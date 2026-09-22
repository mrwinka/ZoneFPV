local M={}
M.keys={33,34,35,36,45,46}
for k=65,90 do M.keys[#M.keys+1]=k end
for k=112,123 do M.keys[#M.keys+1]=k end
function M.valid_keys(a,b,c)
    local allowed={};for _,k in ipairs(M.keys) do allowed[k]=true end
    return allowed[a] and allowed[b] and allowed[c] and a~=b and a~=c and b~=c or false
end
function M.load(root)
    local result={mode='acro',keys={117,119,120}}
    local f=io.open(root..'pilot-mode.txt','r');if f then local v=f:read(16);f:close();v=v and v:match('^(%w+)');if v=='acro' or v=='angle' or v=='3d' then result.mode=v end end
    f=io.open(root..'bindings.txt','r');if f then local text=f:read(100) or '';f:close();local a,b,c=text:match('^(%d+) (%d+) (%d+)%s*$');a,b,c=tonumber(a),tonumber(b),tonumber(c);if M.valid_keys(a,b,c) then result.keys={a,b,c} end end
    return result
end
function M.save(root,name,value)
    local f=io.open(root..name..'.txt','w');if not f then return false end
    local ok=f:write(value..'\n');local closed=f:close();return not not(ok and closed)
end
return M
