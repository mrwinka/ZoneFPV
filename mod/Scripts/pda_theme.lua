-- Native PDA fonts/brushes are read-only sources. Three proven cooked UI
-- assets may be resolved once; only the owner's newly created controls change.
local M={}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local assetLoader=dofile(here..'asset_loader.lua').new()
local skinAssets={
    background='/Game/GameLite/FPS_Game/UIRemaster/UITextures/PDA/PDAView/QuestBackground/T_pda_main_background.T_pda_main_background',
    controlFont='/Game/GameLite/FPS_Game/UIRemaster/Fonts/Oswald.Oswald',
    bodyFont='/Game/GameLite/FPS_Game/UIRemaster/Fonts/Rubik.Rubik',
}
local resolvedAssets={}
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return o~=nil and call(o,'IsValid')==true end
local function exactAsset(object,path,className)
    if not valid(object)then return false end
    local full=call(object,'GetFullName')
    local actual=type(full)=='string'and (full:match('^%S+%s+(/.+)$')or full)
    if type(actual)~='string'or actual:gsub(':([^:/]+)$','.%1')~=path then return false end
    local class=call(object,'GetClass');local seen={}
    for _=1,16 do
        if not valid(class)then return false end
        local address=call(class,'GetAddress');if address and seen[address]then return false end
        if address then seen[address]=true end
        local name=call(class,'GetFullName')
        name=type(name)=='string'and (name:match('^%S+%s+(/.+)$')or name)
        if name=='/Script/Engine.'..className or name=='/Script/Engine:'..className then return true end
        class=call(class,'GetSuperStruct')
    end
    return false
end
local function skinAsset(key,className,provided)
    local path=skinAssets[key]
    if provided then
        local object=provided[path]
        return exactAsset(object,path,className)and object or nil
    end
    local cached=resolvedAssets[path]
    if cached and exactAsset(cached,path,className)then return cached end
    if cached~=nil then resolvedAssets[path]=nil;assetLoader.cache[path]=nil end
    local ok,object=pcall(assetLoader.load,assetLoader,path)
    local result=ok and exactAsset(object,path,className)and object or nil
    resolvedAssets[path]=result
    if not result then assetLoader.cache[path]=nil end
    return result
end
local function unwrap(o)
    local kind=call(o,'type')
    if kind=='RemoteUnrealParam'or kind=='LocalUnrealParam'then return call(o,'get')end
    return o
end
local function eachChild(widget,fn)
    local array=call(widget,'GetAllChildren');if not array then return end
    local plain=type(array)=='table'and type(read(array,'GetArrayNum'))~='function'
    local n=plain and #array or call(array,'GetArrayNum')
    if type(n)~='number'or n<0 or n>64 or n%1~=0 then return end
    for i=1,n do fn(unwrap(read(array,i)))end
end
local function color(r,g,b,a)return {R=r,G=g,B=b,A=a or 1}end
local function srgb(r,g,b,a)
    local function channel(value)
        value=value/255
        return value<=.04045 and value/12.92 or ((value+.055)/1.055)^2.4
    end
    return color(channel(r),channel(g),channel(b),a)
end
local function linear(value)
    local specified=read(value,'SpecifiedColor')
    if specified then
        local rule=read(value,'ColorUseRule');if rule~=nil and rule~=0 then return end
        value=specified
    end
    local result={}
    for _,k in ipairs({'R','G','B','A'})do
        local v=read(value,k)
        if type(v)~='number'or v~=v or v==math.huge or v==-math.huge then return end
        result[k]=v
    end
    return result
end
local function fontOf(widget)
    local text=read(widget,'CommonTextObj')
    local font=valid(text)and read(text,'Font')or read(widget,'Font')
    font=font or read(read(read(widget,'TextSettings'),'FontStyle'),'Font')
    local size=read(font,'Size')
    if type(size)=='number'and size>0 and size<256 then return font end
end
local function regularFont(font)
    if not font then return false end
    local face=read(font,'TypefaceFontName')
    face=type(face)=='string'and face or call(face,'ToString')or ''
    local asset=call(read(font,'FontObject'),'GetFullName')or ''
    local description=(face..' '..asset):lower()
    for _,weight in ipairs({'bold','black','heavy','medium','semibold'})do if description:find(weight,1,true)then return false end end
    for _,weight in ipairs({'regular','light','book','normal'})do if description:find(weight,1,true)then return true end end
    return false
end
local function isVisible(widget)
    local visibility=call(widget,'GetVisibility')
    return valid(widget)and visibility~=1 and visibility~=2
