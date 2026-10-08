-- Bounded LOS sampling, entirely on the game thread. This approximates radio
-- attenuation from loaded collision geometry, not a radio-material simulation.
local collision=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'drone_collision.lua')
local M={interval=0.25}
local function cm(v) return {X=v.x*100,Y=v.y*100,Z=v.z*100} end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function validHit(hit)
    local p=hit and hit.Location
    return p and finite(p.X) and finite(p.Y) and finite(p.Z)
end
function M.update(s,system,enabled,now,log)
    if not enabled then s.radioObstruction=nil;return 0 end
    local cache=s.radioObstruction
    if not cache then cache={penalty=0,next=0};s.radioObstruction=cache end
    if now<cache.next then return cache.penalty end
    cache.next=now+M.interval
    local from,to=cm(s.origin),cm(s.flight.p)
    local dx,dy,dz=to.X-from.X,to.Y-from.Y,to.Z-from.Z
    if dx*dx+dy*dy+dz*dz<100^2 then cache.penalty=0;return 0 end
    local ok,blocked,first=pcall(collision.trace,system,s,from,to,2)
    if not ok then
        if not cache.warned then cache.warned=true;log('Radio obstacle queries unavailable: '..tostring(blocked)) end
        cache.penalty=0;return 0
    end
    cache.penalty=blocked and 35 or 0
    if blocked and validHit(first) then
        -- A reverse query measures the occupied span. Several walls and deep
        -- buildings weaken reception more than a single exposed surface.
        local reversed,reverse,last=pcall(collision.trace,system,s,to,from,2)
        if reversed and reverse and validHit(last) then
            local a,b=first.Location,last.Location
            local span=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100
            cache.penalty=math.min(75,35+span*0.5)
        end
    end
    return cache.penalty
end
return M
