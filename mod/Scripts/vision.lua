-- Camera-local experimental sensors. Palette work is bounded and target meshes
-- come from the existing streaming cache; no periodic global object searches.
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local modes=dofile(here..'vision_modes.lua')
local M={assets=dofile(here..'vision_asset_specs.lua'),clock=os.clock,modes=modes,
    MAX_ACTORS=96,MAX_MESHES=512,MAX_COMPONENTS=256,MAX_SLOTS=128,MAX_PINS=2048,MAX_TARGET_MIDS=128,RANGE_CM=10000}
M.needsTargets=modes.needsTargets
local assetLoader=dofile(here..'asset_loader.lua').new()
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return call(o,'IsValid')==true end
local function address(o)return valid(o) and call(o,'GetAddress')end
local function same(a,b)local id=address(a);return id~=nil and id==address(b)end
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function count(a)
    local n=call(a,'GetArrayNum') or (type(a)=='table' and #a)
    if finite(n) and n%1==0 and n>=0 and n<=2112 then return n end
end
local function unwrap(v)
    local kind=call(v,'type')
    if kind=='RemoteUnrealParam' or kind=='LocalUnrealParam' then return call(v,'get')end
    return v
end
local function once(g,key,text)
    if not g.logged[key] then g.logged[key]=true;g.log('Vision: '..text)end
end
local function load(g,path)
    if g.assets[path]~=nil then return valid(g.assets[path]) and g.assets[path] or nil end
    local ok,o,why=pcall(assetLoader.load,assetLoader,path)
    if not ok or not valid(o)then once(g,'asset-'..path,path..': '..tostring(ok and why or o))end
    g.assets[path]=ok and valid(o) and o or false
    return valid(g.assets[path]) and g.assets[path] or nil
end
local function pp(g)return valid(g.camera) and read(g.camera,'PostProcessSettings')end
local function snapshotValue(v)
    if v==nil then return {absent=true}end
    if type(v)=='number' or type(v)=='boolean' or valid(v) then return {value=v}end
    -- A reflected null UObject is represented by an invalid UObject wrapper,
    -- rather than Lua nil. Its zero address is safe to restore as nullptr.
    if call(v,'type')=='UObject' and call(v,'GetAddress')==0 then return {null=true}end
    local x,y,z,w=read(v,'X'),read(v,'Y'),read(v,'Z'),read(v,'W')
    if finite(x) and finite(y) and finite(z) and finite(w) then return {vector={X=x,Y=y,Z=z,W=w}}end
    error('unsupported postprocess value')
end
local pin
local function set(g,key,value,override)
    local p=assert(pp(g),'camera postprocess unavailable')
    if not g.fields[key] then
        local original=snapshotValue(p[key])
        if valid(original.value) then assert(pin(g,original.value),'original postprocess texture retention failed')end
        g.fields[key]={original=original,override=p['bOverride_'..key]}
    end
    if type(value)=='table' and finite(value.X) and finite(value.Y) and finite(value.Z) and finite(value.W) then
        local v=p[key];v.X,v.Y,v.Z,v.W=value.X,value.Y,value.Z,value.W
    else p[key]=value end
    p['bOverride_'..key]=override~=false
end
-- Weight-zero blendables retain original dynamic materials across engine GC.
-- They never render. Slots are changed only after the original has been pinned.
pin=function(g,object)
    if not valid(object) then return false end
    local id=address(object);if not id then return false end
    if g.pins[id] then g.pins[id].refs=g.pins[id].refs+1;return true end
    if g.pinCount>=M.MAX_PINS then return false end
    local p=assert(pp(g),'camera postprocess unavailable')
    local a=p.WeightedBlendables.Array;local n=assert(count(a),'blendable array unavailable')
    local index
    while #g.freePins>0 do
        local candidate=table.remove(g.freePins)
        if candidate<=n then
            local row=unwrap(a[candidate]);local held=unwrap(read(row,'Object'))
            if read(row,'Weight')==0 and (held==nil or call(held,'GetAddress')==0) then index=candidate;break end
        end
        g.releasedPins[candidate]=nil
    end
    if not index then if n>=2112 then return false end;index=n+1 end
    a[index]={Weight=0,Object=object};g.releasedPins[index]=nil
    g.pins[id]={object=object,index=index,refs=1};g.pinCount=g.pinCount+1
    return true
end
local function pinIndex(a,n,entry)
    local function matches(index)
        local row=unwrap(a[index]);return read(row,'Weight')==0 and same(unwrap(read(row,'Object')),entry.object)
    end
    if entry.index<=n and matches(entry.index) then return entry.index end
    -- Another system can remove/insert array rows. A uniquely matching object
    -- still identifies our row; duplicates are left untouched conservatively.
    local found
    for i=1,n do if matches(i) then if found then return end;found=i end end
    return found
end
local function release(g,object)
    local id=address(object);local entry=id and g.pins[id]
    if not entry then return end
    entry.refs=entry.refs-1;if entry.refs>0 then return end
    pcall(function()
        local p=assert(pp(g));local a=p.WeightedBlendables.Array;local n=assert(count(a))
        local index=pinIndex(a,n,entry)
        if not index then return end
        -- Reuse a vacant engine reference slot rather than rebuilding a native
        -- array for every target that leaves range. The final restore compacts.
        -- Struct-from-table setters skip nil fields in UE4SS. Write through
        -- the live struct wrapper so Object really becomes a null pointer.
        local row=unwrap(a[index]);row.Weight=0;row.Object=nil
        g.pins[id]=nil;g.pinCount=g.pinCount-1
        g.releasedPins[index]=true;g.freePins[#g.freePins+1]=index
    end)
end
local function unpin(g)
    local p=pp(g);if not p then return end
    local a=p.WeightedBlendables.Array;local n=count(a);if not n then return end
    for _,entry in pairs(g.pins)do local index=pinIndex(a,n,entry);if index then entry.index=index end end
    local kept={}
    for i=1,n do
        local v=unwrap(a[i]);local o=unwrap(read(v,'Object'));local weight=read(v,'Weight')
        local own=g.pins[address(o)]
        local vacant=g.releasedPins[i] and weight==0 and (o==nil or call(o,'GetAddress')==0)
        if not vacant and not (own and own.index==i and weight==0 and same(own.object,o)) then
            kept[#kept+1]={Weight=weight,Object=o}
        end
    end
    -- Preserve any blendables another system appended while the sensor was on.
    a:Empty();for i,v in ipairs(kept)do a[i]=v end
end
local prewarmed
local function dropPrewarm(g)
    if not g then return end
    -- A pending-kill RT can fail IsValid while the host still retains its
    -- pointer. Clear only our recorded zero-weight row before compacting it.
    pcall(function()
        local p=pp(g);if not p then return end
        local a=p.WeightedBlendables.Array;local n=count(a);if not n then return end
        for id,entry in pairs(g.pins)do
            if not valid(entry.object) and entry.index<=n then
                local row=unwrap(a[entry.index]);local held=unwrap(read(row,'Object'))
                if read(row,'Weight')==0 and call(held,'GetAddress')==id then
                    row.Object=nil;g.releasedPins[entry.index]=true
                end
            end
        end
        unpin(g)
    end)
    if g.lut then pcall(g.lut.destroy,g.lut)end
    g.lut=nil;g.texture=nil;g.held=nil;g.pins={};g.pinCount=0
end
function M.clearPrewarm()
    local old=prewarmed;prewarmed=nil;dropPrewarm(old)
end
function M.prewarm(context,mode,log)
    if not modes.valid(mode)then M.clearPrewarm();return nil,'invalid vision mode'end
    if mode==0 or modes.modes[mode].fusion then M.clearPrewarm();return true,'ready'end
    local world,camera=read(context,'world'),read(context,'camera')
    if not valid(world) or not valid(camera)then M.clearPrewarm();return nil,'prewarm world/camera unavailable'end
    local g=prewarmed
    if g and (g.mode~=mode or not same(g.world,world) or not same(g.camera,camera)
        or (g.held and not valid(g.held)))then M.clearPrewarm();g=nil end
    if not g then
        g={world=world,camera=camera,mode=mode,log=log or function()end,logged={},assets={},
            pins={},freePins={},releasedPins={},pinCount=0}
        prewarmed=g
    end
    if g.error then return nil,g.error end
    if valid(g.texture)then return true,'ready'end
    local ok,ready=pcall(function()
        if not g.lut then
            local library=load(g,'/Script/Engine.Default__KismetRenderingLibrary')
            assert(valid(library),'palette rendering library unavailable')
            local factory=M.lut or dofile(here..'vision_lut.lua')
            g.lut=factory.new(world,library)
        end
        local function inspect()
            local texture,state,pending=g.lut:texture(mode)
            local held=texture or pending
            if valid(held) and not same(held,g.held)then
                assert(pin(g,held),'prewarm palette retention failed')
                if g.held then release(g,g.held)end
                g.held=held
            end
            if valid(texture)then g.texture=texture;return true end
            assert(state=='pending',tostring(state));return false
        end
        -- Keep the old pending root across the native call, then root a newly
        -- created target before yielding. Never assign the visible player LUT.
        if inspect()then return true end
        local result,why=g.lut:update()
        if result==nil then error(why)end
        return inspect()
    end)
    if not ok then
        dropPrewarm(g);g.error=tostring(ready)
        return nil,g.error -- no per-frame retry/allocation for this same scope
    end
    return ready,ready and 'ready' or 'pending'
end
local function sensorMaterial(g,material)
    -- Components may expose a local dynamic instance of our shared material.
    -- Checking only pointer equality incorrectly rejects that valid override.
    for _=1,6 do
        if not valid(material)then return false end
        if same(material,g.material)then return true end
        if g.localMaterials[address(material)]then return true end
        material=read(material,'Parent')
    end
    return false
end
local function materialName(material)
    return tostring(call(material,'GetFullName') or address(material) or 'null')
end
local function nullMaterial(material)
    return material==nil or (call(material,'type')=='UObject' and call(material,'GetAddress')==0)
end
local function physicalRenderer(g,mesh)
    if not valid(mesh)then return end
    if g.beamMeshes[address(mesh)]then return end
    local owner=call(mesh,'GetOwner')
    if read(mesh,'bVisible')==false or read(mesh,'bHiddenInGame')==true
        or read(mesh,'bOnlyOwnerSee')==true or read(mesh,'bRenderInMainPass')==false
        or read(owner,'bHidden')==true then return end
    local name=tostring(call(mesh,'GetFullName') or ''):lower()
    -- The actual rejected null slot is under WeaponInHandsMesh/WeaponAttachmentSM.
    -- Weapon optics/cards and direction helpers are outside the living model.
    for _,part in ipairs({'weapon','wpn_','muzzle','laser','fakelightbeam','lookat','gaze','debug','arrow','billboard','collision'})do
        if name:find(part,1,true)then
            once(g,'helper-filter','retaining helper/equipment materials on '..materialName(mesh));return
        end
    end
    local asset=call(mesh,'GetSkinnedAsset')
    if not valid(asset)then asset=read(mesh,'SkinnedAsset')end
    if not valid(asset)then asset=read(mesh,'SkeletalMesh')end
    if valid(asset)then return asset,'skinned' end
    asset=read(mesh,'StaticMesh')
    if valid(asset)then return asset,'static' end
    -- Groom/shape components expose material setters too, but do not use the
    -- cooked skeletal/static shader. Replacing their cards can expose flecks.
    once(g,'renderer-filter','retaining non-skeletal/static renderer '..materialName(mesh))
end
local function surfaceMaterial(material)
    local mode
    for _=1,6 do
        if not valid(material)then break end
        local name=materialName(material):lower()
        -- Installed assets explicitly provide fake flashlight beam geometry.
        -- Some variants are masked rather than translucent, so blend mode
        -- alone cannot distinguish them from genuine masked clothing.
        if name:find('m_fakeflashlight',1,true) or name:find('m_volumelight',1,true)then return false end
        for _,part in ipairs({'cornea','tearline','eyeocclusion','eyelash','glass','lens','muzzle','laser','lookat','gaze','debug'})do
            if name:find(part,1,true)then return false end
        end
        local overrides=read(material,'BasePropertyOverrides')
        if mode==nil and read(overrides,'bOverride_BlendMode')==true then mode=read(overrides,'BlendMode')end
        if mode==nil then mode=read(material,'BlendMode')end
        local domain=read(material,'MaterialDomain')
        if finite(domain) and domain~=0 then return false end
        material=read(material,'Parent')
    end
    -- Masked body/clothing (1) remains eligible. Transparent/additive cards
    -- must retain their opacity rather than becoming an opaque hot polygon.
    return not finite(mode) or mode<=1,mode
end
local function physicalSlot(g,mesh,slot,material,asset,kind)
    if valid(material)then
        local eligible=surfaceMaterial(material)
        if not eligible then once(g,'surface-filter','retaining optical/card material '..materialName(material))end
        return eligible
    end
    if not nullMaterial(material)then return false end
    -- Null weapon/helper slots are not evidence of a visible surface. A body
    -- null is eligible only when its real skeletal asset declares an opaque
    -- material there. Never resurrect a masked/empty slot with the white MID.
    if kind~='skinned' then return false end
    local materials=read(asset,'Materials');local n=count(materials)
    if not n or slot>=n then return false end
    local source=unwrap(read(unwrap(materials[slot+1]),'MaterialInterface'))
    if not valid(source)then return false end
    local eligible,mode=surfaceMaterial(source)
    return eligible and mode==0
end
local function restoreSlot(g,record,slot,original)
    if not sensorMaterial(g,call(record.mesh,'GetMaterial',slot))then return end
    if original==false then call(record.mesh,'SetMaterial',slot,nil)
    elseif valid(original)then call(record.mesh,'SetMaterial',slot,original)end
end
local function clearOverlay(g,record)
    local mesh=record.mesh
    if read(mesh,'GetOverlayMaterial')==nil then return end
    local actual=mesh:GetOverlayMaterial()
    if not valid(actual)then return end
    -- A second mesh overlay pass is outside GetNumMaterials/GetMaterial. Keep
    -- it from drawing the original outfit over the verified unlit slots.
    if not same(actual,record.overlay)then
        assert(pin(g,actual),'overlay material retention failed')
        if record.overlay then release(g,record.overlay)end
        record.overlay=actual
    end
    record.overlayOwned=true
    mesh:SetOverlayMaterial(nil)
    assert(nullMaterial(mesh:GetOverlayMaterial()),'overlay material readback mismatch: '..materialName(mesh))
    if not record.overlayVerified then
        record.overlayVerified=true;g.stats.overlays=g.stats.overlays+1
        once(g,'overlay','cleared mesh overlay on '..materialName(mesh)..' original='..materialName(actual))
    end
end
-- Both setters are registered UPrimitiveComponent UFunctions in the installed
-- Shipping executable (SetReceivesDecals 0x549feca, SetRenderCustomDepth 0x11e6d46).
-- These are secondary render passes, separate from the replaced surface slots.
local secondaryPasses={
    {key='bRenderCustomDepth',setter='SetRenderCustomDepth'},
    {key='bReceivesDecals',setter='SetReceivesDecals'},
}
local function holdSecondaryPasses(g,record)
    local mesh=record.mesh
    record.secondaryPasses=record.secondaryPasses or {}
    if not record.secondaryReported and (g.secondaryReports or 0)<3 then
        record.secondaryReported=true;g.secondaryReports=(g.secondaryReports or 0)+1
        local _,source=next(record.originals)
        g.log('Vision: sensor secondary passes '..materialName(mesh)
            ..' depth='..tostring(read(mesh,'bRenderCustomDepth'))
            ..' stencil='..tostring(read(mesh,'CustomDepthStencilValue'))
            ..' decals='..tostring(read(mesh,'bReceivesDecals'))
            ..' source='..materialName(source))
    end
    for _,spec in ipairs(secondaryPasses)do
        local current=read(mesh,spec.key)
        local saved=record.secondaryPasses[spec.key]
        if type(current)=='boolean' and not (saved and saved.failed)then
            if not saved then
                saved={value=current};record.secondaryPasses[spec.key]=saved
            end
            if current then
                -- A game re-enable is the latest real state, including when
                -- the field was false at capture. False is our held value.
                saved.value=current
                if read(mesh,spec.setter)==nil then
                    saved.failed=true
                    once(g,'secondary-api-'..spec.key,'secondary pass setter unavailable: '..spec.setter)
                else
                    -- Retain ownership before calling: an exception after a
                    -- native write must not lose the restoration snapshot.
                    saved.owned=true
                    local ok,why=pcall(function()
                        mesh[spec.setter](mesh,false)
                        assert(read(mesh,spec.key)==false,'secondary flag readback mismatch')
                    end)
                    if not ok then
                        if read(mesh,spec.key)==true then saved.owned=false end
                        saved.failed=true
                        once(g,'secondary-write-'..spec.key,'secondary pass retained after failed override: '..spec.key..' '..tostring(why))
                    end
                end
            end
        end
    end
end
local function restoreSecondaryPasses(g,record)
    for _,spec in ipairs(secondaryPasses)do
        local saved=record.secondaryPasses and record.secondaryPasses[spec.key]
        -- A foreign write to true already restored the latest state. Never
        -- overwrite it or issue setters for a flag that was false throughout.
        if saved and saved.owned and read(record.mesh,spec.key)==false then
            local ok,why=pcall(function()
                record.mesh[spec.setter](record.mesh,saved.value)
                assert(read(record.mesh,spec.key)==saved.value,'secondary flag restoration readback mismatch')
            end)
            if not ok then once(g,'secondary-restore-'..spec.key,'secondary pass restore unavailable: '..spec.key..' '..tostring(why))end
        end
    end
    record.secondaryPasses=nil
end
local function writeSensorSlot(g,record,slot)
    local mesh=record.mesh
    local key=tostring(record.id)..':'..slot
    local cached=g.cachedMIDs[key]
    if not record.localMIDs[slot] and cached and valid(cached.mesh) and same(cached.mesh,mesh) and valid(cached.material)then
        record.localMIDs[slot]=cached.material
    end
    mesh:SetMaterial(slot,record.localMIDs[slot] or g.material)
    local actual=mesh:GetMaterial(slot)
    if sensorMaterial(g,actual)then return end
    -- Use the reflected component-owned creation/assignment path only when a
    -- shared override was rejected. Each slot gets at most one such attempt,
    -- with a hard per-flight allocation cap; no raw native calls or retries
    -- that continuously create UObjects.
    if not g.fallbackAttempts[key] and g.targetMIDCount<M.MAX_TARGET_MIDS
        and read(mesh,'CreateDynamicMaterialInstance')~=nil then
        g.fallbackAttempts[key]=true;g.targetMIDCount=g.targetMIDCount+1
        local createdMID
        local ok,result=pcall(function()
            -- A MID cannot be the parent of another MID. Use the cooked base
            -- and transfer the verified sensor parameters explicitly.
            local asset=g.materialSpec
            local localMID=mesh:CreateDynamicMaterialInstance(slot,g.assets[asset.path],FName('ZoneFPVTarget'))
            createdMID=localMID
            assert(valid(localMID) and pin(g,localMID),'component material retention failed')
            record.localMIDs[slot]=localMID;g.localMaterials[address(localMID)]=localMID
            if asset.color_parameter then
                local key=FName(asset.color_parameter)
                local colour=g.material:K2_GetVectorParameterValue(key)
                localMID:SetVectorParameterValue(key,colour)
                local value=localMID:K2_GetVectorParameterValue(key)
                assert(value.R==colour.R and value.G==colour.G and value.B==colour.B,'component colour readback mismatch')
                if asset.intensity_parameter then
                    local scalar=FName(asset.intensity_parameter);local intensity=g.material:K2_GetScalarParameterValue(scalar)
                    localMID:SetScalarParameterValue(scalar,intensity)
                    assert(localMID:K2_GetScalarParameterValue(scalar)==intensity,'component luminance readback mismatch')
                end
            else
                for _,name in ipairs({asset.heat_parameter,asset.intensity_parameter})do
                    local key=FName(name);local value=g.material:K2_GetScalarParameterValue(key)
                    localMID:SetScalarParameterValue(key,value)
                    assert(localMID:K2_GetScalarParameterValue(key)==value,'component emission readback mismatch')
                end
            end
            if asset.texture_parameter then
                local key=FName(asset.texture_parameter);local white=g.material:K2_GetTextureParameterValue(key)
                localMID:SetTextureParameterValue(key,white)
                assert(same(localMID:K2_GetTextureParameterValue(key),white),'component texture readback mismatch')
            end
            return localMID
        end)
        actual=mesh:GetMaterial(slot)
        if ok and sensorMaterial(g,result) and sensorMaterial(g,actual)then
            -- Keep only verified instances in the bounded per-flight cache.
            -- Passive modes restore outfit slots; returning thermal reuses
            -- these pins instead of allocating another MID for the same slot.
            g.cachedMIDs[key]={mesh=mesh,material=result}
            g.cachedMaterialIds[address(result)]=true
            g.stats.localMIDs=g.stats.localMIDs+1
            once(g,'local-mid','component-owned sensor verified on '..materialName(mesh)..' slot='..slot
                ..' material='..materialName(actual))
            return
        end
        if valid(createdMID)then
            -- A failed parameter/retention verification must not leave its
            -- assigned MID active or pinned until a later actor cleanup.
            if same(actual,createdMID)then
                local original=record.originals[slot]
                if original==false then call(mesh,'SetMaterial',slot,nil)
                elseif valid(original)then call(mesh,'SetMaterial',slot,original)end
            end
            local id=address(createdMID);if id then g.localMaterials[id]=nil end
            release(g,createdMID);record.localMIDs[slot]=nil
            actual=mesh:GetMaterial(slot)
        end
        if not ok then once(g,'local-mid-error','component-owned material unavailable: '..tostring(result))end
    end
    error('SetMaterial readback mismatch: mesh='..materialName(mesh)..' slot='..slot
        ..' actual='..materialName(actual)..' parent='..materialName(read(actual,'Parent'))
        ..' expected='..materialName(g.material))
end
local function releaseLocalMID(g,material)
    local id=address(material)
    if id and g.cachedMaterialIds[id]then return end
    if id then g.localMaterials[id]=nil end
    release(g,material)
end
local function restoreMesh(g,record)
    if valid(record.mesh) then
        for slot,original in pairs(record.originals)do
            restoreSlot(g,record,slot,original)
        end
        if record.overlayOwned and valid(record.overlay)then
            local ok,overlay=pcall(function()return record.mesh:GetOverlayMaterial()end)
            if ok and nullMaterial(overlay)then call(record.mesh,'SetOverlayMaterial',record.overlay)end
        end
        restoreSecondaryPasses(g,record)
        if record.indirect~=nil then call(record.mesh,'SetAffectDynamicIndirectLighting',record.indirect)end
    end
    for _,original in pairs(record.originals)do release(g,original)end
    if record.overlay then release(g,record.overlay)end
    for _,material in pairs(record.localMIDs)do
        releaseLocalMID(g,material)
    end
    record.originals={}
    g.meshes[record.id]=nil
end
local function clearTargets(g)
    for _,record in pairs(g.meshes)do restoreMesh(g,record)end
    g.meshOrder={};g.actors={};g.actorOrder={};g.actorCount=0
    g.restoreCursor=0;g.actorCursor=0
end
function M.restore(s)
    local g=s.vision;if not g then return end
    if valid(g.illuminator)then call(g.illuminator,'K2_DestroyActor')end
    clearTargets(g)
    for _,cached in pairs(g.cachedMIDs)do release(g,cached.material)end
    g.cachedMIDs={};g.cachedMaterialIds={};g.localMaterials={}
    if g.lut then pcall(g.lut.destroy,g.lut)end
    local p=pp(g)
    if p then
        for key,field in pairs(g.fields)do pcall(function()
            if field.original.vector then
                local v=p[key];local o=field.original.vector;v.X,v.Y,v.Z,v.W=o.X,o.Y,o.Z,o.W
            else p[key]=field.original.value end
            p['bOverride_'..key]=field.override==true
        end)end
        pcall(unpin,g)
        pcall(function()g.camera.PostProcessBlendWeight=g.weight end)
    end
    s.vision=nil
end
local function illuminator(g,s)
    local gameplay=load(g,'/Script/Engine.Default__GameplayStatics')
    local class=load(g,'/Script/Engine.SpotLight')
    assert(valid(gameplay) and valid(class),'IR illuminator engine class unavailable')
    local transform=assert(call(s.camera,'GetTransform'),'IR camera transform unavailable')
    local actor=gameplay:BeginDeferredActorSpawnFromClass(s.camera,class,transform,1,s.camera,0)
    assert(valid(actor),'IR illuminator spawn failed');g.illuminator=actor
    local light=read(actor,'SpotLightComponent')
    if not valid(light)then light=read(actor,'LightComponent')end
    assert(valid(light),'IR spotlight component unavailable')
    light:SetMobility(2)
    light:SetIntensity(5000)
    light:SetAttenuationRadius(3500)
    light:SetInnerConeAngle(22)
    light:SetOuterConeAngle(48)
    light:SetCastShadows(true)
    gameplay:FinishSpawningActor(actor,transform,0)
    actor:SetActorEnableCollision(false)
    assert(actor:K2_AttachToActor(s.camera,FName('None'),2,2,2,false)~=false,'IR illuminator attach failed')
end
-- A daylight exposure can reduce an unlit value of 3 to near black. Sensor
-- targets are intentionally in the HDR range; bloom is disabled and mesh
-- indirect-light participation is suspended while the override is owned.
-- Keep headroom for pre-exposure and temporal reconstruction: the previous
-- 65536 already exceeded the largest finite FP16 channel (65504) before any
-- exposure gain. A clipped/Inf hot surface can contaminate neighbouring
-- history pixels; disabling bloom alone does not prevent that path.
M.TARGET_EMISSION=4096
local function prepareMaterial(g)
    if valid(g.material) and g.materialReady then return end
    if valid(g.material)then release(g,g.material);g.material=nil end
    -- Verified slot assignment alone does not flatten the coils shader. Use
    -- the RGB/luminance emitter with a uniform opaque white filter texture,
    -- rather than model-dependent coils or glTF colour/UV inputs.
    local spec=M.assets.uniform_emissive
    local parent=load(g,spec.path)
    if not valid(parent)then spec=M.assets.emissive_fallback;parent=load(g,spec.path)end
    if not valid(parent)then spec=M.assets.silhouette;parent=load(g,spec.path)end
    local library=load(g,'/Script/Engine.Default__KismetMaterialLibrary')
    assert(valid(parent) and valid(library),'skeletal sensor material unavailable')
    assert(read(parent,'bUsedWithSkeletalMesh')~=false,'sensor parent lacks cooked SkeletalMesh usage')
    local material=library:CreateDynamicMaterialInstance(g.world,parent,FName('ZoneFPVSensor'),0)
    assert(valid(material),'sensor material creation failed')
    assert(pin(g,material),'sensor material retention failed')
    g.material=material;g.materialSpec=spec
    if spec.texture_parameter then
        local white=load(g,spec.white_texture)
        assert(valid(white),'verified opaque white sensor texture unavailable')
        material:SetTextureParameterValue(FName(spec.texture_parameter),white)
        assert(same(material:K2_GetTextureParameterValue(FName(spec.texture_parameter)),white),
            'target opaque white filter texture readback mismatch')
        once(g,'texture','target texture readback '..spec.texture_parameter..'='..spec.white_texture)
    end
    g.materialReady=true
    once(g,'material','created target MID '..spec.path..'; mesh assignment not yet verified')
end
local function materialColour(g,spec)
    local material,asset=g.material,g.materialSpec
    if asset.color_parameter then
        local scale=asset.unit_color and 1 or M.TARGET_EMISSION
        local colour=spec.fusion and {R=scale,G=scale*256/M.TARGET_EMISSION,B=scale/M.TARGET_EMISSION,A=1}
            or {R=scale,G=scale,B=scale,A=1}
        material:SetVectorParameterValue(FName(asset.color_parameter),colour)
        local actual=material:K2_GetVectorParameterValue(FName(asset.color_parameter))
        assert(actual and math.abs(actual.R-colour.R)<1 and math.abs(actual.G-colour.G)<1
            and math.abs(actual.B-colour.B)<1,'target colour parameter readback mismatch')
        once(g,'parameter','target colour readback '..asset.color_parameter..'='..tostring(actual.R)..','..tostring(actual.G)..','..tostring(actual.B))
        if asset.intensity_parameter then
            local key=FName(asset.intensity_parameter)
            material:SetScalarParameterValue(key,M.TARGET_EMISSION)
            assert(math.abs(material:K2_GetScalarParameterValue(key)-M.TARGET_EMISSION)<1,'target luminance readback mismatch')
            once(g,'luminance','target luminance readback '..asset.intensity_parameter..'='..M.TARGET_EMISSION)
        end
    else
        material:SetScalarParameterValue(FName(asset.heat_parameter),1)
        material:SetScalarParameterValue(FName(asset.intensity_parameter),M.TARGET_EMISSION)
        assert(math.abs(material:K2_GetScalarParameterValue(FName(asset.heat_parameter))-1)<.001,
            'target heat parameter readback mismatch')
        assert(math.abs(material:K2_GetScalarParameterValue(FName(asset.intensity_parameter))-M.TARGET_EMISSION)<1,
            'target emission parameter readback mismatch')
        once(g,'parameter','target emission readback '..asset.heat_parameter..'=1 '
            ..asset.intensity_parameter..'='..M.TARGET_EMISSION)
    end
    if asset.color_parameter then
        local key=FName(asset.color_parameter);local colour=material:K2_GetVectorParameterValue(key)
        for _,localMID in pairs(g.localMaterials)do
            if valid(localMID)then
                localMID:SetVectorParameterValue(key,colour)
                if asset.intensity_parameter then
                    local scalar=FName(asset.intensity_parameter)
                    localMID:SetScalarParameterValue(scalar,M.TARGET_EMISSION)
                    assert(math.abs(localMID:K2_GetScalarParameterValue(scalar)-M.TARGET_EMISSION)<1,'cached luminance readback mismatch')
                end
            end
        end
    else
        for _,localMID in pairs(g.localMaterials)do
            if valid(localMID)then
                localMID:SetScalarParameterValue(FName(asset.heat_parameter),1)
                localMID:SetScalarParameterValue(FName(asset.intensity_parameter),M.TARGET_EMISSION)
                assert(math.abs(localMID:K2_GetScalarParameterValue(FName(asset.heat_parameter))-1)<.001
                    and math.abs(localMID:K2_GetScalarParameterValue(FName(asset.intensity_parameter))-M.TARGET_EMISSION)<1,
                    'cached component emission readback mismatch')
            end
        end
    end
end
local function commit(g,s,texture)
    local spec=g.spec
    if spec.thermal then prepareMaterial(g);materialColour(g,spec) else clearTargets(g)end
    if valid(g.illuminator)then call(g.illuminator,'K2_DestroyActor');g.illuminator=nil end
    g.committing=true
    local saturation=spec.fusion and 1 or 0
    set(g,'ColorSaturation',{X=saturation,Y=saturation,Z=saturation,W=1})
    set(g,'ColorContrast',{X=1,Y=1,Z=1,W=1})
    set(g,'AutoExposureBias',spec.exposure or 0)
    local gamma=spec.gamma or 1.1
    set(g,'ColorGamma',{X=gamma,Y=gamma,Z=gamma,W=1})
    set(g,'BloomIntensity',0);set(g,'MotionBlurAmount',0);set(g,'SceneFringeIntensity',0)
    set(g,'ColorGain',{X=1,Y=1,Z=1,W=1})
    set(g,'ColorGradingIntensity',texture and 1 or 0)
    if texture then set(g,'ColorGradingLUT',texture)end
    g.camera.PostProcessBlendWeight=1
    if spec.illuminator then
        local ready,why=pcall(illuminator,g,s)
        if not ready then
            if valid(g.illuminator)then call(g.illuminator,'K2_DestroyActor')end
            g.illuminator=nil;once(g,'illuminator',tostring(why)..'; passive NIR fallback')
        end
    end
    g.activeMode=g.mode;g.activeSpec=spec;g.appliedLUT=texture;g.pending=false
    g.committing=false
    g.log('Vision: mode '..g.mode..' committed with '..(texture and 'complete palette' or 'RGB scene'))
end
function M.apply(s,mode,log)
    if not modes.valid(mode)then return false,'invalid vision mode'end
    local prior=s.vision
    if prior and (not same(prior.world,s.world) or not same(prior.camera,read(s.camera,'CameraComponent')))then
        M.restore(s);prior=nil
    end
    if mode==0 then M.restore(s);return true end
    if prior and prior.mode==mode then return true end
    local camera=read(s.camera,'CameraComponent')
    if not valid(camera)then return false,'camera component unavailable'end
    local g=prior or {camera=camera,world=s.world,log=log or function()end,logged={},fields={},assets={},
        meshes={},meshOrder={},actors={},actorOrder={},actorCount=0,pins={},freePins={},releasedPins={},pinCount=0,
        lutPins={},cursor=0,restoreCursor=0,actorCursor=0,weight=read(camera,'PostProcessBlendWeight'),
        fallbackAttempts={},targetMIDCount=0,localMaterials={},cachedMIDs={},cachedMaterialIds={},beamMeshes={},beamCount=0,rejectedMeshes={},rejectedMeshCount=0,
        stats={candidates=0,scans=0,components=0,slots=0,rejected=0,reapplied=0,localMIDs=0,attachments=0,lateSlots=0,nullSlots=0,overlays=0}}
    s.vision=g;g.mode=mode;g.spec=modes.modes[mode];g.pending=true;g.lutFailed=false
    local ok,err=pcall(function()
        if g.spec.fusion then commit(g,s,nil);return end
        local warm=prewarmed
        if warm and warm.mode==mode and same(warm.world,s.world) and valid(warm.camera) and valid(warm.texture)then
            if not same(warm.texture,g.lutPins[mode])then
                assert(pin(g,warm.texture),'prepared palette retention failed')
                if g.lutPins[mode]then release(g,g.lutPins[mode])end
                g.lutPins[mode]=warm.texture
            end
            -- Own a separate engine reference, never the prewarm client. Exit
            -- can release this camera without closing the next flight's cache.
            commit(g,s,warm.texture);return
        end
        if not g.lut then
            local library=load(g,'/Script/Engine.Default__KismetRenderingLibrary')
            assert(valid(library),'palette rendering library unavailable')
            local factory=M.lut or dofile(here..'vision_lut.lua')
            g.lut=factory.new(s.world,library)
        end
        local texture,state=g.lut:texture(mode)
        if valid(texture)then commit(g,s,texture)
        elseif state~='pending' then error(state)
        else g.log('Vision: preparing mode '..mode..'; retaining previous camera image')end
    end)
    if not ok then
        if not prior or g.committing then M.restore(s)else g.pending=false;g.mode=g.activeMode or 0;g.spec=g.activeSpec end
        return false,tostring(err)
    end
    return true
end
local function near(s,e)
    local p=s.flight and s.flight.p;local q=e.position
    if not p or not q then return false end
    local px,py,pz=read(p,'x'),read(p,'y'),read(p,'z')
    local qx,qy,qz=read(q,'X'),read(q,'Y'),read(q,'Z')
    if not finite(px) or not finite(py) or not finite(pz) or not finite(qx) or not finite(qy) or not finite(qz) then return false end
    local x,y,z=qx-px*100,qy-py*100,qz-pz*100
    return x*x+y*y+z*z<=M.RANGE_CM^2
end
local function current(s,actor)
    return valid(actor) and same(call(actor,'GetWorld'),s.world) and not same(actor,s.pawn)
end
local function distanceSq(s,e)
    local p=s.flight.p;local q=e.position
    return (q.X-p.x*100)^2+(q.Y-p.y*100)^2+(q.Z-p.z*100)^2
end
local function restoreActor(g,id)
    for i=#g.meshOrder,1,-1 do
        local row=g.meshOrder[i]
        if row.actorId==id then restoreMesh(g,row);table.remove(g.meshOrder,i)end
    end
    if g.actors[id]then
        g.actors[id]=nil;g.actorCount=g.actorCount-1
        for i=#g.actorOrder,1,-1 do if g.actorOrder[i]==id then table.remove(g.actorOrder,i);break end end
    end
end
local function visitArray(a,limit,fn)
    local n=count(a)
    if not n then return end
    for i=1,math.min(n,limit)do fn(unwrap(a[i]))end
end
local function captureOriginals(g,mesh,n,existing,asset,kind)
    local originals={};local nulls=0
    local ok,why=pcall(function()
        for slot=0,n-1 do
            if not existing or existing[slot]==nil then
                local original=unwrap(mesh:GetMaterial(slot))
                if not valid(original)then assert(nullMaterial(original),'material readback unavailable at slot '..slot)end
                if not physicalSlot(g,mesh,slot,original,asset,kind)then
                    -- Keep optics, cards and intentionally empty sections in
                    -- their original state while capturing the physical body.
                elseif valid(original)then
                    assert(pin(g,original),'material retention limit reached')
                    originals[slot]=original
                else
                    -- False retains the verified body null for restoration.
                    originals[slot]=false;nulls=nulls+1
                end
            end
        end
    end)
    if not ok then
        for _,original in pairs(originals)do release(g,original)end
        once(g,'capture-originals',tostring(why)..'; component slots left intact')
        return
    end
    return originals,nulls
end
local function captureMesh(g,e,actorId,mesh,attachment)
    local id=address(mesh)
    if not id or g.meshes[id] then return end
    local asset,kind=physicalRenderer(g,mesh)
    if not asset or read(e.actor,'bHidden')==true then return end
    if (g.rejectedMeshes[id] or -math.huge)>(g.now or 0)then return end
    -- Hidden LOD parts are reconsidered by the actor scan when visible.
    g.stats.components=g.stats.components+1
    local ok,n=pcall(function()return mesh:GetNumMaterials()end)
    if not ok or not finite(n) or n%1~=0 or n<1 or n>M.MAX_SLOTS then
        once(g,'material-count','cannot capture component '..tostring(call(mesh,'GetFullName') or id)..': GetNumMaterials='..tostring(n))
        return
    end
    if #g.meshOrder>=M.MAX_MESHES then once(g,'mesh-cap','component safety limit reached; nearest actors are prioritized');return end
    local r={id=id,mesh=mesh,actor=e.actor,actorId=actorId,entry=e,localMIDs={},nextAudit=0}
    -- Capture the complete component before replacing any slot. Exhausting the
    -- retention budget must not leave a head/torso half hot and half original.
    local originals,nulls=captureOriginals(g,mesh,n,nil,asset,kind)
    if not originals or not next(originals)then return end
    r.originals=originals
    g.meshes[id]=r;g.meshOrder[#g.meshOrder+1]=r
    local indirect=read(mesh,'bAffectDynamicIndirectLighting')
    if type(indirect)=='boolean' then
        r.indirect=indirect
        local ok,why=pcall(function()
            mesh:SetAffectDynamicIndirectLighting(false)
            assert(read(mesh,'bAffectDynamicIndirectLighting')==false,'indirect-light flag readback mismatch')
        end)
        if not ok then once(g,'indirect-light','cannot suppress sensor indirect-light participation: '..tostring(why))end
    end
    local changed=0
    local ok,why=pcall(function()
        for slot in pairs(r.originals)do
            writeSensorSlot(g,r,slot)
            changed=changed+1
        end
        clearOverlay(g,r)
    end)
    if not ok then
        g.stats.rejected=g.stats.rejected+1
        restoreMesh(g,r);table.remove(g.meshOrder)
        if g.rejectedMeshes[id] or g.rejectedMeshCount<M.MAX_MESHES then
            if not g.rejectedMeshes[id]then g.rejectedMeshCount=g.rejectedMeshCount+1 end
            g.rejectedMeshes[id]=(g.now or 0)+5
        end
        once(g,'slot-failure','component replacement rejected: '..tostring(why))
        return
    end
    if g.rejectedMeshes[id]then g.rejectedMeshes[id]=nil;g.rejectedMeshCount=g.rejectedMeshCount-1 end
    holdSecondaryPasses(g,r)
    g.stats.slots=g.stats.slots+changed
    g.stats.nullSlots=g.stats.nullSlots+nulls
    if attachment then
        g.stats.attachments=g.stats.attachments+1
        once(g,'attachment','verified attachment-tree mesh '..materialName(mesh)..' slots='..changed)
    end
    once(g,'verified-slots','verified '..changed..' material slots on '..tostring(call(mesh,'GetFullName') or id)
        ..'; actor '..tostring(call(e.actor,'GetFullName') or actorId))
end
local function auditMesh(g,r,now)
    if now<r.nextAudit then return end
    r.nextAudit=now+.2
    local asset,kind=physicalRenderer(g,r.mesh)
    if not asset or read(r.actor,'bHidden')==true then return false end
    -- Mesh generation can add outfit material slots to the same component.
    -- Capture the whole new set before writing, just as for initial capture.
    local n=call(r.mesh,'GetNumMaterials')
    if finite(n) and n%1==0 and n>=1 and n<=M.MAX_SLOTS and now>=(r.nextSlotCapture or 0)then
        local added,nulls=captureOriginals(g,r.mesh,n,r.originals,asset,kind)
        if added and next(added)then
            for slot,original in pairs(added)do r.originals[slot]=original end
            local changed=0
            local ok,why=pcall(function()
                for slot in pairs(added)do writeSensorSlot(g,r,slot);changed=changed+1 end
            end)
            if ok then
                g.stats.slots=g.stats.slots+changed;g.stats.lateSlots=g.stats.lateSlots+changed
                g.stats.nullSlots=g.stats.nullSlots+nulls
                once(g,'late-slots','verified '..changed..' newly generated slots on '..materialName(r.mesh))
            else
                g.stats.rejected=g.stats.rejected+1
                for slot,original in pairs(added)do
                    restoreSlot(g,r,slot,original);release(g,original);r.originals[slot]=nil
                    local material=r.localMIDs[slot]
                    if material then
                        releaseLocalMID(g,material);r.localMIDs[slot]=nil
                    end
                end
                r.nextSlotCapture=now+5
                once(g,'late-slot-failure','new component slots rolled back: '..tostring(why))
            end
        elseif not added then r.nextSlotCapture=now+5 end
    end
    -- Appearance updates can replace an OverrideMaterial after we wrote it.
    -- Preserve the latest real material before re-applying the sensor; exit
    -- then restores the current outfit, rather than an obsolete old variant.
    for slot,original in pairs(r.originals)do
        local readOK,current=pcall(function()return unwrap(r.mesh:GetMaterial(slot))end)
        if readOK and (valid(current) or nullMaterial(current)) and not sensorMaterial(g,current)then
            if valid(current) and not same(current,original)then
                if not pin(g,current)then return end
                r.originals[slot]=current;release(g,original)
            elseif nullMaterial(current) and original~=false then
                r.originals[slot]=false;release(g,original)
            end
            if physicalSlot(g,r.mesh,slot,current,asset,kind)then
                local ok,why=pcall(function()writeSensorSlot(g,r,slot)end)
                if ok then g.stats.reapplied=g.stats.reapplied+1
                else once(g,'reapply-failure',tostring(why))end
            end
        end
    end
    local ok,why=pcall(clearOverlay,g,r)
    if not ok then once(g,'overlay-failure',tostring(why))end
    holdSecondaryPasses(g,r)
end
local function target(g,s,e,now)
    g.stats.candidates=g.stats.candidates+1
    if not e or e.expired or not finite(e.type) or e.type<1 or e.type>2 or not near(s,e) or not current(s,e.actor)then return end
    local id=address(e.actor);if not id then return end
    local tracked=g.actors[id]
    if tracked and now<tracked.nextScan then return end
    if not tracked and g.actorCount>=M.MAX_ACTORS then
        local farthest,farId=distanceSq(s,e)
        for actorId,row in pairs(g.actors)do
            local d=near(s,row.entry) and distanceSq(s,row.entry) or math.huge
            if d>farthest then farthest,farId=d,actorId end
        end
        if not farId then once(g,'actor-cap','target safety limit reached; nearest 96 actors retained');return end
        restoreActor(g,farId)
    end
    if not tracked then
        tracked={entry=e};g.actors[id]=tracked;g.actorCount=g.actorCount+1;g.actorOrder[#g.actorOrder+1]=id
    end
    tracked.nextScan=now+1
    g.stats.scans=g.stats.scans+1
    local class=load(g,'/Script/Engine.MeshComponent')
    local flashlightClass=load(g,'/Script/Stalker2.FlashlightComponent')
    local pending,seen={},{};local childReads=0
    local function enqueue(component)
        component=unwrap(component)
        local componentId=address(component)
        if not componentId or seen[componentId]then return end
        seen[componentId]=true
        if #pending>=M.MAX_COMPONENTS then once(g,'attachment-cap','component attachment scan limit reached');return end
        pending[#pending+1]=component
    end
    local function scan(actor)
        -- UFlashlightComponent names the exact renderer responsible for the
        -- headlamp cone. This avoids relying on an arbitrary cone mesh name.
        if valid(flashlightClass)then
            visitArray(call(actor,'K2_GetComponentsByClass',flashlightClass),32,function(light)
                local beam=unwrap(read(light,'FakeLightBeamComponent'));local beamId=address(beam)
                if beamId and not g.beamMeshes[beamId] and g.beamCount<M.MAX_MESHES then
                    g.beamMeshes[beamId]=beam;g.beamCount=g.beamCount+1
                    once(g,'flashlight-beam','retaining FakeLightBeamComponent '..materialName(beam))
                end
            end)
        end
        -- The root Mesh covers only part of modular humans. Components cover
        -- body, face, head, armour and secondary meshes on humans and mutants.
        local mesh=read(actor,'Mesh');captureMesh(g,e,id,mesh);enqueue(mesh)
        enqueue(read(actor,'RootComponent'))
        if valid(class)then
            local ok,components=pcall(function()return actor:K2_GetComponentsByClass(class)end)
            if ok then visitArray(components,96,function(mesh)captureMesh(g,e,id,mesh);enqueue(mesh)end)
            else once(g,'component-scan','K2_GetComponentsByClass: '..tostring(components))end
        end
    end
    scan(e.actor)
    local attached={}
    local returned=call(e.actor,'GetAttachedActors',attached,true,true)
    if count(returned)then attached=returned end
    visitArray(attached,32,function(actor)
        if current(s,actor) and not same(actor,s.camera)then scan(actor)end
    end)
    -- Actor ownership and actor attachment lists do not describe every
    -- generated clothing component. Walk the actual SceneComponent tree with
    -- zero-based child UFunctions instead of another temporary native array.
    for index=1,M.MAX_COMPONENTS do
        local component=pending[index];if not component then break end
        local owner=call(component,'GetOwner')
        if not valid(owner) or (current(s,owner) and not same(owner,s.camera))then
            if read(component,'GetNumMaterials')~=nil then captureMesh(g,e,id,component,true)end
            local children=call(component,'GetNumChildrenComponents')
            if finite(children) and children%1==0 and children>=0 and children<=2112 then
                for child=0,math.min(children,M.MAX_COMPONENTS)-1 do
                    if childReads>=M.MAX_COMPONENTS then once(g,'attachment-cap','component attachment scan limit reached');break end
                    childReads=childReads+1;enqueue(call(component,'GetChildComponent',child))
                end
            end
        end
    end
    return true
end
function M.update(s,now)
    local g=s.vision;if not g then return end
    g.now=now or 0
    if not same(g.world,s.world) or not same(g.camera,read(s.camera,'CameraComponent')) then M.restore(s);return end
    local started=M.clock()
    if g.pending and g.lut and not g.lutFailed then
        local ok,err=pcall(function()
            local tex,state,pending=g.lut:texture(g.mode)
            if not tex then
                local result,detail=g.lut:update()
                if result==nil then error(detail)end
                tex,state,pending=g.lut:texture(g.mode)
            end
            -- A zero-weight engine reference roots partially drawn textures
            -- without touching the active camera's LUT or colour settings.
            local held=tex or pending
            if valid(held) and not same(held,g.lutPins[g.mode])then
                assert(pin(g,held),'palette retention failed')
                if g.lutPins[g.mode]then release(g,g.lutPins[g.mode])end
                g.lutPins[g.mode]=held
            end
            if tex and valid(tex)then commit(g,s,tex)
            elseif state~='pending' then error(state)end
        end)
        if not ok then
            if g.committing then
                M.restore(s)
                g.log('Vision: profile activation failed; camera and targets restored: '..tostring(err))
                return
            end
            g.lutFailed=true;g.pending=false
            once(g,'lutFailed-'..g.mode,tostring(err)..'; previous camera image retained')
        end
    end
    if g.activeSpec and g.activeSpec.thermal and valid(g.material)then
        -- One modular actor scan per frame, with a small time budget. Classes
        -- are loaded once; there are no global object walks in this path.
        local entries=s.worldExperiments and s.worldExperiments.entries or {}
        local deadline=M.clock()+.001
        local rescan
        for _=1,math.min(16,#entries)do
            g.cursor=g.cursor%#entries+1
            local entry=entries[g.cursor]
            local id=address(read(entry,'actor'))
            local tracked=id and g.actors[id]
            -- Keep searching this bounded batch for a newly streamed target.
            -- Otherwise 96 scheduled re-scans can delay a new nearby actor by
            -- 96 frames even though it is already in the observation cache.
            if tracked then
                if (now or 0)>=tracked.nextScan then rescan=rescan or entry end
            else
                local ok,err=pcall(target,g,s,entry,now or 0)
                if not ok then once(g,'targetFailed','target mesh unavailable: '..tostring(err))end
                if ok and err==true then rescan=nil;break end
            end
            if M.clock()>=deadline then break end
        end
        if rescan then
            local ok,err=pcall(target,g,s,rescan,now or 0)
            if not ok then once(g,'targetFailed','target mesh unavailable: '..tostring(err))end
        end
        for _=1,math.min(4,#g.meshOrder)do
            g.restoreCursor=g.restoreCursor%#g.meshOrder+1
            local r=g.meshOrder[g.restoreCursor]
            if not current(s,r.actor) or not valid(r.mesh) or r.entry.expired or not near(s,r.entry)then
                restoreMesh(g,r);table.remove(g.meshOrder,g.restoreCursor);g.restoreCursor=g.restoreCursor-1
            elseif auditMesh(g,r,now or 0)==false then
                restoreMesh(g,r);table.remove(g.meshOrder,g.restoreCursor);g.restoreCursor=g.restoreCursor-1
            end
        end
        if (now or 0)>=(g.nextReport or 0)then
            g.nextReport=(now or 0)+5
            local st=g.stats
            g.log(string.format('Vision coverage: mode=%d cache=%d candidates=%d scans=%d actors=%d meshes=%d slotsVerified=%d rejected=%d reapplied=%d localMIDs=%d/%d attachments=%d lateSlots=%d nullSlots=%d overlays=%d',
                g.activeMode,#entries,st.candidates,st.scans,g.actorCount,#g.meshOrder,st.slots,st.rejected,st.reapplied,st.localMIDs,g.targetMIDCount,st.attachments,st.lateSlots,st.nullSlots,st.overlays))
        end
        -- Actor records contain no engine objects of their own, but must not
        -- accumulate forever when flying through a large streamed population.
        for _=1,math.min(4,#g.actorOrder)do
            if #g.actorOrder==0 then break end
            g.actorCursor=g.actorCursor%#g.actorOrder+1
            local id=g.actorOrder[g.actorCursor];local row=g.actors[id]
            if row.entry.expired or not near(s,row.entry) or not current(s,row.entry.actor)then restoreActor(g,id)end
        end
    end
    g.updateMs=(M.clock()-started)*1000;g.maxMs=math.max(g.maxMs or 0,g.updateMs)
end
return M
