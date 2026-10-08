-- Mirror only the pawn's environmental Niagara effects onto the FPV camera.
-- Native providers still own weather/activation. Leaf terrain inputs are rebased
-- to their camera component. The hidden pawn is never moved
-- or made visible here, and only our disposable components receive setters.
local M={}
local allowed={}
for _,name in ipairs({'NS_Dyn_Rain_Weather','NS_Dyn_Lightning_Weather','NS_Dyn_Lightning_2_Weather','NS_Dyn_Storm_Weather'}) do
    allowed['/Game/_Stalker_2/VFX/Environment/Rain/Niagara/'..name..'.'..name]=true
end
local leafPath='/Game/_Stalker_2/VFX/Player/NS_Leaves_Player.NS_Leaves_Player'
allowed[leafPath]=true
local function read(o,k) local ok,v=pcall(function()return o[k]end);if ok then return v end;return nil end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
    return nil
end
local function valid(o) return call(o,'IsValid')==true end
local function address(o) return valid(o) and call(o,'GetAddress') or nil end
local function assets(g,resolveMissing)
    local found={}
    for path in pairs(allowed) do
        local object=g.assets[path]
        if not valid(object) and resolveMissing then
            local ok,value=pcall(StaticFindObject,path)
            object=ok and value or nil;g.assets[path]=object
        end
        local id=address(object)
        if id then found[id]=path end
    end
    return found
end
local function measured(g,key,started)
    local elapsed=((M.clock or os.clock)()-started)*1000
    g.performance[key..'Ms']=elapsed
    g.performance[key..'MaxMs']=math.max(g.performance[key..'MaxMs'] or 0,elapsed)
end
local function kind(o) return call(o,'type') or type(o) end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function name(v)
    if type(v)=='string' then return v end
    if kind(v)=='FName' then return call(v,'ToString') end
end
local function point(v)
    local x,y,z=read(v,'X'),read(v,'Y'),read(v,'Z')
    if finite(x) and finite(y) and finite(z) then return {X=x,Y=y,Z=z} end
end
local function signature(v)
    local index=read(read(v,'TypeDefHandle'),'RegisteredTypeIndex')
    if finite(index) and index>=0 and index%1==0 then return 'index:'..index end
    for _,field in ipairs({'TypeDef','TypeDef_DEPRECATED'}) do
        local object=read(read(v,field),'ClassStructOrEnum')
        local id=address(object)
        if id then return 'object:'..tostring(id) end
    end
end
local function count(a)
    local n=call(a,'GetArrayNum')
    if kind(a)=='table' then n=#a end
    if finite(n) and n>=0 and n%1==0 then return n end
