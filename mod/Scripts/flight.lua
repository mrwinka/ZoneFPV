-- ZoneFPV: SI units, body X forward/Y right/Z up; Unreal conversion at boundary.
local M = {}
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
M.clamp=clamp
-- Low presets use a transmitter-style throttle SCALE limit. Their translation
-- and aerodynamic coefficients are the same as 2x; no artificial braking.
function M.horizontal_scale(preset) return preset<2 and 1 or preset/2 end
local function throttle_limit(preset)
    return preset==0.5 and 0.50 or (preset==1 and 0.70 or 1)
end
function M.validate(c)
    assert(c.speed_preset==0.5 or c.speed_preset==1 or c.speed_preset==2 or c.speed_preset==3 or c.speed_preset==4,'Invalid config: speed_preset')
    local ranges={step={1/2000,1/60},gravity={0.1,30},thrust_to_weight={1.1,20},
        throttle_curve={0,1},expo={0,1},deadband={0,0.25},rate_response={0.001,1},
        motor_response={0.001,1},roll_rate={10,2000},pitch_rate={10,2000},yaw_rate={10,2000},
        linear_drag={0,10},quadratic_drag={0,2},restitution={0,1},fov={40,150},
        camera_tilt={-45,85},radius={0.02,1},max_distance={0,5000},surface_friction={0,2}}
    for name,range in pairs(ranges) do
        local v=c[name]
        assert(type(v)=='number' and v==v and v>=range[1] and v<=range[2], 'Invalid config: '..name)
    end
end
function M.mul(a,b)
    return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,
      x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
      y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,
      z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w}
end
function M.rotate(q,v)
    local t=M.mul(M.mul(q,{w=0,x=v.x,y=v.y,z=v.z}),{w=q.w,x=-q.x,y=-q.y,z=-q.z})
    return {x=t.x,y=t.y,z=t.z}
end
function M.axis(x,y,z,angle)
    local s=math.sin(angle/2)
    return {w=math.cos(angle/2),x=x*s,y=y*s,z=z*s}
end
function M.new(p,yaw)
    return {p={x=p.x,y=p.y,z=p.z},v={x=0,y=0,z=0},q=M.axis(0,0,1,math.rad(yaw)),
        omega={x=0,y=0,z=0},thrust=0,accumulator=0}
end
function M.rate(x,rate,expo,deadband)
    x=clamp(x,-1,1)
    if math.abs(x)<=deadband then return 0 end
    x=(x<0 and -1 or 1)*(math.abs(x)-deadband)/(1-deadband)
    return math.rad(rate)*((1-expo)*x+expo*x*x*x)
end
local function attitude(s,u,c,dt)
    -- Acro sticks command body angular velocity. A finite motor response models
    -- the closed-loop rate controller; there is deliberately no angle levelling.
    local target={x=-M.rate(u.roll,c.roll_rate,c.expo,c.deadband),
        y=M.rate(u.pitch,c.pitch_rate,c.expo,c.deadband),
        z=M.rate(u.yaw,c.yaw_rate,c.expo,c.deadband)}
    if c.flight_mode=='angle' then
        -- Desired bank/pitch are angles, yaw remains an Acro rate.
        local q=s.q
        local roll=math.atan(2*(q.w*q.x+q.y*q.z),1-2*(q.x*q.x+q.y*q.y))
        local pitch=math.asin(clamp(2*(q.w*q.y-q.z*q.x),-1,1))
        local limit=math.rad(50)
        local rx=clamp(u.roll,-1,1);local py=clamp(u.pitch,-1,1)
        if math.abs(rx)<c.deadband then rx=0 end;if math.abs(py)<c.deadband then py=0 end
        target.x=clamp((-rx*limit-roll)*6,-math.rad(c.roll_rate),math.rad(c.roll_rate))
        target.y=clamp((py*limit-pitch)*6,-math.rad(c.pitch_rate),math.rad(c.pitch_rate))
    end
    local a=1-math.exp(-dt/c.rate_response)
    for _,k in ipairs({'x','y','z'}) do s.omega[k]=s.omega[k]+(target[k]-s.omega[k])*a end
    local o=s.omega
    local speed=math.sqrt(o.x*o.x+o.y*o.y+o.z*o.z)
    if speed>1e-9 then s.q=M.mul(s.q,M.axis(o.x/speed,o.y/speed,o.z/speed,speed*dt)) end
    local q=s.q
    local norm=math.sqrt(q.w*q.w+q.x*q.x+q.y*q.y+q.z*q.z)
    q.w,q.x,q.y,q.z=q.w/norm,q.x/norm,q.y/norm,q.z/norm
