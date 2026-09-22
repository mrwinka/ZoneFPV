local env=dofile('mod/Scripts/environment.lua')
local input=dofile('mod/Scripts/input.lua')
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
test('weather allowlist and time boundaries',function()
    for _,w in ipairs({'Clearly','Cloudy','Fogy','LightRainy','Rainy','Thundery','Stormy'}) do
        local id,command=env.parse('42 weather '..w..'\n');assert(id=='42' and command=='XForceWeather '..w)
    end
    local _,command=env.parse('43 time 23 59\n');assert(command=='XSetWeatherTime 23 59 0')
    assert(not env.parse('44 time 24 0'));assert(not env.parse('44 time 12 60'))
    assert(not env.parse('44 weather Clearly | quit'));assert(not env.parse('44 weather Emission'))
end)
test('calibration reload command is allowlisted',function()
    local id,command=env.parse('9 calibration 1')
    assert(id=='9' and command=='FPVCalibrationReload')
    assert(not env.parse('9 calibration 0'))
end)
test('version two packets carry menu state without breaking old bridges',function()
    assert(input.parse('2 10 100000 1 1 32767 32767 0 0 0 32767 0 1 10').menu)
    assert(not input.parse('1 10 100000 1 1 32767 32767 0 0 0 32767 0 10').menu)
    assert(not input.parse('2 10 100000 1 1 32767 32767 0 0 0 32767 0 3 10'))
    assert(not input.parse('2 10 100000 1 1 32767 32767 0 0 0 32767 0 1 11'))
end)
test('old commands are discarded and new commands execute only once',function()
    local rawOpen=io.open
    local request='100 time 12 0',response
    io.open=function(path,mode)
        if mode=='r' then return {read=function() return request end,close=function() end} end
        return {write=function(_,s) response=s end,close=function() end}
    end
    local calls=0
    local poll=env.new('mock/',function() calls=calls+1;return true end,function() end)
    poll(1);assert(calls==0)
    request='101 time 6 30';poll(2);poll(3);assert(calls==1 and response=='101 sent\n')
    io.open=rawOpen
end)
test('live flight settings validate and persist speed and camera angle',function()
    local settings=dofile('mod/Scripts/flight_settings.lua')
    local cfg={speed_preset=2,camera_tilt=25}
    local id,command=env.parse('44 flight 0.5 60');assert(id=='44' and command=='FPVSettings 0.5 60')
    assert(not env.parse('44 flight 10 25'));assert(not env.parse('44 flight 2 61'))
    assert(not settings.parse('2 -5'));assert(not settings.parse('2 100'))
    local rawOpen=io.open
    local saved
    io.open=function(_,mode)
        return {write=function(_,text) saved=text;return true end,read=function() return saved end,close=function() return true end}
    end
    assert(settings.save('mock/',cfg,4,45));assert(cfg.speed_preset==4 and cfg.camera_tilt==45)
    local restored={};settings.load('mock/',restored)
    assert(restored.speed_preset==4 and restored.camera_tilt==45)
    io.open=function() return nil end
    assert(not settings.save('mock/',cfg,1,0));assert(cfg.speed_preset==4)
    io.open=rawOpen
end)
print(n..' environment tests passed')
