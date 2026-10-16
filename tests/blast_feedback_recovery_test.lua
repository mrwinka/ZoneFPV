-- Real failure shape: source retirement succeeds, but the renderer reads a
-- retained Explosion* MPC scalar and no owned CameraComponent contains a pass.
local guard=dofile('mod/Scripts/visual_guard.lua')
local id=0
local function object(fields)
    id=id+1;local o=fields or {};o.id=id*16
    function o:IsValid()return not self.invalid end
    function o:GetAddress()assert(not self.invalid);return self.id end
    return o
end
local indices,nextIndex={},0
FName=setmetatable({},{__call=function(_,text)
    if not indices[text]then nextIndex=nextIndex+1;indices[text]=nextIndex end
    return {GetComparisonIndex=function()return indices[text]end}
end})
local blastNames={'ExplosionWaterIntensity','ExplosionDirtIntensity','ExplosionRockIntensity','ExplosionWoodIntensity','ExplosionSandIntensity'}
local allowed={}
for _,key in ipairs({'ConcussionIntensity','SuppressionIntensity'})do allowed[FName(key):GetComparisonIndex()]=true end
for _,key in ipairs(blastNames)do allowed[FName(key):GetComparisonIndex()]=true end
local world,otherWorld=object(),object()
local cm=object({StopAllInstancesOfCameraShake=function()error('missing classes must not be loaded')end})
local pawn=object({GetWorld=function()return world end})
local pc=object({Pawn=pawn,PlayerCameraManager=cm,GetWorld=function()return world end})
local rows={GetArrayNum=function(self)return #self end}
local camera=object({PostProcessSettings={WeightedBlendables={Array=rows}}})
local cameraManager=object({PlayerCameraManager=cm,CameraComponent=camera})
local collection,library=object(),object()
local values,writes={},{}
local gate,gateWorld,gateCollection,armCount,disarms={},nil,nil,0,0
local staleScalarSourceRemoved=false
local nativeMode='seven'
local unsupported=0
guard.nativeBridge={new=function()
    return {
        concussionArm=function(_,w,asset,primary,number,secondary,secondaryNumber,blast)
            assert(w==world and asset==collection and number==0 and secondaryNumber==0)
            if blast and nativeMode=='legacy'then unsupported=unsupported+1;return false,'native blast scope unsupported'end
            assert(blast==nil or #blast==5)
            gate={[primary]=true,[secondary]=true};for _,key in ipairs(blast or {})do gate[key]=true end
            gateWorld=w;gateCollection=asset;armCount=armCount+1
            return true,{blastScope=blast~=nil}
        end,
        concussionTick=function()return 0,{}end,
        concussionDisarm=function()gate={};disarms=disarms+1;return true end,
        concussionSourceArm=function(_,p,w)
            assert(p==pawn and w==world);staleScalarSourceRemoved=true
            -- Normal effect callbacks stop the source, but the previous shader
            -- amplitude is still nonzero until explicitly corrected.
            return true,{matched=1,removed=1}
        end,
        concussionSourceTick=function()return {matched=0,removed=0}end,
        concussionSourceDisarm=function()return true end,
    }
end}
function library:GetScalarParameterValue(w,asset,name)
    assert(w==world and asset==collection);return values[name:GetComparisonIndex()]or 0
end
function library:SetScalarParameterValue(w,asset,name,value)
    assert(w==world and asset==collection)
    local key=name:GetComparisonIndex()
    assert(allowed[key],'unrelated weather/blood/vision inputs may never be cleared')
    writes[#writes+1]={key=key,value=value}
    if gateWorld==w and gateCollection==asset and gate[key]then value=0 end
    values[key]=value
end
local extraAssets={}
StaticFindObject=function(path)
    if path=='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'then return collection end
    if path=='/Script/Engine.Default__KismetMaterialLibrary'then return library end
    return extraAssets[path]
end
local scans=0
FindAllOf=function(class)
    assert(class=='CameraManager','recovery cannot scan global materials/volumes')
    scans=scans+1;return {cameraManager}
end
LoadAsset=function()error('no blocking loads during exit recovery')end
local rain=FName('RainIntensity'):GetComparisonIndex()
local blood=FName('DamageBloodIntensity'):GetComparisonIndex()
values[rain]=.42;values[blood]=.38
local function blast(value)
    for _,key in ipairs(blastNames)do values[indices[key]]=value end
end
local function clear()
    for _,key in ipairs(blastNames)do assert(values[indices[key]]==0,key..' dirt must not remain rendered')end
end
blast(.91)
local flight={world=world,pc=pc,pawn=pawn,camera=object({CameraComponent=camera})}
guard.update(flight,9.99)
assert(armCount==1 and gate[indices.ExplosionDirtIntensity])
assert(guard.beginRecovery(flight,10))
assert(staleScalarSourceRemoved and armCount==1 and scans==1,
    'transferred flight retains its seven-key native protection without a downgrade or rearm')
clear()
assert(values[rain]==.42 and values[blood]==.38)
for step=1,99 do
    local now=10+step*.05
    assert(guard.updateRecovery(now,world,pc))
    -- Native writes happen after the Lua tick and before rendering. All five
    -- must be zero, not one frame late, even without any blendable membership.
    for _,key in ipairs(blastNames)do library:SetScalarParameterValue(world,collection,FName(key),.81)end
    clear()
end
blast(.99) -- Last source write arrives just before exact deadline.
assert(not guard.updateRecovery(15,world,pc));clear()
assert(not guard.recoveryActive()and disarms==1)
for _,key in ipairs(blastNames)do library:SetScalarParameterValue(world,collection,FName(key),.53)end
guard.updateRecovery(15.01,world,pc)
for _,key in ipairs(blastNames)do assert(values[indices[key]]==.53,'genuine later explosion must render normally')end
assert(values[rain]==.42 and values[blood]==.38 and scans==1)
print('PASS independent actual blast MPC survives source retirement/no camera pass; all5 retained and late-after-Lua amplitudes clear under exact7 scope, fixed5s deadline has final correction, future explosions/weather/blood remain game-owned, no blocking loads or global scans')

-- A legacy DLL is a declared fallback, never false seven-key native success.
nativeMode='legacy';blast(.7)
assert(guard.beginRecovery({world=world,pc=pc,pawn=pawn},20));clear()
assert(unsupported==1 and not gate[indices.ExplosionDirtIntensity])
for step=1,20 do blast(.6);assert(guard.updateRecovery(20+step*.1,world,pc));clear()end
assert(unsupported==1,'missing capability is not reprobed/rearmed every frame')
local beforeWrites=#writes
pc.Pawn=object({GetWorld=function()return world end})
assert(not guard.updateRecovery(22.1,world,pc)and #writes==beforeWrites,'new possession cannot receive old recovery writes')
pc.Pawn=pawn
nativeMode='seven';assert(guard.beginRecovery({world=world,pc=pc,pawn=pawn},30));blast(.8)
beforeWrites=#writes
assert(not guard.updateRecovery(30.1,otherWorld,pc)and #writes==beforeWrites)
for _,key in ipairs(blastNames)do assert(values[indices[key]]==.8,'world change cancels before scalar cleanup')end
print('PASS old DLL explicitly retains dual gate plus five exact Lua corrections without repeated unsupported arms; pawn/world replacement cancels before any scalar writes')

-- Runtime regression: cancelling recovery on immediate re-entry used to
-- restore a saved positive blast weight and downgrade native7 back to2.
local parent=object({GetFName=function()return FName('PPI_RockExplosive')end})
extraAssets['/Game/_Stalker_2/Materials/PostProcess/Explosive/PPI_RockExplosive.PPI_RockExplosive']=parent
local pass=object({Parent=parent})
rows[1]={Object=pass,Weight=.83}
blast(.94)
local beforeCancelFlight={world=world,pc=pc,pawn=pawn,camera=object({CameraComponent=camera})}
guard.update(beforeCancelFlight,40)
assert(gate[indices.ExplosionRockIntensity]);clear()
assert(guard.beginRecovery(beforeCancelFlight,40.1)and rows[1].Weight==0)
local repeatFlight={world=world,pc=pc,pawn=pawn,camera=object({CameraComponent=camera})}
guard.update(repeatFlight,40.2)
assert(not guard.recoveryActive()and rows[1].Weight==0 and gate[indices.ExplosionRockIntensity],
    'early cancel must neither replay old pass weights nor downgrade to a dual MPC gate')
for step=1,20 do
    guard.update(repeatFlight,40.2+step*.05)
    for _,key in ipairs(blastNames)do library:SetScalarParameterValue(world,collection,FName(key),.97)end
    clear()
end
assert(guard.beginRecovery(repeatFlight,41.3));clear()
assert(not guard.updateRecovery(46.3,world,pc));clear()
rows[1].Weight=.71
library:SetScalarParameterValue(world,collection,FName('ExplosionRockIntensity'),.69)
assert(rows[1].Weight==.71 and values[indices.ExplosionRockIntensity]==.69,
    'after a full new recovery, no old baseline returns and a genuinely later game blast remains enabled')
print('PASS FPV->recovery->immediate FPV->recovery retains7 exact parameters, never restores old positive blast weights/baselines on cancel, ends at fixed deadline and permits a subsequent genuine player explosion')
