local telemetry=dofile('mod/Scripts/telemetry.lua')
local flight=dofile('mod/Scripts/flight.lua')
local guard=dofile('mod/Scripts/visual_guard.lua')
local s={origin={x=0,y=0,z=0},flight=flight.new({x=3,y=4,z=12},0),flightSeconds=75,throttle=.25}
s.flight.v={x=3,y=4,z=2}
local v=telemetry.sample(s,{speed_preset=4,camera_tilt=0},flight)
assert(math.abs(v.speed-math.sqrt(109)*3.6)<1e-6)
assert(v.altitude==12 and v.distance==13 and v.seconds==75 and v.throttle==25 and v.climb==3)
print('PASS actual world velocity, home-relative height and 3D distance')
local function obj(t) function t:IsValid()return true end;return t end
local m=obj({disabled=false})
function m:GetAddress()return 1 end
function m:IsDisabled()return self.disabled end
function m:DisableModifier()self.disabled=true end
function m:EnableModifier()self.disabled=false end
local cm=obj({bEnableColorScaling=true,ModifierList={ForEach=function(_,fn)fn(1,{get=function()return m end})end},
    StopAllCameraShakes=function()end,ClearCameraLensEffects=function()end,StopCameraFade=function()end})
local value=0
local sys={GetConsoleVariableIntValue=function()return value end,ExecuteConsoleCommand=function(_,_,cmd)value=tonumber(cmd:match('(%d+)$'))end}
s.pc={PlayerCameraManager=cm}
guard.update(s,0,sys);assert(m.disabled and not cm.bEnableColorScaling and value==1)
guard.restore(s);assert(not m.disabled and cm.bEnableColorScaling and value==0)
m.disabled=true;guard.update(s,1,sys);guard.restore(s);assert(m.disabled)
print('PASS visual effect suppression restores original settings including disabled modifiers')
