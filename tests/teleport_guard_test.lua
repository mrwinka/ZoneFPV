local M=dofile('mod/Scripts/teleport_guard.lua')
local id=0
local function obj(t)
    id=id+1;t=t or {};t.id=id
    function t:IsValid()return not self.invalid end
    function t:GetAddress()return self.id end
    return t
end
local pawn=obj{position={X=1,Y=2,Z=300}}
function pawn:K2_GetActorLocation()return self.position end
local function component(enabled,owner)
    local c=obj{enabled=enabled,owner=owner or pawn}
    function c:GetOwner()return self.owner end
    function c:GetGenerateOverlapEvents()return self.enabled end
    function c:SetGenerateOverlapEvents(v)self.enabled=v end
    return c
end
local capsule,alreadyOff,foreign=component(true),component(false),component(true,obj())
pawn.CapsuleComponent=capsule
function pawn:K2_GetComponentsByClass()return {capsule,alreadyOff,foreign} end
StaticFindObject=function()return obj()end
local s={pawn=pawn}
M.start(s);M.start(s)
assert(not capsule.enabled and not alreadyOff.enabled and foreign.enabled)
assert(M.update(s)==nil)
capsule.enabled=true;M.update(s);assert(not capsule.enabled,'game re-enable must be suppressed')
s.npcAnchor={position={X=1,Y=2,Z=300},lastPosition={X=20000,Y=0,Z=-4700}}
pawn.position={X=20000,Y=0,Z=-4700};assert(M.update(s)==nil,'own streaming move is not teleport')
s.combat={proxy={position={X=1,Y=2,Z=300},lastPosition={X=60000,Y=20,Z=30}}}
pawn.position={X=60000,Y=20,Z=30};assert(M.update(s)==nil,'combat proxy destination takes precedence')
pawn.position={X=999999,Y=1111,Z=4321}
local destination=assert(M.update(s));M.handoff(s,destination)
assert(s.npcAnchor.position.X==999999 and s.combat.proxy.position.Z==4321,'exit must preserve story destination')
M.restore(s);assert(capsule.enabled and not alreadyOff.enabled and foreign.enabled and not s.teleportGuard)
M.start(s);capsule.invalid=true;M.restore(s);assert(not s.teleportGuard)
print('PASS teleport: overlap ownership, proxy moves, external destination handoff and exact restoration')
