param([Parameter(Mandatory=$true)][string]$GameRoot)
$ErrorActionPreference='Stop'
if(Get-Process Stalker2-Win64-Shipping -ErrorAction SilentlyContinue){throw 'Close the game first.'}
$game=(Resolve-Path -LiteralPath $GameRoot).Path
if(!(Test-Path -LiteralPath (Join-Path $game 'Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe'))){throw 'Invalid game folder.'}
$mods=(Resolve-Path -LiteralPath (Join-Path $game 'Stalker2\Binaries\Win64\ue4ss\Mods')).Path
$target=[IO.Path]::GetFullPath((Join-Path $mods 'ZoneFPV'))
if([IO.Path]::GetDirectoryName($target) -ne $mods){throw 'Unexpected target.'}
$bridge=Join-Path $target 'ZoneFPVInput.exe'
Get-Process ZoneFPVInput -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $bridge} | Stop-Process
$disabled=Join-Path (Split-Path $mods -Parent) ('ZoneFPV-uninstalled-'+(Get-Date -Format yyyyMMdd-HHmmss))
if(Test-Path -LiteralPath $target){Move-Item -LiteralPath $target -Destination $disabled}
$list=Join-Path $mods 'mods.txt'
if(Test-Path -LiteralPath $list){$text=[IO.File]::ReadAllText($list);$text=$text -replace '(?m)^\s*ZoneFPV\s*:\s*\d+','ZoneFPV : 0';[IO.File]::WriteAllText($list,$text,[Text.UTF8Encoding]::new($false))}
Write-Output "ZoneFPV disabled. Files and preferences preserved at $disabled. UE4SS and other mods unchanged."

$packageDirectory=[IO.Path]::GetFullPath((Join-Path $game 'Stalker2\Content\Paks\~mods'))
$packageTarget=[IO.Path]::GetFullPath((Join-Path $packageDirectory 'ZoneFPV_PlayerScent_P.pak'))
if([IO.Path]::GetDirectoryName($packageTarget) -ne $packageDirectory){throw 'Unexpected package path.'}
if(Test-Path -LiteralPath $packageTarget){
    New-Item -ItemType Directory -Path $disabled -Force | Out-Null
    Move-Item -LiteralPath $packageTarget -Destination (Join-Path $disabled 'ZoneFPV_PlayerScent_P.pak')
}
