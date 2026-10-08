-- Preserve nearby native leaves and ambient crows while the pawn is underground.
-- One bounded discovery at entry; no spawns, activation overrides or frame scans.
local M={}
local allowed={}
for i=1,3 do
    local name='NS_GroundLeaves_'..i
    allowed['/Game/_Stalker_2/VFX/Environment/Leaves/'..name..'.'..name]='leaves'
end
allowed['/Game/_Stalker_2/VFX/Player/NS_Character_Crow.NS_Character_Crow']='crows'
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
    return nil
end
local function valid(o)return call(o,'IsValid')==true end
local function address(o)return valid(o) and call(o,'GetAddress') or nil end
local function same(a,b)
    local id=address(a);return id~=nil and id==address(b)
end
local function assets()
    local found={}
    for path in pairs(allowed) do
        local ok,object=pcall(StaticFindObject,path)
        local id=ok and address(object)
        if id then found[id]={object=object,path=path} end
    end
    return found
end
local function path(known,asset)
    local id=address(asset);local entry=id and known[id]
    return entry and same(entry.object,asset) and entry.path or nil
end
local function current(s,e)
    return valid(e.object) and same(call(e.object,'GetWorld'),s.world)
        and same(call(e.object,'GetOwner'),e.owner) and same(call(e.object,'GetAsset'),e.asset)
end
local function lodAvailable()
    -- Check only the fixed UFunction. UE4SS rejects a wrong argument count
    -- before ProcessEvent; enumerating its FFields for their names is unsafe.
    local ok,fn=pcall(StaticFindObject,'/Script/Niagara.NiagaraComponent:SetPreviewLODDistance')
    return ok and valid(fn)
end
local function lodDistance(e,position)
    if e.previewUnsupported then return end
    if not position or type(position.x)~='number' or type(position.y)~='number' or type(position.z)~='number' then return end
    local p=call(e.object,'K2_GetComponentLocation')
    if not p or type(p.X)~='number' or type(p.Y)~='number' or type(p.Z)~='number' then return end
    local distance=math.sqrt((p.X-position.x*100)^2+(p.Y-position.y*100)^2+(p.Z-position.z*100)^2)
    if distance~=distance or distance==math.huge then return end
    if not e.previewApplied or math.abs(distance-e.previewApplied)>=50 then
        if not valid(e.object) then return end
        e.previewOwned=true
        local ok=pcall(function()e.object:SetPreviewLODDistance(true,distance)end)
        local enabled=ok and call(e.object,'GetPreviewLODDistanceEnabled')
        local applied=ok and call(e.object,'GetPreviewLODDistance')
        if enabled==true and type(applied)=='number' and applied==applied
            and math.abs(applied-distance)<=math.max(.01,distance*.000001) then
            e.previewApplied=applied
        else
            e.previewUnsupported=true
            -- A callable setter is insufficient evidence that it took effect.
            -- Restore an ignored/inconsistent successful call immediately.
            if ok and valid(e.object) then
                pcall(function()e.object:SetPreviewLODDistance(e.previewEnabled,e.previewDistance)end)
            end
        end
    end
