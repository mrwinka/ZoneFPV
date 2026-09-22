local bridge=dofile('mod/Scripts/bridge.lua')
local rawOpen,rawExecute=io.open,os.execute
local calls=0;local command
io.open=function() return {close=function() end} end
os.execute=function(value) calls=calls+1;command=value;return true,'exit',0 end
assert(bridge.start('D:/Game With Spaces/Mods/ZoneFPV/'))
assert(command:find('-WindowStyle Hidden',1,true) and command:find('-EncodedCommand ',1,true))
for _,path in ipairs({'D:/bad"/','D:/bad\n/'}) do assert(not bridge.start(path)) end
for _,path in ipairs({'D:/%TEMP%/','D:/Games & Mods/','D:/Игры/','D:/player\'s/'}) do assert(bridge.start(path));assert(not command:find(path,1,true)) end
assert(calls==5)
print('PASS bridge startup encodes Unicode and shell-sensitive paths')
os.execute=function() return nil,'exit',1 end;assert(not bridge.start('D:/Game/'))
io.open=function() return nil end;assert(not bridge.start('D:/Game/'))
io.open,os.execute=rawOpen,rawExecute
print('PASS bridge startup reports launch or missing-file failures')
