local M={}
local controls={'roll','pitch','yaw','throttle'}
function M.parse(line)
    if not line or #line>512 then return nil end
    local n={}
    for word in line:gmatch('%S+') do
        local value=tonumber(word)
        if not value or value~=value or math.abs(value)>1e15 then return nil end
        n[#n+1]=value
    end
    local modern=n[1]==4
    if not ((#n==13 and n[1]==1) or (#n==14 and n[1]==2) or (#n==15 and n[1]==3) or (#n==17 and modern)) or n[2]<1 or n[3]<0 then return nil end
    local lastAxis=modern and 13 or 11
    local buttonIndex=lastAxis+1
    local menuIndex=lastAxis+2
    local deviceIndex=lastAxis+3
    if n[1]>=2 and n[menuIndex]~=0 and n[menuIndex]~=1 then return nil end
    if n[1]>=3 and (n[deviceIndex]<0 or n[deviceIndex]>2000001000 or n[deviceIndex]%1~=0) then return nil end
    if (n[4]~=0 and n[4]~=1) or (n[5]~=0 and n[5]~=1) then return nil end
    local axes={};for i=6,lastAxis do if n[i]<0 or n[i]>65535 then return nil end;axes[#axes+1]=n[i] end
    if n[buttonIndex]<0 or n[buttonIndex]>4294967295 or n[#n]~=n[2] then return nil end
    return {seq=n[2],time=n[3],connected=n[4]==1,focused=n[5]==1,
        axes=axes,buttons=n[buttonIndex],menu=n[1]>=2 and n[menuIndex]==1,device=n[1]>=3 and n[deviceIndex] or nil}
end
function M.controls(packet,c,calibration)
    local u={}
    for _,name in ipairs(controls) do
        local a=calibration and calibration[name]
        local axis=a and a.axis or c[name..'_axis']
        local lo=a and a.min or 0
        local hi=a and a.max or 65535
        local center=a and a.center or 32767.5
        local inv=a and a.invert or (not a and c[name..'_invert'])
        if type(axis)~='number' or axis%1~=0 or axis<1 or axis>8 then error('Invalid axis for '..name) end
        if name~='throttle' and (center<=lo or center>=hi) then error('Invalid center for '..name) end
        local raw=packet.axes[axis]
        if not raw or hi-lo<1000 then error('Invalid calibration for '..name) end
        local value
        if name=='throttle' then value=(raw-lo)/(hi-lo); if inv then value=1-value end
        else
            value=raw>=center and (raw-center)/math.max(1,hi-center) or (raw-center)/math.max(1,center-lo)
            if inv then value=-value end
        end
        u[name]=math.max(name=='throttle' and 0 or -1,math.min(1,value))
    end
    return u
end
return M
