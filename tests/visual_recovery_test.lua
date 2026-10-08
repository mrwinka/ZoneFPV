local guard=dofile('mod/Scripts/visual_guard.lua')
local now,sequence=0,0
local function object(fields)
    local o=fields or {};sequence=sequence+1;o.address=sequence*16
    function o:IsValid()return not self.invalid end
    function o:GetAddress()assert(not self.invalid,'expired object read');return self.address end
    return o
end
local indices={};local nextIndex=0
FName=setmetatable({},{__call=function(_,text)
    if not indices[text]then nextIndex=nextIndex+1;indices[text]=nextIndex end
    local index=indices[text];return {GetComparisonIndex=function()return index end}
end})
local world,otherWorld=object(),object()
local collection=object();local library=object()
local values,reads,writes={},0,{}
for _,name in ipairs({'ConcussionIntensity','SuppressionIntensity','RadiationNoiseIntensity','RadiationSepiaIntensity','RadiationRandom',
    'RadiationRandomPulsation','VignetteIntensity'})do values[FName(name):GetComparisonIndex()]=.77 end
local concussionIndex=indices.ConcussionIntensity
local suppressionIndex=indices.SuppressionIntensity
local nativeActive,nativeWorld,nativeAsset,nativeName,nativeSecondary,nativeRefresh=false
local nativeNew,nativeArms,nativeTicks,nativeDisarms,nativeBlocked=0,0,0,0,0
local nativeFailure=false
guard.nativeBridge={new=function()
    nativeNew=nativeNew+1
    return {
        concussionArm=function(_,context,asset,name,number,secondary,secondaryNumber)
            nativeArms=nativeArms+1
            if nativeFailure then return false,'fixture initial arm failure' end
            assert(number==0 and name==concussionIndex and secondary==suppressionIndex and secondaryNumber==0)
            nativeActive=true;nativeWorld=context;nativeAsset=asset;nativeName=name;nativeSecondary=secondary;nativeRefresh=now
            return true,{ready=true,active=true}
        end,
        concussionTick=function(_,dt)
            assert(dt>=0);nativeTicks=nativeTicks+1;nativeRefresh=now
            return nil,nil -- Native renewal occurs even between status polls.
        end,
        concussionDisarm=function()nativeActive=false;nativeDisarms=nativeDisarms+1;return true end,
    }
end}
function library:GetScalarParameterValue(context,asset,name)
    assert(context==world and asset==collection,'recovery must stay in its original world')
    reads=reads+1;return values[name:GetComparisonIndex()] or 0
