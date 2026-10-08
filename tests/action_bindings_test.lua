local M=dofile('mod/Scripts/action_bindings.lua')
local line,now,epoch=nil,10,100
local poll=M.new(function()return line end,function()return now end,function()return epoch end)
local function packet(seq,focused,menu,pilot,reset,collect,time)
    line=string.format('1 %d %d %d %d %d %d %d %d',seq,time or 100000,focused and 1 or 0,menu,pilot,reset,collect,seq)
end
local function none(value)
    assert(value and value.ready and not value.pilot and not value.reset and not value.collect)
end
for _,bad in ipairs({'','1 1 100000 1 0 0 0 0','1 1 100000 1 0 0 0 0 2',
    '2 1 100000 1 0 0 0 0 1','1 0 100000 1 0 0 0 0 0','1 1 100000 2 0 0 0 0 1',
    '1 1 -100000 1 0 0 0 0 1','1 1 100000 1 0 -1 0 0 1','1 1.5 100000 1 0 0 0 0 1.5',
    '1 1 100000 1 0 1e3 0 0 1','1 1 100000 1 0 0 0 0 1 9','1 1 100000 1 0 1000000000000001 0 0 1'})do
    assert(not M.parse(bad),bad)
end
assert(poll()==nil)
packet(1,true,4,7,8,9);none(poll()) -- Baseline old events on initial attachment.
packet(2,true,5,8,9,10)
local actions=poll();assert(actions.pilot and actions.reset and actions.collect)
none(poll()) -- Holding/re-reading cannot repeat an action.
packet(3,true,5,8,9,11);actions=poll();assert(actions.collect and not actions.pilot and not actions.reset)
none(poll())

-- The game may miss the physical down/up interval; an increasing counter still fires once.
packet(4,true,5,9,9,11);now=now+.05;assert(poll().pilot)
packet(5,true,5,9,9,11);none(poll())
packet(6,false,6,10,10,12);local away=poll();none(away);assert(not away.focused)
packet(7,true,6,11,11,13);none(poll()) -- Prime focus return, consuming background presses.
packet(8,true,6,11,11,13);none(poll())
packet(9,true,6,11,11,14);assert(poll().collect)

now=now+.251;assert(poll()==nil,'repeating sequence cannot extend the local lease')
packet(10,true,6,12,12,15);none(poll()) -- Lease recovery starts a new baseline.
packet(11,true,6,12,13,15);assert(poll().reset)
packet(12,true,6,13,13,16,97000);assert(poll()==nil,'old producer epoch must be rejected')
packet(13,true,6,14,13,17);none(poll())
packet(14,true,6,14,14,17);assert(poll().reset)

packet(1,true,0,0,0,0);none(poll()) -- Writer restart/lower sequence never replays old counters.
packet(2,true,0,0,0,1);assert(poll().collect)
packet(3,true,0,0,0,0);none(poll()) -- Counter reset with an increasing packet sequence.
packet(4,true,0,1,0,0);assert(poll().pilot)
packet(4,true,0,2,0,0);assert(poll()==nil,'changed counters with an unchanged sequence are inconsistent')
packet(5,true,0,2,0,0);none(poll())
line='partial write';assert(poll()==nil)
packet(6,true,0,3,0,0);none(poll())
packet(7,true,0,3,1,0);assert(poll().reset)
epoch=104;assert(poll()==nil)
epoch=100;packet(8,true,0,4,1,0);none(poll())
now=now-1;assert(poll()==nil,'a local clock rewind invalidates a repeated lease')
packet(9,true,0,5,1,0);none(poll())

local errors=M.new(function()error('reader failed')end,function()return 0 end,function()return 0 end)
assert(errors()==nil)
local clockError=M.new(function()return line end,function()error('clock failed')end,function()return 100 end)
assert(clockError()==nil)
print('PASS universal action packet validation, short taps, no held repeat, focus/lease/restart baselines and failures')
now=10;epoch=100
line='2 10 100000 1 0 0 0 0 20 10';none(poll())
line='2 11 100000 1 0 0 0 0 21 11';assert(poll().flashlight)
assert(not poll().flashlight,'held flashlight counter does not repeat')
line='2 12 100000 0 0 0 0 0 22 12';assert(not poll().flashlight)
line='2 13 100000 1 0 0 0 0 23 13';assert(not poll().flashlight)
line='2 14 100000 1 0 0 0 0 24 14';assert(poll().flashlight)
packet(15,true,0,0,0,0);none(poll())
line='2 16 100000 1 0 0 0 0 50 16';assert(not poll().flashlight,'protocol migration primes new action')
assert(not M.parse('2 16 100000 1 0 0 0 0 50 17'))
print('PASS fifth flashlight edge, focus guards and backwards compatible v1/v2 protocol migrations')
line='3 1 100000 1 0 0 0 0 0 7 9 1';none(poll())
line='3 2 100000 1 0 0 0 0 0 8 10 2'
local armed=poll();assert(armed.cameraDown and armed.grenadeDrop and not armed.flashlight)
armed=poll();assert(not armed.cameraDown and not armed.grenadeDrop,'weapon actions never repeat while held')
line='3 3 100000 0 0 0 0 0 0 9 11 3';armed=poll();assert(not armed.cameraDown and not armed.grenadeDrop)
line='3 4 100000 1 0 0 0 0 0 10 12 4';armed=poll();assert(not armed.cameraDown and not armed.grenadeDrop)
line='3 5 100000 1 0 0 0 0 0 11 13 5';armed=poll();assert(armed.cameraDown and armed.grenadeDrop)
now=now+.251;assert(not poll())
line='3 6 100000 1 0 0 0 0 0 12 14 6';armed=poll();assert(not armed.cameraDown and not armed.grenadeDrop)
line='3 7 100000 1 0 0 0 0 0 12 15 7';armed=poll();assert(not armed.cameraDown and armed.grenadeDrop)
line='3 8 100000 1 0 0 0 0 0 12 14 8';armed=poll();assert(not armed.cameraDown and not armed.grenadeDrop,'counter rollback primes all actions')
for _,bad in ipairs({'3 1 100000 1 0 0 0 0 0 0 1','3 1 100000 1 0 0 0 0 0 0 0 2',
    '3 1 100000 1 0 0 0 0 0 0 0 1 9','3 1 100000 1 0 0 0 0 0 -1 0 1'})do assert(not M.parse(bad),bad)end
