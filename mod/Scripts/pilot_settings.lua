local M={}
M.keys={}
for k=1,255 do M.keys[#M.keys+1]=k end
-- Only these established keys use UE4SS callbacks for old bridge builds.
-- Its native subscription array has 255 entries (indices 0..254): registering
-- VK255 writes beyond it. Universal keyboard/mouse/controller bindings are
-- handled by the helper and validated separately below.
M.legacy_keys={33,34,35,36,45,46}
for k=65,90 do M.legacy_keys[#M.legacy_keys+1]=k end
for k=112,123 do M.legacy_keys[#M.legacy_keys+1]=k end
function M.valid_code(code)
    return type(code)=='number' and code%1==0 and (code>=0 and code<=255 or
        code>=1001 and code<=1128 or code>=2001 and code<=2032 or code>=3001 and code<=3024) or false
end
function M.valid_keys(a,b,c,d,e,f,g,h)
    if d==nil then d=0 end
    if e==nil then e=0 end
    if f==nil then f=0 end
    if g==nil then g=0 end
    if h==nil then h=0 end
    local seen={}
    for _,code in ipairs({a,b,c,d,e,f,g,h})do
        if not M.valid_code(code) or code~=0 and seen[code] then return false end
        if code~=0 then seen[code]=true end
    end
    return M.valid_code(a) and M.valid_code(b) and M.valid_code(c) and M.valid_code(d) and M.valid_code(e)
        and M.valid_code(f) and M.valid_code(g) and M.valid_code(h)
end
function M.parse(text)
    if type(text)~='string' or #text>128 then return nil end
    local keys={}
    for token in text:gmatch('%S+')do
        if #keys>=8 or not token:match('^%d+$')then return nil end
        local code=tonumber(token)
        if not M.valid_code(code) or tostring(code)~=token then return nil end
        keys[#keys+1]=code
    end
    if #keys<3 or #keys>8 or #keys==6 then return nil end
    for i=4,8 do keys[i]=keys[i] or 0 end
    if not M.valid_keys(table.unpack(keys))then return nil end
    return keys
end
function M.load(root)
    local result={mode='acro',keys={117,119,120,0,0,0,0,0}}
    local f=io.open(root..'pilot-mode.txt','r');if f then local v=f:read(16);f:close();v=v and v:match('^(%w+)');if v=='acro' or v=='angle' or v=='3d' then result.mode=v end end
    f=io.open(root..'bindings.txt','r');if f then local text=f:read(129) or '';f:close();result.keys=M.parse(text) or result.keys end
    return result
end
function M.save(root,name,value)
    local f=io.open(root..name..'.txt','w');if not f then return false end
    local ok=f:write(value..'\n');local closed=f:close();return not not(ok and closed)
end
return M
