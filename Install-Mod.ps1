param([Parameter(Mandatory=$true)][string]$GameRoot)
$ErrorActionPreference='Stop'
function Assert-ChildPath([string]$Path,[string]$Parent,[string]$Leaf){
    $absolute=[IO.Path]::GetFullPath($Path)
    if([IO.Path]::GetDirectoryName($absolute) -ne [IO.Path]::GetFullPath($Parent) -or ($Leaf -and [IO.Path]::GetFileName($absolute) -ne $Leaf)){throw 'Unexpected installer path.'}
    return $absolute
}
# Required companion archive is checked before any game/helper/runtime changes.
$armamentName='ZoneFPV_Armament_P.pak'
$packageSourceDirectory=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'packages'))
$armamentSource=Assert-ChildPath (Join-Path $packageSourceDirectory $armamentName) $packageSourceDirectory $armamentName
if(!(Test-Path -LiteralPath $armamentSource -PathType Leaf)){throw 'Required ZoneFPV armament PAK is missing. Extract the complete release before installing.'}
$armamentSourceHash=(Get-FileHash -LiteralPath $armamentSource).Hash
if(Get-Process 'Stalker2-Win64-Shipping' -ErrorAction SilentlyContinue){throw 'Close the game first.'}
$GameRoot=(Resolve-Path -LiteralPath $GameRoot).Path
if(!(Test-Path -LiteralPath (Join-Path $GameRoot 'Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe'))){throw 'Invalid STALKER 2 installation folder.'}
$runtime=Join-Path $GameRoot 'Stalker2\Binaries\Win64\ue4ss'
if(!(Test-Path -LiteralPath (Join-Path $runtime 'UE4SS.dll'))){throw 'Install and verify a compatible UE4SS runtime first.'}
. (Join-Path $PSScriptRoot 'Runtime-Settings.ps1')
$runtimeSettings=Join-Path $runtime 'UE4SS-settings.ini'
$settingsExisted=Test-Path -LiteralPath $runtimeSettings
[byte[]]$settingsBytes=@()
$settingsText=''
if($settingsExisted){$settingsBytes=[IO.File]::ReadAllBytes($runtimeSettings);$settingsText=[IO.File]::ReadAllText($runtimeSettings)}
$safeSettings=Get-ZoneFpvRuntimeSettings $settingsText
$settingsChanged=$false
$mods=[IO.Path]::GetFullPath((Join-Path $runtime 'Mods'))
$target=Assert-ChildPath (Join-Path $mods 'ZoneFPV') $mods 'ZoneFPV'
$list=Assert-ChildPath (Join-Path $mods 'mods.txt') $mods 'mods.txt'
$backupRoot=Assert-ChildPath (Join-Path $PSScriptRoot 'backups') $PSScriptRoot 'backups'
$packageDirectory=[IO.Path]::GetFullPath((Join-Path $GameRoot 'Stalker2\Content\Paks\~mods'))
$armamentTarget=Assert-ChildPath (Join-Path $packageDirectory $armamentName) $packageDirectory $armamentName
$armamentExisted=Test-Path -LiteralPath $armamentTarget
[byte[]]$armamentBytes=@()
if($armamentExisted){$armamentBytes=[IO.File]::ReadAllBytes($armamentTarget)}
$armamentChanged=$false
$targetExisted=Test-Path -LiteralPath $target
$listExisted=Test-Path -LiteralPath $list
[byte[]]$listBytes=@()
if($listExisted){$listBytes=[IO.File]::ReadAllBytes($list)}
$bridgePath=Join-Path $target 'ZoneFPVInput.exe'
Get-Process ZoneFPVInput -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $bridgePath } | Stop-Process
if($targetExisted -or $armamentExisted){
    $backup=Assert-ChildPath (Join-Path $backupRoot ('ZoneFPV-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))) $backupRoot ''
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    if($targetExisted){
        Copy-Item -LiteralPath $target -Destination $backup -Recurse
        $previousTarget=Assert-ChildPath (Join-Path $backup 'ZoneFPV') $backup 'ZoneFPV'
    }
    if($armamentExisted){
        $previousArmament=Assert-ChildPath (Join-Path $backup $armamentName) $backup $armamentName
        [IO.File]::WriteAllBytes($previousArmament,$armamentBytes)
    }
    if($settingsExisted){[IO.File]::WriteAllBytes((Join-Path $backup 'UE4SS-settings.ini'),$settingsBytes)}
}
if($settingsExisted -and !$targetExisted -and $safeSettings -ne $settingsText){
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $settingsBackup=Assert-ChildPath (Join-Path $backupRoot ('UE4SS-settings-'+[guid]::NewGuid().ToString('N')+'.ini')) $backupRoot ''
    [IO.File]::WriteAllBytes($settingsBackup,$settingsBytes)
}
$scentMoved=$false
$failedTarget=$null
try {
if($safeSettings -ne $settingsText){
    $settingsChanged=$true
    [IO.File]::WriteAllText($runtimeSettings,$safeSettings,[Text.UTF8Encoding]::new($false))
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach($item in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'mod')){
    if($item.Name -match '^(?:native-[a-z]+(?:-[a-z]+)*-(control|status|profile|manager)|scan-frame(?:-[ab])?)\.txt(\.tmp)?$'){continue}
    if($item.Name -eq 'calibration.lua' -and (Test-Path -LiteralPath (Join-Path $target 'calibration.lua'))){continue}
    Copy-Item -LiteralPath $item.FullName -Destination $target -Recurse -Force
}
$text=if(Test-Path -LiteralPath $list){[IO.File]::ReadAllText($list)}else{''}
if($text -match '(?m)^\s*ZoneFPV\s*:'){$text=$text -replace '(?m)^\s*ZoneFPV\s*:\s*\d+','ZoneFPV : 1'}else{$text+="`r`nZoneFPV : 1`r`n"}
[IO.File]::WriteAllText($list,$text,[Text.UTF8Encoding]::new($false))
foreach($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'mod') -File -Recurse){
    if($file.Name -match '^(?:native-[a-z]+(?:-[a-z]+)*-(control|status|profile|manager)|scan-frame(?:-[ab])?)\.txt(\.tmp)?$'){continue}
    $relative=$file.FullName.Substring((Join-Path $PSScriptRoot 'mod').Length+1)
    if($relative -eq 'calibration.lua'){continue}
    if((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $target $relative)).Hash){throw "Installed file mismatch: $relative"}
}

# Install only our named companion archive; existing game/mod PAKs are untouched.
New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
$armamentChanged=$true # Copy can create/overwrite partial bytes before throwing.
Copy-Item -LiteralPath $armamentSource -Destination $armamentTarget -Force
if((Get-FileHash -LiteralPath $armamentTarget).Hash -ne $armamentSourceHash){throw 'Installed armament PAK mismatch.'}

# Retire the failed scent experiment without touching other mods/base archives.
$packageTarget=Assert-ChildPath (Join-Path $packageDirectory 'ZoneFPV_PlayerScent_P.pak') $packageDirectory 'ZoneFPV_PlayerScent_P.pak'
if(Test-Path -LiteralPath $packageTarget){
    $retiredDirectory=$backupRoot
    New-Item -ItemType Directory -Path $retiredDirectory -Force | Out-Null
    $retiredPackage=Assert-ChildPath (Join-Path $retiredDirectory ('retired-player-scent-'+[guid]::NewGuid().ToString('N')+'.pak')) $retiredDirectory ''
    Move-Item -LiteralPath $packageTarget -Destination $retiredPackage
    $scentMoved=$true
    Write-Output 'Removed experimental scent PAK from game; retained backup.'
}

foreach($retiredName in @('camera_streaming.lua','draw_distance.lua','streaming.lua','player_scent.lua','region_lighting.lua','region_diagnostic.lua','outdoor_weather.lua','cnpp_probe.lua','effect_diagnostic.lua','mutant_diagnostic.lua','terrain_guard.lua')){
    $retiredFile=Join-Path $target ('Scripts\'+$retiredName)
    if(Test-Path -LiteralPath $retiredFile){Remove-Item -LiteralPath $retiredFile}
}

# Retire the CNPP probe switch; preserve existing captured reports/settings.
$probeMarker=Join-Path $target 'cnpp-probe.enabled'
if(Test-Path -LiteralPath $probeMarker){Remove-Item -LiteralPath $probeMarker}
Write-Host "Mod copied to $target. Runtime compatibility still requires in-game verification."
Write-Output "Armament PAK copied and hash verified: $armamentTarget"
Write-Output 'Runtime dispatch: EngineTick enabled; unsafe ProcessEvent action pump disabled.'
} catch {
    $installationError=$_
    $rollbackErrors=[System.Collections.Generic.List[string]]::new()
    try {
        if(Test-Path -LiteralPath $target){
            $checkedTarget=Assert-ChildPath (Resolve-Path -LiteralPath $target).Path $mods 'ZoneFPV'
            # Directory moves must stay on the game's drive. Keep failed files
            # outside Mods so UE4SS cannot discover them as another Lua mod.
            $failedTarget=Assert-ChildPath (Join-Path $runtime ('ZoneFPV-failed-install-'+[guid]::NewGuid().ToString('N'))) $runtime ''
            Move-Item -LiteralPath $checkedTarget -Destination $failedTarget
        }
        if($targetExisted){
            $checkedBackup=Assert-ChildPath (Resolve-Path -LiteralPath $previousTarget).Path $backup 'ZoneFPV'
            Copy-Item -LiteralPath $checkedBackup -Destination $target -Recurse
        }
    } catch {$rollbackErrors.Add('Mod files: '+$_.Exception.Message)}
    try {
        if($listExisted){[IO.File]::WriteAllBytes($list,$listBytes)}
        elseif(Test-Path -LiteralPath $list){Remove-Item -LiteralPath $list}
    } catch {$rollbackErrors.Add('mods.txt: '+$_.Exception.Message)}
    try {
        if($settingsChanged){
            if($settingsExisted){[IO.File]::WriteAllBytes($runtimeSettings,$settingsBytes)}
            elseif(Test-Path -LiteralPath $runtimeSettings){Remove-Item -LiteralPath $runtimeSettings}
        }
    } catch {$rollbackErrors.Add('UE4SS-settings.ini: '+$_.Exception.Message)}
    try {
        if($armamentChanged){
            $checkedArmament=Assert-ChildPath $armamentTarget $packageDirectory $armamentName
            if($armamentExisted){[IO.File]::WriteAllBytes($checkedArmament,$armamentBytes)}
            elseif(Test-Path -LiteralPath $checkedArmament){Remove-Item -LiteralPath $checkedArmament}
        }
    } catch {$rollbackErrors.Add('Armament package: '+$_.Exception.Message)}
    try {
        if($scentMoved){Move-Item -LiteralPath $retiredPackage -Destination $packageTarget}
    } catch {$rollbackErrors.Add('Retired scent package: '+$_.Exception.Message)}
    if($rollbackErrors.Count){Write-Warning ('Installation failed; rollback also needs attention: '+($rollbackErrors -join '; '))}
    elseif($failedTarget){Write-Warning "Installation failed; previous mod files, armament PAK and mods.txt were restored. Partial files retained at $failedTarget."}
    else {Write-Warning 'Installation failed; previous mod files, armament PAK and mods.txt were restored.'}
    throw $installationError
}
