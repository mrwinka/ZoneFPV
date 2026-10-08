local M=dofile('mod/Scripts/external_menu_guard.lua')
local input=dofile('mod/Scripts/input.lua')
local line,now,epoch=nil,10,100
local function object(t)t=t or {};function t:IsValid()return not self.dead end;function t:GetAddress()return self end;return t end
local world=object()
local function controller(cursor,move,look)
    local pc=object({bShowMouseCursor=cursor,move=move or 0,look=look or 0,world=world,Pawn=object(),calls=0})
    function pc:GetWorld()return self.world end
    function pc:SetIgnoreMoveInput(value)self.calls=self.calls+1;self.move=self.move+(value and 1 or -1)end
    function pc:SetIgnoreLookInput(value)self.calls=self.calls+1;self.look=self.look+(value and 1 or -1)end
    return pc
end
local function packet(seq,menu,focused,connected)
    line=string.format('4 %d 100000 %d %d 32768 32768 0 32768 0 0 0 0 0 %d 0 %d',
        seq,connected and 1 or 0,focused and 1 or 0,menu and 1 or 0,seq)
end
local guard=M.new(function()return line end,input.parse,function()return now end,function()return epoch end)
local pc=controller(false,2,3)
packet(1,true,true,false);assert(not guard:update(pc) and pc.calls==0,'first saved open snapshot cannot lock a new game')
for _=1,20 do assert(not guard:update(pc))end
assert(pc.calls==0,'reading a preserved sequence never proves a live menu')
packet(2,true,true,false);assert(guard:update(pc))
assert(pc.move==3 and pc.look==4 and not pc.bShowMouseCursor,'lock before focus transfer without changing UE cursor or USB input')
for _=1,20 do assert(guard:update(pc))end
assert(pc.move==3 and pc.look==4,'menu owns just one counted lock')
packet(3,true,false,true);assert(guard:update(pc))
packet(4,false,true,true);assert(not guard:update(pc))
assert(pc.move==2 and pc.look==3 and not pc.bShowMouseCursor,'native/cutscene locks survive close')
packet(5,true,false,false);guard:update(pc);now=now+.251;assert(not guard:update(pc))
assert(pc.move==2 and pc.look==3 and not pc.bShowMouseCursor,'helper death releases owned input without changing UE cursor')
packet(6,true,false,false);assert(not guard:update(pc));packet(7,true,false,false);guard:update(pc)
local replacement=controller(true,1,1);assert(guard:update(replacement))
assert(pc.move==2 and pc.look==3 and replacement.move==2 and replacement.look==2)
replacement.world=object();guard:update(replacement)
assert(replacement.move==2 and replacement.look==2,'world replacement never stacks menu locks')
line='partial';assert(not guard:update(replacement))
assert(replacement.move==1 and replacement.look==1 and replacement.bShowMouseCursor)
packet(8,true,true,false);assert(not guard:update(pc));packet(9,true,true,false);guard:update(pc);guard:restore();guard:restore()
assert(pc.move==2 and pc.look==3,'emergency restore is idempotent')
packet(10,true,true,false);guard:update(pc);epoch=104;assert(not guard:update(pc))
assert(pc.move==2 and pc.look==3,'old startup file cannot retain control')
print('PASS external-menu counted input ownership before focus, without USB, stale helper/world/controller recovery; native cursor untouched')
epoch=100;now=20
local startup=M.new(function()return line end,input.parse,function()return now end,function()return epoch end)
local loading=controller(false,2,3);loading.Pawn=nil
packet(1,false,true,false);assert(not startup:update(loading))
packet(2,false,true,false);assert(not startup:update(loading) and loading.calls==0)
packet(3,true,true,false);assert(not startup:update(loading) and loading.calls==0,'unpossessed loading controller stays untouched')
packet(4,false,true,false);loading.Pawn=object();assert(not startup:update(loading) and loading.calls==0)
packet(5,true,true,false);assert(startup:update(loading) and loading.move==3 and loading.look==4)
loading.Pawn=nil;assert(not startup:update(loading) and loading.move==2 and loading.look==3)
loading.Pawn=object();assert(startup:update(loading) and loading.move==3)
packet(1,true,true,false);assert(not startup:update(loading) and loading.move==2 and loading.look==3,'restarted helper primes before acquiring input')
packet(2,false,true,false);assert(not startup:update(loading))
assert(loading.move==2 and loading.look==3 and not loading.bShowMouseCursor)
print('PASS zero input changes on closed startup, live-writer proof, possession readiness and helper restart')

