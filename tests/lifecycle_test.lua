-- Adapter contract tests only; mocks do not establish game compatibility.
package.path='mod/Scripts/?.lua;'..package.path
local testClock=10
local rawOpen,rawClock,rawTime=io.open,os.clock,os.time
local line,loop,keys,audioLine,widgetsHidden,hideCalls
local pc,pawn,camera,hud,world,movement
local failSpawn,failView,spawned,destroyed
local paused,frozenTime,timeOffset,timeDilation
local environmentLine
local function object(t) t=t or {};function t:IsValid() return not self.invalid end;function t:GetAddress() return self.address or self end;return t end
local function reset(options)
    options=options or {};paused=false;timeOffset=0;timeDilation=1;environmentLine=nil
    testClock=10;keys={};spawned=0;destroyed=0;failSpawn=false;failView=false;widgetsHidden=false;hideCalls=0
    hud=object({bShowHUD=true})
    movement=object({MovementMode=1,CustomMovementMode=0,ticking=true,
        IsComponentTickEnabled=function(s) return s.ticking end,
        SetComponentTickEnabled=function(s,b) s.ticking=b end,
        StopMovementImmediately=function(s) s.velocity=0 end,
        DisableMovement=function(s) s.MovementMode=0 end,
        SetMovementMode=function(s,m,custom) s.MovementMode=m;s.CustomMovementMode=custom end})
    pawn=object({CharacterMovement=movement,disabled=false,DisableInput=function(s) s.disabled=true end,EnableInput=function(s) s.disabled=false end})
    pawn.position={X=0,Y=0,Z=200};pawn.bHidden=false;pawn.bCanBeDamaged=true;pawn.collision=true
    function pawn:K2_GetActorLocation() return self.position end
    function pawn:K2_SetActorLocation(p) self.position=p end
    function pawn:GetActorEnableCollision() return self.collision end
    function pawn:SetActorEnableCollision(v) self.collision=v end
    function pawn:SetActorHiddenInGame(v) self.bHidden=v end
    world=object({SpawnActor=function()
        if failSpawn then error('injected spawn failure') end
        spawned=spawned+1
        camera=object({transforms=0,CameraComponent=object({SetFieldOfView=function() end}),
            SetTickableWhenPaused=function() end,
            SetActorEnableCollision=function() end,
            K2_DestroyActor=function(s) destroyed=destroyed+1;s.invalid=true end,
            K2_SetActorLocationAndRotation=function(s,pos,rotation) s.position=pos;s.rotation=rotation;s.transforms=s.transforms+1 end})
        return camera
    end})
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
        SetViewTargetWithBlend=function(s,v) if failView then error('injected view failure') end;s.view=v end})
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
    local system=object({SphereTraceSingle=function() return false end,
        ExecuteConsoleCommand=function(_,_,command)
            if command=='XHideAllWidget' then widgetsHidden=true;hideCalls=hideCalls+1
            elseif command=='XShowAllWidget' then widgetsHidden=false
            elseif command:match('^XForceWeather ') then
                timeOffset=timeOffset+100;testClock=testClock+2;pc.view=pawn
            end
        end})
    package.loaded.UEHelpers={GetPlayerController=function() return pc end,GetKismetSystemLibrary=function() return system end}
    StaticFindObject=function(name) return name:find('GameplayStatics') and gameplay or object() end
    Key={F8=119,F9=120};RegisterKeyBind=function(k,fn) keys[k]=fn end
    LoopAsync=function(_,fn) loop=fn end;ExecuteInGameThread=function(fn) fn() end
    os.clock=function() return testClock end;os.time=function() return 100 end
    io.open=function(path,mode)
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
        for _,key in ipairs({'freeze','collision','alternate'}) do
            if path:find(key..'-settings.txt',1,true) then
                return {read=function() return options[key] and '1' or '0' end,close=function() end}
            end
        end
        if path:find('input.txt',1,true) then return {read=function() return line end,close=function() end} end
        if path:find('audio.txt',1,true) then return {write=function(_,text) audioLine=text end,close=function() end} end
        if path:find('telemetry.txt',1,true) or path:find('performance.txt',1,true) then
            return {write=function() return true end,close=function() end}
        end
        return rawOpen(path,mode)
    end
    line='1 1 100000 1 1 32767 32767 0 32767 0 0 0 1'
    dofile('mod/Scripts/main.lua')
end
local function tick() testClock=testClock+0.01;loop() end
local function toggle() keys[Key.F8]();tick() end
local function restored()
    assert(pc.move==0 and pc.look==0,'input lock leaked')
    assert(not pawn.disabled,'pawn input leaked');assert(hud.bShowHUD,'HUD not restored')
    assert(movement.MovementMode==1 and movement.ticking,'character movement state not restored')
    assert(not widgetsHidden,'game widgets not restored')
    assert(not paused and timeDilation==1 and not pc.bShouldPerformFullTickWhenPaused and not pc.PrimaryActorTick.bTickEvenWhenPaused,'world freeze leaked')
end
reset();toggle();assert(spawned==1 and pc.view==camera and pawn.disabled);toggle();restored();assert(destroyed==1 and pc.view==pawn)
print('PASS toggle restores character and destroys camera')
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
for i=2,3001 do
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',i,i)
    tick()
end
assert(camera.position.Z < -20000,'test must cross the old distance limit')
assert(destroyed==0 and pc.view==camera,'unlimited distance must retain the FPV session')
toggle();restored()
print('PASS flight beyond 200 metres stays active with the default unlimited range')
reset();movement.velocity=-1000;toggle()
assert(movement.MovementMode==0 and not movement.ticking and movement.velocity==0)
movement.MovementMode=3;movement.ticking=true;movement.velocity=-50;tick()
assert(movement.MovementMode==0 and not movement.ticking and movement.velocity==0)
toggle();restored()
print('PASS character physics stays frozen even if game requests falling, and restores on exit')
reset();movement.MovementMode=6;movement.CustomMovementMode=2;movement.ticking=false
toggle();toggle()
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
hud.bShowHUD=true;widgetsHidden=false
for i=2,62 do
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',i,i);tick()
end
assert(not hud.bShowHUD and widgetsHidden and hideCalls>=2,'HUD regenerated by the game must be hidden again')
toggle();restored()
print('PASS regenerated HUD is hidden during flight and game widgets return on exit')
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
toggle();restored()
print('PASS weather-induced clock/view changes and menu reset key preserve flight')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
reset();toggle();tick()
local sameTimeTransforms=camera.transforms
for _=1,10 do loop() end
assert(camera.transforms==sameTimeTransforms,'same world-time callbacks must not submit redundant camera transforms')
keys[Key.F9]();loop()
assert(camera.transforms==sameTimeTransforms+1 and camera.position.Z==200,'reset must apply even without a new physics sample')
line='2 2 100000 1 1 32767 32767 0 32767 0 0 0 1 2';tick()
local heldTransforms=camera.transforms
for _=1,10 do tick() end
assert(camera.transforms==heldTransforms,'held camera must not dirty its scene transform repeatedly')
environmentLine='300 flight 2 45';testClock=testClock+0.11;tick()
assert(camera.transforms==heldTransforms+1 and math.abs(camera.rotation.Pitch-45)<1e-8,'camera tilt edits must apply while the menu holds physics')
toggle();restored()
print('PASS camera writes follow motion/reset/tilt changes and held callbacks leave the transform alone')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
print('20 adapter contract tests passed')
