-- Collision damage multiplier is independent of enemy/anomaly experiments.
local M={default=2}
function M.parse(text)
    if type(text)~='string' or #text>24 then return end
    local token=text:match('^([%d%.]+)%s*$')
    if not token or not (token:match('^%d+$') or token:match('^%d+%.%d+$')) then return end
    local value=tonumber(token)
    if value and value>=0 and value<=5 then return value end
end
function M.load(root)
    local f=io.open(root..'impact-settings.txt','r');if not f then return M.default end
    local value=M.parse(f:read(25));f:close();return value or M.default
end
function M.save(root,text)
    local value=M.parse(text);if value==nil then return false end
    local f=io.open(root..'impact-settings.txt','w');if not f then return false end
    local wrote=f:write(string.format('%.6f\n',value));local closed=f:close()
    return not not (wrote and closed),value
end
return M
