local M=dofile('mod/Scripts/pda_navigation_keys.lua')
local epochBase=1700000000
local function line(seq,stamp,focus,q,e,qSeq,eSeq,last)
    return table.concat({1,seq or 1,stamp or epochBase*1000,focus or 0,q or 0,e or 0,qSeq or 0,eSeq or 0,last or seq or 1},' ')
end
local function fixture()
    local state={time=0,epoch=epochBase,line=line(1,nil,1),reads=0}
    local provider=M.new(function()
        state.reads=state.reads+1
        if state.readError then error('Sharing violation')end
        return state.line
    end,function()return state.time end,function()return state.epoch end)
    return state,provider
end
local function keys(provider,q,e,qSeq,eSeq)
    local value=provider()
    assert(value and value.q==q and value.e==e and value.qSeq==qSeq and value.eSeq==eSeq,'Expected current navigation keys')
    assert(value.connected==nil and value.calibrated==nil,'Keyboard exchange must not depend on joystick state')
end
do
    local state,provider=fixture()
    state.line='\t'..line(1,nil,1,1,0,9,7)..'\r\n'
    keys(provider,true,false,9,7)
    state.line=line(2,nil,1,0,1,9,8)
    keys(provider,false,true,9,8)
    state.line=line(3,nil,1,1,1,10,9)
    keys(provider,true,true,10,9)
    -- A press and release between game ticks still advances its counter.
    state.line=line(4,nil,1,0,0,11,10)
    keys(provider,false,false,11,10)
    assert(state.reads==4,'Each call must read a fresh snapshot')
end
do
    local state,provider=fixture()
    keys(provider,false,false,0,0)
    state.time=.25
    keys(provider,false,false,0,0)
    state.time=.25001
    assert(provider()==nil,'Repeated sequence must expire after 250 ms')
    state.epoch=epochBase+1
    state.line=line(1,state.epoch*1000,1,1,0,1,0)
    assert(provider()==nil,'Timestamp changes must not renew a repeated sequence')
    state.line=line(2,state.epoch*1000,1,1,0,1,0)
    keys(provider,true,false,1,0)
end
do
    local state,provider=fixture()
    state.line=line(1,epochBase*1000-2001,1,1)
    assert(provider()==nil,'Reject stale snapshots on the first read')
    state.line=line(1,epochBase*1000+2001,1,1)
    assert(provider()==nil,'Reject timestamps too far in the future')
    state.line=line(1,epochBase*1000-2000,1,1)
    keys(provider,true,false,0,0)
    state.time=.3
    state.line=line(2,epochBase*1000-2001,1)
    assert(provider()==nil,'Stale sequences must not renew the lease')
    state.line=line(1,epochBase*1000,1)
    assert(provider()==nil,'A previously seen sequence remains expired')
end
do
    local state,provider=fixture()
    state.line=line(1,nil,1,1,0,1,0)
    keys(provider,true,false,1,0)
    state.line=nil
    assert(provider()==nil,'Missing snapshot must not reuse held keys')
    state.line=line(1,nil,1,1,0,1,0)
    state.readError=true
    assert(provider()==nil,'Read errors must return no keys')
    state.readError=false
    state.time=.3
    assert(provider()==nil,'Missing reads must not extend the lease')
    state.line=line(2,nil,0,1,1,2,1)
    assert(provider()==nil,'Unfocused snapshots must return no keys')
    state.line=line(3,nil,1,0,0,2,1)
    keys(provider,false,false,2,1)
end
do
    local state,provider=fixture()
    state.line=line(100,nil,1,1,0,23,17)
    keys(provider,true,false,23,17)
    state.time=.4
    state.line=line(1,epochBase*1000+100,1,0,0,0,0)
    keys(provider,false,false,0,0)
    state.time=.7
    assert(provider()==nil,'Restarted writer still has a bounded lease')
end
local malformed={
    false,{},'',
    '1 1 1700000000000 1 0 0 0 0',
    '1 1 1700000000000 1 0 0 0 0 1 1',
    '2 1 1700000000000 1 0 0 0 0 1',
    '1 0 1700000000000 1 0 0 0 0 0',
    '1 1 1700000000000 1 0 0 0 0 2',
    '1.0 1 1700000000000 1 0 0 0 0 1',
    '1 1 -1 1 0 0 0 0 1',
    '1 1 1700000000000 2 0 0 0 0 1',
    '1 1 1700000000000 1 2 0 0 0 1',
    '1 1 1700000000000 1 0 2 0 0 1',
    '1 1 1700000000000 1 0 0 -1 0 1',
    '1 1 1700000000000 1 0 0 0 -1 1',
    '1 1000000000000001 1700000000000 1 0 0 0 0 1000000000000001',
    '1 1 1000000000000001 1 0 0 0 0 1',
    '1 1 1700000000000 1 0 0 1000000000000001 0 1',
    '1 1 1700000000000 1 0 0 0 1000000000000001 1',
    '1 nan 1700000000000 1 0 0 0 0 nan',
    '1 1e3 1700000000000 1 0 0 0 0 1e3',
    '1 1 1700000000000 1 0 0 0 0 1x',
    '1 '..string.rep('9',400)..' 1700000000000 1 0 0 0 0 1',
}
for i,bad in ipairs(malformed)do
    local state,provider=fixture()
    state.line=bad
    assert(provider()==nil,'Malformed packet '..i..' must return no keys')
    state.line=line(1,nil,1,0,0,0,0)
    keys(provider,false,false,0,0)
end
do
    local state,provider=fixture()
    state.line='1 1000000000000000 1700000000000 1 0 0 1000000000000000 1000000000000000 1000000000000000'
    keys(provider,false,false,1000000000000000,1000000000000000)
end
print('PASS PDA navigation snapshots: independent keyboard keys, atomic framing, focus, epoch freshness, sequence lease, rapid taps and writer restart')
