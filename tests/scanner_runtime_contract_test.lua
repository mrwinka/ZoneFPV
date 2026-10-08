-- Use the actual target discovery and packet writer with UE4SS-shaped objects.
-- Optional argv[1] lets the pre-fix installed module reproduce the regression.
local targets=dofile(arg[1] or 'mod/Scripts/world_experiments.lua')
local overlay=dofile('mod/Scripts/scan_overlay.lua')
overlay.targets=targets;overlay.nativeBridge=nil
overlay.projection={new=function(_,project)return project end}
local nextAddress=0x10000
local null={IsValid=function()return false end,GetAddress=function()return 0 end}
setmetatable(null,{__index=function()return null end,
    __call=function()error('unavailable UE4SS reflected function')end})
local function object(fields)
    local o=fields or {};nextAddress=nextAddress+8;o.address=nextAddress;o.invalid=false
    function o:IsValid()return not self.invalid end
    function o:GetAddress()return self.address end
    -- A missing reflected member is an invalid UObject, never nil.
    return setmetatable(o,{__index=function()return null end})
end
local nameMt={__eq=function(a,b)return a.index==b.index and a.value==b.value end}
local function name(index,value)
    return setmetatable({index=index,value=value,GetComparisonIndex=function()return index end,
        ToString=function()return value end},nameMt)
end
local boneIndices={};local nextBoneIndex=0;FName=function(value)
    if not boneIndices[value]then nextBoneIndex=nextBoneIndex+1;boneIndices[value]=nextBoneIndex end
    return name(boneIndices[value],value)
end
local world=object()
local npc=object{world=world,RootComponent=object(),bHidden=false,position={X=1000,Y=0,Z=0},instance=1}
function npc:GetWorld()return self.world or world end
function npc:GetFName()return name(101,'TestNPC_'..self.instance)end
function npc:K2_GetActorLocation()return self.position end
function npc:GetActorBounds(colliding,center,extent,children)
    assert(colliding==true and children==false)
    center.X,center.Y,center.Z=self.position.X,self.position.Y,90
    extent.X,extent.Y,extent.Z=35,40,90
end
local asset=object()
local mesh=object{SkinnedAsset=asset,owner=npc}
function mesh:GetSkinnedAsset()return self.SkinnedAsset end
function mesh:GetOwner()return self.owner or npc end
local socketPoints={jnt_head={X=1000,Y=0,Z=175},jnt_spine_03={X=1000,Y=0,Z=120},
    jnt_r_foot={X=1000,Y=15,Z=5},jnt_l_foot={X=1000,Y=-15,Z=5},
    jnt_r_hand={X=1000,Y=40,Z=100},jnt_l_hand={X=1000,Y=-40,Z=100}}
function mesh:DoesSocketExist(bone)return socketPoints[bone:ToString()]~=nil end
function mesh:GetSocketLocation(bone)return socketPoints[bone:ToString()]end
npc.Mesh=mesh
local pc=object()
function pc:ProjectWorldLocationToScreen(position,out,relative)
    assert(relative==true)
    if position.X<=1 then return false end
    out.X=(.5+position.Y/position.X)*1920
    out.Y=(.5-position.Z/position.X)*1080
    return true
end
local layout=object()
function layout:GetViewportSize(context)assert(context==pc);return {X=1920,Y=1080}end
StaticFindObject=function(path)
    if path=='/Script/UMG.Default__WidgetLayoutLibrary'then return layout end
    return null
end
local notifications={}
NotifyOnNewObject=function(path,callback)notifications[path]=callback end
FindAllOf=function(class)return class=='Agent' and {npc} or {}end
local s={world=world,pawn=object(),camera=object(),pc=pc,flight={p={x=0,y=0,z=0}}}
local api=targets.new(object(),function()end)
api.clock=function()return 0 end
local g=api:update(s,{characters=true},.016,0)
assert(#g.entries==1 and #g.markers==1 and g.markers[1].type==1,
    'copied FName identity must remain a genuine NPC target')