print('PASS camera-down/grenade edges with v3 framing, held/focus/lease/rollback guards and legacy migration')
now=20;epoch=100
local function v4(seq,focused,vision,mask)
    line=string.format('4 %d 100000 %d 0 0 0 0 0 0 0 %d %d %d',seq,focused and 1 or 0,vision,mask,seq)
end
v4(1,true,7,176);armed=poll();assert(not armed.vision and not armed.visionHeld and not armed.cameraDownHeld and not armed.flashlightHeld)
v4(2,true,8,176);armed=poll();assert(armed.vision and armed.visionHeld and armed.cameraDownHeld and armed.flashlightHeld)
armed=poll();assert(not armed.vision and armed.visionHeld,'held state persists without repeating its toggle edge')
v4(3,true,8,0);armed=poll();assert(not armed.vision and not armed.visionHeld and not armed.cameraDownHeld and not armed.flashlightHeld)
v4(4,false,9,176);armed=poll();assert(not armed.vision and not armed.visionHeld)
v4(5,true,9,176);armed=poll();assert(not armed.vision and not armed.visionHeld,'focus return primes all held states')
v4(6,true,10,128);armed=poll();assert(armed.vision and armed.visionHeld and not armed.cameraDownHeld)
v4(6,true,10,0);assert(not poll(),'a held-mask mutation requires a new sequence')
v4(7,true,10,0);armed=poll();assert(not armed.visionHeld)
now=now+.251;assert(not poll(),'stopped helper releases held state through a missing packet')
v4(8,true,11,128);armed=poll();assert(not armed.visionHeld and not armed.vision,'lease recovery consumes stale presses')
for _,mask in ipairs({1,8,64,177,256})do v4(9,true,11,mask);assert(not M.parse(line),'reserved held bits rejected')end
print('PASS v4 selected-vision edge and three held states, focus/lease/restart priming, immediate release and strict held framing')
now=30
local function v5(seq,focused,mask)
    line=string.format('5 %d 100000 %d 0 0 0 0 0 0 0 0 %d %d',seq,focused and 1 or 0,mask,seq)
end
local names={'menu','pilot','reset','collect','flashlight','cameraDown','grenadeDrop','vision'}
v5(1,true,255);armed=poll();assert(not armed.active and armed.sourceHeld==255)
for _,name in ipairs(names)do assert(not armed[name..'Held'])end
v5(2,true,255);armed=poll();assert(armed.active)
for _,name in ipairs(names)do assert(armed[name..'Held'])end
for i,name in ipairs(names)do
    v5(2+i,true,1 << (i-1));armed=poll()
    for _,other in ipairs(names)do assert(armed[other..'Held']==(other==name))end
end
v5(11,false,255);armed=poll();assert(not armed.active)
v5(12,true,255);armed=poll();assert(not armed.active and armed.sourceHeld==255)
v5(13,true,0);armed=poll();assert(armed.active and not armed.pilotHeld)
v5(14,true,256);assert(not M.parse(line))
print('PASS v5 all eight held bits, strict framing, legacy migration, physical source and focus priming')
local savedLine
local cached=M.new(function()return savedLine end,function()return now end,function()return epoch end)
v5(1,true,0);savedLine=line;assert(not cached().active)
v5(2,true,32);savedLine=line;assert(cached().cameraDownHeld)
savedLine=nil;now=now+.10;assert(cached().cameraDownHeld,'transient nil read keeps validated sample in original lease')
now=now+.151;assert(not cached(),'nil reads cannot renew the sequence lease')
v5(3,true,32);savedLine=line;assert(not cached().cameraDownHeld,'expired read still re-primes safely')
v5(4,true,0);savedLine=line;cached()
v5(5,true,32);savedLine=line;assert(cached().cameraDownHeld)
savedLine='partial packet';assert(not cached(),'malformed readable data rejects immediately')
print('PASS transient action file denial preserves held state within original lease; stale/invalid packets still fail safely')
