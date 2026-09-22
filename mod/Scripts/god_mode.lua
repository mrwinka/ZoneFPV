local M={}
local function valid(o) return o and (not o.IsValid or o:IsValid()) end
local function restore(state)
    if state.pawn and valid(state.pawn) and state.damage~=nil then state.pawn.bCanBeDamaged=state.damage end
    state.pawn=nil;state.damage=nil
end
function M.commands(enabled)
    local value=enabled and 'true' or 'false'
    return {'XSetGodMode '..value,'XSetFactionGodMode Player '..value}
end
function M.update(state,pawn,enabled,controller,system)
    local same=valid(state.pawn) and valid(pawn) and
        (state.pawn==pawn or (state.pawn.GetAddress and pawn.GetAddress and state.pawn:GetAddress()==pawn:GetAddress()))
    local changed=not same
    if changed then
        restore(state)
        if valid(pawn) then state.pawn=pawn;state.damage=pawn.bCanBeDamaged end
    end
    if not valid(state.pawn) or not valid(controller) or not valid(system) then return false end
    if state.applied==nil and not enabled then state.applied=false;return false end
    if state.applied==enabled and (not enabled or not changed) then return false end
    -- Both commands are used because different Stalker 2 builds expose the
    -- player and faction damage switches differently. Property write is a fallback.
    for _,command in ipairs(M.commands(enabled)) do
        system:ExecuteConsoleCommand(controller,command,controller)
    end
    if enabled then state.pawn.bCanBeDamaged=false else state.pawn.bCanBeDamaged=state.damage end
    state.applied=enabled
    return true
end
function M.restore(state) restore(state) end
return M
