local guard=dofile('mod/Scripts/player_guard.lua')
guard.nativeGeiger=nil
local writes={}
local function wrote(name) writes[name]=(writes[name] or 0)+1 end
local function audio(id,volume)
 local a={VolumeMultiplier=volume}
 function a:IsValid()return not self.invalid end
 function a:GetAddress()return id end
 function a:SetVolumeMultiplier(v)wrote('audio');self.VolumeMultiplier=v end
 return a
end
local a=audio(1,.7)
local c={percent=.2,tick=true}
function c:IsValid()return true end
function c:GetAddress()return 3 end
function c:GetRadiationPercent()return self.percent end
function c:SetRadiationPercent(v)wrote('percent');self.percent=v end
function c:IsComponentTickEnabled()return self.tick end
function c:SetComponentTickEnabled(v)wrote('tick');self.tick=v end
local p={rad=12,env=2,steps=true,AudioGeiger=a,GeigerCounterComponent=c}
function p:GetRadiation()return self.rad end
function p:ForceSetRadiation(v)wrote('radiation');self.rad=v end
function p:GetCurrentEnvironmentRadiationValue()return self.env end
function p:SetCurrentEnvironmentRadiationValue(v)wrote('environment');self.env=v end
function p:AreFootstepsEnabled()return self.steps end
function p:SetFootstepsEnabled(v)wrote('footsteps');self.steps=v end
p.psy=17;p.bleed=3
p.sleep=60;p.poppy=420
function p:GetCurrentPsyPoints()return self.psy end
function p:SetCurrentPsyPoints(v)self.psy=v end
function p:GetBleeding()return self.bleed end
function p:ForceSetBleeding(v)self.bleed=v end
function p:GetCurrentSleepinessPoints()return self.sleep end
function p:SetCurrentSleepinessPoints(v)wrote('sleep');self.sleep=v end
function p:GetCurrentPoppyFieldSleepiness()return self.poppy end
function p:SetCurrentPoppyFieldSleepiness(v)wrote('poppy');self.poppy=v end
local s={pawn=p}
guard.update(s)
assert(p.rad==0 and p.env==0 and not p.steps and a.VolumeMultiplier==0 and c.percent==0 and not c.tick and p.sleep==0 and p.poppy==0)
for _,name in ipairs({'radiation','environment','footsteps','audio','percent','tick','sleep','poppy'}) do assert(writes[name]==1) end
for _=1,100 do guard.update(s) end
for _,name in ipairs({'radiation','environment','footsteps','audio','percent','tick','sleep','poppy'}) do
 assert(writes[name]==1,'unchanged '..name..' must not repeat its setter')
end
print('PASS 100 stable updates avoid 600 redundant player-state setters')
p.sleep=700;p.poppy=990;p.rad=44;p.env=55
guard.suppress(s)
assert(p.sleep==0 and p.poppy==0 and p.rad==0 and p.env==0,'frame path suppresses exposure and sleep between slower audio updates')
p.psy=80;p.bleed=9;p.rad=50;p.env=60;p.steps=true;a.VolumeMultiplier=1;c.percent=.4;c.tick=true;guard.update(s)
assert(p.rad==0 and p.env==0 and not p.steps and a.VolumeMultiplier==0 and c.percent==0 and not c.tick and p.psy==17 and p.bleed==3)
local b=audio(2,.4);p.AudioGeiger=b;guard.update(s)
assert(a.VolumeMultiplier==.7 and not s.playerGuard.audio[1],'replaced audio must restore immediately')
p.psy=99;p.bleed=10
guard.restore(s)
assert(p.psy==17 and p.bleed==3)
assert(p.sleep==60 and p.poppy==420,'nonzero preflight sleep values restore exactly')
assert(p.rad==12 and p.env==2 and p.steps and a.VolumeMultiplier==.7 and b.VolumeMultiplier==.4 and c.percent==.2 and c.tick)
guard.restore(s)
-- A failing optional sound setter must not strand exposure/footstep restoration.
p.rad=0;p.env=0;p.steps=false
guard.update(s)
function b:SetVolumeMultiplier()error('audio destroyed')end
guard.restore(s)
assert(p.rad==0 and p.env==0 and not p.steps and not s.playerGuard)
-- A transient getter failure must still allow the known setter to enforce FPV.
p.rad=9;guard.update(s)
local getRadiation=p.GetRadiation
p.GetRadiation=function()error('temporary getter failure')end
p.rad=10;guard.update(s);assert(p.rad==0)
p.GetRadiation=getRadiation;guard.restore(s);assert(p.rad==9)
-- Pawn replacement restores the captured pawn instead of applying its state to another.
p.rad=11;guard.update(s)
local other={rad=22,GetRadiation=p.GetRadiation,ForceSetRadiation=p.ForceSetRadiation}
s.pawn=other;guard.update(s)
assert(p.rad==11 and other.rad==0)
guard.restore(s);assert(other.rad==22)
print('PASS preflight radiation, replaced audio, tick and footsteps restore independently')
-- A reflected setter is guarded before execution; callbacks never inspect an
-- expired pawn after exit, including when UE4SS unregistration fails.
local oldRegister,oldUnregister=RegisterHook,UnregisterHook
local callbacks,removed={},0
RegisterHook=function(path,fn)
 assert(path=='/Script/Stalker2.Obj:SetCurrentSleepinessPoints' or path=='/Script/Stalker2.Obj:SetCurrentPoppyFieldSleepiness'
  or path=='/Script/Stalker2.Obj:ForceSetRadiation' or path=='/Script/Stalker2.Obj:SetCurrentEnvironmentRadiationValue')
 callbacks[path]=fn;return 10,11
