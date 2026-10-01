local M={}
local transparent={R=0,G=0,B=0,A=0}
local representations={false,true}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function fraction(hit,startPos,endPos)
    if hit.bStartPenetrating then return 0 end
    if finite(hit.Time) then return math.max(0,math.min(1,hit.Time)) end
    local dx,dy,dz=endPos.X-startPos.X,endPos.Y-startPos.Y,endPos.Z-startPos.Z
    local length2=dx*dx+dy*dy+dz*dz
    if length2==0 then return 0 end
    local p=hit.Location
    return math.max(0,math.min(1,((p.X-startPos.X)*dx+(p.Y-startPos.Y)*dy+(p.Z-startPos.Z)*dz)/length2))
end
local function consider(best,bestTime,yes,hit,startPos,endPos)
    if not yes then return best,bestTime end
    local time=fraction(hit,startPos,endPos)
    if time<bestTime or (time==bestTime and hit.bStartPenetrating and not (best and best.bStartPenetrating)) then
        return hit,time
    end
    return best,bestTime
end
function M.trace(system,session,startPos,endPos,radius)
    session.traceIgnore=session.traceIgnore or {session.pawn,session.camera}
    local ignore=session.traceIgnore
    -- Resolve once per flight, before the optional pawn anchor moves. The profile
    -- includes the game's custom responses; do not guess custom channel numbers.
    if session.traceProfile==nil then
        local capsule=session.pawn.CapsuleComponent
        session.traceProfile=capsule and capsule:IsValid() and capsule:GetCollisionProfileName() or false
    end
    local best,bestTime=nil,math.huge
    -- Always compare hits, even if an earlier query hit something: a complex-only
    -- wall can be nearer than a simple collider behind it. Sweep the full segment
    -- with the drone radius, not rays or endpoint overlaps (high-speed tunnelling).
    -- Fixed upper bound: four sweeps per physics step, no scans of world actors,
    -- no synchronous streaming or extra game-thread callbacks.
    for _,complex in ipairs(representations) do
        local hit={}
        best,bestTime=consider(best,bestTime,system:SphereTraceSingle(session.pawn,startPos,endPos,radius,
            0,complex,ignore,0,hit,true,transparent,transparent,0),hit,startPos,endPos)
        if session.traceProfile then
            hit={}
            best,bestTime=consider(best,bestTime,system:SphereTraceSingleByProfile(session.pawn,startPos,endPos,radius,
                session.traceProfile,complex,ignore,0,hit,true,transparent,transparent,0),hit,startPos,endPos)
        end
    end
    return best~=nil,best or {}
end
return M
