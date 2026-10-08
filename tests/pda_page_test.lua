local methods,serial,fixture,creates={},0,nil,0
function methods:IsValid()return not self.dead end
function methods:GetAddress()return self.id end
function methods:IsAnyClass()return self.classObject==true end
function methods:GetFName()return {ToString=function()return self.name end}end
function methods:GetFullName()return self.full end
function methods:GetClass()return self.class end
function methods:GetOuter()return self.outer end
function methods:GetSuperStruct()return self.super end
function methods:GetAllChildren()return self.children or {}end
function methods:GetChildrenCount()return self.badCount or #(self.children or {})end
function methods:SetIsEnabled(value)self.enabled=value end
function methods:SetVisibility(value)self.visibility=value end
function methods:SetHorizontalAlignment(value)self.horizontal=value end
function methods:SetVerticalAlignment(value)self.vertical=value end
function methods:RemoveFromParent()
    self.removed=(self.removed or 0)+1
    if self.parent then
        for i,w in ipairs(self.parent.children)do if w==self then table.remove(self.parent.children,i);break end end
    end
    self.parent=nil
end
local function obj(name)
    serial=serial+1;return setmetatable({name=name,id=serial},{__index=methods})
end
function methods:AddChild(widget)
    assert(self==fixture.switcher and widget==fixture.created,'Only owned page may be parented')
    assert(widget.WidgetTree.RootWidget==fixture.root,'Page tree must be ready before Slate parent insertion')
    self.children[#self.children+1]=widget;widget.parent=self
    if fixture.failAttach then error('Failed after parent insertion')end
    fixture.slot=obj('WidgetSwitcherSlot');return fixture.slot
end
function methods:Create(context,class,owner)
    creates=creates+1
    assert(self==fixture.lib and context==fixture.pc and owner==fixture.pc and class==fixture.base,'Exact native base and owner required')
    if fixture.alias then return fixture.pages[1]end
    local widget=obj('ZoneFPVPage');widget.class=fixture.wrongClass and fixture.cooked or class
    widget.WidgetTree=obj('PrivateTree');fixture.created=widget
    if fixture.existingRoot then widget.WidgetTree.RootWidget=obj('UnexpectedNativeContent')end
    return widget
end
StaticFindObject=function(path)
    assert(path=='/Script/Stalker2.PageViewBase'or path=='/Script/Stalker2:PageViewBase')
    return fixture.findBase and fixture.base or nil
end
local function setup(count)
    creates=0;fixture={}
    fixture.base=obj('PageViewBase');fixture.base.classObject=true;fixture.base.full='Class /Script/Stalker2.PageViewBase'
    fixture.cooked=obj('W_PDAMap_C');fixture.cooked.classObject=true;fixture.cooked.super=fixture.base
    fixture.pc=obj('Controller');fixture.view=obj('PDAView');fixture.view.WidgetTree=obj('NativeBookTree')
    fixture.switcher=obj('Switcher');fixture.switcher.children={};fixture.view.Switcher=fixture.switcher
    fixture.lib=obj('Default__WidgetBlueprintLibrary');fixture.pages={};fixture.root=obj('OwnCanvasRoot')
    for i=1,count or 2 do
        local page=obj('NativePage'..i);page.class=fixture.cooked
        fixture.pages[i]=page;fixture.switcher.children[i]=page
    end
    return dofile('mod/Scripts/pda_page.lua')
end
local function create(M,index)
    local page,err=M.new(fixture.view,fixture.pc,index or #fixture.pages,function()return fixture.lib end)
    if page then fixture.root.outer=page.tree end
    return page,err
end
local M=setup(7)
local page,err=create(M,7);assert(page,err)
assert(page.index==7 and page.tree==fixture.created.WidgetTree and creates==1)
assert(#fixture.switcher.children==7 and not page.attached,'Construction does not prematurely parent unfinished content')
assert(page.widget.bShouldBindWidgetInputs==false and page.widget.bShoudIgnoreInputOnPouse==false)
assert(page:attach(fixture.root));assert(#fixture.switcher.children==8 and fixture.switcher.children[8]==page.widget)
assert(page.widget.enabled and page.widget.visibility==0)
assert(fixture.slot.horizontal==0 and fixture.slot.vertical==0)
for i,original in ipairs(fixture.pages)do assert(fixture.switcher.children[i]==original and not original.removed)end
for _=1,1000 do assert(create(M,7)==page)end
assert(creates==1,'Host must be reused without repeated native creation')
assert(page:attach(fixture.root));page:destroy();page:destroy()
assert(#fixture.switcher.children==7 and fixture.created.removed==1)
for _,original in ipairs(fixture.pages)do assert(not original.removed)end

M=setup(2);assert(not create(M,3));assert(creates==0,'Index mismatch must fail before native creation')
fixture.switcher.badCount=3;assert(not create(M,2));assert(creates==0)

M=setup(1);fixture.findBase=true;fixture.cooked.super=nil
assert(create(M,1),'Exact reflected class lookup can initialize a blank host')

M=setup(1);fixture.alias=true;assert(not create(M,1));assert(not fixture.pages[1].removed)
fixture.alias=false;assert(not create(M,1)and creates==1,'Attempted native factory failure is latched')

M=setup(1);fixture.wrongClass=true;assert(not create(M,1));assert(fixture.created.removed==1)
M=setup(1);fixture.existingRoot=true;assert(not create(M,1));assert(fixture.created.removed==1)

M=setup(2);page=assert(create(M,2));fixture.switcher.children[1],fixture.switcher.children[2]=fixture.switcher.children[2],fixture.switcher.children[1]
assert(not page:attach(fixture.root));assert(#fixture.switcher.children==2 and not page.attached)

M=setup(2);page=assert(create(M,2));fixture.failAttach=true
assert(not page:attach(fixture.root));assert(#fixture.switcher.children==2 and fixture.created.removed==1)
assert(not page:attach(fixture.root),'Failed host cannot reparent every tick')
M=setup(2);page=assert(create(M,2));fixture.root.outer=fixture.view.WidgetTree
assert(not page:attach(fixture.root),'An existing native tree root must never be shared with the owned page')
print('pda_page_test: passed (native base, initialized tree, exact index, ownership, bounded reuse and failure cleanup)')
