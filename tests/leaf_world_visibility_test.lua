local M=dofile('mod/Scripts/leaf_world_visibility.lua')
local rawOpen=io.open
io.open=function()return {write=function()end,close=function()end}end
local scans=0
local assets,lodFunction,lodArity={}
StaticFindObject=function(path)
    if path=='/Script/Niagara.NiagaraComponent:SetPreviewLODDistance' then return lodFunction end
    assert(path:match('^/Game/_Stalker_2/VFX/'),'only fixed asset paths may be resolved')
    return assets[path]
end
local function object(t)
    t=t or {}
    function t:IsValid()return not self.invalid end
    function t:GetAddress()assert(not self.invalid,'expired UObject address read');return self end
    function t:GetFullName()error('live UObject/FField name conversion forbidden')end
    return t
end
local function asset(name)
    local folder=name=='NS_Character_Crow' and '/Game/_Stalker_2/VFX/Player/' or '/Game/_Stalker_2/VFX/Environment/Leaves/'
    local path=folder..name..'.'..name
    if not assets[path] then assets[path]=object() end
    return assets[path]
end
local function setup()
    local world=object();local s={world=world,pawn=object(),origin={x=10,y=20,z=30}}
    local function component(name,worldObject,owner,position)
        local c=object({world=worldObject or world,owner=owner or object(),asset=asset(name),
            position=position or {X=1100,Y=2200,Z=3000},scalability=true,localPlayer=false,active=true,writes=0,
            forbiddenWrites=0,assetReads=0})
        function c:GetWorld()return self.world end;function c:GetOwner()return self.owner end
        function c:GetAsset()self.assetReads=self.assetReads+1;return self.asset end
        function c:K2_GetComponentLocation()return self.position end
        function c:GetAllowScalability()return self.scalability end
        function c:GetForceLocalPlayerEffect()return self.localPlayer end
        function c:IsActive()return self.active end
        function c:SetAllowScalability(v)self.scalability=v;self.writes=self.writes+1 end
        function c:SetForceLocalPlayerEffect(v)
            if self.failOnce then self.failOnce=false;error('native setter failed')end
            self.localPlayer=v;self.writes=self.writes+1
        end
        local function forbidden(self)self.forbiddenWrites=self.forbiddenWrites+1;error('native lifecycle/transform/owner writes forbidden')end
        c.Activate=forbidden;c.Deactivate=forbidden;c.K2_SetWorldLocation=forbidden
        c.K2_SetRelativeLocation=forbidden;c.K2_SetWorldRotation=forbidden;c.SetOwner=forbidden
        c.SetAsset=forbidden;c.K2_DestroyComponent=forbidden
        return c
    end
    return s,component
end
local function list(objects)
    FindAllOf=function(class)assert(class=='DynamicEnvironmentNiagaraComponent');scans=scans+1;return objects end
end
local s,c=setup()
local near=c('NS_GroundLeaves_2')
local others={c('UnrelatedParticle'),c('NS_GroundLeaves_1',object()),c('NS_GroundLeaves_1',s.world,s.pawn),
    c('NS_GroundLeaves_1',nil,nil,{X=30000,Y=2000,Z=3000})}
