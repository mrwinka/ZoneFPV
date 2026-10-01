local telemetry=dofile('mod/Scripts/telemetry.lua')
local flight=dofile('mod/Scripts/flight.lua')
local guard=dofile('mod/Scripts/visual_guard.lua')
local s={origin={x=0,y=0,z=0},flight=flight.new({x=3,y=4,z=12},0),flightSeconds=75,throttle=.25}
s.flight.v={x=3,y=4,z=2}
local v=telemetry.sample(s,{speed_preset=4,camera_tilt=0},flight)
assert(math.abs(v.speed-math.sqrt(109)*3.6)<1e-6)
assert(v.altitude==12 and v.distance==13 and v.seconds==75 and v.throttle==25 and v.climb==3)
print('PASS actual world velocity, home-relative height and 3D distance')
local function obj(t) function t:IsValid()return true end;return t end
local m=obj({disabled=false})
function m:GetAddress()return 1 end
function m:IsDisabled()return self.disabled end
function m:DisableModifier()self.disabled=true end
function m:EnableModifier()self.disabled=false end
local cm=obj({bEnableColorScaling=true,ModifierList={ForEach=function(_,fn)fn(1,{get=function()return m end})end},
    StopAllCameraShakes=function()end,ClearCameraLensEffects=function()end,StopCameraFade=function()end})
local value=0
local sys={GetConsoleVariableIntValue=function()return value end,ExecuteConsoleCommand=function(_,_,cmd)value=tonumber(cmd:match('(%d+)$'))end}
s.pc={PlayerCameraManager=cm}
guard.update(s,0,sys);assert(m.disabled and not cm.bEnableColorScaling and value==1)
guard.restore(s);assert(not m.disabled and cm.bEnableColorScaling and value==0)
m.disabled=true;guard.update(s,1,sys);guard.restore(s);assert(m.disabled)
print('PASS visual effect suppression restores original settings including disabled modifiers')
local world=obj({});function world:GetAddress() return 20 end
local volume=obj({bEnabled=true,bUnbound=false,GetWorld=function() return world end,GetAddress=function() return 30 end})
local global=obj({bEnabled=true,bUnbound=true,GetFullName=function()return 'global grading' end,GetAddress=function()return 31 end})
FindAllOf=function() return {volume,global} end
s.world=world
local values={['r.PostProcessing.DisableMaterials']=0,['r.Fog']=1,['r.VolumetricFog']=0,['r.LocalFogVolume']=1}
local system={GetConsoleVariableIntValue=function(_,name) return values[name] end,
    ExecuteConsoleCommand=function(_,_,cmd) local name,v=cmd:match('^(%S+) (%d+)$');values[name]=tonumber(v) end}
guard.update(s,2,system,true,true)
assert(not volume.bEnabled and global.bEnabled)
assert(values['r.Fog']==0 and values['r.LocalFogVolume']==0)
values['r.PostProcessing.DisableMaterials']=0;volume.bEnabled=true
guard.update(s,2.5,system,true,true)
assert(values['r.PostProcessing.DisableMaterials']==1 and not volume.bEnabled,'regional reactivation must be suppressed')
guard.update(s,2.6,system,false,false)
assert(volume.bEnabled and values['r.Fog']==1 and values['r.VolumetricFog']==0 and values['r.LocalFogVolume']==1)
guard.restore(s);assert(values['r.PostProcessing.DisableMaterials']==0)
volume.bEnabled=false;guard.update(s,3,system,true,true);guard.restore(s)
assert(not volume.bEnabled,'originally disabled volume must stay disabled')
print('PASS regional effects and explicit Clear fog overrides restore prior state')
-- Accepted regional objects need no repeated reflected name lookups.
local nameReads=0
local anomaly=obj({bEnabled=true,bUnbound=true,GetWorld=function(self)return self.world or world end,GetAddress=function()return 40 end,
 GetFullName=function()nameReads=nameReads+1;return 'psy anomaly volume' end})
FindAllOf=function(name) if name=='PostProcessVolume' then return {anomaly,volume} end;return {} end
volume.bEnabled=true
guard.update(s,4,system,true,true)
assert(not anomaly.bEnabled and not volume.bEnabled and nameReads==1)
guard.update(s,7,system,true,true)
assert(nameReads==1,'known regional effects must reuse their accepted classification')
local foreign=obj({});function foreign:GetAddress()return 21 end
anomaly.world=foreign;guard.update(s,10,system,true,true)
assert(anomaly.bEnabled and not s.visualGuard.volumes[40],'a valid volume moved to another world must restore')
-- A detached modifier and a replaced camera manager each release their state.
cm.ModifierList={ForEach=function()end}
guard.update(s,10.5,system,true,true)
assert(m.disabled,'an originally disabled modifier must stay disabled when removed')
guard.restore(s)
m.disabled=false;cm.ModifierList={ForEach=function(_,fn)fn(1,{get=function()return m end})end}
guard.update(s,11,system,true,false);assert(m.disabled and not cm.bEnableColorScaling)
cm.ModifierList={ForEach=function()end};guard.update(s,11.5,system,true,false)
assert(not m.disabled,'a detached originally enabled modifier must restore immediately')
cm.ModifierList={ForEach=function(_,fn)fn(1,{get=function()return m end})end}
guard.update(s,12,system,true,false);assert(m.disabled)
local replacement=obj({bEnableColorScaling=true,ModifierList={ForEach=function()end},
 StopAllCameraShakes=function()end,ClearCameraLensEffects=function()end,StopCameraFade=function()end})
s.pc.PlayerCameraManager=replacement;guard.update(s,12.2,system,true,false)
assert(cm.bEnableColorScaling and not m.disabled and not replacement.bEnableColorScaling,'replacement camera manager must restore the old manager first')
guard.restore(s);assert(replacement.bEnableColorScaling)
-- Current-world changes release volume flags instead of hiding another world's objects.
s.pc.PlayerCameraManager=cm
volume.bEnabled=true;guard.update(s,13,system,true,true);assert(not volume.bEnabled)
s.world=foreign;guard.update(s,13.1,system,true,true)
assert(volume.bEnabled and not s.visualGuard.volumes[30])
guard.restore(s)
print('PASS cached visual discovery, detached effects and camera/world changes restore prior state')