end
function M.step(s,u,c,dt)
    local preset=c.speed_preset or 2
    local scale=M.horizontal_scale(preset)
    if s.previousPreset and s.previousPreset~=preset and (s.previousPreset<2 or preset<2) then
        -- Changing motor power must not instantly destroy existing momentum.
        local ratio=M.horizontal_scale(s.previousPreset)/scale
        s.v.x,s.v.y=s.v.x*ratio,s.v.y*ratio
    end
    s.previousPreset=preset
    attitude(s,u,c,dt)
    local t=clamp(u.throttle,0,1)*throttle_limit(preset)
    if c.flight_mode=='3d' then
        local signed=clamp(u.throttle,0,1)*2-1
        t=math.abs(signed)<=0.06 and 0 or (signed<0 and -1 or 1)*(math.abs(signed)-0.06)/0.94*throttle_limit(preset)
    end
    local thrust=c.gravity*c.thrust_to_weight*((1-c.throttle_curve)*t+c.throttle_curve*t*math.abs(t))
    s.thrust=s.thrust+(thrust-s.thrust)*(1-math.exp(-dt/c.motor_response))
    local up=M.rotate(s.q,{x=0,y=0,z=1})
    local velocity=math.sqrt(s.v.x^2+s.v.y^2+s.v.z^2)
    for _,k in ipairs({'x','y','z'}) do
        local acc=up[k]*s.thrust-(c.linear_drag+c.quadratic_drag*velocity)*s.v[k]
        if k=='z' then acc=acc-c.gravity end
        s.v[k]=s.v[k]+acc*dt
        -- Keep the accepted gravity calibration. Low power affects the full
        -- body thrust vector, not gravity, time, angular rates or displacement.
        s.p[k]=s.p[k]+s.v[k]*dt*(k=='z' and 1.5 or scale)
    end
end
function M.advance(s,u,c,dt,collision)
    -- Bounded fixed steps: stalls do not produce a huge jump or a catch-up spiral.
    s.accumulator=s.accumulator+clamp(dt,0,0.1)
    while s.accumulator+1e-12>=c.step do
        local old={x=s.p.x,y=s.p.y,z=s.p.z}
        M.step(s,u,c,c.step)
        if collision then collision(s,old) end
        s.accumulator=s.accumulator-c.step
    end
    -- Collision work stays bounded to 100 ms, but do not slow Acro rotation when
    -- streaming produces a long frame. No extra Unreal traces for these steps.
    local remaining=clamp(dt,0,1)-clamp(dt,0,0.1)
    while remaining>1e-12 do
        local step=math.min(remaining,c.step)
        attitude(s,u,c,step)
        remaining=remaining-step
    end
end
function M.collide(s,position,normal,restitution,friction,speedPreset)
    s.p={x=position.x,y=position.y,z=position.z}
    -- Resolve impulses using actual world velocity after axis scaling.
    local scale=M.horizontal_scale(speedPreset or 2)
    local scales={x=scale,y=scale,z=1.5}
    for _,k in ipairs({'x','y','z'}) do s.v[k]=s.v[k]*scales[k] end
    local dot=s.v.x*normal.x+s.v.y*normal.y+s.v.z*normal.z
    if dot<0 then
        -- Suppress tiny resting bounces. Coulomb friction consumes tangential
        -- momentum in proportion to the normal impulse, independent of FPS.
        local bounce=dot < -0.5 and restitution or 0
        local impulse=-(1+bounce)*dot
        local tangent={}
        local speed2=0
        for _,k in ipairs({'x','y','z'}) do
            tangent[k]=s.v[k]-dot*normal[k]
            speed2=speed2+tangent[k]^2
        end
        local speed=math.sqrt(speed2)
        local scale=speed>0 and math.max(0,1-(friction or 0)*impulse/speed) or 0
        for _,k in ipairs({'x','y','z'}) do s.v[k]=tangent[k]*scale-bounce*dot*normal[k] end
    end
    for _,k in ipairs({'x','y','z'}) do s.v[k]=s.v[k]/scales[k] end
end
function M.camera_rotation(s,tilt)
    local q=M.mul(s.q,M.axis(0,1,0,-math.rad(tilt)))
    -- Unreal FRotator conventions: positive pitch up, positive roll clockwise.
    local sinp=2*(q.w*q.y-q.z*q.x)
    return {Pitch=-math.deg(math.asin(clamp(sinp,-1,1))),
        Yaw=math.deg(math.atan(2*(q.w*q.z+q.x*q.y),1-2*(q.y*q.y+q.z*q.z))),
        Roll=-math.deg(math.atan(2*(q.w*q.x+q.y*q.z),1-2*(q.x*q.x+q.y*q.y)))}
end
return M