-- Showing a UE cursor releases persistent viewport capture. Visibility=false
-- alone does not reapply GameOnly mode/capture: an uncaptured mouse reaches an
-- edge and stops producing relative look. The old F6 true/false flag pair must
-- fail this fixture, even though its input counters balance correctly.
local function captureController(initialCursor)
    local pc=controller(initialCursor,2,3)
    local cursorFlag=initialCursor
    pc.bShowMouseCursor=nil
    pc.cursorWrites=0;pc.relativeCapture=not initialCursor;pc.mousePosition=0;pc.yaw=0
    pc.PlayerCameraManager=object({ViewYawMin=11,ViewYawMax=289,ViewPitchMin=-76,ViewPitchMax=83})
    setmetatable(pc,{
        __index=function(_,key)if key=='bShowMouseCursor'then return cursorFlag end end,
        __newindex=function(self,key,value)
            if key=='bShowMouseCursor'then
                self.cursorWrites=self.cursorWrites+1;cursorFlag=value
                if value then self.relativeCapture=false end
            else rawset(self,key,value)end
        end,
    })
    function pc:mouse(delta)
        if self.relativeCapture then self.yaw=self.yaw+delta
        else
            local nextPosition=math.max(-100,math.min(100,self.mousePosition+delta))
            self.yaw=self.yaw+nextPosition-self.mousePosition;self.mousePosition=nextPosition
        end
    end
    return pc
end
local function newGuard()
    epoch=100;now=30
    return M.new(function()return line end,input.parse,function()return now end,function()return epoch end)
end
local capture=captureController(false)
local captures=newGuard()
packet(1,false,true,false);assert(not captures:update(capture))
packet(2,true,true,false);assert(captures:update(capture))
for seq=3,25 do packet(seq,true,false,false);assert(captures:update(capture))end
packet(26,false,true,false);assert(not captures:update(capture))
assert(capture.move==2 and capture.look==3,'cursor fix still balances exactly one menu lock')
for _=1,12 do capture:mouse(100)end
assert(capture.yaw==1200,'after F6 mouse look must keep turning beyond one screen width and three complete revolutions')
assert(capture.cursorWrites==0 and capture.relativeCapture and not capture.bShowMouseCursor,
    'external F6 must not switch the UE viewport out of persistent relative capture')
local cm=capture.PlayerCameraManager
assert(cm.ViewYawMin==11 and cm.ViewYawMax==289 and cm.ViewPitchMin==-76 and cm.ViewPitchMax==83,
    'native camera limits must remain untouched instead of resetting arbitrary yaw/pitch fields')
print('PASS F6 persistent relative mouse capture survives open/close; unbounded mouse-axis regression and camera limits preserved')

-- Native PDA/cutscene input may change while the external menu owns a counted
-- lock. It owns neither that cursor flag nor the native mode and must not write
-- its old snapshot back over a new native UI state on normal or stale release.
local composition=captureController(false)
local composed=newGuard()
packet(1,false,true,false);composed:update(composition)
packet(2,true,false,false);assert(composed:update(composition))
composition.bShowMouseCursor=true -- native UI, not the external guard
composition:SetIgnoreMoveInput(true);composition:SetIgnoreLookInput(true)
packet(3,false,true,false);assert(not composed:update(composition))
assert(composition.cursorWrites==1 and composition.bShowMouseCursor and composition.move==3 and composition.look==4,
    'F6 close must preserve a later native UI cursor and its independent input locks')
local nativeCursor=captureController(true)
local nativeGuard=newGuard()
packet(1,false,true,false);nativeGuard:update(nativeCursor)
packet(2,true,false,false);assert(nativeGuard:update(nativeCursor))
now=now+.251;assert(not nativeGuard:update(nativeCursor))
nativeGuard:restore();nativeGuard:restore()
assert(nativeCursor.cursorWrites==0 and nativeCursor.bShowMouseCursor and nativeCursor.move==2 and nativeCursor.look==3,
    'stale/emergency release preserves a pre-existing native cursor and counted locks')
print('PASS native UI/cutscene cursor and counted input composition survive F6 close/stale/idempotent restore')

-- The helper lease still advances while a closed menu makes no engine calls.
local idleReads,nativeReads=0,0
local idle=M.new(function()idleReads=idleReads+1;return line end,input.parse,
    function()return now end,function()return epoch end)
local untouched=setmetatable({}, {__index=function()nativeReads=nativeReads+1;error('idle controller inspected')end})
packet(1,false,true,false);assert(not idle:update(untouched))
packet(2,false,true,false);assert(not idle:update(untouched))
assert(idleReads==2 and nativeReads==0,'closed idle menu keeps lease without controller/native inspection')
local active=controller(false)
packet(3,true,true,false);assert(idle:update(active) and active.move==1 and active.look==1)
packet(4,false,true,false);assert(not idle:update(active) and active.move==0 and active.look==0,
    'early idle return must never bypass release of owned menu locks')
print('PASS closed-menu zero native reads, live lease and open/close counted ownership')
