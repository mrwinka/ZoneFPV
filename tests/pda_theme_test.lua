-- Font transfer models the engine's by-value FSlateFontInfo setter.
local M=dofile('mod/Scripts/pda_theme.lua')
local methods={}
function methods:IsValid()return not self.dead end
function methods:GetVisibility()return self.visibility or 0 end
function methods:GetRenderOpacity()return self.opacity or 1 end
function methods:GetAllChildren()return self.children or {}end
function methods:GetActiveWidget()return self.active end
function methods:GetFName()return {ToString=function()return self.name end}end
local function obj(name)return setmetatable({name=name},{__index=methods})end
local function copy(value)
    if type(value)~='table'or value.IsValid then return value end
    local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
function methods:SetFont(value)self.Font=copy(value);self.writes=(self.writes or 0)+1 end
function methods:SetColorAndOpacity(value)self.ColorAndOpacity=copy(value);self.writes=(self.writes or 0)+1 end
function methods:SetBackgroundColor(value)self.background=copy(value);self.writes=(self.writes or 0)+1 end
function methods:SetBrushColor(value)self.BrushColor=copy(value);self.writes=(self.writes or 0)+1 end
function methods:SetBrush(value)self.Brush=copy(value);self.writes=(self.writes or 0)+1 end
local wholeStyleCalls=0
function methods:SetStyle(value)
    wholeStyleCalls=wholeStyleCalls+1
    error('Shipping bridge cannot marshal the oversized FButtonStyle parameter')
end
StaticConstructObject=function()error('Theme never creates widgets')end
StaticFindObject=function()error('Theme never loads assets')end
FindAllOf=function()error('Theme never scans UObject array')end
local function setup()
    local view=obj('PDAView');view.NavigationPanel=obj('NavigationPanel');view.NavigationPanel.SlotContainer=obj('TabRow')
    local fontAsset,material=obj('CookedCondensedFont'),obj('FontOutlineMaterial')
    local tabFont={FontObject=fontAsset,FontMaterial=obj('FontMaterial'),Size=25,TypefaceFontName='Condensed',LetterSpacing=1,
        OutlineSettings={OutlineSize=1,OutlineMaterial=material},FutureNativeField={Keep=true}}
    local bodyFont={FontObject=obj('CookedBodyFont'),Size=16,TypefaceFontName='Regular'}
    local beige={SpecifiedColor={R=.76,G=.74,B=.66,A=1},ColorUseRule=0}
    local amber={SpecifiedColor={R=.93,G=.57,B=.2,A=1},ColorUseRule=0}
    local native={}
    for i=1,6 do
        local tab=obj('NativeTab');tab.ButtonText=obj('TextWidget');tab.ButtonText.CommonTextObj=obj('CommonTextBlock')
        tab.Button=obj('NativeButton');tab.Button.WidgetStyle={Normal={DrawAs=0},Hovered={DrawAs=0},Pressed={DrawAs=0},Disabled={DrawAs=0},
            NormalPadding={Left=3,Top=2,Right=3,Bottom=2},PressedSlateSound={ResourceObject=obj('NativeClickSound')},FutureStyleField={Keep=true}}
        tab.ButtonText.CommonTextObj.Font=tabFont;tab.ButtonText.CommonTextObj.ColorAndOpacity=i==1 and amber or beige
        tab.SelectLine=obj('SelectLine');tab.SelectLine.visibility=i==1 and 0 or 2
        native[i]=tab
    end
    view.NavigationPanel.SlotContainer.children=native
    view.Switcher=obj('Switcher');local page=obj('JournalPage');view.Switcher.active=page
    local body=obj('BodyText');body.Font=bodyFont
    local background=obj('PageBackground');background.BrushColor={R=.021,G=.024,B=.018,A=1};background.Brush={ResourceObject=obj('PDAPageNoise'),DrawAs=1}
    page.WidgetTree=obj('WidgetTree');page.WidgetTree.RootWidget=obj('PageRoot');page.WidgetTree.RootWidget.children={body,background}
    return view,native,tabFont,bodyFont,background
end
local view,native,font,bodyFont,background=setup();local theme=M.new(view)
assert(theme.font==font and theme.tabFont==font and theme.bodyFont==bodyFont)
assert(theme.colors.text.R==.76 and theme.colors.amber.R==.93 and theme.colors.page.R==.021)
local label=obj('OwnLabel');label.Font={Size=12};assert(theme:label(label,19))
assert(font.Size==25 and bodyFont.Size==16,'Source font structs remain untouched')
assert(label.Font.Size==19 and label.Font.FontObject==font.FontObject and label.Font.FontMaterial==font.FontMaterial)
assert(label.Font.OutlineSettings.OutlineMaterial==font.OutlineSettings.OutlineMaterial and label.Font.FutureNativeField.Keep,'Copy complete font info including unknown/native fields')
assert(label.ColorAndOpacity.SpecifiedColor.R==.76)
local body=obj('OwnBody');body.Font={Size=12};assert(theme:label(body,17,theme.colors.muted,'body'));assert(body.Font.FontObject==bodyFont.FontObject and body.Font.Size==17)
local button=obj('OwnButton');button.WidgetStyle={Normal={DrawAs=1},Hovered={DrawAs=1},Pressed={DrawAs=1},Disabled={DrawAs=1},
    NormalPadding={Left=7},PressedSlateSound={ResourceObject=obj('OwnClickSound')},FutureStyleField={Keep=true}}
