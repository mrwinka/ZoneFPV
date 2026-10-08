local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
assert(here,'ZoneFPV requires an on-disk script path')
local root=here..'../'
local flight=dofile(here..'flight.lua')
local input=dofile(here..'input.lua')
local inputReader=dofile(here..'input_reader.lua')
local focusGuard=dofile(here..'focus_guard.lua')
local focusState={}
local inputStall=dofile(here..'input_stall_guard.lua').new()
local publishAudio=dofile(here..'audio.lua').new(root)
local cfg=dofile(here..'config.lua')
local radioLink=dofile(here..'radio_link.lua')
local radioSettings=radioLink.load(root)
local experimentsSettings=dofile(here..'experiments_settings.lua')
local experiments=experimentsSettings.load(root)
local artifactSettings=dofile(here..'artifact_settings.lua')
experiments.collectRange=artifactSettings.load(root)
local visionSettings=dofile(here..'vision_settings.lua')
local visionMode=visionSettings.load(root)
local actionModeSettings=dofile(here..'action_modes.lua')
local actionModes=actionModeSettings.load(root)
local vision=dofile(here..'vision.lua')
local session,pilot
local heldActions=dofile(here..'held_actions.lua').new()
local pilotHoldPending=false
local function holdMode(name,index)return actionModes[name]==1 and pilot and pilot.keys[index]~=0 end
local function activeVisionMode(s)
    if s and s.visionEnabled==false or not s and holdMode('vision',8)then return 0 end
    return visionMode
end
local observationOptions
local function refreshObservationOptions()
    observationOptions={}
    for key,value in pairs(experiments)do observationOptions[key]=value end
    observationOptions.visionTargets=vision.needsTargets(activeVisionMode(session))
end
refreshObservationOptions()
local impactSettings=dofile(here..'impact_settings.lua')
local impactMultiplier=impactSettings.load(root)
local radioObstacles=dofile(here..'radio_obstacles.lua')
local droneCombat=dofile(here..'drone_combat.lua')
local worldExperiments=dofile(here..'world_experiments.lua')
local experimentalWorld
local publishScan
local binoculars=dofile(here..'binoculars.lua')
local telemetry=dofile(here..'telemetry.lua')
local publishTelemetry=telemetry.new(root,flight,cfg)
local visualGuard=dofile(here..'visual_guard.lua')
local environmentGuard=dofile(here..'environment_guard.lua')
local playerVisibility=dofile(here..'player_visibility.lua')
local fpvParticles=dofile(here..'fpv_particles.lua')
fpvParticles.worldLeaves=dofile(here..'leaf_world_visibility.lua')
local playerGuard=dofile(here..'player_guard.lua')
local aiGuard=dofile(here..'ai_guard.lua')
local playerUI=dofile(here..'player_ui.lua')
local regionalFog=dofile(here..'regional_fog.lua')
local worldOptions=dofile(here..'world_options.lua')
local options=worldOptions.load(root)
local anomalyNoise=dofile(here..'anomaly_noise.lua')
local anomalyStyle=anomalyNoise.load(root)
local teleportGuard=dofile(here..'teleport_guard.lua')
local worldDistance=dofile(here..'world_distance.lua')
local distanceSelection=worldDistance.load(root)
local worldFreeze=dofile(here..'world_freeze.lua')
local droneCollision=dofile(here..'drone_collision.lua')
local npcAnchor=dofile(here..'npc_anchor.lua')
local godMode=dofile(here..'god_mode.lua')
local godState={}
local analog=dofile(here..'analog.lua')
local droneFlashlight=dofile(here..'drone_flashlight.lua')
local featureSettings=dofile(here..'feature_settings.lua')
local features=featureSettings.load(root)
local weaponSettings=dofile(here..'weapon_settings.lua')
local armament=weaponSettings.load(root)
local droneWeapons=dofile(here..'drone_weapons.lua')
cfg.analog_enabled=analog.load(root)
cfg.analog_style=analog.load_style(root)
cfg.analog_enabled=cfg.analog_style>0
local pilotSettings=dofile(here..'pilot_settings.lua')
pilot=pilotSettings.load(root)
refreshObservationOptions()
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
local function valid(o)
    local ok,value=pcall(function() return o and o:IsValid() end)
    return ok and value
end
local function same(a,b)
    if not valid(a) or not valid(b) then return false end
    local ok,value=pcall(function() return a:GetAddress()==b:GetAddress() end)
    return ok and value
end
local function log(s) print('[ZoneFPV] '..s..'\n') end
-- Arm independently of FPV. The game-thread check also handles managers whose
-- normal Init ran before this Lua mod finished loading.
local achievementsReady,achievementsRecovery=dofile(here..'achievements.lua').start(root,log)
local resourceGuard=dofile(here..'resource_guard.lua').new(root,log)
publishScan=dofile(here..'scan_overlay.lua').new(root,flight,cfg,log)
do
    local ok,detail=dofile(here..'bridge.lua').start(root)
    log(ok and 'Input bridge ready (automatic start).' or ('Input bridge auto-start failed: '..tostring(detail)))
end
local pc,gameplay,system,cameraClass
local exit
local selectedWeather
local selectedHour
local legacyActions={}
local function setCameraDown(value)
    if not session then return false,'fpv_required' end
    if not features.cameraDownEnabled and value~='0'then return false,'feature_disabled'end
    session.cameraDown=value=='toggle' and not session.cameraDown or value=='1'
    session.cameraDirty=true
    return true
end
local function setFeature(key,enabled)
    local saved,value,reason=featureSettings.save(root,features,key,enabled)
    if not saved then return false,reason end
    features=value
    if session and not enabled then
        if key=='cameraDownEnabled'then setCameraDown('0')
        elseif session.flashlightEnabled then droneFlashlight.set(session,false,gameplay,log)end
    end
    return true
end
local function setVisionEnabled(value)
    if not session then return false,'fpv_required' end
    session.visionEnabled=value=='toggle' and session.visionEnabled==false or value=='1'
    session.cameraDirty=true
    refreshObservationOptions()
    return true
end
local function releaseHeldActions()
    if not session then return end
    if holdMode('cameraDown',6)then setCameraDown('0')end
    if holdMode('vision',8)then setVisionEnabled('0')end
    if holdMode('flashlight',5)and session.flashlightEnabled then droneFlashlight.set(session,false,gameplay,log)end
