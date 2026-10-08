local radio=dofile('mod/Scripts/radio_link.lua')
local flight=dofile('mod/Scripts/flight.lua')
local cfg=dofile('mod/Scripts/config.lua')
local settings={enabled=true,range=100}
local function state(p) return {origin={x=0,y=0,z=0},flight=flight.new(p or {x=0,y=0,z=0},0)} end
assert(radio.parse('1 50')==true);assert(radio.parse('0 20000')==false)
assert(select(3,radio.parse('1 100'))==2)
assert(select(3,radio.parse('1 100 0'))==0 and select(3,radio.parse('1 100 5'))==5)
assert(not radio.parse('1 100 5.1') and not radio.parse('1 100 1..2'))
for _,bad in ipairs({'1 49','1 20001','2 100','1 nan','1 100 | quit','1 1e3','1 100 extra'}) do assert(radio.parse(bad)==nil) end
local s=state();assert(radio.update(s,settings,0).rssi==100)
s.flight.p={x=30,y=40,z=0};assert(radio.update(s,settings,0).rssi==50)
s.flight.p={x=0,y=0,z=99};assert(math.abs(radio.update(s,settings,0).rssi-1)<1e-8)
s.flight.p.z=100;s.flight.thrust=100
assert(radio.update(s,settings,0).lost and s.flight.linkLost and s.flight.thrust==0)
-- Range changes and moving back cannot undo a failed flight.
settings.enabled=false;settings.range=20000;s.flight.p.z=0
assert(radio.update(s,settings,0).lost and s.radio.enabled and s.radio.rssi==0)
radio.update(s,settings,0);assert(s.radio.fallSeconds==0 and not radio.finished(s))
-- Full stick commands in every mode cannot resurrect thrust after signal loss.
for _,mode in ipairs({'acro','angle','3d'}) do
    cfg.flight_mode=mode
    local f=flight.new({x=0,y=0,z=10},0);f.linkLost=true;f.thrust=100
    flight.advance(f,{roll=1,pitch=1,yaw=1,throttle=1},cfg,.1)
    assert(f.thrust==0 and f.p.z<10 and f.v.z<0)
end
s.radio.hit=true;radio.update(s,settings,.1);radio.update(s,settings,.1)
assert(not radio.finished(s));radio.update(s,settings,.1);assert(radio.finished(s))
settings={enabled=true,range=100};s=state({x=100,y=0,z=100})
radio.update(s,settings,0)
for _=1,31 do radio.update(s,settings,.1) end
assert(radio.finished(s))
settings.enabled=false;s=state({x=5000,y=0,z=100})
assert(not radio.update(s,settings,.1).lost and not s.flight.linkLost)
settings={enabled=true,range=100};s=state({x=30,y=0,z=0})
assert(radio.update(s,settings,0,{obstacles=35}).rssi==35)
assert(radio.update(s,settings,0,{obstacles=0}).rssi==70)
assert(radio.update(s,settings,0,{obstacles=75}).lost)
settings.enabled=false;s=state()
assert(radio.update(s,settings,0,{anomalyEnabled=true,anomaly=70}).rssi==30)
radio.lose(s,'destroyed');assert(s.radio.lost and s.radio.reason=='destroyed' and s.flight.linkLost)
settings.enabled=false
-- Failed persistence must not change live settings.
local original=io.open;io.open=function()return nil end
assert(not radio.save('mock/',settings,'1 100') and not settings.enabled)
io.open=original
-- The coefficient shapes weakening, but every positive value loses at the
-- selected maximum. Zero disables attenuation from distance/walls/anomalies.
local quality={}
for _,multiplier in ipairs({0,.5,2,5}) do
    local cfg={enabled=true,range=100,attenuation=multiplier}
    local a=state({x=50,y=0,z=0});quality[multiplier]=radio.update(a,cfg,0).rssi
    local edge=state({x=100,y=0,z=0});assert(radio.update(edge,cfg,0).lost==(multiplier>0))
end
assert(quality[0]==100 and quality[.5]>quality[2] and quality[2]>quality[5])
local disabled=state({x=1000,y=0,z=0})
assert(radio.update(disabled,{enabled=true,range=100,attenuation=0},0,{obstacles=75,anomalyEnabled=true,anomaly=95}).rssi==100)
local oldOpen=io.open;local persisted
io.open=function(_,mode)
    return {read=function()return persisted end,write=function(_,text)persisted=text;return true end,close=function()return true end}
end
local live={};assert(radio.save('mock/',live,'1 100 0.75'))
assert(radio.load('mock/').attenuation==.75 and live.attenuation==.75)
persisted='1 100\n';assert(radio.load('mock/').attenuation==2)
io.open=oldOpen
print('PASS simulated RSSI boundaries, 3D distance, latched motor cutoff, pause and fall/impact timeout')
