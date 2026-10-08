local M=dofile('mod/Scripts/pda_geometry.lua')
local function object(address)return {IsValid=function()return true end,GetAddress=function()return address end}end
local widget=object(0x10000);widget.GetCachedGeometry=object(0x10008)
local slate=object(0x10010);slate.GetLocalSize=object(0x10018);slate.AbsoluteToLocal=object(0x10020)
local layout=object(0x10028);layout.GetMousePositionOnPlatform=object(0x10030)
local files,loads,queries,writes={},0,0,0
local mode='ok'
local adapter={load=function(path,symbol)
    assert(path=='fixture/ZoneFPVNative.dll'and symbol=='zonefpv_pda_geometry_query');loads=loads+1
    return function()
        queries=queries+1
        local line=assert(files['fixture/native-pda-geometry-control.txt'])
        local token,addresses=line:match('^ZFPVPG51 (%d+) ([%x ]+)\n$')
        assert(addresses=='10000 10008 10010 10018 10020 10028 10030','Only object/function addresses cross Lua; no opaque geometry table is reconstructed')
        if mode=='throw'then error('native query failed')end
        if mode=='nopublish'then return end
        files['fixture/native-pda-geometry-status.txt']=string.format('ZFPVPG51 %s 1 0 800 450 240 -30\n',mode=='stale'and '0'or token)
    end
end,write=function(path,value)
    writes=writes+1
    if mode=='clearfail'and path=='fixture/native-pda-geometry-status.txt'then return false end
    files[path]=value;return true
end,read=function(path,limit)assert(limit==512);return files[path]end}
local client=M.new('fixture/',adapter)
local result=assert(client.query(widget,slate,layout))
assert(result.width==800 and result.height==450 and result.x==240 and result.y==-30,'Scalar native snapshot retains outside-pointer coordinates')
assert(client.query(widget,slate,layout)and loads==1 and queries==2)
mode='stale';local value,reason=client.query(widget,slate,layout);assert(not value and reason=='invalid_status')
mode='throw';value,reason=client.query(widget,slate,layout);assert(not value and reason=='query_failed','Native exception cannot reuse a prior good status')
-- A real module reload restarts token1 while runtime status survives. Failure
-- to publish the next native response must never reuse that old successful1.
files['fixture/native-pda-geometry-status.txt']='ZFPVPG51 1 1 0 800 450 240 -30\n'
mode='nopublish';local reloaded=dofile('mod/Scripts/pda_geometry.lua').new('fixture/',adapter)
value,reason=reloaded.query(widget,slate,layout);assert(not value and reason=='invalid_status')
files['fixture/native-pda-geometry-status.txt']='ZFPVPG51 2 1 0 800 450 240 -30\n'
mode='clearfail';local beforeQuery=queries
value,reason=reloaded.query(widget,slate,layout);assert(not value and reason=='reset_failed'and queries==beforeQuery,
 'No native query is issued if old response freshness cannot be established')
local before=writes;value,reason=client.query(widget,nil,layout);assert(not value and reason=='invalid_object_3'and writes==before)
widget.IsValid=function()return false end;assert(not client.query(widget,slate,layout)and writes==before)
for _,line in ipairs({'ZFPVPG51 9 1 0 0 450 0 0','ZFPVPG51 9 1 0 800 450 nan 0',
    'ZFPVPG51 9 1 1 800 450 0 0','ZFPVPG51 9 1 0 800 450 0 0 extra','ZFPVPG51 8 1 0 800 450 0 0',string.rep('x',513)})do
    assert(not M.parse(line,9),'Malformed or noncurrent data must not become a drag position')
end
value,reason=M.parse('ZFPVPG51 9 0 7 0 0 0 0\n',9);assert(not value and reason=='native_7')
local absent=M.new('',{load=function()return nil end});widget.IsValid=function()return true end
value,reason=absent.query(widget,slate,layout);assert(not value and reason=='native_unavailable')
print('PASS PDA native geometry client: exact address-only request, current token/scalar validation, outside pointer, lazy load, module reload/no-publish and failed-clear never replay stale geometry')
