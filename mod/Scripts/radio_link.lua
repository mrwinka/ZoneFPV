-- Experimental simulated RSSI; never measures the USB controller.
local multipliers=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'impact_settings.lua')
local M={default_range=1500,min_range=50,max_range=20000,fall_timeout=3,default_attenuation=2}
function M.parse(value)
    if type(value)~='string' or #value>64 then return end
    local enabled,range,multiplier=value:match('^([01]) (%d+) ([%d%.]+)%s*$')
    if not enabled then enabled,range=value:match('^([01]) (%d+)%s*$');multiplier='2' end
    multiplier=multipliers.parse(multiplier)
    range=tonumber(range)
    if range and range>=M.min_range and range<=M.max_range and multiplier~=nil then return enabled=='1',range,multiplier end
end
function M.load(root)
    local settings={enabled=false,range=M.default_range,attenuation=M.default_attenuation}
    local f=io.open(root..'signal-settings.txt','r')
    if f then
        local enabled,range,multiplier=M.parse(f:read(65));f:close()
        if enabled~=nil then settings.enabled,settings.range,settings.attenuation=enabled,range,multiplier end
    end
    return settings
end
function M.save(root,settings,value)
    local enabled,range,multiplier=M.parse(value);if enabled==nil then return false end
    local f=io.open(root..'signal-settings.txt','w');if not f then return false end
    local wrote=f:write(string.format('%d %d %.6f\n',enabled and 1 or 0,range,multiplier))
    local closed=f:close();if not wrote or not closed then return false end
    settings.enabled,settings.range,settings.attenuation=enabled,range,multiplier;return true
end
function M.lose(s,reason)
    local radio=s.radio or {enabled=true,rssi=0,lost=false,fallSeconds=0}
    s.radio=radio
    if not radio.lost then radio.lost=true;radio.reason=reason;radio.fallSeconds=0 end
    radio.enabled=true;radio.rssi=0;s.flight.linkLost=true;s.flight.thrust=0
    return radio
end
function M.update(s,settings,dt,sources)
    local radio=s.radio
    if not radio then radio={enabled=false,rssi=100,lost=false,fallSeconds=0};s.radio=radio end
    if radio.lost then
        -- A lost link cannot be rescued by changing range/settings or pressing F9.
        radio.fallSeconds=radio.fallSeconds+math.max(0,math.min(dt or 0,0.1))
        return radio
    end
    sources=sources or {}
    local multiplier=settings.attenuation
    if type(multiplier)~='number' or multiplier~=multiplier or multiplier<0 or multiplier>5 then multiplier=M.default_attenuation end
    local sourceScale=multiplier/2
    radio.enabled=settings.enabled or sources.anomalyEnabled or false;radio.rssi=100
    if settings.enabled then
        local p,o=s.flight.p,s.origin
        local distance=math.sqrt((p.x-o.x)^2+(p.y-o.y)^2+(p.z-o.z)^2)
        -- Shape attenuation while keeping the selected distance as the hard
        -- maximum at every positive multiplier. 2x preserves the linear curve;
        -- 0x disables signal attenuation, without disabling crash destruction.
        local fraction=math.max(0,math.min(1,distance/settings.range))
        local loss=multiplier>0 and 100*fraction^(2/multiplier) or 0
        radio.rssi=math.max(0,100-loss)
        radio.rssi=math.max(0,radio.rssi-math.max(0,sources.obstacles or 0)*sourceScale)
    end
    if sources.anomalyEnabled then
        radio.rssi=math.max(0,radio.rssi-math.max(0,sources.anomaly or 0)*sourceScale)
    end
    if radio.enabled and radio.rssi<=0 then
        M.lose(s,'signal')
    end
    return radio
end
function M.finished(s)
    local r=s.radio
    return r and r.lost and (r.fallSeconds>=M.fall_timeout or r.hit and r.fallSeconds>=0.25)
end
return M
