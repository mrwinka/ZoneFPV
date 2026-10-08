local M={}
local serial=0
local function address(o)
    local ok,v=pcall(function()assert(o:IsValid());return o:GetAddress()end)
    if ok and type(v)=='number' and v>=0x10000 and v<0x800000000000 and v%8==0 then return v end
end
function M.new(root,loader)
    loader=loader or package.loadlib
    local client={root=root}
    function client:arm(component,pawn)
        local c,p=address(component),address(pawn)
        if not c or not p then return false,'Geiger owner identity unavailable' end
        local funcs={}
        for _,name in ipairs({'arm','tick','poll','disarm'})do
            local ok,fn=pcall(loader,root..'ZoneFPVNative.dll','zonefpv_geiger_'..name)
            if not ok or type(fn)~='function' then return false,'native Geiger '..name..' unavailable' end
            funcs[name]=fn
        end
        self.funcs=funcs
        serial=math.max(serial+1,math.floor(os.clock()*1000000),1);self.token=serial
        local f,why=io.open(root..'native-geiger-control.txt','wb');if not f then return false,why end
        local written=f:write(string.format('ZFPVG12 %d %x %x\n',serial,c,p));local closed=f:close()
        if not written or not closed then return false,'native Geiger request write failed' end
        os.remove(root..'native-geiger-status.txt')
        local ok,err=pcall(funcs.arm);if not ok then return false,tostring(err) end
        ok,err=self:poll()
        if not ok then self:disarm();return false,err end
        self.active=true;self.component=component;self.pawn=pawn;self.componentAddress=c;self.pawnAddress=p
        return true
    end
    function client:poll()
        local ok,err=pcall(self.funcs.poll);if not ok then return false,tostring(err) end
        local f=io.open(root..'native-geiger-status.txt','rb');if not f then return false,'native Geiger status unavailable' end
        local text=f:read(160);local extra=f:read(1);f:close()
        if extra or type(text)~='string' then return false,'native Geiger status malformed' end
        local ready,active,token,blocked,stopped,code=text:match('^ZFPVG12 ([01]) ([01]) (%d+) (%d+) (%d+) (%d+)%s*$')
        if ready~='1' or active~='1' or tonumber(token)~=self.token or code~='0' then return false,'native Geiger guard rejected (code '..tostring(code)..')' end
        self.blocked=tonumber(blocked);self.stopped=tonumber(stopped);return true
    end
    function client:tick()
        if not self.active then return false end
        if address(self.component)~=self.componentAddress or address(self.pawn)~=self.pawnAddress then self:disarm();return false end
        local ok=pcall(self.funcs.tick);if not ok then self:disarm() end
        return ok
    end
    function client:disarm()
        self.active=false
        if self.funcs and self.funcs.disarm then pcall(self.funcs.disarm) end
    end
    return client
end
return M
