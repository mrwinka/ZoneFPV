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
FindAllOf=function(name)if name=='SubtitleView' then return {widget} end;return {}end
local game={subtitles=true}
function game:AreSubtitlesEnabled()return self.subtitles end
function game:SetSubtitlesEnabled(v)self.subtitles=v end
local s={pc={bShowMouseCursor=true},world=world}
ui.update(s,0,game,false)
assert(not s.pc.bShowMouseCursor and not game.subtitles and widget.opacity==0)
s.pc.bShowMouseCursor=true;ui.update(s,.1,game,true)
assert(s.pc.bShowMouseCursor,'native menu must not have its cursor suppressed')
ui.update(s,.2,game,false);assert(not s.pc.bShowMouseCursor)
ui.restore(s,game)
assert(s.pc.bShowMouseCursor and game.subtitles and widget.opacity==.6 and widget.visibility==0)
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
