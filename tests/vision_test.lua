local vision=dofile('mod/Scripts/vision.lua')
local settings=dofile('mod/Scripts/vision_settings.lua')
local nextId=0
local function object(fields)
    nextId=nextId+1;local o=fields or {};o.id=nextId;o.alive=true
    function o:IsValid()return self.alive end
    function o:GetAddress()return self.id end
    function o:type()return 'UObject'end
    return o
end
local function array(values)
    local data=values or {}
    return setmetatable({}, {__len=function()return #data end,
        __index=function(_,key)
            if key=='GetArrayNum' then return function()return #data end end
            if key=='Empty' then return function()data={}end end
            return data[key]
        end,__newindex=function(_,key,value)
            assert(type(key)=='number' and key>=1)
            -- Mirror UE4SS struct setters: missing/nil fields retain existing
            -- storage. Nulling a native Object requires its direct setter.
            local row=data[key] or {Weight=0}
            for field,v in pairs(value)do row[field]=v end
            data[key]=row
        end})
end
local function vec(v)return {X=v,Y=v+.1,Z=v+.2,W=v+.3}end
local function clone(v)local r={};for k,x in pairs(v)do r[k]=type(x)=='table' and clone(x) or x end;return r end
local null=object();null.alive=false;null.id=0
local world=object();local logs={};local loaded={};local materials={};local lutClients={}
local rendering=object();local materialLibrary=object()
function materialLibrary:CreateDynamicMaterialInstance(ctx,parent,name,flags)
    assert(ctx==world and (parent==loaded[vision.assets.silhouette.path] or parent==loaded[vision.assets.emissive_fallback.path] or parent==loaded[vision.assets.uniform_emissive.path]) and flags==0)
    local mid=object({parameters={}})
    function mid:SetVectorParameterValue(key,value)self.parameters[key]=value end
    function mid:SetScalarParameterValue(key,value)self.parameters[key]=value end
    function mid:K2_GetVectorParameterValue(key)return self.parameters[key]end
    function mid:K2_GetScalarParameterValue(key)return self.parameters[key]end
    function mid:SetTextureParameterValue(key,value)self.parameters[key]=value end
    function mid:K2_GetTextureParameterValue(key)return self.parameters[key]end
    materials[#materials+1]=mid;return mid
end
loaded['/Script/Engine.Default__KismetRenderingLibrary']=rendering
loaded['/Script/Engine.Default__KismetMaterialLibrary']=materialLibrary
loaded[vision.assets.silhouette.path]=object()
loaded[vision.assets.emissive_fallback.path]=object()
loaded[vision.assets.silhouette.white_texture]=object()
loaded['/Script/Engine.MeshComponent']=object()
StaticFindObject=function(path)return loaded[path] or null end
LoadAsset=function(path)return loaded[path] or null end
FName=function(name)return name end
FindAllOf=function()error('vision may not perform global object searches')end
vision.clock=function()return 0 end
vision.lut={new=function(ctx,library)
    assert(ctx==world and library==rendering)
    local client={updates=0,destroyed=0,entries={}}
    function client:texture(mode)
        self.mode=mode
        local e=self.entries[mode] or {updates=0};self.entries[mode]=e
        if e.updates>=3 then return e.rt,'ready'end
        return nil,'pending',e.rt
    end
    function client:update()
        self.updates=self.updates+1
        local e=self.entries[self.mode];e.updates=e.updates+1;e.rt=e.rt or object();self.rt=e.rt
        if self.failure then return nil,'test LUT failure'end
        return e.updates>=3,e.updates>=3 and 'ready' or 'pending'
    end
    function client:destroy()self.destroyed=self.destroyed+1 end
    lutClients[#lutClients+1]=client;return client
end}
local vectorKeys={'ColorSaturation','ColorContrast','ColorGamma','ColorGain'}
local scalarKeys={'AutoExposureBias','BloomIntensity','MotionBlurAmount','SceneFringeIntensity','ColorGradingIntensity'}
local function session(originalLUT)
    local pp={ColorGradingLUT=originalLUT or null,WeightedBlendables={Array=array({{Weight=1,Object=object()}})}}
    local original={}
    for i,key in ipairs(vectorKeys)do pp[key]=vec(i+.2);pp['bOverride_'..key]=i%2==0;original[key]=clone(pp[key]);original['bOverride_'..key]=pp['bOverride_'..key]end
    for i,key in ipairs(scalarKeys)do pp[key]=i+.7;pp['bOverride_'..key]=i%2==0;original[key]=pp[key];original['bOverride_'..key]=pp['bOverride_'..key]end
    pp.bOverride_ColorGradingLUT=false
    local component=object({PostProcessSettings=pp,PostProcessBlendWeight=.37})
    local other=object({PostProcessSettings={AutoExposureBias=.75},PostProcessBlendWeight=.9})
    local s={world=world,pawn=object(),camera=object({CameraComponent=component}),
        playerCamera=other,flight={p={x=0,y=0,z=0}},worldExperiments={entries={}}}
    return s,pp,original,component,other
end
local function addActor(s,opts)
    opts=opts or {};local mesh=object({slots={},writes=0});local originals={}
    local sourceMaterials={}
    for slot=0,(opts.slots or 3)-1 do
        originals[slot]=object({BlendMode=0});mesh.slots[slot]=originals[slot]
        sourceMaterials[slot+1]={MaterialInterface=originals[slot]}
    end
    local asset=object({Materials=array(sourceMaterials)})
    function mesh:GetSkinnedAsset()return opts.renderer~='static' and opts.renderer~='groom' and asset or null end
    if opts.renderer=='static' then mesh.StaticMesh=asset end
    if opts.name then function mesh:GetFullName()return opts.name end end
    function mesh:GetNumMaterials()return opts.slots or 3 end
    function mesh:GetMaterial(slot)return self.slots[slot]end
    function mesh:SetMaterial(slot,material)self.writes=self.writes+1;self.slots[slot]=material end
    local actor=opts.actor or object({Mesh=mesh})
    function actor:GetWorld()return opts.world or world end
    local entry={actor=actor,type=opts.type or 1,expired=opts.expired,position={X=opts.x or 0,Y=0,Z=0}}
    s.worldExperiments.entries[#s.worldExperiments.entries+1]=entry
    return mesh,originals,entry
end
local function verifyOriginal(pp,original)
    for _,key in ipairs(vectorKeys)do
        for _,axis in ipairs({'X','Y','Z','W'})do assert(pp[key][axis]==original[key][axis],key..'.'..axis..' must restore')end
        assert(pp['bOverride_'..key]==original['bOverride_'..key])
    end
    for _,key in ipairs(scalarKeys)do assert(pp[key]==original[key] and pp['bOverride_'..key]==original['bOverride_'..key])end
end
local function log(text)logs[#logs+1]=text end
local function finiteSensorRadiance(value)
    -- Check the value actually sent to the material, with three stops of
    -- exposure headroom. This is a numeric HDR bound, not a renderer mock.
    local halfMax=(2-2^-10)*2^15
    assert(type(value)=='number' and value==value and value>0 and value*8<=halfMax,
        'sensor emission must leave finite FP16 exposure headroom')
end

local function run(s,frames,start)
    for frame=1,frames or 5 do vision.update(s,(start or 0)+frame/60)end
end
local function ready(s,mode)
    assert(vision.apply(s,mode,log));run(s,5)
    assert(s.vision and s.vision.activeMode==mode,'requested camera mode must commit')
end
local s,pp,original,camera,other=session()
assert(vision.apply(s,6,log))
verifyOriginal(pp,original)
assert(camera.PostProcessBlendWeight==.37 and not s.vision.material,'pending first mode must keep the existing image and materials')
vision.update(s,0)
local activeLUT=lutClients[#lutClients]
assert(pp.ColorGradingLUT==null and pp.ColorGradingIntensity==original.ColorGradingIntensity)
local pendingPinned=false
for i=1,#pp.WeightedBlendables.Array do if pp.WeightedBlendables.Array[i].Object==activeLUT.rt then pendingPinned=true end end
assert(pendingPinned,'pending texture needs a real engine reference without replacing the active LUT')
run(s,3)
assert(pp.ColorGradingIntensity==1 and pp.ColorGradingLUT==activeLUT.rt and s.vision.activeMode==6)
local firstLUT=activeLUT.rt;local firstMaterial=s.vision.material
assert(s.vision.materialSpec==vision.assets.emissive_fallback and vision.TARGET_EMISSION>1000)
assert(firstMaterial.parameters.CoilsHeatValue==1 and firstMaterial.parameters.Korshunov_EmissiveMult==vision.TARGET_EMISSION)
finiteSensorRadiance(firstMaterial.parameters.Korshunov_EmissiveMult)
assert(firstMaterial.parameters.BaseColorTexture==nil,'primary emitter must avoid the sampled glTF base-color path')
assert(vision.apply(s,4,log));vision.update(s,1)
assert(pp.ColorGradingLUT==firstLUT and s.vision.activeMode==6,'previous complete palette stays visible while the next builds')
run(s,3,1);assert(s.vision.activeMode==4 and pp.ColorGradingLUT~=firstLUT)
local allocations=#lutClients
assert(vision.apply(s,6,log) and s.vision.activeMode==6 and pp.ColorGradingLUT==firstLUT)
assert(#lutClients==allocations and s.vision.material==firstMaterial,'cached mode switch must reuse LUT and material')
assert(other.PostProcessSettings.AutoExposureBias==.75 and other.PostProcessBlendWeight==.9)
vision.restore(s)
assert(not s.vision and activeLUT.destroyed==1 and camera.PostProcessBlendWeight==.37)
assert(pp.ColorGradingLUT==nil and #pp.WeightedBlendables.Array==1);verifyOriginal(pp,original)
print('PASS atomic palette activation, previous image retained, real pending roots and per-flight bounded mode cache')

local emitterParent=loaded[vision.assets.emissive_fallback.path]
emitterParent.alive=false;loaded[vision.assets.emissive_fallback.path]=nil
s,pp,original,camera=session();ready(s,6)
assert(s.vision.materialSpec==vision.assets.silhouette)
assert(s.vision.material.parameters.BaseColorFactor.R==vision.TARGET_EMISSION
 and s.vision.material.parameters.BaseColorTexture==loaded[vision.assets.silhouette.white_texture])
for _,axis in ipairs({'R','G','B'})do finiteSensorRadiance(s.vision.material.parameters.BaseColorFactor[axis])end
vision.restore(s);assert(#pp.WeightedBlendables.Array==1)
emitterParent.alive=true;loaded[vision.assets.emissive_fallback.path]=emitterParent
print('PASS unavailable texture-free emitter falls back to verified glTF colour/white-texture parameters')

s,pp,original,camera=session(object())
local eligible={}
for _=1,40 do local mesh,originals,entry=addActor(s);eligible[#eligible+1]={mesh=mesh,originals=originals,entry=entry}end
local wrongWorld=addActor(s,{world=object()});local far=addActor(s,{x=10001})
local expired=addActor(s,{expired=true});local artifact=addActor(s,{type=3});local player=addActor(s,{actor=s.pawn})
ready(s,6);run(s,65)
assert(#s.vision.meshOrder==40 and s.vision.stats.slots==120)
for _,row in ipairs(eligible)do for _,v in pairs(row.mesh.slots)do assert(v==s.vision.material)end end
assert(wrongWorld.writes==0 and far.writes==0 and expired.writes==0 and artifact.writes==0 and player.writes==0)
local originalTexture=pp.ColorGradingLUT
local foreign=object();eligible[1].mesh.slots[1]=foreign
run(s,40,2)
assert(eligible[1].mesh.slots[1]==s.vision.material and s.vision.stats.reapplied==1,'game appearance replacements must be re-applied')
assert(not vision.apply(s,16,log) and pp.ColorGradingLUT==originalTexture)
ready(s,2)
for _,row in ipairs(eligible)do
 for slot,v in pairs(row.originals)do assert(row.mesh.slots[slot]==(row==eligible[1] and slot==1 and foreign or v))end
end
assert(#s.vision.meshOrder==0,'passive IR restores all target components')
vision.restore(s);assert(#pp.WeightedBlendables.Array==1);verifyOriginal(pp,original)
print('PASS 40 actors, verified slots, world/range/type isolation, appearance changes and passive-mode restoration')

s,pp,original,camera=session()
local body,bodyOriginal,person=addActor(s,{slots=6})
local head,headOriginal,headEntry=addActor(s,{slots=4});headEntry.type=3
local armour,armourOriginal,armourEntry=addActor(s,{slots=2});armourEntry.type=3
local mutant,mutantOriginal,mutantEntry=addActor(s,{type=2,slots=5});mutantEntry.actor.Mesh=nil
-- Hidden body parts become visible later when the appearance/LOD system swaps.
head.bVisible=false;head.bHiddenInGame=true
body.bAffectDynamicIndirectLighting=true
function body:SetAffectDynamicIndirectLighting(value)self.bAffectDynamicIndirectLighting=value end
function person.actor:K2_GetComponentsByClass(class)
 assert(class==loaded['/Script/Engine.MeshComponent'])
 return {body,{type=function()return 'RemoteUnrealParam'end,get=function()return head end},body}
end
function person.actor:GetAttachedActors(out,reset,recursive)assert(reset and recursive);out[1]=armourEntry.actor end
function armourEntry.actor:K2_GetComponentsByClass()return {armour}end
function mutantEntry.actor:K2_GetComponentsByClass()return {mutant}end
ready(s,6);run(s,8)
assert(head.writes==0,'hidden LOD parts must retain their original materials')
head.bVisible=true;head.bHiddenInGame=false;run(s,70,1)
for _,mesh in ipairs({body,head,armour,mutant})do for _,v in pairs(mesh.slots)do assert(v==s.vision.material)end end
assert(#s.vision.meshOrder==4 and s.vision.actorCount==2 and body.bAffectDynamicIndirectLighting==false)
local materialCount,clientCount=#materials,#lutClients
for _=1,100 do assert(vision.apply(s,6,log))end
assert(#materials==materialCount and #lutClients==clientCount)
vision.restore(s)
for i,mesh in ipairs({body,head,armour,mutant})do
 for slot,v in pairs(({bodyOriginal,headOriginal,armourOriginal,mutantOriginal})[i])do assert(mesh.slots[slot]==v)end
end
assert(body.bAffectDynamicIndirectLighting==true and #pp.WeightedBlendables.Array==1)
print('PASS modular/attached meshes, newly visible LOD components, reflected wrappers and indirect-light restoration')

s,pp,original,camera=session()
local treeBody,treeOriginal,treeEntry=addActor(s,{slots=2})
local jacket,jacketOriginal,jacketEntry=addActor(s,{slots=3,type=3})
local belt,beltOriginal,beltEntry=addActor(s,{slots=1,type=3})
local forbidden,_,forbiddenEntry=addActor(s,{slots=1,actor=s.pawn})
local root=object();treeEntry.actor.RootComponent=root
-- These generated components are attached to the NPC tree but owned by
-- actors omitted from GetAttachedActors and the NPC's owned mesh list.
function treeEntry.actor:K2_GetComponentsByClass()return {treeBody}end
function treeEntry.actor:GetAttachedActors()return {}end
function root:GetNumChildrenComponents()return 1 end
function root:GetChildComponent(index)assert(index==0);return treeBody end
function treeBody:GetNumChildrenComponents()return 2 end
function treeBody:GetChildComponent(index)return ({jacket,forbidden})[index+1]end
function jacket:GetNumChildrenComponents()return 1 end
function jacket:GetChildComponent(index)assert(index==0);return {type=function()return 'RemoteUnrealParam'end,get=function()return belt end}end
function belt:GetNumChildrenComponents()return 1 end
function belt:GetChildComponent(index)assert(index==0);return treeBody end -- malformed cycle stays bounded
function jacket:GetOwner()return jacketEntry.actor end
function belt:GetOwner()return beltEntry.actor end
function forbidden:GetOwner()return s.pawn end
ready(s,6)
for _,mesh in ipairs({treeBody,jacket,belt})do for _,material in pairs(mesh.slots)do assert(material==s.vision.material)end end
assert(forbidden.writes==0 and #s.vision.meshOrder==3 and s.vision.stats.attachments==2)
local treeMIDs=#materials
run(s,120,1);assert(#materials==treeMIDs and s.vision.stats.attachments==2)
vision.restore(s)
for i,mesh in ipairs({treeBody,jacket,belt})do
 for slot,material in pairs(({treeOriginal,jacketOriginal,beltOriginal})[i])do assert(mesh.slots[slot]==material)end
end
assert(#pp.WeightedBlendables.Array==1)
print('PASS bounded zero-based component attachment tree, separate clothing owners, cycles and player exclusion')

s,pp,original,camera=session()
local growing,growingOriginal=addActor(s,{slots=1})
local slotCount=1
function growing:GetNumMaterials()return slotCount end
ready(s,6)
local late=object();slotCount=3;growing.slots[1]=late;growing.slots[2]=null
growing:GetSkinnedAsset().Materials[2]={MaterialInterface=late}
growing:GetSkinnedAsset().Materials[3]={MaterialInterface=object({BlendMode=0})}
run(s,20,1)
assert(growing.slots[0]==s.vision.material and growing.slots[1]==s.vision.material and growing.slots[2]==s.vision.material)
assert(s.vision.stats.lateSlots==2 and s.vision.stats.nullSlots==1 and s.vision.stats.slots==3)
local lateMaterials=#materials
run(s,120,2);assert(#materials==lateMaterials and s.vision.stats.lateSlots==2)
-- A genuine null material update must be re-applied and restored as null.
growing.slots[0]=nil;run(s,20,5)
assert(growing.slots[0]==s.vision.material)
-- Failure to read a slot must not replace its retained original with null.
local getGrowing=growing.GetMaterial
function growing:GetMaterial(slot)if slot==1 then error('streaming read failure')end;return getGrowing(self,slot)end
run(s,20,6)
growing.GetMaterial=getGrowing
vision.restore(s)
assert(growing.slots[0]==nil and growing.slots[1]==late and growing.slots[2]==nil)
assert(#pp.WeightedBlendables.Array==1)
print('PASS late outfit slots, null/default materials, failed native reads and exact null restoration without MID growth')

s,pp,original,camera=session()
local physical,physicalOriginal=addActor(s,{slots=4})
physical.slots[1].BlendMode=1 -- a real masked outfit must still be hot
physical.slots[2].BlendMode=2 -- optical shell/card must retain transparency
physical.slots[3]=null
physical:GetSkinnedAsset().Materials[4].MaterialInterface.BlendMode=1
local weapon,weaponOriginal=addActor(s,{renderer='static',name='NPC:CharacterMesh0:WeaponInHandsMesh:WeaponAttachmentSM_wpn_obrez_SM_pin'})
weapon.slots[0]=null
local hair,hairOriginal=addActor(s,{renderer='groom',name='NPC:SK_fac_30_25:GroomComponent'})
local arrow,arrowOriginal=addActor(s,{renderer='static',name='NPC:LookAtDirectionArrow'})
local shadow,shadowOriginal=addActor(s,{name='NPC:ShadowBody'});shadow.bRenderInMainPass=false
ready(s,6)
assert(physical.slots[0]==s.vision.material and physical.slots[1]==s.vision.material)
assert(physical.slots[2]==physicalOriginal[2] and physical.slots[3]==null)
for _,mesh in ipairs({weapon,hair,arrow,shadow})do assert(mesh.writes==0)end
assert(s.vision.stats.slots==2 and s.vision.stats.nullSlots==0 and s.vision.targetMIDCount==0)
-- A disappearing surface remains empty; a later genuine opaque material
-- becomes eligible again without replacing the rest of the outfit.
physical.slots[0]=null;physical:GetSkinnedAsset().Materials[1].MaterialInterface=object({BlendMode=1})
run(s,20,1);assert(physical.slots[0]==null)
local rebuilt=object({BlendMode=0});physical.slots[0]=rebuilt
run(s,20,2);assert(physical.slots[0]==s.vision.material)
physical.bHiddenInGame=true;run(s,20,3)
assert(physical.slots[0]==rebuilt and physical.slots[1]==physicalOriginal[1] and #s.vision.meshOrder==0)
physical.bHiddenInGame=false;run(s,70,4)
assert(physical.slots[0]==s.vision.material and physical.slots[1]==s.vision.material)
vision.restore(s)
assert(physical.slots[0]==rebuilt and physical.slots[1]==physicalOriginal[1] and physical.slots[3]==null)
assert(#pp.WeightedBlendables.Array==1)
print('PASS physical body/masked clothing, helper/weapon/groom/optical exclusions, empty sections and visibility changes')

s,pp,original,camera=session()
local beamBody,beamBodyOriginal,beamPerson=addActor(s)
local actualBeam,actualBeamOriginal=addActor(s,{type=3,slots=1,renderer='static',name='NPC:AdditionalMesh_001'})
local materialBeam,materialBeamOriginal=addActor(s,{type=3,slots=1,renderer='static',name='NPC:AdditionalMesh_002'})
materialBeam.slots[0].BlendMode=1
materialBeam.slots[0].GetFullName=function()return '/Game/_Stalker_2/VFX/Environment/light/M_FakeFlashLight_Mesh' end
local flashlight=object({FakeLightBeamComponent=actualBeam})
local flashlightClass=object();loaded['/Script/Stalker2.FlashlightComponent']=flashlightClass
function beamPerson.actor:K2_GetComponentsByClass(class)
 if class==flashlightClass then return {flashlight}end
 assert(class==loaded['/Script/Engine.MeshComponent']);return {beamBody,actualBeam,materialBeam}
end
ready(s,6)
assert(actualBeam.writes==0 and materialBeam.writes==0 and s.vision.beamMeshes[actualBeam:GetAddress()]==actualBeam)
for _,material in pairs(beamBody.slots)do assert(material==s.vision.material)end
run(s,120,1);assert(actualBeam.writes==0 and materialBeam.writes==0 and s.vision.targetMIDCount==0)
vision.restore(s)
for slot,material in pairs(beamBodyOriginal)do assert(beamBody.slots[slot]==material)end
assert(actualBeam.slots[0]==actualBeamOriginal[0] and materialBeam.slots[0]==materialBeamOriginal[0])
assert(#pp.WeightedBlendables.Array==1)
print('PASS exact FlashlightComponent beam role and cooked masked flashlight material stay unchanged')

s,pp,original,camera=session()
local overlayMesh,overlayOriginal=addActor(s,{slots=2})
local overlay=object();overlayMesh.overlay=overlay
function overlayMesh:GetOverlayMaterial()return self.overlay or null end
function overlayMesh:SetOverlayMaterial(material)self.overlay=material end
ready(s,6)
assert(overlayMesh.overlay==nil and s.vision.stats.overlays==1)
local newOverlay=object();overlayMesh.overlay=newOverlay;run(s,20,1)
assert(overlayMesh.overlay==nil and s.vision.stats.overlays==1)
ready(s,9);assert(overlayMesh.overlay==nil)
ready(s,2)
assert(overlayMesh.overlay==newOverlay,'restore the newest real overlay after appearance changes')
for slot,material in pairs(overlayOriginal)do assert(overlayMesh.slots[slot]==material)end
vision.restore(s);assert(#pp.WeightedBlendables.Array==1)

s,pp,original,camera=session()
local rejectedOverlay,rejectedOriginal=addActor(s,{slots=2})
rejectedOverlay.overlay=overlay
function rejectedOverlay:GetOverlayMaterial()return self.overlay end
function rejectedOverlay:SetOverlayMaterial()end
ready(s,6)
assert(#s.vision.meshOrder==0 and s.vision.stats.rejected==1 and rejectedOverlay.overlay==overlay)
for slot,material in pairs(rejectedOriginal)do assert(rejectedOverlay.slots[slot]==material)end
vision.restore(s);assert(#pp.WeightedBlendables.Array==1)
print('PASS overlay readback, appearance updates, thermal/passive restoration and rejected-write rollback')

s,pp,original,camera=session()
local reject,originals=addActor(s,{slots=4})
local normalSet=reject.SetMaterial
function reject:SetMaterial(slot,value)
 if slot==2 and self.reject~=false then return end
 normalSet(self,slot,value)
end
ready(s,3)
assert(#s.vision.meshOrder==0 and s.vision.stats.rejected==1,'silent SetMaterial failure must not count as an applied component')
for slot,v in pairs(originals)do assert(reject.slots[slot]==v,'rejected component rolls back every changed slot')end
reject.reject=false;run(s,5,6)
assert(#s.vision.meshOrder==1 and reject.slots[2]==s.vision.material,'a rejected component must be retried')
vision.restore(s)
assert(#pp.WeightedBlendables.Array==1)
print('PASS rejected native writes, GetMaterial readback, atomic rollback and retry')

s,pp,original,camera=session()
local wrapped,wrappedOriginal=addActor(s,{slots=4})
local wrappedSet=wrapped.SetMaterial
function wrapped:SetMaterial(slot,material)
 if s.vision and material==s.vision.material then
  self.slots[slot]=object({Parent=material})
 else wrappedSet(self,slot,material)end
end
ready(s,6)
assert(#s.vision.meshOrder==1 and s.vision.stats.rejected==0 and s.vision.targetMIDCount==0)
run(s,80,1)
assert(s.vision.stats.reapplied==0,'inherited sensor material must not be overwritten on each audit')
vision.restore(s)
for slot,v in pairs(wrappedOriginal)do assert(wrapped.slots[slot]==v)end
assert(#pp.WeightedBlendables.Array==1)
print('PASS verified component-local descendants are accepted and their original slots restored')

s,pp,original,camera=session()
local owned,ownedOriginal=addActor(s,{slots=4})
local ownedSet=owned.SetMaterial;local created=0
function owned:SetMaterial(slot,material)
 if s.vision and material==s.vision.material then return end
 ownedSet(self,slot,material)
end
function owned:CreateDynamicMaterialInstance(slot,parent,name)
 assert(parent==loaded[vision.assets.emissive_fallback.path],'native fallback must use the cooked emitter, not another MID')
 created=created+1
 local mid=materialLibrary:CreateDynamicMaterialInstance(world,parent,name,0)
 self.slots[slot]=mid;return mid
end
ready(s,6)
assert(#s.vision.meshOrder==1 and created==4 and s.vision.stats.localMIDs==4)
for _,material in pairs(owned.slots)do
 assert(material.parameters.CoilsHeatValue==1 and material.parameters.Korshunov_EmissiveMult==vision.TARGET_EMISSION)
 finiteSensorRadiance(material.parameters.Korshunov_EmissiveMult)
 assert(material.parameters.BaseColorTexture==nil)
end
run(s,120,1);assert(created==4,'verified local MIDs must be retained without allocating during maintenance')
ready(s,9)
for _,material in pairs(owned.slots)do assert(material.parameters.CoilsHeatValue==1 and material.parameters.Korshunov_EmissiveMult==vision.TARGET_EMISSION,'local MIDs must retain verified emission in Fusion')end
local cachedVision=s.vision
local ownedMIDs={};for _,material in pairs(owned.slots)do ownedMIDs[#ownedMIDs+1]=material end
for cycle=1,10 do
 ready(s,2)
 for slot,v in pairs(ownedOriginal)do assert(owned.slots[slot]==v)end
 ready(s,6)
 for _,material in pairs(owned.slots)do assert(material.parameters.CoilsHeatValue==1 and material.parameters.Korshunov_EmissiveMult==vision.TARGET_EMISSION)end
 assert(created==4 and s.vision.targetMIDCount==4,'passive/thermal switches must reuse verified local MIDs')
end
vision.restore(s)
for slot,v in pairs(ownedOriginal)do assert(owned.slots[slot]==v)end
assert(#pp.WeightedBlendables.Array==1 and not next(cachedVision.cachedMIDs) and not next(cachedVision.cachedMaterialIds))
for _,material in ipairs(ownedMIDs)do assert(not cachedVision.pins[material:GetAddress()],'cached MID pin must be released at final restore')end
print('PASS component-owned native MID fallback, exact parameters, passive/thermal cache reuse and complete reference cleanup')

s,pp,original,camera=session()
local failing=addActor(s,{slots=1});local attempts=0
function failing:SetMaterial()end
function failing:CreateDynamicMaterialInstance()attempts=attempts+1;return null end
ready(s,6);run(s,120,1)
assert(attempts==1 and s.vision.stats.rejected==1,'failed components must back off instead of rebuilding every scan')
for cycle=1,20 do run(s,70,cycle*6)end
assert(attempts==1 and s.vision.targetMIDCount==1 and s.vision.pinCount==2)
vision.restore(s);assert(#pp.WeightedBlendables.Array==1)
print('PASS failed component fallback attempts and rejection records remain bounded across repeated scans')

s,pp,original,camera=session()
local badFallback,badFallbackOriginal=addActor(s,{slots=1})
local setBadFallback=badFallback.SetMaterial;local badAttempts=0;local badMID
function badFallback:SetMaterial(slot,material)
 if s.vision and material==s.vision.material then return end
 setBadFallback(self,slot,material)
end
function badFallback:CreateDynamicMaterialInstance(slot,parent,name)
 badAttempts=badAttempts+1;badMID=materialLibrary:CreateDynamicMaterialInstance(world,parent,name,0)
 function badMID:K2_GetScalarParameterValue()return 0 end
 self.slots[slot]=badMID;return badMID
end
ready(s,6)
assert(badFallback.slots[0]==badFallbackOriginal[0] and badAttempts==1 and s.vision.targetMIDCount==1)
assert(not next(s.vision.localMaterials) and not next(s.vision.cachedMIDs) and not s.vision.pins[badMID:GetAddress()])
for cycle=1,10 do run(s,70,cycle*6)end
assert(badAttempts==1 and badFallback.slots[0]==badFallbackOriginal[0])
vision.restore(s);assert(#pp.WeightedBlendables.Array==1)
print('PASS failed assigned MID parameters roll back immediately, release pins and never repeat allocation')


s,pp,original,camera=session()
ready(s,3)
local previous={}
for wave=1,20 do
 for _,row in ipairs(previous)do row.entry.expired=true end
 local fresh={}
 for _=1,7 do local mesh,originals,entry=addActor(s);fresh[#fresh+1]={mesh=mesh,originals=originals,entry=entry}end
 run(s,70,wave*2)
 for _,row in ipairs(fresh)do assert(row.mesh.slots[0]==s.vision.material)end
 for _,row in ipairs(previous)do assert(row.mesh.slots[0]==row.originals[0])end
 assert(s.vision.pinCount==23 and #pp.WeightedBlendables.Array<=65,'original materials must release/reuse engine reference slots')
 previous=fresh
end
vision.restore(s);assert(#pp.WeightedBlendables.Array==1);verifyOriginal(pp,original)
print('PASS streamed actor churn retains bounded material references and releases originals')

s,pp,original,camera=session()
local farthest
for i=1,vision.MAX_ACTORS do farthest=addActor(s,{slots=1,x=5000+i*10})end
ready(s,3);run(s,vision.MAX_ACTORS)
local closeTarget=addActor(s,{slots=1,x=50});run(s,20,3)
assert(s.vision.actorCount==vision.MAX_ACTORS and closeTarget.slots[0]==s.vision.material and farthest.slots[0]~=s.vision.material)
s.world=object();vision.update(s,4);assert(not s.vision and #pp.WeightedBlendables.Array==1)
print('PASS nearest target priority, hard actor bound and world lifecycle cleanup')

s,pp,original,camera=session()
assert(vision.apply(s,5,log));local failed=lutClients[#lutClients];failed.failure=true
run(s,3)
assert(s.vision.lutFailed and failed.updates==1 and not s.vision.activeMode)
verifyOriginal(pp,original);vision.restore(s);assert(failed.destroyed==1)
s,pp,original,camera=session();local fusion=addActor(s)
assert(vision.apply(s,9,log));vision.update(s,0)
assert(s.vision.activeMode==9 and not s.vision.lut and pp.ColorSaturation.X==1 and fusion.slots[0]==s.vision.material)
vision.restore(s);verifyOriginal(pp,original)
print('PASS failed palette preserves original image; Fusion commits immediately with RGB scenery')

-- Parameter readback is part of activation: a silent unsupported parameter
-- must never be reported as a working thermal material.
s,pp,original,camera=session()
local createMID=materialLibrary.CreateDynamicMaterialInstance
function materialLibrary:CreateDynamicMaterialInstance(...)
 local mid=createMID(self,...)
 function mid:K2_GetScalarParameterValue()return 0 end
 return mid
end
assert(vision.apply(s,6,log));run(s,5)
assert(s.vision.lutFailed and not s.vision.activeMode)
verifyOriginal(pp,original);vision.restore(s)
materialLibrary.CreateDynamicMaterialInstance=createMID
assert(#pp.WeightedBlendables.Array==1)
print('PASS unsupported emitter scalar parameter cannot silently activate thermal rendering')

local lamps={}
loaded['/Script/Engine.SpotLight']=object()
local gameplay=object();loaded['/Script/Engine.Default__GameplayStatics']=gameplay
function gameplay:BeginDeferredActorSpawnFromClass(context,class,transform,collision,owner,scale)
 assert(class==loaded['/Script/Engine.SpotLight'] and context==owner and collision==1 and scale==0)
 local light=object({values={}})
 for _,method in ipairs({'SetMobility','SetIntensity','SetAttenuationRadius','SetInnerConeAngle','SetOuterConeAngle','SetCastShadows'})do
  light[method]=function(self,value)self.values[method]=value end
 end
 local actor=object({SpotLightComponent=light})
 function actor:SetActorEnableCollision(value)assert(value==false)end
 function actor:K2_AttachToActor(parent,socket,l,r,sc,weld)
  assert(parent==owner and l==2 and r==2 and sc==2 and weld==false);self.attached=parent;return true
 end
 function actor:K2_DestroyActor()self.destroyed=true;self.alive=false end
 lamps[#lamps+1]=actor;return actor
end
function gameplay:FinishSpawningActor(actor,transform,scale)assert(scale==0);actor.finished=true end
s,pp,original,camera=session()
function s.camera:GetTransform()return {Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}end
assert(vision.apply(s,12,log) and #lamps==0,'IR lamp must not appear before its camera profile is ready')
run(s,5)
local lamp=lamps[#lamps]
assert(lamp and lamp.finished and lamp.attached==s.camera and lamp.SpotLightComponent.values.SetAttenuationRadius==3500)
assert(not s.vision.material and vision.apply(s,12,log) and #lamps==1)
ready(s,2);assert(lamp.destroyed,'IR lamp must switch off when another mode commits')
vision.restore(s);assert(#pp.WeightedBlendables.Array==1)
print('PASS IR LED atomically starts with its profile, stays camera-attached and is destroyed on mode change')

s,pp,original,camera=session()
local capMesh,capOriginal=addActor(s,{slots=4})
local pinLimit=vision.MAX_PINS;vision.MAX_PINS=4
ready(s,3)
assert(capMesh.writes==0 and #s.vision.meshOrder==0,'reference budget failure must leave the entire component untouched')
vision.MAX_PINS=pinLimit;run(s,5,2)
assert(capMesh.slots[0]==s.vision.material)
vision.restore(s);for slot,v in pairs(capOriginal)do assert(capMesh.slots[slot]==v)end
assert(#pp.WeightedBlendables.Array==1)
print('PASS entire component pin-budget rollback and retry')

s,pp,original,camera=session();pp.ColorGamma=nil
assert(vision.apply(s,3,log));run(s,5)
assert(not s.vision and camera.PostProcessBlendWeight==.37 and #pp.WeightedBlendables.Array==1)
assert(pp.ColorSaturation.X==original.ColorSaturation.X and pp.ColorContrast.X==original.ColorContrast.X)
print('PASS interrupted profile activation restores camera and all engine references')

local rawOpen=io.open;local saved;local mode='ok'
io.open=function(path,openMode)
 assert(path=='mock/vision-settings.txt')
 if mode=='openFail' or (openMode=='r' and saved==nil)then return nil end
 return {read=function()return saved end,write=function(_,text)if mode=='writeFail'then return nil end;saved=text;return true end,
 close=function()if mode=='closeFail'then return nil end;return true end}
end
assert(settings.load('mock/')==0)
for value=0,15 do assert(settings.save('mock/',tostring(value)));assert(settings.load('mock/')==value)end
for _,bad in ipairs({'16','-1','1.0','2 injected','999999999999999999','','01'})do assert(not settings.save('mock/',bad) and settings.parse(bad)==nil)end
for _,failure in ipairs({'openFail','writeFail','closeFail'})do mode=failure;assert(not settings.save('mock/','5'))end
io.open=rawOpen
print('PASS strict sensor preferences and file failure handling')

-- Secondary mesh passes belong only to successfully captured physical targets.
local function secondaryMesh(state,depth,decals,opts)
 local mesh,originals,entry=addActor(state,opts)
 mesh.bRenderCustomDepth=depth;mesh.bReceivesDecals=decals;mesh.CustomDepthStencilValue=73
 mesh.depthWrites=0;mesh.decalWrites=0
 function mesh:SetRenderCustomDepth(value)self.depthWrites=self.depthWrites+1;self.bRenderCustomDepth=value end
 function mesh:SetReceivesDecals(value)self.decalWrites=self.decalWrites+1;self.bReceivesDecals=value end
 return mesh,originals,entry
end
for _,depth in ipairs({false,true})do for _,decals in ipairs({false,true})do
 s,pp=session()
 local mesh,originals=secondaryMesh(s,depth,decals)
 ready(s,3);run(s,90,1)
 assert(mesh.bRenderCustomDepth==false and mesh.bReceivesDecals==false and mesh.CustomDepthStencilValue==73)
 assert(mesh.depthWrites==(depth and 1 or 0) and mesh.decalWrites==(decals and 1 or 0),'held flags must not rebuild render state every audit')
 ready(s,2)
 assert(mesh.bRenderCustomDepth==depth and mesh.bReceivesDecals==decals)
 assert(mesh.depthWrites==(depth and 2 or 0) and mesh.decalWrites==(decals and 2 or 0))
 for slot,material in pairs(originals)do assert(mesh.slots[slot]==material)end
 vision.restore(s)
end end
s,pp=session()
local reenabled,_,reenabledEntry=secondaryMesh(s,false,false)
ready(s,3)
reenabled.bRenderCustomDepth=true;reenabled.bReceivesDecals=true;run(s,30,1)
assert(not reenabled.bRenderCustomDepth and not reenabled.bReceivesDecals)
assert(reenabled.depthWrites==1 and reenabled.decalWrites==1)
reenabledEntry.position.X=10001;run(s,8,2)
assert(reenabled.bRenderCustomDepth and reenabled.bReceivesDecals,'range exit restores game re-enables observed after initial false')
assert(reenabled.depthWrites==2 and reenabled.decalWrites==2)
vision.restore(s)

s,pp=session()
local foreign=secondaryMesh(s,true,true);ready(s,3)
foreign.bRenderCustomDepth=true;foreign.bReceivesDecals=true
vision.restore(s)
assert(foreign.bRenderCustomDepth and foreign.bReceivesDecals and foreign.depthWrites==1 and foreign.decalWrites==1,
 'teardown must preserve an already restored external state without redundant writes')

s,pp=session()
local rejected=secondaryMesh(s,true,true)
function rejected:SetMaterial()end
ready(s,3);run(s,20,1)
assert(#s.vision.meshOrder==0 and rejected.depthWrites==0 and rejected.decalWrites==0)
assert(rejected.bRenderCustomDepth and rejected.bReceivesDecals,'failed thermal capture must never own secondary passes')
vision.restore(s)

s,pp=session()
local missing=secondaryMesh(s,true,true);missing.SetRenderCustomDepth=nil
local refused=secondaryMesh(s,true,true)
function refused:SetRenderCustomDepth()self.depthWrites=self.depthWrites+1 end
local partial=secondaryMesh(s,true,true)
function partial:SetRenderCustomDepth(value)
 self.depthWrites=self.depthWrites+1;self.bRenderCustomDepth=value
 if value==false then error('fixture exception after native mutation')end
end
ready(s,3);run(s,90,1)
assert(#s.vision.meshOrder==3 and s.vision.stats.rejected==0,'unsupported secondary passes must retain full thermal material coverage')
assert(missing.bRenderCustomDepth and refused.bRenderCustomDepth and not partial.bRenderCustomDepth)
assert(missing.depthWrites==0 and refused.depthWrites==1 and partial.depthWrites==1,'unavailable/rejected setters must not retry every frame')
assert(not missing.bReceivesDecals and not refused.bReceivesDecals and not partial.bReceivesDecals)
refused.bRenderCustomDepth=false -- another system changes a rejected flag later
vision.restore(s)
assert(missing.bRenderCustomDepth and not refused.bRenderCustomDepth and partial.bRenderCustomDepth,
 'a rejected setter never owns a later external flag change')
assert(missing.bReceivesDecals and refused.bReceivesDecals and partial.bReceivesDecals)
assert(refused.depthWrites==1 and partial.depthWrites==2,'partial setter exceptions must retain restoration ownership')
print('PASS scoped thermal CustomDepth/decals: exact flag restoration, latest re-enable, no-op avoidance, range exit, rejected capture and partial-write failures')


-- Exercise the new preferred emitter separately; the preceding suite covers
-- installed assets being unavailable and the retained fallback paths.
loaded[vision.assets.uniform_emissive.path]=object({bUsedWithSkeletalMesh=true})
s,pp,original,camera=session()
local uniform,uniformOriginal=addActor(s,{slots=3})
uniformOriginal[1].BlendMode=1 -- Genuine masked clothing remains a hot surface.
ready(s,3)
assert(s.vision.materialSpec==vision.assets.uniform_emissive)
local sensor=s.vision.material
assert(sensor.parameters.LuminanceAmount==vision.TARGET_EMISSION)
assert(sensor.parameters.LuminanceFilterMap==loaded[vision.assets.uniform_emissive.white_texture])
for _,axis in ipairs({'R','G','B'})do
 assert(sensor.parameters.LuminanceFilter[axis]==1,'white hot must use a unit-white filter rather than squared HDR emission')
 finiteSensorRadiance(sensor.parameters.LuminanceFilter[axis]*sensor.parameters.LuminanceAmount)
end
for slot=0,2 do assert(uniform.slots[slot]==sensor)end
vision.restore(s);verifyOriginal(pp,original)
for slot,value in pairs(uniformOriginal)do assert(uniform.slots[slot]==value)end
assert(#pp.WeightedBlendables.Array==1)
print('PASS uniform white emissive filter covers opaque/masked clothing with bounded radiance and complete restoration')

s,pp,original,camera=session()
local localUniform,localOriginal=addActor(s,{slots=2})
local localSet=localUniform.SetMaterial;local newUniformMIDs=0
function localUniform:SetMaterial(slot,material)
 if s.vision and material==s.vision.material then return end
 localSet(self,slot,material)
end
function localUniform:CreateDynamicMaterialInstance(slot,parent,name)
 assert(parent==loaded[vision.assets.uniform_emissive.path])
 newUniformMIDs=newUniformMIDs+1
 local mid=materialLibrary:CreateDynamicMaterialInstance(world,parent,name,0)
 self.slots[slot]=mid;return mid
end
ready(s,3)
assert(newUniformMIDs==2 and s.vision.stats.rejected==0)
for _,material in pairs(localUniform.slots)do
 assert(material.parameters.LuminanceFilter.R==1 and material.parameters.LuminanceFilter.G==1 and material.parameters.LuminanceFilter.B==1)
 assert(material.parameters.LuminanceAmount==vision.TARGET_EMISSION and material.parameters.LuminanceFilterMap==loaded[vision.assets.uniform_emissive.white_texture])
end
ready(s,9)
for _,material in pairs(localUniform.slots)do
 assert(material.parameters.LuminanceFilter.R==1 and material.parameters.LuminanceFilter.G==256/vision.TARGET_EMISSION and material.parameters.LuminanceFilter.B==1/vision.TARGET_EMISSION)
 assert(material.parameters.LuminanceAmount==vision.TARGET_EMISSION)
end
ready(s,2);for slot,value in pairs(localOriginal)do assert(localUniform.slots[slot]==value)end
ready(s,3);assert(newUniformMIDs==2)
for _,material in pairs(localUniform.slots)do assert(material.parameters.LuminanceFilter.G==1 and material.parameters.LuminanceAmount==vision.TARGET_EMISSION)end
vision.restore(s);assert(#pp.WeightedBlendables.Array==1)
print('PASS component-owned uniform emitter copies texture/RGB/luminance, updates Fusion and reuses bounded cached MIDs')

vision.clearPrewarm()
local hostSession,hostPP,hostOriginal,hostCamera=session()
local warmContext={world=world,camera=hostCamera}
local warmClients=#lutClients
local warmed,state=vision.prewarm(warmContext,3,log)
assert(warmed==false and state=='pending' and #lutClients==warmClients+1)
local warmClient=lutClients[#lutClients];local warmTexture=warmClient.rt
assert(#hostPP.WeightedBlendables.Array==2 and hostPP.WeightedBlendables.Array[2].Object==warmTexture)
assert(hostPP.WeightedBlendables.Array[2].Weight==0 and hostPP.ColorGradingLUT==null and hostCamera.PostProcessBlendWeight==.37)
verifyOriginal(hostPP,hostOriginal)
assert(vision.prewarm(warmContext,3,log)==false and warmClient.updates==2)
assert(vision.prewarm(warmContext,3,log)==true and warmClient.updates==3)
for _=1,20 do assert(vision.prewarm(warmContext,3,log)==true)end
assert(warmClient.updates==3 and #lutClients==warmClients+1 and #hostPP.WeightedBlendables.Array==2)
verifyOriginal(hostPP,hostOriginal)

s,pp,original,camera=session()
assert(vision.apply(s,3,log) and s.vision.activeMode==3 and pp.ColorGradingLUT==warmTexture)
assert(not s.vision.pending and s.vision.lut==nil and warmClient.updates==3,'first apply uses prepared texture before any vision.update')
vision.restore(s)
assert(warmClient.destroyed==0 and #hostPP.WeightedBlendables.Array==2)
s,pp,original,camera=session()
assert(vision.apply(s,3,log) and s.vision.activeMode==3 and pp.ColorGradingLUT==warmTexture)
ready(s,4)
local flightClient=lutClients[#lutClients]
assert(flightClient~=warmClient,'later mode changes own a separate per-flight client')
vision.restore(s)
assert(flightClient.destroyed==1 and warmClient.destroyed==0)
s,pp,original,camera=session();assert(vision.apply(s,3,log))
vision.clearPrewarm()
assert(warmClient.destroyed==1 and #hostPP.WeightedBlendables.Array==1)
assert(pp.ColorGradingLUT==warmTexture and s.vision.lutPins[3]==warmTexture,'FPV owns the adopted texture independently')
vision.restore(s);verifyOriginal(hostPP,hostOriginal)

assert(vision.prewarm(warmContext,3,log)==false)
local replacedClient=lutClients[#lutClients]
assert(vision.prewarm(warmContext,4,log)==false and replacedClient.destroyed==1 and #hostPP.WeightedBlendables.Array==2)
local damagedClient=lutClients[#lutClients];damagedClient.rt.alive=false
assert(vision.prewarm(warmContext,4,log)==false and damagedClient.destroyed==1)
assert(#hostPP.WeightedBlendables.Array==2,'an invalid RT must not accumulate stale host references')
local failedClient=lutClients[#lutClients];failedClient.failure=true
local failed,why=vision.prewarm(warmContext,4,log)
assert(failed==nil and why:find('test LUT failure') and failedClient.destroyed==1 and #hostPP.WeightedBlendables.Array==1)
local failedCount=#lutClients
for _=1,20 do assert(vision.prewarm(warmContext,4,log)==nil)end
assert(#lutClients==failedCount,'same-scope draw failures must not allocate/retry on every idle frame')
vision.clearPrewarm()

assert(vision.prewarm(warmContext,3,log)==false)
local oldHostClient=lutClients[#lutClients]
local secondHostSession,secondHostPP,_,secondHostCamera=session()
local secondContext={world=world,camera=secondHostCamera}
assert(vision.prewarm(secondContext,3,log)==false and oldHostClient.destroyed==1)
assert(#hostPP.WeightedBlendables.Array==1 and #secondHostPP.WeightedBlendables.Array==2)
local oldWorld,oldWorldClient=world,lutClients[#lutClients]
world=object();secondContext.world=world
assert(vision.prewarm(secondContext,3,log)==false and oldWorldClient.destroyed==1 and #secondHostPP.WeightedBlendables.Array==2)
local deadWorldClient=lutClients[#lutClients];world.alive=false
assert(vision.prewarm(secondContext,3,log)==nil and deadWorldClient.destroyed==1 and #secondHostPP.WeightedBlendables.Array==1)
world=oldWorld
for _,offMode in ipairs({0,9,16})do
 assert(vision.prewarm(warmContext,3,log)==false)
 local disabledClient=lutClients[#lutClients]
 local result,detail=vision.prewarm(warmContext,offMode,log)
 assert((offMode==16 and result==nil)or(result==true and detail=='ready'))
 assert(disabledClient.destroyed==1 and #hostPP.WeightedBlendables.Array==1)
end
assert(vision.prewarm(warmContext,3,log)==false)
local deadHostClient=lutClients[#lutClients];hostCamera.alive=false
assert(vision.prewarm(warmContext,3,log)==nil and deadHostClient.destroyed==1)
vision.clearPrewarm()
print('PASS selected-mode prewarm: invisible pending roots, bounded work/cache, first-apply commit, independent FPV ownership, mode/world/host invalidation and failure cleanup')

-- A sensor forces camera blend weight back to one. Disabling only that weight
-- used to make the sensor revive the preceding analog grain and vignette.
local analog=dofile('mod/Scripts/analog.lua')
local analogScalars={'FilmGrainIntensity','FilmGrainTexelSize','FilmGrainIntensityShadows',
 'FilmGrainIntensityMidtones','FilmGrainIntensityHighlights','VignetteIntensity'}
for mode=0,vision.modes.max do
    for style=1,4 do
        s,pp,original,camera=session()
        local state={}
        for i,key in ipairs(analogScalars)do pp[key]=i/20;pp['bOverride_'..key]=false end
        analog.apply(camera,true,style,state)
        assert(vision.apply(s,mode,log));run(s,5)
        if mode>0 then assert(s.vision.activeMode==mode)end
        vision.restore(s)
        analog.apply(camera,false,0,state)
        assert(vision.apply(s,mode,log));run(s,5)
        for i,key in ipairs(analogScalars)do
            assert(pp[key]==i/20 and not pp['bOverride_'..key],
                ('analog off must not return under vision %d, style %d, field %s'):format(mode,style,key))
        end
        -- Switching a sensor with analog unchanged must keep analog disabled.
        local nextMode=(mode+1)%(vision.modes.max+1)
        assert(vision.apply(s,nextMode,log));run(s,5)
        for _,key in ipairs(analogScalars)do assert(not pp['bOverride_'..key])end
        assert(vision.apply(s,0,log))
        assert(camera.PostProcessBlendWeight==.37)
        verifyOriginal(pp,original)
        -- Enabling again must capture a fresh clean baseline, not its old style.
        analog.apply(camera,true,style,state)
        assert(vision.apply(s,nextMode,log));run(s,5)
        vision.restore(s);analog.apply(camera,false,0,state)
        verifyOriginal(pp,original)
        for i,key in ipairs(analogScalars)do assert(pp[key]==i/20 and not pp['bOverride_'..key])end
    end
end
print('PASS every vision mode and analog style: immediate disable, unchanged-style sensor switches, repeated enable/disable and exact camera restoration')