list({near,table.unpack(others)})
M.start(s,'mock/',nil,0)
assert(scans==1 and #s.worldLeaves.entries==1 and not near.scalability and near.localPlayer)
for _,o in ipairs(others)do assert(o.writes==0,'foreign, pawn, far or unrelated effects must remain untouched')end
M.start(s,'mock/',nil,1);M.update(s,5);M.update(s,15);M.update(s,20)
assert(scans==1 and near.active,'cached status checks never rescan or change native activation')
M.restore(s)
assert(not s.worldLeaves and near.scalability and not near.localPlayer)
M.restore(s)
print('PASS exact assets, owner/world/radius scope, one discovery, native activation and restoration')

s,c=setup();local objects={}
for i=1,8 do objects[i]=c('NS_GroundLeaves_1')end
list(objects);M.start(s,'mock/',nil,0)
assert(#s.worldLeaves.entries==3,'cloud count is capped at three')
for i=4,8 do assert(objects[i].writes==0)end
M.restore(s)
print('PASS bounded native cloud count')

s,c=setup();near=c('NS_GroundLeaves_2');near.failOnce=true
list({near});M.start(s,'mock/',nil,0)
assert(not s.worldLeaves and near.scalability and not near.localPlayer,
    'second setter failure must restore the first applied setting')
print('PASS partially applied native setter rollback')

s,c=setup();near=c('NS_GroundLeaves_2');list({near});M.start(s,'mock/',nil,0)
near.owner=object();local writes=near.writes
M.restore(s);assert(near.writes==writes,'never restore settings onto a reowned source')
s,c=setup();near=c('NS_GroundLeaves_2');list({near});M.start(s,'mock/',nil,0)
near.invalid=true;writes=near.writes;M.restore(s);assert(near.writes==writes)
print('PASS expired or reowned source cleanup')

s,c=setup();near=c('NS_GroundLeaves_2');near.GetForceLocalPlayerEffect=nil
list({near});M.start(s,'mock/',nil,0)
assert(not near.scalability and not near.localPlayer,'unsupported optional setter must not be called')
M.restore(s);assert(near.scalability)
print('PASS unsupported optional local-player API')

-- Crows already running in the world are guarded directly, never recreated.
s,c=setup();local crow=c('NS_Character_Crow')
local originalOwner,originalPosition,originalAsset=crow.owner,crow.position,crow.asset
local crowOthers={c('NS_Character_Crow',object()),c('NS_Character_Crow',s.world,s.pawn),
    c('NS_Character_Crow',nil,nil,{X=30000,Y=2000,Z=3000}),c('NS_Character_Crow_Land')}
local wrongFolder=c('NS_Character_Crow');wrongFolder.asset=object();crowOthers[#crowOthers+1]=wrongFolder
list({crow,table.unpack(crowOthers)});local crowScans=scans;M.start(s,'mock/',nil,0)
assert(s.worldLeaves.counts.crows==1 and s.worldLeaves.counts.leaves==0 and not crow.scalability and crow.localPlayer)
s.flight={p={x=10,y=20,z=70}};M.update(s,5);crow.active=false;M.update(s,15);M.update(s,20)
assert(scans==crowScans+1 and not crow.active and crow.forbiddenWrites==0,'native crow activation remains authoritative')
assert(crow.owner==originalOwner and crow.position==originalPosition and crow.asset==originalAsset)
assert(crow.position.X==1100 and crow.position.Y==2200 and crow.position.Z==3000)
for _,o in ipairs(crowOthers)do assert(o.writes==0 and o.forbiddenWrites==0)end
M.restore(s)
assert(crow.scalability and not crow.localPlayer and not crow.active and crow.forbiddenWrites==0)
assert(crow.owner==originalOwner and crow.position==originalPosition and crow.asset==originalAsset)
print('PASS exact ambient crow scope, cached checks, untouched native lifecycle/transform/owner and restoration')

s,c=setup();objects={}
for i=1,8 do objects[i]=c('NS_GroundLeaves_1')end
for i=9,16 do objects[i]=c('NS_Character_Crow')end
list(objects);M.start(s,'mock/',nil,0)
assert(#s.worldLeaves.entries==6 and s.worldLeaves.counts.leaves==3 and s.worldLeaves.counts.crows==3)
for i=1,16 do
    local selected=i<=3 or (i>=9 and i<=11)
    assert(objects[i].writes==(selected and 2 or 0) and objects[i].forbiddenWrites==0,'each type must retain its own three-effect cap')
end
M.update(s,5);M.update(s,15);assert(#s.worldLeaves.report==9,'all six effects and both status snapshots stay bounded')
M.restore(s);for _,o in ipairs(objects)do assert(o.scalability and not o.localPlayer and o.forbiddenWrites==0)end
print('PASS independent three-leaf/three-crow caps, six-effect total and bounded status reports')

s,c=setup();objects={}
for i=1,32 do objects[i]=c('UnrelatedParticle')end
objects[33]=c('NS_Character_Crow');list(objects);M.start(s,'mock/',nil,0)
assert(#s.worldLeaves.entries==0 and objects[32].assetReads==1 and objects[33].assetReads==0)
M.restore(s);assert(objects[33].writes==0)
print('PASS thirty-two component inspection cap')

s,c=setup();near=c('NS_GroundLeaves_2');crow=c('NS_Character_Crow');crow.failOnce=true
list({near,crow});M.start(s,'mock/',nil,0)
assert(not s.worldLeaves and near.scalability and not near.localPlayer and crow.scalability and not crow.localPlayer)
assert(near.forbiddenWrites==0 and crow.forbiddenWrites==0,'mixed rollback cannot restart either native effect')
for _,change in ipairs({'owner','world','asset'})do
    s,c=setup();crow=c('NS_Character_Crow');list({crow});M.start(s,'mock/',nil,0)
    crow[change]=object();local crowWrites=crow.writes;M.update(s,5);M.restore(s)
    assert(crow.writes==crowWrites and crow.forbiddenWrites==0,'reused crow identity must not receive restoration writes')
end
print('PASS partial crow setter rollback and owner/world/asset identity cleanup')

local function lodApi(fields)
    lodArity=fields and #fields or 2
    lodFunction=object({ForEachProperty=function()error('live FField iteration forbidden')end})
end
local function preview(o,enabled,distance)
    o.previewEnabled=enabled;o.previewDistance=distance;o.lodWrites=0
    function o:GetPreviewLODDistanceEnabled()return self.previewEnabled end
    function o:GetPreviewLODDistance()return self.previewDistance end
    function o:SetPreviewLODDistance(v,d)
        -- UE4SS checks UFunction argument count before native ProcessEvent.
        assert(lodArity==2,'UFunction argument count mismatch')
        self.previewEnabled=v;self.previewDistance=d;self.lodWrites=self.lodWrites+1
        if self.misreadLod and v then self.previewDistance=d+100 end
        if self.failLodOnce then self.failLodOnce=false;error('partially applied LOD setter')end
    end
end
lodApi();s,c=setup();near=c('NS_GroundLeaves_2');preview(near,false,321)
list({near});local beforeScans=scans;M.start(s,'mock/',nil,0)
assert(near.previewEnabled and math.abs(near.previewDistance-math.sqrt(100^2+200^2))<1e-8)
s.flight={p={x=10,y=20,z=32}};M.update(s,.9);assert(near.lodWrites==1)
M.update(s,1);assert(near.lodWrites==2 and math.abs(near.previewDistance-300)<1e-8)
M.update(s,1.1);assert(near.lodWrites==2)
s.flight.p.z=32.1;M.update(s,2);assert(near.lodWrites==2,'small distance changes must not dirty the native effect')
s.flight.p.z=100;M.update(s,20);M.update(s,30)
assert(near.lodWrites==3 and scans==beforeScans+1,'cached LOD continues beyond diagnostics without discovery')
M.restore(s);assert(not near.previewEnabled and near.previewDistance==321 and near.scalability and not near.localPlayer)
print('PASS verified LOD follows camera distance, rate/change caps, cached updates and exact restoration')

lodApi({'BoolProperty bEnablePreviewLODDistance','FloatProperty PreviewLODDistance','FloatProperty PreviewMaxDistance'})
s,c=setup();near=c('NS_GroundLeaves_2');preview(near,true,456);list({near});M.start(s,'mock/',nil,0);M.update(s,20)
assert(near.lodWrites==0 and not near.scalability and near.localPlayer,'unknown native signature must skip LOD only')
M.restore(s);assert(near.previewEnabled and near.previewDistance==456)
print('PASS incompatible native LOD signature leaves density override untouched')

lodApi();s,c=setup();near=c('NS_GroundLeaves_2');preview(near,true,456);near.failLodOnce=true
list({near});M.start(s,'mock/',nil,0);M.update(s,20);assert(near.lodWrites==1)
M.restore(s);assert(near.previewEnabled and near.previewDistance==456 and near.scalability and not near.localPlayer)
print('PASS partial LOD failure stops retries and still restores all owned state')

lodApi();s,c=setup();near=c('NS_GroundLeaves_2');preview(near,false,321);near.misreadLod=true
list({near});M.start(s,'mock/',nil,0)
assert(near.lodWrites==2 and not near.previewEnabled and near.previewDistance==321,
    'inconsistent successful setter must immediately restore the snapshot')
M.update(s,20);assert(near.lodWrites==2 and not near.scalability and near.localPlayer,
    'failed readback stops only LOD retries and preserves native particle density')
M.restore(s);assert(not near.previewEnabled and near.previewDistance==321 and near.scalability and not near.localPlayer)
print('PASS native LOD readback mismatch restores immediately and stops further attempts')

for _,value in ipairs({math.huge,0/0})do
    s,c=setup();near=c('NS_GroundLeaves_2');preview(near,false,value)
    list({near});M.start(s,'mock/',nil,0);M.update(s,20);M.restore(s);assert(near.lodWrites==0)
end
s,c=setup();near=c('NS_GroundLeaves_2');preview(near,false,50);near.GetPreviewLODDistanceEnabled=nil
list({near});M.start(s,'mock/',nil,0);M.update(s,20);M.restore(s);assert(near.lodWrites==0)
print('PASS missing getters and nonfinite snapshots cannot enable native LOD override')
lodApi();s,c=setup()
local effects={c('NS_GroundLeaves_1'),c('NS_GroundLeaves_2'),c('NS_GroundLeaves_3'),
 c('NS_Character_Crow'),c('NS_Character_Crow'),c('NS_Character_Crow')}
for _,effect in ipairs(effects)do preview(effect,false,321)end
list(effects);M.start(s,'mock/',nil,0)
assert(#s.worldLeaves.entries==6)
s.flight={p={x=30,y=20,z=30}}
local function lodWrites()
 local sum=0;for _,effect in ipairs(effects)do sum=sum+effect.lodWrites end;return sum
end
local initial=lodWrites()
for i=1,30 do
 local before=lodWrites();M.update(s,i*.1)
 assert(lodWrites()-before<=1,'one update may not synchronize all six native particle effects')
end
assert(lodWrites()==initial+6,'every supported native effect still follows camera distance')
M.restore(s)
for _,effect in ipairs(effects)do assert(not effect.previewEnabled and effect.previewDistance==321)end
print('PASS native particle LOD changes are spread across frames and all snapshots restore')
io.open=rawOpen
