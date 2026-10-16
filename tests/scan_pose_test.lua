-- Exercise the real writer, identity guards and calibrated projector. Only
-- packet I/O and UE4SS objects are fixtures; expected pixels use quaternions.
local Overlay
if arg[1]then
    local f=assert(io.open(arg[1],'r'));local source=f:read('*a');f:close()
    Overlay=assert(load(source,'@mod/Scripts/scan_overlay.lua'))()
else Overlay=dofile('mod/Scripts/scan_overlay.lua')end
Overlay.nativeBridge=nil
Overlay.view=nil -- Pose/packet fixture; the game-renderer integration is tested separately.
local oldOpen,oldFind,oldName=io.open,StaticFindObject,FName
local packet
io.open=function(path,mode)
    assert(path:match('^pose%-fixture/scan%-frame%-[ab]%.txt$'))
    if mode=='r'then return nil end
    assert(mode=='w')
    local buffer={}
    return {write=function(self,...)
        for i=1,select('#',...)do buffer[#buffer+1]=tostring(select(i,...))end
        return self
    end,close=function()packet=table.concat(buffer);return true end}
end
local address=100
local function object(fields)
    address=address+1;local o=fields or {};o.address=address
    function o:IsValid()return not self.invalid end
    function o:GetAddress()return self.address end
    return o
end
local function multiply(a,b)
    return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
        y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w}
end
local function axis(x,y,z,angle)
    local a=math.rad(angle)/2;local sine=math.sin(a)
    return {w=math.cos(a),x=x*sine,y=y*sine,z=z*sine}
end
local function cross(a,b)return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X}end
local function rotate(q,v)
    local u={X=q.x,Y=q.y,Z=q.z};local a=cross(u,v);local b=cross(u,a)
    return {X=v.X+2*(q.w*a.X+b.X),Y=v.Y+2*(q.w*a.Y+b.Y),Z=v.Z+2*(q.w*a.Z+b.Z)}
end
local function project(pose,p)
    local r=pose.rotation
    local q=multiply(axis(0,0,1,r.Yaw),multiply(axis(0,1,0,-r.Pitch),axis(1,0,0,-r.Roll)))
    local f,h,v=rotate(q,{X=1,Y=0,Z=0}),rotate(q,{X=0,Y=1,Z=0}),rotate(q,{X=0,Y=0,Z=1})
    local x,y,z=p.X-pose.position.X,p.Y-pose.position.Y,p.Z-pose.position.Z
    local depth=x*f.X+y*f.Y+z*f.Z
    if depth<=1 then return end
    return .5+.4*(x*h.X+y*h.Y+z*h.Z)/depth,.5-.8*(x*v.X+y*v.Y+z*v.Z)/depth
end
local function near(a,b)
    assert(type(a)=='number' and math.abs(a-b)<1e-7,tostring(a)..' != '..tostring(b))
