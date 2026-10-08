-- Suppress player camera feedback during FPV. Keep world weather/materials,
-- particles under their original game ownership. Character recovery removes
-- only verified concussion/explosion feedback through normal effect callbacks.
local M={}
local recovery
local recoverySeconds=5
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
M.nativeBridge=here and dofile(here..'native_bridge.lua')
M.assetLoader=here and dofile(here..'asset_loader.lua')
local materialObserverRegistered=false
local liveMaterials
local materialLimit=32 -- same bounded scalar-entry limit as the native bridge
local function materialKey(id,index)return tostring(id)..':'..tostring(index)end
local function valid(o)
    local ok,value=pcall(function()return o and o:IsValid()end)
    return ok and value
end
local function field(o,key)
    local ok,value=pcall(function()return o[key]end)
    if ok then return value end
end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function()return a and b and a:GetAddress()==b:GetAddress()end)
    return ok and value
end
local function attempt(g,key,fn)
    if g.unsupported[key] then return end
    local ok,err=pcall(fn)
    if not ok then
        g.unsupported[key]=true
        print('[ZoneFPV] Visual guard unavailable: '..key..' / '..tostring(err)..'\n')
    end
    return ok
end
local function cvar(g,s,system,name,wanted)
    attempt(g,name,function()
        local original=g.cvars[name]
        if wanted==nil then
            if original~=nil then
                system:ExecuteConsoleCommand(s.pc,name..' '..tostring(original),s.pc)
                g.cvars[name]=nil
            end
            return
        end
        local current=system:GetConsoleVariableIntValue(name)
        assert(type(current)=='number' and current==current and math.abs(current)<math.huge,
            'console variable restoration value unavailable')
        if original==nil then g.cvars[name]=current end
        if current~=wanted then system:ExecuteConsoleCommand(s.pc,name..' '..wanted,s.pc) end
    end)
end
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
-- The cooked Radiation and Concussion masters import MPC_PostProcess. In
-- particular ConcussionIntensity is driven by ConcussionBlurEffectProcessor
-- and SuppressionWeakBlurEffectProcessor; it is not an MI_PP_Concussion scalar.
-- Holding only a same-named MID override cannot suppress that rendered blur.
local feedbackCollectionPath='/Game/_Stalker_2/Materials/MPC/MPC_PostProcess.MPC_PostProcess'
local collectionKeys={'RadiationNoiseIntensity','RadiationSepiaIntensity','RadiationRandom',
    'RadiationRandomPulsation','VignetteIntensity','ConcussionIntensity','SuppressionIntensity'}
local concussionCollectionKeys={'ConcussionIntensity','SuppressionIntensity'}
local function stopNativeConcussion(g)
    if g.nativeConcussion then pcall(g.nativeConcussion.concussionDisarm,g.nativeConcussion)end
    g.nativeConcussion=nil;g.nativeConcussionLease=nil;g.nativeConcussionNow=nil
end
local function holdNativeConcussion(g,lease,now)
    if not M.nativeBridge or g.nativeConcussionFailed then return end
    if g.nativeConcussionLease and g.nativeConcussionLease~=lease then stopNativeConcussion(g)end
    if not g.nativeConcussion then g.nativeConcussion=M.nativeBridge.new(here..'../')end
    local ok,result,err
    if not g.nativeConcussionLease then
        ok,result,err=pcall(function()
            local name,secondary
            for _,entry in ipairs(lease.entries)do
                if entry.label=='ConcussionIntensity'then name=entry.name end
                if entry.label=='SuppressionIntensity'then secondary=entry.name end
            end
            assert(name and secondary,'concussion/suppression collection names unavailable')
            -- This literal has no numbered suffix. No unverified FName Lua
            -- accessor is required to pass its number=0 native representation.
            return g.nativeConcussion:concussionArm(lease.context,lease.asset,name:GetComparisonIndex(),0,secondary:GetComparisonIndex(),0)
        end)
        if ok and result then
            g.nativeConcussionLease=lease
            print('[ZoneFPV] Native concussion collection gate armed for FPV world\n')
        end
    else
        ok,result,err=pcall(g.nativeConcussion.concussionTick,g.nativeConcussion,math.max(0,now-(g.nativeConcussionNow or now)))
        if ok and type(result)=='number'then
            g.nativeConcussionIntercepted=(g.nativeConcussionIntercepted or 0)+result
            if result>0 and not g.nativeConcussionReported then
                g.nativeConcussionReported=true
                print('[ZoneFPV] Native concussion late writes intercepted: '..result..'\n')
            end
        end
    end
    g.nativeConcussionNow=now
    -- arm returns true,status and a polled tick returns delta,status.
    -- That status table is successful data, not an error. Between polls tick
    -- returns nil,nil; only a nil result with an error indicates failure.
    if not ok or result==false or (result==nil and err~=nil) then
        g.nativeConcussionFailed=true;stopNativeConcussion(g)
        print('[ZoneFPV] Native concussion gate unavailable: '..tostring(ok and err or result)..'; Lua correction retained\n')
    end