end
UnregisterHook=function()removed=removed+1 end
function p:IsValid()return true end
function p:GetAddress()return 123 end
s.pawn=p;p.sleep=77;p.poppy=321
guard.update(s)
local param={value=999,get=function(self)return self.value end,set=function(self,v)self.value=v end}
local callback=callbacks['/Script/Stalker2.Obj:SetCurrentPoppyFieldSleepiness']
callback({get=function()return p end},param)
assert(param.value==0 and #s.playerGuard.hooks==4)
param.value=99;callbacks['/Script/Stalker2.Obj:ForceSetRadiation']({get=function()return p end},param);assert(param.value==0)
local foreign={IsValid=function()return true end,GetAddress=function()return 456 end}
param.value=888;callback({get=function()return foreign end},param);assert(param.value==888)
guard.restore(s)
assert(removed==4 and p.sleep==77 and p.poppy==321)
callback({get=function()error('expired context must not be read')end},param)
RegisterHook,UnregisterHook=oldRegister,oldUnregister
print('PASS native sleep setter suppression filters player and deactivates before restoration')
s.combat={reactionReady=true};p.bleed=3
guard.update(s);assert(p.bleed==0,'pre-existing bleeding cannot drain the protected receiving proxy')
p.bleed=8;guard.suppress(s);assert(p.bleed==0)
guard.restore(s);assert(p.bleed==3,'original bleeding restores only after returning the player')
s.combat=nil
print('PASS protected receiving proxy suppresses ongoing bleeding and restores its original value')
-- Real Geiger uses Wwise on PlayerEffectsSFXComponent, not AudioGeiger volume.
local actions={}
local geigerEvent={IsValid=function()return true end}
function geigerEvent:ExecuteAction(action,actor,playingId,transition,curve)
    assert(actor==p and playingId==0 and transition==0 and curve==4)
    actions[#actions+1]=action;return 1
end
c.SFXStartEvent=geigerEvent;p.AudioGeiger=nil
s.pawn=p;guard.update(s)
assert(#actions==1 and actions[1]==1 and not c.tick and s.playerGuard.geiger[3].wwisePaused)
for _=1,100 do guard.update(s) end
assert(#actions==1,'stable flight must not stack Wwise pause actions')
guard.restore(s)
assert(#actions==2 and actions[2]==2 and c.tick,'one scoped resume restores the existing player event')
guard.restore(s);assert(#actions==2)
c.SFXStartEvent=nil
print('PASS Wwise Geiger event is paused once on its owner and resumed once after exit, without global audio changes')
local gateArms,gateTicks,gateStops=0,0,0
guard.nativeGeiger={new=function()
 return {arm=function(_,component,pawn)assert(component==c and pawn==p);gateArms=gateArms+1;return true end,
 tick=function()gateTicks=gateTicks+1;return true end,disarm=function()gateStops=gateStops+1 end}
end}
c.SFXStartEvent=geigerEvent
guard.update(s);guard.suppress(s);guard.suppress(s);guard.update(s)
assert(gateArms==1 and gateTicks==2,'component-specific native gate renews each game frame, arms only once')
assert(#actions==2,'native stop must not add a Pause on an already stopped event')
guard.restore(s);assert(gateStops==1 and #actions==2,'native stop must not Resume a loop on exit')
c.SFXStartEvent=nil
guard.nativeGeiger=nil
print('PASS native Geiger gate lifecycle follows the owned component and restores on exit')
guard.nativeGeiger={new=function()
 return {arm=function()return true end,tick=function()return true end,
 poll=function()return false,'injected stop failure' end,disarm=function()end}
end}
c.SFXStartEvent=geigerEvent
guard.update(s);s.playerGuard.geiger[3].nextNativePoll=0
guard.update(s)
assert(not s.playerGuard.geiger[3].nativeReady and s.playerGuard.geiger[3].wwisePaused and actions[3]==1,
 'a late native stop failure must become visible and use the scoped audio fallback')
guard.restore(s);assert(actions[4]==2 and c.tick)
c.SFXStartEvent=nil;guard.nativeGeiger=nil
print('PASS late native Geiger failure is reported and falls back to the owned Wwise event')
