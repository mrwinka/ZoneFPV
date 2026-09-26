local M={}
function M.new(execute,clock,log)
    local retryAt=0
    return {
        ready=function() return clock()>=retryAt end,
        post=function(callback)
            -- One argument deliberately preserves UE4SS's configured default.
            -- Never retry with another hook: it may crash this game version.
            local ok,err=pcall(execute,callback)
            if not ok then
                retryAt=clock()+5
                log('Game-thread dispatch failed; retry in 5 seconds: '..tostring(err))
            end
            return ok
        end,
    }
end
return M
