local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
assert(here,'ZoneFPV requires an on-disk script path')
local root=here..'../'
local flight=dofile(here..'flight.lua')
local input=dofile(here..'input.lua')
local publishAudio=dofile(here..'audio.lua').new(root)
local cfg=dofile(here..'config.lua')
local publishTelemetry=dofile(here..'telemetry.lua').new(root,flight,cfg)
local visualGuard=dofile(here..'visual_guard.lua')
local playerVisibility=dofile(here..'player_visibility.lua')
local worldOptions=dofile(here..'world_options.lua')
local options=worldOptions.load(root)
local worldFreeze=dofile(here..'world_freeze.lua')
local droneCollision=dofile(here..'drone_collision.lua')
local npcAnchor=dofile(here..'npc_anchor.lua')
local godMode=dofile(here..'god_mode.lua')
local godState={}
local analog=dofile(here..'analog.lua')
cfg.analog_enabled=analog.load(root)
cfg.analog_style=analog.load_style(root)
cfg.analog_enabled=cfg.analog_style>0
local pilotSettings=dofile(here..'pilot_settings.lua')
local pilot=pilotSettings.load(root)
cfg.flight_mode=pilot.mode
local flightSettings=dofile(here..'flight_settings.lua')
flightSettings.load(root,cfg)
flight.validate(cfg)
local helpers=require('UEHelpers')
local calibration,calibrationDevice
local function loadCalibration()
    calibration=nil
    local path=root..(calibrationDevice and ('calibration-'..calibrationDevice..'.lua') or 'calibration.lua')
    local file=io.open(path,'r')
    if not file then
        calibration=nil
        if calibrationDevice and calibrationDevice>=100 and calibrationDevice<=103 then
            calibration={};for i,name in ipairs({'roll','pitch','throttle','yaw'}) do calibration[name]={axis=i,min=0,max=65535,center=32768,invert=false} end
            return true
        end
        return false
    end
    file:close()
    local ok,value=pcall(dofile,path)
    if not ok or type(value)~='table' then return false end
    local used={}
    for _,name in ipairs({'roll','pitch','yaw','throttle'}) do
        local a=value[name]
        if type(a)~='table' then return false end
        for _,key in ipairs({'axis','min','max','center'}) do
            local v=a[key];if type(v)~='number' or v~=v or v==math.huge or v==-math.huge then return false end
        end
        if a.axis%1~=0 or a.axis<1 or a.axis>8 or used[a.axis] or type(a.invert)~='boolean' or
            a.min<0 or a.max>65535 or a.max-a.min<1000 or a.center<=a.min or a.center>=a.max then return false end
        used[a.axis]=true
    end
    calibration=value;return true
end
loadCalibration()
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function log(s) print('[ZoneFPV] '..s..'\n') end
do
    local ok,detail=dofile(here..'bridge.lua').start(root)
    log(ok and 'Input bridge ready (automatic start).' or ('Input bridge auto-start failed: '..tostring(detail)))
