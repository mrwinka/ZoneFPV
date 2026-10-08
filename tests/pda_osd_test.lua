local M=dofile('mod/Scripts/pda_osd.lua')
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function near(a,b)return math.abs(a-b)<1e-12 end
local function fixture(initial)
    local root='fixture/';local path=root..'osd-layout.txt';local temp=root..'osd-layout.pda.tmp';local backup=root..'osd-layout.pda.rollback'
    local files={[path]=initial};local calls={read=0,write=0,rename=0,remove=0};local now=0;local fs={};local hooks={}
    function fs.read(name,limit)
        calls.read=calls.read+1;assert(limit==4096,'All file reads have a strict byte limit')
        if hooks.read then local handled,a,b,c=hooks.read(name);if handled then return a,b,c end end
        local text=files[name];if text==nil then return nil,'missing'end
        return text:sub(1,limit+1)
    end
    function fs.write(name,text)
        calls.write=calls.write+1;assert(name==temp,'Only our temporary path may be truncated')
        if hooks.write then local handled,a,b=hooks.write(name,text);if handled then return a,b end end
        files[name]=text;return true
    end
    function fs.rename(from,to)
        calls.rename=calls.rename+1
        if hooks.rename then local handled,a,b=hooks.rename(from,to);if handled then return a,b end end
        if not files[from]then return nil,'missing'end
        if files[to]then return nil,'File exists'end -- Actual Windows CRT rename semantics.
        files[to],files[from]=files[from],nil
        if hooks.afterRename then hooks.afterRename(from,to)end
        return true
    end
    function fs.remove(name)
        calls.remove=calls.remove+1
        if hooks.remove then local handled,a,b=hooks.remove(name);if handled then return a,b end end
        if files[name]==nil then return nil,'missing'end
        files[name]=nil;return true
    end
    local logs={};local controller=M.new(root,{fs=fs,clock=function()return now end,log=function(s)logs[#logs+1]=s end})
    return controller,files,calls,hooks,function(t)now=t end,path,temp,backup,logs
end
local function legacy(config,version)
    local head={version,config.enabled and 1 or 0,config.crossStyle}
    if version>=2 then head[#head+1]=config.fontChoice end
    if version>=6 then head[#head+1]=config.downCrossStyle end
    if version>=7 then head[#head+1]=config.downCrossVisible and 1 or 0 end
    local result={table.concat(head,' ')};local count=version>=5 and 14 or version==4 and 13 or version==3 and 11 or 10
    for i=1,count do local e=config.items[i];result[#result+1]=string.format('%.17g %.17g %d %d %d',e.x,e.y,e.size,e.color,e.visible and 1 or 0)end
    return table.concat(result,'\n')..'\n'
end
local baseline=M.defaults();assert(M.version==7 and M.itemCount==14 and #baseline.items==14)
assert(#M.fonts==8 and #M.styles==6 and #M.colorNames==5)
assert(baseline.items[5].id==4 and baseline.items[5].visible and baseline.downCrossVisible and baseline.downCrossStyle==4)
assert(baseline.items[12].size==14 and baseline.items[13].color==3 and baseline.items[14].color==2)
assert(not baseline.items[9].visible and not baseline.items[10].visible)
baseline.items[1].x=0;assert(M.defaults().items[1].x==.14,'Defaults must not share mutable state')
baseline=M.defaults()
-- Compare the authoritative native default table rather than only our fixture.
local source=assert(io.open('src/osd.h','rb'));local native=source:read('*a');source:close()
assert(native:find('f<<"7 "',1,true)and native:find('inline constexpr int itemCount=14',1,true))
local body=assert(native:match('defaults={(.-)};'));local nativeItems={}
for x,y,size,color,visible in body:gmatch('{([%d%.]+),([%d%.]+),(%d+),(%d+),(%a+)}')do
    nativeItems[#nativeItems+1]={tonumber(x),tonumber(y),tonumber(size),tonumber(color),visible=='true'}
end
assert(#nativeItems==14)
for i,e in ipairs(nativeItems)do local item=baseline.items[i]
    assert(item.x==e[1]and item.y==e[2]and item.size==e[3]and item.color==e[4]and item.visible==e[5],'Native default mismatch at '..i)
end
local customized=M.defaults();customized.enabled=false;customized.fontChoice=7;customized.crossStyle=2
customized.downCrossStyle=5;customized.downCrossVisible=false
for i,e in ipairs(customized.items)do e.x=i/20;e.y=1-i/20;e.size=14+i;e.color=i%5;e.visible=i%2==0 end
for version=1,7 do
    local text=legacy(customized,version);local config=assert(M.parse(text))
    assert(config.version==7 and config.sourceVersion==version and not config.enabled and config.crossStyle==2)
    assert(config.fontChoice==(version>=2 and 7 or 0))
    assert(config.downCrossStyle==(version>=6 and 5 or 4)and config.downCrossVisible==(version<7))
    local count=version>=5 and 14 or version==4 and 13 or version==3 and 11 or 10
    for i,e in ipairs(config.items)do local expected=i<=count and customized.items[i]or baseline.items[i]
        assert(e.x==expected.x and e.y==expected.y and e.size==expected.size and e.color==expected.color and e.visible==expected.visible)
    end
    assert(M.parse(assert(M.serialize(config))).sourceVersion==7,'Explicit future edits migrate legacy layouts to native v7')
end
local current=assert(M.serialize(customized));assert(M.parse(current).items[14].size==28)
local malformed={current:gsub('^7','8'),current..'trailing',current:gsub('^7 0 2','7 2 2'),
    current:gsub('^7 0 2','7 0 6'),current:gsub('^7 0 2 7','7 0 2 8'),current:gsub('7 0 2 7 5 0','7 0 2 7 6 0',1),
    current:gsub('7 0 2 7 5 0','7 0 2 7 5 2',1),current:match('^(.-)\n[^\n]+\n$'),'',string.rep(' ',4097),
    current:gsub('0.05','nan',1),current:gsub('0.05','inf',1),current:gsub('0.05','0x1',1),
    current:gsub('0.05','-0.1',1),current:gsub('0.05','1.1',1),current:gsub(' 15 1 0',' 13 1 0',1),
    current:gsub(' 15 1 0',' 73 1 0',1),current:gsub(' 15 1 0',' 15.0 1 0',1),
    current:gsub(' 15 1 0',' 15 5 0',1),(current:gsub(' 15 1 0',' 15 1 2',1))}
for _,text in ipairs(malformed)do assert(not M.parse(text),'Invalid layout accepted: '..text:sub(1,80))end
assert(not M.parse(nil)and not M.parse({}))
local exponent=current:gsub('\n%S+','\n5e-2',1);assert(M.parse(exponent).items[1].x==.05,'Finite decimal scientific coordinates match native reader')
local invalid=M.defaults();invalid.items[1].x=0/0;assert(not M.serialize(invalid))
invalid=M.defaults();invalid.items[14].size=math.huge;assert(not M.serialize(invalid))
print('PASS pda_osd seven native versions/defaults/strict parser')

do
    local c,files,calls,_,time,path=fixture(current);local initial=copy(calls)
    local snap=c:snapshot();assert(snap.status=='loaded'and snap.sourceVersion==7 and snap.fontChoice==7)
    assert(c:execute('selectItem',{id=13})and c.execute('previewDown',{value=true}))
    local preview,previewCalls=M.preview,0
    M.preview=function(...)previewCalls=previewCalls+1;return preview(...)end
    for _=1,100 do local readOnly=c.snapshot();M.rows(readOnly);readOnly.items[1].x=999 end
    M.preview=preview
    assert(previewCalls==0,'Reading OSD settings must not render geometry-specific preview primitives')
    assert(calls.read==initial.read and calls.write==0 and calls.rename==0 and calls.remove==0,'Opening, selection, preview and refresh are read-only and polling bounded')
    assert(c:snapshot().items[1].x==.05 and c:snapshot().selectedItemID==13 and c:snapshot().previewDown)
    local next=M.defaults();next.fontChoice=3;next.items[2].color=4;files[path]=M.serialize(next)
    time(.249);assert(c:snapshot().fontChoice==7)
    time(.25);assert(c:snapshot().fontChoice==3 and c:snapshot().items[2].color==4 and calls.read==initial.read+1)
    files[path]='partial';time(.5);assert(c:snapshot().status=='invalid'and c:snapshot().fontChoice==3,'Partial external updates retain last-valid state')
    local writes=calls.write;assert(not c:execute('fontChoice',{value=2})and calls.write==writes and files[path]=='partial')
    assert(c:execute('resetLayout',{}));assert(M.parse(files[path]).fontChoice==3,'Only explicit reset repairs an invalid file and preserves last-valid global siblings')
    files[path]=nil;time(1);assert(c:snapshot().status=='missing'and c:snapshot().fontChoice==3,'Transient disappearance must not reset valid settings')
end
do
    local c,files,calls,_,_,path=fixture(nil)
    assert(c:snapshot().status=='missing'and #c:snapshot().items==14 and calls.write==0)
    assert(c:execute('enabled',{value=false}));assert(M.parse(files[path]).enabled==false)
    local once=calls.write;assert(c:execute('enabled',{value=false})and calls.write==once,'A no-op does not rewrite a layout')
end
do
    local text=legacy(customized,3);local c,files,calls,_,_,path=fixture(text)
    assert(c:execute('fontChoice',{value=7})and calls.write==0 and files[path]==text,'Opening or a no-op must not silently migrate legacy files')
    assert(c:execute('downCrossVisible',{value=false}));local migrated=assert(M.parse(files[path]))
    assert(migrated.sourceVersion==7 and migrated.fontChoice==7 and migrated.items[11].x==customized.items[11].x
        and migrated.items[12].size==14 and not migrated.downCrossVisible,'Explicit edits retain legacy siblings and add native missing defaults')
end
print('PASS pda_osd read-only bounded refresh/migration/partial-file retention')

do
    local c,files,_,_,_,path,temp,backup=fixture(current)
    assert(c:execute('selectItem',{id=12}));local rendered=c:snapshot();local rows=M.rows(rendered)
    local byLabel={};for _,r in ipairs(rows)do
        assert(type(r.command)=='function'and type(r.help)=='string'and r.help~='')
        byLabel[r.label]=r
    end
    assert(#rows==13 and byLabel['Шрифт OSD'].value=='Bahnschrift')
    local items=M.itemList(rendered)
    assert(#items==14 and items[13].selected and rows[3].kind=='status'and rows[3].command(1)==nil,
        'Indicator choices form a full list rather than a cycling inspector control')
    for i,item in ipairs(items)do assert(item.id==i-1 and item.label==rendered.items[i].label and item.selected==(i==13))end
    local listWrites=files[path]
    for id=0,13 do assert(c:execute('selectItem',{id=id}))end
    assert(files[path]==listWrites,'Choosing indicators never saves the layout')
    assert(c:execute('selectItem',{id=12}))
    assert(not byLabel['Положение по горизонтали']and not byLabel['Положение по вертикали'],'XY rows are removed, positioning stays in preview drag')
    local external=copy(customized);external.fontChoice=1;external.crossStyle=5;external.items[5].visible=false
    external.items[13].y=.12345678901234566;external.items[13].size=71;external.items[14].color=4
    files[path]=M.serialize(external)
    local kind,packet=byLabel['Размер элемента'].set(37.6);assert(kind=='osd'and packet.action=='item'and packet.args.id==12 and packet.args.field=='size'and packet.args.value==38)
    assert(c.execute(packet.action,packet.args));local saved=assert(M.parse(files[path]))
    assert(saved.items[13].x==external.items[13].x and saved.items[13].y==external.items[13].y and saved.items[13].size==38
        and saved.items[14].color==4 and saved.fontChoice==1 and saved.crossStyle==5 and not saved.items[5].visible,
        'A stale slider packet changes one field of the latest file, preserving precise external siblings')
    assert(files[temp]==nil and files[backup]==nil,'Successful commit removes transaction files')
    assert(c:execute('position',{id=13,x=0,y=1}));assert(M.parse(files[path]).items[14].y==1)
    assert(c:execute('item',{id=13,field='visible',value=0}));assert(not M.parse(files[path]).items[14].visible)
    assert(c:execute('size',{id=13,value=72}));assert(c:execute('color',{id=13,value=4}))
    assert(c:execute('resetItem',{id=13}));saved=assert(M.parse(files[path]));assert(saved.items[14].x==.9 and saved.items[14].color==2 and saved.fontChoice==1)
    assert(c:execute('resetLayout',{}));saved=assert(M.parse(files[path]));assert(not saved.enabled and saved.fontChoice==1 and saved.crossStyle==0 and saved.downCrossStyle==4 and saved.downCrossVisible)
    assert(saved.items[13].x==.9 and saved.items[13].color==3)
    local readonly=files[path]
    for _,request in ipairs({{'fontChoice',{value=8}},{'crossStyle',{value=6}},{'downCrossStyle',{value=-1}},
        {'enabled',{value='1'}},{'downCrossVisible',{value=2}},{'item',{id=14,field='x',value=.2}},
        {'item',{id=0,field='unknown',value=1}},{'item',{id=0,field='size',value=14.5}},
        {'item',{id=0,field='x',value=0/0}},{'item',{id=0,field='x',value=math.huge}},
        {'position',{id=0,x=1.001,y=0}},{'selectItem',{id=-1}},{'previewDown',{value='false'}},{'unknown',{}},
        {'item',{id=0,field='color',value=5}}})do
        assert(not c:execute(request[1],request[2])and files[path]==readonly,'Invalid command must not alter persisted bytes')
    end
    assert(not c:execute(nil,{})and not c:execute('enabled',nil))
    rendered=c:snapshot();rendered.selectedItemID=0;rendered.items[1].x=.1412345
    local translated=M.rows(rendered,function(v)return 'T:'..v end)
    assert(translated[5].value==tostring(rendered.items[1].size)and translated[5].format(99.6)=='72'
        and rendered.items[1].x==.1412345,'Arbitrary external coordinates remain unchanged while the compact size inspector renders safely')
end
print('PASS pda_osd full inline row commands/latest sibling preservation/reset/validation')

for _,scenario in ipairs({'write','partial','backup','commit','verify','backup_remove','read_error'})do
    local c,files,calls,hooks,_,path,temp,backup=fixture(current)
    if scenario=='write'then hooks.write=function()return true,false,'denied'end
    elseif scenario=='partial'then hooks.write=function(name,text)files[name]=text:sub(1,20);return true,true end
    elseif scenario=='backup'then hooks.rename=function(from)if from==path then return true,false,'denied'end end
    elseif scenario=='commit'then hooks.rename=function(from)if from==temp then return true,false,'denied'end end
    elseif scenario=='verify'then hooks.afterRename=function(from,to)if from==temp then files[to]='bad readback'end end
    elseif scenario=='backup_remove'then files[backup]='old own rollback';hooks.remove=function(name)if name==backup then return true,false,'denied'end end
    elseif scenario=='read_error'then hooks.read=function(name)if name==path then return true,nil,'io_error','denied'end end end
    local ok,reason=c:execute('fontChoice',{value=2});assert(not ok and files[path]==current,'Prior destination lost on '..scenario..': '..tostring(reason))
    assert(files[temp]==nil,'Temporary file must be cleaned after '..scenario)
    if scenario~='backup_remove'then assert(files[backup]==nil,'Restored backup must not remain after '..scenario)end
    if scenario=='read_error'then assert(calls.write==0)end
end
do
    local c,files,_,hooks,time,path,temp,backup=fixture(current)
    hooks.rename=function(from)if from==temp or from==backup then return true,false,'denied'end end
    local ok,reason=c:execute('crossStyle',{value=4});assert(not ok and reason=='rollback_failed'and files[path]==nil and files[backup]==current)
    assert(c:snapshot().crossStyle==2 and c:snapshot().lastError=='rollback_failed','A failed rollback retains last-good in memory and recoverable original bytes')
    hooks.rename=nil;time(1);local reopened=M.new('fixture',{fs={read=function(name,limit)
        return files[name]and files[name]:sub(1,limit+1)or nil,files[name]and nil or 'missing'
    end,write=function(name,text)files[name]=text;return true end,rename=function(a,b)
        if files[b]or not files[a]then return false end;files[b],files[a]=files[a],nil;return true
    end,remove=function(name)files[name]=nil;return true end},clock=function()return 1 end})
    assert(reopened:snapshot().status=='recovery_needed'and reopened:snapshot().fontChoice==7 and files[path]==nil,'Opening only reads an interrupted transaction backup')
    assert(reopened:execute('fontChoice',{value=2})and M.parse(files[path]).fontChoice==2 and not files[backup])
end
for _,moment in ipairs({'before','during','after'})do
    local c,files,_,hooks,time,path,temp,backup=fixture(current)
    local external=M.defaults();external.fontChoice=6;external.items[1].x=.2222222222222222;local externalText=M.serialize(external)
    if moment=='before'then hooks.write=function(name,text)files[name]=text;files[path]=externalText;return true,true end
    elseif moment=='during'then hooks.rename=function(from,to)if from==temp then files[path]=externalText;return true,false,'File exists'end end
    else hooks.afterRename=function(from,to)if from==temp then files[to]=externalText end end end
    local ok,reason=c:execute('crossStyle',{value=4});assert(not ok and reason=='conflict'and files[path]==externalText,
        'A complete external edit must win rather than be overwritten during '..moment..' commit race')
    assert(c:snapshot().fontChoice==6 and c:snapshot().items[1].x==external.items[1].x)
    files[path]=nil;time(1)
    assert(c:snapshot().status=='missing'and c:snapshot().fontChoice==6,
        'An old retained rollback must not replace the newer last-valid external state during a subsequent missing-file interval')
end
print('PASS pda_osd verified Windows transaction/rollback/recovery/concurrent editor protection')

do
    assert(#M.rows({})==13 and #M.preview({})==0,'Incomplete optional PDA snapshots must safely fall back')
    local s=M.defaults();s.selectedItemID=4;s.previewDown=false
    for _,e in ipairs(s.items)do e.visible=true end
    local expected={4,1,4,16,17,8}
    for style=0,5 do
        s.crossStyle=style;local primitives,bounds=M.preview(s);local lines,texts,cross=0,0,0
        assert(#bounds==14)
        for _,e in ipairs(primitives)do
            if e.kind=='line'then lines=lines+1;if e.id==4 then cross=cross+1 end else texts=texts+1 end
            assert(e.x>=0 and e.x<=1 and e.y>=0 and e.y<=1 and e.width>=0 and e.width<=1 and e.height>=0 and e.height<=1)
            assert(e.colorRGB.R>=0 and e.colorRGB.R<=1 and e.colorRGB.A==1)
        end
        assert(cross==expected[style+1]and lines<=32 and texts==11,'All actual crosshair styles fit bounded native preview primitives')
        assert(bounds[5].selected and bounds[12].visible and primitives[#primitives].text=='GRENADES 3')
    end
    s.items[5].visible=false;s.downCrossVisible=true;s.previewDown=true;s.downCrossStyle=4
    local primitives,bounds=M.preview(s);local cross,horizon=0,0
    for _,e in ipairs(primitives)do if e.id==4 then cross=cross+1 elseif e.id==3 then horizon=horizon+1 end end
    assert(cross==17 and horizon==0 and not bounds[4].visible and bounds[5].visible,'Bottom preview hides horizon and has independent crosshair style/visibility')
    s.downCrossVisible=false;primitives=M.preview(s);for _,e in ipairs(primitives)do assert(e.id~=4)end
    s.enabled=false;primitives=M.preview(s);local visibleText=0
    for _,e in ipairs(primitives)do if e.kind=='text'and e.visible then visibleText=visibleText+1 end end
    assert(visibleText==11,'Native editor preview remains usable with live OSD master disabled')
    s.enabled=true;s.previewDown=false;s.items[4].x=0;s.items[4].y=0;s.items[5].visible=true;s.items[5].x=1;s.items[5].y=1
    s.items[8].x=0;s.items[8].y=1;s.crossStyle=4
    primitives,bounds=M.preview(s,200,900)
    for _,e in ipairs(primitives)do assert(e.x>=0 and e.y>=0 and e.x<=1 and e.y<=1)
        if e.kind=='line'then assert(e.x2>=0 and e.y2>=0 and e.x2<=1 and e.y2<=1)end
    end
    for _,e in ipairs(bounds)do assert(e.x>=0 and e.y>=0 and e.x+e.width<=1.00000001 and e.y+e.height<=1.00000001)end
end
print('PASS pda_osd bounded native preview/colors/styles/down-camera/edge clipping')
do
    local s=M.defaults();s.selectedItemID=0
    local _,bounds=M.preview(s)
    for _,id in ipairs({0,1,2,5,6,7,10,11,12,13})do
        local b=bounds[id+1]
        assert(M.hit(s,b.x+b.width/2,b.y+b.height/2)==id,'Visible preview item must be selectable: '..id)
    end
    assert(M.hit(s,.5,.5)==4,'The crosshair must win its overlap with the horizon')
    assert(M.hit(s,.55,.5)==3,'Horizon remains selectable away from the crosshair')
    s.items[5].visible=false;assert(M.hit(s,.5,.5)==3,'A hidden crosshair must not intercept another item')
    s.previewDown=true;s.downCrossVisible=true
    assert(M.hit(s,.5,.5)==4 and M.hit(s,.55,.5)==nil,'Bottom preview has independent cross visibility and no horizon')
    s.downCrossVisible=false;assert(M.hit(s,.5,.5)==nil)
    s.enabled=false;s.previewDown=false;s.items[5].visible=true
    assert(M.hit(s,.5,.5)==4,'Master-off layouts remain selectable like the F6 editor')
    assert(M.hit(s,.14,.73)==nil,'Hidden text items cannot be picked from the preview')
    local b=bounds[1]
    assert(M.hit(s,b.x,b.y)==0 and M.hit(s,b.x+b.width,b.y)==nil,'Selection uses half-open visible bounds')
    assert(M.hit({},.5,.5)==nil and M.hit(s,-.01,.5)==nil and M.hit(s,.5,1.01)==nil)
    assert(M.hit(s,0/0,.5)==nil and M.hit(s,math.huge,.5)==nil)
    local before=M.serialize(s);local dx,dy=.01,-.007
    local stationary=assert(M.dragPosition(s,0,s.items[1].x+dx,s.items[1].y+dy,dx,dy))
    assert(near(stationary.x,s.items[1].x)and near(stationary.y,s.items[1].y),'Picking text off-center must not jump its anchor')
    local moved=assert(M.dragPosition(s,0,.45,.60,dx,dy))
    assert(near(moved.x,.44)and near(moved.y,.607)and moved.id==0)
    local edge=assert(M.dragPosition(s,13,2,-1,0,0));assert(edge.x==.98 and edge.y==.02)
    assert(not M.dragPosition(s,14,.5,.5)and not M.dragPosition(s,0,0/0,.5)
        and not M.dragPosition(s,0,.5,math.huge)and not M.dragPosition({},0,.5,.5)
        and not M.dragPosition(s,0,nil,.5)and not M.dragPosition(s,0,.5,nil))
    assert(M.serialize(s)==before,'Hit testing and drag drafts cannot mutate the persisted snapshot')
    local c,files,calls,_,_,path=fixture(before);local writes=calls.write
    assert(c:execute('selectItem',{id=13}));local snap=c:snapshot()
    for n=1,100 do assert(M.dragPosition(snap,13,n/100,.5))end
    assert(calls.write==writes and files[path]==before,'Unfinished drag previews must not perform disk I/O')
    assert(c:execute('position',moved)and calls.write==writes+1)
    local saved=assert(M.parse(files[path]));assert(saved.items[1].x==moved.x and saved.items[1].y==moved.y)
    assert(saved.items[14].x==s.items[14].x,'One release changes only the chosen item')
end
print('PASS pda_osd preview hit order/hidden items/grab offsets/clamped single-release edits')
if arg and arg[1]then
    -- Optional isolated directory created by the caller. Never overwrite an
    -- existing layout or transaction file outside this test's ownership.
    local root=arg[1];if not root:match('[/\\]$')then root=root..'/'end
    for _,name in ipairs({'osd-layout.txt','osd-layout.pda.tmp','osd-layout.pda.rollback'})do
        local f=io.open(root..name,'rb');if f then f:close();error('Real-I/O fixture must be empty: '..name)end
    end
    local c=M.new(root,{clock=function()return 0 end})
    assert(c:snapshot().status=='missing')
    assert(c:execute('fontChoice',{value=7})and c:execute('crossStyle',{value=5}))
    assert(c:execute('position',{id=13,x=.12345678901234566,y=.9876543210123456}))
    assert(c:execute('downCrossVisible',{value=false}))
    local reopened=M.new(root);local saved=reopened:snapshot()
    assert(saved.sourceVersion==7 and saved.fontChoice==7 and saved.crossStyle==5 and not saved.downCrossVisible)
    assert(saved.items[14].x==.12345678901234566 and saved.items[14].y==.9876543210123456)
    for _,name in ipairs({'osd-layout.pda.tmp','osd-layout.pda.rollback'})do
        local f=io.open(root..name,'rb');if f then f:close();error('Real-I/O transaction leaked: '..name)end
    end
    assert(os.remove(root..'osd-layout.txt'))
    print('PASS pda_osd real Windows io.open/write/close/rename/reopen precision and cleanup')
end
print('PASS pda_osd inline complete editor, legacy native compatibility and rollback-safe latest-state saves')
