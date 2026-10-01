local M={}
-- Keep EngineTick and the FPV scheduler alive. This is near-freeze, not pause.
function M.set(s,enabled,gameplay)
 if enabled and not s.freezeOwned then
  assert(not gameplay:IsGamePaused(s.pc),'World is already paused')
  local previous=gameplay:GetGlobalTimeDilation(s.pc)
  assert(type(previous)=='number' and previous>0,'Time dilation unavailable')
  s.previousDilation=previous;s.freezePrepared=true
  gameplay:SetGlobalTimeDilation(s.pc,0.0001)
  s.freezeOwned=true
 elseif not enabled and (s.freezeOwned or s.freezePrepared) then
  gameplay:SetGlobalTimeDilation(s.pc,s.previousDilation)
  s.freezeOwned=false;s.freezePrepared=false
 end
end
return M
