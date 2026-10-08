-- The three concrete binocular item SIDs in the game's ItemPrototypes.cfg.
local M={ids={'Binoculars_01','Binoculars_02','Binoculars_03'}}
function M.give(controller,library,log)
    if not controller or not controller:IsValid() or not controller.Pawn or not controller.Pawn:IsValid()
        or not library or not library:IsValid() then return false end
    for _,id in ipairs(M.ids) do
        -- Player inventory UID 0, one item, full durability. Do not enable cheats globally.
        local ok,err=pcall(function() library:ExecuteConsoleCommand(controller,
            'XCreateItemInInventoryByID '..id..' 0 1 1',controller) end)
        if not ok then log('Binocular request failed: '..id..' / '..tostring(err));return false end
        log('Binocular inventory request sent: '..id)
    end
    -- ExecuteConsoleCommand has no item-delivery return value: this acknowledges
    -- dispatch only. Check the actual inventory in game.
    return true
end
return M
