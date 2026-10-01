local guard=dofile('mod/Scripts/player_guard.lua')
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
function p:GetCurrentPsyPoints()return self.psy end
function p:SetCurrentPsyPoints(v)self.psy=v end
function p:GetBleeding()return self.bleed end
function p:ForceSetBleeding(v)self.bleed=v end
local s={pawn=p}
guard.update(s)
assert(p.rad==0 and p.env==0 and not p.steps and a.VolumeMultiplier==0 and c.percent==0 and not c.tick)
for _,name in ipairs({'radiation','environment','footsteps','audio','percent','tick'}) do assert(writes[name]==1) end
for _=1,100 do guard.update(s) end
for _,name in ipairs({'radiation','environment','footsteps','audio','percent','tick'}) do
 assert(writes[name]==1,'unchanged '..name..' must not repeat its setter')
end
print('PASS 100 stable updates avoid 600 redundant player-state setters')
p.psy=80;p.bleed=9;p.rad=50;p.env=60;p.steps=true;a.VolumeMultiplier=1;c.percent=.4;c.tick=true;guard.update(s)
assert(p.rad==0 and p.env==0 and not p.steps and a.VolumeMultiplier==0 and c.percent==0 and not c.tick and p.psy==17 and p.bleed==3)
local b=audio(2,.4);p.AudioGeiger=b;guard.update(s)
assert(a.VolumeMultiplier==.7 and not s.playerGuard.audio[1],'replaced audio must restore immediately')
p.psy=99;p.bleed=10
guard.restore(s)
assert(p.psy==17 and p.bleed==3)
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
