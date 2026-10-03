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
local initialCommands=0
local sys={GetConsoleVariableIntValue=function()error('unselected weather must not read cvars')end,
    ExecuteConsoleCommand=function()initialCommands=initialCommands+1 end}
s.pc={PlayerCameraManager=cm}
guard.update(s,0,sys);assert(m.disabled and not cm.bEnableColorScaling and initialCommands==0)
guard.restore(s);assert(not m.disabled and cm.bEnableColorScaling and initialCommands==0)
m.disabled=true;guard.update(s,1,sys);guard.restore(s);assert(m.disabled)
print('PASS visual effect suppression restores original settings including disabled modifiers')
local world=obj({});function world:GetAddress() return 20 end
local volume=obj({bEnabled=true,bUnbound=false})
local component=obj({bEnabled=true,bUnbound=false})
local global=obj({bEnabled=true,bUnbound=true})
local scans=0
FindAllOf=function()scans=scans+1;error('weather post-processing must not be scanned')end
s.world=world
local values={['r.PostProcessing.DisableMaterials']=0,['r.Fog']=1,['r.VolumetricFog']=0,['r.LocalFogVolume']=1}
local reads,commands={},{}
local fog={['r.Fog']=true,['r.VolumetricFog']=true,['r.LocalFogVolume']=true}
local system={GetConsoleVariableIntValue=function(_,name)
    reads[name]=(reads[name] or 0)+1;assert(fog[name],'only explicit fog cvars may be read');return values[name]
end,ExecuteConsoleCommand=function(_,_,cmd)
    local name,v=cmd:match('^(%S+) (%d+)$');assert(fog[name],'weather materials must not be overridden')
    commands[#commands+1]=cmd;values[name]=tonumber(v)
end}
guard.update(s,2,system,true,false)
assert(next(reads)==nil and #commands==0 and values['r.Fog']==1,'entry without Clear preserves weather fog')
assert(volume.bEnabled and component.bEnabled and global.bEnabled and scans==0)
guard.update(s,2.1,system,true,true)
assert(values['r.Fog']==0 and values['r.VolumetricFog']==0 and values['r.LocalFogVolume']==0)
local applied=#commands
guard.update(s,2.4,system,true,true);assert(#commands==applied,'unchanged fog values need no command')
values['r.Fog']=2;values['r.PostProcessing.DisableMaterials']=3;volume.bEnabled=false
guard.update(s,2.7,system,true,true)
assert(values['r.Fog']==0 and values['r.PostProcessing.DisableMaterials']==3 and not volume.bEnabled)
guard.update(s,2.8,system,false,false)
assert(values['r.Fog']==1 and values['r.VolumetricFog']==0 and values['r.LocalFogVolume']==1)
guard.restore(s)
assert(values['r.PostProcessing.DisableMaterials']==3 and not volume.bEnabled and component.bEnabled and global.bEnabled)
assert(reads['r.PostProcessing.DisableMaterials']==nil and scans==0,'weather post-processing remains untouched')
guard.update(s,3,system,true,true);guard.restore(s)
assert(values['r.Fog']==1 and values['r.VolumetricFog']==0 and values['r.LocalFogVolume']==1,'exit restores exact fog values')
print('PASS weather post-processing untouched, no world scans and explicit Clear fog restores exact values')
local foreign=obj({});function foreign:GetAddress()return 21 end
-- A detached modifier and a replaced camera manager each release their state.
guard.update(s,10,system,true,true)
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
-- A world/controller change releases the old fog and camera state first.
s.pc.PlayerCameraManager=cm
guard.update(s,13,system,true,true);assert(values['r.Fog']==0 and m.disabled)
s.world=foreign;guard.update(s,13.1,system,true,false)
assert(values['r.Fog']==1 and s.visualGuard.world==foreign and s.visualGuard.cvars['r.Fog']==nil)
local otherCm=obj({bEnableColorScaling=true,ModifierList={ForEach=function()end},
    StopAllCameraShakes=function()end,ClearCameraLensEffects=function()end,StopCameraFade=function()end})
s.pc={PlayerCameraManager=otherCm};guard.update(s,13.2,system,true,false)
assert(not m.disabled and cm.bEnableColorScaling and not otherCm.bEnableColorScaling,'controller replacement restores old camera state')
guard.restore(s)
assert(otherCm.bEnableColorScaling and scans==0 and values['r.PostProcessing.DisableMaterials']==3)
print('PASS detached effects and camera/controller/world changes restore prior state')
