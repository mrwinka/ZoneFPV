-- Level actions require an eligible fresh source; repeats never catch up after
-- a menu/pause/stall and never replay a switch held across an in-game menu.
local M={names={'menu','pilot','reset','collect','flashlight','cameraDown','grenadeDrop','vision'},
    intervals={collect=.35,grenadeDrop=.25}}
function M.new()
    local previous,blocked,nextRepeat={},{},{}
    return {clear=function()previous={};blocked={};nextRepeat={}end,
        update=function(_,packet,allowed,now,modes,keys,suspended)
            local result={pressed={},released={},pulse={}}
            local eligible=allowed and packet and packet.ready and packet.focused and packet.active~=false
                and type(now)=='number'and now==now and math.abs(now)<math.huge
            -- A bounded axis-only wait does not invalidate an independently
            -- fresh action source. Keep existing levels without new actions.
            local continuity=not eligible and suspended and packet and packet.ready and packet.focused and packet.active~=false
                and type(now)=='number'and now==now and math.abs(now)<math.huge
            for i,name in ipairs(M.names)do
                local raw=not not(packet and packet[name..'Held'])
                local source=packet and type(packet.sourceHeld)=='number'and (packet.sourceHeld & (1 << (i-1)))~=0 or raw
                if not eligible and not continuity then blocked[name]=blocked[name]or source or previous[name]
                elseif continuity and not previous[name]and source then blocked[name]=true
                elseif not source then blocked[name]=false end
                local held=not not((eligible or continuity and previous[name])and not blocked[name]and modes[name]==1 and keys[i]~=0 and raw)
                result[name]=held;result.pressed[name]=held and not previous[name]or false
                result.released[name]=not held and previous[name]or false
                local interval=M.intervals[name]
                if interval and held and eligible then
                    if not previous[name]or not nextRepeat[name]or now>=nextRepeat[name]then
                        result.pulse[name]=true;nextRepeat[name]=now+interval
                    end
                else nextRepeat[name]=nil end
                previous[name]=held
            end
            return result
        end}
end
return M