end
local function set(widget,method,value)widget[method](widget,value)end
function M.new(view,options)
    -- Display-space samples from the native Notes/Upgrades/Stats pages:
    -- background 22/17/16, footer 30/28/27, list cream 202/191/176,
    -- heading 227/223/205 and orange 243/143/1. Convert once for UMG; inactive
    -- top navigation is a different, deliberately dim role and is not sampled.
    local theme={colors={text=srgb(202,191,176),heading=srgb(227,223,205),muted=srgb(159,162,153),navText=srgb(202,191,176),amber=srgb(243,143,1),
        page=srgb(22,17,16),sidebar=srgb(20,17,15),footer=srgb(30,28,27),preview=srgb(15,12,11),
        row=srgb(25,20,18),rowActive=srgb(158,100,3,.08),rule=srgb(60,53,46,.70),ruleActive=srgb(151,92,11,.72),
        tab=srgb(29,27,25,.85),tabActive=srgb(202,191,176),tabText=srgb(63,55,50),hover=srgb(117,79,32,.055),
        transparent=color(0,0,0,0),panelOverlay=color(0,0,0,.025),modulation=color(1,1,1),controlActive=srgb(202,191,176)},sampledWidgets=0,rounded={}}
    local provided=options and options.assets
    theme.backgroundTexture=skinAsset('background','Texture2D',provided)
    theme.controlFontAsset=skinAsset('controlFont','Font',provided)
    theme.bodyFontAsset=skinAsset('bodyFont','Font',provided)
    if theme.backgroundTexture then theme.pageBrushPath=skinAssets.background end
    local faceOK,face=pcall(function()return FName('Regular')end)
    if faceOK and type(face)~='string'and call(face,'ToString')=='Regular'then theme.regularFace=face end
    local tabs=read(read(view,'NavigationPanel'),'SlotContainer')
    eachChild(tabs,function(tab)
        if not isVisible(tab)then return end
        local id=read(tab,'ButtonId')
        id=type(id)=='string'and id or call(id,'ToString')
        if id=='ZoneFPV'or id=='Name:ZoneFPV'then return end
        local label=read(tab,'ButtonText');if not valid(label)then return end
        theme.tabFont=theme.tabFont or fontOf(label)
    end)
    -- Fonts on the active native page can differ from the compact tab face.
    -- Traverse only that known tree, never the global UObject array. Limit
    -- widget count and every TArray; do not use UE4SS's ForEach callbacks.
    local queue,seen={},{}
    local function enqueue(widget)
        if #queue>=128 or not valid(widget)or seen[widget]then return end
        seen[widget]=true;queue[#queue+1]=widget
    end
    local switcher=read(view,'Switcher');local page=call(switcher,'GetActiveWidget')
    if valid(page)then enqueue(page)
    else eachChild(switcher,function(widget)if #queue<4 then enqueue(widget)end end)end
    -- The cooked book's own backing can carry the worn PDA texture even
    -- when the selected map/tutorial page has no background image itself.
    enqueue(read(read(view,'WidgetTree'),'RootWidget'))
    local i=1
    while i<=#queue do
        local widget=queue[i];i=i+1;theme.sampledWidgets=theme.sampledWidgets+1
        if isVisible(widget)then
            local font=fontOf(widget)
            if not theme.bodyFont and regularFont(font)then theme.bodyFont=font end
            local name=call(call(widget,'GetFName'),'ToString')
            if not theme.backgroundTexture and not theme.pageBrush and type(name)=='string'and name:lower():find('background',1,true)then
                local tint=linear(read(widget,'BrushColor'))or linear(read(widget,'ColorAndOpacity'))
                local brush=read(widget,'Brush')
                local resource=read(brush,'ResourceObject')
                local full=valid(resource)and call(resource,'GetFullName')
                local path=type(full)=='string'and full:match('^%S+%s+(/.+)$')
                local klass=call(resource,'GetClass');local classFull=valid(klass)and call(klass,'GetFullName')
                local classPath=type(classFull)=='string'and classFull:match('^%S+%s+(/.+)$')
                local texture=type(full)=='string'and full:match('^Texture2D ')or classPath=='/Script/Engine.Texture2D'or classPath=='/Script/Engine:Texture2D'
                -- Borrow only an already-loaded native PDA UI texture from a
                -- dark backing. Map photographs, materials and arbitrary mod
                -- assets must not become this page's background. No new load.
                if brush and tint and tint.A>=.5 and math.max(tint.R,tint.G,tint.B)<.2
                    and texture and path and path:match('^/Game/GameLite/FPS_Game/UIRemaster/UITextures/PDA/')then
                    theme.pageBrush=brush;theme.pageBrushPath=path
                end
            end
        end
        enqueue(read(read(widget,'WidgetTree'),'RootWidget'));eachChild(widget,enqueue)
    end
    theme.font=theme.tabFont or theme.bodyFont
    theme.bodyFont=theme.bodyFont or theme.font
    theme.controlFontPath=theme.regularFace and theme.controlFontAsset and skinAssets.controlFont or call(read(theme.font,'FontObject'),'GetFullName')or 'native condensed fallback'
    theme.bodyFontPath=theme.regularFace and theme.bodyFontAsset and skinAssets.bodyFont or call(read(theme.bodyFont,'FontObject'),'GetFullName')or 'native regular/condensed fallback'
    theme.white,theme.amber=theme.colors.text,theme.colors.amber
    function theme:label(widget,size,tint,role)
        return pcall(function()
            assert(valid(widget),'PDA label unavailable')
            local sampled=role=='body'and self.bodyFont or self.font
            -- UTextBlock::SetFont copies the complete FSlateFontInfo value into
            -- this widget. Read back its OWN struct before changing Size;
            -- never write to the borrowed native font proxy or font assets.
            if sampled then set(widget,'SetFont',sampled)end
            if size~=nil then
                assert(type(size)=='number'and size>0 and size<256 and size==size,'Invalid PDA font size')
                local target=assert(read(widget,'Font'),'PDA label Font unavailable')
                -- Plain-table adapters may retain arguments by reference;
                -- preserve their source too. Engine struct properties copy.
                if type(target)=='table'and target==sampled then
                    local copy={};for k,v in pairs(target)do copy[k]=v end;target=copy
                end
                local fontAsset=role=='body'and self.bodyFontAsset or self.controlFontAsset
                if fontAsset and self.regularFace then
                    target.FontObject=fontAsset
                    target.TypefaceFontName=self.regularFace
                end
                -- Native heading fonts can carry an outline that makes small
                -- descriptions look artificially bold. Change only our copied
                -- font, including a copied nested table in retained adapters.
                local outline=read(target,'OutlineSettings')
                if outline and type(read(outline,'OutlineSize'))=='number'then
                    if type(outline)=='table'and outline==read(sampled,'OutlineSettings')then
                        local copy={};for k,v in pairs(outline)do copy[k]=v end;outline=copy;target.OutlineSettings=outline
                    end
                    outline.OutlineSize=0
                end
                target.Size=size;set(widget,'SetFont',target)
            end
            local c=assert(linear(tint or self.colors.text),'Invalid PDA label color')
            set(widget,'SetColorAndOpacity',{SpecifiedColor=c,ColorUseRule=0})
        end)
    end
    function theme:button(widget,active,hovered)
        return pcall(function()
            assert(valid(widget),'PDA control unavailable')
            -- The installed Lua UFunction bridge uses a fixed 0x200-byte
            -- parameter buffer. FButtonStyle exceeds it: SetStyle corrupts
            -- its stack before pcall can catch anything. Edit only small
            -- fields in this OWN button's existing reflected style instead.
            local style=read(widget,'WidgetStyle')
            if style then
                for _,state in ipairs({'Normal','Hovered','Pressed','Disabled'})do
                    local brush=read(style,state)
                    if brush then brush.DrawAs=0 end
                end
            end
            -- Existing Slate controls retain a pointer to their owned style.
            -- Borders supplied by the page paint hover/selection backgrounds.
            set(widget,'SetBackgroundColor',self.colors.transparent)
            -- UButton's color also modulates its child text. Keep it neutral;
            -- each owned label receives its final readable palette directly.
            set(widget,'SetColorAndOpacity',self.colors.modulation)
        end)
    end
    function theme:page(widget,fallback)
        return pcall(function()
            assert(valid(widget),'PDA page backing unavailable')
            local textured=false
            if self.backgroundTexture then textured=pcall(set,widget,'SetBrushFromTexture',self.backgroundTexture)
            elseif self.pageBrush then textured=pcall(set,widget,'SetBrush',self.pageBrush)end
            local brush=read(widget,'Background')or read(widget,'Brush')
            if brush and brush~=self.pageBrush then
                brush.TintColor={SpecifiedColor=self.colors.modulation,ColorUseRule=0}
                if self.backgroundTexture and textured then
                    -- This is the same 72px grid used by ordinary native
                    -- pages. Tile it at its authored size instead of stretching
                    -- its dots across the whole panel or loading a new pattern.
                    brush.DrawAs=3;brush.Tiling=3
                    local size=read(brush,'ImageSize')
                    if type(read(size,'X'))=='number'and type(read(size,'Y'))=='number'then
                        size.X=72;size.Y=72
                    end
                end
            end
            -- This authored backing already contains the warm charcoal/grid
            -- pixels. Multiplying them by a dark panel tint hides the texture.
            set(widget,'SetBrushColor',textured and self.colors.modulation or fallback or self.colors.page)
            self.backgroundApplied=textured
        end)
    end
    function theme:tabBacking(widget,active,hovered)
        return pcall(function()
            assert(valid(widget),'PDA subsection backing unavailable')
            if not self.rounded[widget]then
                self.rounded[widget]=true
                local brush=read(widget,'Background')or read(widget,'Brush')
                local outline=read(brush,'OutlineSettings')
                local radii=read(outline,'CornerRadii')
                if type((read(brush,'DrawAs')))=='number'and type((read(radii,'X')))=='number'
                    and type((read(outline,'RoundingType')))=='number'and type((read(outline,'Width')))=='number'then
                    -- Small fields of this OWN primitive brush only. Never
                    -- marshal a whole FButtonStyle/FSliderStyle UFunction.
                    pcall(function()
                        brush.DrawAs=4 -- RoundedBox.
                        outline.CornerRadii={X=3,Y=3,Z=3,W=3};outline.RoundingType=0
                        outline.Width=0
                    end)
                end
            end
            set(widget,'SetBrushColor',active and self.colors.tabActive or hovered and self.colors.hover or self.colors.tab)
        end)
    end
    return theme
end
return M
