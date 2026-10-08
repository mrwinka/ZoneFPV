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
return M
