local binoculars=dofile('mod/Scripts/binoculars.lua')
local env=dofile('mod/Scripts/environment.lua')
local commands={}
local function obj(t) t=t or {};function t:IsValid()return true end;return t end
local pc=obj({Pawn=obj()})
local lib=obj({ExecuteConsoleCommand=function(_,context,command,controller)
    assert(context==pc and controller==pc);commands[#commands+1]=command
end})
assert(binoculars.give(pc,lib,function()end))
assert(#commands==3)
for i=1,3 do assert(commands[i]==string.format('XCreateItemInInventoryByID Binoculars_0%d 0 1 1',i)) end
assert(not binoculars.give(nil,lib,function()end))
pc.Pawn=nil;assert(not binoculars.give(pc,lib,function()end) and #commands==3)
local id,command=env.parse('42 binoculars 1');assert(id=='42' and command=='FPVBinoculars')
assert(not env.parse('42 binoculars 2'));assert(not env.parse('42 binoculars 1 XEnableCheats'))
_,command=env.parse('43 signal 1 20000');assert(command=='FPVSignal 1 20000')
assert(not env.parse('43 signal 1 20001'));assert(not env.parse('43 signal 1 49'))
print('PASS all three binocular requests, loaded-pawn guard and experimental command allowlists')
