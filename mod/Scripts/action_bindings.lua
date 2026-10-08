-- Independent action counters preserve short taps between game callbacks.
-- The menu counter is carried for protocol stability; the input helper owns it.
local M={}
local maximum=1000000000000000
local lease=.25
local epochTolerance=2
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<=maximum
end
function M.parse(line)
    if type(line)~='string' or #line>256 then return nil end
    local values={}
    for token in line:gmatch('%S+')do
        if #values>=14 or not token:match('^%d+$')then return nil end
        local value=tonumber(token)
        if not finite(value) or value%1~=0 then return nil end
        values[#values+1]=value
    end
    local version=values[1]
    if not (version==1 and #values==9 or version==2 and #values==10 or version==3 and #values==12 or (version==4 or version==5)and #values==14) or values[2]<1 or values[2]~=values[#values] or
        values[4]~=0 and values[4]~=1 then return nil end
    local held=version>=4 and values[13]or 0
    local allowed=version==5 and 255 or 176
    if held>allowed or (held & allowed)~=held then return nil end
    return {version=version,sequence=values[2],epoch=values[3],focused=values[4]==1,
        counters={values[5],values[6],values[7],values[8],version>=2 and values[9] or 0,
            version>=3 and values[10] or 0,version>=3 and values[11] or 0,version>=4 and values[12]or 0},held=held}
end
function M.new(read,clock,epoch)
    assert(type(read)=='function','Action exchange requires a reader')
    clock=clock or os.clock;epoch=epoch or os.time
    local sequence,advancedAt,counters,primed,wasFocused,version,previousHeld,lastLine
    local function discard()primed=false;wasFocused=false;lastLine=nil;return nil end
    return function()
        local ok,line=pcall(read)
        -- Atomic Windows replacement may briefly deny opening the exchange.
        -- Reuse only the last validated sample inside its original sequence
        -- lease; a malformed readable packet is never replaced with old data.
        if not ok or line==nil then line=lastLine end
        local p=M.parse(line)
        if not p then return discard()end
        local clockOK,now=pcall(clock);local epochOK,epochNow=pcall(epoch)
        if not clockOK or not epochOK or not finite(now) or not finite(epochNow) or
            math.abs(epochNow-p.epoch/1000)>epochTolerance then return discard()end
        if counters and sequence==p.sequence then
            for i=1,8 do if p.counters[i]~=counters[i] then return discard()end end
            if p.held~=previousHeld then return discard()end
        end
        local restarted=sequence and (p.sequence<sequence or p.version~=version)
        if sequence~=p.sequence then sequence=p.sequence;advancedAt=now end
        if now<advancedAt or now-advancedAt>lease then return discard()end
        if counters then
            for i=1,8 do
                if p.counters[i]<counters[i] then restarted=true end
            end
        end
        local result={ready=true,version=p.version,focused=p.focused,sourceHeld=p.held,
            active=primed and wasFocused and p.focused and not restarted or false,
            pilot=false,reset=false,collect=false,flashlight=false,cameraDown=false,grenadeDrop=false,vision=false,
            menuHeld=false,pilotHeld=false,resetHeld=false,collectHeld=false,flashlightHeld=false,cameraDownHeld=false,grenadeDropHeld=false,visionHeld=false}
        -- Consume paused snapshots. Prime again on startup, focus recovery,
        -- writer restart or a lease/parse interruption; old presses never replay.
        if primed and wasFocused and p.focused and not restarted then
            result.pilot=p.counters[2]>counters[2]
            result.reset=p.counters[3]>counters[3]
            result.collect=p.counters[4]>counters[4]
            result.flashlight=p.counters[5]>counters[5]
            result.cameraDown=p.counters[6]>counters[6]
            result.grenadeDrop=p.counters[7]>counters[7]
            result.vision=p.counters[8]>counters[8]
            result.menuHeld=(p.held & 1)~=0
            result.pilotHeld=(p.held & 2)~=0
            result.resetHeld=(p.held & 4)~=0
            result.collectHeld=(p.held & 8)~=0
            result.flashlightHeld=(p.held & 16)~=0
            result.cameraDownHeld=(p.held & 32)~=0
            result.grenadeDropHeld=(p.held & 64)~=0
            result.visionHeld=(p.held & 128)~=0
        end
        counters=p.counters;primed=true;wasFocused=p.focused;version=p.version;previousHeld=p.held;lastLine=line
        return result
    end
end
return M
