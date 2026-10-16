-- Full stack: current resource_guard.lua, actual copied DLL, real Lua CRT IO.
local root=assert(arg[1],'isolated DLL directory required'):gsub('[/\\]$','')..'/'
local iterations=tonumber(arg[2])or 500
local expectedPersistent=arg[3]=='persistent'
local module=dofile('mod/Scripts/resource_guard.lua')
local guard=module.new(root,function()end)
local times,previous,retained={},0,nil
for i=1,iterations+10 do
    local start=os.clock()
    local _,sample=guard:update(i*.101,true)
    local elapsed=(os.clock()-start)*1000
    assert(sample and sample.seq==previous+1 and not sample.known,'Every actual guard update must consume the next native packet without reading the unsupported host object array')
    previous=sample.seq
    assert(guard.persistentIO==expectedPersistent,'Capability detection must choose the matching DLL IO contract')
    if expectedPersistent then
        assert(io.type(guard.resourceFile)=='file')
        retained=retained or guard.resourceFile
        assert(guard.resourceFile==retained,'The complete guard keeps one successful unbuffered read handle')
    else assert(guard.resourceFile==nil,'Older DLL retains ordinary reopen behavior')end
    if i>10 then times[#times+1]=elapsed end
end
guard:close();assert(guard.resourceFile==nil)
if retained then assert(io.type(retained)=='closed file','Guard closes the actual owned CRT handle')end
local sum=0;for _,v in ipairs(times)do sum=sum+v end;table.sort(times)
local result=string.format([=[{
  "offline_only": true,
  "gameplay_verified": false,
  "game_object_array_available": false,
  "test": "Current resource_guard.lua update(now step0.101, active=true); actual DLL + real Lua CRT IO",
  "clock": "Lua os.clock; aggregate 500 samples, millisecond CRT clock resolution",
  "iterations": %d,
  "persistent_reader": %s,
  "strictly_sequential_samples": true,
  "mean_ms": %.9f,
  "median_ms": %.9f,
  "p95_ms": %.9f,
  "max_ms": %.9f
}
]=],iterations,tostring(expectedPersistent),sum/#times,times[math.floor(#times/2)],times[math.floor(#times*.95)],times[#times])
local output=assert(io.open(root..'resource-guard-fullstack-benchmark.json','w'));assert(output:write(result));assert(output:close())
print('PASS actual resource_guard.lua + DLL + CRT: '..iterations..' measured strictly sequential packets, matching capability, bounded reader ownership and close')
print(result)
