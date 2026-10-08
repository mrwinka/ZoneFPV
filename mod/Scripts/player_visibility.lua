-- Own player/equipment presentation only while the captured objects still
-- belong to this pawn. IsValid alone cannot identify pooled native objects.
local M={}
local flags={'bVisible','CastShadow','bCastHiddenShadow','bCastDynamicShadow','bCastStaticShadow'}
local meshes={'Mesh','ShadowMesh','ShadowMeshComponent'}
local equipment={'WeaponMeshInHands','WeaponMeshUnequipped','SecondaryItemInHands','ShootingAttachMesh'}
local function invoke(o,k,...)return o[k](o,...)end
local function call(o,k,...)
    local ok,value=pcall(invoke,o,k,...)
    if ok then return value,true end
    return nil,false
end
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function valid(o)return call(o,'IsValid')==true and call(o,'HasAnyFlags',0x18030)~=true end
local function unwrap(o)
    if valid(o)then return o end
    local value=call(o,'get');if valid(value)then return value end
end
local function null(o)return o==nil or call(o,'GetAddress')==0 end
local function identity(o)
    if not valid(o)then return end
    local address,name=call(o,'GetAddress'),call(o,'GetFName')
    if type(address)=='number' and address>0 and name~=nil then
        return {object=o,address=address,name=name}
    end
end
local function matches(saved,o)
    if not valid(o) or call(o,'GetAddress')~=saved.address then return false end
    local name=call(o,'GetFName')
    local ok,equal=pcall(function()return name~=nil and name==saved.name end)
    return ok and equal
end
local function inWorld(g,o)return matches(g.world,call(o,'GetWorld'))end
local function isAgent(g,o)
    return valid(g.agentClass) and call(o,'IsA',g.agentClass)==true
end
local function pawnCurrent(g)
    return matches(g.pawnIdentity,g.pawn) and inWorld(g,g.pawn)
        and call(g.pawn,'IsActorBeingDestroyed')~=true
end
local function ownerIdentity(o)
    local owner,ok=call(o,'GetOwner');if not ok then return end
    if null(owner)then return false end
    return identity(owner)
end
local function ownerMatches(entry)
    local owner,ok=call(entry.object,'GetOwner');if not ok then return false end
    if entry.owner==false then return null(owner)end
    return matches(entry.owner,owner)
end
local function componentWorld(g,component,owner)
    -- Shipping wrappers need not expose UActorComponent::GetWorld. Its
    -- unchanged native owner is the required world authority; a genuinely
    -- available component world additionally rejects a cross-world wrapper.
    if not inWorld(g,owner)then return false end
    local world=call(component,'GetWorld')
    return not valid(world) or matches(g.world,world)
end
local function actorIdentity(g,entry)
    return not entry.retired and matches(entry.identity,entry.object) and inWorld(g,entry.object)
        and call(entry.object,'IsActorBeingDestroyed')~=true
        and not isAgent(g,entry.object)
        and ownerMatches(entry)
end
local function attachment(g,actor)
    -- Re-read the native parent chain before writes, independently of the
    -- slower GetAttachedActors discovery list. A stale list is not ownership.
    local seen={}
    for depth=1,16 do
        if matches(g.pawnIdentity,actor)then return pawnCurrent(g) and 'attached' or nil end
        if not valid(actor) or not inWorld(g,actor)
            or call(actor,'IsActorBeingDestroyed')==true
            or isAgent(g,actor)then return end
        local id=call(actor,'GetAddress');if not id or seen[id]then return end
        seen[id]=true
        if depth>1 then
            local entry=g.actors[id]
            if not entry or not actorIdentity(g,entry)then return end
        end
        local parent,ok=call(actor,'GetAttachParentActor');if not ok then return end
        if null(parent)then return 'detached' end
        actor=parent
    end
end
local function actorCurrent(g,entry,restoring)
    if not actorIdentity(g,entry)then return false end
    local state=attachment(g,entry.object)
    return state=='attached' or restoring and state=='detached'
end
local function componentCurrent(g,entry,restoring)
    if not matches(entry.identity,entry.object) or not ownerMatches(entry)
        or not componentWorld(g,entry.object,entry.owner.object)then return false end
    if matches(g.pawnIdentity,entry.owner.object)then return pawnCurrent(g)end
    local owner=g.actors[entry.owner.address]
    return owner~=nil and matches(owner.identity,entry.owner.object) and actorCurrent(g,owner,restoring)
end
local function restoreComponent(g,entry)
    if not componentCurrent(g,entry,true)then return end
    local c=entry.object
    for name,v in pairs(entry.flags)do
        if componentCurrent(g,entry,true)then pcall(function()c[name]=v end)end
    end
    if entry.flags.bVisible~=nil and componentCurrent(g,entry,true)then call(c,'SetVisibility',entry.flags.bVisible,false)end
    if entry.flags.CastShadow~=nil and componentCurrent(g,entry,true)then call(c,'SetCastShadow',entry.flags.CastShadow)end