end
local ok,err=xpcall(function()
    FName=function(value)return value end
    local world=object()
    local current={position={X=0,Y=0,Z=100},rotation={Pitch=0,Yaw=0,Roll=0}}
    local cached=current
    local component=object{FieldOfView=110}
    local camera=object{CameraComponent=component}
    function camera:K2_GetActorLocation()return current.position end
    function camera:K2_GetActorRotation()return current.rotation end
    local manager=object()
    function manager:GetCameraLocation()return cached.position end
    function manager:GetCameraRotation()return cached.rotation end
    function manager:GetFOVAngle()return 110 end
    local pc=object{PlayerCameraManager=manager}
    function pc:GetViewTarget()return camera end
    local calls=0
    function pc:ProjectWorldLocationToScreen(p,out)
        calls=calls+1;local x,y=project(cached,p)
        if not x then return false end
        out.X=x*1920;out.Y=y*1080;return true
    end
    local layout=object()
    function layout:GetViewportSize()return {X=1920,Y=1080}end
    StaticFindObject=function(path)assert(path=='/Script/UMG.Default__WidgetLayoutLibrary');return layout end
    local actor=object{RootComponent=object(),bHidden=false,position={X=5000,Y=0,Z=0},instance=1}
    function actor:GetWorld()return world end
    function actor:GetFName()return 'npc_'..self.instance end
    function actor:K2_GetActorLocation()return self.position end
    function actor:GetActorBounds(_,center,extent)
        local p=self.position;center.X,center.Y,center.Z=p.X,p.Y,p.Z+90
        extent.X,extent.Y,extent.Z=40,50,90
    end
    local offsets={jnt_head={X=0,Y=0,Z=175},jnt_spine_03={X=0,Y=0,Z=120},
        jnt_r_foot={X=0,Y=15,Z=5},jnt_l_foot={X=0,Y=-15,Z=5},
        jnt_r_hand={X=0,Y=50,Z=100},jnt_l_hand={X=0,Y=-50,Z=100}}
    local mesh=object{SkinnedAsset=object(),origin=false}
    function mesh:GetOwner()return actor end
    function mesh:DoesSocketExist(name)return offsets[name]~=nil end
    function mesh:GetSocketLocation(name)
        local p,o=actor.position,offsets[name]
        if self.origin then return {X=p.X,Y=p.Y,Z=p.Z}end
        return {X=p.X+o.X,Y=p.Y+o.Y,Z=p.Z+o.Z}
    end
    actor.Mesh=mesh
    local entry={mesh=mesh,type=1}
    local function marker()
        local p=actor.position
        return {actor=actor,type=1,actorPosition={X=p.X,Y=p.Y,Z=p.Z},position={X=p.X,Y=p.Y,Z=p.Z+90},
            extent={X=40,Y=50,Z=90},entry=entry,world=world,identityAddress=actor:GetAddress(),identityName=actor:GetFName()}
    end
    local s={world=world,pc=pc,camera=camera,flight={p={x=0,y=0,z=1}},worldExperiments={markers={}}}
    local writer=Overlay.new('pose-fixture/',{}, {},function()end)
    local now=0
    local function frame(dt)
        now=now+(dt or 1/60);s.worldExperiments.markers={marker()};writer(now,s)
        local count=tonumber(packet:match('^4 %d+ %d+ (%d+)\n'))
        if count==0 then return nil end
        local x,y,w,h=packet:match('\n1 ([%d.]+) ([%d.]+) ([%d.]+) ([%d.]+) ')
        assert(count==1 and x)
        return {tonumber(x),tonumber(y),tonumber(w),tonumber(h)}
    end
    local function expected()
        local l,t,r,b=math.huge,math.huge,-math.huge,-math.huge
        for name in pairs(offsets)do
            local x,y=project(current,mesh:GetSocketLocation(name));assert(x)
            l,t,r,b=math.min(l,x),math.min(t,y),math.max(r,x),math.max(b,y)
        end
        local margin=(b-t)*.025
        l,t,r,b=math.max(0,l-margin),math.max(0,t-margin),math.min(1,r+margin),math.min(1,b+margin)
        return {(l+r)/2,(t+b)/2,r-l,b-t}
    end
    local function exact(value)
        local want=expected();assert(value)
        for i=1,4 do near(value[i],want[i])end
    end
    -- Rigid actor translation and changing pitch/yaw/roll must never trail an
    -- EMA screen rectangle, including a camera cache one full frame behind.
    for _,fps in ipairs({60,144})do
        for i=1,fps*2 do
            local t=now+1/fps;cached=current
            current={position={X=100*math.sin(t),Y=250*math.cos(t*.8),Z=100+50*math.sin(t)},
                rotation={Pitch=5*math.sin(t*.6),Yaw=12*math.sin(t*.9),Roll=35*math.sin(t*.7)}}
            actor.position={X=5000+500*math.sin(t*.7),Y=400*math.cos(t*.6),Z=80*math.sin(t*.5)}
            local before=calls;exact(frame(1/fps));assert(calls-before==5)
        end
    end
    print('PASS pose filter preserves current camera pitch/yaw/roll and NPC translation at 60/144 Hz with five native probes')
    current={position={X=0,Y=0,Z=100},rotation={Pitch=0,Yaw=0,Roll=0}};cached=current
    actor.position={X=5000,Y=0,Z=0};frame(.2)
    local rawVariation,filteredVariation,previousRaw,previousFiltered=0,0
    for i=1,120 do
        local jitter=i%2==0 and 8 or -8
        offsets.jnt_r_hand.Y=50+jitter;offsets.jnt_l_hand.Y=-50-jitter
        local value=frame();local raw=expected()[3]
        if i>30 then rawVariation=rawVariation+math.abs(raw-previousRaw);filteredVariation=filteredVariation+math.abs(value[3]-previousFiltered)end
        previousRaw,previousFiltered=raw,value[3]
    end
    assert(filteredVariation<rawVariation*.4,'small socket jitter must fall by at least 60%, not just be delayed')
    -- The source pose and actors must remain untouched by the visual filter.
    near(offsets.jnt_r_hand.Y,58);near(offsets.jnt_l_hand.Y,-58);near(actor.position.X,5000)
    print(string.format('PASS small animation jitter falls by %.1f%% while source sockets and actor transforms remain unchanged',
        (1-filteredVariation/rawVariation)*100))
    -- Snap every discontinuity, rather than blending an unrelated/stale pose.
    offsets.jnt_r_hand.Y=200;offsets.jnt_l_hand.Y=-200;exact(frame())
    offsets.jnt_r_hand.Y=50;offsets.jnt_l_hand.Y=-50;exact(frame())
    actor.position.X=7500;offsets.jnt_r_hand.Y=58;exact(frame()) -- Teleport.
    offsets.jnt_r_hand.Y=50;exact(frame(.2)) -- Long publication gap.
    actor.instance=2;offsets.jnt_r_hand.Y=58;exact(frame()) -- Reused address/new FName.
    entry={mesh=mesh,type=1};offsets.jnt_r_hand.Y=50;exact(frame())
    local previousMesh=mesh
    mesh=object();for key,value in pairs(previousMesh)do if key~='address'then mesh[key]=value end end
    actor.Mesh=mesh;entry.mesh=mesh;offsets.jnt_r_hand.Y=58;exact(frame())
    world=object();s.world=world;offsets.jnt_r_hand.Y=58;exact(frame())
    mesh.origin=true;assert(frame(),'genuine collider fallback remains available')
    mesh.origin=false;offsets.jnt_r_hand.Y=50;exact(frame())
    actor.position.Y=50000;assert(frame()==nil,'raw current off-screen pose clears immediately')
    actor.position.Y=0;offsets.jnt_r_hand.Y=58;exact(frame())
    actor.RootComponent.invalid=true;assert(frame()==nil,'invalid current actor cannot retain filtered brackets')
    actor.RootComponent.invalid=false;offsets.jnt_r_hand.Y=50;exact(frame())
    writer(now+.001,nil);assert(packet:match('^4 %d+ %d+ 0\n'))
    offsets.jnt_r_hand.Y=58;exact(frame())
    print('PASS pose, teleport, gap, identity, entry, world, LOD, off-screen, invalid actor and FPV exit discard old smoothing history')
end,debug.traceback)
io.open,StaticFindObject,FName=oldOpen,oldFind,oldName
assert(ok,err)
