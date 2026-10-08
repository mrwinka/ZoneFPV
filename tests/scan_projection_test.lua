local M=dofile('mod/Scripts/scan_projection.lua')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function near(a,b,tolerance)
    assert(type(a)=='number' and math.abs(a-b)<(tolerance or 1e-9),tostring(a)..' != '..tostring(b))
end
-- Independent oracle uses quaternion composition and cross products, not
-- the production module's explicit FRotator matrix or calibration routine.
local function multiply(a,b)
    return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
        y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w}
end
local function axis(x,y,z,degrees)
    local angle=math.rad(degrees)/2;local sine=math.sin(angle)
    return {w=math.cos(angle),x=x*sine,y=y*sine,z=z*sine}
end
local function cross(a,b)return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X}end
local function rotate(q,v)
    local u={X=q.x,Y=q.y,Z=q.z};local first=cross(u,v);local second=cross(u,first)
    return {X=v.X+2*(q.w*first.X+second.X),Y=v.Y+2*(q.w*first.Y+second.Y),Z=v.Z+2*(q.w*first.Z+second.Z)}
end
local function oracleBasis(r)
    local q=multiply(axis(0,0,1,r.Yaw),multiply(axis(0,1,0,-r.Pitch),axis(1,0,0,-r.Roll)))
    return rotate(q,{X=1,Y=0,Z=0}),rotate(q,{X=0,Y=1,Z=0}),rotate(q,{X=0,Y=0,Z=1})
end
local function localPoint(p,r,depth,horizontal,vertical)
    local f,h,v=oracleBasis(r)
    return {X=p.X+f.X*depth+h.X*horizontal+v.X*vertical,
        Y=p.Y+f.Y*depth+h.Y*horizontal+v.Y*vertical,Z=p.Z+f.Z*depth+h.Z*horizontal+v.Z*vertical}
end
local function oracle(pose,lens,world)
    local f,h,v=oracleBasis(pose.rotation);local x,y,z=world.X-pose.position.X,world.Y-pose.position.Y,world.Z-pose.position.Z
    local depth=x*f.X+y*f.Y+z*f.Z
    if depth<=1 then return end
    local horizontal=(x*h.X+y*h.Y+z*h.Z)/depth
    local vertical=(x*v.X+y*v.Y+z*v.Z)/depth
    return lens.x+lens.rx*horizontal+lens.ux*vertical,lens.y+lens.ry*horizontal+lens.uy*vertical
end
local nextAddress=100
local function object(t)
    nextAddress=nextAddress+1;t=t or {};t.address=nextAddress
    function t:IsValid()return not self.invalid end
    function t:GetAddress()return self.address end
    return t
end
local function fixture(lens)
    local env={calls=0,lens=lens or {x=.5,y=.5,rx=.4,ry=0,ux=0,uy=-.8}}
    env.current={position={X=0,Y=0,Z=0},rotation={Pitch=0,Yaw=0,Roll=0}}
    env.cached={position={X=0,Y=0,Z=0},rotation={Pitch=0,Yaw=0,Roll=0}}
    env.component=object({FieldOfView=110})
    env.camera=object({CameraComponent=env.component})
    function env.camera:K2_GetActorLocation()return env.current.position end
    function env.camera:K2_GetActorRotation()return env.current.rotation end
    env.manager=object({fov=110})
    function env.manager:GetCameraLocation()return env.cached.position end
    function env.manager:GetCameraRotation()return env.cached.rotation end
    function env.manager:GetFOVAngle()return self.fov end
    env.pc=object({PlayerCameraManager=env.manager,view=env.camera})
    function env.pc:GetViewTarget()return self.view end
    env.session={pc=env.pc,camera=env.camera}
    env.native=function(world)
        env.calls=env.calls+1
        return oracle(env.cached,env.lens,world)
    end
    return env
