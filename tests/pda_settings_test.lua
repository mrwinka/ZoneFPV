local M=dofile('mod/Scripts/pda_settings.lua')
local function hex(value)return(value:gsub('.',function(c)return string.format('%02x',c:byte())end))end
local sequence,epoch,session,ack=1,2000000000000,2000000000000000,0
local function packet(changes)
    local h={'1',sequence,epoch,session,ack,1,1,-1,0,0,0,42,1,2,0,0,73,1,720896,hex('Готово'),1}
    for index,value in pairs(changes or {})do h[index]=value end
    for i,v in ipairs(h)do h[i]=tostring(v)end
    return table.concat(h,' ')..'\nD 42 2 '..hex('Radiomaster Pocket')..'\nP 2\nB 117 119 120 65 1001 3018 2032 0\nL 4636 4638 4639 41 427574746f6e31 43483648696768 4861745570 -\nM 0 0 0 1 1 1 1 0\nA 0 32768 65535 20 30 40 50 60\n1 '..sequence..'\n'
end
local valid=assert(M.parse(packet()))
assert(valid.devices[1].name=='Radiomaster Pocket'and valid.status=='Готово'and valid.profile==2)
assert(valid.bindings[6]==3018 and valid.bindingLabels[6]=='CH6High'and valid.bindingLabels[8]=='')
assert(valid.objectLimit.has and valid.objectLimit.value==720896 and valid.axes[3]==65535)
for _,changes in ipairs({{[1]=2},{[2]=0},{[6]=2},{[8]=8},{[9]=5},{[10]=4},{[14]=-2},{[15]=5},
    {[16]=2},{[17]=101},{[18]=2},{[19]=0},{[20]='0'},{[20]='ff'},{[21]=65}})do assert(not M.parse(packet(changes)))end
