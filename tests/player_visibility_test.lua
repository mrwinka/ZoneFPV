local guard=dofile('mod/Scripts/player_visibility.lua')
local function component(id,visible,shadow)
 local c={bVisible=visible,CastShadow=shadow,bCastHiddenShadow=true,bCastDynamicShadow=true,bCastStaticShadow=false}
 function c:IsValid()return not self.invalid end;function c:GetAddress()return id end
 function c:SetVisibility(v) self.bVisible=v end;function c:SetCastShadow(v)self.CastShadow=v end
 return c
end
local mesh=component(1,true,true);local shadow=component(2,false,true);local weapon=component(3,true,false)
local classFinds=0
StaticFindObject=function()classFinds=classFinds+1;return {IsValid=function()return true end}end
local pawn={Mesh=mesh,ShadowMeshComponent=shadow,bHidden=false,ItemAppearanceComponent={WeaponMeshUnequipped=weapon}}
function pawn:SetActorHiddenInGame(v)self.bHidden=v end
function pawn:GetAddress()return 100 end
function pawn:K2_GetComponentsByClass()return {mesh,{get=function()return shadow end},false,metadata=true}end
function pawn:GetAttachedActors()end
local s={pawn=pawn,camera={GetAddress=function()return 101 end}}
guard.update(s,0)
assert(pawn.bHidden)
assert(not mesh.bVisible and not shadow.CastShadow and not shadow.bCastHiddenShadow and not weapon.bVisible)
shadow.CastShadow=true;guard.update(s,.1);assert(not shadow.CastShadow)
guard.restore(s)
assert(not pawn.bHidden)
assert(mesh.bVisible and mesh.CastShadow and not shadow.bVisible and shadow.CastShadow and shadow.bCastHiddenShadow)
assert(weapon.bVisible and not weapon.CastShadow and not weapon.bCastStaticShadow)
local attachedMesh=component(4,true,true)
local attached={bHidden=false,GetAddress=function()return 102 end,IsValid=function()return true end}
function attached:SetActorHiddenInGame(v)self.bHidden=v end
function attached:K2_GetComponentsByClass()return {attachedMesh}end
function pawn:GetAttachedActors()return self.attached or {}end
pawn.attached={attached}
guard.update(s,1);assert(attached.bHidden and not attachedMesh.bVisible)
local before=classFinds
guard.update(s,2);assert(classFinds==before,'class lookup must be cached across all attached actor scans')
pawn.attached={};guard.update(s,3)
assert(not attached.bHidden and attachedMesh.bVisible and attachedMesh.CastShadow,'detached equipment must restore at discovery')
-- Native callable methods can be unsupported even when reflected fields exist.
local fallback=component(5,true,true);fallback.SetVisibility=false;fallback.SetCastShadow=false
pawn.Mesh=fallback;guard.update(s,4)
assert(not fallback.bVisible and not fallback.CastShadow,'field fallback must preserve visibility suppression')
guard.restore(s);assert(fallback.bVisible and fallback.CastShadow)
print('PASS dedicated shadow mesh and all primitive components hide and restore exact flags')
