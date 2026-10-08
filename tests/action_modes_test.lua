local M=dofile('mod/Scripts/action_modes.lua')
local legacy=M.parse('1 1 0');assert(legacy.cameraDown==1 and legacy.vision==0 and legacy.flashlight==0)
local all=M.parse('1 1 1 1\n');assert(all.cameraDown==1 and all.vision==1 and all.flashlight==1)
for _,name in ipairs({'menu','pilot','reset','collect','grenadeDrop'})do assert(all[name]==0,'legacy only migrates its three existing modes')end
all=M.parse('2 1 1 1 1 1 1 1 1\n')
for _,name in ipairs(M.names)do assert(all[name]==1)end
for _,text in ipairs({'','0 1 1 1','1 2 0 0','1 -1 0 0','1 01 0 0','1 1','1 1 0 0 1','1 1 0 x'})do assert(not M.parse(text))end
for _,text in ipairs({'2 0 0 0 0 0 0 0','2 0 0 0 0 0 0 0 0 0','2 0 0 0 0 0 0 0 2','2 00 0 0 0 0 0 0 0'})do assert(not M.parse(text))end
local original=io.open;local written;local failWrite,failClose=false,false
io.open=function(path,mode)
    assert(path=='fixture/action-modes.txt')
    if mode=='r'then return {read=function()return written end,close=function()return true end}end
    return {write=function(_,text)written=text;return not failWrite end,close=function()return not failClose end}
end
local defaults=M.load('fixture/');assert(defaults.cameraDown==0 and defaults.vision==0 and defaults.flashlight==0)
local ok,saved=M.save('fixture/',defaults,'cameraDown',1);assert(ok and written=='2 0 0 0 0 0 1 0 0\n'and defaults.cameraDown==0)
ok,saved=M.save('fixture/',saved,'vision',1);assert(ok and written=='2 0 0 0 0 0 1 0 1\n')
ok,saved=M.save('fixture/',saved,'flashlight',1);assert(ok and written=='2 0 0 0 0 1 1 0 1\n')
for _,name in ipairs({'menu','pilot','reset','collect','grenadeDrop'})do
    ok,saved=M.save('fixture/',saved,name,1);assert(ok and saved[name]==1)
end
assert(written=='2 1 1 1 1 1 1 1 1\n')
assert(M.load('fixture/').flashlight==1)
assert(not M.save('fixture/',saved,'grenade',1)and not M.save('fixture/',saved,'cameraDown',2))
failWrite=true;assert(not M.save('fixture/',saved,'cameraDown',0));failWrite=false
failClose=true;assert(not M.save('fixture/',saved,'cameraDown',0))
io.open=original
print('PASS activation modes: legacy defaults, exact toggle/hold values, independent preferences, failed persistence and unknown actions')
