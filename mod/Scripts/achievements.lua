-- Arm the version-checked achievement hook before gameworld callbacks. A live
-- manager initialized before Lua startup is checked only on the game thread.
local M={}
function M.parse(text)
    if type(text)~='string' or #text>80 then return end
    local ready,code=text:match('^ZFPVA42 ([01]) (%d+)%s*$')
    code=tonumber(code)
    if not code or code>255 or (ready=='1')~=(code==0)then return end
    return {ready=ready=='1',code=code}
end
function M.parseCheck(text)
    if type(text)~='string' or #text>100 then return end
    local valid,enabled,recovered,code=text:match('^ZFPVA42C ([01]) ([01]) ([01]) (%d+)%s*$')
    code=tonumber(code)
    if not code or code>255 or (enabled=='1'and valid~='1')or
        (recovered=='1'and (enabled~='1'or code~=0))then return end
    return {valid=valid=='1',enabled=enabled=='1',recovered=recovered=='1',code=code}
end
local function clearStatus(path)
    local removed,detail=os.remove(path)
    if not removed then
        local exists=io.open(path,'rb')
        if exists then exists:close();return false,'cannot clear previous status: '..tostring(detail)end
    end
    return true
end
local function readStatus(path,limit,parse)
    local f=io.open(path,'rb');if not f then return nil,'native status unavailable'end
    local text=f:read(limit+1);f:close()
    local result=parse(text)
    return result,result and nil or 'native status malformed'
end
function M.start(root,log,loader)
    loader=loader or (package and package.loadlib)
    local function failed(reason)
        if log then log('Achievements compatibility unavailable: '..tostring(reason))end
        return false,reason
    end
    if type(loader)~='function'then return failed('package.loadlib unavailable')end
    local loaded,fn,why=pcall(loader,root..'ZoneFPVNative.dll','zonefpv_achievements_init')
    if not loaded or type(fn)~='function'then return failed(why or fn)end
    local checkLoaded,check,checkWhy=pcall(loader,root..'ZoneFPVNative.dll','zonefpv_achievements_check')
    if not checkLoaded or type(check)~='function'then return failed(checkWhy or check)end
    local path=root..'native-achievements-status.txt'
    -- A report from an earlier game process cannot establish a live hook.
    local fresh,detail=clearStatus(path);if not fresh then return failed(detail)end
    local ok,err=pcall(fn);if not ok then return failed(err)end
    local result,statusError=readStatus(path,80,M.parse)
    if not result or not result.ready then return failed(result and ('native profile rejected (code '..result.code..')')or statusError)end
    local client={nextCheck=0,lastError=nil}
    local checkPath=root..'native-achievements-check-status.txt'
    local function report(reason)
        if client.lastError~=reason then
            client.lastError=reason
            if log then log('Achievements manager check: '..tostring(reason))end
        end
    end
    function client:update(now)
        if now<self.nextCheck then return end
        self.nextCheck=now+1
        local freshCheck,clearError=clearStatus(checkPath)
        if not freshCheck then report(clearError);return end
        local file,writeError=io.open(root..'native-achievements-manager.txt','wb')
        if not file then report(writeError);return end
        -- Zero asks native code to resolve the version-verified active singleton.
        -- It validates lifetime and identity without enumerating all UObjects.
        local written=file:write('ZFPVA42 0\n');local closed=file:close()
        if not written or not closed then report('native manager request write failed');return end
        local checked,checkError=pcall(check)
        if not checked then report(checkError);return end
        local status,why=readStatus(checkPath,100,M.parseCheck)
        if not status then report(why);return end
        if status.code==0 and status.valid and status.enabled then
            self.nextCheck=now+10;self.lastError=nil
            if not self.verified or status.recovered then
                if log then log(status.recovered and 'Achievements tracking restored through native manager initialization' or 'Achievements native manager tracking verified')end
            end
            self.verified=true
        elseif status.code==8 then
            self.verified=false -- Missing/old world manager: wait for a live one.
        elseif status.code~=0 then report('native manager rejected (code '..status.code..')')end
    end
    if log then log('Achievements compatibility hook ready; native manager tracking will be checked on the game thread')end
    return true,client
end
return M
