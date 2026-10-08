local bridge=dofile('mod/Scripts/native_bridge.lua')
local rawOpen,rawRemove=io.open,os.remove
local files={}
io.open=function(path,mode)
    if mode=='wb' then
        files[path]=''
        return {write=function(self,text)files[path]=files[path]..text;return self end,close=function()return true end}
    end
    if not files[path] then return nil,'absent' end
    local at=1
    return {read=function(_,size)local out=files[path]:sub(at,at+size-1);at=at+#out;return #out>0 and out or nil end,close=function()return true end}
end
os.remove=function(path)files[path]=nil;return true end
local incoming,hits,total,source=0,0,0,0
local buttstockHits
local id,visualId,visualCounter,active,visualActive=0,0,0,false,false
local ticks,polls,visualTicks,visualPolls=0,0,0,0
local override
local metadataOverride
local function combatReport()
    files['test/native-combat-status.txt']=override or (string.format('ZFPVN7 1 %d %d %d %d %.17g %d 0',active and 1 or 0,id,incoming,hits,total,source)..
        (buttstockHits and (' '..buttstockHits) or '')..'\n')
end
local function visualReport()files['test/native-visual-status.txt']=string.format('ZFPVV7 1 %d %d %d 0\n',visualActive and 1 or 0,visualId,visualCounter)end
local exports={
    init=function()combatReport();visualReport()end,
    arm=function()
        id=assert(tonumber(files['test/native-combat-control.txt']:match('ZFPVN7 (%d+)')))
        assert(files['test/native-combat-control.txt']:match(' 100000\n$'));active=true;combatReport()
    end,
    tick=function()ticks=ticks+1 end,
    poll=function()polls=polls+1;combatReport()end,
    disarm=function()active=false;combatReport()end,
}
local visualExports={
    arm=function()
        visualId=assert(tonumber(files['test/native-visual-control.txt']:match('ZFPVV7 (%d+) 1\n')))
        assert(files['test/native-visual-control.txt']:match('200000 123 0\n$'));visualActive=true;visualReport()
    end,
    tick=function()visualTicks=visualTicks+1 end,
    poll=function()visualPolls=visualPolls+1;visualReport()end,
    disarm=function()visualActive=false;visualReport()end,
}
local concussionId,concussionCounter,concussionActive,concussionTicks,concussionPolls=0,0,false,0,0
local concussionOverride
local expectDual=false
local function concussionReport()
    files['test/native-concussion-status.txt']=concussionOverride or string.format('ZFPVC21 1 %d %d %d 0\n',concussionActive and 1 or 0,concussionId,concussionCounter)
end
local concussionExports={
    arm=function()
        local pattern=expectDual and '^ZFPVC44 (%d+) 300000 400000 11 0 22 0\n$'or '^ZFPVC21 (%d+) 300000 400000 11 0\n$'
        concussionId=assert(tonumber(files['test/native-concussion-control.txt']:match(pattern)))
        concussionActive=true;concussionCounter=0;concussionReport()
    end,
    tick=function()concussionTicks=concussionTicks+1 end,
    poll=function()concussionPolls=concussionPolls+1;concussionReport()end,
    disarm=function()concussionActive=false;concussionReport()end,
}
local sourceId,sourceMatched,sourceRemoved,sourceActive,sourceTicks,sourcePolls=0,0,0,false,0,0
local sourceOverride,sourceNoReport,sourceRemaining
local sourceInitialMatched,sourceInitialRemoved=0,0
local function sourceReport()
    if sourceNoReport then return end
    files['test/native-concussion-source-status.txt']=sourceOverride or string.format('ZFPVCS45 1 %d %d %d %d 0\n',
        sourceActive and 1 or 0,sourceId,sourceMatched,sourceRemoved)
end
local sourceExports={
    arm=function()
        sourceId=assert(tonumber(files['test/native-concussion-source-control.txt']:match('^ZFPVCS45 (%d+) 100000 300000\n$')))
        sourceActive=true;sourceMatched=sourceInitialMatched;sourceRemoved=sourceInitialRemoved;sourceReport()
    end,
    tick=function()
        sourceTicks=sourceTicks+1
        if sourceRemaining then
            local chunk=math.min(128,sourceRemaining);sourceRemaining=sourceRemaining-chunk
            sourceMatched=sourceMatched+chunk;sourceRemoved=sourceRemoved+chunk
        end
    end,
    poll=function()sourcePolls=sourcePolls+1;sourceReport()end,
    disarm=function()sourceActive=false;sourceReport()end,
}
local function loader(path,export)
    assert(path=='test/ZoneFPVNative.dll')
    local sourceName=export:match('^zonefpv_concussion_source_(%a+)$')
    if sourceName then return sourceExports[sourceName]end
    local mode,name=export:match('^zonefpv_(%a+)_(%a+)$')
    if mode=='metadata' then
        assert(name=='query')
        return function()
            local id,count=files['test/native-metadata-control.txt']:match('^ZFPVM7 (%d+) 100000 (%d+)\n')
            assert(tonumber(count)==2 and files['test/native-metadata-control.txt']:match('200000\n0\n$'))
            files['test/native-metadata-status.txt']=metadataOverride or ('ZFPVM7 1 '..id..' 2 0\n200000 0 2 151 152\n0 -1 0\n')
        end
    end
    return (mode=='combat'and exports or mode=='concussion'and concussionExports or visualExports)[name]
end
local client=bridge.new('test/',loader)
local pawn={IsValid=function()return true end,GetAddress=function()return 0x100000 end}
assert(client:arm(pawn))
assert(client.active and active)
assert(client:update(.03)==nil and ticks==1 and polls==0)
incoming,hits,total,source=3,2,28.5,5
local delta=assert(client:update(.07))
assert(delta.incoming==3 and delta.hits==2 and delta.amount==28.5 and delta.source==5)
assert(ticks==2 and polls==1)
delta=assert(client:update(.1));assert(delta.hits==0 and delta.amount==0)
override='ZFPVN7 1 1 0 3 2 28.5 5 0\n'
local result,err=client:update(.1);assert(result==nil and err:find('identity'))
override=string.format('ZFPVN7 1 1 %d 1 1 1 2 0\n',client.token)
result,err=client:update(.1);assert(result==nil and err:find('backwards'))
override='ZFPVN7 malformed\n'
result,err=client:update(.1);assert(result==nil and err:find('malformed'))
override=nil;assert(client:disarm() and not active and not client.active)
-- Extended reports retain melee evidence even if the last source is a bullet.
buttstockHits=0;assert(client:arm(pawn))
incoming,hits,total,source,buttstockHits=5,4,71,2,1
delta=assert(client:update(.1));assert(delta.buttstockHits==1 and delta.source==2 and delta.hits==2)
delta=assert(client:update(.1));assert(delta.buttstockHits==0)
override=string.format('ZFPVN7 1 1 %d 5 4 71 2 0 0\n',client.token)
result,err=client:update(.1);assert(result==nil and err:find('changed'))
override=string.format('ZFPVN7 1 1 %d 5 4 71 2 0 5\n',client.token)
result,err=client:update(.1);assert(result==nil and err:find('malformed'))
override=string.format('ZFPVN7 1 1 %d 5 4 71 2 0\n',client.token)
result,err=client:update(.1);assert(result==nil and err:find('disappeared'))
override=nil;assert(client:disarm())
local world={IsValid=function(self)return not self.invalid end,GetAddress=function(self)return self.address or 0x300000 end}
local collection={IsValid=function(self)return not self.invalid end,GetAddress=function()return 0x400000 end}
assert(client:concussionArm(world,collection,11,0)and concussionActive)
assert(client:concussionTick(.04)==nil and concussionTicks==1 and concussionPolls==0)
concussionCounter=7
assert(client:concussionTick(.06)==7 and concussionTicks==2 and concussionPolls==1)
assert(client:concussionTick(.1)==0)
concussionOverride='ZFPVC21 malformed\n'
result,err=client:concussionTick(.1);assert(result==nil and err:find('malformed'))
concussionOverride=string.format('ZFPVC21 1 1 %d 6 0\n',client.concussionToken)
result,err=client:concussionTick(.1);assert(result==nil and err:find('backwards'))
concussionOverride='ZFPVC21 1 1 0 7 0\n'
result,err=client:concussionTick(.1);assert(result==nil and err:find('identity'))
concussionOverride=nil;world.address=0x300008
result,err=client:concussionTick(.001);assert(result==nil and err:find('changed')and not concussionActive)
world.address=nil;assert(client:concussionArm(world,collection,11))
collection.invalid=true
result,err=client:concussionTick(.001);assert(result==nil and err:find('changed')and not concussionActive)
assert(not client:concussionArm(world,collection,11))
collection.invalid=false
assert(not client:concussionArm(world,collection,0))
assert(client:concussionArm(world,collection,11));assert(client:concussionDisarm()and not concussionActive)
expectDual=true
assert(client:concussionArm(world,collection,11,0,22)and concussionActive)
assert(client:concussionTick(.001)==nil)
local oldRequest=files['test/native-concussion-control.txt']
for _,invalid in ipairs({0,-1,11,22.5,0xffffffff})do
 assert(not client:concussionArm(world,collection,11,0,invalid))
 assert(files['test/native-concussion-control.txt']==oldRequest,'invalid secondary FName must not dispatch native control')
end
assert(not client:concussionArm(world,collection,11,0,22,1))
assert(not client:concussionArm(world,collection,11,1,22,0))
assert(not client:concussionArm(world,collection,11,0,nil,0))
assert(client:concussionDisarm()and not concussionActive)
expectDual=false
print('PASS strict dual MPC request uses v44 control marker, distinct bounded names, zero secondary number and original single-request compatibility')
function pawn:GetWorld()return world end
local sourceClient=bridge.new('test/',loader)
assert(sourceClient:concussionSourceArm(pawn,world)and sourceActive and not sourceClient.opened,
    'source cleanup must initialize independently from combat/collection hooks')
assert(sourceClient:concussionSourceTick(.04)==nil and sourceTicks==1 and sourcePolls==0,
    'actual descriptor cleanup must run every frame even when status polling is bounded')
sourceMatched,sourceRemoved=4,3
local sourceDelta,sourceState=sourceClient:concussionSourceTick(.06)
assert(sourceDelta.matched==4 and sourceDelta.removed==3 and sourceState.removed==3 and sourceTicks==2 and sourcePolls==1)
sourceDelta=assert(sourceClient:concussionSourceTick(.001,true));assert(sourceDelta.removed==0 and sourcePolls==2,
    'final deadline tick must force fresh removal counters before disarming')
assert(sourceTicks==6,'final deadline executes four bounded source chunks, ordinary frame only one')
sourceRemaining=300;local ticksBeforeDrain=sourceTicks
sourceDelta=assert(sourceClient:concussionSourceTick(.001,true))
assert(sourceRemaining==0 and sourceDelta.removed==300 and sourceTicks-ticksBeforeDrain==4,
    'late three hundred effects drain completely before final source disarm')
sourceRemaining=nil
local sourceRequest=files['test/native-concussion-source-control.txt']
local beforeSourceTicks=sourceTicks
local invalidSourcePawn={IsValid=function()return false end,GetAddress=function()error('invalid pawn address must not be read')end}
assert(not sourceClient:concussionSourceArm(invalidSourcePawn,world))
assert(files['test/native-concussion-source-control.txt']==sourceRequest and sourceTicks==beforeSourceTicks)
local foreignWorld={IsValid=function()return true end,GetAddress=function()return 0x300008 end}
assert(not sourceClient:concussionSourceArm(pawn,foreignWorld))
assert(files['test/native-concussion-source-control.txt']==sourceRequest,'foreign world may not dispatch native source arm')
assert(sourceClient:concussionSourceDisarm()and not sourceActive)
sourceInitialMatched,sourceInitialRemoved=5,4
local sourceArmed,sourceInitialReport=sourceClient:concussionSourceArm(pawn,world)
assert(sourceArmed and sourceInitialReport.matched==5 and sourceInitialReport.removed==4)
sourceDelta=assert(sourceClient:concussionSourceTick(.1));assert(sourceDelta.removed==0,
    'arm already removes effects and the next delta must not count those callbacks twice')
assert(sourceClient:concussionSourceDisarm())
sourceInitialMatched,sourceInitialRemoved=0,0
local function sourceFailure(report,wanted)
    sourceOverride=nil;assert(sourceClient:concussionSourceArm(pawn,world))
    sourceOverride=type(report)=='function'and report(sourceClient.concussionSourceToken)or report
    local value,failure=sourceClient:concussionSourceTick(.1)
    assert(value==nil and failure:find(wanted)and not sourceActive and not sourceClient.concussionSourceActive,failure)
    sourceOverride=nil
end
sourceFailure('ZFPVCS45 malformed\n','malformed')
sourceFailure('ZFPVCS45 1 1 0 0 0 0\n','malformed')
sourceFailure('ZFPVCS45 1 1 1 0 0 0\n','identity')
sourceFailure(function(t)return string.format('ZFPVCS45 1 1 %d 2 3 0\n',t)end,'malformed')
sourceFailure(function(t)return string.format('ZFPVCS45 0 1 %d 0 0 2\n',t)end,'changed')
sourceFailure(function(t)return string.format('ZFPVCS45 1 0 %d 0 0 8\n',t)end,'changed')
sourceFailure(string.rep('x',257),'exceeds')
assert(sourceClient:concussionSourceArm(pawn,world));sourceMatched,sourceRemoved=2,2
assert(sourceClient:concussionSourceTick(.1).removed==2)
sourceMatched,sourceRemoved=1,1
result,err=sourceClient:concussionSourceTick(.1);assert(result==nil and err:find('backwards')and not sourceActive)
assert(sourceClient:concussionSourceArm(pawn,world));world.address=0x300008
beforeSourceTicks=sourceTicks
result,err=sourceClient:concussionSourceTick(.001);assert(result==nil and err:find('changed')and sourceTicks==beforeSourceTicks)
world.address=nil
assert(sourceClient:concussionSourceArm(pawn,world))
local realPawnWorld=pawn.GetWorld
function pawn:GetWorld()return foreignWorld end
beforeSourceTicks=sourceTicks
result,err=sourceClient:concussionSourceTick(.001);assert(result==nil and err:find('changed')and sourceTicks==beforeSourceTicks)
pawn.GetWorld=realPawnWorld
files['test/native-concussion-source-status.txt']='ZFPVCS45 1 1 1 0 0 0\n'
sourceNoReport=true;result,err=sourceClient:concussionSourceArm(pawn,world)
assert(not result and err:find('unavailable')and not sourceActive,'previous process report cannot acknowledge a fresh source arm')
sourceNoReport=false
local noSource=bridge.new('test/',function(path,export)
    if export=='zonefpv_concussion_source_poll'then return nil,'missing source export'end
    return loader(path,export)
end)
assert(not noSource:concussionSourceArm(pawn,world)and not noSource.concussionSourceFuncs,
    'incomplete export set must never partially initialize cleanup')
print('PASS v45 independent source arm, strict fresh bounded status and positive tokens, actual descriptor deltas, every-frame cleanup, forced final poll, ownership and fail-closed malformed/foreign/expired identity handling')
local mid={IsValid=function(self)return not self.invalid end,GetAddress=function()return 0x200000 end}
assert(client:visualArm({{mid=mid,index=123,number=0}}))
assert(client.visualActive and visualActive and not active)
assert(client:visualTick(.02)==nil and visualTicks==1 and visualPolls==0)
visualCounter=4
assert(client:visualTick(.08)==4 and visualTicks==2 and visualPolls==1)
assert(client:visualTick(.1)==0)
mid.invalid=true;result,err=client:visualTick(.001)
assert(result==nil and err:find('changed') and not visualActive and not client.visualActive)
assert(not client:visualArm({{mid=mid,index=123}}))
mid.invalid=false
local invalid={IsValid=function()return false end,GetAddress=function()error('invalid address must not be read')end}
local metadata=assert(client:metadata(pawn,{mid,invalid}))
assert(metadata[0x200000].relation==0 and #metadata[0x200000].names==2 and metadata[0x200000].names[2]==152 and metadata[0]==nil)
assert(not active and not visualActive,'metadata does not arm combat or visual suppression')
metadataOverride='ZFPVM7 1 0 2 0\n200000 0 2 151 152\n0 -1 0\n'
result,err=client:metadata(pawn,{mid,invalid});assert(result==nil and err:find('stale'))
metadataOverride=nil
local huge={};for i=1,17 do huge[i]=mid end
result,err=client:metadata(pawn,huge);assert(result==nil and err:find('1 to 16'))
io.open,os.remove=rawOpen,rawRemove
print('PASS native bridge: synchronous tokens, actual damage deltas, bounded polling, stale/malformed reports, MID leases and safe batched native metadata')