end
local environment=dofile(here..'environment.lua').new(root,function(command)
    local mode=command:match('^FPVMode (%w+)$')
    if mode then
        if not pilotSettings.save(root,'pilot-mode',mode) then return false end
        cfg.flight_mode=mode;return true
    end
    local a,b,c=command:match('^FPVBindings (%d+) (%d+) (%d+)$')
    if a then
        a,b,c=tonumber(a),tonumber(b),tonumber(c)
        if not pilotSettings.valid_keys(a,b,c) then return false end
        if not pilotSettings.save(root,'bindings',string.format('%d %d %d',a,b,c)) then return false end
        pilot.keys={a,b,c};return true
    end
    local style=command:match('^FPVStyle ([0-4])$')
    if style then style=tonumber(style);if not analog.save_style(root,style) then return false end;cfg.analog_style=style;cfg.analog_enabled=style>0;return true end
    if command=='FPVCalibrationReload'  then return loadCalibration() end
    local option,value=command:match('^FPVOption (%a+) ([01])$')
    if option then return worldOptions.save(root,options,option,value=='1') end
    local analogValue=command:match('^FPVAnalog ([01])$')
    if analogValue then
        local enabled=analogValue=='1'
        if not analog.save(root,enabled) then return false end
        cfg.analog_enabled=enabled
        return true
    end
    local values=command:match('^FPVSettings (.+)$')
    if values then
        local speed,tilt=flightSettings.parse(values)
        return speed and flightSettings.save(root,cfg,speed,tilt) or false
    end
    local controller=helpers.GetPlayerController()
    if not valid(controller) or not valid(controller.Pawn) then return false end
    local library=helpers.GetKismetSystemLibrary()
    if not valid(library) then return false end
    library:ExecuteConsoleCommand(controller,command,controller)
    return true
end,log)
local function vec(v) return {X=v.x*100,Y=v.y*100,Z=v.z*100} end
local function meters(v) return {x=v.X/100,y=v.Y/100,z=v.Z/100} end
local session,pc,gameplay,system,cameraClass
local pending=false
local pendingSince,watchdogReported,stage=0,false,'idle'
local cameraUpdates,cameraTime,cameraGap=0,0,0
local request,resetRequested=false,false
local lastPacket,lastChange,lastButton,lastToggle=nil,0,false,-10
local nextGodUpdate
local clock=os.clock
local function packet()
    local file=io.open(root..'input.txt','r')
    local p
    if file then p=input.parse(file:read(512));file:close() end
    -- Atomic replacement can briefly deny opening the file on Windows.
    -- Keep the previous sample only within the existing 250 ms freshness limit.
    p=p or lastPacket
    if not p then return nil end
    if p.device~=calibrationDevice then
        calibrationDevice=p.device;loadCalibration()
        -- Force a clean exit before a different device can control an active flight.
        return nil
    end
    if p.device and not calibration then loadCalibration();if not calibration then return nil end end
    if not lastPacket or p.seq~=lastPacket.seq then lastChange=clock() end
    lastPacket=p
    -- Epoch guard rejects an old file on initial launch; sequence guard is sub-second.
    if math.abs(os.time()-p.time/1000)>2 or clock()-lastChange>0.25 then return nil end
    if not p.connected or not p.focused then return nil end
    return p
end
local function exit(reason)
    local s=session
    if not s then return end
    session=nil
    pcall(publishTelemetry,clock(),nil)
    -- Restore in independent protected calls, so a failed camera call cannot strand input.
    local function restore(label,fn)
        local ok,err=pcall(fn);if not ok then log('Restore '..label..': '..tostring(err)) end
    end
    if (s.freezeOwned or s.freezePrepared) and valid(s.pc) then
        if not same(s.pc:GetWorld(),s.world) then s.freezeOwned=false end
        restore('world time',function() worldFreeze.set(s,false,gameplay) end)
    end
    if s.npcAnchor and valid(s.pawn) then
        restore('NPC anchor',function() npcAnchor.restore(s) end)
    end
    restore('camera effects',function() visualGuard.restore(s) end)
    restore('player equipment',function() playerVisibility.restore(s) end)
    if s.movementFrozen and valid(s.movement) then
        restore('movement mode',function()
            s.movement:StopMovementImmediately()
            s.movement:SetMovementMode(s.previousMovementMode,s.previousCustomMode)
        end)
        restore('movement tick',function() s.movement:SetComponentTickEnabled(s.previousMovementTick) end)
    end
    if valid(s.pc) then
        restore('view',function()
            if not same(s.pc.Pawn,s.pawn) or not same(s.pc:GetWorld(),s.world) then return end
            if valid(s.previousView) then s.pc:SetViewTargetWithBlend(s.previousView,0,0,0,false)
            elseif valid(s.pawn) then s.pc:SetViewTargetWithBlend(s.pawn,0,0,0,false) end
        end)
        if s.moveLocked then restore('movement',function() s.pc:SetIgnoreMoveInput(false) end) end
        if s.lookLocked then restore('look',function() s.pc:SetIgnoreLookInput(false) end) end
        if s.pawnDisabled and valid(s.pawn) then restore('pawn input',function() s.pawn:EnableInput(s.pc) end) end
        if valid(s.hud) then restore('HUD',function() s.hud.bShowHUD=s.hudVisible end) end
        if s.widgetsHidden then restore('HUD widgets',function() system:ExecuteConsoleCommand(s.pc,'XShowAllWidget',s.pc) end) end
    end
    if valid(s.camera) then restore('camera destroy',function() s.camera:K2_DestroyActor() end) end
    lastToggle=clock()
    log('Character mode: '..reason)
