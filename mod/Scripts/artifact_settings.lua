-- Collection range is independent of scanner visibility and detector range.
local M={default=3,min=.5,max=10,step=.5}
function M.value(value)
    if type(value)=='number' and value==value and value>=M.min and value<=M.max then return value end
    return M.default
end
function M.parse(text)
    if type(text)~='string' or #text>24 then return end
    local token=text:match('^([%d%.]+)%s*$')
    if not token or not (token:match('^%d+$') or token:match('^%d+%.%d+$')) then return end
    local value=tonumber(token)
    if value and value>=M.min and value<=M.max then return value end
end
function M.load(root)
    local f=io.open(root..'artifact-settings.txt','r');if not f then return M.default end
    local value=M.parse(f:read(25));f:close();return value or M.default
end
function M.save(root,text)
    local value=M.parse(text);if value==nil then return false end
    local f=io.open(root..'artifact-settings.txt','w');if not f then return false end
    local wrote=f:write(string.format('%.6f\n',value));local closed=f:close()
    return not not (wrote and closed),value
end
return M
