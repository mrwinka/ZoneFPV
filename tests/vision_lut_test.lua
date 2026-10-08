local lut=dofile('mod/Scripts/vision_lut.lua')
local rawClock=lut.clock
lut.clock=function()return 0 end -- fast renderer, deterministic frame ceiling
local nextId=0
local function object()
    nextId=nextId+1
    local value={alive=true,id=nextId}
    function value:IsValid()return self.alive end
    function value:GetAddress()return self.id end
    return value
end
RegisterHook=function()error('LUT must not register native callbacks')end
UnregisterHook=function()error('LUT must not unregister native callbacks during mode changes')end
local function fixture(extra)
    local world,library=object(),object()
    local stats={creates=0,begins=0,ends=0,draws=0,frames=0,maxBatch=0}
    local signature={'WorldContextObject','Width','Height','Format','ClearColor','bAutoGenerateMipMaps'}
    if extra then signature[#signature+1]=extra end
    signature[#signature+1]='ReturnValue'
    library.CreateRenderTarget2D=setmetatable({ForEachProperty=function(_,callback)
        for _,name in ipairs(signature)do
            callback({GetFName=function()return {ToString=function()return name end}end})
        end
    end},{__call=function(_,_,ctx,width,height,format,clear,mips,uavs)
        assert(ctx==world and width==256 and height==16 and format==2 and clear.A==1 and mips==false)
        if extra=='bSupportUAVs' then assert(uavs==false)end
        stats.creates=stats.creates+1
        local texture=object();texture.pixels={};return texture
    end})
    function library:EndDrawCanvasToRenderTarget(ctx,context)
        assert(ctx==world and context==stats.context and context.RenderTarget==stats.target,
            'End must receive the completed reflected context from this Begin')
        assert(stats.active,'End must be paired with Begin')
        stats.ends=stats.ends+1;stats.active=false
        context.RenderTarget=nil
        if stats.endFail then error('end failed')end
    end
    function library:BeginDrawCanvasToRenderTarget(ctx,texture,canvasOut,sizeOut,contextOut)
        assert(ctx==world and canvasOut==sizeOut and sizeOut==contextOut)
        assert(not stats.active,'each batch must end before another batch begins')
        stats.begins=stats.begins+1;stats.active=true
        stats.context=canvasOut;stats.target=texture
        local canvas=object();local batch=0
        function canvas:K2_DrawLine(a,b,thickness,colour)
            assert(stats.active and thickness==1 and b.X==a.X+1 and b.Y==a.Y)
            assert(a.X>=0 and a.X<256 and a.Y>=0 and a.Y<16)
            if stats.drawFail then error('pixel failed')end
            local pixel=math.floor(a.Y)*256+a.X
            assert(not texture.pixels[pixel],'no duplicate pixels or overwritten rows')
            texture.pixels[pixel]=colour;batch=batch+1;stats.draws=stats.draws+1
        end
        -- Actual Shipping context is an 8-byte RenderTarget pointer; profiling
        -- DrawEvent is absent. Canvas becomes usable after Begin has completed.
        canvasOut.Canvas=canvas;canvasOut.X=256;canvasOut.Y=16;canvasOut.RenderTarget=texture
        stats.lastCanvas=canvas
        stats.batch=function()return batch end
    end
    return lut.new(world,library),stats,world,library
end
local function close(a,b,why)assert(math.abs(a-b)<0.00001,why)end
local client,stats=fixture('bSupportUAVs')
local texture,status=client:texture(3);assert(texture==nil and status=='pending')
assert(client:update()==false and stats.draws==512 and stats.ends==1)
local _,pending,partial=client:texture(3);assert(pending=='pending' and partial:IsValid())
client:texture(6);assert(client:update()==false and stats.creates==2)
client:texture(3)
for _=2,8 do client:update()end
texture,status=client:texture(3)
assert(texture==partial and status=='ready' and stats.batch()==512 and stats.begins==stats.ends,'fast renderer must finish in eight frames instead of sixty-four')
close(texture.pixels[0].R,.1,'thermal black floor preserves readable surroundings')
close(texture.pixels[4095].R,1,'hot white-hot is white')
close(texture.pixels[15].R,lut.thermalTone(.2126),'red cube samples preserve graded Rec.709 luminance')
close(texture.pixels[15*256].G,lut.thermalTone(.7152),'green is the vertical cube axis')
close(texture.pixels[240].B,lut.thermalTone(.0722),'blue occupies horizontal cube slices')
local finishedDraws=stats.draws;assert(client:update()==true and stats.draws==finishedDraws)
print('PASS bounded GPU LUT generation after completed Begin, Shipping context, cube axes and requested-mode priority')

for mode=1,15 do
    client:texture(mode)
    for _=1,8 do local result=client:update();assert(result~=nil)end
    local ready,why=client:texture(mode);assert(ready and why=='ready')
    local cold,hot=ready.pixels[0],ready.pixels[4095]
    assert(cold and hot)
    for pixel=0,4095 do
        local c=ready.pixels[pixel];assert(c and c.A==1)
        for _,key in ipairs({'R','G','B'})do assert(c[key]>=0 and c[key]<=1,'palette RGB must stay in display range')end
    end
    if mode==1 then assert(hot.G>hot.R and hot.G>hot.B)
    elseif mode==2 then assert(hot.B>=hot.G and hot.G>=hot.R)
    elseif mode==4 then close(cold.R,.9,'black-hot has a light environment');close(hot.R,0,'black-hot actor is black')
    elseif mode==9 then
        local rgb=lut.colour(mode,.2,.6,.9);close(rgb.R,.2,'Fusion keeps scene red');close(rgb.G,.6,'Fusion keeps scene green');close(rgb.B,.9,'Fusion keeps scene blue')
    elseif mode>=5 and mode~=10 and mode~=12 then
        local mid=lut.colour(mode,0.8,0.8,0.8)
        assert(math.max(mid.R,mid.G,mid.B)-math.min(mid.R,mid.G,mid.B)>0.2,'thermal colour modes must apply actual distinct colour palettes')
    end
end
assert(stats.creates==15 and stats.begins==stats.ends)
local old=client:texture(3);old.alive=false
assert(select(2,client:texture(3))=='pending');client:update();assert(stats.creates==16)
client:destroy();assert(client:update()==nil)
print('PASS fifteen distinct GPU palettes, readable thermal midtones, Fusion RGB, cached textures and callback-free cleanup')

local broken,brokenStats=fixture()
brokenStats.drawFail=true;broken:texture(5)
local result,why=broken:update()
assert(result==nil and why:find('pixel failed') and brokenStats.ends==1 and not brokenStats.active)
assert(broken:update()==nil and brokenStats.begins==1,'failed modes must not retry work every frame')
broken:destroy()
local endBroken,endStats=fixture();endStats.endFail=true;endBroken:texture(6)
result,why=endBroken:update();assert(result==nil and why:find('end failed') and endStats.ends==1);endBroken:destroy()
local nextClient,nextStats=fixture();nextClient:texture(3)
assert(nextClient:update()==false and nextStats.ends==1);nextClient:destroy()
local unsupported,unsupportedStats=fixture('UnexpectedArgument');unsupported:texture(5)
result,why=unsupported:update()
assert(result==nil and why:find('unsupported render target argument') and unsupportedStats.creates==0);unsupported:destroy()
print('PASS draw errors still close their completed context, mode switching without callbacks and reflected signature validation')

local elapsed=0
lut.clock=function()return elapsed end
local slow,slowStats,slowWorld,slowLibrary=fixture()
local rawBegin=slowLibrary.BeginDrawCanvasToRenderTarget
function slowLibrary:BeginDrawCanvasToRenderTarget(...)
    rawBegin(self,...)
    local canvas=slowStats.lastCanvas;local draw=canvas.K2_DrawLine
    function canvas:K2_DrawLine(...)
        draw(self,...);elapsed=elapsed+.001
    end
end
slow:texture(3)
assert(slow:update()==false and slowStats.draws>=4 and slowStats.draws<=5,'slow renderer must yield near 4 ms rather than issuing all 512 draws')
local _,state,partial=slow:texture(3)
assert(state=='pending' and partial.pixels[0] and not partial.pixels[511])
local firstCount=slowStats.draws;slow:update()
assert(slowStats.draws>firstCount and slowStats.begins==slowStats.ends,'next batch resumes without leaking the Canvas context')
slow:destroy();lut.clock=rawClock
print('PASS fast palette preparation and adaptive slow-renderer frame budget')
