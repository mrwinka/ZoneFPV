-- A 16^3 colour grading cube, flattened as R + B*16, G (256 x 16).
-- Only a requested mode is generated, in bounded Canvas batches. The scene
-- itself is processed by the GPU through the camera's ColorGradingLUT.
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local modes=dofile(here..'vision_modes.lua')
local M={WIDTH=256,HEIGHT=16,PIXELS_PER_UPDATE=512,MAX_DRAW_SECONDS=.004,clock=os.clock}
local function clamp(v)return math.max(0,math.min(1,v))end
local function valid(object)
    local ok,value=pcall(function()return object and object:IsValid()end)
    return ok and value
end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function()return a:GetAddress()==b:GetAddress()end)
    return ok and value
end
local palettes={
    [5]={{0,0.02,0,0.25},{0.18,0.12,0,0.65},{0.35,0,0.7,0.9},{0.5,0.1,0.8,0.15},
         {0.65,1,0.95,0},{0.8,1,0.2,0},{0.92,0.95,0.15,0.65},{1,1,0.95,0.98}},
    [6]={{0,0,0,0.04},{0.22,0.18,0,0.4},{0.4,0.58,0,0.5},{0.6,0.95,0.08,0.18},
         {0.78,1,0.48,0},{0.92,1,0.92,0.12},{1,1,1,0.93}},
    [7]={{0,0.01,0.05,0.18},{0.18,0,0.48,0.6},{0.38,0.16,0.1,0.25},
         {0.5,0.55,0,0.12},{0.72,1,0.08,0},{0.88,1,0.66,0.12},{1,1,1,0.87}},
    [8]={{0,0.03,0.03,0.03},{0.68,0.58,0.58,0.58},{0.73,0.75,0.27,0.05},
         {0.83,1,0.65,0.12},{0.94,1,0.96,0.52},{1,1,1,0.98}},
    [11]={{0,.03,.03,.03},{.67,.4,.4,.4},{.76,.6,.08,.02},{.88,1,.06,.01},{1,1,.18,.04}},
    [13]={{0,.015,.04,.12},{.45,.05,.28,.55},{.72,.18,.58,.85},{1,.94,.99,1}},
    [14]={{0,.05,.025,.01},{.45,.36,.2,.07},{.72,.7,.45,.2},{1,1,.89,.68}},
    [15]={{0,.005,.035,.005},{.45,.02,.28,.04},{.72,.06,.62,.12},{1,.67,1,.72}},
}
-- A visible-light scene is not a temperature field. Keep a readable midrange
-- for buildings/terrain; reserve the top end for the emissive actor material.
-- The old straight black-to-white curve plus negative exposure crushed the
-- entire surroundings, making a palette look like silhouettes on black.
local function thermalTone(t)
    if t<=.88 then return .1+.65*(t/.88)^.7 end
    return .75+.25*(t-.88)/.12
