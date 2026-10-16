local M={}
function M.parse(text)
    if type(text)~='string' or #text>160 then return end
    local seq,ram,commit,known,used,max=text:match('^ZFPVR11 (%d+) (%d+) (%d+) ([01]) (%d+) (%d+)%s*$')
    seq,ram,commit,used,max=tonumber(seq),tonumber(ram),tonumber(commit),tonumber(used),tonumber(max)
    if not seq or seq<1 or seq>2^53 or ram>2^40 or commit>2^40 or not max or used>max or max>32000000 then return end
    if known=='1' and max<65536 then return end
    return {seq=seq,ram=ram,commit=commit,known=known=='1',used=used,maximum=max}
end
function M.level(s)
    if not s then return 0 end
    -- Windows can reclaim cached/paged physical memory while commit still has
    -- ample headroom. Low available RAM alone must not block F8 or streaming.
    -- NumElements is an allocation high-water mark, not a live-object count.
    -- Near capacity even a single streaming batch can exhaust new indices.
    if s.commit<256 then return 2 end
    if s.known and s.used>=s.maximum*.97 then return 2 end
    if s.commit<2048 or s.known and s.used>=s.maximum*.90 then return 1 end
    return 0
end
local function recovered(s)
    return s.commit>=3072 and (not s.known or s.used<s.maximum*.85)
end
function M.streamingLimited(s)
    -- Leave the saved selection intact; restore native loading ranges until
    -- there is room for an increased streaming batch. RAM alone is irrelevant.
    return not s or not s.known or s.commit<2048 or s.used>=s.maximum*.80
end
local function reason(s)
    if s.commit<256 then return 'available system commit below 256 MB' end
    return 'UObject allocation high-water at 97% of capacity'
end
function M.new(root,log,loader)
    loader=loader or (package and package.loadlib)
    local g={next=0,lastSeq=0,level=0}
    local statusPath=root..'native-resources-status.txt'
    function g:close()
        local file=self.resourceFile;self.resourceFile=nil
        if file then pcall(function()file:close()end)end
    end
    local function readStatus(self)
        -- Old DLLs replace the status path atomically. Their readers must
        -- reopen every sample; a retained handle would follow the old inode.
        if not self.persistentIO then
            local ok,file=pcall(io.open,statusPath,'r')
            if not ok or not file then return end
            local readOK,text=pcall(function()return file:read(161)end)
            pcall(function()file:close()end)
            local sample=readOK and M.parse(text)
            if sample and sample.seq>self.lastSeq then return sample end
            return
        end
        -- The capability export proves the DLL writes synchronously through
        -- one stable file. No CRT read-ahead may outlive a native publication.
        -- A failed/stale read drops that handle and gets one bounded retry,
        -- recovering replacements without ever renewing an old sample.
        for _=1,2 do
            local file=self.resourceFile
            if not file then
                local ok,value=pcall(io.open,statusPath,'rb')
                if ok then file=value end
                if file then
                    self.resourceFile=file
                    local buffered,accepted=pcall(function()return file:setvbuf('no')end)
                    if not buffered or not accepted then self:close();file=nil end
                end
            end
            if file then
                local sought,offset=pcall(function()return file:seek('set',0)end)
                if sought and offset==0 then
                    local readOK,text=pcall(function()return file:read(161)end)
                    local sample=readOK and M.parse(text)
                    if sample and sample.seq>self.lastSeq then return sample end
                end
                self:close()
            end
        end
    end
    function g:update(now,active)
        if now<self.next then return self.level,self.sample end
        self.next=now+(active and .1 or .5)
        if not self.openAttempted then
            self.openAttempted=true
            if type(loader)=='function' then
                local ok,poll=pcall(loader,root..'ZoneFPVNative.dll','zonefpv_resources_poll')
                if ok then self.poll=poll end
                if type(self.poll)=='function'then
                    local available,capability=pcall(loader,root..'ZoneFPVNative.dll','zonefpv_resources_persistent_io')
                    self.persistentIO=available and type(capability)=='function'or false
                end
            end
            if type(self.poll)~='function' then self.poll=nil end
        end
        if not self.poll or not pcall(self.poll) then self:close();return self.level,self.sample end
        local sample=readStatus(self)
        if not sample then return self.level,self.sample end
        self.lastSeq=sample.seq;self.sample=sample
        if M.streamingLimited(sample) then self.streamingLimited=true
        elseif self.streamingLimited~=true or sample.commit>=3072 and sample.used<sample.maximum*.75 then
            self.streamingLimited=false
        end
        local wanted=M.level(sample)
        local level=self.level
        if wanted==2 then
            level=2;self.reason=reason(sample);self.pressureSince=nil;self.recoverySince=nil
        elseif self.level==2 then
            -- The entry block needs its own small recovery band. Keeping it
            -- until 3 GB recovered stranded F8 at 734 MB despite tiny sensors.
            if sample.commit>=512 then level=1;self.reason=nil;self.recoverySince=nil end
        elseif self.level>0 then
            self.pressureSince=nil
            if recovered(sample) then
                self.recoverySince=self.recoverySince or now
                if now-self.recoverySince>=5 then level=0;self.recoverySince=nil end
            else self.recoverySince=nil end
        elseif wanted==1 then
            self.pressureSince=self.pressureSince or now
            if now-self.pressureSince>=2 then level=1;self.pressureSince=nil end
        else self.pressureSince=nil;self.recoverySince=nil end
        if level~=self.level then
            log(string.format('Resource guard: level=%d RAM free=%d MB commit free=%d MB object high-water=%d/%d',level,sample.ram,sample.commit,sample.used,sample.maximum))
        end
        self.level=level;return level,sample
    end
    return g
end
return M
