-- FGeometry has unreflected native members. Keep it inside the native query;
-- only scalar coordinates cross the Lua boundary.
local M={}
local nextToken=0
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function address(object)
    local ok,value=pcall(function()assert(object:IsValid());return object:GetAddress()end)
    if ok and finite(value)and value%1==0 and value>=0x10000 and value<0x800000000000 and value%8==0 then return value end
end
local function read(object,key)local ok,value=pcall(function()return object[key]end);if ok then return value end end
function M.parse(text,token)
    if type(text)~='string'or #text>512 then return nil,'invalid_status'end
    local id,ok,code,width,height,x,y=text:match('^ZFPVPG51 (%d+) ([01]) (%d+) (%S+) (%S+) (%S+) (%S+)%s*$')
    id,code,width,height,x,y=tonumber(id),tonumber(code),tonumber(width),tonumber(height),tonumber(x),tonumber(y)
    if id~=token or not code or code%1~=0 or code<0 or code>255 then return nil,'invalid_status'end
    if ok=='0'then return nil,'native_'..code end
    if code~=0 or not finite(width)or not finite(height)or width<=1 or height<=1 or width>1000000 or height>1000000
        or not finite(x)or not finite(y)or math.abs(x)>1000000000 or math.abs(y)>1000000000 then return nil,'invalid_geometry'end
    return {width=width,height=height,x=x,y=y}
end
function M.new(root,adapter)
    adapter=adapter or {};root=root or ''
    local load=adapter.load or package.loadlib
    local function write(path,text)
        if adapter.write then return adapter.write(path,text)end
        local file=io.open(path,'wb');if not file then return false end
        local written=file:write(text);local closed=file:close();return not not(written and closed)
    end
    local function status(path)
        if adapter.read then return adapter.read(path,512)end
        local file=io.open(path,'rb');if not file then return end
        local value=file:read(513);file:close();return value
    end
    local queryFunction,tried
    return {query=function(widget,slate,layout)
        local addresses={address(widget),address(read(widget,'GetCachedGeometry')),address(slate),address(read(slate,'GetLocalSize')),
            address(read(slate,'AbsoluteToLocal')),address(layout),address(read(layout,'GetMousePositionOnPlatform'))}
        for i=1,7 do if not addresses[i]then return nil,'invalid_object_'..i end end
        if not tried then
            tried=true
            local ok,value=pcall(load,root..'ZoneFPVNative.dll','zonefpv_pda_geometry_query')
            if ok and type(value)=='function'then queryFunction=value end
        end
        if not queryFunction then return nil,'native_unavailable'end
        nextToken=nextToken+1
        local fields={};for i,value in ipairs(addresses)do fields[i]=string.format('%x',value)end
        -- A module reload restarts its counter. Clear the owned response before
        -- publishing, so even a colliding old token cannot survive a failed
        -- native response replacement. A failed clear cannot issue a query.
        if not write(root..'native-pda-geometry-status.txt','')then return nil,'reset_failed'end
        if not write(root..'native-pda-geometry-control.txt','ZFPVPG51 '..nextToken..' '..table.concat(fields,' ')..'\n')then return nil,'write_failed'end
        local ok=pcall(queryFunction);if not ok then return nil,'query_failed'end
        return M.parse(status(root..'native-pda-geometry-status.txt'),nextToken)
    end}
end
return M
