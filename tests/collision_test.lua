local collision=dofile('mod/Scripts/drone_collision.lua')
local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
local start,finish={X=0,Y=0,Z=0},{X=10000,Y=0,Z=0}
local function fixture(results,noCapsule)
    local reads,calls,outputs=0,{},{}
    local capsule={IsValid=function() return true end,GetCollisionProfileName=function() reads=reads+1;return 'PlayerCustom' end}
    local s={pawn={CapsuleComponent=not noCapsule and capsule or nil},camera={}}
    local function query(kind,world,a,b,r,filter,complex,ignore,debug,hit,self)
        assert(world==s.pawn and a==start and b==finish and r==12)
        assert(ignore[1]==s.pawn and ignore[2]==s.camera and debug==0 and self)
        assert(filter==(kind=='profile' and 'PlayerCustom' or 0))
        local key=kind..(complex and '_complex' or '_simple')
        calls[#calls+1]=key
        outputs[#outputs+1]=hit
        local result=results[key]
        if not result then return false end
        for k,v in pairs(result) do hit[k]=v end
        return true
    end
    local sys={SphereTraceSingle=function(_,...) return query('channel',...) end,
        SphereTraceSingleByProfile=function(_,...) return query('profile',...) end}
    return s,sys,calls,function() return reads end,outputs
end
local function hit(time) return {Time=time,Location={X=time*10000,Y=0,Z=0},Normal={X=-1,Y=0,Z=0}} end
test('complex-only wall is detected across a long movement segment',function()
    local s,sys,calls=fixture({channel_complex=hit(0.3)})
    local yes,h=collision.trace(sys,s,start,finish,12)
    assert(yes and h.Time==0.3 and #calls==4)
end)
test('custom player response catches an object ignored by the trace channel',function()
    local s,sys=fixture({profile_simple=hit(0.4)})
    local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.Time==0.4)
end)
test('nearest hit wins across both representations and filters',function()
    local s,sys=fixture({channel_simple=hit(0.8),profile_simple=hit(0.6),channel_complex=hit(0.3),profile_complex=hit(0.1)})
    local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.Time==0.1)
end)
test('simple geometry remains supported when complex queries miss',function()
    local s,sys=fixture({channel_simple=hit(0.2)})
    local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.Time==0.2)
end)
test('initial penetration takes priority over a later surface',function()
    local overlap=hit(0.9);overlap.bStartPenetrating=true;overlap.PenetrationDepth=2
    local s,sys=fixture({channel_simple=hit(0.2),profile_complex=overlap})
    local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.bStartPenetrating)
end)
test('missing hit Time falls back to sphere centre projected on movement',function()
    local nearest=hit(0.1);nearest.Time=nil
    local s,sys=fixture({channel_simple=hit(0.9),channel_complex=nearest})
    local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.Location.X==1000)
end)
test('profile is cached and query count stays bounded in empty space',function()
    local s,sys,calls,reads=fixture({})
    for _=1,24 do assert(not collision.trace(sys,s,start,finish,12)) end
    assert(#calls==96 and reads()==1)
end)
test('missing capsule retains simple and complex channel sweeps',function()
    local s,sys,calls=fixture({channel_complex=hit(0.5)},true)
    assert(collision.trace(sys,s,start,finish,12));assert(#calls==2)
end)
test('equal fractions retain query order unless a hit starts penetrating',function()
    local first=hit(0.2);first.Normal.X=1
    local s,sys=fixture({channel_simple=first,profile_simple=hit(0.2),channel_complex=hit(0.2),profile_complex=hit(0.2)})
    local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.Normal.X==1)
    local penetrating=hit(0);penetrating.bStartPenetrating=true
    s,sys=fixture({channel_simple=hit(0),profile_complex=penetrating})
    yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.bStartPenetrating)
end)
test('packed blocking bit cannot make swept impacts appear initially overlapping',function()
    local far=hit(.8);far.bStartPenetrating=true;far.PenetrationDepth=0
    local near=hit(.2);near.bStartPenetrating=true;near.PenetrationDepth=0
    local s,sys=fixture({channel_simple=far,profile_complex=near})
    local yes,h=collision.trace(sys,s,start,finish,12)
    assert(yes and h.Time==.2 and not collision.isPenetrating(h),'real sweep time chooses the nearest wall')
    for _,depth in ipairs({0,2})do
        local overlap=hit(0);overlap.bStartPenetrating=true;overlap.PenetrationDepth=depth
        assert(collision.isPenetrating(overlap),'actual Time=0 overlaps remain protected')
    end
    local unknown=hit(0);unknown.Time=nil;unknown.bStartPenetrating=true
    assert(collision.isPenetrating(unknown),'unknown penetration remains conservative')
end)
test('native hit output tables remain separate across queries and steps',function()
    local s,sys,calls,reads,outputs=fixture({channel_simple=hit(0.1),profile_complex=hit(0.8)})
    local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.Time==0.1)
    local _,nextHit=collision.trace(sys,s,start,finish,12)
    assert(h~=nextHit and h.Time==0.1 and #calls==8 and reads()==1)
    for i=1,#outputs do for j=i+1,#outputs do assert(outputs[i]~=outputs[j]) end end
end)
test('nonfinite Time falls back to geometry without rejecting a nearer wall',function()
    for _,time in ipairs({0/0,math.huge,-math.huge}) do
        local nearest=hit(0.1);nearest.Time=time
        local s,sys=fixture({channel_simple=hit(0.9),profile_complex=nearest})
        local yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.Location.X==1000)
    end
