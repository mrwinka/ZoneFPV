local M={}
local transparent={R=0,G=0,B=0,A=0}
local representations={false,true}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function point(p)return p and finite(p.X)and finite(p.Y)and finite(p.Z)end
-- This proof belongs to one synchronous flight.advance call. Dynamic actors
-- must be queried again on the next game callback; never retain clear space
-- across callbacks, or cache/replay a hit after gameplay reacts to it.
function M.beginFrame(session,steps)
    session.traceClearanceFrame=nil
    if not finite(steps)or steps<2 then return end
    session.traceClearanceFrame={steps=math.min(200,math.floor(steps)),first=true}
end
local function samePoint(a,b)
    return a and b and a.X==b.X and a.Y==b.Y and a.Z==b.Z
end
local function distance2(p,a,b)
    local dx,dy,dz=b.X-a.X,b.Y-a.Y,b.Z-a.Z
    local length2=dx*dx+dy*dy+dz*dz
    local t=length2>0 and math.max(0,math.min(1,((p.X-a.X)*dx+(p.Y-a.Y)*dy+(p.Z-a.Z)*dz)/length2))or 0
    local x,y,z=p.X-a.X-t*dx,p.Y-a.Y-t*dy,p.Z-a.Z-t*dz
    return x*x+y*y+z*z
end
local function proofMatches(proof,system,session,ignore,radius)
    if proof.system~=system or proof.world~=session.world or proof.pc~=session.pc or proof.pawn~=session.pawn or proof.camera~=session.camera
        or proof.profile~=session.traceProfile or proof.ignore~=ignore or proof.radius~=radius or #ignore~=#proof.objects then return false end
    for i=1,#proof.objects do if ignore[i]~=proof.objects[i]then return false end end
    return true
end
function M.isPenetrating(hit)
    if not hit.bStartPenetrating then return false end
    -- UE4SS's out-struct BoolProperty conversion can read the whole packed byte,
    -- aliasing bBlockingHit into bStartPenetrating. A positive sweep Time with
    -- no depenetration depth is an ordinary impact; keep Time=0 overlaps intact.
    if finite(hit.Time)and hit.Time>0 and hit.Time<=1
        and finite(hit.PenetrationDepth)and hit.PenetrationDepth<=0 then return false end
    return true
end
local function fraction(hit,startPos,endPos)
    if M.isPenetrating(hit)then return 0 end
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
    if time<bestTime or (time==bestTime and M.isPenetrating(hit)and not(best and M.isPenetrating(best)))then
        return hit,time
    end
    return best,bestTime
end
local function sweep(system,session,startPos,endPos,radius,ignore)
    local best,bestTime=nil,math.huge
    -- Always compare hits, even if an earlier query hit something: a complex-only
    -- wall can be nearer than a simple collider behind it. Sweep the full segment
    -- with the drone radius, not rays or endpoint overlaps (high-speed tunnelling).
    -- Each query set is bounded to four sweeps, with no actor scans, synchronous
    -- streaming or extra callbacks. At most one additional enlarged set is
    -- attempted per frame; a failed proof keeps every exact movement sweep.
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
function M.trace(system,session,startPos,endPos,radius)
    session.traceIgnore=session.traceIgnore or {session.pawn,session.camera}
    local ignore=session.traceIgnore
    -- Resolve once per flight, before the optional pawn anchor moves. The profile
    -- includes the game's custom responses; do not guess custom channel numbers.
    if session.traceProfile==nil then
        local capsule=session.pawn.CapsuleComponent
        session.traceProfile=capsule and capsule:IsValid() and capsule:GetCollisionProfileName() or false
    end
    local frame=session.traceClearanceFrame
    if frame then
        local proof=frame.proof
        if frame.lastEnd and not samePoint(frame.lastEnd,startPos)then
            -- Teleports/discontinuous movement retire all same-frame evidence.
            frame.proof=nil;frame.first=false;proof=nil
        end
        frame.lastEnd={X=endPos.X,Y=endPos.Y,Z=endPos.Z}
        if proof then
            if not proofMatches(proof,system,session,ignore,radius)then frame.proof=nil;frame.first=false
            elseif point(startPos)and point(endPos)
                and distance2(startPos,proof.startPos,proof.endPos)<proof.margin2
                and distance2(endPos,proof.startPos,proof.endPos)<proof.margin2 then
                -- Capsules are convex. If both centres lie inside the proved
                -- capsule shrunk by the drone radius, the entire new sphere
                -- sweep is inside empty space, including curves/reversals.
                return false,{}
            end
        end
        if frame.first then
            frame.first=false
            if point(startPos)and point(endPos)and finite(radius)and radius>0 and #ignore<=32 then
                local dx,dy,dz=endPos.X-startPos.X,endPos.Y-startPos.Y,endPos.Z-startPos.Z
                local margin=math.max(25,math.min(300,math.sqrt(dx*dx+dy*dy+dz*dz)*math.min(12,frame.steps-1)))
                local blocked=sweep(system,session,startPos,endPos,radius+margin,ignore)
                if not blocked then
                    local objects={};for i=1,#ignore do objects[i]=ignore[i]end
                    frame.proof={system=system,world=session.world,pc=session.pc,pawn=session.pawn,camera=session.camera,
                        profile=session.traceProfile,ignore=ignore,objects=objects,radius=radius,margin2=margin*margin,
                        startPos={X=startPos.X,Y=startPos.Y,Z=startPos.Z},endPos={X=endPos.X,Y=endPos.Y,Z=endPos.Z}}
                    return false,{}
                end
                -- An enlarged hit is only a failed empty-space proof. Query the
                -- original radius and retain the exact nearest impact/normal.
            end
        end
    end
    local yes,hit=sweep(system,session,startPos,endPos,radius,ignore)
    if yes and frame then frame.proof=nil;frame.first=false end
    return yes,hit
end
return M
