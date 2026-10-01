local fog=dofile('mod/Scripts/regional_fog.lua')
local world={IsValid=function()return true end,GetAddress=function()return 1 end}
local a={bHidden=false}
function a:IsValid()return true end
function a:GetAddress()return 2 end
function a:GetWorld()return self.world or world end
function a:SetActorHiddenInGame(v)self.bHidden=v end
FindAllOf=function(name)assert(name=='FogActor');return {a}end
local s={world=world}
fog.update(s,0,false);assert(not a.bHidden)
fog.update(s,1,true);assert(a.bHidden)
a.bHidden=false;fog.update(s,1.1,true);assert(a.bHidden)
fog.update(s,2,false);assert(not a.bHidden)
a.bHidden=true;fog.update(s,3,true);fog.restore(s);assert(a.bHidden)
local other={IsValid=function()return true end,GetAddress=function()return 3 end}
a.bHidden=false;fog.update(s,4,true);a.world=other
fog.update(s,6,true)
assert(not a.bHidden and not s.regionalFog.actors[2],'actors moved out of the session world must restore')
a.world=nil;fog.update(s,8,true);assert(a.bHidden)
s.world=other;fog.update(s,8.1,true)
assert(not a.bHidden and not s.regionalFog.actors[2],'a world change must release old fog actors immediately')
fog.restore(s)
print('PASS regional fog only hidden for explicit Clear and restores prior state')
