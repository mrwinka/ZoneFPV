local M=dofile('mod/Scripts/impact_settings.lua')
assert(M.parse('0')==0 and M.parse('5')==5 and M.parse('0.25\n')==.25)
for _,v in ipairs({'5.01','-1','nan','1e0','.25','1..2','1.2.3','0.1 extra','0.1\nquit'}) do assert(M.parse(v)==nil) end
local raw=io.open;local saved
io.open=function(_,mode)
    if mode=='r' then return {read=function()return saved or 'malformed'end,close=function()return true end}end
    return {write=function(_,s)saved=s;return true end,close=function()return true end}
end
assert(M.load('mock/')==2);assert(M.save('mock/','0') and M.load('mock/')==0)
assert(M.save('mock/','2.5') and M.load('mock/')==2.5)
assert(M.save('mock/','0.000001') and M.load('mock/')==0.000001)
io.open=function()return nil end;assert(not M.save('mock/','1'))
io.open=raw
print('PASS collision multiplier validation, zero value, persistence and failed writes')
