local M=dofile('mod/Scripts/asset_loader.lua')
local function object()return {IsValid=function()return true end}end
local asset,library=object(),object()
local registryCalls,blockingCalls=0,0
StaticFindObject=function(path)if path:find('KismetSystemLibrary',1,true)then return library end end
LoadAsset=function()registryCalls=registryCalls+1;return nil,false,false end
function library:MakeSoftObjectPath(path)assert(path=='/Game/Test.Test');return {path=path}end
function library:Conv_SoftObjPathToSoftObjRef(path)return {soft=path}end
function library:LoadAsset_Blocking(ref)
    assert(ref.soft.path=='/Game/Test.Test');blockingCalls=blockingCalls+1;return asset
end
local client=M.new()
assert(client:load('/Game/Test.Test')==asset and blockingCalls==1)
assert(client:load('/Game/Test.Test')==asset and blockingCalls==1 and registryCalls==1)
LoadAsset=function()return asset,true,true end
assert(M.new():load('/Game/Test.Test')==asset and blockingCalls==1)
LoadAsset=function()error('Function LoadAsset can only be called from within the game thread')end
local result,why=M.new():load('/Game/Test.Test')
assert(not result and why:find('game thread',1,true) and blockingCalls==1)
LoadAsset=function()return nil,false,false end
function library:LoadAsset_Blocking()error('package unavailable')end
result,why=M.new():load('/Game/Test.Test');assert(not result and why:find('registry found=false') and why:find('package unavailable'))
print('PASS cached native asset load, cooked registry-miss fallback, wrong-thread rejection and exact diagnostics')
