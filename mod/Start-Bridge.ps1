$ErrorActionPreference='Stop'
try {
    $exe=Join-Path $PSScriptRoot 'ZoneFPVInput.exe'
    if(!(Test-Path -LiteralPath $exe)){throw 'ZoneFPVInput.exe is missing'}
    $gameProcess=Get-Process -Name Stalker2-Win64-Shipping -ErrorAction SilentlyContinue | Select-Object -First 1
    $existing=Get-Process -Name ZoneFPVInput -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}
    foreach($candidate in $existing){
        $command=(Get-CimInstance Win32_Process -Filter ('ProcessId='+$candidate.Id) -ErrorAction SilentlyContinue).CommandLine
        # Reuse only this game's helper. A standalone or previous-game helper
        # can carry an open menu into loading and block the new character.
        $owned=$gameProcess -and $command -match ('(?:^|\s)--parent-pid\s+"?'+[regex]::Escape([string]$gameProcess.Id)+'"?(?:\s|$)')
        if($owned){exit 0}
        if(!$gameProcess){exit 0}
        Stop-Process -Id $candidate.Id -ErrorAction Stop
        if(!$candidate.WaitForExit(3000)){throw 'Previous input bridge did not close'}
    }
    $bridgeArgs=@('--device','-1')
    if($gameProcess){$bridgeArgs+=@('--parent-pid',[string]$gameProcess.Id)}
    $bridgeProcess=Start-Process -FilePath $exe -ArgumentList $bridgeArgs -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot 'input-bridge.log') -RedirectStandardError (Join-Path $PSScriptRoot 'input-bridge-error.log')
    Start-Sleep -Milliseconds 300
    if($bridgeProcess.HasExited -and $bridgeProcess.ExitCode -ne 6){throw "Input bridge exited: $($bridgeProcess.ExitCode)"}
    exit 0
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'bridge-start-error.log') -Encoding UTF8
    exit 1
}
