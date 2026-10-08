local M=dofile('mod/Scripts/native_geiger.lua')
local oldIO,oldRemove=io,os.remove
local files={};local id=0;local ticks,disarms=0,0;local badStatus
io={open=function(path,mode)
 if mode=='rb' then
  local body=files[path];if not body then return nil end
  local at=1;return {read=function(_,n)local s=body:sub(at,at+n-1);at=at+n;return #s>0 and s or nil end,close=function()return true end}
 end
 return {write=function(self,s)files[path]=s;return self end,close=function()return true end}
end}
os.remove=function(path)files[path]=nil end
local function loader(_,name)
 if name=='zonefpv_geiger_arm' then return function()
  local token,c,p=files['test/native-geiger-control.txt']:match('ZFPVG12 (%d+) ([%da-f]+) ([%da-f]+)')
  assert(c=='20000' and p=='30000');id=tonumber(token)
 end end
 if name=='zonefpv_geiger_tick' then return function()ticks=ticks+1 end end
 if name=='zonefpv_geiger_disarm' then return function()disarms=disarms+1 end end
 assert(name=='zonefpv_geiger_poll');return function()files['test/native-geiger-status.txt']=badStatus or ('ZFPVG12 1 1 '..id..' 7 1 0\n')end
end
local function object(at)return {at=at,IsValid=function(self)return not self.invalid end,GetAddress=function(self)return self.at end}end
local c,p=object(0x20000),object(0x30000)
local client=M.new('test/',loader)
assert(client:arm(c,p) and client.active and client.blocked==7 and client.stopped==1)
assert(client:tick() and ticks==1)
c.at=0x40000;assert(not client:tick() and not client.active and disarms==1 and ticks==1);c.at=0x20000
badStatus='ZFPVG12 1 1 '..id..' 7 1 0\n'
assert(not client:arm(c,p) and disarms==2,'a stale lease token must not arm')
badStatus=string.rep('x',161);assert(not client:arm(c,p) and not client.active)
badStatus='ZFPVG12 1 0 999 0 0 8\n';assert(not client:arm(c,p))
badStatus='ZFPVG11 1 1 '..id..' 7 0\n';assert(not client:arm(c,p),'v11 DLL cannot pretend to stop active sounds')
assert(not M.new('test/',function()return nil end):arm(c,p))
io,os.remove=oldIO,oldRemove
print('PASS native Geiger request/lease identity, stale or malformed status, missing export and changed component fail safely')
