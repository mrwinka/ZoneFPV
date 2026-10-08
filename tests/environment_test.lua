local env=dofile('mod/Scripts/environment.lua')
local input=dofile('mod/Scripts/input.lua')
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
test('experimental actions have fixed numeric allowlists',function()
    for mode=0,15 do assert(select(2,env.parse('98 vision '..mode))=='FPVVision '..mode)end
    for _,value in ipairs({'16','-1','1.5','01','1 quit'})do assert(not env.parse('98 vision '..value))end
    for choice=0,5 do assert(select(2,env.parse('97 anomalystyle '..choice))=='FPVAnomalyStyle '..choice)end
    assert(not env.parse('97 anomalystyle 6'))
    local id,command=env.parse('99 experiments 3 1 1 1 1 1 1 1 1')
    assert(id=='99' and command=='FPVExperiments 3 1 1 1 1 1 1 1 1')
    assert(not env.parse('99 experiments 5 1 1 1 1 1 1 1 1'))
    assert(select(2,env.parse('101 impact 0.25'))=='FPVImpact 0.25')
    assert(not env.parse('101 impact 5.1'))
    assert(select(2,env.parse('102 signal 1 100 0.750000'))=='FPVSignal 1 100 0.750000')
    assert(select(2,env.parse('102 signal 0 100 0'))=='FPVSignal 0 100 0')
    assert(not env.parse('102 signal 1 100 5.01'))
    local _,collect=env.parse('100 collect 1');assert(collect=='FPVCollectArtifact')
    assert(not env.parse('100 collect 2'))
    for _,value in ipairs({'0.5','3','10','5.5'})do
        assert(select(2,env.parse('103 collectrange '..value))=='FPVCollectRange '..value)
    end
    for _,value in ipairs({'0','0.49','10.01','-1','nan','1..5','3 quit','1e1'})do
        assert(not env.parse('103 collectrange '..value),value)
    end
    assert(select(2,env.parse('104 flashlight 0'))=='FPVFlashlight 0')
    assert(select(2,env.parse('104 flashlight 1'))=='FPVFlashlight 1')
    assert(not env.parse('104 flashlight 2') and not env.parse('104 flashlight 1 quit'))
    assert(select(2,env.parse('105 armament 1 2.25 0 3'))=='FPVArmament 1 2.25 0 3')
    assert(select(2,env.parse('105 armament 2 1 1 0'))=='FPVArmament 2 1 1 0')
    assert(select(2,env.parse('105 armament 3 1.75 1 0 45'))=='FPVArmament 3 1.75 1 0 45')
    for _,args in ipairs({'4 1 0 3','1 0 0 3','1 5.25 0 3','1 1 2 3','2 1 1 21','1 1 0 -1','1 1 0 3 quit'})do
        assert(not env.parse('105 armament '..args),args)
    end
    for _,value in ipairs({'0','1','toggle'})do assert(select(2,env.parse('106 cameradown '..value))=='FPVCameraDown '..value)end
    assert(not env.parse('106 cameradown 2') and not env.parse('106 cameradown toggle quit'))
end)
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

