local combat=dofile('mod/Scripts/drone_combat.lua')
local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
local function fixture()
    local writes={}
    local function wrote(k) writes[k]=(writes[k] or 0)+1 end
    local capsule={radius=42,height=96,mode=3}
    function capsule:IsValid() return not self.invalid end
    function capsule:GetUnscaledCapsuleRadius() return self.radius end
    function capsule:GetUnscaledCapsuleHalfHeight() return self.height end
    function capsule:SetCapsuleSize(r,h,overlap) assert(overlap==false);wrote('size');self.radius,self.height=r,h end
    function capsule:GetCollisionEnabled() return self.mode end
    function capsule:SetCollisionEnabled(v) wrote('mode');self.mode=v end
    local pawn={p={X=10,Y=20,Z=30},hp=81,bHidden=false,bCanBeDamaged=true,collision=false,
        LastHitTimestampSeconds=10,CapsuleComponent=capsule}
    function pawn:IsValid() return not self.invalid end
    function pawn:GetAddress() return self end
    function pawn:K2_GetActorLocation() return self.p end
    function pawn:K2_SetActorLocation(p,sweep,hit,teleport)
        assert(not sweep and teleport);wrote('position')
        if self.failPosition then error('movement failed') end
        self.p={X=p.X,Y=p.Y,Z=p.Z}
    end
    function pawn:SetActorHiddenInGame(v) wrote('hidden');self.bHidden=v end
    function pawn:GetActorEnableCollision() return self.collision end
    function pawn:SetActorEnableCollision(v) wrote('collision');self.collision=v end
    function pawn:GetHP() return self.hp end
    function pawn:ForceSetHP(v) assert(v%1==0);wrote('hp');self.hp=v end
    local s={pawn=pawn,flight={p={x=1,y=2,z=3}}}
    local logs={}
    return s,pawn,capsule,writes,function(line) logs[#logs+1]=line end,logs
end
test('all experiments disabled leave Unreal actor untouched',function()
    local s,p,c,w=fixture()
    local g=combat.start(s,{})
    combat.update(s,{},.1,1)
    assert(not g.enabled and g.health==100 and not g.proxy and not next(w))
    assert(combat.impact(s,50)==0 and combat.damage(s,100,'test')==0)
    combat.restore(s);assert(not s.combat and not next(w))
end)
test('collision damage is based on normal speed with a small impact grace period',function()
    local s=fixture();local g=combat.start(s,{droneHP=true})
    for _,v in ipairs({0,1,2,3,0/0,math.huge,-2}) do assert(combat.impact(s,v)==0) end
    assert(combat.impact(s,6,0,2)==1.6875 and g.health==98.3125)
    assert(combat.impact(s,40,0,5)==0 and g.health==98.3125,'substeps must not count multiple impacts')
    combat.update(s,{droneHP=true},.1,1);combat.update(s,{droneHP=true},.1,2)
    assert(combat.impact(s,40,1,5)==98.3125 and g.broken and g.health==0)
    assert(combat.damage(s,99)==0)
end)

test('ordinary landing is safe and multiplier scales only collision damage',function()
    local s=fixture();local g=combat.start(s,{droneHP=true})
    assert(combat.impact(s,5,1)==0 and g.health==100)
    assert(combat.impact(s,40,1,0)==0 and not g.lastImpact)
    assert(combat.impact(s,6,1)==0.1875 and g.health==99.8125)
    combat.update(s,{droneHP=true},.1,1);combat.update(s,{droneHP=true},.1,2)
    assert(combat.impact(s,6,0,0.5)==0.421875 and g.health==99.390625)
    assert(combat.damage(s,10,'attack')==10 and g.health==89.390625)
end)
test('anomaly damage enables independent durability and rejects invalid values',function()
    local s=fixture();local g=combat.start(s,{anomalyDamage=true})
    assert(g.enabled and g.anomalyDamage)
    for _,v in ipairs({0,-1,0/0,math.huge}) do assert(combat.damage(s,v)==0) end
    assert(combat.damage(s,7.5,'anomaly')==7.5 and g.health==92.5)
    combat.update(s,{anomalyDamage=true},100,1);assert(g.time==.1)
    combat.update(s,{anomalyDamage=true},0,2);assert(g.time==.1)
end)
test('native reaction proxy shields player and restores position hitbox and flags',function()
    local s,p,c,w,log=fixture()
    local g=combat.start(s,{reaction=true},nil,log)
    assert(g.enabled and g.reactionReady and p.bHidden and not p.bCanBeDamaged and p.collision)
    assert(p.p.X==100 and p.p.Y==200 and p.p.Z==300 and c.radius==42 and c.height==96 and c.mode==1)
    assert(p.hp==81 and not w.hp,'no temporary maxHP/health changes are needed')
    p.bCanBeDamaged=true;p.bHidden=false;p.collision=false;s.flight.p.x=2
    combat.update(s,{reaction=true},.05,1)
    assert(not p.bCanBeDamaged and p.bHidden and p.collision and p.p.X==200)
    combat.restore(s)
    assert(not s.combat and p.p.X==10 and p.p.Y==20 and p.p.Z==30)
    assert(not p.bHidden and p.bCanBeDamaged and not p.collision and c.radius==42 and c.height==96 and c.mode==3)
    combat.restore(s)
end)
test('physics hit timestamps never invent incoming attack damage',function()
    local s,p=fixture();local g=combat.start(s,{reaction=true})
    for i,stamp in ipairs({10,11,11,0,1,2,3,1000})do
        p.LastHitTimestampSeconds=stamp
        combat.update(s,{reaction=true},.05,i*.1)
        assert(g.health==100 and g.hits==0 and not g.broken)
    end
    combat.restore(s);assert(p.hp==81)
end)
test('missing timestamp leaves player protected and reports unavailable feedback',function()
    local s,p,c,w,log,logs=fixture();p.LastHitTimestampSeconds=nil
    local g=combat.start(s,{reaction=true},nil,log)
    assert(g.enabled and g.reactionReady and g.proxy and not g.feedbackReady and g.feedbackFailure and #logs==1)
    assert(p.bHidden and not p.bCanBeDamaged and p.collision and c.radius==42)
    combat.update(s,{reaction=true},.05,1);assert(g.health==100 and g.hits==0)
    combat.restore(s);assert(not p.bHidden and p.bCanBeDamaged and not p.collision and c.radius==42)
end)
test('partial native setup rolls back independent actor and capsule state',function()
    local s,p,c,w=fixture()
    function p:K2_SetActorLocation(v,sweep,hit,teleport)
        if v.X==100 then error('only camera relocation fails') end
        self.p=v
    end
    local g=combat.start(s,{reaction=true})
    assert(not g.reactionReady and not g.proxy and g.failure)
    assert(not p.bHidden and p.bCanBeDamaged and not p.collision and c.radius==42 and c.mode==3)
end)
test('restoration failure does not strand damage collision or visibility state',function()
    local s,p,c=fixture();combat.start(s,{reaction=true});p.failPosition=true
    local ok,err=pcall(combat.restore,s)
    assert(not ok and err:find('position') and not s.combat)
    assert(p.bCanBeDamaged and not p.bHidden and not p.collision and c.radius==42 and c.mode==3)
end)
test('a changed pawn restores the original object without altering its replacement',function()
    local s,p,c=fixture();local g=combat.start(s,{reaction=true})
    local other={};s.pawn=other
    combat.update(s,{reaction=true},.1,1)
    assert(not g.proxy and not g.reactionReady and not next(other))
    assert(p.bCanBeDamaged and not p.bHidden and not p.collision and p.p.X==10)
end)
test('visibility guard original hidden state is respected on rollback',function()
    local s,p=fixture();p.bHidden=true;s.playerVisibility={pawnHidden=false}
    combat.start(s,{reaction=true});combat.restore(s);assert(not p.bHidden)
end)
test('unowned HP changes and fractional health are left to the game',function()
    local s,p,c,w=fixture();p.hp=81.25
    combat.start(s,{reaction=true});combat.update(s,{reaction=true},.05,1)
    assert(p.hp==81.25 and not w.hp)
    p.hp=77.75
    combat.update(s,{reaction=true},.05,1.1);assert(p.hp==77.75 and not w.hp)
    combat.restore(s);assert(p.hp==77.75 and not w.hp)
end)
test('hovering avoids redundant actor transforms while active hit checks stay bounded',function()
    local s,p,c,w=fixture();local g=combat.start(s,{reaction=true})
    local initial=w.position
    for i=1,100 do combat.update(s,{reaction=true},.001,i*.001) end
    assert(w.position==initial and g.hits==0)
    s.flight.p.x=1.01;combat.update(s,{reaction=true},.1,1);assert(w.position==initial)
    s.flight.p.x=1.1;combat.update(s,{reaction=true},.1,2);assert(w.position==initial+1)
    combat.restore(s)
end)
local function hookedFixture(failAt)
    local previousRegister,previousUnregister,previousClock=RegisterHook,UnregisterHook,os.clock
    local handlers,registered,removed={},{},{}
    local at=1
    os.clock=function() return at end
    RegisterHook=function(path,callback)
        assert(path=='/Script/Stalker2.Obj:ReceiveDamage' or path:match('^/Script/Stalker2%.Obj:OnReceive%a+Hit_BP$'))
        registered[#registered+1]=path
        if #registered==failAt then error('injected unavailable Blueprint event') end
        handlers[path]=callback
        return #registered*2,#registered*2+1
    end
    UnregisterHook=function(path,pre,post)
        assert(type(pre)=='number' and type(post)=='number')
        removed[#removed+1]=path;handlers[path]=nil
    end
    local s,p,c,w,log,logs=fixture()
    local function hit(kind,owner,t)
        at=t or at
        local path='/Script/Stalker2.Obj:OnReceive'..kind..'Hit_BP'
        assert(handlers[path],path)
        handlers[path]({get=function() return owner or p end})
    end
    local function finish()
        RegisterHook,UnregisterHook,os.clock=previousRegister,previousUnregister,previousClock
    end
    return s,p,registered,removed,hit,finish,handlers,logs,w,log
end
test('real bullet and mutant melee feedback affects drone only after update',function()
    local s,p,registered,removed,hit,finish,handlers,logs,w,log=hookedFixture()
    local g=combat.start(s,{reaction=true},nil,log)
    assert(g.feedbackReady and g.nativeFeedbackReady and #registered==5 and not p.bCanBeDamaged and p.hp==81)
    local transforms=w.position
    hit('BulletProjectile');hit('Melee',nil,1.03)
    assert(g.health==100 and g.hits==0 and #g.pendingHits==2 and w.position==transforms)
    combat.update(s,{reaction=true},.05,1.05)
    assert(g.health==50 and g.hits==2 and p.hp==81 and not p.bCanBeDamaged)
    combat.restore(s)
    assert(#removed==5 and not next(handlers) and p.bCanBeDamaged and p.hp==81)
    finish()
end)
test('feedback filters other characters and invalid contexts',function()
    local s,p,registered,removed,hit,finish=hookedFixture()
    local g=combat.start(s,{reaction=true})
    local other={IsValid=function()return true end,GetAddress=function(s)return s end}
    hit('Melee',other);hit('BulletProjectile',{IsValid=function()return false end})
    assert(#g.pendingHits==0 and not g.feedbackEvents)
    combat.update(s,{reaction=true},.05,1);assert(g.health==100)
    combat.restore(s);finish()
end)
test('nested bullet and projectile callbacks coalesce without losing consecutive shots',function()
    local s,p,registered,removed,hit,finish=hookedFixture()
    local g=combat.start(s,{reaction=true})
    hit('Projectile',nil,1);hit('BulletProjectile',nil,1.001)
    assert(#g.pendingHits==1 and g.pendingHits[1].kind=='bullet')
    hit('BulletProjectile',nil,1.002)
    assert(#g.pendingHits==2 and g.feedbackEvents==3 and g.feedbackMerged==1)
    p.LastHitTimestampSeconds=11
    combat.update(s,{reaction=true},.05,1.01)
    assert(g.hits==2 and g.health==50,'timestamp echo must not double count Blueprint damage')
    combat.update(s,{reaction=true},.05,1.06);assert(g.hits==2)
    combat.restore(s);finish()
end)
test('missing timestamp still supports protected Blueprint attacks',function()
    local s,p,registered,removed,hit,finish=hookedFixture();p.LastHitTimestampSeconds=nil
    local g=combat.start(s,{reaction=true})
    hit('Melee');combat.update(s,{reaction=true},.05,1)
    assert(g.feedbackReady and g.health==75 and g.hits==1 and not p.bCanBeDamaged and p.hp==81)
    combat.restore(s);finish()
end)
test('unavailable Blueprint hooks retain native incoming observer and player shield',function()
    local s,p,registered,removed,hit,finish,handlers=hookedFixture(3)
    local g=combat.start(s,{reaction=true})
    assert(g.feedbackReady and g.nativeFeedbackReady and not g.blueprintFeedbackReady and g.blueprintFeedbackFailure)
    assert(g.feedbackActive and #removed==0 and handlers['/Script/Stalker2.Obj:ReceiveDamage'])
    assert(not p.bCanBeDamaged and p.hp==81)
    combat.restore(s);assert(#removed==2 and not next(handlers));finish()
end)
test('native incoming damage is measured before zeroing HP armor and bleeding inputs',function()
    local s,p,registered,removed,hit,finish,handlers=hookedFixture(2)
    local g=combat.start(s,{reaction=true})
    assert(g.nativeFeedbackReady and not g.blueprintFeedbackReady and not p.bCanBeDamaged)
    local function param(v)return {get=function(self)return self.value end,set=function(self,wanted)self.value=wanted end,value=v}end
    local amount,armor,bleed,chance=param(17.5),param(6),param(9),param(.8)
    handlers['/Script/Stalker2.Obj:ReceiveDamage']({get=function()return p end},amount,param(1),armor,param(2),bleed,chance,param('head'))
    assert(amount.value==0 and armor.value==0 and bleed.value==0 and chance.value==0)
    assert(g.health==100 and g.nativeEvents==1 and #g.pendingHits==1 and g.pendingHits[1].amount==17.5)
    combat.update(s,{reaction=true},.05,1)
    assert(g.health==82.5 and g.hits==1 and p.hp==81 and not p.bCanBeDamaged)
    local other={IsValid=function()return true end,GetAddress=function(self)return self end}
    amount=param(40);armor=param(7);bleed=param(4);chance=param(.2)
    handlers['/Script/Stalker2.Obj:ReceiveDamage']({get=function()return other end},amount,param(1),armor,param(2),bleed,chance,param('head'))
    assert(amount.value==40 and armor.value==7 and bleed.value==4 and chance.value==.2 and g.nativeEvents==1)
    local callback=handlers['/Script/Stalker2.Obj:ReceiveDamage']
    combat.restore(s)
    callback({get=function()error('expired context must not be read')end})
    assert(p.hp==81 and p.bCanBeDamaged and #removed==1)
    finish()
end)
test('zero invalid and healing native amounts cannot invent drone damage',function()
    local s,p,registered,removed,hit,finish,handlers=hookedFixture(2)
    local g=combat.start(s,{reaction=true})
    local function param(v)return {get=function()return v end,set=function()end}end
    for _,v in ipairs({0,-5,0/0,math.huge})do
        handlers['/Script/Stalker2.Obj:ReceiveDamage']({get=function()return p end},param(v),param(1),param(0),param(0),param(0),param(0),param(''))
    end
    combat.update(s,{reaction=true},.05,1)
    assert(g.health==100 and g.hits==0 and #g.pendingHits==0 and p.hp==81)
    combat.restore(s);finish()
end)
test('native and Blueprint reports of one hit merge while successive native attempts remain distinct',function()
    local s,p,registered,removed,hit,finish,handlers=hookedFixture()
    local g=combat.start(s,{reaction=true})
    local function param(v)return {get=function()return v end,set=function()end}end
    local function native(v)
        handlers['/Script/Stalker2.Obj:ReceiveDamage']({get=function()return p end},param(v),param(1),param(0),param(0),param(0),param(0),param(''))
    end
    hit('Melee',nil,1);native(11);native(7)
    assert(#g.pendingHits==2 and g.feedbackMerged==1)
    combat.update(s,{reaction=true},.05,1)
    assert(g.health==82 and g.hits==2 and g.nativeEvents==2)
    combat.restore(s);finish()
end)
test('stale callback is inert after restore even if loader cannot unregister',function()
    local s,p,registered,removed,hit,finish,handlers=hookedFixture()
    local g=combat.start(s,{reaction=true})
    local callback=handlers['/Script/Stalker2.Obj:OnReceiveMeleeHit_BP']
    UnregisterHook=function() error('world teardown') end
    combat.restore(s)
    callback({get=function()error('expired context must never be read')end})
    assert(not g.feedbackActive and #g.pendingHits==0 and g.health==100 and p.bCanBeDamaged)
    finish()
end)
test('feedback queue is bounded and repeated callbacks cannot allocate without limit',function()
    local s,p,registered,removed,hit,finish=hookedFixture()
    local g=combat.start(s,{reaction=true})
    for i=1,1000 do hit('Melee',nil,1+i*.001) end
    assert(#g.pendingHits==32 and g.feedbackEvents==1000 and g.health==100)
    combat.update(s,{reaction=true},.05,2);assert(g.broken and g.health==0 and p.hp==81)
    combat.restore(s);finish()
end)
test('available health setters are never used to create an attack reserve',function()
    local s,p,c,w,log=fixture();p.hp=81.25;p.maximum=100
    function p:GetMaxHP()error('unowned stat getter must not be used')end
    function p:GetHP()error('combat must not read the native gameplay core')end
    function p:SetMaxHP()error('maximum health must never be replaced')end
    function p:ForceSetHP()error('unowned health must never be replaced')end
    local g=combat.start(s,{reaction=true},nil,log)
    for i=1,100 do combat.update(s,{reaction=true},.016,i*.016) end
    assert(g.reactionReady and not p.bCanBeDamaged and g.health==100 and not g.broken)
    assert(p.hp==81.25 and p.maximum==100)
    combat.restore(s)
    assert(p.hp==81.25 and p.maximum==100 and p.bCanBeDamaged)
end)

test('delayed stat normalization is not attack evidence on entry or in flight',function()
    local s,p=fixture();p.maximum=100
    function p:GetMaxHP()return self.maximum end
    function p:SetMaxHP(v)self.maximum=v end
    local g=combat.start(s,{reaction=true})
    assert(p.hp==81 and p.maximum==100 and not p.bCanBeDamaged)
    -- The game periodically replaces effective maxHP and rescales HP, without
    -- an incoming attack callback. v5 misread its artificial reserve reset.
    p.maximum=90;p.hp=72.9
    combat.update(s,{reaction=true},.4,1)
    assert(g.health==100 and g.hits==0 and not g.broken and not p.bCanBeDamaged)
    p.maximum=100;p.hp=81
    combat.update(s,{reaction=true},.016,1.016)
    assert(g.health==100 and g.hits==0 and not g.broken)
    combat.restore(s);assert(p.hp==81 and p.maximum==100)
end)

test('verified native damage still counts while unrelated HP changes do not',function()
    local s,p,registered,removed,hit,finish,handlers=hookedFixture()
    p.maximum=100
    function p:GetMaxHP()return self.maximum end
    function p:SetMaxHP(v)self.maximum=v end
    local g=combat.start(s,{reaction=true})
    local function param(v)return {get=function()return v end,set=function()end}end
    handlers['/Script/Stalker2.Obj:ReceiveDamage']({get=function()return p end},param(11),param(1),param(0),param(0),param(0),param(0),param(''))
    p.hp=p.hp-7
    combat.update(s,{reaction=true},.016,1)
    assert(g.health==89 and g.hits==1 and p.hp==74 and not p.bCanBeDamaged)
    combat.restore(s);assert(p.maximum==100 and p.hp==74);finish()
end)

test('destroyed drone stops counting hits but its falling proxy remains protected',function()
    local s,p,registered,removed,hit,finish,handlers=hookedFixture()
    local g=combat.start(s,{reaction=true})
    for i=1,10 do hit('Melee',nil,i) end
    combat.update(s,{reaction=true},.016,10)
    assert(g.broken and g.health==0 and g.hits==4 and #g.pendingHits==0)
    for i=11,20 do hit('Melee',nil,i) end
    assert(#g.pendingHits==0)
    combat.update(s,{reaction=true},.016,20)
    assert(g.hits==4 and g.health==0 and not p.bCanBeDamaged)
    local value=99
    local function param()return {get=function()return value end,set=function(_,v)value=v end}end
    handlers['/Script/Stalker2.Obj:ReceiveDamage']({get=function()return p end},param(),param(),param(),param(),param(),param(),param())
    assert(value==0 and #g.pendingHits==0,'broken-state hooks must still shield the body')
    combat.restore(s);assert(p.bCanBeDamaged);finish()
end)
test('direct native receive bridge is authoritative and reports actual amounts without reflected duplicates',function()
    local saved=combat.nativeBridge
    local s,p,c,w,log,logs=fixture()
    local calls={arm=0,tick=0,disarm=0}
    local nextDelta
    combat.nativeBridge={new=function()
        return {arm=function(_,pawn)assert(pawn==p);calls.arm=calls.arm+1;return true end,
            update=function()calls.tick=calls.tick+1;local d=nextDelta;nextDelta=nil;return d end,
            disarm=function()calls.disarm=calls.disarm+1;assert(not p.bCanBeDamaged,'disarm must precede restoration');return true end}
    end}
    local g=combat.start(s,{reaction=true},nil,log)
    assert(g.directNativeReady and g.feedbackReady and calls.arm==1 and #g.hooks==0)
    assert(not p.bCanBeDamaged and p.hp==81)
    nextDelta={incoming=3,hits=2,amount=28.5,source=5}
    combat.update(s,{reaction=true},.1,1)
    assert(g.health==71.5 and g.hits==2 and g.nativeEvents==2 and g.directNativeCalls==3 and p.hp==81)
    p.hp=70;p.LastHitTimestampSeconds=55
    nextDelta={incoming=7,hits=0,amount=0,source=21}
    combat.update(s,{reaction=true},.1,2)
    assert(g.health==71.5 and g.hits==2 and g.directNativeCalls==10 and p.hp==70)
    nextDelta={incoming=1,hits=1,amount=80,source=2}
    combat.update(s,{reaction=true},.1,3)
    assert(g.broken and g.health==0 and not p.bCanBeDamaged)
    combat.update(s,{reaction=true},.1,4)
    assert(calls.tick==4,'broken drone keeps native body shield leased until exit')
    combat.restore(s);assert(calls.disarm==1 and p.bCanBeDamaged and not s.combat)
    combat.nativeBridge=saved
end)
test('direct native identity failure disarms before retaining the player flag shield',function()
    local saved=combat.nativeBridge
    local s,p=fixture();local disarmed=0
    combat.nativeBridge={new=function()
        return {arm=function()return true end,update=function()return nil,'native receiver changed' end,
            disarm=function()disarmed=disarmed+1;return true end}
    end}
    local g=combat.start(s,{reaction=true})
    combat.update(s,{reaction=true},.1,1)
    assert(disarmed==1 and not g.directNativeReady and not g.feedbackReady and not p.bCanBeDamaged and g.health==100)
    combat.restore(s);assert(disarmed==2 and p.bCanBeDamaged)
    combat.nativeBridge=saved
end)
test('buttstock evidence survives a later bullet and schedules guard independently of drone HP',function()
    local savedNative,savedGuard=combat.nativeBridge,combat.buttstockGuard
    local s=fixture();local nextDelta;local hits,updates,restores=0,0,0
    combat.nativeBridge={new=function()return {
        arm=function()return true end,disarm=function()return true end,
        update=function()local d=nextDelta;nextDelta=nil;return d end,
    }end}
    combat.buttstockGuard={new=function()return {
        hit=function(_,n)hits=hits+(n or 0)end,update=function()updates=updates+1 end,
        restore=function()restores=restores+1 end,
    }end}
    local g=combat.start(s,{reaction=true})
    nextDelta={incoming=2,hits=2,amount=30,source=2,buttstockHits=1}
    combat.update(s,{reaction=true},.1,1)
    assert(hits==1 and updates==1 and g.health==70 and g.hits==2)
    nextDelta={incoming=1,hits=1,amount=25,source=12,buttstockHits=0}
    combat.update(s,{reaction=true},.1,2);assert(hits==1,'extended counter overrides latest-source fallback')
    nextDelta={incoming=1,hits=1,amount=25,source=12}
    combat.update(s,{reaction=true},.1,3);assert(hits==2,'old native report supports exact source fallback')
    combat.restore(s);assert(restores==1)
    combat.nativeBridge,combat.buttstockGuard=savedNative,savedGuard
end)
test('actual buttstock guard dispatches through reflected Pawn after native combat update',function()
    local savedNative,savedFind=combat.nativeBridge,StaticFindObject
    local s,p=fixture();local commands,logs={},{};local nextDelta
    s.pc=setmetatable({Pawn=p,IsValid=function()return true end},{__index=function(_,key)
        if key=='GetPawn'then error('GetPawn unavailable in installed reflected API')end
    end})
    local system={IsValid=function()return true end}
    function system:ExecuteConsoleCommand(pc,command,owner)
        assert(pc==s.pc and owner==s.pc);commands[#commands+1]=command
    end
    StaticFindObject=function(path)
        assert(path=='/Script/Stalker2.CustomConsoleManagerMH:XRemoveEffectFromPlayer')
        return {IsValid=function()return true end}
    end
    combat.nativeBridge={new=function()return {
        arm=function()return true end,disarm=function()return true end,
        update=function()local d=nextDelta;nextDelta=nil;return d end,
    }end}
    local g=combat.start(s,{reaction=true},system,function(line)logs[#logs+1]=line end)
    nextDelta={incoming=2,hits=2,amount=30,source=2,buttstockHits=1}
    combat.update(s,{reaction=true},.1,1)
    assert(#commands==10 and g.health==70,'real guard must dispatch with native mixed-source evidence')
    combat.update(s,{reaction=true},.016,1.016);assert(#commands==20)
    assert(logs[#logs]:find('buttstock removal dispatched'))
    combat.restore(s);assert(#commands==20 and p.bCanBeDamaged)
    combat.nativeBridge,StaticFindObject=savedNative,savedFind
end)
test('drone destruction parks the protected body before clearing its acquired AI focus',function()
    local previousAggression,previousNative=combat.aggression,combat.nativeBridge
    local s,p=fixture();local clears,disarms,prepared=0,0,false
    combat.aggression={start=function(session)
        assert(session==s and p.p.X==10,'snapshot must precede proxy relocation')
        return {activate=function()assert(p.p.X==100)end,update=function()end,
            prepare=function()
                assert(p.p.X==100 and p.collision,'acquisition must be observed before parking erases focus')
                prepared=true
            end,
            restore=function()
                assert(prepared)
                assert(not p.collision and p.bHidden and not p.bCanBeDamaged)
                assert(p.p.X==10 and p.p.Y==20 and p.p.Z==30-5000,'clear must follow immediate parking')
                assert(disarms==0,'native effects shield must remain armed during AI cleanup')
                clears=clears+1;return true
            end}
    end}
    combat.nativeBridge={new=function()
        return {arm=function()return true end,update=function()return nil end,
            disarm=function()disarms=disarms+1;return true end}
    end}
    local g=combat.start(s,{reaction=true});combat.damage(s,100,'test')
    assert(g.broken and clears==1 and disarms==0 and g.proxy.reactionStopped and p.p.Z==30-5000)
    combat.update(s,{reaction=true},.016,1);assert(clears==1 and not p.collision and not p.bCanBeDamaged)
    combat.restore(s);assert(clears==1 and disarms==1 and p.p.Z==30 and p.bCanBeDamaged)
    combat.aggression,combat.nativeBridge=previousAggression,previousNative
end)
test('normal exit clears AI focus before native disarm and returns exact original body state',function()
    local previousAggression,previousNative=combat.aggression,combat.nativeBridge
    local s,p=fixture();local order={}
    combat.aggression={start=function()
        return {activate=function()end,update=function()end,restore=function()
            assert(not p.collision and p.p.Z==30-5000 and not p.bCanBeDamaged)
            order[#order+1]='clear';return true
        end}
    end}
    combat.nativeBridge={new=function()
        return {arm=function()return true end,update=function()return nil end,disarm=function()
            assert(order[1]=='clear' and p.p.Z==30-5000 and not p.bCanBeDamaged)
            order[#order+1]='disarm';return true
        end}
    end}
    combat.start(s,{reaction=true});combat.restore(s)
    assert(#order==2 and p.p.X==10 and p.p.Y==20 and p.p.Z==30 and p.bCanBeDamaged and not p.bHidden and not p.collision)
    combat.aggression,combat.nativeBridge=previousAggression,previousNative
end)
test('failed AI cleanup does not skip shield disarm or body restoration',function()
    local previousAggression,previousNative=combat.aggression,combat.nativeBridge
    local s,p=fixture();local disarms=0
    combat.aggression={start=function()
        return {activate=function()end,restore=function()error('AI cleanup unavailable')end}
    end}
    combat.nativeBridge={new=function()
        return {arm=function()return true end,disarm=function()disarms=disarms+1;return true end}
    end}
    combat.start(s,{reaction=true});combat.restore(s)
    assert(disarms==1 and p.p.Z==30 and p.bCanBeDamaged and not p.bHidden)
    combat.aggression,combat.nativeBridge=previousAggression,previousNative
end)
print('PASS '..count..' drone combat tests')