end
local function updateHeldActions(held)
    if not session then return end
    if holdMode('cameraDown',6)then
        local enabled=features.cameraDownEnabled and held.cameraDown
        if session.cameraDown~=enabled then setCameraDown(enabled and '1' or '0')end
    end
    if holdMode('vision',8)then
        if session.visionEnabled~=held.vision then setVisionEnabled(held.vision and '1' or '0')end
    end
    if holdMode('flashlight',5)then
        local enabled=features.flashlightEnabled and held.flashlight
        if (session.flashlightEnabled==true)~=enabled then droneFlashlight.set(session,enabled,gameplay,log)end
    end
end
local function dropGrenade()
    if not session or not session.flight then return false,'fpv_required' end
    if session.radio and session.radio.lost then return false,'signal_lost' end
    return droneWeapons.drop(session,gameplay,log)
end
local function executeCommand(command)
    -- Helper notifications read the latest committed file. Replaying queued
    -- snapshots here could overwrite a newer change made inside the PDA.
    if command=='FPVBindingsReload' then
        local file=io.open(root..'bindings.txt','r');if not file then return false end
        local text=file:read(129);file:close()
        local keys=pilotSettings.parse(text);if not keys then return false end
        local changed=false;for i=1,8 do if pilot.keys[i]~=keys[i]then changed=true end end
        if not changed then return true end
        releaseHeldActions();pilot.keys=keys;legacyActions={}
        if session and keys[8]==0 then setVisionEnabled('1')end
        refreshObservationOptions();return true
    end
    if command=='FPVActionModesReload' then
        local file=io.open(root..'action-modes.txt','r');if not file then return false end
        local text=file:read(81);file:close()
        local value=actionModeSettings.parse(text);if not value then return false end
        local changed=false;for _,name in ipairs(actionModeSettings.names)do if actionModes[name]~=value[name]then changed=true end end
        if not changed then return true end
        local visionChanged=actionModes.vision~=value.vision
        releaseHeldActions();actionModes=value
        if session and visionChanged then setVisionEnabled(holdMode('vision',8)and '0' or '1')end
        return true
    end
    local weaponValues=command:match('^FPVArmament (.+)$')
    if weaponValues then
        local saved,value=weaponSettings.save(root,weaponValues)
        if not saved then return false end
        local changed=false
        for _,key in ipairs({'mode','power','grenade','charges'})do
            if armament[key]~=value[key]then changed=true end
        end
        armament=value
        if session and session.weapons then session.weapons.impactSpeed=value.impactSpeed end
        if session and changed then exit('armament changed; re-enter FPV')end
        return true
    end
    local cameraDown=command:match('^FPVCameraDown ([01])$')
    if cameraDown then return setFeature('cameraDownEnabled',cameraDown=='1')end
    if command=='FPVCameraDown toggle'then return setCameraDown('toggle')end
    local actionName,actionMode=command:match('^FPVActionMode (%a+) ([01])$')
    if actionName then
        local saved,value=actionModeSettings.save(root,actionModes,actionName,tonumber(actionMode))
        if not saved then return false end
        releaseHeldActions();actionModes=value
        if session and actionName=='vision'then setVisionEnabled(holdMode('vision',8)and '0' or '1')end
        return true
    end
    if command=='FPVVisionEnabled toggle'then return setVisionEnabled('toggle')end
    local visionEnabled=command:match('^FPVVisionEnabled ([01])$')
    if visionEnabled then return setVisionEnabled(visionEnabled)end
    local collectRange=command:match('^FPVCollectRange (.+)$')
    if collectRange then
        local saved,value=artifactSettings.save(root,collectRange)
        if saved then experiments.collectRange=value;refreshObservationOptions()end
        return saved
    end
    local flashlight=command:match('^FPVFlashlight ([01])$')
    if flashlight then return setFeature('flashlightEnabled',flashlight=='1')end
    local signal=command:match('^FPVSignal (.+)$')
    if signal then return radioLink.save(root,radioSettings,signal) end
    local impactValue=command:match('^FPVImpact (.+)$')
    if impactValue then
        local saved,value=impactSettings.save(root,impactValue)
        if saved then impactMultiplier=value end
        return saved
    end
    local experimentValues=command:match('^FPVExperiments (.+)$')
    if experimentValues then
        local oldReaction=experiments.reaction
        if not experimentsSettings.save(root,experiments,experimentValues) then return false end
        refreshObservationOptions()
        if session and oldReaction~=experiments.reaction then exit('experimental reaction changed; re-enter FPV') end
        return true
    end
    if command=='FPVCollectArtifact' then
        if not session or not experimentalWorld then log('Enter FPV with the artifact detector enabled first.');return false,'fpv_required' end
        local ok,message,code=experimentalWorld:collect(session,experiments)
        log('Artifact pickup: '..tostring(message));return ok,code
    end
    if command=='FPVBinoculars' then
        if session then log('Exit FPV before requesting binoculars.');return false end
        return binoculars.give(helpers.GetPlayerController(),helpers.GetKismetSystemLibrary(),log)
    end
    local distance=command:match('^FPVDistance ([0-6])$')
    if distance then
        distance=tonumber(distance)
        if not worldDistance.save(root,distance) then return false end
        distanceSelection=distance;return true
    end
    local mode=command:match('^FPVMode (%w+)$')
    if mode then
        if not pilotSettings.save(root,'pilot-mode',mode) then return false end
        cfg.flight_mode=mode;return true
    end
    local bindingValues=command:match('^FPVBindings (.+)$')
    if bindingValues then
        local keys=pilotSettings.parse(bindingValues)
        if not keys then return false end
        if not pilotSettings.save(root,'bindings',table.concat(keys,' ')) then return false end
        releaseHeldActions();pilot.keys=keys;legacyActions={}
        if session and keys[8]==0 then setVisionEnabled('1')end
        refreshObservationOptions();return true
    end
    local style=command:match('^FPVStyle ([0-4])$')
    if style then style=tonumber(style);if not analog.save_style(root,style) then return false end;cfg.analog_style=style;cfg.analog_enabled=style>0;return true end
    local sensor=command:match('^FPVVision (%d+)$')
    if sensor then
        local saved,value=visionSettings.save(root,sensor)
        if saved then
            visionMode=value
            if session then session.visionEnabled=not holdMode('vision',8)end
            refreshObservationOptions()
        end
        return saved
    end
    local anomaly=command:match('^FPVAnomalyStyle ([0-5])$')
    if anomaly then
        local saved,value=anomalyNoise.save(root,anomaly)
        if saved then anomalyStyle=value end
        return saved
    end
    if command=='FPVCalibrationReload'  then return loadCalibration() end
    local option,value=command:match('^FPVOption (%a+) ([01])$')
    if option then
        local previous=options.noclip
        local saved=worldOptions.save(root,options,option,value=='1')
        if saved and session and previous~=options.noclip then exit('noclip changed; re-enter FPV') end
        return saved
    end
    local analogValue=command:match('^FPVAnalog ([01])$')
    if analogValue then
        local enabled=analogValue=='1'
        local style=enabled and (cfg.analog_style>0 and cfg.analog_style or 1) or 0
        if not analog.save_style(root,style) then return false end
        cfg.analog_style=style;cfg.analog_enabled=enabled
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
    local weather=command:match('^XForceWeather (%w+)$')
    if weather then selectedWeather=weather end
    local hour=command:match('^XSetWeatherTime (%d+) ')
    if hour then selectedHour=tonumber(hour) end
    if weather or command:match('^XSetWeatherTime ') then environmentGuard.changed(session,os.clock()) end
    return true
