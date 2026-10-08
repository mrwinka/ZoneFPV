-- Human_MeleeAttack applies this composite separately from ActorCore damage.
-- Remove only its exact SIDs after an observed FPV melee hit; never reset the
-- player's effect registry or disable NPC abilities globally.
local M={}
local effects={
    'ConcussionComposite_Buttstock','ConcussionBlurPostProcess_Buttstock',
    'ButtStroke_CameraShake','ConcussionVelocityChange_Buttstock',
    'ConcussionModifyRotate2DAxis_Buttstock','ConcussionBlockJump_Buttstock',
    'ConcussionInputInertia2DAxis_Buttstock','ConcussionBlockAim_Buttstock',
    'ConcussionBlockSprint_Buttstock','ApplyBaseConcussion',
}
local function valid(o)
    local ok,v=pcall(function()return o and o:IsValid()end)
    return ok and v
end
function M.new(s,system,log)
    local g={session=s,system=system,pending=0,passes=0}
    local function emit(text)if log then log('Buttstock guard: '..text)end end
    function g:hit(count)
        if type(count)=='number' and count>0 then self.pending=2 end
    end
    function g:update()
        if self.pending==0 then return end
        local ok,owned=pcall(function()
            if not valid(s.pc) or not valid(s.pawn) then return false end
            -- AController::GetPawn is a native inline accessor, not a Lua
            -- UFunction. Use the same reflected Pawn property as FPV entry.
            local pawn=s.pc.Pawn
            return valid(pawn) and (pawn==s.pawn or pawn:GetAddress()==s.pawn:GetAddress())
        end)
        if not ok or not owned then
            self.pending=0
            if not self.ownerFailureReported then
                self.ownerFailureReported=true
                emit('local pawn check failed: '..tostring(ok and 'controller Pawn changed' or owned))
            end
            return
        end
        if not self.checked then
            self.checked=true
            local available,ready=pcall(function()
                return valid(system) and type(StaticFindObject)=='function' and
                    valid(StaticFindObject('/Script/Stalker2.CustomConsoleManagerMH:XRemoveEffectFromPlayer'))
            end)
            self.ready=available and ready
            if not self.ready then emit('exact effect-removal API unavailable');self.pending=0;return end
        end
        if not self.ready then self.pending=0;return end
        self.pending=self.pending-1
        local sent=0
        for _,sid in ipairs(effects) do
            local success,why=pcall(function()
                system:ExecuteConsoleCommand(s.pc,'XRemoveEffectFromPlayer '..sid,s.pc)
            end)
            if success then sent=sent+1
            elseif not self.failureReported then
                self.failureReported=true;emit('removal dispatch failed: '..tostring(why))
            end
        end
        self.passes=self.passes+1
        -- Console dispatch is not a reflected success result. The game log
        -- records its own removal result; do not claim that a request succeeded.
        if self.pending==0 then emit('buttstock removal dispatched: '..sent..' exact SIDs; passes='..self.passes)end
    end
    function g:restore()
        -- Finish a pending request while the local proxy is still protected.
        if self.pending>0 then self.pending=1;self:update()end
        self.pending=0
    end
    return g
end
return M
