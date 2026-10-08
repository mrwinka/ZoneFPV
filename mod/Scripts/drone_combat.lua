-- Experimental drone durability. Collision/anomaly damage stays in Lua; the
-- optional invisible player proxy is only a target for the game's existing AI.
-- The supported native bridge intercepts actual ActorCore receive calls before
-- HP, armor and effects. Reflected observers remain optional on other runtimes.
-- Melee ability effects are a separate route; the scoped buttstock guard owns
-- their removal after an observed attack, outside native hit callbacks.
-- HP changes alone are not attack evidence: the game's stat tick can rebase HP
-- and maxHP without a hit. Never replace the player's maximum health to detect
-- direct C++ attacks.
local M={}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
M.nativeBridge=dofile(here..'native_bridge.lua')
M.aggression=dofile(here..'drone_aggression.lua')
M.buttstockGuard=dofile(here..'buttstock_guard.lua')
local HIT_DAMAGE=25
local HIT_HOOKS={
    {'OnReceiveBulletProjectileHit_BP','bullet'},
    {'OnReceiveMeleeHit_BP','melee'},
    {'OnReceiveProjectileHit_BP','projectile'},
    {'OnReceiveExplosionHit_BP','explosion'},
}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function valid(o)
    local ok,value=pcall(function() return o and (not o.IsValid or o:IsValid()) end)
    return ok and value
end
local function field(o,name)
    local ok,value=pcall(function() return o[name] end)
    if ok then return value end
end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    return pcall(invoke,o,k,...)
end
local function copy(v)
    assert(v and finite(v.X) and finite(v.Y) and finite(v.Z),'player position unavailable')
    return {X=v.X,Y=v.Y,Z=v.Z}
end
local function position(s)
    local p=s.flight and s.flight.p
    assert(p and finite(p.x) and finite(p.y) and finite(p.z),'drone position unavailable')
    return {X=p.x*100,Y=p.y*100,Z=p.z*100}
