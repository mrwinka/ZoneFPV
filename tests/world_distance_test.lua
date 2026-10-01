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
local world={IsValid=function()return true end,GetAddress=function()return 42 end}
FindAllOf=function()return {{IsValid=function()return true end,GetWorld=function()return world end,StreamingGrids={ForEach=function(_,fn)fn(1,{get=function()return grid end})end}}}end
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
FindAllOf=function()return {{IsValid=function()return true end,GetWorld=function()return world end,
 StreamingGrids={ForEach=function(_,fn)
  for suffix,range in pairs(baseline) do
   local name=suffix
   fn(1,{get=function()return {GridName={ToString=function()return name end},LoadingRange=range}end})
  end
 end}}}end
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
