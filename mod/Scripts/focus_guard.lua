-- Keep the flight on focus loss, but suspend physics and control actions.
local M={}
function M.accept(g,p,now)
    if not p.connected then return nil end
    if p.focused then return p end
    local paused={};for k,v in pairs(p) do paused[k]=v end
    paused.paused=true
    return paused
end
function M.delta(g,p,dt)
    local paused=p.paused or p.menu or false
    local resume=g.paused and not paused
    g.paused=paused
    -- Never integrate the background interval, including the first resumed frame.
    return (paused or resume) and 0 or dt,paused
end
return M
