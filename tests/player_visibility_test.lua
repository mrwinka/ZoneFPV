local guard=dofile('mod/Scripts/player_visibility.lua')
local presentation={bVisible=true,CastShadow=true,bCastHiddenShadow=true,bCastDynamicShadow=true,bCastStaticShadow=true,bHidden=true}
local function object(id,name,fields)
    local data=fields or {};data.address=id;data.name=name;data.writes=0
    local o=setmetatable({}, {__index=data,__newindex=function(_,key,value)
        if presentation[key]then data.writes=data.writes+1 end
        data[key]=value
    end})
    function o:IsValid()return not self.invalid end
    function o:GetAddress()return self.address end
    function o:GetFName()return self.name end
    function o:GetWorld()return self.world end
    function o:HasAnyFlags()return self.dying or false end
    function o:IsActorBeingDestroyed()return self.dying or false end
    function o:GetOwner()return self.owner end
    function o:IsA(class)assert(class.classPath=='/Script/Stalker2.Agent');return self.npc or false end
    function o:GetAttachParentActor()return self.parent end
    return o
end
local function component(id,owner,visible,shadow)
    local c=object(id,'Mesh_'..id,{owner=owner,world=owner.world,bVisible=visible,CastShadow=shadow,
        bCastHiddenShadow=true,bCastDynamicShadow=true,bCastStaticShadow=false})
    function c:SetVisibility(v,propagate)assert(propagate==false);self.bVisible=v end
    function c:SetCastShadow(v)self.CastShadow=v end
    return c
end
local classFinds=0
StaticFindObject=function(path)
    classFinds=classFinds+1
    if path=='/Script/Stalker2.Agent'then return object(901,'Agent',{classPath=path})end
    assert(path=='/Script/Engine.PrimitiveComponent');return object(900,'PrimitiveComponent')
end
local function actor(id,world,parent,npc)
    local a=object(id,'Actor_'..id,{world=world,parent=parent,npc=npc,bHidden=false,components={}})
    function a:SetActorHiddenInGame(v)self.bHidden=v end
    function a:K2_GetComponentsByClass()return self.components end
    function a:GetAttachedActors()return self.attached or {}end
    return a
end
local function fixture()
    local world=object(500,'World_1')
    local pawn=actor(100,world);pawn.ItemAppearanceComponent={}
    local mesh=component(1,pawn,true,true);local shadow=component(2,pawn,false,true);local weapon=component(3,pawn,true,false)
    pawn.Mesh=mesh;pawn.ShadowMeshComponent=shadow;pawn.ItemAppearanceComponent.WeaponMeshUnequipped=weapon
    pawn.components={mesh,{get=function()return shadow end},false,metadata=true}
    local s={pawn=pawn,world=world,camera=actor(101,world)}
    return s,pawn,mesh,shadow,weapon
end
local function clearWrites(...)
    for _,o in ipairs({...})do o.writes=0 end
end
local function test(name,fn)fn();print('PASS '..name)end

test('dedicated shadow mesh and player-owned primitives restore exact flags',function()
    local s,pawn,mesh,shadow,weapon=fixture()
    guard.update(s,0)
    assert(pawn.bHidden and not mesh.bVisible and not shadow.CastShadow and not shadow.bCastHiddenShadow and not weapon.bVisible)
    shadow.CastShadow=true;guard.update(s,.1);assert(not shadow.CastShadow)
    guard.restore(s)
    assert(not pawn.bHidden and mesh.bVisible and mesh.CastShadow and not shadow.bVisible and shadow.CastShadow and shadow.bCastHiddenShadow)
    assert(weapon.bVisible and not weapon.CastShadow and not weapon.bCastStaticShadow)
end)

test('recursive equipment remains hidden and genuine detachment restores immediately',function()
    local s,pawn=fixture()
    local attached=actor(102,s.world,pawn);local attachedMesh=component(4,attached,true,true)
    attached.components={attachedMesh};pawn.attached={attached}
    guard.update(s,0);assert(attached.bHidden and not attachedMesh.bVisible)
    local before=classFinds;guard.update(s,2);assert(classFinds==before,'stable primitive class is cached')
    -- The discovery list remains stale until the next two-second scan.
    attached.parent=nil;guard.update(s,2.1)
    assert(not attached.bHidden and attachedMesh.bVisible and attachedMesh.CastShadow,'native detachment is recognized between scans')
    assert(not s.playerVisibility.actors[102] and not s.playerVisibility.components[4])
    guard.restore(s)
end)

