-- Adapter tests do not establish that the game exposes this Niagara schema.
local M=dofile('mod/Scripts/fpv_particles.lua')
local logs,clones,finds,reads,writes={}, {},0,0,0
local emptyClonePositions=false
local rawOpen=io.open
io.open=function()return {write=function()end,close=function()end}end
FindAllOf=function()error('world scans forbidden')end
local function object(t)
    t=t or {};function t:IsValid()return not self.invalid end
    function t:GetAddress()return self end
    return t
end
FName=function(text) return {type=function()return 'FName' end,ToString=function()return text end} end
local function array(values)
    return setmetatable({type=function()return 'TArray' end,GetArrayNum=function()return #values end},
        {__index=function(_,k)
            assert(type(k)=='number' and k%1==0 and k>=1 and k<=#values,'out of range native read')
            reads=reads+1;return values[k]
        end,__newindex=function()error('native array write forbidden')end})
end
local types={Float=1,Int=2,Bool=3,Vec3=4,Position=5}
local function niagara(owner,asset,active)
    local c=object({owner=owner,asset=asset,active=active,vars={},values={},order={},locations=0,sets=0,
        bHiddenInGame=true,bUseAttachParentBound=true})
    local function store()
        local offset,vars,data,positions=0,{},{},{}
        for _,text in ipairs(c.order) do
            local item=c.values[text]
            vars[#vars+1]={type=function()return 'UScriptStruct' end,Name=FName(text),Offset=offset,
                TypeDefHandle={RegisteredTypeIndex=types[item.tag]}}
            for i=1,#item.raw do data[#data+1]=item.raw:byte(i) end
            offset=offset+#item.raw
            if item.tag=='Position' then positions[#positions+1]={Name=FName(text),Value=item.value} end
        end
        if c.testClone and emptyClonePositions then positions={} end
        c.OverrideParameters={SortedParameterOffsets=array(vars),ParameterData=array(data),OriginalPositionData=array(positions)}
    end
    function c:put(tag,key,value)
        local text=key:ToString();local raw
        if tag=='Vec3' or tag=='Position' then raw=string.pack('<fff',value.X,value.Y,value.Z)
        elseif tag=='Float' then raw=string.pack('<f',value)
        elseif tag=='Bool' then raw=string.pack('<i4',value and -1 or 0)
        else raw=string.pack('<i4',value) end
        if not self.values[text] then self.order[#self.order+1]=text end
        self.values[text]={tag=tag,raw=raw,value=value};store()
    end
    for tag in pairs(types) do
        c['SetVariable'..tag]=function(self,key,value)
            assert(self.testClone,'only owned clones may receive Niagara setters')
            writes=writes+1;self.sets=self.sets+1;self:put(tag,key,value)
        end
    end
    function c:GetClass()return {GetFName=function()return FName('DynamicEnvironmentNiagaraComponent')end}end
    function c:GetOwner()return self.owner end;function c:GetAsset()return self.asset end
    function c:K2_GetComponentLocation()return self.position or {X=10000,Y=20000,Z=2200}end
    function c:SetAbsolute(x,y,z)assert(x and y and z);self.absolute=true end
    function c:SetHiddenInGame(v,propagate)assert(not propagate);self.bHiddenInGame=v end
    function c:K2_SetWorldRotation()end;function c:SetVisibility(v)self.visible=v;self.bVisible=v end
    function c:K2_SetWorldLocation(v)self.position=v;self.locations=self.locations+1 end
    function c:IsActive()return self.active end
    function c:GetAllowScalability()return self.scalability~=false end
    function c:GetForceLocalPlayerEffect()return self.forceLocalPlayer==true end
    function c:SetAllowScalability(value)assert(self.testClone);self.scalability=value end
    function c:SetForceLocalPlayerEffect(value)assert(self.testClone);self.forceLocalPlayer=value end
    function c:Activate()
        self.activations=(self.activations or 0)+1
        assert(self.position,'configure before activation')
        if self.asset:GetFullName():find('NS_Dyn_Rain_Weather',1,true) then
            assert(self.values['User.AttractorPosition'],'configure rain target before activation')
        end
        self.active=true
    end
    function c:Deactivate()self.active=false end
    function c:K2_DestroyComponent(owner)assert(owner==self.owner);self.invalid=true end
    store();return c
end
local asset=object({GetFullName=function()return 'Object /Game/_Stalker_2/VFX/Environment/Rain/Niagara/NS_Dyn_Rain_Weather:NS_Dyn_Rain_Weather'end})
local function setup()
    local pawn=object({bHidden=true,K2_GetActorLocation=function()return {X=10000,Y=20000,Z=100}end})
    local camera=object({bHidden=true,SetActorHiddenInGame=function(self,v)self.bHidden=v end});camera.CameraComponent=object({owner=camera})
    local source=niagara(pawn,asset,true)
    source:put('Position',FName('User.AttractorPosition'),{X=-999,Y=-999,Z=-999})
    source:put('Float',FName('User.RainIntensity'),.75)
    source:put('Vec3',FName('User.WindDirection'),{X=1,Y=2,Z=3})
    source:put('Bool',FName('User.RainEnabled'),true)
    local s={pawn=pawn,camera=camera,origin={x=100,y=200,z=2},flight={p={x=100,y=200,z=2}},
        playerVisibility={nextScan=1,components={{object=source,flags={bVisible=true}}}}}
    return s,source
end
local library=object({SpawnSystemAttached=function(_,template,parent,attach,loc,rot,locType,autoDestroy,autoActivate,pool,preCull,...)
    assert(select('#',...)==0 and locType==2 and not autoDestroy and not autoActivate and pool==0 and not preCull)
    assert(attach:ToString()=='None')
    local clone=niagara(parent.owner,template,false);clone.testClone=true;clones[#clones+1]=clone;return clone
end})
StaticFindObject=function(path)finds=finds+1;assert(path=='/Script/Niagara.Default__NiagaraFunctionLibrary');return library end
local function log(v)logs[#logs+1]=v end
local s,source=setup()
local original=source.OverrideParameters
M.update(s,0,'mock/',log)
assert(#clones==1 and clones[1].active and clones[1].absolute)
local clone=clones[1]
assert(not s.camera.bHidden and not clone.bHiddenInGame and not clone.bUseAttachParentBound and clone.bVisible,
    'unhide only owned camera/clone and use clone bounds')
assert(clone:GetAllowScalability() and not clone:GetForceLocalPlayerEffect(),'rain retains its original culling policy')
assert(clone.position.Z==2200 and clone.position.X==10000,'world overhead offset must ignore camera rotation')
assert(clone.values['User.AttractorPosition'].value.Z==200,'world position must use FPV camera, never source LWC bytes')
assert(clone.values['User.RainIntensity'].value==.75)
assert(clone.values['User.WindDirection'].value.Y==2 and clone.values['User.RainEnabled'].value)
assert(source.OverrideParameters==original and source.sets==0 and s.pawn.bHidden,'source/player state must not change')
local before={reads=reads,writes=writes,finds=finds,locations=clone.locations}
M.update(s,.01,'mock/',log)
assert(reads==before.reads and writes==before.writes,'early callbacks must do no Niagara work')
M.update(s,.11,'mock/',log)
assert(writes==before.writes and clone.locations==before.locations and finds==before.finds,'hover avoids setters/lookups')
source:put('Float',FName('User.RainIntensity'),.25)
s.flight.p.z=10
M.update(s,.22,'mock/',log)
assert(clone.position.Z==3000 and clone.values['User.AttractorPosition'].value.Z==1000)
assert(clone.values['User.RainIntensity'].value==.25 and #clones==1)
source.active=false;M.update(s,.44,'mock/',log);assert(not clone.active,'dry weather stops the mirror')
source.active=true;M.update(s,.66,'mock/',log);assert(clone.active)
M.restore(s);assert(clone.invalid and not s.fpvParticles and s.pawn.bHidden)
M.restore(s)
print('PASS camera owner, copied scalar/vector/bool, world Position, activation, bounds, rate limit and cleanup')

-- Source component disappears or is pooled: never keep its old weather alive.
s,source=setup();M.update(s,1,'mock/',log);clone=clones[#clones]
source.owner=object();M.update(s,1.11,'mock/',log)
assert(clone.invalid and next(s.fpvParticles.entries)==nil)
M.restore(s)
s,source=setup();M.update(s,2,'mock/',log);clone=clones[#clones]
s.playerVisibility.components={};s.playerVisibility.nextScan=3
M.update(s,2.11,'mock/',log);assert(clone.invalid);M.restore(s)
print('PASS source pooled/replaced/detached cleanup')

-- Unsupported layout fails locally, without stranding a component or FPV.
s,source=setup()
source:put('Int',FName('User.CustomUnknown'),1)
-- Replace one native type handle with an uncalibrated one.
local offsets=source.OverrideParameters.SortedParameterOffsets
offsets[offsets:GetArrayNum()].TypeDefHandle.RegisteredTypeIndex=9001
M.update(s,3,'mock/',log);clone=clones[#clones]
assert(clone.invalid and next(s.fpvParticles.entries)==nil and s.pawn.bHidden)
local n=#clones;M.update(s,5,'mock/',log);assert(#clones==n,'failed effect must not retry every callback')
M.restore(s)
print('PASS unsupported inputs fail closed once and destroy the incomplete clone')

-- Malformed reflected offset must never turn a read into a native TArray resize.
s,source=setup()
local offsets=source.OverrideParameters.SortedParameterOffsets
offsets[2].Offset=100000
M.update(s,6,'mock/',log);clone=clones[#clones]
assert(clone.invalid and source.sets==0 and s.pawn.bHidden)
M.restore(s)
print('PASS malformed byte offset rejected before array indexing')

-- Actual UE build aliases Position and Vector3 in the stored type registry.
types.Position=types.Vec3
s,source=setup()
source:put('Position',FName('User.TerrainReference'),{X=4000000,Y=5000000,Z=100})
M.update(s,7,'mock/',log);clone=clones[#clones]
assert(not clone.invalid and clone.active,'Position/Vec3 storage alias must not disable rain')
assert(clone.values['User.AttractorPosition'].tag=='Position' and clone.values['User.AttractorPosition'].value.Z==200)
assert(clone.values['User.WindDirection'].tag=='Vec3' and clone.values['User.WindDirection'].value.Y==2)
assert(clone.values['User.TerrainReference'].tag=='Position' and clone.values['User.TerrainReference'].value.X==4000000,
    'copy original world position metadata, never decode simulation position bytes')
M.restore(s);assert(clone.invalid)
print('PASS native Position/Vector3 alias, semantic world coordinates and unchanged wind decoder')

-- Actual native trial: readable but empty pre-activation clone position list.
emptyClonePositions=true
s,source=setup();M.update(s,7.5,'mock/',log);clone=clones[#clones]
assert(not clone.invalid and clone.active and clone.values['User.AttractorPosition'].tag=='Position')
assert(s.fpvParticles.calibrationDetail:find('(empty)',1,true),'record observed native metadata instead of assuming marker membership')
M.restore(s);emptyClonePositions=false
print('PASS readable empty clone position metadata permits validated alias')

-- Player leaves may be positioned entirely by the component world transform.
s,source=setup()
source.asset=object({GetFullName=function()return 'Object /Game/_Stalker_2/VFX/Player/NS_Leaves_Player:NS_Leaves_Player'end})
source.values['User.AttractorPosition']=nil;table.remove(source.order,1)
source:put('Float',FName('User.RainIntensity'),.5)
M.update(s,7.7,'mock/',log);clone=clones[#clones]
assert(not clone.invalid and clone.active and clone.position.Z==200,logs[#logs])
assert(not clone:GetAllowScalability() and clone:GetForceLocalPlayerEffect(),'camera leaves bypass non-player distance culling')
assert(source:GetAllowScalability() and not source:GetForceLocalPlayerEffect(),'native effects retain their original culling policy')
assert(not clone.values['User.AttractorPosition'],'never invent native input names for component-driven leaves')
M.restore(s)
print('PASS known leaf asset without AttractorPosition uses world transform')

-- Native leaf location is refreshed separately from the pawn's anchor.
local function setupLeaves()
    local s,source=setup()
    source.asset=object({GetFullName=function()return 'Object /Game/_Stalker_2/VFX/Player/NS_Leaves_Player:NS_Leaves_Player'end})
    source.values['User.AttractorPosition']=nil;table.remove(source.order,1)
    source.position={X=10000,Y=20000,Z=150}
    source:put('Float',FName('User.TerrainOffset'),27)
    return s,source
end
s,source=setupLeaves()
s.pawn.K2_GetActorLocation=function()return {X=10000,Y=20000,Z=-4900}end
s.npcAnchor={position={X=10000,Y=20000,Z=100}}
M.update(s,10,'mock/',log);clone=clones[#clones]
assert(clone.position.Z==200,'detached source must not lift camera leaves by the pawn anchor depth')
assert(clone.values['User.TerrainOffset'].value==-23,'translate the native surface to the camera component')
source.position.Z=-4850
M.update(s,10.22,'mock/',log)
assert(clone.values['User.TerrainOffset'].value==-23,'hold ground while transform updates before the provider')
source:put('Float',FName('User.TerrainOffset'),5027)
M.update(s,10.44,'mock/',log)
assert(clone.values['User.TerrainOffset'].value==-23,'fresh provider compensates the underground transform')
s.flight.p.z=10
M.update(s,10.66,'mock/',log)
assert(clone.values['User.TerrainOffset'].value==-823,'drone altitude changes the camera-relative surface')
assert(source.sets==0 and s.pawn.bHidden,'leaf correction never writes native particle or player state')
source.active=false;M.update(s,10.88,'mock/',log)
assert(not clone.active,'native leaf eligibility remains authoritative')
M.restore(s);assert(clone.invalid)
print('PASS detached leaf source, terrain rebase, stale provider hold, camera altitude and native stop')

s,source=setupLeaves();M.update(s,11,'mock/',log);clone=clones[#clones]
source:put('Float',FName('User.TerrainOffset'),5027)
M.update(s,11.22,'mock/',log)
assert(clone.values['User.TerrainOffset'].value==-23,'hold ground when provider updates before detached transform')
source.position.Z=-4850
M.update(s,11.44,'mock/',log)
assert(clone.values['User.TerrainOffset'].value==-23)
source:put('Float',FName('User.TerrainOffset'),5030)
M.update(s,11.66,'mock/',log)
assert(clone.values['User.TerrainOffset'].value==-20,'native terrain changes still propagate after the rebase')
M.restore(s)
print('PASS provider-before-transform refresh order and ordinary terrain updates')

-- Once/second discovery can first see leaves after the 50 m anchor rebase.
s,source=setupLeaves()
s.pawn.K2_GetActorLocation=function()return {X=10000,Y=20000,Z=-4900}end
s.npcAnchor={position={X=10000,Y=20000,Z=100}}
source.position.Z=-4850
M.update(s,12,'mock/',log);clone=clones[#clones]
assert(clone.values['User.TerrainOffset'].value==-23,'late stale first sample uses known anchor displacement')
local entry=s.fpvParticles.entries['/Game/_Stalker_2/VFX/Player/NS_Leaves_Player.NS_Leaves_Player']
assert(entry.terrain.estimated,'record bootstrap estimate until the native provider refreshes')
source:put('Float',FName('User.TerrainOffset'),5027)
M.update(s,12.22,'mock/',log)
assert(clone.values['User.TerrainOffset'].value==-23 and not entry.terrain.estimated,
    'late first discovery recovers on a fresh terrain provider sample')
M.restore(s)
s,source=setupLeaves()
s.pawn.K2_GetActorLocation=function()return {X=10000,Y=20000,Z=-4900}end
s.npcAnchor={position={X=10000,Y=20000,Z=100}}
source.position.Z=-4850;source:put('Float',FName('User.TerrainOffset'),5027)
M.update(s,13,'mock/',log);clone=clones[#clones]
assert(clone.values['User.TerrainOffset'].value==-23,'already fresh late first sample must not compensate twice')
M.restore(s)
print('PASS late leaf discovery with stale or already refreshed terrain sample')

-- Real v7 logs showed two/three same-asset native sources restarting the clone
-- on every discovery. A retained source must win regardless of collection order.
s,source=setupLeaves();local _,duplicate=setupLeaves();duplicate.owner=s.pawn;duplicate.asset=source.asset
duplicate.active=false
s.playerVisibility.components={{object=duplicate,flags={bVisible=true}},{object=source,flags={bVisible=true}}}
local cloneCount=#clones;M.update(s,13.2,'mock/',log);clone=clones[#clones]
local leafKey='/Game/_Stalker_2/VFX/Player/NS_Leaves_Player.NS_Leaves_Player'
assert(#clones==cloneCount+1 and s.fpvParticles.entries[leafKey].source==source and clone.active,
    'first discovery must select one active source instead of creating multiple instances')
duplicate.active=true
for i=1,4 do
    if i%2==0 then s.playerVisibility.components={{object=source,flags={bVisible=true}},{object=duplicate,flags={bVisible=true}}}
    else s.playerVisibility.components={{object=duplicate,flags={bVisible=true}},{object=source,flags={bVisible=true}}}end
    s.playerVisibility.nextScan=s.playerVisibility.nextScan+1
    M.update(s,13.2+i,'mock/',log)
    assert(#clones==cloneCount+1 and not clone.invalid and s.fpvParticles.entries[leafKey].source==source,
        'an active duplicate cannot reset the retained running particle simulation')
end
s.playerVisibility.nextScan=s.playerVisibility.nextScan+1;source.active=false
local activations=clone.activations;local terrain=s.fpvParticles.entries[leafKey].terrain
M.update(s,18,'mock/',log)
assert(#clones==cloneCount+1 and not clone.invalid and s.fpvParticles.entries[leafKey].source==duplicate,
    'an active replacement provider must take over from an inactive retained one')
assert(s.fpvParticles.entries[leafKey].terrain==terrain and clone.activations==activations,
    'provider handoff preserves particle age and the coherent terrain reference')
s.playerVisibility.components={{object=duplicate,flags={bVisible=true}}};s.playerVisibility.nextScan=s.playerVisibility.nextScan+1
M.update(s,18.3,'mock/',log)
assert(not clone.invalid and #clones==cloneCount+1 and s.fpvParticles.entries[leafKey].source==duplicate,
    'retired source removal must not restart the running same-template mirror')
M.restore(s)
print('PASS duplicate native assets select once, retain simulation across reorder and hand off source without restarting')

s,source=setupLeaves();M.update(s,20,'mock/',log);clone=clones[#clones]
source.owner=object();local cloneCount=#clones
M.update(s,20.22,'mock/',log)
assert(clone.invalid and not s.fpvParticles.failed[leafKey],'native pool retirement cannot blacklist a supported asset')
local _,replacement=setupLeaves();replacement.owner=s.pawn;replacement.asset=source.asset
s.playerVisibility.components={{object=replacement,flags={bVisible=true}}}
M.update(s,20.44,'mock/',log);assert(#clones==cloneCount,'retirement waits for bounded component discovery')
s.playerVisibility.nextScan=s.playerVisibility.nextScan+1;M.update(s,21.3,'mock/',log)
assert(#clones==cloneCount+1 and clones[#clones].active and not clones[#clones].invalid,
    'a fresh eligible source must restore the effect within the same flight')
replacement.invalid=true;M.update(s,21.52,'mock/',log)
assert(not s.fpvParticles.failed[leafKey] and clones[#clones].invalid)
M.restore(s)
print('PASS pooled/expired native sources recover on bounded rediscovery without masking unsupported layouts')

-- Older Niagara builds can lack the optional local-player getter/setter.
s,source=setupLeaves()
local rawSpawn=library.SpawnSystemAttached
library.SpawnSystemAttached=function(...)
    local clone=rawSpawn(...)
    clone.GetForceLocalPlayerEffect=nil;clone.SetForceLocalPlayerEffect=nil
    return clone
end
M.update(s,14,'mock/',log);clone=clones[#clones]
assert(not clone.invalid and clone.active and not clone:GetAllowScalability(),
    'missing optional native API must not stop FPV or prevent supported culling override')
M.restore(s);library.SpawnSystemAttached=rawSpawn
print('PASS missing optional local-player API remains compatible')

-- Unknown scalar collisions and missing semantic metadata remain rejected.
types.Position=types.Float
s,source=setup();M.update(s,8,'mock/',log);clone=clones[#clones]
assert(clone.invalid and next(s.fpvParticles.entries)==nil);M.restore(s)
types.Position=types.Vec3
s,source=setup();source.OverrideParameters.OriginalPositionData=nil
M.update(s,9,'mock/',log);clone=clones[#clones]
assert(clone.invalid and next(s.fpvParticles.entries)==nil);M.restore(s)
print('PASS unrelated type collision and missing semantic position metadata fail closed')
io.open=rawOpen
