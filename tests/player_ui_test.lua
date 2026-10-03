local ui=dofile('mod/Scripts/player_ui.lua')
local world={IsValid=function()return true end,GetAddress=function()return 9 end}
local widget={opacity=.6,visibility=0}
function widget:GetVisibility()return self.visibility end
function widget:SetVisibility(v)self.visibility=v end
function widget:IsValid()return not self.invalid end
function widget:GetWorld()return self.world or world end
function widget:GetAddress()return 10 end
function widget:GetRenderOpacity()return self.opacity end
function widget:SetRenderOpacity(v)self.opacity=v end
local function makeHud(id,opacity,visibility,ownerWorld)
    local hud={opacity=opacity,visibility=visibility,world=ownerWorld or world,sets=0,
        children={compass={visibility=2,opacity=.3},crosshair={visibility=0,opacity=.8}}}
    function hud:GetVisibility()return self.visibility end
    function hud:SetVisibility(v)self.sets=self.sets+1;self.visibility=v end
    function hud:IsValid()return not self.invalid end
    function hud:GetWorld()return self.world end
    function hud:GetAddress()return id end
    function hud:GetRenderOpacity()return self.opacity end
    function hud:SetRenderOpacity(v)self.sets=self.sets+1;self.opacity=v end
    return hud
end
local hud=makeHud(20,.45,4)
local hudRoots={hud}
FindAllOf=function(name)
    if name=='SubtitleView' then return {widget} end
    if name=='PlayerGameHUDView' then return hudRoots end
    return {}
end
local game={subtitles=true}
function game:AreSubtitlesEnabled()return self.subtitles end
function game:SetSubtitlesEnabled(v)self.subtitles=v end
local s={pc={bShowMouseCursor=true},world=world}
ui.update(s,0,game,false)
assert(not s.pc.bShowMouseCursor and not game.subtitles and widget.opacity==0)
assert(hud.opacity==0 and hud.visibility==1,'native gameplay HUD root must be suppressed during FPV')
s.pc.bShowMouseCursor=true;ui.update(s,.1,game,true)
assert(s.pc.bShowMouseCursor,'native menu must not have its cursor suppressed')
ui.update(s,.2,game,false);assert(not s.pc.bShowMouseCursor)
ui.restore(s,game)
assert(s.pc.bShowMouseCursor and game.subtitles and widget.opacity==.6 and widget.visibility==0)
assert(hud.opacity==.45 and hud.visibility==4,'native HUD must restore its original opacity and nondefault visibility')
assert(hud.children.compass.visibility==2 and hud.children.compass.opacity==.3
    and hud.children.crosshair.visibility==0 and hud.children.crosshair.opacity==.8,
    'HUD suppression and restoration must preserve individual child preferences')
s.pc.bShowMouseCursor=false;game.subtitles=false
ui.update(s,1,game,false);ui.restore(s,game)
assert(not s.pc.bShowMouseCursor and not game.subtitles)
local foreign={IsValid=function()return true end,GetAddress=function()return 99 end}
widget.world=nil;widget.opacity=.8;widget.visibility=0
ui.update(s,2,game,false);assert(widget.opacity==0)
widget.world=foreign;ui.update(s,2.5,game,false)
assert(widget.opacity==.8 and widget.visibility==0 and not s.playerUI.widgets[10],'valid widgets moved to another world must restore')
ui.restore(s,game)
widget.world=nil;ui.update(s,3,game,false)
s.world=foreign;ui.update(s,3.1,game,false)
assert(widget.opacity==.8 and not s.playerUI.widgets[10],'world changes must release old UI before capturing the new world')
ui.restore(s,game)
print('PASS UI restoration preserves both enabled and disabled preferences')
-- Independent visibility restoration must survive an optional opacity failure.
s.world=world;widget.world=nil;widget.opacity=.7;widget.visibility=0
s.pc.bShowMouseCursor=true;game.subtitles=true
ui.update(s,4,game,false);assert(widget.opacity==0 and widget.visibility==1)
local opacitySetter=widget.SetRenderOpacity
widget.SetRenderOpacity=function()error('injected opacity restore failure')end
ui.restore(s,game)
assert(widget.visibility==0 and s.pc.bShowMouseCursor and game.subtitles and not s.playerUI)
assert(hud.opacity==.45 and hud.visibility==4,'a subtitle restore error must not prevent native HUD restoration')
widget.SetRenderOpacity=opacitySetter
print('PASS widget visibility, cursor and subtitles restore independently of opacity failure')

