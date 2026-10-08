local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local modes=dofile(here..'vision_modes.lua')
local M={default=0,max=modes.max}
function M.parse(text)
    if type(text)~='string' or #text>16 then return end
    local n=text:match('^(%d%d?)%s*$')
    if not n or (#n>1 and n:sub(1,1)=='0')then return end
    n=tonumber(n)
    return modes.valid(n) and n or nil
end
function M.load(root)
    local f=io.open(root..'vision-settings.txt','r');if not f then return M.default end
    local n=M.parse(f:read(17));f:close();return n or M.default
end
function M.save(root,text)
    local n=M.parse(text);if n==nil then return false end
    local f=io.open(root..'vision-settings.txt','w');if not f then return false end
    local wrote=f:write(n..'\n');local closed=f:close()
    return not not (wrote and closed),n
end
return M
