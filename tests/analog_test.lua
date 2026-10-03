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

local files={['mock/analog-settings.txt']='0\n',['mock/analog-style.txt']='0\n'}
local legacyUnavailable=true
io.open=function(path,mode)
    if mode=='w' and path=='mock/analog-settings.txt' and legacyUnavailable then return nil end
    if mode=='r' and not files[path] then return nil end
    return {read=function()return files[path]end,write=function(_,text)files[path]=text;return true end,close=function()return true end}
end
assert(analog.save_style('mock/',3) and analog.load_style('mock/')==3,
    'a committed authoritative style must succeed even when the legacy flag is unwritable')
assert(files['mock/analog-settings.txt']=='0\n')
legacyUnavailable=false;assert(analog.save_style('mock/',2) and analog.load_style('mock/')==2 and analog.load('mock/'))
io.open=function(path,mode)
    if mode=='w' and path=='mock/analog-style.txt' then return nil end
    return {read=function()return files[path]end,write=function(_,text)files[path]=text;return true end,close=function()return true end}
end
assert(not analog.save_style('mock/',0) and analog.load_style('mock/')==2 and analog.load('mock/'),
    'an unavailable authoritative style file must fail before changing the legacy flag')
io.open=rawOpen
print('PASS authoritative style commit, legacy compatibility and independent write failures')
