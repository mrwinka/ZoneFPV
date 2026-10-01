param([string]$GameRoot='D:\SteamLibrary\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl',[int]$Device=-1)
$ErrorActionPreference='Stop'
$target=Join-Path $GameRoot 'Stalker2\Binaries\Win64\ue4ss\Mods\ZoneFPV'
$exe=Join-Path $target 'ZoneFPVInput.exe'
if(!(Test-Path -LiteralPath $exe)){throw 'Install the mod first.'}
if(Get-Process ZoneFPVInput -ErrorAction SilentlyContinue){throw 'Input bridge already running.'}
$arguments=@('--device',"$Device")
$p=Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $target -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $target 'input-bridge.log') -RedirectStandardError (Join-Path $target 'input-bridge-error.log')
Start-Sleep -Milliseconds 500
if($p.HasExited){throw "Input bridge exited. Read input-bridge-error.log in $target"}
Write-Host "Radio input running. PID: $($p.Id). After playing: Stop-Process -Id $($p.Id)"
