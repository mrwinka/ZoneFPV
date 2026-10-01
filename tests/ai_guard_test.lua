local guard=dofile('mod/Scripts/ai_guard.lua')
local valid={IsValid=function()return true end}
local available,flair=true,true
StaticFindObject=function(path)
 if not available then return nil end
 if path:find('EAIFeature',1,true) then return {
  IsValid=function()return true end,
  ForEachName=function(_,fn)
   fn({ToString=function()return 'EAIFeature::SeePlayer' end},131072)
   if flair then fn({ToString=function()return 'EAIFeature::Flair' end},256)end
  end}
 end
 return valid
end
local calls={};local failRestore=false
local system={ExecuteConsoleCommand=function(_,pc,command)
 calls[#calls+1]=command
 if failRestore and command=='XActivateAIFeature SeePlayer' then error('test restore failure')end
end}
local s={pc={}};local log=function()end
guard.start(s,system,log);guard.start(s,system,log)
assert(#calls==1 and calls[1]=='XDeactivateAIFeature SeePlayer')
failRestore=true;assert(not pcall(guard.restore,s,log))
assert(calls[2]=='XActivateAIFeature SeePlayer')
failRestore=false;guard.restore(s,log);guard.restore(s,log)
assert(#calls==3 and calls[3]=='XActivateAIFeature SeePlayer')
flair=false;guard.start(s,system,log);guard.restore(s,log)
assert(#calls==5 and calls[4]=='XDeactivateAIFeature SeePlayer')
available=false;guard.start(s,system,log);guard.restore(s,log);assert(#calls==5)
print('PASS feature availability, idempotence and independent restoration')
