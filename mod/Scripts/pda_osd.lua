-- Pure PDA adapter for the same versioned layout used by src/osd.h.
-- Reads/repaints never save. Edits reread the latest file, change one field and
-- publish a verified temporary file with rollback on Windows rename failures.
local M={version=7,itemCount=14,pollInterval=.25,maxBytes=4096}
M.fonts={'Consolas','Betaflight','Cascadia Mono','Courier New','Lucida Console','Segoe UI','Arial','Bahnschrift'}
M.styles={'Крест','Точка','Раздельный крест','Кольцо','Кольцо с точкой','Уголки'}
M.colorNames={'Белый','Зелёный','Жёлтый','Голубой','Красный'}
local rgb={{255,255,255},{80,255,110},{255,220,60},{60,225,255},{255,110,110}}
local labels={'Скорость','Высота от старта','Расстояние до старта','Горизонт','Прицел','Время полёта',
    'Курс','Направление к старту','Газ','Вертикальная скорость','RSSI','Здоровье дрона','Детектор артефактов','Запас гранат'}
local defaults={{.14,.80,24,0,true},{.82,.80,24,0,true},{.82,.86,24,0,true},{.50,.50,24,0,true},
    {.50,.50,24,0,true},{.14,.86,24,0,true},{.50,.12,24,0,true},{.50,.21,24,0,true},
    {.14,.73,24,0,false},{.82,.73,24,0,false},{.14,.66,24,0,true},{.90,.09,14,0,true},
    {.90,.14,14,3,true},{.90,.19,14,2,true}}
local function copy(value)
    if type(value)~='table'then return value end
    local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
end
local function bounded(v,a,b,integer)
    return type(v)=='number'and v==v and v>=a and v<=b and (not integer or v%1==0)
end
local function bool(v)
    if type(v)=='boolean'then return v end
    if v==0 then return false end;if v==1 then return true end
end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function defaultItems()
    local out={};for i,d in ipairs(defaults)do out[i]={id=i-1,label=labels[i],x=d[1],y=d[2],size=d[3],color=d[4],visible=d[5]}end
    return out
end
function M.defaults()
    return {version=7,enabled=true,crossStyle=0,fontChoice=0,downCrossStyle=4,downCrossVisible=true,items=defaultItems()}
end
local function decimal(token)
    if type(token)~='string'or #token>40 then return end
    local base,exponent=token:match('^(.-)[eE]([+-]?%d+)$')
    base=base or token
    if not (base:match('^[+-]?%d+%.?%d*$')or base:match('^[+-]?%.%d+$'))then return end
    if not exponent and token:find('[eE]')then return end
    local value=tonumber(token)
    if bounded(value,-math.huge,math.huge)and value~=math.huge and value~=-math.huge then return value end
end
local function integer(token)
    if type(token)~='string'or not token:match('^[+-]?%d+$')or #token>12 then return end
    return tonumber(token)
