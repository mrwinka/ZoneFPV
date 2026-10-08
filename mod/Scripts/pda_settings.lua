-- A bounded, owned exchange for tools displayed inside the native PDA.
-- Only the input helper reads hardware/writes its preferences. This client
-- never starts, shows or focuses an external settings window.
local M={}
local maxInteger=9007199254740991
local function integer(value,low,high)
    return type(value)=='number'and value==value and value%1==0 and value>=low and value<=high
end
local function number(token,low,high)
    if type(token)~='string'or not token:match('^-?%d+$')then return end
    local value=tonumber(token);if integer(value,low,high)then return value end
end
local function tokens(line)
    local result={};for value in line:gmatch('%S+')do result[#result+1]=value end;return result
end
local function hex(value,maximum)
    if value=='-'then return ''end
    if type(value)~='string'or #value==0 or #value>maximum*2 or #value%2~=0 or value:find('[^%da-fA-F]')then return end
    local decoded=value:gsub('..',function(pair)return string.char(tonumber(pair,16))end)
    if decoded:find('%z')then return end
    if utf8 and not utf8.len(decoded)then return end
    return decoded
end
function M.parse(data)
    if type(data)~='string'or #data>32768 then return end
    local lines={};for line in data:gmatch('[^\r\n]+')do lines[#lines+1]=tokens(line);if #lines>72 then return end end
    local h=lines[1];if not h or #h~=21 or h[1]~='1'then return end
    local bounds={{1,maxInteger},{0,maxInteger},{1,maxInteger},{0,maxInteger},{0,1},{0,1},
        {-1,7},{0,4},{0,3},{0,15000},{0,4294967295},{0,1},{-1,32},{0,4},{0,1},{0,100},{0,1},{0,2147483647}}
    local v={}
    for i,limit in ipairs(bounds)do v[i]=number(h[i+1],limit[1],limit[2]);if v[i]==nil then return end end
    local status=hex(h[20],4096);local count=number(h[21],0,64)
    if status==nil or count==nil or #lines~=count+7 or v[17]==1 and v[18]==0 then return end
    local result={sequence=v[1],epoch=v[2],session=v[3],ack=v[4],ackOk=v[5]==1,eligible=v[6]==1,
        capture={row=v[7],remainingMs=v[10]},calibration={stage=v[8],axis=v[9],remainingMs=v[10]},
        device=v[11],connected=v[12]==1,backend=v[13],language=v[14],theme=v[15],volume=v[16],
        objectLimit={has=v[17]==1,value=v[18]},status=status,devices={}}
    local ids={}
    for i=1,count do
        local row=lines[i+1];if #row~=4 or row[1]~='D'then return end
        local id,backend,name=number(row[2],1,4294967295),number(row[3],-1,32),hex(row[4],1024)
        if id==nil or backend==nil or name==nil or ids[id]then return end
        ids[id]=true;result.devices[i]={id=id,backend=backend,name=name}
    end
    local profile=lines[count+2]
    if #profile~=2 or profile[1]~='P'then return end
    result.profile=number(profile[2],0,10);if result.profile==nil then return end
    local descriptors={{'B','bindings',0,3024},{'L','bindingLabels'},{'M','modes',0,1},{'A','axes',0,65535}}
    for i,description in ipairs(descriptors)do
        local row=lines[count+2+i];if #row~=9 or row[1]~=description[1]then return end
        local values={}
        for j=1,8 do
            if description[1]=='L'then values[j]=hex(row[j+1],256)
            else values[j]=number(row[j+1],description[3],description[4])end
            if values[j]==nil then return end
            if description[1]=='B'then
                local code=values[j]
                if not(code==0 or code>=1 and code<=255 or code>=1001 and code<=1128 or code>=2001 and code<=2032 or code>=3001 and code<=3024)then return end
            end
        end
        result[description[2]]=values
    end
    local tail=lines[count+7]
    if #tail~=2 or tail[1]~='1'or number(tail[2],1,maxInteger)~=result.sequence then return end
    return result
end
local commands={device={1,1,0,4294967295},profile={1,1,0,10},calibrate={1,1,0,1},
    capture={9,1,0,7},clear={9,1,0,7},cancel={9,1,0,0},modes={9,2,0,7,0,1},
    language={10,1,0,4},theme={10,1,0,1},audio={10,1,0,100},limit={10,1,1,2147483647},limitreset={10,1,0,0}}
local function readFile(path,maximum)
    local file=io.open(path,'r');if not file then return end
    local value=file:read(maximum+1);file:close();if value and #value<=maximum then return value end
end
local function writeFile(path,value)
    -- Strict frame/trailer validation makes an interrupted write unreadable;
    -- readers keep their last valid heartbeat until its original lease ends.
    local file=io.open(path,'w');if not file then return false end
    local ok=file:write(value);local closed=file:close();return ok~=nil and closed~=nil
end
local function clone(value)
    if type(value)~='table'then return value end
    local copy={};for k,v in pairs(value)do copy[k]=clone(v)end;return copy
end
function M.new(root,opts)
    opts=opts or {};local clock=opts.clock or os.clock;local epoch=opts.epoch or function()return os.time()*1000 end
    local read=opts.read or readFile;local write=opts.write or writeFile
    local ownerPath,requestPath,statePath=root..'pda-settings-owner.txt',root..'pda-settings-request.txt',root..'pda-settings-state.txt'
    local now=clock();local session=math.floor(epoch()/1000)*1000000+math.floor((now%1)*1000000)
    if session<1 then session=1 end
    local previous=read(ownerPath,256)
    if previous then
        local old=tonumber(previous:match('^1 (%d+) '))
        if integer(old,1,maxInteger-1)then session=math.max(session,old+1)end
    end
    local self={open=false,section=0,mouseBlocked=false,session=session,sequence=0,queue={},pending=nil,
        nextOwner=0,nextState=0,lastStateAt=nil,lastStateSequence=nil,lastStateRaw=nil,state=nil,lastId=0,status='',localError=false}
    local function current(time)
        return self.state and self.lastStateAt and time>=self.lastStateAt and time-self.lastStateAt<=.75
            and math.abs(epoch()-self.state.epoch)<=2000
    end
    local function publish(time,force)
        if not force and time<self.nextOwner then return true end
        self.nextOwner=time+.1;self.sequence=self.sequence+1
        local frame=string.format('1 %.0f %.0f %.0f %d %d %d %.0f\n',session,self.sequence,epoch(),self.open and 1 or 0,self.section,self.mouseBlocked and 1 or 0,self.sequence)
        local ok=write(ownerPath,frame);if not ok then self.status='Не удалось применить';self.localError=true end;return ok
    end
    function self:setContext(open,section,mouseBlocked)
        section=integer(section,0,10)and section or 0
        open=open==true and(section==1 or section==9 or section==10)
        if not open then section=0 end
        mouseBlocked=open and mouseBlocked==true
        if self.open==open and self.section==section and self.mouseBlocked==mouseBlocked then return end
        if self.open~=open or self.section~=section then
            self.queue={};self.pending=nil;self.status='';self.localError=false
        end
        self.open,self.section,self.mouseBlocked=open,section,mouseBlocked
        publish(clock(),true)
    end
    function self:request(kind,args)
        local descriptor=commands[kind]
        if not descriptor or type(args)~='table'or #args~=descriptor[2]then return false,'Не удалось применить'end
        local captured={}
        for i=1,#args do
            if not integer(args[i],descriptor[i*2+1],descriptor[i*2+2])then return false,'Не удалось применить'end
            captured[i]=args[i]
        end
        if not self.open or self.section~=descriptor[1]then return false,'Не удалось применить'end
        if not current(clock())or not self.state.eligible or self.state.session~=session then return false,'Программа ввода не готова'end
        -- Coalesce only queued value edits. Capture/calibration/clear are
        -- discrete actions whose order must be retained.
        if kind=='modes'or kind=='language'or kind=='theme'or kind=='audio'or kind=='limit'then
            for i=#self.queue,1,-1 do local row=self.queue[i]
                if row.kind==kind and(kind~='modes'or row.args[1]==captured[1])then table.remove(self.queue,i)end
            end
        end
        if #self.queue>=16 then return false,'Настройки применяются…'end
        self.queue[#self.queue+1]={kind=kind,args=captured,section=self.section}
        self.status='Настройки применяются…';self.localError=false;return true,self.status
    end
    function self:update(time)
        time=time or clock();publish(time)
        if time>=self.nextState then
            self.nextState=time+.05
            local raw=read(statePath,32768);local state=M.parse(raw)
            if state and math.abs(epoch()-state.epoch)<=2000 and
                (state.sequence~=self.lastStateSequence or raw==self.lastStateRaw)then
                if self.lastStateSequence and state.sequence<self.lastStateSequence then
                    -- A helper restart must cancel, never replay, queued work.
                    self.pending=nil;self.queue={};self.lastStateAt=nil
                end
                if state.sequence~=self.lastStateSequence then self.lastStateAt=time end
                self.lastStateSequence=state.sequence;self.lastStateRaw=raw;self.state=state
            end
        end
        if self.pending then
            local pending=self.pending
            if current(time)and self.state.session==session and self.state.ack==pending.id then
                -- New helpers mark a current failure cause; older helpers may
                -- carry an unrelated preceding success with a rejected ack.
                self.status=self.state.ackOk and self.state.status or
                    (self.state.status:match('^! (.+)$')or 'Не удалось применить')
                self.localError=not self.state.ackOk;self.pending=nil
            elseif time-pending.sent>=2 or not self.open or pending.section~=self.section then
                self.pending=nil;self.queue={};self.status='Программа ввода не готова';self.localError=true
            end
        end
        if not self.pending and #self.queue>0 and self.open then
            if not current(time)or not self.state.eligible or self.state.session~=session then
                self.queue={};self.status='Программа ввода не готова';self.localError=true;return
            end
            local item=table.remove(self.queue,1)
            self.lastId=math.max(self.lastId+1,math.floor(time*1000000))
            local id=self.lastId;local args={};for i,v in ipairs(item.args)do args[i]=string.format('%.0f',v)end
            local frame=string.format('1 %.0f %.0f %.0f %d %s %s %.0f\n',session,id,epoch(),item.section,item.kind,table.concat(args,' '),id)
            if write(requestPath,frame)then item.id,item.sent=id,time;self.pending=item
            else self.queue={};self.status='Не удалось применить';self.localError=true end
        end
    end
    function self:snapshot()
        local state=clone(self.state or {devices={},bindings={},bindingLabels={},modes={},axes={},device=0,profile=0,connected=false,backend=-1,
            language=0,theme=0,volume=100,objectLimit={has=false,value=1048576},capture={row=-1,remainingMs=0},calibration={stage=0,axis=0,remainingMs=0},status=''})
        state.available=current(clock())==true;state.eligible=state.available and state.eligible==true and state.session==session
        if not state.eligible then state.capture.row=-1;state.calibration.stage=0 end
        state.pending=self.pending~=nil or #self.queue>0
        if self.status~=''and(state.pending or not state.available or self.localError)then state.status=self.status end
        state.status=state.status:gsub('^! ','')
        return state
    end
    function self:destroy()self:setContext(false,0);self.queue={};self.pending=nil end
    publish(now,true)
    return self
end
return M