end
local environment=dofile(here..'environment.lua').new(root,executeCommand,log)
local function vec(v) return {X=v.x*100,Y=v.y*100,Z=v.z*100} end
local function meters(v) return {x=v.X/100,y=v.Y/100,z=v.Z/100} end
local stage='idle'
local cameraUpdates,cameraTime,cameraGap=0,0,0
local request,resetRequested=false,false
local pendingEntry=false
local sensorFrame=0
local lastPacket,lastChange,lastButton,lastToggle=nil,0,false,-10
local legacyButtonPrimed=false
local pdaOpen,pdaAction=false,nil
local readActions=dofile(here..'action_bindings.lua').new(
    function()return inputReader.read(root..'action-input.txt')end,os.clock,os.time)
local actionChannelSeen,lastActionAllowed=false,false
local externalMenu=dofile(here..'external_menu_guard.lua').new(
    function()return inputReader.read(root..'input.txt')end,input.parse,os.clock,os.time)
local navigationKeys=dofile(here..'pda_navigation_keys.lua').new(
    function()return inputReader.read(root..'pda-navigation.txt')end,os.clock,os.time)
local pdaSettings=dofile(here..'pda_settings.lua').new(root)
local pdaOSD=dofile(here..'pda_osd.lua').new(root,{log=log})
local pda=dofile(here..'pda_menu.lua').new{
    root=root,log=log,execute=executeCommand,
    navigationKeys=navigationKeys,
    snapshot=function()return {cfg=cfg,options=options,features=features,experiments=experiments,radio=radioSettings,
        vision=visionMode,visionEnabled=session and session.visionEnabled~=false or not session and not holdMode('vision',8),
        keys=pilot.keys,actionModes=actionModes,impact=impactMultiplier,distance=distanceSelection,collectRange=experiments.collectRange,armament=armament,session=session,packet=lastPacket,
        weather=selectedWeather,hour=selectedHour,anomalyStyle=anomalyStyle,resources=resourceGuard.sample,resourceLevel=resourceGuard.level,
        telemetry=session and session.flight and telemetry.sample(session,cfg,flight) or nil,
        settings=pdaSettings:snapshot(),osd=pdaOSD:snapshot()}end,
    settings={
        request=function(action,args)return pdaSettings:request(action,args)end,
        context=function(open,section,mouseBlocked)return pdaSettings:setContext(open,section,mouseBlocked)end,
    },
    osd={execute=function(action,args)return pdaOSD:execute(action,args)end},
    action=function(action)
        if action~='flight' and action~='reset' then return false end
        pdaAction=action;return true,'Закройте КПК для выполнения.'
    end
}
local pdaController,nextPdaControllerRead
local function updatePDA(now)
    pdaSettings:update(now)
    -- GetPlayerController enumerates the global UObject pool in UE4SS helpers.
    -- A live flight already owns the controller; idle discovery needs only 2Hz.
    if session then pdaController=session.pc
    elseif not nextPdaControllerRead or now>=nextPdaControllerRead then
        nextPdaControllerRead=now+.5;pdaController=helpers.GetPlayerController()
    end
    local controller=pdaController
    pdaOpen=pda:update(now,controller)
    if pdaAction and not pdaOpen then
        if pdaAction=='flight' then request=true else resetRequested=true end
        pdaAction=nil
    end
end
local function combatOptions(s)
    if not s.noclip then return experiments end
    local value={};for k,v in pairs(experiments)do value[k]=v end
    value.reaction=false;return value
end
local lastPacketLine,lastParsedPacket
local nextGodUpdate
local clock=os.clock
fpvParticles.clock=clock
vision.clock=clock
local stageStarted,stageStats
local function markStage(name)
    local now=clock()
    if stageStarted and stageStats then
        local ms=(now-stageStarted)*1000
        local metric=stageStats[stage] or {total=0,max=0,count=0}
        metric.total=metric.total+ms;metric.max=math.max(metric.max,ms);metric.count=metric.count+1
        stageStats[stage]=metric
    end
    stage=name;stageStarted=now
end
local function packet(actionPacket)
    local line=inputReader.read(root..'input.txt')
    local p
    if line then
        if line~=lastPacketLine then lastPacketLine=line;lastParsedPacket=input.parse(line) end
        p=lastParsedPacket
    end
    -- Atomic replacement can briefly deny opening the file on Windows.
    -- Keep the previous sample only within the existing 250 ms freshness limit.
    p=p or lastPacket
    if not p then return nil end
    if p.device~=calibrationDevice then
        inputStall:clear()
        calibrationDevice=p.device;loadCalibration()
        -- Force a clean exit before a different device can control an active flight.
        return nil
    end
    if p.device and not calibration then loadCalibration();if not calibration then return nil end end
    if not lastPacket or p.seq~=lastPacket.seq then lastChange=clock() end
    lastPacket=p
    -- Epoch guard rejects an old file on initial launch; sequence guard is sub-second.
    local now=clock()
    if not p.connected or math.abs(os.time()-p.time/1000)>2 then inputStall:clear();return nil end
    if now-lastChange>0.25 then
        -- The USB snapshot writer may briefly lag while the independent action
        -- writer remains alive. Pause without applying any old stick values.
        return session and inputStall:pause(now,actionPacket and actionPacket.ready)or nil
    end
    local accepted=focusGuard.accept(focusState,p,now)
    inputStall:accept(accepted)
    return accepted
