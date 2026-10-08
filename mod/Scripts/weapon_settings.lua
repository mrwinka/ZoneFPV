-- Armament is chosen before launch and copied into the flight session.
local M={maxMode=3,minPower=.25,maxPower=5,powerStep=.25,maxGrenade=1,maxCharges=20,
    minImpactSpeed=5,maxImpactSpeed=150,impactSpeedStep=5}
function M.hasKamikaze(mode)return mode==1 or mode==3 end
function M.hasGrenades(mode)return mode==2 or mode==3 end
function M.defaults()return {mode=0,power=1,grenade=0,charges=3,impactSpeed=30}end
local function bounded(value,minimum,maximum,integer)
    return type(value)=='number' and value==value and value>=minimum and value<=maximum
        and (not integer or value%1==0)
end
local function powerValue(value)
    if not bounded(value,M.minPower,M.maxPower)then return end
    local quarter=math.floor(value/M.powerStep+.5)
    if math.abs(value/M.powerStep-quarter)>1e-6 then return end
    return quarter*M.powerStep
end
local function impactValue(value)
    if not bounded(value,M.minImpactSpeed,M.maxImpactSpeed)then return end
    local steps=math.floor(value/M.impactSpeedStep+.5)
    if math.abs(value/M.impactSpeedStep-steps)>1e-6 then return end
    return steps*M.impactSpeedStep
end
function M.value(values)
    local result=M.defaults();values=type(values)=='table' and values or {}
    if bounded(values.mode,0,M.maxMode,true)then result.mode=values.mode end
    result.power=powerValue(values.power)or result.power
    if bounded(values.grenade,0,M.maxGrenade,true)then result.grenade=values.grenade end
    if bounded(values.charges,0,M.maxCharges,true)then result.charges=values.charges end
    result.impactSpeed=impactValue(values.impactSpeed)or result.impactSpeed
    return result
end
function M.parse(text)
    if type(text)~='string' or #text>96 then return end
    local mode,power,grenade,charges,impact=text:match('^%s*(%d+)%s+([%d%.]+)%s+(%d+)%s+(%d+)%s+([%d%.]+)%s*$')
    if not mode then mode,power,grenade,charges=text:match('^%s*(%d+)%s+([%d%.]+)%s+(%d+)%s+(%d+)%s*$')end
    if not mode or not (power:match('^%d+$') or power:match('^%d+%.%d+$'))then return end
    if impact and not (impact:match('^%d+$')or impact:match('^%d+%.%d+$'))then return end
    mode,power,grenade,charges=tonumber(mode),tonumber(power),tonumber(grenade),tonumber(charges)
    power=powerValue(power)
    impact=impact and impactValue(tonumber(impact))or (not impact and M.defaults().impactSpeed)
    if not bounded(mode,0,M.maxMode,true) or not power
        or not bounded(grenade,0,M.maxGrenade,true) or not bounded(charges,0,M.maxCharges,true)or not impact then return end
    return {mode=mode,power=power,grenade=grenade,charges=charges,impactSpeed=impact}
end
function M.load(root)
    local f=io.open(root..'weapon-settings.txt','r');if not f then return M.defaults()end
    local text=f:read(101);f:close();if type(text)~='string'or #text>98 then return M.defaults()end
    local body=type(text)=='string'and text:match('^1%s+(.+)$')
    return M.parse(body)or M.defaults()
end
function M.save(root,values)
    local parsed
    if type(values)=='table'then
        local power=powerValue(values.power)
        local impact=values.impactSpeed==nil and M.defaults().impactSpeed or impactValue(values.impactSpeed)
        if not bounded(values.mode,0,M.maxMode,true)or not power
            or not bounded(values.grenade,0,M.maxGrenade,true)or not bounded(values.charges,0,M.maxCharges,true)or not impact then return false end
        parsed={mode=values.mode,power=power,grenade=values.grenade,charges=values.charges,impactSpeed=impact}
    else parsed=M.parse(values)end
    if not parsed then return false end
    local f=io.open(root..'weapon-settings.txt','w');if not f then return false end
    local wrote=f:write(string.format('1 %d %.6f %d %d %d\n',parsed.mode,parsed.power,parsed.grenade,parsed.charges,parsed.impactSpeed));local closed=f:close()
    return not not(wrote and closed),parsed
end
return M
