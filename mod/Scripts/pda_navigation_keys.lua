-- Keyboard navigation has its own exchange, independent of joystick state.
-- The duplicated sequence rejects partial writes; epoch time rejects old files
-- after startup, and the local lease rejects a writer that stops updating.
local M={}
local maxInteger=1000000000000000
local leaseSeconds=.25
local epochToleranceSeconds=2
local function finiteNumber(value)
    return type(value)=='number'and value==value and math.abs(value)<=maxInteger
end
local function packet(line)
    if type(line)~='string'then return nil end
    local values={}
    for token in line:gmatch('%S+')do
        if #values==9 or not token:match('^%d+$')then return nil end
        local value=tonumber(token)
        if not finiteNumber(value)or value%1~=0 then return nil end
        values[#values+1]=value
    end
    if #values~=9 or values[1]~=1 or values[2]<1 or values[2]~=values[9]then return nil end
    if values[3]<0 or values[7]<0 or values[8]<0 then return nil end
    for i=4,6 do if values[i]~=0 and values[i]~=1 then return nil end end
    return values
end
function M.new(read,clock,epoch)
    assert(type(read)=='function','Navigation exchange requires a reader')
    clock=clock or os.clock
    epoch=epoch or os.time
    local sequence,advancedAt
    return function()
        local readOk,line=pcall(read)
        if not readOk then return nil end
        local values=packet(line)
        if not values then return nil end
        local clockOk,now=pcall(clock)
        local epochOk,epochNow=pcall(epoch)
        if not clockOk or not epochOk or not finiteNumber(now)or not finiteNumber(epochNow)then return nil end
        if math.abs(epochNow-values[3]/1000)>epochToleranceSeconds then return nil end
        -- A lower fresh sequence is a restarted writer. Repeated snapshots
        -- never extend the lease, even when their timestamp was altered.
        if sequence~=values[2]then sequence=values[2];advancedAt=now end
        if now<advancedAt or now-advancedAt>leaseSeconds or values[4]~=1 then return nil end
        return {q=values[5]==1,e=values[6]==1,qSeq=values[7],eSeq=values[8]}
    end
end
return M
