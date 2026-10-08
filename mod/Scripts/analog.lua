-- Camera-local analog styling. No global rendering variables or player changes.
local M={}
function M.load(root)
    local file=io.open(root..'analog-settings.txt','r')
    if not file then return false end
    local value=file:read(16);file:close()
    return value and value:match('^1%s*$')~=nil or false
end
function M.save(root,enabled)
    if type(enabled)~='boolean' then return false end
    local file=io.open(root..'analog-settings.txt','w');if not file then return false end
    local ok=file:write(enabled and '1\n' or '0\n');local closed=file:close()
    return not not (ok and closed)
end
function M.load_style(root)
    local f=io.open(root..'analog-style.txt','r');if not f then return M.load(root) and 1 or 0 end
    local value=tonumber(f:read(16));f:close();return value and value%1==0 and value>=0 and value<=4 and value or 0
end
function M.save_style(root,style)
    if type(style)~='number' or style%1~=0 or style<0 or style>4 then return false end
    local f=io.open(root..'analog-style.txt','w');if not f then return false end
    local ok=f:write(tostring(style)..'\n');local closed=f:close()
    if not ok or not closed then return false end
    -- The style file is authoritative on load. Keep the legacy boolean in sync
    -- when possible, but do not report a failed command after its style committed.
    M.save(root,style>0)
    return true
end
local fields={'FilmGrainIntensity','FilmGrainTexelSize','FilmGrainIntensityShadows',
    'FilmGrainIntensityMidtones','FilmGrainIntensityHighlights','SceneFringeIntensity',
    'VignetteIntensity','ColorSaturation','ColorContrast'}
local vectors={ColorSaturation=true,ColorContrast=true}
local cameraStates=setmetatable({},{__mode='k'})
local function capture(camera,pp,state,weight)
    if state.originals then return end
    local original={}
    for _,name in ipairs(fields)do
        local value=pp[name]
        local row={value=value,override=pp['bOverride_'..name]}
        if vectors[name] then
            assert(value,'Camera colour settings unavailable')
            row.vector={X=value.X,Y=value.Y,Z=value.Z,W=value.W};row.value=nil
        end
        original[name]=row
    end
    state.originals=original;state.weight=weight
end
function M.apply(camera,enabled,style,state)
    -- A flight passes its own state because reflected UObject access may return
    -- a new Lua wrapper for the same camera. The weak map retains compatibility
    -- with callers that apply directly to a stable camera wrapper.
    if not state then state=cameraStates[camera] or {};cameraStates[camera]=state end
    local weight=camera.PostProcessBlendWeight
    -- Leave the effect disabled if any unsupported property raises an error.
    camera.PostProcessBlendWeight=0
    if not enabled then
        if state.originals then
            local pp=assert(camera.PostProcessSettings,'Camera post-process settings unavailable')
            for _,name in ipairs(fields)do
                local row=state.originals[name]
                if row.vector then
                    local value=pp[name];local original=row.vector
                    value.X,value.Y,value.Z,value.W=original.X,original.Y,original.Z,original.W
                else pp[name]=row.value end
                pp['bOverride_'..name]=row.override==true
            end
            camera.PostProcessBlendWeight=state.weight
            state.originals=nil;state.weight=nil
        end
        return
    end
    local pp=camera.PostProcessSettings
    assert(pp,'Camera post-process settings unavailable')
    capture(camera,pp,state,weight)
    local values={FilmGrainIntensity=0.65,FilmGrainTexelSize=2,
        FilmGrainIntensityShadows=1,FilmGrainIntensityMidtones=0.8,FilmGrainIntensityHighlights=0.35,
        SceneFringeIntensity=2.8,VignetteIntensity=0.52}
    style=style or 1
    if style==2 then values.FilmGrainIntensity=0.25;values.SceneFringeIntensity=0.8;values.VignetteIntensity=0.3 end
    if style==3 then values.FilmGrainIntensity=0.9;values.SceneFringeIntensity=0;values.VignetteIntensity=0.6 end
    if style==4 then values.FilmGrainIntensity=1;values.SceneFringeIntensity=6;values.VignetteIntensity=0.7;values.FilmGrainTexelSize=3 end
    for name,value in pairs(values) do pp[name]=value;pp['bOverride_'..name]=true end
    for name,value in pairs({ColorSaturation=style==3 and 0 or style==2 and 0.95 or style==4 and 0.45 or 0.72,ColorContrast=style==4 and 1.2 or 1.08}) do
        local vector=pp[name]
        vector.X,vector.Y,vector.Z,vector.W=value,value,value,1
        pp['bOverride_'..name]=true
    end
    camera.PostProcessBlendWeight=1
end
return M