end
local function restoreActor(g,entry)
    if actorCurrent(g,entry,true)then call(entry.object,'SetActorHiddenInGame',entry.hidden)end
end
local function retireActor(g,entry)
    if not entry.retired then entry.retired=true;g.rejected=g.rejected+1 end
end
local function retireChanged(g)
    -- Validate the old graph before discovery can replace any parent snapshot.
    -- Components restore while genuine detached equipment is still recorded.
    for id,entry in pairs(g.components)do
        if not componentCurrent(g,entry,false)then
            if not componentCurrent(g,entry,true)then g.rejected=g.rejected+1 end
            restoreComponent(g,entry);g.components[id]=nil
        end
    end
    local detached={};local transferred={}
    for id,entry in pairs(g.actors)do
        if not entry.retired and not actorCurrent(g,entry,false)then
            if actorCurrent(g,entry,true)then detached[#detached+1]=id
            else transferred[#transferred+1]=id end
        end
    end
    for _,id in ipairs(detached)do restoreActor(g,g.actors[id])end
    for _,id in ipairs(detached)do g.actors[id]=nil end
    -- Retired sentinels prevent the same flight's stale references from
    -- granting new authority to an actor or descendant already transferred.
    for _,id in ipairs(transferred)do retireActor(g,g.actors[id])end
end
local function admitActor(g,actor)
    if matches(g.pawnIdentity,actor)then return end
    local path={};local seen={};local root=actor
    for _=1,16 do
        if matches(g.pawnIdentity,actor)then
            if not pawnCurrent(g)then return end
            -- Complete cold discovery in parent-first order, regardless of
            -- the order returned by GetAttachedActors. Validation never fills
            -- an unknown parent or replaces an invalid captured identity.
            for index=#path,1,-1 do
                local row=path[index]
                if not g.actors[row.identity.address]then g.actors[row.identity.address]=row end
                if g.seenActors then g.seenActors[row.identity.address]=true end
            end
            return g.actors[call(root,'GetAddress')]
        end
        local token=identity(actor)
        if not token or seen[token.address] or not inWorld(g,actor)
            or call(actor,'IsActorBeingDestroyed')==true or isAgent(g,actor)then return end
        seen[token.address]=true
        local existing=g.actors[token.address]
        if existing and not actorIdentity(g,existing)then retireActor(g,existing);return end
        local owner=ownerIdentity(actor)
        if owner==nil or owner and not matches(g.pawnIdentity,owner.object) and isAgent(g,owner.object)then return end
        local hidden=read(actor,'bHidden');if type(hidden)~='boolean'then return end
        path[#path+1]=existing or {object=actor,identity=token,owner=owner,hidden=hidden}
        local parent,ok=call(actor,'GetAttachParentActor')
        if not ok or null(parent)then return end
        actor=parent
    end
end
local function capture(g,c)
    c=unwrap(c);local id=c and call(c,'GetAddress');if not id then return end
    local existing=g.components[id]
    if existing and componentCurrent(g,existing,false)then
        if g.seenComponents then g.seenComponents[id]=true end
        if g.seenActors and not matches(g.pawnIdentity,existing.owner.object)then admitActor(g,existing.owner.object)end
        return
    end
    if existing then
        if not componentCurrent(g,existing,true)then g.rejected=g.rejected+1 end
        restoreComponent(g,existing)
    end
    g.components[id]=nil
    local token=identity(c);if not token then return end
    local owner=ownerIdentity(c)
    if not owner or not componentWorld(g,c,owner.object)then return end
    if not matches(g.pawnIdentity,owner.object) and not admitActor(g,owner.object)then return end
    local entry={object=c,identity=token,owner=owner,flags={}}
    if not componentCurrent(g,entry,false)then return end
    for _,name in ipairs(flags)do
        local v=read(c,name);if type(v)=='boolean'then entry.flags[name]=v end
    end
    g.components[token.address]=entry
    if g.seenComponents then g.seenComponents[token.address]=true end
end
local function scan(g,actor,class)
    local components=actor:K2_GetComponentsByClass(class)
    if type(components)=='table'then
        for _,c in pairs(components)do capture(g,c)end
    else
        local count=components:GetArrayNum()
        assert(type(count)=='number' and count>=0 and count%1==0 and count<=256,'invalid player component array')
        for i=1,count do capture(g,components[i])end
    end
end
function M.update(s,now)
    local g=s.playerVisibility
    if g and g.retired then return end
    if g and (not matches(g.pawnIdentity,s.pawn) or not inWorld(g,s.pawn)
        or not matches(g.world,s.world or call(s.pawn,'GetWorld')))then
        local reused=call(s.pawn,'GetAddress')==g.pawnIdentity.address
        M.restore(s)
        if reused then
            -- The session's cached wrapper now describes another pawn/world.
            -- Do not acquire its new identity on this or any later frame.
            g.retired=true;g.rejected=g.rejected+1;g.actors={};g.components={}
            s.playerVisibility=g;return
        end
        g=nil
    end
    if not g then
        local pawn,world=identity(s.pawn),identity(s.world or call(s.pawn,'GetWorld'))
        if not pawn or not world then return end
        g={pawn=s.pawn,pawnIdentity=pawn,world=world,actors={},components={},nextScan=0,rejected=0,pawnHidden=read(s.pawn,'bHidden')}
        local ok,agent=pcall(StaticFindObject,'/Script/Stalker2.Agent')
        if ok and valid(agent)then g.agentClass=agent end
        s.playerVisibility=g
    end
    if not pawnCurrent(g)then M.restore(s);return end
    retireChanged(g)
    if read(g.pawn,'bHidden')==false then call(g.pawn,'SetActorHiddenInGame',true)end
    if now>=g.nextScan then
        g.nextScan=now+2
        g.seenComponents={};local seenActors={};g.seenActors=seenActors
        for _,name in ipairs(meshes)do capture(g,read(g.pawn,name))end
        for _,name in ipairs(equipment)do capture(g,read(read(g.pawn,'ItemAppearanceComponent'),name))end
        local ok,err=pcall(function()
            if not valid(g.primitiveClass)then
                g.primitiveClass=StaticFindObject('/Script/Engine.PrimitiveComponent')
                assert(valid(g.primitiveClass),'PrimitiveComponent class unavailable')
            end
            scan(g,g.pawn,g.primitiveClass)
            local attached={};local returned=g.pawn:GetAttachedActors(attached,true,true)
            if type(returned)=='table'then attached=returned end
            for _,actor in pairs(attached)do
                actor=unwrap(actor)
                if actor and call(actor,'GetAddress')~=call(s.camera,'GetAddress') then
                    local entry=admitActor(g,actor)
                    if entry then seenActors[entry.identity.address]=true;scan(g,actor,g.primitiveClass)end
                end
            end
        end)
        if ok then
            for id,entry in pairs(g.components)do
                if not g.seenComponents[id]then
                    if not componentCurrent(g,entry,true)then g.rejected=g.rejected+1 end
                    restoreComponent(g,entry);g.components[id]=nil
                end
            end
            -- Restore meshes while their unchanged equipment owner remains
            -- recorded, so a detached weapon recovers its own presentation.
            for id,entry in pairs(g.actors)do
                if not entry.retired and not seenActors[id]then
                    if not actorCurrent(g,entry,true)then g.rejected=g.rejected+1 end
                    restoreActor(g,entry)
                end
            end
            for id,entry in pairs(g.actors)do if not entry.retired and not seenActors[id]then g.actors[id]=nil end end
        end
        g.seenComponents=nil
        g.seenActors=nil
        if not ok and not g.logged then print('[ZoneFPV] Player component scan: '..tostring(err)..'\n');g.logged=true end
    end
    for _,name in ipairs(meshes)do capture(g,read(g.pawn,name))end
    for _,name in ipairs(equipment)do capture(g,read(read(g.pawn,'ItemAppearanceComponent'),name))end
    for id,entry in pairs(g.components)do
        local c=entry.object
        if not componentCurrent(g,entry,false)then
            -- A detached item may restore; a transferred/recycled item fails
            -- the stronger restoration guard and is only forgotten.
            if not componentCurrent(g,entry,true)then g.rejected=g.rejected+1 end
            restoreComponent(g,entry);g.components[id]=nil
        else
            if read(c,'bVisible')==true and componentCurrent(g,entry,false)then
                local _,ok=call(c,'SetVisibility',false,false)
                if not ok and componentCurrent(g,entry,false)then pcall(function()c.bVisible=false end)end
            end
            if read(c,'CastShadow')==true and componentCurrent(g,entry,false)then
                local _,ok=call(c,'SetCastShadow',false)
                if not ok and componentCurrent(g,entry,false)then pcall(function()c.CastShadow=false end)end
            end
            for name in pairs(entry.flags)do
                if name~='bVisible' and name~='CastShadow' and read(c,name)==true and componentCurrent(g,entry,false)then
                    pcall(function()c[name]=false end)
                end
            end
        end
    end
    for id,entry in pairs(g.actors)do
        if not entry.retired and actorCurrent(g,entry,false) and read(entry.object,'bHidden')==false then
            call(entry.object,'SetActorHiddenInGame',true)
        end
    end
    retireChanged(g)
end
function M.restore(s)
    local g=s.playerVisibility;if not g then return end
    if g.retired then s.playerVisibility=nil;return end
    if type(g.pawnHidden)=='boolean' and pawnCurrent(g)then call(g.pawn,'SetActorHiddenInGame',g.pawnHidden)end
    for _,entry in pairs(g.components)do restoreComponent(g,entry)end
    for _,entry in pairs(g.actors)do restoreActor(g,entry)end
    s.playerVisibility=nil
end
return M
