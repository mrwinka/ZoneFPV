local telemetry=dofile('mod/Scripts/telemetry.lua')
local flight=dofile('mod/Scripts/flight.lua')
local guard=dofile('mod/Scripts/visual_guard.lua')
guard.nativeBridge=nil -- Production DLL has a game-only binary profile.
local s={origin={x=0,y=0,z=0},flight=flight.new({x=3,y=4,z=12},0),flightSeconds=75,throttle=.25}
s.flight.v={x=3,y=4,z=2}
local v=telemetry.sample(s,{speed_preset=4,camera_tilt=0},flight)
assert(math.abs(v.speed-math.sqrt(109)*3.6)<1e-6)
assert(v.altitude==12 and v.distance==13 and v.seconds==75 and v.throttle==25 and v.climb==3)
print('PASS actual world velocity, home-relative height and 3D distance')
s.cameraDown=true
local down=telemetry.sample(s,{speed_preset=4,camera_tilt=25},flight)
assert(down.cameraDown and not v.cameraDown and math.abs(down.pitch+90)<1e-8 and down.roll==0 and down.speed==v.speed and down.altitude==v.altitude)
local levelBody=s.flight.q
s.flight.q=flight.mul(flight.axis(0,0,1,.71),flight.mul(flight.axis(1,0,0,.6),flight.axis(0,1,0,.4)))
local banked=telemetry.sample(s,{speed_preset=4,camera_tilt=25},flight)
local actualView=flight.camera_rotation(s.flight,25,true)
assert(math.abs(banked.pitch-actualView.Pitch)<1e-8 and math.abs(banked.roll-actualView.Roll)<1e-8 and
    math.abs(banked.heading-(actualView.Yaw+360)%360)<1e-8 and banked.speed==v.speed and banked.altitude==v.altitude,
    'OSD must use the body-mounted camera pose while physical flight telemetry remains unchanged')
