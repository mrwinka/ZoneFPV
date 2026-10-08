-- A blank native PageViewBase participates in the real PDA page lifecycle.
-- BookViewBase rejects ordinary panels, even when they are Switcher children.
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
    assert(array~=nil,'Native PDA Switcher children unavailable')
    local result={}
    if type(array)=='table'and type(read(array,'GetArrayNum'))~='function'then
        assert(#array<=64,'Native PDA Switcher exceeds 64 pages')
        for i,v in ipairs(array)do result[i]=unwrap(v)end
    else
        local n=call(array,'GetArrayNum')
        assert(type(n)=='number'and n>=0 and n<=64 and n%1==0,'Native PDA Switcher count outside 0..64')
        for i=1,n do result[i]=unwrap(array[i])end
    end
    local count=call(container,'GetChildrenCount')
    assert(type(count)=='number'and count==#result,'Native PDA Switcher count disagrees with children')
    return result
end
local function exactBase(class)
    if not valid(class)or call(class,'IsAnyClass')~=true then return false end
    if call(call(class,'GetFName'),'ToString')~='PageViewBase'then return false end
    local full=call(class,'GetFullName')
    return type(full)~='string'or full:match('/Script/Stalker2[%.:]PageViewBase$')~=nil
end
local function pageBase(siblings)
    if type(StaticFindObject)=='function'then
        for _,path in ipairs({'/Script/Stalker2.PageViewBase','/Script/Stalker2:PageViewBase'})do
            local ok,class=pcall(StaticFindObject,path)
            if ok and exactBase(class)then return class end
        end
    end
    -- Native classes are already loaded through the PDA's cooked pages even
    -- when StaticFindObject cannot resolve an engine class on this build.
    for _,page in ipairs(siblings)do
        local class=call(page,'GetClass')
        for _=1,16 do
            if not valid(class)then break end
            if exactBase(class)then return class end
            class=call(class,'GetSuperStruct')
        end
    end
end
function M.new(view,controller,index,library)
    local previous=owned[view]
    if previous and previous.failure then return nil,previous.failure end
    if previous and not previous.destroyed and valid(previous.widget)then return previous end
    local widget,attempted,nativeWidget
    local ok,result=pcall(function()
        assert(valid(view)and valid(controller),'Native PDA view/controller unavailable')
        assert(type(index)=='number'and index>=0 and index<64 and index%1==0,'ZoneFPV page index outside 0..63')
        local switcher=read(view,'Switcher')
        assert(valid(switcher),'Native PDA Switcher unavailable')
        local siblings=children(switcher)
        -- Native navigation and pages use matching zero-based indices. Do not
        -- fill gaps with fabricated pages or silently select another section.
        assert(#siblings==index,'Native PDA navigation/page indices do not align')
        local class=pageBase(siblings)
        assert(class,'Exact native PageViewBase class unavailable')
        if type(library)~='function'then
            local src=debug.getinfo(1,'S').source
            local here=src:sub(1,1)=='@'and src:sub(2):match('^(.*[\\/])')or ''
            library=dofile(here..'pda_tab.lua').library
        end
        local lib=library();assert(valid(lib),'WidgetBlueprintLibrary default unavailable')
        attempted=true
        widget=lib:Create(controller,class,controller)
        assert(valid(widget),'Native PDA page Create failed')
        if same(widget,view)then nativeWidget=true;error('Create returned the native PDA view')end
        for _,page in ipairs(siblings)do
            if same(widget,page)then nativeWidget=true;error('Create returned a native PDA page')end
        end
        assert(same(call(widget,'GetClass'),class),'Create did not return the exact blank PageViewBase class')
        local tree=read(widget,'WidgetTree')
        assert(valid(tree)and not same(tree,read(view,'WidgetTree')),'Native PDA page has no private initialized WidgetTree')
        assert(not valid(read(tree,'RootWidget')),'Blank native PDA page unexpectedly has existing content')
        widget.bShouldBindWidgetInputs=false
        widget.bShoudIgnoreInputOnPouse=false
        local host={widget=widget,tree=tree,index=index,switcher=switcher}
        function host:attach(root)
            if self.destroyed or self.failure then return false,self.failure or 'ZoneFPV page destroyed' end
            if self.attached then return same(read(self.tree,'RootWidget'),root),'ZoneFPV page already attached' end
            local success,err=pcall(function()
                assert(valid(root)and valid(self.widget)and valid(self.tree),'ZoneFPV page/root invalid')
                assert(same(call(root,'GetOuter'),self.tree),'ZoneFPV page root must belong to its private WidgetTree')
                local now=children(self.switcher)
                assert(#now==self.index,'Native PDA page insertion index changed')
                for i,page in ipairs(siblings)do assert(same(now[i],page),'Native PDA page order changed')end
                assert(not valid(read(self.tree,'RootWidget')),'ZoneFPV page already has a root')
                self.tree.RootWidget=root
                assert(same(read(self.tree,'RootWidget'),root),'ZoneFPV page root assignment failed')
                self.widget:SetIsEnabled(true)
                self.widget:SetVisibility(0)
                local slot=self.switcher:AddChild(self.widget)
                assert(valid(slot),'Could not parent ZoneFPV page in native Switcher')
                call(slot,'SetHorizontalAlignment',0)
                call(slot,'SetVerticalAlignment',0)
                local after=children(self.switcher)
                assert(#after==self.index+1 and same(after[self.index+1],self.widget),'ZoneFPV page insertion index mismatch')
                for i,page in ipairs(siblings)do assert(same(after[i],page),'Native PDA pages changed during insertion')end
            end)
            if success then self.attached=true;return true end
            self.failure=tostring(err)
            if valid(self.widget)then call(self.widget,'RemoveFromParent')end
            return false,self.failure
        end
        function host:destroy()
            if self.destroyed then return end
            self.destroyed=true
            if valid(self.widget)then call(self.widget,'RemoveFromParent')end
            if owned[view]==self then owned[view]=nil end
        end
        owned[view]=host
        return host
    end)
    if ok then return result end
    if valid(widget)and not nativeWidget then call(widget,'RemoveFromParent')end
    local err=tostring(result)
    if attempted then owned[view]={failure=err}end
    return nil,err
end
return M
