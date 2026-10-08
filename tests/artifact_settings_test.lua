local M=dofile('mod/Scripts/artifact_settings.lua')
assert(M.default==3 and M.min==.5 and M.max==10 and M.step==.5)
for _,text in ipairs({'0.5','3','3.50\n','10','10.0'})do assert(M.parse(text)==tonumber(text))end
for _,text in ipairs({'0','0.49','10.01','-1','nan','inf','3 quit','1..5','1e1',string.rep('1',25)})do
    assert(M.parse(text)==nil,text)
end
for _,value in ipairs({0,.49,10.01,0/0,math.huge,-math.huge,'5',false})do
    assert(M.value(value)==3,'Invalid runtime values retain the safe legacy distance')
end
assert(M.value(.5)==.5 and M.value(10)==10)
local rawOpen=io.open
local saved,failWrite,failClose
io.open=function(_,mode)
    if mode=='r' then
        if not saved then return end
        return {read=function(_,limit)assert(limit==25);return saved end,close=function()end}
    end
    return {write=function(_,text)if failWrite then return nil end;saved=text;return true end,
        close=function()return not failClose end}
end
assert(M.load('test/')==3,'Missing preference retains legacy behavior')
local ok,value=M.save('test/','5.5');assert(ok and value==5.5 and saved=='5.500000\n')
assert(M.load('test/')==5.5,'The range survives reopening the menu/session')
assert(not M.save('test/','11') and saved=='5.500000\n','Invalid settings leave existing preferences intact')
saved='broken';assert(M.load('test/')==3)
failWrite=true;assert(not M.save('test/','4'))
failWrite=nil;failClose=true;assert(not M.save('test/','4'))
io.open=function()return nil end;assert(not M.save('test/','4'))
io.open=rawOpen
print('PASS artifact collection distance boundaries, legacy default, persistence and write failure handling')
