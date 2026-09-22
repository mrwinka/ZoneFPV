param([Parameter(Mandatory=$true)][string]$GameRoot)
$ErrorActionPreference='Stop'
if(Get-Process 'Stalker2-Win64-Shipping' -ErrorAction SilentlyContinue){throw 'Close the game first.'}
$GameRoot=(Resolve-Path -LiteralPath $GameRoot).Path
if(!(Test-Path -LiteralPath (Join-Path $GameRoot 'Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe'))){throw 'Invalid STALKER 2 installation folder.'}
$runtime=Join-Path $GameRoot 'Stalker2\Binaries\Win64\ue4ss'
if(!(Test-Path -LiteralPath (Join-Path $runtime 'UE4SS.dll'))){throw 'Install and verify a compatible UE4SS runtime first.'}
$mods=Join-Path $runtime 'Mods'
$target=Join-Path $mods 'ZoneFPV'
if(Test-Path -LiteralPath $target){
    $backup=Join-Path $PSScriptRoot ('backups\ZoneFPV-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination $backup -Recurse
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
$bridgePath=Join-Path $target 'ZoneFPVInput.exe'
Get-Process ZoneFPVInput -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $bridgePath } | Stop-Process
foreach($item in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'mod')){
    if($item.Name -eq 'calibration.lua' -and (Test-Path -LiteralPath (Join-Path $target 'calibration.lua'))){continue}
    Copy-Item -LiteralPath $item.FullName -Destination $target -Recurse -Force
}
$list=Join-Path $mods 'mods.txt'
$text=if(Test-Path -LiteralPath $list){Get-Content -LiteralPath $list -Raw}else{''}
if($text -match '(?m)^\s*ZoneFPV\s*:'){$text=$text -replace '(?m)^\s*ZoneFPV\s*:\s*\d+','ZoneFPV : 1'}else{$text+="`r`nZoneFPV : 1`r`n"}
[IO.File]::WriteAllText($list,$text,[Text.UTF8Encoding]::new($false))
Write-Host "Mod copied to $target. Runtime compatibility still requires in-game verification."
foreach($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'mod') -File -Recurse){
    $relative=$file.FullName.Substring((Join-Path $PSScriptRoot 'mod').Length+1)
    if($relative -eq 'calibration.lua'){continue}
    if((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $target $relative)).Hash){throw "Installed file mismatch: $relative"}
}
