-- Extend the real PDA navigation row with its own cooked UserWidget class.
-- Create runs the normal UUserWidget lifecycle; native siblings stay untouched.
local M={}
local owned=setmetatable({}, {__mode='k'})
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return o~=nil and call(o,'IsValid')==true end
local function same(a,b)
    if a==b then return true end
    if not valid(a)or not valid(b)then return false end
    local id=call(a,'GetAddress');return id~=nil and id==call(b,'GetAddress')
end
local function unwrap(v)
    local kind=call(v,'type')
    if kind=='RemoteUnrealParam'or kind=='LocalUnrealParam'then return call(v,'get')end
    return v
end
local function children(container)
    local array=call(container,'GetAllChildren')
    assert(array~=nil,'Native PDA navigation children unavailable')
    local result={}
    if type(array)=='table'and type(read(array,'GetArrayNum'))~='function'then
        assert(#array<=64,'Native PDA navigation exceeds 64 children')
        for i,v in ipairs(array)do assert(i<=64,'Native PDA navigation exceeds 64 children');result[i]=unwrap(v)end
    else
        local n=call(array,'GetArrayNum')
        assert(type(n)=='number'and n>=0 and n<=64 and n%1==0,'Native PDA navigation count outside 0..64')
        for i=1,n do result[i]=unwrap(array[i])end
    end
    return result
end
local function parts(widget)
    local button,label,line,notify=read(widget,'Button'),read(widget,'ButtonText'),read(widget,'SelectLine'),read(widget,'Notify')
    local text=read(label,'CommonTextObj')
    if valid(widget)and valid(button)and valid(label)and valid(text)and valid(line)and valid(notify)then
        return {button=button,label=label,text=text,line=line,notify=notify}
    end
end
local function selected(line)
    local v=call(line,'GetVisibility')
    return valid(line)and (v==0 or v==3 or v==4)and (call(line,'GetRenderOpacity')or 1)>.01
end
local function textColor(text,label)
    -- UCommonTextBlock inherits the reflected UTextBlock ColorAndOpacity
    -- property. The shipping game does not expose GetColorAndOpacity here.
    local function capture(tint)
        local c=read(tint,'SpecifiedColor')
        local result={}
        for _,k in ipairs({'R','G','B','A'})do
            local v=read(c,k)
            if type(v)~='number'or v~=v or v==math.huge or v==-math.huge then return end
            result[k]=v
        end
        local rule=read(tint,'ColorUseRule')
        if type(rule)~='number'then return end
        return {SpecifiedColor=result,ColorUseRule=rule}
    end
    return capture(read(text,'ColorAndOpacity'))
        or capture(read(read(read(label,'TextSettings'),'FontStyle'),'ColorAndOpacity'))
        or capture(call(text,'GetColorAndOpacity'))
end
local function defaultLibrary(o)
    return valid(o)and call(call(o,'GetFName'),'ToString')=='Default__WidgetBlueprintLibrary'
end
local function library()
    if type(StaticFindObject)=='function'then
        for _,path in ipairs({'/Script/UMG.Default__WidgetBlueprintLibrary','/Script/UMG:Default__WidgetBlueprintLibrary'})do
            local ok,o=pcall(StaticFindObject,path)
            if ok and defaultLibrary(o)then return o end
        end
    end
    if type(FindFirstOf)=='function'then
        local ok,o=pcall(FindFirstOf,'WidgetBlueprintLibrary')
        if ok and defaultLibrary(o)then return o end
    end
    if type(FindAllOf)=='function'then
        local ok,array=pcall(FindAllOf,'WidgetBlueprintLibrary')
        if ok and array then
            local n=type(array)=='table'and type(read(array,'GetArrayNum'))~='function'and #array or call(array,'GetArrayNum')
            if type(n)=='number'and n>=0 and n%1==0 then
                for i=1,math.min(n,4)do
                    local o=unwrap(read(array,i));if defaultLibrary(o)then return o end
                end
            end
        end
    end
end
M.library=library
local function set(o,k,...)
    local args=table.pack(...)
    local ok,err=pcall(function()o[k](o,table.unpack(args,1,args.n))end)
    assert(ok,k..': '..tostring(err))
end
local function slotValue(slot,k,value)
    -- Use the complete reflected structs, including FSlateChildSize, unchanged.
    local method='Set'..k
    local ok=pcall(function()slot[method](slot,value)end)
    if not ok then slot[k]=value end
end
local function copyField(target,source,key,log)
    local value=read(source,key)
    if value==nil then return false end
    -- Reflected struct assignment copies its complete native value into the
    -- clone; retain font assets and style IDs instead of a partial font setup.
    local ok,err=pcall(function()target[key]=value end)
    if not ok and type(log)=='function'then pcall(log,'Native PDA style copy unavailable for '..key..': '..tostring(err))end
    return ok,err
end
function M.new(view,controller,log)
    local previous=owned[view]
    if previous and previous.failure then return nil,previous.failure end
    if previous and not previous.destroyed and valid(previous.widget)then return previous end
    local widget,attempted,nativeWidget
    local ok,result=pcall(function()
        assert(valid(view)and valid(controller),'Native PDA view/controller unavailable')
        local container=read(read(view,'NavigationPanel'),'SlotContainer')
        assert(valid(container),'Native PDA navigation SlotContainer unavailable')
        local siblings=children(container)
        assert(#siblings<64,'Native PDA navigation has no bounded insertion capacity')
        local template,source,class,inactive,active,selectedSource
        for _,sibling in ipairs(siblings)do
            local p=parts(sibling)
            local cls=p and call(sibling,'GetClass')
            local visibility=call(sibling,'GetVisibility')
            if p and valid(cls)and call(cls,'IsAnyClass')==true and visibility~=1 and visibility~=2 then
                if not template and valid(read(sibling,'Slot'))then template,source,class=sibling,p,cls end
                local tint=textColor(p.text,p.label)
                if selected(p.line)then active=active or tint;selectedSource=selectedSource or p
                else inactive=inactive or tint end
            end
        end
        assert(template,'Complete native PDA tab template/class unavailable')
        local templateSlot=read(template,'Slot')
        assert(call(call(call(templateSlot,'GetClass'),'GetFName'),'ToString')=='HorizontalBoxSlot',
            'Native PDA tab needs a HorizontalBoxSlot for safe row insertion')
        local layout={}
        for _,k in ipairs({'Padding','Size','HorizontalAlignment','VerticalAlignment'})do
            layout[k]=read(templateSlot,k)
            assert(layout[k]~=nil,'Native PDA tab slot '..k..' unavailable')
        end
        local lib=library();assert(lib,'WidgetBlueprintLibrary default unavailable')
        attempted=true
        widget=lib:Create(controller,class,controller)
        assert(valid(widget),'Native PDA tab Create failed')
        for _,sibling in ipairs(siblings)do
            if same(widget,sibling)then nativeWidget=true;error('Create returned a native sibling')end
        end
        local clone=parts(widget)
        assert(clone,'Created PDA tab missing bound native children')
        widget.bEnableLocalisation=false
        widget.ButtonLocalizationSID=''
        widget.DisplayText=FText('ZoneFPV')
        widget.ButtonId=FName('ZoneFPV')
        for _,k in ipairs({'SetStyleIdHover','SetStyleIdUnHover','bEnableSelectAnimation'})do copyField(widget,template,k,log)end
        for _,k in ipairs({'TextSettings','TextScaleSettings','bEnableStyleManager','bUseWrappingFromStyle','DefaultWrapText'})do
            copyField(clone.label,source.label,k,log)
        end
        -- Instance style settings differ from the cooked class defaults. Keep
        -- native hover/selection styling rather than the default pink font.
        widget.bShouldEnableClick=true
        widget.bShouldEnableHover=true
        set(clone.label,'SetText',widget.DisplayText)
        set(clone.notify,'SetVisibility',2)
        set(clone.line,'SetVisibility',2) -- Unselected before entering native navigation.
        local glow=(selectedSource or source).line
        local brush=read(glow,'Brush')
        if brush~=nil then pcall(function()clone.line:SetBrush(brush)end)end
        local glowColor=read(glow,'ColorAndOpacity')
        if glowColor~=nil then pcall(function()clone.line:SetColorAndOpacity(glowColor)end)end
        local glowOpacity=call(glow,'GetRenderOpacity')
        if type(glowOpacity)~='number'or glowOpacity<=.01 then glowOpacity=1 end
        -- Keep the hidden line render-ready for native Q/E selection as well
        -- as direct mouse/F6 selection; visibility still owns its display.
        call(clone.line,'SetRenderOpacity',glowOpacity)
        -- The same cooked class already has the native font. Copy the exact
        -- sibling font proxy when this binding exposes a usable setter.
        local font=read(source.text,'Font')
        if font~=nil then pcall(function()clone.text:SetFont(font)end)end
        inactive=inactive or textColor(clone.text,clone.label)or textColor(source.text,source.label)
        -- The cooked class already owns its normal styling. Missing optional
        -- tint access must never prevent this native tab from being attached.
        active=active or {SpecifiedColor={R=1,G=.62,B=.18,A=1},ColorUseRule=0}
        local slot=container:AddChild(widget)
        assert(valid(slot),'Failed to parent ZoneFPV tab in native SlotContainer')
        for _,k in ipairs({'Padding','Size','HorizontalAlignment','VerticalAlignment'})do slotValue(slot,k,layout[k])end
        local tab={widget=widget,button=clone.button,active=false}
        function tab:isSelected()
            return not self.destroyed and valid(self.widget)and selected(clone.line)or false
        end
        function tab:setActive(value)
            if self.destroyed then return false,'ZoneFPV tab destroyed' end
            value=value==true
            local success,err=pcall(function()
                assert(valid(self.widget)and valid(clone.line)and valid(clone.text),'ZoneFPV tab invalid')
                set(clone.line,'SetVisibility',value and 0 or 2)
                if value then call(clone.line,'SetRenderOpacity',glowOpacity)end
                local tint=value and active or inactive
                if tint then set(clone.text,'SetColorAndOpacity',tint)end
            end)
            if success then self.active=value end
            return success,err
        end
        function tab:destroy()
            if self.destroyed then return end
            self.destroyed=true
            if valid(self.widget)then call(self.widget,'RemoveFromParent')end
            if owned[view]==self then owned[view]=nil end
        end
        local ready,err=tab:setActive(false);assert(ready,err)
        owned[view]=tab
        return tab
    end)
    if ok then return result end
    -- If a hostile factory returns a sibling, cleanup must still leave it alone.
    if valid(widget)and not nativeWidget then call(widget,'RemoveFromParent')end
    local err=tostring(result)
    -- Class/CDO discovery may recover later without allocation. Once Create was
    -- attempted, prevent an incompatible widget from being created every tick.
    if attempted then owned[view]={failure=err}end
    if type(log)=='function'then pcall(log,'Native ZoneFPV tab unavailable: '..err)end
    return nil,err
end
return M
