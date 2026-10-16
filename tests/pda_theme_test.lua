-- Font transfer models the engine's by-value FSlateFontInfo setter.
local M=dofile('mod/Scripts/pda_theme.lua')
local newTheme,themeBuilds=M.new,0
M.new=function(...)themeBuilds=themeBuilds+1;return newTheme(...)end
local methods={}
function methods:IsValid()return not self.dead end
function methods:GetVisibility()return self.visibility or 0 end
function methods:GetRenderOpacity()return self.opacity or 1 end
function methods:GetAllChildren()return self.children or {}end
function methods:GetActiveWidget()return self.active end
function methods:GetFName()return {ToString=function()return self.name end}end
function methods:GetFullName()return self.fullName or self.name end
function methods:GetClass()return self.class end
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
local assetLookups={}
StaticFindObject=function(path)assetLookups[path]=(assetLookups[path]or 0)+1;return nil end
LoadAsset=function(path)assetLookups[path]=(assetLookups[path]or 0)+1;return nil end
FName=setmetatable({},{__call=function(_,name)return {ToString=function()return name end}end})
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
    local background=obj('PageBackground');background.BrushColor={R=.021,G=.024,B=.018,A=1}
    local texture=obj('PDAPageNoise');texture.fullName='Texture2D /Game/GameLite/FPS_Game/UIRemaster/UITextures/PDA/T_PageNoise.T_PageNoise'
    background.Brush={ResourceObject=texture,DrawAs=1,TintColor={SpecifiedColor={R=.35,G=.35,B=.35,A=1},ColorUseRule=0}}
    page.WidgetTree=obj('WidgetTree');page.WidgetTree.RootWidget=obj('PageRoot');page.WidgetTree.RootWidget.children={body,background}
    return view,native,tabFont,bodyFont,background
end
local view,native,font,bodyFont,background=setup();local theme=M.new(view)
local function linear(byte)local value=byte/255;return value<=.04045 and value/12.92 or ((value+.055)/1.055)^2.4 end
local function expected(actual,r,g,b)
    assert(math.abs(actual.R-linear(r))<1e-9 and math.abs(actual.G-linear(g))<1e-9 and math.abs(actual.B-linear(b))<1e-9)
end
assert(theme.font==font and theme.tabFont==font and theme.bodyFont==bodyFont)
expected(theme.colors.text,202,191,176);expected(theme.colors.amber,243,143,1);expected(theme.colors.page,22,17,16)
expected(theme.colors.heading,227,223,205);expected(theme.colors.muted,159,162,153);expected(theme.colors.footer,30,28,27)
expected(theme.colors.tabActive,202,191,176);expected(theme.colors.tabText,63,55,50)
assert(theme.colors.page.R<.01 and theme.colors.page.R>theme.colors.page.G and theme.colors.page.G>theme.colors.page.B,'Fallback matches the native reddish charcoal instead of green/olive black')
local function luminance(c)return .2126*c.R+.7152*c.G+.0722*c.B end
local selectedLuminance=luminance(theme.colors.rowActive)*theme.colors.rowActive.A+luminance(theme.colors.page)*(1-theme.colors.rowActive.A)
assert((luminance(theme.colors.text)+.05)/(selectedLuminance+.05)>7,'Cream captions stay readable over the subtle translucent selection')
assert((luminance(theme.colors.amber)+.05)/(selectedLuminance+.05)>4.5,'Amber values retain text contrast over selection')
assert(theme.colors.rowActive.A<=.1,'Selected rows leave the native texture visible instead of a solid amber block')
local label=obj('OwnLabel');label.Font={Size=12};assert(theme:label(label,19))
assert(font.Size==25 and bodyFont.Size==16,'Source font structs remain untouched')
assert(label.Font.Size==19 and label.Font.FontObject==font.FontObject and label.Font.FontMaterial==font.FontMaterial)
assert(label.Font.OutlineSettings.OutlineMaterial==font.OutlineSettings.OutlineMaterial and label.Font.FutureNativeField.Keep,'Copy complete font info including unknown/native fields')
assert(label.Font.OutlineSettings.OutlineSize==0 and font.OutlineSettings.OutlineSize==1,'Remove faux-bold outline only in the owned font copy')
assert(label.ColorAndOpacity.SpecifiedColor.R==theme.colors.text.R)
local body=obj('OwnBody');body.Font={Size=12};assert(theme:label(body,17,theme.colors.muted,'body'));assert(body.Font.FontObject==bodyFont.FontObject and body.Font.Size==17)
local button=obj('OwnButton');button.WidgetStyle={Normal={DrawAs=1},Hovered={DrawAs=1},Pressed={DrawAs=1},Disabled={DrawAs=1},
    NormalPadding={Left=7},PressedSlateSound={ResourceObject=obj('OwnClickSound')},FutureStyleField={Keep=true}}
