FindAllOf=function()return {}end
local m=dofile('mod/Scripts/world_distance.lua')
local values={};local writes=0
local sys={GetConsoleVariableFloatValue=function(_,n)return values[n] or -1 end,ExecuteConsoleCommand=function(_,_,cmd)local n,v=cmd:match('^(%S+) (%S+)$');values[n]=tonumber(v);writes=writes+1 end}
values['wp.Runtime.LoadingRangeTerrain']=10000
values['wp.Runtime.LoadingRangeArchitecture']=20000
local s={pc={}};local function log()end
m.update(s,sys,0,log);assert(writes==0)
m.update(s,sys,1,log);assert(values['wp.Runtime.LoadingRangeTerrain']==12500 and writes==2)
m.update(s,sys,3,log);assert(values['wp.Runtime.LoadingRangeTerrain']==20000,'must not compound')
local n=writes;m.update(s,sys,3,log);assert(writes==n)
m.restore(s,log);assert(values['wp.Runtime.LoadingRangeTerrain']==10000 and values['wp.Runtime.LoadingRangeArchitecture']==20000)
assert(values['wp.Runtime.LoadingRangeMainGrid']==nil,'do not modify main gameplay grid')
print('PASS grid multiplier, unsupported baselines, cached writes and restoration')

values['wp.Runtime.LoadingRangeTerrain']=-1
local grid={GridName={ToString=function()return 'Terrain'end},LoadingRange=30000}
local function array(items)
 items.GetArrayNum=function(self)return #self end
 items.ForEach=function()error('live array ForEach callback must not run')end
 return items
end
local world={IsValid=function()return true end,GetAddress=function()return 42 end}
FindAllOf=function()return {{IsValid=function()return true end,GetWorld=function()return world end,StreamingGrids=array({grid})}}end
local session={pc={},world=world}
m.update(session,sys,3,log);assert(values['wp.Runtime.LoadingRangeTerrain']==60000)
m.restore(session,log);assert(values['wp.Runtime.LoadingRangeTerrain']==-1,'restore sentinel exactly')

m.update(session,sys,6,log);assert(values['wp.Runtime.LoadingRangeTerrain']==150000,'5x configured grid')
m.restore(session,log);assert(values['wp.Runtime.LoadingRangeTerrain']==-1)
assert(not m.save('',7))

-- Use the exact baselines reported by the failed preview 1 session.
local baseline={Terrain=25400,Architecture=6300,Props=6300,TreesEnv=12700,
 BakedFoliageGrid=50000,HLOD_Terrain=223520,HLOD_Architecture=100000,
 HLOD_Architecture_HQ=12600,HLOD_Props=25000,HLOD_TreesEnv=76000}
for suffix in pairs(baseline) do values['wp.Runtime.LoadingRange'..suffix]=-1 end
FindAllOf=function()
 local items={}
  for suffix,range in pairs(baseline) do
   local name=suffix
   items[#items+1]={GridName={ToString=function()return name end},LoadingRange=range}
  end
 return {{IsValid=function()return true end,GetWorld=function()return world end,StreamingGrids=array(items)}}
end
local uniform={pc={},world=world}
m.update(uniform,sys,6,log)
assert(values['wp.Runtime.LoadingRangeTerrain']==127000)
assert(values['wp.Runtime.LoadingRangeArchitecture']==31500)
assert(values['wp.Runtime.LoadingRangeProps']==31500)
for suffix,range in pairs(baseline) do
 assert(values['wp.Runtime.LoadingRange'..suffix]==range*5,'uniform 5x: '..suffix)
end
local before=writes;m.update(uniform,sys,6,log);assert(writes==before,'no repeated streaming changes')
m.update(uniform,sys,1,log)
assert(values['wp.Runtime.LoadingRangeTreesEnv']==15875,'lower selections remain meaningful')
m.update(uniform,sys,6,log);assert(values['wp.Runtime.LoadingRangeTreesEnv']==63500,'do not compound')
m.update(uniform,sys,0,log)
for suffix in pairs(baseline) do assert(values['wp.Runtime.LoadingRange'..suffix]==-1,'restore sentinel: '..suffix)end
m.restore(uniform,log);assert(uniform.worldDistance==nil)
print('PASS uniform 5x on all ten original geometry grids, cached writes, exact sentinel restoration')

-- A 5x request must not dispatch one enormous loading batch at FPV entry.
local protected={pc={},world=world};local notices={}
local function notice(t)notices[#notices+1]=t end
local sample={commit=9000,used=300000}
local n=writes;m.update(protected,sys,6,notice,0,false,sample)
assert(writes==n,'wait for pressure samples before increasing the loading range')
m.update(protected,sys,6,notice,3,false,sample)
assert(values['wp.Runtime.LoadingRangeTerrain']==31750,'first batch is 1.25x, not the final 5x')
m.update(protected,sys,6,notice,100,false,sample)
assert(values['wp.Runtime.LoadingRangeTerrain']==38100,'long frame must not catch up multiple loading batches')
sample={commit=1698,used=582915}
m.update(protected,sys,6,notice,100.1,true,sample)
for suffix in pairs(baseline) do assert(values['wp.Runtime.LoadingRange'..suffix]==-1,'pressure restores exact native sentinel')end
local n=writes;m.update(protected,sys,6,notice,101,true,sample)
assert(writes==n,'pressure does not repeatedly issue console commands')
sample={commit=9000,used=300000}
m.update(protected,sys,6,notice,102,false,sample)
assert(values['wp.Runtime.LoadingRangeTerrain']==-1,'recovery waits before another batch')
for t=104,119,3 do m.update(protected,sys,6,notice,t,false,sample)end
assert(values['wp.Runtime.LoadingRangeTerrain']==127000,'safe stable recovery reaches saved 5x selection')
m.restore(protected,notice)
assert(protected.distanceRamp==nil and protected.worldDistance==nil)
assert(#notices>0)
print('PASS staged 5x, no long-frame burst, game-log pressure fallback, bounded writes and recovery')
