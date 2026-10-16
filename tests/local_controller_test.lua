local module=dofile('mod/Scripts/local_controller.lua')
local nextAddress=1000
local function object(fields)
    nextAddress=nextAddress+1
    local value=fields or {};value.address=value.address or nextAddress;value.name=value.name or ('Object_'..nextAddress)
    function value:IsValid()return not self.invalid end
    function value:GetAddress()return self.address end
    function value:GetFName()return self.name end
    function value:HasAnyFlags()return self.retired==true end
    return value
end
local function controller(player,world)
    local pc=object({Player=player,world=world,localController=true})
    function pc:IsLocalPlayerController()return self.localController end
    function pc:IsActorBeingDestroyed()return self.destroying==true end
    function pc:GetWorld()return self.world end
    return pc
end
local player,world=object(),object()
local pc=controller(player,world);player.PlayerController=pc
local found=pc
local cache=module.new(function()return found end)
assert(cache:get(0)==pc and cache.discoveries==1)
-- Workload: ten minutes at 20 updates/s used to invoke 1,200 global scans.
-- The hot path must follow the local backlink without any discovery scan.
for frame=1,12000 do assert(cache:get(frame*.05)==pc)end
assert(cache.discoveries==1 and cache.cacheHits==12000)
print('PASS controller workload: 12,000 idle updates; global scans 1 (previous 1,201 including startup)')

-- Map travel leaves the old PC valid. The local player's fresh backlink is
-- authoritative even if global discovery keeps returning the old PC.
local nextWorld=object();local nextPC=controller(player,nextWorld)
player.PlayerController=nextPC
assert(cache:get(601)==nextPC and cache.discoveries==1 and cache.rebindings==1)
assert(pc:IsValid()and pc.world==world)
player.PlayerController=nil
for frame=1,20 do assert(cache:get(602+frame*.05)==nil)end
assert(cache.discoveries==1,'travel gap must not adopt a still-valid old global PC')
player.PlayerController=nextPC
nextPC.world=nil
assert(cache:get(604)==nil,'missing world must not become an active controller')
nextPC.world=nextWorld
assert(cache:get(605)==nextPC)

-- A recycled controller wrapper is rebound only if local ownership, exact
-- backlink and a fresh world are still proven. Invalid ownership fails closed.
nextPC.name='ReusedController';nextPC.world=object()
assert(cache:get(606)==nextPC and cache.rebindings==3)
nextPC.Player=object({PlayerController=nextPC})
assert(cache:get(607)==nil,'controller owner transfer must reject an old player backlink')
nextPC.Player=player
nextPC.localController=false
assert(cache:get(608)==nil,'remote controller cannot own local input')
nextPC.localController=true;nextPC.destroying=true
assert(cache:get(609)==nil)
nextPC.destroying=false;nextPC.retired=true
assert(cache:get(610)==nil)
nextPC.retired=false
assert(cache:get(611)==nextPC)
local precedingDiscoveries=cache.discoveries

-- The local-player wrapper itself can be recycled. Never trust its old scope;
-- discover and establish a fresh owner contract before accepting any pointer.
player.name='ReusedPlayer';found=nil
assert(cache:get(612)==nil and cache.discoveries==precedingDiscoveries+1)
assert(cache:get(612.1)==nil and cache.discoveries==precedingDiscoveries+1)
found=nextPC
assert(cache:get(612.5)==nextPC and cache.discoveries==precedingDiscoveries+2)
player.invalid=true
assert(cache:get(613)==nil and cache.discoveries==precedingDiscoveries+3)
player.invalid=false
assert(cache:get(613.1)==nil,'disconnected discovery cadence must remain bounded')
assert(cache:get(613.5)==nextPC and cache.discoveries==precedingDiscoveries+4)

-- A GameInstance can replace the local player while retaining the old UPlayer
-- and controller. A long missing backlink must recover to the new owner, while
-- a short travel gap remains scan-free and an old enumerated PC is rejected.
local oldPlayer,newPlayer=object(),object()
local oldPC,newPC=controller(oldPlayer,object()),controller(newPlayer,object())
oldPlayer.PlayerController=oldPC;newPlayer.PlayerController=newPC
local enumerated=oldPC
local replacement=module.new(function()return enumerated end)
assert(replacement:get(0)==oldPC)
oldPlayer.PlayerController=nil
assert(replacement:get(1)==nil)
assert(replacement:get(2.9)==nil and replacement.discoveries==1,'brief owner gap must not scan')
assert(replacement:get(3)==nil and replacement.discoveries==2,'stale global controller must fail ownership validation')
enumerated=newPC
assert(replacement:get(3.1)==nil and replacement.discoveries==2,'replacement discovery must respect backoff')
assert(replacement:get(3.5)==newPC and replacement.discoveries==3,'a new proven local player must recover after grace')
assert(oldPlayer:IsValid()and oldPC:IsValid(),'regression requires the previous owner to remain alive')
for frame=1,100 do assert(replacement:get(3.5+frame*.05)==newPC)end
assert(replacement.discoveries==3,'replacement owner resumes the scan-free hot path')

local attempts=0
local empty=module.new(function()attempts=attempts+1;error('loading')end)
for frame=0,1000 do assert(empty:get(frame*.001)==nil)end
assert(attempts==3,'missing/loading discovery runs at most twice per second')
local wrong=controller(player,world);wrong.Player=nil
local invalid=module.new(function()return wrong end)
assert(invalid:get(0)==nil,'a controller without a proven local player is unavailable')
wrong.Player=player;player.PlayerController=nextPC
assert(invalid:get(.5)==nil,'global enumeration cannot override a mismatched current player backlink')
print('PASS controller travel, destruction, recycled identities, owner transfer, loading and discovery backoff')