end
test('native lens keeps principal point, ultrawide scale, both axes and cross terms',function()
    local env=fixture({x=.471,y=.523,rx=.321,ry=.017,ux=-.013,uy=-.321*3440/1440})
    env.cached.position={X=41000,Y=-12000,Z=2500}
    env.cached.rotation={Pitch=35,Yaw=-143,Roll=81}
    env.current.position={X=41500,Y=-12200,Z=2600}
    env.current.rotation={Pitch=-21,Yaw=172,Roll=-77}
    local project,reason=M.new(env.session,env.native);assert(project,reason);assert(env.calls==5)
    for _,v in ipairs({{10,0,0},{100,15,-3},{10000,-3000,1700},{350,120,250},{1200,-2300,-500}})do
        local world=localPoint(env.current.position,env.current.rotation,v[1],v[2],v[3])
        local x,y=project(world);local expectedX,expectedY=oracle(env.current,env.lens,world)
        near(x,expectedX);near(y,expectedY)
    end
    assert(env.calls==5,'target projections never re-enter the native camera cache')
end)
test('separate current mount and previous PCM cache follow every 60 and 144 Hz frame',function()
    for _,fps in ipairs({60,144})do
        local env=fixture();local target={X=8000,Y=350,Z=1600};local previous=env.current
        local staleError=0
        for frame=1,fps*3 do
            local t=frame/fps
            env.cached=previous
            env.current={position={X=100+500*math.sin(t*.83),Y=300*math.sin(t*1.12),Z=900+80*math.cos(t*1.31)},
                rotation={Pitch=15*math.sin(t*1.33),Yaw=30*math.sin(t*.94),Roll=80*math.sin(t*1.19)}}
            local before=env.calls;local project,reason=M.new(env.session,env.native);assert(project,reason)
            local x,y=project(target);local expectedX,expectedY=oracle(env.current,env.lens,target)
            local staleX,staleY=oracle(env.cached,env.lens,target)
            near(x,expectedX);near(y,expectedY)
            staleError=math.max(staleError,math.abs(staleX-expectedX),math.abs(staleY-expectedY))
            assert(env.calls-before==5,'fixed per-frame native budget at '..fps..' Hz')
            previous=env.current
        end
        assert(staleError>.001,'fixture reproduces a visible previous-camera projection defect')
    end
end)
test('jittered frame durations do not throttle projection to 30 Hz',function()
    local env=fixture();local t=0;local target={X=5000,Y=200,Z=1200};local previous=env.current
    for frame=1,150 do
        local durations={.016,.018,.014,.006,.008};t=t+durations[(frame-1)%#durations+1]
        env.cached=previous
        env.current={position={X=0,Y=100*t,Z=0},rotation={Pitch=7*t,Yaw=20*t,Roll=-9*t}}
        local project,reason=M.new(env.session,env.native);assert(project,reason)
        local x,y=project(target);local expectedX,expectedY=oracle(env.current,env.lens,target)
        near(x,expectedX);near(y,expectedY);previous=env.current
    end
    assert(env.calls==150*5)
end)
test('vertical lower mount, banks and upside-down views preserve full orientation',function()
    for _,pitch in ipairs({-90,90,-89.9999999,89.9999999,173})do
        for _,yaw in ipairs({0,37,180,-143})do
            for _,roll in ipairs({0,80,-80,180})do
                local env=fixture();env.cached.rotation={Pitch=11,Yaw=14,Roll=-16}
                env.current.position={X=1400,Y=-1200,Z=6000-.09*100}
                env.current.rotation={Pitch=pitch,Yaw=yaw,Roll=roll}
                local project,reason=M.new(env.session,env.native);assert(project,reason)
                local world=localPoint(env.current.position,env.current.rotation,800,100,-60)
                local x,y=project(world);local expectedX,expectedY=oracle(env.current,env.lens,world)
                near(x,expectedX);near(y,expectedY)
            end
        end
    end
end)
test('projection rejects the camera eye, behind-camera points and malformed coordinates',function()
    local env=fixture();env.current.rotation={Pitch=-90,Yaw=45,Roll=120}
    local project,reason=M.new(env.session,env.native);assert(project,reason)
    for _,depth in ipairs({-10000,-10,0,.99,1})do
        assert(project(localPoint(env.current.position,env.current.rotation,depth,0,0))==nil)
    end
    assert(project({X=0/0,Y=0,Z=0})==nil)
    assert(project({X=math.huge,Y=0,Z=0})==nil)
    assert(project({X='0',Y=0,Z=0})==nil)
    assert(project({X=1e13,Y=0,Z=0})==nil)
    local x,y,depth=project(localPoint(env.current.position,env.current.rotation,1.1,0,0))
    near(x,.5);near(y,.5);near(depth,1.1)
end)
test('FOV transitions fail closed until the current mount and cache use the same lens',function()
    local env=fixture();env.component.FieldOfView=140
    local project,reason=M.new(env.session,env.native)
    assert(not project and reason=='camera_lens_pending' and env.calls==0)
    env.manager.fov=140;env.lens={x=.5,y=.5,rx=.182,ry=0,ux=0,uy=-.435}
    project,reason=M.new(env.session,env.native);assert(project,reason)
    local x,y=project({X=1000,Y=300,Z=150});near(x,.5+.182*.3);near(y,.5-.435*.15)
    assert(env.calls==5)
end)
test('invalid objects, replaced view target and unavailable pose do not query native projection',function()
    for _,mutate in ipairs({
        function(e)e.pc.invalid=true end,function(e)e.camera.invalid=true end,
        function(e)e.manager.invalid=true end,function(e)e.component.invalid=true end,
        function(e)e.pc.view=object()end,function(e)e.cached.position={X=0/0,Y=0,Z=0}end,
        function(e)e.current.rotation={Pitch=0,Yaw=math.huge,Roll=0}end,
        function(e)e.component.FieldOfView=180 end,function(e)e.manager.fov=0 end,
        function(e)e.camera.address=nil end,
    })do
        local env=fixture();mutate(env);local project,reason=M.new(env.session,env.native)
        assert(not project and type(reason)=='string' and env.calls==0)
    end
    local project,reason=M.new(nil,function()error('must not be called')end);assert(not project and reason)
    project,reason=M.new(fixture().session,nil);assert(not project and reason=='native_projection_unavailable')
end)
test('camera or lens mutation during native calibration discards the whole snapshot',function()
    for _,mutate in ipairs({
        function(e)e.current.position={X=1,Y=0,Z=0}end,
        function(e)e.cached.rotation={Pitch=1,Yaw=0,Roll=0}end,
        function(e)e.pc.view=object()end,
        function(e)e.camera.CameraComponent=object({FieldOfView=110})end,
        function(e)e.pc.PlayerCameraManager=object()end,
        function(e)e.camera.invalid=true end,
        function(e)e.manager.fov=109 end,
    })do
        local env=fixture();local native=env.native
        local function changing(world)
            local x,y=native(world);if env.calls==5 then mutate(env)end;return x,y
        end
        local project,reason=M.new(env.session,changing)
        assert(not project and reason=='camera_changed_during_calibration')
        assert(env.calls==5)
    end
end)
test('native exceptions, missing samples and degenerate projections fail closed',function()
    for _,native in ipairs({function()error('native failure')end,function()return nil end,
        function()return 0/0,0 end,function()return .5,.5 end,function()return math.huge,0 end})do
        local env=fixture();local calls=0
        local project,reason=M.new(env.session,function(world)calls=calls+1;return native(world)end)
        assert(not project and type(reason)=='string' and calls<=5)
    end
end)
test('different-depth probes reject orthographic and inconsistent native lens samples',function()
    local env=fixture()
    local project,reason=M.new(env.session,function(world)return .5+world.Y/1000,.5-world.Z/1000 end)
    assert(not project and reason=='native_calibration_inconsistent')
    local native=env.native
    project,reason=M.new(env.session,function(world)
        local x,y=native(world);if env.calls==5 then x=x+.0001 end;return x,y
    end)
    assert(not project and reason=='native_calibration_inconsistent' and env.calls==5)
end)
test('one calibrated snapshot handles 16 targets and all eight corners without extra native calls',function()
    local env=fixture();local project,reason=M.new(env.session,env.native);assert(project,reason)
    for i=1,16 do for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
        local world={X=1000+i*70+x*15,Y=y*40,Z=z*70}
        local px,py=project(world);local expectedX,expectedY=oracle(env.current,env.lens,world)
        near(px,expectedX);near(py,expectedY)
    end end end end
    assert(env.calls==5,'128 pure point projections share only five native probes')
end)
test('returned projector owns its pose snapshot until the next factory call',function()
    local env=fixture();local project,reason=M.new(env.session,env.native);assert(project,reason)
    env.current.position.Y=700;env.cached.rotation.Yaw=60
    local x,y=project({X=1000,Y=100,Z=100});near(x,.54);near(y,.42)
    local refreshed=M.new(env.session,env.native);assert(refreshed)
    local expectedX,expectedY=oracle(env.current,env.lens,{X=1000,Y=100,Z=100})
    x,y=refreshed({X=1000,Y=100,Z=100});near(x,expectedX);near(y,expectedY)
end)
test('production scanner writer, actual target validation and v4 packets share the current calibrated camera',function()
    local Overlay=dofile('mod/Scripts/scan_overlay.lua')
    Overlay.nativeBridge=nil
    local previousOpen,previousFind,previousName=io.open,StaticFindObject,FName
    local packets,paths={},{}
    -- Packet I/O is captured in memory; real writer, projection factory and
    -- target validator execute together without leaving runtime files behind.
    io.open=function(path,mode)
        if mode=='r' then return nil end
        assert(mode=='w' and path:match('scan%-frame%-[ab]%.txt$'))
        local out={}
        function out:write(...)
            for i=1,select('#',...)do out[#out+1]=tostring(select(i,...))end
            return self
        end
        function out:close()
            packets[#packets+1]=table.concat(out);paths[#paths+1]=path;return true
        end
        return out
    end
    FName=nil
    local layout=object()
    function layout:GetViewportSize()return {X=3440,Y=1440}end
    StaticFindObject=function(path)assert(path=='/Script/UMG.Default__WidgetLayoutLibrary');return layout end
    local ok,err=xpcall(function()
        local env=fixture({x=.48,y=.53,rx=.37,ry=.012,ux=-.008,uy=-.37*3440/1440})
        env.session.world=object();env.session.flight={p={x=0,y=0,z=0}}
        local actor=object({RootComponent=object(),bHidden=false})
        function actor:GetWorld()return env.session.world end
        function actor:GetFName()return 'anomaly_fixture_1' end
        function actor:HasAnyFlags()return false end
        function actor:IsActorBeingDestroyed()return false end
        function actor:K2_GetActorLocation()return {X=7000,Y=500,Z=1000}end
        local center,extent=actor:K2_GetActorLocation(),{X=50,Y=60,Z=90}
        local marker={actor=actor,type=3,actorPosition=center,position=center,extent=extent,
            world=env.session.world,identityAddress=actor:GetAddress(),identityName=actor:GetFName()}
        env.session.worldExperiments={markers={marker}}
        function env.pc:ProjectWorldLocationToScreen(position,out,relative)
            assert(relative==true)
            local x,y=env.native(position);if not x then return false end
            out.X=x*3440;out.Y=y*1440;return true
        end
        local logs={}
        local writer=Overlay.new('memory/',{}, {},function(line)logs[#logs+1]=line end)
        local prior=env.current
        local generation,sequence
        for _,fps in ipairs({60,144})do
            for frame=1,fps do
                local t=frame/fps;env.cached=prior
                env.current={position={X=100,Y=300*t,Z=400},rotation={Pitch=5*t,Yaw=20*t,Roll=-40*t}}
                local before=env.calls;writer(t,env.session)
                assert(env.calls-before==5,'integrated writer calibrates on every camera frame at '..fps..' Hz')
                local packet=packets[#packets]
                local packetGeneration,packetSequence,packetCount=packet:match('^4 (%d+) (%d+) (%d+)\n')
                assert(packetCount=='1','actual validated anomaly is present')
                if generation then assert(packetGeneration==generation and tonumber(packetSequence)==sequence+1)end
                generation,sequence=packetGeneration,tonumber(packetSequence)
                assert(packet:match('\n'..generation..' '..packetSequence..'\n$'),'matching generation and sequence trailer')
                assert(paths[#paths]==('memory/scan-frame-'..(sequence%2==1 and 'b' or 'a')..'.txt'),'alternating v4 slots')
                local x,y,w,h=packet:match('\n3 ([%d.]+) ([%d.]+) ([%d.]+) ([%d.]+) ')
                assert(x and y and w and h)
                local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
                for _,a in ipairs({-1,1})do for _,b in ipairs({-1,1})do for _,c in ipairs({-1,1})do
                    local sx,sy=oracle(env.current,env.lens,{X=center.X+a*extent.X,Y=center.Y+b*extent.Y,Z=center.Z+c*extent.Z})
                    left=math.min(left,sx);right=math.max(right,sx);top=math.min(top,sy);bottom=math.max(bottom,sy)
                end end end
                near(tonumber(x),(left+right)/2,1e-7);near(tonumber(y),(top+bottom)/2,1e-7)
                near(tonumber(w),right-left,1e-7);near(tonumber(h),bottom-top,1e-7)
                prior=env.current
            end
        end
        local before=env.calls;env.component.FieldOfView=140;writer(2,env.session)
        assert(env.calls==before and packets[#packets]:match('^4 %d+ %d+ 0\n'),'pending FOV clears a complete packet without native probes')
        env.component.FieldOfView=110;actor.invalid=true;writer(2.01,env.session)
        assert(packets[#packets]:match('^4 %d+ %d+ 0\n'),'invalid cached target clears output immediately')
        actor.invalid=false;marker.identityName='previous_anomaly_instance';writer(2.02,env.session)
        assert(packets[#packets]:match('^4 %d+ %d+ 0\n'),'reused identity cannot inherit a scan rectangle')
        assert(#logs==0,'valid calibration, pending lens and discarded stale actors are normal conditions')
        assert(#packets==207,'every populated camera frame and invalidation publishes once')
    end,debug.traceback)
    io.open,StaticFindObject,FName=previousOpen,previousFind,previousName
    assert(ok,err)
end)
print('PASS '..count..' coherent scanner projection regressions')
