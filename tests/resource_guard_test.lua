local M=dofile('mod/Scripts/resource_guard.lua')
for _,text in ipairs{'','ZFPVR11 1 9000 9000 1 9 8','ZFPVR11 1 9000 9000 1 0 5','ZFPVR11 0 1 1 0 0 0','ZFPVR11 1 1 1 2 0 0',string.rep('1',161)}do assert(M.parse(text)==nil,text)end
local normal=assert(M.parse('ZFPVR11 1 9000 10000 1 300000 720896\n'))
assert(M.level(normal)==0)
normal.used=700000;assert(M.level(normal)==2,'near-capacity UObject pool must stop flight before another allocation batch')
normal.used=650000;assert(M.level(normal)==1,'noncritical high-water must leave ordinary FPV available')
normal.ram=953;normal.used=364035;normal.commit=7853
assert(M.level(normal)==0,'v12 game log: low physical RAM with ample commit must allow F8 and selected draw distance')
normal.ram=631;normal.used=632730;normal.commit=734;assert(M.level(normal)==1,'v14 log: thermal selection was blocked by memory, not a sensor error')
normal.commit=128;assert(M.level(normal)==2)
normal.commit=1800;assert(M.level(normal)==1)
normal.used=530197;normal.commit=10527;normal.ram=4068
assert(M.level(normal)==0,'reported 4GB free RAM must not disable user distance selection')
local rawOpen=io.open
local text,loads,polls='ZFPVR11 1 9000 10000 1 300000 720896',0,0
io.open=function()return {read=function()return text end,close=function()end}end
local guard=M.new('test/',function()end,function(path,symbol)
    assert(path=='test/ZoneFPVNative.dll' and symbol=='zonefpv_resources_poll');loads=loads+1
    return function()polls=polls+1 end
end)
assert(guard:update(0)==0);assert(guard:update(.1)==0 and polls==1)
text='ZFPVR11 2 500 128 1 300000 720896';assert(guard:update(.6)==2)
text='ZFPVR11 1 9000 9000 1 300000 720896';assert(guard:update(1.2)==2,'stale samples cannot clear pressure')
text='ZFPVR11 3 631 734 1 632730 720896';assert(guard:update(1.8)==1 and loads==1,'entry must recover without waiting for 3 GB or five seconds')
text='ZFPVR11 4 900 9000 1 300000 720896';assert(guard:update(2.4)==1)
text='ZFPVR11 5 900 9000 1 300000 720896';assert(guard:update(7.5)==0,'stable advisory recovery remains separate from entry recovery')
text='ZFPVR11 6 2000 1900 1 300000 720896';assert(guard:update(8.1)==0)
text='ZFPVR11 7 2100 9000 1 300000 720896';assert(guard:update(8.7)==0,'brief pressure does not unload the world')
text='ZFPVR11 8 2000 2000 1 300000 720896';assert(guard:update(9.3)==0)
text='ZFPVR11 9 1900 1900 1 300000 720896';assert(guard:update(11.4)==1,'sustained commit pressure raises an advisory')
text='ZFPVR11 10 2800 2800 1 300000 720896';assert(guard:update(12)==1,'separate recovery threshold prevents oscillation')
assert(guard.streamingLimited,'boosted loading must not oscillate around the 2 GB threshold')
text='ZFPVR11 11 900 3200 1 300000 720896';assert(guard:update(12.6)==1)
text='ZFPVR11 12 900 3000 1 300000 720896';assert(guard:update(15.6)==1)
text='ZFPVR11 13 900 3200 1 300000 720896';assert(guard:update(18.6)==1)
text='ZFPVR11 14 900 4000 1 300000 720896';assert(guard:update(23.7)==0)
assert(not guard.streamingLimited,'sufficient recovery releases the temporary loading limit')
io.open=rawOpen
assert(M.streamingLimited({known=true,commit=1698,used=582915,maximum=720896}),'v15 crash: boosted streaming must stop before exhaustion')
assert(M.streamingLimited({known=true,commit=9000,used=666168,maximum=720896}),'v15 final native sample: restore native ranges even with sufficient commit')
assert(not M.streamingLimited({known=true,commit=9000,used=300000,maximum=720896}),'ample room permits the requested distance')
assert(M.streamingLimited(nil),'unknown capacity cannot justify boosted loading')
print('PASS resources: corrupt/stale input, recovery, limited polling and high-water vs actual memory pressure')
