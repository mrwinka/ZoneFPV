-- UEHelpers.GetPlayerController scans the global UObject array. Discover the
-- local player once, then follow its current PlayerController across travel.
-- The backlink is read each time; a still-valid old controller is not proof
-- that it still owns local input. This module never writes native state.
local M={}
local function invoke(o,key,...)return o[key](o,...)end
local function call(o,key,...)
    local ok,value=pcall(invoke,o,key,...);if ok then return value end
end
local function read(o,key)
    local ok,value=pcall(function()return o[key]end);if ok then return value end
end
local function valid(o)
    return call(o,'IsValid')==true and call(o,'HasAnyFlags',0x18030)~=true
end
local function identity(o)
    if not valid(o)then return end
    local address,name=call(o,'GetAddress'),call(o,'GetFName')
    if type(address)=='number'and address>0 and name~=nil then
        return {object=o,address=address,name=name}
    end
end
local function matches(saved,o)
    if not saved or not valid(o)or call(o,'GetAddress')~=saved.address then return false end
    local name=call(o,'GetFName')
    local ok,equal=pcall(function()return name~=nil and name==saved.name end)
    return ok and equal
end
local function currentController(controller,player)
    local candidate=identity(controller)
    if not candidate or call(controller,'IsLocalPlayerController')~=true
        or call(controller,'IsActorBeingDestroyed')==true then return end
    local owner=read(controller,'Player')
    player=player or identity(owner)
    if not player or not matches(player,owner)
        or not matches(candidate,read(owner,'PlayerController'))then return end
    local world=identity(call(controller,'GetWorld'))
    if not world then return end
    return candidate,player,world
end
function M.new(discover,opts)
    assert(type(discover)=='function','local controller discovery required')
    opts=opts or {}
    local self={nextDiscovery=0,discoveries=0,cacheHits=0,rebindings=0}
    function self:get(now)
        now=now or os.clock()
        if self.player then
            if matches(self.player,self.player.object)then
                local controller=read(self.player.object,'PlayerController')
                local candidate,player,world=currentController(controller,self.player)
                if candidate then
                    if not matches(self.controller,controller)or not matches(self.world,world.object)then
                        self.rebindings=self.rebindings+1
                    else self.cacheHits=self.cacheHits+1 end
                    self.controller,self.player,self.world=candidate,player,world
                    self.unavailableSince=nil
                    return controller
                end
                -- A local player persists through travel while its controller
                -- or world is unavailable. Wait for that owner, never select a
                -- globally enumerated old-world controller during this gap.
                self.controller,self.world=nil,nil
                self.unavailableSince=self.unavailableSince or now
                if now-self.unavailableSince<(opts.ownerGrace or 2)then return nil end
                -- GameInstance replacement can leave the previous local player
                -- valid but disconnected forever. After the travel grace period
                -- allow bounded read-only discovery of a fresh proven owner.
                -- An old globally found PC still fails its missing backlink.
            else
                self.controller,self.player,self.world=nil,nil,nil
                self.unavailableSince=nil
            end
        end
        if now<self.nextDiscovery then return nil end
        self.nextDiscovery=now+(opts.interval or .5)
        self.discoveries=self.discoveries+1
        local ok,controller=pcall(discover)
        if not ok then return nil end
        local candidate,player,world=currentController(controller)
        if not candidate then return nil end
        self.controller,self.player,self.world=candidate,player,world
        self.unavailableSince=nil
        return controller
    end
    return self
end
return M
