-- Approximate 5-inch quad + high-rate LiPo, SI units. This is an electrical
-- and rotor-load model, not a flight-duration timer or a hardware calibration.
local M={reference_mass=.650,reference_voltage=25.2,disk_area=4*math.pi*(.127/2)^2}
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local curve={{0,3.20},{.05,3.50},{.10,3.63},{.20,3.73},{.40,3.80},{.60,3.87},{.80,3.98},{1,4.20}}
function M.openCell(soc)
    soc=clamp(soc,0,1)
    for i=2,#curve do
        local a,b=curve[i-1],curve[i]
        if soc<=b[1]then return a[2]+(b[2]-a[2])*(soc-a[1])/(b[1]-a[1])end
    end
    return 4.2
end
function M.packMass(capacity,cells)return .025+3.7*cells*(capacity/1000)/155 end
local dryMass=M.reference_mass-M.packMass(1500,6)
function M.new(settings)
    assert(type(settings)=='table'and type(settings.enabled)=='boolean'and finite(settings.capacity)
        and settings.capacity>=300 and settings.capacity<=20000 and settings.capacity%50==0
        and finite(settings.cells)and settings.cells%1==0 and settings.cells>=2 and settings.cells<=8,'Invalid battery settings')
    local b={enabled=settings.enabled,capacity=settings.capacity,cells=settings.cells,remainingMah=settings.capacity,
        usedMah=0,currentA=0,percent=100,voltage=4.2*settings.cells,cellVoltage=4.2,
        warning=false,critical=false,depleted=false,emptySeconds=0,elapsed=0,
        massKg=dryMass+M.packMass(settings.capacity,settings.cells),temperatureC=20,polarization=0,
        lowSeconds=0,criticalSeconds=0,cutoffSeconds=0,powerScale=1}
    if b.enabled then b.powerScale=(b.voltage/M.reference_voltage)^2*M.reference_mass/b.massKg end
    return b
end
function M.step(b,state,cfg,dt)
    if not b or not b.enabled or not finite(dt)or dt<=0 then return end
    -- The caller integrates fixed simulation steps (also during attitude-only
    -- long-frame catch-up). Menus/focus holds never advance this model.
    dt=math.min(dt,1)
    local soc=clamp(b.remainingMah/b.capacity,0,1)
    local voc=M.openCell(soc)*b.cells
    local v=state.v or {};local speed=math.sqrt((v.x or 0)^2+(v.y or 0)^2+(v.z or 0)^2)
    local thrust=not b.depleted and math.abs(state.thrust or 0)*b.massKg or 0
    local referenceWeight=M.reference_mass*(cfg.gravity or 9.81)
    -- Actuator-disk induced power plus rotor/profile loss and electronics.
    -- More actual thrust consumes disproportionately more energy, including 3D.
    local induced=thrust^1.5/math.sqrt(2*1.225*M.disk_area)/.55
    local profile=45*(thrust/math.max(.01,referenceWeight))^1.5
    local angular=state.omega or {}
    local manoeuvre=math.min(40,((angular.x or 0)^2+(angular.y or 0)^2+(angular.z or 0)^2)*.12)
    local requested=10+induced+profile+(thrust>0 and manoeuvre or 0)
    local cold=1+math.max(0,20-b.temperatureC)*.025
    local resistance=b.cells*.004*(1500/b.capacity)^.85*(1+1.8*(1-soc)^3)*cold
    local effective=math.max(.1,voc-b.polarization)
    local discriminant=effective*effective-4*resistance*requested
    local current=discriminant>0 and 2*requested/(effective+math.sqrt(discriminant))or effective/(2*resistance)
    current=math.min(current,60*b.capacity/1000,effective/(2*resistance),1000)
    local voltage=math.max(0,effective-current*resistance)
    local delivered=voltage*current
    local supply=clamp(delivered/math.max(.01,requested),0,1)^(2/3)
    b.polarization=b.polarization+(current*resistance*.25-b.polarization)*(1-math.exp(-dt/(current>b.currentA and 1.5 or 4)))
    local heat=current*current*resistance
    local cooling=(.5+.08*speed)*(b.temperatureC-20)
    b.temperatureC=clamp(b.temperatureC+(heat-cooling)*dt/(M.packMass(b.capacity,b.cells)*900),-20,100)
    b.currentA,b.voltage,b.cellVoltage=current,voltage,voltage/b.cells
    b.usedMah=clamp(b.usedMah+current*dt/3.6,0,b.capacity)
    b.remainingMah=b.capacity-b.usedMah;b.percent=100*b.remainingMah/b.capacity;b.elapsed=b.elapsed+dt
    local cell=b.cellVoltage
    b.lowSeconds=cell<3.5 and b.lowSeconds+dt or cell>3.6 and 0 or b.lowSeconds
    b.criticalSeconds=cell<3.3 and b.criticalSeconds+dt or cell>3.4 and 0 or b.criticalSeconds
    b.cutoffSeconds=cell<2.9 and b.cutoffSeconds+dt or 0
    b.warning=b.percent<=20 or b.lowSeconds>=2
    b.critical=b.percent<=5 or b.criticalSeconds>=1
    if b.remainingMah<=0 or b.cutoffSeconds>=1 then b.depleted=true end
    if b.depleted then
        b.warning=true;b.critical=true;b.powerScale=0;b.emptySeconds=b.emptySeconds+dt
    else b.powerScale=(voltage/M.reference_voltage)^2*M.reference_mass/b.massKg*supply end
end
return M
