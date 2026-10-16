-- Actual DLL export followed by resource_guard's exact Lua CRT read pattern.
local root=assert(arg[1],'isolated DLL directory required'):gsub('[/\\]$','')..'/'
local iterations=tonumber(arg[2])or 500
local persistent=arg[3]=='persistent'
local poll=assert(package.loadlib(root..'ZoneFPVNative.dll','zonefpv_resources_poll'))
if persistent then assert(package.loadlib(root..'ZoneFPVNative.dll','zonefpv_resources_persistent_io'))end
local parser=dofile('mod/Scripts/resource_guard.lua')
local totals,native,reader={},{},{}
local previous=0
local retained
for index=1,iterations+10 do
    local start=os.clock()
    poll()
    local published=os.clock()
    local file
    if persistent then
        if not retained then
            retained=assert(io.open(root..'native-resources-status.txt','rb'));assert(retained:setvbuf('no'))
        end
        file=retained;assert(file:seek('set',0)==0)
    else file=assert(io.open(root..'native-resources-status.txt','r'))end
    local packet=file:read(161)
    if not persistent then assert(file:close())end
    local complete=os.clock()
    local sample=assert(parser.parse(packet))
    assert(sample.seq==previous+1 and not sample.known);previous=sample.seq
    if index>10 then
        totals[#totals+1]=(complete-start)*1000
        native[#native+1]=(published-start)*1000
        reader[#reader+1]=(complete-published)*1000
    end
end
if retained then assert(retained:close())end
local function mean(values)local sum=0;for _,v in ipairs(values)do sum=sum+v end;return sum/#values end
local totalMean,nativeMean,readerMean=mean(totals),mean(native),mean(reader)
table.sort(totals)
local result=string.format([=[{
  "offline_only": true,
  "gameplay_verified": false,
  "game_object_array_available": false,
  "reader": "%s",
  "persistent_reader": %s,
  "clock": "Lua os.clock; aggregate 500 samples, millisecond CRT clock resolution",
  "iterations": %d,
  "mean_ms": %.9f,
  "median_ms": %.9f,
  "p95_ms": %.9f,
  "max_ms": %.9f,
  "native_poll_mean_ms": %.9f,
  "subsequent_reader_mean_ms": %.9f
}
]=],persistent and 'Actual Lua io.open(rb) once; setvbuf(no), seek(set,0), read(161)'or 'Actual Lua io.open/read(161)/close as resource_guard.lua',
    tostring(persistent),iterations,totalMean,totals[math.floor(#totals/2)],totals[math.floor(#totals*.95)],totals[#totals],nativeMean,readerMean)
local output=assert(io.open(root..(persistent and 'resource-poll-lua-persistent-benchmark.json'or 'resource-poll-lua-benchmark.json'),'w'));assert(output:write(result));assert(output:close())
print(result)
