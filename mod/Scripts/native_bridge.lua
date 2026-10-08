-- Native receive hook lifecycle. The DLL's zero-argument exports ignore the
-- lua_State and return zero Lua results, so no Lua/UE4SS C++ ABI is linked.
local M={}
local exported={'init','arm','tick','poll','disarm'}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function uint(v,max)return finite(v) and v%1==0 and v>=0 and v<=(max or 0x1fffffffffffff) end
local nextToken=0
local function token()
    nextToken=math.max(nextToken+1,math.floor(os.clock()*1000000),1)
    return nextToken
end
local function status(root)
    local file=io.open(root..'native-combat-status.txt','rb')
    if not file then return nil,'native status unavailable' end
    local text=file:read(256);local extra=file:read(1);file:close()
    if extra then return nil,'native status exceeds limit' end
    local ready,active,token,incoming,hits,total,source,code,buttstockHits=text:match('^ZFPVN7 ([01]) ([01]) (%d+) (%d+) (%d+) ([%d%.eE%+%-]+) (%d+) (%d+) (%d+)%s*$')
    if ready==nil then
        ready,active,token,incoming,hits,total,source,code=text:match('^ZFPVN7 ([01]) ([01]) (%d+) (%d+) (%d+) ([%d%.eE%+%-]+) (%d+) (%d+)%s*$')
    end
    ready,active,token,incoming,hits,total,source,code=tonumber(ready),tonumber(active),tonumber(token),tonumber(incoming),tonumber(hits),tonumber(total),tonumber(source),tonumber(code)
    if ready==nil or not uint(token) or not uint(incoming) or not uint(hits) or not finite(total) or total<0 or incoming<hits or not uint(source,255) or not uint(code,255) then return nil,'native status malformed' end
    if buttstockHits then
        buttstockHits=tonumber(buttstockHits)
        if not uint(buttstockHits) or buttstockHits>hits then return nil,'native buttstock counter malformed' end
    end
    return {ready=ready==1,active=active==1,token=token,incoming=incoming,hits=hits,total=total,source=source,code=code,buttstockHits=buttstockHits}
end
local function visualStatus(root)
    local file=io.open(root..'native-visual-status.txt','rb')
    if not file then return nil,'native visual status unavailable' end
    local text=file:read(256);local extra=file:read(1);file:close()
    if extra then return nil,'native visual status exceeds limit' end
    local ready,active,id,intercepted,code=text:match('^ZFPVV7 ([01]) ([01]) (%d+) (%d+) (%d+)%s*$')
    ready,active,id,intercepted,code=tonumber(ready),tonumber(active),tonumber(id),tonumber(intercepted),tonumber(code)
    if ready==nil or not uint(id) or not uint(intercepted) or not uint(code,255) then return nil,'native visual status malformed' end
    return {ready=ready==1,active=active==1,token=id,intercepted=intercepted,code=code}
end
local function concussionStatus(root)
    local file=io.open(root..'native-concussion-status.txt','rb')
    if not file then return nil,'native concussion status unavailable' end
    local text=file:read(256);local extra=file:read(1);file:close()
    if extra then return nil,'native concussion status exceeds limit' end
    local ready,active,id,blocked,code=text:match('^ZFPVC21 ([01]) ([01]) (%d+) (%d+) (%d+)%s*$')
    ready,active,id,blocked,code=tonumber(ready),tonumber(active),tonumber(id),tonumber(blocked),tonumber(code)
    if ready==nil or not uint(id) or not uint(blocked) or not uint(code,255)then return nil,'native concussion status malformed'end
    return {ready=ready==1,active=active==1,token=id,blocked=blocked,code=code}
end
local function concussionSourceStatus(root)
    local file=io.open(root..'native-concussion-source-status.txt','rb')
    if not file then return nil,'native concussion source status unavailable' end
    local text=file:read(256);local extra=file:read(1);file:close()
    if extra then return nil,'native concussion source status exceeds limit' end
    local ready,active,id,matched,removed,code=(text or ''):match('^ZFPVCS45 ([01]) ([01]) (%d+) (%d+) (%d+) (%d+)%s*$')
    ready,active,id,matched,removed,code=tonumber(ready),tonumber(active),tonumber(id),tonumber(matched),tonumber(removed),tonumber(code)
    if ready==nil or not uint(id)or id==0 or not uint(matched)or not uint(removed)or removed>matched or not uint(code,255)then
        return nil,'native concussion source status malformed'
    end
    return {ready=ready==1,active=active==1,token=id,matched=matched,removed=removed,code=code}