end
local function enter(p)
    if clock()-lastToggle<0.6 then return end
    pc=helpers.GetPlayerController()
    if not valid(pc) or not valid(pc.Pawn) then log('Load a save first.');return end
    gameplay=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    system=helpers.GetKismetSystemLibrary()
    if not valid(gameplay) or not valid(system) then error('Engine libraries unavailable') end
    if gameplay:IsGamePaused(pc) or pc:IsMoveInputIgnored() or pc:IsLookInputIgnored() then
        log('Close menus / wait for cutscene.');return
    end
    local u=input.controls(p,cfg,calibration)
    local neutral=cfg.flight_mode=='3d' and math.abs(u.throttle-0.5)<=0.04 or cfg.flight_mode~='3d' and u.throttle<=0.08
    if not neutral and not options.hotstart then log(cfg.flight_mode=='3d' and '3D: center throttle before entering FPV.' or 'Lower throttle before entering FPV.');return end
    local cm=pc.PlayerCameraManager
    if not valid(cm) then error('PlayerCameraManager missing') end
    local position=meters(cm:GetCameraLocation())
    local rotation=cm:GetCameraRotation()
    if not valid(cameraClass) then cameraClass=StaticFindObject('/Script/Engine.CameraActor') end
    if not valid(cameraClass) then error('CameraActor class missing') end
    local s={mode=cfg.flight_mode,pc=pc,pawn=pc.Pawn,previousView=pc:GetViewTarget(),origin=position,
        world=pc:GetWorld(),lastWorldTime=gameplay:GetTimeSeconds(pc),lastRealTime=clock()}
    session=s -- enables rollback if any subsequent call fails
    local halfYaw=math.rad(rotation.Yaw)*0.5
    local transform={Translation=vec(position),Rotation={X=0,Y=0,Z=math.sin(halfYaw),W=math.cos(halfYaw)},Scale3D={X=1,Y=1,Z=1}}
    s.camera=gameplay:BeginDeferredActorSpawnFromClass(s.pawn,cameraClass,transform,1,s.pawn,0)
    if not valid(s.camera) then error('CameraActor spawn failed') end
    gameplay:FinishSpawningActor(s.camera,transform,0)
    s.camera.CameraComponent:SetFieldOfView(cfg.fov)
    s.camera.CameraComponent.bConstrainAspectRatio=false
    s.camera:SetActorEnableCollision(false)
    s.flight=flight.new(position,rotation.Yaw)
    s.startYaw=rotation.Yaw
    s.hud=pc:GetHUD()
    if valid(s.hud) then s.hudVisible=s.hud.bShowHUD;s.hud.bShowHUD=false end
    s.widgetsHidden=true
    system:ExecuteConsoleCommand(pc,'XHideAllWidget',pc)
    s.nextHudHide=clock()+0.1
    pc:SetIgnoreMoveInput(true);s.moveLocked=true
    pc:SetIgnoreLookInput(true);s.lookLocked=true
    s.pawn:DisableInput(pc);s.pawnDisabled=true
    s.movement=s.pawn.CharacterMovement
    if not valid(s.movement) then error('CharacterMovement missing; cannot hold character during FPV') end
    s.previousMovementMode=s.movement.MovementMode
    s.previousCustomMode=s.movement.CustomMovementMode
    s.previousMovementTick=s.movement:IsComponentTickEnabled()
    s.movementFrozen=true -- rollback also covers a partially completed freeze
    s.movement:StopMovementImmediately()
    s.movement:DisableMovement()
    s.movement:SetComponentTickEnabled(false)
    pc:SetViewTargetWithBlend(s.camera,0,0,0,false)
    lastToggle=clock()
    log('FPV active. F8 return; F9 reset. Controller calibration '..(calibration and 'loaded' or 'DEFAULT AETR'))
end
local function collide(s,old)
    if not cfg.collision then return end
    local yes,hit=droneCollision.trace(system,session,vec(old),vec(s.p),cfg.radius*100,false)
    if yes then
        local n={x=hit.Normal.X,y=hit.Normal.Y,z=hit.Normal.Z}
        local p=meters(hit.Location)
        if hit.bStartPenetrating and hit.PenetrationDepth and hit.PenetrationDepth>0 then
            for _,k in ipairs({'x','y','z'}) do p[k]=old[k]+n[k]*hit.PenetrationDepth/100 end
        end
        for _,k in ipairs({'x','y','z'}) do p[k]=p[k]+n[k]*0.002 end
        flight.collide(s,p,n,cfg.restitution,cfg.surface_friction,cfg.speed_preset)
    end
