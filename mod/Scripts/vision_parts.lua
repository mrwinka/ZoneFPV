-- Material authority is narrower than sharing a world. Capture a component,
-- its native owner and the actual attachment chain back to this one NPC.
-- No visibility, AI, animation or actor ownership state is written here.
local M={}
local function invoke(o,k,...)return o[k](o,...)end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...);if ok then return v end
end
local function valid(o)
    return call(o,'IsValid')==true and call(o,'HasAnyFlags',0x18030)~=true
        and call(o,'IsBeingDestroyed')~=true and call(o,'IsActorBeingDestroyed')~=true
end
local function null(o)return o==nil or call(o,'GetAddress')==0 end
function M.identity(o)
    if not valid(o)then return end
    local id,name,class=call(o,'GetAddress'),call(o,'GetFName'),call(o,'GetClass')
    local classId=call(class,'GetAddress')
    if type(id)=='number'and id>0 and name~=nil and type(classId)=='number'and classId>0 then
        return {object=o,address=id,name=name,class=classId}
    end
end
function M.matches(saved,o)
    if not saved or not valid(o)or call(o,'GetAddress')~=saved.address
        or call(call(o,'GetClass'),'GetAddress')~=saved.class then return false end
    local name=call(o,'GetFName')
    local ok,equal=pcall(function()return name~=nil and name==saved.name end)
    return ok and equal
end
function M.new(world,pawn,camera)
    local self={world=M.identity(world),pawn=pawn,camera=camera}
    local function inWorld(o)return M.matches(self.world,call(o,'GetWorld'))end
    local function rootCurrent(root,restoring)
        if not root or not M.matches(root.identity,root.actor)or not inWorld(root.actor)
            or call(root.actor,'GetAddress')==call(pawn,'GetAddress')
            or call(root.actor,'GetAddress')==call(camera,'GetAddress')then return false end
        -- A cache row may be reassigned independently of its previous actor.
        -- It grants no new write authority. Cleanup still uses the original
        -- actor/component identities and their unchanged native attachment.
        if restoring then return true end
        if not M.matches(root.identity,root.entry.actor)
            or root.entry.key~=nil and root.entry.key~=root.identity.address then return false end
        local ok,equal=pcall(function()return root.entry.name==nil or root.entry.name==root.identity.name end)
        return ok and equal
    end
    function self:root(entry)
        local actor=entry and entry.actor
        local identity=M.identity(actor)
        if not identity or not inWorld(actor)then return end
        if entry.key~=nil and entry.key~=identity.address then return end
        if entry.name~=nil then
            local ok,equal=pcall(function()return entry.name==identity.name end)
            if not ok or not equal then return end
        end
        local root={entry=entry,actor=actor,identity=identity}
        return rootCurrent(root)and root or nil
    end
    local function actorPath(root,actor)
        local path,seen={},{}
        for _=1,16 do
            if M.matches(root.identity,actor)then return path end
            -- Without the native Agent class, a different NPC cannot be
            -- distinguished from attached equipment. Never grant that path.
            if not valid(self.agentClass)then return end
            local identity=M.identity(actor)
            if not identity or not inWorld(actor)or seen[identity.address]
                or self.agentClass and call(actor,'IsA',self.agentClass)==true
                or call(actor,'GetAddress')==call(pawn,'GetAddress')
                or call(actor,'GetAddress')==call(camera,'GetAddress')then return end
            seen[identity.address]=true;path[#path+1]=identity
            actor=call(actor,'GetAttachParentActor')
        end
    end
    local function chain(root,mesh,restoring)
        if not rootCurrent(root,restoring)then return end
        local path,seen={},{}
        for _=1,16 do
            if null(mesh)then break end
            local identity,owner=M.identity(mesh),call(mesh,'GetOwner')
            local ownerIdentity=M.identity(owner)
            if not identity or seen[identity.address]or not ownerIdentity or not inWorld(owner)
                or call(owner,'GetAddress')==call(pawn,'GetAddress')
                or call(owner,'GetAddress')==call(camera,'GetAddress')then return end
            seen[identity.address]=true
            local componentWorld=call(mesh,'GetWorld')
            -- UActorComponent::GetWorld need not be reflected. Its exact native
            -- owner supplies the world; an available component world must agree.
            if valid(componentWorld)and not M.matches(self.world,componentWorld)then return end
            local actors=actorPath(root,owner)
            if not actors then return end
            path[#path+1]={identity=identity,owner=ownerIdentity,actors=actors}
            local ok,parent=pcall(invoke,mesh,'GetAttachParent')
            if not ok then return end
            mesh=parent
        end
        if not null(mesh)then return end
        return path
    end
    function self:capture(root,mesh)
        local path=chain(root,mesh)
        if not path or #path==0 then return end
        return {root=root,path=path,identity=path[1].identity,owner=path[1].owner}
    end
    function self:rootCurrent(root)return rootCurrent(root)end
    function self:current(record,restoring)
        if not record or not rootCurrent(record.root,restoring)
            or not M.matches(record.identity,record.identity.object)
            or not M.matches(record.owner,call(record.identity.object,'GetOwner'))then return false end
        if not restoring and (record.root.entry.expired or record.root.entry.suspended)then return false end
        local path=chain(record.root,record.identity.object,restoring)
        if not path then return false end
        -- A native LOD reparent within this same proven NPC revokes ordinary
        -- writes, but must still restore the unchanged component's baseline.
        -- This fresh chain independently excludes foreign NPCs/owners/worlds;
        -- it never grants authority merely because two actors share a world.
        if restoring then return true end
        if #path~=#record.path then return false end
        for i,row in ipairs(path)do
            local saved=record.path[i]
            if not M.matches(saved.identity,row.identity.object)or not M.matches(saved.owner,row.owner.object)
                or #row.actors~=#saved.actors then return false end
            for j,actor in ipairs(row.actors)do
                if not M.matches(saved.actors[j],actor.object)then return false end
            end
        end
        return true
    end
    return self
end
return M