local ownStyle,ownSound=button.WidgetStyle,button.WidgetStyle.PressedSlateSound.ResourceObject
assert(theme:button(button,false,false)and button.background.A==0)
assert(button.WidgetStyle==ownStyle and button.WidgetStyle.NormalPadding.Left==7 and button.WidgetStyle.FutureStyleField.Keep)
assert(button.WidgetStyle.PressedSlateSound.ResourceObject==ownSound,'Keep owned padding, sounds and extra fields')
assert(theme:button(button,true,false)and button.background.A==0 and button.ColorAndOpacity.R==1 and button.ColorAndOpacity.G==1)
assert(button.ColorAndOpacity.B==1,'Button must not multiply the final child text color by a second cream/amber tint')
assert(theme:button(button,false,true)and button.background.A==0)
for _,state in ipairs({'Normal','Hovered','Pressed','Disabled'})do assert(button.WidgetStyle[state].DrawAs==0)end
assert(wholeStyleCalls==0,'No whole FButtonStyle parameter may reach a UFunction')
local backing=obj('OwnBacking');assert(theme:page(backing));assert(backing.Brush.ResourceObject==background.Brush.ResourceObject)
assert(backing.BrushColor.R==1 and backing.BrushColor.G==1 and backing.BrushColor.B==1,'An existing authored dark texture must retain neutral modulation')
assert(backing.Brush.TintColor.SpecifiedColor.R==1 and background.Brush.TintColor.SpecifiedColor.R==.35,'Normalize only our copied brush tint; borrowed native brush remains unchanged')
for _,tab in ipairs(native)do assert(not tab.writes and not tab.Button.writes and not tab.ButtonText.writes and not tab.ButtonText.CommonTextObj.writes and not tab.SelectLine.writes,'Theme never styles native sources')end
assert(not background.writes)
-- A table-backed test adapter that retains SetFont's parameter must also keep
-- native Font untouched when our target Size changes.
local retained=obj('RetainedArgument');retained.Font={Size=12};retained.SetFont=function(self,value)self.Font=value end
assert(theme:label(retained,22));assert(font.Size==25 and retained.Font.Size==22 and font.OutlineSettings.OutlineSize==1)
-- Shipping SDK's reflected TextSettings provides a second valid font/tint path.
view,native,font=setup();for _,tab in ipairs(native)do
    tab.ButtonText.CommonTextObj.Font=nil;tab.ButtonText.CommonTextObj.ColorAndOpacity=nil
    tab.ButtonText.TextSettings={FontStyle={Font=font,ColorAndOpacity={SpecifiedColor={R=.7,G=.69,B=.61,A=1},ColorUseRule=0}}}