test('helper preference notifications only reload current committed files',function()
    for kind,command in pairs({bindingsreload='FPVBindingsReload',actionmodesreload='FPVActionModesReload'})do
        assert(select(2,env.parse('19 '..kind..' 1'))==command)
        for _,value in ipairs({'0','01','2','1 0','1 quit'})do assert(not env.parse('19 '..kind..' '..value))end
    end
end)
test('universal bindings validate codes, distinct actions and old files',function()
    local settings=dofile('mod/Scripts/pilot_settings.lua')
    assert(select(2,env.parse('20 bindings 117 119 120'))=='FPVBindings 117 119 120')
    assert(select(2,env.parse('21 bindings 1 1001 2001 3001'))=='FPVBindings 1 1001 2001 3001')
    assert(select(2,env.parse('22 bindings 0 0 0 0'))=='FPVBindings 0 0 0 0')
    assert(select(2,env.parse('23 bindings 255 1128 2032 3024'))=='FPVBindings 255 1128 2032 3024')
    assert(select(2,env.parse('23 bindings 117 119 120 1001 3001'))=='FPVBindings 117 119 120 1001 3001')
    assert(select(2,env.parse('23 bindings 117 119 120 1001 3001 3024 255'))=='FPVBindings 117 119 120 1001 3001 3024 255')
    for _,args in ipairs({'117 117 120 0','1 2 3 1','256 2 3 4','1000 2 3 4','1129 2 3 4',
        '2000 2 3 4','2033 2 3 4','3000 2 3 4','3025 2 3 4','1 2','1 2 3 4 5 6','1 2 3 4 1','01 2 3 4','-1 2 3 4','1.5 2 3 4'})do
        assert(not settings.parse(args) and not env.parse('24 bindings '..args),args)
    end
    local original=io.open
    local bindingText='117 119 120\n'
    io.open=function(path)
        if path:find('bindings.txt',1,true)then return {read=function()return bindingText end,close=function()end}end
    end
    local loaded=settings.load('fixture/')
    assert(#loaded.keys==8 and loaded.keys[1]==117 and loaded.keys[4]==0 and loaded.keys[5]==0 and loaded.keys[6]==0 and loaded.keys[7]==0 and loaded.keys[8]==0,'new actions remain unassigned on legacy files')
    bindingText='1 1001 2001 3001\n';loaded=settings.load('fixture/')
    assert(loaded.keys[1]==1 and loaded.keys[2]==1001 and loaded.keys[3]==2001 and loaded.keys[4]==3001 and loaded.keys[5]==0)
    bindingText='1 1001 2001 3001 3002\n';loaded=settings.load('fixture/')
    assert(loaded.keys[4]==3001 and loaded.keys[5]==3002,'Fifth action accepts a separate CH switch position')
    bindingText='1 1 2 3\n';loaded=settings.load('fixture/')
    assert(loaded.keys[1]==117 and loaded.keys[2]==119 and loaded.keys[3]==120 and loaded.keys[4]==0 and loaded.keys[5]==0)
    io.open=original
end)
test('selected-vision action and three activation modes use strict commands',function()
    assert(select(2,env.parse('30 bindings 117 119 120 1001 3001 3024 255 65'))=='FPVBindings 117 119 120 1001 3001 3024 255 65')
    assert(not env.parse('30 bindings 117 119 120 1001 3001 3024 255 117'))
    for _,name in ipairs({'cameraDown','vision','flashlight'})do
        assert(select(2,env.parse('31 actionmode '..name..' 1'))=='FPVActionMode '..name..' 1')
    end
    assert(not env.parse('31 actionmode vision 2')and not env.parse('31 actionmode grenade 1'))
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
    for _,speed in ipairs({'0','0.75','2.5','5','0.000001'}) do
        assert(select(2,env.parse('44 flight '..speed..' 25'))=='FPVSettings '..speed..' 25')
        assert(settings.parse(speed..' 25')==tonumber(speed))
    end
    assert(not settings.parse('5.01 25'));assert(not settings.parse('1..2 25'))
    local rawOpen=io.open
    local saved
    io.open=function(_,mode)
        return {write=function(_,text) saved=text;return true end,read=function() return saved end,close=function() return true end}
    end
    assert(settings.save('mock/',cfg,4,45));assert(cfg.speed_preset==4 and cfg.camera_tilt==45)
    local restored={};settings.load('mock/',restored)
    assert(restored.speed_preset==4 and restored.camera_tilt==45)
    assert(settings.save('mock/',cfg,0.000001,25))
    settings.load('mock/',restored);assert(restored.speed_preset==0.000001)
    assert(settings.save('mock/',cfg,0,25));settings.load('mock/',restored);assert(restored.speed_preset==0)
    assert(settings.save('mock/',cfg,4,45))
    io.open=function() return nil end
    assert(not settings.save('mock/',cfg,1,0));assert(cfg.speed_preset==4)
    io.open=rawOpen
end)
test('pickup responses preserve concrete error codes',function()
    local original=io.open
    local request,reply='1 collect 1',''
    io.open=function(path,mode)
        if mode=='r' then return {read=function()return request end,close=function()end}end
        return {write=function(_,text)reply=text end,close=function()end}
    end
    local poll=env.new('test/',function(command)
        assert(command=='FPVCollectArtifact');return false,'artifact_too_far'
    end,function()end)
    request='2 collect 1';poll(0)
    assert(reply=='2 error artifact_too_far\n')
    poll(0.2);assert(reply=='2 error artifact_too_far\n')
    io.open=original
end)
print(n..' environment tests passed')
