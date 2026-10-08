param([Parameter(Mandatory=$true)][string]$GameRoot)
$ErrorActionPreference='Stop'
if(Get-Process Stalker2-Win64-Shipping -ErrorAction SilentlyContinue){throw 'Close the game first.'}
$game=(Resolve-Path -LiteralPath $GameRoot).Path
if(!(Test-Path -LiteralPath (Join-Path $game 'Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe'))){throw 'Invalid game folder.'}
function Assert-ChildPath([string]$Path,[string]$Parent,[string]$Leaf){
    $absolute=[IO.Path]::GetFullPath($Path)
    if([IO.Path]::GetDirectoryName($absolute) -ne [IO.Path]::GetFullPath($Parent) -or ($Leaf -and [IO.Path]::GetFileName($absolute) -ne $Leaf)){throw 'Unexpected uninstall path.'}
    return $absolute
}
$runtime=[IO.Path]::GetFullPath((Join-Path $game 'Stalker2\Binaries\Win64\ue4ss'))
$mods=Assert-ChildPath (Join-Path $runtime 'Mods') $runtime 'Mods'
$target=Assert-ChildPath (Join-Path $mods 'ZoneFPV') $mods 'ZoneFPV'
$bridge=Join-Path $target 'ZoneFPVInput.exe'
Get-Process ZoneFPVInput -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $bridge} | Stop-Process
$disabled=Assert-ChildPath (Join-Path $runtime ('ZoneFPV-uninstalled-'+(Get-Date -Format yyyyMMdd-HHmmss-fff)+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))) $runtime ''
$preserved=$false
if(Test-Path -LiteralPath $target){
    $checkedTarget=Assert-ChildPath (Resolve-Path -LiteralPath $target).Path $mods 'ZoneFPV'
    Move-Item -LiteralPath $checkedTarget -Destination $disabled
    $preserved=$true
}
$list=Assert-ChildPath (Join-Path $mods 'mods.txt') $mods 'mods.txt'
if(Test-Path -LiteralPath $list){$text=[IO.File]::ReadAllText($list);$text=$text -replace '(?m)^\s*ZoneFPV\s*:\s*\d+','ZoneFPV : 0';[IO.File]::WriteAllText($list,$text,[Text.UTF8Encoding]::new($false))}
$packageDirectory=[IO.Path]::GetFullPath((Join-Path $game 'Stalker2\Content\Paks\~mods'))
# Exact leaf allowlist also works if only a companion PAK remains installed.
foreach($packageName in @('ZoneFPV_Armament_P.pak','ZoneFPV_PlayerScent_P.pak')){
    $packageTarget=Assert-ChildPath (Join-Path $packageDirectory $packageName) $packageDirectory $packageName
    if(Test-Path -LiteralPath $packageTarget){
        $checkedPackage=Assert-ChildPath (Resolve-Path -LiteralPath $packageTarget).Path $packageDirectory $packageName
        $savedPackage=Assert-ChildPath (Join-Path $disabled $packageName) $disabled $packageName
        New-Item -ItemType Directory -Path $disabled -Force | Out-Null
        Move-Item -LiteralPath $checkedPackage -Destination $savedPackage
        $preserved=$true
    }
}
if($preserved){Write-Output "ZoneFPV disabled. Files, preferences and own PAKs preserved at $disabled. UE4SS and other mods unchanged."}
else{Write-Output 'ZoneFPV disabled. No installed ZoneFPV files found. UE4SS and other mods unchanged.'}
