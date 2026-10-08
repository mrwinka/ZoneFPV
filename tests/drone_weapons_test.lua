local setupCalls=0
local function registeredLuaState()
    local _,main=coroutine.running()
    assert(main,'fixture UE4SS reflection rejects an unregistered coroutine lua_State')
end
local function instrument(v)
    for name,fn in pairs(v)do
        if type(fn)=='function'and name~='IsValid'and name~='advancePhysics'then
            v[name]=function(...)registeredLuaState();setupCalls=setupCalls+1;return fn(...)end
        end
    end
end
local function object(v)v=v or {};function v:IsValid()registeredLuaState();return not self.dead end;return v end
local classes={}
local function class(name,package)
    local c=object({IsAnyClass=function()return true end,
        GetFName=function()return {ToString=function()return name end}end,
        GetFullName=function()return 'Class /Script/'..package..'.'..name end})
    classes['/Script/'..package..'.'..name]=c;return c
end
local explosionClass=class('ExplosionComponent','Stalker2')
local carrierClass=class('StaticMeshActor','Engine')
-- The reference SDK says 30; the current shipping enum adds a value before it.
-- This fixture deliberately uses 31 and proves the module reads the live enum.
classes['/Script/Stalker2.EPrototypeClass']=object({ForEachName=function(_,fn)
    fn({ToString=function()return 'EPrototypeClass::Emission'end},30)
    fn({ToString=function()return 'EPrototypeClass::Explosion'end},31)
end})
local assets={};local lookups=0
local registryCalls,blockingCalls,unsafeDiscoveryCalls=0,0,0
local lazyExplosion,nativeSoftMiss=false,false
local missing=object({dead=true})
function missing:GetClass()
    unsafeDiscoveryCalls=unsafeDiscoveryCalls+1
    error('the real UE4SS GetClass on this null wrapper causes a native access violation')
