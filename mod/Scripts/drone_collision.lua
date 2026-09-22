local M={}
local transparent={R=0,G=0,B=0,A=0}
function M.trace(system,session,startPos,endPos,radius,enhanced)
    local hit={}
    session.traceIgnore=session.traceIgnore or {session.pawn,session.camera}
    local ignore=session.traceIgnore
    local yes
    if enhanced then
        local capsule=session.pawn.CapsuleComponent
        assert(capsule and capsule:IsValid(),'Player collision capsule unavailable')
        local profile=capsule:GetCollisionProfileName()
        yes=system:SphereTraceSingleByProfile(session.pawn,startPos,endPos,radius,
            profile,false,ignore,0,hit,true,transparent,transparent,0)
    else
        yes=system:SphereTraceSingle(session.pawn,startPos,endPos,radius,
            0,false,ignore,0,hit,true,transparent,transparent,0)
    end
    return yes,hit
end
return M