s.flight.q=levelBody
s.cameraDown=false
print('PASS camera-down telemetry reports actual view while preserving flight speed/altitude')
do
    local cfg={speed_preset=4,camera_tilt=25}
    s.weapons={mode=2,remaining=3}
    local ammo=telemetry.sample(s,cfg,flight);assert(ammo.grenadeEnabled and ammo.grenadeRemaining==3)
    s.weapons.remaining=0;ammo=telemetry.sample(s,cfg,flight);assert(ammo.grenadeEnabled and ammo.grenadeRemaining==0)
    s.weapons.remaining=math.huge;ammo=telemetry.sample(s,cfg,flight);assert(ammo.grenadeEnabled and ammo.grenadeRemaining==-1)
    for _,remaining in ipairs({3,0,math.huge})do
        s.weapons={mode=3,remaining=remaining};ammo=telemetry.sample(s,cfg,flight)
        assert(ammo.grenadeEnabled and ammo.grenadeRemaining==(remaining==math.huge and -1 or remaining),'combined mode retains count/empty/unlimited OSD')
    end
    s.weapons.mode=1;ammo=telemetry.sample(s,cfg,flight);assert(not ammo.grenadeEnabled and ammo.grenadeRemaining==0)
    for _,remaining in ipairs({-1,21,1.5,0/0})do
        s.weapons={mode=2,remaining=remaining};ammo=telemetry.sample(s,cfg,flight);assert(not ammo.grenadeEnabled)
    end
    local rawOpen=io.open
    local packets={}
    io.open=function(path,mode)
        assert(path=='ammo-fixture/telemetry.txt' and mode=='w')
        return {write=function(_,line)packets[#packets+1]=line;return true end,close=function()return true end}
    end
    local publish=telemetry.new('ammo-fixture/',flight,cfg)
    s.weapons={mode=2,remaining=3};publish(0,s)
    s.weapons.remaining=2;publish(.001,s);publish(.002,s);assert(#packets==2,'A changed count publishes immediately; unchanged count keeps the50ms gate')
    s.weapons.remaining=0;publish(.003,s)
    s.weapons.remaining=math.huge;publish(.004,s)
    s.weapons.mode=0;publish(.005,s)
    publish(.006,nil)
    io.open=rawOpen
    local function fields(line)local result={};for token in line:gmatch('%S+')do result[#result+1]=tonumber(token)end;return result end
    local counts={3,2,0,-1,0,0}
    for index,line in ipairs(packets)do
        local packet=fields(line)
        assert(#packet==26 and packet[1]==5 and packet[2]==index and packet[26]==index and packet[25]==0)
        assert(packet[23]==(index<=4 and 1 or 0)and packet[24]==counts[index])
        assert(packet[3]==(index<6 and 1 or 0))
    end
    if arg and arg[1]then local fixture=assert(rawOpen(arg[1],'w'));assert(fixture:write(packets[3]));fixture:close()end
    s.weapons=nil
    print('PASS live grenade count, zero and unlimited telemetry;26-fieldv5 framing, immediate ammo updates, idle clearing and actual packet fixture')
    local viewPackets={}
    io.open=function()return {write=function(_,line)viewPackets[#viewPackets+1]=fields(line);return true end,close=function()return true end}end
    publish=telemetry.new('view-fixture/',flight,cfg)
    publish(0,s);s.cameraDown=true;publish(.001,s);publish(.002,s)
    s.cameraDown=false;publish(.003,s);io.open=rawOpen
    assert(#viewPackets==3 and viewPackets[1][25]==0 and viewPackets[2][25]==1 and viewPackets[3][25]==0,
        'camera selection publishes immediately without waiting for the50ms gate')
end
local function obj(t)
 function t:IsValid()return not self.invalid end
 function t:GetAddress()return self end
 return t
end
local function array(...)
 local values={...}
 values.GetArrayNum=function(self)return #self end
 values.ForEach=function()error('ForEach must never be used')end
 return values
end
local m=obj({disabled=false,Alpha=.35})
function m:IsDisabled()return self.disabled end
function m:DisableModifier(immediate)assert(immediate);self.disabled=true;self.Alpha=0 end
function m:EnableModifier()self.disabled=false end
local shakes,fades=0,0
local cm=obj({bEnableColorScaling=true,ModifierList=array(m),
 StopAllCameraShakes=function(_,immediate)assert(immediate);shakes=shakes+1 end,
 ClearCameraLensEffects=function()error('camera lens/weather particles must not be destroyed')end,
 StopCameraFade=function()fades=fades+1 end})
m.CameraOwner=cm
local reads,commands,scans=0,0,0
local sys={GetConsoleVariableIntValue=function()reads=reads+1;error('weather cvars must not be read')end,
 ExecuteConsoleCommand=function()commands=commands+1;error('weather cvars must not be changed')end}
FindAllOf=function()scans=scans+1;error('world effects must not be scanned')end
s.pc={PlayerCameraManager=cm}
guard.update(s,0,sys)
assert(m.disabled and not cm.bEnableColorScaling)
for i=1,120 do
 m.disabled=false
 guard.update(s,i/120,sys,true,false)
 assert(m.disabled,'camera modifiers must be suppressed every update without .5 sec gaps')
end
assert(shakes==121 and fades==121,'fade/shake fallback must have no .1 sec gaps')
assert(reads==0 and commands==0 and scans==0,'normal weather stays under its original ownership')
guard.restore(s)
assert(not m.disabled and m.Alpha==.35 and cm.bEnableColorScaling)
m.disabled=true;guard.update(s,2,sys);guard.restore(s);assert(m.disabled)
print('PASS every-frame camera feedback suppression preserves modifier/alpha state and world weather')
local world=obj({});local foreign=obj({})
s.world=world
-- A detached modifier and replaced camera each release their captured state.
guard.update(s,10,sys,true,false)
cm.ModifierList=array();guard.update(s,10.01,sys,true,false)
assert(m.disabled,'an originally disabled modifier stays disabled when detached')
guard.restore(s)
m.disabled=false;m.Alpha=.6;cm.ModifierList=array(m)
guard.update(s,11,sys,true,false);assert(m.disabled and not cm.bEnableColorScaling)
cm.ModifierList=array();guard.update(s,11.01,sys,true,false)
assert(not m.disabled and m.Alpha==.6,'detached modifier restores without waiting .5 sec')
cm.ModifierList=array(m);guard.update(s,12,sys,true,false);assert(m.disabled)
local replacement=obj({bEnableColorScaling=true,ModifierList=array(),
 StopAllCameraShakes=function()end,StopCameraFade=function()end})
s.pc.PlayerCameraManager=replacement;guard.update(s,12.01,sys,true,false)
assert(cm.bEnableColorScaling and not m.disabled and not replacement.bEnableColorScaling)
guard.restore(s);assert(replacement.bEnableColorScaling)
s.pc.PlayerCameraManager=cm
guard.update(s,13,sys,true,false);assert(m.disabled)
s.world=foreign;guard.update(s,13.01,sys,true,false)
assert(s.visualGuard.world==foreign and m.disabled)
s.pc={PlayerCameraManager=replacement};guard.update(s,13.02,sys,true,false)
assert(not m.disabled and cm.bEnableColorScaling and not replacement.bEnableColorScaling)
guard.restore(s)
assert(replacement.bEnableColorScaling and reads==0 and commands==0 and scans==0)
print('PASS detached effects and camera/controller/world changes restore prior state')
-- The existing explicit Clear selection may suppress only fog cvars, with
-- exact restoration on preset changes, world changes and FPV exit.
local values={['r.Fog']=1,['r.VolumetricFog']=0,['r.LocalFogVolume']=2,['r.PostProcessing.DisableMaterials']=3}
local fogReads,fogCommands={},{}
local fog={['r.Fog']=true,['r.VolumetricFog']=true,['r.LocalFogVolume']=true}
local weatherSystem={GetConsoleVariableIntValue=function(_,name)
 assert(fog[name]);fogReads[name]=(fogReads[name] or 0)+1;return values[name]
end,ExecuteConsoleCommand=function(_,_,command)
 local name,value=command:match('^(%S+) (%d+)$');assert(fog[name]);values[name]=tonumber(value);fogCommands[#fogCommands+1]=command
end}
s.pc={PlayerCameraManager=cm};cm.ModifierList=array(m)
guard.update(s,14,weatherSystem,true,false);assert(next(fogReads)==nil and #fogCommands==0)
guard.update(s,14.1,weatherSystem,true,true)
assert(values['r.Fog']==0 and values['r.VolumetricFog']==0 and values['r.LocalFogVolume']==0)
local applied=#fogCommands
guard.update(s,14.4,weatherSystem,true,true);assert(#fogCommands==applied)
values['r.Fog']=2;guard.update(s,14.7,weatherSystem,true,true);assert(values['r.Fog']==0)
guard.update(s,14.8,weatherSystem,true,false)
assert(values['r.Fog']==1 and values['r.VolumetricFog']==0 and values['r.LocalFogVolume']==2)
guard.restore(s)
guard.update(s,15,weatherSystem,true,true);guard.restore(s)
assert(values['r.Fog']==1 and values['r.VolumetricFog']==0 and values['r.LocalFogVolume']==2 and values['r.PostProcessing.DisableMaterials']==3)
assert(fogReads['r.PostProcessing.DisableMaterials']==nil and scans==0)
guard.update(s,16,weatherSystem,true,true);s.world=world;guard.update(s,16.01,weatherSystem,true,false)
assert(values['r.Fog']==1 and values['r.LocalFogVolume']==2 and not next(s.visualGuard.cvars))
guard.restore(s)
print('PASS explicit Clear suppresses only fog and restores its exact values independently of player effects')
-- Fixed native incoming hooks act only on the current local camera.
local oldRegister,oldUnregister=RegisterHook,UnregisterHook
local handlers,removed={},0
RegisterHook=function(path,pre,post)
 handlers[path]={pre=pre,post=post};return 4,5
end
UnregisterHook=function(path)removed=removed+1;handlers[path]=nil end
s.pc={PlayerCameraManager=cm};cm.ModifierList=array(m);m.disabled=false;m.Alpha=.9
guard.update(s,20,sys)
local function param(value)
 return {value=value,get=function(self)return self.value end,set=function(self,v)self.value=v end}
end
local function context(object)return {get=function()return object end}end
local from,to,duration,audio,hold=param(.3),param(1),param(2),param(true),param(true)
local fade=handlers['/Script/Engine.PlayerCameraManager:StartCameraFade'].pre
fade(context(cm),from,to,duration,param({}),audio,hold)
assert(from.value==0 and to.value==0 and duration.value==0 and not audio.value and not hold.value)
to.value=1;fade(context(replacement),from,to,duration,param({}),audio,hold);assert(to.value==1)
local manual=handlers['/Script/Engine.PlayerCameraManager:SetManualCameraFade'].pre
local amount=param(1);audio.value=true
manual(context(cm),amount,param({}),audio);assert(amount.value==0 and not audio.value)
local shake=handlers['/Script/Engine.PlayerCameraManager:StartCameraShake'].pre
local scale=param(2);shake(context(cm),param({}),scale,param(1),param({}));assert(scale.value==0)
local enable=handlers['/Script/Engine.CameraModifier:EnableModifier']
-- It is re-disabled in the post hook, before the next rendered camera frame.
enable.pre(context(m));m:EnableModifier();enable.post(context(m));assert(m.disabled)
local unrelated=obj({CameraOwner=replacement,disabled=false})
function unrelated:IsDisabled()return self.disabled end
function unrelated:DisableModifier()error('foreign modifier must not change')end
enable.pre(context(unrelated));enable.post(context(unrelated));assert(not unrelated.disabled)
-- New modifiers are observed at creation/enable without a delayed list scan.
local fresh=obj({CameraOwner=cm,disabled=false,Alpha=.7})
fresh.IsDisabled=m.IsDisabled;fresh.DisableModifier=m.DisableModifier;fresh.EnableModifier=m.EnableModifier
enable.pre(context(fresh));fresh:EnableModifier();enable.post(context(fresh));assert(fresh.disabled)
cm.ModifierList=array(m,fresh)
guard.update(s,20.001,sys)
local oldGuard=s.visualGuard
guard.restore(s)
assert(removed==4 and not next(handlers) and not m.disabled and m.Alpha==.9 and not fresh.disabled and fresh.Alpha==.7)
fade({get=function()error('expired camera must never be read')end})
enable.post({get=function()error('expired modifier must never be read')end})
assert(not oldGuard.active)
RegisterHook,UnregisterHook=oldRegister,oldUnregister
print('PASS native fade/shake/modifier hooks filter ownership and deactivate before restoration')
-- Unreflected native flags are skipped; invalid modifiers and count overflow
-- cannot trigger writes or reads beyond a live array's bounds.
cm.bEnableColorScaling=nil;cm.ModifierList=array(obj({invalid=true}))
guard.update(s,30,sys);guard.restore(s);assert(cm.bEnableColorScaling==nil)
local readsPast=0
cm.ModifierList=setmetatable({GetArrayNum=function()return 65 end},{__index=function()readsPast=readsPast+1;error('out of bounds')end})
guard.update(s,31,sys);assert(readsPast==0)
guard.restore(s)
assert(reads==0 and commands==0 and scans==0)
print('PASS unreflected flags and oversized modifier arrays fail safely without world scans')
-- Exact material parent + FName index matching covers the distinct concussion
-- blur and Poppy blinking materials without native pathname conversion.
local oldFName,oldFind=FName,StaticFindObject
local names={ConcussionIntensity=11,BlinkAlpha=12,RainIntensity=13,RadiationNoiseIntensity=14,RadiationSepiaIntensity=15,RadiationRandom=16,RadiationRandomPulsation=17,VignetteIntensity=18}
names.SuppressionIntensity=22
names['Noise intensity']=19;names['grain power']=20;names['Noise edges power']=21
FName=function(name)
 assert(names[name]);return {GetComparisonIndex=function()return names[name]end,
  ToString=function()error('native names must not be stringified')end}
end
local makeName=FName
FName=setmetatable({},{__call=function(_,...)return makeName(...)end})
local concussionAsset,blinkAsset=obj({}),obj({})
local hdrAsset=obj({})
local radiationAsset,radiationHDRAsset=obj({}),obj({})
local vignetteAsset=obj({})
local materialLookups=0
StaticFindObject=function(path)
 if path=='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'then return nil end
 if path:match('^/Script/') then return obj({}) end
 if path:find('/Suppression/',1,true)then return nil end
 materialLookups=materialLookups+1
 if path=='/Game/_Stalker_2/Materials/PostProcess/VignetteBlur/MI_PP_VignetteBlur_01.MI_PP_VignetteBlur_01' then return vignetteAsset end
 if path=='/Game/_Stalker_2/Materials/PostProcess/Concussion/MI_PP_Concussion.MI_PP_Concussion' then return concussionAsset end
 if path=='/Game/_Stalker_2/Materials/PostProcess/PoppyField/MI_PP_Blinking.MI_PP_Blinking' then return blinkAsset end
 if path=='/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst.MI_PPM_PostProcess_Radiation_Inst' then return radiationAsset end
 if path=='/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst_HDR.MI_PPM_PostProcess_Radiation_Inst_HDR' then return radiationHDRAsset end
 assert(path=='/Game/_Stalker_2/Materials/PostProcess/PoppyField/MI_PP_Blinking_HDR.MI_PP_Blinking_HDR');return hdrAsset
end
handlers={};removed=0
RegisterHook=function(path,pre,post)handlers[path]={pre=pre,post=post};return 9,10 end
UnregisterHook=function(path)removed=removed+1;handlers[path]=nil end
cm.ModifierList=array();cm.bEnableColorScaling=true
guard.update(s,40,sys)
local materialCallback=handlers['/Script/Engine.MaterialInstanceDynamic:SetScalarParameterValue'].pre
assert(materialCallback and s.visualGuard.materialCount==0 and materialLookups==0)
local function mid(parent,value)
 local object=obj({Parent=parent,scalar=value})
 function object:GetFullName()error('native pathname conversion must never run')end
 function object:K2_GetScalarParameterValue(name)
  assert(name:GetComparisonIndex()==11 or name:GetComparisonIndex()==12 or name:GetComparisonIndex()==18);return self.scalar
 end
 function object:SetScalarParameterValue(name,value)
  local argument=param(value)
  if handlers['/Script/Engine.MaterialInstanceDynamic:SetScalarParameterValue'] then
   materialCallback(context(self),param(name),argument)
  end
  self.scalar=argument.value
 end
 return object
end
local concussion=mid(concussionAsset,.33)
local blinking=mid(blinkAsset,.42)
local hdrBlinking=mid(hdrAsset,.52)
concussion:SetScalarParameterValue(FName('ConcussionIntensity'),.5)
blinking:SetScalarParameterValue(FName('BlinkAlpha'),.8)
hdrBlinking:SetScalarParameterValue(FName('BlinkAlpha'),.9)
assert(concussion.scalar==0 and blinking.scalar==0 and hdrBlinking.scalar==0 and s.visualGuard.materialCount==3)
local unrelatedMaterial=mid(obj({}),.2)
unrelatedMaterial:SetScalarParameterValue(FName('ConcussionIntensity'),.7)
assert(unrelatedMaterial.scalar==.7 and s.visualGuard.materialCount==3,'same scalar name on a foreign parent must remain untouched')
materialCallback({get=function()error('unrelated parameter must skip object inspection')end},param(FName('RainIntensity')),param(.6))
concussion.scalar=.6;blinking.scalar=.9;hdrBlinking.scalar=.8
guard.update(s,40.001,sys)
assert(concussion.scalar==0 and blinking.scalar==0 and hdrBlinking.scalar==0,'observed MID corrections have no polling gaps')
local extra={}
for i=1,32 do
 local object=mid(concussionAsset,.1);extra[#extra+1]=object
 object:SetScalarParameterValue(FName('ConcussionIntensity'),.7)
end
assert(s.visualGuard.materialCount==32 and extra[29].scalar==0 and extra[30].scalar==.7 and extra[32].scalar==.7)
guard.restore(s)
assert(removed==5 and concussion.scalar==.33 and blinking.scalar==.42 and hdrBlinking.scalar==.52)
for i=1,29 do assert(extra[i].scalar==.1)end
materialCallback({get=function()error('expired material context must never be inspected')end})
assert(unrelatedMaterial.scalar==.7 and scans==1,'one initial MID lookup per flight')
local observer
NotifyOnNewObject=function(path,callback)
 assert(path=='/Script/Engine.MaterialInstanceDynamic' and not observer);observer=callback
end
local directConcussion=mid(concussionAsset,.4)
local directBlink=mid(blinkAsset,.6)
FindAllOf=function(name)
 assert(name=='MaterialInstanceDynamic');scans=scans+1
 return {directConcussion,directBlink,unrelatedMaterial}
end
guard.update(s,41,sys)
assert(directConcussion.scalar==0 and directBlink.scalar==0 and unrelatedMaterial.scalar==.7)
assert(s.visualGuard.materialDiscoveries==2 and scans==2)
directConcussion.scalar=.8;directBlink.scalar=.9
guard.update(s,41.001,sys)
assert(directConcussion.scalar==0 and directBlink.scalar==0 and scans==2,'direct C++ writes are corrected without global polling')
local streamed=mid(hdrAsset,.5)
observer(streamed);assert(streamed.scalar==.5,'construction callback never accesses a material')
guard.update(s,41.002,sys);assert(streamed.scalar==0)
guard.restore(s)
assert(directConcussion.scalar==.4 and directBlink.scalar==.6 and streamed.scalar==.5)
observer({IsValid=function()error('expired observer must remain inert')end})
local resolvedFind=StaticFindObject
local assetsLoaded=false
StaticFindObject=function(path)if assetsLoaded then return resolvedFind(path)end end
FindAllOf=function(name)assert(name=='MaterialInstanceDynamic');return {unrelatedMaterial}end
guard.update(s,42,sys)
assetsLoaded=true
local late=mid(concussionAsset,.49)
observer(late);guard.update(s,42.001,sys)
assert(late.scalar==0,'a newly loaded effect must not be lost behind an earlier failed asset lookup')
guard.restore(s);assert(late.scalar==.49)
-- A native registration entry does not imply a live UFunction. Availability
-- are checked once per flight, without periodic global-pool lookups.
local hooksLoaded=false
local shakePath='/Script/Engine.PlayerCameraManager:StartCameraShake'
local scalarPath='/Script/Engine.MaterialInstanceDynamic:SetScalarParameterValue'
local absentLookups=0
StaticFindObject=function(path)
 if path==shakePath or path==scalarPath then absentLookups=absentLookups+1;return hooksLoaded and obj({}) or nil end
 return resolvedFind(path)
end
RegisterHook=function(path,pre,post)
 assert(hooksLoaded or path~=shakePath and path~=scalarPath,'an absent UFunction must not reach RegisterHook')
 handlers[path]={pre=pre,post=post};return 9,10
end
FindAllOf=function(name)assert(name=='MaterialInstanceDynamic');scans=scans+1;return {}end
guard.update(s,50,sys)
assert(#s.visualGuard.hooks==3 and s.visualGuard.pendingHooks['shake hook'] and not s.visualGuard.materialFeedbackReady)
hooksLoaded=true;guard.update(s,50.5,sys);assert(#s.visualGuard.hooks==3)
guard.update(s,51,sys)
assert(#s.visualGuard.hooks==3 and absentLookups==2 and not s.visualGuard.materialFeedbackReady,
 'absent reflected hooks are never searched every second during flight')
local deferred=mid(nil,.71)
observer(deferred);guard.update(s,51.001,sys)
assert(deferred.scalar==.71 and #s.visualGuard.materialQueue==1)
guard.update(s,51.002,sys);assert(#s.visualGuard.materialQueue==1)
deferred.Parent=concussionAsset;guard.update(s,51.003,sys)
assert(deferred.scalar==0,'a newly constructed MID survives delayed Parent initialization')
local orphan=mid(nil,.2);observer(orphan)
local entryScans=scans
for i=1,8 do guard.update(s,51.003+i/1000,sys)end
assert(#s.visualGuard.materialQueue==0 and scans==entryScans,'incomplete objects expire without repeated global scans')
local oldMaterials=s.visualGuard
observer(mid(nil,.3));guard.restore(s)
assert(deferred.scalar==.71 and oldMaterials.materialQueue==nil and oldMaterials.materialTargets==nil)
print('PASS missing hooks have no periodic lookup and delayed MID initialization retains bounded restoration')
local nativeArms,nativeTicks,nativeDisarms=0,0,0
guard.nativeBridge={new=function()
 return {visualArm=function(_,targets)
  nativeArms=nativeArms+1
  for _,target in ipairs(targets)do assert(target.mid:IsValid() and (target.index==11 or target.index==12) and target.number==0)end
  return true
 end,visualTick=function()nativeTicks=nativeTicks+1;return true end,
 visualDisarm=function()nativeDisarms=nativeDisarms+1;return true end}
end}
FindAllOf=function()return {}end
guard.update(s,59.99,sys)
assert(nativeArms==0 and not s.visualGuard.nativeVisualFailed,'empty initial discovery must not disable the native guard')
observer(directConcussion);observer(directBlink)
guard.update(s,60,sys)
guard.update(s,60.01,sys)
assert(nativeArms==1 and nativeTicks==1,'native target list only rebuilds when identity changes')
directBlink.invalid=true;guard.update(s,60.02,sys);guard.update(s,60.03,sys)
assert(nativeArms==2 and nativeTicks==2,'expired native targets are removed before the lease renews')
guard.restore(s);assert(nativeDisarms==1 and directConcussion.scalar==.4)
guard.nativeBridge=nil
print('PASS native visual lease receives only exact live targets and disarms before restoration')
local function radiationMID(parent)
 local object=obj({Parent=parent,values={[14]=.7,[15]=.4,[16]=.8,[17]=.6,[19]=.7,[20]=.5,[21]=1}})
 function object:K2_GetScalarParameterValue(name)return self.values[name:GetComparisonIndex()]end
 function object:SetScalarParameterValue(name,value)self.values[name:GetComparisonIndex()]=value end
 return object
end
local radiation,radiationHDR=radiationMID(radiationAsset),radiationMID(radiationHDRAsset)
local priorCollectionFind=StaticFindObject
local collection=obj({values={[14]=.7,[15]=.4,[16]=.8,[17]=.6,[18]=.9,[13]=.55,[11]=.35,[22]=.81}})
local library=obj({writes=0})
function library:GetScalarParameterValue(context,asset,name)
 assert(context==s.world and asset==collection);return asset.values[name:GetComparisonIndex()]
end
function library:SetScalarParameterValue(context,asset,name,value)
 assert(context==s.world and asset==collection);self.writes=self.writes+1;asset.values[name:GetComparisonIndex()]=value
end
StaticFindObject=function(path)
 if path=='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'then return collection end
 if path=='/Script/Engine.Default__KismetMaterialLibrary'then return library end
 return priorCollectionFind(path)
end
guard.nativeBridge=nil
FindAllOf=function()return {radiation,radiationHDR}end
guard.update(s,70,sys)
assert(s.visualGuard.materialCount==6,'only real shader noise scalars are held on two radiation MIDs')
for _,object in ipairs({radiation,radiationHDR})do for i=19,21 do assert(object.values[i]==0)end end
for i=14,18 do assert(collection.values[i]==0)end
assert(collection.values[11]==0,'Concussion must be held in the actual MPC, independently of damage callbacks')
assert(collection.values[22]==0,'Suppression uses its separate scalar in the same cooked MPC')
assert(collection.values[13]==.55,'weather and other collection keys must be unchanged')
assert(radiation.values[14]==.7 and radiationHDR.values[15]==.4,'unused radiation MID overrides must not be created')
local writes=library.writes
guard.update(s,70.001,sys);assert(library.writes==writes,'zero feedback must not be rewritten unnecessarily')
collection.values[14]=1;collection.values[17]=.8;collection.values[18]=.6
collection.values[11]=.5 -- ConcussionBlurEffectProcessor writes after entry.
guard.update(s,70.002,sys)
assert(collection.values[14]==0 and collection.values[17]==0 and collection.values[18]==0)
assert(collection.values[11]==0,'late concussion processor writes must be corrected')
assert(s.visualGuard.concussionCorrections==2,'diagnostic distinguishes initial feedback from repeated processor rewrites')
guard.restore(s)
assert(collection.values[14]==.7 and collection.values[15]==.4 and collection.values[16]==.8 and collection.values[17]==.6 and collection.values[18]==.9)
assert(collection.values[13]==.55)
assert(collection.values[11]==.35,'preflight concussion baseline must be restored')
assert(collection.values[22]==.81,'preflight suppression baseline must be restored outside recovery')
assert(radiation.values[19]==.7 and radiation.values[20]==.5 and radiation.values[21]==1)
-- Simulate the game's processor writing after the Lua update. This must be
-- stopped by the native collection lease, without waiting for another frame.
local originalSet=library.SetScalarParameterValue
local gateActive,gateCount,gateArms,gateDisarms,gateTicks=false,0,0,0,0
local gateTickError
guard.nativeBridge={new=function()return {
 concussionArm=function(_,context,asset,index,number,secondary,secondaryNumber)
  assert(context==s.world and asset==collection and index==11 and number==0 and secondary==22 and secondaryNumber==0)
  gateActive=true;gateArms=gateArms+1;gateTicks=0
  return true,{ready=true,active=true,token=1,blocked=0,code=0}
 end,
 concussionTick=function()
  gateTicks=gateTicks+1
  if gateTickError then return nil,gateTickError end
  if gateTicks==1 then return nil,nil end -- Not yet time for a native poll.
  local delta=gateCount;gateCount=0
  return delta,{ready=true,active=true,token=1,blocked=delta,code=0}
 end,
 concussionDisarm=function()gateActive=false;gateDisarms=gateDisarms+1;return true end,
}end}
function library:SetScalarParameterValue(context,asset,name,value)
 if gateActive and context==s.world and asset==collection and name:GetComparisonIndex()==11 and value~=0 then
  value=0;gateCount=gateCount+1
 end
 return originalSet(self,context,asset,name,value)
end
guard.update(s,70.01,sys)
assert(gateActive and gateDisarms==0 and not s.visualGuard.nativeConcussionFailed,'successful arm status must not disarm the gate')
guard.update(s,70.02,sys)
assert(gateActive and not s.visualGuard.nativeConcussionFailed,'nil,nil between polls is not an error')
library:SetScalarParameterValue(s.world,collection,FName('ConcussionIntensity'),.5)
assert(collection.values[11]==0,'a processor write after Lua update must stay zero before rendering')
library:SetScalarParameterValue(s.world,collection,FName('RainIntensity'),.45)
assert(collection.values[13]==.45,'unrelated collection scalar is forwarded')
guard.update(s,70.12,sys)
assert(gateArms==1 and s.visualGuard.nativeConcussionIntercepted==1)
assert(gateActive and gateDisarms==0 and not s.visualGuard.nativeConcussionFailed,'positive delta,status must retain the gate')
guard.update(s,70.13,sys)
assert(gateActive and not s.visualGuard.nativeConcussionFailed and s.visualGuard.nativeConcussionIntercepted==1,'zero delta,status is also success')
guard.restore(s)
assert(gateDisarms==1 and not gateActive and collection.values[11]==.35,'native lease must release before baseline restoration')
guard.update(s,70.14,sys);gateTickError='native scope changed';collection.values[11]=.5
guard.update(s,70.15,sys)
assert(not gateActive and s.visualGuard.nativeConcussionFailed and collection.values[11]==0,'nil,error must disarm and preserve the Lua fallback')
local failedArms=gateArms
guard.update(s,70.16,sys);assert(gateArms==failedArms,'a real failure must not trigger per-frame rearming')
guard.restore(s);assert(collection.values[11]==.35)
library.SetScalarParameterValue=originalSet;guard.nativeBridge=nil
collection.values[13]=.55
print('PASS native concussion real return contract: true/status, positive/status, zero/status, pending nil/nil, real nil/error, late writes and baseline restoration')
local collectionLookupCount=0
StaticFindObject=function(path)
 if path=='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'then collectionLookupCount=collectionLookupCount+1;return nil end
 return priorCollectionFind(path)
end
FindAllOf=function()return {}end
guard.update(s,70.1,sys)
for frame=1,40 do guard.update(s,70.1+frame/100,sys)end
assert(collectionLookupCount==1,'a missing collection must not trigger per-frame asset lookups')
guard.restore(s)
local originalGet=library.GetScalarParameterValue
StaticFindObject=function(path)
 if path=='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'then return collection end
 if path=='/Script/Engine.Default__KismetMaterialLibrary'then return library end
 return priorCollectionFind(path)
end
function library:GetScalarParameterValue(context,asset,name)
 if name:GetComparisonIndex()==16 then error('test missing scalar getter')end
 return originalGet(self,context,asset,name)
end
writes=library.writes
guard.update(s,70.7,sys)
assert(library.writes==writes and collection.values[14]==.7 and collection.values[15]==.4,'snapshot failure must not partially change collection values')
guard.restore(s);library.GetScalarParameterValue=originalGet
StaticFindObject=priorCollectionFind
print('PASS exact cooked radiation/vignette collection keys, late writes, restoration and unrelated weather isolation')
local priorFindAll=FindAllOf
local vignette=mid(vignetteAsset,.9)
FindAllOf=function(name)return name=='MaterialInstanceDynamic'and {vignette}or {}end
local lens=obj({PostProcessSettings={VignetteIntensity=.65,bOverride_VignetteIntensity=false},PostProcessBlendWeight=.25})
local lensSession={pc=s.pc,world=s.world,camera=obj({CameraComponent=lens})}
guard.update(lensSession,71,sys)
assert(vignette.scalar==0 and lens.PostProcessSettings.VignetteIntensity==0 and lens.PostProcessSettings.bOverride_VignetteIntensity==true)
assert(lens.PostProcessBlendWeight==.25,'lens protection must preserve the selected analog blend weight')
vignette.scalar=.7;lens.PostProcessSettings.VignetteIntensity=.8
guard.update(lensSession,71.001,sys)
assert(vignette.scalar==0 and lens.PostProcessSettings.VignetteIntensity==0,'late vignette changes must be suppressed on the next frame')
guard.restore(lensSession)
assert(vignette.scalar==.9 and lens.PostProcessSettings.VignetteIntensity==.65 and lens.PostProcessSettings.bOverride_VignetteIntensity==false)
assert(lens.PostProcessBlendWeight==.25,'lens state must be restored independently of character camera')
-- Analog-off retains old property overrides but sets the weight to zero.
-- A lens guard must never revive those stale grain/fringe settings.
lens.PostProcessBlendWeight=0;lens.PostProcessSettings.FilmGrainIntensity=1
lens.PostProcessSettings.bOverride_FilmGrainIntensity=true
guard.update(lensSession,72,sys)
assert(lens.PostProcessBlendWeight==0,'Analog off must stay off after lens protection')
guard.restore(lensSession);assert(lens.PostProcessBlendWeight==0)
-- The bypass is exact to Radiation. Foreign/anomaly materials, even those
-- with identical scalar names, retain their values and camera blend weights.
local foreignRadiation=radiationMID(obj({}))
local rows=array({Weight=.6,Object=radiation},{Weight=.7,Object=foreignRadiation},{Weight=.8,Object=radiationHDRAsset})
lens.PostProcessSettings.WeightedBlendables={Array=rows}
FindAllOf=function(name)assert(name=='MaterialInstanceDynamic');return {radiation,radiationHDR,foreignRadiation}end
guard.update(lensSession,73,sys)
assert(rows[1].Weight==0 and rows[2].Weight==.7 and rows[3].Weight==0)
assert(foreignRadiation.values[19]==.7 and foreignRadiation.values[20]==.5 and foreignRadiation.values[21]==1)
radiation.values[19]=.9;rows[1].Weight=1
guard.update(lensSession,73.001,sys)
assert(radiation.values[19]==0 and rows[1].Weight==0,'late shader/weight updates are corrected')
rows[3]={Weight=.9,Object=foreignRadiation}
guard.restore(lensSession)
assert(rows[1].Weight==.6 and rows[2].Weight==.7 and rows[3].Weight==.9,'restore never writes into a replaced foreign row')
assert(radiation.values[19]==.7 and radiation.values[20]==.5 and radiation.values[21]==1)
FindAllOf=function(name)assert(name=='MaterialInstanceDynamic');return {}end
rows[1]={Weight=.4,Object=radiationAsset}
guard.update(lensSession,74,sys)
assert(rows[1].Weight==0,'a constant Radiation blendable must be bypassed even without any dynamic material discovery')
guard.restore(lensSession);assert(rows[1].Weight==.4 and rows[2].Weight==.7)
-- Concussion is another exact owned feedback pass. It is not an anomaly,
-- suppression volume, weather, general blur, or global postprocess disable.
rows[1]={Weight=.5,Object=concussionAsset}
rows[3]={Weight=.3,Object=directConcussion}
guard.update(lensSession,75,sys)
assert(rows[1].Weight==0 and rows[3].Weight==0 and rows[2].Weight==.7)
rows[1].Weight=.9;guard.update(lensSession,75.001,sys);assert(rows[1].Weight==0)
guard.restore(lensSession)
assert(rows[1].Weight==.5 and rows[3].Weight==.3 and rows[2].Weight==.7)
print('PASS MPC concussion processor feedback and exact camera pass bypass restore preflight state without changing foreign effects')
-- Stalker2 keeps its native stack on UCameraManager.CameraComponent, not
-- necessarily on Pawn.CameraComponent. Select it by exact PlayerCameraManager
-- ownership, without touching another player/world or rescanning every tick.
local nativeRows=array({Weight=.85,Object=concussionAsset},{Weight=.45,Object=foreignRadiation})
local foreignRows=array({Weight=.95,Object=concussionAsset})
local nativeComponent=obj({PostProcessSettings={WeightedBlendables={Array=nativeRows}}})
local foreignComponent=obj({PostProcessSettings={WeightedBlendables={Array=foreignRows}}})
local nativeManager=obj({PlayerCameraManager=cm,CameraComponent=nativeComponent})
local foreignManager=obj({PlayerCameraManager=replacement,CameraComponent=foreignComponent})
local managerScans=0
FindAllOf=function(name)
 if name=='CameraManager'then managerScans=managerScans+1;return {foreignManager,nativeManager}end
 assert(name=='MaterialInstanceDynamic');return {}
end
lensSession.pawn=obj({}) -- Deliberately no CameraComponent field.
guard.update(lensSession,76,sys)
assert(nativeRows[1].Weight==0 and nativeRows[2].Weight==.45 and foreignRows[1].Weight==.95)
for i=1,40 do guard.update(lensSession,76+i/100,sys)end
assert(managerScans==1,'native camera class lookup must occur once per flight, never every update')
nativeRows[1].Weight=.75;guard.update(lensSession,76.5,sys);assert(nativeRows[1].Weight==0)
-- If the same manager is rebound to a foreign camera, do not write its stack.
nativeManager.PlayerCameraManager=replacement;nativeRows[1].Weight=.65
guard.update(lensSession,76.6,sys);assert(nativeRows[1].Weight==.65)
nativeManager.PlayerCameraManager=cm
guard.update(lensSession,76.7,sys);assert(nativeRows[1].Weight==0)
guard.restore(lensSession)
assert(nativeRows[1].Weight==.85 and nativeRows[2].Weight==.45 and foreignRows[1].Weight==.95)
lensSession.pawn=nil
print('PASS exact native CameraManager ownership, late writes, one lookup, foreign rebind and restoration')
print('PASS radiation shader inputs and exact camera blendable bypass preserve anomaly materials and Analog off')
FindAllOf=priorFindAll
print('PASS scoped FPV lens and native vignette material suppression, late updates and restoration')
NotifyOnNewObject=nil
FName,StaticFindObject,RegisterHook,UnregisterHook=oldFName,oldFind,oldRegister,oldUnregister
print('PASS exact concussion and blinking scalar guards restore snapshots, bound discovery and preserve foreign/weather materials')
