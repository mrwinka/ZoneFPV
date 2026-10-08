-- Never integrate stale sticks. A live independent action heartbeat permits
-- a short frozen wait for a delayed controller snapshot, not extra input life.
local M={maximumWait=.75}
local function finite(value)return type(value)=='number'and value==value and math.abs(value)<math.huge end
function M.new()
    local last,since
    return {
        accept=function(_,packet)
            last=packet;since=nil
        end,
        clear=function()last=nil;since=nil end,
        pause=function(_,now,heartbeatReady)
            if not heartbeatReady or not finite(now)or not last or not last.connected then since=nil;return end
            since=since or now
            if now<since or now-since>=M.maximumWait then return end
            local paused={}
            for key,value in pairs(last)do paused[key]=value end
            paused.focused=false;paused.paused=true;paused.staleInput=true
            return paused
        end,
    }
end
return M