end)

local function geometryFixture(walls)
    local s={world={},pc={},pawn={},camera={}}
    s.pawn.CapsuleComponent={IsValid=function()return true end,GetCollisionProfileName=function()return 'PlayerCustom'end}
    local calls={}
    local function query(kind,context,a,b,r,filter,complex,ignore,debug,out,selfIgnore)
        assert(context==s.pawn and debug==0 and selfIgnore)
        assert(ignore==s.traceIgnore and filter==(kind=='profile'and s.traceProfile or 0))
        calls[#calls+1]={radius=r,startPos=a,endPos=b,key=kind..(complex and '_complex'or '_simple')}
        local nearest,wall,penetrating=math.huge
        for _,w in ipairs(walls)do
            if not w.key or w.key==calls[#calls].key then
                local from,to=a[w.axis],b[w.axis]
                local t,overlap
                if from>=w.value-r then t,overlap=0,true
                elseif to>=w.value-r and to>from then t=(w.value-r-from)/(to-from)end
                if t and t<nearest then nearest,wall,penetrating=t,w,overlap end
            end
        end
        if not wall then return false end
        out.Time=nearest;out.bStartPenetrating=penetrating or false
        out.PenetrationDepth=penetrating and math.max(0,r-wall.value+a[wall.axis])or 0
        out.Location={X=a.X+(b.X-a.X)*nearest,Y=a.Y+(b.Y-a.Y)*nearest,Z=a.Z+(b.Z-a.Z)*nearest}
        out.Normal={X=0,Y=0,Z=0};out.Normal[wall.axis]=-1
        return true
    end
    local sys={SphereTraceSingle=function(_,...)return query('channel',...)end,
        SphereTraceSingleByProfile=function(_,...)return query('profile',...)end}
    return s,sys,calls
end
local function p(x,y,z)return {X=x,Y=y or 0,Z=z or 0}end

test('same-frame clearance covers complete curved and reversing segments',function()
    local s,sys,calls=geometryFixture({})
    local points={p(0),p(10),p(15,40),p(-20,80),p(-60,40),p(0,-50),p(100,-10)}
    collision.beginFrame(s,24)
    for i=2,#points do assert(not collision.trace(sys,s,points[i-1],points[i],12))end
    assert(#calls==4,'one complete four-filter clearance proof replaces 24 exact sweeps, including turns and reversal')
    assert(calls[1].radius==132,'bounded margin expands the full swept sphere, not only its endpoints')
    collision.beginFrame(s,24)
    assert(not collision.trace(sys,s,points[#points],points[1],12)and #calls==8,
        'clearance is never reused across callbacks')
end)
test('high-speed wall outside clearance retains full-segment radius and nearest profile/complex contact',function()
    local s,sys,calls=geometryFixture({{axis='X',value=900,key='channel_simple'},
        {axis='X',value=800,key='profile_complex'}})
    collision.beginFrame(s,24)
    assert(not collision.trace(sys,s,p(0),p(10),12)and #calls==4)
    local yes,h=collision.trace(sys,s,p(10),p(10000),12)
    assert(yes and math.abs(h.Time-(800-12-10)/(10000-10))<1e-12 and h.Location.X==788 and #calls==8,
        'leaving the proof queries the whole high-speed path and detects the nearer thin complex-only wall')
    for i=5,8 do assert(calls[i].radius==12 and calls[i].startPos.X==10 and calls[i].endPos.X==10000)end
    assert(not s.traceClearanceFrame.proof,'actual contact retires the clearance before any response/gameplay callback')
end)
test('a broad hit never becomes a false impact and has one fixed overhead per frame',function()
    local s,sys,calls=geometryFixture({{axis='Y',value=50,key='profile_complex'}})
    collision.beginFrame(s,96)
    for i=1,96 do assert(not collision.trace(sys,s,p((i-1)*10),p(i*10),12))end
    assert(#calls==4+96*4 and not s.traceClearanceFrame.proof,
        'nearby non-contact geometry adds only one broad query set, never one per substep')
    for i=5,#calls do assert(calls[i].radius==12,'exact collision geometry remains unchanged after the failed proof')end
end)
test('initial high-speed broad hit reruns exact queries and preserves contact fraction',function()
    local s,sys,calls=geometryFixture({{axis='X',value=800,key='profile_complex'}})
    collision.beginFrame(s,24)
    local yes,h=collision.trace(sys,s,p(0),p(10000),12)
    assert(yes and h.Location.X==788 and h.Time==.0788 and #calls==8)
    assert(calls[1].radius==312 and calls[5].radius==12,'inflation stays capped at three metres and exact sweep retains drone radius')
end)
test('new callback rechecks dynamic geometry instead of reusing old empty space',function()
    local walls={};local s,sys,calls=geometryFixture(walls)
    collision.beginFrame(s,8);assert(not collision.trace(sys,s,p(0),p(10),12))
    walls[1]={axis='X',value=30,key='channel_complex'}
    collision.beginFrame(s,8)
    local yes,h=collision.trace(sys,s,p(10),p(20),12)
    assert(yes and h.Location.X==18 and #calls==12,'next callback detects an actor newly entering the previously clear capsule')
end)
test('all owner, shape, ignore, radius and discontinuity changes retire same-frame proof',function()
    for _,change in ipairs({'system','world','pc','pawn','camera','profile','ignore-table','ignore-content','ignore-size','radius','teleport'})do
        local s,sys,calls=geometryFixture({})
        collision.beginFrame(s,24);assert(not collision.trace(sys,s,p(0),p(10),12)and #calls==4)
        local radius,a=12,p(10)
        if change=='system'then sys={SphereTraceSingle=sys.SphereTraceSingle,SphereTraceSingleByProfile=sys.SphereTraceSingleByProfile}
        elseif change=='world'or change=='pc'or change=='pawn'or change=='camera'then s[change]={}
        elseif change=='profile'then s.traceProfile='ChangedCustom'
        elseif change=='ignore-table'then s.traceIgnore={s.pawn,s.camera}
        elseif change=='ignore-content'then s.traceIgnore[1]={}
        elseif change=='ignore-size'then s.traceIgnore[3]={}
        elseif change=='radius'then radius=13
        elseif change=='teleport'then a=p(11)end
        assert(not collision.trace(sys,s,a,p(20),radius)and #calls==8 and not s.traceClearanceFrame.proof,
            change..' must fall back to all exact sweeps even inside the prior capsule')
    end
end)
test('single-step callbacks and standalone payload traces keep the exact path without proof overhead',function()
    for _,steps in ipairs({0,1})do
        local s,sys,calls=geometryFixture({});collision.beginFrame(s,steps)
        assert(not collision.trace(sys,s,p(0),p(10),12)and #calls==4)
        for _,call in ipairs(calls)do assert(call.radius==12)end
    end
    local s,sys,calls=geometryFixture({})
    for i=1,96 do assert(not collision.trace(sys,s,p(i),p(i+1),12))end
    assert(#calls==384,'standalone grenade traces cannot accidentally reuse flight clearance')
end)
test('empty-space flight query count falls from 48 to 4 at twelve fixed substeps',function()
    local frames,steps=500,12
    local plain,plainSys,plainCalls=geometryFixture({})
    local batched,batchSys,batchCalls=geometryFixture({})
    for frame=1,frames do
        collision.beginFrame(batched,steps)
        for step=1,steps do
            local a,b=p((step-1)*10,math.sin((step-1)*.05)*10),p(step*10,math.sin(step*.05)*10)
            assert(not collision.trace(plainSys,plain,a,b,12))
            assert(not collision.trace(batchSys,batched,a,b,12))
        end
    end
    assert(#plainCalls==24000 and #batchCalls==2000,'500 callbacks preserve each full path with 91.7% fewer native query calls in open space')
    print('MEASURED deterministic 500-callback query count: exact='..#plainCalls..' clearance='..#batchCalls..'; not an in-game FPS measurement')
end)
print(count..' collision tests passed')
