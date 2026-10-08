local M={}
function M.new(execute,clock,log,method)
    method=method~=nil and method or (EGameThreadMethod and EGameThreadMethod.EngineTick)
    local retryAt=0
    local scheduler={
        ready=function() return clock()>=retryAt end,
        post=function(callback)
            -- The installed ProcessEvent dispatcher drains Lua on ANY calling
            -- thread, including async loading workers. Only EngineTick owns
            -- the game thread. Missing support fails closed, without fallback.
            local ok,err=pcall(function()
                assert(type(method)=='number','EngineTick dispatch unavailable; install the v10 runtime settings')
                execute(callback,method)
            end)
            if not ok then
                retryAt=clock()+5
                log('EngineTick dispatch failed; retry in 5 seconds: '..tostring(err))
            end
            return ok
        end,
    }
    function scheduler.start(callback,interval)
        -- Lua coroutines share their heap. A LoopAsync worker can run the
        -- collector while a game-thread callback is using Lua's FILE* stack.
        -- Renew the queue through EngineTick and never enter Unreal on a worker.
        local running,nextRun=true,0
        local step
        step=function()
            if not running then return end
            local now=clock()
            if now>=nextRun then
                nextRun=now+interval
                local ok,err=xpcall(callback,debug.traceback)
                if not ok then log('Game-thread loop: '..tostring(err)) end
            end
            if running and not scheduler.post(step) then running=false end
        end
        running=scheduler.post(step)
        return running,function() running=false end
    end
    return scheduler
end
return M
