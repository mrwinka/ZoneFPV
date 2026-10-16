local M=dofile('mod/Scripts/vision_parts.lua')
local serial=0
local null={IsValid=function()return false end,GetAddress=function()return 0 end,type=function()return 'UObject'end}
local function object(kind,world,owner)
    serial=serial+1
    local o={id=serial,name='Native_'..serial,kind=kind,world=world,owner=owner,alive=true}
    function o:IsValid()return self.alive end
    function o:GetAddress()return self.id end
    function o:GetFName()return self.name end
    function o:GetClass()return rawget(self,'class')or self end
    function o:GetWorld()return self.world or null end
    function o:GetOwner()return self.owner or null end
    function o:GetAttachParent()return self.parent or null end
    function o:GetAttachParentActor()return self.actorParent or null end
    function o:IsA(class)return class.kind=='AgentClass'and self.kind=='Agent'end
    return setmetatable(o,{__index=function()return null end})
end
local world=object('World');world.world=world
local pawn,camera=object('Player',world),object('Camera',world)
local actor=object('Agent',world)
local entry={actor=actor,key=actor.id,name=actor.name}
local agentClass=object('AgentClass')
local state=M.new(world,pawn,camera);state.agentClass=agentClass
local root=assert(state:root(entry))
local face=object('Face',world,actor)
local captured=assert(state:capture(root,face))
assert(state:current(captured)and state:current(captured,true),'genuine native null-parent wrapper is supported')
local ownerGetter=face.GetOwner
face.GetOwner=null;assert(not state:capture(root,face),'unavailable GetOwner sentinel cannot grant component authority')
face.GetOwner=ownerGetter;face.owner=null
assert(not state:capture(root,face),'reflected null owner is rejected rather than treated as optional')
face.owner=actor
local attachGetter=face.GetAttachParent
face.GetAttachParent=null
assert(not state:capture(root,face),'missing attachment getter cannot masquerade as a confirmed null parent')
face.GetAttachParent=attachGetter
local parentA,parentB=object('Scene',world,actor),object('Scene',world,actor)
face.parent=parentA;captured=assert(state:capture(root,face))
face.parent=parentB
assert(not state:current(captured)and state:current(captured,true),
    'same-NPC LOD reparent revokes rendering but permits proven baseline cleanup')
local other=object('Agent',world)
parentB.owner=other
assert(not state:current(captured,true),'a parent transferred to another NPC receives no restoration write')
parentB.owner=actor;face.parent=nil
local outfit=object('Equipment',world);outfit.actorParent=actor
local cloth=object('Mesh',world,outfit)
assert(state:capture(root,cloth),'exact native actor attachment proves separate equipment ownership')
state.agentClass=nil
assert(not state:capture(root,cloth),'unknown native Agent class must not admit arbitrary attached actors')
assert(state:capture(root,face),'unknown Agent class still permits components directly owned by the captured NPC')
state.agentClass=agentClass
other.actorParent=actor
local otherFace=object('Face',world,other)
assert(not state:capture(root,otherFace),'another attached Agent is never classified as equipment')
local borrowed=assert(state:capture(root,cloth))
outfit.actorParent=other
assert(not state:current(borrowed)and not state:current(borrowed,true),'intermediate actor transfer revokes writes and cleanup')
outfit.actorParent=actor
captured=assert(state:capture(root,face))
entry.actor=other;entry.key=other.id;entry.name=other.name
assert(not state:current(captured)and state:current(captured,true),
    'reused cache rows cannot grant rendering; captured original native ownership still permits cleanup')
entry.actor=actor;entry.key=actor.id;entry.name=actor.name
entry.key=entry.key+1;assert(not state:current(captured));entry.key=actor.id
entry.name='ReplacementName';assert(not state:current(captured));entry.name=actor.name
local originalName=face.name;face.name='RecycledSameAddress'
assert(not state:current(captured)and not state:current(captured,true),'same-address recycled component must never receive old snapshots')
face.name=originalName
local class=rawget(face,'class');face.class=object('OtherClass')
assert(not state:current(captured,true),'class replacement at a retained address invalidates identity');face.class=class
face.world=object('OtherWorld');assert(not state:current(captured,true));face.world=world
entry.suspended=true;assert(not state:current(captured)and state:current(captured,true));entry.suspended=nil
face.parent=parentA;parentA.parent=face
assert(not state:capture(root,face),'malformed attachment cycles stay bounded')
print('PASS vision part authority: native missing/null sentinels, precise owner/world/Agent ancestry, entry reuse, identity/class recycling, LOD cleanup, transfers and bounded cycles')
