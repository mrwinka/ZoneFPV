local M={}
local allowed={freeze=true,npcs=true,god=true,hotstart=true}
function M.load(root)
    local cfg={}
    for key in pairs(allowed) do
        local file=io.open(root..key..'-settings.txt','r')
        if file then local text=file:read(16);file:close();cfg[key]=text and text:match('^1%s*$')~=nil or false
        else cfg[key]=false end
    end
    return cfg
end
function M.save(root,cfg,key,enabled)
    if not allowed[key] or type(enabled)~='boolean' then return false end
    local file=io.open(root..key..'-settings.txt','w');if not file then return false end
    local ok=file:write(enabled and '1\n' or '0\n');local closed=file:close()
    if not ok or not closed then return false end
    cfg[key]=enabled;return true
end
return M
