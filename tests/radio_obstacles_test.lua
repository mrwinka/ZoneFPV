local M=dofile('mod/Scripts/radio_obstacles.lua')
local calls=0
local function obj(t)function t:IsValid()return true end;return t end
local pawn=obj({})
local s={pawn=pawn,camera=obj({}),origin={x=0,y=0,z=1},flight={p={x=100,y=0,z=1}}}
local sys={SphereTraceSingle=function(_,_,from,to,_,_,complex,_,_,hit)
    calls=calls+1
    if complex then return false end
    hit.Time=.2;hit.Location=from.X<to.X and {X=2000,Y=0,Z=100} or {X=4000,Y=0,Z=100}
    return true
end}
local logs={};local function log(v)logs[#logs+1]=v end
assert(M.update(s,sys,false,0,log)==0 and calls==0)
assert(M.update(s,sys,true,0,log)==45 and calls==4)
assert(M.update(s,sys,true,.1,log)==45 and calls==4)
assert(M.update(s,sys,true,.3,log)==45 and calls==8)
sys.SphereTraceSingle=function()return false end
assert(M.update(s,sys,true,.6,log)==0)
sys.SphereTraceSingle=function()error('unsupported')end
assert(M.update(s,sys,true,1,log)==0 and #logs==1)
assert(M.update(s,sys,true,2,log)==0 and #logs==1)
print('PASS bounded simple/complex LOS, occupied span, clear LOS and unavailable query fallback')
