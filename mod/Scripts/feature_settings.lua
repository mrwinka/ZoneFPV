-- Camera/light permissions are independent of the active state of either tool.
local M={}
function M.defaults()return {flashlightEnabled=true,cameraDownEnabled=true}end
function M.parse(text)
    if type(text)~='string'or #text>32 then return end
    local light,down=text:match('^1 ([01]) ([01])%s*$')
    if light then return {flashlightEnabled=light=='1',cameraDownEnabled=down=='1'}end
end
function M.serialize(value)
    if type(value)~='table'or type(value.flashlightEnabled)~='boolean'or type(value.cameraDownEnabled)~='boolean'then return end
    return string.format('1 %d %d\n',value.flashlightEnabled and 1 or 0,value.cameraDownEnabled and 1 or 0)
end
local fs={}
function fs.read(path)
    local file,err,code=io.open(path,'rb');if not file then return nil,code==2 and 'missing'or 'io_error',err end
    local text=file:read(33);local closed=file:close();if not closed then return nil,'io_error'end
    return text
end
function fs.write(path,text)
    local file=io.open(path,'wb');if not file then return false end
    local wrote=file:write(text);local closed=file:close();return not not(wrote and closed)
end
function fs.rename(a,b)return os.rename(a,b)end
function fs.remove(path)return os.remove(path)end
function M.load(root,ioAdapter)
    local adapter=ioAdapter or fs
    local value=M.parse(adapter.read(root..'drone-features.txt'))
    -- Missing preferences retain the existing working button behavior.
    return value or M.defaults()
end
function M.save(root,current,key,enabled,ioAdapter)
    if (key~='flashlightEnabled'and key~='cameraDownEnabled')or type(enabled)~='boolean'then return false,nil,'invalid_value'end
    local adapter=ioAdapter or fs
    local path,temp,backup=root..'drone-features.txt',root..'drone-features.tmp',root..'drone-features.rollback'
    local before,kind=adapter.read(path)
    if before==nil and kind~='missing'then return false,nil,'read_failed'end
    local nextValue
    if before~=nil then nextValue=M.parse(before)
    else nextValue=M.parse(M.serialize(current))end
    if not nextValue then return false,nil,'invalid_file'end
    if nextValue[key]==enabled then return true,nextValue,'unchanged'end
    nextValue[key]=enabled;local text=M.serialize(nextValue)
    if not adapter.write(temp,text)or adapter.read(temp)~=text then adapter.remove(temp);return false,nil,'write_failed'end
    local latest,latestKind=adapter.read(path)
    if latest~=before or latest==nil and latestKind~='missing'then adapter.remove(temp);return false,nil,'conflict'end
    if adapter.read(backup)~=nil and not adapter.remove(backup)then adapter.remove(temp);return false,nil,'backup_failed'end
    if before~=nil and not adapter.rename(path,backup)then adapter.remove(temp);return false,nil,'backup_failed'end
    if not adapter.rename(temp,path)then
        local restored=before==nil or adapter.rename(backup,path)
        adapter.remove(temp);return false,nil,restored and 'commit_failed'or 'rollback_failed'
    end
    if adapter.read(path)~=text then
        local removed=adapter.remove(path)
        local restored=removed and (before==nil or adapter.rename(backup,path))
        return false,nil,restored and 'verify_failed'or 'rollback_failed'
    end
    if before~=nil then adapter.remove(backup)end
    return true,nextValue,'saved'
end
return M
