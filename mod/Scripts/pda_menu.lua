-- ZoneFPV's tab belongs to NavigationPanel.SlotContainer; its page belongs to
-- PDAView.Switcher as an initialized PageViewBase. All engine calls
-- run from the owner's EngineTick update. No viewport overlay, delegates,
-- Blueprint bytecode patch or per-frame widget creation. Opaque geometry is
-- queried through the guarded native adapter and returns scalar values only.
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local model=dofile(here..'pda_model.lua')
local weaponSettings=dofile(here..'weapon_settings.lua')
local textLanguage=dofile(here..'pda_text.lua')
local nativeTab=dofile(here..'pda_tab.lua')
local nativePage=dofile(here..'pda_page.lua')
local nativeTheme=dofile(here..'pda_theme.lua')
local osdLayout=dofile(here..'pda_osd.lua')
local nativeGeometry=dofile(here..'pda_geometry.lua')
local M={}
local observerInstalled,blueprintObserverInstalled,observerTarget=false,false,nil
local pdaBlueprint='/Game/GameLite/FPS_Game/UIRemaster/PDA/W_PDABookView.W_PDABookView_C'
local function invoke(o,k,...)return o[k](o,...)end
local function call(o,k,...)
    local ok,a,b=pcall(invoke,o,k,...)
    if ok then return a,b end
end
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function valid(o)return o~=nil and call(o,'IsValid')==true end
local function same(a,b)
    if a==b and a~=nil then return valid(a) end
    if not valid(a)or not valid(b)then return false end
    return call(a,'GetAddress')==call(b,'GetAddress')
end
local function unwrap(x)
    local kind=call(x,'type')
    if kind=='RemoteUnrealParam'or kind=='LocalUnrealParam'then return call(x,'get')end
    return x
end
local function each(array,fn)
    if type(array)=='table'and type(array.GetArrayNum)~='function'then
        for i,v in ipairs(array)do if i>64 then return false end;fn(v)end;return true
    end
    -- Use fresh bounded indexing, never UE4SS TArray:ForEach callbacks (the
    -- installed binding documents a Lua stack/GC failure for that iterator).
    return pcall(function()
        local n=array:GetArrayNum();assert(type(n)=='number'and n>=0 and n<=64 and n%1==0,'PDA array outside 0..64')
        for i=1,n do fn(unwrap(array[i]))end
    end)
end
local function color(r,g,b,a)return {R=r,G=g,B=b,A=a or 1}end
local white,amber=color(.8,.78,.68),color(1,.62,.18)
local function visible(o)
    if not valid(o)then return false end
    local v=call(o,'GetVisibility')
    return v~=nil and v~=1 and v~=2 and (call(o,'GetRenderOpacity')or 1)>.01
end
local function find(path)local ok,v=pcall(StaticFindObject,path);return ok and valid(v)and v or nil end
local function list(name)local ok,v=pcall(FindAllOf,name);return ok and v or {} end
local function isPDAView(view)
    if not valid(view)or not valid(read(view,'Container'))or not valid(read(view,'Switcher'))or not valid(read(view,'NavigationPanel'))then return false end
    -- Installed cooked W_PDABookView and EWidgetNameEx::PDA (11). Do not
    -- confuse another open native book/menu with the PDA we can extend.
    if read(view,'WidgetName')==11 then return true end
    local name=call(call(view,'GetClass'),'GetFName')
    name=call(name,'ToString')
    return name=='W_PDABookView_C'or name=='PDAView'
end
local function text(o,value)
    if o.lastText==value then return end
    o.widget:SetText(FText(value));o.lastText=value
