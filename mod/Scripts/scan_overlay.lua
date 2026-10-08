-- Calibrate the game's lens, then track the current FPV mount each frame.
-- Complete alternating packets keep a reader from drawing a torn frame.
local M={}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
M.nativeBridge=here and dofile(here..'native_bridge.lua')
M.projection=here and dofile(here..'scan_projection.lua')
M.targets=here and dofile(here..'world_experiments.lua')
local lastGeneration=0
-- W_BinocularsView's serialized faction map, including its explicit NULL
-- Mutant entry. Match numeric FNames; never stringify live native names.
local factionMap={Duty=3,Bandits=1,Corpus=2,Freedom=4,FreeStalkers=6,Mercenaries=7,
    Monolith=8,SIRCAA_Scientist=10,Noon=9,Scientists=10,Spark=11,Varta=12,
    NeutralMSOP=5,Militaries=5,Mutant=0}
function M.factionIcon(names,map)
    for _,name in ipairs(names or {})do
        if map[name]~=nil then return map[name] end
    end
    return 0
end
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function valid(o)return call(o,'IsValid')==true end
local function point(v)
    local x,y,z=read(v,'X'),read(v,'Y'),read(v,'Z')
    if finite(x) and finite(y) and finite(z)then return {X=x,Y=y,Z=z}end
end
local function clamp(x)return math.max(0,math.min(1,x))end
local function same(a,b)
    if not valid(a) or not valid(b)then return false end
    local address=call(a,'GetAddress')
    return finite(address) and address>0 and address==call(b,'GetAddress')
end
local function capsuleBounds(actor)
    -- Collision-only actor bounds omit NoCollision components. A loaded
    -- character's actual capsule still has a current shape and transform.
    local capsule=read(actor,'CapsuleComponent')
    if not valid(capsule) or call(capsule,'HasAnyFlags',0x18030)==true
        or call(capsule,'IsBeingDestroyed')==true then return end
    local owner=call(capsule,'GetOwner')
    local world=call(actor,'GetWorld')
    if not same(owner,actor) or not same(call(owner,'GetWorld'),world)then return end
    -- UE4SS provides native GetWorld on AActor; components may not expose
    -- that reflected getter. When present, it must agree with their owner.
    local componentWorld=call(capsule,'GetWorld')
    if componentWorld~=nil and not same(componentWorld,world)then return end
    local radius=call(capsule,'GetScaledCapsuleRadius')
    local halfHeight=call(capsule,'GetScaledCapsuleHalfHeight')
    local center=point(call(capsule,'K2_GetComponentLocation'))
    local up=point(call(capsule,'GetUpVector'))
    if not finite(radius) or not finite(halfHeight) or radius<=0 or halfHeight<radius
        or halfHeight>=10000 or not center or not up then return end
    local lengthSquared=up.X*up.X+up.Y*up.Y+up.Z*up.Z
    if not finite(lengthSquared) or math.abs(lengthSquared-1)>.001 then return end
    local length=math.sqrt(lengthSquared)
    local segment=halfHeight-radius
    -- A capsule is a line segment swept by its real radius. This exact
    -- world AABB also works when the capsule tilts or turns horizontally.
    return center,{X=radius+segment*math.abs(up.X)/length,
        Y=radius+segment*math.abs(up.Y)/length,Z=radius+segment*math.abs(up.Z)/length}
end
local function currentBounds(actor,center,extent)
    if read(actor,'GetActorBounds')==nil then return center,extent end
    local liveCenter,liveExtent={},{}
    local ok=pcall(function()actor:GetActorBounds(true,liveCenter,liveExtent,false)end)
    liveCenter=ok and point(liveCenter);liveExtent=ok and point(liveExtent)
    if liveCenter and liveExtent and liveExtent.X>0 and liveExtent.Y>0 and liveExtent.Z>0
        and math.max(liveExtent.X,liveExtent.Y,liveExtent.Z)<10000 then return liveCenter,liveExtent end
    return capsuleBounds(actor)
