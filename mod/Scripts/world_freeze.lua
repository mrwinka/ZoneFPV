local M={}
function M.set(s,enabled,gameplay)
    if enabled and not s.freezeOwned then
        assert(not gameplay:IsGamePaused(s.pc),'World is already paused')
        s.previousFullTick=s.pc.bShouldPerformFullTickWhenPaused
        s.previousPauseTick=s.pc.PrimaryActorTick.bTickEvenWhenPaused
        s.freezePrepared=true
        s.pc.bShouldPerformFullTickWhenPaused=true
        s.pc:SetTickableWhenPaused(true)
        s.camera:SetTickableWhenPaused(true)
        s.freezeOwned=true -- rollback also covers a partially successful call
        assert(gameplay:SetGamePaused(s.pc,true),'Game refused world pause')
    elseif not enabled then
        local errors={}
        local function restore(fn)
            local ok,err=pcall(fn);if not ok then errors[#errors+1]=tostring(err) end
        end
        if s.freezeOwned then
            restore(function()
                if gameplay:IsGamePaused(s.pc) then
                    gameplay:SetGamePaused(s.pc,false)
                    assert(not gameplay:IsGamePaused(s.pc),'Game refused world resume')
                end
                s.freezeOwned=false
            end)
        end
        if s.freezePrepared then
            restore(function() s.pc.bShouldPerformFullTickWhenPaused=s.previousFullTick end)
            restore(function() s.pc:SetTickableWhenPaused(s.previousPauseTick) end)
            s.freezePrepared=false
        end
        assert(#errors==0,table.concat(errors,'; '))
    end
end
return M
