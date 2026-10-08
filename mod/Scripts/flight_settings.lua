local M={}
local multipliers=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'impact_settings.lua')
function M.parse(text)
    if not text or #text>64 then return end
    local speed,tilt=text:match('^([%d%.]+) (%d+)%s*$')
    speed,tilt=multipliers.parse(speed),tonumber(tilt)
    if speed~=nil and tilt and tilt<=60 then return speed,tilt end
end
function M.apply(cfg,speed,tilt)
    assert(type(speed)=='number' and speed==speed and speed>=0 and speed<=5 and type(tilt)=='number' and tilt%1==0 and tilt>=0 and tilt<=60,'Invalid FPV settings')
    cfg.speed_preset=speed;cfg.camera_tilt=tilt
end
function M.load(root,cfg)
    local file=io.open(root..'flight-settings.txt','r');if not file then return end
    local speed,tilt=M.parse(file:read(65));file:close()
    if speed then M.apply(cfg,speed,tilt) end
end
function M.save(root,cfg,speed,tilt)
    if type(speed)~='number' or speed~=speed or speed<0 or speed>5 or type(tilt)~='number' or tilt%1~=0 or tilt<0 or tilt>60 then return false end
    local dest=io.open(root..'flight-settings.txt','w');if not dest then return false end
    local ok=dest:write(string.format('%.6f %d\n',speed,tilt));local closed=dest:close()
    if not ok or not closed then return false end
    M.apply(cfg,speed,tilt);return true
end
return M
