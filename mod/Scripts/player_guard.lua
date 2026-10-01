-- Preserve pre-flight exposure; only suppress the player's Geiger audio.
local M={}
-- Explicit getter/setter pairs confirmed in the live reflected API inventory.
-- These are scalar state values, not the full timed-effect registry.
local states={
    {'GetCurrentPsyPoints','SetCurrentPsyPoints'},
    {'GetBleeding','ForceSetBleeding'},
    {'GetCurrentHungerPoints','ForceSetCurrentHungerPoints'},
    {'GetCurrentThirstPoints','SetCurrentThirstPoints'},
    {'GetCurrentSleepinessPoints','SetCurrentSleepinessPoints'},
    {'GetCurrentPoppyFieldSleepiness','SetCurrentPoppyFieldSleepiness'},
}
local function get(o,name)
    return pcall(function() return o[name](o) end)
end
local function set(o,name,value)
    return pcall(function() return o[name](o,value) end)
end
local function field(o,name)
    local ok,value=pcall(function() return o[name] end)
    if ok then return value,true end
    return nil,false
end
local function valid(o)
    if not o then return false end
    local ok,value=pcall(function() return o:IsValid() end)
    return ok and value
end
local function restoreAudio(state)
    if valid(state.object) then set(state.object,'SetVolumeMultiplier',state.volume) end
end
local function restoreGeiger(state)
    local counter=state.object
    if valid(counter) then
        if state.percent~=nil then set(counter,'SetRadiationPercent',state.percent) end
        if state.tick~=nil then set(counter,'SetComponentTickEnabled',state.tick) end
    end
end
local function replace(entries,id,object,restore)
    for oldId,state in pairs(entries) do
        if oldId~=id or (state.object~=object and not valid(state.object)) then restore(state);entries[oldId]=nil end
    end
end
local function correct(o,getter,setter,wanted)
    local ok,current=get(o,getter)
    if not ok or current~=wanted then set(o,setter,wanted) end
end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function() return a:GetAddress()==b:GetAddress() end)
    return ok and value
end
function M.update(s)
    local p=s.pawn
    local g=s.playerGuard
    if g and not same(g.pawn,p) then M.restore(s);g=nil end
    if not g then
        g={pawn=p,audio={},geiger={},states={}};s.playerGuard=g
        for _,pair in ipairs(states) do
            local ok,value=get(p,pair[1])
            if ok and type(value)=='number' and value==value and math.abs(value)<math.huge then
                g.states[#g.states+1]={getter=pair[1],setter=pair[2],value=value}
            end
        end
        local ok,value=get(p,'GetRadiation');if ok and type(value)=='number' then g.radiation=value end
        ok,value=get(p,'GetCurrentEnvironmentRadiationValue');if ok and type(value)=='number' then g.environment=value end
        ok,value=get(p,'AreFootstepsEnabled');if ok and type(value)=='boolean' then g.footsteps=value end
    end
    if g.radiation~=nil then correct(p,'GetRadiation','ForceSetRadiation',0) end
    if g.environment~=nil then correct(p,'GetCurrentEnvironmentRadiationValue','SetCurrentEnvironmentRadiationValue',0) end
    if g.footsteps~=nil then correct(p,'AreFootstepsEnabled','SetFootstepsEnabled',false) end
    for _,state in ipairs(g.states) do
        correct(p,state.getter,state.setter,state.value)
    end
    local audio,audioKnown=field(p,'AudioGeiger')
    local audioId=valid(audio) and audio:GetAddress() or nil
    if audioKnown then replace(g.audio,audioId,audio,restoreAudio) end
    if audioId then
        local id=audioId
        if g.audio[id]==nil then
            local volume=field(audio,'VolumeMultiplier')
            if type(volume)=='number' then g.audio[id]={object=audio,volume=volume} end
        end
        if g.audio[id]~=nil and field(audio,'VolumeMultiplier')~=0 then set(audio,'SetVolumeMultiplier',0) end
    end
    local counter,counterKnown=field(p,'GeigerCounterComponent')
    local counterId=valid(counter) and counter:GetAddress() or nil
    if counterKnown then replace(g.geiger,counterId,counter,restoreGeiger) end
    if counterId then
        local id=counterId
        if not g.geiger[id] then
            local state={object=counter};g.geiger[id]=state
            local ok,value=get(counter,'GetRadiationPercent');if ok then state.percent=value end
            ok,value=get(counter,'IsComponentTickEnabled');if ok then state.tick=value end
        end
        local state=g.geiger[id]
        if state.percent~=nil then correct(counter,'GetRadiationPercent','SetRadiationPercent',0) end
        if state.tick~=nil then correct(counter,'IsComponentTickEnabled','SetComponentTickEnabled',false) end
    end
end
function M.restore(s)
    local g=s.playerGuard;if not g then return end
    -- Called after the pawn returns home; each operation is independent.
    local p=g.pawn
    if g.radiation~=nil then set(p,'ForceSetRadiation',g.radiation) end
    if g.environment~=nil then set(p,'SetCurrentEnvironmentRadiationValue',g.environment) end
    if g.footsteps~=nil then set(p,'SetFootstepsEnabled',g.footsteps) end
    for _,state in ipairs(g.states) do set(p,state.setter,state.value) end
    for _,state in pairs(g.audio) do restoreAudio(state) end
    for _,state in pairs(g.geiger) do restoreGeiger(state) end
    s.playerGuard=nil
end
return M
