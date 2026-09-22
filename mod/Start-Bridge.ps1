$ErrorActionPreference='Stop'
try {
    $exe=Join-Path $PSScriptRoot 'ZoneFPVInput.exe'
    if(!(Test-Path -LiteralPath $exe)){throw 'ZoneFPVInput.exe is missing'}
    if(Get-Process -Name ZoneFPVInput -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}){exit 0}
    $bridgeArgs=@('--device','-1')
    $gameProcess=Get-Process -Name Stalker2-Win64-Shipping -ErrorAction SilentlyContinue | Select-Object -First 1
    if($gameProcess){$bridgeArgs+=@('--parent-pid',[string]$gameProcess.Id)}
    $bridgeProcess=Start-Process -FilePath $exe -ArgumentList $bridgeArgs -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot 'input-bridge.log') -RedirectStandardError (Join-Path $PSScriptRoot 'input-bridge-error.log')
    Start-Sleep -Milliseconds 300
    if($bridgeProcess.HasExited -and $bridgeProcess.ExitCode -ne 6){throw "Input bridge exited: $($bridgeProcess.ExitCode)"}
    exit 0
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'bridge-start-error.log') -Encoding UTF8
    exit 1
}
