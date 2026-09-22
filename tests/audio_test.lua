local rawOpen=io.open
local output,writes=nil,0
io.open=function() return {write=function(_,text) output=text;writes=writes+1 end,close=function() end} end
local publish=dofile('mod/Scripts/audio.lua').new('mock/')
publish(1,true,25,50);assert(output:match(' 1 0%.500000'))
publish(1.01,true,50,50);assert(writes==1,'publication rate must be bounded')
publish(1.1,true,100,50);assert(output:match(' 1 1%.000000'))
publish(1.2,false,50,50);assert(output:match(' 0 0%.000000'))
io.open=rawOpen
print('PASS audio follows normalized thrust and silences on exit')
