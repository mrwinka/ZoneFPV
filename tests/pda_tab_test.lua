-- Reflected adapter/lifecycle contract; native row fit still needs in-game QA.
local methods,serial={},0
local fixture,creates,searches,logs= nil,0,0,{}
function methods:IsValid()return not self.dead end
function methods:GetAddress()return self.id end
function methods:IsAnyClass()return self.classObject==true end
function methods:GetClass()return self.class end
function methods:GetFName()return {ToString=function()return self.name end}end
function methods:GetAllChildren()return self.children or {}end
function methods:GetVisibility()return self.visibility or 0 end
function methods:GetRenderOpacity()return self.opacity or 1 end
function methods:GetColorAndOpacity()assert(not self.noGetter,'Getter is not reflected');return self.color end
function methods:SetColorAndOpacity(v)assert(not self.failColor,'Unsupported color');self.color=v;self.ColorAndOpacity=v;self.changed=(self.changed or 0)+1 end
function methods:SetFont(v)assert(not self.failFont,'Unsupported font');self.Font=v;self.changed=(self.changed or 0)+1 end
function methods:SetText(v)assert(not self.failText,'Unsupported text');self.text=v;self.changed=(self.changed or 0)+1 end
function methods:SetVisibility(v)assert(not self.failVisibility,'Unsupported visibility');self.visibility=v;self.changed=(self.changed or 0)+1 end
function methods:SetRenderOpacity(v)self.opacity=v end
function methods:SetBrush(v)self.Brush=v end
function methods:RemoveFromParent()
    self.removed=(self.removed or 0)+1
    if self.parent then
        for i,v in ipairs(self.parent.children)do if v==self then table.remove(self.parent.children,i);break end end
    end
    self.parent=nil
end
local function obj(name)
    serial=serial+1;return setmetatable({name=name,id=serial},{__index=methods})
end
local keys={'Padding','Size','HorizontalAlignment','VerticalAlignment'}
local slotClass=obj('HorizontalBoxSlot');slotClass.classObject=true
for _,k in ipairs(keys)do
    methods['Set'..k]=function(self,v)
        assert(not self.failSetters,'Unsupported reflected setter');self[k]=v
    end
end
local function slot()
    local s=obj('HorizontalBoxSlot');s.class=slotClass
    s.Padding={Left=9,Top=3,Right=9,Bottom=2};s.Size={SizeRule=0,Value=.83};s.HorizontalAlignment=2;s.VerticalAlignment=1
    return s
end
local inactive={SpecifiedColor={R=.7,G=.65,B=.6,A=1},ColorUseRule=0}
local active={SpecifiedColor={R=.96,G=.4,B=.11,A=1},ColorUseRule=0}
local font={Size=21,FontObject=obj('CookedFont'),TypefaceFontName='Condensed',OutlineSettings={OutlineSize=1}}
local nativeStyles={PDAHover={Font=font,ColorAndOpacity=active},PDAUnHover={Font=font,ColorAndOpacity=inactive}}
local defaultStyle={Font={Size=12,TypefaceFontName='Default'},ColorAndOpacity={SpecifiedColor={R=1,G=0,B=.5,A=1},ColorUseRule=0}}
local function nativeTab(class,isSelected)
    local w=obj('NativePDATab');w.class=class;w.Slot=slot()
    w.Button=obj('Button');w.ButtonText=obj('CommonText');w.ButtonText.CommonTextObj=obj('TextBlock')
    w.ButtonText.CommonTextObj.Font=font;w.ButtonText.CommonTextObj.color=isSelected and active or inactive
    w.ButtonText.CommonTextObj.ColorAndOpacity=w.ButtonText.CommonTextObj.color
    w.SelectLine=obj('Image');w.SelectLine.visibility=isSelected and 0 or 2;w.Notify=obj('Notify')
    w.SelectLine.opacity=isSelected and 1 or 0;w.SelectLine.Brush={ResourceObject=obj('NativePDASelectionGlow')}
    w.SetStyleIdHover='PDAHover';w.SetStyleIdUnHover='PDAUnHover';w.bEnableSelectAnimation=true
    w.ButtonText.bEnableStyleManager=true;w.ButtonText.bUseWrappingFromStyle=true;w.ButtonText.DefaultWrapText=170
    w.ButtonText.TextSettings={FontStyleId='PDAUnHover',FontStyle=nativeStyles.PDAUnHover}
    w.ButtonText.TextScaleSettings={MaxFontScale=1,MinFontScale=.8}
    w.ButtonId='Native'..w.id;w.DisplayText='Native text';return w
