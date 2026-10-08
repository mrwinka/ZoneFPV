local M=dofile('mod/Scripts/weapon_settings.lua')
local default=M.defaults()
assert(default.mode==0 and default.power==1 and default.grenade==0 and default.charges==3 and default.impactSpeed==30)
default.mode=2;default.impactSpeed=150
assert(M.defaults().mode==0 and M.defaults().impactSpeed==30,'Defaults must not share mutable flight state')
for mode=0,3 do
    assert(M.hasKamikaze(mode)==(mode==1 or mode==3)and M.hasGrenades(mode)==(mode==2 or mode==3),
        'Payload capabilities preserve the three legacy modes and combine both for mode3')
end
for _,mode in ipairs({-1,4,1.5,'1','3',true,{},math.huge,0/0})do
    assert(not M.hasKamikaze(mode)and not M.hasGrenades(mode),'Invalid capability input must not arm payloads')
end
assert(not M.hasKamikaze(nil)and not M.hasGrenades(nil)and M.maxMode==3)
local parsed=assert(M.parse('2 1.25 1 0'))
assert(parsed.mode==2 and parsed.power==1.25 and parsed.grenade==1 and parsed.charges==0 and parsed.impactSpeed==30,
    'Legacy four-field commands retain the default impact threshold')
assert(M.parse('2 1.2500000001 1 0').power==1.25,'Round floating point noise to the exact quarter-step SID')
assert(M.parse('0 0.25 0 20')and M.parse('1 5 1 1'))
assert(M.parse('3 1.25 1 0').impactSpeed==30 and M.parse('3 2.25 0 20 75').mode==3,
    'Combined mode uses existing optional fifth-field/default-threshold contract')
assert(M.minImpactSpeed==5 and M.maxImpactSpeed==150 and M.impactSpeedStep==5)
for threshold=5,150,5 do
    assert(M.parse('1 1.25 1 3 '..threshold).impactSpeed==threshold,'Every UI threshold must parse exactly')
end
assert(M.parse('1 1.25 1 3 5.000000').impactSpeed==5 and M.parse('1 1.25 1 3 150.000000').impactSpeed==150)
assert(M.parse('1 1.25 1 3 30.000000001').impactSpeed==30,
    'Only floating point noise rounds to the exact five km/h step')
for _,invalid in ipairs({'','1 2 0','1 2 0 3 extra','1 1 2 0 3','4 1 0 3','1 0.249 0 3',
    '1 5.001 0 3','1 nan 0 3','1 inf 0 3','1 1e0 0 3','1 .5 0 3','1 1..0 0 3','1 1 2 3',
    '1 1 0 21','1 1 0 -1','1.0 1 0 3','1 1 0 1.5','1 0.26 0 3','1 1.234567 0 3',string.rep(' ',97)..'1 1 0 3'})do
    assert(M.parse(invalid)==nil,'Unsafe armament command accepted: '..invalid)
end
for _,threshold in ipairs({'0','4.999999999','150.000000001','151','29','30.00001','32.5','nan','inf','1e1','.5','30.','-5','30 extra'})do
    assert(M.parse('1 1.25 1 3 '..threshold)==nil,'Unsafe impact threshold accepted: '..threshold)
end
assert(M.parse(nil)==nil and M.parse({})==nil)
local fallback=M.value{mode=math.huge,power=0/0,grenade=-1,charges=1.5,impactSpeed=0/0}
assert(fallback.mode==0 and fallback.power==1 and fallback.grenade==0 and fallback.charges==3 and fallback.impactSpeed==30)
local infinite=M.value{mode=2,power=5,grenade=1,charges=0}
assert(infinite.mode==2 and infinite.power==5 and infinite.grenade==1 and infinite.charges==0 and infinite.impactSpeed==30)
local thresholdOnly=M.value{mode=2,power=5,grenade=1,charges=0,impactSpeed=32}
assert(thresholdOnly.mode==2 and thresholdOnly.power==5 and thresholdOnly.grenade==1 and thresholdOnly.charges==0
    and thresholdOnly.impactSpeed==30,'Invalid threshold fallback must preserve valid sibling selections')
