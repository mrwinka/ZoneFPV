-- Exercise the real rendering adapter with a restricted reflected UI model:
-- no native game object is a writable widget, and every UMG node has one tree.
local M=dofile('mod/Scripts/scan_view.lua')
local methods,serial,fixture={},0,nil
local function object(n,class,owned)
    serial=serial+1
    return setmetatable({id=serial,name=n,class=class,owned=owned,children={},Font={Size=24}}, {__index=methods})
end
function methods:IsValid()return not self.dead end
function methods:GetAddress()return self.id end
function methods:GetFName()return {ToString=function()return self.name end}end
function methods:GetClass()return self.class end
function methods:GetSuperStruct()fixture.superReads=(fixture.superReads or 0)+1;return self.super end
function methods:GetFullName()return self.full end
function methods:IsAnyClass()return self.classObject==true end
function methods:GetOuter()return self.outer end
function methods:GetWorld()return self.world or self.owner and self.owner.world end
function methods:GetOwningPlayer()return self.owner end
function methods:GetViewportSize()return {X=3440,Y=1440}end
function methods:GetViewportScale()fixture.scaleReads=(fixture.scaleReads or 0)+1;return fixture.viewportScale or 1 end
function methods:GetDesiredSize()return {X=#(self.text or '')*self.Font.Size*.65,Y=self.Font.Size*(fixture.lineHeight or 4/3)}end
function methods:IsInViewport()return self.viewport==true end
function methods:IsA(path)
    fixture.stringTypeQueries=(fixture.stringTypeQueries or 0)+1
    -- Shipping UE4SS string IsA resolves the class through StaticFindObject.
    -- The real log already proved that native classes can be unavailable by
    -- this path even when an existing object's reflected UClass is valid.
    if fixture.nativeClassPathMiss then return false end
    return self.texture and path=='/Script/Engine.Texture2D'
end
local function writable(o)
    assert(o.owned,'Scanner must never write native game actors/UI')
    fixture.writes=fixture.writes+1
end
-- Bound below after writable is defined, so measurements never bypass the
-- same ownership assertion used by normal rendering setters.
function methods:ForceLayoutPrepass()writable(self);fixture.prepasses=(fixture.prepasses or 0)+1 end
function methods:SetRenderTransformPivot(v)writable(self);self.pivot=v end
function methods:SetRenderTransformAngle(v)writable(self);self.angle=v end
function methods:SetVisibility(v)
    writable(self);if fixture.failVisibility and self==fixture.host then error('visibility failure')end
    self.visibility=v
end
function methods:SetAnchors(v)
    writable(self);self.anchors=v;fixture.anchorWrites=fixture.anchorWrites+1
end
function methods:SetOffsets(v)writable(self);self.offsets=v;fixture.offsetWrites=(fixture.offsetWrites or 0)+1 end
function methods:SetPadding(v)writable(self);self.padding=v end
function methods:SetBrushColor(v)writable(self);self.color=v;fixture.tintWrites=fixture.tintWrites+1 end
function methods:SetJustification(v)writable(self);self.justification=v end
function methods:SetFont(v)writable(self);self.Font=v;fixture.fontWrites=(fixture.fontWrites or 0)+1 end
function methods:SetColorAndOpacity(v)writable(self);self.color=v end
function methods:SetText(v)writable(self);self.text=v;fixture.textWrites=fixture.textWrites+1 end
function methods:SetBrushFromTexture(v,match)
    writable(self);assert(v.texture and match==false);self.texture=v;fixture.textureWrites=fixture.textureWrites+1
end
function methods:AddToViewport(z)
    writable(self);assert(z==50 and self.WidgetTree.RootWidget,'Root must be privately initialized before attachment')
    self.viewport=true;fixture.viewportAdds=fixture.viewportAdds+1
end
function methods:RemoveFromParent()
    writable(self);if fixture.failRemove then error('detach failure')end
    self.viewport=false;fixture.removes=fixture.removes+1
end
function methods:AddChild(widget)
    writable(self);assert(widget.owned and widget.outer==fixture.tree)
    self.children[#self.children+1]=widget
    widget.Slot=object('Slot',fixture.meta,true);widget.Slot.outer=fixture.tree
    return widget.Slot
end
function methods:Create(pc,class,owner)
    assert(self==fixture.library and pc==fixture.pc and owner==pc and class==fixture.base)
    fixture.creates=fixture.creates+1
    if fixture.failFactory then error('factory unavailable')end
    local host=object('ZoneFPVScanner',class,true);host.owner=pc
    fixture.tree=object('PrivateWidgetTree',fixture.meta,true);host.WidgetTree=fixture.tree
    fixture.host=host
    return host
end
FText=function(s)return s end
FindAllOf=function()error('Scanner renderer must not globally enumerate UI or NPCs')end
FindFirstOf=FindAllOf
local function setup()
    fixture={writes=0,anchorWrites=0,tintWrites=0,textWrites=0,textureWrites=0,viewportAdds=0,removes=0,creates=0,allocations=0,lookups=0}
    fixture.meta=object('Class');fixture.meta.class=fixture.meta
    fixture.world=object('GameWorld',fixture.meta)
    fixture.pc=object('PlayerController',fixture.meta);fixture.pc.world=fixture.world
    fixture.base=object('PageViewBase',fixture.meta);fixture.base.classObject=true;fixture.base.full='Class /Script/Stalker2:PageViewBase'
    fixture.classes={}
    for _,n in ipairs({'CanvasPanel','Border','TextBlock','Image'})do
        local class=object(n,fixture.meta);class.classObject=true;class.full='Class /Script/UMG:'..n
        fixture.classes[n]=class
    end
    fixture.library=object('Default__WidgetBlueprintLibrary',fixture.meta)
    fixture.layout=object('Default__WidgetLayoutLibrary',fixture.meta)
    fixture.textureClass=object('Texture2D',fixture.meta);fixture.textureClass.classObject=true;fixture.textureClass.full='Class /Script/Engine:Texture2D'
    fixture.texture=object('NativeBanditsTexture',fixture.textureClass);fixture.texture.texture=true
    StaticFindObject=function(path)
        fixture.lookups=fixture.lookups+1
        if not fixture.classesUnavailable and path==(fixture.dotOnly and '/Script/Stalker2.PageViewBase'or '/Script/Stalker2:PageViewBase')then return fixture.base end
        if path=='/Script/UMG:Default__WidgetBlueprintLibrary'then return fixture.library end
        if path=='/Script/UMG.Default__WidgetLayoutLibrary'then return fixture.layout end
        local class=path:match(fixture.dotOnly and '^/Script/UMG%.(.+)$'or '^/Script/UMG:(.+)$')
        if class and not fixture.classesUnavailable then return fixture.classes[class]end
        if not fixture.unloadedIcons and path:match('T_binocular_faction_icon_bandits%.T_binocular_faction_icon_bandits$')then return fixture.texture end
    end
    LoadAsset=function(path)
        fixture.assetLoads=fixture.assetLoads or {};fixture.assetLoads[#fixture.assetLoads+1]=path
        if fixture.loadPolicy then return fixture.loadPolicy(path)end
        return nil,false,false
    end
    StaticConstructObject=function(class,outer)
        assert(outer==fixture.tree and class.classObject and class~=fixture.base)
        fixture.allocations=fixture.allocations+1
        local o=object('Own'..class.name..fixture.allocations,class,true);o.outer=outer
        return o
    end
    local s={pc=fixture.pc,world=fixture.world}
    local logs={};return M.new(function(v)logs[#logs+1]=v end),s,logs
end
local function marker(x,faction)
    return {type=1,x=x or .5,y=.5,width=.1,height=.2,distance=43.2,relation=0,faction=faction or 1}
end
local view,s,logs=setup()
assert(view:update(s,{marker()},3440,1440))
assert(fixture.creates==1 and fixture.viewportAdds==1 and #view.pool==1)
assert(fixture.host.visibility==3 and fixture.host.bShouldBindWidgetInputs==false and fixture.host.bShoudIgnoreInputOnPouse==false)
assert(view.pool[1].panel.visibility==3 and #view.pool[1].lines==12)
assert(view.pool[1].icon.visibility==3 and view.pool[1].label.text=='43 m')
local function srgb(channel)return channel<=.0031308 and channel*12.92 or 1.055*channel^(1/2.4)-.055 end
local red=view.pool[1].lines[1].color
assert(math.abs(srgb(red.R)*255-239)<1e-10 and math.abs(srgb(red.G)*255-70)<1e-10 and math.abs(srgb(red.B)*255-78)<1e-10,'UMG linear colour must reproduce the original red, not the pink caused by treating sRGB bytes as linear')
local a,t,text,lookups,alloc=fixture.anchorWrites,fixture.tintWrites,fixture.textWrites,fixture.lookups,fixture.allocations
for i=1,144 do
    local x=.5+.2*math.sin(i)
    assert(view:update(s,{marker(x)},3440,1440))
    local slot=view.pool[1].slot
    assert(math.abs(slot.anchors.Minimum.X-(x-.05))<1e-12,'Every game camera frame writes the exact current rectangle without temporal filtering')
end
assert(fixture.anchorWrites-a==144,'Exactly one root rectangle update per target/frame; corner geometry is static')
assert(fixture.tintWrites==t and fixture.textWrites==text and fixture.lookups==lookups and fixture.allocations==alloc,'No repeated styles, text, texture searches or widget construction')
assert(#logs==4 and logs[1]:find('Scanner renderer bindings:',1,true)and logs[2]:find('Scanner renderer: game-frame UMG',1,true)
    and logs[3]:find('Scanner pixel style:',1,true)and logs[4]:find('Scanner faction icon ready: bandits.',1,true))
assert(view:update(s,{marker(.6,3)},3440,1440))
assert(view.pool[1].label.text=='43 m'and view.pool[1].icon.visibility==1,'Unavailable icons retain the compact distance without large English faction names')
assert(view:update(s,{},3440,1440)and fixture.host.visibility==1)
assert(view:update(s,{marker()},3440,1440)and fixture.host.visibility==3)
s.inputPaused=true;assert(view:update(s,{marker()},3440,1440)and fixture.host.visibility==1)
s.inputPaused=false;s.radio={lost=true};assert(view:update(s,{marker()},3440,1440)and fixture.host.visibility==1)
s.radio.lost=false
local many={};for i=1,64 do many[i]=marker(.4+i*.001)end
for i=1,20 do assert(view:update(s,many,3440,1440));assert(#view.pool<=16)end
assert(#view.pool==16 and fixture.creates==1,'Marker pool is bounded and reused')
assert(view:update(s,{marker()},3440,1440))
for i=2,16 do assert(view.pool[i].panel.visibility==1)end
assert(not view:update(nil,{},3440,1440)and fixture.removes==1 and #view.pool==0,'FPV exit removes its owned viewport host')
view:destroy();assert(fixture.removes==1)

view,s,logs=setup();fixture.nativeClassPathMiss=true
assert(view:update(s,{marker()},3440,1440))
assert(view.pool[1].icon.visibility==3 and view.pool[1].icon.texture==fixture.texture,
    'A loaded native Texture2D must reach the icon even when the shipping string-IsA class lookup cannot resolve it')
assert(not fixture.stringTypeQueries,'Loaded texture validation must use its reflected exact UClass, not repeat the failed native class lookup')
view:destroy()

view,s,logs=setup();fixture.nativeClassPathMiss=true
fixture.textureClass.full='Object /Script/Engine.Texture2D'
assert(view:update(s,{marker()},3440,1440)and view.pool[1].icon.visibility==3,'The dot identity and shipping Object-labelled UClass wrapper are accepted too')
assert(logs[#logs]:find('class=/Script/Engine.Texture2D',1,true),'Successful load diagnostics include the actual accepted class')
view:destroy()

view,s=setup();fixture.nativeClassPathMiss=true
local textureSubclass=object('StreamingTexture',fixture.meta);textureSubclass.classObject=true
textureSubclass.full='Class /Game/Textures.StreamingTexture';textureSubclass.super=fixture.textureClass
fixture.texture.class=textureSubclass
assert(view:update(s,{marker()},3440,1440)and view.pool[1].icon.visibility==3,'A genuine texture subclass retains its proven native Texture2D base')
view:destroy()

for _,falseClass in ipairs({'/Script/AnotherPlugin.Texture2D','/Script/CoreUObject.Package'})do
    view,s,logs=setup();fixture.nativeClassPathMiss=true
    fixture.textureClass.full='Class '..falseClass
    for _=1,601 do assert(view:update(s,{marker()},3440,1440))end
    assert(view.pool[1].icon.visibility==1 and not view.assetHolders[1],'A valid wrong-type UObject never becomes a texture brush')
    assert(logs[#logs]:find('returned_class=Class '..falseClass,1,true),'Rejection diagnostics expose the actual asset class instead of a userdata pointer')
    view:destroy()
end

view,s=setup();fixture.nativeClassPathMiss=true
fixture.textureClass.classObject=false
for _=1,601 do assert(view:update(s,{marker()},3440,1440))end
assert(view.pool[1].icon.visibility==1,'A matching class path without a real UClass cannot grant texture authority')
view:destroy()

-- Real UE4SS FText is callable userdata, rather than a Lua/C function. Keep
-- both table adapters and the actual userdata shape covered, including opaque
-- metatables: capability is the protected call, not metatable introspection.
local previousText=FText
local textCalls=0
FText=setmetatable({}, {__call=function(_,value)textCalls=textCalls+1;return value end,__metatable='protected constructor'})
view,s,logs=setup()
assert(type(FText)=='table'and view:update(s,{marker()},3440,1440))
assert(textCalls==2 and logs[1]:find('FText=table',1,true),'Callable table performs one probe and one initial label construction')
for i=1,100 do assert(view:update(s,{marker(.5+i*.0001)},3440,1440))end
assert(textCalls==2,'The constructor capability probe is not repeated per frame')
view:destroy();FText=previousText

local textUserdata=assert(io.tmpfile())
local userdataMeta=debug.getmetatable(textUserdata)
textCalls=0
debug.setmetatable(textUserdata,{__call=function(_,value)textCalls=textCalls+1;return value end,__metatable='protected constructor'})
FText=textUserdata
local userdataOK,userdataError=xpcall(function()
    assert(type(FText)=='userdata')
    view,s,logs=setup()
    assert(view:update(s,{marker()},3440,1440)and fixture.viewportAdds==1,'Actual callable userdata enters the game renderer')
    assert(textCalls==2 and logs[1]:find('FText=userdata',1,true))
    view:destroy()
end,debug.traceback)
FText=previousText;debug.setmetatable(textUserdata,userdataMeta);textUserdata:close()
assert(userdataOK,userdataError)

FText={}
view,s,logs=setup()
assert(not view:update(s,{marker()},3440,1440)and fixture.creates==0,'Non-callable text binding fails before native UI allocation')
assert(#logs==2 and logs[2]:find('Game-frame scanner unavailable; desktop fallback:',1,true),'Constructor failure reports the actual cause instead of silently returning')
for _=1,1000 do assert(not view:update(s,{marker()},3440,1440))end
assert(#logs==2 and fixture.creates==0,'Unavailable constructor diagnostics and retries are bounded')
FText=previousText

view,s=setup();fixture.dotOnly=true
assert(view:update(s,{marker()},3440,1440),'Dot-only reflected lookup accepts the exact colon-form class identity returned by UE4SS')
view:destroy()

-- Runtime class resolution mirrors the shipping UE4SS log: library CDOs
-- resolve by path, while primitive/page classes come from existing widgets.
local previousFirst=FindFirstOf
view,s,logs=setup();fixture.classesUnavailable=true
local firstLookups,instances=0,{}
for _,kind in ipairs({'CanvasPanel','Border','TextBlock','Image','PageViewBase'})do
    local native=kind=='PageViewBase'and fixture.base or fixture.classes[kind]
    local cooked=object('Cooked'..kind,fixture.meta);cooked.classObject=true;cooked.full='Class /Game/Existing.Cooked'..kind;cooked.super=native
    instances[kind]=object('ExistingNativeUI'..kind,cooked)
end
FindFirstOf=function(kind)
    assert(instances[kind],'Only a known primitive/page may be queried, never arbitrary Class or world actors')
    firstLookups=firstLookups+1;return instances[kind]
end
assert(view:update(s,{marker()},3440,1440)and fixture.viewportAdds==1,'Existing instance UClasses initialize the real scanner when direct native lookup fails')
assert(firstLookups==5 and fixture.superReads==5 and #logs==9)
for i=1,144 do assert(view:update(s,{marker(.5+i*.0001)},3440,1440))end
assert(firstLookups==5 and fixture.superReads==5,'Cold class lookups and superclass reads never repeat per frame')
for _,nativeWidget in pairs(instances)do assert(not nativeWidget.owned and #nativeWidget.children==0 and not nativeWidget.visibility,'Existing game widgets remain read-only')end
view:destroy()

view,s,logs=setup();fixture.classesUnavailable=true
local foreign=object('PluginCanvas',fixture.meta);foreign.classObject=true;foreign.full='Class /Script/AnotherPlugin.CanvasPanel'
firstLookups=0
FindFirstOf=function(kind)assert(kind=='CanvasPanel');firstLookups=firstLookups+1;return object('ForeignUI',foreign)end
assert(not view:update(s,{marker()},3440,1440)and fixture.creates==0,'A matching short name from another package never grants construction authority')
for _=1,1000 do assert(not view:update(s,{marker()},3440,1440))end
assert(firstLookups==1 and #logs==2,'Unavailable exact classes are diagnosed and latched without recurring global lookups')

view,s=setup();fixture.classesUnavailable=true
local chain=fixture.classes.CanvasPanel
for i=1,17 do
    local subclass=object('CookedLevel'..i,fixture.meta);subclass.classObject=true;subclass.full='Class /Game/Existing.CookedLevel'..i;subclass.super=chain;chain=subclass
end
FindFirstOf=function(kind)assert(kind=='CanvasPanel');return object('DeepNativeUI',chain)end
assert(not view:update(s,{marker()},3440,1440)and fixture.superReads==16 and fixture.creates==0,'Superclass validation has a hard sixteen-read bound')
FindFirstOf=previousFirst

view,s=setup();fixture.failFactory=true
assert(not view:update(s,{marker()},3440,1440));assert(fixture.creates==1)
for _=1,1000 do assert(not view:update(s,{marker()},3440,1440))end
assert(fixture.creates==1,'Failed UI allocation is latched for the session')

view,s=setup();assert(view:update(s,{marker()},3440,1440))
local writes=fixture.writes
fixture.pc.name='RecycledController'
assert(not view:update(s,{marker()},3440,1440)and fixture.removes==1,'A PC change revokes rendering and detaches the still-proven private viewport host')
local afterCleanup=fixture.writes
view:destroy();assert(fixture.writes==afterCleanup,'Private host cleanup is idempotent')

view,s=setup();assert(view:update(s,{marker()},3440,1440))
fixture.pc.world=object('NextWorld',fixture.meta)
assert(not view:update(s,{marker()},3440,1440)and fixture.removes==1 and fixture.host.visibility==1,'World travel cannot leave stale brackets in a persistent viewport')

view,s=setup();assert(view:update(s,{marker()},3440,1440))
fixture.host.name='RecycledNativeWidget';writes=fixture.writes
assert(not view:update(s,{marker()},3440,1440)and fixture.writes==writes,'Recycled host identity revokes cleanup authority as well as rendering')

view,s=setup();assert(view:update(s,{marker()},3440,1440))
fixture.host.WidgetTree=object('ReplacementNativeTree',fixture.meta)
writes=fixture.writes
assert(not view:update(s,{marker()},3440,1440)and fixture.writes==writes,'A replaced tree cannot receive writes')

view,s=setup();assert(view:update(s,{marker()},3440,1440))
fixture.host.owner=object('OtherPlayer',fixture.meta);writes=fixture.writes
assert(not view:update(s,{marker()},3440,1440)and fixture.writes==writes,'An altered owning-player binding revokes private cleanup authority')

view,s,logs=setup();assert(view:update(s,{marker()},3440,1440))
fixture.failRemove=true;view:destroy()
assert(fixture.host.visibility==1 and not view.cleanupPending and #logs>=2,'Failed detach still hides a proven private host and reports cleanup failure')

view,s,logs=setup();assert(view:update(s,{marker()},3440,1440))
fixture.failRemove=true;fixture.failVisibility=true;view:destroy()
assert(view.cleanupPending and #view.pool==1 and fixture.host.viewport,'If both cleanup calls fail the still-visible private host retains its ownership references')
fixture.failRemove=false;fixture.failVisibility=false
view:update(nil,{},3440,1440)
assert(not view.cleanupPending and fixture.removes==1 and #view.pool==0,'Retained cleanup can complete on a later update')

view,s=setup();assert(view:update(s,{marker()},3440,1440))
fixture.host.viewport=false;writes=fixture.writes
assert(not view:update(s,{marker()},3440,1440)and fixture.removes==1,'A detached still-private viewport host is safely cleaned up')

-- Compare actual UMG offsets after DPI scaling with the former GDI pixel
-- contract. A fixed twelve-logical-pixel arm and an unscaled font fail these
-- cases, as does passing the old sRGB bytes directly into linear UMG colour.
for _,screen in ipairs({{1920,1080,1},{3440,1440,1.5},{3840,2160,2},{1280,720,.75}})do
    local width,height,scale=table.unpack(screen)
    view,s=setup();fixture.viewportScale=scale
    local m=marker();assert(view:update(s,{m},width,height))
    local item=view.pool[1]
    local half=math.min(math.max(2,math.floor(m.width*width/2+.5)),math.max(2,math.floor(m.height*height/2+.5)))
    local oldCorner=math.min(half,math.max(3,math.min(14,math.floor(half/5))))
    local oldRound=math.min(4,math.floor(oldCorner/2))
    local oldThickness=math.max(2,math.min(3,math.floor(height/550)))
    local arms=item.corners[1].arms
    assert(math.abs(arms[1].offsets.Right*scale-(oldCorner-oldRound))<1e-10)
    assert(math.abs(arms[2].offsets.Right*scale-oldRound*math.sqrt(2))<1e-10)
    assert(math.abs(arms[3].offsets.Right*scale-oldThickness)<1e-10)
    local labelHeight=math.max(12,math.min(20,math.floor(height/75)))
    local renderedHeight=item.label.Font.Size*(4/3)*scale
    assert(math.abs(renderedHeight-labelHeight)<=scale*2/3+.01,'Font points must yield the compact physical pixel height at '..scale..' DPI')
    assert(math.abs(item.iconSlot.offsets.Right*scale-math.max(16,math.min(32,math.floor(height/45))))<1e-10)
    assert(item.label.text=='43 m')
    local offsets,fonts,probes=fixture.offsetWrites,fixture.fontWrites,fixture.prepasses
    for i=1,144 do assert(view:update(s,{marker(.5+.1*math.sin(i))},width,height))end
    assert(fixture.offsetWrites==offsets and fixture.fontWrites==fonts and fixture.prepasses==probes,'Camera rotation/translation never rewrites cached corner, font or label geometry')
    local distant=marker();distant.width=.005;distant.height=.015
    assert(view:update(s,{distant},width,height))
    local farHalf=math.min(math.max(2,math.floor(distant.width*width/2+.5)),math.max(2,math.floor(distant.height*height/2+.5)))
    local farCorner=math.min(farHalf,math.max(3,math.min(14,math.floor(farHalf/5))))
    local farRound=math.min(4,math.floor(farCorner/2))
    assert(math.abs(item.corners[1].arms[1].offsets.Right*scale-(farCorner-farRound))<1e-10,'Distant NPCs keep short proportional corner arms')
    view:destroy()
end

view,s=setup();fixture.viewportScale=1.25;fixture.lineHeight=2
assert(view:update(s,{marker()},3440,1440))
assert(fixture.prepasses==1 and fixture.fontWrites==2,'One measurement and at most one correction account for actual font line metrics')
assert(math.abs(view.pool[1].label.Font.Size*2*1.25-19)<=1.25)
view:destroy()

-- Demand loading exercises the existing cooked asset loader, not a mock of
-- the scanner's result cache. Each successful texture is immediately pinned
-- by an owned hidden Image brush and can arrive without a faction change.
view,s=setup();fixture.unloadedIcons=true
local loaded={}
fixture.loadPolicy=function(path)
    local asset=object(path,fixture.textureClass);asset.texture=true;loaded[path]=asset
    return asset,true,true
end
local targets={marker(.35,1),marker(.5,3),marker(.65,4)}
assert(view:update(s,targets,3440,1440)and #fixture.assetLoads==1)
assert(view.pool[1].icon.visibility==3 and view.pool[2].icon.visibility==1)
assert(view.pool[2].label.text=='43 m','Pending textures never introduce a large English faction label')
assert(view.assetHolders[1].visibility==1 and view.assetHolders[1].texture==view.pool[1].icon.texture,'The strong engine resource reference belongs to our private tree')
assert(view:update(s,targets,3440,1440)and #fixture.assetLoads==2 and view.pool[2].faction==3 and view.pool[2].icon.visibility==3,'Same-faction marker picks up a texture loaded on a later frame')
assert(view:update(s,targets,3440,1440)and #fixture.assetLoads==3 and view.pool[3].icon.visibility==3)
local textureWrites=fixture.textureWrites
for _=1,144 do assert(view:update(s,targets,3440,1440))end
assert(#fixture.assetLoads==3 and fixture.textureWrites==textureWrites,'No repeated asset or brush writes after the demanded icons are ready')
local noFaction=marker();noFaction.faction=0
assert(view:update(s,{noFaction},3440,1440))
local brushRoots={}
local function collectBrushes(widget)
    if type(widget.texture)=='table'then brushRoots[widget.texture]=true end
    for _,child in ipairs(widget.children)do collectBrushes(child)end
end
collectBrushes(fixture.tree.RootWidget)
for _,asset in pairs(loaded)do assert(brushRoots[asset],'Invisible/different factions retain an engine brush reference, not only a Lua userdata cache')end
view:destroy()

view,s=setup();fixture.unloadedIcons=true
fixture.loadPolicy=function(path)
    if #fixture.assetLoads==1 then return nil,false,false end
    local asset=object(path,fixture.textureClass);asset.texture=true;return asset,true,true
end
assert(view:update(s,{marker()},3440,1440)and #fixture.assetLoads==1 and view.pool[1].icon.visibility==1)
for _=2,300 do assert(view:update(s,{marker()},3440,1440))end
assert(#fixture.assetLoads==1,'Missing cooked icon has a cooldown instead of a per-frame load loop')
assert(view:update(s,{marker()},3440,1440)and #fixture.assetLoads==2 and view.pool[1].icon.visibility==3,'A prior miss is retried and replaced without changing faction')
view:destroy()

view,s,logs=setup();fixture.unloadedIcons=true
for _=1,1200 do assert(view:update(s,{marker()},3440,1440))end
assert(#fixture.assetLoads==3 and #logs==4 and logs[4]:find('faction icon unavailable',1,true),'Repeated failures stop at three attempts and produce one bounded diagnostic')
assert(view.pool[1].label.text=='43 m')
view:destroy()

view,s=setup();local bad=marker();bad.x=0/0
assert(not view:update(s,{bad},3440,1440)and fixture.creates==0,'Invalid/unbounded geometry never constructs UI')
StaticConstructObject=nil
logs={};view=M.new(function(line)logs[#logs+1]=line end)
assert(not view:update(s,{marker()},3440,1440),'Non-game consumers retain desktop protocol fallback')
assert(#logs==1 and logs[1]:find('missing constructor binding',1,true)and logs[1]:find('StaticConstructObject=nil',1,true),'Missing UI APIs have an explicit diagnostic')

-- Actual producer + actual UMG renderer: every camera-frame rectangle reaches
-- the game tree, while the desktop protocol carries only a slow empty lease.
local Overlay=dofile('mod/Scripts/scan_overlay.lua')
Overlay.nativeBridge=nil
Overlay.projection={new=function(_,native)return native end}
Overlay.targets={markerCurrent=function(_,m)return m.actor:IsValid()end}
view,s=setup()
local integrated
Overlay.view={new=function(log)integrated=M.new(log);return integrated end}
local actor=object('NPC',fixture.meta)
actor.position={X=500,Y=500,Z=50}
function actor:K2_GetActorLocation()return self.position end
function fixture.pc:ProjectWorldLocationToScreen(p,out,relative)
    assert(relative==true);out.X=p.X/1000*3440;out.Y=p.Y/1000*1440;return p.Z>0
end
s.flight={p={x=0,y=0,z=0}}
s.worldExperiments={markers={{actor=actor,type=1,actorPosition={X=500,Y=500,Z=50},
    position={X=500,Y=500,Z=50},extent={X=50,Y=100,Z=30}}}}
local previousOpen=io.open
local publications={}
io.open=function(path,mode)
    if mode=='r'then return nil end
    assert(mode=='w'and path:match('^native%-scanner%-fixture/scan%-frame%-[ab]%.txt$'))
    local chunks={};local file={}
    function file:write(...)
        for i=1,select('#',...)do chunks[#chunks+1]=tostring(select(i,...))end
        return self
    end
    function file:close()publications[#publications+1]=table.concat(chunks);return true end
    return file
end
local ok,err=xpcall(function()
    local writer=Overlay.new('native-scanner-fixture/',{}, {})
    for i=0,143 do
        actor.position.X=500+100*math.sin(i)
        writer(i/144,s)
        local rootSlot=integrated.pool[1].slot
        local expected=(actor.position.X-50)/1000
        assert(math.abs(rootSlot.anchors.Minimum.X-expected)<1e-12,'Producer and game tree share this frame, without any file poll or WM_PAINT')
    end
    assert(#publications>=9 and #publications<=11,'Only a 10 Hz empty heartbeat remains in desktop transport')
    for _,packet in ipairs(publications)do assert(packet:match('^4 %d+ %d+ 0\n'),'Desktop frames cannot duplicate game-rendered markers')end
    s.inputPaused=true;writer(1,s);assert(fixture.host.visibility==1,'Opening PDA/F6 hides game-frame markers')
    s.inputPaused=false;writer(1.01,s);assert(fixture.host.visibility==3)
    writer(1.02,nil);assert(fixture.removes==1 and publications[#publications]:match('^4 %d+ %d+ 0\n'))
    -- UI unavailable is reversible: an independent new session keeps the
    -- original complete desktop packet, rather than silently losing scanning.
    fixture.failFactory=true
    local nextSession={pc=s.pc,world=s.world,flight=s.flight,worldExperiments=s.worldExperiments}
    writer(1.03,nextSession)
    assert(publications[#publications]:match('^4 %d+ %d+ 1\n'),'UI failure retains the validated desktop fallback')
end,debug.traceback)
io.open=previousOpen;assert(ok,err)
print('scan_view_test: passed (current-frame UMG, compact DPI-aware corners/font, exact sRGB colours, bounded cooked icons/GC brushes, pause, exit and stale ownership)')