end
function methods:AddChild(w)
    assert(self==fixture.container,'Only native SlotContainer may parent the clone')
    assert(w.SelectLine.visibility==2,'Clone enters native navigation unselected')
    w.parent=self;self.children[#self.children+1]=w;w.Slot=slot()
    if fixture.proxySlots then w.Slot.failSetters=true end
    if fixture.failSlot then
        w.Slot.failSetters=true
        setmetatable(w.Slot,{__index=methods,__newindex=function(_,k)error('Slot write blocked: '..k)end})
        for _,k in ipairs(keys)do w.Slot[k]=nil end
    end
    if fixture.failParent then error('Parent failure after attachment')end
    return w.Slot
end
function methods:Create(context,class,owner)
    creates=creates+1
    assert(self==fixture.lib and context==fixture.pc and owner==fixture.pc and class==fixture.class,'Create needs real cooked class and owning controller')
    if fixture.factoryThrows then error('Create unsupported')end
    if fixture.returnSibling then return fixture.siblings[1]end
    if fixture.returnSiblingWrapper then
        local w=nativeTab(class,false);w.id=fixture.siblings[1].id;fixture.clone=w;return w
    end
    if fixture.returnInvalid then local w=obj('Invalid');w.dead=true;return w end
    local w=nativeTab(class,false);fixture.clone=w;w.lifecycle=true
    w.SetStyleIdHover='CookedDefaultHover';w.SetStyleIdUnHover='CookedDefaultUnHover';w.bEnableSelectAnimation=false
    w.ButtonText.TextSettings={FontStyleId='CookedDefault',FontStyle=defaultStyle}
    w.ButtonText.TextScaleSettings={MaxFontScale=2};w.ButtonText.DefaultWrapText=0
    w.ButtonText.CommonTextObj.noGetter=fixture.noGetter
    w.ButtonText.CommonTextObj.ColorAndOpacity=fixture.directTint and inactive or nil
    if fixture.styleTint then w.ButtonText.TextSettings={FontStyle={ColorAndOpacity=inactive}}end
    if fixture.nativeStyleOnly then w.ButtonText.TextSettings=nil end
    if fixture.missingClone then
        if fixture.missingClone=='CommonTextObj'then w.ButtonText.CommonTextObj=nil else w[fixture.missingClone]=nil end
    end
    if fixture.failText then w.ButtonText.failText=true end
    if fixture.failColor then w.ButtonText.CommonTextObj.failColor=true end
    if fixture.noFont then w.ButtonText.CommonTextObj.failFont=true end
    return w
end
FText=function(v)return 'Text:'..v end;FName=function(v)return 'Name:'..v end
StaticConstructObject=function()error('UserWidgets must use WidgetBlueprintLibrary.Create')end
StaticFindObject=function(path)
    assert(path=='/Script/UMG.Default__WidgetBlueprintLibrary'or path=='/Script/UMG:Default__WidgetBlueprintLibrary')
    if fixture.pathMissing then return nil end
    return fixture.lib
end
FindFirstOf=function(name)assert(name=='WidgetBlueprintLibrary');searches=searches+1;return fixture.first end
FindAllOf=function(name)assert(name=='WidgetBlueprintLibrary');searches=searches+1;return fixture.libraries or {}end
local function setup(count)
    fixture={};creates=0;searches=0;logs={}
    fixture.pc=obj('Controller');fixture.class=obj('W_ActualNavigation_C');fixture.class.classObject=true
    fixture.lib=obj('Default__WidgetBlueprintLibrary');fixture.view=obj('PDAView');fixture.view.Switcher=obj('Switcher')
    fixture.view.NavigationPanel=obj('NavigationPanel');fixture.container=obj('HorizontalBox');fixture.container.children={}
    fixture.view.NavigationPanel.SlotContainer=fixture.container;fixture.siblings=fixture.container.children
    for _=1,count or 6 do
        local w=nativeTab(fixture.class,#fixture.siblings==0);w.parent=fixture.container;fixture.siblings[#fixture.siblings+1]=w
    end
    fixture.module=dofile('mod/Scripts/pda_tab.lua');return fixture
end
local function create()return fixture.module.new(fixture.view,fixture.pc,function(v)logs[#logs+1]=v end)end
local function nativeUnchanged(f,count)
    assert(#f.container.children==count,'All native tabs must remain')
    for i=1,count do
        local w=f.siblings[i]
        assert(w.parent==f.container and not w.removed and not w.changed and not w.ButtonText.changed and not w.ButtonText.CommonTextObj.changed and not w.SelectLine.changed and not w.Notify.changed,'Native tab mutated')
    end
    assert(not f.view.Switcher.changed and not f.view.Switcher.removed,'Switcher must not be touched by tab clone')
end
local f=setup();local tab,err=create();assert(tab,err)
assert(creates==1 and tab.widget.lifecycle and tab.button==tab.widget.Button and tab.widget.parent==f.container)
assert(tab.widget.bEnableLocalisation==false and tab.widget.ButtonLocalizationSID=='' and tab.widget.bEnableSelectAnimation==true)
assert(tab.widget.SetStyleIdHover=='PDAHover'and tab.widget.SetStyleIdUnHover=='PDAUnHover')
assert(tab.widget.ButtonText.TextSettings==f.siblings[1].ButtonText.TextSettings
    and tab.widget.ButtonText.TextScaleSettings==f.siblings[1].ButtonText.TextScaleSettings
    and tab.widget.ButtonText.bEnableStyleManager==f.siblings[1].ButtonText.bEnableStyleManager)
assert(tab.widget.DisplayText==FText('ZoneFPV')and tab.widget.ButtonId==FName('ZoneFPV')and tab.widget.ButtonText.text==FText('ZoneFPV'))
assert(tab.widget.Notify.visibility==2 and tab.widget.SelectLine.visibility==2
    and tab.widget.ButtonText.CommonTextObj.color.SpecifiedColor.R==inactive.SpecifiedColor.R
    and tab.widget.ButtonText.CommonTextObj.color.ColorUseRule==inactive.ColorUseRule)
assert(tab.widget.ButtonText.CommonTextObj.Font==font,'Reuse complete exact native font proxy')
local selectedSibling
for _,w in ipairs(f.siblings)do if w.SelectLine.visibility==0 then selectedSibling=w;break end end
assert(tab.widget.SelectLine.Brush==selectedSibling.SelectLine.Brush,'Use the native selected glow resource')
local function nativeStyleEvent(hover,selection)
    local style=nativeStyles[hover and tab.widget.SetStyleIdHover or tab.widget.SetStyleIdUnHover]or defaultStyle
    tab.widget.ButtonText.CommonTextObj:SetFont(style.Font)
    tab.widget.ButtonText.CommonTextObj:SetColorAndOpacity(style.ColorAndOpacity)
    tab.widget.SelectLine:SetVisibility(selection and 0 or 2)
    tab.widget.SelectLine:SetRenderOpacity(selection and tab.widget.bEnableSelectAnimation and 1 or 0)
end
for _=1,20 do
    nativeStyleEvent(true,false)
    assert(tab.widget.ButtonText.CommonTextObj.Font==font and tab.widget.ButtonText.CommonTextObj.color==active,
        'Native hover style replay must retain the condensed font and bright color')
    nativeStyleEvent(true,true);assert(tab:isSelected(),'Native selection animation must make its glow visible')
    nativeStyleEvent(false,false);assert(not tab:isSelected()and tab.widget.ButtonText.CommonTextObj.color==inactive)
end
for _,k in ipairs(keys)do assert(tab.widget.Slot[k]==f.siblings[1].Slot[k],'Copy exact native slot '..k)end
assert(create()==tab and creates==1,'Repeated binding must reuse its own tab')
for _=1,100 do assert(tab:setActive(true));assert(tab:setActive(false))end
assert(creates==1 and tab.widget.SelectLine.visibility==2,'Selection must never allocate widgets')
assert(tab:setActive(true)and tab.widget.ButtonText.CommonTextObj.color.SpecifiedColor.R==active.SpecifiedColor.R
    and tab.widget.ButtonText.CommonTextObj.color.SpecifiedColor.G==active.SpecifiedColor.G,'Capture selected native text style')
assert(tab:isSelected());tab.widget.SelectLine.visibility=2;assert(not tab:isSelected(),'Observe native selection changes, not cached active flag')
assert(tab:setActive(true)and tab:isSelected(),'Explicit selection can restore the line after native transition changed it')
for _,v in ipairs({0,3,4})do tab.widget.SelectLine.visibility=v;assert(tab:isSelected())end
for _,v in ipairs({1,2,5})do tab.widget.SelectLine.visibility=v;assert(not tab:isSelected())end
tab.widget.SelectLine.visibility=0;tab.widget.SelectLine.opacity=0;assert(not tab:isSelected());tab.widget.SelectLine.opacity=1
tab:destroy();tab:destroy();assert(tab.widget.removed==1 and not tab:setActive(true));nativeUnchanged(f,6)
tab=assert(create());assert(creates==2,'Explicit destroy permits a fresh binding');tab:destroy();nativeUnchanged(f,6)
f=setup(7);tab=assert(create());assert(#f.container.children==8,'Adding a seventh/eighth tab must not replace natives');tab:destroy();nativeUnchanged(f,7)
f=setup();f.proxySlots=true;f.noFont=true;tab=assert(create());for _,k in ipairs(keys)do assert(tab.widget.Slot[k]==f.siblings[1].Slot[k])end;tab:destroy();nativeUnchanged(f,6)
f=setup();for _,w in ipairs(f.siblings)do w.SelectLine.visibility=2 end
tab=assert(create());assert(tab:setActive(true));assert(tab.widget.ButtonText.CommonTextObj.color.SpecifiedColor.R==1,'Amber fallback is permitted only for unavailable selected color');tab:destroy()
for _,missing in ipairs({'Button','ButtonText','CommonTextObj','SelectLine','Notify'})do
    f=setup();f.missingClone=missing
    local value,message=create();assert(not value and message:find('missing bound native children',1,true)and creates==1)
    assert(f.clone.removed==1);nativeUnchanged(f,6)
    create();assert(creates==1,'Failed lifecycle must not repeat Create')
end
for _,failure in ipairs({'failText','failColor','failParent','failSlot','factoryThrows'})do
    f=setup();f[failure]=true
    local value,message=create();assert(not value and type(message)=='string'and #logs==1)
    if f.clone then assert(f.clone.removed==1,'Failed clone must be detached once')end
    nativeUnchanged(f,6);create();assert(creates==1,'Failed construction is allocation-circuit-broken')
end
f=setup();f.returnSibling=true;assert(not create());nativeUnchanged(f,6)
f=setup();f.returnSiblingWrapper=true;assert(not create()and not f.clone.removed);nativeUnchanged(f,6)
f=setup();f.siblings[1].visibility=2
f.siblings[2].Slot.Padding={Left=31,Top=0,Right=31,Bottom=0}
tab=assert(create());assert(tab.widget.Slot.Padding==f.siblings[2].Slot.Padding,'Hidden Bestiary must not supply the row layout')
tab:destroy();nativeUnchanged(f,6)
for _,mode in ipairs({'directTint','styleTint','nativeStyleOnly'})do
    f=setup();f.noGetter=true;f[mode]=true
    for _,w in ipairs(f.siblings)do
        w.ButtonText.CommonTextObj.noGetter=true
        local tint=w.SelectLine.visibility==0 and active or inactive
        if mode=='directTint'then w.ButtonText.CommonTextObj.ColorAndOpacity=tint end
        if mode~='directTint'then w.ButtonText.CommonTextObj.ColorAndOpacity=nil end
        if mode=='styleTint'then w.ButtonText.TextSettings={FontStyle={ColorAndOpacity=tint}}end
        if mode=='nativeStyleOnly'then w.ButtonText.TextSettings=nil end
    end
    tab=assert(create());assert(tab.widget.parent==f.container,'Unavailable getter must not hide the native tab')
    assert(tab:setActive(true)and tab:isSelected());assert(tab:setActive(false))
    if mode~='nativeStyleOnly'then
        assert(tab.widget.ButtonText.CommonTextObj.color.SpecifiedColor.R==inactive.SpecifiedColor.R,'Copy the reflected inactive style')
    end
    tab:destroy();nativeUnchanged(f,6)
end
f=setup();f.returnInvalid=true;assert(not create()and creates==1);nativeUnchanged(f,6)
f=setup();f.class.classObject=false;assert(not create()and creates==0);f.class.classObject=true;tab=assert(create());tab:destroy()
f=setup();for _,w in ipairs(f.siblings)do w.ButtonText.CommonTextObj=nil end
assert(not create()and creates==0,'An incomplete native template cannot supply a cooked lifecycle')
f=setup();f.pathMissing=true;assert(not create()and creates==0);f.first=f.lib;tab=assert(create());assert(searches>=3);tab:destroy()
f=setup();f.pathMissing=true;f.first=obj('WrongWidgetBlueprintLibrary');local indexed=0
f.libraries=setmetatable({GetArrayNum=function()return 100 end,ForEach=function()error('Unsafe TArray iterator')end},{__index=function(_,i)
    indexed=indexed+1;assert(i<=4,'Library fallback must inspect at most four objects')
    if i==4 then return {type=function()return 'RemoteUnrealParam'end,get=function()return f.lib end}end
    return obj('WrongCDO')
end})
tab=assert(create());assert(indexed==4 and creates==1);tab:destroy()
f=setup();f.pathMissing=true;f.first=obj('WrongWidgetBlueprintLibrary');f.libraries={obj('Other1'),obj('Other2'),obj('Other3'),obj('Other4'),f.lib}
assert(not create()and creates==0,'A library beyond the bounded fallback is not searched')
for _,n in ipairs({-1,1.5,65})do
    f=setup();f.container.GetAllChildren=function()return {GetArrayNum=function()return n end,ForEach=function()error('Unsafe TArray iterator')end}end
    assert(not create()and creates==0,'Invalid native child count must reject before allocation')
end
f=setup(64);assert(not create()and creates==0,'64 native children leave no bounded insertion capacity');nativeUnchanged(f,64)
f=setup();for _,w in ipairs(f.siblings)do w.Slot.class=obj('CanvasPanelSlot')end
assert(not create()and creates==0,'Fixed-position native slots must fail before creating an overlapping tab');nativeUnchanged(f,6)
f=setup();local original=f.siblings
f.container.GetAllChildren=function()return {GetArrayNum=function()return #original end,ForEach=function()error('Unsafe TArray iterator')end,
    [1]={type=function()return 'RemoteUnrealParam'end,get=function()return original[1]end},[2]=original[2],[3]=original[3],[4]=original[4],[5]=original[5],[6]=original[6]}end
tab=assert(create());tab:destroy();nativeUnchanged(f,6)
f=setup();f.view.NavigationPanel.SlotContainer=nil;assert(not create()and creates==0,'No floating-button fallback')
print('PASS native PDA tab cooked Create lifecycle, exact style/layout copy, bounded discovery, owned cleanup and allocation circuit breaker')
