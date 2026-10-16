local model=dofile('mod/Scripts/battery.lua')
local settings=dofile('mod/Scripts/battery_settings.lua')
local flight=dofile('mod/Scripts/flight.lua')
local cfg=dofile('mod/Scripts/config.lua')
assert(settings.parse('1 1 1500 6').enabled)
assert(not settings.parse('1 0 1500 6').enabled)
for _,text in ipairs({'1 1 299 6','1 1 20050 6','1 1 1551 6','1 1 1500 1','1 1 1500 9','1 2 1500 6','1 1 nan 6','1 1 1500 6 junk'})do
    assert(not settings.parse(text),text)
end
local saved,closeFail,writeFail={},false,false
local originalOpen=io.open
io.open=function(path,mode)
    if mode=='r'then
        if not saved[path]then return end
        return {read=function()return saved[path]end,close=function()return true end}
    end
    return {write=function(_,text)if writeFail then return end;saved[path]=text;return true end,close=function()return not closeFail end}
end
local loaded=settings.load('fixture/')
assert(loaded.enabled and loaded.capacity==1500 and loaded.cells==6)
assert(settings.save('fixture/',loaded,'0 2250 4')and not loaded.enabled and loaded.capacity==2250 and loaded.cells==4)
assert(settings.load('fixture/').capacity==2250 and saved['fixture/battery-settings.txt']=='1 0 2250 4\n')
writeFail=true;assert(not settings.save('fixture/',loaded,'1 1500 6')and loaded.capacity==2250)
writeFail=false;closeFail=true;assert(not settings.save('fixture/',loaded,'1 1500 6')and loaded.capacity==2250)
io.open=originalOpen
local function new(capacity,cells,enabled)return model.new{enabled=enabled~=false,capacity=capacity or 1500,cells=cells or 6}end
local function state(thrust)return {thrust=thrust,v={x=0,y=0,z=0},omega={x=0,y=0,z=0}}end
local function run(b,s,seconds,step)
    step=step or .01
    for _=1,math.floor(seconds/step+.5)do model.step(b,s,cfg,step)end
    return b
end
local hover=run(new(),state(cfg.gravity),60)
local fast=run(new(),state(cfg.gravity*3),60)
local loadedAmps=fast.currentA
local idle=run(new(),state(0),60)
assert(fast.usedMah>hover.usedMah*3 and hover.usedMah>idle.usedMah*5,'actual rotor load, not a fixed flight timer')
assert(fast.voltage<hover.voltage and fast.powerScale<hover.powerScale,'load sag reduces available motor thrust')
local used,voltage=fast.usedMah,fast.voltage
run(fast,state(0),5)
assert(fast.voltage>voltage and fast.usedMah>used,'voltage recovers after unloading but charge never regenerates')
local heavy=run(new(3000),state(cfg.gravity),60)
assert(heavy.massKg>hover.massKg and heavy.currentA>hover.currentA,'larger pack mass increases hover power')
assert(heavy.usedMah/heavy.capacity>hover.usedMah/(2*hover.capacity),'capacity gain is not free of mass cost')
local reverse=run(new(),state(-cfg.gravity),60)
assert(math.abs(reverse.usedMah-hover.usedMah)<1e-8,'reversed 3D thrust consumes energy too')
local disabled=run(new(1500,6,false),state(cfg.gravity*5),3600,.1)
assert(disabled.usedMah==0 and disabled.powerScale==1 and not disabled.depleted)
local paused=new();local snapshot=paused.usedMah
for _,dt in ipairs({0,-1,0/0,math.huge})do model.step(paused,state(50),cfg,dt)end
assert(paused.usedMah==snapshot,'invalid/paused intervals never consume or poison battery state')
assert(model.openCell(1)==4.2 and model.openCell(0)==3.2)
local lower=new(1500,4);assert(lower.powerScale<new().powerScale,'same six-cell motor model reacts to pack voltage')
local drain=new(300);local loadedState=state(cfg.gravity*5)
run(drain,loadedState,300,.02)
assert(drain.depleted and drain.powerScale==0 and drain.warning and drain.critical)
local remaining=drain.remainingMah;run(drain,state(0),5)
assert(drain.depleted and drain.powerScale==0 and drain.remainingMah<=remaining,'empty pack stays empty after voltage recovery')
local function simulate(step)
    local b=new();run(b,state(cfg.gravity),120,step);return b
end
local a,b=simulate(.01),simulate(.005)
assert(math.abs(a.usedMah-b.usedMah)<.1 and math.abs(a.voltage-b.voltage)<.01,'physical integration remains stable across frame rates')
local f1=flight.new({x=0,y=0,z=0},0);local f2=flight.new({x=0,y=0,z=0},0)
f2.battery=new(1500,6,false)
local controls={roll=.1,pitch=.2,yaw=.3,throttle=.4}
for _=1,240 do flight.step(f1,controls,cfg,cfg.step);flight.step(f2,controls,cfg,cfg.step)end
for _,axis in ipairs({'x','y','z'})do assert(f1.p[axis]==f2.p[axis]and f1.v[axis]==f2.v[axis],'disabled simulation preserves existing trajectories')end
local dead=flight.new({x=0,y=0,z=20},0);dead.battery=drain;dead.thrust=50
flight.step(dead,controls,cfg,cfg.step)
assert(dead.thrust==0 and dead.v.z<0,'depleted battery stops motors and allows gravity-driven fall')
local crossing=flight.new({x=0,y=0,z=20},0);crossing.battery=new();crossing.battery.usedMah=1499.999;crossing.battery.remainingMah=.001;crossing.thrust=50
flight.step(crossing,controls,cfg,cfg.step)
assert(crossing.battery.depleted and crossing.thrust==0 and crossing.v.z<0,'cutoff inside the current step stops thrust before its acceleration')
print(string.format('PASS LiPo charge/current/sag/relaxation/pack mass/3D/cutoff/temperature/paused intervals/FPS consistency and strict settings; hover %.2fA vs aggressive %.2fA',hover.currentA,loadedAmps))
