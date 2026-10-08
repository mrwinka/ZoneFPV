local M=dofile('mod/Scripts/feature_settings.lua')
local function fixture(text)
    local path='fixture/drone-features.txt';local files={[path]=text};local writes=0;local failRename=false
    local fs={read=function(p)return files[p],files[p]==nil and 'missing'or nil end,
        write=function(p,t)writes=writes+1;files[p]=t;return true end,
        rename=function(a,b)if failRename and a:match('%.tmp$')then return false end
            if files[a]==nil or files[b]~=nil then return false end;files[b],files[a]=files[a],nil;return true end,
        remove=function(p)files[p]=nil;return true end}
    return fs,files,path,function()return writes end,function(v)failRename=v end
end
assert(M.defaults().flashlightEnabled and M.defaults().cameraDownEnabled)
assert(M.parse('1 0 1\n').cameraDownEnabled and not M.parse('1 0 1\n').flashlightEnabled)
for _,text in ipairs({'','2 1 1','1 2 1','1 1 0 trailing','1 1','1 1 1 '..string.rep(' ',40)})do assert(not M.parse(text))end
assert(not M.parse(nil)and not M.serialize({flashlightEnabled=1,cameraDownEnabled=true}))
do
    local fs,files,path,writes,fail=fixture(nil);local settings=M.load('fixture/',fs)
    assert(settings.flashlightEnabled and settings.cameraDownEnabled and writes()==0,'Missing permissions preserve button behavior without creating preferences')
    local ok,nextValue=M.save('fixture/',settings,'flashlightEnabled',false,fs)
    assert(ok and not nextValue.flashlightEnabled and nextValue.cameraDownEnabled)
    assert(files[path]=='1 0 1\n'and writes()==1)
    local same=M.save('fixture/',nextValue,'flashlightEnabled',false,fs);assert(same and writes()==1,'No-op has no rewrite')
    files[path]='1 1 0\n';ok,nextValue=M.save('fixture/',nextValue,'flashlightEnabled',false,fs)
    assert(ok and files[path]=='1 0 0\n','Latest saved sibling wins over an older in-memory checkbox state')
    fail(true);local before=files[path];ok=M.save('fixture/',nextValue,'cameraDownEnabled',true,fs)
    assert(not ok and files[path]==before,'Failed Windows replacement restores original permissions')
    assert(not files['fixture/drone-features.tmp']and not files['fixture/drone-features.rollback'])
    fail(false);files[path]='partial';ok=M.save('fixture/',nextValue,'cameraDownEnabled',true,fs)
    assert(not ok and files[path]=='partial','Invalid external preferences are not silently overwritten')
end
do
    local fs,files,path=fixture('1 1 1\n');local originalWrite=fs.write
    fs.write=function(p,t)local result=originalWrite(p,t);files[path]='1 1 0\n';return result end
    local ok,_,reason=M.save('fixture/',M.defaults(),'flashlightEnabled',false,fs)
    assert(not ok and reason=='conflict'and files[path]=='1 1 0\n','A concurrent complete preference change is retained')
    assert(not M.save('fixture/',M.defaults(),'other',true,fs))
    assert(not M.save('fixture/',M.defaults(),'cameraDownEnabled',1,fs))
end
do
    local root='build/v50-features-test-'..os.time()..'-'..math.random(100000,999999)..'-'
    local path=root..'drone-features.txt'
    assert(not io.open(path,'rb'),'Real-I/O fixture must start empty')
    local ok,why=pcall(function()
        local initial=M.load(root)
        assert(initial.flashlightEnabled and initial.cameraDownEnabled and not io.open(path,'rb'))
        local saved,nextValue=M.save(root,initial,'flashlightEnabled',false)
        assert(saved and not nextValue.flashlightEnabled and nextValue.cameraDownEnabled)
        local loaded=M.load(root);assert(not loaded.flashlightEnabled and loaded.cameraDownEnabled)
        saved,nextValue=M.save(root,loaded,'cameraDownEnabled',false)
        assert(saved and not nextValue.flashlightEnabled and not nextValue.cameraDownEnabled,
            'Actual Windows rename replacement preserves the other permission')
        saved,nextValue=M.save(root,initial,'flashlightEnabled',true)
        assert(saved and nextValue.flashlightEnabled and not nextValue.cameraDownEnabled,'Actual disk sibling wins over stale memory')
        local file=assert(io.open(path,'wb'));assert(file:write('partial')and file:close())
        local reason;saved,nextValue,reason=M.save(root,initial,'cameraDownEnabled',false)
        assert(not saved and reason=='invalid_file')
        file=assert(io.open(path,'rb'));assert(file:read('*a')=='partial');file:close()
        assert(not io.open(root..'drone-features.tmp','rb')and not io.open(root..'drone-features.rollback','rb'))
    end)
    os.remove(path);os.remove(root..'drone-features.tmp');os.remove(root..'drone-features.rollback')
    assert(ok,why)
end
print('PASS feature_settings persistent permissions/default compatibility/latest siblings/Windows rollback/read-only startup/actual disk replacement')
