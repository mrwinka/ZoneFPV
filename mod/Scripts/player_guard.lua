-- Preserve pre-flight exposure; suppress player sleep sources and Geiger audio
-- during FPV without removing timed effects or changing world anomaly actors.
local M={}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
M.nativeGeiger=here and dofile(here..'native_geiger.lua')
-- Explicit getter/setter pairs confirmed in the live reflected API inventory.
-- These are scalar state values, not the full timed-effect registry.
local states={
    {'GetCurrentPsyPoints','SetCurrentPsyPoints'},
    {'GetBleeding','ForceSetBleeding'},
    {'GetCurrentHungerPoints','ForceSetCurrentHungerPoints'},
    {'GetCurrentThirstPoints','SetCurrentThirstPoints'},
    {'GetCurrentSleepinessPoints','SetCurrentSleepinessPoints',0},
    {'GetCurrentPoppyFieldSleepiness','SetCurrentPoppyFieldSleepiness',0},
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
    if state.native then
        if state.nativeReady and type(state.native.poll)=='function' then
            pcall(state.native.poll,state.native)
            print('[ZoneFPV] Player Geiger native updates blocked: '..tostring(state.native.blocked or 0)..'; active loops stopped: '..tostring(state.native.stopped or 0)..'\n')
        end
        state.native:disarm()
    end
    local counter=state.object
    if valid(counter) then
        if state.percent~=nil then set(counter,'SetRadiationPercent',state.percent) end
        if state.tick~=nil then set(counter,'SetComponentTickEnabled',state.tick) end
    end
    if state.wwisePaused and valid(state.wwiseEvent) and valid(state.pawn) then
        -- Match only the single actor/event Pause owned by this guard. Resume
        -- preserves the existing loop; Stop/Play would restart it on exit.
        pcall(function()state.wwiseEvent:ExecuteAction(2,state.pawn,0,0,4)end)
        state.wwisePaused=false
    end
end
local function pauseGeiger(state,pawn)
    if state.wwisePaused or (state.wwiseAttempts or 0)>=3 or state.tick==nil or not valid(pawn) then return end
    local event=field(state.object,'SFXStartEvent')
    if not valid(event) and type(StaticFindObject)=='function' and (state.wwiseLookups or 0)<2 then
        -- Exact owned event from CoreVariables.GeigerSFXStart. No world audio,
        -- all-actor StopActor, ambient sound classes or global mix are touched.
        local ok,value=pcall(StaticFindObject,'/Game/_STALKER2/Audio/WwiseAudio/Events/Radiation/SFX_GeigerCounter_Play.SFX_GeigerCounter_Play')
        state.wwiseLookups=(state.wwiseLookups or 0)+1
        if ok then event=value end
    end
    if not valid(event) then return end
    state.wwiseAttempts=(state.wwiseAttempts or 0)+1
    local ok,result=pcall(function()return event:ExecuteAction(1,pawn,0,0,4)end)
    -- SDK AkActionOnEventType Pause=1/Resume=2, Curve Linear=4, EAkResult
    -- Success=1. PlayingID=0 selects this event's instances on this actor.
    if ok and result==1 then
        state.wwiseEvent=event;state.pawn=pawn;state.wwisePaused=true
        print('[ZoneFPV] Player Geiger Wwise loop paused for FPV; component tick held off.\n')
    elseif not state.wwiseFailureReported then
        state.wwiseFailureReported=true
        print('[ZoneFPV] Player Geiger event pause unavailable: '..tostring(result)..'\n')
    end
end
local function gateGeiger(state,pawn)
    if state.nativeAttempted or not M.nativeGeiger then return end
    state.nativeAttempted=true;state.native=M.nativeGeiger.new(here..'../')
    local ok,result,why=pcall(state.native.arm,state.native,state.object,pawn)
    state.nativeReady=ok and result==true
    state.nextNativePoll=os.clock()+1
    print('[ZoneFPV] Player Geiger native update gate: '..(state.nativeReady and 'armed for owned component' or tostring(ok and why or result))..'\n')
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
local function stopHooks(g)
    g.active=false
    for _,h in ipairs(g.hooks or {}) do pcall(UnregisterHook,h.path,h.pre,h.post) end
    g.hooks={}
end
local function startHooks(g)
    g.hooks={};g.active=true
    if type(RegisterHook)~='function' or type(UnregisterHook)~='function' then return end
    local ok,address=pcall(function()return g.pawn:GetAddress()end)
    if not ok or address==nil then return end
    local hookStates={}
    for _,state in ipairs(g.states)do hookStates[#hookStates+1]=state end
    if g.radiation~=nil then hookStates[#hookStates+1]={setter='ForceSetRadiation',wanted=0} end
    if g.environment~=nil then hookStates[#hookStates+1]={setter='SetCurrentEnvironmentRadiationValue',wanted=0} end
    for _,state in ipairs(hookStates) do
        if state.wanted==0 then
            local path='/Script/Stalker2.Obj:'..state.setter
            -- Captured signature: one FloatProperty argument. A native pre-hook
            -- prevents a reflected setter from briefly enabling eyelid effects
            -- between updates. Native C++ paths can bypass this UFunction thunk;
            -- suppress() independently corrects their scalar values each frame.
            local got,err=pcall(function()
                local pre,post=RegisterHook(path,function(context,value)
                    if not g.active then return end
                    local accepted=pcall(function()
                        local owner=context:get()
                        if valid(owner) and owner:GetAddress()==address then value:set(0) end
                    end)
                    if not accepted then g.hookCallbackFailure=true end
                end)
                assert(type(pre)=='number' and type(post)=='number','player state hook IDs unavailable')
                g.hooks[#g.hooks+1]={path=path,pre=pre,post=post}
            end)
            if not got then
                print('[ZoneFPV] Player state setter observer unavailable: '..state.setter..' / '..tostring(err)..'\n')
            end
        end
    end
end
-- Cheap game-frame path. The slower update retains audio/Geiger housekeeping.
function M.suppress(s)
    local g=s.playerGuard
    if not g or not same(g.pawn,s.pawn) then return end
    if g.radiation~=nil then correct(g.pawn,'GetRadiation','ForceSetRadiation',0) end
    if g.environment~=nil then correct(g.pawn,'GetCurrentEnvironmentRadiationValue','SetCurrentEnvironmentRadiationValue',0) end
    for _,state in pairs(g.geiger)do
        if state.nativeReady and state.native:tick()==false then state.nativeReady=false end
    end
    for _,state in ipairs(g.states) do
        if state.wanted==0 or state.getter=='GetBleeding' and s.combat and s.combat.reactionReady then
            correct(g.pawn,state.getter,state.setter,0)
        end
    end
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
                g.states[#g.states+1]={getter=pair[1],setter=pair[2],value=value,wanted=pair[3]}
            end
        end
        local ok,value=get(p,'GetRadiation');if ok and type(value)=='number' then g.radiation=value end
        ok,value=get(p,'GetCurrentEnvironmentRadiationValue');if ok and type(value)=='number' then g.environment=value end
        ok,value=get(p,'AreFootstepsEnabled');if ok and type(value)=='boolean' then g.footsteps=value end
        startHooks(g)
    end
    if g.radiation~=nil then correct(p,'GetRadiation','ForceSetRadiation',0) end
    if g.environment~=nil then correct(p,'GetCurrentEnvironmentRadiationValue','SetCurrentEnvironmentRadiationValue',0) end
    if g.footsteps~=nil then correct(p,'AreFootstepsEnabled','SetFootstepsEnabled',false) end
    for _,state in ipairs(g.states) do
        local wanted=state.wanted~=nil and state.wanted or state.value
        if state.getter=='GetBleeding' and s.combat and s.combat.reactionReady then wanted=0 end
        correct(p,state.getter,state.setter,wanted)
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
        gateGeiger(state,p)
        if state.nativeReady and type(state.native.poll)=='function' and os.clock()>=state.nextNativePoll then
            state.nextNativePoll=os.clock()+1
            local ok,ready,why=pcall(state.native.poll,state.native)
            if not ok or ready~=true then
                state.nativeReady=false;state.native:disarm()
                print('[ZoneFPV] Player Geiger native guard stopped: '..tostring(ok and why or ready)..'; scoped event fallback.\n')
            end
        end
        if not state.nativeReady then pauseGeiger(state,p) end
    end
end
function M.restore(s)
    local g=s.playerGuard;if not g then return end
    -- Deactivate callbacks before restoring nonzero pre-flight sleep values.
    stopHooks(g)
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
