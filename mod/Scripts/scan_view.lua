-- Scanner brackets belong to the game frame, not to an independently queued
-- desktop window. Only newly constructed, privately owned UMG objects are
-- written here. Discovery, NPCs and native game UI are never modified.
local M={}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
M.assetLoader=here and dofile(here..'asset_loader.lua')
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function invoke(o,k,...)return o[k](o,...)end
local function call(o,k,...)local ok,v=pcall(invoke,o,k,...);if ok then return v end end
local function valid(o)return o~=nil and call(o,'IsValid')==true end
local function address(o)local id=valid(o)and call(o,'GetAddress');if finite(id)and id>0 and id%1==0 then return id end end
local function same(a,b)local id=address(a);return id~=nil and id==address(b)end
local function name(o)local v=call(o,'GetFName');return type(v)=='string'and v or call(v,'ToString')end
local function capture(o)
    local id,cls,n=address(o),call(o,'GetClass'),name(o)
    local classID=address(cls)
    if id and classID and type(n)=='string'then return {object=o,address=id,class=classID,name=n}end
end
local function current(identity)
    return identity and address(identity.object)==identity.address
        and address(call(identity.object,'GetClass'))==identity.class and name(identity.object)==identity.name
end
local function find(path)
    if type(StaticFindObject)~='function'then return end
    local ok,o=pcall(StaticFindObject,path);if ok and valid(o)then return o end
end
local function nativeClass(package,class,log)
    local dot,colon='/Script/'..package..'.'..class,'/Script/'..package..':'..class
    local function exact(o)
        local full=o and call(o,'GetFullName')
        full=type(full)=='string'and (full:match('^%S+%s+(.+)$')or full)
        return call(o,'IsAnyClass')==true and (full==dot or full==colon)
    end
    for _,separator in ipairs({'.',':'})do
        local path='/Script/'..package..separator..class
        local o=find(path)
        if exact(o)then return o end
    end
    -- On this UE4SS build exact native class lookup can fail while existing
    -- widgets expose a valid reflected UClass. A cold, single-object lookup
    -- and at most sixteen superclass reads resolve the SAME engine class;
    -- cooked subclasses themselves must never be constructed as primitives.
    if type(FindFirstOf)=='function'then
        local ok,instance=pcall(FindFirstOf,class)
        local candidate=ok and call(instance,'GetClass')
        local seen={}
        for _=1,16 do
            local id=address(candidate)
            if not id or seen[id]then break end
            seen[id]=true
            if exact(candidate)then
                if log then log('Scanner UMG class '..dot..' acquired via existing '..class..' GetClass chain.')end
                return candidate
            end
            candidate=call(candidate,'GetSuperStruct')
        end
    end
end
local function texture2D(asset)
    if not valid(asset)then return false,'loader returned no valid object'end
    local class=call(asset,'GetClass')
    local original=call(class,'GetFullName')or name(class)or 'unavailable'
    local seen={}
    for _=1,16 do
        local id=address(class)
        if not id or seen[id]then break end
        seen[id]=true
        local full=call(class,'GetFullName')
        full=type(full)=='string'and (full:match('^%S+%s+(.+)$')or full)
        if call(class,'IsAnyClass')==true and (full=='/Script/Engine.Texture2D'or full=='/Script/Engine:Texture2D')then
            return true,full
        end
        class=call(class,'GetSuperStruct')
    end
    -- UE4SS IsA(string) internally calls StaticFindObject for the UClass.
    -- That lookup can fail in this game even though LoadAsset returned a
    -- genuine Texture2D, just as it does for the existing UMG primitives.
    -- Validate this loaded object's actual reflected class chain instead.
    return false,'expected native Texture2D; returned_class='..tostring(original)
end
local function anchors(slot,x,y,w,h)
    slot:SetAnchors({Minimum={X=x,Y=y},Maximum={X=x+w,Y=y+h}})
end
-- Native texture paths come from W_BinocularsView's serialized faction map.
-- The matching cooked assets are also recorded in build/binocular-icon-map.json.
local textures={'bandits','corpus','duty','freedom','ipsf','loners','mercenaries','monolith',
    'noontide','scientists','spark','ward','ndichaz','x'}
local function linear(channel)
    local value=channel/255
    return value<=.04045 and value/12.92 or ((value+.055)/1.055)^2.4
