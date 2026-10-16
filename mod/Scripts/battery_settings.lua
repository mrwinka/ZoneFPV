local M={default_capacity=1500,default_cells=6,min_capacity=300,max_capacity=20000}
function M.parse(text)
    if type(text)~='string'or #text>64 then return end
    local enabled,capacity,cells=text:match('^1 ([01]) (%d+) (%d+)%s*$')
    capacity,cells=tonumber(capacity),tonumber(cells)
    if capacity and capacity>=M.min_capacity and capacity<=M.max_capacity and capacity%50==0
        and cells and cells>=2 and cells<=8 then
        return {enabled=enabled=='1',capacity=capacity,cells=cells}
    end
end
function M.load(root)
    local value={enabled=true,capacity=M.default_capacity,cells=M.default_cells}
    local file=io.open(root..'battery-settings.txt','r')
    if file then local parsed=M.parse(file:read(65));file:close();value=parsed or value end
    return value
end
function M.save(root,settings,text)
    local value=M.parse('1 '..tostring(text));if not value then return false end
    local file=io.open(root..'battery-settings.txt','w');if not file then return false end
    local wrote=file:write(string.format('1 %d %d %d\n',value.enabled and 1 or 0,value.capacity,value.cells))
    local closed=file:close();if not wrote or not closed then return false end
    settings.enabled,settings.capacity,settings.cells=value.enabled,value.capacity,value.cells
    return true
end
return M
