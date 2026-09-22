-- Adapter contract tests only; mocks do not establish game compatibility.
package.path='mod/Scripts/?.lua;'..package.path
local testClock=10
local rawOpen,rawClock,rawTime=io.open,os.clock,os.time
local line,loop,keys,audioLine,widgetsHidden,hideCalls
local pc,pawn,camera,hud,world,movement
local failSpawn,failView,spawned,destroyed
local paused,frozenTime,timeOffset
local function object(t) t=t or {};function t:IsValid() return not self.invalid end;function t:GetAddress() return self.address or self end;return t end
local function reset(options)
    options=options or {};paused=false;timeOffset=0
    testClock=10;keys={};spawned=0;destroyed=0;failSpawn=false;failView=false;widgetsHidden=false;hideCalls=0
    hud=object({bShowHUD=true})
    movement=object({MovementMode=1,CustomMovementMode=0,ticking=true,
        IsComponentTickEnabled=function(s) return s.ticking end,
        SetComponentTickEnabled=function(s,b) s.ticking=b end,
        StopMovementImmediately=function(s) s.velocity=0 end,
        DisableMovement=function(s) s.MovementMode=0 end,
        SetMovementMode=function(s,m,custom) s.MovementMode=m;s.CustomMovementMode=custom end})
    pawn=object({CharacterMovement=movement,disabled=false,DisableInput=function(s) s.disabled=true end,EnableInput=function(s) s.disabled=false end})
    world=object({SpawnActor=function()
        if failSpawn then error('injected spawn failure') end
        spawned=spawned+1
        camera=object({CameraComponent=object({SetFieldOfView=function() end}),
            SetTickableWhenPaused=function() end,
            SetActorEnableCollision=function() end,
            K2_DestroyActor=function(s) destroyed=destroyed+1;s.invalid=true end,
            K2_SetActorLocationAndRotation=function(s,pos) s.position=pos end})
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
    local gameplay=object({IsGamePaused=function() return paused end,
        GetTimeSeconds=function() return paused and frozenTime or testClock-timeOffset end,
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
            elseif command=='XShowAllWidget' then widgetsHidden=false end
        end})
    package.loaded.UEHelpers={GetPlayerController=function() return pc end,GetKismetSystemLibrary=function() return system end}
    StaticFindObject=function(name) return name:find('GameplayStatics') and gameplay or object() end
    Key={F8=119,F9=120};RegisterKeyBind=function(k,fn) keys[k]=fn end
    LoopAsync=function(_,fn) loop=fn end;ExecuteInGameThread=function(fn) fn() end
    os.clock=function() return testClock end;os.time=function() return 100 end
    io.open=function(path,mode)
        if path:find('Start-Bridge.ps1',1,true) then return nil end
        if path:find('calibration.lua',1,true) then return nil end
        if path:find('flight-settings.txt',1,true) then return nil end
        for _,key in ipairs({'freeze','collision','npcs'}) do
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
    assert(not paused and not pc.bShouldPerformFullTickWhenPaused and not pc.PrimaryActorTick.bTickEvenWhenPaused,'world freeze leaked')
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
reset();toggle();line='1 2 100000 1 0 32767 32767 0 32767 0 0 0 2';tick();restored();assert(destroyed==1)
print('PASS focus loss returns to character')
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
assert(destroyed==0 and camera.position.Z<height,'closing the menu resumes physics')
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
for i=2,32 do
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
reset({freeze=true});toggle();assert(paused and pc.bShouldPerformFullTickWhenPaused)
local pausedHeight=camera.position.Z
for i=2,15 do
    line=string.format('1 %d 100000 1 1 32767 32767 0 32767 0 0 0 %d',i,i);tick()
end
assert(camera.position.Z<pausedHeight and destroyed==0,'drone must advance while world time is frozen')
toggle();restored()
print('PASS world pause preserves drone physics and F8 restores time and controller flags')
reset({freeze=true});toggle();assert(paused)
line='1 2 100000 1 0 32767 32767 0 32767 0 0 0 2';tick();restored()
print('PASS focus loss thaws the world before returning control')
io.open,os.clock,os.time=rawOpen,rawClock,rawTime
print('18 adapter contract tests passed')
