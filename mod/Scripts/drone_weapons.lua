-- Drone equipment uses the game's grenade meshes and native ExplosionComponent.
-- AGrenade itself requires an unreflected game-model binding before its native
-- tick (shipping 0x68f6bb8); spawning that actor with only SID is unsafe. Our
-- owned physical carrier needs no game-model pointer. Lua manages its fuse and
-- terrain guard; native explosion prototypes own damage, impulse, FX and audio.
local M={maxActive=32,fuseSeconds=3,dropCooldown=.25,guardInterval=.05,poolReady=3}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local assetLoader=dofile(here..'asset_loader.lua').new()
local collision=dofile(here..'drone_collision.lua')
local weaponSettings=dofile(here..'weapon_settings.lua')
local identity={Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
local catalogue={
    {sid='GrenadeRGD5',explosion='ExplosionRGD5',mass=.2,
        mesh='/Game/_Stalker_2/weapons/grenades/SM_rgd5/SM_gre_rgd5_no_tear.SM_gre_rgd5_no_tear'},
    {sid='GrenadeF1',explosion='ExplosionF1',mass=.3,
        mesh='/Game/_Stalker_2/weapons/grenades/SM_f1/SM_gre_f1_no_tear.SM_gre_f1_no_tear'},
}
local cache,projectiles,pools={},{},{}
local ownedCount=0
local function finite(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return call(o,'IsValid')==true end
local function same(a,b)
    if not valid(a)or not valid(b)then return false end
    if a==b then return true end
    local left,right=call(a,'GetAddress'),call(b,'GetAddress')
    return left~=nil and left==right
end
local function emit(log,text)if log then log('Drone weapons: '..text)end end
local function vector(v)return v and finite(v.X) and finite(v.Y) and finite(v.Z) end
local function position(s)
    local p=s and s.flight and s.flight.p
    if p and finite(p.x) and finite(p.y) and finite(p.z)then return {X=p.x*100,Y=p.y*100,Z=p.z*100}end
end
local function copy(v)return {X=v.X,Y=v.Y,Z=v.Z}end
local function traceSystem()
    if valid(cache.system)then return cache.system end
    local ok,library=pcall(StaticFindObject,'/Script/Engine.Default__KismetSystemLibrary')
    assert(ok and valid(library),'grenade collision query unavailable')
    cache.system=library;return library
end
local function traceContext(context,pawn,actor,profile)
    local ignore={}
    if valid(pawn)then ignore[#ignore+1]=pawn end
    if valid(actor)then ignore[#ignore+1]=actor end
    return {pawn=context,traceIgnore=ignore,traceProfile=profile or false}
end
local function pawnProfile(pawn)
    local capsule=pawn.CapsuleComponent
    return valid(capsule)and call(capsule,'GetCollisionProfileName')or false
end
local function sweep(record,startPos,endPos)
    -- Use both simple and complex geometry and the game's own walking profile,
    -- matching drone_collision's bounded four-query path. The physical body is
    -- the primary collider; this sweep also catches complex-only terrain and
    -- segments crossed between Lua updates. Never pass destroyed ignore actors.
    local context=valid(record.actor)and record.actor or record.instigator
    assert(valid(context),'grenade collision context unavailable')
    return collision.trace(traceSystem(),traceContext(context,record.instigator,record.actor,record.profile),
        startPos,endPos,record.radius)
end
local function hitPosition(hit,startPos,endPos)
    assert(not collision.isPenetrating(hit),'grenade release/movement starts inside geometry')
    local normal=hit.Normal
    assert(vector(normal),'grenade collision normal unavailable')
    local length=math.sqrt(normal.X*normal.X+normal.Y*normal.Y+normal.Z*normal.Z)
    assert(length>.5,'grenade collision normal invalid')
    normal={X=normal.X/length,Y=normal.Y/length,Z=normal.Z/length}
    local location=hit.Location
    if not vector(location)then
        assert(finite(hit.Time),'grenade collision location unavailable')
        local t=math.max(0,math.min(1,hit.Time))
        location={X=startPos.X+(endPos.X-startPos.X)*t,Y=startPos.Y+(endPos.Y-startPos.Y)*t,Z=startPos.Z+(endPos.Z-startPos.Z)*t}
    end
    -- FHitResult.Location is the swept sphere's centre at contact, whereas
    -- ImpactPoint is the terrain surface. Do not add the radius a second time.
    return {X=location.X+normal.X,Y=location.Y+normal.Y,Z=location.Z+normal.Z},normal
end
local function physicalCollision(body,dormant)
    body:SetCollisionProfileName(FName('PhysicsActor'),true)
    -- Verified shipping ECollisionChannel values: PhysicsBody=5, Pawn=2.
    -- A named profile alone can inherit query-only/custom responses. Explicitly
    -- enable physics and block world geometry. Pawn contact is ignored as before.
    body:SetCollisionObjectType(5)
    body:SetCollisionEnabled(3) -- QueryAndPhysics
    body:SetCollisionResponseToAllChannels(2) -- ECR_Block
    body:SetCollisionResponseToChannel(2,0) -- ECC_Pawn / ECR_Ignore
    body:SetUseCCD(true,FName('None'))
    -- Effective collision getters honor the owner's disabled collision flag.
    -- Configure stored body responses while dormant; validate effective physics
    -- only in an atomic phase with its actor enabled, before returning to idle.
    if not dormant then
        assert(body:GetCollisionEnabled()==3 and body:K2_IsPhysicsCollisionEnabled()==true,
            'grenade physical collision unavailable')
    end
    assert(body:GetCollisionResponseToChannel(0)==2 and body:GetCollisionResponseToChannel(1)==2,
        'grenade world collision unavailable')
end
local function bodyRadius(body)
    local minimum,maximum={X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
    body:GetLocalBounds(minimum,maximum)
    assert(vector(minimum)and vector(maximum),'grenade mesh bounds unavailable')
    local x=math.max(math.abs(minimum.X),math.abs(maximum.X))
    local y=math.max(math.abs(minimum.Y),math.abs(maximum.Y))
    local z=math.max(math.abs(minimum.Z),math.abs(maximum.Z))
    local radius=math.sqrt(x*x+y*y+z*z)+.5
    assert(finite(radius)and radius>.5 and radius<=50,'grenade mesh bounds invalid')
    return math.max(4,radius)
end
local function guardMovement(record)
    local current=record.actor:K2_GetActorLocation()
    assert(vector(current)and valid(record.body),'grenade physical location unavailable')
    local last=record.lastPosition
    if last and (current.X~=last.X or current.Y~=last.Y or current.Z~=last.Z)then
        local yes,hit=sweep(record,last,current)
        if yes then
            local safe,normal
            if collision.isPenetrating(hit)then
                -- A moving obstacle can penetrate a previously clear point.
                -- Keep the last verified position until a full segment is clear.
                safe=copy(last)
            else safe,normal=hitPosition(hit,last,current)end
            assert(record.actor:K2_SetActorLocation(safe,false,{},true)==true,'grenade collision correction failed')
            local velocity=record.body:GetPhysicsLinearVelocity(FName('None'))
            if not vector(velocity)then velocity={X=0,Y=0,Z=0}end
            if normal then
                local into=velocity.X*normal.X+velocity.Y*normal.Y+velocity.Z*normal.Z
                if into<0 then
                    velocity={X=velocity.X-normal.X*into*1.2,Y=velocity.Y-normal.Y*into*1.2,Z=velocity.Z-normal.Z*into*1.2}
                end
            else velocity={X=0,Y=0,Z=0}end
            record.body:SetPhysicsLinearVelocity(velocity,false,FName('None'))
            current=safe;record.corrections=(record.corrections or 0)+1
        end
    end
    record.lastPosition=copy(current)
    return current
end
local function exactClass(class,name,package)
    for _=1,16 do
        if not valid(class)then return end
        if call(class,'IsAnyClass')==true and call(call(class,'GetFName'),'ToString')==name then
            local full=call(class,'GetFullName')
            if type(full)=='string' and full:match('/Script/'..package..'[%.:]'..name..'$')then return class end
        end
        class=call(class,'GetSuperStruct')
    end
end
local function resolveClass(name,package,discovery)
    local key=package..'.'..name;if valid(cache[key])then return cache[key]end
    if type(StaticFindObject)=='function'then
        for _,separator in ipairs({'.',':'})do
            local ok,o=pcall(StaticFindObject,'/Script/'..package..separator..name)
            local class=ok and exactClass(o,name,package)
            if class then cache[key]=class;return class end
        end
    end
    if type(FindFirstOf)=='function'then
        local ok,o=pcall(FindFirstOf,discovery or name)
        -- A missing UE4SS search returns a UObject wrapper with a null native
        -- pointer. GetClass dereferences it; pcall cannot catch that access
        -- violation. Always establish native validity before reflecting it.
        local class=ok and valid(o)and exactClass(call(o,'GetClass'),name,package)
        if class then cache[key]=class;return class end
    end
    -- Native classes may still be lazily registered when no matching actor or
    -- component exists. Soft loading resolves the compiled class/package; it
    -- does not construct or tick an uninitialized AGrenade actor.
    local loaded=assetLoader:load('/Script/'..package..'.'..name)
    local class=exactClass(loaded,name,package)
    if class then cache[key]=class;return class end
    if package=='Stalker2'and name=='ExplosionComponent'then
        -- This shipped blueprint references the native grenade/explosion
        -- classes. Loading its generated class/CDO also initializes their
        -- registration if the direct native soft path did not resolve it.
        local blueprint=assetLoader:load('/Game/GameLite/Blueprints/Grenades/BP_grenade.BP_Grenade_C')
        if valid(blueprint)then
            local ok,o=pcall(StaticFindObject,'/Script/Stalker2.ExplosionComponent')
            class=ok and exactClass(o,name,package)
            if class then cache[key]=class;return class end
        end
    end
end
local function asset(path)
    return assetLoader:load(path)
end
local function removeComponent(component,owner)
    if valid(component)then pcall(function()component:K2_DestroyComponent(owner)end)end
end
local function destroy(record)
    if valid(record.actor)then pcall(function()record.actor:K2_DestroyActor()end)end
    record.actor=nil;record.body=nil;record.component=nil;record.world=nil;record.instigator=nil;record.lastPosition=nil
    if record.counted then record.counted=false;ownedCount=ownedCount-1 end
end
local function counted(record)
    assert(ownedCount<M.maxActive,'too many active grenades/explosions')
    ownedCount=ownedCount+1;record.counted=true;return record
end
local function explosionOrdinal()
    if cache.explosionOrdinal then return cache.explosionOrdinal end
    local enum=StaticFindObject('/Script/Stalker2.EPrototypeClass')
    assert(valid(enum),'EPrototypeClass enum unavailable')
    enum:ForEachName(function(name,value)
        if name:ToString():match('([^:]+)$')=='Explosion'and finite(value)and value%1==0 then
            cache.explosionOrdinal=value;return true
        end
    end)
    return assert(cache.explosionOrdinal,'Explosion prototype enum value unavailable')
end
local function explosionComponent(owner,sid)
    local class=assert(resolveClass('ExplosionComponent','Stalker2','GrenadeExplosionComponent'),
        'native ExplosionComponent class unavailable')
    local component=owner:AddComponentByClass(class,true,identity,true)
    assert(valid(component),'native explosion component creation failed')
    local ok,err=pcall(function()
        -- Resolve the live enum instead of copying the reference SDK ordinal:
        -- its Explosion value is 30, but the installed shipping game uses 31.
        -- Configure every reflected field before registration/BeginPlay.
        local prototype=component.PrototypeSID
        prototype.Value=sid;prototype.PrototypeClass=explosionOrdinal();prototype.Subtype=FName('None')
        owner:FinishAddComponent(component,true,identity)
    end)
    if not ok then removeComponent(component,owner);error(err)end
    return component
end
local function preparePhase(s,state)
    -- UE4SS reflection resolves the calling lua_State in its registered mod
    -- instances. A coroutine has a different, unregistered state even when it
    -- runs on the game thread. Advance plain phases on the caller's state.
    local record=assert(state.preparing,'grenade preparation record unavailable')
    local phase=state.preparation
    local data=catalogue[state.grenade+1]
    if phase==1 then
        record.transform={Translation=assert(position(s),'flight position unavailable'),Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
        record.actor=state.gameplay:BeginDeferredActorSpawnFromClass(s.pawn,state.carrierClass,record.transform,1,s.pawn,0)
        assert(valid(record.actor),'physical grenade preparation failed')
        record.actor:SetActorEnableCollision(false);record.actor:SetActorHiddenInGame(true)
        local body=record.actor.StaticMeshComponent
        assert(valid(body),'physical grenade mesh component unavailable')
        body:SetMobility(2)
        assert(body:SetStaticMesh(state.mesh)==true,'armed grenade mesh assignment failed')
        record.body=body;record.radius=bodyRadius(body);record.profile=pawnProfile(s.pawn)
    elseif phase==2 then
        physicalCollision(record.body,true)
    elseif phase==3 then
        record.component=explosionComponent(record.actor,data.explosion)
    elseif phase==4 then
        state.gameplay:FinishSpawningActor(record.actor,record.transform,0)
        assert(valid(record.actor)and call(record.actor,'IsActorBeingDestroyed')~=true,'grenade preparation failed')
        record.actor:SetActorEnableCollision(false);record.actor:SetActorHiddenInGame(true)
        local body=record.actor.StaticMeshComponent;assert(valid(body),'grenade physical body unavailable')
        record.body=body
    elseif phase==5 then
        physicalCollision(record.body,true)
    elseif phase==6 then
        local body=record.body
        record.actor:SetActorEnableCollision(true)
        assert(body:GetCollisionEnabled()==3 and body:K2_IsPhysicsCollisionEnabled()==true,
            'grenade physical collision unavailable')
        body:SetEnableGravity(true);body:SetSimulatePhysics(true)
        assert(body:IsSimulatingPhysics(FName('None'))==true,'grenade mesh has no physical body')
        body:SetUseCCD(true,FName('None'))
        body:SetMassOverrideInKg(FName('None'),data.mass,true)
        body:SetSimulatePhysics(false)
    elseif phase==7 then
        -- A spent ExplosionComponent is one-shot native state. Keep only the
        -- already built Chaos body and register a fresh component for reuse.
        record.component=explosionComponent(record.actor,data.explosion)
    elseif phase~=8 then error('grenade preparation phase invalid')
    end
    if phase~=6 and phase~=8 then state.preparation=phase+1;return false end
    -- Complete warmup and disabling atomically: never leave a dormant pooled
    -- body simulating or colliding between update callbacks.
    record.actor:SetActorEnableCollision(false);record.actor:SetActorHiddenInGame(true)
    record.actor:SetLifeSpan(0)
    record.world=s.world;record.instigator=s.pawn;record.sid=data.sid;record.pool=state
    record.exploded=nil;record.cleanupAt=nil;record.releaseTime=nil;record.due=nil
    record.lastPosition=nil;record.nextGuard=nil;record.corrections=0
    record.transform=nil
    return true
end
local function beginPreparation(s,state)
    local record=table.remove(state.recycled)or counted({world=s.world,instigator=s.pawn})
    state.preparing=record;state.preparation=record.actor and 7 or 1
end
local function advancePreparation(s,state)
    local ok,complete=pcall(preparePhase,s,state)
    if not ok then
        destroy(state.preparing);state.preparing=nil;state.preparation=nil
        return false,tostring(complete)
    end
    if complete then
        state.ready[#state.ready+1]=state.preparing;state.preparing=nil;state.preparation=nil
    end
    return true
end
function M.start(s,settings,gameplay,log)
    if s.weapons then return s.weapons end
    settings=settings or {}
    local mode=finite(settings.mode) and settings.mode%1==0 and settings.mode>=0 and settings.mode<=weaponSettings.maxMode and settings.mode or 0
    local power=finite(settings.power) and math.max(.25,math.min(5,settings.power))or 1
    power=math.floor(power*4+.5)/4
    local grenade=settings.grenade==1 and 1 or 0
    local charges=finite(settings.charges) and settings.charges%1==0 and settings.charges>=0 and settings.charges<=20 and settings.charges or 3
    local state={mode=mode,power=power,grenade=grenade,remaining=charges==0 and math.huge or charges,
        impactSpeed=weaponSettings.value(settings).impactSpeed}
    s.weapons=state
    if weaponSettings.hasKamikaze(mode)then
        state.prototype=string.format('ZoneFPV_Kamikaze_%02d',math.floor(power*4+.5))
        local record={world=s.world,instigator=s.pawn}
        local ok,value=pcall(function()
            counted(record)
            assert(valid(s.camera)and valid(s.world)and valid(gameplay),'flight camera unavailable')
            local p=assert(position(s),'flight position unavailable')
            local class=assert(resolveClass('StaticMeshActor','Engine'),'explosive carrier class unavailable')
            local transform={Translation=p,Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
            record.actor=gameplay:BeginDeferredActorSpawnFromClass(s.pawn,class,transform,1,s.pawn,0)
            assert(valid(record.actor),'explosive carrier spawn failed')
            record.actor:SetActorEnableCollision(false);record.actor:SetActorHiddenInGame(true)
            local body=record.actor.StaticMeshComponent
            assert(valid(body),'explosive carrier mesh component unavailable')
            body:SetMobility(2)
            record.component=explosionComponent(record.actor,state.prototype)
            gameplay:FinishSpawningActor(record.actor,transform,0)
            assert(valid(record.actor),'explosive carrier initialization failed')
            record.actor:SetActorEnableCollision(false);record.actor:SetActorHiddenInGame(true)
            return record
        end)
        if ok then state.record=value;state.component=value.component
        else destroy(record);state.failure=tostring(value);emit(log,'kamikaze arming failed: '..state.failure)end
    end
    if weaponSettings.hasGrenades(mode)and not state.failure then
        state.ready={};state.recycled={};state.gameplay=gameplay;state.open=true
        pools[#pools+1]={session=s,state=state}
        local ok,err=pcall(function()
            assert(valid(s.world)and valid(s.pawn)and valid(gameplay),'grenade preparation context unavailable')
            state.carrierClass=assert(resolveClass('StaticMeshActor','Engine'),'physical carrier class unavailable')
            traceSystem()
            local mesh,loadError=asset(catalogue[grenade+1].mesh)
            assert(valid(mesh),'armed grenade mesh unavailable: '..tostring(loadError));state.mesh=mesh
            for _=1,math.min(2,state.remaining)do
                beginPreparation(s,state)
                while state.preparation do local yes,why=advancePreparation(s,state);assert(yes,why)end
            end
        end)
        if not ok then state.failure=tostring(err);emit(log,'grenade preparation failed: '..state.failure)end
    end
    return state
end
function M.clear(s)
    if not s then return end
    local state=s.weapons;s.weapons=nil
    if state then
        state.open=false
        if state.preparing then destroy(state.preparing);state.preparing=nil;state.preparation=nil end
        for _,record in ipairs(state.ready or {})do destroy(record)end
        for _,record in ipairs(state.recycled or {})do destroy(record)end
        state.ready={};state.recycled={}
        if state.record then destroy(state.record)end
        state.record=nil;state.component=nil
    end
    for i=#pools,1,-1 do if pools[i].state==state then table.remove(pools,i)end end
    -- Released grenades are independent actors in projectiles, not equipment on
    -- this session. Returning the pilot or changing equipment must not disarm them.
end
function M.shouldDetonate(s,closingSpeed,hit)
    local state=s and s.weapons
    if not state or not weaponSettings.hasKamikaze(state.mode)or state.attempted or state.failure or not finite(closingSpeed)
        or closingSpeed<=0 or closingSpeed*3.6+1e-9<state.impactSpeed then return false end
    -- Our trace currently returns an out-param table; other reflected hit
    -- wrappers can be userdata. Read fields rather than assuming a Lua type.
    local ok,penetrating=pcall(function()return hit.bStartPenetrating end)
    if not ok then return false end
    if type(penetrating)~='boolean'then return false end
    -- Share the packed-bool-aware classification with nearest-hit selection,
    -- clearance and the movement guard. Time=0 overlaps remain non-explosive.
    local readable,isPenetrating=pcall(collision.isPenetrating,hit)
    return readable and not isPenetrating
end
function M.prepare(s,gameplay,log,allowed)
    local state=s and s.weapons
    if not state or not weaponSettings.hasGrenades(state.mode)or not state.open or state.failure or state.attempted then return end
    if state.justDropped then state.justDropped=false;return end
    if allowed==false or not valid(s.world)or not valid(s.pawn)or not valid(gameplay)then return end
    local time=call(gameplay,'GetTimeSeconds',s.world)
    if not finite(time)or state.retryAt and time<state.retryAt then return end
    if state.remaining<=0 then
        if state.preparing then destroy(state.preparing);state.preparing=nil;state.preparation=nil end
        for _,record in ipairs(state.ready)do destroy(record)end;state.ready={}
        for _,record in ipairs(state.recycled)do destroy(record)end;state.recycled={}
        return
    end
    if not state.preparation then
        if #state.ready>=math.min(M.poolReady,state.remaining)or ownedCount>=M.maxActive and #state.recycled==0 then return end
        beginPreparation(s,state)
    end
    local yes,why=advancePreparation(s,state)
    if not yes then state.retryAt=time+.5;emit(log,'grenade background preparation failed: '..why)end
end
function M.drop(s,gameplay,log)
    local state=s and s.weapons
    if not state then return false,'fpv_required'end
    if not weaponSettings.hasGrenades(state.mode)then return false,'grenade_mode_required'end
    if state.attempted then return false,'kamikaze_spent'end
    if state.remaining<=0 then return false,'grenades_empty'end
    local p=position(s)
    if not p or not valid(s.world)or not valid(s.pawn)or not valid(gameplay)then return false,'fpv_required'end
    local time=call(gameplay,'GetTimeSeconds',s.world)
    if not finite(time)then return false,'grenade_unavailable'end
    if state.lastDrop and time-state.lastDrop>=0 and time-state.lastDrop+1e-9<M.dropCooldown then return false,'grenade_cooldown'end
    state.justDropped=true
    if state.failure then return false,'grenade_unavailable'end
    local record=table.remove(state.ready)
    if not record then return false,'grenades_busy'end
    local ok,err=pcall(function()
        assert(valid(record.actor)and valid(record.body)and valid(record.component),'prepared grenade unavailable')
        -- One complete conservative sphere sweep covers the release start,
        -- segment and endpoint. Prepared actors are already fully registered;
        -- release never spawns, registers, soft-loads or reapplies mesh/collision
        -- configuration. The engine still owns physics activation itself.
        local target={X=p.X,Y=p.Y,Z=p.Z-35}
        local yes,hit=sweep(record,p,target)
        if yes then target=hitPosition(hit,p,target)end
        assert(record.actor:K2_SetActorLocation(target,false,{},true)==true,'grenade release location unavailable')
        record.actor:SetActorEnableCollision(true);record.actor:SetActorHiddenInGame(false)
        assert(record.body:GetCollisionEnabled()==3 and record.body:K2_IsPhysicsCollisionEnabled()==true,
            'grenade physical collision unavailable')
        record.body:SetSimulatePhysics(true)
        assert(record.body:IsSimulatingPhysics(FName('None'))==true,'grenade mesh has no physical body')
        record.body:SetPhysicsLinearVelocity({X=0,Y=0,Z=-100},false,FName('None'))
        record.actor:SetLifeSpan(30)
        record.lastPosition=copy(target);record.releaseTime=time;record.due=time+M.fuseSeconds
        record.nextGuard=time+M.guardInterval;record.pool=state
    end)
    if not ok then
        -- An obstructed release keeps the prepared charge. Other failures also
        -- consume no inventory; rebuild the owned slot off the input hot path.
        if valid(record.actor)and tostring(err):find('starts inside geometry',1,true)then state.ready[#state.ready+1]=record
        else destroy(record)end
        emit(log,'grenade release failed: '..tostring(err));return false,'grenade_unavailable'
    end
    projectiles[#projectiles+1]=record
    if state.remaining~=math.huge then state.remaining=state.remaining-1 end
    state.lastDrop=time
    emit(log,record.sid..' armed; fuse 3 s; remaining '..tostring(state.remaining))
    return true
end
function M.detonate(s,p,gameplay,log)
    local state=s and s.weapons
    if not state then return false,'fpv_required'end
    if not weaponSettings.hasKamikaze(state.mode)then return false,'kamikaze_mode_required'end
    if state.attempted then return false,'kamikaze_spent'end
    if not vector(p)or not valid(s.world)or not valid(s.pawn)then return false,'fpv_required'end
    state.attempted=true -- native effects may have committed before a Lua error
    local record=state.record
    if not record or not valid(state.component)or not valid(record.actor)then emit(log,'kamikaze unavailable: '..tostring(state.failure));return false,'kamikaze_unavailable'end
    local ok,err=pcall(function()
        record.actor:K2_SetActorLocation({X=p.X,Y=p.Y,Z=p.Z},false,{},true)
        state.component:ExplodeAtCustomLocation({X=p.X,Y=p.Y,Z=p.Z},s.pawn)
    end)
    -- Hand ownership to the global cleanup queue even on an uncertain native
    -- failure. Exiting FPV must not tear down an explosion's owning actor/audio.
    local time=call(gameplay,'GetTimeSeconds',s.world)
    record.exploded=true;record.releaseTime=finite(time)and time or 0;record.cleanupAt=record.releaseTime+2
    projectiles[#projectiles+1]=record;state.record=nil;state.component=nil
    pcall(function()record.actor:SetLifeSpan(10)end)
    if not ok then emit(log,'kamikaze failed: '..tostring(err));return false,'kamikaze_unavailable'end
    state.detonated=true;emit(log,'kamikaze native explosion '..state.prototype)
    return true
end
function M.update(now,gameplay,log,...)
    local hasCurrentWorld=select('#',...)>0;local currentWorld=...
    local times={}
    -- Called on the existing game-thread update even without an active flight.
    -- GetTimeSeconds follows pause/time dilation; wall-clock menu time never
    -- consumes a grenade fuse. Each actor's world owns that fuse independently.
    for i=#projectiles,1,-1 do
        local record=projectiles[i]
        if not valid(record.world)or not valid(record.actor)or (hasCurrentWorld and not same(record.world,currentWorld))then destroy(record);table.remove(projectiles,i)
        else
            local time=times[record.world]
            if time==nil then time=call(gameplay,'GetTimeSeconds',record.world);times[record.world]=time or false end
            if not finite(time)or time<record.releaseTime then destroy(record);table.remove(projectiles,i)
            elseif record.cleanupAt and time>=record.cleanupAt then
                local state=record.pool
                if state and state.open and state.remaining>0 and #state.recycled<M.poolReady and valid(record.body)then
                    local ok=pcall(function()
                        record.body:SetSimulatePhysics(false)
                        if valid(record.component)then record.component:K2_DestroyComponent(record.actor)end
                        record.component=nil;record.actor:SetLifeSpan(0)
                        state.recycled[#state.recycled+1]=record
                    end)
                    if not ok then destroy(record)end
                else destroy(record)end
                table.remove(projectiles,i)
            elseif not record.exploded then
                local ok,err=pcall(function()
                    -- Correct a crossed surface before the fuse reads position:
                    -- native damage and FX must never fire under that surface.
                    if time<record.due and time<(record.nextGuard or 0)then return end
                    local p=guardMovement(record);record.nextGuard=time+M.guardInterval
                    if time<record.due then return end
                    record.exploded=true
                    assert(valid(record.component),'grenade explosion component unavailable')
                    record.component:ExplodeAtCustomLocation({X=p.X,Y=p.Y,Z=p.Z},valid(record.instigator)and record.instigator or nil)
                end)
                if not ok then emit(log,'grenade movement/fuse failed: '..tostring(err));destroy(record);table.remove(projectiles,i)
                elseif record.exploded then
                    pcall(function()record.actor:SetActorHiddenInGame(true);record.actor:SetActorEnableCollision(false)end)
                    record.cleanupAt=time+2
                    emit(log,record.sid..' native explosion; collision corrections '..tostring(record.corrections or 0))
                end
            end
        end
    end
    for i=#pools,1,-1 do
        local pool=pools[i]
        if not valid(pool.session.world)or not valid(pool.session.pawn)
            or hasCurrentWorld and not same(pool.session.world,currentWorld)then M.clear(pool.session)end
    end
end
return M