end
function M.new(root,loader)
    assert(type(root)=='string' and #root>0,'native bridge root unavailable')
    loader=loader or (package and package.loadlib)
    local funcs={}
    local client={root=root}
    function client:open()
        if self.opened then return true end
        if type(loader)~='function' then return false,'package.loadlib unavailable' end
        for _,name in ipairs(exported) do
            local fn,err=loader(root..'ZoneFPVNative.dll','zonefpv_combat_'..name)
            if type(fn)~='function' then return false,'native '..name..': '..tostring(err) end
            funcs[name]=fn
        end
        -- Remove a previous process's report before testing this loaded module.
        os.remove(root..'native-combat-status.txt')
        local ok,err=pcall(funcs.init)
        if not ok then return false,tostring(err) end
        local report,why=status(root)
        if not report or not report.ready then return false,why or ('native profile rejected (code '..report.code..')') end
        self.opened=true;return true
    end
    function client:arm(pawn)
        local ok,err=self:open();if not ok then return false,err end
        local got,address=pcall(function()return pawn:GetAddress()end)
        if not got or not uint(address,0x7fffffffffff) or address<0x10000 or address%8~=0 then return false,'native pawn address unavailable' end
        self.token=token()
        local file,why=io.open(root..'native-combat-control.txt','wb')
        if not file then return false,tostring(why) end
        local written=file:write(string.format('ZFPVN7 %d %x\n',self.token,address))
        local closed=file:close()
        if not written or not closed then return false,'native control write failed' end
        local armed,failure=pcall(funcs.arm)
        if not armed then return false,tostring(failure) end
        local report,detail=status(root)
        if not report or not report.ready or not report.active or report.token~=self.token then
            pcall(funcs.disarm);return false,detail or ('native arm rejected (code '..report.code..')')
        end
        self.active=true;self.last=report;self.elapsed=0;return true,report
    end
    function client:update(dt,force)
        if not self.active then return nil end
        local ok,err=pcall(funcs.tick)
        if not ok then self:disarm();return nil,tostring(err) end
        self.elapsed=self.elapsed+(finite(dt) and math.max(0,dt) or 0)
        if not force and self.elapsed<0.1 then return nil end
        self.elapsed=0
        ok,err=pcall(funcs.poll)
        if not ok then return nil,tostring(err) end
        local report,why=status(root)
        if not report then return nil,why end
        if report.token~=self.token then return nil,'native session identity changed' end
        if not report.active or report.code~=0 then self:disarm();return nil,'native receiver changed (code '..report.code..')' end
        if report.incoming<self.last.incoming or report.hits<self.last.hits or report.total<self.last.total then return nil,'native counters moved backwards' end
        local delta={incoming=report.incoming-self.last.incoming,hits=report.hits-self.last.hits,
            amount=report.total-self.last.total,source=report.source}
        if report.buttstockHits~=nil then
            if self.last.buttstockHits==nil or report.buttstockHits<self.last.buttstockHits then return nil,'native buttstock counter changed' end
            delta.buttstockHits=report.buttstockHits-self.last.buttstockHits
            if delta.buttstockHits>delta.hits then return nil,'native buttstock delta malformed' end
        elseif self.last.buttstockHits~=nil then return nil,'native buttstock counter disappeared' end
        self.last=report;return delta
    end
    function client:disarm()
        if not funcs.disarm then return true end
        self.active=false
        local ok,err=pcall(funcs.disarm)
        return ok,err
    end
    function client:visualArm(targets)
        local ok,err=self:open();if not ok then return false,err end
        if not self.visualFuncs then
            self.visualFuncs={}
            for _,name in ipairs({'arm','tick','poll','disarm'}) do
                local fn,why=loader(root..'ZoneFPVNative.dll','zonefpv_visual_'..name)
                if type(fn)~='function' then return false,'native visual '..name..': '..tostring(why) end
                self.visualFuncs[name]=fn
            end
        end
        if type(targets)~='table' or #targets==0 or #targets>32 then return false,'native visual targets must contain 1 to 32 entries' end
        local rows,objects={},{}
        self.visualToken=token()
        for _,target in ipairs(targets) do
            local mid=target.mid
            local good,address,index=pcall(function()
                assert(mid and mid:IsValid(),'native visual MID unavailable')
                local comparison=target.index
                if comparison==nil then comparison=FName(target.name):GetComparisonIndex() end
                return mid:GetAddress(),comparison
            end)
            local number=target.number or 0
            if not good or not uint(address,0x7fffffffffff) or address<0x10000 or address%8~=0 or
                not uint(index,0xffffffff) or index==0 or not uint(number,0xffffffff) then return false,'native visual target identity unavailable' end
            rows[#rows+1]=string.format('%x %d %d\n',address,index,number)
            objects[#objects+1]={mid=mid,address=address}
        end
        local file,why=io.open(root..'native-visual-control.txt','wb')
        if not file then return false,tostring(why) end
        local written=file:write(string.format('ZFPVV7 %d %d\n',self.visualToken,#rows)..table.concat(rows))
        local closed=file:close()
        if not written or not closed then return false,'native visual control write failed' end
        ok,err=pcall(self.visualFuncs.arm)
        if not ok then return false,tostring(err) end
        local report,detail=visualStatus(root)
        if not report or not report.ready or not report.active or report.token~=self.visualToken or report.code~=0 then
            self:visualDisarm();return false,detail or ('native visual arm rejected (code '..report.code..')')
        end
        self.visualActive=true;self.visualTargets=objects;self.visualElapsed=0;self.visualLast=report
        return true,report
    end
    function client:visualTick(dt,force)
        if not self.visualActive then return nil end
        for _,target in ipairs(self.visualTargets) do
            local ok,same=pcall(function()return target.mid:IsValid() and target.mid:GetAddress()==target.address end)
            if not ok or not same then self:visualDisarm();return nil,'native visual MID changed' end
        end
        local ok,err=pcall(self.visualFuncs.tick)
        if not ok then self:visualDisarm();return nil,tostring(err) end
        self.visualElapsed=self.visualElapsed+(finite(dt) and math.max(0,dt) or 0)
        if not force and self.visualElapsed<0.1 then return nil end
        self.visualElapsed=0
        ok,err=pcall(self.visualFuncs.poll)
        if not ok then return nil,tostring(err) end
        local report,why=visualStatus(root)
        if not report then return nil,why end
        if report.token~=self.visualToken then return nil,'native visual session identity changed' end
        if not report.active or report.code~=0 then self:visualDisarm();return nil,'native visual identity changed (code '..report.code..')' end
        if report.intercepted<self.visualLast.intercepted then return nil,'native visual counter moved backwards' end
        local delta=report.intercepted-self.visualLast.intercepted
        self.visualLast=report;return delta,report
    end
    function client:visualDisarm()
        self.visualActive=false;self.visualTargets=nil
        if not self.visualFuncs or not self.visualFuncs.disarm then return true end
        return pcall(self.visualFuncs.disarm)
    end
    function client:concussionArm(world,collection,comparison,number,secondaryComparison,secondaryNumber)
        local ok,err=self:open();if not ok then return false,err end
        if not self.concussionFuncs then
            self.concussionFuncs={}
            for _,name in ipairs({'arm','tick','poll','disarm'})do
                local fn,why=loader(root..'ZoneFPVNative.dll','zonefpv_concussion_'..name)
                if type(fn)~='function'then self.concussionFuncs=nil;return false,'native concussion '..name..': '..tostring(why)end
                self.concussionFuncs[name]=fn
            end
        end
        number=number or 0
        if not uint(comparison,0xfffffffe) or comparison==0 or not uint(number,0xffffffff)then return false,'native concussion FName invalid'end
        if secondaryComparison~=nil then
            secondaryNumber=secondaryNumber or 0
            if not uint(secondaryComparison,0xfffffffe)or secondaryComparison==0 or secondaryComparison==comparison or number~=0 or secondaryNumber~=0 then
                return false,'native secondary concussion FName invalid'
            end
        elseif secondaryNumber~=nil then return false,'native secondary concussion FName incomplete'end
        local good,worldAddress,collectionAddress=pcall(function()
            assert(world and world:IsValid()and collection and collection:IsValid())
            return world:GetAddress(),collection:GetAddress()
        end)
        for _,address in ipairs({worldAddress or 0,collectionAddress or 0})do
            if not good or not uint(address,0x7fffffffffff)or address<0x10000 or address%8~=0 then return false,'native concussion world/collection unavailable'end
        end
        self.concussionToken=token()
        local file,why=io.open(root..'native-concussion-control.txt','wb')
        if not file then return false,tostring(why)end
        -- The new control marker makes an older DLL reject a dual request;
        -- it must never report success after silently arming only the first key.
        local request=secondaryComparison and string.format('ZFPVC44 %d %x %x %d %d %d %d\n',
            self.concussionToken,worldAddress,collectionAddress,comparison,number,secondaryComparison,secondaryNumber)or
            string.format('ZFPVC21 %d %x %x %d %d\n',self.concussionToken,worldAddress,collectionAddress,comparison,number)
        local written=file:write(request)
        local closed=file:close()
        if not written or not closed then return false,'native concussion control write failed'end
        local armed,failure=pcall(self.concussionFuncs.arm)
        if not armed then pcall(self.concussionFuncs.disarm);return false,tostring(failure)end
        local report,detail=concussionStatus(root)
        if not report or not report.ready or not report.active or report.token~=self.concussionToken or report.code~=0 then
            pcall(self.concussionFuncs.disarm);return false,detail or('native concussion arm rejected (code '..report.code..')')
        end
        self.concussionActive=true;self.concussionElapsed=0;self.concussionLast=report
        self.concussionScope={world=world,collection=collection,worldAddress=worldAddress,collectionAddress=collectionAddress}
        return true,report
    end
    function client:concussionTick(dt,force)
        if not self.concussionActive then return nil end
        local scope=self.concussionScope
        local ok,same=pcall(function()
            return scope.world:IsValid()and scope.collection:IsValid()and
                scope.world:GetAddress()==scope.worldAddress and scope.collection:GetAddress()==scope.collectionAddress
        end)
        if not ok or not same then self:concussionDisarm();return nil,'native concussion world/collection changed'end
        local renewed,err=pcall(self.concussionFuncs.tick)
        if not renewed then self:concussionDisarm();return nil,tostring(err)end
        self.concussionElapsed=self.concussionElapsed+(finite(dt)and math.max(0,dt)or 0)
        if not force and self.concussionElapsed<0.1 then return nil end
        self.concussionElapsed=0
        local polled,failure=pcall(self.concussionFuncs.poll)
        if not polled then return nil,tostring(failure)end
        local report,why=concussionStatus(root)
        if not report then return nil,why end
        if report.token~=self.concussionToken then return nil,'native concussion session identity changed'end
        if not report.active or report.code~=0 then self:concussionDisarm();return nil,'native concussion identity changed (code '..report.code..')'end
        if report.blocked<self.concussionLast.blocked then return nil,'native concussion counter moved backwards'end
        local delta=report.blocked-self.concussionLast.blocked
        self.concussionLast=report;return delta,report
    end
    function client:concussionDisarm()
        self.concussionActive=false;self.concussionScope=nil
        if not self.concussionFuncs or not self.concussionFuncs.disarm then return true end
        return pcall(self.concussionFuncs.disarm)
    end
    function client:concussionSourceArm(pawn,world)
        -- Source cleanup has an independent verified profile and does not need
        -- to initialize a combat hook or a collection gate to become available.
        if type(loader)~='function'then return false,'package.loadlib unavailable'end
        if not self.concussionSourceFuncs then
            local loaded={}
            for _,name in ipairs({'arm','tick','poll','disarm'})do
                local fn,why=loader(root..'ZoneFPVNative.dll','zonefpv_concussion_source_'..name)
                if type(fn)~='function'then return false,'native concussion source '..name..': '..tostring(why)end
                loaded[name]=fn
            end
            self.concussionSourceFuncs=loaded
        end
        local got,pawnAddress,worldAddress=pcall(function()
            assert(pawn and pawn:IsValid()and world and world:IsValid())
            local pawnWorld=pawn:GetWorld()
            assert(pawnWorld and pawnWorld:IsValid()and pawnWorld:GetAddress()==world:GetAddress())
            return pawn:GetAddress(),world:GetAddress()
        end)
        for _,address in ipairs({pawnAddress or 0,worldAddress or 0})do
            if not got or not uint(address,0x7fffffffffff)or address<0x10000 or address%8~=0 then
                return false,'native concussion source pawn/world unavailable'
            end
        end
        self.concussionSourceToken=token()
        local file,why=io.open(root..'native-concussion-source-control.txt','wb')
        if not file then return false,tostring(why)end
        local written=file:write(string.format('ZFPVCS45 %d %x %x\n',self.concussionSourceToken,pawnAddress,worldAddress))
        local closed=file:close()
        if not written or not closed then return false,'native concussion source control write failed'end
        os.remove(root..'native-concussion-source-status.txt')
        local armed,failure=pcall(self.concussionSourceFuncs.arm)
        if not armed then self:concussionSourceDisarm();return false,tostring(failure)end
        local report,detail=concussionSourceStatus(root)
        if not report or not report.ready or not report.active or report.token~=self.concussionSourceToken or report.code~=0 then
            self:concussionSourceDisarm();return false,detail or('native concussion source arm rejected (code '..report.code..')')
        end
        self.concussionSourceActive=true;self.concussionSourceElapsed=0;self.concussionSourceLast=report
        self.concussionSourceScope={pawn=pawn,world=world,pawnAddress=pawnAddress,worldAddress=worldAddress}
        return true,report
    end
    function client:concussionSourceTick(dt,force)
        if not self.concussionSourceActive then return nil end
        local scope=self.concussionSourceScope
        -- A normal frame handles one bounded 128-entry native chunk. The final
        -- deadline drains at most the verified 512-entry registry with four
        -- chunks, validating the captured world/pawn before each callback batch.
        for _=1,force and 4 or 1 do
            local got,unchanged=pcall(function()
                if not scope.pawn:IsValid()or not scope.world:IsValid()then return false end
                local pawnWorld=scope.pawn:GetWorld()
                return pawnWorld and pawnWorld:IsValid()and
                    scope.pawn:GetAddress()==scope.pawnAddress and scope.world:GetAddress()==scope.worldAddress and
                    pawnWorld:GetAddress()==scope.worldAddress
            end)
            if not got or not unchanged then self:concussionSourceDisarm();return nil,'native concussion source pawn/world changed'end
            local cleared,why=pcall(self.concussionSourceFuncs.tick)
            if not cleared then self:concussionSourceDisarm();return nil,tostring(why)end
        end
        self.concussionSourceElapsed=self.concussionSourceElapsed+(finite(dt)and math.max(0,dt)or 0)
        if not force and self.concussionSourceElapsed<.1 then return nil end
        self.concussionSourceElapsed=0
        local polled,failure=pcall(self.concussionSourceFuncs.poll)
        if not polled then self:concussionSourceDisarm();return nil,tostring(failure)end
        local report,detail=concussionSourceStatus(root)
        if not report then self:concussionSourceDisarm();return nil,detail end
        if report.token~=self.concussionSourceToken then self:concussionSourceDisarm();return nil,'native concussion source session identity changed'end
        if not report.ready or not report.active or report.code~=0 then
            self:concussionSourceDisarm();return nil,'native concussion source identity changed (code '..report.code..')'
        end
        local previous=self.concussionSourceLast
        if report.matched<previous.matched or report.removed<previous.removed then
            self:concussionSourceDisarm();return nil,'native concussion source counters moved backwards'
        end
        local delta={matched=report.matched-previous.matched,removed=report.removed-previous.removed}
        self.concussionSourceLast=report;return delta,report
    end
    function client:concussionSourceDisarm()
        self.concussionSourceActive=false;self.concussionSourceScope=nil
        if not self.concussionSourceFuncs or not self.concussionSourceFuncs.disarm then return true end
        return pcall(self.concussionSourceFuncs.disarm)
    end
    function client:metadata(pawn,actors)
        local ok,err=self:open();if not ok then return nil,err end
        if not self.metadataFn then
            local fn,why=loader(root..'ZoneFPVNative.dll','zonefpv_metadata_query')
            if type(fn)~='function' then return nil,'native metadata: '..tostring(why) end
            self.metadataFn=fn
        end
        if type(actors)~='table' or #actors==0 or #actors>16 then return nil,'native metadata batch must contain 1 to 16 actors' end
        local good,pawnAddress=pcall(function()assert(pawn and pawn:IsValid());return pawn:GetAddress()end)
        if not good or not uint(pawnAddress,0x7fffffffffff) or pawnAddress<0x10000 or pawnAddress%8~=0 then return nil,'native metadata player unavailable' end
        local addresses={}
        for _,actor in ipairs(actors) do
            local valid,address=pcall(function()assert(actor and actor:IsValid());return actor:GetAddress()end)
            if not valid or not uint(address,0x7fffffffffff) or address<0x10000 or address%8~=0 then address=0 end
            addresses[#addresses+1]=address
        end
        local id=token()
        local rows={string.format('ZFPVM7 %d %x %d\n',id,pawnAddress,#addresses)}
        for _,address in ipairs(addresses) do rows[#rows+1]=string.format('%x\n',address) end
        local file,why=io.open(root..'native-metadata-control.txt','wb')
        if not file then return nil,tostring(why) end
        local written=file:write(table.concat(rows));local closed=file:close()
        if not written or not closed then return nil,'native metadata control write failed' end
        os.remove(root..'native-metadata-status.txt')
        ok,err=pcall(self.metadataFn)
        if not ok then return nil,tostring(err) end
        file,why=io.open(root..'native-metadata-status.txt','rb')
        if not file then return nil,tostring(why) end
        local text=file:read(4096);local extra=file:read(1);file:close()
        if not text or extra then return nil,'native metadata status exceeds limit' end
        local lines={};for line in (text..'\n'):gmatch('(.-)\n') do if line:find('%S') then lines[#lines+1]=line end end
        local ready,responseId,count,code=(lines[1] or ''):match('^ZFPVM7 ([01]) (%d+) (%d+) (%d+)%s*$')
        ready,responseId,count,code=tonumber(ready),tonumber(responseId),tonumber(count),tonumber(code)
        if ready~=1 or responseId~=id or count~=#addresses or code~=0 or #lines~=count+1 then return nil,'native metadata rejected or stale (code '..tostring(code)..')' end
        local result={}
        for i=1,count do
            local words={};for word in lines[i+1]:gmatch('%S+') do words[#words+1]=word end
            local address=tonumber(words[1] or '',16)
            local relation,nameCount=tonumber(words[2]),tonumber(words[3])
            if address~=addresses[i] or not uint(nameCount,8) or #words~=nameCount+3 or
                not finite(relation) or relation%1~=0 or relation< -1 or relation>4 then return nil,'native metadata row malformed' end
            local names={}
            for n=1,nameCount do
                local comparison=tonumber(words[n+3])
                if not uint(comparison,0xfffffffe) or comparison==0 then return nil,'native metadata faction name malformed' end
                names[#names+1]=comparison
            end
            if address~=0 then result[address]={relation=relation,names=names} end
        end
        -- Both layers recheck identity: native core/UID snapshots around the
        -- read, then Lua's same userdata/address after the synchronous call.
        for i,actor in ipairs(actors) do
            local valid,same=pcall(function()return actor:IsValid() and actor:GetAddress()==addresses[i]end)
            if not valid or not same then result[addresses[i]]=nil end
        end
        return result
    end
    return client
end
return M
