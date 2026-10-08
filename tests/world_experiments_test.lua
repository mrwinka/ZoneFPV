local M=dofile('mod/Scripts/world_experiments.lua')
-- Logical fixtures use the injected clock so host load/GC cannot consume a
-- native time slice between assertions. The separate slow-native fixture
-- below advances its own clock and verifies the real 1.5 ms deadline.
local function logicalAPI(...)
    local api=M.new(...)
    api.clock=function()return 0 end
    return api
end
local scans,commands,logs=0,{},{}
local lists={}
FName=function(name)return name end
FindAllOf=function(name)scans=scans+1;return lists[name]end
local function object(t)
    t=t or {}
    function t:IsValid()return not self.invalid end
    function t:GetAddress()return self end
    return t
end
local function text(s)return {ToString=function()return s end}end
local function class(name,functions,super)
    local c=object()
    function c:GetFName()return text(name)end
    function c:GetFullName()return '/Script/Test.'..name end
    function c:GetSuperStruct()return super end
    function c:ForEachFunction(f)for _,fn in ipairs(functions or {})do f(fn)end end
    return c
end
local function fn(name,fields,flags)
    local f=object()
    function f:GetFName()return text(name)end
    function f:GetFunctionFlags()return flags or 0x400 end
    function f:ForEachProperty(cb)
        for _,field in ipairs(fields or {})do
            local prop=object()
            function prop:GetFName()return text(field[1])end
            function prop:GetClass()return class(field[2])end
            cb(prop)
        end
    end
    return f
