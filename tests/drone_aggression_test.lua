local aggression=dofile('mod/Scripts/drone_aggression.lua')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function object(at,world)
    local o={address=at,world=world}
    function o:IsValid()return not self.expired end
    function o:GetAddress()return self.address end
    function o:GetWorld()return self.world end
    return o
end
local function fixture(n)
    local world=object(0x10000);local pawn=object(0x20000,world)
    local s={world=world,pawn=pawn,worldExperiments={entries={}}}
    local actors={};local entries={};local calls={}
    for i=1,n do
        local a=object(0x30000+i*8,world);actors[i]=a
        entries[a.address]={actor=a,guid=100+i,core=0x40000+i*8,index=i,focus=0}
    end
    local client={}
    function client:request(p,items,clear)
        assert(p==pawn and #items>=1 and #items<=16)
        calls[#calls+1]={clear=clear,count=#items,items=items}
        if self.fail then error('native request failed')end
        local rows={}
        for _,item in ipairs(items)do
            local a=clear and item.actor or item;local live=entries[a.address]
            local row={guid=live.guid,core=live.core,index=live.index,focus=live.focus,reason=0}
            if clear and (live.focus==pawn.address or live.focus==0 and item.acquired)
                and item.guid==live.guid and item.core==live.core and item.index==live.index then
                live.focus=0;live.searching=false;row.focus=0;row.cleared=true;row.attempted=true
            elseif clear then row.reason=live.focus==0 and 1 or 2
            end
            rows[a.address]=row
        end
        return rows
    end
    FindAllOf=function(kind)assert(kind=='Agent');return actors end
    return s,actors,entries,client,calls
end
test('new drone focus is cleared while existing player and other targets are preserved',function()
    local s,a,e,client,calls=fixture(4)
    e[a[2].address].focus=s.pawn.address;e[a[3].address].focus=0x90000
    local g=aggression.start(s,'',nil,client);g:activate()
    e[a[1].address].focus=s.pawn.address;e[a[4].address].focus=0xa0000
    assert(g:restore() and g.cleared==1 and g.protected==2)
    assert(e[a[1].address].focus==0 and e[a[2].address].focus==s.pawn.address)
    assert(e[a[3].address].focus==0x90000 and e[a[4].address].focus==0xa0000)
    assert(calls[2].count==2 and calls[2].clear)
    local total=#calls;assert(g:restore() and #calls==total,'restoration must be idempotent')
end)
test('capture keeps the first baseline even after the same actor acquires the pawn',function()
    local s,a,e,client=fixture(1);local g=aggression.start(s,'',nil,client);g:activate()
    e[a[1].address].focus=s.pawn.address;assert(g:capture(a))
    assert(g.baseline[a[1].address].focus==0 and g:restore() and g.cleared==1)
end)
test('streamed actors keep first snapshots and acquisition observation uses bounded batches',function()
    local s,a,e,client,calls=fixture(0);local g=aggression.start(s,'',nil,client);g:activate()
    for i=1,20 do
        local actor=object(0x50000+i*8,s.world)
        e[actor.address]={guid=200+i,core=0x60000+i*8,index=i,focus=i==20 and s.pawn.address or 0}
        s.worldExperiments.entries[i]={actor=actor,type=i==1 and 2 or 1}
    end
    g:update(s,0);assert(#calls==2 and calls[1].count==16 and calls[2].count<=16)
    g:update(s,.1);assert(#calls==2)
    g:update(s,.25);assert(#calls==4 and calls[3].count==4 and calls[4].count<=16)
    for _,entry in ipairs(s.worldExperiments.entries)do e[entry.actor.address].focus=s.pawn.address end
    assert(g:restore() and g.cleared==19 and g.protected==1)
end)
test('expired and foreign world actors are excluded including two invalid worlds',function()
    local s,a,e,client,calls=fixture(4);local other=object(0x70000)
    a[2].world=other;a[3].expired=true;a[4].world=nil
    local g=aggression.start(s,'',nil,client);assert(calls[1].count==1);g:activate()
    e[a[1].address].focus=s.pawn.address;a[1].world=other
    assert(g:restore() and #calls==1)
    s.world.expired=true;s.pawn.world=object(0x10000);s.pawn.world.expired=true
    assert(aggression.start(s,'',nil,client)==nil,'nil world addresses cannot authorize capture')
end)
test('world teardown and a changed session pawn prevent native cleanup or new reads',function()
    local s,a,e,client,calls=fixture(1);local g=aggression.start(s,'',nil,client);g:activate()
    s.worldExperiments.entries={{actor=object(0x50000,s.world),type=1}}
    local original=s.pawn;s.pawn=object(0x90000,s.world);g:update(s,1);assert(#calls==1)
    s.pawn=original;s.world.expired=true
    local ok,why=g:restore();assert(ok==false and why:find('expired') and #calls==1)
end)
test('request failures are contained on initial capture flight discovery and restoration',function()
    local s,a,e,client,calls=fixture(1);client.fail=true
    local g=assert(aggression.start(s,'',nil,client));assert(g.failure:find('native request failed'));g:activate()
    client.fail=false;e[a[1].address].focus=s.pawn.address;assert(g:restore() and #calls==1)
    s,a,e,client,calls=fixture(1);g=aggression.start(s,'',nil,client);g:activate();client.fail=true
    e[a[1].address].focus=s.pawn.address
    local ok,why=g:restore();assert(ok==false and why:find('native request failed'))
    s,a,e,client,calls=fixture(0);g=aggression.start(s,'',nil,client);g:activate();client.fail=true
    s.worldExperiments.entries={{actor=object(0x50000,s.world),type=2}}
    assert(pcall(g.update,g,s,1) and g.failure:find('native request failed'))
end)
test('recycled core GUID and internal object index cannot authorize reset',function()
    for _,field in ipairs({'guid','core','index'})do
        local s,a,e,client=fixture(1);local g=aggression.start(s,'',nil,client);g:activate()
        e[a[1].address].focus=s.pawn.address;e[a[1].address][field]=e[a[1].address][field]+8
        assert(g:restore() and g.cleared==0 and e[a[1].address].focus==s.pawn.address)
    end
end)
test('initial and cleanup batches respect the sixteen actor native limit',function()
    local s,a,e,client,calls=fixture(34);local g=aggression.start(s,'',nil,client);g:activate()
    assert(#calls==3 and calls[1].count==16 and calls[2].count==16 and calls[3].count==2)
    for _,actor in ipairs(a)do e[actor.address].focus=s.pawn.address end
    assert(g:restore() and #calls==6 and g.cleared==34)
end)
test('full baseline preserves valid original targets and never resets uncaptured actors',function()
    local s,a,e,client,calls=fixture(2050)
    e[a[2].address].focus=0x90000
    local messages={};local g=aggression.start(s,'',function(v)messages[#messages+1]=v end,client);g:activate()
    assert(#g.baselineRows==2048 and #calls==128)
    s.worldExperiments.entries={{actor=a[2049],type=1},{actor=a[2050],type=2}}
    for _,actor in ipairs(a)do e[actor.address].focus=s.pawn.address end
    g:update(s,0);g:update(s,.25)
    assert(#g.baselineRows==2048 and #calls==130 and #messages==1)
    assert(g.baseline[a[2].address].focus==0x90000,'capacity cannot replace a valid first target')
    assert(g:restore() and g.cleared==2047 and g.protected==1)
    assert(e[a[2].address].focus==s.pawn.address)
    assert(e[a[2049].address].focus==s.pawn.address and e[a[2050].address].focus==s.pawn.address)
end)
test('expired snapshots are incrementally released and freed capacity can observe later actors',function()
    local s,a,e,client,calls=fixture(2048);local g=aggression.start(s,'',nil,client);g:activate()
    for _,actor in ipairs(a)do actor.expired=true end
    g:update(s,0)
    assert(#g.baselineRows==2032,'one interval retires at most sixteen expired wrappers')
    g:update(s,.1);assert(#g.baselineRows==2032,'pruning respects the interval')
    for i=1,16 do
        local actor=object(0x80000+i*8,s.world)
        e[actor.address]={guid=3000+i,core=0x90000+i*8,index=3000+i,focus=i==1 and s.pawn.address or 0}
        s.worldExperiments.entries[i]={actor=actor,type=1}
    end
    g:update(s,.25);assert(#g.baselineRows==2032 and calls[129].count==16)
    for i=2,280 do g:update(s,i*.25)end
    assert(#g.baselineRows==16,'retired wrappers must not accumulate over a long flight')
    local retained=0;for _ in pairs(g.baseline)do retained=retained+1 end;assert(retained==16)
    for _,entry in ipairs(s.worldExperiments.entries)do e[entry.actor.address].focus=s.pawn.address end
    assert(g:restore() and g.cleared==15 and g.protected==1,'a target already present when capacity frees stays protected')
end)
test('a still-valid wrapper with a reused native identity keeps fail-closed cleanup',function()
    local s,a,e,client,calls=fixture(1);local g=aggression.start(s,'',nil,client);g:activate()
    local original=g.baseline[a[1].address]
    local replacement=object(a[1].address,s.world)
    e[replacement.address]={guid=999,core=0xa0000,index=999,focus=s.pawn.address}
    s.worldExperiments.entries={{actor=replacement,type=1}}
    g:update(s,0)
    assert(g.baseline[replacement.address]==original and #g.baselineRows==1 and #calls==2)
    assert(g:restore() and g.cleared==0 and e[replacement.address].focus==s.pawn.address)
end)
test('observed acquisition resets persistent search after parking has erased current focus',function()
    local s,a,e,client=fixture(3)
    e[a[2].address].focus=s.pawn.address;e[a[3].address].focus=0x90000
    local g=aggression.start(s,'',nil,client);g:activate()
    e[a[1].address].focus=s.pawn.address;e[a[1].address].searching=true
    g:update(s,0)
    assert(g.baseline[a[1].address].acquired and g.acquiredCount==1)
    e[a[1].address].focus=0 -- collision-off / proxy parking loses aim, not memory
    assert(g:restore() and g.cleared==1 and not e[a[1].address].searching)
    assert(g.protected==2 and e[a[2].address].focus==s.pawn.address and e[a[3].address].focus==0x90000)
end)
test('last-frame acquisition is observed before parking even between periodic reads',function()
    local s,a,e,client=fixture(1);local g=aggression.start(s,'',nil,client);g:activate()
    e[a[1].address].focus=s.pawn.address;e[a[1].address].searching=true
    g:prepare();assert(g.baseline[a[1].address].acquired)
    e[a[1].address].focus=0
    assert(g:restore() and g.cleared==1 and not e[a[1].address].searching)
    -- The next flight takes a fresh baseline; native targets that predate it
    -- are protected, not retroactively assumed to belong to an earlier drone.
    e[a[1].address].focus=s.pawn.address
    local second=aggression.start(s,'',nil,client);second:activate();second:prepare()
    assert(second:restore() and second.protected==1 and second.cleared==0)
end)
test('acquisition history never resets an actor that has switched to another target',function()
    local s,a,e,client=fixture(1);local g=aggression.start(s,'',nil,client);g:activate()
    e[a[1].address].focus=s.pawn.address;g:prepare()
    e[a[1].address].focus=0x90000;e[a[1].address].searching=true
    assert(g:restore() and g.cleared==0 and e[a[1].address].focus==0x90000 and e[a[1].address].searching)
end)
local notified,registrations=nil,0
NotifyOnNewObject=function(name,callback)
    assert(name=='/Script/Stalker2.Agent');notified=callback;registrations=registrations+1
end
test('new NPC acquisition is tracked without enabling scanner markers and survives late native initialization',function()
    local s,a,e,client=fixture(0);local g=aggression.start(s,'',nil,client);g:activate()
    local actor=object(0x50000,s.world)
    e[actor.address]={guid=333,core=0x60000,index=333,focus=s.pawn.address,searching=true}
    local request=client.request;local first=true
    function client:request(p,items,clear)
        if first and not clear then first=false;return {} end
        return request(self,p,items,clear)
    end
    notified(actor);g:update(s,0)
    assert(not g.baseline[actor.address] and #g.pending==1)
    g:update(s,.25)
    assert(g.baseline[actor.address].acquired and g.baseline[actor.address].firstFocus==s.pawn.address)
    e[actor.address].focus=0
    assert(g:restore() and g.cleared==1 and not e[actor.address].searching)
    notified(actor);assert(#g.pending==0,'completed flights do not retain construction notifications')
end)
test('construction observer registers once and its pending references and retries stay bounded',function()
    local s,a,e,client=fixture(0);local g=aggression.start(s,'',nil,client);g:activate()
    for i=1,500 do notified(object(0x70000+i*8,nil))end
    assert(registrations==1 and #g.pending==128)
    for i=0,200 do g:update(s,i*.25)end
    assert(#g.pending==0 and #g.baselineRows==0)
    assert(g:restore())
end)
local function protocol(fn)
    local previousOpen,previousRemove=io.open,os.remove
    local files={};local reply
    io.open=function(path,mode)
        if mode=='wb'then
            local file={}
            function file:write(value)files[path]=value;return self end
            function file:close()return true end
            return file
        end
        if not files[path]then return nil,'not found'end
        local offset=1;local file={}
        function file:read(n)
            if offset>#files[path]then return nil end
            local value=files[path]:sub(offset,offset+n-1);offset=offset+#value;return value
        end
        function file:close()return true end
        return file
    end
    os.remove=function(path)files[path]=nil;return true end
    local function loader(path,name)
        assert(path=='fixture/ZoneFPVNative.dll' and name:find('zonefpv_aggression_'))
        return function()
            local request=assert(files['fixture/native-aggression-control.txt'])
            local token,mode,pawn,guid,n=request:match('^ZFPVAG12 (%d+) (%d+) (%x+) (%d+) (%d+)')
            files['fixture/native-aggression-status.txt']=reply(token,mode,pawn,guid,tonumber(n),request)
        end
    end
    local ok,err=pcall(fn,files,loader,function(f)reply=f end)
    io.open,os.remove=previousOpen,previousRemove
    assert(ok,err)
end
test('native loader unavailable or throwing degrades without escaping the flight tick',function()
    local world=object(0x10000);local p=object(0x20000,world);local a=object(0x30000,world)
    local rows,why=aggression.new('fixture/',false):request(p,{a},false)
    assert(rows==nil and why:find('loader unavailable'))
    rows,why=aggression.new('fixture/',function()error('loadlib failure')end):request(p,{a},false)
    assert(rows==nil and why:find('loadlib failure'))
end)
test('native protocol verifies token actor count order and valid identity before committing player GUID',function()
    protocol(function(files,loader,setReply)
        local world=object(0x10000);local p=object(0x20000,world);local a=object(0x30000,world)
        local client=aggression.new('fixture/',loader)
        setReply(function(token)return 'ZFPVAG12 1 '..token..' 100 1 0\n30000 101 40000 7 0 0 0 0\n'end)
        local rows=assert(client:request(p,{a},false));assert(client.playerGuid==100 and rows[0x30000].index==7)
        assert(files['fixture/native-aggression-control.txt']:find('20000 4294967295 1'))
        setReply(function(token)return 'ZFPVAG12 1 '..token..' 101 1 0\n30000 101 40000 7 0 0 0 0\n'end)
        assert(client:request(p,{a},false)==nil and client.playerGuid==100)
        for _,row in ipairs({'30008 101 40000 7 0 0','30000 101 40001 7 0 0','30000 101 40000 7 3 0','30000 101 40000 7 0 2'})do
            local fresh=aggression.new('fixture/',loader)
            setReply(function(token)return 'ZFPVAG12 1 '..token..' 100 1 0\n'..row..' 0 0\n'end)
            assert(fresh:request(p,{a},false)==nil and fresh.playerGuid==0xffffffff)
        end
        setReply(function(token)return 'ZFPVAG12 1 '..(tonumber(token)+1)..' 100 1 0\n30000 101 40000 7 0 0 0 0\n'end)
        assert(client:request(p,{a},false)==nil)
        setReply(function(token)return 'ZFPVAG12 1 '..token..' 100 1 0\n30000 4294967295 0 -1 0 0 0 3\n'end)
        assert(next(assert(client:request(p,{a},false)))==nil,'unsupported actor rows are ignored')
        setReply(function(token)return 'ZFPVAG12 1 '..token..' 100 1 0\n30000 101 40000 7 0 1 1 0\n'end)
        rows=assert(client:request(p,{{actor=a,guid=101,core=0x40000,index=7,acquired=true}},true))
        assert(rows[0x30000].cleared and rows[0x30000].attempted)
        assert(files['fixture/native-aggression-control.txt']:find('30000 101 40000 7 1\n',1,true))
        setReply(function(token)return 'ZFPVA7 1 '..token..' 100 1 0\n30000 101 40000 7 0 0\n'end)
        assert(client:request(p,{a},false)==nil,'v11 DLL cannot silently omit acquisition history')
    end)
end)
FindAllOf=nil
NotifyOnNewObject=nil
print('PASS '..count..' drone aggression tests')
