-- Optional prototype features. A fixed numeric protocol keeps the native menu
-- from dispatching arbitrary console commands or executable configuration.
local M={names={'style','obstacles','characters','anomaliesScan','droneHP','reaction','anomalyInterference','anomalyDamage','detector'}}
function M.defaults()
    local v={style=0}
    for i=2,#M.names do v[M.names[i]]=false end
    return v
end
function M.parse(text)
    if type(text)~='string' or #text>64 then return end
    local values={}
    for token in text:gmatch('%S+') do
        if not token:match('^%d$') then return end
        values[#values+1]=tonumber(token)
    end
    if #values~=#M.names or values[1]>4 then return end
    local settings={style=values[1]}
    for i=2,#values do
        if values[i]>1 then return end
        settings[M.names[i]]=values[i]==1
    end
    return settings
end
function M.load(root)
    local f=io.open(root..'experiment-settings.txt','r')
    if not f then return M.defaults() end
    local value=f:read(66);f:close()
    return value and M.parse(value:match('^1 (.*)')) or M.defaults()
end
function M.save(root,settings,text)
    local parsed=M.parse(text);if not parsed then return false end
    local f=io.open(root..'experiment-settings.txt','w');if not f then return false end
    local wrote=f:write('1 '..text..'\n');local closed=f:close()
    if not wrote or not closed then return false end
    for _,name in ipairs(M.names) do settings[name]=parsed[name] end
    return true
end
return M
