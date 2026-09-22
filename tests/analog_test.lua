local analog=dofile('mod/Scripts/analog.lua')
local env=dofile('mod/Scripts/environment.lua')
local camera={PostProcessBlendWeight=0,PostProcessSettings={ColorSaturation={},ColorContrast={}}}
local player={PostProcessBlendWeight=0.7,PostProcessSettings={}}
analog.apply(camera,true)
assert(camera.PostProcessBlendWeight==1 and camera.PostProcessSettings.bOverride_FilmGrainIntensity)
assert(camera.PostProcessSettings.ColorSaturation.X<1 and player.PostProcessBlendWeight==0.7)
analog.apply(camera,false);assert(camera.PostProcessBlendWeight==0)
print('PASS analog styling is camera-local and can be disabled')
local bad={PostProcessBlendWeight=1,PostProcessSettings=setmetatable({},{__newindex=function() error('unsupported property') end})}
assert(not pcall(analog.apply,bad,true));assert(bad.PostProcessBlendWeight==0)
print('PASS unsupported analog property leaves effect disabled')
local rawOpen=io.open;local contents
io.open=function(_,mode)
    if mode=='r' and not contents then return nil end
    return {read=function() return contents end,write=function(_,text) contents=text;return true end,close=function() return true end}
end
assert(not analog.load('mock/'));assert(analog.save('mock/',true));assert(analog.load('mock/'))
assert(analog.save('mock/',false));assert(not analog.load('mock/'))
contents='1 bad';assert(not analog.load('mock/'));assert(not analog.save('mock/',1))
io.open=function() return nil end;assert(not analog.save('mock/',true));io.open=rawOpen
local _,command=env.parse('47 analog 1');assert(command=='FPVAnalog 1')
assert(not env.parse('47 analog 2'));assert(not env.parse('47 analog 1 quit'))
print('PASS analog preference persistence and command allowlist')