end
M.thermalTone=thermalTone
local function colour(mode,r,g,b)
    local t=clamp(0.2126*r+0.7152*g+0.0722*b)
    if mode==1 then
        t=t^0.62
        return {R=t*0.09,G=t,B=t*0.16,A=1}
    elseif mode==2 then
        t=t^0.72
        return {R=t*0.9,G=t*0.96,B=t,A=1}
    elseif mode==10 then
        t=clamp(.035+.96*t^.8)
        return {R=t*.94,G=t*.97,B=t,A=1}
    elseif mode==12 then
        t=clamp(.025+.975*t^.68)
        return {R=t,G=t,B=t,A=1}
    elseif mode==9 then return {R=r,G=g,B=b,A=1} end
    if modes.needsTargets(mode)then t=thermalTone(t)end
    if mode==3 then return {R=t,G=t,B=t,A=1}
    elseif mode==4 then return {R=1-t,G=1-t,B=1-t,A=1} end
    local stops=palettes[mode]
    if not stops then return {R=r,G=g,B=b,A=1} end
    for i=2,#stops do
        local a,z=stops[i-1],stops[i]
        if t<=z[1] then
            local q=(t-a[1])/(z[1]-a[1])
            return {R=a[2]+(z[2]-a[2])*q,G=a[3]+(z[3]-a[3])*q,
                    B=a[4]+(z[4]-a[4])*q,A=1}
        end
    end
    local z=stops[#stops];return {R=z[2],G=z[3],B=z[4],A=1}
end
M.colour=colour
local function createArguments(library,world)
    -- CreateRenderTarget2D acquired optional UAV support in later engines.
    -- Read the actual reflected signature instead of trying an incorrect call.
    local arguments={}
    local values={WorldContextObject=world,Width=M.WIDTH,Height=M.HEIGHT,
        Format=2,ClearColor={R=0,G=0,B=0,A=1},bAutoGenerateMipMaps=false,bSupportUAVs=false}
    library.CreateRenderTarget2D:ForEachProperty(function(property)
        local name=property:GetFName():ToString()
        if name~='ReturnValue' then
            assert(values[name]~=nil,'unsupported render target argument: '..tostring(name))
            arguments[#arguments+1]=values[name]
        end
    end)
    assert(#arguments>=6,'render target signature unavailable')
    return arguments
end
function M.new(world,library)
    local client={world=world,library=library,entries={}}
    local function fail(self,entry,why)
        entry.error=tostring(why);self.error=entry.error
        return nil,entry.error
    end
    function client:texture(mode)
        if self.closed then return nil,'render target client closed' end
        if not modes.valid(mode) or mode==0 then return nil,'invalid vision mode' end
        self.requested=mode
        local entry=self.entries[mode]
        if entry and entry.texture and not valid(entry.texture) then self.entries[mode]=nil;entry=nil end
        if not entry then entry={mode=mode,nextPixel=0};self.entries[mode]=entry end
        if entry.error then return nil,entry.error end
        if entry.ready then return entry.texture,'ready' end
        -- The caller must root the pending texture through an engine reference
        -- without assigning it to the visible LUT until every pixel is ready.
        return nil,'pending',entry.texture
    end
    function client:update()
        if self.closed then return nil,'render target client closed' end
        if not self.requested then return true,'ready' end
        local entry=self.entries[self.requested]
        if entry.error then return nil,entry.error end
        if not valid(world) or not valid(library) then return fail(self,entry,'render target world/library unavailable') end
        if entry.ready and valid(entry.texture) then return true,'ready' end
        if entry.texture and not valid(entry.texture) then entry.texture=nil;entry.nextPixel=0;entry.ready=nil end
        if not entry.texture then
            local created,texture=pcall(function()
                self.createArgs=self.createArgs or createArguments(library,world)
                return library:CreateRenderTarget2D(table.unpack(self.createArgs))
            end)
            if not created or not valid(texture) then return fail(self,entry,created and 'render target creation failed' or texture) end
            entry.texture=texture
        end
        local first=entry.nextPixel
        local last=math.min(M.WIDTH*M.HEIGHT-1,first+M.PIXELS_PER_UPDATE-1)
        -- UE4SS supplies object out params in holder.Canvas and struct fields
        -- directly in the holder. The same holder also accommodates older
        -- UE4SS builds which do not consume object out-param tables.
        local holder={}
        local begun,err=pcall(function()
            library:BeginDrawCanvasToRenderTarget(world,entry.texture,holder,holder,holder)
        end)
        if not begun then return fail(self,entry,err) end
        -- Use completed reflected out parameters, rather than native hook
        -- wrappers: the installed UE4SS's post-hook exposed an invalid Canvas.
        -- Binary proof for the supported Shipping game (cd15cbee / b963000):
        -- Begin exec 0x57e85c4 allocates only an 8-byte context; Begin 0x57e87cc
        -- writes only its RenderTarget pointer, End 0x57eb5c8 reads/clears it.
        -- The private profiling DrawEvent field is compiled out in this build,
        -- so the reflected table retains the complete native context.
        local drawn,drawError=pcall(function()
            assert(same(holder.RenderTarget,entry.texture),'render target context unavailable')
            local canvas=holder.Canvas
            assert(valid(canvas),'render target Canvas unavailable after Begin returned')
            local deadline=M.clock()+M.MAX_DRAW_SECONDS
            for pixel=first,last do
                -- The old fixed 64-pixel batch needed 64 game frames (about
                -- two seconds in the reported flight). Use a larger ceiling,
                -- but stop on elapsed CPU time to avoid a long frame.
                if pixel>first and M.clock()>=deadline then break end
                local x=pixel%M.WIDTH;local y=math.floor(pixel/M.WIDTH)
                local r=(x%16)/15;local b=math.floor(x/16)/15;local g=y/15
                canvas:K2_DrawLine({X=x,Y=y+0.5},{X=x+1,Y=y+0.5},1,
                    colour(entry.mode,r,g,b))
                entry.nextPixel=pixel+1
            end
        end)
        -- Always end once on this same game-thread call, including draw errors.
        local ended,endError=pcall(function()
            library:EndDrawCanvasToRenderTarget(world,holder)
        end)
        if not drawn then return fail(self,entry,drawError) end
        if not ended then return fail(self,entry,endError) end
        if entry.nextPixel==M.WIDTH*M.HEIGHT then entry.ready=true;return true,'ready' end
        return false,'pending'
    end
    function client:destroy()
        self.closed=true
        self.entries={};self.createArgs=nil
    end
    return client
end
return M
