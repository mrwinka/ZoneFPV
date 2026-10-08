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
local owned={'FilmGrainIntensity','FilmGrainTexelSize','FilmGrainIntensityShadows',
 'FilmGrainIntensityMidtones','FilmGrainIntensityHighlights','SceneFringeIntensity','VignetteIntensity'}
for style=1,4 do
    local pp={ColorSaturation={X=.81,Y=.82,Z=.83,W=.84},ColorContrast={X=1.21,Y=1.22,Z=1.23,W=1.24},
        bOverride_ColorSaturation=false,bOverride_ColorContrast=true,BloomIntensity=7,bOverride_BloomIntensity=true}
    for i,name in ipairs(owned)do pp[name]=i/10;pp['bOverride_'..name]=i%2==0 end
    local component={PostProcessSettings=pp,PostProcessBlendWeight=.37};local state={}
    analog.apply(component,true,style,state)
    analog.apply(component,true,style%4+1,state)
    analog.apply(component,false,0,state)
    assert(component.PostProcessBlendWeight==.37 and state.originals==nil)
    for i,name in ipairs(owned)do
        assert(pp[name]==i/10 and pp['bOverride_'..name]==(i%2==0),name..' must restore its original value and override')
    end
    assert(pp.ColorSaturation.X==.81 and pp.ColorSaturation.W==.84 and not pp.bOverride_ColorSaturation)
    assert(pp.ColorContrast.Z==1.23 and pp.ColorContrast.W==1.24 and pp.bOverride_ColorContrast)
    assert(pp.BloomIntensity==7 and pp.bOverride_BloomIntensity,'analog must not own other post-process fields')
end
print('PASS all analog styles restore exact scalar/vector/override/weight baselines after repeated style changes')
local native={PostProcessBlendWeight=0,PostProcessSettings={ColorSaturation={X=1,Y=1,Z=1,W=1},ColorContrast={X=1,Y=1,Z=1,W=1}}}
local function wrapper()
    return setmetatable({},{__index=function(_,key)return native[key]end,__newindex=function(_,key,value)native[key]=value end})
end
local state={}
analog.apply(wrapper(),true,4,state)
analog.apply(wrapper(),false,0,state)
assert(native.PostProcessBlendWeight==0 and not native.PostProcessSettings.bOverride_FilmGrainIntensity)
assert(native.PostProcessSettings.ColorSaturation.X==1 and not native.PostProcessSettings.bOverride_ColorSaturation)
print('PASS explicit flight state restores across different reflected wrappers for the same native camera')
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
