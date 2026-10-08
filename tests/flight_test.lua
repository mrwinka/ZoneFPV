package.path='mod/Scripts/?.lua;'..package.path
local f=require('flight')
local c=require('config')
local input=require('input')
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function near(a,b,t) assert(math.abs(a-b)<(t or 1e-8), tostring(a)..' ~= '..tostring(b)) end
local zero={roll=0,pitch=0,yaw=0,throttle=0}
test('freefall matches the former 3x vertical motion',function()
    local settings=setmetatable({linear_drag=0,quadratic_drag=0},{__index=c})
    local s=f.new({x=0,y=0,z=10},0)
    for i=1,240 do f.step(s,zero,settings,1/240) end
    near(s.v.z,-9.81);near(s.p.z,10-1.5*9.81/2,0.04)
end)
test('level hover has balanced forces',function()
    local cfg=setmetatable({throttle_curve=0},{__index=c})
    local s=f.new({x=0,y=0,z=10},0);s.thrust=c.gravity
    for i=1,240 do f.step(s,{roll=0,pitch=0,yaw=0,throttle=1/c.thrust_to_weight},cfg,1/240) end
    near(s.p.z,10);near(s.p.x,0)
end)
test('inverted thrust points down',function()
    local s=f.new({x=0,y=0,z=100},0);s.q=f.axis(1,0,0,math.pi)
    for i=1,60 do f.step(s,{roll=0,pitch=0,yaw=0,throttle=1},c,1/240) end
    assert(s.v.z < -5)
end)
test('acro keeps bank after sticks centre',function()
    local s=f.new({x=0,y=0,z=100},0);s.q=f.axis(1,0,0,0.7)
    for i=1,240 do f.step(s,zero,c,1/240) end
    near(s.q.x,math.sin(0.35))
end)
test('fixed step independent of rendering at 30/144 FPS',function()
    local function run(fps)
        local s=f.new({x=0,y=0,z=100},0)
        for i=1,fps*2 do f.advance(s,{roll=0.1,pitch=-0.2,yaw=0.3,throttle=0.3},c,1/fps) end
        return s
    end
    local a,b=run(30),run(144)
    near(a.p.x,b.p.x);near(a.p.y,b.p.y);near(a.q.w,b.q.w)
end)
test('quaternion remains normalized through repeated flips',function()
    local s=f.new({x=0,y=0,z=100},0)
    for i=1,24000 do f.step(s,{roll=1,pitch=0.7,yaw=0.3,throttle=0.3},c,1/240) end
    near(s.q.w^2+s.q.x^2+s.q.y^2+s.q.z^2,1)
end)
test('camera tilt and yaw use Unreal conventions',function()
    local s=f.new({x=0,y=0,z=0},90);local r=f.camera_rotation(s,25)
    near(r.Pitch,25);near(r.Yaw,90);near(r.Roll,0)
end)
test('vector rotation matches Hamilton products for arbitrary and non-unit quaternions',function()
    local quaternions={f.axis(1,0,0,0.7),f.mul(f.axis(0,0,1,1.2),f.axis(0,1,0,-0.3)),
        {w=2,x=-3,y=0.5,z=4},{w=0,x=0,y=0,z=0}}
    for _,q in ipairs(quaternions) do
        for _,v in ipairs({{x=0,y=0,z=1},{x=-3,y=2,z=0.25},{x=1.5,y=-0.2,z=-7}}) do
            local expected=f.mul(f.mul(q,{w=0,x=v.x,y=v.y,z=v.z}),{w=q.w,x=-q.x,y=-q.y,z=-q.z})
            local actual=f.rotate(q,v)
            near(actual.x,expected.x);near(actual.y,expected.y);near(actual.z,expected.z)
        end
    end
end)
test('fixed steps retain independent pre-movement snapshots and bounded collision work',function()
    local s=f.new({x=0,y=0,z=100},0)
    local snapshots,positions={},{}
    f.advance(s,zero,c,0.3,function(state,old)
        snapshots[#snapshots+1]=old
        positions[#positions+1]=state.p.z
    end)
    assert(#snapshots==24,'long frames must keep the 100 ms collision bound')
    for i,old in ipairs(snapshots) do
        near(old.z,i==1 and 100 or positions[i-1])
        assert(positions[i]<old.z,'every translation step must still move')
        if i>1 then assert(old~=snapshots[i-1]) end
    end
end)
test('collision removes inward velocity and respects bounce',function()
    local s=f.new({x=0,y=0,z=0},0);s.v={x=2,y=0,z=-10}
    f.collide(s,{x=0,y=0,z=1},{x=0,y=0,z=1},0.1)
    near(s.v.x,2);near(s.v.z,1)
end)
test('packet parser rejects malformed/torn/nonfinite input',function()
    assert(not input.parse('1 2 nan'))
    assert(not input.parse('1 2 123 1 1 0 0 0 0 0 0 0 3'))
    assert(not input.parse('1 2 123 1 1 999999 0 0 0 0 0 0 2'))
    assert(input.parse('1 2 123 1 1 32767 32767 0 32767 0 0 0 2'))
end)
test('axis mapping preserves analogue resolution and inversion',function()
    local packet={axes={32767.5,65535,0,0,0,0}}
    local u=input.controls(packet,c,nil)
    near(u.roll,0);near(u.pitch,1);near(u.throttle,0);near(u.yaw,-1)
    local cfg=setmetatable({throttle_invert=true,pitch_invert=true},{__index=c})
    local v=input.controls(packet,cfg,nil);near(v.throttle,1);near(v.pitch,-1)
end)
test('rate curve has deadband and correct endpoints',function()
    near(f.rate(0.01,650,0.35,0.025),0)
    near(f.rate(1,650,0.35,0.025),math.rad(650))
end)
test('invalid time step is rejected before starting loop',function()
    f.validate(c)
    local cfg=setmetatable({step=0},{__index=c})
    assert(not pcall(f.validate,cfg))
end)
test('ground friction stops sliding and permits takeoff',function()
    local cfg=setmetatable({linear_drag=0,quadratic_drag=0},{__index=c})
    local s=f.new({x=0,y=0,z=0.12},0);s.v.x=8
    local function floor(state)
        if state.p.z<=0.12 then
            f.collide(state,{x=state.p.x,y=state.p.y,z=0.122},{x=0,y=0,z=1},cfg.restitution,cfg.surface_friction)
        end
    end
    for i=1,720 do f.advance(s,zero,cfg,1/240,floor) end
    near(s.v.x,0);assert(s.p.x<5)
    local stopped=s.p.x
    for i=1,240 do f.advance(s,zero,cfg,1/240,floor) end
    near(s.p.x,stopped)
    for i=1,240 do f.advance(s,{roll=0,pitch=0,yaw=0,throttle=0.6},cfg,1/240,floor) end
    assert(s.p.z>2 and s.v.z>0,'surface contact must not latch the drone to the ground')
end)
test('surface friction stops a drone on a shallow slope',function()
    local s=f.new({x=0,y=0,z=0},0)
    local normal={x=0,y=-math.sin(0.2),z=math.cos(0.2)}
    for i=1,480 do
        f.step(s,zero,c,c.step)
        f.collide(s,{x=0,y=0,z=0},normal,c.restitution,c.surface_friction)
    end
    near(s.v.x,0);near(s.v.y,0);near(s.v.z,0)
end)
test('accepted 2x 3x 4x presets preserve their horizontal scaling and Acro rotation',function()
    local u={roll=0.1,pitch=-0.2,yaw=0.3,throttle=0.5}
    local function run(speed)
        local cfg=setmetatable({speed_preset=speed},{__index=c})
        local s=f.new({x=0,y=0,z=0},0)
        for i=1,240 do f.step(s,u,cfg,cfg.step) end
        return s
    end
    local base=run(2)
    for _,speed in ipairs({2,3,4,5}) do
        local s=run(speed)
        for _,k in ipairs({'x','y','z'}) do near(s.p[k],base.p[k]*(k=='z' and 1 or speed/2));near(s.v[k],base.v[k]) end
        for _,k in ipairs({'w','x','y','z'}) do near(s.q[k],base.q[k]) end
    end
end)

test('continuous 0-5 speed values validate and zero power safely falls',function()
    for _,speed in ipairs({0,.25,.75,1.5,2.5,5}) do
        local cfg=setmetatable({speed_preset=speed},{__index=c});f.validate(cfg)
        local s=f.new({x=0,y=0,z=100},0)
        for _=1,240 do f.step(s,{roll=0,pitch=0,yaw=0,throttle=1},cfg,cfg.step) end
        for _,axis in ipairs({'x','y','z'}) do assert(s.p[axis]==s.p[axis] and math.abs(s.p[axis])<math.huge) end
        if speed==0 then assert(s.thrust==0 and s.p.z<100 and s.v.z<0) end
        f.collide(s,s.p,{x=0,y=0,z=1},0,0,speed)
        assert(s.v.z==s.v.z)
    end
    assert(not pcall(f.validate,setmetatable({speed_preset=5.01},{__index=c})))
end)
test('fall trajectory is identical across presets and a mid-air preset change',function()
    local base=f.new({x=0,y=0,z=100},0)
    local states={}
    for _,speed in ipairs({0.5,1,2,3,4}) do states[speed]=f.new({x=0,y=0,z=100},0) end
    local changing=f.new({x=0,y=0,z=100},0)
    for i=1,720 do
        f.step(base,zero,c,c.step)
        for speed,s in pairs(states) do
            f.step(s,zero,setmetatable({speed_preset=speed},{__index=c}),c.step)
            near(s.p.z,base.p.z);near(s.v.z,base.v.z)
        end
        f.step(changing,zero,setmetatable({speed_preset=i<360 and 0.5 or 4},{__index=c}),c.step)
        near(changing.p.z,base.p.z);near(changing.v.z,base.v.z)
    end
end)
test('yaw at hover retains the 2x rate at every preset and through long frames',function()
    local u={roll=0,pitch=0,yaw=0.5,throttle=0.2}
    local function run(speed,fps)
        local cfg=setmetatable({speed_preset=speed},{__index=c})
        local s=f.new({x=0,y=0,z=100},0)
        for i=1,fps*2 do f.advance(s,u,cfg,1/fps) end
        return s
    end
    local base=run(2,240)
    near(base.omega.z,f.rate(0.5,500,c.expo,c.deadband))
    for _,speed in ipairs({0.5,1,2,3,4}) do
        for _,fps in ipairs({5,8,30,60,144}) do
            local s=run(speed,fps)
            near(s.omega.z,base.omega.z)
            for _,k in ipairs({'w','x','y','z'}) do near(s.q[k],base.q[k]) end
        end
    end
end)
test('slope collisions remove inward world velocity at every speed',function()
    local normal={x=0,y=-math.sin(0.4),z=math.cos(0.4)}
    for _,speed in ipairs({0.5,1,2,3,4}) do
        local s=f.new({x=0,y=0,z=0},0);s.v={x=2,y=3,z=-6}
        f.collide(s,{x=0,y=0,z=0},normal,0,0,speed)
        local scale=speed<2 and 1 or speed/2
        near(s.v.y*scale*normal.y+s.v.z*1.5*normal.z,0)
    end
end)
test('low presets behave like reduced transmitter throttle, not slowed displacement',function()
    for preset,limit in pairs({[0.5]=0.5,[1]=0.7}) do
        local low=f.new({x=0,y=0,z=100},0)
        local reference=f.new({x=0,y=0,z=100},0)
        local cfg=setmetatable({speed_preset=preset},{__index=c})
        for i=1,480 do
            local gas=i<240 and 1 or 0.4
            f.step(low,{roll=0.1,pitch=-0.15,yaw=0.2,throttle=gas},cfg,c.step)
            f.step(reference,{roll=0.1,pitch=-0.15,yaw=0.2,throttle=gas*limit},c,c.step)
            for _,k in ipairs({'x','y','z'}) do near(low.p[k],reference.p[k]);near(low.v[k],reference.v[k]) end
            near(low.thrust,reference.thrust)
        end
    end
end)
test('zero-throttle coasting has no additional drag or displacement loss in low presets',function()
    local reference
    for _,preset in ipairs({2,1,0.5}) do
        local s=f.new({x=0,y=0,z=100},0);s.v={x=12,y=3,z=0}
        local cfg=setmetatable({speed_preset=preset},{__index=c})
        for i=1,240 do f.step(s,zero,cfg,c.step) end
        if reference then
            for _,k in ipairs({'x','y','z'}) do near(s.p[k],reference.p[k]);near(s.v[k],reference.v[k]) end
        else reference=s end
    end
end)
test('low profiles remain capable of takeoff with ordered power and unchanged yaw',function()
    local previous=0
    for _,preset in ipairs({0.5,1,2}) do
        local s=f.new({x=0,y=0,z=0},0)
        local cfg=setmetatable({speed_preset=preset},{__index=c})
        for i=1,240 do f.step(s,{roll=0,pitch=0,yaw=0.5,throttle=1},cfg,c.step) end
        assert(s.p.z>2 and s.v.z>0,'low power must retain takeoff authority')
        assert(s.thrust>previous,'power profiles must be ordered')
        previous=s.thrust
        near(s.omega.z,f.rate(0.5,500,c.expo,c.deadband))
    end
end)
test('switching to or from low power preserves world momentum',function()
    for _,pair in ipairs({{4,0.5},{4,1},{0.5,4},{1,3},{1,0.5}}) do
        local old,new=pair[1],pair[2]
        local oldScale=old<2 and 1 or old/2
        local newScale=new<2 and 1 or new/2
        local s=f.new({x=0,y=0,z=100},0);s.previousPreset=old;s.v.x=12/oldScale
        local cfg=setmetatable({speed_preset=new,linear_drag=0,quadratic_drag=0},{__index=c})
        f.step(s,zero,cfg,c.step)
        near(s.v.x*newScale,12);near(s.p.x,12*c.step)
    end
end)
test('lower camera follows the full body pose and mount through banks, flips and vertical singularities',function()
    local function unrealBasis(rotation,v)
        local q=f.mul(f.axis(0,0,1,math.rad(rotation.Yaw)),
            f.mul(f.axis(0,1,0,-math.rad(rotation.Pitch)),f.axis(1,0,0,-math.rad(rotation.Roll))))
        return f.rotate(q,v)
    end
    local cases={}
    for _,yaw in ipairs({0,.37,1.239,2.4,math.pi,-math.pi/2})do
        for _,pitch in ipairs({0,1e-10,-1e-10,1e-7,-1e-7,.43,-.91,math.pi/2,-math.pi/2,math.pi})do
            for _,roll in ipairs({0,.55,-.87,math.pi/2,-math.pi/2,math.pi})do
                cases[#cases+1]=f.mul(f.axis(0,0,1,yaw),f.mul(f.axis(0,1,0,pitch),f.axis(1,0,0,roll)))
            end
        end
    end
    for _,q in ipairs(cases)do
        local state=f.new({x=1,y=2,z=30},0);state.q=q
        local before={w=q.w,x=q.x,y=q.y,z=q.z}
        local normal=f.camera_rotation(state,35)
        local below=f.camera_rotation(state,35,true)
        -- View forward = body underside, view right = body right, view up =
        -- body front. This checks physical axes rather than ambiguous Euler angles.
        for _,pair in ipairs({{{x=1,y=0,z=0},{x=0,y=0,z=-1}},
            {{x=0,y=1,z=0},{x=0,y=1,z=0}},{{x=0,y=0,z=1},{x=1,y=0,z=0}}})do
            local actual=unrealBasis(below,pair[1]);local expected=f.rotate(q,pair[2])
            for _,axis in ipairs({'x','y','z'})do near(actual[axis],expected[axis],1e-6)end
        end
        local mount=f.camera_position(state,true,.12);local offset=f.rotate(q,{x=0,y=0,z=-.09})
        for _,axis in ipairs({'x','y','z'})do near(mount[axis],state.p[axis]+offset[axis])end
        for _,key in ipairs({'w','x','y','z'})do near(state.q[key],before[key])end
        assert(f.camera_position(state,false,.12)==state.p,'forward view keeps original position')
        local returned=f.camera_rotation(state,35,false)
        for _,key in ipairs({'Pitch','Yaw','Roll'})do near(returned[key],normal[key])end
    end
end)
test('payload collision ends fixed-step movement at first contact',function()
    local state=f.new({x=0,y=0,z=20},0)
    state.v.x=10
    local contacts=0
    local continued=f.advance(state,zero,c,.1,function(body)
        contacts=contacts+1;body.p={x=5,y=0,z=20};return false
    end)
    assert(continued==false and contacts==1 and state.accumulator==0)
    near(state.p.x,5);near(state.p.z,20)
end)
print(n..' tests passed')