end
local library=object()
function library:ExecuteConsoleCommand(pc,command,again)
    assert(pc==again);commands[#commands+1]=command
end
local api=logicalAPI(library,function(line)logs[#logs+1]=line end)
api.pickup={start=function()return false,'Native pickup unavailable in this test.','pickup_unavailable'end,
    update=function()return nil end}
local world=object()
local function actor(p,kind,worldObject,name)
    local a=object({position=p or {X=0,Y=0,Z=0},kind=kind,world=worldObject or world,alive=true,
        class=class(name or 'TestActor'),writes=0})
    function a:GetWorld()return self.world end
    function a:K2_GetActorLocation()return self.position end
    function a:GetAgentType_BP()error('unsafe streamed gameplay core getter forbidden')end
    function a:IsAlive()error('unsafe streamed gameplay core getter forbidden')end
    if kind~=nil and kind<=16 then
        a.Mesh=object{SkinnedAsset=object()}
        function a.Mesh:DoesSocketExist()return kind==0 end
    end
    function a:GetClass()return self.class end
    local function forbidden(self)self.writes=self.writes+1;error('world mutation forbidden')end
    a.SetActorHiddenInGame=forbidden;a.K2_DestroyActor=forbidden;a.K2_SetActorLocation=forbidden
    a.ForceActivateOnce=forbidden;a.SetInteractionActive=forbidden
    return a
end
local function session()
    return {world=world,pawn=actor(),camera=actor(),pc=object(),flight={p={x=0,y=0,z=0}}}
end
StaticFindObject=function()return nil end
local s=session()
local g=api:update(s,{},.01,0)
assert(scans==0 and #g.markers==0 and g.artifactDistance==-1)
local emptyMarkers,emptyBuckets=g.markers,g.buckets
for n=1,100 do api:update(s,{},.01,n*.01)end
assert(scans==0,'disabled experiments must not enumerate the world')
assert(g.markers==emptyMarkers and g.buckets==emptyBuckets,'disabled callbacks must not allocate/reset state tables')
api:finish(s);assert(not s.worldExperiments)

s=session()
local human=actor({X=1000,Y=0,Z=0},0)
local mutant=actor({X=2000,Y=0,Z=0},4)
local dead=actor({X=500,Y=0,Z=0},0);dead.alive=false;dead.DeadBodyComponent=object()
local foreign=actor({X=1000,Y=0,Z=0},0,object())
local invalid=actor({X=1000,Y=0,Z=0},0);invalid.invalid=true
local unknown=actor({X=1000,Y=0,Z=0},17)
local far=actor({X=36000,Y=0,Z=0},0)
lists.Agent={human,mutant,dead,foreign,invalid,unknown,far,s.pawn,s.camera}
g=api:update(s,{characters=true},0,0)
assert(#g.markers==2 and g.markers[1].type==1 and g.markers[2].type==2)
assert(g.markers[1].distance==10 and g.markers[1].position.Z==0 and g.markers[1].extent.Z==90)
local before=scans
for i=1,19 do api:update(s,{characters=true},.1,i*.1)end
assert(scans==before,'actor lists are cached for at least two seconds')
human.invalid=true
g=api:update(s,{characters=true},.1,1.99)
-- Cached view expires on next scheduled reading; do not draw destroyed actors.
g=api:update(s,{characters=true},.1,2.21)
assert(#g.markers==1 and g.markers[1].type==2)
assert(human.writes==0 and mutant.writes==0)

s=session();lists.Agent={}
local electro=actor({X=100,Y=0,Z=0},nil,nil,'BP_ElectroAnomaly_C')
lists.UIDActor_Anomaly={electro}
g=api:update(s,{anomaliesScan=true,anomalyInterference=true,anomalyDamage=true},0,0)
assert(#g.markers==1 and g.markers[1].type==3 and g.anomalyInterference==95 and g.anomalyDamageRate==40)
s.flight.p.x=13
g=api:update(s,{anomaliesScan=true,anomalyInterference=true,anomalyDamage=true},.1,.21)
assert(g.anomalyInterference==0 and g.anomalyDamageRate==0)
s.flight.p.x=9
g=api:update(s,{anomaliesScan=true,anomalyInterference=true},.1,.42)
assert(g.anomalyInterference>0 and g.anomalyInterference<95 and g.anomalyDamageRate==0)
g=api:update(s,{anomaliesScan=true},.1,.63)
assert(g.anomalyInterference==0 and g.anomalyDamageRate==0 and electro.writes==0)

s=session();local artifact=actor({X=250,Y=0,Z=0});local distant=actor({X=10100,Y=0,Z=0})
lists.Artifact={artifact,distant}
g=api:update(s,{detector=true},0,0)
assert(#g.markers==1 and g.markers[1].type==4 and g.nearestArtifact==artifact and g.artifactDistance==2.5 and g.artifactReady)
g=api:update(s,{detector=true,collectRange=2},0,.001)
assert(not g.artifactReady and g.artifactDistance==2.5,'Range edits refresh readiness inside the stationary 33 ms throttle')
local rangeOk,rangeMessage,rangeCode=api:collect(s,{detector=true,collectRange=2})
assert(not rangeOk and rangeCode=='artifact_too_far' and rangeMessage:find('2 m',1,true))
g=api:update(s,{detector=true,collectRange=5},0,.002)
assert(g.artifactReady and g.artifactDistance==2.5,'Readiness uses the same range as pickup')
rangeOk,rangeMessage,rangeCode=api:collect(s,{detector=true,collectRange=5})
assert(not rangeOk and rangeCode=='pickup_unavailable','Configured range reaches the original pickup API')
g=api:update(s,{detector=true},0,.003)
assert(g.artifactReady and g.collectRange==3,'Legacy/default opts retain 3 m')
local ok,message,code=api:collect(s,{detector=true})
assert(not ok and code=='pickup_unavailable' and #commands==0)
local count=#logs
for _=1,10 do api:collect(s,{detector=true})end
assert(#logs<=count+2,'diagnostics must remain bounded')
assert(not api:collect(s,{}))
artifact.position.X=350
assert(not api:collect(s,{detector=true}) and #commands==0,'pickup requires fresh proximity')
rangeOk,rangeMessage,rangeCode=api:collect(s,{detector=true,collectRange=3.5})
assert(not rangeOk and rangeCode=='pickup_unavailable','Pickup accepts the exact configured range boundary')
rangeOk,rangeMessage,rangeCode=api:collect(s,{detector=true,collectRange=math.huge})
assert(not rangeOk and rangeCode=='artifact_too_far','Invalid range never widens the collection gate')

-- No runtime reflection on AArtifact. CppMediator UID helpers take AObj,
-- which is not this actor's base class. Even coincidentally named native
-- methods must not be guessed or enumerated.
s=session();artifact=actor({X=200,Y=0,Z=0})
artifact.class=class('Artifact',{fn('GetUID',{{'ReturnValue','IntProperty'}})})
function artifact.class:ForEachFunction()error('native function iteration forbidden')end
function artifact:GetClass()error('dynamic class traversal forbidden')end
function artifact:GetUID()error('unverified actor UID getter forbidden')end
StaticFindObject=function()error('unknown collection API probing forbidden')end
lists.Artifact={artifact};api:update(s,{detector=true},0,0)
assert(not api:collect(s,{detector=true}) and #commands==0)
assert(artifact.writes==0)

-- The drone uses the original artifact native callback. It reports pending
-- separately and removes detector geometry only after inventory confirmation.
local nativeStart,nativePoll=0,0
local collecting=logicalAPI(library,function()end)
collecting.pickup={start=function(self,pawn,target)
    assert(pawn==s.pawn and target==artifact);nativeStart=nativeStart+1;self.pending=true
    return true,'pending','artifact_collecting'
end,update=function(self,dt)
    assert(dt==.1);nativePoll=nativePoll+1
    if nativePoll==1 then return nil end
    self.pending=nil;return true,'collected','artifact_collected'
end}
s=session();artifact=actor({X=200,Y=0,Z=0});lists.Artifact={artifact}
g=collecting:update(s,{detector=true},0,0)
ok,message,code=collecting:collect(s,{detector=true})
assert(ok and code=='artifact_collecting' and g.nearestArtifact==artifact and nativeStart==1)
assert(collecting:collect(s,{detector=true}) and nativeStart==1)
assert(collecting:pollPickup(s,.1)==nil and g.nearestArtifact==artifact)
ok,message,code=collecting:pollPickup(s,.1)
assert(ok and code=='artifact_collected' and not g.nearestArtifact and #g.markers==0 and #g.entries==0)
assert(artifact.writes==0 and #commands==0,'no spawn, destroy, teleport or console item cheat')
ok,message,code=collecting:collect(s,{detector=true});assert(not ok and code=='artifact_missing')
ok,message,code=collecting:collect(s,{});assert(not ok and code=='detector_required')
collecting:finish(s)

-- Native collider bounds are captured once; movement refreshes reuse the
-- verified centre offset without repeating bounds reads each camera frame.
s=session();human=actor({X=1000,Y=0,Z=100},0)
local boundCalls=0
function human:GetActorBounds(onlyColliding,center,extent,children)
    assert(onlyColliding==true and children==false)
    boundCalls=boundCalls+1
    center.X,center.Y,center.Z=1000,0,190
    extent.X,extent.Y,extent.Z=35,35,90
end
lists.Agent={human}
g=api:update(s,{characters=true},0,0)
assert(g.markers[1].position.Z==190 and g.markers[1].extent.X==35)
for n=1,19 do api:update(s,{characters=true},.001,n*.001)end
assert(boundCalls==1,'actor bounds must not be read per camera callback')

-- Large loaded pools are cached in bounded slices, including objects far
-- beyond the initial camera position. Moving quickly never needs another lookup.
api.nativeBudget=1 -- Verify the count cap independently of host CPU timing.
s=session();lists.Agent={}
for n=1,520 do lists.Agent[n]=actor({X=n*100,Y=0,Z=0},0)end
g=api:update(s,{characters=true},0,0)
assert(#g.markers<=16 and #g.buckets.Agent==16)
local scanCount=scans
for n=1,40 do api:update(s,{characters=true},.016,n*.016)end
assert(scans==scanCount and #g.buckets.Agent==520 and #g.markers==128)
s.flight.p.x=510
g=api:update(s,{characters=true},.016,.8)
assert(g.markers[1].distance==0 and g.markers[1].actor==lists.Agent[510])
assert(scans==scanCount,'fast travel uses already loaded actors, not delayed near-camera discovery')
api:finish(s);assert(not s.worldExperiments)

-- Notifications perform no actor reads inside construction and are not
-- duplicated on each flight. Newly streamed anomalies become hazards promptly.
local notifications={}
NotifyOnNewObject=function(path,callback)assert(not notifications[path]);notifications[path]=callback end
local streaming=logicalAPI(library,function()end)
lists.UIDActor_Anomaly={};s=session()
g=streaming:update(s,{anomalyDamage=true,anomalyInterference=true},0,0)
local fresh=actor({X=1000,Y=0,Z=0})
notifications['/Script/Stalker2.UIDActor_Anomaly'](fresh)
streaming:update(s,{anomalyDamage=true,anomalyInterference=true},.016,.016)
assert(#g.entries==1)
s.flight.p.x=20
streaming:hazards(s,{anomalyDamage=true},.1,{X=0,Y=0,Z=0})
assert(math.abs(g.anomalyDamageAmount-.8)<1e-6,'crossing four metres of a twenty-metre segment charges only its inside fraction')
assert(g.anomalyDamageRate==0,'end point is already outside the anomaly')
s.flight.p.x=10
streaming:hazards(s,{anomalyDamage=true,anomalyInterference=true},.1)
assert(g.anomalyDamageAmount==4 and g.anomalyInterference==95)
fresh.invalid=true
streaming:hazards(s,{anomalyDamage=true,anomalyInterference=true},.1)
assert(g.anomalyDamageAmount==0 and g.anomalyInterference==0,'expired geometry never damages the drone')
streaming:finish(s)
notifications['/Script/Stalker2.UIDActor_Anomaly'](actor())
s=session();local nextFlight=logicalAPI(library,function()end)
nextFlight:update(s,{anomalyDamage=true},0,1)
assert(#s.worldExperiments.entries==0)
notifications['/Script/Stalker2.UIDActor_Anomaly'](actor({X=100,Y=0,Z=0}))
nextFlight:update(s,{anomalyDamage=true},.016,1.016)
assert(#s.worldExperiments.entries==1,'existing observers dispatch to a new flight API without duplicate registration')
nextFlight:finish(s);NotifyOnNewObject=nil

-- A fresh hazard bypasses both a loaded NPC backlog and a loaded anomaly
-- backlog. These regressions use the real clock and the count cap, so a mock
-- timer cannot accidentally hide starvation between anomaly classes.
local prompt=logicalAPI(library,function()end);prompt.nativeBudget=1
s=session();lists.Agent={};lists.UIDActor_Anomaly={}
for n=1,520 do lists.Agent[n]=actor({X=100000+n*100,Y=0,Z=0},0)end
for n=1,128 do lists.UIDActor_Anomaly[n]=actor({X=200000+n*100,Y=0,Z=0})end
local options={characters=true,anomaliesScan=true,anomalyDamage=true,anomalyInterference=true}
g=prompt:update(s,options,.016,0)
assert(#g.buckets.Agent==16)
local freshBase=actor({X=1000,Y=0,Z=0})
local freshFire=actor({X=2000,Y=0,Z=0})
for n=1,40 do notifications['/Script/Stalker2.UIDActor_Anomaly'](actor({X=300000+n*100,Y=0,Z=0}))end
notifications['/Script/Stalker2.UIDActor_FireBreathAnomaly'](freshFire)
prompt:update(s,options,.016,.016)
assert(g.byAddress[freshFire],'a full base-anomaly notification slice cannot starve another anomaly class')
-- Drain only the notification burst, retaining hundreds of initial objects.
for n=2,4 do prompt:update(s,options,.016,n*.016)end
notifications['/Script/Stalker2.UIDActor_Anomaly'](freshBase)
s.flight.p.x=10
prompt:update(s,options,.016,.08)
assert(g.byAddress[freshBase] and g.anomalyDamageRate==40,'streamed anomaly is active before this frame hazards')
assert(g.performance.discovered<=16 and g.performance.refreshed<=36,'native actor reads obey count caps')
assert(g.performance.hazardCandidates<8,'hazard checks exclude distant cached pools')
assert(g.markers[1].actor==freshBase and g.markers[1].distance==0,'fast movement rebuilds markers in this frame')
local reused=lists.UIDActor_Anomaly[1]
assert(g.byAddress[reused]);reused.position.X=1000
notifications['/Script/Stalker2.UIDActor_Anomaly'](reused)
prompt:update(s,options,.001,.081)
assert(g.anomalyDamageRate==80,'a notified cached address refreshes its old far-away cell before hazards')
local lookupCount=scans
for n=1,5 do prompt:update(s,options,.016,60+n)end
assert(scans==lookupCount,'registered notifications disable periodic global lookups')
prompt:finish(s)

-- A notified hazard can be observed before its constructor installs a world.
-- Once ready on the next frame, it bypasses a large initial anomaly backlog;
-- an unready retry is attempted once and leaves the rest of the slice useful.
local deferred=logicalAPI(library,function()end);deferred.nativeBudget=1
s=session();lists.UIDActor_Anomaly={}
for n=1,520 do lists.UIDActor_Anomaly[n]=actor({X=200000+n*100,Y=0,Z=0})end
g=deferred:update(s,{anomalyDamage=true,anomaliesScan=true},.016,0)
local constructing=actor({X=0,Y=0,Z=0});constructing.world=nil
notifications['/Script/Stalker2.UIDActor_Anomaly'](constructing)
deferred:update(s,{anomalyDamage=true,anomaliesScan=true},.016,.016)
local q=g.queues.UIDActor_Anomaly
assert(q.criticalRetries[q.criticalHead].tries==1,'constructor retry is attempted once in its first frame')
assert(#g.entries==31 and g.performance.discovered==16,'waiting retry leaves fifteen attempts for the initial backlog')
deferred:update(s,{anomalyDamage=true,anomaliesScan=true},.016,.017)
assert(q.criticalRetries[q.criticalHead].tries==2 and #g.entries==46,'each deferred retry is attempted at most once in a frame')
constructing.world=world
deferred:update(s,{anomalyDamage=true,anomaliesScan=true},.016,.018)
assert(g.byAddress[constructing] and g.anomalyDamageRate==40,'ready constructor hazard bypasses the initial backlog on the next frame')
assert(q.initial and q.cursor<q.limit,'regression still has a large initial anomaly backlog')
local nextFrame=actor({X=0,Y=0,Z=0});nextFrame.world=nil
notifications['/Script/Stalker2.UIDActor_Anomaly'](nextFrame)
deferred:update(s,{anomalyDamage=true,anomaliesScan=true},.001,.019)
assert(not g.byAddress[nextFrame]);nextFrame.world=world
deferred:update(s,{anomalyDamage=true,anomaliesScan=true},.001,.020)
assert(g.byAddress[nextFrame] and g.anomalyDamageRate==80,'notify with world absent becomes an active hazard on the immediately following frame')
assert(type(g.performance.hazardsMs)=='number','main performance timing key remains available')
deferred:finish(s)

-- A late cached neighbour is refreshed immediately after fast travel instead
-- of waiting for the rotating global cursor to visit hundreds of far actors.
local moving=logicalAPI(library,function()end);moving.nativeBudget=1
s=session();lists.Agent={}
for n=1,520 do lists.Agent[n]=actor({X=100000+n*100,Y=0,Z=0},0)end
g=moving:update(s,{characters=true},.016,0)
for n=1,33 do moving:update(s,{characters=true},.016,n*.016)end
local neighbour=lists.Agent[510];local reads=0
function neighbour:K2_GetActorLocation()reads=reads+1;return self.position end
s.flight.p.x=1510;s.flight.p.y=10;neighbour.position.X=151150;neighbour.position.Y=1000
moving:update(s,{characters=true},.016,.56)
assert(reads==1 and g.markers[1].actor==neighbour and g.markers[1].distance==1.5,'nearby moving actor is refreshed before marker selection')
local previousMarker=g.markers[1]
neighbour.position.X=151175
moving:update(s,{characters=true},.016,.561)
assert(previousMarker.actorPosition.X==151175,'existing marker references receive per-frame cached position refresh')
moving:finish(s)

-- The native time deadline stops each slice even when the count cap has room.
local bounded=M.new(library,function()end);local nativeTime=0;local nativeReads=0
bounded.clock=function()return nativeTime end
s=session();lists.Agent={}
for n=1,40 do
    local a=actor({X=n*100,Y=0,Z=0},0)
    function a:K2_GetActorLocation()nativeReads=nativeReads+1;nativeTime=nativeTime+.0004;return self.position end
    lists.Agent[n]=a
end
g=bounded:update(s,{characters=true},.016,0)
assert(g.performance.discovered==2 and nativeReads==2,'slow native calls stop discovery before sixteen reads')
nativeReads=0
bounded:update(s,{characters=true},.016,.016)
assert(g.performance.discovered==2 and g.performance.refreshed<=2 and nativeReads<=4,'discovery and refresh each obey the native time deadline')
bounded:finish(s)

-- A full loaded NPC cache still admits genuine newly streamed hazards.
local full=logicalAPI(library,function()end);full.nativeBudget=1
s=session();lists.Agent={};lists.UIDActor_Anomaly={}
for n=1,2048 do lists.Agent[n]=actor({X=100000+n*100,Y=0,Z=0},0)end
g=full:update(s,{characters=true,anomalyDamage=true},.016,0)
for n=1,134 do full:update(s,{characters=true,anomalyDamage=true},.016,n*.016)end
assert(#g.entries==2048)
local urgent=actor({X=0,Y=0,Z=0})
notifications['/Script/Stalker2.UIDActor_Anomaly'](urgent)
full:update(s,{characters=true,anomalyDamage=true},.016,3)
assert(#g.entries==2048 and g.byAddress[urgent] and g.anomalyDamageRate==40,'far NPC eviction reserves prompt hazard observation at capacity')
s.flight.p.x=20
full:hazards(s,{anomalyDamage=true},.1,{X=-2000,Y=0,Z=0})
assert(math.abs(g.anomalyDamageAmount-.4)<1e-6,'spatial segment query retains swept damage with both endpoints outside')
full:finish(s)
-- Sensor silhouettes use the loaded character cache independently of scan UI.
local sensor=logicalAPI(library,function()end);sensor.nativeBudget=1
s=session();lists.Agent={human,mutant};local before=scans
g=sensor:update(s,{visionTargets=true},.016,0)
assert(#g.entries==2 and #g.markers==0 and scans==before+1)
for i=1,90 do sensor:update(s,{visionTargets=true},.016,i*.016)end
assert(scans==before+1,'sensor mode must share notification cache, not repeat global discovery')
sensor:update(s,{},.016,2);assert(#g.entries==0)
sensor:finish(s)
-- Characters with an empty root mesh still supply genuine modular skeletal components.
local modular=actor({X=100,Y=0,Z=0},0);local body=modular.Mesh;modular.Mesh=nil
function modular:K2_GetComponentsByClass()return {body}end
local modularMutant=actor({X=200,Y=0,Z=0},4);local creatureMesh=modularMutant.Mesh
modularMutant.Mesh=object{GetSkinnedAsset=function()return nil end}
function modularMutant:K2_GetComponentsByClass()return {creatureMesh}end
StaticFindObject=function()return object()end
lists.Agent={modular,modularMutant};s=session()
g=sensor:update(s,{visionTargets=true,characters=true},.016,3)
assert(#g.entries==2 and #g.markers==2 and g.markers[1].type==1 and g.markers[2].type==2,'rootless modular NPC/mutant must enter shared vision cache')
sensor:finish(s)
-- A valid UObject does not guarantee a currently rendered target. Pooling,
-- destruction and world replacement are rechecked even inside the 33 ms
-- stationary selection throttle, and again at the writer's export boundary.
local guarded=logicalAPI(library,function()end);guarded.nativeBudget=1
s=session();local pooled=actor({X=1000,Y=0,Z=0},0);lists.Agent={pooled}
g=guarded:update(s,{characters=true},.016,0)
local published=g.markers[1];assert(M.markerCurrent(s,published))
pooled.bHidden=true
assert(not M.markerCurrent(s,published),'writer rejects a hidden pooled NPC before its next update')
guarded:update(s,{characters=true},.001,.001)
assert(#g.markers==0 and #g.entries==1,'hidden NPC never leaves a one-frame stale box; cache can safely await unpooling')
pooled.bHidden=false
guarded:update(s,{characters=true},.016,.04);assert(#g.markers==1)
published=g.markers[1]
function pooled:IsActorBeingDestroyed()return true end
assert(pooled:IsValid() and not M.markerCurrent(s,published),'pending actor destruction is stronger than UObject validity')
guarded:update(s,{characters=true},.001,.041)
assert(#g.markers==0 and #g.entries==0)
guarded:finish(s)

-- Hidden pool members must not occupy the exported-nearest-target limit and
-- displace a genuine visible NPC farther from their default pooled position.
s=session();lists.Agent={}
for i=1,40 do local a=actor({X=i,Y=0,Z=0},0);a.bHidden=true;lists.Agent[i]=a end
local visibleNPC=actor({X=1000,Y=0,Z=0},0);lists.Agent[41]=visibleNPC
g=guarded:update(s,{characters=true},.016,0)
for i=1,3 do guarded:update(s,{characters=true},.016,i*.016)end
assert(#g.entries==41 and #g.markers==1 and g.markers[1].actor==visibleNPC,
    'hidden pool actors cannot crowd a genuine NPC out of the bounded candidate pool')
guarded:finish(s)

-- Begin/finish-destroy flags are rejected without entering a streamed Obj
-- gameplay core. A nonvisual/hidden anomaly is still a genuine hazard.
s=session();local flagged=actor({X=1000,Y=0,Z=0},0)
function flagged:HasAnyFlags(mask)assert(mask==0x18030);return true end
lists.Agent={flagged}
g=guarded:update(s,{characters=true},.016,0);assert(#g.entries==0 and #g.markers==0)
guarded:finish(s)
s=session();local hiddenHazard=actor({X=100,Y=0,Z=0});hiddenHazard.bHidden=true
lists.UIDActor_Anomaly={hiddenHazard}
g=guarded:update(s,{anomaliesScan=true,anomalyDamage=true},.016,0)
assert(#g.markers==1 and M.markerCurrent(s,g.markers[1]) and g.anomalyDamageRate==40,
    'hidden/nonvisual anomaly volumes must not be confused with pooled hidden NPCs')
guarded:finish(s)

-- Engine actor-location accessors return the origin before root construction.
-- Retain the constructor event, but never cache that default-position scan.
s=session();lists.UIDActor_Anomaly={}
g=guarded:update(s,{anomaliesScan=true,anomalyDamage=true},.016,0)
local rootPending=actor({X=0,Y=0,Z=0});rootPending.RootComponent=object{invalid=true}
notifications['/Script/Stalker2.UIDActor_Anomaly'](rootPending)
guarded:update(s,{anomaliesScan=true,anomalyDamage=true},.016,.016)
assert(#g.entries==0 and #g.markers==0 and g.anomalyDamageRate==0,
    'world installed but root absent does not produce an origin phantom')
rootPending.RootComponent=object();rootPending.position.X=100
guarded:update(s,{anomaliesScan=true,anomalyDamage=true},.001,.017)
assert(g.byAddress[rootPending] and #g.markers==1 and g.anomalyDamageRate==40,
    'a genuine root-ready streamed hazard appears on the next frame without arbitrary debounce')
guarded:finish(s)

-- A failed transform suspends cached geometry instead of publishing/damaging
-- from its last successful position. A later valid transform recovers it.
s=session();local transient=actor({X=100,Y=0,Z=0});lists.UIDActor_Anomaly={transient}
local transformReady=true
function transient:K2_GetActorLocation()if transformReady then return self.position end end
g=guarded:update(s,{anomaliesScan=true,anomalyDamage=true},.016,0)
published=g.markers[1];transformReady=false
guarded:update(s,{anomaliesScan=true,anomalyDamage=true},.001,.001)
assert(#g.markers==0 and #g.entries==1 and g.entries[1].suspended and g.anomalyDamageRate==0
    and not M.markerCurrent(s,published),'invalid native transform cannot keep cached phantom geometry')
transformReady=true
guarded:update(s,{anomaliesScan=true,anomalyDamage=true},.016,.04)
assert(#g.markers==1 and not g.entries[1].suspended and g.anomalyDamageRate==40)
guarded:finish(s)

-- Copy the actor's numeric FName identity; never stringify native names.
-- Address reuse must not inherit a previous NPC type or collider offset.
local numericNameMt={__eq=function(a,b)return a.index==b.index and a.number==b.number end}
local function numericName(index,number)
    return setmetatable({index=index,number=number,ToString=function()error('native name stringify forbidden')end},numericNameMt)
end
s=session();local original=actor({X=1000,Y=0,Z=100},0);original.nameIndex=10;original.nameNumber=1
function original:GetAddress()return 123456 end
function original:GetFName()return numericName(self.nameIndex,self.nameNumber)end
function original:GetActorBounds(colliding,center,extent,children)
    center.X,center.Y,center.Z=1000,0,190;extent.X,extent.Y,extent.Z=35,35,90
end
lists.Agent={original}
g=guarded:update(s,{characters=true},.016,0)
published=g.markers[1];assert(M.markerCurrent(s,published) and published.position.Z==190)
original.nameNumber=2
assert(not M.markerCurrent(s,published),'different FName instance at the same address invalidates the export')
guarded:update(s,{characters=true},.001,.001);assert(#g.entries==0 and #g.markers==0)
guarded:finish(s)

s=session();local noIdentity=actor({X=1000,Y=0,Z=0},0)
function noIdentity:GetFName()return nil end
lists.Agent={noIdentity}
g=guarded:update(s,{characters=true},.016,0)
assert(#g.markers==1 and not M.markerCurrent(s,g.markers[1]),
    'a cached candidate with failed available name accessor is rejected by final live validation')
guarded:finish(s)

s=session();original.nameNumber=1;lists.Agent={original}
g=guarded:update(s,{characters=true},.016,0);published=g.markers[1]
local replacement=actor({X=1100,Y=0,Z=100},4)
function replacement:GetAddress()return 123456 end
function replacement:GetFName()return numericName(10,2)end
function replacement:GetActorBounds(colliding,center,extent,children)
    center.X,center.Y,center.Z=1100,0,125;extent.X,extent.Y,extent.Z=60,60,25
end
notifications['/Script/Stalker2.Agent'](replacement)
guarded:update(s,{characters=true},.001,.001)
assert(#g.entries==1 and #g.markers==1 and g.markers[1].actor==replacement and g.markers[1].type==2
    and g.markers[1].position.Z==125 and g.markers[1].extent.Z==25,
    'construction at a cached address reclassifies and recaptures actual geometry')
assert(not M.markerCurrent(s,published),'an expired cache entry is never usable by a delayed writer')
local oldState=g;published=g.markers[1];s.world=object();lists.Agent={replacement}
g=guarded:update(s,{characters=true},.001,.002)
assert(g~=oldState and #g.entries==0 and #g.markers==0 and not M.markerCurrent(s,published),
    'a changed world cannot retain discovery arrays, cached markers or writer identities')
guarded:finish(s)

-- Cached actors can retain valid AActor/root UObjects while their visual
-- skeletal assets unload. Export readiness follows the actually loaded mesh;
-- modular alternatives are discovered only in the bounded refresh slice.
s=session();local visual=actor({X=1000,Y=0,Z=100},0);visual.Mesh=nil
local visualAsset=object();local assetLoaded=true;local componentQueries=0
local body=object()
function body:GetSkinnedAsset()return assetLoaded and visualAsset or object{invalid=true}end
function body:GetOwner()return self.owner or visual end
function body:DoesSocketExist()return true end
local components={body}
function visual:K2_GetComponentsByClass()
    componentQueries=componentQueries+1;return components
end
local boundsReads=0
function visual:GetActorBounds(colliding,center,extent,children)
    boundsReads=boundsReads+1;center.X,center.Y,center.Z=self.position.X,0,self.position.Z+25
    extent.X,extent.Y,extent.Z=50,50,25
end
lists.Agent={visual}
g=guarded:update(s,{characters=true},.016,0)
published=g.markers[1];assert(published.type==1 and M.markerMesh(visual,published)==body)
local queriesBefore=componentQueries
for i=1,32 do assert(M.markerCurrent(s,published) and M.markerMesh(visual,published)==body)end
assert(componentQueries==queriesBefore,'export checks never enumerate modular outfit components again')
assetLoaded=false
assert(body:IsValid() and not M.markerCurrent(s,published) and M.markerMesh(visual,published)==nil,
    'an unloaded skeletal asset cannot publish default-origin sockets or cached collider geometry')
guarded:update(s,{characters=true},.001,.001)
assert(#g.markers==0 and #g.entries==1 and g.entries[1].suspended)
local alternate=object()
function alternate:GetSkinnedAsset()return visualAsset end
function alternate:GetOwner()return visual end
function alternate:DoesSocketExist()return false end
components={body,alternate};visual.position.X=1300;visual.position.Z=140
guarded:update(s,{characters=true},.016,.04)
assert(#g.markers==1 and g.markers[1].type==2 and M.markerMesh(visual,g.markers[1])==alternate
    and g.markers[1].position.X==1300 and g.markers[1].position.Z==165 and boundsReads==2,
    'loaded alternative mesh reclassifies/rebases real bounds without adding movement twice')
published=g.markers[1]
body.owner=actor();assetLoaded=true;alternate.invalid=true
guarded:update(s,{characters=true},.001,.041)
assert(#g.markers==0 and g.entries[1].suspended and not M.markerCurrent(s,published),
    'a reused skeletal component now owned by another actor is not a target mesh')
guarded:finish(s)
-- Discovery totals alone cannot explain a vanished marker. Live cache state
-- and actual retirement reasons must follow the same production transitions.
local diagnosed=logicalAPI(library,function()end);diagnosed.nativeBudget=1
s=session();local living=actor({X=1000,Y=0,Z=0},0)
local initialCorpse=actor({X=1500,Y=0,Z=0},0);initialCorpse.DeadBodyComponent=object()
lists.Agent={living,initialCorpse}
g=diagnosed:update(s,{characters=true},.016,0)
local diagnostic=g.scannerDiagnostics
assert(diagnostic.observed==2 and diagnostic.cached==1 and diagnostic.deadRejected==1
    and diagnostic.live==1 and diagnostic.readyInRange==1 and diagnostic.selectedNPC==1)
living.bHidden=true
diagnosed:update(s,{characters=true},.016,.05)
assert(diagnostic.live==1 and diagnostic.hidden==1 and diagnostic.selectedNPC==0,
    'hidden pooled NPC remains cached and diagnostic distinguishes it from retirement')
living.bHidden=false;living.Mesh.invalid=true
diagnosed:update(s,{characters=true},.016,.1)
assert(diagnostic.live==1 and diagnostic.hidden==0 and diagnostic.suspended==1 and diagnostic.selectedNPC==0)
living.Mesh.invalid=false
diagnosed:update(s,{characters=true},.016,.15)
assert(diagnostic.suspended==0 and diagnostic.selectedNPC==1,'ready pooled NPC recovers without a construction event')
living.DeadBodyComponent=object()
diagnosed:update(s,{characters=true},.016,.2)
assert(diagnostic.live==0 and diagnostic.retired==1 and diagnostic.retiredDead==1
    and diagnostic.hidden==0 and diagnostic.suspended==0 and diagnostic.selectedNPC==0,
    'a concrete dead-body retirement is counted separately from geometry rejection')
diagnosed:finish(s)
-- Nearby actors behind the camera must not distance-truncate a farther
-- visible target before the writer can test visibility. Selection keeps a
-- bounded candidate pool and leaves its live validation to publication.
local crowded=logicalAPI(library,function()end);crowded.nativeBudget=1
s=session();lists.Agent={}
for i=1,70 do lists.Agent[i]=actor({X=-1000-i*10,Y=0,Z=0},0)end
local forwardNPC=actor({X=20000,Y=0,Z=0},0);lists.Agent[71]=forwardNPC
for i=0,6 do g=crowded:update(s,{characters=true},.016,i*.05)end
assert(#g.entries==71 and #g.markers==71 and g.markers[71].actor==forwardNPC,
    'more than 32 close rear candidates cannot remove the farther forward NPC')
for i=7,12 do
    crowded:update(s,{characters=true},.016,i*.05)
    assert(g.markers[71].actor==forwardNPC and g.scannerDiagnostics.selectedNPC==71)
end
assert(g.scannerDiagnostics.live==71 and g.scannerDiagnostics.readyInRange==71
    and g.scannerDiagnostics.droppedByLimit==0)
crowded:finish(s)

-- Notification support does not imply a second construction event when an
-- existing actor's streamed mesh loads five/ten seconds later. Fast retries
-- become sparse, bounded pending reads, with identity/world retirement first.
local late=logicalAPI(library,function()end)
s=session();lists.Agent={}
local function waitingNPC(id)
    local a=actor({X=1000+id*100,Y=0,Z=0},0)
    a.RootComponent=object();a.instance=1;a.address=100000+id
    function a:GetAddress()return self.address end
    function a:GetFName()return 'PendingNPC_'..id..'_'..self.instance end
    a.Mesh.SkinnedAsset=object{invalid=true}
    lists.Agent[#lists.Agent+1]=a
    return a
end
local ready5,ready10,hiddenLate=waitingNPC(1),waitingNPC(2),waitingNPC(3)
hiddenLate.bHidden=true
local recycled,foreignPending,deadPending,expiredPending,addressPending=
    waitingNPC(4),waitingNPC(5),waitingNPC(6),waitingNPC(7),waitingNPC(8)
local lateScans=scans
for frame=0,140 do
    local now=frame*.1
    if frame==40 then
        assert(g.scannerDiagnostics.deferredNPC==8,'unloaded initial actors outlive thirty fast retries')
        recycled.instance=2;foreignPending.world=object();deadPending.DeadBodyComponent=object()
        expiredPending.invalid=true;addressPending.address=addressPending.address+1
    end
    if frame==50 then ready5.Mesh.SkinnedAsset=object()end
    if frame==60 then
        for _,a in ipairs({recycled,foreignPending,deadPending,expiredPending,addressPending})do a.Mesh.SkinnedAsset=object()end
    end
    if frame==100 then ready10.Mesh.SkinnedAsset=object();hiddenLate.Mesh.SkinnedAsset=object()end
    g=late:update(s,{characters=true},.1,now)
    assert(g.performance.discovered<=16 and g.queued<=8192,'late readiness respects the shared read/queue caps')
    if frame<50 then assert(#g.entries==0,'unloaded actor never becomes a guessed marker')end
    if frame>=70 and frame<100 then assert(#g.entries==1 and #g.markers==1,'five-second asset load remains visible across frames')end
    if frame>=120 then assert(#g.entries==3 and #g.markers==2,'ten-second readiness recovers; genuine hidden NPC stays excluded')end
end
assert(scans==lateScans+1,'long-lived pending discovery never repeats global FindAllOf with notifications')
assert(g.scannerDiagnostics.live==3 and g.scannerDiagnostics.hidden==1 and g.scannerDiagnostics.deferredNPC==0)
assert(not g.byAddress[recycled.address] and not g.byAddress[foreignPending.address]
    and not g.byAddress[deadPending.address] and not g.byAddress[expiredPending.address]
    and not g.byAddress[addressPending.address],'stale/dead/foreign delayed references cannot adopt loaded meshes')
hiddenLate.bHidden=false
for frame=141,146 do late:update(s,{characters=true},.1,frame*.1);assert(#g.markers==3)end
late:update(s,{characters=true},.1,60)
assert(scans==lateScans+1 and #g.markers==3,'same ready actors persist without a fresh event or periodic enumeration')
assert(ready5.writes==0 and ready10.writes==0 and hiddenLate.writes==0,'pending reads do not alter NPC rendering')
late:finish(s)

-- Notify can precede both the world's assignment and a valid root. Snapshot
-- identity immediately, bind world once available, and await the same actor.
local early=logicalAPI(library,function()end)
s=session();lists.Agent={}
g=early:update(s,{characters=true},.1,0)
local earlyScans=scans
local earlyNPC=waitingNPC(50);lists.Agent={}
earlyNPC.world=nil;earlyNPC.RootComponent=object{invalid=true};earlyNPC.Mesh.SkinnedAsset=object()
notifications['/Script/Stalker2.Agent'](earlyNPC)
for frame=1,120 do
    if frame==50 then earlyNPC.world=world end
    if frame==100 then earlyNPC.RootComponent=object()end
    g=early:update(s,{characters=true},.1,frame*.11)
    if frame<100 then assert(#g.entries==0 and g.queued==1,'late world/root constructor is retained without an origin target')end
    if frame==80 then
        local q=g.queues.Agent
        assert(q.deferred[q.deferredHead].pendingWorld==world,'world binding waits for the actual construction assignment')
    end
    if frame>=110 then assert(#g.entries==1 and #g.markers==1,'same early-notified actor recovers when its root becomes ready')end
end
assert(scans==earlyScans and earlyNPC.writes==0)
early:finish(s)

-- Slow pending work still uses the production native deadline, even when a
-- whole delayed group becomes ready at once. An event burst stays bounded.
local pendingBudget=logicalAPI(library,function()end)
s=session();lists.Agent={}
local budgetNPCs={}
for i=1,8 do budgetNPCs[i]=waitingNPC(100+i)end
for frame=0,40 do g=pendingBudget:update(s,{characters=true},.1,frame*.11)end
assert(g.scannerDiagnostics.deferredNPC==8 and g.queued==8)
local pendingTime,pendingReads=0,0
for _,a in ipairs(budgetNPCs)do
    a.Mesh.SkinnedAsset=object()
    function a:K2_GetActorLocation()pendingReads=pendingReads+1;pendingTime=pendingTime+.0004;return self.position end
end
pendingBudget.clock=function()return pendingTime end
pendingBudget:update(s,{characters=true},.1,6)
assert(g.performance.discovered==2 and pendingReads==2,'late mesh adoption stops at the native 0.75 ms discovery deadline')
pendingBudget.clock=function()return 0 end
local burst=waitingNPC(999)
for i=1,9000 do notifications['/Script/Stalker2.Agent'](burst)end
assert(g.queued==8192 and g.queueDrops>0,'pending plus construction events share one bounded queue')
pendingBudget:update(s,{characters=true},.1,6.1)
assert(g.performance.discovered==16 and g.queued<=8192,'a full delayed event burst preserves the frame count cap')
assert(#g.entries==8,'ready deferred actors alternate with a full fresh-event backlog instead of starving')
pendingBudget:update(s,{},.1,6.2)
assert(g.queued==0 and g.scannerDiagnostics.deferredNPC==0,'disabling experiments releases delayed references')
pendingBudget:finish(s)

-- On hosts without construction notifications, a later fallback lookup can
-- introduce another large initial array. That real initial backlog shares
-- the same sixteen attempts with ready deferred references.
local fallbackTargets=dofile('mod/Scripts/world_experiments.lua')
local fallbackAPI=fallbackTargets.new(library,function()end);fallbackAPI.clock=function()return 0 end
s=session();lists.Agent={}
local fallbackPending={}
for i=1,8 do fallbackPending[i]=waitingNPC(200+i)end
for frame=0,40 do g=fallbackAPI:update(s,{characters=true},.1,frame*.11)end
assert(g.scannerDiagnostics.deferredNPC==8)
lists.Agent={}
for i=1,520 do lists.Agent[i]=actor({X=2000+i*100,Y=0,Z=0},0)end
for _,a in ipairs(fallbackPending)do a.Mesh.SkinnedAsset=object();lists.Agent[#lists.Agent+1]=a end
local fallbackScans=scans
fallbackAPI:update(s,{characters=true},.1,30)
assert(scans==fallbackScans+1 and g.queues.Agent.initial and g.queues.Agent.cursor==9)
assert(g.performance.discovered==16 and #g.entries==16 and g.scannerDiagnostics.deferredNPC==0,
    'eight ready deferred actors alternate with eight reads from a large initial fallback array')
fallbackAPI:finish(s)
print('PASS same NPC late mesh readiness at 5/10 seconds, hidden/stale/dead/world guards, bounded pending queue and native deadline without repeated global search')
print('PASS scanner lifecycle/world/name identity, root-ready construction, hidden NPCs and invalid-transform phantom rejection')
print('PASS independent sensor target cache, hidden scanner markers and no repeated character search')
print('PASS bounded native discovery/refresh, priority streamed hazards, safe NPC reads, spatial fast-flight markers and every-frame swept damage')
