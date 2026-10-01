-- Session-local UI suppression; never write the game's saved preferences.
local M={}
local function valid(o) return o and o:IsValid() end
local function same(a,b)
    if a==b then return true end
    local ok,value=pcall(function() return a:GetAddress()==b:GetAddress() end)
    return ok and value
end
local function restoreWidget(entry)
    pcall(function() if valid(entry.object) then entry.object:SetRenderOpacity(entry.opacity);entry.object:SetVisibility(entry.visibility) end end)
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
        g={world=s.world,worldId=s.world:GetAddress(),pc=s.pc,gameplay=gameplay,widgets={},unsupported={},nextScan=0};s.playerUI=g
        attempt(g,'cursor snapshot',function() g.cursor=s.pc.bShowMouseCursor end)
        attempt(g,'subtitle snapshot',function() g.subtitles=gameplay:AreSubtitlesEnabled() end)
    end
    if not menu and g.cursor~=nil then
        attempt(g,'cursor',function() if s.pc.bShowMouseCursor then s.pc.bShowMouseCursor=false end end)
    end
    if g.subtitles~=nil then
        attempt(g,'subtitles',function() if gameplay:AreSubtitlesEnabled() then gameplay:SetSubtitlesEnabled(false) end end)
    end
    if now>=g.nextScan then
        g.nextScan=now+0.5
        attempt(g,'subtitle widgets',function()
            for id,entry in pairs(g.widgets) do
                local w=entry.object
                if not valid(w) then g.widgets[id]=nil
                elseif not same(w:GetWorld(),g.world) then restoreWidget(entry);g.widgets[id]=nil end
            end
            local candidates=FindAllOf('SubtitleView') or {}
            if now>=(g.nextWideScan or 0) then
                g.nextWideScan=now+2
                for _,w in ipairs(FindAllOf('UserWidget') or {}) do
                    if valid(w) and w:GetFullName():lower():find('subtitle',1,true) then candidates[#candidates+1]=w end
                end
            end
            local seen={}
            for _,w in ipairs(candidates) do
                if valid(w) then
                    local id=w:GetAddress()
                    if not seen[id] then
                        seen[id]=true
                        if not g.widgets[id] then
                            local world=w:GetWorld()
                            if valid(world) and world:GetAddress()==g.worldId then
                                local key='widget '..tostring(id);g.unsupported[key]=nil
                                g.widgets[id]={object=w,key=key,opacity=w:GetRenderOpacity(),visibility=w:GetVisibility()}
                            end
                        end
                    end
                end
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
    if g.cursor~=nil then pcall(function() g.pc.bShowMouseCursor=g.cursor end) end
    if g.subtitles~=nil then pcall(function() gameplay:SetSubtitlesEnabled(g.subtitles) end) end
    for _,entry in pairs(g.widgets) do
        restoreWidget(entry)
    end
    s.playerUI=nil
end
return M
