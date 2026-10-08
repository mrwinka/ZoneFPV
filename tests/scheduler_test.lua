local scheduler=dofile('mod/Scripts/scheduler.lua')
EGameThreadMethod={EngineTick=0,ProcessEvent=1}
local now,logs,calls=0,{},0
local queue={}
local s=scheduler.new(function(...)
    assert(select('#',...)==2 and select(2,...)==0,'must require EngineTick, never ProcessEvent')
    calls=calls+1;queue[#queue+1]=(...)
end,function() return now end,function(s) logs[#logs+1]=s end)
local ran=false
assert(s.ready() and s.post(function() ran=true end))
assert(not ran and calls==1)
queue[1]();assert(ran)
local fail=true
s=scheduler.new(function(...) assert(select('#',...)==2 and select(2,...)==0);calls=calls+1;if fail then error('hook unavailable') end;(...)() end,
    function() return now end,function(v) logs[#logs+1]=v end)
assert(not s.post(function() end) and not s.ready())
assert(calls==2 and #logs==1) -- no silent fallback to ProcessEvent
now=4.9;assert(not s.ready());now=5;assert(s.ready())
fail=false;assert(s.post(function() end))
print('PASS EngineTick-only dispatch, deferred callback, bounded error retry, no unsafe ProcessEvent fallback')
local jobs,runCount,stopped={},0,nil
now=0
s=scheduler.new(function(...)
    assert(select('#',...)==2 and select(2,...)==0);jobs[#jobs+1]=(...)
end,function()return now end,function(v)logs[#logs+1]=v end)
local started,stop=s.start(function()runCount=runCount+1 end,0.004)
assert(started and #jobs==1 and runCount==0)
local function nextJob()local job=table.remove(jobs,1);job();assert(#jobs<=1)end
nextJob();assert(runCount==1 and #jobs==1)
now=0.003;nextJob();assert(runCount==1)
now=0.004;nextJob();assert(runCount==2)
stop();nextJob();assert(#jobs==0 and runCount==2)
print('PASS game-thread recurrence, single queued callback, minimum interval, cancellation')
EGameThreadMethod=nil
local attempted=false
local missing=scheduler.new(function()attempted=true end,function()return now end,function()end)
assert(not missing.post(function()end) and not attempted,'unsupported runtime must not enqueue any Lua action')
print('PASS missing EngineTick enum fails closed before invoking the dispatcher')
