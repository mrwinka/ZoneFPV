local f=dofile('mod/Scripts/flight.lua')
local base=dofile('mod/Scripts/config.lua')
local input=dofile('mod/Scripts/input.lua')
local settings=dofile('mod/Scripts/pilot_settings.lua')
local function cfg(mode) return setmetatable({flight_mode=mode},{__index=base}) end
local neutral={roll=0,pitch=0,yaw=0,throttle=0.5}
local function run(s,u,c,seconds) for _=1,math.floor(seconds/c.step) do f.step(s,u,c,c.step) end end
local tilted=f.new({x=0,y=0,z=100},0);tilted.q=f.mul(f.axis(0,0,1,0.7),f.axis(1,0,0,0.6))
run(tilted,neutral,cfg('angle'),3)
assert(f.rotate(tilted.q,{x=0,y=0,z=1}).z>0.999,'Angle must level when sticks center')
local banked=f.new({x=0,y=0,z=100},0)
run(banked,{roll=1,pitch=0,yaw=0,throttle=0.5},cfg('angle'),3)
assert(math.abs(math.deg(math.acos(f.rotate(banked.q,{x=0,y=0,z=1}).z))-50)<1,'Angle bank limit')
local acro=f.new({x=0,y=0,z=100},0);acro.q=f.axis(1,0,0,0.6)
run(acro,neutral,cfg('acro'),1);assert(math.abs(acro.q.x-math.sin(0.3))<1e-6,'Acro must not auto-level')
local center=f.new({x=0,y=0,z=100},0);run(center,neutral,cfg('3d'),1)
assert(math.abs(center.thrust)<1e-9 and center.v.z<0,'3D center means zero thrust')
local upright=f.new({x=0,y=0,z=100},0);run(upright,{roll=0,pitch=0,yaw=0,throttle=1},cfg('3d'),1)
assert(upright.v.z>0 and upright.thrust>0,'3D positive thrust')
local inverted=f.new({x=0,y=0,z=100},0);inverted.q=f.axis(1,0,0,math.pi)
run(inverted,{roll=0,pitch=0,yaw=0,throttle=0},cfg('3d'),1)
assert(inverted.thrust<0 and inverted.v.z>0,'3D inverted flight requires reverse thrust')
assert(settings.valid_keys(117,119,120));assert(not settings.valid_keys(117,117,120));assert(settings.valid_keys(0,119,120))
local p=input.parse('4 10 100000 1 1 1 2 3 4 5 6 7 8 0 0 3456 10')
assert(p and p.axes[8]==8 and p.device==3456 and not p.menu)
assert(not input.parse('4 10 100000 1 1 1 2 3 4 5 6 7 8 0 0 3456 11'))
-- Captured from the pre-cleanup solver: two seconds of changing sticks and
-- throttle with repeated slope impulses, across all modes and low/high power.
local trajectories={
    acro={q={-0.13331103105350375,-0.90587579093458392,-0.016322730668232418,0.4016849373098601},
        [0.5]={-1.8611608084303468,-3.9479940218922107,97.33446830097418,-2.8552941079445668,-2.1653550688064214,-3.4198042702513436,17.914889187505253},
        [2]={-8.7992753091529448,1.7153741820006798,108.22764422100558,-14.99241553766816,-2.6091371409438526,-5.5698889153921556,40.348049252886049},
        [4]={-20.250524494966843,4.9879544836306895,108.93882427580367,-16.068692430093666,-2.6177249322361682,-6.0608042857387678,40.348049252886049}},
    angle={q={-0.047627912138844049,0.044951497790585326,0.0058641883529256715,0.99783593647785562},
        [0.5]={-0.11283256636604691,-3.0204447272719861,100.4252996121994,-2.698764629016885,0.10408633959014836,0.55201190624201169,17.914889187505253},
        [2]={-1.9398470651081652,-1.5128519528807696,124.02630583965673,-5.080157729838394,1.0055319078593175,16.331410584672767,40.348049252886049},
        [4]={-5.8796941302163281,-0.025703905761540843,124.02630583965673,-5.080157729838394,1.0055319078593175,16.331410584672767,40.348049252886049}},
    ['3d']={q={-0.13331103105350375,-0.90587579093458392,-0.016322730668232418,0.4016849373098601},
        [0.5]={1.9734926829172741,-3.202950673378107,95.713069145748037,-0.60396061973218751,-0.32537045277076232,-2.1492443204002485,14.200999162070648},
        [2]={1.9452805811810552,-3.1579458245687189,95.05248490256767,-1.3104458618769534,-0.54185474768730801,-2.9328870967128204,31.591218227221141},
        [4]={2.065244377720691,-3.1840471720001173,94.993285251264908,-1.3104479884669658,-0.50096532160718699,-2.935902089139705,31.591218227221141}}
}
local function near(actual,expected) assert(math.abs(actual-expected)<1e-9,tostring(actual)..' ~= '..tostring(expected)) end
for mode,expected in pairs(trajectories) do
    for _,preset in ipairs({0.5,2,4}) do
        local c=setmetatable({flight_mode=mode,speed_preset=preset},{__index=base})
        local s=f.new({x=2,y=-3,z=100},23)
        for i=1,480 do
            local u={roll=math.sin(i/71)*0.45,pitch=math.cos(i/53)*0.35,yaw=math.sin(i/113)*0.6,throttle=(i%97)/96}
            f.step(s,u,c,c.step)
            if i%73==0 then f.collide(s,{x=s.p.x,y=s.p.y,z=s.p.z},{x=0,y=-math.sin(0.4),z=math.cos(0.4)},c.restitution,c.surface_friction,preset) end
        end
        for i,k in ipairs({'x','y','z'}) do near(s.p[k],expected[preset][i]);near(s.v[k],expected[preset][i+3]) end
        for i,k in ipairs({'w','x','y','z'}) do near(s.q[k],expected.q[i]) end
        near(s.thrust,expected[preset][7])
    end
end
print('PASS nine pre-cleanup trajectories preserve modes, speed, rotation and slope collisions')
print('PASS Angle leveling/bank, Acro preservation, 3D forward/center/reverse thrust, bindings, 8-axis packets')
