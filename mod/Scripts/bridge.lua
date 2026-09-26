local M={}
local function encodedCommand(text)
    local units={}
    for _,code in utf8.codes(text) do
        if code>0xffff then code=code-0x10000;local high=0xd800+(code>>10);units[#units+1]=string.char(high&255,high>>8);code=0xdc00+(code&1023) end
        units[#units+1]=string.char(code&255,code>>8)
    end
    local bytes=table.concat(units);local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local out={}
    for i=1,#bytes,3 do
        local a,b,c=bytes:byte(i,i+2);local bits=(a<<16)|((b or 0)<<8)|(c or 0)
        out[#out+1]=alphabet:sub(((bits>>18)&63)+1,((bits>>18)&63)+1)..alphabet:sub(((bits>>12)&63)+1,((bits>>12)&63)+1)..(b and alphabet:sub(((bits>>6)&63)+1,((bits>>6)&63)+1) or '=')..(c and alphabet:sub((bits&63)+1,(bits&63)+1) or '=')
    end
    return table.concat(out)
end
function M.start(root)
    if root:find('[\0\r\n"]') then return false,'Unsupported characters in mod path' end
    local file=io.open(root..'Start-Bridge.ps1','r')
    if not file then return false,'Start-Bridge.ps1 is missing' end
    file:close()
    -- ExecutionPolicy applies to this child process only; no system policy change.
    -- Encode the complete literal script path, preserving Unicode and preventing
    -- cmd.exe expansion of %, &, ! and other legal filename characters.
    local script="& '"..(root..'Start-Bridge.ps1'):gsub("'","''").."'"
    -- Do not set WindowStyle here: PowerShell can inherit UE4SS's console,
    -- and hiding that shared window also hides the user's console. The script
    -- starts the separate bridge process hidden; this bootstrap never hides it.
    local ok=os.execute('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand '..encodedCommand(script))
    if ok then return true end
    return false,'See bridge-start-error.log / input-bridge-error.log'
end
return M