end
local function report(g,text,log)
    if #g.report>=10 then return end
    g.report[#g.report+1]=text
    if log then log('World particles: '..text) end
    local file=io.open(g.root..'leaf-world.txt','w')
    if file then file:write(table.concat(g.report,'\n')..'\n');file:close() end
end
function M.start(s,root,log,now)
    if s.worldLeaves or not valid(s.world) or not s.origin then return end
    local g={root=root,entries={},counts={leaves=0,crows=0},report={},statusAt=now+5,statusRemaining=2,
        lodAt=now+1,previewSupported=lodAvailable(),assets=assets()};s.worldLeaves=g
    local checked=0
    local ok,err=pcall(function()
        local objects=FindAllOf('DynamicEnvironmentNiagaraComponent')
        if objects==nil then return end
        if type(objects)~='table' then error('native component list is not a Lua table') end
        for _,c in pairs(objects) do
            checked=checked+1;if checked>32 or #g.entries>=6 then break end
            if valid(c) and same(call(c,'GetWorld'),s.world) then
                local owner=call(c,'GetOwner');local asset=call(c,'GetAsset')
                local assetPath=path(g.assets,asset);local kind=allowed[assetPath]
                if valid(owner) and not same(owner,s.pawn) and kind and g.counts[kind]<3 then
                    local p=call(c,'K2_GetComponentLocation')
                    local x,y,z=p and p.X,p and p.Y,p and p.Z
                    if type(x)=='number' and type(y)=='number' and type(z)=='number' and
                        (x-s.origin.x*100)^2+(y-s.origin.y*100)^2+(z-s.origin.z*100)^2<=10000^2 then
                        local e={object=c,owner=owner,asset=asset,path=assetPath,kind=kind,
                            scalability=call(c,'GetAllowScalability'),localPlayer=call(c,'GetForceLocalPlayerEffect'),
                            previewEnabled=call(c,'GetPreviewLODDistanceEnabled'),previewDistance=call(c,'GetPreviewLODDistance')}
                        e.previewEligible=g.previewSupported and type(e.previewEnabled)=='boolean' and type(e.previewDistance)=='number'
                            and e.previewDistance==e.previewDistance and math.abs(e.previewDistance)<math.huge
                        -- Capture before either setter so rollback also covers a
                        -- partial native call failure. Never change shared assets.
                        g.entries[#g.entries+1]=e
                        g.counts[kind]=g.counts[kind]+1
                        if type(e.scalability)=='boolean' and e.scalability then
                            e.scalabilityOwned=true;c:SetAllowScalability(false)
                        end
                        if type(e.localPlayer)=='boolean' and not e.localPlayer then
                            e.localPlayerOwned=true;c:SetForceLocalPlayerEffect(true)
                        end
                        if e.previewEligible then
                            lodDistance(e,s.origin)
                        end
                        report(g,e.kind..': '..e.path..'; active='..tostring(call(c,'IsActive'))..
                            '; scalability_before='..tostring(e.scalability)..
                            '; scalability_after='..tostring(call(c,'GetAllowScalability'))..
                            '; force_local_player='..tostring(call(c,'GetForceLocalPlayerEffect'))..
                            '; camera_LOD_cm='..tostring(e.previewApplied),log)
                    end
                end
            end
        end
    end)
    report(g,'Entry discovery: checked='..math.min(checked,32)..'; matched='..#g.entries..
        '; leaves='..g.counts.leaves..'; crows='..g.counts.crows..
        '; capped at 3 per type, 6 nearby native effects; camera_LOD_function_found='..tostring(g.previewSupported)..
        (ok and '' or '; error='..tostring(err)),log)
    if not ok then M.restore(s) end
end
function M.update(s,now,log)
    local g=s.worldLeaves
    if not g then return end
    if g.previewSupported and now>=g.lodAt then
        -- Native Niagara LOD changes can synchronize particle work. Spread
        -- the up-to-six effects over updates instead of changing all together
        -- in the same once-per-second frame.
        g.lodAt=now+1/math.max(1,#g.entries)
        local position=s.flight and s.flight.p or s.origin
        if #g.entries>0 then
            g.lodCursor=(g.lodCursor or 0)%#g.entries+1
            local e=g.entries[g.lodCursor]
            if e.previewEligible and current(s,e)then lodDistance(e,position)end
        end
    end
    if g.statusRemaining==0 or now<g.statusAt then return end
    g.statusRemaining=g.statusRemaining-1;g.statusAt=now+10
    local states={}
    for _,e in ipairs(g.entries) do
        if current(s,e) then
            states[#states+1]=e.path..' active='..tostring(call(e.object,'IsActive'))..
                ' scalability='..tostring(call(e.object,'GetAllowScalability'))..
                ' camera_LOD_cm='..tostring(e.previewApplied)
        else states[#states+1]=e.path..' expired/reused' end
    end
    report(g,'Native status: '..table.concat(states,'; '),log)
end
function M.restore(s)
    local g=s.worldLeaves;if not g then return end
    for _,e in ipairs(g.entries) do
        if current(s,e) then
            if e.previewOwned then pcall(function()e.object:SetPreviewLODDistance(e.previewEnabled,e.previewDistance)end) end
            if e.scalabilityOwned then pcall(function()e.object:SetAllowScalability(e.scalability)end) end
            if e.localPlayerOwned then pcall(function()e.object:SetForceLocalPlayerEffect(e.localPlayer)end) end
        end
    end
    s.worldLeaves=nil
end
return M
