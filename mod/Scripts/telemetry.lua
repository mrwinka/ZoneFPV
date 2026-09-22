local M={}
function M.sample(s,cfg,flight)
    local f=s.flight
    local scale=flight.horizontal_scale(cfg.speed_preset)
    local r=flight.camera_rotation(f,cfg.camera_tilt)
    local dx,dy,dz=s.origin.x-f.p.x,s.origin.y-f.p.y,s.origin.z-f.p.z
    return {speed=math.sqrt((f.v.x*scale)^2+(f.v.y*scale)^2+(f.v.z*1.5)^2)*3.6,
        altitude=-dz,distance=math.sqrt(dx*dx+dy*dy+dz*dz),pitch=r.Pitch,roll=r.Roll,
        heading=(r.Yaw+360)%360,home=(math.deg(math.atan(dy,dx))-r.Yaw+540)%360-180,
        seconds=s.flightSeconds or 0,climb=f.v.z*1.5,throttle=(s.throttle or 0)*100}
end
function M.new(root,flight,cfg)
    local nextWrite,seq,wasActive=0,0,false
    return function(now,s)
        local active=s~=nil
        if now<nextWrite and active==wasActive then return end
        nextWrite=now+(active and 0.05 or 1);wasActive=active;seq=seq+1
        local v=active and M.sample(s,cfg,flight) or {}
        local f=io.open(root..'telemetry.txt','w')
        if f then
            f:write(string.format('1 %d %d %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %d\n',
                seq,active and 1 or 0,v.speed or 0,v.altitude or 0,v.distance or 0,v.pitch or 0,v.roll or 0,
                v.heading or 0,v.home or 0,v.seconds or 0,v.climb or 0,v.throttle or 0,seq));f:close()
        end
    end
end
return M
