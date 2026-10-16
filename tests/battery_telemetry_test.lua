local telemetry=dofile('mod/Scripts/telemetry.lua')
local flight=dofile('mod/Scripts/flight.lua')
local cfg={speed_preset=2,camera_tilt=25}
local s={origin={x=0,y=0,z=0},flight=flight.new({x=0,y=0,z=0},0),
    battery={enabled=true,capacity=1500,cells=6,percent=85,voltage=23.4,currentA=12,usedMah=225}}
local packets={};local rawOpen=io.open
io.open=function(path,mode)
    assert(path=='battery-fixture/telemetry.txt'and mode=='w')
    return {write=function(_,text)local row={};for token in text:gmatch('%S+')do row[#row+1]=assert(tonumber(token))end
        packets[#packets+1]=row end,close=function()end}
end
local publish=telemetry.new('battery-fixture/',flight,cfg)
publish(0,s);publish(.001,s);assert(#packets==1)
s.battery.currentA=30;publish(.002,s);assert(#packets==1,'ordinary measurements keep the50ms gate')
s.battery.warning=true;publish(.003,s);assert(#packets==2,'LOW publishes immediately')
s.battery.critical=true;publish(.004,s);assert(#packets==3,'LAND publishes immediately')
s.battery.depleted=true;publish(.005,s);assert(#packets==4,'empty battery publishes immediately')
s.battery.enabled=false;publish(.006,s);assert(#packets==5,'disabled battery clears immediately')
s.battery.enabled=true;publish(.007,s);publish(.008,nil);assert(#packets==7)
io.open=rawOpen
for i,row in ipairs(packets)do assert(#row==36 and row[1]==6 and row[2]==i and row[36]==i)end
local p=packets[1]
assert(p[26]==1 and p[27]==85 and p[28]==23.4 and p[29]==12 and p[30]==225 and p[31]==1500 and p[32]==6
    and p[33]==0 and p[34]==0 and p[35]==0)
assert(packets[2][33]==1 and packets[3][34]==1 and packets[4][35]==1)
for _,i in ipairs({5,7})do for field=26,35 do assert(packets[i][field]==0,'disabled/idle battery is canonical zero')end end
for key,values in pairs({percent={-1,101,0/0,math.huge},voltage={-1,41},currentA={-1,1001},
    capacity={299,20050,1525},cells={1,9,6.5},usedMah={-1,1501}})do
    local old=s.battery[key]
    for _,value in ipairs(values)do s.battery[key]=value;assert(not telemetry.sample(s,cfg,flight).batteryEnabled,key)end
    s.battery[key]=old
end
assert(telemetry.sample(s,cfg,flight).batteryEnabled)
if arg and arg[1]then
    local f=assert(rawOpen(arg[1],'w'));assert(f:write(table.concat(packets[3],' ')..'\n'));f:close()
end
print('PASS battery v6 units/ranges, live LOW/LAND/empty transitions, bounded publication and canonical disabled/exit clearing')