local prefix=os.tmpname()..'-'
local path=prefix..'weapon-settings.txt'
assert(M.load(prefix).mode==0,'Missing settings must leave drone unarmed')
local file=assert(io.open(path,'w'));file:write('1 2 1.250000 1 0\n');file:close()
local legacy=M.load(prefix)
assert(legacy.mode==2 and legacy.power==1.25 and legacy.grenade==1 and legacy.charges==0 and legacy.impactSpeed==30,
    'Existing version-one four-field files remain readable')
local ok,saved=M.save(prefix,parsed)
assert(ok and saved.mode==2 and saved.charges==0 and saved.impactSpeed==30)
local loaded=M.load(prefix)
assert(loaded.power==1.25 and loaded.grenade==1 and loaded.charges==0 and loaded.impactSpeed==30,
    'Persist exact selected power, grenade, unlimited supply and default threshold')
assert(M.save(prefix,'1 0.75 0 5'))
assert(M.load(prefix).mode==1 and M.load(prefix).charges==5 and M.load(prefix).impactSpeed==30)
file=assert(io.open(path,'r'));assert(file:read('*a')=='1 1 0.750000 0 5 30\n','New writes add integer impact speed to version-one schema');file:close()
assert(M.save(prefix,'1 0.75 0 5 150'))
local selected=M.load(prefix)
assert(selected.mode==1 and selected.power==.75 and selected.grenade==0 and selected.charges==5 and selected.impactSpeed==150,
    'Explicit threshold changes preserve the four sibling selections')
selected.impactSpeed=5;assert(M.save(prefix,selected))
assert(M.load(prefix).impactSpeed==5,'Table saves round-trip the lower threshold boundary')
file=assert(io.open(path,'r'));local before=file:read('*a');file:close()
assert(before=='1 1 0.750000 0 5 5\n')
assert(not M.save(prefix,'2 6 1 0')and not M.save(prefix,{mode=2,power=1,grenade=1}), 'Invalid save must not truncate a good file')
for _,threshold in ipairs({0,4.999999999,150.000000001,151,32,30.00001,math.huge,0/0})do
    assert(not M.save(prefix,{mode=1,power=.75,grenade=0,charges=5,impactSpeed=threshold}),
        'Invalid table threshold must not alter persisted selections')
end
file=assert(io.open(path,'r'));assert(file:read('*a')==before);file:close()
assert(M.save(prefix,{mode=3,power=.75,grenade=1,charges=0,impactSpeed=75}))
local combined=M.load(prefix)
assert(combined.mode==3 and combined.power==.75 and combined.grenade==1 and combined.charges==0 and combined.impactSpeed==75,
    'Combined mode preserves grenade type, unlimited stock, impact power and threshold in one version1 row')
file=assert(io.open(path,'r'));assert(file:read('*a')=='1 3 0.750000 1 0 75\n');file:close()
assert(M.save(prefix,'3 0.75 1 0')and M.load(prefix).impactSpeed==30,
    'Four-field combined commands retain legacy default-threshold compatibility')
for _,invalid in ipairs({'2 2 1 0 3','1 1 6 0 3','1 1 1 0 3 extra','1 1 1 0 3 4','1 1 1 0 3 32',
    '1 1 1 0 3 151','1 1 1 0 3 30 extra',string.rep('x',200),'1 1 1 0 3'..string.rep(' ',200)})do
    file=assert(io.open(path,'w'));file:write(invalid);file:close()
    local values=M.load(prefix)
    assert(values.mode==0 and values.power==1 and values.grenade==0 and values.charges==3 and values.impactSpeed==30,
        'Malformed settings must fail to unarmed defaults, including the safe impact threshold')
end
os.remove(path);os.remove(prefix:sub(1,-2))
print('PASS armament mode3 capabilities, combined payload persistence, legacy migration, impact thresholds, sibling preservation and corrupt-file fallback')
