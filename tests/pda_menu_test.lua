-- Adapter contract, not proof of layout or game compatibility.
local M=dofile('mod/Scripts/pda_menu.lua')
local serial,created,callback=0,0
local world,pc,view,manager,hint,subsystem
local objects,classes,logs,commands,injections={}, {}, {}, {}, {}
local failFont=false
local ownershipReads,globalSearches=0,0
local nativeSeed,blueprintSeed=true,false
local missingEnhanced=false
local missingUMG,existingWidgets={},{}
local snapshot
local pointer={X=0,Y=0}
local methods={}
function methods:IsValid()return not self.dead end
function methods:GetAddress()return self.id end
function methods:IsAnyClass()return self.className~=nil end
function methods:GetFullName()return self.fullNameOverride or (self.className and 'Class '..self.className or self.kind)end
function methods:GetClass()return self.class end
function methods:GetWorld()return self.world or world end
function methods:GetOwningPlayer()ownershipReads=ownershipReads+1;if not self.ownerPending then return pc end end
function methods:GetOwningLocalPlayer()return nil end
function methods:GetVisibility()return self.visibility or 0 end
function methods:SetVisibility(v)self.visibility=v end
function methods:GetRenderOpacity()return 1 end
function methods:GetParent()return self.parent end
function methods:GetOuter()return self.outer end
function methods:IsInViewport()return self.viewport or false end
function methods:RemoveFromParent()
    if self.parent and self.parent.children then
        for i,v in ipairs(self.parent.children)do if v==self then table.remove(self.parent.children,i);break end end
    end
    self.parent=nil;self.removed=true
