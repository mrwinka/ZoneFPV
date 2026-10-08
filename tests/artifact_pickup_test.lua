local M=dofile('mod/Scripts/artifact_pickup.lua')
local realIO,realRemove=io,os.remove
local files={};local starts,polls=0,0
local nativeCode,nativeReady=0,1
local nativeStage=0
local token,target,item=0,0,123
io={open=function(path,mode)
    if mode=='rb' then
        local body=files[path];if not body then return nil,'missing' end
        local at=1
        return {read=function(_,n)local v=body:sub(at,at+n-1);at=at+n;if #v==0 then return nil end;return v end,close=function()return true end}
    end
    files[path]=''
    return {write=function(self,s)files[path]=files[path]..s;return self end,close=function()return true end}
end}
os.remove=function(path)files[path]=nil;return true end
local function report()
    files['test/native-artifact-status.txt']=string.format('ZFPVA12 %d %d %x %d %d\n',nativeReady,token,target,item,nativeCode)
    files['test/native-artifact-validation.txt']=string.format('ZFPVAV12 %d %d 17 23 101 202 0\n',token,nativeStage)
end
local function loader(path,name)
    assert(path=='test/ZoneFPVNative.dll')
    if name=='zonefpv_artifact_start' then return function()
        starts=starts+1
        local p,a
        token,p,a=files['test/native-artifact-control.txt']:match('^ZFPVA12 (%d+) ([%da-f]+) ([%da-f]+)\n$')
        assert(tonumber(p,16)==0x20000)
        token,target=tonumber(token),tonumber(a,16);report()
    end end
    assert(name=='zonefpv_artifact_poll')
    return function()polls=polls+1;report()end
end
local function obj(at)return {IsValid=function()return true end,GetAddress=function()return at end}end
local pawn,artifact=obj(0x20000),obj(0x30000)
local client=M.new('test/',loader)
local ok,message,code=client:start(pawn,artifact)
assert(ok and code=='artifact_collecting' and client.pending and starts==1)
assert(client:start(pawn,artifact) and starts==1,'repeat request must not duplicate native interaction')
assert(client:update(.05)==nil and polls==0)
assert(client:update(.05)==nil and polls==1,'pending native transaction is not reported as inventory success')
nativeCode=1
ok,message,code=client:update(.1)
assert(ok and code=='artifact_collected' and not client.pending)
assert(client:update(1)==nil and polls==2,'completed pickup does not keep polling')

nativeCode=8;nativeStage=4
ok,message,code=client:start(pawn,artifact)
assert(not ok and code=='pickup_failed' and not client.pending,'disappearing/stale actor alone never confirms collection')
assert(message:find('player UID mismatch',1,true) and message:find('Player UID 17, expected 23',1,true),'the rejected validation stage must be visible')
nativeCode=0;nativeStage=0
assert(client:start(pawn,artifact))
nativeReady=0;nativeCode=2
files['test/native-artifact-profile.txt']=string.format('ZFPVAP12 %d 26 140000000 1410bf72e\n',token)
ok,message,code=client:update(.1)
assert(not ok and code=='pickup_unavailable' and not client.pending)
assert(message:find('artifact callback',1,true) and message:find('Take All ABI',1,true) and message:find('inventory manager',1,true))
assert(not message:find('native transfer,',1,true),'diagnostic must identify only failed guards')
files['test/native-artifact-profile.txt']=string.format('ZFPVAP12 %d 31 140000000 0\n',token)
ok,message,code=client:start(pawn,artifact)
assert(not ok and code=='pickup_unavailable' and not message:find('Failed guards:',1,true),'stale profile diagnostic must not describe a new transaction')
files['test/native-artifact-profile.txt']=string.format('ZFPVAP12 %d 512 140000000 0\n',token)
ok,message,code=client:result({ready=false,code=2,token=token})
assert(not ok and message:find('player UID operand',1,true),'UID instruction guard must be identified')
nativeReady=1;nativeCode=0
assert(client:start(pawn,artifact))
ok,message,code=client:update(13)
assert(not ok and code=='pickup_failed' and not client.pending,'native pickup is bounded even if it never completes')
local bad=M.new('test/',function()return nil,'missing export' end)
ok,message,code=bad:start(pawn,artifact)
assert(not ok and code=='pickup_unavailable')
ok,message,code=client:start(obj(0),artifact)
assert(not ok and code=='artifact_missing')

local stale=M.new('test/',function(path,name)
    if name=='zonefpv_artifact_start' then return function()token=1;target=0x30000;nativeCode=1;report()end end
    return function()end
end)
ok,message,code=stale:start(pawn,artifact)
assert(not ok and code=='pickup_failed','old successful response must not be accepted')
local malformed=M.new('test/',function(path,name)
    if name=='zonefpv_artifact_start' then return function()files['test/native-artifact-status.txt']='ZFPVA12 1 2 30000 123 1\n'..string.rep('x',260)end end
    return function()end
end)
ok,message,code=malformed:start(pawn,artifact)
assert(not ok and code=='pickup_failed','oversized native response must be rejected')
for _,body in ipairs({'','truncated status','ZFPVA12 1 wrong 30000 123 1\n','ZFPVA8 1 2 30000 123 1\n'})do
    local broken=M.new('test/',function(path,name)
        if name=='zonefpv_artifact_start' then return function()files['test/native-artifact-status.txt']=body end end
        return function()end
    end)
    ok,message,code=broken:start(pawn,artifact)
    assert(not ok and code=='pickup_failed','invalid status must not abort the mod Lua callback')
end
local throwing=M.new('test/',function()error('loader unavailable')end)
ok,message,code=throwing:start(pawn,artifact)
assert(not ok and code=='pickup_unavailable')
files['test/native-artifact-validation.txt']='ZFPVAV12 '..token..' 4 17 23 101 202 0\n'
ok,message,code=client:result({ready=true,code=8,token=token+1})
assert(not ok and not message:find('Validation:',1,true),'a stale validation detail must be ignored')
for _,body in ipairs({'ZFPVAV12 '..token..' 99 17 23 101 202 0\n','ZFPVAV12 '..token..' 4 -1 23 101 202 0\n',string.rep('x',257)})do
    files['test/native-artifact-validation.txt']=body
    ok,message,code=client:result({ready=true,code=8,token=token})
    assert(not ok and not message:find('Validation:',1,true),'stale or malformed validation detail must be ignored')
end
nativeReady=1;nativeCode=12;nativeStage=0
ok,message,code=client:start(pawn,artifact)
assert(not ok and code=='pickup_failed' and message:find('not confirmed in the player inventory',1,true),'empty source without original destination UID must not report collection')
nativeCode=8;nativeStage=17
ok,message,code=client:start(pawn,artifact)
assert(not ok and message:find('player inventory container',1,true),'destination identity failures are explained')
io,os.remove=realIO,realRemove
print('PASS v12 genuine artifact transfer protocol, no old UI callback DLL, original UID confirmation failures, unique transactions, bounded wait and stale/invalid response rejection')
