-- Adapter contract tests only; mocks do not establish game compatibility.
package.path='mod/Scripts/?.lua;'..package.path
local testClock=10
local rawOpen,rawClock,rawTime,rawLoadlib,rawRemove=io.open,os.clock,os.time,package.loadlib,os.remove
local rawRename=os.rename
local line,loop,keys,audioLine,widgetsHidden,hideCalls
local pc,pawn,camera,hud,hudRoot,world,movement
local failSpawn,failView,spawned,destroyed,collisionTraces
local paused,frozenTime,timeOffset,timeDilation
local environmentLine,consoleValues
local actionLine
local telemetryLine
local hitHandlers={}
local controllerLookups
local legacyNativeKeys={}
for _,code in ipairs({33,34,35,36,45,46})do legacyNativeKeys[code]=true end
for code=65,90 do legacyNativeKeys[code]=true end
for code=112,123 do legacyNativeKeys[code]=true end
local function object(t) t=t or {};function t:IsValid() return not self.invalid end;function t:GetAddress() return self.address or self end;return t end
local function reset(options)
    options=options or {};paused=false;timeOffset=0;timeDilation=1;environmentLine=nil;telemetryLine=nil;actionLine=options.actions
    controllerLookups=0
    local resourceLine,resourceSequence=nil,0
    package.loadlib=function(_,symbol)
        if symbol=='zonefpv_achievements_init'and options.achievementInit then
            return function()
                assert(next(keys)==nil and spawned==0,'achievement compatibility must arm before key callbacks and first FPV')
                options.achievementCalls=(options.achievementCalls or 0)+1;options.achievementReady=true
            end
        end
        if symbol=='zonefpv_achievements_check'and options.achievementInit then
            return function()
                assert(options.onGameThread,'live achievement manager must be checked on EngineTick')
                assert(options.achievementRequest=='ZFPVA42 0\n','native resolves the active singleton')
                options.achievementChecks=(options.achievementChecks or 0)+1
                options.achievementCheckStatus='ZFPVA42C 1 1 1 0\n'
            end
        end
        if symbol=='zonefpv_resources_poll' and options.resources then
            return function()
                resourceSequence=resourceSequence+1
                resourceLine=string.format('ZFPVR11 %d %d %d 1 %d 720896',resourceSequence,options.resources.ram,options.resources.commit,options.resources.used or 300000)
            end
        end
        return nil,'Fixture has no native engine'
    end
    hitHandlers={};RegisterHook=nil;UnregisterHook=nil
    if options.nativeHits then
        RegisterHook=function(path,callback)
            assert(path=='/Script/Stalker2.Obj:ReceiveDamage','optional endpoint unavailable in fixture')
            hitHandlers[path]=callback;return 1,2
        end
        UnregisterHook=function(path)hitHandlers[path]=nil end
    end
    consoleValues={['r.Fog']=1,['r.VolumetricFog']=1,['r.LocalFogVolume']=1,['r.PostProcessing.DisableMaterials']=0}
    if options.distance then consoleValues['wp.Runtime.LoadingRangeTerrain']=10000 end
    testClock=10;keys={};spawned=0;destroyed=0;collisionTraces=0;failSpawn=false;failView=false;widgetsHidden=false;hideCalls=0
    local pdaSettingsFrames={}
    local featureFrames={}
    if options.features then featureFrames['mod/Scripts/../drone-features.txt']=options.features end
    hud=object({bShowHUD=true})
    movement=object({MovementMode=1,CustomMovementMode=0,ticking=true,
        IsComponentTickEnabled=function(s) return s.ticking end,
        SetComponentTickEnabled=function(s,b) s.ticking=b end,
        StopMovementImmediately=function(s) s.velocity=0 end,
        DisableMovement=function(s) s.MovementMode=0 end,
        SetMovementMode=function(s,m,custom) s.MovementMode=m;s.CustomMovementMode=custom end})
    pawn=object({CharacterMovement=movement,disabled=false,DisableInput=function(s) s.disabled=true end,EnableInput=function(s) s.disabled=false end})
    if options.visionFixture then pawn.CameraComponent=object()end
    pawn.position={X=0,Y=0,Z=200};pawn.bHidden=false;pawn.bCanBeDamaged=true;pawn.collision=true
    function pawn:K2_GetActorLocation() return self.position end
    function pawn:K2_SetActorLocation(p) self.position=p end
    function pawn:GetActorEnableCollision() return self.collision end
    function pawn:SetActorEnableCollision(v) self.collision=v end
    function pawn:SetActorHiddenInGame(v) self.bHidden=v end
    if options.reactionFixture then
        pawn.LastHitTimestampSeconds=0;pawn.hp=87
        function pawn:GetHP()return self.hp end
        function pawn:ForceSetHP(v)self.hp=v end
        if options.healthReserve then
            pawn.maximum=100
            function pawn:GetMaxHP()return self.maximum end
            function pawn:SetMaxHP(v)self.maximum=v end
        end
    end
    world=object({SpawnActor=function()
        if failSpawn then error('injected spawn failure') end
        spawned=spawned+1
        camera=object({transforms=0,CameraComponent=object({SetFieldOfView=function() end}),
            SetTickableWhenPaused=function() end,
            SetActorEnableCollision=function() end,
            K2_DestroyActor=function(s)
                destroyed=destroyed+1;s.invalid=true
                if options.resetHUDOnCameraDestroy then hudRoot:SetRenderOpacity(0);hudRoot:SetVisibility(1) end
            end,
            K2_SetActorLocationAndRotation=function(s,pos,rotation) s.position=pos;s.rotation=rotation;s.transforms=s.transforms+1 end})
        return camera
    end})
    hudRoot=object({opacity=.75,visibility=0,GetWorld=function()return world end,
        GetRenderOpacity=function(s)return s.opacity end,GetVisibility=function(s)return s.visibility end,
        SetRenderOpacity=function(s,v)s.opacity=v end,
        SetVisibility=function(s,v)s.visibility=v;widgetsHidden=v==1;if v==1 then hideCalls=hideCalls+1 end end})
    FindAllOf=function(name)return name=='PlayerGameHUDView' and {hudRoot} or {} end
    pc=object({Pawn=pawn,move=0,look=0,view=pawn,
        bShouldPerformFullTickWhenPaused=false,PrimaryActorTick={bTickEvenWhenPaused=false},
        SetTickableWhenPaused=function(s,b) s.PrimaryActorTick.bTickEvenWhenPaused=b end,
        PlayerCameraManager=object({GetCameraLocation=function() return {X=0,Y=0,Z=200} end,
            GetCameraRotation=function() return {Pitch=0,Yaw=10,Roll=0} end}),
        GetWorld=function() return world end,GetViewTarget=function(s) return s.view end,
        GetHUD=function() return hud end,IsMoveInputIgnored=function() return false end,
        IsLookInputIgnored=function() return false end,
        SetIgnoreMoveInput=function(s,b) s.move=s.move+(b and 1 or -1) end,
        SetIgnoreLookInput=function(s,b) s.look=s.look+(b and 1 or -1) end,
        SetViewTargetWithBlend=function(s,v)
            if failView then error('injected view failure') end
            if options.visionFixture and v==camera then
                assert(v.CameraComponent.visionApplied,'selected vision must commit before exposing FPV view')
                options.visionFixture.events[#options.visionFixture.events+1]='view'
            end
            s.view=v
        end})
    local worldClock,lastRealClock=testClock,testClock
    local function worldTime()
        if not paused then worldClock=worldClock+(testClock-lastRealClock)*timeDilation end
        lastRealClock=testClock
        return worldClock-timeOffset
    end
    local gameplay=object({IsGamePaused=function() return paused end,
        GetTimeSeconds=worldTime,
        GetGlobalTimeDilation=function() return timeDilation end,
        SetGlobalTimeDilation=function(_,_,value) worldTime();timeDilation=value end,
        SetGamePaused=function(_,_,b)
            if b and not paused then frozenTime=testClock-timeOffset
            elseif paused and not b then timeOffset=testClock-frozenTime end
            paused=b;return true
        end,
        BeginDeferredActorSpawnFromClass=function() return world:SpawnActor() end,
        FinishSpawningActor=function(_,actor) return actor end})
    local system=object({SphereTraceSingle=function(_,_,_,_,_,_,_,_,_,hit)
            collisionTraces=collisionTraces+1
            if options.weaponsFixture and options.weaponsFixture.hit then
                hit.Time=.5;hit.Location={X=0,Y=0,Z=190};hit.Normal={X=0,Y=0,Z=1};return true
            end
            return false
        end,
        GetConsoleVariableIntValue=function(_,name)return consoleValues[name]end,
        GetConsoleVariableFloatValue=function(_,name)return consoleValues[name]or -1 end,
        ExecuteConsoleCommand=function(_,_,command)
            local name,value=command:match('^(%S+) (%d+)$')
            if consoleValues[name]~=nil then consoleValues[name]=tonumber(value)end
            assert(command~='XHideAllWidget' and command~='XShowAllWidget','FPV must not mutate global widget/view-manager state')
            if command:match('^XForceWeather ') then
                timeOffset=timeOffset+100;testClock=testClock+2;pc.view=pawn
            end
        end})
    package.loaded.UEHelpers={GetPlayerController=function()controllerLookups=controllerLookups+1;return pc end,GetKismetSystemLibrary=function() return system end}
    StaticFindObject=function(name) return name:find('GameplayStatics') and gameplay or object() end
    local registrationAttempts={}
    Key={F8=119,F9=120};RegisterKeyBind=function(k,fn)
        registrationAttempts[#registrationAttempts+1]=k
        -- Native UE4SS's 255-entry subscription array has indices 0..254.
        -- Track attempts before throwing: main's pcall must not hide a failure.
        assert(k~=255,'native subscription would overwrite the input source pointer')
        assert(legacyNativeKeys[k],'native fallback must retain the stable legacy key set')
        keys[k]=fn
    end
    LoopAsync=function()error('flight must not use a concurrent Lua worker')end
    EGameThreadMethod={EngineTick=0,ProcessEvent=1}
    ExecuteInGameThread=function(fn,method)
        assert(method==EGameThreadMethod.EngineTick,'flight must dispatch on EngineTick')
        loop=function()options.onGameThread=true;fn();options.onGameThread=false end
    end
    os.clock=function() return testClock end;os.time=function() return 100 end
    os.remove=function(path)
        if path:find('drone-features.',1,true)then featureFrames[path]=nil;return true end
        if path:find('native-achievements-check-status.txt',1,true)then options.achievementCheckStatus=nil;return true end
        if path:find('native-achievements-status.txt',1,true)then options.achievementReady=false;return true end
        return rawRemove(path)
    end
    os.rename=function(a,b)
        if a:find('drone-features.',1,true)then
            if featureFrames[a]==nil or featureFrames[b]~=nil then return nil,'File exists'end
            featureFrames[b],featureFrames[a]=featureFrames[a],nil
            if b:match('drone%-features%.txt$')then options.features=featureFrames[b]end
            return true
        end
        return rawRename(a,b)
    end
    io.open=function(path,mode)
        if path:find('drone-features.',1,true)then
            if mode=='wb'then return {write=function(_,text)featureFrames[path]=text;return true end,close=function()return true end}end
            if featureFrames[path]then return {read=function()return featureFrames[path]end,close=function()return true end}end
            return nil,'missing',2
        end
        if path:find('pda-settings-',1,true)then
            if mode=='w'then return {write=function(_,text)pdaSettingsFrames[path]=text;return true end,close=function()return true end}end
            if pdaSettingsFrames[path]then return {read=function()return pdaSettingsFrames[path]end,close=function()return true end}end
            return nil
        end
        if path:find('native-achievements-manager.txt',1,true)then
            assert(mode=='wb')
            return {write=function(_,text)options.achievementRequest=text;return true end,close=function()return true end}
        end
        if path:find('native-achievements-check-status.txt',1,true)then
            if not options.achievementCheckStatus then return nil end
            return {read=function()return options.achievementCheckStatus end,close=function()end}
        end
        if path:find('native-achievements-status.txt',1,true)then
            if not options.achievementReady then return nil end
            return {read=function()return 'ZFPVA42 1 0\n'end,close=function()end}
        end
        if path:find('weapon-settings.txt',1,true)then
            if mode=='w'then return {write=function(_,text)options.armament=text;return true end,close=function()return true end}end
            if options.armament then return {read=function()return options.armament end,close=function()end}end
            return nil
        end
        if path:find('action-modes.txt',1,true)then
            if mode=='w'then return {write=function(_,text)options.actionModes=text;options.preferenceWrites=(options.preferenceWrites or 0)+1;return true end,close=function()return true end}end
            if options.actionModes then return {read=function()return options.actionModes end,close=function()end}end
            return nil
        end
        if path:find('action-input.txt',1,true)then
            if actionLine then return {read=function()return actionLine end,close=function()end}end
            return nil
        end
        if path:find('bindings.txt',1,true)then
            if mode=='w' then return {write=function(_,value)options.bindings=value;options.preferenceWrites=(options.preferenceWrites or 0)+1;return true end,close=function()return true end}end
            if options.bindings then return {read=function()return options.bindings end,close=function()end}end
            return nil
        end
        if options.visionFixture and path:find('vision-settings.txt',1,true)then
            return {read=function()return '3'end,close=function()end}
        end
        if path:find('native-resources-status.txt',1,true) then
            if not resourceLine then return nil end
            return {read=function()return resourceLine end,close=function()end}
        end
        if path:find('world-distance.txt',1,true)and options.distance then return {read=function()return tostring(options.distance)end,close=function()end}end
        if path:find('god-settings.txt',1,true) then
            if mode=='w' then return {write=function(_,value)options.god=value:match('1')~=nil;return true end,close=function()return true end} end
            return {read=function()return options.god and '1' or '0' end,close=function()end}
        end
        if path:find('experiment-settings.txt',1,true) then
            if mode=='w' then return {write=function(_,value)options.experiments=value;return true end,close=function()return true end} end
            if options.experiments then return {read=function()return options.experiments end,close=function()end} end
            return nil
        end
        if path:find('scan-frame.txt',1,true) then return {write=function()return true end,close=function()return true end} end
        if path:find('signal-settings.txt',1,true) then
            if mode=='w' then return {write=function(_,value)options.signal=value;return true end,close=function()return true end} end
            if options.signal then return {read=function()return options.signal end,close=function()end} end
            return nil
        end
        if path:find('telemetry.txt',1,true) then return {write=function(_,value)telemetryLine=value;return true end,close=function()end} end
        if path:find('Start-Bridge.ps1',1,true) then return nil end
        if path:find('calibration.lua',1,true) then return nil end
        if path:find('flight-settings.txt',1,true) then
            if mode=='w' then return {write=function() return true end,close=function() return true end} end
            return nil
        end
        if path:find('environment.txt',1,true) then
            if not environmentLine then return nil end
            return {read=function() return environmentLine end,close=function() end}
        end
        if path:find('environment-response.txt',1,true) then return {write=function() end,close=function() end} end
        for _,key in ipairs({'freeze','collision','alternate','noclip'}) do
            if path:find(key..'-settings.txt',1,true) then
                return {read=function() return options[key] and '1' or '0' end,close=function() end}
            end
        end
        if path:find('input.txt',1,true) then return {read=function() return line end,close=function() end} end
        if path:find('audio.txt',1,true) then return {write=function(_,text) audioLine=text end,close=function() end} end
        if path:find('telemetry.txt',1,true) or path:find('performance.txt',1,true)
            or path:find('particle-mirror.txt',1,true) or path:find('leaf-world.txt',1,true) then
            return {write=function() return true end,close=function() end}
        end
        return rawOpen(path,mode)
    end
    line='1 1 100000 1 1 32767 32767 0 32767 0 0 0 1'
    local priorDofile=dofile
    if options.inspectPreferences then
        local original=priorDofile('mod/Scripts/pda_menu.lua')
        dofile=function(path)
            if path:match('[/\\]pda_menu%.lua$')then return {new=function(args)
                options.preferenceSnapshot=args.snapshot;options.preferenceCommand=args.execute
                return original.new(args)
            end}end
            return priorDofile(path)
        end
    end
    if options.recoveryFixture then
        local fixture=options.recoveryFixture
        local mocked={
            update=function(s)fixture.flight=s;fixture.active=false end,
            restore=function()end,
            beginRecovery=function(s,now)
                assert(options.onGameThread and s.world==world and s.camera:IsValid(),
                    'recovery must begin on EngineTick before camera teardown')
                fixture.begins=(fixture.begins or 0)+1;fixture.active=true;fixture.deadline=now+5
            end,
            updateRecovery=function(now,currentWorld,currentController)
                assert(options.onGameThread,'recovery updates require EngineTick even in character mode')
                assert(currentController==pc,'recovery must follow the current player camera after FPV teardown')
                fixture.updates=(fixture.updates or 0)+1
                if fixture.active then
                    assert(currentWorld==world,'recovery receives current world even without flight')
                    if now>=fixture.deadline then fixture.active=false;fixture.completed=now end
                end
            end,
            recoveryActive=function()return fixture.active==true end,
        }
        dofile=function(path)
            if path:match('[/\\]visual_guard%.lua$')then return mocked end
            return priorDofile(path)
        end
    end
    if options.visionFixture then
        local fixture=options.visionFixture
        fixture.calls=0;fixture.progress=0;fixture.applies=0;fixture.events={};fixture.frames={};fixture.ready=false
        local mocked={needsTargets=function(mode)return mode==3 end,
            clearPrewarm=function()fixture.ready=false;fixture.progress=0 end,
            prewarm=function(context,mode)
                assert(context.world==world and context.camera==pawn.CameraComponent and mode==3)
                fixture.calls=fixture.calls+1;fixture.frames[testClock]=(fixture.frames[testClock]or 0)+1
                assert(fixture.frames[testClock]==1,'idle prewarm plus pending enter must use at most one batch per frame')
                if not fixture.ready then
                    fixture.progress=fixture.progress+1
                    fixture.ready=fixture.progress>=(fixture.steps or 3)
                end
                return fixture.ready,fixture.ready and 'ready' or 'pending'
            end,
            apply=function(session,mode)
                assert((mode==3 or fixture.runtime and mode==0) and fixture.ready and (pc.view==pawn or fixture.runtime),'cold entry must wait for selected palette readiness')
                fixture.session=session;fixture.lastMode=mode
                fixture.applies=fixture.applies+1;fixture.events[#fixture.events+1]='apply'
                session.camera.CameraComponent.visionApplied=true
                return true
            end,
            update=function()end,restore=function()end}
        local savedDofile=dofile
        dofile=function(path)
            if path:match('[/\\]vision%.lua$')then return mocked end
            return savedDofile(path)
        end
        local ok,why=pcall(savedDofile,'mod/Scripts/main.lua')
        dofile=savedDofile
        assert(ok,why)
    elseif options.weaponsFixture then
        local savedDofile=dofile
        local fixture=options.weaponsFixture
        local mocked={
            start=function(s,settings)
                s.weapons={mode=settings.mode,power=settings.power,impactSpeed=settings.impactSpeed,remaining=settings.charges==0 and math.huge or settings.charges}
                fixture.session=s;fixture.starts=(fixture.starts or 0)+1
                return s.weapons
            end,
            drop=function(s,_,_,velocity)
                fixture.attempts=(fixture.attempts or 0)+1
                if not savedDofile('mod/Scripts/weapon_settings.lua').hasGrenades(s.weapons.mode)or s.weapons.remaining==0 then return false,'no_grenades' end
                assert(velocity==nil,'main must leave grenade velocity to the independent drop adapter')
                fixture.drops=(fixture.drops or 0)+1
                if s.weapons.remaining~=math.huge then s.weapons.remaining=s.weapons.remaining-1 end
                return true,'grenade_dropped'
            end,
            shouldDetonate=function(s,speed,hit)
                assert(savedDofile('mod/Scripts/weapon_settings.lua').hasKamikaze(s.weaponMode)and speed>=0 and hit.Location)
                fixture.impacts=(fixture.impacts or 0)+1;fixture.closingSpeed=speed
                return fixture.fastImpact~=false
            end,
            detonate=function(s,pos)
                assert(savedDofile('mod/Scripts/weapon_settings.lua').hasKamikaze(s.weaponMode)and pos.X==0 and pos.Z==190 and camera:IsValid())
                fixture.detonations=(fixture.detonations or 0)+1;return true
            end,
            clear=function(s)fixture.clears=(fixture.clears or 0)+1;s.weapons=nil end,
            update=function()fixture.updates=(fixture.updates or 0)+1 end}
        dofile=function(path)
            if path:match('[/\\]drone_weapons%.lua$')then return mocked end
            if path:match('[/\\]config%.lua$')and options.collision==false then
                local config=savedDofile(path);config.collision=false;return config
            end
            return savedDofile(path)
        end
        local ok,why=pcall(savedDofile,'mod/Scripts/main.lua')
        dofile=savedDofile;assert(ok,why)
    elseif options.flashlightFixture then
        local savedDofile=dofile
        local fixture=options.flashlightFixture
        local mocked={
            set=function(s,enabled)
                if not s then return false,'fpv_required' end
                fixture.changes=(fixture.changes or 0)+1;s.flashlightEnabled=enabled;return true
            end,
            toggle=function(s)
                assert(s,'flashlight action requires active flight')
                fixture.toggles=(fixture.toggles or 0)+1;s.flashlightEnabled=not s.flashlightEnabled;return true
            end,
            restore=function(s)fixture.restores=(fixture.restores or 0)+1;s.flashlightEnabled=false end}
        dofile=function(path)
            if path:match('[/\\]drone_flashlight%.lua$')then return mocked end
            return savedDofile(path)
        end
        local ok,why=pcall(savedDofile,'mod/Scripts/main.lua')
        dofile=savedDofile;assert(ok,why)
    elseif options.pickupFixture then
        local savedDofile=dofile
        local original=savedDofile('mod/Scripts/world_experiments.lua')
        local wrapped={new=function(...)
            local api=original.new(...)
            local collect=api.collect
            api.collect=function(self,s,settings)
                local fixture=options.pickupFixture
                fixture.invocations=(fixture.invocations or 0)+1
                if fixture.distance then
                    s.worldExperiments.nearestArtifact=object({GetWorld=function()return world end,
                        K2_GetActorLocation=function()return {X=s.flight.p.x*100+fixture.distance*100,Y=s.flight.p.y*100,Z=s.flight.p.z*100}end})
                end
                local ok,message,code=collect(self,s,settings)
                fixture.lastCode=code;return ok,message,code
            end
            return api
        end}
        dofile=function(path)
            if path:match('[/\\]world_experiments%.lua$')then return wrapped end
            return savedDofile(path)
        end
        local ok,why=pcall(savedDofile,'mod/Scripts/main.lua')
        dofile=savedDofile;assert(ok,why)
    else dofile('mod/Scripts/main.lua')end
    dofile=priorDofile
    for _,code in ipairs(registrationAttempts)do assert(code~=255,'VK255 must never reach native registration, even inside pcall')end
    assert(#registrationAttempts==44,'startup must register only the 44 legacy fallback keys')
    for _,code in ipairs(registrationAttempts)do assert(legacyNativeKeys[code],'unsafe native registration attempted: '..code)end
    assert(keys[119] and keys[120] and not keys[255],'default fallback keys must remain safe')
end
local function tick() testClock=testClock+0.01;loop() end
local function toggle() keys[Key.F8]();tick() end
local function incomingHit(amount)
    local function param(value)return {get=function(self)return self.value end,set=function(self,v)self.value=v end,value=value}end
    local damage=param(amount)
    assert(hitHandlers['/Script/Stalker2.Obj:ReceiveDamage'])({get=function()return pawn end},damage,param(1),param(0),param(0),param(0),param(0),param(''))
    assert(damage.value==0 and pawn.hp==87,'reflected attack must not damage the body')
end
local function restored()
    assert(pc.move==0 and pc.look==0,'input lock leaked')
    assert(not pawn.disabled,'pawn input leaked');assert(hud.bShowHUD,'HUD not restored')
    assert(movement.MovementMode==1 and movement.ticking,'character movement state not restored')
    assert(not widgetsHidden,'game widgets not restored')
    assert(hudRoot.opacity==.75 and hudRoot.visibility==0,'native HUD root snapshot not restored')
    assert(not paused and timeDilation==1 and not pc.bShouldPerformFullTickWhenPaused and not pc.PrimaryActorTick.bTickEvenWhenPaused,'world freeze leaked')
end
reset();toggle();assert(spawned==1 and pc.view==camera and pawn.disabled);toggle();restored();assert(destroyed==1 and pc.view==pawn)
print('PASS toggle restores character and destroys camera')
reset({resetHUDOnCameraDestroy=true});toggle();toggle();restored()
print('PASS native HUD snapshot restores after camera/view teardown without opening Esc')
reset();failSpawn=true;toggle();restored();assert(spawned==0)
print('PASS spawn failure rolls back without locks')
reset();failView=true;toggle();restored();assert(destroyed==1)
print('PASS partial activation failure releases input despite failed view restoration')
reset();line='1 1 100000 1 1 32767 32767 65535 32767 0 0 0 1';toggle();restored();assert(spawned==0)
print('PASS high throttle refuses activation')
reset();toggle();testClock=testClock+0.3;tick();restored();assert(destroyed==1)
print('PASS stale controller returns to character')
reset();toggle();tick();local focusHeight=camera.position.Z
line='1 2 100000 1 0 32767 32767 65535 32767 0 0 0 2';tick()
assert(destroyed==0 and pc.view==camera and camera.position.Z==focusHeight,'focus loss holds FPV without applying throttle')
testClock=testClock+2;line='1 3 100000 1 0 32767 32767 65535 32767 0 0 0 3';tick()
assert(destroyed==0 and camera.position.Z==focusHeight,'background time must not move or exit FPV')
line='1 4 100000 1 1 32767 32767 0 32767 0 0 0 4';tick()
assert(destroyed==0 and camera.position.Z==focusHeight,'first resumed frame is rebased')
line='1 5 100000 1 1 32767 32767 0 32767 0 0 0 5';tick()
assert(camera.position.Z<focusHeight,'physics resumes on the next frame')
toggle();restored()
print('PASS focus loss holds FPV and resuming focus discards background time')
reset();toggle();pc.Pawn=object();tick();restored();assert(destroyed==1)
print('PASS pawn replacement tears down session')
reset();toggle();pc.Pawn=object({address=pawn:GetAddress()});tick();assert(destroyed==0 and pc.view==camera);toggle();restored();assert(pc.view==pawn)
print('PASS a new wrapper for the same UObject keeps the flight and restores view')
reset();toggle();line='';tick();assert(destroyed==0);testClock=testClock+0.3;tick();restored();assert(destroyed==1)
print('PASS transient missing sample is tolerated but the freshness deadline still applies')
reset();toggle()
local flightControllerLookups=controllerLookups
for i=2,3001 do
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',i,i)
    tick()
end
assert(camera.position.Z < -20000,'test must cross the old distance limit')
assert(destroyed==0 and pc.view==camera,'unlimited distance must retain the FPV session')
assert(controllerLookups==flightControllerLookups,'stable flight must not perform global controller scans for PDA/god mode')
toggle();restored()
print('PASS flight beyond 200 metres stays active with the default unlimited range')
reset();movement.velocity=-1000;toggle()
assert(movement.MovementMode==0 and movement.ticking and movement.velocity==0)
movement.MovementMode=3;movement.ticking=false;movement.velocity=-50;tick()
assert(movement.MovementMode==0 and movement.ticking and movement.velocity==0)
toggle();restored()
print('PASS character movement stays disabled while original native ticking survives falling/tick overrides and restores on exit')
reset();movement.MovementMode=6;movement.CustomMovementMode=2;movement.ticking=false
toggle();assert(not movement.ticking);movement.ticking=true;tick();assert(not movement.ticking);toggle()
assert(movement.MovementMode==6 and movement.CustomMovementMode==2 and not movement.ticking)
print('PASS custom movement and previously disabled tick restore exactly')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle();tick();local height=camera.position.Z
for i=2,102 do
    line=string.format('2 %d 100000 1 1 32767 32767 65535 32767 0 0 0 1 %d',i,i);tick()
end
assert(destroyed==0 and camera.position.Z==height,'menu must hold the camera without leaving FPV')
line='2 103 100000 1 1 32767 32767 0 32767 0 0 0 0 103';tick()
assert(destroyed==0 and camera.position.Z==height,'closing the menu discards its elapsed interval')
line='2 104 100000 1 1 32767 32767 0 32767 0 0 0 0 104';tick()
assert(destroyed==0 and camera.position.Z<height,'physics resumes on the following frame')
toggle();restored()
print('PASS weather menu holds FPV and resumes flight on close')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle();assert(audioLine:match('^1 %d+ 1 '),'audio must activate with FPV')
testClock=testClock+0.3;tick();assert(audioLine:match('^1 %d+ 0 '),'stale controller must silence audio')
restored()
print('PASS audio activates with FPV and becomes silent on controller timeout')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle();assert(widgetsHidden)
hud.bShowHUD=true;widgetsHidden=false;hudRoot.opacity=.75;hudRoot.visibility=0
for i=2,62 do
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',i,i);tick()
end
assert(not hud.bShowHUD and widgetsHidden and hideCalls>=2,'HUD regenerated by the game must be hidden again')
toggle();restored()
print('PASS regenerated native HUD is suppressed during flight and restores without global hide/show commands')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle();testClock=testClock+1.1
line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2';tick()
assert(destroyed==1,'a long freeze must exit rather than rotate through a second of unobserved input')
restored()
print('PASS frame stall over one second restores character')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({freeze=true});toggle();assert(not paused and timeDilation==0.0001)
local pausedHeight=camera.position.Z
for i=2,15 do
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',i,i);tick()
end
assert(camera.position.Z<pausedHeight and destroyed==0,'drone must advance while world time is frozen')
toggle();restored()
print('PASS near-freeze preserves drone physics and F8 restores time dilation')
reset({freeze=true});toggle();assert(timeDilation==0.0001)
local awayHeight=camera.position.Z
line='1 2 100000 1 0 32767 32767 65535 32767 0 0 0 2';tick()
assert(timeDilation==0.0001 and destroyed==0 and camera.position.Z==awayHeight,'focus loss retains near-freeze and holds FPV')
line='1 3 100000 1 1 32767 32767 0 32767 0 0 0 3';tick();toggle();restored()
print('PASS focus loss retains near-freeze until explicit FPV exit')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle();tick()
local heldZ=camera.position.Z
line='2 2 100000 1 1 32767 32767 0 32767 0 0 0 1 2'
environmentLine='100 weather Clearly';testClock=testClock+0.11;tick()
assert(destroyed==0 and camera.position.Z==heldZ and pc.view==camera,'weather must retain position despite clock rebase/stall/view replacement')
keys[Key.F9]();tick();assert(camera.position.Z==heldZ,'reset key must not reset flight while editing weather')
toggle();assert(destroyed==0,'pilot key must be ignored while editing weather')
line='2 3 100000 1 1 32767 32767 0 32767 0 0 0 0 3';tick()
assert(destroyed==0,'ignored menu actions must not replay after closing the menu')
toggle();restored()
print('PASS weather-induced clock/view changes and menu actions preserve flight without replay')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle();tick()
local sameTimeTransforms=camera.transforms
for _=1,10 do loop() end
assert(camera.transforms==sameTimeTransforms,'same world-time callbacks must not submit redundant camera transforms')
keys[Key.F9]();testClock=testClock+0.005;timeOffset=timeOffset+0.005;loop()
assert(camera.transforms==sameTimeTransforms+1 and camera.position.Z==200,'reset must apply even without a new physics sample')
line='2 2 100000 1 1 32767 32767 0 32767 0 0 0 1 2';tick()
local heldTransforms=camera.transforms
for _=1,10 do tick() end
assert(camera.transforms==heldTransforms,'held camera must not dirty its scene transform repeatedly')
environmentLine='300 flight 2 45';testClock=testClock+0.11;tick()
assert(camera.transforms==heldTransforms+1 and math.abs(camera.rotation.Pitch-45)<1e-8,'camera tilt edits must apply while the menu holds physics')
line='2 3 100000 1 1 32767 32767 0 32767 0 0 0 0 3';tick();toggle();restored()
print('PASS camera writes follow motion/reset/tilt changes and held callbacks leave the transform alone')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();environmentLine='400 weather Clearly';testClock=testClock+.11;tick()
assert(destroyed==0 and spawned==0)
line='2 2 100000 1 1 32767 32767 0 32767 0 0 0 0 2';toggle()
assert(consoleValues['r.Fog']==1 and consoleValues['r.VolumetricFog']==1 and consoleValues['r.LocalFogVolume']==1,
    'a Clear command before flight must not suppress the weather on entry')
line='2 3 100000 1 1 32767 32767 0 32767 0 0 0 1 3'
environmentLine='401 weather Clearly';testClock=testClock+.11;tick()
assert(consoleValues['r.Fog']==0 and consoleValues['r.VolumetricFog']==0 and consoleValues['r.LocalFogVolume']==0,
    'an explicit Clear command in flight must still remove fog')
line='2 4 100000 1 1 32767 32767 0 32767 0 0 0 0 4';tick();toggle();restored()
assert(consoleValues['r.Fog']==1 and consoleValues['r.VolumetricFog']==1 and consoleValues['r.LocalFogVolume']==1)
testClock=testClock+.61;line='2 5 100000 1 1 32767 32767 0 32767 0 0 0 0 5';toggle()
assert(consoleValues['r.Fog']==1 and consoleValues['r.VolumetricFog']==1 and consoleValues['r.LocalFogVolume']==1,
    'a previous flight Clear selection must not suppress a new flight weather')
assert(consoleValues['r.PostProcessing.DisableMaterials']==0,'flight must not disable weather materials')
toggle();restored()
print('PASS Clear selection is scoped to one flight and entry retains current weather')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({signal='1 50'});toggle()
local lost,descending,lastHeight=false,false,nil
for seq=2,700 do
    line=string.format('1 %d 100000 1 1 32767 32767 65535 32767 0 0 0 %d',seq,seq)
    tick()
    local values={};for token in (telemetryLine or ''):gmatch('%S+') do values[#values+1]=token end
    if values[16]=='1' then
        if not lost then lost=true;keys[Key.F9]() end
        if lastHeight and camera.position.Z<lastHeight then descending=true end
        lastHeight=camera.position.Z
        assert(camera.position.Z>200,'F9 must not rescue a lost link')
    end
    if destroyed>0 then break end
end
assert(lost and descending and destroyed==1,'loss must cut motors, allow falling, then exit')
restored();assert(pc.view==pawn)
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
print('PASS simulated loss ignores reset, visibly descends, exits and restores HUD/player/camera')
reset({reactionFixture=true,nativeHits=true,experiments='1 0 0 0 0 1 1 0 0 0'});toggle()
assert(not pawn.bCanBeDamaged and pawn.bHidden and pawn.collision)
for hit=1,4 do
    pawn.LastHitTimestampSeconds=hit
    incomingHit(25)
    testClock=testClock+.06
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',hit+1,hit+1);tick()
end
local fields={};for token in telemetryLine:gmatch('%S+')do fields[#fields+1]=tonumber(token)end
assert(fields[1]==5 and fields[14]==1 and fields[16]==1 and fields[18]==1 and fields[19]==0,
    'incoming reflected attack callbacks must zero drone HP and produce valid loss telemetry')
for seq=6,350 do
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',seq,seq);tick()
    if destroyed>0 then break end
end
assert(destroyed==1 and pawn.hp==87 and pawn.bCanBeDamaged and not pawn.bHidden and pawn.collision)
assert(pawn.position.X==0 and pawn.position.Y==0 and pawn.position.Z==200)
restored()
print('PASS experimental incoming attack callbacks break drone and return protected player state')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({reactionFixture=true,experiments='1 0 0 0 0 1 1 0 0 0'});toggle()
environmentLine='999 experiments 0 0 0 0 1 0 0 0 0';testClock=testClock+.11
line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2';tick()
assert(destroyed==1 and pawn.bCanBeDamaged and not pawn.bHidden and pawn.position.Z==200)
restored()
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
print('PASS changing reaction restores proxy and requires a clean new flight')
reset({god=true,reactionFixture=true,healthReserve=true,experiments='1 0 0 0 0 1 1 0 0 0'});toggle()
assert(not pawn.bCanBeDamaged and pawn.hp==87 and pawn.maximum==100,
    'FPV must leave normal HP and configured god mode intact')
-- Model the engine's delayed effective-stat normalization and collision stamp.
pawn.maximum=90;pawn.hp=78.3;pawn.LastHitTimestampSeconds=1;tick()
local reserveFields={};for token in telemetryLine:gmatch('%S+')do reserveFields[#reserveFields+1]=tonumber(token)end
assert(reserveFields[19]==100 and reserveFields[16]==0 and destroyed==0 and not pawn.bCanBeDamaged,
    'entry stat rebase and physical timestamp must not destroy the drone')
toggle();restored()
assert(pawn.hp==78.3 and pawn.maximum==90 and not pawn.bCanBeDamaged,
    'return must preserve unowned game stat changes and configured god mode')
print('PASS FPV entry survives delayed health normalization without a reserve or false attack')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({god=true,reactionFixture=true,healthReserve=true,experiments='1 0 0 0 0 1 1 0 0 0'})
failView=true;toggle();restored()
assert(pawn.hp==87 and pawn.maximum==100 and not pawn.bCanBeDamaged)
print('PASS failed entry preserves normal HP/maxHP and configured god mode')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({god=true,reactionFixture=true,healthReserve=true,experiments='1 0 0 0 0 1 1 0 0 0'});toggle()
environmentLine='1001 option god 0';testClock=testClock+.11
line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2';tick()
assert(not pawn.bCanBeDamaged and pc.view==camera,'menu edits must not open the active proxy damage gate')
toggle();restored();assert(pawn.bCanBeDamaged,'God off applies after proxy teardown')
print('PASS God off during flight keeps proxy shield and applies on return')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({reactionFixture=true,healthReserve=true,experiments='1 0 0 0 0 1 1 0 0 0'});toggle()
environmentLine='1002 option god 1';testClock=testClock+.11
line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2';tick()
assert(not pawn.bCanBeDamaged and pc.view==camera)
toggle();restored();assert(not pawn.bCanBeDamaged,'God on applies after proxy teardown')
print('PASS God on during flight applies on return without leaking the entry damage flag')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({freeze=true});toggle()
function pc:GetWorld()error('expired world accessor')end
tick();restored();assert(destroyed==1)
print('PASS a failed world accessor during teardown does not strand UI/input/visibility')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle()
function pc:IsValid()error('expired wrapper')end
tick();assert(movement.ticking and hud.bShowHUD and hudRoot.opacity==.75 and destroyed==1)
print('PASS expired controller validity cannot abort independent teardown steps')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({noclip=true,reactionFixture=true,experiments='1 0 0 0 0 1 1 0 0 0'});toggle();tick()
assert(destroyed==0 and collisionTraces==0 and pawn.position.Z==200,'noclip must bypass collision and keep body at entry despite saved reaction option')
assert(camera.position.Z<200,'noclip camera still moves')
toggle();restored();assert(pawn.position.Z==200)
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
print('PASS noclip moves camera through collision without moving player or enabling reaction proxy')
reset();toggle();pawn.position={X=900000,Y=200,Z=500};tick();restored()
assert(destroyed==1 and pawn.position.X==900000,'story teleport must terminate FPV without returning player home')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
print('PASS external teleport hands destination to gameplay and restores input')
reset();toggle();pawn.position={X=123000,Y=200,Z=500};testClock=testClock+.3;tick();restored()
assert(destroyed==1 and pawn.position.X==123000,'stale input same frame as teleport must preserve destination too')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({resources={ram=900,commit=9000}});toggle()
assert(spawned==1 and destroyed==0 and pc.view==camera,'low physical RAM with ample commit must permit F8 entry')
toggle();restored()
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({resources={ram=9000,commit=128}});toggle();restored();assert(spawned==0,'critical commit headroom must refuse FPV before spawn/input locking')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({resources={ram=574,commit=1801},distance=6});toggle()
for step=1,22 do
    testClock=testClock+.11;line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',step+1,step+1);tick()
end
assert(destroyed==0 and consoleValues['wp.Runtime.LoadingRangeTerrain']==10000,'v15 crash: leave FPV available but defer boosted loading under pressure')
toggle();restored();assert(consoleValues['wp.Runtime.LoadingRangeTerrain']==10000)
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({resources={ram=631,commit=734}});toggle()
assert(spawned==1 and destroyed==0,'v14 log: 734 MB commit must permit FPV independently of vision selection')
toggle();restored()
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
local objects={ram=9000,commit=9000,used=666168}
reset({resources=objects,distance=6});toggle();assert(spawned==1 and destroyed==0)
assert(consoleValues['wp.Runtime.LoadingRangeTerrain']==10000,'near-capacity object pool must not start the saved 5x loading burst')
objects.used=700000;testClock=testClock+.51
line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2';tick();restored();assert(destroyed==1,'object exhaustion protection must restore the player')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset({resources=objects});toggle();restored();assert(spawned==0,'critical UObject capacity must refuse entry before creating a camera')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
local memory={ram=9000,commit=9000}
reset({resources=memory});toggle();assert(spawned==1 and destroyed==0)
memory.commit=128;testClock=testClock+.51
line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2';tick();restored();assert(destroyed==1)
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS resource pressure refuses entry and independently restores an active flight')
print('PASS adapter contracts including commit and UObject-pressure teardown')

local prepared={steps=3}
local paletteSequence=1
local function paletteTick(focused)
 paletteSequence=paletteSequence+1
 line=string.format('1 %d 100000 1 %d 32767 32767 0 32767 0 0 0 %d',paletteSequence,focused==false and 0 or 1,paletteSequence)
 testClock=testClock+.05;tick() -- also crosses the ordinary character-mode idle interval
end
reset({visionFixture=prepared});toggle()
assert(prepared.calls==1 and spawned==0 and destroyed==0 and pc.view==pawn and hideCalls==0)
restored()
tick();assert(prepared.calls==2 and spawned==0 and pc.view==pawn and hideCalls==0);restored()
tick() -- pending entry must bypass the 50 ms character-mode idle throttle
assert(prepared.calls==3 and spawned==1 and pc.view==camera and pawn.disabled,
 string.format('cold entry calls=%d progress=%d ready=%s spawned=%d applies=%d',prepared.calls,prepared.progress,tostring(prepared.ready),spawned,prepared.applies))
assert(prepared.events[1]=='apply' and prepared.events[2]=='view' and prepared.applies==1)
toggle();restored();assert(prepared.ready and prepared.progress==3)
testClock=testClock+.61;line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2'
toggle()
assert(spawned==2 and pc.view==camera and prepared.applies==2 and prepared.progress==3,
 'repeat flight must consume the prepared palette without waiting for another build')
assert(prepared.events[3]=='apply' and prepared.events[4]=='view')
toggle();restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS palette adapter: once per frame, cold F8 stays unlocked until ready, apply precedes view and repeat flight reuses readiness')

local cancelled={steps=3}
reset({visionFixture=cancelled});toggle();assert(spawned==0)
toggle();assert(cancelled.progress==2 and spawned==0);restored()
paletteTick();paletteTick()
assert(cancelled.ready and spawned==0 and cancelled.applies==0 and pc.view==pawn and hideCalls==0,
 'second F8 must cancel pending entry even when its palette becomes ready later')
toggle();assert(spawned==1 and pc.view==camera)
toggle();restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS second F8 cancels pending entry without cancelling safe background preparation')

local unfocused={steps=3}
reset({visionFixture=unfocused});toggle();assert(spawned==0)
paletteTick(false);restored()
paletteTick(true);paletteTick(true)
assert(unfocused.ready and spawned==0 and unfocused.applies==0 and pc.view==pawn and hideCalls==0,
 'focus loss must cancel pending entry rather than entering automatically on refocus')
toggle();assert(spawned==1 and pc.view==camera)
toggle();restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS focus loss cancels pending entry; a fresh F8 is required after refocus')

-- Universal counters carry short presses and share the existing collect gates.
local pickup={}
local universal={bindings='117 119 120 1',actions='1 1 100000 1 0 0 0 0 1',pickupFixture=pickup}
reset(universal)
local actionSequence,pilotCounter,resetCounter,collectCounter=1,0,0,0
local function actionTick(focused,menu,connected,delay)
    actionSequence=actionSequence+1
    focused=focused~=false;connected=connected~=false
    line=string.format('2 %d 100000 %d %d 32767 32767 0 32767 0 0 0 %d %d',
        actionSequence,connected and 1 or 0,focused and 1 or 0,menu and 1 or 0,actionSequence)
    actionLine=string.format('1 %d 100000 %d 0 %d %d %d %d',actionSequence,focused and 1 or 0,
        pilotCounter,resetCounter,collectCounter,actionSequence)
    testClock=testClock+(delay or .051);tick()
end
keys[Key.F8]();tick()
assert(spawned==0,'first helper snapshot must prime and suppress a simultaneous native VK callback')
collectCounter=1;actionTick();assert(spawned==0 and not pickup.invocations,'collection requires an active FPV session')
pilotCounter=1;actionTick();assert(spawned==1 and pc.view==camera)
keys[Key.F8]();actionTick();assert(destroyed==0,'native VK callback must not duplicate a helper edge')
for _=1,10 do actionTick()end
local beforeReset=camera.position.Z
resetCounter=1;actionTick();assert(camera.position.Z>beforeReset+10,'universal reset must return the drone to launch')
collectCounter=2;actionTick()
assert(pickup.invocations==1 and pickup.lastCode=='detector_required','universal collect must use the existing detector gate')
for _=1,3 do actionTick()end
assert(pickup.invocations==1,'held collection input must not repeat')
pilotCounter=2;resetCounter=2;collectCounter=3;actionTick(true,true)
local menuHeight=camera.position.Z
assert(destroyed==0 and pickup.invocations==1,'menu actions must be consumed without executing')
pilotCounter=3;resetCounter=3;collectCounter=4;actionTick()
assert(destroyed==0 and pickup.invocations==1 and camera.position.Z==menuHeight,'first menu-resume frame must discard pending presses')
actionTick();assert(destroyed==0 and pickup.invocations==1,'held menu actions must not replay after resume')
collectCounter=5;actionTick();assert(pickup.invocations==2)
pilotCounter=4;resetCounter=4;collectCounter=6;actionTick(false)
pilotCounter=5;resetCounter=5;collectCounter=7;actionTick()
actionTick();assert(destroyed==0 and pickup.invocations==2,'background and held-on-refocus presses must be discarded')
collectCounter=8;actionTick();assert(pickup.invocations==3)
pilotCounter=6;actionTick();restored();assert(destroyed==1)
collectCounter=9;actionTick();assert(pickup.invocations==3,'collection after leaving FPV must not reach the pickup adapter')
pc.Pawn=nil;pilotCounter=7;actionTick();assert(spawned==1,'loading/no pawn must block pilot actions')
pc.Pawn=pawn;pilotCounter=8;actionTick();actionTick();assert(spawned==1,'loading-time presses must not replay after a pawn returns')
paused=true;pilotCounter=9;actionTick();assert(spawned==1,'native pause must block entry')
paused=false;actionTick();actionTick();assert(spawned==1)
pilotCounter=10;actionTick(true,false,true,.65);assert(spawned==2 and pc.view==camera)
pickup.distance=4;environmentLine='990 experiments 0 0 0 0 0 0 0 0 1';actionTick(true,false,true,.12)
collectCounter=10;actionTick()
assert(pickup.invocations==4 and pickup.lastCode=='artifact_too_far','universal collection retains the 3 m range gate')
environmentLine='991 bindings 0 0 0 0';actionTick(true,false,true,.12)
assert(universal.bindings=='0 0 0 0 0 0 0 0\n','universal bindings must save all eight actions')
pilotCounter=11;resetCounter=6;collectCounter=11;actionTick()
assert(destroyed==1 and pickup.invocations==4,'disabled actions ignore still-arriving old producer counters')
environmentLine='992 bindings 117 119 120';actionTick(true,false,true,.12)
assert(universal.bindings=='117 119 120 0 0 0 0 0\n','legacy binding command adds all unassigned actions')
collectCounter=12;actionTick();assert(pickup.invocations==4)
pilotCounter=12;actionTick();restored();assert(destroyed==2)
environmentLine='993 bindings 117 119 120 1';actionTick(true,false,true,.12)
actionTick(true,false,true,.65);pilotCounter=13;actionTick();assert(spawned==3)
pilotCounter=14;collectCounter=13;actionTick(true,false,false)
restored();assert(destroyed==3,'controller disconnect must restore the player')
pilotCounter=15;collectCounter=14;actionTick();actionTick()
assert(spawned==3 and pickup.invocations==4,'held inputs on reconnect must not start a new flight or collect')
actionTick(true,false,true,.65);pilotCounter=16;actionTick();assert(spawned==4)
collectCounter=15;actionTick();assert(pickup.invocations==5 and pickup.lastCode=='artifact_too_far')
pilotCounter=17;actionTick();restored()
-- The universal helper supports VK255 without passing it to native UE4SS.
reset({bindings='117 255 120 0',actions='1 1 100000 1 0 0 0 0 1'})
actionSequence,pilotCounter,resetCounter,collectCounter=1,0,0,0
assert(not keys[255]);tick()
pilotCounter=1;actionTick();assert(spawned==1 and pc.view==camera,'VK255 must enter FPV through the universal action channel')
actionTick();assert(destroyed==0,'holding the VK255 binding must not repeat')
pilotCounter=2;actionTick();restored();assert(destroyed==1,'a fresh VK255 helper edge must return to the player')
print('PASS native key registration is bounded while universal VK255 actions remain available')
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS universal action integration: short taps, no VK duplication/held repeat, menu/focus/loading/pause/disconnect recovery, four-value saves and existing collection gates')

local flashlight={}
reset({bindings='117 119 120 0 1001',actions='2 1 100000 1 0 0 0 0 0 1',flashlightFixture=flashlight})
local seq,pilots,lights=1,0,0
local function flashlightTick(menu,focused,connected,delay)
    seq=seq+1;focused=focused~=false;connected=connected~=false
    line=string.format('2 %d 100000 %d %d 32767 32767 0 32767 0 0 0 %d %d',seq,connected and 1 or 0,focused and 1 or 0,menu and 1 or 0,seq)
    actionLine=string.format('2 %d 100000 %d 0 %d 0 0 %d %d',seq,focused and 1 or 0,pilots,lights,seq)
    testClock=testClock+(delay or .051);tick()
end
tick();lights=1;flashlightTick();assert(not flashlight.toggles,'flashlight cannot act before FPV')
pilots=1;flashlightTick();assert(pc.view==camera)
lights=2;flashlightTick();assert(flashlight.toggles==1)
for _=1,4 do flashlightTick()end;assert(flashlight.toggles==1,'held lamp source cannot toggle repeatedly')
lights=3;flashlightTick(true);assert(flashlight.toggles==1)
lights=4;flashlightTick();flashlightTick();assert(flashlight.toggles==1,'menu press and held-on-close source cannot replay')
lights=5;flashlightTick();assert(flashlight.toggles==2)
environmentLine='994 flashlight 1';flashlightTick(false,true,true,.12);assert(not flashlight.changes,'Enabling the permission must not activate the light')
pilots=2;flashlightTick();restored();assert(flashlight.restores==1)
lights=6;flashlightTick();assert(flashlight.toggles==2)
pilots=3;flashlightTick(false,true,true,.65);assert(pc.view==camera)
flashlightTick(false,true,false);restored();assert(flashlight.restores==2,'disconnect always cleans up owned drone light')
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS fifth flashlight integration: active-flight gate, no held/menu replay, menu command and exit/disconnect teardown')

-- Exercise the real external-menu guard through main.lua. Its raw menu lease
-- must survive packet() rejecting disconnected USB input, and its counted lock
-- must compose with both cutscene locks and the separate flight locks.
local menuSequence=1
local function externalMenuTick(open,focused,connected,delay)
    menuSequence=menuSequence+1
    line=string.format('2 %d 100000 %d %d 32767 32767 0 32767 0 0 0 %d %d',
        menuSequence,connected and 1 or 0,focused and 1 or 0,open and 1 or 0,menuSequence)
    testClock=testClock+(delay or .061);tick()
end
reset();pc.bShowMouseCursor=false;pc.move=2;pc.look=3;tick()
externalMenuTick(true,true,false)
assert(spawned==0 and pc.move==3 and pc.look==4 and not pc.bShowMouseCursor,
    'F6 must lock control before focus transfers without changing the game viewport cursor mode')
for _=1,4 do externalMenuTick(true,false,false)end
assert(pc.move==3 and pc.look==4,'fresh disconnected menu updates must not stack locks')
externalMenuTick(false,true,false)
assert(pc.move==2 and pc.look==3 and not pc.bShowMouseCursor,'closing F6 preserves prior cutscene locks/cursor')
externalMenuTick(true,false,false)
testClock=testClock+.3;tick()
assert(pc.move==2 and pc.look==3 and not pc.bShowMouseCursor,'stale helper releases only the menu lock without USB')

reset();pc.bShowMouseCursor=false;toggle()
local heldHeight=camera.position.Z
assert(pc.move==1 and pc.look==1)
externalMenuTick(true,true,true)
assert(pc.move==2 and pc.look==2 and not pc.bShowMouseCursor and destroyed==0 and camera.position.Z==heldHeight,
    'external menu adds one lock to the flight and holds its camera immediately')
for _=1,4 do externalMenuTick(true,false,true)end
assert(pc.move==2 and pc.look==2 and destroyed==0)
externalMenuTick(false,true,true)
assert(pc.move==1 and pc.look==1 and not pc.bShowMouseCursor and camera.position.Z==heldHeight,
    'closing the external menu removes its own lock, keeps flight locks and discards the background interval')
toggle();restored();assert(destroyed==1)

reset();pc.bShowMouseCursor=false;toggle()
externalMenuTick(true,true,true)
externalMenuTick(true,false,false)
assert(destroyed==1 and pc.move==1 and pc.look==1 and not pawn.disabled,
    'disconnect returns the character while the still-visible external menu retains its own lock')
externalMenuTick(true,false,false)
assert(pc.move==1 and pc.look==1 and not pc.bShowMouseCursor)
testClock=testClock+.3;tick()
restored();assert(not pc.bShowMouseCursor and destroyed==1,
    'helper death after disconnect releases the remaining menu lock and restores cursor')
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS main external-menu integration: disconnected/focused raw packets, native/flight lock composition, close and stale-helper cleanup')

local weapons={}
local function assertAmmoTelemetry(enabled,remaining)
    local fields={};for token in (telemetryLine or ''):gmatch('%S+')do fields[#fields+1]=tonumber(token)end
    assert(#fields==26 and fields[1]==5 and fields[23]==(enabled and 1 or 0) and fields[24]==remaining,
        'live flight telemetry must publish actual finite/zero/unlimited weapon capacity')
end
local weaponOptions={armament='1 2 1 0 2',bindings='117 119 120 0 0 65 1001',
    actions='3 1 100000 1 0 0 0 0 0 0 0 1',weaponsFixture=weapons}
reset(weaponOptions)
local weaponSeq,weaponPilots,weaponResets,downPresses,dropPresses=1,0,0,0,0
local function weaponTick(menu,focused,connected,delay)
    weaponSeq=weaponSeq+1;focused=focused~=false;connected=connected~=false
    line=string.format('2 %d 100000 %d %d 32767 32767 0 32767 0 0 0 %d %d',
        weaponSeq,connected and 1 or 0,focused and 1 or 0,menu and 1 or 0,weaponSeq)
    actionLine=string.format('3 %d 100000 %d 0 %d %d 0 0 %d %d %d',
        weaponSeq,focused and 1 or 0,weaponPilots,weaponResets,downPresses,dropPresses,weaponSeq)
    testClock=testClock+(delay or .061);tick()
end
tick();downPresses=1;dropPresses=1;weaponTick()
assert(not weapons.attempts,'weapon and view actions require an active flight')
weaponPilots=1;weaponTick();assert(pc.view==camera and weapons.session.weapons.remaining==2)
weaponTick();assertAmmoTelemetry(true,2)
assert(not weapons.session.cameraDown)
downPresses=2;weaponTick();assert(weapons.session.cameraDown and math.abs(camera.rotation.Pitch+90)<1e-8 and camera.rotation.Roll==0)
local realFlight=dofile('mod/Scripts/flight.lua')
weapons.session.flight.q=realFlight.mul(realFlight.axis(0,0,1,.7),
    realFlight.mul(realFlight.axis(1,0,0,.6),realFlight.axis(0,1,0,.4)))
weaponTick()
local viewQ=realFlight.mul(realFlight.axis(0,0,1,math.rad(camera.rotation.Yaw)),
    realFlight.mul(realFlight.axis(0,1,0,-math.rad(camera.rotation.Pitch)),realFlight.axis(1,0,0,-math.rad(camera.rotation.Roll))))
local viewForward=realFlight.rotate(viewQ,{x=1,y=0,z=0})
local bodyDown=realFlight.rotate(weapons.session.flight.q,{x=0,y=0,z=-1})
for _,axis in ipairs({'x','y','z'})do assert(math.abs(viewForward[axis]-bodyDown[axis])<1e-6,'lower view must follow bank/pitch')end
local mount=realFlight.camera_position(weapons.session.flight,true,.12)
assert(math.abs(camera.position.X-mount.x*100)<1e-6 and math.abs(camera.position.Y-mount.y*100)<1e-6 and math.abs(camera.position.Z-mount.z*100)<1e-6,
    'lower camera location follows the body mount')
for _=1,4 do weaponTick()end
assert(weapons.session.cameraDown,'held source cannot toggle the downward camera repeatedly')
downPresses=3;weaponTick();assert(not weapons.session.cameraDown)
local forwardView=realFlight.camera_rotation(weapons.session.flight,25,false)
for _,axis in ipairs({'Pitch','Yaw','Roll'})do assert(math.abs(camera.rotation[axis]-forwardView[axis])<1e-6,'toggle back preserves forward mount')end
dropPresses=2;weaponTick();assert(weapons.drops==1 and weapons.session.weapons.remaining==1)
assertAmmoTelemetry(true,1)
for _=1,4 do weaponTick()end
assert(weapons.drops==1,'held grenade source must release only one charge')
dropPresses=3;downPresses=4;weaponTick(true)
assert(weapons.drops==1 and not weapons.session.cameraDown,'F6 blocks both new actions')
weaponTick();weaponTick();assert(weapons.drops==1 and not weapons.session.cameraDown,'menu-time presses never replay after close')
weaponResets=1;weaponTick();assert(weapons.session.weapons.remaining==1,'return-to-launch retains spent ammunition')
dropPresses=4;weaponTick();assert(weapons.drops==2 and weapons.session.weapons.remaining==0)
assertAmmoTelemetry(true,0)
dropPresses=5;weaponTick(false,true,true,.3);assert(weapons.drops==2 and weapons.attempts==3,'empty inventory reaches the adapter but cannot release another grenade')
local updates=weapons.updates;weaponPilots=2;weaponTick();restored()
assert(weapons.clears==1 and destroyed==1)
weaponTick();assert(weapons.updates>updates,'released-grenade update continues after leaving flight')
weaponPilots=3;weaponTick(false,true,true,.65)
assert(pc.view==camera and weapons.session.weapons.remaining==2 and not weapons.session.cameraDown,'new flight reloads charges and resets camera view')
environmentLine='1100 armament 2 1 1 0';weaponTick(false,true,true,.12);restored()
assert(destroyed==2 and weaponOptions.armament=='1 2 1.000000 1 0 30\n','changing loadout saves and exits the old flight')
weaponPilots=4;weaponTick(false,true,true,.65);assert(weapons.session.weapons.remaining==math.huge)
weaponTick();assertAmmoTelemetry(true,-1)
dropPresses=6;weaponTick();assert(weapons.drops==3 and weapons.session.weapons.remaining==math.huge)
dropPresses=7;downPresses=5;weaponTick(false,false);weaponTick();weaponTick()
assert(weapons.drops==3 and not weapons.session.cameraDown,'focus loss and recovery consume rather than replay weapon presses')
weaponTick(false,true,false);restored();assert(destroyed==3 and weapons.clears==3)

local kamikaze={}
reset({armament='1 1 2.25 0 3',bindings='117 119 120 0 0 65 66',weaponsFixture=kamikaze,noclip=true,collision=false})
toggle();assert(pc.view==camera and not kamikaze.session.noclip,'kamikaze ignores saved noclip without modifying its preference')
kamikaze.hit=true
line='1 2 100000 1 1 32767 32767 0 32767 0 0 0 2';tick()
restored();assert(kamikaze.detonations==1 and destroyed==1 and collisionTraces==2,
    'first impact runs one native detonation even with ordinary collision disabled')
line='1 3 100000 1 1 32767 32767 0 32767 0 0 0 3';tick();tick()
assert(kamikaze.detonations==1,'idle callbacks cannot replay the impact explosion')

local legacyWeapon={}
local landing={fastImpact=false}
local landingOptions={armament='1 1 1 0 3',weaponsFixture=landing,noclip=true,collision=false}
reset(landingOptions);toggle();landing.hit=true;tick()
assert(pc.view==camera and not landing.detonations and landing.impacts>0,'below-threshold collisions land without detonation')
environmentLine='1101 armament 1 1 0 3 60';testClock=testClock+.12;tick()
assert(pc.view==camera and landing.session.weapons.impactSpeed==60 and landingOptions.armament=='1 1 1.000000 0 3 60\n',
    'changing the impact threshold updates the active flight without exiting or changing its loadout')
landing.fastImpact=true;tick();restored();assert(landing.detonations==1)
reset({armament='1 2 1 0 1',bindings='117 119 120 0 0 65 66',weaponsFixture=legacyWeapon})
toggle();keys[65]();tick();assert(legacyWeapon.session.cameraDown)
keys[66]();tick();assert(legacyWeapon.drops==1,'safe legacy native keys route both appended actions')
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS main armament integration: camera edges, finite/unlimited ammunition, F9/new-flight ownership, menu/focus/disconnect guards, loadout commands, forced single impact and safe legacy dispatch')
local achievementStartup={achievementInit=true}
reset(achievementStartup)
assert(achievementStartup.achievementCalls==1 and pc.view==pawn and spawned==0,
    'achievement compatibility is ready at startup without opening a menu or starting FPV')
tick();tick();assert(achievementStartup.achievementCalls==1,'normal callbacks do not reinitialize achievement tracking')
assert(achievementStartup.achievementChecks==1,'live manager recovery runs once on the game thread')
toggle();toggle();restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS main achievement integration: startup before key callbacks/FPV, active manager check only on EngineTick, unchanged character control, no per-frame reinitialization')
local recoveryFixture={}
reset({recoveryFixture=recoveryFixture})
toggle();toggle();restored()
assert(recoveryFixture.begins==1 and recoveryFixture.active,'every normal FPV exit starts the five-second recovery')
local recoveryUpdates=recoveryFixture.updates
for i=1,80 do externalMenuTick(false,true,false,.06)end
assert(recoveryFixture.updates>recoveryUpdates and recoveryFixture.completed>=recoveryFixture.deadline and not recoveryFixture.active,
    'disconnected character-mode callbacks must renew protection and expire without opening F6')
restored()
local impactRecovery,impactWeapons={},{}
reset({recoveryFixture=impactRecovery,weaponsFixture=impactWeapons,armament='1 1 1 0 3',noclip=true,collision=false})
toggle();impactWeapons.hit=true;tick();restored()
assert(impactWeapons.detonations==1 and impactRecovery.begins==1 and impactRecovery.active,
    'kamikaze teardown leaves recovery alive after its camera and payload are removed')
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS main recovery integration: every exit and kamikaze, game-thread idle/disconnected renewal, five-second expiration and immediate player/input/camera restoration')

-- The real v4 consumer drives current flight state and camera effects, not only
-- parser flags. Press counters and held bits remain separate contracts.
local binary={runtime=true,steps=1}
local binaryOptions={visionFixture=binary,actionModes='1 1 1 0',bindings='117 119 120 0 0 65 66 67',
    actions='4 1 100000 1 0 0 0 0 0 0 0 0 0 1'}
reset(binaryOptions)
local binarySeq,binaryPilots,binaryVision,binaryDown,binaryHeld=1,0,0,0,0
local function binaryTick(menu,focused,advance,delay,connected)
    binarySeq=binarySeq+1;focused=focused~=false
    if advance~=false then
        line=string.format('2 %d 100000 %d %d 32767 32767 0 32767 0 0 0 %d %d',
            binarySeq,connected==false and 0 or 1,focused and 1 or 0,menu and 1 or 0,binarySeq)
    end
    actionLine=string.format('4 %d 100000 %d 0 %d 0 0 0 %d 0 %d %d %d',
        binarySeq,focused and 1 or 0,binaryPilots,binaryDown,binaryVision,binaryHeld,binarySeq)
    testClock=testClock+(delay or .061);tick()
end
tick();binaryPilots=1;binaryTick()
assert(pc.view==camera and binary.lastMode==0 and not binary.session.cameraDown,'hold vision starts off; forward camera is default')
binaryDown=1;binaryVision=1;binaryHeld=160;binaryTick()
assert(binary.lastMode==3 and binary.session.visionEnabled and binary.session.cameraDown)
local downFields={};for token in telemetryLine:gmatch('%S+')do downFields[#downFields+1]=tonumber(token)end
assert(downFields[25]==1 and math.abs(camera.rotation.Pitch+90)<1e-8,'held camera drives down telemetry and actual view')
local applied=binary.applies;binaryTick();assert(binary.applies==applied,'held states do not reapply unchanged effects')
binaryHeld=0;binaryTick()
assert(binary.lastMode==0 and not binary.session.cameraDown,'release returns to forward camera and disables selected vision')
binaryHeld=160;binaryTick();binaryTick(true)
assert(binary.lastMode==0 and not binary.session.cameraDown,'menu opening releases held actions immediately')
binaryHeld=0;binaryTick();binaryTick();binaryHeld=160;binaryTick()
assert(binary.lastMode==3 and binary.session.cameraDown)
binaryTick(false,false);assert(binary.lastMode==0 and not binary.session.cameraDown,'focus loss releases held actions')
binaryHeld=0;binaryTick();binaryTick()
environmentLine='1201 actionmode vision 0';binaryTick(false,true,true,.12)
assert(binaryOptions.actionModes=='2 0 0 0 0 0 1 0 0\n' and binary.lastMode==3,'mode preference persists without changing selected palette')
binaryVision=2;binaryTick();assert(binary.lastMode==0)
binaryTick();assert(binary.lastMode==0,'vision toggle does not repeat while its source remains held')
binaryVision=3;binaryTick();assert(binary.lastMode==3,'toggle restores the selected palette')
environmentLine='1202 bindings 117 119 120 0 0 0 66 67';binaryHeld=32;binaryTick(false,true,true,.12)
assert(not binary.session.cameraDown and binaryOptions.bindings=='117 119 120 0 0 0 66 67\n','unbinding camera clears its held state')

-- Axis-only delay is tolerated only with a fresh independent helper heartbeat.
local before={X=camera.position.X,Y=camera.position.Y,Z=camera.position.Z}
binaryTick(false,true,false,.30)
assert(pc.view==camera and binary.session.inputPaused and camera.position.X==before.X and camera.position.Y==before.Y and camera.position.Z==before.Z,
    'short axis-writer delay freezes flight rather than ejecting or integrating old controls')
binaryTick(false,true,false,.20);assert(pc.view==camera and binary.session.inputPaused)
binaryTick();assert(pc.view==camera and not binary.session.inputPaused and camera.position.X==before.X and camera.position.Z==before.Z,
    'first resumed input frame has zero physics delta')
binaryTick(false,true,true,nil,false);restored();assert(destroyed==1,'real controller disconnect still exits immediately')
binaryTick(false,true,true,.65);binaryTick();binaryPilots=2;binaryTick();assert(pc.view==camera)
binaryTick(false,true,false,.30);binaryTick(false,true,false,.40);binaryTick(false,true,false,.40)
restored();assert(destroyed==2,'fresh actions cannot extend axis wait beyond750ms')
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS main v4 hold/toggle integration: camera/selected vision, telemetry, focus/menu/unbind release, persisted modes, frozen axis wait, zero-delta resume and bounded disconnect')

local heldLamp={}
reset({flashlightFixture=heldLamp,actionModes='1 0 0 1',bindings='117 119 120 0 1001 0 0 0',
    actions='4 1 100000 1 0 0 0 0 0 0 0 0 0 1'})
local lampSeq,lampPilots,lampHeld=1,0,0
local function lampTick(menu,focused)
    lampSeq=lampSeq+1;focused=focused~=false
    line=string.format('2 %d 100000 1 %d 32767 32767 0 32767 0 0 0 %d %d',lampSeq,focused and 1 or 0,menu and 1 or 0,lampSeq)
    actionLine=string.format('4 %d 100000 %d 0 %d 0 0 1 0 0 0 %d %d',lampSeq,focused and 1 or 0,lampPilots,lampHeld,lampSeq)
    testClock=testClock+.061
    tick()
end
tick();lampPilots=1;lampTick();assert(pc.view==camera)
lampHeld=16;lampTick();assert(heldLamp.changes==1 and not heldLamp.toggles)
lampTick();assert(heldLamp.changes==1,'hold light stays on without repeated engine writes')
lampHeld=0;lampTick();assert(heldLamp.changes==2)
lampHeld=16;lampTick();lampTick(true);assert(heldLamp.changes==4,'menu releases held flashlight')
lampHeld=0;lampTick();lampTick();lampHeld=16;lampTick();lampTick(false,false)
assert(heldLamp.changes==6,'focus loss releases flashlight')
lampHeld=0;lampTick();lampTick();lampPilots=2;lampTick();restored();assert(heldLamp.restores==1)
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS held flashlight integration: native calls only on state changes, release on key/menu/focus and teardown')

local automatic={runtime=true,steps=1}
reset({visionFixture=automatic,actionModes='2 0 0 0 0 0 0 0 1',bindings='117 119 120 0 0 0 0 0'})
toggle();assert(pc.view==camera and automatic.lastMode==3 and automatic.session.visionEnabled,
    'unassigned selected vision turns on before the first FPV frame even with persisted Hold')
toggle();restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS selected vision automatically starts without a binding regardless of persisted Hold mode')

local repeating={}
reset({weaponsFixture=repeating,armament='1 2 1 0 0',bindings='117 119 120 0 0 0 66 0',
    actionModes='2 0 1 1 0 0 0 1 0',actions='5 1 100000 1 0 0 0 0 0 0 0 0 0 1'})
local holdSeq,holdPilotCounter=1,0
local function holdTick(mask,menu,focused,delay,throttle)
    holdSeq=holdSeq+1;focused=focused~=false
    line=string.format('2 %d 100000 1 %d 32767 32767 %d 32767 0 0 0 %d %d',
        holdSeq,focused and 1 or 0,throttle or 0,menu and 1 or 0,holdSeq)
    actionLine=string.format('5 %d 100000 %d 0 %d 0 0 0 0 0 0 %d %d',
        holdSeq,focused and 1 or 0,holdPilotCounter,mask,holdSeq)
    testClock=testClock+(delay or .06);tick()
end
tick();holdTick(2);assert(pc.view==camera and repeating.starts==1 and repeating.session.pilotHoldOwned)
holdTick(66);assert(repeating.drops==1)
holdTick(66);assert(repeating.drops==1,'held grenade interval bounds repeated release')
holdTick(66,nil,nil,.26);assert(repeating.drops==2 and repeating.starts==1,'held pilot does not toggle on every packet')
local startPosition=repeating.session.origin
repeating.session.flight.p={x=70,y=80,z=90}
holdTick(70,nil,nil,nil,65535)
assert(camera.position.X==startPosition.x*100 and camera.position.Z==startPosition.z*100,'held return-to-launch parks the drone')
holdTick(70,nil,nil,nil,65535)
assert(camera.position.Z==startPosition.z*100,'held reset prevents integration while throttle is raised')
holdTick(0);restored();assert(pc.view==pawn and destroyed==1,'pilot release exits its held session')
holdTick(2);assert(repeating.starts==1,'a fresh held press waits during the rapid-toggle cooldown')
for _=1,9 do holdTick(2)end
assert(repeating.starts==2 and pc.view==camera,'continuing that owned press enters once after the cooldown')
holdTick(0);restored()
holdTick(2,true);holdTick(2);holdTick(2,nil,nil,.7)
assert(pc.view==pawn and repeating.starts==2,'holding across a menu never re-enters automatically')
holdTick(0);holdTick(2);assert(repeating.starts==3 and pc.view==camera)
holdTick(0);restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS v5 main Hold integration: pilot ownership/release, reset parking, grenade intervals, menu safety and fresh re-entry')

local approaching={distance=10}
reset({pickupFixture=approaching,experiments='1 0 0 0 0 0 0 0 0 1',bindings='117 119 120 65',
    actionModes='2 0 0 0 1 0 0 0 0',actions='5 1 100000 1 0 0 0 0 0 0 0 0 0 1'})
holdSeq=1;tick();holdPilotCounter=1;holdTick(0)
holdTick(8);assert(approaching.invocations==1 and approaching.lastCode=='artifact_too_far')
holdTick(8);assert(approaching.invocations==1)
approaching.distance=2;holdTick(8,nil,nil,.36)
assert(approaching.invocations==2 and approaching.lastCode~='artifact_too_far','held collection retries with the current drone/artifact distance')
holdTick(8,true);holdTick(8);holdTick(8,nil,nil,.4)
assert(approaching.invocations==2,'menu interruption requires release before collection resumes')
holdTick(0);holdTick(8);assert(approaching.invocations==3)
holdPilotCounter=2;holdTick(0);restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS held artifact collection integration: bounded retries on approach, existing distance/detector gates and menu release')

local pendingHold={runtime=true,steps=20}
reset({visionFixture=pendingHold,actionModes='2 0 1 0 0 0 0 0 0',bindings='117 119 120 0 0 0 0 0',
    actions='5 1 100000 1 0 0 0 0 0 0 0 0 0 1'})
holdSeq=1;holdPilotCounter=0;tick();holdTick(2);assert(spawned==0,'held entry waits for vision readiness')
holdTick(0)
for _=1,25 do holdTick(0)end
assert(spawned==0 and pc.view==pawn,'releasing pilot cancels pending entry while prewarm finishes')
restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS held pilot release cancels pending vision preparation without a later unsolicited FPV entry')

local delayedView={runtime=true,steps=1}
reset({visionFixture=delayedView,actionModes='2 0 0 0 0 0 1 0 0',bindings='117 119 120 0 0 3018 0 0',
    actions='5 1 100000 1 0 0 0 0 0 0 0 0 0 1'})
local delayedSeq,delayedPilots=1,0
local function delayedTick(mask,advance,delay,menu,focused)
    delayedSeq=delayedSeq+1;focused=focused~=false
    if advance~=false then
        line=string.format('2 %d 100000 1 %d 32767 32767 0 32767 0 0 0 %d %d',
            delayedSeq,focused and 1 or 0,menu and 1 or 0,delayedSeq)
    end
    actionLine=string.format('5 %d 100000 %d 0 %d 0 0 0 0 0 0 %d %d',
        delayedSeq,focused and 1 or 0,delayedPilots,mask,delayedSeq)
    testClock=testClock+(delay or .06);tick()
end
tick();delayedPilots=1;delayedTick(0);delayedTick(32)
assert(delayedView.session.cameraDown)
local height=camera.position.Z
delayedTick(32,false,.30);assert(delayedView.session.cameraDown and delayedView.session.inputPaused and camera.position.Z==height,
    'brief axis delay must keep an existing CH-held lower view without integrating stale sticks')
delayedTick(32,false,.20);assert(delayedView.session.cameraDown and camera.position.Z==height)
delayedTick(32);assert(delayedView.session.cameraDown and not delayedView.session.inputPaused and camera.position.Z==height,
    'first resumed axis frame remains zero-delta and the continuously held CH stays active')
delayedTick(0,false,.30);assert(not delayedView.session.cameraDown,'physical release remains observable through the independent action channel')
delayedTick(32,false,.06);assert(not delayedView.session.cameraDown,'new press during the suspended frame cannot activate a view')
delayedTick(32);assert(not delayedView.session.cameraDown,'paused presses require a physical release')
delayedTick(0);delayedTick(32);assert(delayedView.session.cameraDown)
paused=true;delayedTick(32,false,.30);assert(not delayedView.session.cameraDown,'actual native game pause interrupts hold even during axis delay')
paused=false;delayedTick(32);assert(not delayedView.session.cameraDown)
delayedTick(0);delayedTick(32);assert(delayedView.session.cameraDown)
delayedTick(32,true,nil,true);assert(not delayedView.session.cameraDown,'an actual menu still clears hold')
delayedTick(0);delayedTick(0);delayedPilots=2;delayedTick(0);restored()
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS held lower-camera delay regression: CH continuity, frozen physics, zero-delta resume, observed release, no new suspended press and real pause/menu gates')

local multi={}
reset({weaponsFixture=multi,armament='1 3 2.25 1 2 30',bindings='117 119 120 0 0 0 66 0',noclip=true,collision=false,
    actionModes='2 0 0 0 0 0 0 1 0',actions='5 1 100000 1 0 0 0 0 0 0 0 0 0 1'})
holdSeq=1;holdPilotCounter=0;tick();holdPilotCounter=1;holdTick(0)
assert(pc.view==camera and not multi.session.noclip and multi.session.weaponMode==3)
holdTick(64);holdTick(64,nil,nil,.26);assert(multi.drops==2 and multi.session.weapons.remaining==0)
assertAmmoTelemetry(true,0)
multi.hit=true;holdTick(0);restored()
assert(multi.detonations==1 and multi.clears==1 and destroyed==1,'empty combined drone still detonates once with saved ordinary collision/noclip disabled')
local updates=multi.updates;holdTick(0);assert(multi.updates>updates and multi.detonations==1,'projectile callback survives combined-drone teardown without replaying impact')
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS main combined mode: held finite grenade drops, OSD empty count, forced impact collision, single explosion after empty stock and teardown/projectile continuity')

local reloaded={inspectPreferences=true,bindings='117 119 120 0 0 0 0 0',actionModes='2 0 0 0 0 0 0 0 0'}
reset(reloaded)
reloaded.bindings='117 65 120 1001 3001 3018 66 67\n'
reloaded.actionModes='2 0 1 0 1 1 1 1 1\n'
assert(reloaded.preferenceCommand('FPVBindingsReload') and reloaded.preferenceCommand('FPVActionModesReload'))
local latest=reloaded.preferenceSnapshot()
assert(latest.keys[2]==65 and latest.keys[8]==67 and latest.actionModes.pilot==1 and latest.actionModes.cameraDown==1)
assert((reloaded.preferenceWrites or 0)==0,'helper notifications must never write stale preferences over newer committed files')
assert(reloaded.preferenceCommand('FPVBindingsReload') and reloaded.preferenceCommand('FPVActionModesReload'))
local same=reloaded.preferenceSnapshot()
assert(same.keys==latest.keys and same.actionModes==latest.actionModes,'duplicate reloads remain idempotent rather than releasing/replacing current actions')
reloaded.bindings='1 1 2 3';reloaded.actionModes='2 0 0'
assert(not reloaded.preferenceCommand('FPVBindingsReload') and not reloaded.preferenceCommand('FPVActionModesReload'))
same=reloaded.preferenceSnapshot();assert(same.keys==latest.keys and same.actionModes==latest.actionModes,'malformed file must retain current configuration')
reloaded.bindings=nil;reloaded.actionModes=nil
assert(not reloaded.preferenceCommand('FPVBindingsReload') and not reloaded.preferenceCommand('FPVActionModesReload'))
reloaded.bindings='117 66 120 1002 3002 3019 65 68';reloaded.actionModes='2 1 0 1 0 0 0 0 0'
assert(reloaded.preferenceCommand('FPVBindingsReload') and reloaded.preferenceCommand('FPVActionModesReload'))
latest=reloaded.preferenceSnapshot();assert(latest.keys[2]==66 and latest.keys[8]==68 and latest.actionModes.menu==1 and latest.actionModes.reset==1)
assert((reloaded.preferenceWrites or 0)==0)
io.open,os.clock,os.time,package.loadlib,os.remove=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove
print('PASS helper preference reload notifications: latest committed files, zero stale writes, duplicate idempotence and invalid/missing retention')

for _,mode in ipairs({0,1})do
    local lamp={}
    local permissions={inspectPreferences=true,flashlightFixture=lamp,features='1 0 0\n',
        bindings='117 119 120 0 1001 3018 0 0',actionModes='2 0 0 0 0 '..mode..' '..mode..' 0 0',
        actions='5 1 100000 1 0 0 0 0 0 0 0 0 0 1'}
    reset(permissions)
    local seq,pilots,light,down,mask=1,0,0,0,0
    local function permissionTick(delay)
        seq=seq+1
        line=string.format('2 %d 100000 1 1 32767 32767 0 32767 0 0 0 0 %d',seq,seq)
        actionLine=string.format('5 %d 100000 1 0 %d 0 0 %d %d 0 0 %d %d',seq,pilots,light,down,mask,seq)
        testClock=testClock+(delay or .061);tick()
    end
    local command=permissions.preferenceCommand
    assert(not permissions.preferenceSnapshot().features.flashlightEnabled and not permissions.preferenceSnapshot().features.cameraDownEnabled,
        'Both permissions reload before flight')
    tick();pilots=1;permissionTick();assert(pc.view==camera)
    local active=permissions.preferenceSnapshot().session
    light,down,mask=1,1,48;permissionTick()
    assert(not active.cameraDown and not active.flashlightEnabled and not lamp.toggles,'Disabled permission rejects toggle and held sources')
    mask=0;permissionTick()
    assert(command('FPVFlashlight 1')and command('FPVCameraDown 1'))
    assert(permissions.features=='1 1 1\n'and not active.cameraDown and not active.flashlightEnabled,
        'Enabling permissions persists without actuating either feature')
    light,down,mask=2,2,48;permissionTick()
    assert(active.cameraDown and active.flashlightEnabled,'A fresh assigned input activates enabled features')
    assert(command('FPVFlashlight 0')and command('FPVCameraDown 0'))
    assert(not active.cameraDown and not active.flashlightEnabled and permissions.features=='1 0 0\n',
        'Disabling either active feature turns it off and persists the permission')
    light,down=3,3;permissionTick()
    assert(not active.cameraDown and not active.flashlightEnabled,'Further presses or continuous hold remain blocked')
    mask=0;permissionTick();pilots=2;permissionTick();restored()
    assert(command('FPVFlashlight 1')and command('FPVCameraDown 1'),'Permissions can be edited while not flying')
    assert(not permissions.preferenceSnapshot().session and permissions.features=='1 1 1\n')
    pilots=3;permissionTick(.7);assert(pc.view==camera)
    active=permissions.preferenceSnapshot().session
    assert(not active.cameraDown and not active.flashlightEnabled,'New flight keeps enabled features inactive until input')
    light,down,mask=4,4,48;permissionTick();assert(active.cameraDown and active.flashlightEnabled)
    mask=0;permissionTick();pilots=4;permissionTick();restored()
end
io.open,os.clock,os.time,package.loadlib,os.remove,os.rename=rawOpen,rawClock,rawTime,rawLoadlib,rawRemove,rawRename
print('PASS saved camera/light permissions: toggle and Hold input gates, immediate off, no auto-activation, idle edits and next-flight behavior')