end
function M.parse(text)
    if type(text)~='string'or #text>M.maxBytes then return nil,'invalid_size' end
    local tokens={};for token in text:gmatch('%S+')do tokens[#tokens+1]=token;if #tokens>76 then return nil,'extra_fields'end end
    local v=integer(tokens[1]);if not bounded(v,1,7,true)then return nil,'invalid_version'end
    local result=M.defaults();local on,style=integer(tokens[2]),integer(tokens[3])
    if not bounded(on,0,1,true)or not bounded(style,0,v>=6 and 5 or 2,true)then return nil,'invalid_header'end
    result.enabled,result.crossStyle=on==1,style
    local index=4
    if v>=2 then
        result.fontChoice=integer(tokens[index]);index=index+1
        if not bounded(result.fontChoice,0,7,true)then return nil,'invalid_font'end
    end
    if v>=6 then
        result.downCrossStyle=integer(tokens[index]);index=index+1
        if not bounded(result.downCrossStyle,0,5,true)then return nil,'invalid_down_style'end
    end
    if v>=7 then
        local visible=integer(tokens[index]);index=index+1
        if not bounded(visible,0,1,true)then return nil,'invalid_down_visibility'end
        result.downCrossVisible=visible==1
    end
    local count=v>=5 and 14 or v==4 and 13 or v==3 and 11 or 10
    if #tokens~=index-1+count*5 then return nil,'invalid_item_count'end
    for i=1,count do
        local x,y,size,color,visible=decimal(tokens[index]),decimal(tokens[index+1]),integer(tokens[index+2]),integer(tokens[index+3]),integer(tokens[index+4])
        if not bounded(x,0,1)or not bounded(y,0,1)or not bounded(size,14,72,true)
            or not bounded(color,0,4,true)or not bounded(visible,0,1,true)then return nil,'invalid_item'end
        local item=result.items[i];item.x,item.y,item.size,item.color,item.visible=x,y,size,color,visible==1
        index=index+5
    end
    result.sourceVersion=v;return result
end
local function valid(config)
    if type(config)~='table'or type(config.enabled)~='boolean'or type(config.downCrossVisible)~='boolean'
        or not bounded(config.crossStyle,0,5,true)or not bounded(config.downCrossStyle,0,5,true)
        or not bounded(config.fontChoice,0,7,true)or type(config.items)~='table'or #config.items~=14 then return false end
    for i=1,14 do
        local e=config.items[i]
        if type(e)~='table'or not bounded(e.x,0,1)or not bounded(e.y,0,1)or not bounded(e.size,14,72,true)
            or not bounded(e.color,0,4,true)or type(e.visible)~='boolean'then return false end
    end
    return true
end
function M.serialize(config)
    if not valid(config)then return nil,'invalid_layout'end
    local rows={string.format('7 %d %d %d %d %d',config.enabled and 1 or 0,config.crossStyle,config.fontChoice,
        config.downCrossStyle,config.downCrossVisible and 1 or 0)}
    -- Seventeen significant digits retain untouched external coordinates.
    for _,e in ipairs(config.items)do rows[#rows+1]=string.format('%.17g %.17g %d %d %d',e.x,e.y,e.size,e.color,e.visible and 1 or 0)end
    return table.concat(rows,'\n')..'\n'
end
local sample={'SPD 64 km/h','ALT +25.0 m','HOME 120 m',nil,nil,'02:05','HDG 085',nil,'THR 42%','V/S +2.1 m/s',
    'RSSI 63%','DRONE HP  86%','DETECTOR 28.9 m','GRENADES 3'}
function M.preview(snapshot,width,height)
    snapshot=type(snapshot)=='table'and snapshot or M.defaults()
    width=bounded(width,200,8192)and width or 1600;height=bounded(height,100,8192)and height or 900
    local out,bounds={},{};local selected=snapshot.selectedItemID or 0
    local function color(index)local c=rgb[index+1];return {R=c[1]/255,G=c[2]/255,B=c[3]/255,A=1}end
    local function line(id,x,y,x2,y2,c,thickness)
        -- Clip preview geometry to its canvas, including items placed at an edge.
        local dx,dy=x2-x,y2-y;local low,high=0,1
        local function clip(p,q)
            if p==0 then return q>=0 end
            local t=q/p;if p<0 then if t>high then return false end;low=math.max(low,t)
            else if t<low then return false end;high=math.min(high,t)end
            return true
        end
        if not (clip(-dx,x)and clip(dx,width-x)and clip(-dy,y)and clip(dy,height-y))then return end
        x2,y2=x+high*dx,y+high*dy;x,y=x+low*dx,y+low*dy
        out[#out+1]={kind='line',id=id,x=x/width,y=y/height,x2=x2/width,y2=y2/height,
            width=math.abs(x2-x)/width,height=math.abs(y2-y)/height,color=c,colorRGB=color(c),thickness=thickness or 2,visible=true}
    end
    if not valid(snapshot)then return out,bounds end
    for i,e in ipairs(snapshot.items)do
        local id=i-1;local visible=e.visible
        if id==4 and snapshot.previewDown then visible=snapshot.downCrossVisible end
        if id==3 and snapshot.previewDown then visible=false end
        -- As in the native editor's draw(..., true), the layout remains editable
        -- in preview even when the live OSD master switch is off.
        local px,py=e.x*width,e.y*height
        local size=clamp(math.floor(e.size*height/900),10,90)
        local left,top,right,bottom
        if id==3 then
            left,top,right,bottom=px-5*size,py-4*size,px+5*size,py+4*size
            if visible then
                local a=-12*math.pi/180;local offset=math.floor(10*size/15)
                local cx,cy=px+math.sin(a)*offset,py+math.cos(a)*offset
                for _,side in ipairs({-1,1})do line(id,cx+math.cos(a)*size*side,cy+math.sin(a)*size*side,
                    cx+math.cos(a)*size*4*side,cy+math.sin(a)*size*4*side,e.color)end
            end
        elseif id==4 then
            left,top,right,bottom=px-size,py-size,px+size,py+size
            if visible then
                local style=snapshot.previewDown and snapshot.downCrossStyle or snapshot.crossStyle
                if style==1 then line(id,px-1,py,px+2,py,e.color,3)
                elseif style==3 or style==4 then
                    for n=0,15 do local a,b=n*math.pi/8,(n+1)*math.pi/8
                        line(id,px+math.cos(a)*size/2,py+math.sin(a)*size/2,px+math.cos(b)*size/2,py+math.sin(b)*size/2,e.color)end
                    if style==4 then line(id,px-1,py,px+2,py,e.color,3)end
                elseif style==5 then
                    local radius,segment=size/2,math.max(2,math.floor(size/4))
                    for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do
                        line(id,px+sx*radius,py+sy*radius,px+sx*(radius-segment),py+sy*radius,e.color)
                        line(id,px+sx*radius,py+sy*radius,px+sx*radius,py+sy*(radius-segment),e.color)
                    end end
                else
                    local gap=style==2 and math.floor(size/3)or 0
                    for _,sign in ipairs({-1,1})do line(id,px+sign*gap,py,px+sign*size/2,py,e.color)
                        line(id,px,py+sign*gap,px,py+sign*size/2,e.color)end
                end
            end
        elseif id==7 then
            left,top,right,bottom=px-2*size,py-2*size,px+2*size,py+2*size
            if visible then local a=35*math.pi/180;local dx,dy=math.sin(a)*size,-math.cos(a)*size
                line(id,px-dx,py-dy,px+dx,py+dy,e.color);line(id,px+dx,py+dy,px+dy/2,py-dx/2,e.color)
                line(id,px+dx,py+dy,px-dy/2,py+dx/2,e.color)
            end
        else
            local text=sample[i];local textWidth=math.min(width,#text*size*(snapshot.fontChoice==1 and 12/18 or .62))
            left=clamp(px-textWidth/2,0,math.max(0,width-textWidth));top=clamp(py-size/2,0,math.max(0,height-size))
            right,bottom=left+textWidth,top+size
            out[#out+1]={kind='text',id=id,text=text,label=e.label,x=left/width,y=top/height,
                width=textWidth/width,height=size/height,size=size,fontChoice=snapshot.fontChoice,font=M.fonts[snapshot.fontChoice+1],
                color=e.color,colorRGB=color(e.color),visible=not not visible}
        end
        left,top,right,bottom=clamp(left,0,width),clamp(top,0,height),clamp(right,0,width),clamp(bottom,0,height)
        bounds[i]={id=id,x=left/width,y=top/height,width=(right-left)/width,height=(bottom-top)/height,
            visible=not not visible,selected=id==selected}
    end
    -- Estimated text bounds use a fixed glyph ratio; GDI still renders the live
    -- overlay with its selected font. The preview never mutates layout values.
    return out,bounds
end
-- Preview selection follows draw order, so the small crosshair can be selected
-- even where its bounds overlap the artificial horizon. These operations are
-- pure: a click or an unfinished drag must never write the shared layout file.
function M.hit(snapshot,x,y,width,height)
    if not valid(snapshot)or not bounded(x,0,1)or not bounded(y,0,1)then return end
    local _,bounds=M.preview(snapshot,width,height)
    for i=#bounds,1,-1 do
        local b=bounds[i]
        if b.visible and b.width>0 and b.height>0 and x>=b.x and y>=b.y
            and x<b.x+b.width and y<b.y+b.height then return b.id end
    end
end
function M.dragPosition(snapshot,id,x,y,offsetX,offsetY)
    if not valid(snapshot)or not bounded(id,0,13,true)then return end
    offsetX,offsetY=offsetX or 0,offsetY or 0
    local function finite(value)return bounded(value,-math.huge,math.huge)and value~=math.huge and value~=-math.huge end
    if not(finite(x)and finite(y)and finite(offsetX)and finite(offsetY))then return end
    -- Keep the grab point under the cursor instead of moving the item's anchor
    -- to it on the first movement; releasing outside the preview stays in frame.
    return {id=id,x=clamp(x-offsetX,.02,.98),y=clamp(y-offsetY,.02,.98)}
end
local defaultFS={}
function defaultFS.read(path,limit)
    local f,err,code=io.open(path,'rb');if not f then return nil,code==2 and 'missing'or 'io_error',err end
    local text=f:read(limit+1)or '';local closed=f:close();if not closed then return nil,'io_error','read_close_failed'end
    return text
end
function defaultFS.write(path,text)
    local f,err=io.open(path,'wb');if not f then return false,err end
    local wrote=f:write(text);local closed=f:close();return not not(wrote and closed),err
end
defaultFS.rename=os.rename;defaultFS.remove=os.remove
function M.new(root,opts)
    assert(type(root)=='string'and root~='','OSD root is required');opts=opts or {}
    if not root:match('[/\\]$')then root=root..'/'end
    local fs=opts.fs or defaultFS;local clock=opts.clock or os.clock
    local path=root..'osd-layout.txt';local temp=root..'osd-layout.pda.tmp';local backup=root..'osd-layout.pda.rollback'
    local self={};local config=M.defaults();local selected,previewDown=0,false
    local nextPoll=-math.huge;local status,lastError='defaults',nil;local observed,sourceVersion=nil,nil
    local everLoaded,recoveryPending=false,false
    local function report(message)if type(opts.log)=='function'then pcall(opts.log,'[OSD] '..message)end end
    local function read(file)
        local ok,text,kind,err=pcall(fs.read,file,M.maxBytes)
        if not ok then return nil,'io_error',tostring(text)end
        if type(text)=='string'then return text end
        return nil,kind or 'io_error',err
    end
    local function call(fn,...)
        local ok,result,err=pcall(fn,...);if not ok then return false,tostring(result)end
        return not not result,err
    end
    local function refresh(force)
        local now=clock();if not bounded(now,-math.huge,math.huge)or now==math.huge or now==-math.huge then now=0 end
        if not force and now<nextPoll then return end;nextPoll=now+M.pollInterval
        local text,kind,err=read(path);observed=text
        if text then
            local value,reason=M.parse(text)
            if value then config=value;sourceVersion=value.sourceVersion;status,lastError='loaded',nil;everLoaded,recoveryPending=true,false
            else status,lastError='invalid',reason end
        elseif kind=='missing'then
            local old=(not everLoaded or recoveryPending)and read(backup);local value=old and M.parse(old)
            if value then config=value;sourceVersion=value.sourceVersion;status,lastError='recovery_needed','incomplete_previous_save'
            else status,lastError='missing',nil end
        else status,lastError='io_error',err or kind end
    end
    function self.snapshot()
        refresh(false);local result=copy(config)
        result.sourceVersion,result.status,result.lastError=sourceVersion,status,lastError
        result.selectedItemID,result.previewDown=selected,previewDown
        result.fonts,result.styles,result.colorNames,result.colors=copy(M.fonts),copy(M.styles),copy(M.colorNames),copy(rgb)
        for _,item in ipairs(result.items)do item.scale=item.size end
        result.selectedItem=copy(result.items[selected+1]);result.previewWidth,result.previewHeight=1600,900
        return result
    end
    local function restore(before)
        local current=read(path)
        if current~=nil then
            -- A valid concurrent external edit wins over our rollback.
            if current~=before and M.parse(current)then return false,'conflict'end
            local removed=call(fs.remove,path);if not removed then return false,'rollback_failed'end
        end
        if before~=nil then
            local restored=call(fs.rename,backup,path)
            if not restored or read(path)~=before then return false,'rollback_failed'end
        end
        return true
    end
    local function publish(text,before)
        local wrote=call(fs.write,temp,text)
        if not wrote or read(temp)~=text then call(fs.remove,temp);return false,'write_failed'end
        local latest,kind=read(path)
        if latest~=before or latest==nil and kind~='missing'then call(fs.remove,temp);return false,'conflict'end
        local oldBackup=read(backup)
        if oldBackup~=nil and not call(fs.remove,backup)then call(fs.remove,temp);return false,'backup_failed'end
        if before~=nil then
            if not call(fs.rename,path,backup)then call(fs.remove,temp);return false,'backup_failed'end
            if read(backup)~=before then
                call(fs.rename,backup,path);call(fs.remove,temp);return false,'conflict'
            end
        end
        if not call(fs.rename,temp,path)then
            local rolled,reason=restore(before);call(fs.remove,temp)
            return false,rolled and 'commit_failed'or reason
        end
        local committed=read(path)
        if committed~=text or not M.parse(committed)then
            local rolled,reason=restore(before);return false,rolled and 'verify_failed'or reason
        end
        if before~=nil then call(fs.remove,backup)end
        return true
    end
    local global={enabled='bool',fontChoice=7,crossStyle=5,downCrossStyle=5,downCrossVisible='bool'}
    local itemFields={x={0,1},y={0,1},size={14,72,true},color={0,4,true},visible='bool'}
    function self.execute(action,args,colonArgs)
        if action==self then action,args=args,colonArgs end
        if type(action)~='string'or type(args)~='table'then return false,'invalid_action'end
        if action=='selectItem'then
            if not bounded(args.id,0,13,true)then return false,'invalid_item'end
            selected=args.id;return true,'selected'
        elseif action=='previewDown'then
            local value=bool(args.value);if value==nil then return false,'invalid_value'end
            previewDown=value;return true,'preview'
        end
        refresh(true)
        if status=='io_error'then return false,'read_failed'end
        if status=='invalid'and action~='resetLayout'then return false,'invalid_file'end
        if status=='recovery_needed'then
            local prior=read(backup)
            if not prior or not call(fs.rename,backup,path)or read(path)~=prior then return false,'rollback_failed'end
            refresh(true)
        end
        local next=copy(config)
        local spec=global[action]
        if spec then
            local value=spec=='bool'and bool(args.value)or args.value
            if spec=='bool'then value=bool(args.value);if value==nil then return false,'invalid_value'end
            elseif not bounded(value,0,spec,true)then return false,'invalid_value'end
            next[action]=value
        elseif action=='item'or itemFields[action]then
            local id=args.id==nil and selected or args.id;local field=action=='item'and args.field or action
            if not bounded(id,0,13,true)or not itemFields[field]then return false,'invalid_item'end
            local itemSpec=itemFields[field];local value=args.value
            if itemSpec=='bool'then value=bool(value);if value==nil then return false,'invalid_value'end
            elseif not bounded(value,table.unpack(itemSpec))then return false,'invalid_value'end
            next.items[id+1][field]=value
        elseif action=='position'then
            local id=args.id==nil and selected or args.id
            if not bounded(id,0,13,true)or not bounded(args.x,0,1)or not bounded(args.y,0,1)then return false,'invalid_value'end
            next.items[id+1].x,next.items[id+1].y=args.x,args.y
        elseif action=='resetItem'then
            local id=args.id==nil and selected or args.id;if not bounded(id,0,13,true)then return false,'invalid_item'end
            next.items[id+1]=defaultItems()[id+1]
        elseif action=='resetLayout'then
            next.items=defaultItems();next.crossStyle,next.downCrossStyle,next.downCrossVisible=0,4,true
        else return false,'invalid_action'end
        local text=M.serialize(next)
        if not text then return false,'invalid_layout'end
        if text==M.serialize(config)and status~='invalid'then return true,'unchanged'end
        local ok,reason=publish(text,observed)
        if not ok then recoveryPending=reason=='rollback_failed';refresh(true);lastError=reason;report('save failed: '..reason);return false,reason end
        config=next;config.sourceVersion=7;sourceVersion,status,lastError,observed=7,'loaded',nil,text
        everLoaded,recoveryPending=true,false
        return true,'saved'
    end
    refresh(true);return self
end
function M.itemList(snapshot,translate)
    local s=valid(snapshot)and snapshot or M.defaults();local tr=translate or function(v)return v end
    local selected=bounded(s.selectedItemID,0,13,true)and s.selectedItemID or 0
    local items={}
    for i,item in ipairs(s.items)do items[i]={id=i-1,label=tr(item.label),selected=i-1==selected}end
    return items
end
function M.rows(snapshot,translate)
    local s=valid(snapshot)and snapshot or M.defaults();local tr=translate or function(v)return v end
    local selected=bounded(s.selectedItemID,0,13,true)and s.selectedItemID or 0
    local item=s.items[selected+1];local rows={}
    local function command(action,args)return 'osd',{action=action,args=args}end
    local function row(label,value,kind,fn,help)
        local r={key=label,label=tr(label),value=tostring(value),kind=kind,command=fn,help=tr(help)};rows[#rows+1]=r;return r
    end
    local function toggle(label,value,action,args,help)
        return row(label,tr(value and 'Вкл.'or 'Выкл.'),'toggle',function()
            local next=copy(args or {});next.value=not value;return command(action,next)
        end,help)
    end
    local function choice(label,value,list,action,args,help)
        return row(label,tr(list[value+1]),'choice',function(dir)
            local next=copy(args or {});next.value=(value+(dir or 1))%#list;return command(action,next)
        end,help)
    end
    local function slider(label,value,minimum,maximum,step,format,action,args,transform,help)
        local function rounded(v)
            if not bounded(v,-math.huge,math.huge)or v==math.huge or v==-math.huge then v=value end
            return clamp(minimum+math.floor((clamp(v,minimum,maximum)-minimum)/step+.5)*step,minimum,maximum)
        end
        local function send(v)local next=copy(args);next.value=transform and transform(rounded(v))or rounded(v);return command(action,next)end
        local r=row(label,format(value),'slider',function(dir)return send(value+(dir or 1)*step)end,help)
        r.number,r.min,r.max,r.step=value,minimum,maximum,step;r.set=send;r.format=function(v)return format(rounded(v))end
    end
    toggle('Показывать OSD',s.enabled,'enabled',nil,'Включает все показатели на экране дрона.')
    choice('Шрифт OSD',s.fontChoice,M.fonts,'fontChoice',nil,'Общий шрифт всех текстовых показателей.')
    row('Элемент OSD',tr(item.label),'status',function()end,
        'Выберите один из 14 показателей для настройки.')
    toggle('Показывать элемент',item.visible,'item',{id=selected,field='visible'},'Видимость выбранного показателя. Нижний прицел настраивается отдельно.')
    slider('Размер элемента',item.size,14,72,1,function(v)return string.format('%d',v)end,'item',{id=selected,field='size'},nil,
        'Размер показателя сохраняется для экрана высотой 900 пикселей и масштабируется с разрешением.')
    choice('Цвет элемента',item.color,M.colorNames,'item',{id=selected,field='color'},'Цвет выбранного показателя.')
    toggle('Показывать обычный прицел',s.items[5].visible,'item',{id=4,field='visible'},'Видимость прицела передней камеры.')
    choice('Обычный прицел',s.crossStyle,M.styles,'crossStyle',nil,'Форма прицела передней камеры.')
    toggle('Показывать нижний прицел',s.downCrossVisible,'downCrossVisible',nil,'Нижний прицел имеет собственную видимость.')
    choice('Прицел нижней камеры',s.downCrossStyle,M.styles,'downCrossStyle',nil,'Форма прицела при взгляде вниз.')
    toggle('Предпросмотр нижней камеры',s.previewDown,'previewDown',nil,'Переключает только предпросмотр OSD; режим полёта не меняется.')
    row('Сбросить выбранный элемент',tr('Выполнить'),'action',function()return command('resetItem',{id=selected})end,
        'Возвращает положение, размер, цвет и видимость выбранного показателя.')
    row('Сбросить расположение OSD',tr('Выполнить'),'action',function()return command('resetLayout',{})end,
        'Возвращает 14 показателей и оба прицела к исходному виду. Шрифт и общий переключатель сохраняются.')
    return rows
end
return M