end
local function color(r,g,b)return {R=linear(r),G=linear(g),B=linear(b),A=1}end
local colors={anomaly=color(255,211,60),artifact=color(55,224,255),enemy=color(239,70,78),
    friendly=color(80,220,115),neutral=color(232,229,207),unknown=color(170,170,165)}
local function tint(marker)
    local key='unknown'
    if marker.type==3 then key='anomaly' elseif marker.type==4 then key='artifact'
    elseif marker.relation==0 or marker.relation==1 then key='enemy'
    elseif marker.relation==3 or marker.relation==4 then key='friendly'
    elseif marker.relation==2 then key='neutral'end
    -- GDI scanColor is sRGB. UMG accepts linear colour: passing byte/255
    -- directly brightens the green/blue channels into a pale pink marker.
    return colors[key],key
end
local function clamp(value,low,high)return math.max(low,math.min(high,value))end
local function safeMarker(m)
    return type(m)=='table'and finite(m.x)and finite(m.y)and finite(m.width)and finite(m.height)
        and finite(m.distance)and m.distance>=0 and m.distance<=1e8
        and m.width>0 and m.height>0 and m.width<=1 and m.height<=1
        and m.x-m.width/2>=-1e-5 and m.x+m.width/2<=1.00001
        and m.y-m.height/2>=-1e-5 and m.y+m.height/2<=1.00001
        and finite(m.type)and m.type%1==0 and m.type>=1 and m.type<=4