end
exit=function(reason)
    pilotHoldPending=false
    local s=session
    if not s then return end
    -- Teardown may also be triggered by stale input or memory pressure in the
    -- same frame as a story teleport. Preserve its destination on every exit.
    pcall(function()
        if valid(s.pc) and same(s.pc.Pawn,s.pawn) and same(s.pc:GetWorld(),s.world) then
            local destination=teleportGuard.update(s)
            if destination then teleportGuard.handoff(s,destination) end
        end
    end)
    session=nil
    inputStall:clear()
    refreshObservationOptions()
    pcall(publishTelemetry,clock(),nil)
    pcall(publishScan,clock(),nil)
    -- Restore in independent protected calls, so a failed camera call cannot strand input.
    local function restore(label,fn)
        local ok,err=pcall(fn);if not ok then log('Restore '..label..': '..tostring(err)) end
    end
    if s.freezeOwned or s.freezePrepared then
        restore('world time',function()
            -- Restore the world we changed, even if the controller accessor
            -- fails or now points at a different world during teardown.
            if valid(s.world) then worldFreeze.set(s,false,gameplay)
            else s.freezeOwned=false;s.freezePrepared=false end
        end)
    end
    if s.npcAnchor and valid(s.pawn) then
        restore('NPC anchor',function() npcAnchor.restore(s) end)
    end
    restore('drone combat proxy',function() droneCombat.restore(s) end)
    restore('teleport trigger overlaps',function() teleportGuard.restore(s) end)
    restore('sensor vision',function() vision.restore(s) end)
    restore('drone flashlight',function() droneFlashlight.restore(s) end)
    restore('drone armament',function() droneWeapons.clear(s) end)
    restore('player god mode',function()
        godMode.update(godState,s.pawn,options.god,s.pc,system)
        godMode.enforce_damage_flag(godState,s.pawn,options.god)
    end)
    if experimentalWorld then restore('experimental world cache',function() experimentalWorld:finish(s) end) end
    restore('player exposure and audio',function() playerGuard.restore(s) end)
    restore('world distance',function() worldDistance.restore(s,log) end)
    restore('camera effects and concussion recovery',function() visualGuard.beginRecovery(s,clock()) end)
    restore('regional fog',function() regionalFog.restore(s) end)
    restore('FPV weather particles',function() fpvParticles.restore(s) end)
    restore('player equipment',function() playerVisibility.restore(s) end)
    restore('player AI detection',function() aiGuard.restore(s,log) end)
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
    end
    if valid(s.hud) then restore('HUD',function() s.hud.bShowHUD=s.hudVisible end) end
    if valid(s.camera) then restore('camera destroy',function() s.camera:K2_DestroyActor() end) end
    -- Native view/input changes can rebuild the HUD. Restore its session-local
    -- widget state only after returning to the character and removing the camera.
    restore('player UI',function() playerUI.restore(s,gameplay) end)
    lastToggle=clock()
    pilotHoldPending=false
    log('Character mode: '..reason)
