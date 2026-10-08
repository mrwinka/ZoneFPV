local M=dofile('mod/Scripts/scan_overlay.lua')
M.nativeBridge=nil
-- Envelope/protocol fixtures use a simple lens. The separate projection
-- suite exercises the real five-probe lens against an independent oracle.
local actualProjection,actualTargets=M.projection,M.targets
M.projection={new=function(_,nativeProject)return nativeProject end}
M.targets={markerCurrent=function(_,marker)return marker.actor:IsValid() and not marker.expired end}
local function near(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' != '..tostring(b))end
local projectCalls=0
local function project(p)
    projectCalls=projectCalls+1
    return p.X/1000,p.Y/1000
end
local c,e={X=500,Y=500,Z=50},{X=50,Y=100,Z=30}
local x,y,w,h=M.bounds(c,e,project)
near(x,.5);near(y,.5);near(w,.1);near(h,.2)
assert(projectCalls==8,'all world corners bound the object instead of a fixed screen square')
c.X=0;x,y,w,h=M.bounds(c,e,project)
near(x,.025);near(w,.05)
c.X=-200;assert(not M.bounds(c,e,project))
assert(not M.bounds(c,{X=0,Y=1,Z=1},project))
assert(not M.bounds({X=0/0,Y=0,Z=0},e,project))
assert(not M.bounds(c,e,function()return nil end))
assert(not M.bounds({X=0,Y=500,Z=0},e,function(p)
    if p.X<=0 then return end
    return p.X/1000,p.Y/1000
end),'camera-plane intersections cannot use only their visible corners')

local root='build/'
local logs={}
local function object(t)
    t=t or {};function t:IsValid()return not self.invalid end
    return t
end
local pc=object({screenShift=0})
local nativeCalls=0
function pc:ProjectWorldLocationToScreen(pos,out,relative)
    assert(relative==true)
    nativeCalls=nativeCalls+1
    -- Represents engine camera projection; only that API determines pixels.
    out.X=(pos.X/1000+self.screenShift)*3440
    out.Y=pos.Y/1000*1440
    return pos.Z>=0
end
local layout=object()
function layout:GetViewportSize(context)
    assert(context==pc);return {X=3440,Y=1440}
end
StaticFindObject=function(path)
    assert(path=='/Script/UMG.Default__WidgetLayoutLibrary');return layout
end
FindAllOf=function()error('overlay must never rediscover objects')end
local actor=object({position={X=500,Y=500,Z=50}})
function actor:K2_GetActorLocation()return self.position end
local marker={actor=actor,type=1,actorPosition={X=500,Y=500,Z=50},
    position={X=500,Y=500,Z=50},extent=e,distance=999}
