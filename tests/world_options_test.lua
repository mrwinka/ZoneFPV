local freeze=dofile('mod/Scripts/world_freeze.lua')
local prefs=dofile('mod/Scripts/world_options.lua')
local env=dofile('mod/Scripts/environment.lua')
local anchor=dofile('mod/Scripts/npc_anchor.lua')
local god=dofile('mod/Scripts/god_mode.lua')
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
test('freeze owns pause and restores original controller ticking',function()
    local paused=false
    local g={IsGamePaused=function() return paused end,SetGamePaused=function(_,_,v) paused=v;return true end}
    local pc={bShouldPerformFullTickWhenPaused=false,PrimaryActorTick={bTickEvenWhenPaused=false},SetTickableWhenPaused=function(s,v) s.PrimaryActorTick.bTickEvenWhenPaused=v end}
    local s={pc=pc,camera={SetTickableWhenPaused=function() end}}
    freeze.set(s,true,g);assert(paused and pc.bShouldPerformFullTickWhenPaused)
    freeze.set(s,true,g);freeze.set(s,false,g)
    assert(not paused and not pc.bShouldPerformFullTickWhenPaused and not pc.PrimaryActorTick.bTickEvenWhenPaused)
    paused=true;assert(not pcall(freeze.set,s,true,g));assert(not s.freezeOwned)
end)
test('god mode uses native player and faction commands only on state changes',function()
    local pawn={bCanBeDamaged=true}
    local commands={}
    local controller={}
    local system={ExecuteConsoleCommand=function(_,_,command) commands[#commands+1]=command end}
    local state={}
    assert(god.update(state,pawn,true,controller,system));assert(not pawn.bCanBeDamaged)
    assert(commands[1]=='XSetGodMode true' and commands[2]=='XSetFactionGodMode Player true')
    assert(not god.update(state,pawn,true,controller,system) and #commands==2)
    assert(god.update(state,pawn,false,controller,system));assert(pawn.bCanBeDamaged)
    assert(commands[3]=='XSetGodMode false' and commands[4]=='XSetFactionGodMode Player false')
    god.update(state,pawn,true,controller,system);god.restore(state)
    assert(pawn.bCanBeDamaged and not state.pawn)
end)

test('partial freeze failure restores tick flags without owning an external pause',function()
    local g={IsGamePaused=function() return false end,SetGamePaused=function() return false end}
    local pc={bShouldPerformFullTickWhenPaused=false,PrimaryActorTick={bTickEvenWhenPaused=true},SetTickableWhenPaused=function(s,v) s.PrimaryActorTick.bTickEvenWhenPaused=v end}
    local s={pc=pc,camera={SetTickableWhenPaused=function() end}}
    assert(not pcall(freeze.set,s,true,g))
    freeze.set(s,false,g)
    assert(not pc.bShouldPerformFullTickWhenPaused and pc.PrimaryActorTick.bTickEvenWhenPaused)
    assert(not s.freezeOwned and not s.freezePrepared)
end)
test('world checkbox preferences and command validation',function()
    local raw=io.open;local files={}
    io.open=function(path,mode)
        if mode=='r' and not files[path] then return nil end
        return {read=function() return files[path] end,write=function(_,v) files[path]=v;return true end,close=function() return true end}
    end
    local cfg=prefs.load('mock/');assert(not cfg.freeze and not cfg.npcs and not cfg.god)
    assert(prefs.save('mock/',cfg,'freeze',true));assert(prefs.load('mock/').freeze)
    assert(not prefs.save('mock/',cfg,'other',true))
    local _,command=env.parse('1 option freeze 1');assert(command=='FPVOption freeze 1')
    local _,godCommand=env.parse('2 option god 1');assert(godCommand=='FPVOption god 1')
    assert(not env.parse('1 option freeze 2'));assert(not env.parse('1 option other 1'))
    io.open=raw
end)
test('player-property anchor hides shadow, follows camera and restores state',function()
    local mesh={bVisible=true,CastShadow=true,bCastHiddenShadow=true}
    function mesh:IsValid() return true end
    function mesh:SetVisibility(v) self.bVisible=v end
    function mesh:SetCastShadow(v) self.CastShadow=v end
    local pawn={position={X=1,Y=2,Z=3},bHidden=false,bCanBeDamaged=true,collision=true,Mesh=mesh}
    function pawn:K2_GetActorLocation() return self.position end
    function pawn:GetActorEnableCollision() return self.collision end
    function pawn:SetActorHiddenInGame(v) self.bHidden=v end
    function pawn:SetActorEnableCollision(v) self.collision=v end
    function pawn:K2_SetActorLocation(p,sweep,hit,teleport) assert(not sweep and teleport);self.position=p;return true end
    local s={pawn=pawn}
    anchor.update(s,true,{X=100,Y=200,Z=300})
    assert(pawn.bHidden and not pawn.bCanBeDamaged and not pawn.collision and pawn.position.X==100)
    assert(pawn.position.Y==200 and pawn.position.Z==-4997)
    assert(not mesh.bVisible and not mesh.CastShadow and not mesh.bCastHiddenShadow)
    anchor.update(s,true,{X=400,Y=500,Z=600})
    assert(pawn.position.X==400 and pawn.position.Y==500 and pawn.position.Z==-4997)
    anchor.update(s,false,{})
    assert(pawn.position.X==1 and pawn.position.Y==2 and pawn.position.Z==3)
    assert(not pawn.bHidden and pawn.bCanBeDamaged and pawn.collision and not s.npcAnchor)
    assert(mesh.bVisible and mesh.CastShadow and mesh.bCastHiddenShadow)
    anchor.restore(s)
end)
test('NPC anchor rollback restores flags even if return teleport fails',function()
    local pawn={bHidden=true,bCanBeDamaged=false,collision=false}
    function pawn:K2_SetActorLocation() error('injected teleport failure') end
    function pawn:SetActorHiddenInGame(v) self.bHidden=v end
    function pawn:SetActorEnableCollision(v) self.collision=v end
    local s={pawn=pawn,npcAnchor={position={},hidden=false,damage=true,collision=true}}
    assert(not pcall(anchor.restore,s))
    assert(not pawn.bHidden and pawn.bCanBeDamaged and pawn.collision)
end)
print(n..' world option tests passed')