end
local function emit(g,message) if g.log then g.log('Drone combat: '..message) end end
local function queueHit(g,kind,amount)
    if g.broken then return end
    local t=os.clock()
    local queue=g.pendingHits
    local last=queue[#queue]
    -- One native ReceiveDamage can accompany a Blueprint hit notification.
    -- Merge different routes only; repeated native calls remain real attempts.
    if last and t>=last.time and t-last.time<=0.025 and
        ((last.kind=='projectile' and kind=='bullet') or
         (last.kind=='bullet' and kind=='projectile') or
         (last.kind=='native' and kind~='native') or
         (last.kind~='native' and kind=='native')) then
        if kind=='native' then last.amount=amount;last.kind=kind
        elseif last.kind~='native' then last.kind='bullet' end
        g.feedbackMerged=(g.feedbackMerged or 0)+1
    elseif #queue<32 then queue[#queue+1]={kind=kind,amount=amount,time=t} end
    g.feedbackEvents=(g.feedbackEvents or 0)+1
end
local function clearHooks(g)
    -- Disable dispatch first. Even if UE4SS refuses an unregistration during
    -- world teardown, the remaining callback cannot inspect an expired pawn.
    g.feedbackActive=false;g.pendingHits={}
    local errors={}
    if g.nativeReceiver then
        local ok,success,err=pcall(g.nativeReceiver.disarm,g.nativeReceiver)
        if not ok or success==false then errors[#errors+1]='native disarm: '..tostring(ok and err or success) end
        g.nativeReceiver=nil;g.directNativeReady=false
    end
    for _,h in ipairs(g.hooks or {}) do
        local ok,err=pcall(UnregisterHook,h.path,h.pre,h.post)
        if not ok then errors[#errors+1]=tostring(err) end
    end
    g.hooks={};g.feedbackReady=false
    if #errors>0 then emit(g,'hit feedback cleanup: '..table.concat(errors,'; ')) end
end
local function setupHooks(g,a)
    if M.nativeBridge then
        local ok,armed,detail=pcall(function()
            local client=M.nativeBridge.new(here..'../')
            g.nativeReceiver=client
            return client:arm(a.pawn)
        end)
        if ok and armed then
            g.directNativeReady=true;g.nativeFeedbackReady=true;g.feedbackReady=true
            g.feedbackActive=true;g.pendingHits={};g.hooks={}
            return
        end
        g.directNativeFailure=tostring(ok and detail or armed)
        if g.nativeReceiver then pcall(g.nativeReceiver.disarm,g.nativeReceiver);g.nativeReceiver=nil end
    end
    if type(RegisterHook)~='function' or type(UnregisterHook)~='function' then
        g.feedbackFailure='Blueprint hit hook API unavailable';return
    end
    local got,address=call(a.pawn,'GetAddress')
    if not got or address==nil then g.feedbackFailure='player identity unavailable';return end
    g.hooks={};g.pendingHits={};g.feedbackActive=true
    local function listen(path,fn)
        local ok,err=pcall(function()
            local pre,post=RegisterHook(path,fn)
            assert(type(pre)=='number' and type(post)=='number','hit hook registration IDs unavailable')
            g.hooks[#g.hooks+1]={path=path,pre=pre,post=post}
        end)
        return ok,err
    end
    -- Seven parameters and their types are from the captured player inventory.
    -- This native UFunction does not require the unavailable ProcessInternal
    -- address that prevented v3's nonnative Blueprint events from registering.
    local nativePath='/Script/Stalker2.Obj:ReceiveDamage'
    local nativeOK,nativeError=listen(nativePath,function(context,inDamage,damageType,armorDamage,armorPiercing,bleeding,bleedingChance,boneHit)
        if not g.feedbackActive then return end
        local accepted=pcall(function()
            local owner=context:get()
            if not valid(owner) or owner:GetAddress()~=address then return end
            local amount=inDamage:get()
            -- Change only incoming damage parameters for our hidden proxy.
            -- SetDamageMultiplier is an outgoing attack multiplier, not a shield.
            inDamage:set(0);armorDamage:set(0);bleeding:set(0);bleedingChance:set(0)
            if finite(amount) and amount>0 then
                queueHit(g,'native',amount)
                g.nativeEvents=(g.nativeEvents or 0)+1
            end
        end)
        if not accepted then g.feedbackCallbackFailure=true end
    end)
    g.nativeFeedbackReady=nativeOK
    if not nativeOK then g.nativeFeedbackFailure=tostring(nativeError) end
    -- Retain optional Blueprint observations on runtimes that support them.
    -- Each registration is independent: a missing script hook cannot discard a
    -- successfully registered native observer. Stop after the first failure.
    g.blueprintFeedbackReady=true
    for _,endpoint in ipairs(HIT_HOOKS) do
        local kind=endpoint[2]
        local ok,err=listen('/Script/Stalker2.Obj:'..endpoint[1],function(context)
            if not g.feedbackActive then return end
            local accepted=pcall(function()
                local owner=context:get()
                if valid(owner) and owner:GetAddress()==address then queueHit(g,kind,HIT_DAMAGE) end
            end)
            if not accepted then g.feedbackCallbackFailure=true end
        end)
        if not ok then g.blueprintFeedbackReady=false;g.blueprintFeedbackFailure=tostring(err);break end
    end
    g.feedbackReady=#g.hooks>0
    if not g.feedbackReady then
        g.feedbackActive=false
        g.feedbackFailure='native ReceiveDamage: '..tostring(g.nativeFeedbackFailure)..'; Blueprint: '..tostring(g.blueprintFeedbackFailure)
    end
end
local function parkProxy(g)
    local a=g.proxy;if not a or not a.lastPosition or not valid(a.pawn)then return end
    if g.aggression and g.aggression.prepare then
        local ok,err=pcall(g.aggression.prepare,g.aggression)
        if not ok then emit(g,'aggression pre-parking observation: '..tostring(err))end
    end
    -- Remove the perceived target before ResetAI, so the AI cannot immediately
    -- reacquire the same pawn at the destroyed drone's position.
    a.reactionStopped=true
    a.pawn:SetActorEnableCollision(false)
    local target={X=a.position.X,Y=a.position.Y,Z=a.position.Z-5000}
    a.pawn:K2_SetActorLocation(target,false,{},true);a.lastPosition=target
end
local function clearAggression(g)
    if g.aggression then
        local ok,success,err=pcall(g.aggression.restore,g.aggression)
        if not ok or success==false then emit(g,'aggression cleanup: '..tostring(ok and err or success))end
        g.aggression=nil
    end
end
local function restoreProxy(g)
    if g.buttstockGuard then g.buttstockGuard:restore()end
    local parked,parkError=pcall(parkProxy,g)
    if not parked then emit(g,'proxy parking: '..tostring(parkError))end
    -- Keep the native damage/effect shield while ResetAI runs. Restoration of
    -- the actual body happens only after its drone-acquired focus is cleared.
    clearAggression(g)
    clearHooks(g)
    local a=g.proxy;if not a then return end
    local errors={}
    local function restore(label,fn)
        local ok,err=pcall(fn)
        if not ok then errors[#errors+1]=label..': '..tostring(err) end
    end
    if valid(a.pawn) then
        -- Returning the body before enabling its original collision prevents an
        -- overlap at the drone location from affecting the returned character.
        restore('position',function() a.pawn:K2_SetActorLocation(a.position,false,{},true) end)
        if valid(a.capsule) then
            if a.collisionMode~=nil then restore('capsule collision',function() a.capsule:SetCollisionEnabled(a.collisionMode) end) end
        end
        restore('actor collision',function() a.pawn:SetActorEnableCollision(a.collision) end)
        restore('visibility',function() a.pawn:SetActorHiddenInGame(a.hidden) end)
        restore('damage shield',function() a.pawn.bCanBeDamaged=a.damage end)
    end
    g.proxy=nil;g.reactionReady=false
    assert(#errors==0,table.concat(errors,'; '))
end
local function setupProxy(s,g)
    local p=s.pawn
    assert(valid(p),'player unavailable')
    local a={pawn=p,position=copy(p:K2_GetActorLocation()),hidden=field(p,'bHidden'),
        damage=field(p,'bCanBeDamaged'),collision=p:GetActorEnableCollision()}
    assert(type(a.hidden)=='boolean' and type(a.damage)=='boolean' and type(a.collision)=='boolean',
        'player restoration state unavailable')
    -- Other guards may already own visibility. Preserve their entry snapshot.
    if s.playerVisibility and type(s.playerVisibility.pawnHidden)=='boolean' then a.hidden=s.playerVisibility.pawnHidden end
    g.proxy=a -- rollback owns every following operation, including partial setup
    g.aggression=M.aggression.start(s,here..'../',g.log)
    p.bCanBeDamaged=false
    p:SetActorHiddenInGame(true)
    local capsule=field(p,'CapsuleComponent')
    if valid(capsule) then
        a.capsule=capsule
        local gotRadius,radius=call(capsule,'GetUnscaledCapsuleRadius')
        local gotHeight,height=call(capsule,'GetUnscaledCapsuleHalfHeight')
        if gotRadius and gotHeight and finite(radius) and finite(height) and radius>0 and height>=radius then
            a.radius,a.halfHeight=radius,height
            -- Native AI still aims at the player's head/torso bones. Shrinking
            -- only the capsule to 20 cm leaves those aim points outside the
            -- receiving collision and makes real shots miss the proxy.
            g.hitbox='native receiving capsule'
        else g.hitbox='original player capsule' end
        local gotMode,mode=call(capsule,'GetCollisionEnabled')
        if gotMode and type(mode)=='number' then
            a.collisionMode=mode
            capsule:SetCollisionEnabled(1) -- QueryOnly: bullets/melee, no body physics
        end
    else g.hitbox='original player collision' end
    p:SetActorEnableCollision(true)
    local target=position(s)
    p:K2_SetActorLocation(target,false,{},true)
    a.lastPosition=target
    if g.aggression then g.aggression:activate()end
    g.reactionReady=true
    setupHooks(g,a)
    if g.directNativeReady then
        emit(g,'direct ActorCore interceptor armed; native attack payload amounts feed drone HP; body damage cancelled ('..g.hitbox..')')
    elseif g.feedbackReady then
        emit(g,'incoming observers registered: native='..tostring(g.nativeFeedbackReady)..' Blueprint='..tostring(g.blueprintFeedbackReady)..
            ' ('..g.hitbox..'); player shield active; direct C++ bridge unavailable: '..tostring(g.directNativeFailure))
        if not g.blueprintFeedbackReady then emit(g,'optional Blueprint hit observers unavailable; native observer remains active') end
    else emit(g,'incoming observers unavailable: '..tostring(g.feedbackFailure)..'; native bridge: '..tostring(g.directNativeFailure)..'; protected reaction only; no inferred attack damage') end
end
function M.start(s,opts,system,log)
    if s.combat then return s.combat end
    opts=opts or {}
    local g={enabled=not not (opts.droneHP or opts.reaction or opts.anomalyDamage),health=100,
        broken=false,reaction=not not opts.reaction,reactionReady=false,anomalyDamage=not not opts.anomalyDamage,
        time=0,hits=0,log=log,pendingHits={}}
    s.combat=g
    if g.reaction then g.buttstockGuard=M.buttstockGuard.new(s,system,log)end
    if g.reaction then
        local ok,err=pcall(setupProxy,s,g)
        if not ok then
            local restored,why=pcall(restoreProxy,g)
            g.failure=tostring(err)
            emit(g,'reaction unavailable: '..g.failure..(restored and '' or '; restoration: '..tostring(why)))
        end
    end
    return g
end
function M.damage(s,amount,reason)
    local g=s.combat
    if not g or not g.enabled or g.broken or not finite(amount) or amount<=0 then return 0 end
    local old=g.health
    g.health=math.max(0,g.health-amount)
    g.lastDamage=reason or 'damage'
    if g.health==0 then
        g.broken=true;emit(g,'destroyed by '..tostring(g.lastDamage))
        local parked,err=pcall(parkProxy,g)
        if not parked then emit(g,'destroyed proxy parking: '..tostring(err))end
        clearAggression(g)
    end
    return old-g.health
end
function M.impact(s,normalSpeed,normalZ,multiplier)
    local g=s.combat
    local safeSpeed=finite(normalZ) and normalZ>=0.55 and 5 or 3
    if not finite(multiplier) or multiplier<0 or multiplier>5 then multiplier=2 end
    if not g or not g.enabled or not finite(normalSpeed) or normalSpeed<=safeSpeed or multiplier==0 then return 0 end
    -- Count one impact rather than every substep against the same wall. Damage
    -- follows normal kinetic impact speed; glancing/tangential speed is ignored.
    if g.lastImpact and g.time-g.lastImpact<0.18 then return 0 end
    g.lastImpact=g.time
    -- Ground contacts tolerate an ordinary descent. The setting changes crash
    -- damage only; attacks and anomaly damage keep their own damage rules.
    return M.damage(s,math.min(100,(normalSpeed-safeSpeed)^2*0.09375*multiplier),'collision')
end
function M.update(s,opts,dt,now)
    local g=s.combat or M.start(s,opts,nil)
    opts=opts or {}
    g.enabled=not not (opts.droneHP or opts.reaction or opts.anomalyDamage)
    g.anomalyDamage=not not opts.anomalyDamage
    if finite(dt) and dt>0 then g.time=g.time+math.min(dt,0.1) end
    -- Reaction state changes require re-entry, so proxy ownership cannot be
    -- shared mid-flight with the existing underground streaming anchor.
    local a=g.proxy
    if not a or not g.reactionReady then return g end
    if not valid(a.pawn) or a.pawn~=s.pawn then
        local ok,err=pcall(restoreProxy,g)
        if not ok then emit(g,'proxy restore: '..tostring(err)) end
        g.failure='player changed';return g
    end
    a.pawn.bCanBeDamaged=false
    if not a.pawn.bHidden then a.pawn:SetActorHiddenInGame(true) end
    local collision=not a.reactionStopped
    if a.pawn:GetActorEnableCollision()~=collision then a.pawn:SetActorEnableCollision(collision) end
    local target=a.reactionStopped and {X=a.position.X,Y=a.position.Y,Z=a.position.Z-5000} or position(s)
    local old=a.lastPosition
    if not old or (target.X-old.X)^2+(target.Y-old.Y)^2+(target.Z-old.Z)^2>=5^2 then
        a.pawn:K2_SetActorLocation(target,false,{},true);a.lastPosition=target
    end
    if not finite(now) then now=g.time end
    if g.aggression then g.aggression:update(s,now)end
    if g.nativeReceiver and g.directNativeReady then
        local ok,delta,err=pcall(g.nativeReceiver.update,g.nativeReceiver,dt)
        if ok and delta then
            g.directNativeCalls=(g.directNativeCalls or 0)+delta.incoming
            g.nativeEvents=(g.nativeEvents or 0)+delta.hits
            g.feedbackEvents=(g.feedbackEvents or 0)+delta.hits
            if g.buttstockGuard then
                -- Dedicated counter survives a gunshot following melee in the
                -- same native poll. Older bridges retain source-only fallback.
                local count=delta.buttstockHits
                if count==nil and delta.source==12 then count=delta.hits end
                g.buttstockGuard:hit(count)
            end
            if not g.broken and delta.hits>0 then
                g.hits=g.hits+delta.hits
                M.damage(s,delta.amount,'incoming native attack')
                emit(g,'direct native attack observed; calls='..tostring(g.directNativeCalls)..' attacks='..tostring(g.nativeEvents)..
                    ' amount='..tostring(delta.amount)..' source='..tostring(delta.source)..' drone HP '..tostring(g.health))
            end
        elseif not ok or err then
            pcall(g.nativeReceiver.disarm,g.nativeReceiver)
            g.directNativeReady=false;g.feedbackReady=false;g.feedbackActive=false
            g.directNativeFailure=tostring(ok and err or delta)
            emit(g,'direct native receiver stopped: '..g.directNativeFailure..'; player shield active')
        end
    end
    -- Callbacks enqueue primitive data only. All drone mutation happens in the
    -- existing game-thread update, never inside a feedback callback.
    local pending=g.pendingHits;g.pendingHits={}
    if #pending>0 then
        for _,hit in ipairs(pending) do
            if hit.kind=='melee' and g.buttstockGuard then g.buttstockGuard:hit(1)end
            if g.broken then break end
            g.hits=g.hits+1
            M.damage(s,hit.amount or HIT_DAMAGE,hit.kind=='native' and 'incoming native damage' or ('Blueprint '..hit.kind..' hit'))
        end
        emit(g,'incoming hit observed; native='..tostring(g.nativeEvents or 0)..' events='..tostring(g.feedbackEvents)..
            ' merged='..tostring(g.feedbackMerged or 0)..' drone HP '..tostring(g.health))
    end
    if g.feedbackCallbackFailure and not g.feedbackCallbackReported then
        g.feedbackCallbackReported=true;emit(g,'hit callback identity read failed; player remains protected')
    end
    if g.buttstockGuard then g.buttstockGuard:update()end
    -- LastHitTimestampSeconds is native physics OnHit cooldown, not bullet or
    -- melee evidence. The shield, incoming hooks and independent Lua collision
    -- system own protection/damage; unrelated HP/stat changes are left alone.
    return g
end
function M.restore(s)
    local g=s.combat;if not g then return end
    if g.reaction then emit(g,'hit feedback summary: registered='..tostring(g.feedbackReady)..
        ' native='..tostring(g.nativeFeedbackReady)..' directNative='..tostring(g.directNativeReady)..
        ' directNativeCalls='..tostring(g.directNativeCalls or 0)..' nativeEvents='..tostring(g.nativeEvents or 0)..
        ' events='..tostring(g.feedbackEvents or 0)..' merged='..tostring(g.feedbackMerged or 0)..
        ' hits='..tostring(g.hits)..' HP='..tostring(g.health)) end
    local ok,err=pcall(restoreProxy,g)
    s.combat=nil
    assert(ok,err)
end
return M
