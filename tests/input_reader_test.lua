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
local input=dofile('mod/Scripts/input.lua')
local reads,parses=0,0
local function line(seq,menu)
    return string.format('4 %d 100000 1 1 32768 32768 32768 32768 32768 32768 32768 32768 0 %d 1 %d',seq,menu and 1 or 0,seq)
end
local current=line(1,false)
local shared=reader.frame(function()reads=reads+1;return current end,function(raw)parses=parses+1;return input.parse(raw)end)
local frame1=assert(shared(1));assert(frame1.seq==1 and not frame1.menu)
current=line(2,true)
assert(shared(1)==frame1 and not shared(1).menu,'all consumers use one coherent snapshot in a callback')
assert(reads==1 and parses==1,'a second menu/control consumer performs no extra exchange or parsing')
local frame2=assert(shared(2));assert(frame2.seq==2 and frame2.menu and reads==2)
current=nil;assert(shared(3)==nil)
current=line(3,false);assert(shared(3)==nil,'a failed frame cannot acquire different ownership midway through that callback')
assert(shared(4).seq==3,'next callback samples new input without delaying focus/menu state')
current='partial';assert(shared(5)==nil and shared(5)==nil,'invalid packets are cached only within the callback')
current=line(4,false);assert(shared(6).seq==4 and reads==6 and parses==6)
local broken=reader.frame(function()error('sharing failure')end,input.parse)
assert(broken(1)==nil and broken(1)==nil)
print('PASS one read/parse per callback; coherent menu/control ownership and fresh next-frame recovery')
