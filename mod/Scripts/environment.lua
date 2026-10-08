local M={}
local experiments=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'experiments_settings.lua')
local impact=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'impact_settings.lua')
local radio=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'radio_link.lua')
local flightSettings=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'flight_settings.lua')
local pilotSettings=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'pilot_settings.lua')
local artifactSettings=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'artifact_settings.lua')
local weaponSettings=dofile(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')..'weapon_settings.lua')
local presets={Clearly=true,Cloudy=true,Fogy=true,LightRainy=true,Rainy=true,Thundery=true,Stormy=true}
function M.parse(line)
    if not line or #line>120 then return end
    local id,kind,args=line:match('^(%d+) (%a+) ([%w%. ]+)%s*$')
    if not id then return end
    args=args:match('^(.-)%s*$')
    if kind=='bindingsreload' and args=='1' then return id,'FPVBindingsReload' end
    if kind=='actionmodesreload' and args=='1' then return id,'FPVActionModesReload' end
    if kind=='armament' and weaponSettings.parse(args) then return id,'FPVArmament '..args end
    if kind=='cameradown' and (args=='0' or args=='1' or args=='toggle')then return id,'FPVCameraDown '..args end
    if kind=='actionmode' then
        local name,value=args:match('^(%a+) ([01])$')
        if name=='cameraDown' or name=='vision' or name=='flashlight'then return id,'FPVActionMode '..name..' '..value end
    end
    if kind=='impact' and impact.parse(args)~=nil then return id,'FPVImpact '..args end
    if kind=='experiments' then
        if experiments.parse(args) then return id,'FPVExperiments '..args end
    end
    if kind=='collect' and args=='1' then return id,'FPVCollectArtifact' end
    if kind=='collectrange' and artifactSettings.parse(args)~=nil then return id,'FPVCollectRange '..args end
    if kind=='flashlight' and (args=='0' or args=='1') then return id,'FPVFlashlight '..args end
    if kind=='signal' then
        if radio.parse(args)~=nil then return id,'FPVSignal '..args end
    end
    if kind=='binoculars' and args=='1' then return id,'FPVBinoculars' end
    if kind=='distance' and args:match('^[0-6]$') then return id,'FPVDistance '..args end
    if kind=='mode' and (args=='acro' or args=='angle' or args=='3d') then return id,'FPVMode '..args end
    if kind=='style' and args:match('^[0-4]$') then return id,'FPVStyle '..args end
    if kind=='vision' and args:match('^%d+$') and tonumber(args)<=15 and tostring(tonumber(args))==args then return id,'FPVVision '..args end
    if kind=='anomalystyle' and args:match('^[0-5]$') then return id,'FPVAnomalyStyle '..args end
    if kind=='bindings' and pilotSettings.parse(args) then return id,'FPVBindings '..args end
    if kind=='weather' and presets[args] then return id,'XForceWeather '..args end
    if kind=='analog' and (args=='0' or args=='1') then return id,'FPVAnalog '..args end
    if kind=='calibration' and args=='1' then return id,'FPVCalibrationReload' end
    if kind=='option' then
        local name,value=args:match('^(%a+) ([01])$')
        if name=='freeze' or name=='alternate' or name=='noclip' or name=='god' or name=='hotstart' then return id,'FPVOption '..name..' '..value end
    end
    if kind=='flight' then
        if flightSettings.parse(args)~=nil then return id,'FPVSettings '..args end
    end
    if kind=='time' then
        local h,m=args:match('^(%d+) (%d+)$');h,m=tonumber(h),tonumber(m)
        if h and m and h<24 and m<60 then return id,string.format('XSetWeatherTime %d %d 0',h,m) end
    end
end
function M.new(root,execute,log)
    local last,nextPoll=nil,0
    -- Discard commands left by a previous game session.
    local file=io.open(root..'environment.txt','r')
    if file then last=M.parse(file:read(121));file:close() end
    return function(now)
        if now<nextPoll then return end;nextPoll=now+0.1
        local request=io.open(root..'environment.txt','r');if not request then return end
        local id,command=M.parse(request:read(121));request:close()
        if not id or id==last then return end;last=id
        local ok,result,detail=pcall(execute,command)
        local status=ok and result and 'sent' or 'error'
        log('Environment '..status..': '..command..(not ok and (' / '..tostring(result)) or ''))
        local reply=io.open(root..'environment-response.txt','w')
        local code=ok and type(detail)=='string' and detail:match('^[a-z_]+$') and #detail<=60 and detail or ''
        if reply then reply:write(id..' '..status..(code~='' and (' '..code) or '')..'\n');reply:close() end
    end
end
return M