end
function M.new(log)
    -- UE4SS installs FText as userdata with an __call metamethod. A function
    -- type check silently disables the renderer in the real game, even though
    -- function-only offline adapters pass. Probe its actual invocation below,
    -- inside the first game-thread build; do not inspect a protected metatable.
    local self={enabled=StaticConstructObject~=nil and FText~=nil,pool={},shown=false}
    local bindings='StaticConstructObject='..type(StaticConstructObject)..'; FText='..type(FText)
    if log then
        if self.enabled then log('Scanner renderer bindings: '..bindings..'; game-thread constructor probe pending.')
        else log('Game-frame scanner unavailable; desktop fallback: missing constructor binding ('..bindings..').')end
    end
    local textReady=false
    local session,pcIdentity,worldIdentity,hostIdentity,treeIdentity,rootIdentity
    local host,tree,root,classes,failed,lastFailure,attached
    local iconCache,assetClient,frame={},{},0
    local layout,viewport,nextScaleProbe,pixelStyleLogged=nil,nil,0,false
    local function privateTree()
        return current(hostIdentity)and current(treeIdentity)and current(rootIdentity)
            and pcIdentity and address(call(host,'GetOwningPlayer'))==pcIdentity.address
            and same(read(host,'WidgetTree'),tree)
            and same(read(tree,'RootWidget'),root)and same(call(root,'GetOuter'),tree)
    end
    local function owns()
        return current(pcIdentity)and current(worldIdentity)and same(call(pcIdentity.object,'GetWorld'),worldIdentity.object)
            and same(call(host,'GetOwningPlayer'),pcIdentity.object)and privateTree()
            and (not attached or call(host,'IsInViewport')==true)
    end
    local function abandon()
        self.pool={};self.shown=false;host,tree,root,classes=nil,nil,nil,nil;attached=false
        hostIdentity,treeIdentity,rootIdentity,pcIdentity,worldIdentity=nil,nil,nil,nil,nil
        self.assetHolders={};layout,viewport=nil,nil
    end
    local function destroy()
        -- A world/controller change revokes rendering, but a proven private
        -- tree still belongs to this adapter and must leave the viewport.
        -- Recycled widget wrappers or replaced trees are never touched.
        if host and privateTree()then
            local hidden=pcall(invoke,host,'SetVisibility',1)
            local detached=privateTree()and pcall(invoke,host,'RemoveFromParent')
            if log and (not hidden or not detached or call(host,'IsInViewport')==true)then
                log('Scanner private viewport cleanup incomplete; owned host was hidden where possible.')
            end
            if not hidden and call(host,'IsInViewport')==true then
                -- Keep ownership references for another cleanup attempt. Do
                -- not silently abandon a still-visible privately owned host.
                self.cleanupPending=true;return false
            end
        end
        self.cleanupPending=false;abandon();return true
    end
    local function fail(reason)
        destroy();failed=true
        local message=tostring(reason)
        if log and message~=lastFailure then log('Game-frame scanner unavailable; desktop fallback: '..message);lastFailure=message end
    end
    local function make(kind,parent)
        local widget=StaticConstructObject(assert(classes[kind],'Missing UMG '..kind),tree)
        assert(valid(widget)and same(call(widget,'GetOuter'),tree),'Unowned scanner '..kind)
        assert(same(call(widget,'GetClass'),classes[kind]),'Unexpected scanner widget class')
        if parent then assert(valid(parent:AddChild(widget)),'Scanner parenting failed')end
        widget:SetVisibility(3) -- HitTestInvisible, including descendants.
        return widget
    end
    local function build(s)
        pcIdentity,worldIdentity=capture(s.pc),capture(s.world)
        assert(pcIdentity and worldIdentity and same(call(s.pc,'GetWorld'),s.world),'Scanner PC/world unavailable')
        classes={}
        for _,kind in ipairs({'CanvasPanel','Border','TextBlock','Image'})do
            classes[kind]=assert(nativeClass('UMG',kind,log),'Exact UMG '..kind..' class unavailable')
        end
        local base=assert(nativeClass('Stalker2','PageViewBase',log),'Exact blank native page class unavailable')
        local library=find('/Script/UMG.Default__WidgetBlueprintLibrary')or find('/Script/UMG:Default__WidgetBlueprintLibrary')
        assert(valid(library)and name(library)=='Default__WidgetBlueprintLibrary','Widget factory unavailable')
        host=library:Create(s.pc,base,s.pc)
        assert(valid(host)and same(call(host,'GetClass'),base)and same(call(host,'GetOwningPlayer'),s.pc),'Scanner factory returned wrong owner/class')
        tree=read(host,'WidgetTree');assert(valid(tree)and not valid(read(tree,'RootWidget')),'Scanner host must have an empty private tree')
        host.bShouldBindWidgetInputs=false;host.bShoudIgnoreInputOnPouse=false
        root=make('CanvasPanel');tree.RootWidget=root
        hostIdentity,treeIdentity,rootIdentity=capture(host),capture(tree),capture(root)
        assert(owns(),'Scanner tree ownership mismatch')
        host:SetVisibility(3);host:AddToViewport(50)
        assert(call(host,'IsInViewport')==true,'Scanner viewport attachment failed')
        attached=true;self.shown=true
        layout=find('/Script/UMG.Default__WidgetLayoutLibrary')or find('/Script/UMG:Default__WidgetLayoutLibrary')
        if log then log('Scanner renderer: game-frame UMG; desktop scanner disabled.')end
    end
    local function markerSlot()
        local panel=make('CanvasPanel',root)
        local slot=read(panel,'Slot');assert(valid(slot),'Scanner canvas slot unavailable')
        slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
        local item={panel=panel,slot=slot,lines={},corners={},visible=true}
        -- Each corner matches the old GDI polyline: horizontal, short bevel,
        -- vertical. Only quantized pixel size or DPI changes rebuild offsets;
        -- camera movement still changes one parent anchor per target/frame.
        for _,x in ipairs({0,1})do for _,y in ipairs({0,1})do
            local corner={x=x,y=y,arms={}}
            for segment=1,3 do
                local arm=make('Border',panel);local armSlot=read(arm,'Slot')
                anchors(armSlot,x,y,0,0)
                arm:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
                if segment==2 then
                    arm:SetRenderTransformPivot({X=0,Y=.5})
                    arm:SetRenderTransformAngle((x==0 and (y==0 and 135 or -135)or (y==0 and 45 or -45)))
                end
                item.lines[#item.lines+1]=arm
                corner.arms[segment]=armSlot
            end
            item.corners[#item.corners+1]=corner
        end end
        item.icon=make('Image',panel);item.iconSlot=read(item.icon,'Slot')
        anchors(item.iconSlot,.5,1,0,0)
        item.icon:SetVisibility(1)
        item.label=make('TextBlock',panel);item.labelSlot=read(item.label,'Slot')
        anchors(item.labelSlot,.5,1,0,0)
        item.label:SetJustification(1)
        self.pool[#self.pool+1]=item
        return item
    end
    local function factionOf(marker)
        local faction=marker.faction
        return marker.type<=2 and finite(faction)and faction%1==0 and textures[faction]and faction or 0
    end
    local function prepareIcon(markers)
        -- At most ONE demanded faction load per frame; never load all fourteen
        -- assets in a batch or turn a registry miss into a permanent false.
        for _,marker in ipairs(markers)do
            local faction=factionOf(marker)
            if faction>0 then
                local state=iconCache[faction]
                if not state then state={attempts=0,nextFrame=0};iconCache[faction]=state end
                if not state.texture and state.attempts<3 and frame>=state.nextFrame then
                    state.attempts=state.attempts+1;state.nextFrame=frame+300
                    local asset='T_binocular_faction_icon_'..textures[faction]
                    local path='/Game/GameLite/FPS_Game/UIRemaster/UITextures/Binoculars/'..asset..'.'..asset
                    local ok,result,reason=pcall(function()return assetClient:load(path)end)
                    local isTexture,classDetail=texture2D(ok and result or nil)
                    if ok and isTexture then
                        -- A Lua UObject wrapper is not an engine GC reference.
                        -- This owned hidden Image keeps the brush resource live
                        -- even while the visible slots display other factions.
                        local holder=make('Image',root);holder:SetVisibility(1)
                        holder:SetBrushFromTexture(result,false)
                        self.assetHolders[faction]=holder;state.texture=result
                        if log then log('Scanner faction icon ready: '..textures[faction]..'. class='..classDetail)end
                    elseif state.attempts==3 and log then
                        local detail=not ok and tostring(result)or reason or classDetail
                        log('Scanner faction icon unavailable: '..textures[faction]..' ('..tostring(detail)..'); distance label retained.')
                    end
                    return
                end
            end
        end
    end
    local function viewportStyle(width,height)
        if not viewport or viewport.width~=width or viewport.height~=height or frame>=nextScaleProbe then
            nextScaleProbe=frame+60
            local measured=call(layout,'GetViewportScale',pcIdentity.object)
            local measuredOK=finite(measured)and measured>=.25 and measured<=8
            local scale=measuredOK and measured or viewport and viewport.scale or 1
            viewport={width=width,height=height,scale=scale,thickness=clamp(math.floor(height/550),2,3),
                labelHeight=clamp(math.floor(height/75),12,20),iconSize=clamp(math.floor(height/45),16,32)}
            if log and not pixelStyleLogged then
                pixelStyleLogged=true
                log(string.format('Scanner pixel style: viewport=%dx%d scale=%.3f source=%s label=%dpx stroke=%dpx icon=%dpx corners=3..14px.',
                    width,height,scale,measuredOK and 'UMG' or 'fallback',viewport.labelHeight,viewport.thickness,viewport.iconSize))
            end
        end
        return viewport
    end
    local function cornerStyle(item,m,v)
        local half=math.min(math.max(2,math.floor(m.width*v.width/2+.5)),math.max(2,math.floor(m.height*v.height/2+.5)))
        local corner=math.min(half,clamp(math.floor(half/5),3,14))
        local rounding=math.min(4,math.floor(corner/2))
        local key=corner..':'..v.thickness..':'..v.scale
        if key==item.cornerStyle then return end
        item.cornerStyle=key
        local arm,bevel,thickness=(corner-rounding)/v.scale,rounding/v.scale,v.thickness/v.scale
        for _,c in ipairs(item.corners)do
            c.arms[1]:SetOffsets({Left=c.x==1 and -corner/v.scale or bevel,Top=-thickness/2,Right=arm,Bottom=thickness})
            c.arms[2]:SetOffsets({Left=c.x==1 and -bevel or bevel,Top=-thickness/2,Right=bevel*math.sqrt(2),Bottom=thickness})
            c.arms[3]:SetOffsets({Left=-thickness/2,Top=c.y==1 and -corner/v.scale or bevel,Right=thickness,Bottom=arm})
        end
    end
    local function labelStyle(item,v)
        local key=v.labelHeight..':'..v.scale
        if key==item.fontStyle then return end
        item.fontStyle=key
        local font=assert(read(item.label,'Font'),'Scanner label font unavailable')
        font.Size=clamp(math.floor(v.labelHeight*.75/v.scale+.5),1,64)
        if FName~=nil then pcall(function()font.TypefaceFontName=FName('Bold')end)end
        item.label:SetFont(font)
        -- Slate Size is points, not physical pixels. One bounded measurement
        -- calibrates the owned text; at most one correction per style change.
        call(item.label,'ForceLayoutPrepass')
        local desired=call(item.label,'GetDesiredSize');local h=read(desired,'Y')
        if finite(h)and h>0 and h<256 then
            local size=clamp(math.floor(font.Size*v.labelHeight/(h*v.scale)+.5),1,64)
            if size~=font.Size then font.Size=size;item.label:SetFont(font)end
        end
    end
    local function contentOffsets(item,m,v)
        local bottom=(m.y+m.height/2)*v.height
        local iconTop=math.min(v.height-v.iconSize,bottom+4)-bottom
        local iconKey=v.scale..':'..v.iconSize..':'..iconTop
        if iconKey~=item.iconStyle then
            item.iconSlot:SetOffsets({Left=-v.iconSize/2/v.scale,Top=iconTop/v.scale,Right=v.iconSize/v.scale,Bottom=v.iconSize/v.scale})
            item.iconStyle=iconKey
        end
        local x=m.x*v.width;local left=math.max(0,x-100)-x;local width=math.min(v.width,x+100)-math.max(0,x-100)
        local top=math.min(v.height-v.labelHeight-2,bottom+3+(item.hasIcon and v.iconSize+4 or 0))-bottom
        local key=v.scale..':'..left..':'..top..':'..width..':'..v.labelHeight
        if key~=item.labelStyle then
            item.labelSlot:SetOffsets({Left=left/v.scale,Top=top/v.scale,Right=width/v.scale,Bottom=(v.labelHeight+2)/v.scale})
            item.labelStyle=key
        end
    end
    local function updateItem(item,m,v)
        anchors(item.slot,m.x-m.width/2,m.y-m.height/2,m.width,m.height)
        cornerStyle(item,m,v)
        if not item.visible then item.panel:SetVisibility(3);item.visible=true end
        local color,key=tint(m)
        if key~=item.tint then
            for _,arm in ipairs(item.lines)do arm:SetBrushColor(color)end
            item.label:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0})
            item.icon:SetColorAndOpacity(color);item.tint=key
        end
        local faction=factionOf(m)
        local icon=faction>0 and iconCache[faction]and iconCache[faction].texture or nil
        if faction~=item.faction or icon~=item.texture then
            if icon then item.icon:SetBrushFromTexture(icon,false)end
            item.icon:SetVisibility(icon and 3 or 1);item.hasIcon=icon~=nil
            item.faction,item.texture=faction,icon
        end
        local label=string.format('%.0f m',m.distance)
        if m.type==3 then label='ANOMALY  '..label elseif m.type==4 then label='ARTIFACT  '..label end
        if label~=item.text then item.label:SetText(FText(label));item.text=label end
        labelStyle(item,v);contentOffsets(item,m,v)
    end
    function self:hide()
        if not host then return end
        if not owns()then destroy();failed=true;return end
        if self.shown then
            local ok,reason=pcall(invoke,host,'SetVisibility',1)
            if not ok then fail(reason);return end
            self.shown=false
        end
    end
    function self:update(s,markers,width,height)
        if not self.enabled then return false end
        if self.cleanupPending then
            if not destroy()then return false end
            session=nil;failed=false
        end
        if s~=session then
            if not destroy()then return false end
            session=s;failed=false;iconCache={};self.assetHolders={};pixelStyleLogged=false
            assetClient=M.assetLoader and M.assetLoader.new()or {}
        end
        if not s then return false end
        frame=frame+1
        if host and not owns()then destroy();failed=true;return false end
        if failed then return false end
        local hidden=s.inputPaused or s.radio and s.radio.lost or not finite(width)or not finite(height)or width<320 or height<200
        if hidden or #markers==0 then self:hide();return host~=nil end
        local selected={}
        for _,marker in ipairs(markers)do
            if safeMarker(marker)then selected[#selected+1]=marker;if #selected==16 then break end end
        end
        if #selected==0 then self:hide();return host~=nil end
        local ok,reason=pcall(function()
            if not textReady then
                assert(FText('')~=nil,'FText constructor returned no text')
                textReady=true
            end
            if not host then build(s)end
            local style=viewportStyle(width,height)
            prepareIcon(selected)
            -- Lazy bounded allocation avoids a sixteen-target construction
            -- spike when entering FPV. Reuse all slots until this session ends.
            local missing=math.min(2,#selected-#self.pool)
            for _=1,missing do markerSlot()end
            for i,item in ipairs(self.pool)do
                if selected[i]then updateItem(item,selected[i],style)
                elseif item.visible then item.panel:SetVisibility(1);item.visible=false end
            end
            if not self.shown then host:SetVisibility(3);self.shown=true end
        end)
        if not ok then fail(reason);return false end
        return true
    end
    function self:destroy()
        if destroy()then session=nil;failed=false else failed=true end
    end
    return self
end
return M
