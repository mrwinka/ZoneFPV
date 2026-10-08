local M={}
function M.parse(text)
    if type(text)=='string' then return tonumber(text:match('^([0-5])%s*$')) end
end
function M.load(root)
    local f=io.open(root..'anomaly-noise-style.txt','r');if not f then return 0 end
    local v=M.parse(f:read(16));f:close();return v or 0
end
function M.save(root,value)
    local v=M.parse(tostring(value));if not v then return false end
    local f=io.open(root..'anomaly-noise-style.txt','w');if not f then return false end
    local ok=f:write(v..'\n');return f:close() and ok and true or false,v
end
-- 0 follows the radio style; 1..5 select a separate style near anomalies.
function M.style(normal,choice,active)
    return active and choice>0 and choice-1 or normal
end
return M
