local M={}
local speeds={[0.5]=true,[1]=true,[2]=true,[3]=true,[4]=true}
function M.parse(text)
    if not text or #text>64 then return end
    local speed,tilt=text:match('^([%d%.]+) (%d+)%s*$')
    speed,tilt=tonumber(speed),tonumber(tilt)
    if speeds[speed] and tilt and tilt<=60 then return speed,tilt end
end
function M.apply(cfg,speed,tilt)
    assert(speeds[speed] and type(tilt)=='number' and tilt%1==0 and tilt>=0 and tilt<=60,'Invalid FPV settings')
    cfg.speed_preset=speed;cfg.camera_tilt=tilt
end
function M.load(root,cfg)
    local file=io.open(root..'flight-settings.txt','r');if not file then return end
    local speed,tilt=M.parse(file:read(65));file:close()
    if speed then M.apply(cfg,speed,tilt) end
end
function M.save(root,cfg,speed,tilt)
    if not M.parse(tostring(speed)..' '..tostring(tilt)) then return false end
    local dest=io.open(root..'flight-settings.txt','w');if not dest then return false end
    local ok=dest:write(string.format('%g %d\n',speed,tilt));local closed=dest:close()
    if not ok or not closed then return false end
    M.apply(cfg,speed,tilt);return true
end
return M