end
function M.new(opts)
    assert(type(opts)=='table'and type(opts.snapshot)=='function'and type(opts.execute)=='function')
    local self={pending={},candidates={},rejected={},pages={},opts=opts,page=1,section=1,sectionSelections={},row=1,active=false,
        nextRefresh=0,selectRequested=false,keys={},status='',root=nil,pc=nil,seeded=false,nextProbe=0,
        nextDiscovery=0,diagnostics={},geometrySizes={}}
    self.geometry=opts.geometry or nativeGeometry.new(opts.root)
    local diagnose
    local function selectedSection(pages)
        local group=(pages or self.pages)[self.page]
        return group and group.sections[self.section]
    end
    local function rowsFor(section)
        section=section or selectedSection()
        return section and section.id==3 and self.osdRowWidgets or self.rowWidgets or {}
    end
    local function rowIdentity(section,item,index,snapshot)
        if not section or not item then return nil end
        local identity=section.id..':'..(item.key or item.label)
        if section.id==3 and index>=4 and index<=6 then
            identity=identity..':'..tostring(snapshot.osd and snapshot.osd.selectedItemID or 0)
        end
        return identity
    end
    local function cancelPreviewDrag()
        if self.previewDrag then self.previewLayout=nil;self.nextRefresh=0 end
        self.previewDrag=nil;self.previewDraft=nil
    end
    local function geometrySize(widget)
        local cached=self.geometrySizes[widget]
        if cached and (self.currentNow or 0)<cached.untilTime and valid(widget)then return cached.width,cached.height end
        local ok,result=pcall(self.geometry.query,widget,self.slateLibrary,self.layoutLibrary)
        if ok and result then
            self.geometrySizes[widget]={width=result.width,height=result.height,untilTime=(self.currentNow or 0)+.1}
            return result.width,result.height
        end
    end
    local function defaultLibrary(name)
        local expected='Default__'..name
        local function accept(object,source)
            if not valid(object)or call(call(object,'GetFName'),'ToString')~=expected then return end
            diagnose('library-'..name,name..' resolved via '..source);return object
        end
        for _,path in ipairs({'/Script/UMG.'..expected,'/Script/UMG:'..expected})do
            local object=accept(find(path),'StaticFindObject');if object then return object end
        end
        if type(FindFirstOf)=='function'then
            local ok,object=pcall(FindFirstOf,name)
            object=ok and accept(object,'FindFirstOf')or nil;if object then return object end
        end
        local result
        each(list(name),function(object)if not result then result=accept(object,'FindAllOf')end end)
        if not result then diagnose('library-missing-'..name,'Default '..name..' unavailable')end
        return result
    end
    local function previewPointer()
        local ok,result,reason=pcall(self.geometry.query,self.previewBody,self.slateLibrary,self.layoutLibrary)
        if ok and result then
            self.geometrySizes[self.previewBody]={width=result.width,height=result.height,untilTime=(self.currentNow or 0)+.1}
            return result.x/result.width,result.y/result.height,result.width,result.height
        end
        diagnose('preview-pointer-'..tostring(reason),'OSD drag unavailable: '..tostring(reason or 'query failed')..'; saved positions retained')
    end
    local function previewHit(state,x,y,width,height)
        local layout=self.previewLayout
        if not layout or layout.width~=width or layout.height~=height then return osdLayout.hit(state,x,y,width,height)end
        if x<0 or x>1 or y<0 or y>1 then return end
        for i=#layout.bounds,1,-1 do
            local b=layout.bounds[i]
            if b.visible and b.width>0 and b.height>0 and x>=b.x and y>=b.y and x<b.x+b.width and y<b.y+b.height then return b.id end
        end
    end
    local capturing
    local function blockCaptureMouse()
        if not self.active or not capturing or not capturing()then return false end
        if visible(self.scroll)and call(self.scroll,'IsHovered')==true then return true end
        for _,b in ipairs(self.buttons or {})do
            if visible(b.widget)and call(b.widget,'IsHovered')==true then return true end
        end
        for _,r in ipairs(rowsFor())do if visible(r.root)then
            if visible(r.slider)and call(r.slider,'IsHovered')==true or visible(r.number)and call(r.number,'IsHovered')==true then return true end
        end end
        -- Native sibling tab buttons also cancel this capture on selection.
        -- Read only the already-bound, bounded navigation children.
        local hovered=false
        local tabs=read(read(self.view,'NavigationPanel'),'SlotContainer')
        each(call(tabs,'GetAllChildren'),function(tab)
            local button=read(tab,'Button')
            if visible(button)and call(button,'IsHovered')==true then hovered=true end
        end)
        return hovered
    end
    local function settingsContext(open)
        local section=selectedSection()
        self.mouseBlocked=open==true and blockCaptureMouse()or false
        if opts.settings and opts.settings.context then
            local ok,err=pcall(opts.settings.context,open==true,section and section.id or 0,self.mouseBlocked)
            if not ok and opts.log then opts.log('PDA settings context: '..tostring(err))end
        end
    end
    capturing=function()
        local current=opts.snapshot()or self.snapshot
        local capture=current and current.settings and current.settings.capture
        local active=capture and type(capture.row)=='number'and capture.row>=0
        local pending=self.capturePending and current and current.settings and current.settings.pending
        if not pending then self.capturePending=false end
        return active or pending
    end
    local function editingNumber()
        for _,r in ipairs(rowsFor())do
            if visible(r.number)and call(r.number,'HasKeyboardFocus')==true then return true end
        end
        return false
    end
    local language=textLanguage.new(opts.root or '')
    local function log(message)if opts.log then opts.log('PDA: '..message)end end
    diagnose=function(key,message)
        if self.diagnostics[key]then return end
        self.diagnostics[key]=true;log(message)
    end
    local function ownedByPlayer(widget,pc)
        -- UUserWidget ownership is reflected and is the actual local UI context.
        -- Do not use UE4SS's generic UObject:GetWorld virtual-table call here:
        -- it differs from the AActor helper. A missing/mismatched generic world
        -- used to discard every PDA/HUD candidate without a diagnostic.
        if not valid(widget)then return false end
        local owner=call(widget,'GetOwningPlayer')
        if valid(owner)then return same(owner,pc)end
        local player=call(widget,'GetOwningLocalPlayer')
        if valid(player)then return same(player,read(pc,'Player'))end
        -- Some game-created views have no FLocalPlayerContext until opened.
        -- A live native manager entry is sufficient in this single-player UI;
        -- a widget explicitly owned by a different player is never accepted.
        return self.managerViews and self.managerViews[call(widget,'GetAddress')]==true
    end
    local function observe()
        observerTarget=self
        if type(NotifyOnNewObject)~='function'then return end
        local function notify(object)
            local owner=observerTarget
            if owner and #owner.pending<16 then owner.pending[#owner.pending+1]={object=object,tries=0}end
        end
        if not observerInstalled then observerInstalled=pcall(NotifyOnNewObject,'/Script/Stalker2.PDAView',notify)end
        if not blueprintObserverInstalled then blueprintObserverInstalled=pcall(NotifyOnNewObject,pdaBlueprint,notify)end
    end
    observe()
    local function make(class,parent,method)
        self.buildStage='construct '..class
        local object=StaticConstructObject(assert(self.classes[class],class),self.outer)
        assert(valid(object),'Failed to create '..class)
        if parent then assert(valid(parent[method or 'AddChild'](parent,object)),'Failed to parent '..class)end
        return object
    end
    local function label(parent,value,size,tint,role)
        local w=make('TextBlock',parent)
        self.buildStage='TextBlock.Font'
        local ok,err=self.theme:label(w,size or 16,tint or self.theme.colors.text,role)
        assert(ok,err)
        w:SetText(FText(value or ''))
        w:SetVisibility(3) -- decorative text cannot intercept its parent's mouse click.
        return {widget=w,lastText=value or ''}
    end
    local function at(w,x,y,width,height,z)
        local slot=w.Slot
        slot:SetAnchors({Minimum={X=x,Y=y},Maximum={X=x+width,Y=y+height}})
        slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
        if z then slot:SetZOrder(z)end
    end
    local function button(parent,caption,fn)
        local w=make('Button',parent)
        local ok,err=self.theme:button(w,false,false);assert(ok,err)
        local t=label(w,caption,17)
        local value={widget=w,text=t,action=fn,pressed=false}
        self.buttons[#self.buttons+1]=value;return value
    end
    local function show(value,nativeSelection)
        if not value then cancelPreviewDrag();settingsContext(false)end
        if not self.root or not valid(self.body)then return end
        if not value and self.commitSliders then self:commitSliders()end
        local sw=read(self.view,'Switcher')
        if value and not nativeSelection then
            local previous=call(sw,'GetActiveWidgetIndex')
            if previous~=self.pageHost.index then self.previousIndex=previous end
            -- This synchronously dispatches the native BookView selection.
            -- InitClickTransition schedules a timer that visits every tab.
            call(read(self.view,'NavigationPanel'),'ClickMenuButton',FName('ZoneFPV'))
            value=call(sw,'GetActiveWidgetIndex')==self.pageHost.index
            if not value then diagnose('select','Native ZoneFPV page selection was not acknowledged')end
        end
        self.active=value
        if value then self.previewPressed=call(self.previewInput,'IsPressed')==true end
        settingsContext(value)
        -- Page index owns selection. The animated underline can temporarily
        -- fade out and must not close the page or overwrite native styles.
        if self.tab and value and not nativeSelection then self.tab:setActive(true)end
        self.body:SetVisibility(value and 0 or 1)
        self.nextRefresh=0
    end
    function self:close()show(false)end
    local function detach()
        if self.pageHost and valid(self.view)and call(read(self.view,'Switcher'),'GetActiveWidgetIndex')==self.pageHost.index then
            local sibling=call(read(read(self.view,'NavigationPanel'),'SlotContainer'),'GetChildAt',self.previousIndex or 0)
            local id=read(sibling,'ButtonId')
            if id then call(read(self.view,'NavigationPanel'),'ClickMenuButton',id)end
        end
        show(false)
        if self.tab then self.tab:destroy();self.tab=nil end
        if self.pageHost then self.pageHost:destroy();self.pageHost=nil end
        if valid(self.root)then call(self.root,'RemoveFromParent')end
        self.root,self.view,self.body,self.buttons,self.rowWidgets,self.sidebar,self.sectionTabs=nil,nil,nil,nil,nil,nil,nil
        self.preview,self.previewTexts,self.previewLines=nil,nil,nil
        self.previewLayout=nil
        self.osdRowWidgets,self.previewBody,self.previewInput,self.previewOutline=nil,nil,nil,nil
        self.osdItemTitle,self.osdItemScroll,self.osdItemList,self.osdItemButtons,self.osdSelected=nil,nil,nil,nil,nil
        self.scroll,self.rowList,self.scrolledSection=nil,nil,nil
        self.theme,self.previousIndex=nil,nil
        self.geometrySizes={}
        self.navigationPending,self.navigationKeys,self.navigationSequences=nil,nil,nil
    end
    local function refresh()
        local snapshot=opts.snapshot()or {}
        if self.previewDrag and self.previewDraft and type(snapshot.osd)=='table'then
            local copy={};for k,v in pairs(snapshot)do copy[k]=v end;copy.osd={}
            for k,v in pairs(snapshot.osd)do copy.osd[k]=v end;copy.osd.items={}
            for i,item in ipairs(snapshot.osd.items or {})do local entry={};for k,v in pairs(item)do entry[k]=v end;copy.osd.items[i]=entry end
            local item=copy.osd.items[self.previewDraft.id+1]
            if item then item.x,item.y=self.previewDraft.x,self.previewDraft.y end
            snapshot=copy
        end
        self.snapshot=snapshot
        local tr=opts.translate or language.translate
        if self.exitHint then text(self.exitHint,'Esc  '..tr('Выход'))end
        self.pages=model.pages(snapshot,tr)
        self.page=math.max(1,math.min(#self.pages,self.page))
        local group=self.pages[self.page]
        self.section=math.max(1,math.min(#group.sections,self.section))
        local p=selectedSection();self.row=math.max(1,math.min(#p.rows,self.row))
        if p.id~=3 then cancelPreviewDrag()end
        settingsContext(self.active)
        text(self.title,group.label);text(self.description,p.description)
        for i,b in ipairs(self.sectionTabs or {})do
            local section=group.sections[i];b.widget:SetVisibility(section and 0 or 1)
            if section then text(b.text,section.label);self.theme:button(b.widget,i==self.section,b.hovered==true)end
        end
        for i,b in ipairs(self.sidebar)do
            text(b.text,self.pages[i].label)
            local selected=i==self.page
            b.background:SetBrushColor(selected and self.theme.colors.rowActive or b.hovered and self.theme.colors.hover or self.theme.colors.transparent)
            b.left:SetVisibility(selected and 3 or 2);b.right:SetVisibility(selected and 3 or 2)
            b.text.widget:SetColorAndOpacity({SpecifiedColor=selected and amber or self.theme.colors.text,ColorUseRule=0})
        end
        local preview=p.id==3
        local rowX,rowWidth=preview and .744 or .272,preview and .228 or .70
        at(self.scroll,rowX,.25,rowWidth,.565)
        if self.osdItemScroll then
            self.osdItemTitle.widget:SetVisibility(preview and 3 or 1)
            self.osdItemScroll:SetVisibility(preview and 0 or 1)
            if preview then
                text(self.osdItemTitle,tr('Показатели'))
                local selected=snapshot.osd and snapshot.osd.selectedItemID or 0
                local selectionChanged=self.osdSelected~=selected
                self.osdSelected=selected
                for i,b in ipairs(self.osdItemButtons)do
                    local item=p.osdItems[i]
                    text(b.text,item.label)
                    self.theme:button(b.widget,item.selected,b.hovered==true)
                    b.background:SetBrushColor(item.selected and self.theme.colors.rowActive or b.hovered and self.theme.colors.hover or self.theme.colors.transparent)
                    if item.selected and selectionChanged then call(self.osdItemScroll,'ScrollWidgetIntoView',b.root,false,0,0)end
                end
            end
        end
        -- Native ScrollBox owns clipping, wheel input and its scrollbar. A
        -- refresh must retain the user's offset; only changing section resets it.
        if self.scrolledSection~=p.id then self.scroll:SetScrollOffset(0);self.scrolledSection=p.id end
        local bodyWidth,bodyHeight=geometrySize(self.body)
        local rowHeight=preview and math.max(34,math.min(46,(bodyHeight or 900)*.565/math.max(1,#p.rows)))or 54
        local activeRows=rowsFor(p)
        for i,r in ipairs(activeRows)do
            r.root:SetHeightOverride(rowHeight)
            r.index=i
            local item=p.rows[r.index]
            r.root:SetVisibility(item and 0 or 1)
            -- A combat-mode change may reuse this slot for a different slider.
            -- Never reinterpret an old pending charge edit as impact speed.
            local identity=rowIdentity(p,item,i,snapshot)
            local changed=r.rowIdentity~=identity
            if changed then r.pending=nil;r.sliderNumber=nil;r.dragging=false;r.rowIdentity=identity end
            local slider=item and item.kind=='slider'
            local binding=item and item.kind=='binding'
            local numeric=item and item.kind=='number'
            local readonly=item and item.kind=='status'
            local action=item and (item.kind=='action'or item.kind=='toggle'or binding)
            r.slider:SetVisibility(slider and 0 or 1)
            r.minus.widget:SetVisibility(item and not slider and not action and not numeric and not readonly and 0 or 1)
            r.plus.widget:SetVisibility(item and not slider and not action and not numeric and not readonly and 0 or 1)
            r.activate.widget:SetVisibility((action or numeric)and 0 or 1)
            r.mode.widget:SetVisibility(binding and 0 or 1)
            r.clear.widget:SetVisibility(binding and 0 or 1)
            r.number:SetVisibility(numeric and 0 or 1)
            r.value.widget:SetVisibility(item and not action and not numeric and 3 or 1)
            if item then
                text(r.caption,preview and item.compactLabel or item.label);text(r.value,item.value)
                text(r.activate.text,numeric and tr('Применить')or item.value)
                call(r.activate.widget,'SetIsEnabled',item.disabled~=true)
                local fontSize=preview and 14 or 16
                if r.fontSize~=fontSize then
                    for _,entry in ipairs({r.caption,r.value,r.activate.text,r.minus.text,r.plus.text})do self.theme:label(entry.widget,fontSize,nil,'body')end
                    r.fontSize=fontSize
                end
                local pixels=math.max(100,rowWidth*(bodyWidth or 1600)-16)
                local labelCount=utf8.len(preview and item.compactLabel or item.label)or #(item.label or '')
                local labelWidth=math.max(preview and .27 or .16,math.min(preview and .47 or .42,(labelCount*fontSize*.54+12)/pixels))
                local controls=labelWidth+.015
                if binding then
                    text(r.mode.text,item.modeValue)
                    text(r.clear.text,item.clearValue)
                    at(r.caption.widget,0,.1,.32,.8);at(r.activate.widget,.33,0,.29,1)
                    at(r.clear.widget,.63,0,.10,1);at(r.mode.widget,.74,0,.255,1)
                elseif numeric then
                    at(r.caption.widget,0,.1,.45,.8);at(r.number,.46,0,.33,1);at(r.activate.widget,.81,0,.185,1)
                    if r.numberKey~=p.id..':'..r.index or call(r.number,'HasKeyboardFocus')~=true then
                        call(r.number,'SetText',FText(item.value));r.numberKey=p.id..':'..r.index
                    end
                    call(r.number,'SetHintText',FText(item.placeholder or ''))
                else
                    at(r.caption.widget,0,.1,labelWidth,.8)
                    at(r.activate.widget,controls,0,1-controls,1)
                    local arrow=math.max(.025,math.min(.08,30/pixels))
                    local gap=math.max(.003,6/pixels)
                    local valueWidth=math.max(.04,math.min(1-controls-2*arrow-2*gap,
                        ((utf8.len(item.value)or #item.value)*fontSize*.60+12)/pixels))
                    r.choiceValueX,r.choiceValueWidth=controls+arrow+gap,valueWidth
                    at(r.minus.widget,controls,0,arrow,1)
                    at(r.plus.widget,r.choiceValueX+valueWidth+gap,0,arrow,1)
                    at(r.slider,controls,.12,math.max(.10,.83-controls),.76)
                end
                if slider then
                    -- Reuse each owned native Slider. A pending mouse edit must
                    -- not be overwritten by the periodic preference refresh.
                    if changed or not r.pending and call(r.slider,'HasMouseCapture')~=true then
                        r.slider:SetMinValue(item.min);r.slider:SetMaxValue(item.max)
                        r.slider:SetStepSize(item.step);r.slider:SetValue(item.number)
                        r.sliderNumber=r.slider:GetValue()
                    elseif r.pending then text(r.value,r.pending.item.format(r.pending.number))end
                    at(r.value.widget,.85,.1,.145,.8)
                else
                    r.pending=nil;r.sliderNumber=nil
                    if not binding and not numeric then
                        at(r.value.widget,readonly and controls or r.choiceValueX,.1,
                            readonly and math.max(.1,1-controls)or r.choiceValueWidth,.8)
                    end
                end
                r.background:SetBrushColor(r.index==self.row and self.theme.colors.rowActive or self.theme.colors.transparent)
            end
        end
        if self.preview then self.preview:SetVisibility(preview and 4 or 1)end
        if self.preview and preview then
            text(self.previewTitle,tr('Предпросмотр OSD'))
            text(self.previewHint,tr('Нажмите показатель и перетащите. Настройки выбранного элемента — справа.'))
            local outerWidth,outerHeight=geometrySize(self.preview)
            if outerWidth then
                at(self.previewBody,.01,.10,.98,math.min(.77,.98*outerWidth/(16/9)/outerHeight))
            end
            local previewWidth,previewHeight=geometrySize(self.previewBody)
            previewWidth,previewHeight=previewWidth or 560,previewHeight or 315
            local osd=snapshot.osd or {}
            -- The preview's minimum glyph size is in local pixels. Drawing at
            -- one size and testing at the default1600x900 made visible small
            -- labels extend below their clickable bounds on the real PDA.
            local primitives,bounds=osdLayout.preview(osd,previewWidth,previewHeight)
            self.previewLayout={width=previewWidth,height=previewHeight,bounds=bounds}
            local texts,lines=0,0
            for _,primitive in ipairs(primitives)do
                if primitive.visible~=false and (primitive.kind=='text'or primitive.text)then
                    texts=texts+1;local target=self.previewTexts[texts]
                    if target then
                        local textChanged=target.lastText~=(primitive.text or '')
                        target.widget:SetVisibility(3);text(target,primitive.text or '')
                        local c=primitive.colorRGB or {1,1,1}
                        local fontSize=math.max(8,math.min(90,math.floor((primitive.height or .02)*previewHeight+.5)))
                        local fontChanged=target.previewFontSize~=fontSize
                        if fontChanged then self.theme:label(target.widget,fontSize,nil,'body');target.previewFontSize=fontSize end
                        -- Slate font Size is points. Measure this OWN text's
                        -- desired local-pixel rectangle instead of assuming
                        -- the font value is also its rendered line height.
                        if textChanged or fontChanged or not target.desiredWidth or target.previewWidth~=previewWidth or target.previewHeight~=previewHeight then
                            call(target.widget,'ForceLayoutPrepass')
                            local desired=call(target.widget,'GetDesiredSize')
                            local w,h=read(desired,'X'),read(desired,'Y')
                            local function extent(v)return type(v)=='number'and v==v and v>0 and v<1000000 end
                            target.desiredWidth,target.desiredHeight=nil,nil
                            if extent(w)and extent(h)then target.desiredWidth,target.desiredHeight=w,h end
                            target.previewWidth,target.previewHeight=previewWidth,previewHeight
                        end
                        local w=math.min(previewWidth,target.desiredWidth or (primitive.width or .35)*previewWidth)
                        local h=math.min(previewHeight,target.desiredHeight or (primitive.height or .09)*previewHeight)
                        local item=osd.items and osd.items[(primitive.id or 0)+1]
                        local x=item and math.max(0,math.min(previewWidth-w,item.x*previewWidth-w/2))/previewWidth or primitive.x or 0
                        local y=item and math.max(0,math.min(previewHeight-h,item.y*previewHeight-h/2))/previewHeight or primitive.y or 0
                        w,h=w/previewWidth,h/previewHeight
                        local box=bounds[(primitive.id or 0)+1]
                        if box then box.x,box.y,box.width,box.height=x,y,w,h end
                        call(target.widget,'SetColorAndOpacity',{SpecifiedColor=color(c[1]or c.R or 1,c[2]or c.G or 1,c[3]or c.B or 1),ColorUseRule=0})
                        at(target.widget,x,y,w,h,(primitive.id or 0)*2)
                    end
                elseif primitive.visible~=false then
                    lines=lines+1;local target=self.previewLines[lines]
                    if target then
                        target:SetVisibility(3)
                        local c=primitive.colorRGB or {1,1,1};target:SetBrushColor(color(c[1]or c.R or 1,c[2]or c.G or 1,c[3]or c.B or 1))
                        local x,y=primitive.x or 0,primitive.y or 0
                        local x2,y2=primitive.x2 or x,primitive.y2 or y
                        local dx,dy=(x2-x)*previewWidth,(y2-y)*previewHeight
                        local length=math.sqrt(dx*dx+dy*dy)
                        at(target,x,y,math.max(.002,length/previewWidth),math.max(.002,(primitive.thickness or 2)/previewHeight),(primitive.id or 0)*2)
                        call(target,'SetRenderTransformPivot',{X=0,Y=0})
                        call(target,'SetRenderTransformAngle',math.atan(dy,dx)*180/math.pi)
                    end
                end
            end
            for i=texts+1,#self.previewTexts do self.previewTexts[i].widget:SetVisibility(1)end
            for i=lines+1,#self.previewLines do self.previewLines[i]:SetVisibility(1)end
            local box=bounds[(osd.selectedItemID or 0)+1]
            for _,edge in ipairs(self.previewOutline)do edge:SetVisibility(box and box.visible and 3 or 1)end
            if box and box.visible then
                local x,y,w,h=box.x,box.y,math.max(.006,box.width),math.max(.008,box.height)
                at(self.previewOutline[1],x,y,w,.003,90);at(self.previewOutline[2],x,y+h,w,.003,90)
                at(self.previewOutline[3],x,y,.002,h,90);at(self.previewOutline[4],x+w,y,.002,h,90)
            end
        end
        local selected=p.rows[self.row]
        text(self.rowHelp,selected and selected.help or '')
        local s=snapshot.session
        -- Use the OSD sample, which already applies horizontal speed scaling
        -- and the game's vertical movement scale. Raw physics velocity differs.
        local speed=snapshot.telemetry and snapshot.telemetry.speed or 0
        if type(speed)~='number'or speed~=speed or speed<0 or speed==math.huge then speed=0 end
        local hp=s and s.combat and s.combat.health
        local rssi=s and s.radio and s.radio.rssi
        local telemetry=string.format('%s  |  %.0f km/h  |  RSSI %s  |  HP %s',s and 'FPV' or 'STANDBY',speed,rssi and string.format('%.0f%%',rssi)or '--',hp and string.format('%.0f',hp)or '--')
        if s and s.weapons and weaponSettings.hasGrenades(s.weapons.mode) then
            local remaining=s.weapons.remaining
            local ammo=remaining==math.huge and '∞'or type(remaining)=='number'and string.format('%d',remaining)or '--'
            telemetry=telemetry..'  |  '..tr('Заряды')..' '..ammo
        end
        text(self.telemetry,telemetry)
        local resources=snapshot.resources
        if resources then
            local pressure=snapshot.resourceLevel~=nil and snapshot.resourceLevel>=2
                or snapshot.resourceLevel==nil and resources.commit<256
            local reduced=snapshot.resourceLevel~=nil and snapshot.resourceLevel>0
                or snapshot.resourceLevel==nil and (pressure or resources.commit<2048 or resources.known and resources.used>=resources.maximum*.9)
            text(self.resources,string.format('%s  |  RAM %.1f GB  |  OBJECTS %s',
                tr(pressure and 'Память: критически мало' or reduced and 'Память: ограниченный запас' or 'Память: нормально'),
                resources.ram/1024,resources.known and string.format('%d / %d',resources.used,resources.maximum)or '--'))
        else text(self.resources,'')end
        -- Keep developer resource counters available to diagnostics/tests;
        -- ordinary PDA content does not expose engine object counts or RAM.
        self.resources.widget:SetVisibility(snapshot.resourceLevel and snapshot.resourceLevel>0 and 3 or 2)
        local backend=snapshot.settings
        local feedback=self.status
        local helperSection=p.id==1 or p.id==9 or p.id==10
        if helperSection and backend and type(backend.status)=='string'and backend.status~=''and not self.statusError then
            local capture=backend.capture or {};local calibration=backend.calibration or {}
            if feedback==''or self.statusSource=='settings'or backend.pending or (capture.row or -1)>=0 or (calibration.stage or 0)>0 then feedback=tr(backend.status)end
        end
        text(self.feedback,feedback)
    end
    local function dispatch(command,argument)
        local ok,result,detail
        if command==nil then return end
        settingsContext(self.active)
        if command=='settings'then
            if opts.settings and opts.settings.request then ok,result,detail=pcall(opts.settings.request,argument.action,argument.args)else ok,result,detail=true,false,'Программа ввода не готова'end
            if ok and result and argument.action=='capture'then
                self.capturePending=true;self.captureWasActive=true;self.navigationPending=nil
            end
        elseif command=='osd'then
            if opts.osd and opts.osd.execute then ok,result,detail=pcall(opts.osd.execute,argument.action,argument.args)else ok,result,detail=true,false,'read_failed'end
        elseif command=='flight'or command=='reset'then
            if opts.action then ok,result,detail=pcall(opts.action,command)else ok,result,detail=true,false,'Close PDA and use the flight hotkey'end
        else ok,result,detail=pcall(opts.execute,command)end
        local tr=opts.translate or language.translate
        self.statusSource=command;self.statusError=not(ok and result)
        if command=='osd'then
            if ok and result then detail=(detail=='selected'or detail=='preview')and 'Обновлено'or 'Настройки сохранены'
            else
                log('OSD command failed: '..tostring(detail or result))
                detail=detail=='invalid_file'and 'Файл OSD повреждён. Сбросьте расположение OSD.'
                    or detail=='conflict'and 'OSD изменён в другом меню. Повторите настройку.'
                    or detail=='read_failed'and 'Не удалось прочитать настройки OSD.'or 'Не удалось сохранить настройки OSD.'
            end
        end
        if not ok then detail='Не удалось применить'end
        self.status=ok and result and tr(detail or 'Настройки сохранены')or tr(tostring(detail or result or 'Не удалось применить'))
        if not ok then log('Command failed: '..tostring(result))end
    end
    function self:commitSliders()
        local changed=false
        local p=selectedSection()
        local snapshot,current
        local function latestRows()
            snapshot=opts.snapshot()or {}
            current=selectedSection(model.pages(snapshot,opts.translate or language.translate))
        end
        latestRows()
        for i,r in ipairs(rowsFor(p))do
            -- Closing/native Q/E or a section click can precede the next
            -- periodic refresh. Validate the fresh target BEFORE polling the
            -- old thumb, not only while repainting reused widget slots.
            local index=r.index or i
            local item=current and current.rows[index]
            local matches=r.rowIdentity~=nil and r.rowIdentity==rowIdentity(current,item,index,snapshot)
                and item.kind=='slider'and type(item.set)=='function'
            if not matches then r.pending=nil;r.sliderNumber=nil;r.dragging=false end
            -- Native tab selection/closing precedes ordinary slider polling.
            -- Read the final thumb position too, including clicks completed
            -- wholly between updates and the last movement before Q/E.
            if matches and self.active and valid(r.slider)then
                local number=r.slider:GetValue()
                if type(number)=='number'and number==number and math.abs(number-(r.sliderNumber or number))>1e-5 then
                    r.sliderNumber=number;r.pending={item=item,number=number}
                end
            end
            local pending=r.pending
            if pending and matches then
                r.pending=nil
                -- Two quick edits can concern related controls. Build a fresh
                -- command after each commit so its untouched sibling retains
                -- the value just saved, rather than a previous closure's copy.
                dispatch(item.set(pending.number))
                changed=true
                latestRows()
            end
        end
        return changed
    end
    local function executeRow(index,direction)
        if self:commitSliders()then refresh()end
        local p=selectedSection();local row=p and p.rows[index]
        if not row then return end
        if row.disabled then return end
        self.row=index
        if row.kind=='number'then
            local widget
            for _,candidate in ipairs(rowsFor(p))do if candidate.index==index then widget=candidate.number end end
            local value=call(widget,'GetText');value=type(value)=='string'and value or call(value,'ToString')
            local command,argument=row.set(value)
            if command then dispatch(command,argument)else
                self.status=(opts.translate or language.translate)('Введите целое число от 1 до 2147483647.');self.statusError=true;self.statusSource='settings'
            end
        else dispatch(row.command(direction or 1))end
        refresh()
    end
    local function executeClear(index)
        local p=selectedSection();local row=p and p.rows[index]
        if row and row.kind=='binding'then self.row=index;dispatch(row.clearCommand());refresh()end
    end
    local function selectVertical(direction,step)
        self.row=math.max(1,math.min(#selectedSection().rows,self.row+direction*(step or 1)))
        local row=rowsFor()[self.row]
        if row then call(self.scroll,'ScrollWidgetIntoView',row.root,false,0,0)end
        self.nextRefresh=0
    end
    local function executeMode(index)
        if self:commitSliders()then refresh()end
        local p=selectedSection();local row=p and p.rows[index]
        if row and row.kind=='binding'then self.row=index;dispatch(row.modeCommand());refresh()end
    end
    local function selectGroup(index)
        cancelPreviewDrag();self:commitSliders();self.sectionSelections[self.page]=self.section
        self.page=index;self.section=self.sectionSelections[index]or 1;self.row=1;refresh()
    end
    local function selectOSDItem(id)
        self:commitSliders();cancelPreviewDrag()
        dispatch('osd',{action='selectItem',args={id=id}});refresh()
    end
    local function build(view)
        self.classes={};self.classPending=true;self.buildStage='resolve UMG classes'
        local names={'CanvasPanel','Border','TextBlock','Button','Slider','EditableTextBox','ScrollBox','VerticalBox','SizeBox'}
        local function accept(name,cls,source)
            -- GetClass constructs a UClass wrapper in the installed UE4SS
            -- binding. Only accept the exact engine class, never an arbitrary
            -- cooked subclass with initialization/event requirements.
            local full=valid(cls)and call(cls,'GetFullName')
            -- This game's binding may label a UClass as Object and separate
            -- its native package with ':'; the type check is authoritative.
            local path=type(full)=='string'and (full:match('^%S+%s+(/Script/.*)$')or full)
            if call(cls,'IsAnyClass')~=true or (path~='/Script/UMG.'..name and path~='/Script/UMG:'..name)then return false end
            self.classes[name]=cls
            diagnose('class-'..name,'UMG class '..full..' acquired via '..source)
            return true
        end
        for _,name in ipairs(names)do accept(name,find('/Script/UMG.'..name),'StaticFindObject')end
        local function inspect(widget,source)
            if not valid(widget)then return end
            local cls=call(widget,'GetClass')
            for _,name in ipairs(names)do if not self.classes[name]then accept(name,cls,source)end end
        end
        local function complete()
            for _,name in ipairs(names)do if not self.classes[name]then return false end end
            return true
        end
        if not complete()then
            -- A loaded PDA can exist while StaticFindObject cannot resolve a
            -- native class path. Its real widgets provide reflected UClasses.
            local queue,seen={},{}
            local function enqueue(widget)
                if #queue>=256 or not valid(widget)then return end
                local id=call(widget,'GetAddress')
                if id and not seen[id]then seen[id]=true;queue[#queue+1]=widget end
            end
            enqueue(view);enqueue(read(view,'Container'));enqueue(read(view,'Switcher'));enqueue(read(view,'NavigationPanel'))
            local i=1
            while i<=#queue and not complete()do
                local widget=queue[i];i=i+1;inspect(widget,'PDA widget GetClass')
                enqueue(read(read(widget,'WidgetTree'),'RootWidget'))
                each(call(widget,'GetAllChildren'),enqueue)
            end
            -- Not all primitive classes occur in every PDA page. Resolve
            -- remaining classes from existing instances only during a bounded
            -- build attempt, never during the ordinary per-frame UI update.
            for _,name in ipairs(names)do
                if not self.classes[name]then
                    for j,widget in ipairs(list(name))do
                        if j>32 then break end
                        inspect(widget,'existing '..name..' GetClass')
                        if self.classes[name]then break end
                    end
                end
            end
        end
        for _,name in ipairs(names)do assert(self.classes[name],'Missing UMG '..name)end
        self.classPending=false -- From here failures retain the allocation circuit breaker.
        local container=read(view,'Container');assert(valid(container),'PDA container unavailable')
        self.view,self.buttons,self.rowWidgets,self.sidebar,self.sectionTabs=view,{},{},{},{}
        self.osdRowWidgets={}
        self.slateLibrary=defaultLibrary('SlateBlueprintLibrary')
        self.layoutLibrary=defaultLibrary('WidgetLayoutLibrary')
        self.theme=nativeTheme.new(view)
        log('Native PDA theme sampled; creating page host')
        local navigation=read(view,'NavigationPanel')
        local tabs=read(navigation,'SlotContainer')
        local children=call(tabs,'GetAllChildren')
        local tabIndex=0
        assert(each(children,function()tabIndex=tabIndex+1 end),'PDA navigation count unavailable')
        self.buildStage='native PDA page host'
        local pageHost,pageError=nativePage.new(view,self.pc,tabIndex,nativeTab.library)
        assert(pageHost,pageError or 'Native PDA page unavailable');self.pageHost=pageHost
        self.outer=self.pageHost.tree
        self.previousIndex=call(read(view,'Switcher'),'GetActiveWidgetIndex')
        self.root=make('CanvasPanel')
        local attached,attachError=self.pageHost:attach(self.root);assert(attached,attachError)
        self.root:SetVisibility(4) -- controls remain interactive inside the native page.
        self.buildStage='native PDA navigation tab'
        local tab,tabError=nativeTab.new(view,self.pc,log)
        assert(tab,tabError or 'Native PDA tab unavailable')
        self.tab=tab
        log('Native PDA page and tab attached; building controls without whole button-style calls')
        self.buttons[1]={widget=tab.button,action=function()show(true);refresh()end,pressed=false}
        self.body=make('Border',self.root);at(self.body,0,0,1,1)
        local styled,styleError=self.theme:page(self.body);assert(styled,styleError)
        self.body:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
        local canvas=make('CanvasPanel',self.body)
        local sidebarBackground=make('Border',canvas);at(sidebarBackground,0,0,.25,.915)
        sidebarBackground:SetBrushColor(color(.019,.019,.017))
        local divider=make('Border',canvas);at(divider,.25,0,.002,.915)
        divider:SetBrushColor(color(.12,.115,.095))
        self.sidebarTitle=label(canvas,'ZoneFPV',23);at(self.sidebarTitle.widget,.02,.024,.22,.06)
        local pageCount=#model.pages(opts.snapshot()or {})
        local pageStep=.80/math.max(5,pageCount)
        for i=1,pageCount do
            local y=.11+(i-1)*pageStep
            local background=make('Border',canvas);at(background,0,y,.25,pageStep-.01)
            local b=button(canvas,'',function()selectGroup(i)end)
            at(b.widget,.008,y,.234,pageStep-.01)
            call(b.text.widget,'SetJustification',0)
            call(read(b.text.widget,'Slot'),'SetHorizontalAlignment',0)
            call(read(b.text.widget,'Slot'),'SetPadding',{Left=14,Top=0,Right=0,Bottom=0})
            local left=make('Border',canvas);at(left,0,y,.003,pageStep-.01)
            local right=make('Border',canvas);at(right,.247,y,.003,pageStep-.01)
            left:SetBrushColor(amber);right:SetBrushColor(amber)
            b.background,b.left,b.right=background,left,right;self.sidebar[i]=b
        end
        self.title=label(canvas,'ZoneFPV',24);at(self.title.widget,.272,.035,.70,.065)
        local headingLine=make('Border',canvas);at(headingLine,.272,.106,.70,.0015)
        headingLine:SetBrushColor(color(.10,.096,.078))
        for i=1,3 do
            local b=button(canvas,'',function()cancelPreviewDrag();self:commitSliders();self.section=i;self.sectionSelections[self.page]=i;self.row=1;refresh()end)
            at(b.widget,.272+(i-1)*.235,.115,.226,.049)
            b.sectionId=i;self.sectionTabs[i]=b
        end
        self.description=label(canvas,'',15,nil,'body');at(self.description.widget,.272,.176,.70,.065)
        self.description.widget:SetAutoWrapText(true)
        self.scroll=make('ScrollBox',canvas);at(self.scroll,.272,.25,.70,.565)
        self.scroll:SetOrientation(1) -- Orient_Vertical.
        self.scroll:SetConsumeMouseWheel(1) -- Always: never leak an owned list's wheel to the world.
        self.rowList=make('VerticalBox',self.scroll)
        call(read(self.rowList,'Slot'),'SetHorizontalAlignment',0)
        for i=1,15 do
            local rowSize=make('SizeBox',self.rowList);rowSize:SetHeightOverride(54)
            local border=make('Border',rowSize)
            border:SetPadding({Left=8,Top=4,Right=8,Bottom=4})
            local rowCanvas=make('CanvasPanel',border)
            local caption=label(rowCanvas,'',16);at(caption.widget,0,.1,.48,.8)
            caption.widget:SetAutoWrapText(true)
            local value=label(rowCanvas,'',16,amber);at(value.widget,.57,.1,.36,.8)
            value.widget:SetAutoWrapText(true)
            local minus=button(rowCanvas,'<',function()executeRow(self.osdRowWidgets[i].index,-1)end);at(minus.widget,.495,0,.055,1)
            local plus=button(rowCanvas,'>',function()executeRow(self.osdRowWidgets[i].index,1)end);at(plus.widget,.945,0,.055,1)
            local activate=button(rowCanvas,'',function()executeRow(self.osdRowWidgets[i].index,1)end);at(activate.widget,.50,0,.49,1)
            local mode=button(rowCanvas,'',function()executeMode(self.osdRowWidgets[i].index)end);at(mode.widget,.72,0,.275,1)
            local clear=button(rowCanvas,'',function()executeClear(self.osdRowWidgets[i].index)end)
            local number=make('EditableTextBox',rowCanvas);call(number,'SetSelectAllTextWhenFocused',true)
            local slider=make('Slider',rowCanvas);at(slider,.495,.12,.335,.76)
            -- Whole FSliderStyle arguments exceed UE4SS's fixed parameter
            -- buffer. Native defaults plus small reflected setters are enough.
            slider:SetSliderBarColor(self.theme.colors.muted)
            slider:SetSliderHandleColor(self.theme.colors.amber)
            if type(read(slider,'IsFocusable'))=='boolean'then slider.IsFocusable=false end
            local entry={root=rowSize,background=border,caption=caption,value=value,minus=minus,plus=plus,activate=activate,mode=mode,clear=clear,number=number,slider=slider}
            self.osdRowWidgets[i]=entry;self.rowWidgets[i]=entry
        end
        self.osdItemTitle=label(canvas,'',15,nil,'body');at(self.osdItemTitle.widget,.272,.25,.19,.037)
        self.osdItemScroll=make('ScrollBox',canvas);at(self.osdItemScroll,.272,.295,.19,.52)
        self.osdItemScroll:SetOrientation(1);self.osdItemScroll:SetConsumeMouseWheel(1)
        self.osdItemList=make('VerticalBox',self.osdItemScroll)
        self.osdItemButtons={}
        for id=0,13 do
            local rowSize=make('SizeBox',self.osdItemList);rowSize:SetHeightOverride(32)
            local border=make('Border',rowSize);border:SetPadding({Left=6,Top=3,Right=6,Bottom=3})
            local b=button(border,'',function()selectOSDItem(id)end)
            self.theme:label(b.text.widget,14,nil,'body')
            b.text.widget:SetAutoWrapText(true);call(b.text.widget,'SetJustification',0)
            b.osdItemID,b.background,b.root=id,border,rowSize;self.osdItemButtons[id+1]=b
        end
        self.preview=make('Border',canvas);at(self.preview,.475,.25,.255,.565)
        self.preview:SetBrushColor(color(.012,.013,.012));self.preview:SetPadding({Left=4,Top=4,Right=4,Bottom=4})
        local previewCanvas=make('CanvasPanel',self.preview)
        self.previewTitle=label(previewCanvas,'',13);at(self.previewTitle.widget,.01,.01,.96,.05)
        local previewBody=make('CanvasPanel',previewCanvas);at(previewBody,.01,.10,.98,.77);self.previewBody=previewBody
        self.previewHint=label(previewCanvas,'',13,nil,'body');at(self.previewHint.widget,.015,.89,.97,.10)
        self.previewHint.widget:SetAutoWrapText(true)
        self.previewTexts,self.previewLines={},{}
        for i=1,32 do
            self.previewTexts[i]=label(previewBody,'',11)
            call(self.previewTexts[i].widget,'SetClipping',1) -- ClipToBounds also protects the unmeasured initial fallback.
            self.previewLines[i]=make('Border',previewBody)
        end
        self.previewOutline={};for i=1,4 do local edge=make('Border',previewBody);edge:SetBrushColor(amber);self.previewOutline[i]=edge end
        self.previewInput=make('Button',previewBody);self.theme:button(self.previewInput,false,false);at(self.previewInput,0,0,1,1,100)
        if type(read(self.previewInput,'IsFocusable'))=='boolean'then self.previewInput.IsFocusable=false end
        self.rowHelp=label(canvas,'',14,nil,'body');at(self.rowHelp.widget,.272,.836,.70,.045)
        self.rowHelp.widget:SetAutoWrapText(true)
        self.resources=label(canvas,'',12,nil,'body');at(self.resources.widget,.272,.86,.70,.026)
        self.feedback=label(canvas,'',14,amber,'body');at(self.feedback.widget,.272,.885,.70,.027)
        local footer=make('Border',canvas);at(footer,0,.917,1,.083)
        footer:SetBrushColor(color(.043,.043,.037))
        local footerLine=make('Border',canvas);at(footerLine,0,.915,1,.002)
        footerLine:SetBrushColor(color(.13,.12,.10))
        self.exitHint=label(canvas,'Esc',17);at(self.exitHint.widget,.02,.938,.20,.044)
        self.telemetry=label(canvas,'',14,nil,'body');at(self.telemetry.widget,.272,.94,.70,.04)
        self.body:SetVisibility(1);self.active=false
        refresh();log('ZoneFPV tab attached to NavigationPanel.SlotContainer; native PageViewBase attached to PDAView.Switcher at index '..tabIndex)
    end
    local function viewOpen(view)
        if not visible(view)then return false end
        -- The actual screen attachment takes precedence. OpenViews is an
        -- implementation detail and can omit an animated/native root page.
        if call(view,'IsInViewport')==true then return true end
        if self.managerViews and self.managerViews[call(view,'GetAddress')]then return true end
        -- A child PDA can be hosted inside another native UserWidget. Verify
        -- its visible ancestors instead of treating any cached parent as open.
        local parent=call(view,'GetParent')
        for _=1,8 do
            if not valid(parent)or not visible(parent)then return false end
            if call(parent,'IsInViewport')==true then return true end
            parent=call(parent,'GetParent')
        end
        return false
    end
    local function discovery(now,pc)
        if not same(pc,self.pc)then
            detach();self.pc=pc;self.candidates={};self.rejected={};self.seeded=false;self.nextProbe=0;self.managers={};self.managerViews={}
            self.nextDiscovery=0;self.diagnostics={}
        end
        -- Discovery/closed-PDA work is limited to 10 Hz; active UI input is
        -- still polled every EngineTick. Never scan the global array per frame.
        if now<self.nextDiscovery and #self.pending==0 then
            return self.nativeOpen and self.openView or nil
        end
        self.nextDiscovery=now+.1
        self.nativeOpen=false;self.openView=nil
        -- Registration success does not prove delivery: the installed run had
        -- an empty startup seed and no PDA notification. Refresh stale manager
        -- references slowly until a real local PDA is bound, then stop scans.
        if now>=self.nextProbe and not valid(self.root)then self.seeded=false end
        if not self.seeded and now>=self.nextProbe then
            self.seeded=true;self.nextProbe=now+5
            local views=list('PDAView')
            for i,v in ipairs(views)do if i<=16 then self.pending[#self.pending+1]={object=v,tries=0}end end
            local blueprintViews=list('W_PDABookView_C')
            for i,v in ipairs(blueprintViews)do if i<=16 then self.pending[#self.pending+1]={object=v,tries=0}end end
            self.managers=list('UIBaseManager')
            diagnose('seed','Discovery seeded: PDAView='..#views..'; W_PDABookView_C='..#blueprintViews..'; managers='..#self.managers..'; observer='..tostring(observerInstalled))
        end
        self.managerViews={};self.nativeViews={}
        for i,manager in ipairs(self.managers or {})do
            if i>4 then break end
            if valid(manager)then each(read(manager,'OpenViews'),function(v)
                if valid(v)then
                    local id=call(v,'GetAddress');self.managerViews[id]=true
                    if #self.nativeViews<64 then self.nativeViews[#self.nativeViews+1]=v end
                    -- OpenViews was only a visibility flag in v12: when the
                    -- initial class search was empty and no observer arrived,
                    -- the actual open PDA could never become a candidate.
                    if not self.candidates[id]and isPDAView(v)then
                        self.candidates[id]=v;diagnose('manager-'..id,'PDA candidate acquired from native manager OpenViews')
                    end
                end
            end)end
        end
        for _=1,math.min(4,#self.pending)do
            local entry=table.remove(self.pending,1);local v=entry.object
            if valid(v)then
                -- Construction notification can precede local-player setup by
                -- seconds during a load. Keep the bounded candidate, not a
                -- thirty-frame retry which permanently misses that PDA.
                self.candidates[call(v,'GetAddress')]=v
            end
        end
        for id,v in pairs(self.candidates)do
            if not valid(v)then self.candidates[id]=nil;self.rejected[id]=nil
            elseif ownedByPlayer(v,pc)then
                local opened=viewOpen(v)
                self.nativeOpen=self.nativeOpen or opened
                if opened then self.openView=v end
                diagnose('owner-'..id,'Local PDA found; viewport='..tostring(call(v,'IsInViewport'))..'; visibility='..tostring(call(v,'GetVisibility')))
                if type(self.rejected[id])=='number'and now>=self.rejected[id]then self.rejected[id]=nil end
                if self.rejected[id]then if opened then return v end
                elseif valid(read(v,'Container'))then
                    if (opened or not valid(self.root))and (not same(self.view,v)or not valid(self.root))then
                        detach();local ok,err=pcall(build,v)
                        if not ok then
                            detach();self.rejected[id]=self.classPending and now+5 or true
                            diagnose('build-'..id..'-'..tostring(err),'Native panel unavailable at '..tostring(self.buildStage)..': '..tostring(err))
                            if opened then return v end
                        end
                    end
                    if opened then return v end
                else diagnose('container-'..id,'Local PDA is waiting for its Container binding')end
            else diagnose('owner-wait-'..id,'PDA candidate waiting for its owning local player')
            end
        end
    end
    local function releaseInput()
        local inject=self.inject
        if not inject then return end
        self.inject=nil
        if valid(inject.mimic)then call(inject.mimic,'OnMouseButtonReleased');return end
        if valid(inject.subsystem)and valid(inject.action)then
            call(inject.subsystem,'InjectInputForAction',inject.action,{Value={X=0,Y=0,Z=0},ValueType=0},{},inject.triggers)
        end
    end
    function self:requestOpen(now,pc)
        self.selectRequested=true;self.requestUntil=(now or 0)+3
        pc=pc or self.pc
        if not valid(pc)then return false end
        self.nextDiscovery=0
        discovery(now or 0,pc)
        if not valid(self.root)then
            self.selectRequested=false
            diagnose('not-ready','Native panel not ready; immediate desktop fallback')
            return false
        end
        if self.view and ownedByPlayer(self.view,pc)and viewOpen(self.view)and valid(self.root)then
            self.selectRequested=false;show(true);refresh();return true
        end
        local lib=find('/Script/Engine.Default__SubsystemBlueprintLibrary')
        local cls=find('/Script/EnhancedInput.EnhancedInputLocalPlayerSubsystem')
        local subsystem=valid(lib)and valid(cls)and call(lib,'GetLocalPlayerSubSystemFromPlayerController',pc,cls)
        if not valid(subsystem)then
            diagnose('subsystem','EnhancedInput subsystem unavailable; trying the game PDA hint button')
        end
        local hints=list('HudHintsPanel');local localHints,readyActions=0,0
        -- Blueprint HUDs can also be absent from a native class search. Reuse
        -- the manager's small live view list and its reflected HUD binding.
        for _,v in ipairs(self.nativeViews or {})do
            local h=read(v,'HudHintsPanel')
            if valid(h)and #hints<64 then hints[#hints+1]=h end
        end
        for _,h in ipairs(hints)do
            if ownedByPlayer(h,pc)then
                localHints=localHints+1
                local hint=read(h,'OpenPDA');local mimic=read(hint,'MimicButtonElement')
                local action=read(mimic,'InputAction');local trigger=read(mimic,'InputTrigger')
                if valid(subsystem)and valid(action)and valid(trigger)then
                    readyActions=readyActions+1
                    local ok,err=pcall(function()subsystem:InjectInputForAction(action,{Value={X=1,Y=0,Z=0},ValueType=0},{},{trigger})end)
                    if ok then
                        self.inject={subsystem=subsystem,action=action,triggers={trigger},releaseAt=(now or 0)+.12}
                        diagnose('inject-ready','Native PDA action injected; waiting for visible PDA acknowledgement');return true
                    end
                    diagnose('inject','Native input injection failed: '..tostring(err))
                end
                -- These are the game's own UActionMimicButton handlers, whose
                -- pressed state is consumed by its native UI tick. No guessed
                -- keyboard binding or subsystem class is needed. Acknowledge
                -- success only when the real PDA is subsequently visible.
                local press,release=read(mimic,'OnMouseButtonPressed'),read(mimic,'OnMouseButtonReleased')
                if (type(press)=='function'or valid(press))and (type(release)=='function'or valid(release))then
                    local ok=pcall(function()mimic:OnMouseButtonPressed()end)
                    if ok then
                        self.inject={mimic=mimic,releaseAt=(now or 0)+.12}
                        diagnose('mimic','Game PDA hint pressed; waiting for visible PDA acknowledgement');return true
                    end
                end
            end
        end
        diagnose('hints','Native opener unavailable: HudHintsPanel='..#hints..'; local='..localHints..'; ready actions='..readyActions..'. Open the PDA with its normal game binding, then select ZoneFPV')
        return false
    end
    local function keyPressed(pc,key)
        local fkey=self.keys[key]
        if not fkey then fkey={KeyName=FName(key)};self.keys[key]=fkey end
        return call(pc,'WasInputKeyJustPressed',fkey)==true
    end
    local function navigationSample()
        if opts.navigationKeys==nil then return nil end
        -- UIOnly focus can suppress both player-controller key methods. The
        -- independent provider supplies one coherent, fresh foreground sample.
        -- Once configured, it owns Q/E: unavailable data never falls back to
        -- an engine key state that may have remained down before UI focus.
        local ok,keys=pcall(opts.navigationKeys)
        if ok and type(keys)=='table'and type(keys.q)=='boolean'and type(keys.e)=='boolean'then
            local function sequence(value)
                return type(value)=='number'and value>=0 and value<math.huge and value%1==0
            end
            if keys.qSeq==nil and keys.eSeq==nil then
                self.navigationSequences=nil
                return {Q=keys.q,E=keys.e}
            elseif sequence(keys.qSeq)and sequence(keys.eSeq)then
                return {Q=keys.q,E=keys.e,sequences={Q=keys.qSeq,E=keys.eSeq}}
            end
        end
        self.navigationPending=nil
        self.navigationSequences=nil
        -- After a sample gap, require release before accepting another press.
        -- A key held while returning from another window must not move a tab.
        self.navigationKeys={Q=true,E=true}
        return false
    end
    local function navigationEdge(pc,key,sample)
        if sample==false then return false end
        if sample and sample.sequences then
            -- The producer counts rising presses, retaining taps that begin
            -- and end between Lua updates. The first sample primes counters;
            -- focus recovery or entering the PDA cannot replay an old press.
            self.navigationSequences=self.navigationSequences or {}
            local previous=self.navigationSequences[key]
            local current=sample.sequences[key]
            self.navigationSequences[key]=current
            self.navigationKeys=self.navigationKeys or {}
            self.navigationKeys[key]=sample[key]
            -- A freshly restarted producer resets counters. Adopt that lower
            -- baseline without treating the reset as a physical key press.
            return previous~=nil and current>previous
        end
        local pressed,down
        if sample then down=sample[key];pressed=false
        else
            pressed=keyPressed(pc,key)
            down=call(pc,'IsInputKeyDown',self.keys[key])
        end
        -- Sample on native pages too so E held while entering ZoneFPV cannot
        -- immediately leave it again. Held keys produce a single movement.
        self.navigationKeys=self.navigationKeys or {}
        local previous=self.navigationKeys[key]
        local current=type(down)=='boolean'and down or pressed
        local edge=current and not previous or pressed and not previous
        self.navigationKeys[key]=current or pressed
        return edge==true
    end
    local function update(now,pc)
        self.currentNow=now
        if self.inject and now>=self.inject.releaseAt then releaseInput()end
        if not valid(pc)then self.nativeOpen=false;detach();return false end
        -- The usual 100ms discovery cache can outlive a closed PDA. Refresh
        -- its bounded open-state check before dispatching a queued movement.
        if self.previewDrag or self.navigationPending and now>=self.navigationPending.after then self.nextDiscovery=0 end
        local view=discovery(now,pc)
        if not view then
            self.navigationPending=nil;self.navigationKeys=nil;self.navigationSequences=nil
            if self.active then show(false)end;return false
        end
        language.update(now)
        local captureActive=capturing()
        self.keyboardReserved=captureActive or self.captureWasActive or editingNumber()or self.previewDrag~=nil
        self.captureWasActive=captureActive
        local wasActive=self.active
        if self.selectRequested and now<=self.requestUntil then show(true);self.selectRequested=false end
        if self.requestUntil and now>self.requestUntil then self.selectRequested=false end
        local navigationState
        if self.tab and self.pageHost then
            navigationState=navigationSample();local sample=navigationState
            local index=call(read(view,'Switcher'),'GetActiveWidgetIndex')
            local selected=index==self.pageHost.index
            if index~=nil and not selected then self.previousIndex=index end
            if selected and not self.active then show(true,true);refresh()
            elseif not selected and self.active then show(false,true)end
            local captureInput=self.keyboardReserved
            if captureInput then self.navigationPending=nil end
            local pending=self.navigationPending
            if pending and (not selected or not wasActive or pending.host~=self.pageHost)then
                self.navigationPending=nil;pending=nil
            end
            if pending and now>=pending.after then
                -- Independent UIOnly input gives native synchronous handling
                -- one update to run first. Legacy controller input also waits
                -- for the game's first-movement timer; never start one here.
                self.navigationPending=nil
                local nav=read(view,'NavigationPanel')
                call(nav,pending.direction<0 and 'MoveSelectSlotToPreviousSlot'or 'MoveSelectSlotToNextSlot')
                index=call(read(view,'Switcher'),'GetActiveWidgetIndex')
                selected=index==self.pageHost.index
                if not selected then self.previousIndex=index;show(false,true)end
            end
            local previousEdge=navigationEdge(pc,'Q',sample)
            local nextEdge=navigationEdge(pc,'E',sample)
            if selected and wasActive and not captureInput then
                if previousEdge and nextEdge then self.navigationPending=nil
                elseif previousEdge or nextEdge then
                    local delay=0
                    if not sample then
                        delay=read(read(view,'NavigationPanel'),'PDASectionSwitch')
                        if type(delay)~='number'or delay~=delay or delay<0 or delay>10 then delay=.5 end
                        delay=delay+.02
                    end
                    self.navigationPending={host=self.pageHost,direction=previousEdge and -1 or 1,after=now+delay}
                end
            end
        end
        for _,b in ipairs(self.buttons or {})do
            -- Buttons only react on release while still hovered. A press-drag
            -- outside the control cancels exactly as it does in ordinary UMG.
            local osdVisible=b.osdItemID==nil or self.active and selectedSection().id==3
            local enabled=osdVisible and visible(b.widget)and call(b.widget,'GetIsEnabled')~=false and (b==self.buttons[1]or self.active)
            local pressed=enabled and call(b.widget,'IsPressed')==true
            if b.pressed and not pressed and enabled and call(b.widget,'IsHovered')==true then b.action()end
            b.pressed=pressed
            if b~=self.buttons[1]and enabled then
                local hovered=call(b.widget,'IsHovered')==true
                if b.hovered~=hovered then
                    local selected=b.osdItemID~=nil and b.osdItemID==self.osdSelected or b.sectionId~=nil and b.sectionId==self.section
                    self.theme:button(b.widget,selected,hovered);b.hovered=hovered
                    if b.background then
                        local active=b.osdItemID~=nil and b.osdItemID==self.osdSelected or b==self.sidebar[self.page]
                        b.background:SetBrushColor(active and self.theme.colors.rowActive or hovered and self.theme.colors.hover or self.theme.colors.transparent)
                    end
                end
            end
        end
        if self.active then
            local section=selectedSection()
            if section.id==3 and self.previewInput then
                local pressed=call(self.previewInput,'IsPressed')==true
                local focusOK=not opts.navigationKeys or type(navigationState)=='table'
                if not focusOK then cancelPreviewDrag()
                elseif pressed and not self.previewPressed and call(self.previewInput,'IsHovered')==true then
                    local x,y,width,height=previewPointer();local state=(opts.snapshot()or {}).osd
                    if x and (not self.previewLayout or self.previewLayout.width~=width or self.previewLayout.height~=height)then refresh()end
                    local id=x and previewHit(state,x,y,width,height)
                    if id~=nil then
                        self:commitSliders();dispatch('osd',{action='selectItem',args={id=id}})
                        state=(opts.snapshot()or {}).osd;local item=state and state.items and state.items[id+1]
                        if not self.statusError and item then
                            self.previewDrag={id=id,x=item.x,y=item.y,startX=x,startY=y,offsetX=x-item.x,offsetY=y-item.y}
                            self.previewDraft={id=id,x=item.x,y=item.y};self.keyboardReserved=true;self.navigationPending=nil;refresh()
                        end
                    end
                elseif pressed and self.previewDrag then
                    local x,y=previewPointer();local drag=self.previewDrag
                    local moved=x and (math.abs(x-drag.startX)>.001 or math.abs(y-drag.startY)>.001)
                    local position=x and (moved or drag.moved)and osdLayout.dragPosition((opts.snapshot()or {}).osd,drag.id,x,y,drag.offsetX,drag.offsetY)
                    if not x then cancelPreviewDrag()
                    elseif position then
                        drag.moved=true
                        if math.abs(position.x-self.previewDraft.x)>1e-6 or math.abs(position.y-self.previewDraft.y)>1e-6 then
                            self.previewDraft=position;refresh()
                        end
                    end
                elseif not pressed and self.previewPressed and self.previewDrag then
                    local drag=self.previewDrag;local x,y=previewPointer()
                    local moved=x and (math.abs(x-drag.startX)>.001 or math.abs(y-drag.startY)>.001)
                    local position=x and (moved or drag.moved)and osdLayout.dragPosition((opts.snapshot()or {}).osd,drag.id,x,y,drag.offsetX,drag.offsetY)
                    cancelPreviewDrag()
                    if position and (math.abs(position.x-drag.x)>1e-6 or math.abs(position.y-drag.y)>1e-6)then
                        dispatch('osd',{action='position',args=position})
                    end
                    refresh()
                end
                self.previewPressed=pressed
            else cancelPreviewDrag();self.previewPressed=false end
            for i,r in ipairs(rowsFor(section))do
                local index=r.index or i
                local item=selectedSection().rows[index]
                if item and call(r.root,'IsHovered')==true and not r.hovered then self.row=index;self.nextRefresh=0 end
                r.hovered=item and call(r.root,'IsHovered')==true
                if item and item.kind=='slider'then
                    local captured=call(r.slider,'HasMouseCapture')==true
                    local number=r.slider:GetValue()
                    if type(number)=='number'and number==number and math.abs(number-(r.sliderNumber or number))>1e-5 then
                        r.sliderNumber=number;self.row=index
                        r.pending={item=item,number=number,after=now+.12}
                        text(r.value,item.format(number));text(self.rowHelp,item.help or '')
                    end
                    if r.pending and not captured and (r.dragging or now>=r.pending.after)then
                        local pending=r.pending;r.pending=nil
                        dispatch(item.set(pending.number));refresh()
                    end
                    r.dragging=captured
                end
            end
            if not self.keyboardReserved and not capturing()and not editingNumber()then
                if keyPressed(pc,'Up')or keyPressed(pc,'Gamepad_DPad_Up')then selectVertical(-1)end
                if keyPressed(pc,'Down')or keyPressed(pc,'Gamepad_DPad_Down')then selectVertical(1)end
                local selected=selectedSection().rows[self.row]
                if keyPressed(pc,'Left')or keyPressed(pc,'Gamepad_DPad_Left')then
                    if selected and selected.kind=='binding'then executeMode(self.row)else executeRow(self.row,-1)end
                end
                if keyPressed(pc,'Right')or keyPressed(pc,'Gamepad_DPad_Right')then
                    if selected and selected.kind=='binding'then executeMode(self.row)else executeRow(self.row,1)end
                end
                if keyPressed(pc,'Enter')or keyPressed(pc,'Gamepad_FaceButton_Bottom')then executeRow(self.row,1)end
                if not capturing()then
                    if keyPressed(pc,'PageUp')then selectVertical(-1,6)end
                    if keyPressed(pc,'PageDown')then selectVertical(1,6)end
                    if keyPressed(pc,'Gamepad_LeftShoulder')then selectGroup((self.page-2)%#self.pages+1);self.nextRefresh=0 end
                    if keyPressed(pc,'Gamepad_RightShoulder')then selectGroup(self.page%#self.pages+1);self.nextRefresh=0 end
                end
            else
                if not capturing()and editingNumber()and keyPressed(pc,'Enter')then
                    for _,r in ipairs(rowsFor())do if visible(r.number)and call(r.number,'HasKeyboardFocus')==true then executeRow(r.index);break end end
                end
                -- Consume our own adapter edges during capture and its release
                -- frame; the helper observes hardware independently. A key
                -- assigned in the wizard cannot replay as PDA navigation.
                for _,key in ipairs({'Up','Down','Left','Right','Enter','PageUp','PageDown','Gamepad_DPad_Up','Gamepad_DPad_Down','Gamepad_DPad_Left','Gamepad_DPad_Right','Gamepad_FaceButton_Bottom','Gamepad_LeftShoulder','Gamepad_RightShoulder'})do keyPressed(pc,key)end
            end
            if now>=self.nextRefresh then refresh();self.nextRefresh=now+.25 end
            settingsContext(true)
        end
        return true -- Every native PDA page pauses FPV, including map/notes.
    end
    function self:update(now,pc)
        local ok,result=pcall(update,now,pc)
        if ok then return result end
        if not self.updateError then self.updateError=true;log('Panel update failed: '..tostring(result))end
        local id=call(self.view,'GetAddress')
        if id then self.rejected[id]=true end -- never rebuild an incompatible panel every tick.
        releaseInput();detach();return self.nativeOpen==true
    end
    function self:destroy()
        releaseInput();detach();self.pending={};self.candidates={}
        if observerTarget==self then observerTarget=nil end
    end
    return self
end
return M
