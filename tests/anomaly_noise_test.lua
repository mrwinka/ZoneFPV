local M=dofile('mod/Scripts/anomaly_noise.lua')
for i=0,5 do assert(M.parse(tostring(i))==i)end
for _,s in ipairs{'6','-1','1.0','2 3','nan',''}do assert(M.parse(s)==nil)end
for normal=0,4 do for choice=0,5 do
    assert(M.style(normal,choice,false)==normal)
    assert(M.style(normal,choice,true)==(choice==0 and normal or choice-1))
end end
local original=io.open;local saved
io.open=function()return {write=function(_,s)saved=s;return true end,close=function()return true end}end
local ok,v=M.save('',4);assert(ok and v==4 and saved=='4\n')
io.open=original
print('PASS anomaly noise: independent override only inside anomaly interference; save returns selected value')