end
local function update()
    stage='menu and god mode'
    local tickNow=clock()
    environment(tickNow)
    -- Console commands and controller discovery are comparatively expensive.
    -- Poll slowly and godMode applies only on an actual option/pawn change.
    if not nextGodUpdate or tickNow>=nextGodUpdate then
        local activeController=helpers.GetPlayerController()
        local activePawn=valid(activeController) and activeController.Pawn or nil
        godMode.update(godState,activePawn,options.god,activeController,helpers.GetKismetSystemLibrary())
        nextGodUpdate=tickNow+0.25
    end
    local p=packet()
    if p and cfg.toggle_button>0 then
        local down=(p.buttons & (1 << (cfg.toggle_button-1)))~=0
        if down and not lastButton then request=true end
        lastButton=down
    elseif not p then lastButton=false end
    if request then
        request=false
        if session then exit('toggle') elseif p then enter(p) else log('Start input bridge / focus game / check USB.') end
    end
    if not session then return end
    local s=session
    if s.mode~=cfg.flight_mode then exit('flight mode changed; re-enter FPV');return end
    if not p then exit('controller disconnected, stale input or focus lost');return end
    if not valid(s.pc) or not valid(s.pawn) or not valid(s.camera) or not valid(s.world) then
        exit('world changed');return
    end
    if not same(s.pc.Pawn,s.pawn) or not same(s.pc:GetWorld(),s.world) then exit('pawn/world changed');return end
    if gameplay:IsGamePaused(s.pc) and not s.freezeOwned and not p.menu then exit('pause/menu');return end
    local wasFrozen=s.freezeOwned
    worldFreeze.set(s,options.freeze,gameplay)
    if valid(s.hud) then s.hud.bShowHUD=false end
    if clock()>=s.nextHudHide then
        stage='hide HUD'
        system:ExecuteConsoleCommand(s.pc,'XHideAllWidget',s.pc)
        s.nextHudHide=clock()+0.1
    end
    if not valid(s.movement) then exit('character movement unavailable');return end
    -- Game scripts may request falling even though player input is disabled.
    if s.movement.MovementMode~=0 then
        if not s.movementOverrideLogged then
            log('Holding character: game changed movement mode to '..tostring(s.movement.MovementMode))
            s.movementOverrideLogged=true
        end
        s.movement:StopMovementImmediately()
        s.movement:DisableMovement()
    end
    if s.movement:IsComponentTickEnabled() then s.movement:SetComponentTickEnabled(false) end
    local now=gameplay:GetTimeSeconds(s.pc)
    local realNow=clock()
    local dt=(s.freezeOwned or wasFrozen) and (realNow-s.lastRealTime) or (now-s.lastWorldTime)
    s.lastWorldTime=now;s.lastRealTime=realNow
    if dt==0 and not p.menu then return end
    if dt<0 then exit('world time reset');return end
    if dt>1 and not p.menu then exit('frame stall over one second');return end
    if dt>0 and not p.menu then cameraUpdates=cameraUpdates+1;cameraTime=cameraTime+dt;cameraGap=math.max(cameraGap,dt) end
    if dt>0.1 and not p.menu and (not s.nextStallLog or clock()>=s.nextStallLog) then
        log(string.format('Long frame %.3fs; speed=%gx; Acro rotation catches up',dt,cfg.speed_preset))
        s.nextStallLog=clock()+10
    end
    if resetRequested then
        resetRequested=false
        s.flight=flight.new(s.origin,s.startYaw)
    end
    local u=input.controls(p,cfg,calibration)
    s.throttle=cfg.flight_mode=='3d' and (u.throttle*2-1) or u.throttle
    if dt>0 and not p.menu then s.flightSeconds=(s.flightSeconds or 0)+math.min(dt,1) end
    stage='physics and collision traces'
    if dt>0 and not p.menu then flight.advance(s.flight,u,cfg,dt,collide) end
    if not p.menu and (not s.nextFlightLog or clock()>=s.nextFlightLog) then
        log(string.format('Flight speed=%gx yaw_input=%.3f yaw_rate=%.1fdeg/s dt=%.3fs',
            cfg.speed_preset,u.yaw,math.deg(s.flight.omega.z),dt))
        s.nextFlightLog=clock()+5
    end
    local pos=s.flight.p
    if cfg.max_distance>0 and (pos.x-s.origin.x)^2+(pos.y-s.origin.y)^2+(pos.z-s.origin.z)^2>cfg.max_distance^2 then
        exit('configured distance limit reached');return
    end
    local hit={}
    if s.analogApplied~=cfg.analog_enabled or s.analogStyleApplied~=cfg.analog_style then
        local ok,err=pcall(analog.apply,s.camera.CameraComponent,cfg.analog_enabled,cfg.analog_style)
        s.analogApplied=cfg.analog_enabled;s.analogStyleApplied=cfg.analog_style
        log(ok and ('Analog camera: '..(cfg.analog_enabled and 'on' or 'off')) or ('Analog effect unavailable: '..tostring(err)))
    end
    stage='camera transform'
    s.camera:K2_SetActorLocationAndRotation(vec(pos),flight.camera_rotation(s.flight,cfg.camera_tilt),false,hit,true)
    stage='camera effects'
    visualGuard.update(s,realNow,system)
    publishTelemetry(realNow,s)
    if not s.nextVisibilityUpdate or realNow>=s.nextVisibilityUpdate then
        stage='equipment visibility'
        playerVisibility.update(s,realNow)
        s.nextVisibilityUpdate=realNow+0.1
    end
    if (s.npcAnchor~=nil)~=options.npcs or not s.nextAnchorUpdate or clock()>=s.nextAnchorUpdate then
        stage='player streaming anchor'
        npcAnchor.update(s,options.npcs,vec(pos))
        s.nextAnchorUpdate=clock()+0.25
    end
