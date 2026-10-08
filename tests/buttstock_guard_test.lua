local guard=dofile('mod/Scripts/buttstock_guard.lua')
local seen,lookups,logs={},0,{}
local pawn={IsValid=function(self)return not self.invalid end,GetAddress=function()return 101 end}
local pc={IsValid=function()return true end,Pawn=pawn}
setmetatable(pc,{__index=function(_,key)
    if key=='GetPawn'then error('native inline GetPawn is not a reflected UFunction')end
end})
local system={IsValid=function()return true end}
function system:ExecuteConsoleCommand(context,command,owner)
    assert(context==pc and owner==pc);seen[#seen+1]=command
end
local saved=StaticFindObject
StaticFindObject=function(path)
    assert(path=='/Script/Stalker2.CustomConsoleManagerMH:XRemoveEffectFromPlayer')
    lookups=lookups+1;return {IsValid=function()return true end}
end
local s={pc=pc,pawn=pawn}
local g=guard.new(s,system,function(line)logs[#logs+1]=line end)
for i=1,20 do g:update()end
assert(#seen==0 and lookups==0,'idle FPV must not remove effects or scan')
g:hit(1);g:update();assert(#seen==10 and g.pending==1)
g:update();assert(#seen==20 and g.pending==0 and lookups==1)
for i=1,20 do g:update()end
assert(#seen==20,'removal is bounded, never a permanent registry sweep')
local allowed={ConcussionComposite_Buttstock=true,ConcussionBlurPostProcess_Buttstock=true,
    ButtStroke_CameraShake=true,ConcussionVelocityChange_Buttstock=true,
    ConcussionModifyRotate2DAxis_Buttstock=true,ConcussionBlockJump_Buttstock=true,
    ConcussionInputInertia2DAxis_Buttstock=true,ConcussionBlockAim_Buttstock=true,
    ConcussionBlockSprint_Buttstock=true,ApplyBaseConcussion=true}
for _,command in ipairs(seen)do assert(allowed[command:match('^XRemoveEffectFromPlayer ([%w_]+)$')])end
pc.Pawn={IsValid=function()return true end,GetAddress=function()return 101 end}
g:hit(1);g:update();assert(#seen==30,'different wrapper for same pawn is accepted')
pc.Pawn={IsValid=function()return true end,GetAddress=function()return 999 end}
g:update();assert(#seen==30 and g.pending==0,'changed pawn must not receive removals')
pc.Pawn=pawn;g:hit(1);g:restore();assert(#seen==40 and g.pending==0)
g:update();assert(#seen==40)
StaticFindObject=function()error('lookup unavailable')end
local unavailable=guard.new(s,system);unavailable:hit(1);unavailable:update();unavailable:update()
assert(#seen==40 and unavailable.pending==0,'discovery errors must fail closed')
StaticFindObject=saved
assert(logs[#logs]:find('dispatched') and logs[#logs-1]:find('local pawn check failed'),'ownership failure must be visible')
print('PASS buttstock guard: reflected Pawn with unavailable GetPawn, bounded exact removals after hit, local identity, visible ownership failures, cleanup and API isolation')