-- Root suppression must never turn an initially hidden HUD on after flight.
local hiddenHud=makeHud(21,0,2)
hudRoots={hiddenHud}
ui.update(s,5,game,false)
assert(hiddenHud.opacity==0 and hiddenHud.visibility==1)
ui.update(s,5.1,game,false)
ui.restore(s,game)
assert(hiddenHud.opacity==0 and hiddenHud.visibility==2,'an initially hidden native HUD must stay hidden')
print('PASS an initially hidden gameplay HUD keeps its original state')

-- A recreated HUD during FPV gets its own snapshot; valid former roots restore too.
local oldHud=makeHud(22,.55,0)
local replacementHud=makeHud(23,.75,3)
local foreignHud=makeHud(24,.9,0,foreign)
hudRoots={oldHud,foreignHud}
ui.update(s,6,game,false)
assert(oldHud.opacity==0 and oldHud.visibility==1)
assert(foreignHud.opacity==.9 and foreignHud.visibility==0 and foreignHud.sets==0,
    'foreign-world native HUD roots must remain untouched')
hudRoots={replacementHud,foreignHud}
ui.update(s,6.5,game,false)
assert(replacementHud.opacity==0 and replacementHud.visibility==1,'replacement native HUD must be suppressed')
ui.restore(s,game)
assert(oldHud.opacity==.55 and oldHud.visibility==0
    and replacementHud.opacity==.75 and replacementHud.visibility==3,
    'each native HUD root must restore its own original state')
assert(foreignHud.sets==0,'native HUD restoration must not alter foreign-world roots')
print('PASS replacement gameplay HUD roots restore independently and foreign worlds are ignored')

-- An optional native HUD failure must not strand subtitles or another HUD root.
local failingHud=makeHud(25,.65,4)
local healthyHud=makeHud(26,.85,0)
hudRoots={failingHud,healthyHud}
widget.opacity=.6;widget.visibility=0;s.pc.bShowMouseCursor=true;game.subtitles=true
ui.update(s,7,game,false)
local failingOpacitySetter=failingHud.SetRenderOpacity
failingHud.SetRenderOpacity=function()error('injected HUD opacity restore failure')end
ui.restore(s,game)
assert(failingHud.visibility==4,'native HUD visibility restore must survive opacity restore failure')
assert(healthyHud.opacity==.85 and healthyHud.visibility==0,'another native HUD root must restore after a peer failure')
assert(widget.opacity==.6 and widget.visibility==0 and s.pc.bShowMouseCursor and game.subtitles and not s.playerUI,
    'native HUD restoration errors must not strand subtitles, cursor or preferences')
failingHud.SetRenderOpacity=failingOpacitySetter

local unsupportedHud=makeHud(27,.35,0)
unsupportedHud.GetRenderOpacity=function()error('injected unsupported HUD getter')end
local supportedAfterError=makeHud(28,.5,3)
hudRoots={unsupportedHud,supportedAfterError}
ui.update(s,8,game,false)
assert(widget.opacity==0 and widget.visibility==1 and not game.subtitles,
    'an unsupported native HUD API must not prevent subtitle suppression')
assert(supportedAfterError.opacity==0 and supportedAfterError.visibility==1,
    'an unsupported native HUD snapshot must not prevent capture of a later supported root')
local laterHud=makeHud(29,.4,0)
hudRoots={unsupportedHud,supportedAfterError,laterHud}
ui.update(s,8.5,game,false)
assert(laterHud.opacity==0 and laterHud.visibility==1,
    'an unsupported native HUD snapshot must not disable future scans')
ui.restore(s,game)
assert(unsupportedHud.sets==0 and widget.opacity==.6 and widget.visibility==0 and game.subtitles,
    'unsupported native HUD roots must remain untouched while supported UI restores')
assert(supportedAfterError.opacity==.5 and supportedAfterError.visibility==3
    and laterHud.opacity==.4 and laterHud.visibility==0,'supported roots captured around API failures must restore')
print('PASS native HUD API and restoration errors remain isolated from supported UI')
