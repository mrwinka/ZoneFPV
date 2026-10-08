-- Version2 follows binding/action packet order; version1 keeps its old order.
local M={names={'menu','pilot','reset','collect','flashlight','cameraDown','grenadeDrop','vision'}}
local function mode(value)return value==0 or value==1 end
function M.defaults()local result={};for _,key in ipairs(M.names)do result[key]=0 end;return result end
function M.parse(text)
    if type(text)~='string' or #text>80 then return end
    local values={}
    for token in text:gmatch('%S+')do
        if #values>=9 or not token:match('^[012]$')then return end
        values[#values+1]=tonumber(token)
    end
    local result=M.defaults()
    for i=2,#values do if not mode(values[i])then return end end
    if values[1]==1 and (#values==3 or #values==4)then
        result.cameraDown,result.vision,result.flashlight=values[2],values[3],values[4]or 0
    elseif values[1]==2 and #values==9 then
        for i,key in ipairs(M.names)do result[key]=values[i+1]end
    else return end
    return result
end
function M.load(root)
    local f=io.open(root..'action-modes.txt','r')
    if not f then return M.defaults()end
    local text=f:read(81);f:close()
    return M.parse(text)or M.defaults()
end
function M.save(root,current,name,value)
    if not mode(value)then return false end
    local result={};local known=false
    for _,key in ipairs(M.names)do
        if key==name then known=true end
        result[key]=key==name and value or current[key]or 0
        if not mode(result[key])then return false end
    end
    if not known then return false end
    local f=io.open(root..'action-modes.txt','w');if not f then return false end
    local fields={'2'};for _,key in ipairs(M.names)do fields[#fields+1]=tostring(result[key])end
    local ok=f:write(table.concat(fields,' ')..'\n')
    local closed=f:close()
    if not ok or not closed then return false end
    return true,result
end
return M