end
local function holdCollection(g,s,now,concussionOnly)
    if FName==nil or type(StaticFindObject)~='function' then return end
    attempt(g,'player feedback collection',function()
        local lease=g.feedbackCollection
        if lease and (not valid(lease.asset) or not valid(lease.library))then
            stopNativeConcussion(g)
            g.feedbackCollection=nil;lease=nil
        end
        if not lease then
            if now<(g.nextCollectionLookup or 0)then return end
            g.nextCollectionLookup=now+1
            local asset=StaticFindObject(feedbackCollectionPath)
            if not valid(asset)then return end
            local library=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary')
            if not valid(library)then return end
            -- The UWorld is the context, so restoration cannot accidentally
            -- target a new world through a controller reused during loading.
            assert(valid(s.world),'feedback collection world unavailable')
            lease={asset=asset,library=library,context=s.world,entries={}}
            g.feedbackCollection=lease
            -- Snapshot all values before writing any, so a failed getter never
            -- leaves a partially captured collection lease.
            for _,key in ipairs(concussionOnly and concussionCollectionKeys or collectionKeys)do
                local name=FName(key)
                local value=library:GetScalarParameterValue(lease.context,asset,name)
                assert(finite(value),'collection restoration value unavailable: '..key)
                lease.entries[#lease.entries+1]={name=name,label=key,value=value}
            end
            local values={}
            for _,entry in ipairs(lease.entries)do values[#values+1]=entry.label..'='..entry.value end
            print('[ZoneFPV] Player collection snapshot: '..table.concat(values,', ')..'\n')
        end
        holdNativeConcussion(g,lease,now)
        for _,entry in ipairs(lease.entries)do
            local value=lease.library:GetScalarParameterValue(lease.context,lease.asset,entry.name)
            assert(finite(value),'collection read unavailable: '..entry.label)
            if value~=0 then
                lease.library:SetScalarParameterValue(lease.context,lease.asset,entry.name,0)
                assert(lease.library:GetScalarParameterValue(lease.context,lease.asset,entry.name)==0,
                    'collection zero readback failed: '..entry.label)
                if entry.label=='ConcussionIntensity'then
                    g.concussionCorrections=(g.concussionCorrections or 0)+1
                elseif entry.label=='SuppressionIntensity'then
                    g.suppressionCorrections=(g.suppressionCorrections or 0)+1
                end
                if not entry.reported then
                    entry.reported=true
                    print('[ZoneFPV] Player collection verified zero: '..entry.label..'; baseline='..entry.value..'\n')
                end
            end
        end
    end)
end
local function restoreCollection(g)
    local lease=g.feedbackCollection;g.feedbackCollection=nil
    if not lease or not valid(lease.context) or not valid(lease.asset) or not valid(lease.library)then return end
    for _,entry in ipairs(lease.entries)do pcall(function()
        lease.library:SetScalarParameterValue(lease.context,lease.asset,entry.name,entry.value)
    end)end
end
local function holdLens(g,s)
    local camera=field(s.camera,'CameraComponent')
    if not valid(camera)then return end
    attempt(g,'FPV vignette',function()
        local settings=camera.PostProcessSettings
        local value,override,weight=settings.VignetteIntensity,settings.bOverride_VignetteIntensity,camera.PostProcessBlendWeight
        if not finite(value)or type(override)~='boolean'or not finite(weight)then return end
        if not g.fpLens then g.fpLens={camera=camera,value=value,override=override,weight=weight}end
        settings.VignetteIntensity=0;settings.bOverride_VignetteIntensity=true
        -- The analog module disables its entire stack by setting weight to 0.
        -- Forcing it back to 1 resurrects the previous grain/fringe overrides
        -- even when the user selected Analog off. Override only the lens value.
        assert(settings.VignetteIntensity==0 and settings.bOverride_VignetteIntensity==true,'FPV vignette readback mismatch')
    end)
end
local function restoreLens(g)
    local lens=g.fpLens;if not lens or not valid(lens.camera)then return end
    pcall(function()
        local settings=lens.camera.PostProcessSettings
        settings.VignetteIntensity=lens.value;settings.bOverride_VignetteIntensity=lens.override
        lens.camera.PostProcessBlendWeight=lens.weight
    end)
    g.fpLens=nil
end
local function materialTarget(g,mid,index)
    local target=g.materialTargets and g.materialTargets[index]
    if not target or not valid(mid) then return end
    -- The only inspected field is the documented reflected Parent TObjectPtr.
    -- Resolve fixed assets from the decoded game configs, compare addresses;
    -- never stringify a native object or walk material/post-process arrays.
    local parent=field(mid,'Parent')
    if not valid(parent) then return end
    if target.assets then
        local available=false
        for _,asset in ipairs(target.assets)do if valid(asset)then available=true;break end end
        if not available then target.assets=nil;target.retryAt=0 end
    end
    if not target.assets then
        local now=os.clock()
        target.checkedParents=target.checkedParents or {}
        local parentID=parent:GetAddress()
        local fresh=not target.checkedParents[parentID]
        target.checkedParents[parentID]=true
        -- Unrelated, newly constructed MIDs must not trigger a global asset
        -- lookup. Match the fixed parent's FName first, without ToString.
        local getName=field(parent,'GetFName')
        if getName and target.parentNames then
            local ok,name=pcall(function()return parent:GetFName():GetComparisonIndex()end)
            if not ok or not target.parentNames[name] then return end
        end
        -- A newly loaded parent can be the effect that was absent at entry;
        -- retry immediately instead of dropping its only creation notification.
        if not fresh and target.retryAt and now<target.retryAt then return end
        target.retryAt=now+0.5
        local assets={}
        for _,path in ipairs(target.paths)do
            local asset=StaticFindObject(path)
            if valid(asset) then assets[#assets+1]=asset end
        end
        if #assets>0 then target.assets=assets end
    end
    for _,asset in ipairs(target.assets or {})do
        if valid(asset) and same(parent,asset) then return target end
    end
end
local function unwrap(value)
    local kind=field(value,'type')
    if kind then
        local ok,label=pcall(function()return value:type()end)
        if ok and (label=='RemoteUnrealParam' or label=='LocalUnrealParam')then return value:get()end
    end
    return value
end
local function blendableArray(owner)
    local settings=field(owner,'PostProcessSettings')
    local blendables=field(settings,'WeightedBlendables')
    local list=field(blendables,'Array')
    if not list then return end
    local count=list:GetArrayNum()
    if not finite(count)or count<0 or count%1~=0 or count>2112 then return end
    -- Vision may append up to 2048 weight-zero retention slots; these never
    -- render and are not part of the original camera postprocess stack.
    return list,math.min(count,64)
end
local function feedbackMaterial(g,object,index)
    local target=index and g.materialTargets and g.materialTargets[index]
    if not target then return false end
    g.feedbackAssetsChecked=g.feedbackAssetsChecked or {}
    if not target.assets and not g.feedbackAssetsChecked[index] then
        g.feedbackAssetsChecked[index]=true
        target.assets={}
        for _,path in ipairs(target.paths)do
            local asset=StaticFindObject(path)
            if valid(asset)then target.assets[#target.assets+1]=asset end
        end
    end
    for _=1,4 do
        if not valid(object)then return false end
        if materialTarget(g,object,index)then return true end
        for _,asset in ipairs(target.assets or {})do if same(object,asset)then return true end end
        object=field(object,'Parent')
    end
    return false
end
local function feedbackLabel(g,object)
    if feedbackMaterial(g,object,g.concussionIndex)then return 'Concussion',g.concussionIndex end
    if feedbackMaterial(g,object,g.suppressionIndex)then return 'Suppression',g.suppressionIndex end
    if feedbackMaterial(g,object,g.radiationIndex)then return 'Radiation',g.radiationIndex end
    for index,label in pairs(g.blastIndices or {})do
        if feedbackMaterial(g,object,index)then return label,index end
    end
end
local function captureOwnedMaterial(g,object,index)
    local target=index and materialTarget(g,object,index)
    if not target or target.feedbackOnly or g.collectionOnlyMaterials or not field(object,'K2_GetScalarParameterValue')then return end
    local id=object:GetAddress();local key=materialKey(id,index)
    if g.materials[key] or g.materialCount>=materialLimit then return end
    attempt(g,'owned material discovery '..key,function()
        local value=object:K2_GetScalarParameterValue(target.name)
        assert(finite(value),'owned material scalar unavailable')
        g.materials[key]={object=object,id=id,name=target.name,index=index,value=value,label=target.label}
        g.materialCount=g.materialCount+1;g.materialDiscoveries=(g.materialDiscoveries or 0)+1
    end)
end
local function nativePlayerCamera(g,s)
    -- UCameraManager (Stalker2/CameraManager.h) owns the game's actual camera
    -- component. It is not required to be exposed on the player Pawn; native
    -- player feedback can be attached to this stack instead of the FPV actor.
    -- Resolve once per flight, then revalidate its local-player link every use.
    if not g.playerCameraManagerLookup and valid(s.pawn) and type(FindAllOf)=='function' then
        g.playerCameraManagerLookup=true
        attempt(g,'native player camera discovery',function()
            local list=FindAllOf('CameraManager')
            if type(list)~='table'then return end
            for i=1,math.min(#list,8)do
                local manager=list[i]
                if valid(manager) and same(field(manager,'PlayerCameraManager'),g.camera) then
                    local component=field(manager,'CameraComponent')
                    if valid(component)then
                        g.playerCameraManager=manager
                        print('[ZoneFPV] Player feedback: native CameraManager component matched local camera owner\n')
                        break
                    end
                end
            end
        end)
    end
    local manager=g.playerCameraManager
    if valid(manager) and same(field(manager,'PlayerCameraManager'),g.camera)then
        local component=field(manager,'CameraComponent')
        if valid(component)then return component end
    end
end
local function holdRadiationBlendables(g,s)
    if not g.radiationIndex and not g.concussionIndex and not g.suppressionIndex and not next(g.blastIndices or {})then return end
    g.radiationBlendables=g.radiationBlendables or {}
    -- Only owned camera components, never world volume scans or
    -- clearing a whole blendable array (which would remove anomaly/weather FX).
    local components={fpv=field(s.camera,'CameraComponent'),player=field(s.pawn,'CameraComponent'),
        native=nativePlayerCamera(g,s)}
    for _,owner in pairs(components)do
        if valid(owner)then attempt(g,'player feedback blendables '..tostring(owner:GetAddress()),function()
            local list,count=blendableArray(owner)
            if not list then return end
            local leases=g.radiationBlendables[owner:GetAddress()]
            if not leases then leases={owner=owner,entries={}};g.radiationBlendables[owner:GetAddress()]=leases end
            for i=1,count do
                local row=unwrap(list[i]);local object=unwrap(field(row,'Object'));local weight=field(row,'Weight')
                local label,index
                if finite(weight)then label,index=feedbackLabel(g,object)end
                -- Identify owned passes even when already weight-zero. Actual
                -- concussion/suppression/blast amplitudes use the MPC, not unused
                -- same-named MID overrides. Never scan global MIDs in recovery.
                if label then
                    captureOwnedMaterial(g,object,index)
                end
                if label and weight~=0 then
                    local entry=leases.entries[i]
                    if not entry or not same(entry.object,object)then
                        leases.entries[i]={object=object,weight=weight,blast=g.blastIndices and g.blastIndices[index]~=nil}
                        if g.blastIndices and g.blastIndices[index]then g.blastPasses=(g.blastPasses or 0)+1 end
                        print('[ZoneFPV] '..label..' camera blendable bypass: slot='..i..'; weight='..weight..'\n')
                    end
                    row.Weight=0
                    assert(row.Weight==0,'player feedback blendable zero readback failed')
                end
            end
        end)end
    end
end
local function restoreRadiationBlendables(g,retireOldBlast)
    for _,leases in pairs(g.radiationBlendables or {})do pcall(function()
        if not valid(leases.owner)then return end
        local list,count=blendableArray(leases.owner);if not list then return end
        for i,entry in pairs(leases.entries)do
            if i<=count then
                local row=unwrap(list[i])
                -- Never restore into a replacement/foreign row. If a camera
                -- rebuilds its stack, the rebuilt stack remains its own state.
                if same(unwrap(field(row,'Object')),entry.object)and row.Weight==0 then
                    -- The old explosion pass can retain its ordinary lerp-out
                    -- after source removal. At the fixed recovery deadline do
                    -- not replay its captured positive event weight. Release
                    -- ownership immediately so a genuine later game write or
                    -- newly added pass can render normally.
                    if not(retireOldBlast and entry.blast)then row.Weight=entry.weight end
                end
            end
        end
    end)end
    g.radiationBlendables=nil
end
local function observeMaterial(g,context,parameter,value)
    if g.internalMaterialWrite then return end
    local name=parameter:get()
    local index=name:GetComparisonIndex() -- numeric comparison, no ToString
    if not (g.materialTargets and g.materialTargets[index]) then return end
    local mid=context:get()
    local target=materialTarget(g,mid,index)
    if not target or target.feedbackOnly then return end
    local id=mid:GetAddress()
    local key=materialKey(id,index)
    local entry=g.materials[key]
    if not entry then
        if g.materialCount>=materialLimit then return end
        local original=mid:K2_GetScalarParameterValue(target.name)
        assert(finite(original),'player material scalar restoration value unavailable')
        entry={object=mid,id=id,name=target.name,index=index,value=original}
        g.materials[key]=entry;g.materialCount=g.materialCount+1
        print('[ZoneFPV] Visual guard: observed '..target.label..'; scalar held at zero; entries='..tostring(g.materialCount)..'\n')
    end
    value:set(0)
    g.materialEvents=(g.materialEvents or 0)+1
end
local function discoverMaterials(g)
    liveMaterials=g
    if not g.materialTargets then return end
    if not materialObserverRegistered and type(NotifyOnNewObject)=='function' then
        materialObserverRegistered=pcall(NotifyOnNewObject,'/Script/Engine.MaterialInstanceDynamic',function(mid)
            local live=liveMaterials
            if live and live.active and live.materialQueue and #live.materialQueue<8192 then
                -- Construction can precede initialized properties. Defer all
                -- engine reads to the existing game-thread update.
                live.materialQueue[#live.materialQueue+1]={object=mid,tries=0}
            end
        end)
    end
    if not g.materialQueue then
        g.materialQueue={}
        if type(FindAllOf)=='function' then
            local ok,list=pcall(FindAllOf,'MaterialInstanceDynamic')
            if ok and type(list)=='table' then
                for i=1,math.min(#list,8192)do g.materialQueue[#g.materialQueue+1]={object=list[i],tries=0}end
            end
        end
    end
    local deferred={}
    for _=1,16 do
        local queued=table.remove(g.materialQueue)
        if not queued then break end
        local mid=queued.object
        if valid(mid) and g.materialCount<materialLimit then
            if not valid(field(mid,'Parent')) then
                -- A construction notification can precede Parent initialization
                -- by more than one update. Retry at most eight frames; never
                -- examine the same queued object twice in a single update.
                queued.tries=queued.tries+1
                if queued.tries<8 then deferred[#deferred+1]=queued end
            else for index in pairs(g.materialTargets)do
                local target=materialTarget(g,mid,index)
                local key=materialKey(mid:GetAddress(),index)
                if target and not target.feedbackOnly and not g.materials[key] and g.materialCount<materialLimit then
                    attempt(g,'material discovery '..tostring(mid:GetAddress()),function()
                        local value=mid:K2_GetScalarParameterValue(target.name)
                        assert(finite(value),'material snapshot unavailable')
                        local id=mid:GetAddress()
                        g.materials[key]={object=mid,id=id,name=target.name,index=index,value=value,label=target.label}
                        g.materialCount=g.materialCount+1
                        g.materialDiscoveries=(g.materialDiscoveries or 0)+1
                    end)
                end
            end end
        end
    end
    for _,queued in ipairs(deferred)do g.materialQueue[#g.materialQueue+1]=queued end
end
local function updateMaterials(g)
    for id,entry in pairs(g.materials)do
        if not valid(entry.object) or not materialTarget(g,entry.object,entry.index) then
            g.materials[id]=nil;g.materialCount=g.materialCount-1
        else
            attempt(g,'player material '..tostring(id),function()
                local value=entry.object:K2_GetScalarParameterValue(entry.name)
                assert(finite(value),'player material scalar unavailable')
                if value~=0 then
                    g.internalMaterialWrite=true
                    local ok,err=pcall(function()entry.object:SetScalarParameterValue(entry.name,0)end)
                    g.internalMaterialWrite=false
                    assert(ok,err)
                    assert(entry.object:K2_GetScalarParameterValue(entry.name)==0,'player material zero readback failed')
                    entry.corrections=(entry.corrections or 0)+1
                    if not entry.zeroReported then
                        entry.zeroReported=true
                        print('[ZoneFPV] Player material verified zero: '..tostring(entry.label or entry.index)..'; baseline='..tostring(entry.value)..'\n')
                    end
                end
            end)
        end
    end
end
local function restoreMaterials(g)
    for id,entry in pairs(g.materials)do
        pcall(function()
            if valid(entry.object) and materialTarget(g,entry.object,entry.index) then
                entry.object:SetScalarParameterValue(entry.name,entry.value)
            end
        end)
        g.materials[id]=nil
    end
    g.materialCount=0
end
local function restoreModifier(g,entry)
    g.restoring=true
    pcall(function()
        if valid(entry.object) and entry.object:GetAddress()==entry.id then
            if entry.disabled then entry.object:DisableModifier(true)
            else entry.object:EnableModifier() end
            if entry.alpha~=nil then entry.object.Alpha=entry.alpha end
        end
    end)
    g.restoring=false
end
local function restoreCamera(g)
    -- Clear dispatch identity before enabling the old manager's modifiers.
    local camera=g.camera;g.cameraAddress=nil
    for id,entry in pairs(g.modifiers)do restoreModifier(g,entry);g.modifiers[id]=nil end
    pcall(function()
        if valid(camera) and g.colorEnabled~=nil then camera.bEnableColorScaling=g.colorEnabled end
    end)
    g.colorEnabled=nil;g.camera=nil
end
local function remember(g,modifier)
    if not valid(modifier) then return end
    local id=modifier:GetAddress()
    local entry=g.modifiers[id]
    if not entry or not same(entry.object,modifier) then
        local disabled=modifier:IsDisabled()
        assert(type(disabled)=='boolean','camera modifier state unavailable')
        local alpha=field(modifier,'Alpha')
        if type(alpha)~='number' or alpha~=alpha or math.abs(alpha)==math.huge then alpha=nil end
        entry={object=modifier,id=id,disabled=disabled,alpha=alpha};g.modifiers[id]=entry
    end
    return entry
end
local function ownedCamera(g,context)
    if not g.active or g.restoring or not g.cameraAddress then return false end
    local owner=context:get()
    return valid(owner) and owner:GetAddress()==g.cameraAddress
end
local function ownedModifier(g,context)
    if not g.active or g.restoring or not g.cameraAddress then return end
    local modifier=context:get()
    if not valid(modifier) then return end
    local camera=field(modifier,'CameraOwner') -- reflected TObjectPtr in UE 5.5
    if valid(camera) and camera:GetAddress()==g.cameraAddress then return modifier end
end
local function installHook(g,key,path,pre,post)
    -- Native registration tables also contain functions that have no live
    -- UFunction yet. Check once at entry. Repeating an absent UObject lookup
    -- each second walks the global object pool and stalls the game thread.
    if type(StaticFindObject)=='function' then
        local ok,fn=pcall(StaticFindObject,path)
        if ok and not valid(fn) then
            g.pendingHooks[key]={path=path,pre=pre,post=post}
            return false
        end
    end
    local installed=attempt(g,key,function()
        local a,b=RegisterHook(path,pre,post)
        assert(type(a)=='number' and type(b)=='number','camera hook IDs unavailable')
        g.hooks[#g.hooks+1]={path=path,pre=a,post=b}
    end)
    g.pendingHooks[key]=nil
    return installed
end
local function setupHooks(g)
    g.hooks={};g.pendingHooks={};g.active=true
    if type(RegisterHook)~='function' or type(UnregisterHook)~='function' then return end
    local function listen(key,path,pre,post)
        return installHook(g,key,path,pre,post)
    end
    local function safely(key,fn)
        return function(...)
            if not g.active or g.restoring then return end
            local args={...}
            attempt(g,key,function()fn(table.unpack(args))end)
        end
    end
    -- Fixed native engine signatures from the UE 5.5 API. Reflected pre-hooks
    -- suppress new requests before they can produce a rendered blink/shake.
    listen('fade hook','/Script/Engine.PlayerCameraManager:StartCameraFade',safely('fade callback',
        function(context,from,to,duration,color,audio,hold)
            if not ownedCamera(g,context) then return end
            from:set(0);to:set(0);duration:set(0);audio:set(false);hold:set(false)
            g.fadeEvents=(g.fadeEvents or 0)+1
        end))
    listen('manual fade hook','/Script/Engine.PlayerCameraManager:SetManualCameraFade',safely('manual fade callback',
        function(context,amount,color,audio)
            if not ownedCamera(g,context) then return end
            amount:set(0);audio:set(false);g.fadeEvents=(g.fadeEvents or 0)+1
        end))
    listen('shake hook','/Script/Engine.PlayerCameraManager:StartCameraShake',safely('shake callback',
        function(context,shakeClass,scale,playSpace,rotation)
            if not ownedCamera(g,context) then return end
            scale:set(0);g.shakeEvents=(g.shakeEvents or 0)+1
        end))
    listen('modifier enable hook','/Script/Engine.CameraModifier:EnableModifier',safely('modifier enable pre',
        function(context)
            local modifier=ownedModifier(g,context)
            if modifier then remember(g,modifier) end
        end),safely('modifier enable post',function(context)
            local modifier=ownedModifier(g,context)
            if modifier then modifier:DisableModifier(true) end
        end))
    -- UE4SS exposes constructors as callable tables on some releases.
    if FName~=nil and type(StaticFindObject)=='function' then
        attempt(g,'player material keys',function()
            g.materialTargets={}
            -- PostProcessParamPrototypes + PostProcessMaterialPrototypes confirm
            -- these exact scalar names and parents; no inferred shader keys.
            for _,spec in ipairs({
                {name='ConcussionIntensity',parents={'MI_PP_Concussion'},paths={'/Game/_Stalker_2/Materials/PostProcess/Concussion/MI_PP_Concussion.MI_PP_Concussion'}},
                -- Config identifies this pass; its cooked master imports the
                -- MPC, so use this spec only to identify an owned blendable.
                -- Do not create an unused same-named MID scalar override.
                {name='SuppressionIntensity',feedbackOnly=true,parents={'PPI_Suppression','PPI_Suppression_HDR'},paths={
                    '/Game/_Stalker_2/Materials/PostProcess/Suppression/PPI_Suppression.PPI_Suppression',
                    '/Game/_Stalker_2/Materials/PostProcess/Suppression/PPI_Suppression_HDR.PPI_Suppression_HDR'}},
                {name='BlinkAlpha',parents={'MI_PP_Blinking','MI_PP_Blinking_HDR'},paths={'/Game/_Stalker_2/Materials/PostProcess/PoppyField/MI_PP_Blinking.MI_PP_Blinking',
                    '/Game/_Stalker_2/Materials/PostProcess/PoppyField/MI_PP_Blinking_HDR.MI_PP_Blinking_HDR'}},
                {name='VignetteIntensity',parents={'MI_PP_VignetteBlur_01'},paths={
                    '/Game/_Stalker_2/Materials/PostProcess/VignetteBlur/MI_PP_VignetteBlur_01.MI_PP_VignetteBlur_01'}},
                -- Actual scalar overrides in the cooked Radiation master/HDR
                -- instance. The MPC values alone can be rewritten after our
                -- frame tick; hold the noise-producing shader inputs as well.
                -- These names are NOT the unused Radiation* MID overrides.
                {name='Noise intensity',parents={'MI_PPM_PostProcess_Radiation_Inst','MI_PPM_PostProcess_Radiation_Inst_HDR'},paths={
                    '/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst.MI_PPM_PostProcess_Radiation_Inst',
                    '/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst_HDR.MI_PPM_PostProcess_Radiation_Inst_HDR'}},
                {name='grain power',parents={'MI_PPM_PostProcess_Radiation_Inst','MI_PPM_PostProcess_Radiation_Inst_HDR'},paths={
                    '/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst.MI_PPM_PostProcess_Radiation_Inst',
                    '/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst_HDR.MI_PPM_PostProcess_Radiation_Inst_HDR'}},
                {name='Noise edges power',parents={'MI_PPM_PostProcess_Radiation_Inst','MI_PPM_PostProcess_Radiation_Inst_HDR'},paths={
                    '/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst.MI_PPM_PostProcess_Radiation_Inst',
                    '/Game/_Stalker_2/Materials/PostProcess/Radiation/MI_PPM_PostProcess_Radiation_Inst_HDR.MI_PPM_PostProcess_Radiation_Inst_HDR'}},
            })do
                local name=FName(spec.name)
                local parentNames={}
                for _,parent in ipairs(spec.parents)do
                    local ok,value=pcall(function()return FName(parent):GetComparisonIndex()end)
                    if ok then parentNames[value]=true end
                end
                g.materialTargets[name:GetComparisonIndex()]={name=name,label=spec.name,paths=spec.paths,
                    parentNames=next(parentNames) and parentNames or nil,feedbackOnly=spec.feedbackOnly}
                if spec.name=='Noise intensity'then g.radiationIndex=name:GetComparisonIndex()end
                if spec.name=='ConcussionIntensity'then g.concussionIndex=name:GetComparisonIndex()end
                if spec.name=='SuppressionIntensity'then g.suppressionIndex=name:GetComparisonIndex()end
            end
        end)
        if g.materialTargets then
            g.materialFeedbackReady=listen('player material hook','/Script/Engine.MaterialInstanceDynamic:SetScalarParameterValue',
                safely('player material callback',function(...)observeMaterial(g,...)end))
        end
    end
end
local function updateNativeVisual(g,now)
    if not M.nativeBridge or g.nativeVisualFailed then return end
    local targets,keys={},{}
    for id,entry in pairs(g.materials)do
        if valid(entry.object) then
            targets[#targets+1]={mid=entry.object,index=entry.index,number=0}
            keys[#keys+1]=tostring(id)..':'..tostring(entry.index)
        end
    end
    table.sort(keys)
    local signature=table.concat(keys,'|')
    if #targets==0 then
        if g.nativeVisual and g.nativeVisualSignature then pcall(g.nativeVisual.visualDisarm,g.nativeVisual)end
        g.nativeVisualSignature=nil;g.nativeVisualNow=now
        return -- Empty initial discovery is not an unsupported native bridge.
    end
    if not g.nativeVisual then g.nativeVisual=M.nativeBridge.new(here..'../') end
    local ok,result,err
    if signature~=g.nativeVisualSignature then
        ok,result,err=pcall(g.nativeVisual.visualArm,g.nativeVisual,targets)
        if ok and result then g.nativeVisualSignature=signature end
    else
        ok,result,err=pcall(g.nativeVisual.visualTick,g.nativeVisual,math.max(0,now-(g.nativeVisualNow or now)))
        if ok and type(result)=='number' then g.nativeVisualIntercepted=(g.nativeVisualIntercepted or 0)+result end
    end
    g.nativeVisualNow=now
    if not ok or result==false or result==nil and type(err)=='string' then
        g.nativeVisualFailed=true
        pcall(g.nativeVisual.visualDisarm,g.nativeVisual)
        print('[ZoneFPV] Native visual guard unavailable: '..tostring(ok and err or result)..'\n')
    end
end
local function scanModifiers(g,cm)
    local seen={}
    local scanned=attempt(g,'modifiers',function()
        -- Fresh bounded one-based access; no ForEach callback (UE4SS source has
        -- a Lua GC/stack crash warning), no live array/struct wrapper is retained.
        local list=cm.ModifierList
        local n=list:GetArrayNum()
        assert(type(n)=='number' and n>=0 and n%1==0 and n<=64,'camera modifier count outside 0..64')
        for i=1,n do
            local modifier=list[i]
            if modifier and type(modifier)=='userdata' then
                local kind=modifier:type()
                if kind=='RemoteUnrealParam' or kind=='LocalUnrealParam' then modifier=modifier:get() end
            end
            local entry=remember(g,modifier)
            if entry then
                seen[entry.id]=true
                if not modifier:IsDisabled() then modifier:DisableModifier(true) end
            end
        end
    end)
    if scanned then
        for id,entry in pairs(g.modifiers)do
            if not seen[id] then restoreModifier(g,entry);g.modifiers[id]=nil end
        end
    end
end
function M.update(s,now,system,_playerMode,clearWeather)
    -- A new flight owns its own collection lease; the expired character handoff
    -- must not later disarm or restore over this replacement scope.
    M.endRecovery()
    local g=s.visualGuard
    if g and (not same(g.world,s.world) or not same(g.pc,s.pc)) then M.restore(s);g=nil end
    if not g then
        g={world=s.world,pc=s.pc,modifiers={},materials={},materialCount=0,cvars={},unsupported={},nextVariables=0};s.visualGuard=g
    end
    holdLens(g,s)
    holdCollection(g,s,now)
    if system and (now>=g.nextVariables or g.clearWeather~=clearWeather) then
        g.nextVariables=now+0.25;g.system=system;g.clearWeather=clearWeather
        -- Keep the existing user-selected Clear feature separate from player
        -- effect suppression. Normal weather never opts into these variables.
        cvar(g,s,system,'r.Fog',clearWeather and 0 or nil)
        cvar(g,s,system,'r.VolumetricFog',clearWeather and 0 or nil)
        cvar(g,s,system,'r.LocalFogVolume',clearWeather and 0 or nil)
    end
    local cm=field(s.pc,'PlayerCameraManager')
    if not valid(cm) then return end
    if not same(g.camera,cm) then
        restoreCamera(g);g.camera=cm;g.cameraAddress=cm:GetAddress()
        for _,key in ipairs({'modifiers','camera shakes','camera fade','color scale'})do g.unsupported[key]=nil end
        -- This C++ field is not reflected on all builds. Read/write it only if
        -- UE4SS actually exposes a boolean and preserve its original value.
        local color=field(cm,'bEnableColorScaling')
        if type(color)=='boolean' then g.colorEnabled=color end
    end
    if not g.hooks then setupHooks(g) end
    scanModifiers(g,cm)
    discoverMaterials(g)
    holdRadiationBlendables(g,s)
    updateNativeVisual(g,now)
    updateMaterials(g)
    -- Direct native game calls can bypass the reflected function thunk. Keep
    -- the fallback on every existing game-frame update, without 0.1/0.5 s gaps.
    attempt(g,'camera shakes',function()cm:StopAllCameraShakes(true)end)
    attempt(g,'camera fade',function()cm:StopCameraFade()end)
    if g.colorEnabled~=nil then
        attempt(g,'color scale',function()if cm.bEnableColorScaling then cm.bEnableColorScaling=false end end)
    end
end
function M.restore(s)
    local g=s.visualGuard;if not g then return end
    if g.hooks and #g.hooks>0 then
        print('[ZoneFPV] Visual feedback summary: hooks='..tostring(#g.hooks)..
            ' materialRegistered='..tostring(g.materialFeedbackReady==true)..
            ' materialEvents='..tostring(g.materialEvents or 0)..
            ' materialDiscoveries='..tostring(g.materialDiscoveries or 0)..
            ' nativeMaterialEvents='..tostring(g.nativeVisualIntercepted or 0)..
            ' concussionCorrections='..tostring(g.concussionCorrections or 0)..
            ' suppressionCorrections='..tostring(g.suppressionCorrections or 0)..
            ' nativeConcussionEvents='..tostring(g.nativeConcussionIntercepted or 0)..
            ' fadeEvents='..tostring(g.fadeEvents or 0)..' shakeEvents='..tostring(g.shakeEvents or 0)..'\n')
    end
    -- Stale native callbacks stay inert even if unregistration fails at teardown.
    g.active=false
    -- Release the native value gate before restoring the captured preflight
    -- value, or restoration would itself be intercepted and replaced with 0.
    stopNativeConcussion(g)
    if g.nativeVisual then pcall(g.nativeVisual.visualDisarm,g.nativeVisual);g.nativeVisual=nil end
    if liveMaterials==g then liveMaterials=nil end
    for _,h in ipairs(g.hooks or {})do pcall(UnregisterHook,h.path,h.pre,h.post)end
    g.hooks={}
    g.pendingHooks={};g.materialQueue=nil
    restoreMaterials(g)
    restoreRadiationBlendables(g)
    restoreCollection(g)
    restoreLens(g)
    g.materialTargets=nil
    for name,value in pairs(g.cvars)do
        pcall(function()g.system:ExecuteConsoleCommand(g.pc,name..' '..tostring(value),g.pc)end)
    end
    restoreCamera(g)
    s.visualGuard=nil
end
local function setupRecoveryMaterials(r,g)
    if FName==nil or type(StaticFindObject)~='function' then return end
    attempt(r,'recovery material keys',function()
        r.materialTargets={};r.blastIndices={}
        for _,spec in ipairs({
            {name='ConcussionIntensity',parents={'MI_PP_Concussion'},paths={
                '/Game/_Stalker_2/Materials/PostProcess/Concussion/MI_PP_Concussion.MI_PP_Concussion'}},
            {name='SuppressionIntensity',parents={'PPI_Suppression','PPI_Suppression_HDR'},paths={
                '/Game/_Stalker_2/Materials/PostProcess/Suppression/PPI_Suppression.PPI_Suppression',
                '/Game/_Stalker_2/Materials/PostProcess/Suppression/PPI_Suppression_HDR.PPI_Suppression_HDR'}},
        })do
            local name=FName(spec.name);local index=name:GetComparisonIndex();local names={}
            for _,parent in ipairs(spec.parents)do
                local ok,value=pcall(function()return FName(parent):GetComparisonIndex()end)
                if ok then names[value]=true end
            end
            r.materialTargets[index]=g and g.materialTargets and g.materialTargets[index]or
                {name=name,label=spec.name,paths=spec.paths,parentNames=next(names)and names or nil}
            if spec.name=='ConcussionIntensity'then r.concussionIndex=index else r.suppressionIndex=index end
        end
        -- These exact installed Explosion.Empty postFX use independent cooked
        -- blast masters. Suppress only their passes in the local owned camera
        -- stack while normal source removal executes its ordinary stop policy.
        -- No new collection/scalar key is written or added to the native gate.
        for _,surface in ipairs({'Water','Dirt','Rock','Wood','Sand'})do
            local parents,paths={},{}
            local leaf=surface=='Water'and 'MI_PP_WaterExplosive'or 'PPI_'..surface..'Explosive'
            parents[1]=leaf;paths[1]='/Game/_Stalker_2/Materials/PostProcess/Explosive/'..leaf..'.'..leaf
            if surface~='Water'then
                parents[2]=leaf..'_HDR';paths[2]='/Game/_Stalker_2/Materials/PostProcess/Explosive/'..leaf..'_HDR.'..leaf..'_HDR'
            end
            local name=FName('Explosion'..surface..'Intensity');local index=name:GetComparisonIndex();local parentNames={}
            for _,parent in ipairs(parents)do parentNames[FName(parent):GetComparisonIndex()]=true end
            r.materialTargets[index]={name=name,label='Explosion'..surface,paths=paths,parentNames=parentNames,feedbackOnly=true}
            r.blastIndices[index]='Explosion'..surface
        end
        -- Some native camera MIDs unwrap the configured PPI/HDR instance and
        -- have the cooked blast master as their immediate parent instead.
        -- Identify only these two proven masters in the owned camera stack;
        -- their FNames are classifier keys, never scalar/MPC parameters.
        for _,master in ipairs({'PPM_Explosive','M_PP_ExplosiveWater'})do
            local name=FName(master);local index=name:GetComparisonIndex()
            r.materialTargets[index]={name=name,label=master,feedbackOnly=true,
                parentNames={[index]=true},paths={
                    '/Game/_Stalker_2/Materials/PostProcess/Explosive/'..master..'.'..master}}
            r.blastIndices[index]=master
        end
    end)
end
local concussionShakePaths={
    '/Game/GameLite/Resources/CameraShake/CamShakeConcussion.CamShakeConcussion_C',
    '/Game/GameLite/Resources/CameraShake/CamShakeConcussion_2.CamShakeConcussion_2_C',
}
local concussionAudioPath='/Game/_STALKER2/Audio/WwiseAudio/Events/Effects/Concussion/SFX_Concussion_Start.SFX_Concussion_Start'
local function ownedRecoveryPawn(r,currentController)
    local pc=valid(currentController)and currentController or r.pc
    local possessed=valid(pc)and field(pc,'Pawn')
    if not valid(pc)or not valid(r.pawn)or not valid(possessed)or not same(possessed,r.pawn)then return false end
    -- Both wrappers must still belong to the captured world. A global effect
    -- removal console command cannot provide this receiver ownership contract.
    local owned,matching=pcall(function()
        local pawnWorld=r.pawn:GetWorld();local controllerWorld=pc:GetWorld()
        return valid(pawnWorld)and valid(controllerWorld)and same(pawnWorld,r.world)and same(controllerWorld,r.world)
    end)
    return owned and matching
end
local function stopRecoverySource(r)
    if r.nativeConcussionSource then
        pcall(r.nativeConcussionSource.concussionSourceDisarm,r.nativeConcussionSource)
    end
    r.nativeConcussionSource=nil;r.nativeConcussionSourceNow=nil
end
local function holdRecoverySource(r,now,currentController)
    if not ownedRecoveryPawn(r,currentController)then
        if r.nativeConcussionSource then r.nativeConcussionSourceFailed=true;stopRecoverySource(r)end
        return
    end
    if not M.nativeBridge or r.nativeConcussionSourceFailed then return end
    if not r.nativeConcussionSource then
        if now<(r.nextSourceArm or 0)or (r.sourceArmAttempts or 0)>=3 then return end
        r.sourceArmAttempts=(r.sourceArmAttempts or 0)+1;r.nextSourceArm=now+1
        local ok,client=pcall(M.nativeBridge.new,here..'../')
        local armed,ready,why
        if ok and client then
            armed,ready,why=pcall(client.concussionSourceArm,client,r.pawn,r.world)
        else why=client end
        if not armed or not ready then
            if ok and client then pcall(function()client:concussionSourceDisarm()end)end
            if not r.nativeConcussionSourceReported then
                r.nativeConcussionSourceReported=true
                print('[ZoneFPV] Owned concussion source cleanup unavailable: '..tostring(armed and why or ready or why)..'; exact MPC/camera recovery retained\n')
            end
            return
        end
        r.nativeConcussionSource=client;r.nativeConcussionSourceNow=now;r.nativeConcussionSourceReady=true
        -- Arming already invokes the normal source cleanup, so its confirmed
        -- removals belong to this recovery even before the first tick delta.
        if type(why)=='table'then
            r.nativeSourceMatched=(r.nativeSourceMatched or 0)+(why.matched or 0)
            r.nativeSourceRemoved=(r.nativeSourceRemoved or 0)+(why.removed or 0)
        end
        print('[ZoneFPV] Owned concussion source cleanup armed for fixed five-second recovery\n')
    end
    local dt=math.max(0,now-(r.nativeConcussionSourceNow or now));r.nativeConcussionSourceNow=now
    local ok,delta,why=pcall(r.nativeConcussionSource.concussionSourceTick,r.nativeConcussionSource,dt,now>=r.expires)
    if not ok or (delta==nil and why~=nil)then
        r.nativeConcussionSourceFailed=true
        stopRecoverySource(r)
        print('[ZoneFPV] Owned concussion source cleanup stopped: '..tostring(ok and why or delta)..'; exact MPC/camera recovery retained\n')
        return
    end
    if delta then
        r.nativeSourceMatched=(r.nativeSourceMatched or 0)+delta.matched
        r.nativeSourceRemoved=(r.nativeSourceRemoved or 0)+delta.removed
    end
end
local function holdRecoverySuppression(r,currentController)
    if not ownedRecoveryPawn(r,currentController)then return end
    if not r.suppressionSourceChecked then
        r.suppressionSourceChecked=true
        -- Current PE registration confirms both methods on AObj, with a float
        -- getter and the normal clamped setter. An SDK name alone is insufficient;
        -- require these callable reflected members on this actual owned pawn.
        r.suppressionSourceReady=field(r.pawn,'GetCurrentSuppressionPoints')~=nil and
            field(r.pawn,'SetCurrentSuppressionPoints')~=nil
        if not r.suppressionSourceReady then
            print('[ZoneFPV] Owned suppression source API unavailable; exact MPC/camera recovery retained\n')
        end
    end
    if not r.suppressionSourceReady then return end
    attempt(r,'owned suppression source',function()
        local value=r.pawn:GetCurrentSuppressionPoints()
        assert(finite(value),'owned suppression source getter unavailable')
        if value>0 then
            -- GrenadeConcussion adds accumulated points; hiding a shader for five
            -- seconds leaves those points driving the mechanic afterward. Clear
            -- only this proven vital source, never HP or other vitals.
            r.pawn:SetCurrentSuppressionPoints(0)
            assert(r.pawn:GetCurrentSuppressionPoints()==0,'owned suppression source zero readback failed')
            r.suppressionSourceCorrections=(r.suppressionSourceCorrections or 0)+1
        end
    end)
end
local function recoveryAsset(r,path)
    local ok,asset=pcall(StaticFindObject,path)
    local didLoad=false
    if not ok or not valid(asset)then
        r.assetLoadAttempts=r.assetLoadAttempts or {}
        if (r.assetLoadAttempts[path]or 0)<3 and M.assetLoader then
            r.assetLoadAttempts[path]=(r.assetLoadAttempts[path]or 0)+1
            r.recoveryAssets=r.recoveryAssets or M.assetLoader.new()
            local loaded,value,why=pcall(r.recoveryAssets.load,r.recoveryAssets,path)
            if loaded and valid(value)then
                asset=value;didLoad=true
            else
                r.assetLoadReported=r.assetLoadReported or {}
                if not r.assetLoadReported[path]then
                    r.assetLoadReported[path]=true
                    print('[ZoneFPV] Concussion exact feedback asset load unavailable: '..path..' / '..tostring(loaded and why or value)..'\n')
                end
            end
        end
    end
    if not valid(asset)then return end
    return asset,didLoad
end
local function concussionClass(r,path)
    local asset,didLoad=recoveryAsset(r,path)
    if not asset then return end
    -- The extracted shipping exports prove both *_C names and LegacyCameraShake
    -- ancestry. Reject an unconverted Blueprint asset returned by a loader;
    -- StopAllInstancesOfCameraShake requires its generated class, not the asset.
    local expected=path:match('%.([^%.]+)$')
    local checked,name=pcall(function()return asset:GetFName():GetComparisonIndex()end)
    local named,index=pcall(function()return FName(expected):GetComparisonIndex()end)
    if not checked or not named or name~=index then
        if not r.classIdentityReported then
            r.classIdentityReported=true
            print('[ZoneFPV] Concussion shake class identity rejected: '..path..'\n')
        end
        return
    end
    r.classLookups=(r.classLookups or 0)+1
    if didLoad then r.classLoads=(r.classLoads or 0)+1 end
    return asset
end
local function holdRecoveryCamera(r,now,currentController)
    local pc=valid(currentController)and currentController or r.pc
    if not valid(pc)then return end
    local cm=field(pc,'PlayerCameraManager')
    if not valid(cm)then return end
    if not same(r.camera,cm)then
        restoreRadiationBlendables(r)
        r.camera=cm;r.playerCameraManager=nil;r.playerCameraManagerLookup=nil
    end
    holdRadiationBlendables(r,{pc=pc,pawn=r.pawn})
    -- Config GroupSID=Concussion names these two exact classes. Normal walking,
    -- recoil, hit feedback and other modifiers remain under game ownership.
    if type(StaticFindObject)=='function' and now>=(r.nextRecoveryEffectsLookup or 0)then
        r.nextRecoveryEffectsLookup=now+1;r.shakeClasses=r.shakeClasses or {}
        for i,path in ipairs(concussionShakePaths)do
            if not valid(r.shakeClasses[i])then
                local asset=concussionClass(r,path)
                if asset then r.shakeClasses[i]=asset end
            end
        end
        if not valid(r.concussionAudio)then
            local event,didLoad=recoveryAsset(r,concussionAudioPath)
            if event then
                r.concussionAudio=event;r.audioLookups=(r.audioLookups or 0)+1
                if didLoad then r.audioLoads=(r.audioLoads or 0)+1 end
            end
        end
    end
    for _,class in pairs(r.shakeClasses or {})do
        if valid(class)then attempt(r,'concussion shake '..tostring(class:GetAddress()),function()
            cm:StopAllInstancesOfCameraShake(class,true)
            r.shakeStops=(r.shakeStops or 0)+1
        end)end
    end
    if valid(r.pawn)and valid(r.concussionAudio)and now>=(r.nextRecoveryAudio or 0)then
        r.nextRecoveryAudio=now+.1
        attempt(r,'owned concussion audio',function()
            -- Reflected Wwise API: Stop=0, PlayingID=0 selects only this
            -- event's instances on the original local pawn, Linear curve=4.
            local result=r.concussionAudio:ExecuteAction(0,r.pawn,0,0,4)
            if result==1 then r.audioStops=(r.audioStops or 0)+1 end
        end)
    end
end
function M.endRecovery(reason)
    local previous=recovery;recovery=nil
    if not previous then return end
    previous.active=false
    stopRecoverySource(previous)
    stopNativeConcussion(previous)
    restoreRadiationBlendables(previous,reason=='deadline')
    previous.feedbackCollection=nil
    -- Keep the final zero scalar values; restoring a preflight/blast amplitude
    -- would revive the old stun. Restore blendable weights so genuine new
    -- processor writes render normally once the collection gate is released.
    -- Old explosion event passes stay zero at deadline; their positive saved
    -- event weights would otherwise replay lingering dirt. No lease survives.
    print('[ZoneFPV] Concussion recovery finished: reason='..tostring(reason or 'cancel')..
        ' nativeCollectionEvents='..tostring(previous.nativeConcussionIntercepted or 0)..
        ' concussionCorrections='..tostring(previous.concussionCorrections or 0)..
        ' suppressionCorrections='..tostring(previous.suppressionCorrections or 0)..
        ' suppressionSourceReady='..tostring(previous.suppressionSourceReady==true)..
        ' suppressionSourceCorrections='..tostring(previous.suppressionSourceCorrections or 0)..
        ' nativeSourceReady='..tostring(previous.nativeConcussionSourceReady==true)..
        ' nativeSourceFailed='..tostring(previous.nativeConcussionSourceFailed==true)..
        ' nativeSourceMatched='..tostring(previous.nativeSourceMatched or 0)..
        ' nativeSourceRemoved='..tostring(previous.nativeSourceRemoved or 0)..
        ' ownedBlastPasses='..tostring(previous.blastPasses or 0)..
        ' exactShakeClasses='..tostring(previous.classLookups or 0)..' exactShakeLoads='..tostring(previous.classLoads or 0)..
        ' exactAudioEvents='..tostring(previous.audioLookups or 0)..' exactAudioLoads='..tostring(previous.audioLoads or 0)..
        ' concussionShakeStops='..tostring(previous.shakeStops or 0)..' ownedAudioStops='..tostring(previous.audioStops or 0)..'\n')
end
function M.recoveryActive()return recovery~=nil end
function M.updateRecovery(now,currentWorld,currentController)
    local r=recovery;if not r then return false end
    if not finite(now) or not valid(r.world) or not valid(currentWorld) or not same(r.world,currentWorld)then
        M.endRecovery('world unavailable');return false
    end
    if valid(currentController)and r.pc~=nil and (not valid(r.pc)or not same(currentController,r.pc))then
        M.endRecovery('local controller changed');return false
    end
    local pc=valid(currentController)and currentController or r.pc
    local possessed=valid(pc)and field(pc,'Pawn')
    if r.pawn~=nil and valid(possessed)and (not valid(r.pawn)or not same(r.pawn,possessed))then
        M.endRecovery('local pawn changed');return false
    end
    -- Clear only verified concussion/explosion feedback effects, suppression
    -- source points, two MPC values and owned
    -- feedback passes. HP, other vitals, input and normal camera state remain
    -- restored. Finish the same-owner deadline with one final correction so a
    -- source written between the last protected update and expiry cannot replay.
    holdRecoverySource(r,now,currentController)
    holdRecoverySuppression(r,currentController)
    holdCollection(r,{world=r.world},now,true)
    holdRecoveryCamera(r,now,currentController)
    if now>=r.expires then M.endRecovery('deadline');return false end
    return true
end
function M.beginRecovery(s,now)
    if not s then return false end
    if s.visualRecoveryToken then
        M.restore(s)
        return recovery~=nil and recovery.token==s.visualRecoveryToken
    end
    M.endRecovery()
    local token={};s.visualRecoveryToken=token
    if not finite(now) or not valid(s.world)then M.restore(s);return false end
    local r={world=s.world,pc=s.pc,pawn=s.pawn,token=token,expires=now+recoverySeconds,unsupported={},
        materials={},materialCount=0,collectionOnlyMaterials=true,active=true}
    local g=s.visualGuard
    setupRecoveryMaterials(r,g)
    if g then
        r.camera=g.camera;r.playerCameraManager=g.playerCameraManager;r.playerCameraManagerLookup=g.playerCameraManagerLookup
        r.radiationBlendables={}
        for id,leases in pairs(g.radiationBlendables or {})do
            local retained={owner=leases.owner,entries={}}
            for index,entry in pairs(leases.entries)do
                local label=feedbackLabel(r,entry.object)
                if label then
                    retained.entries[index]=entry;leases.entries[index]=nil
                end
            end
            if next(retained.entries)then r.radiationBlendables[id]=retained end
        end
    end
    local lease=g and g.feedbackCollection
    if lease and valid(lease.context) and same(lease.context,s.world) and valid(lease.asset) and valid(lease.library)then
        local keep,others={},{}
        for _,entry in ipairs(lease.entries)do
            if entry.label=='ConcussionIntensity'or entry.label=='SuppressionIntensity'then keep[#keep+1]=entry else others[#others+1]=entry end
        end
        if #keep==#concussionCollectionKeys then
            r.feedbackCollection={asset=lease.asset,library=lease.library,context=lease.context,entries=keep}
            lease.entries=others
            -- Transfer the existing gate without a disarm/re-arm gap. The
            -- native scope uses the world/asset/name, not the destroyed camera.
            r.nativeConcussion=g.nativeConcussion
            r.nativeConcussionLease=g.nativeConcussionLease and r.feedbackCollection or nil
            r.nativeConcussionNow=g.nativeConcussionNow
            g.nativeConcussion=nil;g.nativeConcussionLease=nil;g.nativeConcussionNow=nil
        end
    end
    recovery=r
    M.restore(s)
    -- Early exits can precede the first FPV update or a successful asset/native
    -- lookup. Acquire only these two scalars now, retry absent assets at most once
    -- per second within the original, fixed five-second deadline.
    return M.updateRecovery(now,s.world,s.pc)
end
return M
