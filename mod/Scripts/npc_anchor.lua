-- Optional A-Life workaround: the real pawn is the simulation anchor.
-- It stays hidden/non-colliding during the flight and returns before input unlocks.
local M={}
local function copy(v) return {X=v.X,Y=v.Y,Z=v.Z} end
local function valid(o) return o and (not o.IsValid or o:IsValid()) end
local function invoke(o,name,...)
    local args={...}
    return pcall(function() return o[name](o,table.unpack(args)) end)
end
function M.update(s,enabled,position)
    if not enabled then return M.restore(s) end
    local pawn=s.pawn
    if not s.npcAnchor then
        local a={position=copy(pawn:K2_GetActorLocation()),
            hidden=pawn.bHidden,collision=pawn:GetActorEnableCollision(),damage=pawn.bCanBeDamaged}
        s.npcAnchor=a
        if type(StaticFindObject)=='function' then
            local ok,class=pcall(StaticFindObject,'/Script/AIModule.AIPerceptionStimuliSourceComponent')
            if ok and valid(class) then
                local got,component=pcall(pawn.GetComponentByClass,pawn,class)
                if got and valid(component) then
                    a.perception=component
                    invoke(component,'UnregisterFromPerceptionSystem')
                end
            end
        end
        pawn:SetActorHiddenInGame(true)
        pawn:SetActorEnableCollision(false)
    end
    -- Reassert these because game scripts can restore character presentation/state.
    if pawn.bCanBeDamaged then pawn.bCanBeDamaged=false end
    if not pawn.bHidden then pawn:SetActorHiddenInGame(true) end
    if pawn:GetActorEnableCollision() then pawn:SetActorEnableCollision(false) end
    -- Restore RC2/RC3 placement: follow camera XY, keep the real pawn 50 m
    -- below its ENTRY height. Never put the detectable pawn at the camera.
    -- Camera movement/collision and current presentation guards stay separate.
    local anchorPosition={X=position.X,Y=position.Y,Z=s.npcAnchor.position.Z-5000}
    local previous=s.npcAnchor.lastPosition
    -- Avoid repeated scene/streaming updates while hovering or using the menu.
    if not previous or (anchorPosition.X-previous.X)^2+(anchorPosition.Y-previous.Y)^2>=200^2 then
        pawn:K2_SetActorLocation(anchorPosition,false,{},true)
        s.npcAnchor.lastPosition=anchorPosition
    end
end
function M.restore(s)
    local a=s.npcAnchor
    if not a then return end
    local pawn=s.pawn
    local errors={}
    local function restore(fn)
        local ok,err=pcall(fn);if not ok then errors[#errors+1]=tostring(err) end
    end
    restore(function() pawn:K2_SetActorLocation(a.position,false,{},true) end)
    restore(function() pawn.bCanBeDamaged=a.damage end)
    if a.perception then restore(function() invoke(a.perception,'RegisterWithPerceptionSystem') end) end
    restore(function() pawn:SetActorHiddenInGame(a.hidden) end)
    restore(function() pawn:SetActorEnableCollision(a.collision) end)
    s.npcAnchor=nil
    assert(#errors==0,table.concat(errors,'; '))
end
return M
