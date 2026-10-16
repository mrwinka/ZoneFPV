-- Actual compiled DLL + the same io.open reader as resource_guard.lua.
-- Run against an isolated DLL copy; never the installed live game directory.
local root=assert(arg[1],'isolated DLL directory required'):gsub('[/\\]$','')..'/'
local parser=dofile('mod/Scripts/resource_guard.lua')
local poll=assert(package.loadlib(root..'ZoneFPVNative.dll','zonefpv_resources_poll'))
local capability=assert(package.loadlib(root..'ZoneFPVNative.dll','zonefpv_resources_persistent_io'))
assert(capability()==nil,'capability marker has no side effects or Lua return values')
local path=root..'native-resources-status.txt'
local function read(name)
    local file=assert(io.open(name,'rb'));local packet=file:read(161);file:close();return packet
end
local function replace(name,text)
    local file=assert(io.open(name,'wb'));assert(file:write(text));assert(file:close())
end
local previous=0
for i=1,510 do
    poll()
    local sample=assert(parser.parse(read(path)),'native packet must parse after every synchronous poll')
    assert(sample.seq==previous+1 and not sample.known,'sequence increments and unsupported host does not read the game object array')
    previous=sample.seq
    if i==60 then
        assert(os.remove(path))
    elseif i==120 then
        local old=path..'.old';assert(os.rename(path,old));replace(path,'stale replacement')
        local original=read(old);poll();previous=previous+1
        assert(parser.parse(read(path)).seq==previous and read(old)==original,'publisher recovers the path instead of writing the renamed file')
        assert(os.remove(old))
    elseif i==180 then
        local swap=path..'.swap';replace(swap,'replacement');assert(os.remove(path));assert(os.rename(swap,path))
    end
end
local retained=assert(io.open(path,'rb'));assert(retained:setvbuf('no'))
for i=1,600 do
    poll();assert(retained:seek('set',0)==0)
    local sample=assert(parser.parse(retained:read(161)))
    assert(sample.seq==previous+1 and not sample.known,'unbuffered persistent Lua reader must observe every new packet, including the 999 to 1000 length change')
    previous=sample.seq
end
assert(retained:close())
assert(not io.open(path..'.tmp','rb'),'resource polling no longer creates temporary files')
print('PASS actual native resource DLL + Lua io.open: 510 sequential packets, unsupported PE rejection, open-file deletion and rename/replacement recovery; capability marker + 600 persistent unbuffered seek/read samples, including sequence length change')
