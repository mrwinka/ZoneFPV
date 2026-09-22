local M={}
local function valid(o) return o and o:IsValid() end
function M.update(s,now)
    local g=s.playerVisibility
    if not g then g={actors={},nextScan=0};s.playerVisibility=g end
    if now>=g.nextScan then
        g.nextScan=now+0.5
        local ok,err=pcall(function()
            local attached={}
            s.pawn:GetAttachedActors(attached,true,true)
            for _,actor in pairs(attached) do
                if valid(actor) and actor:GetAddress()~=s.camera:GetAddress() and actor:GetAddress()~=s.pawn:GetAddress() then
                    local id=actor:GetAddress()
                    if not g.actors[id] then g.actors[id]={object=actor,hidden=actor.bHidden} end
                end
            end
        end)
        if not ok and not g.logged then
            print('[ZoneFPV] Attached equipment scan: '..tostring(err)..'\n');g.logged=true
        end
        -- Attached components also cover first-person weapon meshes belonging
        -- to the player rather than to a separate attached actor.
        if not g.mesh then
            pcall(function()
                local mesh=s.pawn.Mesh
                if valid(mesh) then g.mesh=mesh;g.visible=mesh.bVisible end
            end)
        end
    end
    if g.mesh then pcall(function() if valid(g.mesh) then g.mesh:SetVisibility(false,true) end end) end
    for id,entry in pairs(g.actors) do
        if valid(entry.object) then
            pcall(function() if not entry.object.bHidden then entry.object:SetActorHiddenInGame(true) end end)
        else g.actors[id]=nil end
    end
end
function M.restore(s)
    local g=s.playerVisibility;if not g then return end
    for _,entry in pairs(g.actors) do
        pcall(function() if valid(entry.object) then entry.object:SetActorHiddenInGame(entry.hidden) end end)
    end
    if g.mesh then pcall(function() if valid(g.mesh) then g.mesh:SetVisibility(g.visible,true) end end) end
    s.playerVisibility=nil
end
return M