assert(not M.parse(packet()..'extra\n'))
assert(not M.parse(packet():gsub('P 2','P 11')))
assert(not M.parse(packet():gsub('A 0','A -1')))
assert(not M.parse(packet():gsub('2032 0\nL','2000 0\nL')))
assert(not M.parse(packet():gsub('3018','3000')))
assert(M.parse(packet():gsub('3018','3024'))and M.parse(packet():gsub('2032','2001')))
assert(not M.parse(packet():gsub('4636','4')))
assert(not M.parse(packet():gsub('\n1 1\n$','\n1 2\n')))
assert(not M.parse(string.rep('x',32769)))
local time,files,denied=0,{},false
local writes={}
local function read(path,maximum)local value=files[path];if value and #value<=maximum then return value end end
local function write(path,value)if denied then return false end;files[path]=value;writes[#writes+1]={path=path,value=value};return true end
local client=M.new('',{clock=function()return time end,epoch=function()return epoch end,read=read,write=write})
session=client.session
assert(files['pda-settings-owner.txt']:match(' 0 0 0 1\n$'))
assert(not client:request('language',{1}))
client:setContext(true,10)
assert(not client:request('language',{1}),'No stale/cold state can authorize settings')
local function state(changes)
    sequence=sequence+1;files['pda-settings-state.txt']=packet(changes);client:update(time)
end
state()
local snap=client:snapshot();assert(snap.available and snap.eligible and snap.volume==73)
snap.bindings[1]=0;snap.devices[1].name='changed'
assert(client:snapshot().bindings[1]==117 and client:snapshot().devices[1].name=='Radiomaster Pocket','Snapshots are copies')
assert(not client:request('modes',{0,1}),'Wrong section')
assert(not client:request('language',{5})and not client:request('language',{'1'})and not client:request('language',{1,2}))
assert(client:request('language',{1}));client:update(time)
local pending=client.pending;assert(pending and pending.kind=='language')
assert(files['pda-settings-request.txt']==string.format('1 %.0f %d %.0f 10 language 1 %d\n',session,pending.id,epoch,pending.id))
assert(client:request('audio',{10}));assert(client:request('audio',{20}));assert(#client.queue==1 and client.queue[1].args[1]==20)
ack=pending.id-1;time=.06;state();assert(client.pending==pending,'Unmatched ack cannot consume request')
ack=pending.id;time=.12;state({[20]=hex('Сохранено')})
assert(client.pending and client.pending.kind=='audio'and client.pending.args[1]==20,'Latest queued value follows the acknowledged command')
assert(client.pending.id>pending.id)
ack=client.pending.id;time=.18;state({[6]=0,[20]=hex('Ошибка записи')})
assert(not client.pending and client:snapshot().status=='Не удалось применить','Error acknowledgement must show a failure')

time=.24;state({[6]=0,[20]=hex('Сохранено')})
assert(client:snapshot().status=='Не удалось применить','A stale helper success cannot hide the failed acknowledgement')
assert(client:request('theme',{1}));client:update(time)
ack=client.pending.id;time=.30;state({[6]=0,[20]=hex('Сохранено')})
assert(not client.pending and client:snapshot().status=='Не удалось применить','Focus rejection with an old successful status is still a failed command')
time=.36;state()

assert(client:request('theme',{1}));client:update(time)
client:setContext(true,9)
assert(not client.pending and #client.queue==0 and files['pda-settings-owner.txt']:match(' 1 9 0 %d+\n$'),'Changing tools cancels queued ownership')
time=.42;state()
assert(client:request('capture',{5}));client:update(time)
local capturing=client.pending
client:setContext(true,9,true)
assert(client.pending==capturing and files['pda-settings-owner.txt']:match(' 1 9 1 %d+\n$'),'Reserved hover publishes without cancelling capture request')
client:setContext(true,9,false)
assert(client.pending==capturing,'Leaving controls re-enables physical mouse capture')
ack=client.pending.id;time=.48;state({[8]=5,[11]=14000,[20]=hex('Нажмите кнопку...')})
assert(client:snapshot().capture.row==5 and client:snapshot().capture.remainingMs==14000)
assert(client:request('clear',{5}));assert(client:request('clear',{6}));assert(#client.queue==2,'Discrete actions are not coalesced')
client:setContext(false,0)
assert(#client.queue==0 and not client.pending and files['pda-settings-owner.txt']:match(' 0 0 0 %d+\n$'))
assert(not client:request('cancel',{0}))

client:setContext(true,1);time=.54;state()
assert(client:request('profile',{10}));client:update(time)
time=2.6;client:update(time)
assert(not client.pending and not client:snapshot().available,'Same sequence must not extend its lease')
assert(not client:request('calibrate',{0}))
time=2.66;state({[8]=-1,[9]=2,[10]=1,[11]=6000})
assert(client:snapshot().calibration.stage==2)
assert(client:request('calibrate',{1}));client:update(time)
sequence=1;time=2.72;client:update(time);files['pda-settings-state.txt']=packet();time=2.78;client:update(time)
assert(not client.pending and #client.queue==0,'Helper restart cancels rather than replays')
assert(client:snapshot().available)
local saved=client:snapshot()
files['pda-settings-state.txt']='1 broken';time=2.84;client:update(time)
assert(client:snapshot().calibration.stage==saved.calibration.stage,'Partial state cannot corrupt last valid display')
epoch=epoch+3000;time=2.90;client:update(time)
assert(not client:snapshot().available and client:snapshot().capture.row==-1)
assert(not client:request('device',{42}))
epoch=epoch-3000;time=2.96;state({[7]=0})
assert(not client:snapshot().eligible and not client:request('device',{0}),'Actual focus/owner ineligibility gates mutation')
time=3.02;state();denied=true
assert(client:request('device',{0}));client:update(time)
assert(not client.pending and #client.queue==0 and client:snapshot().status=='Не удалось применить','A local publication failure remains visible')
client:destroy();assert(not client.open)
denied=false
local replacement=M.new('',{clock=function()return time end,epoch=function()return epoch end,read=read,write=write})
assert(replacement.session>client.session,'Reloads never reuse an earlier owner session')
local third=M.new('',{clock=function()return time end,epoch=function()return epoch end,read=read,write=write})
assert(third.session>replacement.session,'Repeated reloads at one clock value remain unique')
local errors=M.new('',{clock=function()return time end,epoch=function()return epoch end,read=read,write=write})
session=errors.session;errors:setContext(true,10)
local function errorState(changes)
    time=time+.06;sequence=sequence+1;files['pda-settings-state.txt']=packet(changes);errors:update(time)
end
errorState()
assert(errors:request('audio',{20}));errors:update(time)
ack=errors.pending.id;errorState({[6]=0,[20]=hex('! Подключите пульт в режиме USB Joystick')})
assert(not errors.pending and errors:snapshot().status=='Подключите пульт в режиме USB Joystick','Marked current error explains the failed command')
errorState({[6]=0,[20]=hex('Сохранено')})
assert(errors:snapshot().status=='Подключите пульт в режиме USB Joystick','Later stale success cannot replace the acknowledged failure cause')
assert(errors:request('audio',{20}));errors:update(time)
ack=errors.pending.id;errorState({[6]=0,[20]=hex('! ')})
assert(errors:snapshot().status=='Не удалось применить','Empty marked cause still has a useful fallback')
if arg and arg[1]then
    local file=assert(io.open(arg[1],'r'));local data=file:read('*a');file:close()
    local actual=assert(M.parse(data),'Production C++ state fixture must parse in actual Lua client')
    assert(#actual.bindings==8 and #actual.modes==8 and #actual.bindingLabels==8 and #actual.axes==8)
    assert(actual.session==1700000000000123 and #actual.devices>0)
end
print('PASS PDA headless state framing, UTF8, bounded ownership, queued settings, capture/calibration, errors, stale/restart/focus guards')