end
local function skeletalBounds(actor,names,project,marker,center,extent)
    local mesh
    if M.targets.markerMesh then
        mesh=M.targets.markerMesh(actor,marker)
        if not mesh then return false end
    else mesh=read(actor,'Mesh')end
    if not valid(mesh) or not names then return end
    local points={}
    local low,high={X=math.huge,Y=math.huge,Z=math.huge},{X=-math.huge,Y=-math.huge,Z=-math.huge}
    local reach=math.max(extent.X,extent.Y,extent.Z)*4+100
    for _,name in ipairs(names)do
        if call(mesh,'DoesSocketExist',name)~=true then return end
        local p=point(call(mesh,'GetSocketLocation',name))
        if not p then return end
        -- Modular/LOD components can retain a construction or previous pose
        -- while their loaded actor and collider have already moved. Such a
        -- pose does not establish this actor's silhouette, even off-screen.
        if math.max(math.abs(p.X-center.X),math.abs(p.Y-center.Y),math.abs(p.Z-center.Z))>reach then return end
        for _,axis in ipairs({'X','Y','Z'})do low[axis]=math.min(low[axis],p[axis]);high[axis]=math.max(high[axis],p[axis])end
        points[#points+1]=p
    end
    if math.max(high.X-low.X,high.Y-low.Y,high.Z-low.Z)<=1 then return end
    local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
    for _,p in ipairs(points)do
        local x,y=project(p)
        if not finite(x) or not finite(y)then return false end
        left=math.min(left,x);right=math.max(right,x)
        top=math.min(top,y);bottom=math.max(bottom,y)
    end
    -- A genuine posed skeleton outside this camera stays hidden. A collapsed
    -- screen silhouette is unavailable, independently of its world pose.
    if right<=0 or left>=1 or bottom<=0 or top>=1 then return false end
    if right<=left or bottom<=top then return end
    local margin=(bottom-top)*.025
    left,right,top,bottom=clamp(left-margin),clamp(right+margin),clamp(top-margin),clamp(bottom+margin)
    return (left+right)/2,(top+bottom)/2,right-left,bottom-top
end
function M.bounds(center,extent,project)
    if not point(center) or not point(extent) or extent.X<=0 or extent.Y<=0 or extent.Z<=0 then return end
    local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
    for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
        local sx,sy=project({X=center.X+x*extent.X,Y=center.Y+y*extent.Y,Z=center.Z+z*extent.Z})
        -- A box crossing the camera eye cannot be bounded by its remaining
        -- front-facing corners: that produces giant/fleeting false brackets.
        if not finite(sx) or not finite(sy)then return end
        left=math.min(left,sx);right=math.max(right,sx)
        top=math.min(top,sy);bottom=math.max(bottom,sy)
    end end end
    if right<=0 or left>=1 or bottom<=0 or top>=1 then return end
    left,right,top,bottom=clamp(left),clamp(right),clamp(top),clamp(bottom)
    local width,height=right-left,bottom-top
    if width<=.0001 or height<=.0001 then return end
    return (left+right)/2,(top+bottom)/2,width,height
end
local function possiblyVisible(marker,project)
    local entry=marker.entry
    local center=point(entry and entry.center) or point(marker.position)
    local extent=point(entry and entry.extent) or point(marker.extent)
    if not center or not extent or math.min(extent.X,extent.Y,extent.Z)<=0 then return true end
    -- This is only a cheap broad phase. Expand cached geometry to tolerate
    -- animation/movement between cache refreshes; exact live bounds follow.
    extent={X=extent.X*2+500,Y=extent.Y*2+500,Z=extent.Z*2+500}
    local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
    local front=0
    for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
        local sx,sy=project({X=center.X+x*extent.X,Y=center.Y+y*extent.Y,Z=center.Z+z*extent.Z})
        if finite(sx) and finite(sy)then
            front=front+1
            left=math.min(left,sx);right=math.max(right,sx)
            top=math.min(top,sy);bottom=math.max(bottom,sy)
        end
    end end end
    if front==0 then return false end
    if front<8 then return true end -- A near-plane intersection needs live geometry.
    return right>0 and left<1 and bottom>0 and top<1
end
function M.new(root,flight,cfg,log)
    local seq,nextWrite,wasActive,hadMarkers=0,0,false,false
    local slots={root..'scan-frame-a.txt',root..'scan-frame-b.txt'}
    local initialized,publicationUnavailable=false,false
    local generation=math.max(lastGeneration+1,os.time()*1000000+math.floor((os.clock()%1)*1000000))
    -- Reloads may occur within one second, or after a wall-clock adjustment.
    -- Advance beyond both persisted slots before deleting their old session.
    for _,path in ipairs(slots)do
        local f=io.open(path,'r')
        if f then
            local previous=tonumber((f:read(96) or ''):match('^4 (%d+) '));f:close()
            if finite(previous) and previous>0 and previous<9007199254740990 then
                generation=math.max(generation,previous+1)
            end
        end
    end
    assert(generation>0 and generation<9007199254740991 and generation%1==0,'invalid scan generation')
    lastGeneration=generation
    local function publicationError()
        if not publicationUnavailable and log then log('Scanner packet publication unavailable.')end
        publicationUnavailable=true
    end
    local function prepare()
        if initialized then return true end
        for _,path in ipairs(slots)do
            local f=io.open(path,'r')
            if f then
                f:close()
                if not os.remove(path)then publicationError();return false end
            end
        end
        initialized=true
        return true
    end
    local width,height,layout,layoutChecked,unavailable=0,0,nil,false,false
    local native,metadataSession,nextMetadata,metadata,metadataOwners= nil,nil,0,{},{}
    local metadataUnavailable=false
    local projectionFailures={}
    local diagnosticSession,nextDiagnostic,diagnostic=nil,0,nil
    local iconNames={}
    for name,icon in pairs(factionMap)do
        local ok,index=pcall(function()return FName(name):GetComparisonIndex()end)
        if ok and finite(index)then iconNames[index]=icon end
    end
    local bones
    pcall(function()
        local names={}
        for _,name in ipairs({'jnt_head','jnt_spine_03','jnt_r_foot','jnt_l_foot','jnt_r_hand','jnt_l_hand'})do
            names[#names+1]=FName(name)
        end
        bones=names
    end)
    local function dimensions(s)
        if not layoutChecked and type(StaticFindObject)=='function'then
            layoutChecked=true
            local ok,v=pcall(StaticFindObject,'/Script/UMG.Default__WidgetLayoutLibrary')
            if ok and valid(v)then layout=v end
        end
        local size=valid(layout) and call(layout,'GetViewportSize',s.pc)
        local w,h=read(size,'X'),read(size,'Y')
        if not finite(w) or not finite(h) or w<320 or h<200 or w>16384 or h>16384 then
            -- Native helper's game-client dimensions only normalize pixels;
            -- they never replace the engine's camera projection.
            local f=io.open(root..'scan-aspect.txt','r')
            if f then
                local a,b=(f:read(64) or ''):match('^(%d+) (%d+)%s*$');f:close()
                w,h=tonumber(a),tonumber(b)
            end
        end
        if finite(w) and finite(h) and w>=320 and h>=200 and w<=16384 and h<=16384 then
            width,height=w,h;return true
        end
        return false
    end
    return function(now,s)
        if not prepare()then return end
        local active=s~=nil
        local markers=active and s.worldExperiments and s.worldExperiments.markers or {}
        -- The current camera is applied in EngineTickPre. Publish on every
        -- camera frame; only an empty scanner uses slow idle housekeeping.
        if #markers==0 and not hadMarkers and now<nextWrite and active==wasActive then return end
        hadMarkers=#markers>0
        wasActive=active;seq=seq+1
        nextWrite=now+.1
        if s~=diagnosticSession then
            diagnosticSession=s;nextDiagnostic=now+1
            diagnostic={selected=0,valid=0,published=0,geometryRejected=0,colliderFallback=0,viewCulled=0}
        end
        local worldState=active and s.worldExperiments
        local diagnose=log and worldState and worldState.options and worldState.options.characters
        local rows={}
        local candidates={}
        if active then
            for i=1,math.min(128,#markers)do
                local marker=markers[i]
                if diagnose and marker.type<=2 then diagnostic.selected=diagnostic.selected+1 end
                candidates[#candidates+1]=marker
            end
        end
        if s~=metadataSession then metadataSession=s;metadata={};metadataOwners={};nextMetadata=0 end
        local drawable={}
        if active and #candidates>0 and valid(s.pc) and dimensions(s)then
            local calls,failed=0,false
            local function nativeProject(position)
                if not valid(s.pc)then failed=true;return end
                local screen={}
                local ok,visible=pcall(function()
                    return s.pc:ProjectWorldLocationToScreen(position,screen,true)
                end)
                calls=calls+1
                if not ok then failed=true;return end
                local x,y=read(screen,'X'),read(screen,'Y')
                if visible==true and finite(x) and finite(y)then return x/width,y/height end
            end
            local ok,project,reason=pcall(M.projection.new,s,nativeProject)
            if not ok then reason=tostring(project);project=nil end
            if diagnose then diagnostic.projection=project and 'ready' or reason or 'unavailable' end
            if not project and not failed and reason~='camera_lens_pending' and not projectionFailures[reason or 'unknown']then
                projectionFailures[reason or 'unknown']=true
                if log then log('Scanner projection unavailable: '..tostring(reason or 'unknown'))end
            end
            for _,marker in ipairs(project and candidates or {})do
                local actor=marker.actor
                -- Read this actor's transform again at publication time. A
                -- pooled/streamed actor cannot reuse old geometry or identity.
                local visible=possiblyVisible(marker,project)
                if diagnose and marker.type<=2 and not visible then diagnostic.viewCulled=diagnostic.viewCulled+1 end
                if failed then break end
                if visible and M.targets.markerCurrent(s,marker)then
                    if diagnose and marker.type<=2 then diagnostic.valid=diagnostic.valid+1 end
                    local current=point(call(actor,'K2_GetActorLocation'))
                    local old,center,extent=point(marker.actorPosition),point(marker.position),point(marker.extent)
                    if current and old and center and extent then
                        center={X=center.X+current.X-old.X,Y=center.Y+current.Y-old.Y,Z=center.Z+current.Z-old.Z}
                        -- Characters fall back only to their current genuine
                        -- collider; a cached capsule cannot revive a stale pose.
                        local liveCenter,liveExtent=center,extent
                        if marker.type<=2 then liveCenter,liveExtent=currentBounds(actor,center,extent)end
                        local x,y,w,h
                        if marker.type==1 then
                            x,y,w,h=skeletalBounds(actor,bones,project,marker,liveCenter or center,liveExtent or extent)
                        end
                        -- nil means skeleton unavailable; false means a
                        -- genuine skeleton is outside this camera's view.
                        if x==nil and liveCenter and liveExtent then
                            if diagnose and marker.type==1 then diagnostic.colliderFallback=diagnostic.colliderFallback+1 end
                            x,y,w,h=M.bounds(liveCenter,liveExtent,project)
                        end
                        if failed then break end
                        local p=s.flight and s.flight.p
                        local d=p and math.sqrt((current.X/100-p.x)^2+(current.Y/100-p.y)^2+(current.Z/100-p.z)^2)
                        if x and marker.type and marker.type>=1 and marker.type<=4 and finite(d) and d>=0 then
                            drawable[#drawable+1]={marker=marker,x=x,y=y,width=w,height=h,distance=d}
                            -- Rejected/behind-camera actors do not consume
                            -- the 16-row display and native metadata budget.
                            if #drawable>=16 then break end
                        elseif diagnose and marker.type<=2 then
                            diagnostic.geometryRejected=diagnostic.geometryRejected+1
                        end
                    elseif diagnose and marker.type<=2 then
                        diagnostic.geometryRejected=diagnostic.geometryRejected+1
                    end
                end
            end
            if failed then
                drawable={}
                if not unavailable then
                    unavailable=true
                    if log then log('Scanner unavailable: native PlayerController.ProjectWorldLocationToScreen API failed.')end
                end
            end
            -- Production projection performs five native lens probes; all
            -- candidate/pose point projections then run locally. The upper
            -- bound also permits direct native projection fixtures.
            assert(calls<=128*22,'scanner projection budget exceeded')
        end
        if active and M.nativeBridge and now>=nextMetadata then
            nextMetadata=now+.1
            native=native or M.nativeBridge.new(root)
            local actors={}
            metadataOwners={}
            for _,item in ipairs(drawable)do
                local marker=item.marker
                if marker.type<=2 then
                    actors[#actors+1]=marker.actor
                    local address=call(marker.actor,'GetAddress')
                    if address then metadataOwners[address]={actor=marker.actor,entry=marker.entry,
                        name=marker.identityName,world=marker.world}end
                end
            end
            if #actors>0 then
                local ok,result,err=pcall(native.metadata,native,s.pawn,actors)
                metadata=ok and type(result)=='table' and result or {}
                if not ok or type(result)~='table' then
                    if not metadataUnavailable and log then log('Native binocular metadata unavailable: '..tostring(ok and err or result))end
                    metadataUnavailable=true
                else metadataUnavailable=false end
            else metadata={} end
        end
        for _,item in ipairs(drawable)do
            local marker=item.marker
            if M.targets.markerCurrent(s,marker)then
                local address=call(marker.actor,'GetAddress')
                local owner=metadataOwners[address]
                local ok,matches=pcall(function()return owner and owner.actor==marker.actor and owner.entry==marker.entry
                    and owner.name==marker.identityName and owner.world==marker.world end)
                local record=ok and matches and metadata[address]
                local relation=record and record.relation or -1
                if not finite(relation) or relation%1~=0 or relation< -1 or relation>4 then relation=-1 end
                local faction=record and M.factionIcon(record.names,iconNames) or 0
                rows[#rows+1]=string.format('%d %.7f %.7f %.7f %.7f %.2f %d %d',marker.type,item.x,item.y,item.width,item.height,item.distance,relation,faction)
                if diagnose and marker.type<=2 then diagnostic.published=diagnostic.published+1 end
            end
        end
        if diagnose and now>=nextDiagnostic then
            nextDiagnostic=now+5
            local found=worldState.scannerDiagnostics or {}
            log(string.format('Scanner NPC: observed=%d cached=%d live=%d hidden=%d suspended=%d retired=%d retired_actor=%d retired_identity=%d retired_world=%d retired_dead=%d dead_rejected=%d actor_rejected=%d mesh_pending=%d position_pending=%d ready_in_range=%d selected_npc=%d dropped_by_limit=%d selected=%d view_culled=%d valid=%d published=%d geometry_rejected=%d collider_fallback=%d projection=%s',
                found.observed or 0,found.cached or 0,found.live or 0,found.hidden or 0,found.suspended or 0,
                found.retired or 0,found.retiredActor or 0,found.retiredIdentity or 0,found.retiredWorld or 0,found.retiredDead or 0,found.deadRejected or 0,
                found.actorRejected or 0,found.meshPending or 0,found.positionPending or 0,
                found.readyInRange or 0,found.selectedNPC or 0,found.droppedByLimit or 0,
                diagnostic.selected,diagnostic.viewCulled,diagnostic.valid,diagnostic.published,diagnostic.geometryRejected,diagnostic.colliderFallback,
                diagnostic.projection or 'no_targets'))
            diagnostic.selected,diagnostic.viewCulled,diagnostic.valid,diagnostic.published,diagnostic.geometryRejected,diagnostic.colliderFallback=0,0,0,0,0,0
            diagnostic.projection=nil
            -- Fixed engine getters only, once per diagnostic interval. This
            -- distinguishes a stale pawn anchor from unavailable scan geometry.
            local pawn=point(call(s.pawn,'K2_GetActorLocation'))
            local camera=point(call(s.camera,'K2_GetActorLocation'))
            local combat=s.combat
            local anchor=combat and combat.reactionReady and combat.proxy or s.npcAnchor
            local intended=point(anchor and anchor.lastPosition)
            local movement=s.movement
            if pawn and camera then
                local gap=math.sqrt((pawn.X-camera.X)^2+(pawn.Y-camera.Y)^2+(pawn.Z-camera.Z)^2)/100
                local anchorGap=intended and math.sqrt((pawn.X-intended.X)^2+(pawn.Y-intended.Y)^2+(pawn.Z-intended.Z)^2)/100 or -1
                local visibility=s.playerVisibility
                log(string.format('NPC residency: anchor=%s pawn_cm=%.0f,%.0f,%.0f camera_cm=%.0f,%.0f,%.0f camera_gap_m=%.2f anchor_gap_m=%.2f movement_mode=%s tick=%s entry_tick=%s visibility_rejected=%d',
                    combat and combat.reactionReady and 'combat' or s.npcAnchor and 'streaming' or 'launch',
                    pawn.X,pawn.Y,pawn.Z,camera.X,camera.Y,camera.Z,gap,anchorGap,
                    tostring(read(movement,'MovementMode')),tostring(call(movement,'IsComponentTickEnabled')),
                    tostring(s.previousMovementTick),visibility and visibility.rejected or 0))
            end
        end
        -- Windows Lua cannot atomically rename over an existing file. Write
        -- alternating slots instead; header/trailer identify complete frames,
        -- and the reader keeps the other coherent slot while this one changes.
        local f=io.open(slots[seq%2+1],'w')
        if not f then publicationError();return end
        local token=string.format('%.0f %d',generation,seq)
        local ok=f:write('4 '..token..' '..#rows..'\n',table.concat(rows,'\n'),#rows>0 and '\n' or '',token,'\n')
        local closed=f:close()
        if not ok or not closed then publicationError()else publicationUnavailable=false end
    end
end
return M
