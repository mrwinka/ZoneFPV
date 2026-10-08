-- Explicit game-thread asset loading. Registry misses are distinct from errors;
-- cooked assets absent from the registry can use the engine's soft-load path.
local M={}
local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v==true end
function M.new()
    local client={cache={}}
    function client:load(path)
        local cached=self.cache[path]
        if valid(cached) then return cached end
        local ok,o=pcall(StaticFindObject,path)
        if ok and valid(o)then self.cache[path]=o;return o end
        local why={}
        local loaded,asset,found,didLoad=pcall(LoadAsset,path)
        if loaded and valid(asset)then self.cache[path]=asset;return asset end
        why[#why+1]=loaded and ('registry found='..tostring(found)..' loaded='..tostring(didLoad)) or tostring(asset)
        -- A wrong-thread error must not be followed by another engine loader.
        if not loaded and tostring(asset):lower():find('game thread',1,true)then return nil,table.concat(why,'; ')end
        local libraryOK,library=pcall(StaticFindObject,'/Script/Engine.Default__KismetSystemLibrary')
        if libraryOK and valid(library)then
            local blocked,result=pcall(function()
                local softPath=library:MakeSoftObjectPath(path)
                local softRef=library:Conv_SoftObjPathToSoftObjRef(softPath)
                return library:LoadAsset_Blocking(softRef)
            end)
            if blocked and valid(result)then self.cache[path]=result;return result end
            why[#why+1]=blocked and 'blocking loader returned no object' or tostring(result)
        else why[#why+1]='KismetSystemLibrary unavailable'end
        return nil,table.concat(why,'; ')
    end
    return client
end
return M
