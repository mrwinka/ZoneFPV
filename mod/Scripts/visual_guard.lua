-- Suppress player camera modifiers only during FPV; restore their prior state.
local M={}
local function valid(o) return o and o:IsValid() end
local function attempt(state,key,fn)
    if state.unsupported[key] then return end
    local ok,err=pcall(fn)
    if not ok then
        state.unsupported[key]=true
        print('[ZoneFPV] Visual guard unavailable: '..key..' / '..tostring(err)..'\n')
    end
end
function M.update(s,now,system)
    if not s.visualGuard then s.visualGuard={modifiers={},unsupported={},nextScan=0,nextClear=0} end
    local g=s.visualGuard
    if not g.materialsApplied and system then
        attempt(g,'post-process materials',function()
            g.materialValue=system:GetConsoleVariableIntValue('r.PostProcessing.DisableMaterials')
            system:ExecuteConsoleCommand(s.pc,'r.PostProcessing.DisableMaterials 1',s.pc)
            g.system=system;g.materialsApplied=true
        end)
    end
    local cm=s.pc.PlayerCameraManager
    if not valid(cm) then return end
    if now>=g.nextScan then
        g.nextScan=now+0.5
        attempt(g,'modifiers',function()
            cm.ModifierList:ForEach(function(_,ref)
                local modifier=ref:get()
                if valid(modifier) then
                    local id=modifier:GetAddress()
                    if not g.modifiers[id] then
                        g.modifiers[id]={object=modifier,disabled=modifier:IsDisabled()}
                    end
                end
            end)
        end)
    end
    -- Checking cached modifiers is cheap; no global UObject scans or console spam.
    for _,entry in pairs(g.modifiers) do
        attempt(g,'modifier '..tostring(entry.object),function()
            if valid(entry.object) and not entry.object:IsDisabled() then entry.object:DisableModifier(true) end
        end)
    end
    if now>=g.nextClear then
        g.nextClear=now+0.1
        attempt(g,'camera shakes',function() cm:StopAllCameraShakes(true) end)
        attempt(g,'lens effects',function() cm:ClearCameraLensEffects() end)
        attempt(g,'camera fade',function() cm:StopCameraFade() end)
        attempt(g,'color scale',function()
            if g.colorEnabled==nil then g.colorEnabled=cm.bEnableColorScaling end
            cm.bEnableColorScaling=false
        end)
    end
end
function M.restore(s)
    local g=s.visualGuard;if not g then return end
    if g.materialsApplied then
        pcall(function() g.system:ExecuteConsoleCommand(s.pc,'r.PostProcessing.DisableMaterials '..tostring(g.materialValue),s.pc) end)
    end
    for _,entry in pairs(g.modifiers) do
        pcall(function() if valid(entry.object) and not entry.disabled then entry.object:EnableModifier() end end)
    end
    pcall(function()
        local cm=s.pc.PlayerCameraManager
        if valid(cm) and g.colorEnabled~=nil then cm.bEnableColorScaling=g.colorEnabled end
    end)
    s.visualGuard=nil
end
return M