test('nested player equipment and component-owned attachment trees stay supported',function()
    local s,pawn=fixture()
    local holder=actor(102,s.world,pawn);local accessory=actor(103,s.world,holder)
    local mesh=component(4,accessory,true,true);accessory.components={mesh}
    pawn.attached={accessory,holder,{get=function()return s.camera end},pawn}
    pawn.ItemAppearanceComponent.SecondaryItemInHands=mesh
    guard.update(s,0)
    assert(holder.bHidden and accessory.bHidden and not mesh.bVisible and not s.camera.bHidden)
    assert(not s.playerVisibility.actors[100],'the pawn cannot be captured as its own equipment')
    holder.parent=nil;guard.update(s,.1)
    assert(not holder.bHidden and not accessory.bHidden and mesh.bVisible,'detached equipment subtree restores as a group')
    guard.restore(s);assert(not pawn.bHidden)
end)

test('reflected setter failure retains guarded property fallback',function()
    local s,pawn=fixture();local fallback=component(5,pawn,true,true)
    fallback.SetVisibility=false;fallback.SetCastShadow=false;pawn.Mesh=fallback
    guard.update(s,0);assert(not fallback.bVisible and not fallback.CastShadow)
    guard.restore(s);assert(fallback.bVisible and fallback.CastShadow)
end)

