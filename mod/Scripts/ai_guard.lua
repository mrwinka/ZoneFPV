-- Retain the confirmed human-NPC fix; remove the unsuccessful Flair experiment.
-- No verified prior-state getter: exit re-enables features dispatched here.
-- Not compatible with external settings intentionally keeping those features off.
local M={}
local features={'SeePlayer'}
local function valid(o)
    local ok,value=pcall(function() return o and o:IsValid() end)
    return ok and value
end
function M.start(s,system,log)
    if s.aiGuard then return end
    local g={pending={},system=system};s.aiGuard=g
    local ok,err=pcall(function()
        local enum=StaticFindObject('/Script/Stalker2.EAIFeature')
        assert(valid(enum),'EAIFeature enum unavailable')
        local available={}
        enum:ForEachName(function(name,value)
            local short=name:ToString():match('([^:]+)$')
            if short and type(value)=='number' then available[short]=true end
        end)
        for _,name in ipairs({'XDeactivateAIFeature','XActivateAIFeature'}) do
            assert(valid(StaticFindObject('/Script/Stalker2.CustomConsoleManagerAM:'..name)),name..' unavailable')
        end
        for _,feature in ipairs(features) do
            if available[feature] then
                -- Record before dispatch so partial success still gets restoration.
                g.pending[feature]=true
                local sent,why=pcall(function()
                    system:ExecuteConsoleCommand(s.pc,'XDeactivateAIFeature '..feature,s.pc)
                end)
                log(sent and ('AI: requested '..feature..' off during FPV') or
                    ('AI: '..feature..' dispatch failed: '..tostring(why)))
            else log('AI: feature unavailable on this build: '..feature) end
        end
    end)
    if not ok then log('AI detection guard unavailable: '..tostring(err)) end
end
function M.restore(s,log)
    local g=s.aiGuard;if not g then return end
    local errors={}
    for _,feature in ipairs(features) do
        if g.pending[feature] then
            local ok,err=pcall(function()
                g.system:ExecuteConsoleCommand(s.pc,'XActivateAIFeature '..feature,s.pc)
            end)
            if ok then g.pending[feature]=nil;log('AI: requested '..feature..' on after FPV')
            else errors[#errors+1]=feature..': '..tostring(err) end
        end
    end
    if #errors>0 then error(table.concat(errors,'; ')) end
    s.aiGuard=nil
end
return M
