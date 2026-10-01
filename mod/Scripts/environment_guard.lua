-- Time/weather console commands may rebase world time or take a long frame.
-- Discard that interval; never recreate the flight at its original position.
local M={}
function M.changed(s,now)
    if s then s.environmentUntil=now+3;s.environmentRebase=true end
end
function M.delta(s,dt,now)
    if s.environmentRebase then s.environmentRebase=false;return 0 end
    if now<=(s.environmentUntil or -1) and (dt<0 or dt>1) then return 0 end
    return dt
end
return M