local ownStyle,ownSound=button.WidgetStyle,button.WidgetStyle.PressedSlateSound.ResourceObject
assert(theme:button(button,false,false)and button.background.A==0)
assert(button.WidgetStyle==ownStyle and button.WidgetStyle.NormalPadding.Left==7 and button.WidgetStyle.FutureStyleField.Keep)
assert(button.WidgetStyle.PressedSlateSound.ResourceObject==ownSound,'Keep owned padding, sounds and extra fields')
assert(theme:button(button,true,false)and button.background.A==0 and button.ColorAndOpacity.R==.93)
assert(theme:button(button,false,true)and button.background.A==0)
for _,state in ipairs({'Normal','Hovered','Pressed','Disabled'})do assert(button.WidgetStyle[state].DrawAs==0)end
assert(wholeStyleCalls==0,'No whole FButtonStyle parameter may reach a UFunction')
local backing=obj('OwnBacking');assert(theme:page(backing));assert(backing.Brush.ResourceObject==background.Brush.ResourceObject and backing.BrushColor.R==.021)
for _,tab in ipairs(native)do assert(not tab.writes and not tab.Button.writes and not tab.ButtonText.writes and not tab.ButtonText.CommonTextObj.writes and not tab.SelectLine.writes,'Theme never styles native sources')end
assert(not background.writes)
-- A table-backed test adapter that retains SetFont's parameter must also keep
-- native Font untouched when our target Size changes.
local retained=obj('RetainedArgument');retained.Font={Size=12};retained.SetFont=function(self,value)self.Font=value end
assert(theme:label(retained,22));assert(font.Size==25 and retained.Font.Size==22)
-- Shipping SDK's reflected TextSettings provides a second valid font/tint path.
view,native,font=setup();for _,tab in ipairs(native)do
    tab.ButtonText.CommonTextObj.Font=nil;tab.ButtonText.CommonTextObj.ColorAndOpacity=nil
    tab.ButtonText.TextSettings={FontStyle={Font=font,ColorAndOpacity={SpecifiedColor={R=.7,G=.69,B=.61,A=1},ColorUseRule=0}}}
end
theme=M.new(view);assert(theme.font==font and theme.colors.text.R==.7)
-- Invalid native arrays cannot induce an unbounded traversal or use ForEach.
view=obj('PDAView');view.Switcher=obj('Switcher');view.Switcher.active=obj('Page');view.Switcher.active.GetAllChildren=function()
    return {GetArrayNum=function()return 65 end,ForEach=function()error('Unsafe TArray callback')end}
end
theme=M.new(view);assert(theme.sampledWidgets==1 and theme.colors.page.A==1)
local plain=obj('FallbackLabel');plain.Font={Size=12};assert(theme:label(plain,16)and plain.Font.Size==16)
assert(theme:page(obj('FallbackBacking')))
local fallback=obj('FallbackButton');fallback.WidgetStyle={Normal={DrawAs=1},Hovered={DrawAs=1},Pressed={DrawAs=1},Disabled={DrawAs=1},NormalPadding={Left=5},FutureStyleField='retained'}
local oldStyle=fallback.WidgetStyle;assert(theme:button(fallback,true,true))
assert(fallback.WidgetStyle.Normal.DrawAs==0 and fallback.WidgetStyle.Hovered.DrawAs==0 and fallback.background.A==0,'Remove primitive bevel through complete own style')
assert(fallback.WidgetStyle==oldStyle and fallback.WidgetStyle.NormalPadding.Left==5 and fallback.WidgetStyle.FutureStyleField=='retained')
for _=1,1000 do assert(theme:button(fallback,true,true))end
assert(wholeStyleCalls==0,'Repeated hover and selection must never call the unsafe style setter')
-- Cyclic known widget trees stop at the fixed 128-widget budget.
view=obj('PDAView');view.Switcher=obj('Switcher');local root=obj('Root');view.Switcher.active=root
local previous=root
for i=1,180 do local child=obj('Child'..i);previous.children={child};previous=child end
previous.children={root};theme=M.new(view);assert(theme.sampledWidgets==128)
-- Use fresh bounded indexing and unwrap parameters returned by native arrays.
view,native,font=setup();view.NavigationPanel.SlotContainer.GetAllChildren=function()
    return {GetArrayNum=function()return 1 end,ForEach=function()error('Unsafe TArray callback')end,
        [1]={type=function()return 'RemoteUnrealParam'end,get=function()return native[1]end}}
end
theme=M.new(view);assert(theme.font==font)
-- An old custom tab must not contaminate the native font/highlight sample.
view,native,font=setup();native[1].SelectLine.visibility=2
local custom=obj('OldZoneFPV');custom.ButtonId={ToString=function()return 'ZoneFPV'end};custom.ButtonText=obj('OldTextWidget')
custom.ButtonText.CommonTextObj=obj('OldText');custom.ButtonText.CommonTextObj.Font={Size=12,TypefaceFontName='GenericDefault'}
custom.ButtonText.CommonTextObj.ColorAndOpacity={SpecifiedColor={R=1,G=0,B=.5,A=1},ColorUseRule=0}
custom.SelectLine=obj('OldLine');table.insert(native,1,custom);theme=M.new(view)
assert(theme.font==font and theme.colors.amber.G==.62,'Sample only actual game tabs')
assert(not theme:label(obj('BadSize'),math.huge),'Reject invalid supplied sizes')
print('PASS bounded PDA theme, native fonts, unchanged sources and transparent owned controls without oversized UFunction style parameters')
