-- Own component visibility and shadow flags, including the dedicated shadow mesh.
local M={}
local flags={'bVisible','CastShadow','bCastHiddenShadow','bCastDynamicShadow','bCastStaticShadow'}
local meshes={'Mesh','ShadowMesh','ShadowMeshComponent'}
local equipment={'WeaponMeshInHands','WeaponMeshUnequipped','SecondaryItemInHands','ShootingAttachMesh'}
local function valid(o)
    if not o then return false end
    local ok,value=pcall(function() return o:IsValid() end)
    return ok and value
end
local function unwrap(o)
    if valid(o) then return o end
    local ok,value=pcall(function() return o:get() end)
    if ok and valid(value) then return value end
end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function() return a:GetAddress()==b:GetAddress() end)
    return ok and value
end
local function restoreComponent(entry)
    local c=entry.object
    if valid(c) then
        for name,v in pairs(entry.flags) do pcall(function() c[name]=v end) end
        if entry.flags.bVisible~=nil then pcall(function() c:SetVisibility(entry.flags.bVisible,false) end) end
        if entry.flags.CastShadow~=nil then pcall(function() c:SetCastShadow(entry.flags.CastShadow) end) end
    end
end
local function restoreActor(entry)
    pcall(function() if valid(entry.object) then entry.object:SetActorHiddenInGame(entry.hidden) end end)
end
local function capture(g,c)
    c=unwrap(c)
    if not c then return end
    local id=c:GetAddress()
    if g.seenComponents then g.seenComponents[id]=true end
    if g.components[id] and valid(g.components[id].object) then return end
    local entry={object=c,flags={}}
    for _,name in ipairs(flags) do
        local ok,v=pcall(function() return c[name] end)
        if ok and type(v)=='boolean' then entry.flags[name]=v end
    end
    g.components[id]=entry
end
local function scan(g,actor,class)
    local components=actor:K2_GetComponentsByClass(class)
    if type(components)=='table' then
        for _,c in pairs(components) do capture(g,c) end
    else
        components:ForEach(function(_,ref) capture(g,ref:get()) end)
    end
end
function M.update(s,now)
    local g=s.playerVisibility
    if g and not same(g.pawn,s.pawn) then M.restore(s);g=nil end
    if not g then g={pawn=s.pawn,actors={},components={},nextScan=0,pawnHidden=s.pawn.bHidden};s.playerVisibility=g end
    pcall(function() if not s.pawn.bHidden then s.pawn:SetActorHiddenInGame(true) end end)
    if now>=g.nextScan then
        g.nextScan=now+1
        g.seenComponents={};local seenActors={}
        for _,name in ipairs(meshes) do pcall(function() capture(g,s.pawn[name]) end) end
        for _,name in ipairs(equipment) do
            pcall(function() capture(g,s.pawn.ItemAppearanceComponent[name]) end)
        end
        local ok,err=pcall(function()
            -- The class is stable across equipment and attached actor changes.
            if not valid(g.primitiveClass) then
                g.primitiveClass=StaticFindObject('/Script/Engine.PrimitiveComponent')
                if not valid(g.primitiveClass) then error('PrimitiveComponent class unavailable') end
            end
            scan(g,s.pawn,g.primitiveClass)
            local attached={};local returned=s.pawn:GetAttachedActors(attached,true,true)
            if type(returned)=='table' then attached=returned end
            local cameraId=s.camera:GetAddress();local pawnId=s.pawn:GetAddress()
            for _,actor in pairs(attached) do
                actor=unwrap(actor)
                if actor and actor:GetAddress()~=cameraId and actor:GetAddress()~=pawnId then
                    local id=actor:GetAddress()
                    seenActors[id]=true
                    if not g.actors[id] or not valid(g.actors[id].object) then g.actors[id]={object=actor,hidden=actor.bHidden} end
                    scan(g,actor,g.primitiveClass)
                end
            end
        end)
        if ok then
            for id,entry in pairs(g.components) do
                if not g.seenComponents[id] then restoreComponent(entry);g.components[id]=nil end
            end
            for id,entry in pairs(g.actors) do
                if not seenActors[id] then restoreActor(entry);g.actors[id]=nil end
            end
        end
        g.seenComponents=nil
        if not ok and not g.logged then print('[ZoneFPV] Player component scan: '..tostring(err)..'\n');g.logged=true end
    end
    for id,entry in pairs(g.components) do
        local c=entry.object
        if not valid(c) then g.components[id]=nil else
            -- UFunctions can be callable userdata; do not require type=function.
            pcall(function() if c.bVisible then
                if not pcall(function() c:SetVisibility(false,false) end) then c.bVisible=false end
            end end)
            pcall(function() if c.CastShadow then
                if not pcall(function() c:SetCastShadow(false) end) then c.CastShadow=false end
            end end)
            -- Visibility/shadow setters above already own these two fields.
            for name in pairs(entry.flags) do
                if name~='bVisible' and name~='CastShadow' then pcall(function() if c[name] then c[name]=false end end) end
            end
        end
    end
    for id,entry in pairs(g.actors) do
        if valid(entry.object) then pcall(function() if not entry.object.bHidden then entry.object:SetActorHiddenInGame(true) end end)
        else g.actors[id]=nil end
    end
end
function M.restore(s)
    local g=s.playerVisibility;if not g then return end
    if g.pawnHidden~=nil then pcall(function() g.pawn:SetActorHiddenInGame(g.pawnHidden) end) end
    for _,entry in pairs(g.actors) do restoreActor(entry) end
    for _,entry in pairs(g.components) do restoreComponent(entry) end
    s.playerVisibility=nil
end
return M