end
function methods:SetText(v)self.text=v;self.textWrites=(self.textWrites or 0)+1 end
function methods:GetText()return self.text or ""end
function methods:SetHintText(v)self.hint=v end
function methods:HasKeyboardFocus()return self.keyboardFocus or false end
function methods:GetIsEnabled()return self.enabled~=false end
function methods:SetAutoWrapText(v)self.wrap=v end
function methods:SetFont(v)assert(not failFont,'Injected unsupported font');self.Font=v end
function methods:ForceLayoutPrepass()self.prepasses=(self.prepasses or 0)+1 end
function methods:GetDesiredSize()
    self.desiredReads=(self.desiredReads or 0)+1
    if self.desiredUnavailable then return {X=0,Y=0}end
    if self.desiredSize then return self.desiredSize end
    local size=self.Font.Size
    return {X=#(self.text or '')*size*.82,Y=size*1.6}
end
function methods:SetClipping(value)self.clipping=value end
function methods:SetColorAndOpacity(v)self.color=v;self.ColorAndOpacity=v end
function methods:SetBackgroundColor(v)self.color=v end
function methods:SetBrushColor(v)self.color=v end
function methods:SetPadding(v)self.padding=v end
function methods:SetHorizontalAlignment(v)self.halign=v end
function methods:SetVerticalAlignment(v)self.valign=v end
function methods:SetAnchors(v)self.anchors=v end
function methods:SetOffsets(v)self.offsets=v;self.offsetWrites=(self.offsetWrites or 0)+1 end
function methods:SetZOrder(v)self.z=v end
function methods:IsPressed()return self.pressed or false end
function methods:IsHovered()return self.hovered or false end
function methods:HasMouseCapture()return self.captured or false end
function methods:GetCachedGeometry()return {}end -- installed loader loses opaque native members
function methods:GetLocalSize()error('Opaque FGeometry must not cross Lua')end
function methods:AbsoluteToLocal()error('Opaque FGeometry must not cross Lua')end
function methods:GetMousePositionOnPlatform()error('Native query supplies a coherent pointer/geometry snapshot')end
function methods:SetRenderTransformPivot(v)self.pivot=v end
function methods:SetRenderTransformAngle(v)self.angle=v end
function methods:SetHeightOverride(v)self.heightOverride=v end
function methods:SetOrientation(v)self.orientation=v end
function methods:SetConsumeMouseWheel(v)self.consumeWheel=v end
function methods:SetScrollOffset(v)self.scrollOffset=v;self.scrollResets=(self.scrollResets or 0)+1 end
function methods:ScrollWidgetIntoView(widget,animate,destination,padding)
 assert(widget.parent==self.children[1]and not animate and destination==0 and padding==0,'Only owned list descendants enter view')
 self.scrolledWidget=widget;self.intoViewCalls=(self.intoViewCalls or 0)+1
end
function methods:SetMinValue(v)self.minValue=v end
function methods:SetMaxValue(v)self.maxValue=v end
function methods:SetStepSize(v)self.stepSize=v end
function methods:SetValue(v)self.value=v;self.valueWrites=(self.valueWrites or 0)+1 end
function methods:GetValue()return self.value or 0 end
function methods:SetSliderBarColor(v)self.barColor=v end
function methods:SetSliderHandleColor(v)self.handleColor=v end
function methods:GetActiveWidgetIndex()return self.index or 0 end
function methods:GetActiveWidget()return self.children and self.children[(self.index or 0)+1]end
function methods:GetChildrenCount()return #(self.children or {})end
function methods:GetChildAt(index)return self.children and self.children[index+1]end
function methods:SetActiveWidgetIndex(index)
    assert(self.children[index+1],'Selected page must exist')
    self.index=index;self.transitions=self.transitions or {};self.transitions[#self.transitions+1]=index
end
function methods:SetIsEnabled(value)self.enabled=value end
function methods:GetAllChildren()return self.children or {}end
function methods:GetColorAndOpacity()error('Shipping CommonTextObj does not expose this getter')end
function methods:GetFName()return {ToString=function()return self.kind:match('([^.:]+)$')or self.kind end}end
function methods:WasInputKeyJustPressed(k)
    if self.unavailablePress then error('JustPressed unavailable in UI focus')end
    local result=self.keys and self.keys[k.KeyName];if self.keys then self.keys[k.KeyName]=nil end;return result or false
end
function methods:IsInputKeyDown(k)
    if self.down~=nil then return self.down[k.KeyName]==true end
end
local function obj(kind)
    serial=serial+1;local o=setmetatable({id=serial,kind=kind,Font={Size=12}}, {__index=methods});objects[#objects+1]=o;return o
end
function methods:AddChild(child)
    child.parent=self;child.Slot=obj(self.kind=='Tabs'and 'HorizontalBoxSlot'or 'Slot')
    self.children=self.children or {};self.children[#self.children+1]=child;return child.Slot
end
methods.AddChildToOverlay=methods.AddChild
local function nativeTabFixture()
    local tab=obj('NativeTab');tab.class=obj('PDAButtonClass');tab.class.className='/Game/UI/W_TopBookButton.W_TopBookButton_C'
    tab.Button=obj('NativeButton');tab.ButtonText=obj('TextWidget');tab.ButtonText.CommonTextObj=obj('CommonTextBlock')
    tab.ButtonText.CommonTextObj.ColorAndOpacity={SpecifiedColor={R=.6,G=.6,B=.6,A=1},ColorUseRule=0}
    tab.SelectLine=obj('Image');tab.SelectLine.visibility=1;tab.Notify=obj('Image');tab.ButtonId='Map'
    tab.Slot=obj('HorizontalBoxSlot');tab.Slot.Padding={Left=4,Top=0,Right=4,Bottom=0}
    tab.Slot.class=obj('HorizontalBoxSlot');tab.Slot.class.className='/Script/UMG.HorizontalBoxSlot'
    tab.Slot.Size={SizeRule=1,Value=1};tab.Slot.HorizontalAlignment=0;tab.Slot.VerticalAlignment=0
    return tab
end
function methods:Create(context,class,owner)
    if class.className=='/Script/Stalker2.PageViewBase'then
        assert(context==pc and owner==pc,'Native page requires local player ownership')
        created=created+1;local page=obj('OwnedPage');page.class=class;page.WidgetTree=obj('OwnedTree');return page
    end
    assert(context==pc and owner==pc and class.className:find('W_TopBookButton',1,true),'Create must initialize a cooked native tab for local player')
    created=created+1;local tab=nativeTabFixture();tab.class=class;return tab
end
function methods:SetSize(value)self.Size=value end
function methods:InitClickTransition(id)self.transition=id end
function methods:ClickMenuButton(id)
    for i,tab in ipairs(self.SlotContainer.children)do
        if tab.ButtonId==id then
            view.Switcher:SetActiveWidgetIndex(i-1)
            self.directClick=id
            for j,sibling in ipairs(self.SlotContainer.children)do sibling.SelectLine:SetVisibility(i==j and 0 or 2)end
            return
        end
    end
    error('Unknown native tab id')
end
local function nativeMove(panel,direction)
    panel.moveCalls=(panel.moveCalls or 0)+1
    panel.moveDirection=direction
    local tabs=panel.SlotContainer.children
    local current=view.Switcher:GetActiveWidgetIndex()
    for _=1,#tabs do
        current=current+direction
        if current<0 or current>=#tabs then
            if panel.bShouldLoopMove==false then return end
            current=current%#tabs
        end
        local tab=tabs[current+1]
        if tab:GetVisibility()~=1 and tab:GetVisibility()~=2 then panel:ClickMenuButton(tab.ButtonId);return end
    end
end
function methods:MoveSelectSlotToPreviousSlot()nativeMove(self,-1)end
function methods:MoveSelectSlotToNextSlot()nativeMove(self,1)end
function methods:GetLocalPlayerSubSystemFromPlayerController(player,class)assert(player==pc);return subsystem end
function methods:InjectInputForAction(action,value,modifiers,triggers)
    assert(action==hint.OpenPDA.MimicButtonElement.InputAction and #modifiers==0 and #triggers==1)
    injections[#injections+1]=value.Value.X
end
FText=function(v)return v end;FName=function(v)return v end
StaticFindObject=function(path)
    if missingEnhanced and path=='/Script/EnhancedInput.EnhancedInputLocalPlayerSubsystem'then return nil end
    if missingUMG[path]then return nil end
    classes[path]=classes[path]or obj(path)
    if path:match('^/Script/UMG%.')then classes[path].className=path end
    if path=='/Script/Stalker2.PageViewBase'then classes[path].className=path end
    return classes[path]
end
StaticConstructObject=function(class,outer)
    created=created+1;assert(outer.kind=='OwnedTree','Content must use its own initialized page tree')
    local widget=obj(class.kind);widget.outer=outer;return widget
end
NotifyOnNewObject=function(path,fn)
    assert(path=='/Script/Stalker2.PDAView'or path=='/Game/GameLite/FPS_Game/UIRemaster/PDA/W_PDABookView.W_PDABookView_C');callback=fn
end
FindAllOf=function(name)
    globalSearches=globalSearches+1
    if name=='PDAView'then return nativeSeed and {view}or {}end
    if name=='W_PDABookView_C'then return blueprintSeed and {view}or {}end
    if name=='UIBaseManager'then return {manager}end
    if name=='HudHintsPanel'then return {hint}end
    return existingWidgets[name]or {}
end
local function setup(navigationKeys)
    world=obj('World');pc=obj('PC');view=obj('PDA');view.WidgetName=11;view.viewport=true;view.Container=obj('Overlay');view.Switcher=obj('Switcher');view.WidgetTree=obj('Tree')
    manager=obj('Manager');manager.OpenViews={view};hint=obj('Hint')
    view.NavigationPanel=obj('Navigation');view.NavigationPanel.SlotContainer=obj('Tabs');view.NavigationPanel.PDASectionSwitch=0
    local tab=nativeTabFixture();view.NavigationPanel.SlotContainer.children={tab}
    view.Switcher.children={obj('NativePage')}
    hint.OpenPDA=obj('OpenPDA');hint.OpenPDA.MimicButtonElement=obj('Mimic')
    hint.OpenPDA.MimicButtonElement.InputAction=obj('Action');hint.OpenPDA.MimicButtonElement.InputTrigger=obj('Trigger')
    subsystem=obj('Subsystem');created=0
    snapshot={cfg={flight_mode='acro'}}
    return M.new{root='',snapshot=function()return snapshot end,
        execute=function(command)commands[#commands+1]=command;return true end,log=function(m)logs[#logs+1]=m end,
        geometry={query=function(widget)
            widget.geometryReads=(widget.geometryReads or 0)+1
            if widget.geometryUnavailable then return nil,'native_geometry_unavailable'end
            local g=widget.geometry or {width=640,height=40,x=0,y=0,scale=1}
            return {width=g.width,height=g.height,x=(pointer.X-g.x)/(g.scale or 1),y=(pointer.Y-g.y)/(g.scale or 1)}
        end},
        tool=function()return true end,navigationKeys=navigationKeys}
end
local menu=setup()
assert(menu:update(1,pc)==true and created>0)
local initial=created
assert(menu.pageHost.widget.parent==view.Switcher and menu.pageHost.tree.RootWidget==menu.root,
 'Content must be an initialized native page in the actual Switcher')
assert(menu.body.Slot.anchors.Minimum.Y==0 and menu.body.Slot.anchors.Maximum.Y==1,
 'Content uses native page bounds instead of guessed viewport coordinates')
assert(menu.tab.widget.parent==view.NavigationPanel.SlotContainer and #view.NavigationPanel.SlotContainer.children==2,
 'ZoneFPV must join the native top row instead of using canvas coordinates')
assert(menu.buttons[1].widget==menu.tab.button and menu.tab.widget.ButtonId=='ZoneFPV')
local nativeSelectedColor={SpecifiedColor={R=1,G=.62,B=.18,A=1},ColorUseRule=0}
menu.tab.widget.ButtonText.CommonTextObj.color=nativeSelectedColor
menu.tab.widget.SelectLine:SetVisibility(0);view.Switcher:SetActiveWidgetIndex(menu.pageHost.index);menu:update(1.01,pc)
assert(menu.active and view.Switcher:GetVisibility()==0,'Native Q/E selection must show its actual page without hiding Switcher')
assert(menu.tab.widget.ButtonText.CommonTextObj.color==nativeSelectedColor,'Native Q/E highlight must retain the game style')
menu.tab.widget.SelectLine:SetVisibility(2);view.Switcher:SetActiveWidgetIndex(0);menu:update(1.02,pc)
assert(not menu.active and view.Switcher:GetVisibility()==0,'Native Q/E deselection must use the game page')
menu.tab.button.pressed=true;menu.tab.button.hovered=true;menu:update(1.03,pc)
assert(not menu.active,'Top-row tab must activate on release')
menu.tab.button.pressed=false;menu:update(1.04,pc)
assert(menu.active and view.NavigationPanel.directClick=='ZoneFPV'and not view.NavigationPanel.transition,
 'Mouse release must select the page synchronously without the traversal timer')
menu.tab.widget.SelectLine:SetVisibility(2)
for i=1,100 do menu:update(1.04+i*.05,pc)end
assert(menu.active,'Underline animation must not close a selected page after several seconds')
assert(menu:requestOpen(1,pc)and menu.active and view.Switcher:GetVisibility()==0)
assert(view.NavigationPanel.directClick=='ZoneFPV','F6/direct open uses native synchronous selection')
for i=1,100 do assert(menu:update(1+i*.02,pc)==true)end
assert(created==initial,'Opening/refreshing must reuse widgets')
pc.keys={Right=true};menu:update(4,pc)
assert(commands[#commands]=='FPVMode 3d','Native keyboard controls dispatch shared handler')
view.NavigationPanel.SlotContainer.children[1].Button.pressed=true
view.NavigationPanel:ClickMenuButton('Map');menu:update(4.05,pc)
assert(not menu.active,'Clicking the same native tab must leave ZoneFPV')
view.NavigationPanel.SlotContainer.children[1].Button.pressed=false;menu:requestOpen(4.06,pc)
view.Switcher:SetActiveWidgetIndex(0);menu:update(4.1,pc)
assert(not menu.active and view.Switcher:GetVisibility()==0,'Original page selection stays native')
menu:requestOpen(4.2,pc);manager.OpenViews={};view.viewport=false;menu:update(4.31,pc)
assert(not menu.active and view.Switcher:GetVisibility()==0,'Closing actual PDA must keep the native switcher intact')
assert(menu:requestOpen(5,pc)and injections[#injections]==1,'Opener uses game input action, not a guessed keyboard binding')
menu:update(5.2,pc);assert(injections[#injections]==0,'Injected input must be released')
manager.OpenViews={view};view.viewport=true;menu:update(5.31,pc)
assert(menu.active,'Pending request selects ZoneFPV after native PDA appears')
local ownedTab=menu.tab.widget
local ownedPage=menu.pageHost.widget
menu:destroy();assert(menu.root==nil and ownedTab.removed and ownedPage.removed and #view.NavigationPanel.SlotContainer.children==1 and #view.Switcher.children==1,
 'Detach must remove only the ZoneFPV tab and page')
menu=setup();failFont=true;assert(menu:update(10,pc)==true,'Actual PDA pauses flight even if panel construction fails')
local failedCount=created
for i=1,50 do assert(menu:update(10+i*.05,pc)==true)end
assert(created==failedCount,'Failed builds must not leak widgets in a retry loop')
failFont=false;menu:destroy()
menu=setup();menu:update(20,pc);menu:requestOpen(20,pc)
menu.title.widget.SetText=function()error('Injected update error')end
menu.title.lastText=nil;assert(menu:update(21,pc)==true);local failedUpdateCount=created
for i=1,50 do assert(menu:update(21+i*.05,pc)==true)end
assert(created==failedUpdateCount,'Failed updates must not recreate a bad widget tree every tick')
assert(view.Switcher:GetVisibility()==0 and view.Switcher:GetActiveWidgetIndex()==0,'Error cleanup must restore original PDA page')
menu:destroy()
nativeSeed=false;blueprintSeed=false
menu=setup();manager.OpenViews={};menu:update(80,pc)
assert(created==0,'Empty seed must not manufacture a PDA')
manager.OpenViews={view};assert(menu:update(81,pc)and created>0,'Already-open manager PDA must become a candidate even with empty native/BP seeds and no observer callback')
menu:destroy()
blueprintSeed=true;menu=setup();manager.OpenViews={}
assert(menu:update(82,pc)and created>0,'Exact cooked Blueprint class is a supported seed')
menu:destroy()
nativeSeed=true;blueprintSeed=false;menu=setup()
snapshot.resources={ram=953,commit=7853,known=true,used=364035,maximum=720896};snapshot.resourceLevel=0
menu:update(83,pc);menu:requestOpen(83,pc)
assert(menu.resources.lastText:find('Память: нормально',1,true),'Low physical RAM alone must not display critical pressure')
snapshot.resourceLevel=nil;menu:update(84,pc)
assert(menu.resources.lastText:find('Память: нормально',1,true),'Compatibility footer also uses commit headroom')
menu:destroy()
menu=setup();view.viewport=false;manager.OpenViews={};missingEnhanced=true
local mimic=hint.OpenPDA.MimicButtonElement
mimic.OnMouseButtonPressed=function(self)self.injectHeld=true end
mimic.OnMouseButtonReleased=function(self)self.injectHeld=false end
menu:update(85,pc);assert(menu:requestOpen(85,pc)and mimic.injectHeld,'Missing subsystem must use the existing native PDA hint handlers')
menu:update(85.2,pc);assert(mimic.injectHeld==false,'Native hint press must always be released')
menu:destroy();missingEnhanced=false
nativeSeed=false;blueprintSeed=false;menu=setup();manager.OpenViews={}
menu:update(86,pc);local staleManager=manager
manager=obj('ReplacementManager');manager.OpenViews={view}
assert(not menu:update(87,pc)and created==0,'Cached startup manager is intentionally stale in this regression')
assert(menu:update(91.1,pc)and created>0,'Five-second unbound reseed must recover a loaded-later PDA even with observer registration success and no callback')
local boundSearches=globalSearches
menu:update(97,pc);assert(globalSearches==boundSearches,'Bound PDA must stop the periodic global seed')
menu:destroy();nativeSeed=true
menu=setup()
snapshot.session={flight={v={x=1,y=0,z=0}}};snapshot.resourceLevel=1
snapshot.telemetry={speed=73.4}
snapshot.resources={ram=8192,commit=16384,known=true,used=100,maximum=1000}
menu:update(30,pc);menu:requestOpen(30,pc)
assert(menu.telemetry.lastText:find('73 km/h',1,true),'PDA must use the same scaled speed as OSD')
assert(menu.resources.lastText:find('Память: ограниченный запас',1,true),'Advisory level must describe memory headroom, not a streaming reduction')
snapshot.resourceLevel=0;menu:update(31,pc)
assert(menu.resources.lastText:find('Память: нормально',1,true),'Normal resource status returns after restriction ends')
menu:destroy()
menu=setup();manager.OpenViews={};view.GetWorld=function()error('Generic UObject virtual world is unavailable')end
hint.GetWorld=view.GetWorld;view.viewport=true
assert(menu:update(40,pc)and created>0,'Reflected owner/viewport must not depend on generic GetWorld or manager OpenViews')
menu:destroy()
menu=setup();view.ownerPending=true;view.viewport=false;manager.OpenViews={}
for i=1,100 do assert(not menu:update(50+i*.02,pc))end
assert(created==0,'Wait for actual local-player ownership before constructing UI')
view.ownerPending=false;view.viewport=true
assert(menu:update(53,pc)and created>0,'A PDA initialized after thirty frames must still be discovered')
menu:destroy()
menu=setup();view.ownerPending=true;view.viewport=false
manager.OpenViews={GetArrayNum=function()return 1 end,
    [1]={type=function()return 'RemoteUnrealParam'end,get=function()return view end},
    ForEach=function()error('Native array callback must not be used')end}
assert(menu:update(60,pc)and created>0,'Native manager-hosted PDA must work without direct viewport attachment or local-player context')
menu:destroy()
menu=setup();view.viewport=false;manager.OpenViews={}
menu:update(70,pc);local allocationBaseline,searchBaseline,ownershipBaseline=created,globalSearches,ownershipReads
for i=1,1000 do menu:update(70+i*.001,pc)end
assert(globalSearches==searchBaseline and created==allocationBaseline,'Closed PDA must not rescan global objects or create widgets')
assert(ownershipReads-ownershipBaseline<=12,'Closed PDA owner checks must be throttled to 10Hz')
menu:destroy()
-- Runtime regression: the actual PDA is present, but the native class path
-- lookup fails before any widget construction. Use a real widget's UClass.
missingUMG['/Script/UMG.CanvasPanel']=true
menu=setup()
local nativeCanvasClass=obj('CanvasPanelClass');nativeCanvasClass.className='/Script/UMG.CanvasPanel'
nativeCanvasClass.fullNameOverride='Object /Script/UMG:CanvasPanel'
local gameCanvas=obj('GameCanvas');gameCanvas.class=nativeCanvasClass
view.WidgetTree.RootWidget=gameCanvas
assert(menu:update(100,pc)and created>0 and menu.classes.CanvasPanel==nativeCanvasClass,'Missing StaticFindObject class must resolve from the existing native PDA tree')
assert(table.concat(logs,'\n'):find('Object /Script/UMG:CanvasPanel acquired via PDA widget GetClass',1,true),'Log must identify the runtime class spelling and actual acquisition method')
menu:destroy()
menu=setup();existingWidgets.CanvasPanel={gameCanvas}
assert(menu:update(101,pc)and created>0 and menu.classes.CanvasPanel==nativeCanvasClass,'An existing native widget elsewhere can supply a class absent from this PDA page')
menu:destroy();existingWidgets.CanvasPanel={}
menu=setup()
local cookedClass=obj('CookedCanvasClass');cookedClass.className='/Game/Mod/CanvasPanel.CanvasPanel_C'
local cookedCanvas=obj('CookedCanvas');cookedCanvas.class=cookedClass;view.WidgetTree.RootWidget=cookedCanvas
assert(menu:update(110,pc)and created==0,'Never construct an arbitrary cooked subclass in place of native UMG')
local searchesAfterMissing=globalSearches
assert(not menu:requestOpen(110.1,pc)and not menu.inject and not menu.selectRequested,'F6 must immediately decline while the panel is unavailable')
for i=1,40 do assert(menu:update(110+i*.1,pc))end
assert(created==0 and globalSearches==searchesAfterMissing,'Missing class retries must allocate nothing and remain bounded')
view.WidgetTree.RootWidget=gameCanvas
assert(menu:update(115.1,pc)and created>0,'A native class that becomes available later must recover without a reload')
local recoveredCount,recoveredSearches=created,globalSearches
menu:update(121,pc)
assert(created==recoveredCount and globalSearches==recoveredSearches,'Successful recovery must stop class scans and reuse its widgets')
menu:destroy();missingUMG={}
-- Actual failure: LMB from a distant native tab used to start a traversal
-- timer and close after an unrelated page/glow update. Own page has index 6.
menu=setup()
for i=2,6 do
    local tab=nativeTabFixture();tab.ButtonId='Native'..i
    view.NavigationPanel.SlotContainer.children[i]=tab
    view.Switcher.children[i]=obj('NativePage'..i)
end
menu:update(130,pc)
assert(menu.pageHost.index==6 and #view.Switcher.children==7)
local clickAllocationCount=created
for _,start in ipairs({0,2,5})do
    view.Switcher:SetActiveWidgetIndex(start);view.Switcher.transitions={}
    menu:update(130.01+start,pc)
    menu.tab.button.hovered=true;menu.tab.button.pressed=true;menu:update(130.02+start,pc)
    menu.tab.button.pressed=false;menu:update(130.03+start,pc)
    assert(menu.active and #view.Switcher.transitions==1 and view.Switcher.transitions[1]==6,
     'Each LMB click must go directly to ZoneFPV without visiting intermediate pages')
    assert(not view.NavigationPanel.transition,'LMB must never start the native traversal timer')
    menu.tab.widget.SelectLine:SetVisibility(2)
    for i=1,120 do menu:update(136+start+i*.05,pc)end
    assert(menu.active and created==clickAllocationCount,'Selected content stays visible without allocating more widgets')
end
assert(menu.body.parent==menu.root and not menu.root.parent and menu.pageHost.widget.parent==view.Switcher)
assert(menu.sidebar[1].left:GetVisibility()==3 and menu.sidebar[1].right:GetVisibility()==3)
assert(menu.resources.widget:GetVisibility()==2,'Normal PDA page must not show implementation counters')
local category=menu.sidebar[3]
category.widget.hovered=true;category.widget.pressed=true;menu:update(150,pc)
assert(category.background.color==menu.theme.colors.hover,'Category hover must render even with a transparent native button style')
category.widget.pressed=false;menu:update(150.01,pc)
assert(menu.page==3 and menu.title.lastText==menu.pages[3].label and menu.active,
 'Each category updates information inside the same selected PDA page')
assert(category.background.color==menu.theme.colors.rowActive,'Selected fill takes precedence over hover')
view.NavigationPanel:ClickMenuButton('Native6');menu:update(150.1,pc)
assert(not menu.active and view.Switcher:GetActiveWidgetIndex()==5 and view.Switcher:GetVisibility()==0,
 'Native selection must leave the owned page through the real switcher')
-- Real Q/E key routing, rather than faking a page-index change.
local nav=view.NavigationPanel
local function selectOwn(now)
    pc.keys={};pc.down={};menu:requestOpen(now,pc);menu:update(now+.01,pc)
    view.Switcher.transitions={};nav.moveCalls=0
end
selectOwn(160);pc.keys={Q=true};pc.down={Q=true};menu:update(160.02,pc)
assert(menu.active and nav.moveCalls==0,'Give native input one update before bridging a press')
menu:update(160.05,pc)
assert(not menu.active and view.Switcher:GetActiveWidgetIndex()==5 and nav.moveCalls==1,'Q leaves ZoneFPV through one native previous-slot command')
for i=1,10 do menu:update(160.05+i*.01,pc)end
assert(nav.moveCalls==1,'Held Q must not step twice or take over a native page')
selectOwn(161)
nav.SlotContainer.children[1]:SetVisibility(2)
pc.keys={E=true};pc.down={E=true};menu:update(161.02,pc);menu:update(161.05,pc)
assert(not menu.active and view.Switcher:GetActiveWidgetIndex()==1 and nav.moveCalls==1,'E uses native wrap and skips the hidden first tab')
nav.SlotContainer.children[1]:SetVisibility(0)
selectOwn(162);pc.keys={Q=true};pc.down={Q=true};menu:update(162.02,pc)
nav:ClickMenuButton('Native6');menu:update(162.03,pc)
assert(nav.moveCalls==0 and #view.Switcher.transitions==1,'If native input handles the press, pending bridge must cancel')
pc.keys={E=true};pc.down={E=true};menu:update(162.04,pc);menu:update(162.05,pc)
assert(nav.moveCalls==0,'Native pages retain their own Q/E handler')
-- The E that entered ZoneFPV through native input must not leave it again.
nav:ClickMenuButton('ZoneFPV');menu:update(162.06,pc);menu:update(162.07,pc)
assert(menu.active and nav.moveCalls==0,'Entering with held E must not immediately advance again')
selectOwn(163);pc.unavailablePress=true;pc.down={Q=true}
menu:update(163.02,pc);menu:update(163.05,pc)
assert(not menu.active and nav.moveCalls==1,'Held-state edge works when JustPressed is unavailable')
pc.unavailablePress=false
selectOwn(164);pc.keys={Q=true};pc.down={Q=true};menu:update(164.02,pc)
manager.OpenViews={};view.viewport=false;menu:update(164.05,pc)
assert(nav.moveCalls==0 and not menu.navigationPending,'Closing PDA cancels a queued navigation press even before cached discovery expires')
manager.OpenViews={view};view.viewport=true;menu.nextDiscovery=0;pc.down={};menu:update(164.04,pc)
selectOwn(165);pc.keys={Q=true,E=true};pc.down={Q=true,E=true}
menu:update(165.02,pc);menu:update(165.03,pc)
assert(menu.active and nav.moveCalls==0,'Opposite simultaneous keys cancel instead of guessing a direction')
selectOwn(165.2);nav.PDASectionSwitch=.5;pc.keys={Q=true};pc.down={Q=true}
menu:update(165.22,pc);menu:update(165.5,pc)
assert(menu.active and nav.moveCalls==0,'Native first-movement timer gets its configured delay before bridging')
nav:ClickMenuButton('Native6');menu:update(165.72,pc);menu:update(165.9,pc)
assert(not menu.active and nav.moveCalls==0,'A delayed native transition cancels the bridge without another movement')
selectOwn(165.95);pc.keys={E=true};pc.down={E=true}
menu:update(165.97,pc);menu:update(166.3,pc)
assert(nav.moveCalls==0)
menu:update(166.51,pc)
assert(not menu.active and nav.moveCalls==1 and view.Switcher:GetActiveWidgetIndex()==0,
 'If native timer never changes the page, the bridge executes once after the grace interval')
nav.PDASectionSwitch=0
selectOwn(167);pc.keys={Q=true};pc.down={Q=true};menu:update(167.02,pc)
assert(menu.navigationPending)
local ownedBeforeDetach=menu.pageHost.widget;menu:destroy()
assert(not menu.navigationPending and ownedBeforeDetach.removed and nav.moveCalls==0,'Detach cancels pending navigation without dispatching it')
assert(#view.Switcher.children==6 and #view.NavigationPanel.SlotContainer.children==6)
-- UIOnly focus suppresses both engine key methods, so exercise the independent
-- input channel rather than assuming IsInputKeyDown remains available.
local input={q=false,e=false}
local inputCalls,inputError=0,false
menu=setup(function()
    inputCalls=inputCalls+1
    if inputError then error('Input bridge unavailable')end
    return input
end)
menu:update(180,pc);menu:requestOpen(180,pc);menu:update(180.01,pc)
nav=view.NavigationPanel;nav.PDASectionSwitch=.5;pc.keys={};pc.down={}
input.q=true;local callsBeforePress=inputCalls;menu:update(180.02,pc)
assert(inputCalls==callsBeforePress+1 and menu.navigationPending,
 'A UIOnly press reads one coherent independent Q/E sample per update')
menu:update(180.021,pc)
assert(not menu.active and nav.moveCalls==1 and nav.moveDirection==-1,
 'Independent Q switches on the next update without waiting for a half-second native timer')
menu:update(180.06,pc);nav:ClickMenuButton('ZoneFPV');menu:update(180.07,pc);menu:update(180.10,pc)
assert(menu.active and nav.moveCalls==1 and not menu.navigationPending,
 'Independent Q held while entering ZoneFPV cannot immediately leave it')
-- Native state can be cached down after switching into UIOnly. A valid false
-- provider state must remain false, including when JustPressed is cached true.
pc.keys={Q=true,E=true};pc.down={Q=true,E=true};input.q=false
menu:update(180.11,pc)
assert(not menu.navigationPending and pc.keys.Q and pc.keys.E,
 'Provider release is authoritative and never consults cached native Q/E')
input.e=true;menu:update(180.12,pc);menu:update(180.15,pc)
assert(not menu.active and nav.moveCalls==2 and nav.moveDirection==1,
 'Independent E leaves ZoneFPV after an authoritative false release')
input={q=false,e=false};menu:update(180.16,pc)
nav:ClickMenuButton('ZoneFPV');menu:update(180.17,pc)
input.q=true;menu:update(180.18,pc);assert(menu.navigationPending)
input=nil;menu:update(180.21,pc)
assert(menu.active and nav.moveCalls==2 and not menu.navigationPending,
 'A stale or unfocused provider cancels queued navigation before its due movement')
input={q=true,e=false};menu:update(180.22,pc);menu:update(180.25,pc)
assert(menu.active and nav.moveCalls==2 and not menu.navigationPending,
 'Availability restored with a held key requires release and cannot revive cached native input')
input.q=false;menu:update(180.26,pc);input.q=true;menu:update(180.27,pc)
nav:ClickMenuButton('Map');menu:update(180.28,pc);menu:update(180.31,pc)
assert(nav.moveCalls==2 and not menu.navigationPending,
 'Native movement gets priority over queued independent input')
input.q=false;input.e=true;menu:update(180.32,pc);menu:update(180.35,pc)
assert(nav.moveCalls==2,'Independent input never takes over native pages')
nav:ClickMenuButton('ZoneFPV');menu:update(180.36,pc);menu:update(180.39,pc)
assert(menu.active and nav.moveCalls==2,'Entering ZoneFPV with independent E held must remain selected')
input={q=false,e=false};menu:update(180.40,pc)
input={q=true,e=true};menu:update(180.41,pc);menu:update(180.44,pc)
assert(menu.active and not menu.navigationPending and nav.moveCalls==2,
 'Opposite independent keys cancel instead of choosing a direction')
input={q=false,e=false};menu:update(180.45,pc)
input.q=true;menu:update(180.46,pc);assert(menu.navigationPending)
input={q=true};menu:update(180.49,pc)
assert(menu.active and not menu.navigationPending and nav.moveCalls==2,
 'A partial input sample is unavailable and cancels pending movement')
inputError=true;menu:update(180.50,pc)
assert(menu.active and not menu.updateError,'A failed input provider cannot destroy the native PDA page')
inputError=false;input={q=false,e=false};menu:update(180.51,pc)
input.e=true;menu:update(180.52,pc);manager.OpenViews={};view.viewport=false;menu:update(180.55,pc)
assert(not menu.navigationPending and nav.moveCalls==2,'Closing PDA cancels independent navigation before its due movement')
menu:destroy()
-- Independent counters retain presses shorter than an idle Lua update. They
-- own the edge when present; held booleans cannot create a second press.
input={q=true,e=false,qSeq=5,eSeq=8}
menu=setup(function()return input end)
menu:update(190,pc);menu:requestOpen(190,pc);menu:update(190.01,pc)
nav=view.NavigationPanel;pc.keys={};pc.down={}
assert(menu.active and not menu.navigationPending,
 'The first sequence sample primes counters even with Q already held')
input.q=false;input.qSeq=6;menu:update(190.05,pc)
assert(menu.navigationPending,'A short Q tap retained in its counter must survive a released current state')
menu:update(190.08,pc)
assert(not menu.active and nav.moveCalls==1 and nav.moveDirection==-1,
 'A released short Q tap leaves ZoneFPV once through native navigation')
nav:ClickMenuButton('ZoneFPV');menu:update(190.09,pc)
input.q=true;menu:update(190.10,pc);menu:update(190.13,pc)
assert(menu.active and nav.moveCalls==1 and not menu.navigationPending,
 'A down-state change with the same sequence cannot fabricate another press')
input.qSeq=7;menu:update(190.14,pc);menu:update(190.17,pc);menu:update(190.20,pc)
assert(not menu.active and nav.moveCalls==2,'A changed counter dispatches exactly once while held')
input.e=true;input.eSeq=9;menu:update(190.21,pc)
nav:ClickMenuButton('ZoneFPV');menu:update(190.22,pc);menu:update(190.25,pc)
assert(menu.active and nav.moveCalls==2 and not menu.navigationPending,
 'Counters sampled on a native page cannot repeat its entering-held E on ZoneFPV')
input=nil;menu:update(190.26,pc)
input={q=true,e=true,qSeq=20,eSeq=30};menu:update(190.27,pc);menu:update(190.30,pc)
assert(menu.active and nav.moveCalls==2 and not menu.navigationPending,
 'The first valid counter sample after a focus gap primes without replaying held presses')
input.q=false;input.e=false;menu:update(190.31,pc)
input.eSeq=31;menu:update(190.32,pc);menu:update(190.35,pc)
assert(not menu.active and nav.moveCalls==3 and nav.moveDirection==1,
 'A new short E tap works after focus recovery and release')
nav:ClickMenuButton('ZoneFPV');menu:update(190.36,pc)
input.qSeq=21;menu:update(190.37,pc);assert(menu.navigationPending)
input.qSeq=-1;menu:update(190.40,pc)
assert(menu.active and nav.moveCalls==3 and not menu.navigationPending,
 'Invalid sequence counters cancel movement rather than falling back to held states')
input={q=false,e=false,qSeq=100,eSeq=200};menu:update(190.41,pc)
input={q=false,e=false,qSeq=0,eSeq=0};menu:update(190.42,pc);menu:update(190.45,pc)
assert(menu.active and nav.moveCalls==3 and not menu.navigationPending,
 'A fast producer restart resets counters without fabricating Q/E presses')
input.qSeq=1;menu:update(190.46,pc);menu:update(190.49,pc)
assert(not menu.active and nav.moveCalls==4 and nav.moveDirection==-1,
 'A real press after a producer counter reset uses the new baseline')
menu:destroy()
-- Real Slider controls are seeded without writing preferences. Mouse capture
-- prevents periodic refresh from pulling the thumb back to the saved value.
commands={};menu=setup()
snapshot.cfg.speed_preset=1.234567;snapshot.cfg.camera_tilt=37
menu:update(200,pc);menu:requestOpen(200,pc)
assert(#menu.sidebar==5 and #menu.pages==5 and #commands==0)
local function chooseSection(group,section)
    menu.sidebar[group].action();menu.sectionTabs[section].action()
    assert(menu.page==group and menu.section==section)
end
local slidersCreated=created
local speedRow=menu.rowWidgets[2]
assert(speedRow.slider:GetVisibility()==0 and speedRow.minus.widget:GetVisibility()==1
 and speedRow.plus.widget:GetVisibility()==1 and speedRow.slider:GetValue()==1.234567,
 'Multipliers use actual sliders and opening preserves the saved precision')
assert(menu.rowWidgets[1].minus.widget:GetVisibility()==0
 and menu.rowWidgets[3].activate.widget:GetVisibility()==0,
 'Choices keep arrows; toggles and actions have one clickable value')
speedRow.slider.captured=true
menu:update(200.01,pc);menu:update(200.3,pc)
assert(menu.active and menu.pageHost and not menu.updateError and #commands==0,
 'Holding a slider without moving it must survive refresh with no pending edit')
speedRow.slider.captured=true;speedRow.slider.value=1.87
menu:update(200.32,pc)
local writesDuringDrag=speedRow.slider.valueWrites
menu:update(200.5,pc)
assert(#commands==0 and speedRow.pending and speedRow.value.lastText=='1.85 ×'
 and speedRow.slider.valueWrites==writesDuringDrag and speedRow.slider:GetValue()==1.87,
 'Dragging previews the stepped value without rewriting preferences or resetting the thumb')
speedRow.slider.captured=false;menu:update(200.51,pc)
assert(#commands==1 and commands[1]=='FPVSettings 1.85 37',
 'Releasing a slider applies one command with the untouched camera angle')
for i=1,20 do menu:update(200.51+i*.02,pc)end
assert(#commands==1 and created==slidersCreated,'Repaint must neither reapply sliders nor allocate widgets')
-- A click completed between ticks still changes GetValue; it cannot be lost
-- simply because capture was never sampled true.
speedRow.slider.value=2.28;menu:update(201,pc);menu:update(201.13,pc)
assert(#commands==2 and commands[2]=='FPVSettings 2.30 37')
-- A fast category switch commits the final pending mouse value before reusing
-- the same slider widget for a different setting.
speedRow.slider.value=.67;menu:update(201.2,pc)
chooseSection(2,1)
assert(#commands==3 and commands[3]=='FPVSettings 0.65 37' and menu.page==2 and menu.section==1)
assert(menu.rowWidgets[1].slider:GetValue()==37 and not menu.rowWidgets[1].pending)
menu.rowWidgets[1].slider.value=44;menu:update(201.21,pc);menu:update(201.34,pc)
assert(commands[#commands]=='FPVSettings 1.234567 44',
 'Changing a camera slider must retain all stored speed precision')
chooseSection(4,1)
local geometry=menu.rowWidgets[4]
assert(geometry.slider.maxValue==6 and geometry.slider.stepSize==1)
geometry.slider.value=3.2;menu:update(201.4,pc)
assert(geometry.value.lastText=='2 ×','Geometry slider preview maps positions to actual distance factors')
menu:update(201.53,pc);assert(commands[#commands]=='FPVDistance 3')
chooseSection(4,2)
snapshot.radio={enabled=true,range=1275,attenuation=1.876543};menu.nextRefresh=0;menu:update(201.6,pc)
assert(menu.rowWidgets[2].slider:GetValue()==1275 and menu.rowWidgets[3].slider:GetValue()==1.876543,
 'Unaligned saved range and precise attenuation must not change on page open')
menu.rowWidgets[2].slider.value=1841;menu:update(201.61,pc);menu:update(201.74,pc)
assert(commands[#commands]=='FPVSignal 1 1850 1.876543')
chooseSection(3,3)
menu.rowWidgets[4].slider.value=4.04;menu:update(201.8,pc)
view.NavigationPanel:ClickMenuButton('Map');menu:update(201.81,pc)
assert(commands[#commands]=='FPVImpact 4.05' and not menu.active,
 'Leaving ZoneFPV commits a pending slider once through the same command handler')
assert(created==slidersCreated)
menu:destroy()
-- This adapter actually applies signal state, exposing stale closures that a
-- command-only recorder cannot detect when two related controls change fast.
commands={};menu=setup()
snapshot.radio={enabled=true,range=1500,attenuation=2}
menu.opts.execute=function(command)
    commands[#commands+1]=command
    local on,range,attenuation=command:match('^FPVSignal (%d) (%d+) ([%d%.]+)$')
    if on then snapshot.radio={enabled=on=='1',range=tonumber(range),attenuation=tonumber(attenuation)}end
    return true
end
menu:update(210,pc);menu:requestOpen(210,pc);chooseSection(4,2)
menu.rowWidgets[3].slider.value=3.17;menu:update(210.01,pc)
menu.rowWidgets[1].activate.action()
assert(#commands==2 and snapshot.radio.enabled==false and snapshot.radio.attenuation==3.15
 and commands[2]=='FPVSignal 0 1500 3.15',
 'A fast toggle uses fresh settings after committing a pending sibling slider')
menu.rowWidgets[2].slider.value=2222;menu.rowWidgets[3].slider.value=4.12
menu.rowWidgets[1].activate.action()
assert(snapshot.radio.enabled and snapshot.radio.range==2200 and snapshot.radio.attenuation==4.10,
 'Final polling and consecutive commits retain both quick sibling slider edits')
menu.rowWidgets[2].slider.value=2790;menu.rowWidgets[3].slider.value=1.13
menu:update(210.01,pc);menu:update(210.14,pc)
assert(snapshot.radio.range==2800 and snapshot.radio.attenuation==1.15,
 'Two settled slider clicks apply in order without restoring the previous sibling value')
local beforeSectionSwitch=#commands
menu.rowWidgets[3].slider.value=2.63
menu.sectionTabs[1].action()
assert(#commands==beforeSectionSwitch+1 and snapshot.radio.attenuation==2.65
 and menu.section==1 and menu.rowWidgets[1].caption.lastText=='Сильно замедлить мир в FPV',
 'An internal section switch commits the pending setting before the reused row changes its meaning')
menu.sectionTabs[2].action()
local beforeFinalExit=#commands
menu.rowWidgets[3].slider.value=.73
view.NavigationPanel:ClickMenuButton('Map');menu:update(210.15,pc)
assert(#commands==beforeFinalExit+1 and snapshot.radio.attenuation==.75 and not menu.active,
 'Closing the native page polls and commits the last position without an intervening slider update')
menu:destroy()
commands={};menu=setup()
snapshot.armament={mode=3,power=1.25,grenade=1,charges=3}
snapshot.session={weapons={mode=3,remaining=2}}
menu.opts.execute=function(command)
    commands[#commands+1]=command
    local values=command:match('^FPVArmament (.+)$')
    if values then snapshot.armament=assert(dofile('mod/Scripts/weapon_settings.lua').parse(values))end
    return true
end
menu:update(220,pc);menu:requestOpen(220,pc);chooseSection(3,1)
assert(menu.telemetry.lastText:find('Заряды 2',1,true),'Armament footer reflects charges left in the active flight')
assert(menu.pages[3].label=='Оснащение'and menu.pages[3].sections[1].label=='Боевой режим'
 and menu.rowWidgets[1].value.lastText=='Сброс + камикадзе'and menu.rowWidgets[2].slider:GetValue()==1.25)
for i=2,5 do assert(menu.rowWidgets[i].root:GetVisibility()==0,'Both combined payload parameter sets stay available')end
menu.rowWidgets[2].slider.value=2.13;menu.rowWidgets[5].slider.value=21
menu:update(220.01,pc);menu:update(220.14,pc)
assert(#commands==2 and snapshot.armament.power==2.25 and snapshot.armament.charges==0
 and snapshot.armament.grenade==1 and snapshot.armament.mode==3,
 'Rapid power/capacity edits preserve both accepted values and the selected grenade')
snapshot.session.weapons.remaining=math.huge;menu.nextRefresh=0;menu:update(220.3,pc)
assert(menu.telemetry.lastText:find('Заряды ∞',1,true),'Unlimited ammunition is distinct from an empty finite supply')
local beforeModes=#commands
for mode=0,3 do
 snapshot.armament.mode=mode;menu.nextRefresh=0;menu:update(220.31+mode*.01,pc)
 local expected=({1,3,3,5})[mode+1]
 for i=1,15 do assert(menu.rowWidgets[i].root:GetVisibility()==(i<=expected and 0 or 1),'Conditional rows collapse without empty gaps')end
 assert(menu.rowWidgets[1].index==1 and menu.scroll.consumeWheel==1)
 if mode==2 then assert(menu.rowWidgets[2].caption.lastText=='Тип гранаты'and menu.rowWidgets[3].caption.lastText=='Количество зарядов')end
end
assert(#commands==beforeModes,'Repainting mode-dependent rows never changes stored weapons settings')
snapshot.armament.mode=2;menu.nextRefresh=0;menu:update(220.35,pc)
menu.rowWidgets[3].slider.captured=true;menu.rowWidgets[3].slider.value=17;menu:update(220.36,pc)
assert(menu.rowWidgets[3].pending,'Old charge slider has a real uncommitted edit')
snapshot.armament.mode=1;menu.nextRefresh=0;menu:update(220.37,pc)
assert(not menu.rowWidgets[3].pending and menu.rowWidgets[3].slider:GetValue()==snapshot.armament.impactSpeed,'Changed slider identity drops the old charge draft and uses actual impact speed')
menu.rowWidgets[3].slider.captured=false;menu:update(220.38,pc)
assert(#commands==beforeModes,'A released old slider cannot write into a new combat parameter')
snapshot.armament.mode=3;menu.nextRefresh=0;menu:update(220.39,pc)
-- Environment/F6 updates precede pda:update in the owner. A close/native Q/E
-- or section action can commit before refresh has repainted the changed slot.
local function primeCombatDraft(now,skipPoll)
 snapshot.armament={mode=2,power=3.75,grenade=1,charges=7,impactSpeed=65}
 menu:requestOpen(now,pc);chooseSection(3,1)
 local r=menu.rowWidgets[3];r.slider.captured=true;r.slider.value=17
 if not skipPoll then menu:update(now+.001,pc)end
 assert((skipPoll and not r.pending or not skipPoll and r.pending)and r.rowIdentity:find('Количество зарядов',1,true))
 snapshot.armament.mode=1
 return r,#commands
end
local function unchangedCombat(before)
 assert(#commands==before and snapshot.armament.mode==1 and snapshot.armament.impactSpeed==65
  and snapshot.armament.charges==7 and snapshot.armament.power==3.75 and snapshot.armament.grenade==1,
  'A stale pre-refresh charge thumb cannot write impact speed or restore any current sibling')
end
local r,before=primeCombatDraft(220.40);assert(not menu:commitSliders());unchangedCombat(before);r.slider.captured=false
r,before=primeCombatDraft(220.42);menu:close();unchangedCombat(before);r.slider.captured=false
r,before=primeCombatDraft(220.44);menu.sectionTabs[2].action();unchangedCombat(before);r.slider.captured=false
r,before=primeCombatDraft(220.46);menu.sidebar[5].action();unchangedCombat(before);r.slider.captured=false
r,before=primeCombatDraft(220.48);view.NavigationPanel:ClickMenuButton('Map');menu:update(220.482,pc)
assert(not menu.active,'Native Q/E selected another page before periodic refresh')
unchangedCombat(before);r.slider.captured=false
menu:requestOpen(220.49,pc);chooseSection(3,1)
r,before=primeCombatDraft(220.50,true);menu:close();unchangedCombat(before);r.slider.captured=false
menu:requestOpen(220.51,pc);chooseSection(3,1)
chooseSection(5,3)
assert(menu.pages[5].sections[3].label=='Кнопки'and #menu.pages[5].sections[3].rows==8 and #menu.rowWidgets==15)
assert(menu.sectionTabs[1].text.lastText=='Общие'and menu.sectionTabs[2].text.lastText=='Пульт'
 and menu.sectionTabs[3].text.lastText=='Кнопки'and menu.sectionTabs[3].widget:GetVisibility()==0)
snapshot.actionModes={}
snapshot.settings={available=true,eligible=true,connected=true,device=44,profile=1,devices={{id=44,backend=1,name='Pocket USB'}},
 bindings={117,119,120,0,0,3018,3011,0},modes={0,0,0,0,0,0,0,0},capture={row=-1},calibration={stage=0},
 language=0,theme=0,volume=20,axes={0,10000,20000,30000,40000,50000,60000,65535},objectLimit={has=true,value=3000000},status='Helper neutral'}
local osdModule=dofile('mod/Scripts/pda_osd.lua')
snapshot.osd=osdModule.defaults();snapshot.osd.selectedItemID=0;snapshot.osd.previewDown=false
snapshot.osd.preview,snapshot.osd.previewBounds=osdModule.preview(snapshot.osd)
local requests,contexts={},{}
menu.opts.tool=function()error('No external tool may open')end
menu.opts.settings={context=function(open,id,blocked)contexts[#contexts+1]={open,id,blocked}end,
 request=function(action,args)
  requests[#requests+1]={action=action,args=args};local st=snapshot.settings
  if action=='modes'then st.modes[args[1]+1]=args[2]
  elseif action=='capture'then st.capture={row=args[1],remainingMs=15000}
  elseif action=='cancel'then st.capture={row=-1}
  elseif action=='clear'then st.bindings[args[1]+1]=0
  elseif action=='device'then st.device=args[1]
  elseif action=='profile'then st.profile=args[1]
  elseif action=='calibrate'then st.calibration={stage=args[1]==1 and 0 or 1,axis=0};st.status='Leave sticks neutral'
  elseif action=='language'then st.language=args[1]
  elseif action=='theme'then st.theme=args[1]
  elseif action=='audio'then st.volume=args[1]
  elseif action=='limit'then st.objectLimit={has=true,value=args[1]}
  elseif action=='limitreset'then st.objectLimit={has=false,value=0}
  else error(action)end
  return true,'Настройки сохранены'
 end}
local osdWrites,osdCalls=0,{}
menu.opts.osd={execute=function(action,args)
 osdCalls[#osdCalls+1]={action=action,args=args};if action~='selectItem'and action~='previewDown'then osdWrites=osdWrites+1 end
 if action=='item'then snapshot.osd.items[args.id+1][args.field]=args.value
 elseif action=='selectItem'then snapshot.osd.selectedItemID=args.id
 elseif action=='position'then snapshot.osd.items[args.id+1].x,snapshot.osd.items[args.id+1].y=args.x,args.y
 elseif action=='resetLayout'then snapshot.osd=osdModule.defaults();snapshot.osd.selectedItemID=0
 else snapshot.osd[action]=args.value end
 snapshot.osd.preview,snapshot.osd.previewBounds=osdModule.preview(snapshot.osd)
 return true,'saved'
end}
local beforeInlineAllocations=created
menu.nextRefresh=0;menu:update(221,pc)
for i=1,8 do
 local r=menu.rowWidgets[i];r.mode.action()
 assert(requests[#requests].action=='modes'and requests[#requests].args[1]==i-1 and requests[#requests].args[2]==1)
 assert(r.mode.text.lastText=='Удержание')
 r.activate.action();assert(requests[#requests].action=='capture'and requests[#requests].args[1]==i-1)
 assert(r.clear.text.lastText=='Отмена'and snapshot.settings.modes[i]==1)
 r.clear.action();assert(requests[#requests].action=='cancel'and snapshot.settings.capture.row==-1)
 r.clear.action();assert(requests[#requests].action=='clear'and requests[#requests].args[1]==i-1)
end
assert(created==beforeInlineAllocations,'Inline capture/mode/clear reuse every owned widget')
-- Q/E and row keyboard edges are captured without navigating or replaying.
menu.rowWidgets[6].activate.action();local nativeMoves=view.NavigationPanel.moveCalls or 0
menu.rowWidgets[6].clear.widget.hovered=true;menu.rowWidgets[6].clear.widget.pressed=true;menu:update(221.005,pc)
assert(contexts[#contexts][3]==true and snapshot.settings.capture.row==5,'Cancel mousedown is blocked from LMB capture before its release action')
menu.rowWidgets[6].clear.widget.hovered=false;menu.rowWidgets[6].clear.widget.pressed=false;menu:update(221.006,pc)
assert(contexts[#contexts][3]==false and snapshot.settings.capture.row==5,'Blank PDA content still accepts a mouse-button assignment')
menu.scroll.hovered=true;menu:update(221.0065,pc)
assert(contexts[#contexts][3]==true and snapshot.settings.capture.row==5,'Owned scrolling/scrollbar pointer input cannot become a Mouse1 assignment')
menu.scroll.hovered=false
view.NavigationPanel.SlotContainer.children[1].Button.hovered=true;menu:update(221.007,pc)
assert(contexts[#contexts][3]==true,'Native sibling-tab clicks are capture-reserved too')
view.NavigationPanel.SlotContainer.children[1].Button.hovered=false
pc.keys={Q=true,Enter=true,Right=true};pc.down={Q=true};menu:update(221.01,pc);menu:update(221.02,pc)
assert(menu.active and (view.NavigationPanel.moveCalls or 0)==nativeMoves and snapshot.settings.capture.row==5)
menu.rowWidgets[6].clear.action();pc.keys={};menu:update(221.03,pc)
assert(menu.active and snapshot.settings.capture.row==-1 and (view.NavigationPanel.moveCalls or 0)==nativeMoves)
pc.down={Q=false};menu:update(221.04,pc)
menu.rowWidgets[1].activate.action();snapshot.settings.capture={row=-1}
pc.keys={Q=true,Enter=true};pc.down={Q=true};menu:update(221.05,pc);menu:update(221.06,pc)
assert(menu.active and (view.NavigationPanel.moveCalls or 0)==nativeMoves,'Capture completion before the next UI update cannot replay its assigned Q/Enter')
pc.keys={};pc.down={Q=false};menu:update(221.07,pc)
-- General editing is inline, supports exact large uint31 limits and reset.
chooseSection(5,1)
assert(contexts[#contexts][1]and contexts[#contexts][2]==10)
assert(menu.rowWidgets[1].caption.lastText=='Язык'and menu.rowWidgets[2].caption.lastText=='Звук моторов и громкость')
menu.rowWidgets[1].plus.action()
assert(snapshot.settings.language==1 and snapshot.settings.theme==0,'Theme remains stored without a menu row or write')
menu.rowWidgets[2].slider.value=54;menu:update(222,pc);menu:update(222.2,pc)
assert(snapshot.settings.volume==54)
local limit=menu.rowWidgets[3];assert(limit.number:GetVisibility()==0 and limit.number.text=='3000000')
limit.number.text='2147483647';limit.activate.action();assert(snapshot.settings.objectLimit.value==2147483647)
limit.number.keyboardFocus=true;limit.number.text='2000123';pc.keys={Enter=true,Q=true};pc.down={Q=true};menu:update(222.3,pc)
assert(snapshot.settings.objectLimit.value==2000123 and menu.active,'Numeric Enter applies the exact value and owns navigation while focused')
limit.number.keyboardFocus=false;pc.down={Q=false};pc.keys={};menu:update(222.31,pc)
limit.number.text='2147483648';local n=#requests;limit.activate.action();assert(#requests==n and menu.statusError)
assert(menu.feedback.lastText:find('2147483647',1,true),'Local validation error survives neutral helper feedback')
menu.rowWidgets[4].activate.action();assert(not snapshot.settings.objectLimit.has)
-- Controller wizard and all eight live axes stay inside the same page.
chooseSection(5,2);assert(contexts[#contexts][2]==1)
assert(menu.rowWidgets[1].caption.lastText=='Устройство контроллера'and menu.rowWidgets[1].value.lastText=='Pocket USB [DirectInput]')
menu.rowWidgets[2].plus.action();assert(snapshot.settings.profile==2)
menu.rowWidgets[4].activate.action();assert(snapshot.settings.calibration.stage==1)
assert(menu.description.lastText=='Leave sticks neutral'and menu.rowWidgets[4].activate.text.lastText=='Зафиксировать нейтраль')
menu.rowWidgets[5].activate.action();assert(snapshot.settings.calibration.stage==0)
assert(menu.paging==nil and menu.contentPage==nil and menu.scroll.orientation==1 and menu.scroll.consumeWheel==1,'Actual native vertical ScrollBox owns wheel input; no pagination')
assert(menu.rowWidgets[9].caption.lastText=='CH3'and menu.rowWidgets[14].value.lastText=='65535')
for i=1,14 do assert(menu.rowWidgets[i].root:GetVisibility()==0 and menu.rowWidgets[i].root.parent==menu.rowList,'Every controller row is an owned continuous list item')end
assert(menu.rowWidgets[15].root:GetVisibility()==1,'Unused reusable row collapses without an empty gap')
menu.scroll.scrollOffset=270;local resets=menu.scroll.scrollResets;menu.nextRefresh=0;menu:update(222.4,pc)
assert(menu.scroll.scrollOffset==270 and menu.scroll.scrollResets==resets,'Live axis/status refresh retains the wheel offset')
menu.row=1;pc.keys={PageDown=true};menu:update(222.41,pc)
assert(menu.row==7 and menu.page==5 and menu.scroll.scrolledWidget==menu.rowWidgets[7].root,'PageDown scrolls vertically without changing groups')
pc.keys={PageDown=true};menu:update(222.42,pc);pc.keys={Down=true};menu:update(222.43,pc)
assert(menu.row==14 and menu.scroll.scrolledWidget==menu.rowWidgets[14].root,'Keyboard can reach the last live CH row')
pc.keys={PageUp=true};menu:update(222.44,pc)
assert(menu.row==8 and menu.scroll.scrolledWidget==menu.rowWidgets[8].root)
-- Complete OSD controls, item positions and independent styles are local.
chooseSection(2,2);assert(contexts[#contexts][2]==3 and menu.preview:GetVisibility()==4)
assert(menu.osdItemTitle.lastText=='Показатели'and #menu.osdItemButtons==14
 and menu.osdItemScroll.orientation==1 and menu.osdItemScroll.consumeWheel==1,'All indicators have a native vertical scrollable selector')
assert(menu.osdItemScroll.Slot.anchors.Maximum.X<menu.preview.Slot.anchors.Minimum.X
 and menu.preview.Slot.anchors.Maximum.X<menu.scroll.Slot.anchors.Minimum.X,'List, preview and inspector occupy separate readable columns')
local listWrites=osdWrites
for i,b in ipairs(menu.osdItemButtons)do
 assert(b.root.parent==menu.osdItemList and b.root.heightOverride==32 and b.text.lastText==snapshot.osd.items[i].label,
  'Every indicator, including hidden ones, has a named owned vertical list entry')
 b.action()
 assert(snapshot.osd.selectedItemID==i-1 and menu.osdSelected==i-1 and menu.rowWidgets[3].value.lastText==snapshot.osd.items[i].label
  and b.background.color==menu.theme.colors.rowActive and menu.osdItemScroll.scrolledWidget==b.root,
  'Selecting any list entry synchronizes the inspector, highlight and scroll target')
end
assert(osdWrites==listWrites,'Selecting all indicators must not save or change visibility')
menu.osdItemButtons[1].action()
menu.osdItemScroll.scrollOffset=64;local listScrollCalls=menu.osdItemScroll.intoViewCalls
menu.nextRefresh=0;menu:update(222.45,pc)
assert(menu.osdItemScroll.scrollOffset==64 and menu.osdItemScroll.intoViewCalls==listScrollCalls,'Periodic refresh retains the list scroll position')
assert(menu.rowWidgets[3].minus.widget:GetVisibility()==1 and menu.rowWidgets[3].plus.widget:GetVisibility()==1
 and menu.osdRowWidgets[4].caption.lastText=='Отображать','Selected indicator uses the list; display permission has its requested label')
assert(menu.osdRowWidgets[1].caption.lastText=='OSD'and menu.paging==nil and menu.scroll.scrollOffset==0)
assert(#menu.osdRowWidgets==15 and menu.osdRowWidgets[13].root:GetVisibility()==0 and menu.osdRowWidgets[14].root:GetVisibility()==1,'OSD inspector has13 controls with no XY rows or trailing layout gaps')
local beforeItemDraft=osdWrites
menu.rowWidgets[5].slider.captured=true;menu.rowWidgets[5].slider.value=83;menu:update(222.6,pc)
assert(menu.rowWidgets[5].pending,'Size edit is pending on the original item')
snapshot.osd.selectedItemID=2;menu.nextRefresh=0;menu:update(222.61,pc)
assert(not menu.rowWidgets[5].pending and menu.rowWidgets[5].slider:GetValue()==snapshot.osd.items[3].size,'External item selection drops the prior item draft')
menu.rowWidgets[5].slider.captured=false;menu:update(222.62,pc)
assert(osdWrites==beforeItemDraft,'Old size edit cannot become a new selected item write')
snapshot.osd.selectedItemID=0;menu.nextRefresh=0;menu:update(222.63,pc)
local function primeOSDDraft(now,skipPoll)
 snapshot.osd.selectedItemID=0;menu:requestOpen(now,pc);chooseSection(2,2)
 local r=menu.rowWidgets[5];r.slider.captured=true;r.slider.value=83
 if not skipPoll then menu:update(now+.001,pc)end
 assert(skipPoll and not r.pending or not skipPoll and r.pending)
 snapshot.osd.selectedItemID=2;snapshot.osd.items[3].x=.314159265358979;snapshot.osd.items[3].size=37
 snapshot.osd.items[3].color=4;snapshot.osd.items[1].x=.123456789012345
 return r,osdWrites
end
local function unchangedOSD(before)
 assert(osdWrites==before and snapshot.osd.selectedItemID==2 and snapshot.osd.items[3].x==.314159265358979 and snapshot.osd.items[3].size==37
  and snapshot.osd.items[3].color==4 and snapshot.osd.items[1].x==.123456789012345,
  'Old size thumb must not retarget the externally selected OSD item or restore its siblings')
end
r,before=primeOSDDraft(222.65);assert(not menu:commitSliders());unchangedOSD(before);r.slider.captured=false
r,before=primeOSDDraft(222.67);menu:close();unchangedOSD(before);r.slider.captured=false
r,before=primeOSDDraft(222.69);menu.sectionTabs[1].action();unchangedOSD(before);r.slider.captured=false
r,before=primeOSDDraft(222.71);menu.sidebar[5].action();unchangedOSD(before);r.slider.captured=false
r,before=primeOSDDraft(222.73);view.NavigationPanel:ClickMenuButton('Map');menu:update(222.732,pc)
assert(not menu.active);unchangedOSD(before);r.slider.captured=false
snapshot.osd.selectedItemID=0;menu:requestOpen(222.74,pc);chooseSection(2,2)
r,before=primeOSDDraft(222.75,true);assert(not menu:commitSliders());unchangedOSD(before);r.slider.captured=false
snapshot.osd.selectedItemID=0;menu:requestOpen(222.76,pc);chooseSection(2,2)
menu.rowWidgets[2].plus.action();assert(snapshot.osd.fontChoice==1 and menu.feedback.lastText=='Настройки сохранены')
local selectButton=menu.osdItemButtons[2]
selectButton.widget.hovered=true;selectButton.widget.pressed=true;menu:update(222.77,pc)
selectButton.widget.pressed=false;menu:update(222.78,pc)
assert(snapshot.osd.selectedItemID==1,'An indicator list click selects on release')
selectButton.widget.hovered=false
local targetSize=snapshot.osd.items[13].size;local priorItemWrites=osdWrites
menu.rowWidgets[5].slider.value=29;menu.osdItemButtons[13].action()
assert(osdWrites==priorItemWrites+1 and snapshot.osd.items[2].size==29 and snapshot.osd.items[13].size==targetSize
 and snapshot.osd.selectedItemID==12 and menu.rowWidgets[5].slider:GetValue()==targetSize,
 'List selection commits the final slider to its prior indicator before switching the inspector')
menu.osdItemButtons[2].action()
menu.rowWidgets[5].slider.value=27;menu:update(223,pc);menu:update(223.2,pc)
assert(snapshot.osd.items[2].size==27)
menu.rowWidgets[6].plus.action();assert(snapshot.osd.items[2].color==1)
menu.osdRowWidgets[7].activate.action();assert(snapshot.osd.items[5].visible==false and snapshot.osd.downCrossVisible)
menu.osdRowWidgets[9].activate.action();assert(snapshot.osd.downCrossVisible==false)
menu.osdRowWidgets[10].plus.action();assert(snapshot.osd.downCrossStyle==5)
menu.osdRowWidgets[11].activate.action();assert(snapshot.osd.previewDown)
local visibleLines=0;for _,line in ipairs(menu.previewLines)do if line:GetVisibility()~=1 then visibleLines=visibleLines+1 end end
assert(visibleLines==3,'Lower preview hides disabled crosshair/horizon and retains the home arrow')
-- Pointer selection and dragging use the actual preview BODY geometry, with
-- desktop origin/DPI conversion; neither title nor inspector is part of it.
menu.previewBody.geometry={x=410,y=230,width=800,height=450,scale=1.5}
local function point(nx,ny)
 local g=menu.previewBody.geometry;pointer={X=g.x+nx*g.width*g.scale,Y=g.y+ny*g.height*g.scale}
end
local function itemPoint(id)
 local b=menu.previewLayout.bounds[id+1];return b.x+b.width/2,b.y+b.height/2
end
menu.nextRefresh=0;menu:update(223.9,pc)
local px,py=itemPoint(11);local hp=snapshot.osd.items[12]
local ox,oy=hp.x,hp.y;local writesBeforeDrag=osdWrites
point(px,py);menu.previewInput.hovered=true;menu.previewInput.pressed=true;pc.keys={Enter=true,Right=true,PageDown=true};menu:update(224,pc)
assert(snapshot.osd.selectedItemID==11 and menu.previewDrag.id==11 and osdWrites==writesBeforeDrag,
 'Press selects the specific visible HP element without saving the layout')
assert(menu.osdSelected==11 and menu.osdItemButtons[12].background.color==menu.theme.colors.rowActive
 and menu.osdItemScroll.scrolledWidget==menu.osdItemButtons[12].root,'Preview selection reveals and highlights its list entry')
assert(menu.page==2 and menu.section==2 and snapshot.osd.fontChoice==1,'Same-frame keyboard actions cannot run while pointer drag starts')
assert(menu.previewOutline[1]:GetVisibility()==3,'Selected preview item has an amber outline')
point(px-.15,py+.20);menu:update(224.01,pc);menu:update(224.3,pc)
assert(math.abs(menu.previewDraft.x-(ox-.15))<1e-10 and math.abs(menu.previewDraft.y-(oy+.20))<1e-10
 and hp.x==ox and hp.y==oy and osdWrites==writesBeforeDrag,
 'Drag retains its grab offset and only updates local preview/inspector, including periodic refresh')
assert(menu.osdRowWidgets[5].caption.lastText=='Размер'and menu.osdRowWidgets[5].slider.value==hp.size,'Only size remains in inspector; pointer drafts do not become XY sliders')
-- Last movement can happen wholly between a held sample and release.
point(px-.18,py+.25);menu.previewInput.pressed=false;menu:update(224.31,pc)
assert(osdWrites==writesBeforeDrag+1 and osdCalls[#osdCalls].action=='position'
 and math.abs(hp.x-(ox-.18))<1e-10 and math.abs(hp.y-(oy+.25))<1e-10,
 'Release reads its final pointer and saves both coordinates exactly once')
menu:update(224.6,pc);assert(osdWrites==writesBeforeDrag+1)
px,py=itemPoint(11);point(px,py);menu.previewInput.pressed=true;menu:update(224.7,pc)
menu.previewInput.pressed=false;menu:update(224.71,pc)
assert(osdWrites==writesBeforeDrag+1,'A stationary click only selects; it cannot save/round existing coordinates')
-- Imported edge anchors survive a stationary click despite drag clamping.
hp.x=0;hp.y=.03;snapshot.osd.preview,snapshot.osd.previewBounds=osdModule.preview(snapshot.osd)
menu.nextRefresh=0;menu:update(224.79,pc)
px,py=itemPoint(11);point(px,py);menu.previewInput.pressed=true;menu:update(224.8,pc);menu:update(224.9,pc)
menu.previewInput.pressed=false;menu:update(224.91,pc)
assert(hp.x==0 and osdWrites==writesBeforeDrag+1,'Clicking an imported edge position does not apply drag bounds')
px,py=itemPoint(11);point(px,py);menu.previewInput.pressed=true;menu:update(225,pc)
point(-.5,1.7);menu:update(225.01,pc);menu.previewInput.pressed=false;menu.previewInput.hovered=false;menu:update(225.02,pc)
assert(hp.x==.02 and hp.y==.98 and osdWrites==writesBeforeDrag+2,'Captured drag release outside the preview clamps into the frame')
-- Empty preview space does not choose a nearest/hidden item.
point(.02,.5);menu.previewInput.hovered=true;menu.previewInput.pressed=true;menu:update(225.1,pc)
assert(not menu.previewDrag and snapshot.osd.selectedItemID==11)
menu.previewInput.pressed=false;menu:update(225.11,pc)
menu.osdRowWidgets[5].slider.value=54;menu:update(225.2,pc);menu:update(225.4,pc)
local previewHP;for _,t in ipairs(menu.previewTexts)do if t.lastText:find('DRONE HP',1,true)then previewHP=t end end
assert(previewHP and previewHP.widget.Font.Size==27,'Preview glyph size visibly follows selected size and actual preview height')
-- Leaving the section/closing/focus loss cancel the draft, never restore or
-- write an earlier imported/external layout snapshot.
local function startHPDrag(now)
 local x,y=itemPoint(11);point(x,y);menu.previewInput.hovered=true;menu.previewInput.pressed=true;menu:update(now,pc)
 point(x+.05,y-.2);menu:update(now+.01,pc);assert(menu.previewDrag)
end
local beforeCancel=osdWrites
startHPDrag(226);chooseSection(2,1);assert(not menu.previewDrag and osdWrites==beforeCancel)
menu.previewInput.pressed=false;menu:update(226.02,pc);chooseSection(2,2)
local navLive=true;menu.opts.navigationKeys=function()return navLive and {q=false,e=false,qSeq=0,eSeq=0}or nil end
startHPDrag(227);navLive=false;menu.previewInput.pressed=false;menu:update(227.02,pc)
assert(not menu.previewDrag and osdWrites==beforeCancel,'Focus/stale provider false cancels instead of committing on release')
navLive=true;menu:update(227.03,pc);menu.opts.navigationKeys=nil
startHPDrag(228);menu:close();assert(not menu.previewDrag and osdWrites==beforeCancel)
menu.previewInput.pressed=false;menu:requestOpen(228.1,pc);menu:update(228.11,pc)
assert(osdWrites==beforeCancel,'Opening cannot replay or save a cancelled drag')
startHPDrag(229);view.NavigationPanel:ClickMenuButton('Map');menu.previewInput.pressed=false;menu:update(229.02,pc)
assert(not menu.active and not menu.previewDrag and osdWrites==beforeCancel,'Native tab selection cancels an unfinished drag')
menu:requestOpen(229.1,pc);startHPDrag(230)
view.viewport=false;manager.OpenViews={};menu.previewInput.pressed=false;assert(not menu:update(230.02,pc))
assert(not menu.previewDrag and osdWrites==beforeCancel,'Actual PDA closing bypasses the 100ms discovery cache before any release save')
view.viewport=true;manager.OpenViews={view};menu:requestOpen(230.1,pc);startHPDrag(231)
menu.previewBody.geometryUnavailable=true;menu:update(231.02,pc)
assert(not menu.previewDrag and osdWrites==beforeCancel and not menu.updateError,'Missing pointer geometry cancels safely without tearing down the PDA')
menu.previewBody.geometryUnavailable=false;menu.previewInput.pressed=false;menu:update(231.03,pc)
startHPDrag(232);snapshot.osd.items[12].color=4;snapshot.osd.items[1].x=.123456789012345
menu.previewInput.pressed=false;menu:update(232.02,pc)
assert(snapshot.osd.items[12].color==4 and snapshot.osd.items[1].x==.123456789012345 and osdWrites==beforeCancel+1,
 'Position command contains only selected coordinates and preserves concurrent colors/precise sibling positions')
-- Real v51 QA produced this local body and HP pointer. The old900px hit box
-- rejected the visible lower half of the label even though native geometry succeeded.
local liveWidth,liveHeight=704.6590576171875,394.66571044921875
menu.previewBody.geometry={x=1165.558075,y=580.1650625,width=liveWidth,height=liveHeight,scale=1.25}
hp.x,hp.y,hp.size=.9,.09,14
snapshot.osd.enabled=false;snapshot.osd.selectedItemID=0
menu.nextRefresh=0;menu:update(233,pc)
local liveX,liveY=638.7535400390625/liveWidth,39.86795043945312/liveHeight
assert(osdModule.hit(snapshot.osd,liveX,liveY)~=11,'Fixture must expose the old default-dimension miss')
local hpText;for _,t in ipairs(menu.previewTexts)do if t.lastText:find('DRONE HP',1,true)then hpText=t end end
assert(hpText.widget.Font.Size==10 and hpText.widget.clipping==1,'Small real preview renders its local minimum font and clips only owned labels')
local liveWrites=osdWrites
point(liveX,liveY);menu.previewInput.hovered=true;menu.previewInput.pressed=true;menu:update(233.01,pc)
assert(snapshot.osd.selectedItemID==11 and menu.previewDrag and menu.previewDrag.id==11,
 'Exact real HP pointer selects its rendered lower half with master OSD off')
menu.previewInput.pressed=false;menu:update(233.02,pc)
assert(osdWrites==liveWrites,'A real HP click is selection only')
-- Retain a100x40 desktop-pixel drag at125% DPI, with a minimum-size Speed label.
local speed=snapshot.osd.items[1];speed.x,speed.y,speed.size=.12,.49,14
menu.nextRefresh=0;menu:update(233.03,pc)
point(.12,.4988);menu.previewInput.pressed=true;menu:update(233.04,pc)
assert(menu.previewDrag and menu.previewDrag.id==0,'Speed lower-half press starts the local draft')
local dragX,dragY=100/(liveWidth*1.25),40/(liveHeight*1.25)
point(.12+dragX,.4988+dragY);menu:update(233.05,pc)
assert(osdWrites==liveWrites and speed.x==.12 and speed.y==.49,'Held movement does not save')
menu.previewInput.pressed=false;menu:update(233.06,pc)
assert(osdWrites==liveWrites+1 and math.abs(speed.x-(.12+dragX))<1e-10 and math.abs(speed.y-(.49+dragY))<1e-10,
 'Final release saves the exact desktop movement divided by the real DPI/body extent once')
-- Slate point fonts can have a desired line height larger than our pixel estimate.
hp.x,hp.y=.64,.38;hpText.widget.desiredSize={X=170,Y=40};hpText.desiredWidth=nil
menu.nextRefresh=0;menu:update(234,pc)
local box=menu.previewLayout.bounds[12];local anchor=hpText.widget.Slot.anchors
assert(math.abs(box.width*liveWidth-170)<1e-10 and math.abs(box.height*liveHeight-40)<1e-10
 and anchor.Minimum.X==box.x and anchor.Minimum.Y==box.y
 and math.abs(anchor.Maximum.Y-anchor.Minimum.Y-box.height)<1e-10,'Measured drawing slot and hit rectangle are identical')
local lowerY=.38+18/liveHeight
assert(osdModule.hit(snapshot.osd,.64,lowerY,liveWidth,liveHeight)~=11,'Measured glyph must extend beyond the pure estimated rectangle')
point(.64,lowerY);menu.previewInput.pressed=true;menu:update(234.01,pc)
assert(menu.previewDrag and menu.previewDrag.id==11,'A rendered measured glyph can be selected outside the old estimate')
local outline=menu.previewOutline[1].Slot.anchors
assert(outline.Minimum.X==box.x and outline.Minimum.Y==box.y,'Selected outline uses the same measured bounds')
menu.previewInput.pressed=false;menu:update(234.02,pc)
local reads,prepasses=hpText.widget.desiredReads,hpText.widget.prepasses
menu.nextRefresh=0;menu:update(234.03,pc)
assert(hpText.widget.desiredReads==reads and hpText.widget.prepasses==prepasses,'Stable live refresh does not repeat text prepasses/measurements')
hpText.widget.desiredUnavailable=true;hpText.desiredWidth=nil
menu.nextRefresh=0;menu:update(234.04,pc)
assert(not hpText.desiredWidth,'An unavailable first Slate layout cannot become a permanent measured cache')
hpText.widget.desiredUnavailable=false;hpText.widget.desiredSize={X=180,Y=48}
menu.nextRefresh=0;menu:update(234.05,pc)
assert(hpText.desiredWidth==180 and hpText.desiredHeight==48 and hpText.widget.desiredReads==reads+2,
 'The next refresh retries a zero desired size and adopts the now-valid layout')
assert(osdWrites==liveWrites+1,'Measurements, redraw, click and fallback recovery never write layout preferences')
chooseSection(5,1)
assert(menu.rowWidgets[1].minus.widget.Slot.anchors.Minimum.X<.3,'Short labels no longer leave half a row empty before their values')
chooseSection(2,2)
-- A local OSD failure must not be replaced by an unrelated helper status.
menu.opts.osd.execute=function()return false,'OSD write failed'end
menu.osdRowWidgets[13].activate.action();assert(menu.feedback.lastText=='Не удалось сохранить настройки OSD.')
chooseSection(1,1);assert(menu.preview:GetVisibility()==1 and menu.sectionTabs[2].widget:GetVisibility()==1 and menu.sectionTabs[3].widget:GetVisibility()==1)
local choice=menu.rowWidgets[1]
local left,value,right=choice.minus.widget.Slot.anchors,choice.value.widget.Slot.anchors,choice.plus.widget.Slot.anchors
assert(left.Maximum.X<value.Minimum.X and value.Maximum.X<right.Minimum.X and right.Minimum.X-value.Maximum.X<.02,
 'Both arrows directly bracket the displayed choice, rather than the remaining row width')
assert(created==beforeInlineAllocations,'Scrolling, preview and settings do not allocate widgets during updates')
menu:close();assert(contexts[#contexts][1]==false,'Closing immediately releases headless owner context')
menu:destroy();assert(contexts[#contexts][1]==false)
-- Installed bindings may require a colon object path or loaded CDO lookup.
-- FindFirstOf can return an ordinary library instance; accept only the CDO.
local cdoSlate,cdoLayout=obj('Default__SlateBlueprintLibrary'),obj('Default__WidgetLayoutLibrary')
local ordinarySlate,ordinaryLayout=obj('SlateBlueprintLibrary'),obj('WidgetLayoutLibrary')
for _,name in ipairs({'SlateBlueprintLibrary','WidgetLayoutLibrary'})do
 missingUMG['/Script/UMG.Default__'..name]=true
 missingUMG['/Script/UMG:Default__'..name]=true
end
existingWidgets.SlateBlueprintLibrary={ordinarySlate,cdoSlate}
existingWidgets.WidgetLayoutLibrary={ordinaryLayout,cdoLayout}
FindFirstOf=function(name)return name=='SlateBlueprintLibrary'and ordinarySlate or ordinaryLayout end
local fallbackMenu=setup();assert(fallbackMenu:update(300,pc))
assert(fallbackMenu.slateLibrary==cdoSlate and fallbackMenu.layoutLibrary==cdoLayout,
 'Geometry libraries resolve loaded exact-name CDOs when both object paths fail; ordinary instances are rejected')
fallbackMenu:destroy();FindFirstOf=nil
do
 local guarded=setup();snapshot.osd=osdModule.defaults();snapshot.osd.selectedItemID=0
 assert(not snapshot.osd.preview and guarded:update(400,pc)and guarded:requestOpen(400,pc))
 local previewText=guarded.previewTexts[1].widget
 local textWrites=previewText.textWrites
 guarded:update(400.3,pc);guarded:update(400.6,pc)
 assert(not guarded.preview.geometryReads and not guarded.previewBody.geometryReads and previewText.textWrites==textWrites
  and not previewText.Slot.offsetWrites,
  'Other sections must not query hidden OSD geometry or render its preview')
 guarded.sidebar[2].action();guarded.sectionTabs[2].action()
 assert(guarded.preview:GetVisibility()==4 and guarded.preview.geometryReads==1 and guarded.previewBody.geometryReads==1
  and guarded.previewLayout.width==640 and previewText.textWrites>textWrites and previewText.Slot.offsetWrites==1,
  'First OSD entry renders using actual geometry without precomputed snapshot primitives')
 guarded.previewBody.geometry={x=0,y=0,width=800,height=450,scale=1}
 guarded.nextRefresh=0;guarded:update(401,pc)
 assert(guarded.previewLayout.width==800 and guarded.previewLayout.height==450 and guarded.previewBody.geometryReads==2,
  'Visible OSD refresh still adopts resized geometry')
 guarded.sidebar[1].action()
 local outerReads,bodyReads=guarded.preview.geometryReads,guarded.previewBody.geometryReads
 textWrites=previewText.textWrites
 local offsetWrites=previewText.Slot.offsetWrites
 guarded:update(401.3,pc);guarded:update(401.6,pc)
 assert(guarded.preview:GetVisibility()==1 and guarded.preview.geometryReads==outerReads
  and guarded.previewBody.geometryReads==bodyReads and previewText.textWrites==textWrites and previewText.Slot.offsetWrites==offsetWrites,
  'Leaving OSD stops geometry queries and rendering on subsequent settings refreshes')
 guarded:destroy()
end
print('PASS native PDA ownership, bounded15 reusable rows, vertical ScrollBox/wheel/keyboard/offset retention, no pagination, relevant combat slots/no stale slider replay, Q/E capture safety, inline settings, compact OSD inspector, exact live HP point/local dimensions, measured Slate text draw/hit/outline bounds and retry/cache, DPI grab-offset drag/final release, local draft/no replay, focus/close cancellation and responsive preview size')
