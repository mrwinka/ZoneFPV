-- Counted PlayerController locks belong to the external menu only. They work
-- even when Windows has not yet transferred focus or no controller is plugged
-- in; stale helper data releases them instead of stranding the character.
-- F6 is a Win32 window: its helper owns cursor display and focus. Setting the
-- UE viewport's bShowMouseCursor here drops relative mouse capture; hiding that
-- cursor on close does not restore capture and can leave look bounded by the
-- screen edges. Preserve native cursor/input-mode state throughout the menu.
local M={}
local function valid(object)
    local ok,value=pcall(function()return object and object:IsValid()end)
    return ok and value==true
end
local function same(a,b)
    if not valid(a) or not valid(b)then return false end
    local ok,value=pcall(function()return a:GetAddress()==b:GetAddress()end)
    return ok and value
end
function M.new(read,parse,clock,epoch)
    local owner,world,pawn,move,look,sequence,changedAt,live
    local function release()
        if valid(owner)then
            if move then pcall(function()owner:SetIgnoreMoveInput(false)end)end
            if look then pcall(function()owner:SetIgnoreLookInput(false)end)end
        end
        owner,world,pawn,move,look=nil,nil,nil,false,false
    end
    local api={restore=release}
    function api:update(controller)
        local now=clock()
        local ok,line=pcall(read)
        local p=ok and parse(line) or nil
        if p and sequence~=p.seq then
            -- One preserved snapshot is not proof of a live helper. A writer
            -- restart establishes a new baseline instead of inheriting its
            -- predecessor's open-menu state during game loading.
            live=sequence~=nil and p.seq>sequence
            sequence=p.seq;changedAt=now
        end
        local fresh=p and changedAt and now>=changedAt and now-changedAt<=.25 and
            math.abs(epoch()-p.time/1000)<=2
        if not fresh then sequence,changedAt,live=nil,nil,false end
        local open=fresh and live and p.menu
        -- Closed menus own no controller state. Keep the helper lease alive
        -- without inspecting Unreal objects during ordinary play/loading.
        if not open and not owner then return false end
        local currentWorld,currentPawn
        if valid(controller)then local ready,value=pcall(function()return controller:GetWorld()end);if ready then currentWorld=value end end
        if valid(controller)then pcall(function()currentPawn=controller.Pawn end)end
        if owner and (not open or not same(owner,controller) or not same(world,currentWorld) or not same(pawn,currentPawn))then release()end
        -- UEHelpers can discover a controller before it possesses a character.
        -- Loading and unpossessed controllers must retain native input state.
        if not open or not valid(controller) or not valid(currentWorld) or not valid(currentPawn)then return false end
        if not owner then
            owner,world,pawn=controller,currentWorld,currentPawn
            move=pcall(function()controller:SetIgnoreMoveInput(true)end)
            look=pcall(function()controller:SetIgnoreLookInput(true)end)
        end
        return true
    end
    return api
end
return M