-- A filename prefix isolates this suite from other scanner packet fixtures.
local root='build/scanner-runtime-contract-'
local diagnosticLogs={}
local writer=overlay.new(root,{}, {},function(line)diagnosticLogs[#diagnosticLogs+1]=line end)
local function count()
    local latest
    for _,suffix in ipairs({'a','b'})do
        local f=io.open(root..'scan-frame-'..suffix..'.txt','r')
        if f then
            local packet=f:read('*a');f:close()
            local generation,seq,n=packet:match('^4 (%d+) (%d+) (%d+)\n')
            local tailGeneration,tailSeq=packet:match('\n(%d+) (%d+)\n$')
            assert(generation==tailGeneration and seq==tailSeq,'complete production packet')
            seq,n=tonumber(seq),tonumber(n)
            if not latest or seq>latest.seq then latest={seq=seq,count=n,text=packet}end
        end
    end
    assert(latest);return latest.count,latest.text
end
writer(0,s);assert(count()==1,'valid NPC reaches production packet writer')
local posedPoints=socketPoints
socketPoints={}
for bone in pairs(posedPoints)do socketPoints[bone]={X=1000,Y=0,Z=0}end
writer(.001,s)
assert(count()==1,'loaded NPC with a collapsed construction/LOD pose uses its genuine collider')
for bone in pairs(posedPoints)do socketPoints[bone]={X=1000,Y=1500,Z=-1500}end
writer(.0015,s)
assert(count()==1,'collapsed LOD/component-origin sockets do not erase a current genuine collider')
for bone,p in pairs(posedPoints)do socketPoints[bone]={X=p.X,Y=p.Y+1500,Z=p.Z-1500}end
writer(.0017,s)
assert(count()==1,'noncollapsed stale component pose outside the live actor cannot erase its current collider')
socketPoints=posedPoints
npc.position.Y=1500
for _,p in pairs(socketPoints)do p.Y=p.Y+1500 end
writer(.0018,s)
assert(count()==0,'genuine posed off-screen actor remains hidden')
npc.position.Y=0
for _,p in pairs(socketPoints)do p.Y=p.Y-1500 end
socketPoints=posedPoints
writer(.002,s);assert(count()==1,'posed skeleton resumes after its animation becomes available')
-- Getter compatibility does not relax asset validity or ownership.
mesh.GetSkinnedAsset=nil
assert(mesh.GetSkinnedAsset==null and mesh.GetSkinnedAsset~=nil)
api:update(s,{characters=true},.016,.016);writer(.016,s)
assert(count()==1,'loaded reflected SkinnedAsset survives absent getter sentinel')
mesh.SkinnedAsset=null;mesh.SkeletalMesh=asset
api:update(s,{characters=true},.016,.032);writer(.032,s)
assert(count()==1,'loaded legacy SkeletalMesh remains usable')
mesh.SkeletalMesh=null
api:update(s,{characters=true},.016,.048);writer(.048,s)
assert(count()==0 and #g.entries==1 and g.entries[1].suspended,
    'invalid asset cannot project default-origin sockets or cached collider')
mesh.SkinnedAsset=asset
api:update(s,{characters=true},.016,.1);writer(.1,s);assert(count()==1)
mesh.owner=object()
api:update(s,{characters=true},.016,.15);writer(.15,s)
assert(count()==0,'mesh now owned by another actor must remain excluded')
mesh.owner=npc
api:update(s,{characters=true},.016,.2);writer(.2,s);assert(count()==1)
-- Same comparison index/address with a new instance suffix is another actor.
local previous=g.markers[1];npc.instance=2
assert(not targets.markerCurrent(s,previous),'instance-number reuse invalidates old target')
api:update(s,{characters=true},.016,.25);writer(.25,s)
assert(count()==0 and #g.entries==0,'old actor identity is retired immediately')
notifications['/Script/Stalker2.Agent'](npc)
api:update(s,{characters=true},.016,.3);writer(.3,s)
assert(count()==1 and #g.entries==1,'fresh construction establishes the new identity')
npc.RootComponent=null;writer(.35,s);assert(count()==0,'null root cannot publish an origin target')
npc.RootComponent=object();writer(.4,s);assert(count()==1)
writer(1.1,s)
assert(#diagnosticLogs==1 and diagnosticLogs[1]:find('Scanner NPC:',1,true)
    and diagnosticLogs[1]:find('projection=ready',1,true),'diagnostic summary identifies discovery and publication stages')
writer(1.2,s);assert(#diagnosticLogs==1,'per-frame writer does not spam diagnostics')
writer(6.1,s);assert(#diagnosticLogs==2,'subsequent diagnostic summaries are five seconds apart')
npc.world=object();writer(6.2,s);assert(count()==0,'foreign-world actor is rejected')
api:finish(s)

-- The real target cache and packet writer must recover a SAME existing NPC
-- after streamed assets load beyond the initial three-second retry window.
-- No second constructor callback or global Agent search is available here.
local baseRoot=root
for _,loadAt in ipairs({5,10})do
    root='build/scanner-runtime-contract-late-'..loadAt..'-'
    npc.world=world;npc.instance=npc.instance+1;npc.RootComponent=object();npc.bHidden=false
    mesh.owner=npc;mesh.SkinnedAsset=null;mesh.SkeletalMesh=null
    local lookups=0
    FindAllOf=function(class)lookups=lookups+1;return class=='Agent' and {npc} or {}end
    local lateAPI=targets.new(object(),function()end);lateAPI.clock=function()return 0 end
    local lateSession={world=world,pawn=object(),camera=object(),pc=pc,flight={p={x=0,y=0,z=0}}}
    local lateWriter=overlay.new(root,{}, {},function()end)
    for frame=0,(loadAt+3)*60 do
        local now=frame/60
        if frame==loadAt*60 then mesh.SkinnedAsset=asset end
        local lateCache=lateAPI:update(lateSession,{characters=true},1/60,now)
        lateWriter(now,lateSession)
        if now<loadAt then assert(count()==0 and #lateCache.entries==0,'unloaded real NPC cannot publish a fallback marker')end
        if now>=loadAt+1.2 then
            assert(count()==1 and #lateCache.entries==1,
                'same existing NPC stays in every real packet after late streamed asset readiness')
        end
    end
    assert(lookups==1,'registered construction support cannot cause another global lookup to mask late readiness')
    lateAPI:finish(lateSession)
    os.remove(root..'scan-frame-a.txt');os.remove(root..'scan-frame-b.txt')
end
root=baseRoot
print('PASS production packets persist after same NPC mesh loads at 5/10 seconds without a new construction event or global search')

-- A crowded scene reaches the real discovery, current-camera projector,
-- live pose/collider checks, metadata and packet writer on every frame.
-- Forty-eight nearer actors behind the eye must never hide eight farther
-- on-screen NPCs, including actors whose modular animation pose is pending.
overlay.projection=dofile('mod/Scripts/scan_projection.lua')
local actors,frontActors={},{}
local socketReads,boundsReads,nativeProbes,metadataRequests=0,0,0,0
local offsets={jnt_head={Y=0,Z=175},jnt_spine_03={Y=0,Z=120},
    jnt_r_foot={Y=15,Z=5},jnt_l_foot={Y=-15,Z=5},
    jnt_r_hand={Y=40,Z=100},jnt_l_hand={Y=-40,Z=100}}
local function makeNPC(index,x,y)
    local actor=object{world=world,RootComponent=object(),bHidden=false,position={X=x,Y=y,Z=0},pose='ready'}
    function actor:GetWorld()return self.world end
    function actor:GetFName()return name(1000+index,'CrowdNPC_'..index)end
    function actor:K2_GetActorLocation()return self.position end
    function actor:GetActorBounds(colliding,center,extent,children)
        boundsReads=boundsReads+1;assert(colliding==true and children==false)
        center.X,center.Y,center.Z=self.position.X,self.position.Y,self.position.Z+90
        extent.X,extent.Y,extent.Z=35,40,self.boundsInvalid==true and 0 or 90
    end
    local component=object{SkinnedAsset=asset,owner=actor}
    function component:GetOwner()return self.owner end
    function component:DoesSocketExist(bone)return offsets[bone:ToString()]~=nil end
    function component:GetSocketLocation(bone)
        socketReads=socketReads+1
        local p,o=actor.position,offsets[bone:ToString()]
        if actor.pose=='origin'then return {X=0,Y=0,Z=0}end
        if actor.pose=='collapsed'then return {X=p.X,Y=p.Y,Z=p.Z}end
        local shift=actor.pose=='stale' and 10000 or 0
        return {X=p.X+shift,Y=p.Y+o.Y,Z=p.Z+o.Z}
    end
    actor.Mesh=component;actors[#actors+1]=actor
    return actor
end
for i=1,48 do makeNPC(i,-1000-i*10,(i%7-3)*35)end
for i=1,8 do frontActors[i]=makeNPC(48+i,4000+i*20,(i-4.5)*200)end
FindAllOf=function(class)return class=='Agent' and actors or {}end
local current={position={X=0,Y=0,Z=125},yaw=0}
local cached=current
local component=object{FieldOfView=110}
local camera=object{CameraComponent=component}
function camera:K2_GetActorLocation()return current.position end
function camera:K2_GetActorRotation()return {Pitch=0,Yaw=current.yaw,Roll=0}end
local manager=object()
function manager:GetCameraLocation()return cached.position end
function manager:GetCameraRotation()return {Pitch=0,Yaw=cached.yaw,Roll=0}end
function manager:GetFOVAngle()return 110 end
pc.PlayerCameraManager=manager
function pc:GetViewTarget()return camera end
function pc:ProjectWorldLocationToScreen(position,out,relative)
    nativeProbes=nativeProbes+1;assert(relative==true)
    local yaw=math.rad(cached.yaw)
    local dx,dy,dz=position.X-cached.position.X,position.Y-cached.position.Y,position.Z-cached.position.Z
    local depth=dx*math.cos(yaw)+dy*math.sin(yaw)
    if depth<=1 then return false end
    out.X=(.5+.4*(-dx*math.sin(yaw)+dy*math.cos(yaw))/depth)*1920
    out.Y=(.5-.8*dz/depth)*1080
    return true
end
local crowdSession={world=world,pawn=object(),camera=camera,pc=pc,flight={p={x=0,y=0,z=1.25}}}
local crowdAPI=targets.new(object(),function()end)
crowdAPI.clock=function()return 0 end
overlay.nativeBridge={new=function()return {metadata=function(_,pawn,selected)
    assert(pawn==crowdSession.pawn and #selected>0 and #selected<=16)
    metadataRequests=metadataRequests+1
    local result={}
    for _,actor in ipairs(selected)do
        assert(actor.position.X>0,'metadata budget belongs to current drawable actors')
        result[actor:GetAddress()]={relation=0,names={}}
    end
    return result
end}end}
for frame=1,4 do crowdAPI:update(crowdSession,{characters=true},.016,frame*.016)end
assert(#crowdSession.worldExperiments.entries==56 and #crowdSession.worldExperiments.markers==56,
    'world selection keeps visible candidates beyond thirty-two nearer off-screen actors')
local crowdWriter=overlay.new(root,{}, {},function()end)
local elapsed=.1
for _,fps in ipairs({60,144})do
    for frame=1,fps*3 do
        elapsed=elapsed+1/fps;cached=current
        current={position={X=0,Y=100*math.sin(elapsed),Z=125},yaw=5*math.sin(elapsed*.8)}
        crowdSession.flight.p.y=current.position.Y/100
        for i,actor in ipairs(frontActors)do
            local poses={'ready','origin','collapsed','stale'}
            actor.pose=poses[(frame+i-1)%#poses+1]
        end
        crowdAPI:update(crowdSession,{characters=true},1/fps,elapsed)
        local probes,bounds,sockets=nativeProbes,boundsReads,socketReads
        crowdWriter(elapsed,crowdSession)
        local n,packet=count()
        assert(n==8,'all eight visible NPCs persist every frame at '..fps..' Hz, frame '..frame)
        assert(nativeProbes-probes==5,'crowd projection uses exactly five native lens probes')
        assert(boundsReads-bounds==8,'cached broad phase prevents hidden crowd from entering native collider queries')
        assert(socketReads-sockets<=8*6,'only visible live NPCs query current pose sockets')
        local rows=0
        for line in packet:gmatch('[^\n]+')do
            local d,relation=line:match('^1 [^\n]+ ([%d.]+) ([%-]?%d+) %d+$')
            if d then rows=rows+1;assert(tonumber(d)>35 and relation=='0','near hidden actors cannot consume rows or metadata')end
        end
        assert(rows==8)
    end
end
assert(metadataRequests>30 and metadataRequests<70,'metadata cadence stays independent of per-frame geometry')
frontActors[1].boundsInvalid=true;frontActors[1].pose='ready'
crowdWriter(elapsed+.0005,crowdSession)
assert(count()==8,'genuine on-screen posed skeleton does not require a collision fallback')
frontActors[1].pose='origin';crowdWriter(elapsed+.001,crowdSession)
assert(count()==7,'invalid fresh collider cannot reuse cached geometry during pose fallback')
local capsule=object{owner=frontActors[1],world=world,radius=37,halfHeight=105,
    position={X=frontActors[1].position.X+25,Y=frontActors[1].position.Y+15,Z=90},up={X=0,Y=0,Z=1},collision=0}
function capsule:GetOwner()return self.owner end
function capsule:GetWorld()return self.world end
function capsule:GetScaledCapsuleRadius()return self.radius end
function capsule:GetScaledCapsuleHalfHeight()return self.halfHeight end
function capsule:K2_GetComponentLocation()return self.position end
function capsule:GetUpVector()return self.up end
function capsule:GetCollisionEnabled()return self.collision end
frontActors[1].CapsuleComponent=capsule
local function capsuleFrame(time,expected)
    crowdWriter(time,crowdSession)
    local n,packet=count()
    assert(n==expected,'current capsule fallback/validation must publish '..expected..' NPCs')
    return packet
end
local function capsuleRectangle(packet)
    local p=crowdSession.flight.p
    local a=frontActors[1].position
    local distance=string.format('%.2f',math.sqrt((a.X/100-p.x)^2+(a.Y/100-p.y)^2+(a.Z/100-p.z)^2))
    for line in packet:gmatch('[^\n]+')do
        local x,y,w,h,d=line:match('^1 ([%d.]+) ([%d.]+) ([%d.]+) ([%d.]+) ([%d.]+) ')
        if d==distance then return tonumber(x),tonumber(y),tonumber(w),tonumber(h)end
    end
    error('capsule target row missing')
end
for frame,up in ipairs({{X=0,Y=0,Z=1},{X=1,Y=0,Z=0},{X=.6,Y=0,Z=.8}})do
    capsule.up=up;capsule.position.Y=capsule.position.Y+10
    local packet=capsuleFrame(elapsed+.001+frame*.0001,8)
    assert(capsule:GetCollisionEnabled()==0,'scanner must preserve NoCollision')
    local center= capsule.position
    local segment=capsule.halfHeight-capsule.radius
    local extent={X=capsule.radius+segment*math.abs(up.X),Y=capsule.radius+segment*math.abs(up.Y),Z=capsule.radius+segment*math.abs(up.Z)}
    local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
    local yaw=math.rad(current.yaw)
    for _,dx in ipairs({-1,1})do for _,dy in ipairs({-1,1})do for _,dz in ipairs({-1,1})do
        local x=center.X+dx*extent.X-current.position.X
        local y=center.Y+dy*extent.Y-current.position.Y
        local z=center.Z+dz*extent.Z-current.position.Z
        local depth=x*math.cos(yaw)+y*math.sin(yaw)
        local sx,sy=.5+.4*(-x*math.sin(yaw)+y*math.cos(yaw))/depth,.5-.8*z/depth
        left=math.min(left,sx);right=math.max(right,sx);top=math.min(top,sy);bottom=math.max(bottom,sy)
    end end end
    local x,y,w,h=capsuleRectangle(packet)
    assert(math.abs(x-(left+right)/2)<1e-7 and math.abs(y-(top+bottom)/2)<1e-7
        and math.abs(w-(right-left))<1e-7 and math.abs(h-(bottom-top))<1e-7,
        'rotated NoCollision capsule rectangle must use its real scaled size and current component transform')
end
capsule.owner=frontActors[2];capsuleFrame(elapsed+.0014,7)
capsule.owner=null;capsuleFrame(elapsed+.0015,7)
capsule.owner=frontActors[1];capsule.world=object();capsuleFrame(elapsed+.0016,7)
capsule.world=world;capsule.invalid=true;capsuleFrame(elapsed+.0017,7)
capsule.invalid=false
for _,mutate in ipairs({
    function()capsule.radius=0 end,function()capsule.radius=0/0 end,
    function()capsule.halfHeight=10 end,function()capsule.halfHeight=math.huge end,
    function()capsule.up={X=0,Y=0,Z=0}end,function()capsule.up={X=0,Y=0,Z=2}end,
    function()capsule.position={X=math.huge,Y=0,Z=0}end,
})do
    local radius,halfHeight,up,position=capsule.radius,capsule.halfHeight,capsule.up,capsule.position
    mutate();capsuleFrame(elapsed+.0018,7)
    capsule.radius,capsule.halfHeight,capsule.up,capsule.position=radius,halfHeight,up,position
end
capsule.GetWorld=nil
capsuleFrame(elapsed+.0019,8) -- Missing reflected getter is an invalid UE4SS sentinel.
frontActors[1].CapsuleComponent=null
frontActors[1].boundsInvalid=false;frontActors[2].RootComponent=null
crowdWriter(elapsed+.002,crowdSession);assert(count()==7,'current root invalidation clears a crowded-scene target immediately')
frontActors[2].RootComponent=object()
for i=57,65 do
    local actor=makeNPC(i,4800+(i-57)*20,(i-61)*200)
    notifications['/Script/Stalker2.Agent'](actor)
end
crowdAPI:update(crowdSession,{characters=true},.016,elapsed+.2)
crowdWriter(elapsed+.2,crowdSession)
assert(count()==16,'seventeen visible actors keep the sixteen-row display and native metadata limit')
crowdWriter(elapsed+.21,nil);assert(count()==0,'exit clears every crowd rectangle in one packet')
crowdAPI:finish(crowdSession)
os.remove(root..'scan-frame-a.txt');os.remove(root..'scan-frame-b.txt')
print('PASS UE4SS loaded/LOD poses, rotated NoCollision capsule ownership/geometry, persistent crowd packets at 60/144 Hz, five native probes and sixteen visible-row metadata budget')
