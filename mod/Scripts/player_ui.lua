-- Session-local UI suppression; never write the game's saved preferences.
local M={}
local observers={}
local liveUI
local function observe(g)
    liveUI=g
    if type(NotifyOnNewObject)~='function'then return end
    for _,name in ipairs({'SubtitleView','PlayerGameHUDView'})do
        if observers[name]==nil then
            observers[name]=pcall(NotifyOnNewObject,'/Script/Stalker2.'..name,function(widget)
                local live=liveUI
                if live and live.active and #live.pending<128 then
                    live.pending[#live.pending+1]={object=widget,tries=0}
                end
            end)
        end
    end
end
local function valid(o)
    local ok,value=pcall(function()return o:IsValid()end)
    return ok and value==true
end
local function retry(g,entry,now)
    if entry.tries<10 and #g.pending<128 then
        entry.tries=entry.tries+1;entry.retryAt=now+.1
        g.pending[#g.pending+1]=entry
    end
end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function() return a:GetAddress()==b:GetAddress() end)
    return ok and value
end
local function restoreWidget(entry)
    pcall(function() if valid(entry.object) then entry.object:SetRenderOpacity(entry.opacity) end end)
    pcall(function() if valid(entry.object) then entry.object:SetVisibility(entry.visibility) end end)
end
local function attempt(g,key,fn)
    if g.unsupported[key] then return end
    local ok,err=pcall(fn)
    if not ok then
        g.unsupported[key]=true
        print('[ZoneFPV] Player UI unavailable: '..key..' / '..tostring(err)..'\n')
    end
end
function M.update(s,now,gameplay,menu)
    local g=s.playerUI
    if g and (not same(g.world,s.world) or not same(g.pc,s.pc)) then M.restore(s,g.gameplay);g=nil end
    if not g then
        g={world=s.world,worldId=s.world:GetAddress(),pc=s.pc,gameplay=gameplay,widgets={},unsupported={},nextScan=0,pending={},active=true};s.playerUI=g
        observe(g)
        attempt(g,'cursor snapshot',function() g.cursor=s.pc.bShowMouseCursor end)
        attempt(g,'subtitle snapshot',function() g.subtitles=gameplay:AreSubtitlesEnabled() end)
    end
    if not menu and g.cursor~=nil then
        attempt(g,'cursor',function() if s.pc.bShowMouseCursor then s.pc.bShowMouseCursor=false end end)
    end
    if g.subtitles~=nil then
        attempt(g,'subtitles',function() if gameplay:AreSubtitlesEnabled() then gameplay:SetSubtitlesEnabled(false) end end)
    end
    if now>=g.nextScan or #g.pending>0 then
        g.nextScan=now+0.5
        attempt(g,'UI widgets',function()
            for id,entry in pairs(g.widgets) do
                local w=entry.object
                if not valid(w) then g.widgets[id]=nil
                elseif not same(w:GetWorld(),g.world) then restoreWidget(entry);g.widgets[id]=nil end
            end
            local candidates={}
            for _=1,math.min(8,#g.pending)do
                local entry=table.remove(g.pending,1)
                if entry.retryAt and now<entry.retryAt then g.pending[#g.pending+1]=entry
                else candidates[#candidates+1]=entry end
            end
            -- Hide the native HUD root, preserving every child's own settings.
            -- Global XHideAllWidget/XShowAllWidget commands are not inverses of
            -- the game's view-manager state and can leave the HUD hidden.
            if not g.initialScan or not (observers.SubtitleView and observers.PlayerGameHUDView)then
                for _,name in ipairs({'SubtitleView','PlayerGameHUDView'})do
                    for _,w in ipairs(FindAllOf(name) or {})do candidates[#candidates+1]={object=w,tries=0} end
                end
                g.initialScan=true
            end
            -- The two known view classes cover native UI without enumerating
            -- every UserWidget or converting names on live native objects.
            local seen={}
            for _,candidate in ipairs(candidates) do
                local w=candidate.object
                if valid(w) then
                    local ok,id=pcall(function()return w:GetAddress()end)
                    if ok and id~=nil and not seen[id] then
                        seen[id]=true
                        if not g.widgets[id] then
                            local ready,world=pcall(function()return w:GetWorld()end)
                            if not ready or not valid(world)then
                                -- Construction notifications can precede the
                                -- widget's world. Retry only on game-thread
                                -- updates, with fixed time and count budgets.
                                retry(g,candidate,now)
                            elseif same(world,g.world)then
                                attempt(g,'snapshot '..tostring(id),function()
                                    local key='widget '..tostring(id);g.unsupported[key]=nil
                                    g.widgets[id]={object=w,key=key,opacity=w:GetRenderOpacity(),visibility=w:GetVisibility()}
                                end)
                            end
                        end
                    elseif not ok or id==nil then retry(g,candidate,now)end
                else retry(g,candidate,now)end
            end
        end)
    end
    for id,entry in pairs(g.widgets) do
        if not valid(entry.object) then g.widgets[id]=nil
        else attempt(g,entry.key,function()
            if entry.object:GetRenderOpacity()~=0 then entry.object:SetRenderOpacity(0) end
            if entry.object:GetVisibility()~=1 then entry.object:SetVisibility(1) end
        end) end
    end
end
function M.restore(s,gameplay)
    local g=s.playerUI;if not g then return end
    g.active=false;if liveUI==g then liveUI=nil end
    if g.cursor~=nil then pcall(function() g.pc.bShowMouseCursor=g.cursor end) end
    if g.subtitles~=nil then pcall(function() gameplay:SetSubtitlesEnabled(g.subtitles) end) end
    for _,entry in pairs(g.widgets) do
        restoreWidget(entry)
    end
    s.playerUI=nil
end
return M