end
function library:SetScalarParameterValue(context,asset,name,value)
    assert(context==world and asset==collection,'recovery must stay in its original world')
    local index=name:GetComparisonIndex()
    if nativeActive and now-nativeRefresh<.1 and context==nativeWorld and asset==nativeAsset and (index==nativeName or index==nativeSecondary)and value~=0 then
        nativeBlocked=nativeBlocked+1;value=0
    end
    writes[#writes+1]={index=index,value=value};values[index]=value
end
local assetPresent,assetLookups=true,0
StaticFindObject=function(path)
    if path=='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'then assetLookups=assetLookups+1;return assetPresent and collection or nil end
    if path=='/Script/Engine.Default__KismetMaterialLibrary'then return library end
    if path:match('^/Script/')then return object() end
    return nil
end
local registered,removed=0,0
RegisterHook=function()registered=registered+1;return registered*2,registered*2+1 end
UnregisterHook=function()removed=removed+1 end
local scans=0
FindAllOf=function()scans=scans+1;return {} end
local shakes,fades,disabled,enabled=0,0,0,0
local modifier=object({disabled=false,Alpha=.4})
function modifier:IsDisabled()return self.disabled end
function modifier:DisableModifier()disabled=disabled+1;self.disabled=true;self.Alpha=0 end
function modifier:EnableModifier()enabled=enabled+1;self.disabled=false end
local list={modifier,GetArrayNum=function()return 1 end}
local cameraManager=object({ModifierList=list,bEnableColorScaling=true})
function cameraManager:StopAllCameraShakes()shakes=shakes+1 end
function cameraManager:StopCameraFade()fades=fades+1 end
modifier.CameraOwner=cameraManager
local cameraComponent=object({PostProcessSettings={VignetteIntensity=.5,bOverride_VignetteIntensity=false},PostProcessBlendWeight=.8})
local camera=object({CameraComponent=cameraComponent})
local pc=object({PlayerCameraManager=cameraManager})
local fog={['r.Fog']=2,['r.VolumetricFog']=1,['r.LocalFogVolume']=3}
local console=0
local system={GetConsoleVariableIntValue=function(_,name)return assert(fog[name])end,
    ExecuteConsoleCommand=function(_,_,command)
        local name,value=command:match('^(%S+) (%d+)$');assert(fog[name]);fog[name]=tonumber(value);console=console+1
    end}
local session={world=world,pc=pc,camera=camera}
now=9.99;guard.update(session,now,system,nil,true)
assert(nativeActive and values[concussionIndex]==0 and modifier.disabled and not cameraManager.bEnableColorScaling)
assert(fog['r.Fog']==0 and cameraComponent.PostProcessSettings.VignetteIntensity==0)
local originalArms,originalNew=nativeArms,nativeNew
now=10;assert(guard.beginRecovery(session,now)and guard.recoveryActive())
assert(session.visualGuard==nil and nativeActive and nativeArms==originalArms and nativeNew==originalNew,
    'existing native lease transfers without disarm or re-arm gap')
assert(not modifier.disabled and modifier.Alpha==.4 and cameraManager.bEnableColorScaling)
assert(cameraComponent.PostProcessSettings.VignetteIntensity==.5 and not cameraComponent.PostProcessSettings.bOverride_VignetteIntensity)
assert(fog['r.Fog']==2 and fog['r.VolumetricFog']==1 and fog['r.LocalFogVolume']==3 and removed==registered)
camera.invalid=true;cameraComponent.invalid=true;pc.invalid=true
local effects={shakes=shakes,fades=fades,disabled=disabled,enabled=enabled,console=console,registered=registered,reads=reads,scans=scans}
local firstRecoveryWrite=#writes
now=11;assert(guard.beginRecovery(session,now),'repeat exit remains idempotent')
for frame=1,99 do
    now=10+frame*.05
    assert(guard.updateRecovery(now,world)and nativeActive)
    library:SetScalarParameterValue(world,collection,FName('ConcussionIntensity'),.9)
    assert(values[concussionIndex]==0,'late blast writes remain zero after camera teardown')
end
assert(nativeTicks>=100 and nativeBlocked>=99 and assetLookups==1,'each frame renews existing native scope without asset polling')
assert(shakes==effects.shakes and fades==effects.fades and disabled==effects.disabled and enabled==effects.enabled and console==effects.console and registered==effects.registered and scans==effects.scans)
for index=firstRecoveryWrite+1,#writes do assert(writes[index].index==concussionIndex or writes[index].index==suppressionIndex,'only two concussion MPC parameters may be held after exit')end
local radiationIndex=indices.RadiationNoiseIntensity
library:SetScalarParameterValue(world,collection,FName('RadiationNoiseIntensity'),.42)
now=14.999;guard.updateRecovery(now,world);assert(values[radiationIndex]==.42)
now=15;assert(not guard.updateRecovery(now,world)and not guard.recoveryActive()and not nativeActive)
assert(values[concussionIndex]==0,'stale .77 preflight baseline must not replay at expiration')
now=15.001;library:SetScalarParameterValue(world,collection,FName('ConcussionIntensity'),.31);assert(values[concussionIndex]==.31)
now=20;assert(not guard.beginRecovery(session,now)and not guard.recoveryActive(),'repeat exit never extends original deadline')
print('PASS exact five-second post-exit lease, gap-free native handoff, every-frame renewal, idempotence and no stale baseline replay')
print('PASS camera/cvars/hooks restore immediately; character recovery holds only concussion and genuine later effects resume')

-- Any early exit starts its own fixed recovery even before visual_guard.update.
local early={world=world}
values[concussionIndex]=.8;now=30
local beforeArms=nativeArms;assert(guard.beginRecovery(early,now)and nativeArms==beforeArms+1 and values[concussionIndex]==0)
local beforeReads,beforeWrites=reads,#writes
now=30.02;assert(not guard.updateRecovery(now,otherWorld)and not nativeActive)
assert(reads==beforeReads and #writes==beforeWrites,'world change cannot read/write a replacement context')
assert(not guard.updateRecovery(31,world),'world-scoped recovery does not restart after travel')
now=40;assert(guard.beginRecovery({world=world},now))
beforeReads,beforeWrites=reads,#writes
assert(not guard.updateRecovery(40.01,nil)and not nativeActive and reads==beforeReads and #writes==beforeWrites)
now=50;assert(not guard.beginRecovery({world=object({invalid=true})},now))
print('PASS early exit arms concussion-only protection; missing/changed/invalid worlds disarm immediately without new-world writes')

-- Missing assets retry at most once per second, without moving the deadline.
assetPresent=false;now=60
local beforeLookups=assetLookups
assert(guard.beginRecovery({world=world},now)and guard.recoveryActive())
for step=1,9 do now=60+step*.1;guard.updateRecovery(now,world)end
assert(assetLookups==beforeLookups+1)
now=61;guard.updateRecovery(now,world);assert(assetLookups==beforeLookups+2)
assetPresent=true;now=61.999;guard.updateRecovery(now,world);assert(not nativeActive)
now=62;values[concussionIndex]=.9;guard.updateRecovery(now,world);assert(nativeActive and values[concussionIndex]==0)
now=65;assert(not guard.updateRecovery(now,world)and not nativeActive,'late asset discovery cannot extend five seconds')
print('PASS absent assets use bounded lookup retries and retain the original five-second deadline')

-- A failed FPV native attempt does not poison the new recovery scope.
local failed={world=world};nativeFailure=true;now=70
guard.update(failed,now,nil)
assert(failed.visualGuard.nativeConcussionFailed and not nativeActive)
nativeFailure=false;now=70.01;beforeArms=nativeArms
assert(guard.beginRecovery(failed,now)and nativeArms==beforeArms+1 and nativeActive)
now=70.02
local replacement={world=world};local beforeDisarms=nativeDisarms
guard.update(replacement,now,nil)
assert(not guard.recoveryActive()and nativeDisarms==beforeDisarms+1 and nativeActive,
    'new FPV stops previous recovery before arming its own native lease')
now=75.02;assert(not guard.updateRecovery(now,world)and nativeActive,'old deadline must not disarm the replacement flight')
guard.restore(replacement);assert(not nativeActive)
print('PASS previous native failure retries independently; new FPV cancels old recovery without touching replacement scope')

-- Unsupported native versions keep the same narrowly scoped Lua correction.
guard.nativeBridge=nil;values[concussionIndex]=.6;now=80
assert(guard.beginRecovery({world=world},now)and values[concussionIndex]==0)
values[concussionIndex]=.7;values[radiationIndex]=.53
now=80.01;guard.updateRecovery(now,world)
assert(values[concussionIndex]==0 and values[radiationIndex]==.53)
world.invalid=true;beforeReads,beforeWrites=reads,#writes
assert(not guard.updateRecovery(80.02,world)and reads==beforeReads and #writes==beforeWrites)
assert(not guard.recoveryActive())
print('PASS Lua concussion correction remains available without native support; invalid old-world wrappers are never read')

-- v44 regression: an explosion can render SuppressionIntensity while the
-- native ConcussionIntensity MPC gate is already demonstrably working.
guard=dofile('mod/Scripts/visual_guard.lua');world.invalid=nil;now=100
local assets={}
local function asset(path,label)
    local value=object();function value:GetFName()return FName(label)end
    assets[path]=value;return value
end
local concussionParent=asset('/Game/_Stalker_2/Materials/PostProcess/Concussion/MI_PP_Concussion.MI_PP_Concussion','MI_PP_Concussion')
local suppressionParent=asset('/Game/_Stalker_2/Materials/PostProcess/Suppression/PPI_Suppression.PPI_Suppression','PPI_Suppression')
local suppressionHDRParent=asset('/Game/_Stalker_2/Materials/PostProcess/Suppression/PPI_Suppression_HDR.PPI_Suppression_HDR','PPI_Suppression_HDR')
local blinkParent=asset('/Game/_Stalker_2/Materials/PostProcess/PoppyField/MI_PP_Blinking.MI_PP_Blinking','MI_PP_Blinking')
local radiationParent=asset('/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst.MI_PPM_PostProcess_Radiation_Inst','MI_PPM_PostProcess_Radiation_Inst')
local shake1=asset('/Game/GameLite/Resources/CameraShake/CamShakeConcussion.CamShakeConcussion_C','CamShakeConcussion_C')
local shake2=asset('/Game/GameLite/Resources/CameraShake/CamShakeConcussion_2.CamShakeConcussion_2_C','CamShakeConcussion_2_C')
local audioEvent=asset('/Game/_STALKER2/Audio/WwiseAudio/Events/Effects/Concussion/SFX_Concussion_Start.SFX_Concussion_Start','SFX_Concussion_Start')
local suppressionIndex=FName('SuppressionIntensity'):GetComparisonIndex()
local visualActive,visualRefresh,visualTargets=false,0,{}
local visualArms,visualTicks,visualDisarms,visualBlocked=0,0,0,0
local function mid(parent,label,baseline)
    local value=object({Parent=parent,scalars={[FName(label):GetComparisonIndex()]=baseline}})
    function value:K2_GetScalarParameterValue(name)return self.scalars[name:GetComparisonIndex()]or 0 end
    function value:SetScalarParameterValue(name,wanted)
        local index=name:GetComparisonIndex();local key=self:GetAddress()..':'..index
        if visualActive and now-visualRefresh<.1 and visualTargets[key]and wanted~=0 then
            visualBlocked=visualBlocked+1;wanted=0
        end
        self.scalars[index]=wanted
    end
    return value
end
local concussionMID=mid(concussionParent,'ConcussionIntensity',.73)
local suppressionMID=mid(suppressionParent,'SuppressionIntensity',.88)
local suppressionHDRMID=mid(suppressionHDRParent,'SuppressionIntensity',.94)
local foreignSuppression=mid(suppressionParent,'SuppressionIntensity',1.23)
local blinkMID=mid(blinkParent,'BlinkAlpha',.41)
local radiationMID=mid(radiationParent,'Noise intensity',.59)
local weather=object()
local function array(...)
    local values={...};function values:GetArrayNum()return #self end;return values
end
local rows=array({Object=concussionMID,Weight=.7},{Object=suppressionMID,Weight=.6},
    {Object=suppressionHDRMID,Weight=.9},{Object=blinkMID,Weight=.4},{Object=weather,Weight=.95},
    {Object=radiationMID,Weight=.3})
local localComponent=object({PostProcessSettings={WeightedBlendables={Array=rows}}})
local otherComponent=object({PostProcessSettings={WeightedBlendables={Array=array({Object=foreignSuppression,Weight=.8})}}})
local normalShake=object();local activeShakes={[shake1]=true,[shake2]=true,[normalShake]=true}
local allShakeStops,classShakeStops,allFades=0,0,0
local normalModifier=object({disabled=false,Alpha=.45})
function normalModifier:IsDisabled()return self.disabled end
function normalModifier:DisableModifier()self.disabled=true;self.Alpha=0 end
function normalModifier:EnableModifier()self.disabled=false end
local pcm=object({ModifierList=array(normalModifier),bEnableColorScaling=true})
normalModifier.CameraOwner=pcm
function pcm:StopAllCameraShakes()allShakeStops=allShakeStops+1 end
function pcm:StopCameraFade()allFades=allFades+1 end
function pcm:StopAllInstancesOfCameraShake(class,immediate)
    assert((class==shake1 or class==shake2)and immediate==true,'only exact Concussion shake classes may be stopped')
    classShakeStops=classShakeStops+1;activeShakes[class]=nil
end
local controller=object({PlayerCameraManager=pcm});local localPawn=object()
local nativeManager=object({PlayerCameraManager=pcm,CameraComponent=localComponent})
local foreignManager=object({PlayerCameraManager=object(),CameraComponent=otherComponent})
local droneComponent=object({PostProcessSettings={VignetteIntensity=.5,bOverride_VignetteIntensity=false},PostProcessBlendWeight=.8})
local droneCamera=object({CameraComponent=droneComponent})
local ownedAudio,foreignAudio=true,true
local audioStops=0
function audioEvent:ExecuteAction(action,actor,id,duration,curve)
    assert(action==0 and actor==localPawn and id==0 and duration==0 and curve==4)
    audioStops=audioStops+1;ownedAudio=false;return 1
end
local globalMIDScans,nativeCameraScans,lookups=0,0,{}
StaticFindObject=function(path)
    lookups[path]=(lookups[path]or 0)+1
    if path=='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'then return collection end
    if path=='/Script/Engine.Default__KismetMaterialLibrary'then return library end
    if path:match('^/Script/')then return object()end
    return assets[path]
end
FindAllOf=function(class)
    if class=='CameraManager'then nativeCameraScans=nativeCameraScans+1;return {foreignManager,nativeManager}end
    assert(class=='MaterialInstanceDynamic');globalMIDScans=globalMIDScans+1
    return {concussionMID,suppressionMID,suppressionHDRMID,foreignSuppression,blinkMID,radiationMID}
end
NotifyOnNewObject=nil
guard.nativeBridge={new=function()
    local reported=visualBlocked
    return {
        concussionArm=function(_,context,asset,name,number,secondary,secondaryNumber)
            assert(context==world and asset==collection and name==concussionIndex and number==0 and secondary==suppressionIndex and secondaryNumber==0)
            nativeActive=true;nativeWorld=context;nativeAsset=asset;nativeName=name;nativeSecondary=secondary;nativeRefresh=now;return true,{}
        end,
        concussionTick=function()nativeRefresh=now;return nil,nil end,
        concussionDisarm=function()nativeActive=false;return true end,
        visualArm=function(_,targets)
            assert(#targets>0 and #targets<=32);visualArms=visualArms+1;visualTargets={}
            for _,target in ipairs(targets)do
                assert(target.mid:IsValid()and target.number==0)
                visualTargets[target.mid:GetAddress()..':'..target.index]=true
            end
            visualActive=true;visualRefresh=now;return true,{}
        end,
        visualTick=function(_,dt)
            assert(dt>=0);visualTicks=visualTicks+1;visualRefresh=now
            local delta=visualBlocked-reported;reported=visualBlocked;return delta,{}
        end,
        visualDisarm=function()visualActive=false;visualTargets={};visualDisarms=visualDisarms+1;return true end,
    }
end}
local flight={world=world,pc=controller,pawn=localPawn,camera=droneCamera}
values[concussionIndex]=0;values[suppressionIndex]=.82
guard.update(flight,now,nil)
assert(values[suppressionIndex]==0 and suppressionMID.scalars[suppressionIndex]==.88 and suppressionHDRMID.scalars[suppressionIndex]==.94,
    'actual shader input is MPC; do not create an unused MID override')
assert(values[concussionIndex]==0 and rows[1].Weight==0 and rows[2].Weight==0 and rows[3].Weight==0)
assert(rows[5].Weight==.95 and rows[6].Weight==0 and foreignSuppression.scalars[suppressionIndex]==1.23)
now=100.01;assert(guard.beginRecovery(flight,now))
assert(not visualActive and nativeActive and nativeCameraScans==1 and globalMIDScans==1)
assert(not normalModifier.disabled and normalModifier.Alpha==.45 and pcm.bEnableColorScaling)
assert(blinkMID.scalars[indices.BlinkAlpha]==.41 and radiationMID.scalars[indices['Noise intensity']]==.59 and rows[6].Weight==.3)
assert(foreignSuppression.scalars[suppressionIndex]==1.23 and otherComponent.PostProcessSettings.WeightedBlendables.Array[1].Weight==.8,
    'global same-parent material must be restored, not retained without owned camera membership')
assert(not visualTargets[foreignSuppression:GetAddress()..':'..suppressionIndex])
assert(not ownedAudio and foreignAudio and not activeShakes[shake1]and not activeShakes[shake2]and activeShakes[normalShake])
local unchanged={allShakeStops=allShakeStops,allFades=allFades,registered=registered}
local beforeBlocked=nativeBlocked
droneCamera.invalid=true;droneComponent.invalid=true
local lateMID=mid(suppressionParent,'SuppressionIntensity',.62)
rows[7]={Object=lateMID,Weight=.55}
local foreignLate=mid(suppressionParent,'SuppressionIntensity',.91)
for frame=1,99 do
    now=100.01+frame*.05
    activeShakes[shake1]=true;activeShakes[shake2]=true;ownedAudio=true
    assert(guard.updateRecovery(now,world,controller))
    library:SetScalarParameterValue(world,collection,FName('ConcussionIntensity'),.9)
    library:SetScalarParameterValue(world,collection,FName('SuppressionIntensity'),.8)
    assert(values[concussionIndex]==0 and values[suppressionIndex]==0,
        'both late native processor writes must remain zero before rendering')
    assert(suppressionMID.scalars[suppressionIndex]==.88 and suppressionHDRMID.scalars[suppressionIndex]==.94 and lateMID.scalars[suppressionIndex]==.62,
        'same-named unused MID parameters must not be modified')
    assert(rows[1].Weight==0 and rows[2].Weight==0 and rows[3].Weight==0 and rows[7].Weight==0)
    assert(not activeShakes[shake1]and not activeShakes[shake2]and activeShakes[normalShake])
    assert(foreignLate.scalars[suppressionIndex]==.91 and rows[5].Weight==.95 and foreignAudio)
end
assert(nativeBlocked-beforeBlocked>=198 and classShakeStops>=200 and audioStops>25)
assert(globalMIDScans==1 and nativeCameraScans==1 and allShakeStops==unchanged.allShakeStops and allFades==unchanged.allFades and registered==unchanged.registered)
-- The fallback also corrects direct raw writes bypassing a synthetic native setter.
values[suppressionIndex]=.8;now=105.009;guard.updateRecovery(now,world,controller)
assert(values[suppressionIndex]==0)
now=105.01;assert(not guard.updateRecovery(now,world,controller)and not visualActive and not nativeActive)
assert(rows[1].Weight==.7 and rows[2].Weight==.6 and rows[3].Weight==.9 and rows[7].Weight==.55)
assert(values[suppressionIndex]==0 and values[concussionIndex]==0,'old nonzero MPC blast baselines must not replay')
local stopped=classShakeStops;activeShakes[shake1]=true
library:SetScalarParameterValue(world,collection,FName('SuppressionIntensity'),.27)
now=105.02;guard.updateRecovery(now,world,controller)
assert(values[suppressionIndex]==.27 and activeShakes[shake1]and stopped==classShakeStops,
    'genuine subsequent suppression/shake resumes after exact five-second deadline')
print('PASS v44 real MPC SuppressionIntensity regression with ConcussionIntensity already zero, dual native late-write renewal, owned late blendable discovery and exact five-second cleanup')
print('PASS v44 only local concussion shakes/audio and blendables are held; normal movement/hit feedback, blink/radiation/weather and foreign same-parent materials remain independent')

-- Collision/entry failure before the first flight update must still discover
-- the current owned stack, without a global material scan or a movable deadline.
now=110;values[concussionIndex]=0;values[suppressionIndex]=.95
local beforeGlobal,beforeCamera=globalMIDScans,nativeCameraScans
assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(values[suppressionIndex]==0 and rows[2].Weight==0 and globalMIDScans==beforeGlobal and nativeCameraScans==beforeCamera+1)
local replacementController=object({PlayerCameraManager=pcm})
now=110.01;assert(not guard.updateRecovery(now,world,replacementController)and not nativeActive and not visualActive and rows[2].Weight==.6)
now=120;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
local priorForeign=foreignSuppression.scalars[suppressionIndex]
local priorStops=classShakeStops
now=120.01;assert(not guard.updateRecovery(now,otherWorld,controller)and not nativeActive and not visualActive)
assert(foreignSuppression.scalars[suppressionIndex]==priorForeign and classShakeStops==priorStops)
controller.Pawn=localPawn
now=130;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
controller.Pawn=object();local stopsBeforePossess=audioStops;local readsBeforePossess=reads
now=130.01;assert(not guard.updateRecovery(now,world,controller)and not nativeActive and rows[2].Weight==.6)
assert(audioStops==stopsBeforePossess and reads==readsBeforePossess,'possession change must cancel before audio or collection writes')
controller.Pawn=localPawn
now=135;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
localPawn.invalid=true;controller.Pawn=object();stopsBeforePossess=audioStops;readsBeforePossess=reads
now=135.01;assert(not guard.updateRecovery(now,world,controller)and not nativeActive and rows[2].Weight==.6)
assert(audioStops==stopsBeforePossess and reads==readsBeforePossess,'invalid original pawn with new possession must cancel before touching replacement camera or MPC')
localPawn.invalid=nil;controller.Pawn=localPawn
print('PASS v44 early exits acquire only current owned feedback; changed local controller/pawn/world releases native scopes without foreign writes')
now=140;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now)and nativeActive)
local newCamera=object({CameraComponent=object({PostProcessSettings={VignetteIntensity=.2,bOverride_VignetteIntensity=false},PostProcessBlendWeight=1})})
local nextFlight={world=world,pc=controller,pawn=localPawn,camera=newCamera}
now=141;guard.update(nextFlight,now,nil)
assert(not guard.recoveryActive()and nativeActive and nextFlight.visualGuard,'new flight cancels character recovery before acquiring its own scope')
now=146;assert(not guard.updateRecovery(now,world,controller)and nativeActive,'old five-second deadline cannot disarm replacement FPV')
guard.restore(nextFlight);assert(not nativeActive and not visualActive and rows[2].Weight==.6)
guard.nativeBridge=nil;values[concussionIndex]=.4;values[suppressionIndex]=.67
now=150;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(values[concussionIndex]==0 and values[suppressionIndex]==0)
values[concussionIndex]=.6;values[suppressionIndex]=.7;values[indices.RadiationNoiseIntensity]=.91
now=150.01;guard.updateRecovery(now,world,controller)
assert(values[concussionIndex]==0 and values[suppressionIndex]==0 and values[indices.RadiationNoiseIntensity]==.91)
now=155;assert(not guard.updateRecovery(now,world,controller)and rows[2].Weight==.6)
print('PASS v44 new FPV cancels recovery without stale-deadline interference; unsupported native versions retain both narrowly scoped MPC corrections')

-- v45 shipping generated-class paths are correct, but registry-only discovery
-- can miss assets until their first load. Exercise the actual shared loader.
local exactPaths={
    '/Game/GameLite/Resources/CameraShake/CamShakeConcussion.CamShakeConcussion_C',
    '/Game/GameLite/Resources/CameraShake/CamShakeConcussion_2.CamShakeConcussion_2_C',
    '/Game/_STALKER2/Audio/WwiseAudio/Events/Effects/Concussion/SFX_Concussion_Start.SFX_Concussion_Start',
}
local hiddenAssets={}
for _,path in ipairs(exactPaths)do hiddenAssets[path]=assert(assets[path]);assets[path]=nil end
local assetLoads={}
LoadAsset=function(path)
    assert(hiddenAssets[path],'recovery may load only exact known concussion feedback assets')
    assetLoads[path]=(assetLoads[path]or 0)+1
    assets[path]=hiddenAssets[path];return assets[path],true,true
end
activeShakes[shake1]=true;activeShakes[shake2]=true;ownedAudio=true
now=160;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
for _,path in ipairs(exactPaths)do assert(assetLoads[path]==1,'missing registry asset must use game-thread loader once')end
assert(not activeShakes[shake1]and not activeShakes[shake2]and not ownedAudio and activeShakes[normalShake]and foreignAudio)
for frame=1,99 do
    now=160+frame*.05;activeShakes[shake1]=true;activeShakes[shake2]=true
    assert(guard.updateRecovery(now,world,controller))
    assert(not activeShakes[shake1]and not activeShakes[shake2]and activeShakes[normalShake])
end
for _,path in ipairs(exactPaths)do assert(assetLoads[path]==1,'already valid classes/events must not reload per frame')end
now=165;assert(not guard.updateRecovery(now,world,controller))
print('PASS v45 registry misses soft-load only the two shipping generated shake classes and exact local Wwise event; cached assets do not reload per frame')

-- A Blueprint asset is not a TSubclassOf camera shake. Reject that loader result
-- instead of invoking an unrelated/wrong object or widening to all camera shakes.
local wrongBlueprint=object();function wrongBlueprint:GetFName()return FName('CamShakeConcussion')end
assets[exactPaths[1]]=wrongBlueprint
activeShakes[shake1]=true;activeShakes[shake2]=true
now=170;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(activeShakes[shake1]and not activeShakes[shake2]and activeShakes[normalShake])
assets[exactPaths[1]]=shake1
now=171;assert(guard.updateRecovery(now,world,controller)and not activeShakes[shake1])
now=175;assert(not guard.updateRecovery(now,world,controller))
print('PASS v45 generated-class identity rejects raw Blueprint assets and safely accepts later exact class availability')

-- Failed loads stay bounded inside the original five seconds, including audio.
for _,path in ipairs(exactPaths)do assets[path]=nil;assetLoads[path]=0 end
LoadAsset=function(path)
    assert(hiddenAssets[path]);assetLoads[path]=assetLoads[path]+1;return nil,false,false
end
now=180;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
for frame=1,99 do now=180+frame*.05;assert(guard.updateRecovery(now,world,controller))end
for _,path in ipairs(exactPaths)do assert(assetLoads[path]==3,'failed exact feedback loads are bounded to three attempts per recovery')end
now=185;assert(not guard.updateRecovery(now,world,controller))
for _,path in ipairs(exactPaths)do assert(assetLoads[path]==3);assets[path]=hiddenAssets[path]end
LoadAsset=nil
print('PASS v45 missing shake/event assets have bounded three-attempt loading and cannot extend recovery or touch unrelated assets')

-- v45 source regression: points remain alive behind a zero MPC shader input;
-- after a shader-only five-second mask ends the mechanics immediately recreates
-- suppression. The legitimate owned-pawn setter must remove that source.
function controller:GetWorld()return world end
function localPawn:GetWorld()return world end
local sourcePoints,sourceReads,sourceWrites=60,0,0
local hp=87;local hunger=.2;local unrelatedEffects={weather=true,bleeding=true}
function localPawn:GetCurrentSuppressionPoints()sourceReads=sourceReads+1;return sourcePoints end
function localPawn:SetCurrentSuppressionPoints(value)
    assert(value==0,'recovery source setter may only request zero suppression')
    sourceWrites=sourceWrites+1;sourcePoints=math.max(0,value)
end
local function mechanicsTick()
    values[suppressionIndex]=sourcePoints>0 and sourcePoints/100 or 0
    return values[suppressionIndex]
end
values[suppressionIndex]=0
assert(mechanicsTick()==.6,'points revive suppression even after a previous shader mask wrote zero')
now=190;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(sourcePoints==0 and sourceWrites==1 and mechanicsTick()==0,'source clear prevents mechanical pass from re-enabling on the next tick')
local countsBeforeZero=sourceWrites
now=190.01;guard.updateRecovery(now,world,controller)
assert(sourceWrites==countsBeforeZero,'an already zero source is not rewritten')
for frame=1,99 do
    sourcePoints=60;now=190+frame*.05
    assert(guard.updateRecovery(now,world,controller))
    assert(sourcePoints==0 and mechanicsTick()==0,'every game frame clears new suppression source during protection')
end
assert(sourceWrites==100 and hp==87 and hunger==.2 and unrelatedEffects.weather and unrelatedEffects.bleeding)
sourcePoints=60 -- A final hit arrives after the last protected update.
activeShakes[shake1]=true;activeShakes[shake2]=true
now=195;assert(not guard.updateRecovery(now,world,controller)and sourcePoints==0 and mechanicsTick()==0,
    'source baseline 60 must not replay at expiry, so old explosion cannot revive suppression')
assert(sourceWrites==101 and not activeShakes[shake1]and not activeShakes[shake2],
    'exact deadline must perform final same-owner source and shake cleanup before releasing scopes')
local endedWrites=sourceWrites
sourcePoints=35;now=195.01;guard.updateRecovery(now,world,controller)
assert(sourceWrites==endedWrites and sourcePoints==35 and mechanicsTick()==.35,'genuine later suppression resumes after protection')
print('PASS v45 clears actual accumulated suppression through the normal owned getter/setter, verifies zero, prevents next-tick mechanics revival and clears final between-frame source at exact expiry')

-- Member availability, finite values and successful zero readback are required;
-- unavailable or mismatched contexts never mutate a foreign player/source.
sourcePoints=55
local foreignPawn=object({GetWorld=function()return world end})
function foreignPawn:GetCurrentSuppressionPoints()error('foreign pawn getter must not be touched')end
function foreignPawn:SetCurrentSuppressionPoints()error('foreign pawn setter must not be touched')end
controller.Pawn=foreignPawn
now=200;assert(not guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(sourcePoints==55 and sourceWrites==endedWrites)
controller.Pawn=localPawn
local originalWorld=localPawn.GetWorld
function localPawn:GetWorld()return otherWorld end
now=210;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(sourcePoints==55 and sourceWrites==endedWrites,'a pawn from another world may not receive suppression writes')
guard.endRecovery();localPawn.GetWorld=originalWorld
local oldGetter,oldSetter=localPawn.GetCurrentSuppressionPoints,localPawn.SetCurrentSuppressionPoints
localPawn.SetCurrentSuppressionPoints=nil
local beforeUnavailable=sourceReads
now=220;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(sourceReads==beforeUnavailable and sourcePoints==55,'unavailable reflected pair is not partially read or written')
guard.endRecovery();localPawn.SetCurrentSuppressionPoints=oldSetter
function localPawn:GetCurrentSuppressionPoints()return 0/0 end
now=230;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(sourceWrites==endedWrites,'nonfinite getter data must not be sent into a native setter')
guard.endRecovery();localPawn.GetCurrentSuppressionPoints=oldGetter
local failedReadback=0
function localPawn:SetCurrentSuppressionPoints(value)assert(value==0);failedReadback=failedReadback+1 end
now=240;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
now=240.01;guard.updateRecovery(now,world,controller)
assert(failedReadback==1 and sourcePoints==55,'failed source zero readback must stop retries without claiming success')
guard.endRecovery();localPawn.SetCurrentSuppressionPoints=oldSetter
print('PASS v45 source ownership/world validation, unavailable reflection, finite reads and exact zero readback; HP/input/other effect state are not reset')

-- Timed composites and surface-explosion postFX are separate from suppression
-- points/MPC. A late 3s composite or 6.1s surface pass outlives the mask unless
-- normal effect removal executes against its actual source descriptor.
local sourceArms,sourceCalls,sourceDisarms,sourceActiveScope=0,0,0,false
local registry,foreignRegistry,removedDescriptors={},{},{}
local sourceFailure,sourceRejectArm
local sourceMatched,sourceRemoved=0,0
local cleanupSIDs={ConcussionComposite=true,ConcussionBlurPostProcess=true,ConcussionCameraShake=true,
    ConcussionComposite_Buttstock=true,ExplosionDirtPostProcess=true,ExplosionWaterPostProcess=true,
    ExplosionRockPostProcess=true,ExplosionWoodPostProcess=true,ExplosionSandPostProcess=true}
local function effect(sid,guid,kind,expires)
    return {sid=sid,sourceGUID=guid,sourceType=kind,expires=expires,active=true}
end
local function effectProcessorTick()
    for _,entry in ipairs(registry)do
        if entry.active and now<entry.expires then
            if entry.sid=='ConcussionComposite'or entry.sid=='ConcussionCameraShake'then activeShakes[shake1]=true end
        end
    end
end
local function normalSourceCleanup(limit)
    local selected=0
    for _,entry in ipairs(registry)do
        if selected<limit and entry.active and cleanupSIDs[entry.sid]then
            sourceMatched=sourceMatched+1;selected=selected+1
            -- The normal removal callback gets the *actual* effect descriptor,
            -- even an NPC/Explosion source enum and GUID.
            assert(entry.sourceGUID==777 and entry.sourceType==3,'do not substitute Other=6 or pawn GUID')
            entry.active=false;removedDescriptors[#removedDescriptors+1]=entry
            sourceRemoved=sourceRemoved+1
        end
    end
end
guard.nativeBridge={new=function()
    local reportedMatched,reportedRemoved=0,0
    return {
        concussionSourceArm=function(_,capturedPawn,capturedWorld)
            sourceArms=sourceArms+1
            assert(capturedPawn==localPawn and capturedWorld==world,'native source arm captures only the original local pawn/world')
            if sourceRejectArm then return false,'fixture pending processor'end
            sourceActiveScope=true;sourceMatched=0;sourceRemoved=0
            normalSourceCleanup(128)
            reportedMatched,reportedRemoved=sourceMatched,sourceRemoved
            return true,{matched=sourceMatched,removed=sourceRemoved}
        end,
        concussionSourceTick=function(_,dt,force)
            assert(sourceActiveScope and dt>=0);sourceCalls=sourceCalls+1
            if sourceFailure then return nil,'fixture expired/changed core identity'end
            normalSourceCleanup(force and 512 or 128)
            local out={matched=sourceMatched-reportedMatched,removed=sourceRemoved-reportedRemoved}
            reportedMatched,reportedRemoved=sourceMatched,sourceRemoved
            if force then assert(now>=250 and now%5==0,'deadline always requests final fresh source status')end
            return out,{matched=sourceMatched,removed=sourceRemoved}
        end,
        concussionSourceDisarm=function()sourceActiveScope=false;sourceDisarms=sourceDisarms+1;return true end,
    }
end}
registry={effect('ConcussionComposite',777,3,253),effect('ExplosionDirtPostProcess',777,3,256.1),
    effect('Bleeding',777,3,999),effect('WeatherRain',777,3,999)}
foreignRegistry={effect('ConcussionComposite',999,3,999)}
sourcePoints=60;now=250
assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
assert(sourceArms==1 and sourceCalls==1 and sourceActiveScope and sourcePoints==0)
assert(not registry[1].active and not registry[2].active and registry[3].active and registry[4].active and foreignRegistry[1].active)
for frame=1,99 do
    now=250+frame*.05
    registry[#registry+1]=effect('ConcussionCameraShake',777,3,now+3)
    registry[#registry+1]=effect('ExplosionRockPostProcess',777,3,now+6.1)
    effectProcessorTick()
    assert(guard.updateRecovery(now,world,controller))
    assert(not activeShakes[shake1]and registry[3].active and registry[4].active and foreignRegistry[1].active)
end
assert(sourceCalls==100 and sourceArms==1 and #removedDescriptors==200,'source clear runs each game frame under one fixed identity')
for i=1,300 do registry[#registry+1]=effect(i%2==0 and 'ConcussionComposite_Buttstock'or 'ExplosionSandPostProcess',777,3,261.09)end
local previousPrint,recoveryReport=print
print=function(text)
    if text:find('Concussion recovery finished:')then recoveryReport=text end
    previousPrint(text)
end
now=255;assert(not guard.updateRecovery(now,world,controller)and not sourceActiveScope)
print=previousPrint
assert(sourceCalls==101 and sourceDisarms==1 and #removedDescriptors==500,
    'final deadline clears late multi-charge composite/surface sources before disarming instead of restoring a hidden active pass')
assert(recoveryReport:find('nativeSourceMatched=500')and recoveryReport:find('nativeSourceRemoved=500'),
    'final diagnostics must include initial arm removals and exactly count actual descriptor retirement')
local afterDeadlineCalls=sourceCalls
registry[#registry+1]=effect('ConcussionComposite',777,3,259)
now=255.01;guard.updateRecovery(now,world,controller);effectProcessorTick()
assert(sourceCalls==afterDeadlineCalls and registry[#registry].active and activeShakes[shake1],
    'genuine new concussion effects are unrestricted after fixed five-second cleanup')
print('PASS v45 native source client clears actual source descriptors every protected game frame and at expiry; late 3s composite and 6.1s explosion passes cannot replay, three hundred final sources drain bounded cleanup and foreign/unrelated effects survive')

-- Cancellation must disarm, never perform a final cleanup on a replacement
-- pawn/world. A changed native core is fatal to the original capture, not a
-- reason to recapture that new identity during the old recovery window.
now=260;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
local callsBeforeCancel=sourceCalls;local armsBeforeCancel=sourceArms
controller.Pawn=foreignPawn
now=260.01;assert(not guard.updateRecovery(now,world,controller)and not sourceActiveScope and sourceCalls==callsBeforeCancel)
controller.Pawn=localPawn
now=265;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
callsBeforeCancel=sourceCalls
now=265.01;assert(not guard.updateRecovery(now,otherWorld,controller)and sourceCalls==callsBeforeCancel and not sourceActiveScope)
now=270;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
sourceFailure=true;armsBeforeCancel=sourceArms
now=270.01;assert(guard.updateRecovery(now,world,controller)and not sourceActiveScope)
for frame=1,90 do now=270.01+frame*.05;assert(guard.updateRecovery(now,world,controller))end
assert(sourceArms==armsBeforeCancel,'native core/lease failure must never recapture under the old recovery identity')
now=275;assert(not guard.updateRecovery(now,world,controller))
sourceFailure=nil
print('PASS v45 source cleanup cancels before any foreign pawn/world callback; native identity/lease loss disarms without rearming and preserves exact MPC/camera fallback')

sourceRejectArm=true
now=280;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
armsBeforeCancel=sourceArms
for frame=1,99 do now=280+frame*.05;assert(guard.updateRecovery(now,world,controller))end
assert(sourceArms-armsBeforeCancel==2,'initial unavailable processor retries at most three times within the original deadline')
now=285;assert(not guard.updateRecovery(now,world,controller))
sourceRejectArm=nil
now=290;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now)and sourceActiveScope)
local replacementFlight={world=world,pc=controller,pawn=localPawn,camera=newCamera}
now=291;guard.update(replacementFlight,now,nil)
assert(not sourceActiveScope and not guard.recoveryActive(),'new FPV releases old source cleanup before its replacement scope')
callsBeforeCancel=sourceCalls
now=295;guard.updateRecovery(now,world,controller)
assert(sourceCalls==callsBeforeCancel)
guard.restore(replacementFlight)
print('PASS v45 pending native source setup has bounded retries without extending five seconds; new FPV cancels source lease without an old deadline affecting the new flight')

-- Normal postFX removal owns its stop policy; the camera pass must already be
-- weight-zero while it is stopped. Actual cooked PPI/HDR parent identity plus
-- current local camera membership prove these independent blast passes.
guard.nativeBridge=nil
local blastParents,blastMIDs,blastBaseline={}, {}, {}
for _,surface in ipairs({'Water','Dirt','Rock','Wood','Sand'})do
    local leaf=surface=='Water'and 'MI_PP_WaterExplosive'or 'PPI_'..surface..'Explosive'
    for _,suffix in ipairs(surface=='Water'and {''}or {'','_HDR'})do
        local label=leaf..suffix
        local parent=asset('/Game/_Stalker_2/Materials/PostProcess/Explosive/'..label..'.'..label,label)
        local ownedMID=mid(parent,'Explosion'..surface..'Intensity',.78)
        blastParents[#blastParents+1]=parent;blastMIDs[#blastMIDs+1]=ownedMID
    end
end
local foreignBlast=mid(blastParents[2],'ExplosionDirtIntensity',1.18)
local foreignRows=otherComponent.PostProcessSettings.WeightedBlendables.Array
foreignRows[2]={Object=foreignBlast,Weight=.82}
local sourceRowCount=#rows
for i,ownedMID in ipairs(blastMIDs)do
    rows[#rows+1]={Object=ownedMID,Weight=.3+i*.02};blastBaseline[i]=rows[#rows].Weight
end
local firstBlastSlot=sourceRowCount+1
local preBlastScans=globalMIDScans
now=300;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
for i,ownedMID in ipairs(blastMIDs)do
    assert(rows[firstBlastSlot+i-1].Weight==0)
    local scalar=next(ownedMID.scalars);assert(ownedMID.scalars[scalar]==.78,
        'do not add a possibly unused MID scalar override or new MPC key while bypassing a known owned blast pass')
end
assert(foreignRows[2].Weight==.82 and foreignBlast.scalars[indices.ExplosionDirtIntensity]==1.18 and rows[5].Weight==.95)
assert(globalMIDScans==preBlastScans,'blast recovery must not scan global materials or postprocess volumes')
local lateBlast=mid(blastParents[2],'ExplosionDirtIntensity',.89)
rows[#rows+1]={Object=lateBlast,Weight=.77};local lateBlastSlot=#rows
now=300.01;assert(guard.updateRecovery(now,world,controller)and rows[lateBlastSlot].Weight==0)
local replacedMID=mid(blastParents[1],'ExplosionWaterIntensity',.64)
for frame=1,99 do
    now=300+frame*.05
    for i=1,#blastMIDs do rows[firstBlastSlot+i-1].Weight=.96 end
    rows[lateBlastSlot].Weight=.99
    assert(guard.updateRecovery(now,world,controller))
    for i=1,#blastMIDs do assert(rows[firstBlastSlot+i-1].Weight==0)end
    assert(rows[lateBlastSlot].Weight==0 and foreignRows[2].Weight==.82 and rows[5].Weight==.95)
end
-- A late ownership-independent row replacement may not receive an old lease's
-- restoration weight. It is captured and restored only as its own new row.
rows[firstBlastSlot]={Object=replacedMID,Weight=.66}
now=304.99;guard.updateRecovery(now,world,controller)
assert(rows[firstBlastSlot].Weight==0)
-- The existing first64 camera-stack bound must still apply to blast passes.
while #rows<64 do rows[#rows+1]={Object=weather,Weight=.1}end
local beyondBound=mid(blastParents[2],'ExplosionDirtIntensity',.44)
rows[65]={Object=beyondBound,Weight=.52}
now=305;assert(not guard.updateRecovery(now,world,controller))
assert(rows[firstBlastSlot].Weight==0 and rows[lateBlastSlot].Weight==0 and rows[65].Weight==.52)
for i=2,#blastMIDs do assert(rows[firstBlastSlot+i-1].Weight==0,'old explosion event weights must not replay at deadline')end
assert(foreignRows[2].Weight==.82 and foreignBlast.scalars[indices.ExplosionDirtIntensity]==1.18 and rows[5].Weight==.95)
rows[firstBlastSlot].Weight=.91;now=305.01;guard.updateRecovery(now,world,controller)
assert(rows[firstBlastSlot].Weight==.91,'new genuine blast pass weights resume after the fixed deadline')
for i=#rows,sourceRowCount+1,-1 do rows[i]=nil end
foreignRows[2]=nil
print('PASS v46 owned nine cooked explosion PPI/HDR pass bypass, late pass/write correction and final old-event weight retirement, no scalar/MPC additions or global scans, foreign stacks/weather unchanged and replacement-safe bounded cleanup')

-- v46: native-created camera MIDs can parent the actual cooked master directly,
-- rather than the configured PPI/HDR leaf. Exact full asset identity must still
-- reject an unrelated asset that merely shares the same short FName.
local masterPath='/Game/_Stalker_2/Materials/PostProcess/Explosive/'
local dirtMaster=asset(masterPath..'PPM_Explosive.PPM_Explosive','PPM_Explosive')
local waterMaster=asset(masterPath..'M_PP_ExplosiveWater.M_PP_ExplosiveWater','M_PP_ExplosiveWater')
local directDirt=mid(dirtMaster,'BlurStrength',.85)
local directWater=mid(waterMaster,'BlurStrength',.72)
local wrappedDirt=mid(mid(dirtMaster,'BlurStrength',.39),'BlurStrength',.62)
local impostor=asset('/Game/Weather/PPM_Explosive.PPM_Explosive','PPM_Explosive')
local weatherImpostor=mid(impostor,'BlurStrength',.51)
local foreignMaster=mid(dirtMaster,'BlurStrength',.95)
local foreignMasterRows=otherComponent.PostProcessSettings.WeightedBlendables.Array
foreignMasterRows[2]={Object=foreignMaster,Weight=.88}
local masterSlots={}
for _,value in ipairs({directDirt,directWater,wrappedDirt,dirtMaster,weatherImpostor})do
    rows[#rows+1]={Object=value,Weight=.75};masterSlots[#masterSlots+1]=#rows
end
local scansBeforeMaster=globalMIDScans;local writesBeforeMaster=#writes
now=310;assert(guard.beginRecovery({world=world,pc=controller,pawn=localPawn},now))
for i=1,4 do assert(rows[masterSlots[i]].Weight==0,'exact owned direct/wrapped blast master must be hidden immediately')end
assert(rows[masterSlots[5]].Weight==.75 and foreignMasterRows[2].Weight==.88 and rows[5].Weight==.95)
assert(directDirt.scalars[indices.BlurStrength]==.85 and directWater.scalars[indices.BlurStrength]==.72,
    'master classifier must not invent a MID scalar or change the original material amplitude')
local lateMaster=mid(dirtMaster,'BlurStrength',.98)
rows[#rows+1]={Object=lateMaster,Weight=.69};local lateMasterSlot=#rows
now=314.99;assert(guard.updateRecovery(now,world,controller)and rows[lateMasterSlot].Weight==0)
for i=1,4 do rows[masterSlots[i]].Weight=.94 end
now=315;assert(not guard.updateRecovery(now,world,controller))
for i=1,4 do assert(rows[masterSlots[i]].Weight==0,'captured positive blast weights must not replay old dirt after five seconds')end
assert(rows[lateMasterSlot].Weight==0 and rows[masterSlots[5]].Weight==.75 and foreignMasterRows[2].Weight==.88)
for i=writesBeforeMaster+1,#writes do
    assert(writes[i].index==concussionIndex or writes[i].index==suppressionIndex,'blast classifier must not add MPC scalar keys')
end
assert(globalMIDScans==scansBeforeMaster)
rows[masterSlots[1]].Weight=.92;now=315.01;guard.updateRecovery(now,world,controller)
assert(rows[masterSlots[1]].Weight==.92,'new genuine blast writes must resume at fixed deadline')
for i=#rows,sourceRowCount+1,-1 do rows[i]=nil end
foreignMasterRows[2]=nil
print('PASS v46 exact two cooked blast masters: direct parent, wrapped MID and master asset bypass in owned local camera only; late dirt bypass and fixed five-second cleanup; same-name weather/foreign camera preserved, no scalar/MPC/global scans and genuine later writes resume')
