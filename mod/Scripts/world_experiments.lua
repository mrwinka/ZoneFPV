-- Experimental world observations. The scanner reads genuine loaded actors;
-- it never changes AI, spawns artifacts or writes shared game prototypes.
local M={}
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
M.pickup=dofile(here..'artifact_pickup.lua')
local artifactSettings=dofile(here..'artifact_settings.lua')
local constructionObservers={}
local liveAPI
local function invoke(o,k,...)
    return o[k](o,...)
end
local function call(o,k,...)
    local ok,v=pcall(invoke,o,k,...)
    if ok then return v end
end
local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function valid(o)return call(o,'IsValid')==true end
local function same(a,b)
    if not valid(a) or not valid(b)then return false end
    local address=call(a,'GetAddress')
    return address~=nil and address==call(b,'GetAddress')
end
local function finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function integer(n)return finite(n) and n%1==0 and n>=0 and n<=2147483647 end
local function point(v)
    local x,y,z=read(v,'X'),read(v,'Y'),read(v,'Z')
    if finite(x) and finite(y) and finite(z) then return {X=x,Y=y,Z=z} end
end
local function distance(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
local function cameraPosition(s)
    local p=s.flight and s.flight.p
    if p and finite(p.x) and finite(p.y) and finite(p.z) then return {X=p.x*100,Y=p.y*100,Z=p.z*100} end
end
local function squared(a,b)return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2 end
-- Horizontal cells keep nearby queries small without assuming that a streamed
-- actor's gameplay core exists. All positions come from AActor's fixed API.
local cellSize=10000
local function cellKey(p)return math.floor(p.X/cellSize)..':'..math.floor(p.Y/cellSize)end
local function index(g,e)
    local key=cellKey(e.center)
    if e.cell==key then return end
    if e.cell then
        local old=g.cells[e.cell]
        if old then old[e]=nil;if next(old)==nil then g.cells[e.cell]=nil end end
    end
    e.cell=key
    local cell=g.cells[key] or {};g.cells[key]=cell;cell[e]=true
end
local function nearby(g,a,b,padding)
    b=b or a
    local found={}
    local x1=math.floor((math.min(a.X,b.X)-padding)/cellSize)
    local x2=math.floor((math.max(a.X,b.X)+padding)/cellSize)
    local y1=math.floor((math.min(a.Y,b.Y)-padding)/cellSize)
    local y2=math.floor((math.max(a.Y,b.Y)+padding)/cellSize)
    -- A teleport/invalidly long segment must not walk millions of empty cells.
    if (x2-x1+1)*(y2-y1+1)>256 then return g.entries end
    for x=x1,x2 do for y=y1,y2 do
        local cell=g.cells[x..':'..y]
        if cell then for e in pairs(cell)do found[#found+1]=e end end
    end end
    return found
end
local function active(opts)
    return opts and (opts.characters or opts.visionTargets or opts.anomaliesScan or opts.anomalyInterference or opts.anomalyDamage or opts.detector)
end
local function liveActor(a)
    -- A streamed/pool actor can remain a valid UObject while it is already
    -- being torn down. These fixed engine checks never enter Obj's gameplay
    -- core, which may have disappeared before its AActor is retired.
    return valid(a) and call(a,'HasAnyFlags',0x18030)~=true
        and call(a,'IsActorBeingDestroyed')~=true
end
local function rooted(a)
    -- K2_GetActorLocation returns the origin for actors whose construction
    -- has not installed a root yet. Do not mistake that default for a target.
    -- Nil permits wrappers without this reflected property; a native null
    -- UObject is represented by an invalid object and is rejected.
    local root=read(a,'RootComponent')
    return root==nil or valid(root)
end
local function currentActor(s,a)
    return liveActor(a) and rooted(a) and same(call(a,'GetWorld'),s.world)
        and not same(a,s.pawn) and not same(a,s.camera)
end
local function identityMatches(a,name)
    if name==nil then return read(a,'GetFName')==nil end
    local current=call(a,'GetFName')
    -- UE4SS FName equality compares the copied numeric identity, including
    -- its instance number. Never stringify a streamed actor's native name.
    local ok,equal=pcall(function()return current~=nil and current==name end)
    return ok and equal
end
function M.markerCurrent(s,marker)
    if not s or not marker or not integer(marker.type) or marker.type<1 or marker.type>4 then return false end
    local entry=marker.entry
    if entry and (entry.expired or entry.suspended or entry.type~=marker.type) then return false end
    local a=marker.actor
    if not currentActor(s,a) or not same(marker.world,s.world)
        or marker.identityAddress~=call(a,'GetAddress') or not identityMatches(a,marker.identityName) then return false end
    -- Hidden pooled NPCs are not rendered scan targets. Hidden/nonvisual
    -- anomaly volumes are genuine hazards and must remain detectable.
    return marker.type>2 or read(a,'bHidden')~=true and not valid(read(a,'DeadBodyComponent'))
        and M.markerMesh(a,marker)~=nil
end
local groups={
    {class='Agent',type=1,enabled=function(o)return o.characters or o.visionTargets end},
    {class='UIDActor_Anomaly',type=3,enabled=function(o)return o.anomaliesScan or o.anomalyInterference or o.anomalyDamage end},
    {class='Artifact',type=4,enabled=function(o)return o.detector end},
    {class='UIDActor_FireBreathAnomaly',type=3,enabled=function(o)return o.anomaliesScan or o.anomalyInterference or o.anomalyDamage end},
    {class='UIDActor_MistAnomaly',type=3,enabled=function(o)return o.anomaliesScan or o.anomalyInterference or o.anomalyDamage end},
    {class='UIDActor_VortexArchAnomaly',type=3,enabled=function(o)return o.anomaliesScan or o.anomalyInterference or o.anomalyDamage end},
    {class='UIDActor_PoppyFieldAnomaly',type=3,enabled=function(o)return o.anomaliesScan or o.anomalyInterference or o.anomalyDamage end}
}
local function radius(actor)
    -- Fixed engine API only. Avoid dynamic class traversal and reads of
    -- optional component properties on recycled/unknown Blueprint classes.
    if not valid(actor)then return 2 end
    local center,extent={},{}
    local ok=pcall(function()actor:GetActorBounds(true,center,extent,false)end)
    extent=ok and point(extent)
    if extent and extent.X>0 and extent.Y>0 and extent.Z>0 then
        return math.max(.5,math.min(30,math.max(extent.X,extent.Y)/100))
    end
    return 2 -- Explicit generic prototype radius when no collision data exists.
end
local function actorBounds(actor,pos,t,r)
    if not valid(actor)then return pos,{X=45,Y=45,Z=90}end
    local center,extent={},{ }
    -- Native Actor bounds use the real collider centre rather than guessed
    -- human/mutant height offsets. Collision-only bounds exclude attached
    -- weather/audio components whose enormous extents are not the target.
    local ok=pcall(function()actor:GetActorBounds(true,center,extent,false)end)
    center=ok and point(center);extent=ok and point(extent)
    if center and extent and extent.X>0 and extent.Y>0 and extent.Z>0
        and extent.X<10000 and extent.Y<10000 and extent.Z<10000 then
        return center,extent
    end
    -- Some non-blocking anomalies have no colliding bounds. Their genuine
    -- prototype radius defines their scan area; no arbitrary screen square.
    local radiusCm=t==3 and (r or 2)*100 or t==4 and 12 or 45
    return pos,{X=radiusCm,Y=radiusCm,Z=t<=2 and 90 or radiusCm}
end
local function empty(g)
    g.markers={};g.anomalyInterference=0;g.anomalyDamageRate=0;g.artifactDistance=-1
    g.artifactReady=false;g.nearestArtifact=nil
end
-- Human binoculars use these bones in ObjBinocularsParamsPrototypes. Engine
-- skeleton queries do not dereference Obj's streamed-out gameplay core.
local boneNames={'jnt_head','jnt_spine_03','jnt_r_foot','jnt_l_foot','jnt_r_hand','jnt_l_hand'}
local bones
local skinnedClass
local function loadedMeshAsset(mesh)
    -- UE4SS returns an invalid UObject for an unavailable reflected member,
    -- not nil. A getter missing from this engine build must not exclude a
    -- mesh whose actual reflected asset is loaded. Require a genuine asset
    -- in every case, including wrappers used during construction/streaming.
    return valid(read(mesh,'SkinnedAsset')) or valid(read(mesh,'SkeletalMesh'))
        or valid(call(mesh,'GetSkinnedAsset'))
end
local function usableMesh(mesh,actor)
    return valid(mesh) and call(mesh,'HasAnyFlags',0x18030)~=true
        and loadedMeshAsset(mesh)
        and (not actor or read(mesh,'GetOwner')==nil or same(call(mesh,'GetOwner'),actor))
end
local function characterMeshes(a)
    local primary=read(a,'Mesh')
    if usableMesh(primary,a) then return {primary} end
    if not valid(skinnedClass) then
        local ok,value=pcall(function()return StaticFindObject('/Script/Engine.SkinnedMeshComponent')end)
        if ok then skinnedClass=value end
    end
    local meshes={}
    if not valid(skinnedClass) then return meshes end
    local list=call(a,'K2_GetComponentsByClass',skinnedClass)
    local n=call(list,'GetArrayNum') or (type(list)=='table' and #list)
    if not finite(n) or n<0 or n>128 then return meshes end
    for i=1,n do
        local mesh=read(list,i)
        if type(mesh)=='userdata' then
            local kind=call(mesh,'type')
            if kind=='RemoteUnrealParam' or kind=='LocalUnrealParam' then mesh=call(mesh,'get') end
        end
        if usableMesh(mesh,a) then meshes[#meshes+1]=mesh end
    end
    return meshes
end
function M.markerMesh(a,marker)
    -- Discovery/refresh owns modular component enumeration. A live writer
    -- only validates its chosen cached mesh, keeping repeated per-frame
    -- export checks independent of the number of outfit components.
    local entry=marker and marker.entry
    if entry then return usableMesh(entry.mesh,a) and entry.mesh or nil end
    return characterMeshes(a)[1]
end
local function characterType(a)
    if valid(read(a,'DeadBodyComponent'))then return nil,nil,'dead' end
    local meshes=characterMeshes(a)
    if #meshes==0 then return end
    if not bones then
        bones={}
        for _,name in ipairs(boneNames)do
            local ok,value=pcall(function()return FName(name)end)
            if not ok then bones=nil;return end
            bones[#bones+1]=value
        end
    end
    for _,mesh in ipairs(meshes)do
        local human=true
        for _,bone in ipairs(bones)do
            if call(mesh,'DoesSocketExist',bone)~=true then human=false;break end
        end
        if human then return 1,mesh end
    end
    return 2,meshes[1]
end
-- Fraction of a movement segment inside a sphere; catches crossings whose
-- endpoints are both outside, without assigning a full frame of damage.
function M.insideFraction(a,b,center,r)
    local dx,dy,dz=b.X-a.X,b.Y-a.Y,b.Z-a.Z
    local ox,oy,oz=a.X-center.X,a.Y-center.Y,a.Z-center.Z
    local aa=dx*dx+dy*dy+dz*dz
    local cc=ox*ox+oy*oy+oz*oz-r*r
    if aa<.000001 then return cc<=0 and 1 or 0 end
    local bb=2*(ox*dx+oy*dy+oz*dz)
    local discriminant=bb*bb-4*aa*cc
    if discriminant<=0 then return 0 end
    local root=math.sqrt(discriminant)
    return math.max(0,math.min(1,(-bb+root)/(2*aa))-math.max(0,(-bb-root)/(2*aa)))
end
function M.new(system,log,root)
    local api={system=system,log=log or function()end,notifications=constructionObservers,
        clock=os.clock,nativeBudget=.0015,pickup=M.pickup.new(root or here..'../')}
    function api:once(g,key,text)
        if not g.logged[key]then g.logged[key]=true;self.log('World experiments: '..text)end
    end
    function api:begin(s,opts)
        if s.worldExperiments then return s.worldExperiments end
        local g={world=s.world,buckets={},cells={},nextRead=0,group=0,logged={},elapsed=0,active=false,frame=0,
            queues={},queued=0,entries={},byAddress={},refresh=0,initial={},fallback={},performance={}}
        g.scannerDiagnostics={observed=0,cached=0,actorRejected=0,meshPending=0,positionPending=0,deadRejected=0,
            live=0,hidden=0,suspended=0,retired=0,retiredActor=0,retiredIdentity=0,retiredWorld=0,retiredDead=0,
            readyInRange=0,selectedNPC=0,droppedByLimit=0,deferredNPC=0}
        for _,group in ipairs(groups)do g.queues[group.class]={items={},head=1,tail=0}end
        empty(g);s.worldExperiments=g
        return g
    end
    function api:current(s,a)
        return currentActor(s,a)
    end
    function api:enqueue(g,a,group)
        if g.queued>=8192 then
            if group.type==3 then
                for _,other in ipairs(groups)do
                    local q=g.queues[other.class]
                    if other.type~=3 then
                        if q.head<=q.tail then
                            q.items[q.head]=nil;q.head=q.head+1;g.queued=g.queued-1;break
                        elseif q.deferred then
                            q.deferred[q.deferredHead]=nil;q.deferredHead=q.deferredHead+1;g.queued=g.queued-1
                            g.scannerDiagnostics.deferredNPC=g.scannerDiagnostics.deferredNPC-1
                            if q.deferredHead>q.deferredTail then q.deferred=nil end
                            break
                        elseif q.retries then
                            q.retries[q.retryHead]=nil;q.retryHead=q.retryHead+1;g.queued=g.queued-1
                            if q.retryHead>q.retryTail then q.retries=nil end
                            break
                        end
                    end
                end
            end
            if g.queued>=8192 then g.queueDrops=(g.queueDrops or 0)+1;return end
        end
        local q=g.queues[group.class]
        q.tail=q.tail+1;q.items[q.tail]={actor=a,group=group,tries=0,notified=true};g.queued=g.queued+1
    end
    function api:expire(g,e,reason)
        if e.type<=2 then
            local d=g.scannerDiagnostics
            d.live=d.live-1;d.retired=d.retired+1
            if e.hiddenNPC then d.hidden=d.hidden-1 end
            if e.suspended then d.suspended=d.suspended-1 end
            if reason then d[reason]=(d[reason] or 0)+1 end
        end
        e.expired=true;g.byAddress[e.key]=nil
        local cell=g.cells[e.cell]
        if cell then cell[e]=nil;if next(cell)==nil then g.cells[e.cell]=nil end end
        local bucket=g.buckets[e.group.class] or {}
        for i=#bucket,1,-1 do if bucket[i]==e then table.remove(bucket,i);break end end
        -- Swap removal avoids shifting a large loaded pool during flight.
        local at=e.slot;local last=g.entries[#g.entries]
        g.entries[at]=last;g.entries[#g.entries]=nil
        if last~=e then last.slot=at end
    end
    function api:refreshEntry(s,g,e)
        local retired
        if not liveActor(e.actor)then retired='retiredActor'
        elseif not identityMatches(e.actor,e.name)then retired='retiredIdentity'
        elseif not same(call(e.actor,'GetWorld'),s.world)then retired='retiredWorld'
        elseif same(e.actor,s.pawn) or same(e.actor,s.camera)then retired='retiredActor'
        elseif e.type<=2 and valid(read(e.actor,'DeadBodyComponent'))then retired='retiredDead' end
        if retired then
            self:expire(g,e,retired);return
        end
        local pos=rooted(e.actor) and point(call(e.actor,'K2_GetActorLocation'))
        local recaptureBounds=false
        if e.type<=2 and not usableMesh(e.mesh,e.actor)then
            local t,mesh=characterType(e.actor)
            if t then
                recaptureBounds=true
                e.type,e.mesh=t,mesh
            end
        end
        local suspended=not pos or e.type<=2 and not usableMesh(e.mesh,e.actor)
        local hidden=e.type<=2 and read(e.actor,'bHidden')==true
        if e.type<=2 then
            local d=g.scannerDiagnostics
            if (e.suspended==true)~=suspended then d.suspended=d.suspended+(suspended and 1 or -1)end
            if (e.hiddenNPC==true)~=hidden then d.hidden=d.hidden+(hidden and 1 or -1)end
        end
        e.suspended=suspended;e.hiddenNPC=hidden
        if pos then
            local old=e.position
            e.center.X=e.center.X+pos.X-old.X;e.center.Y=e.center.Y+pos.Y-old.Y;e.center.Z=e.center.Z+pos.Z-old.Z
            old.X=pos.X;old.Y=pos.Y;old.Z=pos.Z
            if recaptureBounds then
                local center,extent=actorBounds(e.actor,pos,e.type)
                for _,axis in ipairs({'X','Y','Z'})do e.center[axis]=center[axis];e.extent[axis]=extent[axis]end
            end
            index(g,e)
        end
        e.refreshed=g.frame
    end
    function api:discover(s,opts,now)
        local g=s.worldExperiments
        local performance=g.performance;performance.lookupMs=0
        self.live=g;liveAPI=self
        -- Construction notifications only retain references. No engine calls
        -- are made until a subsequent game-thread update.
        for _,group in ipairs(groups)do
            if self.notifications[group.class]==nil and type(NotifyOnNewObject)=='function' then
                local ok=pcall(NotifyOnNewObject,'/Script/Stalker2.'..group.class,function(a)
                    local current=liveAPI
                    local live=current and current.live
                    if live and live.active and group.enabled(live.options)then current:enqueue(live,a,group)end
                end)
                self.notifications[group.class]=ok
            end
        end
        -- Initial lookups are spread over frames, then notifications handle
        -- streaming. Slow fallback is used only without construction support.
        for _=1,#groups do
            g.group=g.group%#groups+1
            local group=groups[g.group]
            if group.enabled(opts) and (not g.initial[group.class]
                or not self.notifications[group.class] and now>=(g.fallback[group.class] or 0))then
                g.initial[group.class]=true;g.fallback[group.class]=now+30
                local started=self.clock()
                local ok,list=pcall(FindAllOf,group.class)
                performance.lookupMs=(self.clock()-started)*1000
                if ok and type(list)=='table' then
                    -- Keep the returned array and consume it in bounded slices.
                    -- New-object notifications have a separate queue and never
                    -- wait behind this initial loaded-world backlog.
                    local q=g.queues[group.class]
                    q.initial=list;q.cursor=1;q.limit=math.min(#list,8192)
                elseif not ok then self:once(g,'lookup-'..group.class,'lookup unavailable for '..group.class)end
                break
            end
        end
        local started=self.clock();local deadline=started+self.nativeBudget*.5
        local discovered=0
        local function pop(group,notificationsOnly)
            local q=g.queues[group.class]
            local retry=q.criticalRetries and q.criticalRetries[q.criticalHead]
            local ready=retry and retry.retryFrame<=g.frame and retry.attemptFrame~=g.frame
            local function takeRetry()
                q.criticalRetries[q.criticalHead]=nil;q.criticalHead=q.criticalHead+1;g.queued=g.queued-1
                if q.criticalHead>q.criticalTail then q.criticalRetries=nil end
                q.preferRetry=false
                return retry
            end
            -- Ready construction retries share the notification fast lane.
            -- Alternate with fresh events; waiting/current-frame retries never
            -- consume attempts and never block an initial array behind them.
            if ready and (q.head>q.tail or q.preferRetry~=false)then return takeRetry()end
            local deferred=q.deferred and q.deferred[q.deferredHead]
            local deferredReady=deferred and deferred.retryAt<=now and deferred.attemptFrame~=g.frame
            local function takeDeferred()
                q.deferred[q.deferredHead]=nil;q.deferredHead=q.deferredHead+1;g.queued=g.queued-1
                g.scannerDiagnostics.deferredNPC=g.scannerDiagnostics.deferredNPC-1
                if q.deferredHead>q.deferredTail then q.deferred=nil end
                q.preferDeferred=false
                return deferred
            end
            -- An existing NPC may load its mesh long after construction.
            -- Sparse pending reads alternate with events/initial/fast work so
            -- a continuing construction backlog cannot starve those actors.
            if not notificationsOnly and deferredReady and q.preferDeferred~=false then return takeDeferred()end
            if q.head<=q.tail then
                local e=q.items[q.head];q.items[q.head]=nil;q.head=q.head+1;g.queued=g.queued-1
                if q.head>q.tail then q.items={};q.head=1;q.tail=0 end
                q.preferRetry=true;q.preferDeferred=true
                return e
            end
            if ready then return takeRetry()end
            if not notificationsOnly and q.initial then
                if q.cursor<=q.limit then
                    local e={actor=q.initial[q.cursor],group=group,tries=0}
                    q.cursor=q.cursor+1
                    if q.cursor>q.limit then q.initial=nil end
                    q.preferDeferred=true
                    return e
                end
                q.initial=nil
            end
            if not notificationsOnly and q.retries and q.retryHead<=q.retryTail then
                local e=q.retries[q.retryHead]
                if e.attemptFrame~=g.frame and (not e.retryAt or now>=e.retryAt)then
                    q.retries[q.retryHead]=nil;q.retryHead=q.retryHead+1;g.queued=g.queued-1
                    if q.retryHead>q.retryTail then q.retries=nil end
                    q.preferDeferred=true
                    return e
                end
            end
            if not notificationsOnly and deferredReady then return takeDeferred()end
        end
        local function retain(e)
            if g.queued>=8192 then g.queueDrops=(g.queueDrops or 0)+1;return end
            -- Bind a delayed reference before it survives another frame.
            -- Address reuse/name/world changes cannot adopt a replacement
            -- through an old construction or unloaded-mesh retry.
            if not e.pendingBound then
                e.pendingBound=true;e.pendingAddress=call(e.actor,'GetAddress');e.pendingName=call(e.actor,'GetFName')
            end
            if not e.pendingWorld then
                local world=call(e.actor,'GetWorld');if valid(world)then e.pendingWorld=world end
            end
            local q=g.queues[e.group.class]
            if e.slowPending then
                if not q.deferred then q.deferred={};q.deferredHead=1;q.deferredTail=0 end
                q.deferredTail=q.deferredTail+1;q.deferred[q.deferredTail]=e;g.queued=g.queued+1
                g.scannerDiagnostics.deferredNPC=g.scannerDiagnostics.deferredNPC+1
                return
            end
            if e.notified and e.group.type==3 then
                e.retryFrame=g.frame+1;e.retryAt=nil
                if not q.criticalRetries then q.criticalRetries={};q.criticalHead=1;q.criticalTail=0 end
                q.criticalTail=q.criticalTail+1;q.criticalRetries[q.criticalTail]=e;g.queued=g.queued+1
                return
            end
            if not q.retries then q.retries={};q.retryHead=1;q.retryTail=0 end
            q.retryTail=q.retryTail+1;q.retries[q.retryTail]=e;g.queued=g.queued+1
        end
        local function retryUnready(e)
            if e.tries<30 then e.tries=e.tries+1;e.retryAt=now+.1
            else e.slowPending=true;e.retryAt=now+1 end
            retain(e)
        end
        local function observe(e)
            local a,group=e.actor,e.group
            local diagnostic=group.type==1 and g.scannerDiagnostics
            if diagnostic then diagnostic.observed=diagnostic.observed+1 end
            e.attemptFrame=g.frame
            if e.pendingBound and (not liveActor(a) or e.pendingAddress~=call(a,'GetAddress')
                or not identityMatches(a,e.pendingName) or e.pendingWorld and not same(call(a,'GetWorld'),e.pendingWorld))then
                if diagnostic then diagnostic.actorRejected=diagnostic.actorRejected+1 end
                return
            end
            if diagnostic and liveActor(a) and valid(read(a,'DeadBodyComponent'))then
                diagnostic.deadRejected=diagnostic.deadRejected+1;return
            end
            if group.enabled(opts) and self:current(s,a)then
                local key=call(a,'GetAddress')
                if not key then return end
                local cached=g.byAddress[key]
                if cached then
                    -- A construction event can reuse an address after an
                    -- actor was pooled/replaced. Reclassify and recapture its
                    -- collider instead of translating the previous geometry.
                    -- Repeated initial arrays still reuse an unchanged entry.
                    if e.notified or not liveActor(cached.actor) or not identityMatches(cached.actor,cached.name)
                        or group.type==3 and cached.type~=3 then
                        self:expire(g,cached)
                    else return end
                end
                local pos=point(call(a,'K2_GetActorLocation'))
                local t,mesh,characterReason=group.type
                if t==1 then t,mesh,characterReason=characterType(a)end
                if pos and t then
                    if #g.entries>=2048 and t==3 then
                        -- A full NPC cache must not prevent a newly streamed
                        -- hazard from being observed in this flight.
                        local farthest,at;local p=cameraPosition(s)
                        for _,cached in ipairs(g.entries)do
                            if cached.type~=3 then
                                local d=p and squared(cached.position,p) or 0
                                if not farthest or d>farthest then farthest=d;at=cached end
                            end
                        end
                        if at then self:expire(g,at)end
                    end
                    if #g.entries>=2048 then return end
                    local r=t==3 and radius(a) or nil
                    local center,extent=actorBounds(a,pos,t,r)
                    local entry={actor=a,type=t,position=pos,center=center,extent=extent,radius=r,group=group,key=key,
                        name=call(a,'GetFName'),mesh=mesh,hiddenNPC=t<=2 and read(a,'bHidden')==true,
                        slot=#g.entries+1,refreshed=g.frame}
                    g.entries[#g.entries+1]=entry;g.byAddress[key]=entry
                    if diagnostic then
                        diagnostic.cached=diagnostic.cached+1;diagnostic.live=diagnostic.live+1
                        if entry.hiddenNPC then diagnostic.hidden=diagnostic.hidden+1 end
                    end
                    index(g,entry)
                    local bucket=g.buckets[group.class] or {};g.buckets[group.class]=bucket;bucket[#bucket+1]=entry
                elseif not t and characterReason=='dead' then
                    if diagnostic then diagnostic.deadRejected=diagnostic.deadRejected+1 end
                elseif not t and (e.tries<30 or group.type==1) then
                    if diagnostic then diagnostic.meshPending=diagnostic.meshPending+1 end
                    retryUnready(e)
                elseif not pos and e.notified and group.type==3 and e.tries<30 then
                    e.tries=e.tries+1;retain(e)
                end
                if diagnostic and not pos then diagnostic.positionPending=diagnostic.positionPending+1 end
            elseif liveActor(a) and (e.tries<30 or group.type==1) and (not valid(call(a,'GetWorld'))
                or same(call(a,'GetWorld'),s.world) and not rooted(a))then
                retryUnready(e)
                if diagnostic then diagnostic.actorRejected=diagnostic.actorRejected+1 end
            elseif diagnostic then
                diagnostic.actorRejected=diagnostic.actorRejected+1
            end
        end
        -- Consume streamed hazards first, before either NPC notifications or
        -- initial arrays. The callback itself still makes zero engine calls.
        for _=1,16 do
            if discovered>=16 or self.clock()>=deadline then break end
            local e
            for _=1,#groups do
                g.notificationGroup=(g.notificationGroup or 0)%#groups+1
                local group=groups[g.notificationGroup]
                if group.type==3 and group.enabled(opts)then
                    e=pop(group,true);if e then break end
                end
            end
            if not e then break end
            observe(e);discovered=discovered+1
        end
        -- Initial anomalies take precedence over a large initial Agent array.
        for priority=1,2 do
            for _=1,16 do
                if discovered>=16 or self.clock()>=deadline then break end
                local e
                for _=1,#groups do
                    g.discoveryGroup=(g.discoveryGroup or 0)%#groups+1
                    local group=groups[g.discoveryGroup]
                    if group.enabled(opts) and ((group.type==3)==(priority==1))then
                        e=pop(group,false);if e then break end
                    end
                end
                if not e then break end
                observe(e);discovered=discovered+1
            end
        end
        performance.discoveryMs=(self.clock()-started)*1000;performance.discovered=discovered

        started=self.clock()
        local p=cameraPosition(s);local candidates=p and nearby(g,p,nil,40000) or {}
        local closest={}
        for _,e in ipairs(candidates)do
            e.refreshDistance=squared(e.position,p)
            for i=1,math.min(8,#closest+1)do
                if not closest[i] or e.refreshDistance<closest[i].refreshDistance then
                    table.insert(closest,i,e);if #closest>8 then table.remove(closest)end;break
                end
            end
        end
        for _,e in ipairs(closest)do e.refreshPriority=g.frame end
        table.sort(candidates,function(a,b)
            local firstA,firstB=a.refreshPriority==g.frame,b.refreshPriority==g.frame
            if firstA~=firstB then return firstA end
            if firstA then return a.refreshDistance<b.refreshDistance end
            local nearA,nearB=a.refreshDistance<=10000^2,b.refreshDistance<=10000^2
            if nearA~=nearB then return nearA end
            if a.refreshed~=b.refreshed then return a.refreshed<b.refreshed end
            return a.refreshDistance<b.refreshDistance
        end)
        deadline=self.clock()+self.nativeBudget*.5
        local refreshed=0
        -- Eight closest cached neighbours take priority every frame. Oldest
        -- remaining reads rotate within each band, so dense groups cannot starve.
        for _,e in ipairs(candidates)do
            if refreshed>=32 or self.clock()>=deadline then break end
            if e.refreshed~=g.frame and e.refreshDistance<=30000^2 then
                self:refreshEntry(s,g,e);refreshed=refreshed+1
            end
        end
        -- A small rotating background slice finds actors moving toward the
        -- camera and retires references outside the nearby spatial cells.
        for _=1,math.min(4,#g.entries)do
            if self.clock()>=deadline or #g.entries==0 then break end
            g.refresh=g.refresh%#g.entries+1
            local e=g.entries[g.refresh]
            if e.refreshed~=g.frame then self:refreshEntry(s,g,e);refreshed=refreshed+1 end
        end
        performance.refreshMs=(self.clock()-started)*1000;performance.refreshed=refreshed
        performance.entries=#g.entries;performance.queued=g.queued
    end
    function api:hazards(s,opts,dt,before)
        local g=s.worldExperiments;if not g then return end
        local started=self.clock()
        g.anomalyInterference=0;g.anomalyDamageRate=0;g.anomalyDamageAmount=0
        local p=cameraPosition(s);if not p then return g end
        before=before or p
        local fraction=0
        local candidates=nearby(g,before,p,9000)
        g.performance.hazardCandidates=#candidates
        for _,e in ipairs(candidates)do
            if e.type==3 and not e.expired and not e.suspended then
                local center=e.center;local r=e.radius or 2
                local d=distance(center,p);local outer=math.max(12,r*3)
                local inside=opts.anomalyDamage and M.insideFraction(before,p,center,r*100) or 0
                if (d<=outer or inside>0) and self:current(s,e.actor)then
                    if opts.anomalyInterference then
                        local strength=math.max(0,1-math.max(0,d-r)/(outer-r))
                        g.anomalyInterference=math.max(g.anomalyInterference,strength*95)
                    end
                    if opts.anomalyDamage then
                        if d<=r then g.anomalyDamageRate=math.min(120,g.anomalyDamageRate+40)end
                        fraction=fraction+inside
                    end
                end
            end
        end
        g.anomalyDamageAmount=math.min(3,fraction)*40*math.max(0,math.min(.1,dt or 0))
        g.performance.hazardsMs=(self.clock()-started)*1000
        return g
    end
    function api:update(s,opts,dt,now)
        local g=self:begin(s,opts)
        if g.active and not same(g.world,s.world)then
            self:finish(s);g=self:begin(s,opts)
        end
        if finite(dt) and dt>0 then g.elapsed=g.elapsed+math.min(.1,dt)end
        if not finite(now)then now=g.elapsed end
        if not active(opts) or not valid(s.world)then
            if g.active then
                empty(g);g.entries={};g.byAddress={};g.buckets={};g.cells={};g.initial={};g.queues={}
                local d=g.scannerDiagnostics
                d.live,d.hidden,d.suspended,d.readyInRange,d.selectedNPC,d.droppedByLimit,d.deferredNPC=0,0,0,0,0,0,0
                for _,group in ipairs(groups)do g.queues[group.class]={items={},head=1,tail=0}end
                g.queued=0;g.active=false;self.live=nil;g.lastSelectionPosition=nil
            end
            return g
        end
        g.frame=g.frame+1;g.active=true;g.options=opts;self:discover(s,opts,now)
        self:hazards(s,opts,0)
        local p=cameraPosition(s);if not p then return g end
        g.performance.selectionMs=0
        local collectRange=artifactSettings.value(opts.collectRange)
        -- Fast movement and new streamed objects rebuild the nearby view in
        -- this frame, independently of stationary marker housekeeping.
        local function pruneMarkers()
            -- The writer tests camera visibility before native validation.
            -- Keep the bounded candidate pool cheap here; cached lifecycle
            -- changes prune immediately and publication checks live identity.
            local selected=0
            for i=#g.markers,1,-1 do
                local marker=g.markers[i];local entry=marker.entry
                if not entry or entry.expired or entry.suspended or entry.type~=marker.type
                    or marker.type<=2 and entry.hiddenNPC then table.remove(g.markers,i)
                elseif marker.type<=2 then selected=selected+1 end
            end
            g.scannerDiagnostics.selectedNPC=selected
            if g.nearestArtifact and not self:current(s,g.nearestArtifact)then
                g.nearestArtifact=nil;g.artifactDistance=-1;g.artifactReady=false
            end
        end
        if g.collectRange==collectRange and now<g.nextRead and g.performance.discovered==0 and g.lastSelectionPosition
            and squared(p,g.lastSelectionPosition)<50^2 then
            local started=self.clock();pruneMarkers();g.performance.selectionMs=(self.clock()-started)*1000;return g
        end
        local started=self.clock()
        g.lastSelectionPosition=p
        g.collectRange=collectRange
        g.nextRead=now+.033
        g.markers={};g.artifactDistance=-1;g.artifactReady=false;g.nearestArtifact=nil
        local nearest=math.huge
        local diagnostic=g.scannerDiagnostics
        diagnostic.readyInRange=0;diagnostic.droppedByLimit=0
        local candidates=nearby(g,p,nil,40000)
        g.performance.markerCandidates=#candidates
        for _,e in ipairs(candidates)do
            if not e.expired and not e.suspended and e.group.enabled(opts)then
                local d=distance(e.position,p)
                if e.type==4 and d<=100 and d<nearest then
                    nearest=d;g.nearestArtifact=e.actor;g.artifactDistance=d;g.artifactReady=d<=collectRange
                end
                local show=(e.type<=2 and not e.hiddenNPC and opts.characters or e.type==3 and opts.anomaliesScan)and d<=300
                    or e.type==4 and opts.detector and d<=100
                if show then
                    if e.type<=2 then diagnostic.readyInRange=diagnostic.readyInRange+1 end
                    g.markers[#g.markers+1]={type=e.type,actor=e.actor,actorPosition=e.position,
                        position=e.center,extent=e.extent,radius=e.radius,distance=d,entry=e,
                        world=g.world,identityAddress=e.key,identityName=e.name}
                end
            end
        end
        table.sort(g.markers,function(a,b)return a.distance<b.distance end)
        while #g.markers>128 do
            if g.markers[#g.markers].type<=2 then diagnostic.droppedByLimit=diagnostic.droppedByLimit+1 end
            table.remove(g.markers)
        end
        pruneMarkers()
        g.performance.selectionMs=(self.clock()-started)*1000
        return g
    end
    function api:collect(s,opts)
        local g=s.worldExperiments
        if not opts or not opts.detector then return false,'Artifact detector is disabled.','detector_required' end
        if self.pickup.pending then return true,'Artifact pickup is in progress.','artifact_collecting' end
        if not g or not self:current(s,g.nearestArtifact)then return false,'No loaded artifact in detector range.','artifact_missing'end
        local target=g.nearestArtifact;local pos=point(call(target,'K2_GetActorLocation'));local p=cameraPosition(s)
        local collectRange=artifactSettings.value(opts.collectRange)
        if not pos or not p or distance(pos,p)>collectRange then
            return false,string.format('Move within %g m of the artifact.',collectRange),'artifact_too_far'
        end
        local ok,message,code=self.pickup:start(s.pawn,target)
        if ok then
            g.pickupTarget=target
            if code=='artifact_collected' then self:collected(g)end
        else self:once(g,'pickup-'..tostring(code),message)end
        return ok,message,code
    end
    function api:collected(g)
        local key=call(g.pickupTarget,'GetAddress');local entry=key and g.byAddress[key]
        if entry then self:expire(g,entry)end
        for i=#g.markers,1,-1 do if g.markers[i].actor==g.pickupTarget then table.remove(g.markers,i)end end
        if g.nearestArtifact==g.pickupTarget then g.nearestArtifact=nil;g.artifactDistance=-1;g.artifactReady=false end
        g.pickupTarget=nil
    end
    function api:pollPickup(s,dt)
        local ok,message,code=self.pickup:update(dt)
        if ok~=nil then
            if ok and code=='artifact_collected' and s.worldExperiments then self:collected(s.worldExperiments)end
            self.log('Artifact pickup: '..tostring(message))
        end
        return ok,message,code
    end
    function api:finish(s)
        self.live=nil;if liveAPI==self then liveAPI=nil end;s.worldExperiments=nil
    end
    return api
end
return M
