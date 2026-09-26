local scheduler=dofile('mod/Scripts/scheduler.lua')
local now,logs,calls=0,{},0
local queue={}
local s=scheduler.new(function(...)
    assert(select('#',...)==1,'must not override configured UE4SS hook')
    calls=calls+1;queue[#queue+1]=(...)
end,function() return now end,function(s) logs[#logs+1]=s end)
local ran=false
assert(s.ready() and s.post(function() ran=true end))
assert(not ran and calls==1)
queue[1]();assert(ran)
local fail=true
s=scheduler.new(function(...) assert(select('#',...)==1);calls=calls+1;if fail then error('hook unavailable') end;(...)() end,
    function() return now end,function(v) logs[#logs+1]=v end)
assert(not s.post(function() end) and not s.ready())
assert(calls==2 and #logs==1) -- no silent fallback to ProcessEvent
now=4.9;assert(not s.ready());now=5;assert(s.ready())
fail=false;assert(s.post(function() end))
print('PASS configured-default dispatch, deferred callback, bounded error retry, no hook fallback')
