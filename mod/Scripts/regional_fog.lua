-- FogActor uses a mesh material, independently of engine fog console variables.
local M={}
local function valid(o) return o and o:IsValid() end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function() return a:GetAddress()==b:GetAddress() end)
    return ok and value
end
local function restoreActor(e)
    pcall(function() if valid(e.object) then e.object:SetActorHiddenInGame(e.hidden) end end)
end
function M.restore(s)
    local g=s.regionalFog;if not g then return end
    for _,e in pairs(g.actors) do restoreActor(e) end
    s.regionalFog=nil
end
function M.update(s,now,clear)
    if not clear then M.restore(s);return end
    local g=s.regionalFog
    if g and not same(g.world,s.world) then M.restore(s);g=nil end
    if not g then g={world=s.world,worldId=s.world:GetAddress(),actors={},nextScan=0};s.regionalFog=g end
    if now>=g.nextScan then
        g.nextScan=now+2
        local ok,err=pcall(function()
            for id,e in pairs(g.actors) do
                if not valid(e.object) then g.actors[id]=nil
                elseif not same(e.object:GetWorld(),g.world) then restoreActor(e);g.actors[id]=nil end
            end
            for _,actor in ipairs(FindAllOf('FogActor') or {}) do
                if valid(actor) then
                    local world=actor:GetWorld()
                    if valid(world) and world:GetAddress()==g.worldId then
                        local id=actor:GetAddress()
                        if not g.actors[id] then g.actors[id]={object=actor,hidden=actor.bHidden} end
                    end
                end
            end
        end)
        if not ok and not g.logged then print('[ZoneFPV] Regional fog scan unavailable: '..tostring(err)..'\n');g.logged=true end
    end
    for id,e in pairs(g.actors) do
        if not valid(e.object) then g.actors[id]=nil
        else pcall(function() if not e.object.bHidden then e.object:SetActorHiddenInGame(true) end end) end
    end
end
return M
