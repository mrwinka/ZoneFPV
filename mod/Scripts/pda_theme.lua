-- Sample only the already-created PDA. This module never creates widgets,
-- loads assets or changes native controls; the owner supplies its new widgets.
local M={}
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return o~=nil and call(o,'IsValid')==true end
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
local function textTint(label)
    return linear(read(read(label,'CommonTextObj'),'ColorAndOpacity'))
        or linear(read(read(read(label,'TextSettings'),'FontStyle'),'ColorAndOpacity'))
        or linear(read(label,'ColorAndOpacity'))
end
local function isVisible(widget)
    local visibility=call(widget,'GetVisibility')
    return valid(widget)and visibility~=1 and visibility~=2
end
local function lineSelected(widget)
    local line=read(widget,'SelectLine');local v=call(line,'GetVisibility')
    return valid(line)and (v==0 or v==3 or v==4)and (call(line,'GetRenderOpacity')or 1)>.01
end
local function set(widget,method,value)widget[method](widget,value)end
function M.new(view)
    local theme={colors={text=color(.8,.78,.68),muted=color(.52,.51,.46),amber=color(1,.62,.18),
        page=color(.026,.028,.024),row=color(.037,.039,.033),rowActive=color(.085,.073,.045),
        transparent=color(0,0,0,0),hover=color(.28,.24,.15,.18),controlActive=color(.28,.24,.15,.08)},sampledWidgets=0}
    local tabs=read(read(view,'NavigationPanel'),'SlotContainer')
    local gotInactive,gotActive=false,false
    eachChild(tabs,function(tab)
        if not isVisible(tab)then return end
        local id=read(tab,'ButtonId')
        id=type(id)=='string'and id or call(id,'ToString')
        if id=='ZoneFPV'or id=='Name:ZoneFPV'then return end
        local label=read(tab,'ButtonText');if not valid(label)then return end
        theme.tabFont=theme.tabFont or fontOf(label)
        local tint=textTint(label)
        if tint and lineSelected(tab)and not gotActive then theme.colors.amber=tint;gotActive=true
        elseif tint and not lineSelected(tab)and not gotInactive then theme.colors.text=tint;gotInactive=true end
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
    local i=1
    while i<=#queue do
        local widget=queue[i];i=i+1;theme.sampledWidgets=theme.sampledWidgets+1
        if isVisible(widget)then
            theme.bodyFont=theme.bodyFont or fontOf(widget)
            local name=call(call(widget,'GetFName'),'ToString')
            if not theme.pageBrush and type(name)=='string'and name:lower():find('background',1,true)then
                local tint=linear(read(widget,'BrushColor'))or linear(read(widget,'ColorAndOpacity'))
                local brush=read(widget,'Brush')
                if brush and tint and tint.A>=.5 and math.max(tint.R,tint.G,tint.B)<.2 then
                    theme.pageBrush=brush;theme.colors.page=tint
                end
            end
        end
        enqueue(read(read(widget,'WidgetTree'),'RootWidget'));eachChild(widget,enqueue)
    end
    theme.font=theme.tabFont or theme.bodyFont
    theme.bodyFont=theme.bodyFont or theme.font
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
            set(widget,'SetColorAndOpacity',active and self.colors.amber or self.colors.text)
        end)
    end
    function theme:page(widget)
        return pcall(function()
            assert(valid(widget),'PDA page backing unavailable')
            if self.pageBrush then pcall(set,widget,'SetBrush',self.pageBrush)end
            set(widget,'SetBrushColor',self.colors.page)
        end)
    end
    return theme
end
return M
