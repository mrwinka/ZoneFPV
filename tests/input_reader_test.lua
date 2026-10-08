local reader=dofile('mod/Scripts/input_reader.lua')
local original=io.open
local closed=false
io.open=function()return {read=function(_,n)assert(n==512);return 'valid packet' end,close=function()closed=true end}end
assert(reader.read('input.txt')=='valid packet' and closed)
io.open=function()return nil,'sharing violation' end
assert(reader.read('input.txt')==nil)
io.open=function()error('attempt to call a FILE* value')end
assert(reader.read('input.txt')==nil)
io.open=function()return function()end end
assert(reader.read('input.txt')==nil)
closed=false
io.open=function()return {read=function()error('read failed')end,close=function()closed=true end}end
assert(reader.read('input.txt')==nil and closed)
io.open=original
print('PASS input exchange errors do not abort flight callback; bounded read and close')
