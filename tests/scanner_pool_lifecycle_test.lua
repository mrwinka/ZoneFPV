-- A-Life may reuse a loaded actor without constructing another UObject.
-- argv[1] permits reproducing this against the pre-fix discovery module.
local targets=dofile(arg[1] or 'mod/Scripts/world_experiments.lua')
local address=0x10000
local null={IsValid=function()return false end,GetAddress=function()return 0 end}
setmetatable(null,{__index=function()return null end,__call=function()error('missing reflected function')end})
local function object(fields)
    local o=fields or {};address=address+8;o.address=address;o.invalid=false
    function o:IsValid()return not self.invalid end
    function o:GetAddress()return self.address end
    return setmetatable(o,{__index=function()return null end})
end
FName=function(value)return value end
local world=object()
local function actor(index)
    local a=object{world=world,RootComponent=object(),bHidden=false,instance=1,
        position={X=1000+index*10,Y=index*5,Z=0}}
    function a:GetWorld()return self.world end
    function a:GetFName()return 'PooledNPC_'..index..'_'..self.instance end
    function a:K2_GetActorLocation()return self.position end
    function a:GetActorBounds(_,center,extent)
        center.X,center.Y,center.Z=self.position.X,self.position.Y,90
        extent.X,extent.Y,extent.Z=35,40,90
    end
    local mesh=object{SkinnedAsset=object()}
    function mesh:GetOwner()return a end
    function mesh:DoesSocketExist()return true end
    a.Mesh=mesh
    for _,method in ipairs({'SetActorHiddenInGame','SetActorEnableCollision','K2_SetActorLocation','K2_DestroyActor'})do
        a[method]=function()error('scanner must never mutate an NPC')end
    end
    return a
end
StaticFindObject=function()return null end
local notifications,lists,lookups={}, {},{}
NotifyOnNewObject=function(path,callback)
    assert(not notifications[path],'construction observers are registered once')
    notifications[path]=callback
end
FindAllOf=function(class)
    lookups[class]=(lookups[class] or 0)+1
    return lists[class]
end
local function session()
    return {world=world,pawn=object(),camera=object(),flight={p={x=0,y=0,z=0}}}
end
local function api()
    local a=targets.new(object(),function()end)
    a.clock=function()return 0 end
    return a
end
local function checkedUpdate(a,s,options,now)
    local g=a:update(s,options,1/60,now)
    assert((g.performance.discovered or 0)<=16 and g.queued<=8192,'discovery retains the shared read/queue caps')
    local unique={}
    for _,e in ipairs(g.entries)do
        assert(not unique[e.key],'reconciliation cannot duplicate an admitted actor')
        unique[e.key]=true
    end
    for _,m in ipairs(g.markers)do assert(targets.markerCurrent(s,m),'published candidate has a current genuine identity')end
    return g
end

local pooled={}
for i=1,6 do pooled[i]=actor(i);pooled[i].DeadBodyComponent=object()end
local corpse=actor(7);corpse.DeadBodyComponent=object()
local foreign=actor(8);foreign.world=object()
lists.Agent={table.unpack(pooled)}
lists.Agent[#lists.Agent+1]=corpse;lists.Agent[#lists.Agent+1]=foreign
local a,s=api(),session()
local g=checkedUpdate(a,s,{characters=true},0)
assert(#g.entries==0 and g.scannerDiagnostics.deadRejected==7,'genuine corpses remain excluded initially')
assert(notifications['/Script/Stalker2.Agent'],'construction support is available throughout this regression')
for _,npc in ipairs(pooled)do npc.DeadBodyComponent=null end
for frame=1,119 do
    g=checkedUpdate(a,s,{characters=true},frame/60)
    assert(#g.markers==0,'reactivation is reconciled sparsely instead of enumerating every frame')
end
for frame=120,235 do
    g=checkedUpdate(a,s,{characters=true},frame/60)
    assert(#g.markers==6 and #g.entries==6,'all six reactivated actors persist without any constructor callback')
end
assert(lookups.Agent==2,'one initial lookup and one two-second reconciliation')
assert(not g.byAddress[corpse.address] and not g.byAddress[foreign.address],'reconciliation preserves corpse/world guards')

-- The same object may be retired as a corpse, then become another live pool
-- instance without a notification. New discovery must snapshot its new name.
local old=g.markers[1]
local revived=old.actor;revived.DeadBodyComponent=object()
g=checkedUpdate(a,s,{characters=true},3.95)
assert(#g.markers==5 and not targets.markerCurrent(s,old),'death retires its old marker immediately')
revived.DeadBodyComponent=null;revived.instance=2
g=checkedUpdate(a,s,{characters=true},4.01)
assert(#g.markers==6 and not targets.markerCurrent(s,old),'fresh pool identity cannot reuse an expired marker')
assert(g.byAddress[revived.address].name==revived:GetFName(),'reactivation snapshots the current actor identity')

-- Stopping character observations does not stop another sensor. Events while
-- disabled are intentionally ignored and need reconciliation on re-enabling.
g=checkedUpdate(a,s,{anomaliesScan=true},4.1)
local missed=actor(9);lists.Agent[#lists.Agent+1]=missed
notifications['/Script/Stalker2.Agent'](missed)
g=checkedUpdate(a,s,{anomaliesScan=true},6.1)
assert(not g.byAddress[missed.address],'disabled character observations ignore constructor events')
g=checkedUpdate(a,s,{characters=true,anomaliesScan=true},6.2)
for frame=1,8 do g=checkedUpdate(a,s,{characters=true,anomaliesScan=true},6.2+frame/60)end
assert(g.byAddress[missed.address] and #g.markers==7,'re-enabling observations recovers missed actors without a repeated callback')
a:finish(s)

-- An incomplete initial list is never overwritten when its scheduled
-- reconciliation becomes due before bounded consumption has completed.
lists.Agent={}
for i=1,600 do lists.Agent[i]=actor(100+i);lists.Agent[i].Mesh.SkinnedAsset=null end
a,s=api(),session();lookups.Agent=0
g=checkedUpdate(a,s,{characters=true},0)
local initial=g.queues.Agent.initial
assert(g.queues.Agent.cursor==17 and g.queued==16)
g=checkedUpdate(a,s,{characters=true},2.1)
assert(lookups.Agent==1 and g.queues.Agent.initial==initial and g.queues.Agent.cursor==33,
    'a due reconciliation must not reset an unfinished six-hundred-actor list')
for frame=1,1080 do
    g=checkedUpdate(a,s,{characters=true},2.1+frame/60)
    assert(g.queued<=600,'repeat lookups must not multiply still-loading retries')
    local pending=0
    for _ in pairs(g.pendingByAddress)do pending=pending+1 end
    assert(pending<=600 and pending<=g.queued,'pending identity index retains only owned queued work')
end
assert(lookups.Agent<=11,'eighteen seconds of updates cannot exceed the two-second lookup cadence')
for _,npc in ipairs(lists.Agent)do npc.Mesh.SkinnedAsset=object()end
for frame=1081,1440 do g=checkedUpdate(a,s,{characters=true},2.1+frame/60)end
assert(#g.entries==600 and g.queued==0 and next(g.pendingByAddress)==nil,
    'ready meshes drain unique pending ownership and enter the cache')
g=checkedUpdate(a,s,{},27)
assert(g.queued==0 and next(g.pendingByAddress)==nil,'disabling observations releases pending ownership')
a:finish(s)
print('PASS pooled NPC revival without notifications, missed-event recovery, bounded reconciliation and pending identity deduplication')