end
for _,vk in ipairs(pilotSettings.keys) do
    local code=vk
    RegisterKeyBind(code,function()
        if code==pilot.keys[2] then request=true elseif code==pilot.keys[3] then resetRequested=true end
    end)
end
-- At most one queued game-thread callback. Never access Unreal objects on the worker.
local nextIdleUpdate=0
local perfNext,perfTotal,perfMax,perfCount=0,0,0,0
-- EngineTickAvailable reports symbol availability, not a successfully installed hook.
-- This game's compatibility configuration disables EngineTick; always use the
-- verified ProcessEvent path. Never select a scheduler merely by symbol presence.
local function dispatch(callback)
    if EGameThreadMethod and EGameThreadMethod.ProcessEvent then
        ExecuteInGameThread(callback,EGameThreadMethod.ProcessEvent)
    else ExecuteInGameThread(callback) end
end
local function pump()
    if pending then
        if not watchdogReported and clock()-pendingSince>3 then
            watchdogReported=true
            pcall(function()
                local f=io.open(root..'stall-diagnostic.txt','w')
                if f then f:write(os.date()..' stage='..stage..' pending_seconds='..tostring(clock()-pendingSince)..'\n');f:close() end
            end)
        end
        return false
    end
    if not session and not request then
        local now=clock();if now<nextIdleUpdate then return false end;nextIdleUpdate=now+0.05
    end
    pending=true
    pendingSince=clock();watchdogReported=false;stage='waiting for game thread'
    dispatch(function()
        local started=clock()
        local ok,err=xpcall(function()
            update()
            stage='audio publication'
            publishAudio(clock(),session~=nil,session and session.flight and session.flight.thrust or 0,cfg.gravity*cfg.thrust_to_weight)
        end,debug.traceback)
        if not ok then
            log(tostring(err))
            local restored,restoreError=pcall(exit,'error; see UE4SS.log')
            if not restored then log('Emergency restore: '..tostring(restoreError)) end
        end
        local elapsed=(clock()-started)*1000
        perfTotal=perfTotal+elapsed;perfMax=math.max(perfMax,elapsed);perfCount=perfCount+1
        if clock()>=perfNext then
            perfNext=clock()+10
            pcall(function()
                local f=io.open(root..'performance.txt','w')
                if f then f:write(string.format('mode=%s callbacks=%d callback_avg_ms=%.3f callback_max_ms=%.3f camera_hz=%.1f camera_max_gap_ms=%.1f\n',
                    session and 'fpv' or 'character',perfCount,perfTotal/perfCount,perfMax,cameraTime>0 and cameraUpdates/cameraTime or 0,cameraGap*1000));f:close() end
            end)
            perfTotal,perfMax,perfCount=0,0,0
            cameraUpdates,cameraTime,cameraGap=0,0,0
        end
        pending=false
        stage='idle'
    end)
    return false
end
LoopAsync(1,pump)
log('Camera scheduler: ProcessEvent / 1 ms bounded queue')
log('Loaded. F8 toggles FPV. Input bridge required; physics 240 Hz.')
