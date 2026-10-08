-- Restore only focus acquired by the pawn while it represented the drone.
-- Never change faction/relation values or reset an actor with a baseline target.
local M={}
local serial=0
local baselineLimit=2048
local liveAggression,observerRegistered
local function uint(v,max)return type(v)=='number' and v==v and v%1==0 and v>=0 and v<=(max or 0xffffffff)end
local function address(o)
    local ok,v=pcall(function()if o and o:IsValid()then return o:GetAddress()end end)
    return ok and uint(v,0x7fffffffffff) and v>=0x10000 and v%8==0 and v or nil
end
local function current(s,a)
    local world=address(s.world);if not world or not address(a)then return false end
    local ok,w=pcall(function()return a:GetWorld()end)
    return ok and address(w)==world
end
function M.new(root,loader)
    if loader==nil then loader=package and package.loadlib end
    local client={root=root,functions={},playerGuid=0xffffffff}
    local function request(self,pawn,actors,clear)
        if type(actors)~='table'then return nil,'aggression actors unavailable'end
        local pawnAddress=address(pawn);if not pawnAddress or #actors==0 or #actors>16 then return nil,'aggression identity unavailable'end
        local method=clear and 'clear' or 'query'
        local fn=self.functions[method]
        if not fn then
            if type(loader)~='function'then return nil,'native aggression loader unavailable'end
            local why;fn,why=loader(root..'ZoneFPVNative.dll','zonefpv_aggression_'..method)
            if type(fn)~='function'then return nil,tostring(why)end
            self.functions[method]=fn
        end
        serial=serial+1;local id=serial
        local rows={string.format('ZFPVAG12 %d %d %x %u %d\n',id,clear and 1 or 0,pawnAddress,self.playerGuid,#actors)}
        local ids={}
        for i,item in ipairs(actors)do
            local a=clear and item.actor or item;local at=address(a);if not at then return nil,'aggression actor expired'end
            ids[i]=at
            rows[#rows+1]=string.format('%x %u %x %d %d\n',at,clear and item.guid or 0xffffffff,clear and item.core or 0,
                clear and item.index or -1,clear and item.acquired and 1 or 0)
        end
        local file,why=io.open(root..'native-aggression-control.txt','wb');if not file then return nil,tostring(why)end
        local written=file:write(table.concat(rows));local closed=file:close()
        if not written or not closed then return nil,'aggression request write failed'end
        os.remove(root..'native-aggression-status.txt')
        local ok,err=pcall(fn);if not ok then return nil,tostring(err)end
        file,why=io.open(root..'native-aggression-status.txt','rb');if not file then return nil,tostring(why)end
        local data=file:read(4096);local extra=file:read(1);file:close()
        if not data or extra then return nil,'aggression response exceeds limit'end
        local lines={};for line in data:gmatch('[^\r\n]+')do lines[#lines+1]=line end
        local ready,response,playerGuid,count,code=(lines[1]or''):match('^ZFPVAG12 (%d+) (%d+) (%d+) (%d+) (%d+)$')
        ready,response,playerGuid,count,code=tonumber(ready),tonumber(response),tonumber(playerGuid),tonumber(count),tonumber(code)
        if ready~=1 or response~=id or count~=#actors or code~=0 or #lines~=count+1 or not uint(playerGuid) or playerGuid>=0xfffffff0 then return nil,'aggression response rejected'end
        if self.playerGuid~=0xffffffff and self.playerGuid~=playerGuid then return nil,'aggression player changed'end
        local result={}
        for i=1,count do
            local at,guid,core,index,focus,changed,attempted,reason=lines[i+1]:match('^(%x+) (%d+) (%x+) (%-?%d+) (%x+) (%d+) (%d+) (%d+)$')
            at,guid,core,index,focus,changed=tonumber(at,16),tonumber(guid),tonumber(core,16),tonumber(index),tonumber(focus,16),tonumber(changed)
            attempted,reason=tonumber(attempted),tonumber(reason)
            if at~=ids[i] or not uint(guid) or not uint(core,0x7fffffffffff) or not uint(focus,0x7fffffffffff) or
                not index or index%1~=0 or index< -1 or index>0x7fffffff or not uint(changed,1)
                or not uint(attempted,1) or not uint(reason,6) or changed>attempted then return nil,'aggression row malformed'end
            if guid<0xfffffff0 and core>=0x10000 and core%8==0 and index>=0 and (focus==0 or focus>=0x10000 and focus%8==0)then
                result[at]={guid=guid,core=core,index=index,focus=focus,cleared=changed==1,attempted=attempted==1,reason=reason}
            elseif guid~=0xffffffff or core~=0 or index~= -1 or focus~=0 or changed~=0 or attempted~=0 or (reason~=0 and reason~=3) then return nil,'aggression row identity rejected'end
        end
        self.playerGuid=playerGuid
        return result
    end
    function client:request(pawn,actors,clear)
        local ok,rows,err=pcall(request,self,pawn,actors,clear)
        if not ok then return nil,tostring(rows)end
        return rows,err
    end
    return client
end
function M.start(s,root,log,client)
    if not current(s,s.pawn) or type(FindAllOf)~='function'then return end
    local ok,list=pcall(FindAllOf,'Agent');if not ok or type(list)~='table'then return end
    local g={pawn=s.pawn,world=s.world,baseline={},baselineRows={},pruneCursor=0,observeCursor=0,pending={},acquiredCount=0,
        client=client or M.new(root),log=log,active=false,nextRead=0}
    liveAggression=g
    if observerRegistered==nil and type(NotifyOnNewObject)=='function'then
        observerRegistered=pcall(NotifyOnNewObject,'/Script/Stalker2.Agent',function(actor)
            local live=liveAggression
            if live and live.active and #live.pending<128 then live.pending[#live.pending+1]={actor=actor,tries=0}end
        end)
    end
    function g:prune()
        -- Keep every still-valid actor's first focus for exit restoration.
        -- An address alone cannot prove replacement: ambiguous reuse retains
        -- the old row, and native GUID/core/index guards reject its cleanup.
        for _=1,math.min(16,#self.baselineRows)do
            local rows=self.baselineRows;if #rows==0 then break end
            self.pruneCursor=self.pruneCursor%#rows+1
            local row=rows[self.pruneCursor]
            if not address(row.actor)then
                if self.baseline[row.address]==row then self.baseline[row.address]=nil end
                rows[self.pruneCursor]=rows[#rows];rows[#rows]=nil
                self.pruneCursor=self.pruneCursor-1
            end
        end
    end
    function g:capture(actors,bornDuringFlight)
        local pending,seen={},{}
        for _,a in ipairs(actors)do
            local at=address(a)
            if at and not self.baseline[at] and not seen[at]then
                if #self.baselineRows+#pending>=baselineLimit then
                    if not self.capacityReported then
                        self.capacityReported=true
                        if self.log then self.log('Drone aggression: baseline limit 2048; uncaptured actors retain their targets on exit')end
                    end
                    break
                end
                pending[#pending+1]=a;seen[at]=true
            end
        end
        if #pending==0 then return true end
        local ok,rows,err=pcall(self.client.request,self.client,self.pawn,pending,false)
        if not ok or type(rows)~='table'then self.failure=tostring(ok and err or rows);return false end
        for _,a in ipairs(pending)do
            local at=address(a);local row=at and rows[at]
            if row and not self.baseline[at]then
                -- A construction event after activation proves this actor did
                -- not own a pre-flight target. Existing loaded NPC snapshots
                -- remain protected, even when their initial target is player.
                if bornDuringFlight and row.focus==address(self.pawn)then
                    row.firstFocus=row.focus;row.focus=0;row.acquired=true;self.acquiredCount=self.acquiredCount+1
                end
                row.actor=a;row.address=at;self.baseline[at]=row
                self.baselineRows[#self.baselineRows+1]=row
            end
        end
        return true
    end
    function g:observe(actors)
        if #actors==0 then return true end
        local ok,rows,err=pcall(self.client.request,self.client,self.pawn,actors,false)
        if not ok or type(rows)~='table'then
            self.observationFailure=tostring(ok and err or rows);return false
        end
        local pawn=address(self.pawn)
        for _,a in ipairs(actors)do
            local at=address(a);local baseline=at and self.baseline[at];local row=at and rows[at]
            if baseline and row and baseline.guid==row.guid and baseline.core==row.core and baseline.index==row.index
                and baseline.focus==0 and row.focus==pawn and not baseline.acquired then
                baseline.acquired=true;self.acquiredCount=self.acquiredCount+1
            end
        end
        return true
    end
    function g:prepare()
        -- Called before proxy parking: preserve acquisition evidence while
        -- GetFocusedEnemy can still see the live drone target. Native ResetAI
        -- then runs after parking, even if current aim has become null.
        local batch={}
        for _,row in ipairs(self.baselineRows)do
            if row.focus==0 and not row.acquired and current({world=self.world},row.actor)then
                batch[#batch+1]=row.actor
                if #batch==16 then self:observe(batch);batch={}end
            end
        end
        self:observe(batch)
    end
    function g:activate()
        self.active=true
        if self.failure and self.log then self.log('Drone aggression: snapshot unavailable: '..self.failure)end
    end
    function g:update(session,now)
        if not self.active or self.failure or type(now)~='number' or now~=now or now<self.nextRead then return end
        if address(session.pawn)~=address(self.pawn) or address(session.world)~=address(self.world) or not current(session,self.pawn)then return end
        self.nextRead=now+.25
        self:prune()
        local newborn,newbornEntries={},{}
        for _=1,math.min(16,#self.pending)do
            local entry=table.remove(self.pending,1)
            if current(session,entry.actor)then newborn[#newborn+1]=entry.actor;newbornEntries[#newbornEntries+1]=entry
            elseif entry.tries<20 then entry.tries=entry.tries+1;self.pending[#self.pending+1]=entry end
        end
        if #newborn>0 then
            self:capture(newborn,true)
            -- Construction can precede ActorCore/AI initialization. Retain a
            -- bounded retry instead of letting the scanner misclassify it as
            -- an old actor whose already-acquired pawn target must be protected.
            for _,entry in ipairs(newbornEntries)do
                if not self.baseline[address(entry.actor)] and entry.tries<20 and #self.pending<128 then
                    entry.tries=entry.tries+1;self.pending[#self.pending+1]=entry
                end
            end
        end
        local batch={}
        local awaiting={};for _,entry in ipairs(self.pending)do local at=address(entry.actor);if at then awaiting[at]=true end end
        for _,entry in ipairs(session.worldExperiments and session.worldExperiments.entries or {})do
            if type(entry.type)=='number' and entry.type>=1 and entry.type<=2 and not self.baseline[address(entry.actor)]
                and not awaiting[address(entry.actor)] and current(session,entry.actor)then
                batch[#batch+1]=entry.actor;if #batch>=16 then break end
            end
        end
        if #batch>0 then self:capture(batch)end
        batch={}
        for _=1,math.min(64,#self.baselineRows)do
            self.observeCursor=self.observeCursor%#self.baselineRows+1
            local row=self.baselineRows[self.observeCursor]
            if row.focus==0 and not row.acquired and current(session,row.actor)then
                batch[#batch+1]=row.actor;if #batch==16 then break end
            end
        end
        self:observe(batch)
    end
    function g:restore()
        if not self.active then return true end
        self.active=false;if liveAggression==self then liveAggression=nil end;self.pending={}
        local batch={};local cleared,protected,attempted,unobserved,other,identity=0,0,0,0,0,0;local errors={}
        if not current({world=self.world},self.pawn)then return false,'aggression player/world expired'end
        local function flush()
            local ok,rows,err=pcall(self.client.request,self.client,self.pawn,batch,true)
            if not ok or type(rows)~='table'then errors[#errors+1]=tostring(ok and err or rows)
            else
                local seen=0
                for _,row in pairs(rows)do
                    seen=seen+1
                    if row.cleared then cleared=cleared+1 end
                    if row.attempted then attempted=attempted+1 end
                    if row.reason==1 then unobserved=unobserved+1 elseif row.reason==2 then other=other+1
                    elseif row.reason==3 or row.reason==4 then identity=identity+1 end
                end
                identity=identity+#batch-seen
            end
            batch={}
        end
        for _,row in pairs(self.baseline)do
            if row.focus~=0 then protected=protected+1
            elseif current({world=self.world},row.actor)then batch[#batch+1]=row;if #batch==16 then flush()end end
        end
        if #batch>0 then flush()end
        self.cleared=cleared;self.protected=protected
        if self.log then self.log('Drone aggression: reset '..cleared..' acquired AI states; attempted='..attempted..
            '; observed='..self.acquiredCount..'; preserved baseline='..protected..'; no acquisition='..unobserved..
            '; other target='..other..'; expired/changed='..identity..
            (self.observationFailure and '; observation unavailable: '..self.observationFailure or '')..
            (#errors>0 and '; cleanup unavailable: '..errors[1]or''))end
        return #errors==0,errors[1]
    end
    local batch={}
    for i=1,math.min(#list,baselineLimit)do
        if current(s,list[i])then batch[#batch+1]=list[i]end
        if #batch==16 then if not g:capture(batch)then return g end;batch={}end
    end
    if #batch>0 then g:capture(batch)end
    return g
end
return M