end
local function variables(component)
    local store=read(component,'OverrideParameters')
    local offsets=read(store,'SortedParameterOffsets');local n=count(offsets)
    if not n or n>64 then error('Niagara parameter layout unavailable or exceeds 64 entries') end
    local result={}
    -- UE4SS indexing is ONE based. Never read past Num: even a native READ
    -- outside the range can expand a TArray. Do not use its ForEach callback.
    for i=1,n do
        local v=offsets[i]
        local t=kind(v)
        if t=='LocalUnrealParam' or t=='RemoteUnrealParam' then v=call(v,'get') end
        local text=name(read(v,'Name'));local offset=read(v,'Offset')
        if type(text)=='string' and finite(offset) and offset>=0 and offset%1==0 then
            local sig=signature(v)
            local detail=not sig and ('TypeDefHandle='..tostring(kind(read(v,'TypeDefHandle')))..', TypeDef='..
                tostring(kind(read(v,'TypeDef')))..', TypeDef_DEPRECATED='..tostring(kind(read(v,'TypeDef_DEPRECATED'))))
            result[#result+1]={name=text,key=FName(text),offset=offset,signature=sig,typeDetail=detail}
        end
    end
    return result,read(store,'ParameterData')
end
local function worldPositions(component,required)
    local positions=read(read(component,'OverrideParameters'),'OriginalPositionData')
    local n=count(positions)
    if not n then
        if required then error('Niagara semantic world position list unavailable') end
        return
    end
    if n>64 then error('Niagara world position list exceeds 64 entries') end
    local values={}
    for i=1,n do
        local v=positions[i];local t=kind(v)
        if t=='LocalUnrealParam' or t=='RemoteUnrealParam' then v=call(v,'get') end
        local text=name(read(v,'Name'));local value=point(read(v,'Value'))
        if type(text)~='string' or not value then error('Niagara world position entry unavailable') end
        if text:sub(1,5)~='User.' then text='User.'..text end
        values[text]=value
    end
    return values
end
local function bytes(data,n,offset,size)
    if not n or offset<0 or offset%1~=0 or offset+size>n then error('Niagara byte range outside ParameterData') end
    local out={}
    for i=offset+1,offset+size do
        local value=data[i]
        if not finite(value) or value%1~=0 or value<0 or value>255 then error('Niagara data is not a byte array') end
        out[#out+1]=string.char(value)
    end
    return table.concat(out)
end
local probes={
    {tag='Float',method='SetVariableFloat',value=.375,size=4,format='<f'},
    {tag='Int',method='SetVariableInt',value=73,size=4,format='<i4'},
    {tag='Bool',method='SetVariableBool',value=true,size=4,format='<i4'},
    {tag='Vec3',method='SetVariableVec3',value={X=1.25,Y=-2.5,Z=3.75},size=12,format='<fff'},
    {tag='Position',method='SetVariablePosition',value={X=11.25,Y=22.5,Z=33.75},size=12,format='<fff'}
}
local function calibrate(component)
    local markers={}
    for _,p in ipairs(probes) do
        local key='User.ZoneFPVType'..p.tag
        component[p.method](component,FName(key),p.value);markers[key]=p
    end
    local vars,data=variables(component);local n=count(data);local types={};local found=0;local alias=false
    for _,v in ipairs(vars) do
        local p=markers[v.name]
        if p then
            if not v.signature then
                error('Niagara type registry unavailable or ambiguous for '..v.name..' ('..tostring(v.typeDetail or v.signature)..')')
            end
            if p.size then
                local a,b,c=string.unpack(p.format,bytes(data,n,v.offset,p.size))
                if p.tag=='Vec3' or p.tag=='Position' then
                    if a~=p.value.X or b~=p.value.Y or c~=p.value.Z then error('Niagara '..p.tag..' layout mismatch') end
                elseif p.tag=='Bool' then
                    if a==0 then error('Niagara bool layout mismatch') end
                elseif a~=p.value then error('Niagara scalar layout mismatch') end
            end
            local previous=types[v.signature]
            if previous then
                if (previous.tag=='Vec3' and p.tag=='Position') or (previous.tag=='Position' and p.tag=='Vec3') then
                    -- Some UE builds convert Position to Vector3 in the storage
                    -- schema. Preserve the verified vector decoder; semantic
                    -- positions are identified separately by OriginalPositionData.
                    local vector=previous.tag=='Vec3' and previous or p
                    types[v.signature]={tag='Vec3',method=vector.method,size=vector.size,format=vector.format,
                        positionMethod='SetVariablePosition'}
                    alias=true
                else
                    error('Niagara type collision '..previous.tag..' / '..p.tag..' ('..v.signature..')')
                end
            else types[v.signature]=p end
            found=found+1
        end
    end
    if found~=#probes then error('Niagara calibration markers missing') end
    local detail='distinct native types'
    if alias then
        local positions=worldPositions(component,true);local names={}
        for text in pairs(positions) do names[#names+1]=text end
        table.sort(names)
        -- Marker membership can differ on this build before activation. Both
        -- APIs have independently passed the byte-value check above. Actual
        -- SOURCE metadata, not assumptions about marker membership, decides
        -- which inputs must be copied as semantic world positions.
        detail='validated Position/Vec3 storage alias; clone world-position names='..
            (#names>0 and table.concat(names,',') or '(empty)')
    end
    return types,detail
end
local function destroy(e)
    if valid(e.clone) then
        pcall(function() e.clone:Deactivate() end)
        pcall(function() e.clone:K2_DestroyComponent(e.owner) end)
    end
    e.clone=nil
end
local function report(g,text,log)
    if #g.report>=30 then return end
    g.report[#g.report+1]=text
    if log then log('FPV particles: '..text) end
    local file=io.open(g.root..'particle-mirror.txt','w')
    if file then file:write(table.concat(g.report,'\n')..'\n');file:close() end
end
local function create(g,s,source,asset,path)
    local location=point(call(source,'K2_GetComponentLocation'))
    local pawnLocation=point(call(s.pawn,'K2_GetActorLocation'))
    if not location or not pawnLocation then error('weather component location unavailable') end
    local origin=s.origin;local entry=s.npcAnchor and s.npcAnchor.position or pawnLocation
    local head={X=origin.x*100-entry.X,Y=origin.y*100-entry.Y,Z=origin.z*100-entry.Z}
    local offset={X=location.X-pawnLocation.X-head.X,Y=location.Y-pawnLocation.Y-head.Y,Z=location.Z-pawnLocation.Z-head.Z}
    local leaf=path==leafPath
    -- Native leaves are not root-attached (PlayerHeadOffset=0). Their last
    -- world location can lag behind the underground pawn. Never bake that
    -- separation into the camera clone as a permanent 50 m offset.
    if leaf then offset={X=0,Y=0,Z=0} end
    local e={source=source,asset=asset,assetId=asset:GetAddress(),offset=offset,path=path,lastValues={},
        leaf=leaf,sourceStartZ=location.Z,anchorEntryZ=s.npcAnchor and entry.Z,
        anchorDepth=s.npcAnchor and entry.Z-pawnLocation.Z}
    -- A camera-owned component is visible even while the real pawn is hidden.
    -- Pooling=None, AutoDestroy=false: there is exactly one owned instance per
    -- live native weather asset, destroyed on exit/weather replacement.
    e.clone=g.library:SpawnSystemAttached(asset,s.camera.CameraComponent,FName('None'),{X=0,Y=0,Z=0},
        {Pitch=0,Yaw=0,Roll=0},2,false,false,0,false)
    if not valid(e.clone) then error('camera weather spawn failed') end
    e.owner=call(e.clone,'GetOwner')
    if not valid(e.owner) or e.owner:GetAddress()~=s.camera:GetAddress() then
        destroy(e);error('weather clone is not owned by the camera')
    end
    local ok,err=pcall(function()
        -- These objects belong only to this FPV session. Never clear hidden
        -- flags on the real pawn or its original weather/equipment components.
        if read(s.camera,'bHidden')==true then s.camera:SetActorHiddenInGame(false) end
        if read(e.clone,'bHiddenInGame')==true then e.clone:SetHiddenInGame(false,false) end
        if read(e.clone,'bUseAttachParentBound')==true then e.clone.bUseAttachParentBound=false end
        e.clone:SetAbsolute(true,true,true)
        e.clone:K2_SetWorldRotation({Pitch=0,Yaw=0,Roll=0},false,{},true)
        e.clone:SetVisibility(true,false)
        if leaf then
            -- The cooked player leaf system uses NET_Mutants and distance
            -- significance. A generic camera component is not automatically
            -- classified like the original player-owned environmental effect.
            -- Override culling for this single disposable leaf instance only;
            -- retain normal batching, native activation and every other effect.
            e.render={sourceScalability=call(source,'GetAllowScalability'),
                initialScalability=call(e.clone,'GetAllowScalability'),
                sourceLocalPlayer=call(source,'GetForceLocalPlayerEffect')}
            if type(call(e.clone,'GetForceLocalPlayerEffect'))=='boolean' then
                e.render.localPlayerSet=pcall(function()e.clone:SetForceLocalPlayerEffect(true)end)
            end
            if type(e.render.initialScalability)=='boolean' then
                e.render.scalabilitySet=pcall(function()e.clone:SetAllowScalability(false)end)
            end
            e.render.localPlayer=call(e.clone,'GetForceLocalPlayerEffect')
            e.render.scalability=call(e.clone,'GetAllowScalability')
        end
        if not g.types then g.types,g.calibrationDetail=calibrate(e.clone) end
    end)
    if not ok then destroy(e);error(err) end
    return e
end
local function layout(g,e)
    local vars=variables(e.source);local descriptors={};local target
    local alias=false;for _,p in pairs(g.types) do if p.positionMethod then alias=true;break end end
    local positions=worldPositions(e.source,alias)
    for _,v in ipairs(vars) do
        if v.name:sub(1,5)=='User.' then
            local p=v.signature and g.types[v.signature]
            if v.name=='User.AttractorPosition' then
                if not p or (p.tag~='Position' and p.tag~='Vec3') then error('AttractorPosition has an unsupported native type') end
                target={key=v.key,method=(positions and positions[v.name] and p.positionMethod) or p.method}
            elseif positions and positions[v.name] then
                if not p or (p.tag~='Position' and not p.positionMethod) then error('unverified weather position '..v.name) end
                v.type={tag='Position',method='SetVariablePosition'};descriptors[#descriptors+1]=v
            elseif p and p.tag~='Position' then
                v.type=p;descriptors[#descriptors+1]=v
            elseif p and p.tag=='Position' then error('unhandled weather world position '..v.name)
            elseif not p then error('unsupported weather input '..v.name..' ('..tostring(v.signature)..')') end
        end
    end
    if not target and not e.leaf then
        error('weather asset has no verified AttractorPosition input')
    end
    e.parameters=descriptors;e.target=target;e.worldPositions=positions
    local detail={};for _,v in ipairs(descriptors) do detail[#detail+1]=v.name..':'..v.type.tag end
    return 'AttractorPosition='..(target and target.method or 'component world transform')..'; '..table.concat(detail,', ')
end
local function leafTerrain(e,raw,sourceZ,cloneZ)
    if not e.terrain then
        local reference=e.sourceStartZ;local estimated=false
        -- Discovery may run after anchoring. An outdoor leaf already below
        -- the entry level with a small pre-anchor distance is a stale first
        -- sample. Use the known pawn displacement until its provider catches up.
        if e.anchorDepth and e.anchorDepth>2000 and reference<e.anchorEntryZ-2000 and math.abs(raw)<2000 then
            reference=reference+e.anchorDepth;estimated=true
        end
        e.terrain={raw=raw,sourceZ=reference,groundZ=reference+raw,estimated=estimated}
    end
    local t=e.terrain
    local dz=sourceZ-t.sourceZ
    -- After a large vertical rebase, an old provider value must not move the
    -- inferred surface underground. A fresh distance changes by the opposite
    -- amount. Ordinary terrain changes continue to come from the native provider.
    if math.max(math.abs(dz),math.abs(raw-t.raw))<=2000 or math.abs(raw-t.raw+dz)<=500 then
        t.raw=raw;t.sourceZ=sourceZ;t.groundZ=sourceZ+raw;t.estimated=false
    end
    return t.groundZ-cloneZ
end
local function sync(e,position)
    local store=read(e.source,'OverrideParameters');local data=read(store,'ParameterData');local n=count(data)
    local sourcePosition
    if e.leaf then
        sourcePosition=point(call(e.source,'K2_GetComponentLocation'))
        if not sourcePosition then error('leaf source world location unavailable') end
        e.sourceZ=sourcePosition.Z
    end
    for _,v in ipairs(e.parameters) do
        local p=v.type;local raw,value
        if p.tag=='Position' then
            value=e.worldPositions and e.worldPositions[v.name]
            if not value then error('weather world position disappeared') end
            raw=string.pack('<ddd',value.X,value.Y,value.Z)
        else
            raw=bytes(data,n,v.offset,p.size)
            if e.leaf and v.name=='User.TerrainOffset' then
                if p.tag~='Float' then error('leaf terrain offset is not a verified float') end
                local native=string.unpack(p.format,raw)
                if not finite(native) then error('non-finite leaf terrain offset') end
                e.nativeTerrain=native
                raw=string.pack(p.format,leafTerrain(e,native,sourcePosition.Z,position.Z+e.offset.Z))
            end
        end
        if e.lastValues[v.name]~=raw then
            if p.tag~='Position' then
                local a,b,c=string.unpack(p.format,raw);value=a
                if p.tag=='Vec3' then
                    if not finite(a) or not finite(b) or not finite(c) then error('non-finite Niagara wind vector') end
                    value={X=a,Y=b,Z=c}
                elseif p.tag=='Bool' then value=a~=0
                elseif not finite(a) then error('non-finite Niagara scalar') end
            end
            e.clone[p.method](e.clone,v.key,value);e.lastValues[v.name]=raw
        end
    end
end
local function discover(g,s,components,entries)
    local started=(M.clock or os.clock)()
    local candidates={};local checked=0;local sources={};local sourceAssets={};local newAsset=false
    -- Resolve only known templates. UObject/FField name conversion traverses
    -- native outer chains, so it must never identify live particle providers.
    local pawnId=address(s.pawn)
    if not pawnId then return candidates end
    for _,entry in pairs(components) do
        checked=checked+1;if checked>64 then break end
        local c=entry.object
        if valid(c) and entry.flags.bVisible==true then
            local owner=call(c,'GetOwner')
            if address(owner)==pawnId then
                local asset=call(c,'GetAsset');local assetId=address(asset)
                if assetId then
                    sourceAssets[assetId]=true
                    if not (g.known and g.known[assetId]) and not (g.sourceAssets and g.sourceAssets[assetId]) then
                        newAsset=true
                    end
                    sources[#sources+1]={source=c,asset=asset,id=assetId}
                end
            end
        end
    end
    -- StaticFindObject traverses the global UObject collection when a fixed
    -- path is absent. Repeating these missing rain/lightning lookups on every
    -- component scan adds global searches to flight callbacks. Try at entry,
    -- then when a newly observed native template may have loaded. Permit one
    -- follow-up for lookup registration lag, never continuous missing-path
    -- polling. The previous source
    -- set is bounded by the same 64-component inspection cap.
    local lookupStarted=(M.clock or os.clock)()
    local known=assets(g,not g.assetsResolved or newAsset or g.retryMissing)
    g.retryMissing=false
    if newAsset then
        for id in pairs(sourceAssets) do if not known[id] then g.retryMissing=true;break end end
    end
    g.assetsResolved=true;g.sourceAssets=sourceAssets;g.known=known
    measured(g,'lookup',lookupStarted)
    for _,item in ipairs(sources) do
        local c,asset=item.source,item.asset;local path=known[item.id]
        if path then
            local existing=entries[path]
            local retained=existing and valid(existing.source) and existing.source:GetAddress()==c:GetAddress()
                and existing.assetId==asset:GetAddress()
            local active=call(c,'IsActive')==true
            local selected=candidates[path]
            local score=(active and 2 or 0)+(retained and 1 or 0)
            -- Several native components can use the same template. Choose
            -- once per discovery; never destroy a running mirror for every
            -- duplicate encountered in an unordered component collection.
            if not selected or score>selected.score then
                candidates[path]={source=c,asset=asset,score=score}
            end
        end
    end
    measured(g,'discovery',started)
    return candidates
end
function M.update(s,now,root,log)
    local visibility=s.playerVisibility
    if not visibility or not valid(s.camera) then return end
    local g=s.fpvParticles
    if not g then
        g={root=root,entries={},assets={},failed={},report={},performance={},nextUpdate=0,nextParameters=0};s.fpvParticles=g
        report(g,'Camera weather mirror v11 initialized; cached template discovery, waiting for native environmental components',log)
        if M.worldLeaves then M.worldLeaves.start(s,root,log,now) end
    end
    if g.disabled or now<g.nextUpdate then return end
    g.nextUpdate=now+.1
    if not g.library then
        g.library=StaticFindObject('/Script/Niagara.Default__NiagaraFunctionLibrary')
        if not valid(g.library) then g.disabled=true;report(g,'Niagara library unavailable',log);return end
    end
    -- Reuse the existing bounded pawn component discovery; never enumerate
    -- world objects or find the player controller in a particle callback.
    if g.scanStamp~=visibility.nextScan then
        g.scanStamp=visibility.nextScan
        local candidates=discover(g,s,visibility.components,g.entries)
        for path,candidate in pairs(candidates) do
            local c,asset=candidate.source,candidate.asset;local e=g.entries[path]
            if e and (e.assetId~=asset:GetAddress() or not valid(e.clone)) then
                destroy(e);g.entries[path]=nil;e=nil
            end
            if e then
                if not valid(e.source) or e.source:GetAddress()~=c:GetAddress() then
                    -- A pooled provider can hand over the same template. Keep
                    -- its running camera simulation and coherent terrain basis;
                    -- only the verified input source changes, never its age.
                    e.source=c
                    if e.leaf and not e.terrain then
                        local p=point(call(c,'K2_GetComponentLocation'))
                        if p then e.sourceStartZ=p.Z end
                    end
                    g.nextParameters=0
                    report(g,path..' source changed; retained running camera effect',log)
                end
            elseif not g.failed[path] then
                local created
                local ok,err=pcall(function()
                    created=create(g,s,c,asset,path)
                    if created.leaf then created.statusAt=now+5;created.statusRemaining=2 end
                    local detail=layout(g,created);g.entries[path]=created
                    report(g,path..' ready; '..g.calibrationDetail..'; '..detail,log)
                    if created.render then
                        local r=created.render
                        report(g,'Leaves culling: source_scalability='..tostring(r.sourceScalability)..
                            '; clone_scalability_before='..tostring(r.initialScalability)..
                            '; clone_scalability_after='..tostring(r.scalability)..
                            '; scalability_set='..tostring(r.scalabilitySet)..
                            '; source_force_local_player='..tostring(r.sourceLocalPlayer)..
                            '; clone_force_local_player='..tostring(r.localPlayer)..
                            '; local_player_set='..tostring(r.localPlayerSet),log)
                    end
                end)
                if not ok then
                    if created then destroy(created) end
                    g.failed[path]=true;report(g,path..' disabled: '..tostring(err),log)
                end
            end
        end
        for path,e in pairs(g.entries) do if not candidates[path] then destroy(e);g.entries[path]=nil end end
    end
    local copyValues=now>=g.nextParameters
    if copyValues then g.nextParameters=now+.2 end
    local pos=s.flight and s.flight.p
    if not pos then return end
    local position={X=pos.x*100,Y=pos.y*100,Z=pos.z*100}
    local copyStarted=(M.clock or os.clock)()
    for path,e in pairs(g.entries) do
        local retired=false
        local ok,err=pcall(function()
            if not valid(e.source) or not valid(e.clone) then retired=true;error('weather component expired') end
            local owner=call(e.source,'GetOwner');local asset=call(e.source,'GetAsset')
            if not valid(owner) or owner:GetAddress()~=s.pawn:GetAddress() or not valid(asset) or asset:GetAddress()~=e.assetId then
                retired=true;error('native weather component reused')
            end
            local active
            if copyValues then
                -- Refresh offsets after native providers change their layout.
                layout(g,e);sync(e,position)
                active=call(e.source,'IsActive')
                if type(active)~='boolean' then error('native weather activation unavailable') end
            end
            if e.x~=position.X or e.y~=position.Y or e.z~=position.Z then
                e.clone:K2_SetWorldLocation({X=position.X+e.offset.X,Y=position.Y+e.offset.Y,Z=position.Z+e.offset.Z},false,{},true)
                -- Positions are set in WORLD centimetres. Do not decode/copy a
                -- source Position buffer: Niagara may store it in a local LWC tile.
                if e.target then e.clone[e.target.method](e.clone,e.target.key,position) end
                e.x=position.X;e.y=position.Y;e.z=position.Z
            end
            if active~=nil and active~=e.active then
                if active then e.clone:Activate(false) else e.clone:Deactivate() end
                e.active=active
                local controls={}
                for _,v in ipairs(e.parameters) do
                    if v.type.tag=='Float' or v.type.tag=='Int' or v.type.tag=='Bool' then
                        local raw=e.lastValues[v.name]
                        if raw then controls[#controls+1]=v.name..'='..tostring((string.unpack(v.type.format,raw))) end
                    end
                end
                report(g,path..' native_active='..tostring(active)..'; mirror_active='..tostring(call(e.clone,'IsActive'))..
                    '; owner_hidden='..tostring(read(e.owner,'bHidden'))..'; visible='..tostring(read(e.clone,'bVisible'))..
                    '; component_hidden='..tostring(read(e.clone,'bHiddenInGame'))..'; '..table.concat(controls,', '),log)
            end
            if e.leaf and (not e.positionReported or (e.statusRemaining>0 and now>=e.statusAt)) then
                if e.positionReported then e.statusRemaining=e.statusRemaining-1;e.statusAt=now+10 end
                e.positionReported=true
                local clonePosition=point(call(e.clone,'K2_GetComponentLocation'))
                local terrain=e.lastValues['User.TerrainOffset']
                report(g,'Leaves coordinates: sourceZ='..tostring(e.sourceZ)..'; cloneZ='..
                    tostring(clonePosition and clonePosition.Z)..'; nativeTerrainOffset='..tostring(e.nativeTerrain)..
                    '; cameraTerrainOffset='..tostring(terrain and string.unpack('<f',terrain))..
                    '; groundZ='..tostring(e.terrain and e.terrain.groundZ)..'; native_active='..tostring(e.active)..
                    '; ground_estimated='..tostring(e.terrain and e.terrain.estimated)..
                    '; paused='..tostring(call(e.clone,'IsPaused'))..'; complete='..tostring(call(e.clone,'IsComplete'))..
                    '; allow_scalability='..tostring(call(e.clone,'GetAllowScalability'))..
                    '; mirror_active='..tostring(call(e.clone,'IsActive')),log)
            end
        end)
        if not ok then
            destroy(e);g.entries[path]=nil;g.failed[path]=not retired
            -- Pool retirement is a normal provider lifecycle. Rediscover at the
            -- next existing component scan; schema failures remain disabled so
            -- unsupported effects cannot enter a spawn/fail loop.
            report(g,path..(retired and ' retired: ' or ' disabled: ')..tostring(err),log)
        end
    end
    measured(g,'copy',copyStarted)
    if M.worldLeaves then M.worldLeaves.update(s,now,log) end
end
function M.restore(s)
    if M.worldLeaves then M.worldLeaves.restore(s) end
    local g=s.fpvParticles;if not g then return end
    for _,e in pairs(g.entries) do destroy(e) end
    s.fpvParticles=nil
end
return M
