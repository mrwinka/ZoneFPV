local M=dofile('mod/Scripts/achievements.lua')
assert(M.parse('ZFPVA42 1 0\n').ready)
assert(not M.parse('ZFPVA42 0 2').ready)
for _,bad in ipairs({'ZFPVA42 1 2','ZFPVA42 0 0','ZFPVA42 1 -1','ZFPVA42 0 256','ZFPVA42 1 0 trailing',string.rep('x',81)})do
    assert(M.parse(bad)==nil,'strict achievement readiness report')
end
assert(M.parseCheck('ZFPVA42C 1 1 1 0').recovered)
assert(not M.parseCheck('ZFPVA42C 1 0 0 0').enabled,'pending base Init is not confirmed enabled')
for _,bad in ipairs({'ZFPVA42C 0 1 0 0','ZFPVA42C 1 0 1 0','ZFPVA42C 1 1 1 9','ZFPVA42C 1 1 0 256','ZFPVA42C 1 1 0 0 trailing',string.rep('x',101)})do
    assert(M.parseCheck(bad)==nil,'strict manager readiness report')
end
local rawOpen,rawRemove=io.open,os.remove
local files,initCalls,checkCalls={},0,0
local rejectRemoval,writeFailure,checkFailure=false,false,false
local nextCheckStatus='ZFPVA42C 1 1 1 0\n'
local logs={}
local function log(text)logs[#logs+1]=text end
io.open=function(path,mode)
    assert(path:match('^fixture/native%-achievements'),'only own runtime files may be accessed')
    if mode=='wb'then
        assert(path=='fixture/native-achievements-manager.txt')
        if writeFailure then return nil,'write locked'end
        return {write=function(_,text)files[path]=text;return true end,close=function()return true end}
    end
    assert(mode=='rb')
    local value=files[path];if not value then return end
    return {read=function(_,length)return value:sub(1,length)end,close=function()end}
end
os.remove=function(path)
    assert(path=='fixture/native-achievements-status.txt'or path=='fixture/native-achievements-check-status.txt')
    if rejectRemoval then return nil,'locked'end
    local existed=files[path]~=nil;files[path]=nil
    return existed and true or nil,'missing'
end
local function loader(result,failure,missingCheck)
    return function(path,symbol)
        assert(path=='fixture/ZoneFPVNative.dll')
        if symbol=='zonefpv_achievements_check'then
            if missingCheck then return nil,'missing check export'end
            return function()
                checkCalls=checkCalls+1
                assert(files['fixture/native-achievements-manager.txt']=='ZFPVA42 0\n','native owns singleton identity validation')
                if checkFailure then error('native check failure')end
                files['fixture/native-achievements-check-status.txt']=nextCheckStatus
            end
        end
        assert(symbol=='zonefpv_achievements_init')
        return function()
            initCalls=initCalls+1
            if failure then error(failure)end
            files['fixture/native-achievements-status.txt']=result
        end
    end
end
files['fixture/native-achievements-status.txt']='ZFPVA42 1 0\n'
assert(not M.start('fixture/',nil,function()return nil,'missing export'end)and initCalls==0)
assert(not M.start('fixture/',nil,loader(nil)),'stale success must be removed before new initialization')
assert(M.start('fixture/',nil,loader('ZFPVA42 1 0\n')))
local before=initCalls
assert(not M.start('fixture/',nil,loader('ZFPVA42 1 0\n',nil,true))and initCalls==before,'do not arm a UI-only DLL')
assert(not M.start('fixture/',nil,loader('ZFPVA42 0 2\n')),'unsupported game version is reported without blocking gameplay')
assert(not M.start('fixture/',nil,loader('bad')))
assert(not M.start('fixture/',nil,loader(nil,'native init failure')))
files['fixture/native-achievements-status.txt']='ZFPVA42 1 0\n';rejectRemoval=true;before=initCalls
assert(not M.start('fixture/',nil,loader('ZFPVA42 1 0\n'))and initCalls==before,'a locked stale status cannot be trusted')
rejectRemoval=false
local ready,client=M.start('fixture/',log,loader('ZFPVA42 1 0\n'));assert(ready)
nextCheckStatus='ZFPVA42C 0 0 0 8\n';client:update(0)
assert(checkCalls==1 and not client.verified,'missing singleton waits for world startup')
client:update(.5);assert(checkCalls==1,'no check every frame')
nextCheckStatus='ZFPVA42C 1 0 0 0\n';client:update(1)
assert(checkCalls==2 and not client.verified,'base Init must finish before confirming progress')
nextCheckStatus='ZFPVA42C 1 1 1 0\n';client:update(2)
assert(checkCalls==3 and client.verified and logs[#logs]:find('restored',1,true))
client:update(3);assert(checkCalls==3,'verified manager check interval is ten seconds')
nextCheckStatus='ZFPVA42C 1 1 0 0\n';client:update(12)
assert(checkCalls==4 and initCalls==before+1,'manager checks never rearm the startup hook')
nextCheckStatus='ZFPVA42C 0 0 0 8\n';client:update(22);assert(not client.verified,'world change restarts pending checks')
files['fixture/native-achievements-check-status.txt']='ZFPVA42C 1 1 1 0\n';rejectRemoval=true;before=checkCalls
client:update(23);assert(checkCalls==before and not client.verified,'locked stale check status is rejected')
rejectRemoval=false;writeFailure=true;client:update(24);assert(checkCalls==before,'failed request must not call native Init')
writeFailure=false;checkFailure=true;client:update(25);assert(checkCalls==before+1 and not client.verified)
checkFailure=false;nextCheckStatus='malformed';client:update(26);assert(not client.verified)
nextCheckStatus='ZFPVA42C 1 0 0 9\n';client:update(27)
assert(not client.verified and logs[#logs]:find('code 9',1,true))
io.open,os.remove=rawOpen,rawRemove
print('PASS achievement startup/fresh status/profile failures, native singleton request, pending/recovered/world-change checks, bounded intervals and no save/account mutation')