end
-- Palette work happens on the existing game-thread callback before entry.
-- UCameraManager owns the native player component when it is not on the Pawn.
local warmController,warmWorld,warmPawn,warmPlayerManager,warmOwner,warmManager,nextWarmLookup
local warmFrame,warmFrameMode,warmFrameController,warmResult,warmDetail
local function warmVision(controller)
    if warmFrame==sensorFrame and warmFrameMode==visionMode and same(warmFrameController,controller)then
        return warmResult,warmDetail
    end
    local function field(object,key)
        local ok,value=pcall(function()return object[key]end);if ok then return value end
    end
    local world
    if valid(controller)then local ok,value=pcall(function()return controller:GetWorld()end);if ok then world=value end end
    local pawn=field(controller,'Pawn')
    local playerManager=field(controller,'PlayerCameraManager')
    if not same(warmController,controller) or not same(warmWorld,world)
        or not same(warmPawn,pawn) or not same(warmPlayerManager,playerManager)then
        warmController,warmWorld,warmPawn,warmPlayerManager=controller,world,pawn,playerManager
        warmOwner,warmManager,nextWarmLookup=nil,nil,nil
        vision.clearPrewarm()
    end
    warmFrame,warmFrameMode,warmFrameController=sensorFrame,visionMode,controller
    if visionMode==0 or visionMode==9 then
        vision.clearPrewarm();warmResult,warmDetail=true,'ready';return warmResult,warmDetail
    end
    if not valid(world)then vision.clearPrewarm();warmResult,warmDetail=nil,'player world unavailable';return warmResult,warmDetail end
    if warmManager and (not same(field(warmManager,'PlayerCameraManager'),playerManager)
        or not same(field(warmManager,'CameraComponent'),warmOwner))then
        warmOwner,warmManager,nextWarmLookup=nil,nil,nil;vision.clearPrewarm()
    end
    if not valid(warmOwner)then
        warmOwner=field(pawn,'CameraComponent')
        if not valid(warmOwner)then warmOwner=field(playerManager,'CameraComponent')end
        if not valid(warmOwner) and (not nextWarmLookup or clock()>=nextWarmLookup)then
            nextWarmLookup=clock()+2
            local ok,managers=pcall(function()return FindAllOf('CameraManager')end)
            if ok and type(managers)=='table'then
                for i=1,math.min(#managers,8)do
                    if valid(managers[i]) and same(field(managers[i],'PlayerCameraManager'),playerManager)then
                        local component=field(managers[i],'CameraComponent')
                        if valid(component)then warmOwner,warmManager=component,managers[i];break end
                    end
                end
            end
        end
    end
    local ok,result,detail=pcall(vision.prewarm,{world=world,camera=warmOwner},visionMode,log)
    warmResult,warmDetail=ok and result or nil,ok and detail or tostring(result)
    -- Preserve false/pending: Lua's 'and/or' idiom converts it to nil.
    if ok then warmResult=result end
    return warmResult,warmDetail
end
local function applyCameraEffects(s)
    local sensor=activeVisionMode(s)
    if s.analogApplied~=cfg.analog_enabled or s.analogStyleApplied~=cfg.analog_style or s.visionApplied~=sensor then
        if s.analogApplied~=cfg.analog_enabled or s.analogStyleApplied~=cfg.analog_style then
            vision.restore(s)
            s.analogState=s.analogState or {}
            local ok,err=pcall(analog.apply,s.camera.CameraComponent,cfg.analog_enabled,cfg.analog_style,s.analogState)
            s.analogApplied=cfg.analog_enabled;s.analogStyleApplied=cfg.analog_style
            log(ok and ('Analog camera: '..(cfg.analog_enabled and 'on' or 'off')) or ('Analog effect unavailable: '..tostring(err)))
        end
        local sensorOK,sensorError=vision.apply(s,sensor,log)
        s.visionApplied=sensor
        log(sensorOK and ('Vision mode: '..sensor) or ('Vision unavailable: '..tostring(sensorError)))
    end
end
local function enter(p)
    local waiting=pendingEntry;pendingEntry=false
    if clock()-lastToggle<0.6 then
        -- A fresh held press owns this wait and can cancel it on release. Other
        -- failures (throttle/cutscene/loadout) still require a new press.
        if pilotHoldPending then pendingEntry=true end
        return
    end
    if pdaOpen then log('Close the PDA before starting FPV.');return end
    if resourceGuard.level>=2 then log('FPV unavailable: '..(resourceGuard.reason or 'critical resource pressure')..'.');return end
    pc=waiting and pdaController or helpers.GetPlayerController()
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
    local ready,why=warmVision(pc)
    if ready==false then
        if not waiting then log('Vision: completing selected palette before opening FPV')end
        pendingEntry=true;return
    end
    pendingEntry=false
    if ready==nil then log('Vision prewarm unavailable: '..tostring(why)..'; normal activation retained')end
    local cm=pc.PlayerCameraManager
    if not valid(cm) then error('PlayerCameraManager missing') end
    -- A new flight inherits the game's current weather. Only a weather command
    -- sent during this flight may request extra Clear fog suppression.
    selectedWeather=nil
    local position=meters(cm:GetCameraLocation())
    local rotation=cm:GetCameraRotation()
    if not valid(cameraClass) then cameraClass=StaticFindObject('/Script/Engine.CameraActor') end
    if not valid(cameraClass) then error('CameraActor class missing') end
    local s={mode=cfg.flight_mode,noclip=options.noclip and not weaponSettings.hasKamikaze(armament.mode),weaponMode=armament.mode,cameraDown=false,visionEnabled=not holdMode('vision',8),pilotHoldOwned=pilotHoldPending,pc=pc,pawn=pc.Pawn,previousView=pc:GetViewTarget(),origin=position,
        world=pc:GetWorld(),lastWorldTime=gameplay:GetTimeSeconds(pc),lastRealTime=clock()}
    session=s -- enables rollback if any subsequent call fails
    refreshObservationOptions()
    teleportGuard.start(s)
    local effectiveCombat=combatOptions(s)
    if not effectiveCombat.reaction then aiGuard.start(s,system,log) end
    playerGuard.update(s)
    playerUI.update(s,clock(),gameplay,p.menu)
    local halfYaw=math.rad(rotation.Yaw)*0.5
    local transform={Translation=vec(position),Rotation={X=0,Y=0,Z=math.sin(halfYaw),W=math.cos(halfYaw)},Scale3D={X=1,Y=1,Z=1}}
    s.camera=gameplay:BeginDeferredActorSpawnFromClass(s.pawn,cameraClass,transform,1,s.pawn,0)
    if not valid(s.camera) then error('CameraActor spawn failed') end
    gameplay:FinishSpawningActor(s.camera,transform,0)
    s.camera.CameraComponent:SetFieldOfView(cfg.fov)
    s.camera.CameraComponent.bConstrainAspectRatio=false
    s.camera:SetActorEnableCollision(false)
    s.flight=flight.new(position,rotation.Yaw)
    local payload=droneWeapons.start(s,armament,gameplay,log)
    if payload.failure then
        log('Drone armament unavailable: '..tostring(payload.failure))
        exit('armament preparation failed');return
    end
    playerVisibility.update(s,clock())
    droneCombat.start(s,effectiveCombat,system,log)
    playerGuard.suppress(s)
    if effectiveCombat.reaction and not s.combat.reactionReady then aiGuard.start(s,system,log) end
    experimentalWorld=worldExperiments.new(system,log)
    experimentalWorld:begin(s,observationOptions)
    fpvParticles.update(s,clock(),root,log)
    s.startYaw=rotation.Yaw
    s.hud=pc:GetHUD()
    if valid(s.hud) then s.hudVisible=s.hud.bShowHUD;s.hud.bShowHUD=false end
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
    -- MOVE_None holds the body; the game's custom movement component still
    -- owns native position/simulation housekeeping. Preserve its entry tick.
    -- Commit both camera effects before exposing the first drone frame.
    applyCameraEffects(s)
    vision.update(s,clock())
    pc:SetViewTargetWithBlend(s.camera,0,0,0,false)
    -- One-time camera/payload preparation is not flight simulation time.
    s.lastWorldTime=gameplay:GetTimeSeconds(pc);s.lastRealTime=clock()
    lastToggle=clock()
    log('FPV active. Use the assigned pilot action to return and reset action to return the drone to launch. Controller calibration '..(calibration and 'loaded' or 'DEFAULT AETR'))
    log('ZoneFPV 0.3.0 RC1: native movement tick retained; equipment ancestor ownership and delayed NPC readiness guarded.')
end
local function collide(s,old)
    if not session or session.pendingDetonation then return false end
    if not weaponSettings.hasKamikaze(session.weaponMode)and(not cfg.collision or session.noclip)then return end
    local yes,hit=droneCollision.trace(system,session,vec(old),vec(s.p),cfg.radius*100)
    if yes then
        local n={x=hit.Normal.X,y=hit.Normal.Y,z=hit.Normal.Z}
        local scale=flight.horizontal_scale(cfg.speed_preset)
        local speed=math.max(0,-(s.v.x*scale*n.x+s.v.y*scale*n.y+s.v.z*1.5*n.z))
        if weaponSettings.hasKamikaze(session.weaponMode)and droneWeapons.shouldDetonate(session,speed,hit)then
            local pos=hit.Location
            session.pendingDetonation={X=pos.X,Y=pos.Y,Z=pos.Z}
            s.p=meters(pos);s.v={x=0,y=0,z=0}
            return false
        end
        if session.radio and session.radio.lost then session.radio.hit=true end
        if experiments.droneHP then
            droneCombat.impact(session,speed,n.z,impactMultiplier)
        end
        local p=meters(hit.Location)
        if droneCollision.isPenetrating(hit)and hit.PenetrationDepth and hit.PenetrationDepth>0 then
            for _,k in ipairs({'x','y','z'}) do p[k]=old[k]+n[k]*hit.PenetrationDepth/100 end
        end
        for _,k in ipairs({'x','y','z'}) do p[k]=p[k]+n[k]*0.002 end
        flight.collide(s,p,n,cfg.restitution,cfg.surface_friction,cfg.speed_preset)
    end
end
local function actionsAllowed(p)
    if not p or not p.focused or p.menu or p.paused or pdaOpen or resourceGuard.level>=2 then return false end
    local controller=session and session.pc or pdaController
    if not valid(controller) or not valid(controller.Pawn) then return false end
    local ok,world=pcall(controller.GetWorld,controller)
    if not ok or not valid(world) then return false end
    if session and (not same(controller.Pawn,session.pawn) or not same(world,session.world)) then return false end
    if not valid(gameplay) then gameplay=StaticFindObject('/Script/Engine.Default__GameplayStatics') end
    if not valid(gameplay) then return false end
    local pausedOK,paused=pcall(gameplay.IsGamePaused,gameplay,controller)
    if not pausedOK or paused then return false end
    -- Our own flight locks native movement; those locks are only a loading or
    -- cutscene guard while the player is still controlling the character.
    if not session then
        local moveOK,moveIgnored=pcall(controller.IsMoveInputIgnored,controller)
        local lookOK,lookIgnored=pcall(controller.IsLookInputIgnored,controller)
        if not moveOK or not lookOK or moveIgnored or lookIgnored then return false end
    end
    return true
end
local function update()
    markStage('menu and god mode')
    sensorFrame=sensorFrame+1
    local tickNow=clock()
    environment(tickNow)
    updatePDA(tickNow)
    local currentWorld
    if valid(pdaController)then pcall(function()currentWorld=pdaController:GetWorld()end)end
    visualGuard.updateRecovery(tickNow,currentWorld,pdaController)
    -- Released grenades keep their game-time fuse after the pilot leaves FPV.
    -- They share this one game-thread callback rather than owning a Lua worker.
    droneWeapons.update(tickNow,gameplay,log,currentWorld)
    externalMenu:update(session and session.pc or pdaController)
    resourceGuard:update(tickNow,session~=nil)
    if resourceGuard.level>=2 then
        pendingEntry=false;vision.clearPrewarm()
    elseif not session then warmVision(pdaController)end
    if session and resourceGuard.level>=2 then exit('resource pressure: '..(resourceGuard.reason or 'critical resource pressure'));return end
    -- Console commands and controller discovery are comparatively expensive.
    -- Poll slowly and godMode applies only on an actual option/pawn change.
    if not nextGodUpdate or tickNow>=nextGodUpdate then
        -- The receiving proxy owns the damage flag for this whole flight.
        -- Apply menu changes after its teardown, before returning control.
        if not (session and session.combat and session.combat.reactionReady) then
            local activeController=session and session.pc or pdaController
            local activePawn=valid(activeController) and activeController.Pawn or nil
            godMode.update(godState,activePawn,options.god,activeController,helpers.GetKismetSystemLibrary())
        end
        nextGodUpdate=tickNow+0.25
    end
    local actionPacket=readActions()
    local p=packet(actionPacket)
    if p and pdaOpen then
        local held={};for k,v in pairs(p)do held[k]=v end
        held.menu=true;p=held
    end
    local allowed=actionsAllowed(p)
    local suspended=false
    if session and p and p.staleInput and actionPacket and actionPacket.ready and actionPacket.focused and actionPacket.active then
        local current={};for k,v in pairs(p)do current[k]=v end
        current.focused=true;current.paused=false
        suspended=actionsAllowed(current)
    end
    local held=heldActions:update(actionPacket,allowed,tickNow,actionModes,pilot.keys,suspended)
    if actionPacket and actionPacket.ready then actionChannelSeen=true end
    if actionPacket and actionPacket.focused and allowed and lastActionAllowed then
        if actionPacket.pilot and actionModes.pilot==0 and pilot.keys[2]~=0 then request=true end
        if actionPacket.reset and actionModes.reset==0 and pilot.keys[3]~=0 and session then resetRequested=true end
        if actionPacket.collect and actionModes.collect==0 and pilot.keys[4]~=0 then executeCommand('FPVCollectArtifact') end
        if actionPacket.flashlight and features.flashlightEnabled and actionModes.flashlight==0 and pilot.keys[5]~=0 and session then droneFlashlight.toggle(session,gameplay,log)end
        if actionPacket.cameraDown and actionModes.cameraDown==0 and pilot.keys[6]~=0 and session then setCameraDown('toggle')end
        if actionPacket.grenadeDrop and actionModes.grenadeDrop==0 and pilot.keys[7]~=0 and session then dropGrenade()end
        if actionPacket.vision and actionModes.vision==0 and pilot.keys[8]~=0 and session then setVisionEnabled('toggle')end
    elseif not actionChannelSeen and allowed then
        -- Compatibility with old helpers: callbacks are consumed only after
        -- probing the new channel, so its first packet cannot duplicate a VK.
        if legacyActions[2]and actionModes.pilot==0 then request=true end
        if legacyActions[3]and actionModes.reset==0 and session then resetRequested=true end
        if legacyActions[4]and actionModes.collect==0 then executeCommand('FPVCollectArtifact') end
        if legacyActions[5] and features.flashlightEnabled and actionModes.flashlight==0 and session then droneFlashlight.toggle(session,gameplay,log)end
        if legacyActions[6] and actionModes.cameraDown==0 and session then setCameraDown('toggle')end
        if legacyActions[7] and actionModes.grenadeDrop==0 and session then dropGrenade()end
        if legacyActions[8] and actionModes.vision==0 and session then setVisionEnabled('toggle')end
    end
    if held.pressed.pilot and allowed then
        if session then session.pilotHoldOwned=true
        else request=true;pilotHoldPending=true end
    elseif held.released.pilot then
        if pilotHoldPending then pendingEntry=false;request=false;pilotHoldPending=false end
        if session and session.pilotHoldOwned then exit('pilot button released')end
    end
    if held.pulse.collect and allowed then executeCommand('FPVCollectArtifact')end
    if held.pulse.grenadeDrop and allowed and session then dropGrenade()end
    legacyActions={};lastActionAllowed=allowed
    local legacyToggle=cfg.toggle_button>0
    if legacyToggle then
        for _,code in ipairs(pilot.keys)do
            if code==1000+cfg.toggle_button then legacyToggle=false;break end
        end
    end
    if legacyToggle and p then
        local down=(p.buttons & (1 << (cfg.toggle_button-1)))~=0
        if legacyButtonPrimed and allowed and down and not lastButton then request=true end
        lastButton=down;legacyButtonPrimed=true
    else lastButton=false;legacyButtonPrimed=false end
    if not allowed then resetRequested=false end
    if request then
        request=false
        if allowed then
            if session then exit('toggle')
            elseif pendingEntry then pendingEntry=false
            else enter(p) end
        else pendingEntry=false;log('Start input bridge / focus game / check USB.') end
    elseif pendingEntry then
        if not p or not p.focused or p.menu or pdaOpen then pendingEntry=false
        else enter(p)end
    end
    if not session and not pendingEntry then pilotHoldPending=false end
    if not session then resetRequested=false;return end
    updateHeldActions(held)
    local s=session
    if s.mode~=cfg.flight_mode then exit('flight mode changed; re-enter FPV');return end
    if not p then exit('controller disconnected or stale input');return end
    if not valid(s.pc) or not valid(s.pawn) or not valid(s.camera) or not valid(s.world) then
        exit('world changed');return
    end
    if not same(s.pc.Pawn,s.pawn) or not same(s.pc:GetWorld(),s.world) then exit('pawn/world changed');return end
    local destination=teleportGuard.update(s)
    if destination then
        teleportGuard.handoff(s,destination)
        exit('external teleport: control returned at game destination');return
    end
    if gameplay:IsGamePaused(s.pc) and not p.menu and not p.paused then exit('pause/menu');return end
    local wasFrozen=s.freezeOwned
    worldFreeze.set(s,options.freeze,gameplay)
    if valid(s.hud) and s.hud.bShowHUD then s.hud.bShowHUD=false end
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
    if s.movement:IsComponentTickEnabled()~=s.previousMovementTick then
        s.movement:SetComponentTickEnabled(s.previousMovementTick)
    end
    local now=gameplay:GetTimeSeconds(s.pc)
    local realNow=clock()
    local dt=(s.freezeOwned or wasFrozen) and (realNow-s.lastRealTime) or (now-s.lastWorldTime)
    s.lastWorldTime=now;s.lastRealTime=realNow
    dt=environmentGuard.delta(s,dt,realNow)
    local inputPaused
    dt,inputPaused=focusGuard.delta(s,p,dt)
    s.inputPaused=inputPaused
    if held.reset and not inputPaused and not(s.radio and s.radio.lost)then
        resetRequested=true;dt=0
    end
    if dt<0 then exit('world time reset');return end
    if dt>1 and not inputPaused then exit('frame stall over one second');return end
    if dt>0 and not inputPaused then cameraUpdates=cameraUpdates+1;cameraTime=cameraTime+dt;cameraGap=math.max(cameraGap,dt) end
    if dt>0.1 and not inputPaused and (not s.nextStallLog or clock()>=s.nextStallLog) then
        log(string.format('Long frame %.3fs; speed=%gx; Acro rotation catches up',dt,cfg.speed_preset))
        s.nextStallLog=clock()+10
    end
    if resetRequested and not inputPaused then
        resetRequested=false
        if not inputPaused and not (s.radio and s.radio.lost) then
            s.flight=flight.new(s.origin,s.startYaw);s.radio=nil;s.cameraDirty=true
        end
    end
    local u=input.controls(p,cfg,calibration)
    local wasLost=s.radio and s.radio.lost
    markStage('experimental world and signal')
    local experimentalDelta=inputPaused and 0 or math.max(0,math.min(dt,0.1))
    local priorPosition={X=s.flight.p.x*100,Y=s.flight.p.y*100,Z=s.flight.p.z*100}
    experimentalWorld:pollPickup(s,experimentalDelta)
    local readings=experimentalWorld:update(s,observationOptions,experimentalDelta,realNow)
    local sources={obstacles=radioObstacles.update(s,system,radioSettings.enabled and experiments.obstacles,realNow,log),
        anomalyEnabled=experiments.anomalyInterference,anomaly=readings.anomalyInterference or 0}
    s.experimentOptions=experiments
    local radio=radioLink.update(s,radioSettings,inputPaused and 0 or dt,sources)
    if radio.lost then u={roll=0,pitch=0,yaw=0,throttle=cfg.flight_mode=='3d' and 0.5 or 0} end
    if not inputPaused then s.throttle=cfg.flight_mode=='3d' and (u.throttle*2-1) or u.throttle end
    if dt>0 and not inputPaused then s.flightSeconds=(s.flightSeconds or 0)+math.min(dt,1) end
    markStage('physics and collision traces')
    if dt>0 and not inputPaused then flight.advance(s.flight,u,cfg,dt,collide) end
    if s.pendingDetonation then
        local position=s.pendingDetonation;s.pendingDetonation=nil
        local fired,code=droneWeapons.detonate(s,position,gameplay,log)
        exit(fired and 'kamikaze impact' or ('kamikaze payload unavailable: '..tostring(code)))
        return
    end
    -- Hazards use this frame's actual movement segment, and the hit proxy moves
    -- to the completed flight position before checking incoming attack damage.
    readings=experimentalWorld:hazards(s,experiments,experimentalDelta,priorPosition)
    droneCombat.update(s,combatOptions(s),experimentalDelta,realNow)
    if experiments.anomalyDamage and (readings.anomalyDamageAmount or 0)>0 then
        droneCombat.damage(s,readings.anomalyDamageAmount,'anomaly')
    end
    sources.anomaly=readings.anomalyInterference or 0
    s.noiseStyle=anomalyNoise.style(experiments.style,anomalyStyle,experiments.anomalyInterference and sources.anomaly>0)
    -- Check boundary crossings in this frame as well, without advancing the fall timer twice.
    if s.combat and s.combat.broken then radioLink.lose(s,'destroyed') end
    radio=radioLink.update(s,radioSettings,0,sources)
    if radio.lost and not wasLost then log('Simulated signal lost; motors off, emergency fall.') end
    if radioLink.finished(s) then exit(radio.reason=='destroyed' and 'drone destroyed' or 'simulated signal loss');return end
    if not inputPaused and (not s.nextFlightLog or clock()>=s.nextFlightLog) then
        log(string.format('Flight speed=%gx yaw_input=%.3f yaw_rate=%.1fdeg/s dt=%.3fs',
            cfg.speed_preset,u.yaw,math.deg(s.flight.omega.z),dt))
        s.nextFlightLog=clock()+5
    end
    local pos=s.flight.p
    if not radio.enabled and cfg.max_distance>0 and (pos.x-s.origin.x)^2+(pos.y-s.origin.y)^2+(pos.z-s.origin.z)^2>cfg.max_distance^2 then
        exit('configured distance limit reached');return
    end
    applyCameraEffects(s)
    markStage('camera transform')
    -- Callbacks can share a world-time sample, and menus/focus hold physics.
    -- Do not dirty the camera's scene transform when no flight/tilt change occurred.
    if (dt>0 and not inputPaused) or s.cameraDirty or s.appliedCameraTilt~=cfg.camera_tilt then
        s.camera:K2_SetActorLocationAndRotation(vec(flight.camera_position(s.flight,s.cameraDown,cfg.radius)),flight.camera_rotation(s.flight,cfg.camera_tilt,s.cameraDown),false,{},true)
        s.cameraDirty=false;s.appliedCameraTilt=cfg.camera_tilt
    end
    -- Weather/region scripts can replace the view target without ending FPV.
    if not same(s.pc:GetViewTarget(),s.camera) then s.pc:SetViewTargetWithBlend(s.camera,0,0,0,false) end
    markStage('player exposure and audio')
    playerGuard.suppress(s)
    if not s.nextPlayerGuard or realNow>=s.nextPlayerGuard then
        playerGuard.update(s)
        playerUI.update(s,realNow,gameplay,p.menu)
        regionalFog.update(s,realNow,selectedWeather=='Clearly')
        s.nextPlayerGuard=realNow+0.1
    end
    -- Stage increased streaming and explicitly report temporary protection.
    -- The saved selection is retained for the next safe flight.
    worldDistance.update(s,system,distanceSelection,log,realNow,resourceGuard.streamingLimited~=false,resourceGuard.sample)
    markStage('camera effects')
    visualGuard.update(s,realNow,system,options.npcs,selectedWeather=='Clearly')
    markStage('sensor vision')
    local sensorOK,sensorError=pcall(vision.update,s,realNow)
    if not sensorOK then vision.restore(s);log('Vision disabled after error: '..tostring(sensorError))end
    markStage('telemetry and scanner')
    publishTelemetry(realNow,s)
    publishScan(realNow,s)
    if not s.nextVisibilityUpdate or realNow>=s.nextVisibilityUpdate then
        markStage('equipment visibility')
        playerVisibility.update(s,realNow)
        s.nextVisibilityUpdate=realNow+0.1
    end
    markStage('world particles')
    fpvParticles.update(s,realNow,root,log)
    if droneWeapons.prepare then
        markStage('weapon preparation')
        droneWeapons.prepare(s,gameplay,log,not inputPaused and allowed and not (s.radio and s.radio.lost))
    end
    if not (s.combat and s.combat.reactionReady) and ((s.npcAnchor~=nil)~=options.npcs or not s.nextAnchorUpdate or clock()>=s.nextAnchorUpdate) then
        markStage('player streaming anchor')
        npcAnchor.update(s,options.npcs,vec(pos))
        s.nextAnchorUpdate=clock()+0.05
    end
end
for _,vk in ipairs(pilotSettings.legacy_keys) do
    local code=vk
    -- The helper owns universal edges. Native callbacks serve old helper builds
    -- only, using their stable native key allowlist. They never invoke actions
    -- directly from an unknown UI/focus state.
    pcall(RegisterKeyBind,code,function()
        for action=2,7 do if code==pilot.keys[action] then legacyActions[action]=true end end
    end)
end
-- One game-thread callback renews itself. No concurrent Lua worker/collector.
local nextIdleUpdate=0
local perfNext,perfTotal,perfMax,perfCount=0,0,0,0
-- EngineTick is required: this UE4SS build's ProcessEvent dispatcher can run
-- Lua on async loading workers. Installer enables Tick and disables that route.
local scheduler=dofile(here..'scheduler.lua').new(ExecuteInGameThread,clock,log)
local function pump()
    if not session and not request and not pendingEntry and next(legacyActions)==nil then
        local now=clock();if now<nextIdleUpdate then return false end
        nextIdleUpdate=now+((visualGuard.recoveryActive()or (pdaOpen and pda.active))and .01 or .05)
    end
    stage='game thread'
        local started=clock()
        stageStats=stageStats or {};stageStarted=started
        local ok,err=xpcall(function()
            if achievementsReady then achievementsRecovery:update(clock())end
            update()
            markStage('audio publication')
            publishAudio(clock(),session~=nil and not session.inputPaused,session and session.flight and session.flight.thrust or 0,cfg.gravity*cfg.thrust_to_weight)
        end,debug.traceback)
        if not ok then
            log(tostring(err))
            pcall(externalMenu.restore)
            local restored,restoreError=pcall(exit,'error; see UE4SS.log')
            if not restored then log('Emergency restore: '..tostring(restoreError)) end
        end
        markStage('callback complete');stageStarted=nil
        local elapsed=(clock()-started)*1000
        perfTotal=perfTotal+elapsed;perfMax=math.max(perfMax,elapsed);perfCount=perfCount+1
        if clock()>=perfNext then
            perfNext=clock()+10
            pcall(function()
                local f=io.open(root..'performance.txt','w')
                if f then f:write(string.format('mode=%s callbacks=%d callback_avg_ms=%.3f callback_max_ms=%.3f camera_hz=%.1f camera_max_gap_ms=%.1f\n',
                    session and 'fpv' or 'character',perfCount,perfTotal/perfCount,perfMax,cameraTime>0 and cameraUpdates/cameraTime or 0,cameraGap*1000))
                    local names={};for name in pairs(stageStats)do names[#names+1]=name end;table.sort(names)
                    for _,name in ipairs(names)do local metric=stageStats[name]
                        f:write(string.format('stage=%s calls=%d avg_ms=%.3f max_ms=%.3f\n',name,metric.count,metric.total/metric.count,metric.max))
                    end
                    local metrics=session and session.worldExperiments and session.worldExperiments.performance
                    if metrics then for _,key in ipairs({'lookupMs','discoveryMs','refreshMs','hazardsMs','selectionMs'})do
                        if type(metrics[key])=='number' then f:write(string.format('world_%s=%.3f\n',key,metrics[key])) end
                    end end
                    local particles=session and session.fpvParticles and session.fpvParticles.performance
                    if particles then for _,key in ipairs({'lookupMs','lookupMaxMs','discoveryMs','discoveryMaxMs','copyMs','copyMaxMs'})do
                        if type(particles[key])=='number'then f:write(string.format('particles_%s=%.3f\n',key,particles[key]))end
                        if key:match('MaxMs$')then particles[key]=0 end
                    end end
                    if session and session.vision then
                        f:write(string.format('vision_mode=%d vision_max_ms=%.3f\n',session.vision.mode,session.vision.maxMs or 0))
                        session.vision.maxMs=0
                    end
                    f:close() end
            end)
            perfTotal,perfMax,perfCount=0,0,0
            stageStats={}
            cameraUpdates,cameraTime,cameraGap=0,0,0
        end
        stage='idle'
    return false
end
local scheduled=scheduler.start(pump,0.004)
log(scheduled and 'Camera scheduler: EngineTick only / one Lua callback per frame / 4 ms minimum' or 'Camera scheduler failed; install runtime settings and see dispatch error above')
log('Loaded. Configure pilot, reset and artifact collection actions in the menu. Input bridge required; physics 240 Hz.')
