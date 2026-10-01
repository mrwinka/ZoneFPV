-- Game-specific geometry grid overrides, discovered in the installed executable.
local M={}
local scales={1,1.25,1.5,2,3,4,5}
-- Apply the user's selected multiplier uniformly to the original geometry
-- grids, including foliage/HLOD. Large ranges increase object/streaming load.
-- The optional engine object-limit setting is separate and requires restart.
local names={'Terrain','Architecture','Props','TreesEnv','BakedFoliageGrid','HLOD_Terrain','HLOD_Architecture','HLOD_Architecture_HQ','HLOD_Props','HLOD_TreesEnv'}
function M.load(root)
 local f=io.open(root..'world-distance.txt','r');if not f then return 0 end
 local t=f:read(16);f:close();return tonumber((t or ''):match('^([0-6])%s*$')) or 0
end
function M.save(root,v)
 if not scales[v+1] then return false end
 local f=io.open(root..'world-distance.txt','w');if not f then return false end
 local ok=f:write(v..'\n');return f:close() and ok and true or false
end
local function set(system,pc,name,value)
 system:ExecuteConsoleCommand(pc,name..' '..string.format('%.9g',value),pc)
 local actual=system:GetConsoleVariableFloatValue(name)
 assert(type(actual)=='number' and math.abs(actual-value)<=math.max(.001,math.abs(value)*.0001),'readback mismatch: '..tostring(actual))
end
local function gridRanges(s,log)
 local ranges={}
 local ok,err=pcall(function()
  for _,hash in ipairs(FindAllOf('WorldPartitionRuntimeSpatialHash') or {}) do
   if hash:IsValid() then
    local world=hash:GetWorld()
    if world and world:IsValid() and world:GetAddress()==s.world:GetAddress() then
     hash.StreamingGrids:ForEach(function(_,ref)
      local grid=ref:get();local name=grid.GridName:ToString()
      if type(grid.LoadingRange)=='number' and grid.LoadingRange>0 then
       ranges[name:lower()]=grid.LoadingRange
       log('World grid baseline: '..name..'='..grid.LoadingRange)
      end
     end)
    end
   end
  end
 end)
 if not ok then log('World grid baselines unavailable: '..tostring(err))end
 return ranges
end
function M.update(s,system,v,log)
 if not scales[v+1] then return end
 if not s.worldDistance then
  if v==0 then return end
  s.worldDistance={original={},selection=-1,system=system,ranges=gridRanges(s,log)}
 end
 local g=s.worldDistance;if g.selection==v then return end
 g.selection=v
 local changed=0
 for _,suffix in ipairs(names) do
  local name='wp.Runtime.LoadingRange'..suffix
  local ok,err=pcall(function()
   local original=g.original[name]
   if original==nil then
    if v==0 then return end
    original=system:GetConsoleVariableFloatValue(name)
    -- Nonpositive values can be override sentinels, not real distances.
    assert(type(original)=='number' and original==original,'invalid baseline')
    local baseline=original>0 and original or g.ranges[suffix:lower()]
    assert(type(baseline)=='number' and baseline>0 and baseline<10000000,'grid baseline unavailable for '..suffix..' ('..tostring(original)..')')
    g.original[name]=original;g.baseline=g.baseline or {};g.baseline[name]=baseline
   end
   local scale=scales[v+1]
   local wanted=v==0 and original or g.baseline[name]*scale
   set(system,s.pc,name,wanted);changed=changed+1
   if v==0 then g.original[name]=nil end
   log('World distance: '..name..' '..original..' -> '..wanted..'; applied multiplier='..(v==0 and 1 or scale))
  end)
  if not ok then log('World distance skipped: '..name..' / '..tostring(err))end
 end
 log('World distance verified grids='..changed..'; multiplier='..scales[v+1])
end
function M.restore(s,log)
 local g=s.worldDistance;if not g then return end
 for name,value in pairs(g.original) do
  local ok,err=pcall(set,g.system,s.pc,name,value)
  if ok then g.original[name]=nil else log('World distance restore failed: '..name..' / '..tostring(err))end
 end
 if next(g.original)==nil then s.worldDistance=nil end
end
return M
