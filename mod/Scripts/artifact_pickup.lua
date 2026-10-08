-- Invoke native container transfer on the game thread, without opening loot UI.
-- Success requires the exact original item UID in the player's inventory AND
-- an empty original source container. Protocol v12 rejects the old UI callback DLL.
local M={}
local nextToken=0
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function uint(v,max)return finite(v) and v%1==0 and v>=0 and v<=(max or 0x1fffffffffffff)end
local function address(object)
    local ok,value=pcall(function()assert(object:IsValid());return object:GetAddress()end)
    if ok and uint(value,0x7fffffffffff) and value>=0x10000 and value%8==0 then return value end
end
local function status(root)
    local f=io.open(root..'native-artifact-status.txt','rb')
    if not f then return nil,'native artifact status unavailable' end
    local text=f:read(256);local extra=f:read(1);f:close()
    if extra then return nil,'native artifact status exceeds limit' end
    if type(text)~='string' then return nil,'native artifact status empty' end
    local ready,token,actor,item,code=text:match('^ZFPVA12 ([01]) (%d+) ([%da-fA-F]+) (%d+) (%d+)%s*$')
    ready,token,actor,item,code=tonumber(ready),tonumber(token),tonumber(actor or '',16),tonumber(item),tonumber(code)
    if ready==nil or not uint(token) or not uint(actor,0x7fffffffffff) or not uint(item,0xffffffff) or not uint(code,255)then
        return nil,'native artifact status malformed'
    end
    return {ready=ready==1,token=token,actor=actor,item=item,code=code}
end
local function profileFailure(root,token)
    local f=io.open(root..'native-artifact-profile.txt','rb')
    if not f then return '' end
    local text=f:read(256);local extra=f:read(1);f:close()
    if extra or type(text)~='string' then return '' end
    local got,mask,base,pickup=text:match('^ZFPVAP12 (%d+) (%d+) ([%da-fA-F]+) ([%da-fA-F]+)%s*$')
    got,mask=tonumber(got),tonumber(mask)
    if got~=token or not uint(mask,1023) or mask==0 then return '' end
    local guards={}
    for i,name in ipairs({'executable identity','artifact callback','native transfer','Take All ABI','inventory manager',
        'container pool','player inventory chain','inventory UID getter','artifact retirement','player UID operand'})do
        if math.floor(mask/2^(i-1))%2==1 then guards[#guards+1]=name end
    end
    return ' Failed guards: '..table.concat(guards,', ')..' (image '..base..', transfer '..pickup..').'
end
local function validationFailure(root,token)
    local f=io.open(root..'native-artifact-validation.txt','rb')
    if not f then return '' end
    local text=f:read(256);local extra=f:read(1);f:close()
    if extra or type(text)~='string' then return '' end
    local got,stage,actual,expected,source,destination,cleanup=text:match('^ZFPVAV12 (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)%s*$')
    got,stage,actual,expected=tonumber(got),tonumber(stage),tonumber(actual),tonumber(expected)
    source,destination,cleanup=tonumber(source),tonumber(destination),tonumber(cleanup)
    if got~=token or not uint(stage,19) or stage==0 or not uint(actual,0xffffffff) or not uint(expected,0xffffffff)
        or not uint(source,0xffffffff) or not uint(destination,0xffffffff) or not uint(cleanup,3) then return '' end
    local names={'player core','player class','player UID address','player UID mismatch','artifact class','artifact lifetime',
        'interaction component','interaction class','interaction owner','original container','artifact state','removed artifact',
        'player already picking up an item','original item','original container UID','original container pool identity',
        'player inventory container','native inventory manager','inventory item membership'}
    local detail=' Validation: '..names[stage]..'.'
    if stage==4 then detail=detail..' Player UID '..actual..', expected '..expected..'.' end
    return detail
end
function M.new(root,loader)
    assert(type(root)=='string' and #root>0,'artifact bridge root unavailable')
    loader=loader or (package and package.loadlib)
    local client={root=root}
    function client:open()
        if self.funcs then return true end
        if type(loader)~='function' then return false,'package.loadlib unavailable' end
        local funcs={}
        for _,name in ipairs({'start','poll'})do
            local loaded,fn,why=pcall(loader,root..'ZoneFPVNative.dll','zonefpv_artifact_'..name)
            if not loaded then why=fn;fn=nil end
            if type(fn)~='function' then return false,'native artifact '..name..': '..tostring(why) end
            funcs[name]=fn
        end
        self.funcs=funcs;return true
    end
    function client:result(report)
        if not report.ready or report.code==2 then
            self.pending=nil
            return false,'This game executable is not supported by artifact pickup.'..profileFailure(root,report.token),'pickup_unavailable'
        end
        if report.code==1 then self.pending=nil;return true,'Artifact transferred to player inventory.','artifact_collected' end
        if report.code~=0 then
            self.pending=nil
            local detail=report.code==12 and ' The original item was not confirmed in the player inventory.' or ''
            return false,'Native artifact pickup failed (code '..report.code..').'..detail..validationFailure(root,report.token),'pickup_failed'
        end
        return true,'Artifact pickup is in progress.','artifact_collecting'
    end
    function client:start(pawn,artifact)
        if self.pending then return true,'Artifact pickup is in progress.','artifact_collecting' end
        local opened,why=self:open()
        if not opened then return false,why,'pickup_unavailable' end
        local p,a=address(pawn),address(artifact)
        if not p or not a then return false,'Player or artifact identity unavailable.','artifact_missing' end
        nextToken=math.max(nextToken+1,math.floor(os.clock()*1000000),1)
        local request={token=nextToken,actor=a,pawn=p,elapsed=0,pollElapsed=0}
        local f,detail=io.open(root..'native-artifact-control.txt','wb')
        if not f then return false,tostring(detail),'pickup_unavailable' end
        local written=f:write(string.format('ZFPVA12 %d %x %x\n',request.token,p,a));local closed=f:close()
        if not written or not closed then os.remove(root..'native-artifact-control.txt');return false,'Native pickup request write failed.','pickup_unavailable' end
        os.remove(root..'native-artifact-status.txt')
        local called,err=pcall(self.funcs.start)
        if not called then return false,tostring(err),'pickup_failed' end
        local report,error=status(root)
        if not report or report.token~=request.token or report.actor~=a then return false,error or 'Native pickup response is stale.','pickup_failed' end
        self.pending=request
        return self:result(report)
    end
    function client:update(dt,force)
        local pending=self.pending
        if not pending then return nil end
        dt=finite(dt) and math.max(0,dt) or 0
        pending.elapsed=pending.elapsed+dt;pending.pollElapsed=pending.pollElapsed+dt
        if not force and pending.pollElapsed<.1 then return nil end
        pending.pollElapsed=0
        local called,why=pcall(self.funcs.poll)
        if not called then self.pending=nil;return false,tostring(why),'pickup_failed' end
        local report,error=status(root)
        if not report or report.token~=pending.token or report.actor~=pending.actor then
            self.pending=nil;return false,error or 'Native pickup response is stale.','pickup_failed'
        end
        if pending.elapsed>12 and report.code==0 then self.pending=nil;return false,'Artifact pickup did not complete.','pickup_failed' end
        if report.ready and report.code==0 then return nil end
        return self:result(report)
    end
    return client
end
return M
