local M={}
function M.new(root)
    local nextWrite,seq,wasActive=0,0,false
    return function(now,active,thrust,maximum)
        if now<nextWrite and active==wasActive then return end
        nextWrite=now+(active and 0.04 or 1);seq=seq+1;wasActive=active
        local level=active and math.max(0,math.min(1,math.abs(thrust)/maximum)) or 0
        local file=io.open(root..'audio.txt','w')
        if file then file:write(string.format('1 %d %d %.6f\n',seq,active and 1 or 0,level));file:close() end
    end
end
return M