end
theme=M.new(view);assert(theme.font==font);expected(theme.colors.text,202,191,176)
view,native,font,bodyFont=setup();bodyFont.TypefaceFontName='Bold'
theme=M.new(view);assert(theme.bodyFont==font,'An arbitrary bold native heading is never reused for prose')
local caption=obj('ControlCaption');caption.Font={Size=12};assert(theme:label(caption,16,nil,'control'))
assert(caption.Font.FontObject==font.FontObject,'Control captions keep the narrow native tab face instead of a wide body heading')
-- Native inactive and active colors can be nearly black or cream. They are
-- font sources only and cannot contaminate the field instrument palette.
view,native=setup()
for i,tab in ipairs(native)do tab.ButtonText.CommonTextObj.ColorAndOpacity={SpecifiedColor={R=i==1 and .8 or .008,G=.008,B=.008,A=1},ColorUseRule=0}end
theme=M.new(view);expected(theme.colors.text,202,191,176);expected(theme.colors.amber,243,143,1)
-- Installed UE4SS calls exact native texture classes Object /Script/...:...
-- too. Reuse their existing PDA backing without requiring a new asset load.
view,native,font,bodyFont,background=setup()
background.Brush.ResourceObject.fullName='Object /Game/GameLite/FPS_Game/UIRemaster/UITextures/PDA/T_PageNoise:T_PageNoise'
local textureClass=obj('Texture2DClass');textureClass.fullName='Object /Script/Engine:Texture2D'
background.Brush.ResourceObject.class=textureClass;theme=M.new(view)
assert(theme.pageBrush==background.Brush and theme.pageBrushPath:find('/UITextures/PDA/',1,true))
view,native,font,bodyFont,background=setup();background.Brush.ResourceObject.fullName='Texture2D /Game/Photos/T_Map.T_Map'
theme=M.new(view);assert(theme.pageBrush==nil,'Map/photograph assets cannot become the instrument backing')
view,native,font,bodyFont,background=setup();background.Brush.ResourceObject.fullName='Material /Game/GameLite/FPS_Game/UIRemaster/UITextures/PDA/M_Background.M_Background'
theme=M.new(view);assert(theme.pageBrush==nil,'Only exact native Texture2D backing assets can be borrowed')
view,native,font,bodyFont,background=setup()
view.Switcher.active.WidgetTree.RootWidget.children={}
view.WidgetTree=obj('BookTree');view.WidgetTree.RootWidget=obj('BookRoot');view.WidgetTree.RootWidget.children={background}
theme=M.new(view);assert(theme.pageBrush==background.Brush,'The existing cooked book backing is sampled even when its current page has no background')
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
assert(theme.font==font,'Sample fonts only from actual game tabs');expected(theme.colors.amber,243,143,1)
local subsection=obj('OwnSubsectionBacking')
subsection.Background={DrawAs=1,OutlineSettings={CornerRadii={X=0,Y=0,Z=0,W=0},RoundingType=1,Width=1}}
assert(theme:tabBacking(subsection,true,false))
expected(subsection.BrushColor,202,191,176)
assert(subsection.Background.DrawAs==4 and subsection.Background.OutlineSettings.CornerRadii.X==3)
assert(subsection.Background.OutlineSettings.Width==0 and wholeStyleCalls==0,'Rounded cream subsection uses only its own small brush fields')
assert((luminance(theme.colors.tabActive)+.05)/(luminance(theme.colors.tabText)+.05)>4.5,'Native selected cream subsection and brown type retain readable contrast')
for _=1,1000 do assert(theme:tabBacking(subsection,false,true))end
assert(subsection.BrushColor.A==theme.colors.hover.A and wholeStyleCalls==0)
-- Proven cooked assets work without depending on which PDA widgets happen
-- to be visible. Engine native classes may print the installed colon form.
local paths={
 background='/Game/GameLite/FPS_Game/UIRemaster/UITextures/PDA/PDAView/QuestBackground/T_pda_main_background.T_pda_main_background',
 control='/Game/GameLite/FPS_Game/UIRemaster/Fonts/Oswald.Oswald',
 body='/Game/GameLite/FPS_Game/UIRemaster/Fonts/Rubik.Rubik',
}
local provided={}
for key,path in pairs(paths)do
    local asset=obj(key);asset.fullName='Object '..path:gsub('%.([^./]+)$',':%1')
    asset.class=obj(key..'Class');asset.class.fullName='Object /Script/Engine:'..(key=='background'and 'Texture2D'or 'Font')
    provided[path]=asset
end
view,native,font,bodyFont=setup();theme=M.new(view,{assets=provided})
assert(theme.backgroundTexture==provided[paths.background]and theme.pageBrushPath==paths.background)
local deterministic=obj('DeterministicBacking')
function deterministic:SetBrushFromTexture(texture)self.Background={ResourceObject=texture,DrawAs=1,Tiling=0,ImageSize={X=32,Y=32}}end
assert(theme:page(deterministic)and theme.backgroundApplied)
assert(deterministic.Background.ResourceObject==provided[paths.background]and deterministic.Background.DrawAs==3 and deterministic.Background.Tiling==3)
assert(deterministic.Background.ImageSize.X==72 and deterministic.Background.ImageSize.Y==72,'Native grid keeps its authored pixel pitch instead of stretching across the page')
assert(deterministic.BrushColor.R==1 and deterministic.BrushColor.G==1,'Native backing retains neutral modulation instead of an olive tint')
local control=obj('DeterministicControl');control.Font={Size=12}
assert(theme:label(control,16,nil,'control'))
assert(control.Font.FontObject==provided[paths.control]and control.Font.TypefaceFontName:ToString()=='Regular')
local prose=obj('DeterministicProse');prose.Font={Size=12}
assert(theme:label(prose,13,nil,'body'))
assert(prose.Font.FontObject==provided[paths.body]and prose.Font.TypefaceFontName:ToString()=='Regular')
assert(font.FontObject~=provided[paths.control]and bodyFont.FontObject~=provided[paths.body],'Borrowed native font structs remain unchanged')
assert(theme.controlFontPath==paths.control and theme.bodyFontPath==paths.body,'Diagnostics name the actual selected cooked font assets')
provided[paths.background].class.fullName='Object /Script/Engine:Material'
theme=M.new(view,{assets=provided});assert(theme.backgroundTexture==nil,'A wrong-class object at the expected texture path is rejected')
for path,count in pairs(assetLookups)do
    local known=path=='/Script/Engine.Default__KismetSystemLibrary'or path=='/Script/Engine:Default__KismetSystemLibrary'
    for _,allowed in pairs(paths)do if path==allowed then known=true;assert(count%2==0 and count<=themeBuilds*2,'A missing skin asset is probed at most once per new build, never per repaint')end end
    assert(known,'No speculative/global asset lookup is allowed: '..path)