test('NPC-owned stale equipment references and Agent subclasses never become presentation targets',function()
    local s,pawn=fixture()
    local npc=actor(200,s.world,pawn,true);local npcMesh=component(8,npc,true,true)
    npc.components={npcMesh};pawn.attached={npc};pawn.ItemAppearanceComponent.WeaponMeshInHands=npcMesh
    pawn.components[#pawn.components+1]=npcMesh
    guard.update(s,0)
    assert(not npc.bHidden and npcMesh.bVisible and npcMesh.CastShadow and npc.writes==0 and npcMesh.writes==0)
    assert(not s.playerVisibility.actors[200] and not s.playerVisibility.components[8])
    guard.restore(s);assert(npc.writes==0 and npcMesh.writes==0)
end)

test('component transfer to an NPC stops frame writes and never restores player flags into it',function()
    local s,pawn,mesh=fixture();guard.update(s,0)
    local npc=actor(200,s.world,nil,true)
    -- A pooled component can keep its exact name and address while changing
    -- owner. Stale Mesh and ItemAppearanceComponent fields still point at it.
    mesh.owner=npc;mesh.bVisible=true;mesh.CastShadow=true;mesh.bCastHiddenShadow=false
    clearWrites(mesh);guard.update(s,.1)
    assert(mesh.bVisible and mesh.CastShadow and not mesh.bCastHiddenShadow and mesh.writes==0)
    assert(not s.playerVisibility.components[1])
    assert(s.playerVisibility.rejected==1,'transferred capture contributes exactly one bounded rejection')
    guard.restore(s);assert(mesh.writes==0,'retirement/exit cannot restore a transferred component')
end)

test('component reuse at the same address captures the replacement name and its own baseline',function()
    local s,pawn,mesh=fixture();guard.update(s,0)
    mesh.name='ReplacementMesh_1';mesh.bVisible=true;mesh.CastShadow=false;mesh.bCastHiddenShadow=false
    clearWrites(mesh);guard.update(s,.1)
    assert(not mesh.bVisible and not mesh.CastShadow)
    guard.restore(s)
    assert(mesh.bVisible and not mesh.CastShadow and not mesh.bCastHiddenShadow,'replacement must not inherit old mesh baseline')
end)

test('renamed cached components absent from current discovery are discarded without restoration',function()
    local s,pawn,mesh=fixture();guard.update(s,0)
    pawn.Mesh=nil;pawn.components={};mesh.name='NPCMeshReused_1';mesh.bVisible=false;mesh.CastShadow=false
    clearWrites(mesh);guard.update(s,.1);guard.restore(s)
    assert(mesh.writes==0 and not mesh.bVisible and not mesh.CastShadow)
end)

test('attached actor and its components transferred under NPC do not receive cached hides or restoration',function()
    local s,pawn=fixture();local item=actor(102,s.world,pawn);local mesh=component(4,item,true,true)
    item.components={mesh};pawn.attached={item};guard.update(s,0)
    local npc=actor(200,s.world,nil,true)
    item.parent=npc;item.bHidden=false;mesh.bVisible=true;mesh.CastShadow=false
    clearWrites(item,mesh);guard.update(s,.1)
    assert(not item.bHidden and mesh.bVisible and not mesh.CastShadow and item.writes==0 and mesh.writes==0)
    assert(s.playerVisibility.actors[102].retired and not s.playerVisibility.components[4])
    guard.update(s,2);guard.restore(s);assert(item.writes==0 and mesh.writes==0,'stale discovery cannot reacquire transferred equipment')
end)

test('actor owner transfer with an unchanged player attachment cannot receive its previous baseline',function()
    local s,pawn=fixture();local item=actor(102,s.world,pawn);local mesh=component(4,item,true,true)
    item.owner=pawn;item.components={mesh};pawn.attached={item};guard.update(s,0)
    local npc=actor(200,s.world,nil,true);item.owner=npc;item.bHidden=false;mesh.bVisible=true
    clearWrites(item,mesh);guard.restore(s)
    assert(item.writes==0 and mesh.writes==0 and not item.bHidden and mesh.bVisible)
end)

test('pooled actor keeps its address but changes name and class without inheriting player presentation',function()
    local s,pawn=fixture();local item=actor(102,s.world,pawn);local mesh=component(4,item,true,true)
    item.components={mesh};pawn.attached={item};guard.update(s,0)
    item.name='HumanPooled_102';item.npc=true;item.bHidden=false;mesh.name='HumanMesh_4';mesh.bVisible=true
    clearWrites(item,mesh);guard.update(s,.1);guard.restore(s)
    assert(item.writes==0 and mesh.writes==0 and not item.bHidden and mesh.bVisible)
end)

test('world transfer and teardown never restore snapshots to another world or dying object',function()
    local s,pawn,mesh=fixture();guard.update(s,0)
    mesh.world=object(600,'World_2');mesh.bVisible=false;clearWrites(mesh)
    guard.restore(s);assert(mesh.writes==0 and not mesh.bVisible)
    s,pawn,mesh=fixture();guard.update(s,0);mesh.dying=true;clearWrites(mesh)
    guard.restore(s);assert(mesh.writes==0)
end)

test('native actor world and attachment getter failures cannot authorize cached writes or cleanup',function()
    local s,pawn=fixture();local item=actor(102,s.world,pawn);local mesh=component(4,item,true,true)
    item.components={mesh};pawn.attached={item};guard.update(s,0)
    function item:GetAttachParentActor()error('pooled root unavailable')end
    item.bHidden=false;mesh.bVisible=true;clearWrites(item,mesh)
    guard.update(s,.1);guard.restore(s);assert(item.writes==0 and mesh.writes==0)
    s,pawn,mesh=fixture();guard.update(s,0)
    function pawn:GetWorld()error('streamed object unavailable')end
    mesh.bVisible=true;clearWrites(mesh);guard.update(s,.1);guard.restore(s)
    assert(mesh.writes==0 and mesh.bVisible)
end)

test('absent or invalid component world getter uses its stable native owner world',function()
    local s,pawn,mesh,shadow=fixture()
    mesh.GetWorld=false
    local unavailable=object(0,'Null',{invalid=true})
    function shadow:GetWorld()return unavailable end
    guard.update(s,0)
    assert(not mesh.bVisible and not mesh.CastShadow and not shadow.CastShadow)
    guard.restore(s);assert(mesh.bVisible and mesh.CastShadow and shadow.CastShadow)
end)

test('same-address pawn recycled as an Agent retires the whole guard for the remaining flight',function()
    local s,pawn,mesh=fixture();guard.update(s,0)
    pawn.name='PooledHuman_100';pawn.npc=true;pawn.bHidden=false;mesh.name='PooledHumanMesh_1';mesh.bVisible=true
    clearWrites(pawn,mesh)
    guard.update(s,.1);local retired=s.playerVisibility
    assert(retired and retired.retired and retired.rejected==1)
    assert(pawn.writes==0 and mesh.writes==0 and not pawn.bHidden and mesh.bVisible)
    for i=1,10 do guard.update(s,i)end
    assert(s.playerVisibility==retired and pawn.writes==0 and mesh.writes==0,'later scans cannot reacquire the recycled pawn')
    guard.restore(s);assert(not s.playerVisibility and pawn.writes==0 and mesh.writes==0)
end)

test('same-address pawn world change retires the guard without reacquiring the foreign world',function()
    local s,pawn,mesh=fixture();guard.update(s,0)
    local otherWorld=object(600,'World_2');pawn.world=otherWorld;mesh.world=otherWorld
    pawn.bHidden=false;mesh.bVisible=true;clearWrites(pawn,mesh)
    -- The session world can itself be stale; native pawn residency must still
    -- detect the transfer even before main refreshes its world reference.
    guard.update(s,.1);local retired=s.playerVisibility
    assert(retired and retired.retired and retired.rejected==1 and pawn.writes==0 and mesh.writes==0)
    s.world=otherWorld
    for i=1,10 do guard.update(s,i)end
    assert(s.playerVisibility==retired and not pawn.bHidden and mesh.bVisible and pawn.writes==0 and mesh.writes==0)
    guard.restore(s);assert(not s.playerVisibility and pawn.writes==0 and mesh.writes==0)
end)

local function equipmentTree(order)
    local s,pawn=fixture()
    local holder=actor(102,s.world,pawn);holder.owner=pawn
    local middle=actor(103,s.world,holder);middle.owner=holder
    local child=actor(104,s.world,middle)
    local mesh=component(4,child,true,true);child.components={mesh}
    local nodes={holder,middle,child};pawn.attached={}
    for _,index in ipairs(order or {1,2,3})do pawn.attached[#pawn.attached+1]=nodes[index]end
    return s,pawn,holder,middle,child,mesh
end
test('cold nested equipment capture is independent of native discovery order and omitted intermediate parents',function()
    for _,order in ipairs({{1,2,3},{3,2,1},{2,1,3},{3}})do
        local s,pawn,holder,middle,child,mesh=equipmentTree(order)
        -- Mirror the actual void native UFunction's mutable output table.
        function pawn:GetAttachedActors(out)for i,a in ipairs(self.attached)do out[i]=a end end
        guard.update(s,0)
        assert(holder.bHidden and middle.bHidden and child.bHidden and not mesh.bVisible)
        assert(s.playerVisibility.actors[102] and s.playerVisibility.actors[103] and s.playerVisibility.actors[104])
        guard.update(s,2)
        assert(holder.bHidden and middle.bHidden and child.bHidden and not mesh.bVisible,'housekeeping must retain verified intermediate parents')
        guard.restore(s)
        assert(not holder.bHidden and not middle.bHidden and not child.bHidden and mesh.bVisible)
    end
end)

local ancestorTransfers={
    {'owner transferred to NPC',function(s,parent)parent.owner=actor(200,s.world,nil,true)end},
    {'name reused at the same address',function(_,parent)parent.name='ReusedHolder_102'end},
    {'world transferred',function(_,parent)parent.world=object(600,'World_2')end},
    {'detached under a foreign NPC',function(s,parent)parent.parent=actor(200,s.world,nil,true)end},
}
for _,variant in ipairs(ancestorTransfers)do
    test('grandparent '..variant[1]..' blocks descendant writes before discovery and through exit',function()
        for _,exitImmediately in ipairs({false,true})do
            local s,pawn,holder,middle,child,mesh=equipmentTree({1,2,3})
            guard.update(s,0);variant[2](s,holder)
            holder.bHidden=false;middle.bHidden=false;child.bHidden=false;mesh.bVisible=true;mesh.CastShadow=false
            clearWrites(holder,middle,child,mesh)
            if not exitImmediately then
                -- Parent-first discovery must not replace its failed snapshot
                -- before the child checks its inherited ownership authority.
                for _,now in ipairs({.1,2,2.1,4})do guard.update(s,now)end
                assert(s.playerVisibility.actors[102].retired and s.playerVisibility.actors[103].retired
                    and s.playerVisibility.actors[104].retired)
            end
            guard.restore(s)
            assert(holder.writes==0 and middle.writes==0 and child.writes==0 and mesh.writes==0,
                'neither stale hides nor old baseline restoration may write to the transferred tree')
            assert(not child.bHidden and mesh.bVisible and not mesh.CastShadow)
        end
    end)
end

test('new unowned intermediate parent cannot authorize an NPC-owned equipment subtree',function()
    local s,pawn,holder,middle,child,mesh=equipmentTree({3})
    holder.owner=actor(200,s.world,nil,true)
    guard.update(s,0)
    assert(holder.writes==0 and middle.writes==0 and child.writes==0 and mesh.writes==0)
    assert(not s.playerVisibility.actors[102] and not s.playerVisibility.actors[103] and not s.playerVisibility.actors[104])
    guard.restore(s);assert(child.writes==0 and mesh.writes==0)
end)

test('cold cyclic parent paths cannot allocate or hide equipment',function()
    local s,pawn,holder,middle,child,mesh=equipmentTree({3})
    holder.parent=child
    guard.update(s,0)
    assert(holder.writes==0 and middle.writes==0 and child.writes==0 and mesh.writes==0)
    assert(not s.playerVisibility.actors[102] and not s.playerVisibility.actors[103] and not s.playerVisibility.actors[104])
    guard.restore(s)
end)

print('PASS player presentation identity/world/owner/ancestor guards, cold nested discovery, pooled NPC isolation and equipment restoration')
