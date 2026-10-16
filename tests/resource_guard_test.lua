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

-- Model the Windows publication distinction, not just read-call counts: a
-- retained handle follows its original inode, while a new open sees a rename.
local function row(seq,commit)return string.format('ZFPVR11 %d 9000 %d 1 300000 720896\n',seq,commit or 9000)end
local state={inode={text=row(0)},sequence=0,opens=0,closes=0,live=0,peak=0,reads=0,seeks=0,polls=0}
local function fixtureLoader(path,symbol)
    assert(path=='resource-fixture/ZoneFPVNative.dll')
    if symbol=='zonefpv_resources_persistent_io'then
        return function()error('The capability marker must only be resolved, never executed')end
    end
    assert(symbol=='zonefpv_resources_poll')
    return function()
        state.polls=state.polls+1
        if state.pollError then error('native publication failed')end
        if state.replaced then state.inode={text=state.inode.text};state.replaced=false end
        if not state.stale then state.sequence=state.sequence+1 end
        state.inode.text=state.corrupt and 'partial write' or row(state.sequence,state.commit)
    end
end
io.open=function(path,mode)
    assert(path=='resource-fixture/native-resources-status.txt'and mode=='rb')
    state.opens=state.opens+1;state.live=state.live+1;state.peak=math.max(state.peak,state.live)
    local inode=state.inode
    local file={unbuffered=false,closed=false}
    function file:setvbuf(mode)
        assert(mode=='no');if state.bufferError then return nil,'buffer mode unavailable'end
        self.unbuffered=true;return true
    end
    function file:seek(mode,offset)
        assert(not self.closed and mode=='set'and offset==0)
        state.seeks=state.seeks+1
        if state.seekError then state.seekError=false;return nil,'seek failed'end
        return 0
    end
    function file:read(count)
        assert(not self.closed and self.unbuffered and count==161,'CRT read-ahead must be disabled before native updates')
        state.reads=state.reads+1
        if state.readError then state.readError=false;error('read failed')end
        return inode.text
    end
    function file:close()
        assert(not self.closed,'exactly one close per descriptor')
        self.closed=true;state.live=state.live-1;state.closes=state.closes+1;return true
    end
    return file
end
local fixtureOK,fixtureError=xpcall(function()
    local live=M.new('resource-fixture/',function()end,fixtureLoader)
    for tick=0,99 do
        local level,sample=live:update(tick*.101,true)
        assert(level==0 and sample.seq==tick+1,'every native publication must be observed through the same live descriptor')
    end
    assert(live.persistentIO and state.opens==1 and state.live==1 and state.reads==100 and state.peak==1)
    local priorPolls=state.polls;live:update(99*.101+.01,true)
    assert(state.polls==priorPolls,'persistent IO does not bypass guard cadence')
    local now=10.2
    state.commit=128;assert(live:update(now,true)==2)
    local pressure=live.sample
    state.stale=true;state.commit=9000
    local before=state.opens
    assert(live:update(now+.11,true)==2 and live.sample==pressure and state.opens==before+1 and state.live==0,
        'same sequence with healthy values must never lift pressure; stale handles close after one reopen retry')
    state.stale=false;state.commit=128;state.replaced=true
    assert(live:update(now+.22,true)==2 and state.live==1)
    pressure=live.sample
    state.replaced=true;state.commit=9000;before=state.opens
    local level,sample=live:update(now+.33,true)
    assert(level==1 and sample.seq>pressure.seq and state.opens==before+1 and state.live==1,
        'inode replacement must reopen in the same bounded attempt and recover the newest committed sample')
    state.commit=128;state.seekError=true;before=state.opens
    assert(live:update(now+.44,true)==2 and state.opens==before+1 and state.live==1,'failed seek closes and reopens exactly once')
    state.readError=true;before=state.opens
    assert(live:update(now+.55,true)==2 and state.opens==before+1 and state.live==1,'failed read closes and reopens exactly once')
    pressure=live.sample;state.corrupt=true;before=state.opens
    assert(live:update(now+.66,true)==2 and live.sample==pressure and state.opens==before+1 and state.live==0,
        'two malformed reads leave no descriptor and cannot replace the last pressure sample')
    state.corrupt=false;assert(live:update(now+.77,true)==2 and state.live==1)
    pressure=live.sample;state.pollError=true
    assert(live:update(now+.88,true)==2 and live.sample==pressure and state.live==0,'failed publication releases its persistent reader')
    state.pollError=false;assert(live:update(now+.99,true)==2 and state.live==1)
    live:close();pressure=live.sample;state.bufferError=true;before=state.opens
    assert(live:update(now+1.10,true)==2 and live.sample==pressure and state.opens==before+2 and state.live==0,
        'unavailable unbuffered IO must fail closed after two bounded attempts, rather than reuse read-ahead')
    state.bufferError=false;assert(live:update(now+1.21,true)==2 and state.live==1)
    live:close();live:close()
    assert(state.live==0 and state.peak==1 and state.opens==state.closes,'all failure paths retain at most one handle and explicit close is idempotent')
end,debug.traceback)
io.open=rawOpen;assert(fixtureOK,fixtureError)
print('PASS persistent resources: live inode reuse, unbuffered reads, replacements, stale pressure, bounded retries, publication/seek/read/parse failures and handle ownership')

-- Exercise actual Lua FILE* semantics as well as the replacement fixture.
-- In-place native publication changes both length and content under one rb
-- reader. A CRT buffer or missing rewind repeats old bytes and fails this.
local status=os.tmpname()
local actualOpens,actualCloses=0,0
local published=0
io.open=function(path,mode)
    if path=='resource-real/native-resources-status.txt'then
        assert(mode=='rb');actualOpens=actualOpens+1
        local file=assert(rawOpen(status,'rb'))
        return {setvbuf=function(_,...)return file:setvbuf(...)end,seek=function(_,...)return file:seek(...)end,
            read=function(_,...)return file:read(...)end,close=function()actualCloses=actualCloses+1;return file:close()end}
    end
    return rawOpen(path,mode)
end
local actualOK,actualError=xpcall(function()
    local actual=M.new('resource-real/',function()end,function(_,symbol)
        if symbol=='zonefpv_resources_persistent_io'then return function()end end
        assert(symbol=='zonefpv_resources_poll')
        return function()
            published=published+1
            local file=assert(rawOpen(status,'wb'))
            file:write(row(published,published%2==0 and 128 or 9000));file:close()
        end
    end)
    for tick=0,1099 do
        local _,sample=actual:update(tick*.101,true)
        assert(sample and sample.seq==tick+1 and sample.commit==((tick+1)%2==0 and 128 or 9000),
            'real native-style rewrite must be visible immediately, including shrinking fields and sequence digit changes')
    end
    assert(actualOpens==1 and actual.resourceFile,'one actual Lua descriptor survives all synchronous publications')
    actual:close();assert(actualCloses==1)
end,debug.traceback)
io.open=rawOpen;os.remove(status);assert(actualOK,actualError)
print('PASS real FILE* resource stream: 1100 changing in-place publications through one unbuffered reader')
