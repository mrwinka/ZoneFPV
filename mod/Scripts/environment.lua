local M={}
local presets={Clearly=true,Cloudy=true,Fogy=true,LightRainy=true,Rainy=true,Thundery=true,Stormy=true}
function M.parse(line)
    if not line or #line>120 then return end
    local id,kind,args=line:match('^(%d+) (%a+) ([%w%. ]+)%s*$')
    if not id then return end
    args=args:match('^(.-)%s*$')
    if kind=='mode' and (args=='acro' or args=='angle' or args=='3d') then return id,'FPVMode '..args end
    if kind=='style' and args:match('^[0-4]$') then return id,'FPVStyle '..args end
    if kind=='bindings' and args:match('^%d+ %d+ %d+$') then return id,'FPVBindings '..args end
    if kind=='weather' and presets[args] then return id,'XForceWeather '..args end
    if kind=='analog' and (args=='0' or args=='1') then return id,'FPVAnalog '..args end
    if kind=='calibration' and args=='1' then return id,'FPVCalibrationReload' end
    if kind=='option' then
        local name,value=args:match('^(%a+) ([01])$')
        if name=='freeze' or name=='npcs' or name=='god' or name=='hotstart' then return id,'FPVOption '..name..' '..value end
    end
    if kind=='flight' then
        local speed,tilt=args:match('^([%d%.]+) (%d+)$');speed,tilt=tonumber(speed),tonumber(tilt)
        if (speed==0.5 or speed==1 or speed==2 or speed==3 or speed==4) and tilt and tilt<=60 then
            return id,string.format('FPVSettings %g %d',speed,tilt)
        end
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
        local ok,result=pcall(execute,command)
        local status=ok and result and 'sent' or 'error'
        log('Environment '..status..': '..command..(not ok and (' / '..tostring(result)) or ''))
        local reply=io.open(root..'environment-response.txt','w')
        if reply then reply:write(id..' '..status..'\n');reply:close() end
    end
end
return M
