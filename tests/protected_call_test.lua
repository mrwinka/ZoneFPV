-- Exercise the actual private helpers, not a second implementation.
local modules={'drone_flashlight','drone_weapons','pda_page','pda_tab','pda_theme','scan_overlay',
    'scan_projection','teleport_guard','vision','world_experiments','drone_combat','fpv_particles',
    'leaf_world_visibility','pda_menu'}
local function helper(name)
    local f=assert(io.open('mod/Scripts/'..name..'.lua'));local source=f:read('*a');f:close()
    local code=assert(source:match('(local function invoke.-end\nlocal function call.-\nend)'),name)
    return assert(load(code..'\nreturn call',name))()
end
local rawPack=table.pack
local packs=0
for _,name in ipairs(modules)do
    local call=helper(name)
    local object={}
    function object:method(...)
        assert(select('#',...)==5,'nil holes and trailing arguments retained')
        local a,b,c,d,e=...
        assert(a==nil and b==17 and c==nil and d==false and e==nil)
        return 123,'second',nil,'fourth'
    end
    function object:fail()error('engine failure')end
    table.pack=function(...)packs=packs+1;return rawPack(...)end
    local result=rawPack(call(object,'method',nil,17,nil,false,nil))
    local failed=rawPack(call(object,'fail'))
    local lookup=rawPack(call(setmetatable({},{__index=function()error('unavailable UObject property')end}),'method'))
    table.pack=rawPack
    if name=='drone_combat'then
        assert(result.n==5 and result[1]==true and result[2]==123 and result[3]=='second' and result[5]=='fourth')
        assert(failed[1]==false and lookup[1]==false)
    elseif name=='pda_menu'then
        assert(result.n==2 and result[1]==123 and result[2]=='second' and failed.n==0 and lookup.n==0)
    else
        assert(result.n==1 and result[1]==123 and failed[1]==nil and lookup[1]==nil)
        local failures=(name=='fpv_particles' or name=='leaf_world_visibility')and 1 or 0
        assert(failed.n==failures and lookup.n==failures,'failure return shape retained: '..name)
    end
    assert(packs==0,'protected native invocation must not allocate argument-pack tables')
end
print('PASS 14 actual protected helpers: nil arguments, getter/method failures, original result shapes and zero argument-pack tables')
