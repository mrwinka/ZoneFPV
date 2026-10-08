-- One visible spotlight component owned by the flight camera. Cooked S.T.A.L.K.E.R.
-- does not expose the unused Engine.SpotLight actor class on every build; its
-- native character flashlight already loads Engine.SpotLightComponent.
local M={}
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function read(object,name)
    local ok,value=pcall(function()return object[name]end)
    if ok then return value end
end
local function valid(object)return call(object,'IsValid')==true end
local function spotlightClass(class)
    for _=1,16 do
        if not valid(class)then return end
        if call(class,'IsAnyClass')==true and call(call(class,'GetFName'),'ToString')=='SpotLightComponent' then
            local full=call(class,'GetFullName')
            if type(full)=='string' and full:match('/Script/Engine[%.:]SpotLightComponent$')then return class end
        end
        class=call(class,'GetSuperStruct')
    end
end
local cachedClass
local function resolveClass()
    if valid(cachedClass)then return cachedClass end
    if type(StaticFindObject)=='function'then
        for _,path in ipairs({'/Script/Engine.SpotLightComponent','/Script/Engine:SpotLightComponent'})do
            local ok,object=pcall(StaticFindObject,path)
            local class=ok and spotlightClass(object)
            if class then cachedClass=class;return class end
        end
    end
    -- Fixed, one-time class discovery when the native object path resolver
    -- misses. Never copy or move another actor's actual light component.
    if type(FindFirstOf)=='function'then
        local ok,instance=pcall(FindFirstOf,'SpotLightComponent')
        -- FindFirstOf may return a null UObject wrapper, not Lua nil. Its
        -- GetClass method can dereference native address 0x10 before pcall.
        local class=ok and valid(instance) and spotlightClass(call(instance,'GetClass'))
        if class then cachedClass=class;return class end
    end
end
function M.restore(s)
    if not s then return end
    local component=s.flashlight
    s.flashlight=nil;s.flashlightEnabled=false
    if valid(component)then
        pcall(function()component:SetVisibility(false,false)end)
        pcall(function()component:K2_DestroyComponent(s.camera)end)
    end
    local hidden=s.flashlightOwnerHidden;s.flashlightOwnerHidden=nil
    if hidden and valid(hidden.owner) and read(hidden.owner,'bHidden')==false then
        pcall(function()hidden.owner:SetActorHiddenInGame(hidden.value)end)
    end
end
function M.set(s,enabled,gameplay,log)
    if not s or not valid(s.camera) or not valid(s.world)then return false,'fpv_required' end
    if not enabled then M.restore(s);return true end
    if s.flashlightEnabled and valid(s.flashlight)then return true end
    M.restore(s)
    local ok,err=pcall(function()
        local class=assert(resolveClass(),'flashlight spotlight component class unavailable')
        local parent=s.camera.CameraComponent
        assert(valid(parent),'flashlight camera component unavailable')
        local relative={Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
        -- Complete the engine's deferred component registration after mobility
        -- and photometric properties are configured. The camera owns it across
        -- GC and attachment follows camera pitch/yaw/roll without frame updates.
        local light=s.camera:AddComponentByClass(class,true,relative,true)
        assert(valid(light),'flashlight component creation failed');s.flashlight=light
        light:SetMobility(2)
        light:SetIntensity(5000)
        light:SetAttenuationRadius(3500)
        light:SetInnerConeAngle(22)
        light:SetOuterConeAngle(48)
        light:SetCastShadows(true)
        light:SetVisibility(true,false)
        light:SetHiddenInGame(false,false)
        assert(light:K2_AttachToComponent(parent,FName('None'),0,0,0,false)==true,'flashlight attach failed')
        s.camera:FinishAddComponent(light,true,relative)
        if read(s.camera,'bHidden')==true then
            s.flashlightOwnerHidden={owner=s.camera,value=true}
            s.camera:SetActorHiddenInGame(false)
        end
        s.flashlightEnabled=true
        if log then log('Drone flashlight: on; camera-owned spotlight component registered')end
    end)
    if not ok then
        M.restore(s)
        if log then log('Drone flashlight unavailable: '..tostring(err))end
        return false,'flashlight_unavailable'
    end
    return true
end
function M.toggle(s,gameplay,log)return M.set(s,not (s and s.flashlightEnabled),gameplay,log)end
return M