end
-- The real factory can be callable userdata. Only native FName values may
-- enter a reflected FNameProperty; a raw 'Regular' string is not accepted.
local originalFactory=FName
local function userdataWith(meta)
    local value=assert(io.tmpfile());assert(value:close());debug.setmetatable(value,meta);return value
end
local nativeNames=setmetatable({},{__mode='k'})
local regularName=userdataWith({__index={ToString=function()return 'Regular'end}});nativeNames[regularName]='Regular'
local calls=0
FName=userdataWith({__call=function(_,name)calls=calls+1;assert(name=='Regular');return regularName end,__metatable='protected callable FName factory'})
provided[paths.background].class.fullName='Object /Script/Engine:Texture2D'
theme=M.new(view,{assets=provided});assert(calls==1 and theme.regularFace==regularName)
local strict=obj('StrictFNamePropertyLabel');local assignments=0
function strict:SetFont(value)
    local backing=copy(value)
    self.Font=setmetatable({}, {__index=backing,__pairs=function()return pairs(backing)end,__newindex=function(_,key,newValue)
        if key=='TypefaceFontName'then assert(type(newValue)=='userdata'and nativeNames[newValue]=='Regular','FNameProperty requires a native FName userdata');assignments=assignments+1 end
        backing[key]=newValue
    end})
end
strict.Font={Size=12};assert(theme:label(strict,16,nil,'control'))
assert(assignments==1 and strict.Font.TypefaceFontName==regularName and calls==1,'One factory probe supplies all owned labels')
FName=nil;theme=M.new(view,{assets=provided});local inherited=obj('UnavailableFactoryLabel');inherited.Font={Size=12}
assert(theme:label(inherited,16,nil,'control'))
assert(inherited.Font.TypefaceFontName==font.TypefaceFontName and inherited.Font.FontObject==font.FontObject,'Unavailable FName factory retains the borrowed native face/family')
FName=originalFactory
-- Positive assets are revalidated and a failed startup lookup is not a
-- permanent false cache. Recycled-but-valid wrappers must be replaced too.
local ordinaryLookup=StaticFindObject;local lookups=0
StaticFindObject=function(path)lookups=lookups+1;return provided[path]end
theme=M.new(view);assert(theme.backgroundTexture==provided[paths.background])
local afterLoaded=lookups;M.new(view);assert(lookups==afterLoaded,'A current exact cached asset needs no additional native load')
local recycled=provided[paths.background];recycled.class.fullName='Object /Script/Engine:Material'
local replacement=obj('ReplacementBacking');replacement.fullName='Object '..paths.background:gsub('%.([^./]+)$',':%1')
replacement.class=obj('TextureClass');replacement.class.fullName='Object /Script/Engine:Texture2D';provided[paths.background]=replacement
theme=M.new(view);assert(theme.backgroundTexture==replacement and lookups==afterLoaded+1,'A valid-address wrong-class wrapper is retired from both caches before reloading')
replacement.dead=true
local later=obj('LaterBacking');later.fullName=replacement.fullName;later.class=replacement.class;provided[paths.background]=later
theme=M.new(view);assert(theme.backgroundTexture==later and lookups==afterLoaded+2,'Invalid cached asset recovers on the next bounded build')
StaticFindObject=ordinaryLookup
assert(not theme:label(obj('BadSize'),math.huge),'Reject invalid supplied sizes')
print('PASS native PDA reddish charcoal/cream/orange palette, tiled native backing, readable unmodulated child text, native fonts/source immutability and bounded safe styling')
