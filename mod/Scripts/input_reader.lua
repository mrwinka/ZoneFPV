local M={}
function M.read(path)
    local ok,file=pcall(io.open,path,'r')
    if not ok or not file then return nil end
    -- A failed file exchange is a missing sample, never a reason to abort
    -- the whole callback. main.lua still enforces the 250 ms input lease.
    local readOk,line=pcall(function() return file:read(512) end)
    pcall(function() file:close() end)
    if readOk and type(line)=='string' then return line end
end
-- One atomic snapshot per game callback. Menu locking and flight controls
-- consume the same producer state, without a second Windows file exchange.
-- The caller advances the frame token every callback; failed/invalid reads
-- are cached only for that frame, never turned into a new freshness lease.
function M.frame(read,parse)
    assert(type(read)=='function'and type(parse)=='function','input frame requires reader and parser')
    local token,captured,sample
    local counts={reads=0,parses=0}
    local function sampleFrame(frame)
        assert(frame~=nil,'input frame requires a callback token')
        if not captured or frame~=token then
            token,captured=frame,true
            counts.reads=counts.reads+1;counts.parses=counts.parses+1
            local ok,line=pcall(read)
            local parsed,value=pcall(parse,ok and line or nil)
            sample=parsed and value or nil
        end
        return sample
    end
    return sampleFrame,counts
end
return M
