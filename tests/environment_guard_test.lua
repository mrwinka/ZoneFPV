local guard=dofile('mod/Scripts/environment_guard.lua')
local flight={p={x=123,y=456,z=78},v={x=1,y=2,z=3}}
local s={flight=flight}
guard.changed(s,10)
assert(guard.delta(s,-500,10)==0)
assert(guard.delta(s,2,11)==0)
assert(guard.delta(s,0.02,12)==0.02)
assert(s.flight==flight and flight.p.x==123 and flight.v.y==2)
assert(guard.delta(s,2,14)==2,'ordinary stall safety must remain active')
assert(guard.delta(s,-5,14)==-5,'unrelated world reset must remain visible')
guard.changed(nil,20)
print('PASS weather/time rebasing preserves flight and keeps ordinary stall protection')
