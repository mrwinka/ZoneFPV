local M=dofile('mod/Scripts/held_actions.lua')
local guard=M.new()
local modes,keys={},{}
for i,name in ipairs(M.names)do modes[name]=1;keys[i]=65+i end
local function packet(mask,active)
    local p={ready=true,focused=true,active=active~=false,sourceHeld=mask}
    for i,name in ipairs(M.names)do p[name..'Held']=active~=false and(mask & (1 << (i-1)))~=0 end
    return p
end
local function off(value)
    for _,name in ipairs(M.names)do assert(not value[name]and not value.pressed[name]and not value.pulse[name])end
end
off(guard:update(packet(255,false),true,0,modes,keys))
off(guard:update(packet(255),true,.1,modes,keys))
off(guard:update(packet(0),true,.2,modes,keys))
local p=guard:update(packet(255),true,.3,modes,keys)
for _,name in ipairs(M.names)do assert(p[name]and p.pressed[name])end
assert(p.pulse.collect and p.pulse.grenadeDrop)
p=guard:update(packet(255),true,.4,modes,keys)
for _,name in ipairs(M.names)do assert(p[name]and not p.pressed[name])end
assert(not p.pulse.collect and not p.pulse.grenadeDrop)
p=guard:update(packet(255),true,.56,modes,keys);assert(p.pulse.grenadeDrop and not p.pulse.collect)
p=guard:update(packet(255),true,.66,modes,keys);assert(p.pulse.collect and not p.pulse.grenadeDrop)
p=guard:update(packet(255),true,5,modes,keys);assert(p.pulse.collect and p.pulse.grenadeDrop)
p=guard:update(packet(255),true,5,modes,keys);assert(not p.pulse.collect and not p.pulse.grenadeDrop,'no catch-up burst after a stall')
p=guard:update(packet(255),false,5.1,modes,keys)
for _,name in ipairs(M.names)do assert(not p[name]and p.released[name])end
off(guard:update(packet(255),true,5.2,modes,keys))
off(guard:update(packet(0),true,5.3,modes,keys))
p=guard:update(packet(255),true,5.4,modes,keys);assert(p.pressed.pilot)
p=guard:update(nil,true,5.5,modes,keys);assert(p.released.pilot)
off(guard:update(packet(255,false),true,5.6,modes,keys))
off(guard:update(packet(255),true,5.7,modes,keys))
off(guard:update(packet(0),true,5.8,modes,keys))
for i,name in ipairs(M.names)do
    modes[name]=0
    p=guard:update(packet(1 << (i-1)),true,6+i,modes,keys);assert(not p[name],'toggle mode never follows physical level')
    modes[name]=1;keys[i]=0
    p=guard:update(packet(1 << (i-1)),true,7+i,modes,keys);assert(not p[name],'unassigned hold never activates')
    keys[i]=65+i
    p=guard:update(packet(0),true,8+i,modes,keys)
end
guard:clear();p=guard:update(packet(0),true,20,modes,keys);off(p)
guard:update(packet(255),true,21,modes,keys)
p=guard:update(packet(255),false,21.4,modes,keys,true)
for _,name in ipairs(M.names)do assert(p[name]and not p.pressed[name]and not p.released[name]and not p.pulse[name])end
p=guard:update(packet(223),false,21.5,modes,keys,true)
assert(not p.cameraDown and p.released.cameraDown,'release is observable during axis-only suspension')
p=guard:update(packet(255),false,21.6,modes,keys,true);assert(not p.cameraDown and not p.pressed.cameraDown)
p=guard:update(packet(255),true,21.7,modes,keys);assert(not p.cameraDown,'a new suspended press cannot replay on resume')
guard:update(packet(223),true,21.8,modes,keys)
p=guard:update(packet(255),true,21.9,modes,keys);assert(p.cameraDown and p.pressed.cameraDown)
p=guard:update(packet(255),false,22,modes,keys)
assert(not p.cameraDown and p.released.cameraDown,'real ineligibility still releases and blocks hold')
print('PASS eight held actions: startup/focus/menu/stale source priming, release, independent modes and bindings, bounded grenade/collect repeats')