local s={pc=pc,flight={p={x=0,y=0,z=0}},worldExperiments={markers={marker}}}
local writer=M.new(root,{},
    {fov=140,camera_tilt=25},function(line)logs[#logs+1]=line end)
local function packet()
    local newest
    for _,suffix in ipairs({'a','b'})do
        local f=io.open(root..'scan-frame-'..suffix..'.txt','r')
        if f then
            local value=f:read('*a');f:close()
            local generation,seq,count=value:match('^4 (%d+) (%d+) (%d+)\n')
            local tailGeneration,tailSeq=value:match('\n(%d+) (%d+)\n$')
            if generation and generation==tailGeneration and seq==tailSeq then
                generation,seq,count=tonumber(generation),tonumber(seq),tonumber(count)
                if not newest or generation>newest.generation or generation==newest.generation and seq>newest.seq then
                    newest={value=value,generation=generation,seq=seq,count=count}
                end
            end
        end
    end
    return assert(newest,'one complete generation/sequence slot must remain readable')
end
local function frame()
    local result=packet();local text=result.value
    local typeID,cx,cy,bw,bh,d=text:match('\n(%d+) ([%d%.]+) ([%d%.]+) ([%d%.]+) ([%d%.]+) ([%d%.]+) %-?%d+ %d+\n')
    return result.count,tonumber(cx),tonumber(cy),tonumber(bw),tonumber(bh),tonumber(d),result.seq
end
writer(0,s)
local count,px,py,pw,ph,d,seq=frame()
assert(count==1 and nativeCalls==16)
near(px,.5);near(py,.5);near(pw,.1);near(ph,.2)
assert(d<8,'distance must follow current actor position, not stale cached value')
writer(.01,s);assert(select(7,frame())==seq+1,'track every camera frame without 30 Hz stepping')
actor.position.X=600;pc.screenShift=.1
writer(.04,s)
count,px,py,pw,ph=frame()
near(px,.7);near(py,.5)
near(pw,.1);near(ph,.2)
actor.invalid=true;writer(.08,s)
assert(frame()==0,'destroyed actors are not drawn until stale discovery expires')
actor.invalid=false
marker.expired=true;writer(.09,s);assert(frame()==0,'writer rejects stale identity/lifecycle immediately')
marker.expired=false
function pc:ProjectWorldLocationToScreen()error('native API unavailable')end
writer(.12,s);assert(frame()==0 and #logs==1)
writer(.16,s);assert(frame()==0 and #logs==1,'API error only logs once')
writer(.161,nil);assert(frame()==0,'exit immediately clears scan brackets')

-- The direct projection fixture includes eight cheap candidate corners and
-- eight exact collider corners. Actual calibrated native cost is tested below.
nativeCalls=0
function pc:ProjectWorldLocationToScreen(pos,out,relative)
    assert(relative==true);nativeCalls=nativeCalls+1
    out.X=pos.X/1000*3440;out.Y=pos.Y/1000*1440;return true
end
s.worldExperiments.markers={}
for i=1,32 do s.worldExperiments.markers[i]=marker end
writer(.2,s)
assert(frame()==16 and nativeCalls==256)
-- The same six bones as native binoculars define a posed human, independently
-- of capsule size. Bone movement and camera movement are projected together.
FName=function(name)return name end
local bonePoints={
 jnt_head={X=500,Y=300,Z=50},jnt_spine_03={X=500,Y=450,Z=50},
 jnt_r_foot={X=550,Y=700,Z=50},jnt_l_foot={X=450,Y=700,Z=50},
 jnt_r_hand={X=600,Y=500,Z=50},jnt_l_hand={X=400,Y=500,Z=50},
}
actor.Mesh=object()
function actor.Mesh:DoesSocketExist(name)return bonePoints[name]~=nil end
function actor.Mesh:GetSocketLocation(name)return bonePoints[name]end
s.worldExperiments.markers={marker}
local skeletonWriter=M.new(root,{}, {},function()end)
nativeCalls=0;skeletonWriter(.24,s)
count,px,py,pw,ph=frame()
assert(count==1 and nativeCalls==14)
near(px,.5);near(py,.5);near(pw,.22);near(ph,.42)
bonePoints.jnt_r_hand.X=700
nativeCalls=0;skeletonWriter(.28,s)
count,px,py,pw,ph=frame()
near(px,.55);near(pw,.32);assert(nativeCalls==14)
local socketQuery=actor.Mesh.DoesSocketExist
function actor.Mesh:DoesSocketExist()return false end
nativeCalls=0;skeletonWriter(.29,s)
assert(frame()==1 and nativeCalls==16,'absent sockets never project their default component origin')
actor.Mesh.DoesSocketExist=socketQuery
actor.Mesh.invalid=true;nativeCalls=0;skeletonWriter(.32,s)
assert(frame()==1 and nativeCalls==16,'unavailable skeleton retains collider fallback')
FName=nil
local indices={Duty=101,Mutant=102,FreeStalkers=103}
FName=function(name)return {GetComparisonIndex=function()return indices[name] or 999 end}end
local requests=0
M.nativeBridge={new=function()return {metadata=function(_,pawn,actors)
    requests=requests+1;assert(pawn==s.pawn and #actors==1)
    return {[actor:GetAddress()]={relation=0,names={105,101}}}
end}end}
function actor:GetAddress()return 123456 end
s.pawn=object()
local metadataWriter=M.new(root,{}, {},function()end)
metadataWriter(.4,s)
local function metadataFields()
 local value=packet().value
 return value:match('\n1 [^\n]+ ([%-]?%d+) (%d+)\n')
end
local relation,faction=metadataFields();assert(relation=='0' and faction=='3','actual hostile relation and parent Duty icon')
metadataWriter(.44,s);assert(requests==1,'metadata work is bounded separately from live projection')
local replacement={};for key,value in pairs(marker)do replacement[key]=value end
replacement.entry={};s.worldExperiments.markers={replacement}
metadataWriter(.45,s)
relation,faction=metadataFields();assert(relation=='-1' and faction=='0','reused address cannot inherit an old target relation/faction')
s.worldExperiments.markers={marker}
metadataWriter(.51,s);assert(requests==2)
assert(M.factionIcon({102,103},{[102]=0,[103]=6})==0,'native Mutant NULL stops parent-icon lookup')
assert(M.factionIcon({104},{[103]=6})==0,'unknown faction never receives a fabricated icon')
metadataWriter(.52,nil);assert(frame()==0)
M.nativeBridge=nil;FName=nil

-- Marker disappearance clears immediately, even within the idle period.
local clearingWriter=M.new(root,{}, {},function()end)
clearingWriter(.6,s);assert(frame()==1)
local previous=packet()
s.worldExperiments.markers={};clearingWriter(.601,s)
assert(frame()==0 and packet().seq==previous.seq+1)
previous=packet();clearingWriter(.602,s);assert(packet().seq==previous.seq,'empty scanner idles')

-- A factory fault must clear output without escaping into main's FPV guard.
s.worldExperiments.markers={marker}
M.projection={new=function()error('fixture calibration fault')end}
local faultLogs={}
local faultWriter=M.new(root,{}, {},function(line)faultLogs[#faultLogs+1]=line end)
faultWriter(.603,s);assert(frame()==0 and #faultLogs==1)
faultWriter(.604,s);assert(frame()==0 and #faultLogs==1)
M.projection={new=function()return nil,'camera_lens_pending' end}
faultWriter(.605,s);assert(frame()==0 and #faultLogs==1,'FOV handoff is expected and not repeatedly logged')
M.projection={new=function(_,nativeProject)return nativeProject end}
s.worldExperiments.markers={};clearingWriter(.606,s)
previous=packet()

-- A partial write to the inactive slot cannot masquerade as a whole packet.
local inactive=previous.seq%2==0 and 'b' or 'a'
local f=assert(io.open(root..'scan-frame-'..inactive..'.txt','w'))
f:write(string.format('4 %.0f %d 1\n',previous.generation,previous.seq+1));f:close()
assert(packet().seq==previous.seq,'complete other slot survives a torn packet')
-- Reload resets seq but advances generation, removes both old session slots.
local restarted=M.new(root,{}, {},function()end)
restarted(.7,s);assert(packet().generation>previous.generation and packet().seq==1)

M.projection=actualProjection;M.targets=actualTargets
os.remove(root..'scan-frame-a.txt');os.remove(root..'scan-frame-b.txt')
print('PASS current-frame tracking, coherent dual-slot publication, reload generation, near-plane clipping, fresh lifecycle, native metadata and bounded projection')
