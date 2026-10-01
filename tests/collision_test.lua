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
    local penetrating=hit(0.2);penetrating.bStartPenetrating=true
    s,sys=fixture({channel_simple=hit(0),profile_complex=penetrating})
    yes,h=collision.trace(sys,s,start,finish,12);assert(yes and h.bStartPenetrating)
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
print(count..' collision tests passed')
