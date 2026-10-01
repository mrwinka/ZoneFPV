-- Suppress player camera modifiers only during FPV; restore their prior state.
local M={}
local function valid(o) return o and o:IsValid() end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function() return a:GetAddress()==b:GetAddress() end)
    return ok and value
end
local function attempt(state,key,fn)
    if state.unsupported[key] then return end
    local ok,err=pcall(fn)
    if not ok then
        state.unsupported[key]=true
        print('[ZoneFPV] Visual guard unavailable: '..key..' / '..tostring(err)..'\n')
    end
    return ok
end
local function restoreVolume(entry)
    pcall(function() if valid(entry.object) then entry.object.bEnabled=entry.enabled end end)
end
local function restoreVolumes(g)
    for id,entry in pairs(g.volumes or {}) do
        restoreVolume(entry)
        g.volumes[id]=nil
    end
end
local function restoreModifier(entry)
    pcall(function() if valid(entry.object) and not entry.disabled then entry.object:EnableModifier() end end)
end
local function restoreCamera(g)
    for id,entry in pairs(g.modifiers) do restoreModifier(entry);g.modifiers[id]=nil end
    pcall(function() if valid(g.camera) and g.colorEnabled~=nil then g.camera.bEnableColorScaling=g.colorEnabled end end)
    g.colorEnabled=nil
end
local function cvar(g,s,system,name,wanted)
    attempt(g,name,function()
        local original=g.cvars[name]
        if wanted==nil then
            if original~=nil then
                system:ExecuteConsoleCommand(s.pc,name..' '..tostring(original),s.pc)
                g.cvars[name]=nil
            end
            return
        end
        local current=system:GetConsoleVariableIntValue(name)
        if original==nil then g.cvars[name]=current end
        if current~=wanted then system:ExecuteConsoleCommand(s.pc,name..' '..wanted,s.pc) end
    end)
end
function M.update(s,now,system,playerMode,clearWeather)
    local g=s.visualGuard
    if g and (not same(g.world,s.world) or not same(g.pc,s.pc)) then M.restore(s);g=nil end
    if not g then
        g={world=s.world,worldId=s.world and s.world:GetAddress(),pc=s.pc,modifiers={},volumes={},cvars={},unsupported={},nextScan=0,nextClear=0,nextVariables=0,nextVolumes=0}
        s.visualGuard=g
    end
    if system and (now>=g.nextVariables or g.clearWeather~=clearWeather) then
        g.nextVariables=now+0.25;g.system=system;g.clearWeather=clearWeather
        -- Region scripts can reset these while the pawn crosses a volume.
        cvar(g,s,system,'r.PostProcessing.DisableMaterials',1)
        -- Only an explicit Clear selection opts into fog suppression. Restore on
        -- another preset or FPV exit; do not remove intentionally selected fog.
        cvar(g,s,system,'r.Fog',clearWeather and 0 or nil)
        cvar(g,s,system,'r.VolumetricFog',clearWeather and 0 or nil)
        cvar(g,s,system,'r.LocalFogVolume',clearWeather and 0 or nil)
    end
    if not playerMode then restoreVolumes(g)
    elseif now>=g.nextVolumes then
        g.nextVolumes=now+3
        attempt(g,'regional post-process volumes',function()
            for id,entry in pairs(g.volumes) do
                if not valid(entry.object) then g.volumes[id]=nil
                elseif not same(entry.object:GetWorld(),g.world) then restoreVolume(entry);g.volumes[id]=nil end
            end
            local candidates=FindAllOf('PostProcessVolume') or {}
            for _,v in ipairs(FindAllOf('PostProcessComponent') or {}) do candidates[#candidates+1]=v end
            local seen={}
            for _,volume in ipairs(candidates) do
                if valid(volume) then
                    local id=volume:GetAddress()
                    if not seen[id] and not g.volumes[id] then
                        seen[id]=true
                        -- Bounded effects need no name reflection; accepted
                        -- objects keep their classification for this flight.
                        local selected=not volume.bUnbound
                        if not selected then
                            local name=volume:GetFullName():lower()
                            selected=name:find('psy',1,true) or name:find('anomal',1,true)
                        end
                        if selected then
                            local world=volume:GetWorld()
                            if valid(world) and world:GetAddress()==g.worldId then
                                local key='volume '..tostring(id);g.unsupported[key]=nil
                                g.volumes[id]={object=volume,key=key,enabled=volume.bEnabled}
                            end
                        end
                    end
                end
            end
        end)
    end
    if now<g.nextClear then return end
    for id,entry in pairs(g.volumes) do
        if not valid(entry.object) then g.volumes[id]=nil
        else attempt(g,entry.key,function() if entry.object.bEnabled then entry.object.bEnabled=false end end) end
    end
    local cm=s.pc.PlayerCameraManager
    if not valid(cm) then return end
    if not same(g.camera,cm) then
        restoreCamera(g);g.camera=cm;g.nextScan=0
        for _,key in ipairs({'modifiers','camera shakes','lens effects','camera fade','color scale'}) do g.unsupported[key]=nil end
    end
    if now>=g.nextScan then
        g.nextScan=now+0.5
        local seen={}
        local scanned=attempt(g,'modifiers',function()
            cm.ModifierList:ForEach(function(_,ref)
                local modifier=ref:get()
                if valid(modifier) then
                    local id=modifier:GetAddress()
                    seen[id]=true
                    if not g.modifiers[id] or not valid(g.modifiers[id].object) then
                        local key='modifier '..tostring(id);g.unsupported[key]=nil
                        g.modifiers[id]={object=modifier,key=key,disabled=modifier:IsDisabled()}
                    end
                end
            end)
        end)
        if scanned then
            for id,entry in pairs(g.modifiers) do
                if not seen[id] then restoreModifier(entry);g.modifiers[id]=nil end
            end
        end
    end
    for id,entry in pairs(g.modifiers) do
        if not valid(entry.object) then g.modifiers[id]=nil
        else attempt(g,entry.key,function()
            if not entry.object:IsDisabled() then entry.object:DisableModifier(true) end
        end) end
    end
    if now>=g.nextClear then
        g.nextClear=now+0.1
        attempt(g,'camera shakes',function() cm:StopAllCameraShakes(true) end)
        attempt(g,'lens effects',function() cm:ClearCameraLensEffects() end)
        attempt(g,'camera fade',function() cm:StopCameraFade() end)
        attempt(g,'color scale',function()
            if g.colorEnabled==nil then g.colorEnabled=cm.bEnableColorScaling end
            if cm.bEnableColorScaling then cm.bEnableColorScaling=false end
        end)
    end
end
function M.restore(s)
    local g=s.visualGuard;if not g then return end
    for name,value in pairs(g.cvars) do
        pcall(function() g.system:ExecuteConsoleCommand(g.pc,name..' '..tostring(value),g.pc) end)
    end
    restoreVolumes(g)
    restoreCamera(g)
    s.visualGuard=nil
end
return M
