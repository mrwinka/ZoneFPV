local M={}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local weaponSettings=dofile(here..'weapon_settings.lua')
local function battery(s)
    local b=s and s.battery
    local function bounded(v,a,z)return type(v)=='number'and v==v and v>=a and v<=z end
    if type(b)~='table'or b.enabled~=true or not bounded(b.percent,0,100)
        or not bounded(b.voltage,0,40)or not bounded(b.currentA,0,1000)
        or not bounded(b.capacity,300,20000)or b.capacity%50~=0
        or not bounded(b.cells,2,8)or b.cells%1~=0 or not bounded(b.usedMah,0,b.capacity)then return {} end
    return {batteryEnabled=true,batteryPercent=b.percent,batteryVoltage=b.voltage,batteryCurrent=b.currentA,
        batteryUsed=b.usedMah,batteryCapacity=b.capacity,batteryCells=b.cells,
        batteryWarning=b.warning==true,batteryCritical=b.critical==true,batteryDepleted=b.depleted==true}
end
local function ammunition(s)
    local weapons=s and s.weapons
    if not weapons or not weaponSettings.hasGrenades(weapons.mode)then return false,0 end
    local remaining=weapons.remaining
    if remaining==math.huge then return true,-1 end
    if type(remaining)=='number' and remaining==remaining and remaining%1==0 and remaining>=0 and remaining<=20 then
        return true,remaining
    end
    return false,0
end
function M.sample(s,cfg,flight)
    local f=s.flight
    local scale=flight.horizontal_scale(cfg.speed_preset)
    local r=flight.camera_rotation(f,cfg.camera_tilt,s.cameraDown)
    local dx,dy,dz=s.origin.x-f.p.x,s.origin.y-f.p.y,s.origin.z-f.p.z
    local grenadeEnabled,grenadeRemaining=ammunition(s)
    local result={speed=math.sqrt((f.v.x*scale)^2+(f.v.y*scale)^2+(f.v.z*1.5)^2)*3.6,
        altitude=-dz,distance=math.sqrt(dx*dx+dy*dy+dz*dz),pitch=r.Pitch,roll=r.Roll,
        heading=(r.Yaw+360)%360,home=(math.deg(math.atan(dy,dx))-r.Yaw+540)%360-180,
        seconds=s.flightSeconds or 0,climb=f.v.z*1.5,throttle=(s.throttle or 0)*100,
        signalEnabled=s.radio and s.radio.enabled or false,rssi=s.radio and s.radio.rssi or 100,
        signalLost=s.radio and s.radio.lost or false,
        noiseStyle=s.noiseStyle or (s.experimentOptions and s.experimentOptions.style or 0),
        hpEnabled=s.combat and s.combat.enabled or false,hpPercent=s.combat and s.combat.health or 100,
        detectorEnabled=s.experimentOptions and s.experimentOptions.detector or false,
        artifactDistance=s.worldExperiments and s.worldExperiments.artifactDistance or -1,
        artifactReady=s.worldExperiments and s.worldExperiments.artifactReady or false,
        grenadeEnabled=grenadeEnabled,grenadeRemaining=grenadeRemaining,cameraDown=s.cameraDown==true}
    for key,value in pairs(battery(s))do result[key]=value end
    return result
end
function M.new(root,flight,cfg)
    local nextWrite,seq,wasActive,lastHealth,lastLost,lastAmmoEnabled,lastAmmo,lastCameraDown,lastBatteryState=0,0,false,nil,nil,nil,nil,nil,nil
    return function(now,s)
        local active=s~=nil
        local health=active and s.combat and s.combat.health or nil
        local lost=active and s.radio and s.radio.lost or false
        local ammoEnabled,ammo=ammunition(s)
        local cameraDown=active and s.cameraDown==true or false
        local b=battery(s)
        local batteryState=tostring(b.batteryEnabled)..tostring(b.batteryWarning)..tostring(b.batteryCritical)..tostring(b.batteryDepleted)
        if now<nextWrite and active==wasActive and health==lastHealth and lost==lastLost and ammoEnabled==lastAmmoEnabled and ammo==lastAmmo and cameraDown==lastCameraDown and batteryState==lastBatteryState then return end
        nextWrite=now+(active and 0.05 or 1);wasActive=active;seq=seq+1
        lastHealth,lastLost=health,lost
        lastAmmoEnabled,lastAmmo=ammoEnabled,ammo
        lastCameraDown=cameraDown
        lastBatteryState=batteryState
        local v=active and M.sample(s,cfg,flight) or {}
        local f=io.open(root..'telemetry.txt','w')
        if f then
            f:write(string.format('6 %d %d %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %d %.3f %d %d %d %.3f %d %.3f %d %d %d %d %d %.3f %.3f %.3f %.3f %d %d %d %d %d %d\n',
                seq,active and 1 or 0,v.speed or 0,v.altitude or 0,v.distance or 0,v.pitch or 0,v.roll or 0,
                v.heading or 0,v.home or 0,v.seconds or 0,v.climb or 0,v.throttle or 0,
                v.signalEnabled and 1 or 0,v.rssi or 100,v.signalLost and 1 or 0,
                v.noiseStyle or 0,v.hpEnabled and 1 or 0,v.hpPercent or 100,v.detectorEnabled and 1 or 0,
                v.artifactDistance or -1,v.artifactReady and 1 or 0,v.grenadeEnabled and 1 or 0,v.grenadeRemaining or 0,v.cameraDown and 1 or 0,
                v.batteryEnabled and 1 or 0,v.batteryPercent or 0,v.batteryVoltage or 0,v.batteryCurrent or 0,v.batteryUsed or 0,
                v.batteryCapacity or 0,v.batteryCells or 0,v.batteryWarning and 1 or 0,v.batteryCritical and 1 or 0,v.batteryDepleted and 1 or 0,seq));f:close()
        end
    end
end
return M