end
local library=object()
local terrain,traceCalls={},{}
local proxyCollider
local function trace(startPos,endPos,radius,complex,out)
    traceCalls[#traceCalls+1]={start=startPos,finish=endPos,radius=radius,complex=complex}
    if terrain.error then error('collision trace unavailable')end
    local best,bestTime
    for _,plane in ipairs(terrain)do
        if complex or not plane.complexOnly then
            local axis=plane.axis or 'Z';local direction=plane.direction or 1
            local a=(startPos[axis]-plane.value)*direction
            local b=(endPos[axis]-plane.value)*direction
            local t=a<radius and 0 or (b<radius and (a-radius)/(a-b)or nil)
            if t and (not bestTime or t<bestTime)then
                best={bStartPenetrating=a<radius,Time=t,PenetrationDepth=a<radius and radius-a or 0,
                    Location={X=startPos.X+(endPos.X-startPos.X)*t,Y=startPos.Y+(endPos.Y-startPos.Y)*t,Z=startPos.Z+(endPos.Z-startPos.Z)*t},
                    Normal={X=0,Y=0,Z=0}}
                best.Normal[axis]=direction;bestTime=t
            end
        end
    end
    if best then
        for k,v in pairs(best)do out[k]=v end
        -- Model the installed UE4SS local-out bool conversion: both packed
        -- flags read the same nonzero blocking byte, even on later impacts.
        out.bBlockingHit=true;out.bStartPenetrating=true
        return true
    end
    return false
end
function library:SphereTraceSingle(context,a,b,radius,channel,complex,ignore,draw,hit,selfIgnore,color,endColor,time)
    registeredLuaState()
    assert(context:IsValid()and channel==0 and draw==0 and selfIgnore and time==0)
    for _,actor in ipairs(ignore)do assert(actor:IsValid(),'destroyed actors never enter trace ignore lists')end
    if proxyCollider and proxyCollider:IsValid()then
        local ignored=false
        for _,actor in ipairs(ignore)do if actor==proxyCollider then ignored=true;break end end
        assert(ignored,'moving combat proxy must never collide with its own released grenade trace')
    end
    return trace(a,b,radius,complex,hit)
end
function library:SphereTraceSingleByProfile(context,a,b,radius,profile,complex,ignore,draw,hit,selfIgnore,color,endColor,time)
    assert(profile=='PlayerCapsule')
    return self:SphereTraceSingle(context,a,b,radius,0,complex,ignore,draw,hit,selfIgnore,color,endColor,time)
end
classes['/Script/Engine.Default__KismetSystemLibrary']=library
function library:MakeSoftObjectPath(path)return {path=path}end
function library:Conv_SoftObjPathToSoftObjRef(path)return {soft=path}end
function library:LoadAsset_Blocking(ref)
    registeredLuaState()
    local path=ref.soft.path;blockingCalls=blockingCalls+1
    if path=='/Script/Stalker2.ExplosionComponent'and lazyExplosion then
        if nativeSoftMiss then return missing end
        classes[path]=explosionClass;return explosionClass
    end
    if path=='/Game/GameLite/Blueprints/Grenades/BP_grenade.BP_Grenade_C'and lazyExplosion then
        classes['/Script/Stalker2.ExplosionComponent']=explosionClass;return object()
    end
    assert(path:find('/Game/_Stalker_2/weapons/grenades/',1,true),'only exact cooked grenade assets are soft loaded')
    assets[path]=assets[path]or object({path=path});return assets[path]
end
StaticFindObject=function(path)registeredLuaState();lookups=lookups+1;return classes[path]or assets[path]end
LoadAsset=function()
    registeredLuaState()
    -- Current game has no AssetRegistryHelpers:GetAsset, so UE4SS reports a
    -- registry hit that it cannot load and returns an invalid object wrapper.
    registryCalls=registryCalls+1;return missing,true,false
end
FindFirstOf=function()registeredLuaState();return missing end
FName=function(v)registeredLuaState();return v end
local exploded,actors,components={},{},{};local failure
local function carrier(camera)
    local actor=object({camera=camera,collision=true,order={},position={X=0,Y=0,Z=0}})
    function actor:AddComponentByClass(kind,manual,transform,deferred)
        assert(kind==explosionClass and manual and deferred and transform.Rotation.W==1)
        if failure=='component' then error('component unavailable')end
        local component=object({PrototypeSID={},owner=self})
        function component:ExplodeAtCustomLocation(p,instigator)
            assert(self.registered and self.owner.finished~=false,'only registered native explosion components fire')
            if failure=='explode' then error('native explosion rejected')end
            exploded[#exploded+1]={p=p,instigator=instigator,sid=self.PrototypeSID.Value}
        end
        function component:K2_DestroyComponent(owner)assert(self.owner==owner);self.dead=true end
        instrument(component)
        components[#components+1]=component;self.order[#self.order+1]='component';return component
    end
    function actor:FinishAddComponent(component,manual,transform)
        assert(component.owner==self and manual and transform.Rotation.W==1)
        assert(component.PrototypeSID.Value and component.PrototypeSID.PrototypeClass==31 and component.PrototypeSID.Subtype=='None',
            'native prototype must be configured before registration')
        if failure=='register' then error('registration unavailable')end
        component.registered=true;self.order[#self.order+1]='registered'
    end
    function actor:K2_DestroyActor()self.dead=true;self.destroyed=(self.destroyed or 0)+1 end
    function actor:SetActorEnableCollision(value)self.collision=value end
    function actor:SetActorHiddenInGame(value)self.hidden=value end
    function actor:SetLifeSpan(value)self.lifeSpan=value end
    function actor:K2_GetActorLocation()return self.position end
    function actor:K2_SetActorLocation(p,sweep,hit,teleport)
        assert(not sweep and teleport);self.position=p;self.positionWrites=(self.positionWrites or 0)+1;return true
    end
    local body=object()
    function body:SetMobility(value)assert(value==2);self.movable=true end
    function body:SetStaticMesh(value)
        assert(self.movable and value.path);self.asset=value;return failure~='mesh'
    end
    function body:SetCollisionProfileName(value,overlaps)assert(value=='PhysicsActor'and overlaps);self.profile=value end
    function body:SetCollisionObjectType(value)assert(value==5);self.objectType=value end
    function body:SetCollisionEnabled(value)assert(value==3);self.enabled=value end
    function body:GetCollisionEnabled()return actor.collision and (failure=='collision'and 1 or self.enabled)or 0 end
    function body:K2_IsPhysicsCollisionEnabled()return actor.collision and self.enabled==3 end
    function body:SetCollisionResponseToAllChannels(value)assert(value==2);self.blockWorld=true end
    function body:SetCollisionResponseToChannel(channel,response)assert(channel==2 and response==0);self.ignorePawn=true end
    function body:GetCollisionResponseToChannel(channel)assert(channel==0 or channel==1);return self.blockWorld and 2 or 0 end
    function body:SetUseCCD(value,bone)
        assert(value and bone=='None');if failure=='ccd'then error('CCD unavailable')end;self.ccd=value
    end
    function body:GetLocalBounds(minimum,maximum)
        if failure=='bounds'then return end
        minimum.X=-3;minimum.Y=-3;minimum.Z=-5;maximum.X=3;maximum.Y=3;maximum.Z=5
    end
    function body:SetEnableGravity(value)assert(actor.finished);self.gravity=value end
    function body:SetSimulatePhysics(value)
        assert(not value or actor.collision,'physics warmup/release must enable the actor owner before effective collision checks')
        assert(actor.finished and self.profile and self.ignorePawn and self.ccd and self.enabled==3 and self.blockWorld and self.objectType==5,
            'explicit blocking physics and CCD must survive construction before simulation begins')
        self.physics=value
    end
    function body:IsSimulatingPhysics(bone)assert(bone=='None');return self.physics and failure~='physics'end
    function body:SetMassOverrideInKg(bone,mass,override)assert(bone=='None'and override);self.mass=mass end
    function body:SetPhysicsLinearVelocity(v,add,bone)
        assert(not add and bone=='None');self.velocity=v;self.velocityWrites=(self.velocityWrites or 0)+1
    end
    function body:GetPhysicsLinearVelocity(bone)assert(bone=='None');return self.velocity end
    function body:advancePhysics(dt)
        assert(self.physics and self.gravity,'free-fall fixture must use a native simulated gravity body')
        self.velocity={X=self.velocity.X,Y=self.velocity.Y,Z=self.velocity.Z-980*dt}
        actor.position={X=actor.position.X+self.velocity.X*dt,Y=actor.position.Y+self.velocity.Y*dt,Z=actor.position.Z+self.velocity.Z*dt}
    end
    instrument(body);instrument(actor)
    actor.StaticMeshComponent=body;return actor
end
local gameplay=object()
function gameplay:GetTimeSeconds(world)registeredLuaState();return world.time end
function gameplay:BeginDeferredActorSpawnFromClass(context,kind,transform,collision,owner,scale)
    registeredLuaState()
    setupCalls=setupCalls+1
    assert(kind==carrierClass and (collision==1 or collision==3)and owner==context and scale==0)
    if failure=='spawn' then return nil end
    local actor=carrier();actor.owner=owner;actor.finished=false;actor.position=transform.Translation;actor.spawnCollision=collision;actors[#actors+1]=actor;return actor
end
function gameplay:FinishSpawningActor(actor,transform,scale)
    registeredLuaState()
    setupCalls=setupCalls+1
    assert(scale==0 and actor.order[#actor.order]=='registered')
    if failure=='finish' then error('spawn finish unavailable')end
    if failure=='obstructed' and actor.spawnCollision==3 then actor.dead=true;return end
    actor.position=transform.Translation;actor.finished=true
    -- Construction can recreate a BodyInstance from the static mesh's defaults.
    local body=actor.StaticMeshComponent
    body.profile=nil;body.ccd=false;body.enabled=0;body.blockWorld=false;body.ignorePawn=false;body.objectType=nil
end
do
    -- Model the actual installed-v46 failure rather than allowing engine stubs
    -- to run on a child Lua thread just because this fixture uses plain tables.
    local child=coroutine.create(function()return gameplay:GetTimeSeconds({time=0})end)
    local ok,err=coroutine.resume(child)
    assert(not ok and tostring(err):find('unregistered coroutine lua_State',1,true),
        'native reflection fixture must reproduce UE4SS rejecting coroutine engine calls')
end
local function session(world)
    return {world=world or object({time=0}),pawn=object({CapsuleComponent=object({GetCollisionProfileName=function()return 'PlayerCapsule'end})}),
        camera=carrier(true),flight={p={x=1,y=2,z=3}}}
end
local adapterPath=os.getenv('ZFPV_WEAPONS_ADAPTER')
local M=dofile(adapterPath and adapterPath~=''and adapterPath or 'mod/Scripts/drone_weapons.lua')
local s=session();local n=lookups
assert(M.start(s,{mode=0}).mode==0 and lookups==n,'unarmed flights never touch the engine')
assert(not M.drop(s,gameplay));M.clear(s)
assert(not M.drop(nil,gameplay));assert(not M.detonate(nil,{},gameplay));M.clear(nil)

local world=object({time=10});s=session(world)
local state=M.start(s,{mode=2,grenade=0,charges=2},gameplay);assert(state.remaining==2)
assert(not state.failure,'grenade launch preparation failed: '..tostring(state.failure))
assert(M.drop(s,gameplay,nil,{X=25,Y=50,Z=75}))
local first=actors[#actors]
assert(state.remaining==1 and first.position.X==100 and first.position.Y==200 and first.position.Z==265)
assert(first.StaticMeshComponent.asset.path:find('no_tear',1,true)and first.StaticMeshComponent.mass==.2)
assert(first.StaticMeshComponent.velocity.X==0 and first.StaticMeshComponent.velocity.Y==0 and first.StaticMeshComponent.velocity.Z==-100,
    'released grenade immediately falls below the release point, even if a legacy caller supplies flight velocity')
local ok,code=M.drop(s,gameplay);assert(not ok and code=='grenade_cooldown'and state.remaining==1)
world.time=10.25;assert(M.drop(s,gameplay)and state.remaining==0)
ok,code=M.drop(s,gameplay);assert(not ok and code=='grenades_empty')
M.clear(s);assert(not first.dead,'exiting flight never deletes armed grenades')
for _=1,10 do M.update(999999,gameplay)end
assert(#exploded==0,'wall-clock pause never consumes a game-time fuse')
world.time=12.999;M.update(0,gameplay);assert(#exploded==0)
first.position={X=100,Y=200,Z=2};world.time=13;M.update(0,gameplay)
assert(#exploded==1 and exploded[1].sid=='ExplosionRGD5'and exploded[1].p.Z==2 and first.hidden and not first.collision)
M.update(0,gameplay);assert(#exploded==1,'each fuse invokes native damage exactly once')
world.time=13.25;M.update(0,gameplay);assert(#exploded==2)
world.time=15.25;M.update(0,gameplay);assert(first.dead)

-- A moving/ascent drone must never lend its motion to a dropped grenade.
-- The owner and attack receiver are the same moving pawn, but ownership must
-- not become a transform constraint. Advance the native-physics fixture, move
-- both camera/pawn far away, and let the Lua update observe the independent body.
world=object({time=0});s=session(world);M.start(s,{mode=2,charges=1},gameplay)
proxyCollider=s.pawn
assert(M.drop(s,gameplay,nil,{X=50000,Y=-25000,Z=30000}))
local released=actors[#actors];local body=released.StaticMeshComponent
assert(released.owner==s.pawn and body.velocity.X==0 and body.velocity.Y==0 and body.velocity.Z<0,
    'even fast flight and ascent produce a separate gravity-driven drop')
for index=1,5 do
    s.flight.p={x=100+index,y=200+index,z=300+index}
    s.pawn.position={X=s.flight.p.x*100,Y=s.flight.p.y*100,Z=s.flight.p.z*100}
    s.camera.position=s.pawn.position
    body:advancePhysics(.1);world.time=index*.1
    local nativePosition=released.position
    M.update(0,gameplay,nil,world)
    assert(released.position==nativePosition and released.position.X==100 and released.position.Y==200 and released.position.Z<265,
        'moving/ascending owner cannot pull the independent falling body to the drone')
    assert(body.velocityWrites==1 and released.positionWrites==1,
        'without world contact Lua never resets grenade velocity or synchronizes its transform')
end
M.clear(s);s.camera.dead=true
body:advancePhysics(.1);world.time=.6;M.update(0,gameplay,nil,world)
assert(not released.dead and released.position.X==100 and released.position.Y==200,
    'the free fall continues after the pilot returns and the camera is removed')
proxyCollider=nil;world.time=3;M.update(0,gameplay,nil,world)
assert(exploded[#exploded].p.X==100 and exploded[#exploded].p.Y==200,'native explosion uses the independent drop location')
world.time=5;M.update(0,gameplay,nil,world);assert(released.dead)

for _,kind in ipairs({'spawn','component','register','mesh','finish','physics','collision','ccd','bounds'})do
    s=session(object({time=20}));failure=kind;local before=#actors
    state=M.start(s,{mode=2,grenade=1,charges=1},gameplay)
    assert(state.failure and state.remaining==1,'preparation failure must not consume a charge: '..kind)
    M.clear(s)
    for i=before+1,#actors do assert(actors[i].dead,'partial preparation actor is rolled back: '..kind)end
end
failure=nil;s=session(object({time=20}));M.start(s,{mode=2,grenade=1,charges=1},gameplay)
failure=nil;assert(M.drop(s,gameplay));local f1=actors[#actors]
assert(f1.StaticMeshComponent.mass==.3 and f1.StaticMeshComponent.asset.path:find('SM_f1/',1,true))
s.world.time=23;M.update(0,gameplay);assert(exploded[#exploded].sid=='ExplosionF1')
s.world.time=25;M.update(0,gameplay);M.clear(s)

for index=1,20 do
    s=session();state=M.start(s,{mode=1,power=index/4},gameplay)
    assert(state.prototype==string.format('ZoneFPV_Kamikaze_%02d',index)and state.component.registered)
    local before=#exploded;local hit={X=1,Y=2,Z=3}
    assert(M.detonate(s,hit,gameplay)and state.detonated and #exploded==before+1)
    assert(exploded[#exploded].sid==state.prototype and exploded[#exploded].p~=hit,
        'kamikaze uses scoped real native damage prototype at the collision location')
    ok,code=M.detonate(s,hit,gameplay);assert(not ok and code=='kamikaze_spent'and #exploded==before+1)
    local explosiveOwner=state.record and state.record.actor or actors[#actors]
    M.clear(s);assert(not explosiveOwner.dead and not s.camera.dead,'kamikaze explosion owner survives FPV camera teardown')
    s.world.time=2;M.update(0,gameplay,nil,s.world);assert(explosiveOwner.dead)
end
failure='register';s=session();state=M.start(s,{mode=1,power=1},gameplay);failure=nil
assert(state.failure and not state.component);ok,code=M.detonate(s,{X=1,Y=2,Z=3},gameplay)
assert(not ok and code=='kamikaze_unavailable');M.clear(s)
failure='explode';s=session();M.start(s,{mode=1,power=1},gameplay);ok,code=M.detonate(s,{X=1,Y=2,Z=3},gameplay)
assert(not ok and code=='kamikaze_unavailable');failure=nil
ok,code=M.detonate(s,{X=1,Y=2,Z=3},gameplay);assert(not ok and code=='kamikaze_spent','never replay a partially committed native explosion')
M.clear(s);s.world.time=2;M.update(0,gameplay,nil,s.world)

-- Combined payloads retain independent prepared grenades and a distinct
-- one-shot impact charge; empty inventory never silently disarms that charge.
for grenade=0,1 do
    world=object({time=0});s=session(world)
    local ownedBefore=#actors;local eventsBefore=#exploded
    state=M.start(s,{mode=3,power=2.25,grenade=grenade,charges=2,impactSpeed=65},gameplay)
    assert(not state.failure and state.mode==3 and state.remaining==2 and #state.ready==2 and #actors-ownedBefore==3,
        'combined launch prepares one impact carrier plus two ready grenade carriers')
    local impactOwner,impactComponent=state.record.actor,state.component
    local releasedFirst=state.ready[#state.ready].actor
    assert(M.drop(s,gameplay)and state.remaining==1 and state.component==impactComponent and not state.attempted)
    for _=1,30 do
        local yes,why=M.drop(s,gameplay)
        assert(not yes and why=='grenade_cooldown'and state.remaining==1,
            'repeated input during cooldown neither spends extra charges nor touches the impact payload')
    end
    world.time=.25;local releasedSecond=state.ready[#state.ready].actor
    assert(M.drop(s,gameplay)and state.remaining==0)
    local yes,why=M.drop(s,gameplay);assert(not yes and why=='grenades_empty')
    M.prepare(s,gameplay,nil,true);M.prepare(s,gameplay,nil,true)
    assert(not impactOwner.dead and state.component==impactComponent and #state.ready==0,
        'grenade exhaustion/unused-slot cleanup must preserve the armed impact charge')
    local contact={bBlockingHit=true,bStartPenetrating=true,Time=.5,PenetrationDepth=0}
    assert(not M.shouldDetonate(s,64.999/3.6,contact)and M.shouldDetonate(s,65/3.6,contact))
    world.time=.5;assert(M.detonate(s,{X=400,Y=500,Z=600},gameplay))
    assert(#exploded==eventsBefore+1 and exploded[#exploded].sid=='ZoneFPV_Kamikaze_09',
        'combined impact fires the selected scaled native prototype once')
    yes,why=M.detonate(s,{X=400,Y=500,Z=600},gameplay);assert(not yes and why=='kamikaze_spent')
    yes,why=M.drop(s,gameplay);assert(not yes and why=='kamikaze_spent')
    M.clear(s);s.camera.dead=true;s.pawn.dead=true
    assert(not impactOwner.dead and not releasedFirst.dead and not releasedSecond.dead,
        'FPV teardown retains both live grenade fuses and the native impact effect owner')
    world.time=2.5;M.update(0,gameplay,nil,world)
    assert(impactOwner.dead and not releasedFirst.dead and not releasedSecond.dead and #exploded==eventsBefore+1)
    world.time=3;M.update(0,gameplay,nil,world)
    world.time=3.25;M.update(0,gameplay,nil,world)
    local grenadeSID=grenade==0 and 'ExplosionRGD5'or 'ExplosionF1'
    assert(#exploded==eventsBefore+3 and exploded[eventsBefore+2].sid==grenadeSID and exploded[eventsBefore+3].sid==grenadeSID,
        'each released grenade retains its original native type/fuse after combined impact teardown')
    world.time=5.25;M.update(0,gameplay,nil,world)
    for index=ownedBefore+1,#actors do assert(actors[index].dead and actors[index].destroyed==1,'combined owners clean up exactly once')end
end
for _,kind in ipairs({'component','mesh'})do
    world=object({time=0});s=session(world);local ownedBefore=#actors
    failure=kind;state=M.start(s,{mode=3,charges=2},gameplay);failure=nil
    assert(state.failure and state.remaining==2 and not M.shouldDetonate(s,100,{bStartPenetrating=false}),
        'failure of either combined payload leaves the whole launch unavailable without spending ammo')
    M.clear(s)
    for index=ownedBefore+1,#actors do assert(actors[index].dead,'partial combined initialization rolls back all owned equipment')end
end
do
    world=object({time=0});s=session(world);local ownedBefore=#actors
    state=M.start(s,{mode=3,charges=0},gameplay)
    M.prepare(s,gameplay,nil,true);assert(state.preparing and state.record.actor)
    M.update(0,gameplay,nil,object({time=0}))
    assert(not s.weapons,'world travel cancels combined ready/pending/impact equipment')
    for index=ownedBefore+1,#actors do assert(actors[index].dead,'combined pool/impact owner does not leak across worlds')end
end

world=object({time=100});s=session(world);state=M.start(s,{mode=2,charges=0},gameplay)
assert(state.remaining==math.huge)
for i=1,M.maxActive do
    world.time=100+i*.25;assert(M.drop(s,gameplay))
    for _=1,7 do M.prepare(s,gameplay,nil,true)end
end
world.time=world.time+.25
ok,code=M.drop(s,gameplay);assert(not ok and code=='grenades_busy'and state.remaining==math.huge,
    'unlimited inventory still has bounded live native actors')
M.clear(s);world.dead=true;M.update(0,gameplay)
assert(actors[#actors].dead,'unloaded world cancels only owned grenades')
world=object({time=50});s=session(world);M.start(s,{mode=2,charges=1},gameplay);assert(M.drop(s,gameplay));local stale=actors[#actors]
world.time=0;M.update(0,gameplay);assert(stale.dead,'world time reset never carries an old grenade fuse into a new game')
world=object({time=100,GetAddress=function()return 55 end});s=session(world);M.start(s,{mode=2,charges=1},gameplay);assert(M.drop(s,gameplay));stale=actors[#actors]
local sameWorldWrapper=object({GetAddress=function()return 55 end});M.update(0,gameplay,nil,sameWorldWrapper)
assert(not stale.dead,'equivalent Unreal wrappers identify the same active world')
M.update(0,gameplay,nil,object({time=103}));assert(stale.dead,'a still-valid previous world never detonates a grenade after level travel')
world=object({time=100});s=session(world);M.start(s,{mode=2,charges=1},gameplay);assert(M.drop(s,gameplay));stale=actors[#actors]
M.update(0,gameplay,nil,nil);assert(stale.dead,'explicit loading/no-world state cancels the old armed queue')

-- Thin collision geometry may be complex-only and a low hover can put the
-- original 35 cm release point below the floor. Sweep the complete release path
-- with the mesh's bounding sphere, and shorten the release without spending a
-- charge on a genuinely embedded start.
terrain={{value=0,complexOnly=true}};world=object({time=0});s=session(world)
s.flight.p.z=.12;M.start(s,{mode=2,charges=2},gameplay)
assert(M.drop(s,gameplay));local low=actors[#actors]
local radius=math.sqrt(43)+.5
assert(math.abs(low.position.Z-(radius+1))<1e-8 and low.position.Z>0,
    '35 cm release is clamped above the complex-only floor during a 12 cm hover')
assert(low.StaticMeshComponent.physics and low.StaticMeshComponent.ccd and low.StaticMeshComponent.enabled==3)
world.time=.25;s.flight.p.z=.03
ok,code=M.drop(s,gameplay);assert(not ok and code=='grenade_unavailable'and s.weapons.remaining==1 ,
    'a release starting inside geometry retains its prepared actor and remaining charge')
M.clear(s);world.dead=true;M.update(0,gameplay)

-- Reproduce a fast native body crossing a thin floor between updates, including
-- the exact fuse frame. The segment guard must correct the carrier before its
-- native damage/FX location is sampled, even after the flight camera/pawn exits.
world=object({time=0});s=session(world);M.start(s,{mode=2,charges=1},gameplay)
assert(M.drop(s,gameplay,nil,{X=17,Y=29,Z=-25000}));local falling=actors[#actors]
-- Native impacts/forces can still accelerate an already independent body.
falling.StaticMeshComponent:SetPhysicsLinearVelocity({X=17,Y=29,Z=-25000},false,'None')
M.clear(s);s.camera.dead=true;s.pawn.dead=true
local beforeTraces=#traceCalls
M.update(100000,gameplay,nil,world);assert(#traceCalls==beforeTraces,'paused/stationary grenades do not resweep unchanged positions')
falling.position={X=100,Y=200,Z=-500};world.time=.05;M.update(0,gameplay,nil,world)
assert(math.abs(falling.position.Z-(radius+1))<1e-8 and not falling.dead,
    'high-speed descent crossing thin complex terrain rewinds to the sphere contact above ground')
assert(falling.StaticMeshComponent.velocity.X==17 and falling.StaticMeshComponent.velocity.Y==29 and falling.StaticMeshComponent.velocity.Z>0,
    'terrain correction preserves tangent velocity and removes the inward component')
local beforeExplosions=#exploded
falling.position={X=100,Y=200,Z=-1000};world.time=3;M.update(0,gameplay,nil,world)
assert(#exploded==beforeExplosions+1 and math.abs(exploded[#exploded].p.Z-(radius+1))<1e-8,
    'fuse-frame tunnelling still detonates above terrain, never under the map')
world.time=5;M.update(0,gameplay,nil,world);assert(falling.dead)

-- External lateral impact/force must still sweep the whole movement path rather
-- than only looking for ground beneath the grenade's endpoint.
terrain={{axis='X',value=300,direction=-1,complexOnly=true}}
world=object({time=0});s=session(world);M.start(s,{mode=2,grenade=1,charges=1},gameplay)
assert(M.drop(s,gameplay,nil,{X=50000,Y=31,Z=0}));local fast=actors[#actors]
fast.StaticMeshComponent:SetPhysicsLinearVelocity({X=50000,Y=31,Z=-100},false,'None')
fast.position={X=600,Y=200,Z=265};world.time=.05;M.update(0,gameplay,nil,world)
assert(math.abs(fast.position.X-(300-radius-1))<1e-8 and fast.StaticMeshComponent.velocity.X<0 and fast.StaticMeshComponent.velocity.Y==31,
    'high-speed native lateral velocity cannot tunnel through a complex-only wall')
world.time=3;M.update(0,gameplay,nil,world);world.time=5;M.update(0,gameplay,nil,world);M.clear(s)

terrain={error=true};world=object({time=0});s=session(world);M.start(s,{mode=2,charges=1},gameplay)
ok,code=M.drop(s,gameplay);assert(not ok and code=='grenade_unavailable'and s.weapons.remaining==1 and actors[#actors].dead,
    'failed native clearance query rejects release atomically without spending inventory')
terrain={};M.clear(s)
assert(registryCalls==2 and blockingCalls==2,'both grenade meshes use the shared soft-load fallback and then its cache')

-- Reproduce the real crash precondition: native class search misses and
-- FindFirstOf returns a null UObject wrapper, rather than Lua nil. Reflection
-- must never enter that wrapper, even if a pcall surrounds the lookup.
for _,directMiss in ipairs({false,true})do
    lazyExplosion=true;nativeSoftMiss=directMiss
    classes['/Script/Stalker2.ExplosionComponent']=nil
    local fresh=dofile('mod/Scripts/drone_weapons.lua');s=session()
    local before=blockingCalls;state=fresh.start(s,{mode=1,power=1},gameplay)
    assert(state.component and not state.failure and unsafeDiscoveryCalls==0,'null discovery is never reflected')
    assert(blockingCalls==before+(directMiss and 2 or 1),'lazy native classes use direct soft load or the exact cooked blueprint')
    fresh.clear(s)
end
lazyExplosion=false;nativeSoftMiss=false
-- The normal component of impact velocity is supplied by main before impulse
-- resolution. Slow landing, tangential contact and initial penetration must
-- leave the native payload armed for a later deliberate impact.
for _,threshold in ipairs({5,30,150})do
    s=session();state=M.start(s,{mode=1,impactSpeed=threshold},gameplay)
    local contact={bStartPenetrating=false,Normal={X=0,Y=0,Z=1}}
    assert(state.impactSpeed==threshold)
    assert(not M.shouldDetonate(s,(threshold-.001)/3.6,contact))
    assert(not M.shouldDetonate(s,-100,contact))
    assert(not M.shouldDetonate(s,math.huge,contact))
    assert(not M.shouldDetonate(s,100,{bStartPenetrating=true,Normal={X=0,Y=0,Z=1}}))
    assert(not M.shouldDetonate(s,100,nil)and not M.shouldDetonate(s,100,1)
        and not M.shouldDetonate(s,100,{})and not M.shouldDetonate(s,100,{bStartPenetrating=0}),
        'unreadable or missing native contact flags must never arm an explosion')
    local packed={bBlockingHit=true,bStartPenetrating=true,Time=.5,PenetrationDepth=0}
    assert(not M.shouldDetonate(s,(threshold-.001)/3.6,packed)
        and M.shouldDetonate(s,threshold/3.6,packed),
        'packed out-bool alias on a later sweep impact must preserve the exact speed threshold')
    for _,ambiguous in ipairs({{Time=0,PenetrationDepth=0},{Time=0,PenetrationDepth=2},
        {Time=.5,PenetrationDepth=2},{Time=1.1,PenetrationDepth=0},
        {Time=math.huge,PenetrationDepth=0},{Time=.5},{PenetrationDepth=0}})do
        ambiguous.bStartPenetrating=true
        assert(not M.shouldDetonate(s,100,ambiguous),'initial/ambiguous packed contacts never detonate')
    end
    assert(not state.attempted and not state.detonated,'soft contacts never spend the armed payload')
    assert(M.shouldDetonate(s,threshold/3.6,contact),'the configured threshold includes its exact boundary')
    assert(M.detonate(s,{X=100,Y=200,Z=300},gameplay))
    assert(not M.shouldDetonate(s,100,contact),'a committed payload cannot retrigger on another contact')
    M.clear(s);s.world.time=2;M.update(0,gameplay,nil,s.world)
end
assert(not M.shouldDetonate(nil,100,{}))
s=session();M.start(s,{mode=0});assert(not M.shouldDetonate(s,100,{}));M.clear(s)
do
    -- A full userdata with guarded fields reproduces UE4SS's reflected hit
    -- wrapper type. Our trace uses an out table, but the adapter must also
    -- accept valid direct reflected wrappers without a Lua type restriction.
    local proxy=assert(io.tmpfile());local original=getmetatable(proxy)
    local penetrating=false
    debug.setmetatable(proxy,{__index=function(_,field)
        registeredLuaState()
        if field=='bStartPenetrating'then return penetrating end
        error('unavailable reflected FHitResult field: '..tostring(field))
    end})
    assert(type(proxy)=='userdata')
    s=session();state=M.start(s,{mode=1,impactSpeed=30},gameplay)
    assert(not M.shouldDetonate(s,29.999/3.6,proxy),'soft userdata contact preserves the armed payload')
    assert(M.shouldDetonate(s,30/3.6,proxy),'reflected userdata contact must trigger at the exact speed threshold')
    penetrating=true;assert(not M.shouldDetonate(s,100,proxy),'initial overlap still rejects userdata contact')
    penetrating=false
    local before=#exploded
    assert(M.shouldDetonate(s,100,proxy)and M.detonate(s,{X=100,Y=200,Z=300},gameplay))
    assert(#exploded==before+1 and not M.shouldDetonate(s,100,proxy),'userdata collision commits native explosion once')
    M.clear(s);s.world.time=2;M.update(0,gameplay,nil,s.world)
    debug.setmetatable(proxy,original);proxy:close()
end

local settings=dofile('mod/Scripts/weapon_settings.lua')
assert(settings.defaults().impactSpeed==30)
assert(settings.parse('1 2.25 1 20').impactSpeed==30,'legacy four-field settings keep the new safe default')
assert(settings.parse('1 2.25 1 20 65').impactSpeed==65)
assert(settings.parse('1 2.25 1 20 65.000').impactSpeed==65)
for _,text in ipairs({'1 1 0 3 0','1 1 0 3 155','1 1 0 3 32','1 1 0 3 nan','1 1 0 3 1e2','1 1 0 3 30 1'})do
    assert(not settings.parse(text),'invalid or extra impact speed fields must not be silently accepted: '..text)
end
local prefix=os.tmpname()..'-'
local saved,values=settings.save(prefix,{mode=1,power=2.25,grenade=1,charges=7,impactSpeed=65})
assert(saved and values.impactSpeed==65 and settings.load(prefix).impactSpeed==65)
assert(settings.save(prefix,'1 2.25 1 7')and settings.load(prefix).impactSpeed==30)
assert(not settings.save(prefix,{mode=1,power=1,grenade=0,charges=3,impactSpeed=32}))
os.remove(prefix..'weapon-settings.txt');os.remove(prefix:sub(1,-2))

-- A level change cancels both unused ready slots and a deferred preparation,
-- even when the old world wrapper is still valid. No copied resources can be
-- activated from an older session or proceed while menus pause preparation.
world=object({time=0});s=session(world);local stalePoolBegin=#actors
state=M.start(s,{mode=2,charges=0},gameplay);assert(M.drop(s,gameplay))
M.prepare(s,gameplay,nil,true);M.prepare(s,gameplay,nil,true)
assert(state.preparing and #state.ready==1)
local beforePaused=setupCalls
for _=1,100 do M.prepare(s,gameplay,nil,false)end
assert(setupCalls==beforePaused,'paused preparation never advances native work')
M.update(0,gameplay,nil,object({time=0}))
assert(not s.weapons and not state.open and not state.preparing and #state.ready==0)
for index=stalePoolBegin+1,#actors do assert(actors[index].dead,'world change cancels ready, pending and live owned carriers')end
for completed=1,5 do
    world=object({time=0});s=session(world);local firstOwned=#actors+1
    state=M.start(s,{mode=2,charges=0},gameplay)
    for _=1,completed do M.prepare(s,gameplay,nil,true)end
    assert(type(state.preparation)=='number'and state.preparation==completed+1,
        'preparation persists only an explicit phase index between main-state callbacks')
    local pending=state.preparing
    assert(pending and pending.actor and not pending.actor.collision and not pending.actor.StaticMeshComponent.physics,
        'a partially prepared carrier must stay physically dormant between callbacks')
    M.clear(s)
    for index=firstOwned,#actors do assert(actors[index].dead,'exit cancels every incomplete explicit phase')end
end
do
    world=object({time=0});s=session(world);state=M.start(s,{mode=2,charges=0},gameplay)
    M.prepare(s,gameplay,nil,true);local failed=state.preparing.actor
    failure='ccd';M.prepare(s,gameplay,nil,true);failure=nil
    assert(failed.dead and not state.preparing and not state.preparation and #state.ready==2 and not state.failure,
        'one failed background phase rolls back only its owned carrier and retains existing prepared charges')
    local before=setupCalls;world.time=.1;M.prepare(s,gameplay,nil,true)
    assert(setupCalls==before,'background retry respects its game-time delay')
    world.time=.5
    for _=1,6 do M.prepare(s,gameplay,nil,true)end
    assert(#state.ready==3 and not state.preparing,'a failed explicit phase can replenish on the registered main state')
    M.clear(s)
end

-- Measurable burst contract: prepared release performs no asset load, actor
-- construction, prototype registration or body rebuilding. Refill advances
-- only one bounded phase per frame and never on a frame with a drop attempt.
local maximumReleaseCalls,maximumPrepareCalls=0,0
for _,payload in ipairs({2,3})do
terrain={};world=object({time=0});s=session(world)
local poolBegin=#actors;state=M.start(s,{mode=payload,grenade=1,charges=0},gameplay)
local impactOwner=state.record and state.record.actor
assert(#actors-poolBegin==(payload==3 and 3 or 2)and #state.ready==2,
    'launch prepares only two ready grenades and the optional separate impact payload')
local drops=0
local nextDrop=0;local traceBegin=#traceCalls;local loadBegin=blockingCalls
for frame=1,360 do
    world.time=frame/60
    for index=poolBegin+1,#actors do
        local actor=actors[index]
        if not actor.dead and actor.collision and actor.StaticMeshComponent.physics then actor.StaticMeshComponent:advancePhysics(1/60)end
    end
    M.update(0,gameplay,nil,world)
    local didDrop=false
    if drops<20 and world.time+1e-8>=nextDrop then
        local actorCount,componentCount,before=#actors,#components,setupCalls
        assert(M.drop(s,gameplay),'a sustained 250 ms burst must have a prepared payload')
        local used=setupCalls-before;maximumReleaseCalls=math.max(maximumReleaseCalls,used)
        assert(used<=9 and #actors==actorCount and #components==componentCount and blockingCalls==loadBegin,
            'drop hot path has at most nine actor/body calls and no construction, config registration or blocking loading')
        drops=drops+1;nextDrop=world.time+.25;didDrop=true
    end
    local before=setupCalls
    M.prepare(s,gameplay,nil,true)
    local used=setupCalls-before;maximumPrepareCalls=math.max(maximumPrepareCalls,used)
    assert(used<=12,'background preparation has a fixed per-frame reflected setup bound')
    if didDrop then assert(used==0,'a drop frame must not also rebuild a payload')end
end
assert(drops==20 and maximumReleaseCalls==9 and maximumPrepareCalls<=12)
if payload==3 then
    assert(not impactOwner.dead and not state.attempted and state.remaining==math.huge
        and M.shouldDetonate(s,30/3.6,{bStartPenetrating=false}),
        'unlimited combined-mode burst retains a fully armed impact payload')
end
assert(#traceCalls-traceBegin<=20*(4+4*(M.fuseSeconds/M.guardInterval+1)),
    'full sphere sweeps retain four geometry queries, bounded to 50 ms plus each fuse frame')
local frozenTraces=#traceCalls
for _=1,100 do M.update(0,gameplay,nil,world)end
assert(#traceCalls==frozenTraces,'paused game-time samples never repeat grenade movement queries')
local spare=state.ready[#state.ready]or state.preparing
M.clear(s);if spare then assert(spare.actor==nil,'unused and partly prepared resources are destroyed on flight exit')end
world.time=12;M.update(0,gameplay,nil,world);world.time=14;M.update(0,gameplay,nil,world)
for index=poolBegin+1,#actors do assert(actors[index].dead,'no owned pooled/live actor leaks after fuse cleanup and exit')end
end

-- A reused physical carrier must receive a fresh native one-shot component.
world=object({time=0});s=session(world);state=M.start(s,{mode=2,charges=0},gameplay)
assert(M.drop(s,gameplay));local reuse=actors[#actors];local oldBody=reuse.StaticMeshComponent;local oldComponent=components[#components]
world.time=3;M.update(0,gameplay,nil,world);world.time=5;M.update(0,gameplay,nil,world)
assert(#state.recycled==1 and not reuse.dead and not reuse.StaticMeshComponent.physics)
for _=1,7 do M.prepare(s,gameplay,nil,true)end
local warm=state.ready[#state.ready]
assert(warm.actor==reuse and warm.body==oldBody and warm.component~=oldComponent and oldComponent.dead,
    'spent native explosion state is never reset or reused with the cached physical body')
world.time=5.25;assert(M.drop(s,gameplay));M.clear(s);world.time=8.25;M.update(0,gameplay,nil,world)
world.time=10.25;M.update(0,gameplay,nil,world);assert(reuse.dead)

-- Optional measured comparison against the actual pre-v46 adapter. This is a
-- fixture only; no native game object or installed file is changed by the test.
local baselinePath=os.getenv('ZFPV_WEAPONS_BASELINE')
if baselinePath and baselinePath~=''then
    local baseline=dofile(baselinePath);local prior=session(object({time=0}))
    assert(not baseline.prepare,'performance baseline must be a pre-pool adapter, not the newly installed revision')
    baseline.start(prior,{mode=2,grenade=1,charges=1},gameplay)
    local before=setupCalls;local beforeTrace=#traceCalls
    assert(baseline.drop(prior,gameplay))
    print('Release setup calls: baseline='..(setupCalls-before)..' v46='..maximumReleaseCalls..'; clearance sweeps baseline='..(#traceCalls-beforeTrace)..' v46=4; staged preparation maximum='..maximumPrepareCalls)
    baseline.clear(prior);prior.world.dead=true;baseline.update(0,gameplay)
end
print('PASS mode3 independent drop+impact payloads, exhausted ammo retains impact, post-impact released fuses survive, combined failure/world rollback, mode2/mode3 sustained20-drop bursts, release9/setup12 call bounds, registered-main-state preparation, packed out-bool/userdata thresholds, native once-only explosions and legacy settings')
print('drone weapons test: PASS (immediate independent gravity drop, no drone XY/ascent inheritance, moving owner/proxy/camera cannot tow body, collision-only position/velocity corrections, explicit physical world collision/CCD survives construction, low-hover release clearance, high-speed thin-floor/lateral-wall sweeps, fuse-frame above-ground explosion, null-wrapper crash regression, missing AssetRegistry API fallback, lazy native class loading, native physics/meshes, two grenade types, 20 power prototypes, pause-aware fuse, independent post-flight ownership, atomic ammo, bounded actors, exactly-once explosions)')
