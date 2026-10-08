-- Disable only the player's primitive overlap notifications while piloting.
-- Blocking/query collision remains available to the combat receiving capsule.
local M={}
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return call(o,'IsValid')==true end
local function field(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function point(v)
    if not v then return end
    local x,y,z=field(v,'X'),field(v,'Y'),field(v,'Z')
    if type(x)=='number' and type(y)=='number' and type(z)=='number' and x==x and y==y and z==z and math.abs(x)+math.abs(y)+math.abs(z)<1e12 then return {X=x,Y=y,Z=z} end
end
local function own(g,c)
    if not valid(c) then return end
    local id=call(c,'GetAddress');if not id or g.components[id] then return end
    local value=call(c,'GetGenerateOverlapEvents')
    if type(value)~='boolean' then return end
    local owner=call(c,'GetOwner')
    if owner and call(owner,'GetAddress')~=call(g.pawn,'GetAddress') then return end
    g.components[id]={object=c,enabled=value}
    if value then call(c,'SetGenerateOverlapEvents',false) end
end
function M.start(s)
    if s.teleportGuard then return end
    local g={pawn=s.pawn,components={},origin=point(call(s.pawn,'K2_GetActorLocation'))};s.teleportGuard=g
    own(g,field(s.pawn,'CapsuleComponent'))
    local ok,klass=pcall(function()return StaticFindObject('/Script/Engine.PrimitiveComponent')end)
    if ok and valid(klass) then
        local list=call(s.pawn,'K2_GetComponentsByClass',klass)
        local count=call(list,'GetArrayNum') or (type(list)=='table' and #list)
        if type(count)=='number' and count>=0 and count<=128 then
            for i=1,count do
                local c=field(list,i)
                if type(c)=='userdata' then local k=call(c,'type');if k=='RemoteUnrealParam' or k=='LocalUnrealParam' then c=call(c,'get') end end
                own(g,c)
            end
        end
    end
end
function M.update(s)
    local g=s.teleportGuard;if not g then return end
    for _,e in pairs(g.components)do
        if valid(e.object) and call(e.object,'GetGenerateOverlapEvents')==true then call(e.object,'SetGenerateOverlapEvents',false) end
    end
    local expected=s.combat and s.combat.proxy and s.combat.proxy.lastPosition or s.npcAnchor and s.npcAnchor.lastPosition or g.origin
    local actual=point(call(g.pawn,'K2_GetActorLocation'))
    -- A story teleport that bypasses overlap triggers must get full ownership
    -- back before the streaming anchor/combat proxy overwrites its destination.
    if actual and expected and (actual.X-expected.X)^2+(actual.Y-expected.Y)^2+(actual.Z-expected.Z)^2>500^2 then return actual end
end
function M.handoff(s,destination)
    if s.npcAnchor then s.npcAnchor.position=destination end
    if s.combat and s.combat.proxy then s.combat.proxy.position=destination end
end
function M.restore(s)
    local g=s.teleportGuard;if not g then return end
    for _,e in pairs(g.components)do
        if valid(e.object) then call(e.object,'SetGenerateOverlapEvents',e.enabled) end
    end
    s.teleportGuard=nil
end
return M
