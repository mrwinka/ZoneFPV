local M=dofile('mod/Scripts/experiments_settings.lua')
local d=M.defaults();assert(d.style==0 and not d.droneHP and not d.detector)
local v=M.parse('3 1 0 1 1 1 0 1 1')
assert(v.style==3 and v.obstacles and not v.characters and v.detector)
assert(M.parse('4 0 0 0 0 0 0 0 0').style==4)
for _,bad in ipairs({'5 0 0 0 0 0 0 0 0','1 2 0 0 0 0 0 0 0','1 0 0','1 0 0 0 0 0 0 0 0 extra','1 0 0 0 0 0 0 0 0\nquit'}) do assert(not M.parse(bad)) end
local raw=io.open;io.open=function()return nil end
assert(not M.save('mock/',d,'1 1 1 1 1 1 1 1 1'));assert(d.style==0 and not d.obstacles)
io.open=raw
print('PASS experimental settings allowlist and failed-write preservation')
