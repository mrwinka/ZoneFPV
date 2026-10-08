$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $project ('build\installer-fixture-'+[guid]::NewGuid().ToString('N'))
$win64=Join-Path $fixture 'Stalker2\Binaries\Win64'
$runtime=Join-Path $win64 'ue4ss'
$mod=Join-Path $runtime 'Mods\ZoneFPV'
$pakDirectory=Join-Path $fixture 'Stalker2\Content\Paks\~mods'
$armamentName='ZoneFPV_Armament_P.pak'
$armamentSource=Join-Path $project ('packages\'+$armamentName)
$armamentTarget=Join-Path $pakDirectory $armamentName
$unrelatedPak=Join-Path $pakDirectory 'OtherUserMod_P.pak'
$basePak=Join-Path $fixture 'Stalker2\Content\Paks\pakchunk-fixture.pak'
New-Item -ItemType Directory -Path $mod -Force | Out-Null
New-Item -ItemType Directory -Path $pakDirectory -Force | Out-Null
$previousArmament=[Text.Encoding]::UTF8.GetBytes('previous armament fixture '+[guid]::NewGuid().ToString('N'))
[IO.File]::WriteAllBytes($armamentTarget,$previousArmament)
[IO.File]::WriteAllText($unrelatedPak,'unrelated mod PAK bytes')
[IO.File]::WriteAllText($basePak,'base game PAK bytes')
[IO.File]::WriteAllText((Join-Path $win64 'Stalker2-Win64-Shipping.exe'),'fixture only - not executable')
[IO.File]::WriteAllText((Join-Path $runtime 'UE4SS.dll'),'fixture only')
$runtimeConfig="[General]`r`nDefaultExecuteInGameThreadMethod = ProcessEvent`r`nUseCache = 1`r`n[Hooks]`r`nHookEngineTick = 0`r`nHookUObjectProcessEvent = 1`r`nHookLocalPlayerExec = 0`r`n"
[IO.File]::WriteAllText((Join-Path $runtime 'UE4SS-settings.ini'),$runtimeConfig)
$unicodeModName=-join (@(0x041c,0x043e,0x0434) | ForEach-Object {[char]$_})
[IO.File]::WriteAllText((Join-Path $runtime 'Mods\mods.txt'),"OtherMod : 1`r`n$unicodeModName : 1`r`nZoneFPV : 0`r`n",[Text.UTF8Encoding]::new($false))
$preferences=@{'calibration-123.lua'='custom';'calibration.lua'='legacy';'bindings.txt'='117 119 120';'osd-layout.txt'='keep-layout';'controller.txt'='123';'experiment-settings.txt'='1 3 1 1 1 1 0 1 1 1';'impact-settings.txt'='0.5';'signal-settings.txt'='1 1500';'flight-settings.txt'='2 25';'world-distance.txt'='6';'weapon-settings.txt'='1 2 2.25 1 0'}
foreach($name in $preferences.Keys){[IO.File]::WriteAllText((Join-Path $mod $name),$preferences[$name])}
$preferences['native-combat-status.txt']='preserve live native diagnostics'
$preferences['native-visual-status.txt']='preserve live effect diagnostics'
$preferences['native-achievements-status.txt']='preserve prior achievement initialization diagnostics'
$preferences['native-achievements-check-status.txt']='preserve prior active manager diagnostics'
$preferences['native-achievements-manager.txt']='preserve own prior manager request'
foreach($name in @('native-combat-status.txt','native-visual-status.txt','native-achievements-status.txt','native-achievements-check-status.txt','native-achievements-manager.txt')){
    [IO.File]::WriteAllText((Join-Path $mod $name),$preferences[$name])
}
$retired=@('outdoor_weather.lua','cnpp_probe.lua','effect_diagnostic.lua','mutant_diagnostic.lua','terrain_guard.lua')
New-Item -ItemType Directory -Path (Join-Path $mod 'Scripts') -Force | Out-Null
foreach($name in $retired){[IO.File]::WriteAllText((Join-Path $mod ('Scripts\'+$name)),'retired fixture')}
[IO.File]::WriteAllText((Join-Path $mod 'Scripts\OtherUserScript.lua'),'keep-other-script')
[IO.File]::WriteAllText((Join-Path $mod 'cnpp-probe.enabled'),'1')
[IO.File]::WriteAllText((Join-Path $mod 'cnpp-probe.txt'),'keep-report')
& (Join-Path $project 'Install-Mod.ps1') -GameRoot $fixture
& (Join-Path $project 'Install-Mod.ps1') -GameRoot $fixture
if((Get-FileHash -LiteralPath $armamentTarget).Hash -ne (Get-FileHash -LiteralPath $armamentSource).Hash){throw 'Required armament PAK not deployed or verified'}
if([IO.File]::ReadAllText($unrelatedPak) -ne 'unrelated mod PAK bytes' -or [IO.File]::ReadAllText($basePak) -ne 'base game PAK bytes'){throw 'Unrelated PAK changed'}
$preservedArmamentBackup=$false
foreach($backupPak in Get-ChildItem -LiteralPath (Join-Path $project 'backups') -Filter $armamentName -File -Recurse){
    if([Convert]::ToBase64String([IO.File]::ReadAllBytes($backupPak.FullName)) -eq [Convert]::ToBase64String($previousArmament)){
        if(!(Test-Path -LiteralPath (Join-Path $backupPak.DirectoryName 'ZoneFPV'))){throw 'PAK backup must accompany its previous Lua mod backup'}
        $preservedArmamentBackup=$true;break
    }
}
if(!$preservedArmamentBackup){throw 'Previous armament PAK was not backed up'}
Write-Output 'PASS armament PAK repeated installation, exact old-package backup and unrelated/base PAK preservation'
foreach($name in $preferences.Keys){if([IO.File]::ReadAllText((Join-Path $mod $name)) -ne $preferences[$name]){throw "Preference overwritten: $name"}}
$text=[IO.File]::ReadAllText((Join-Path $runtime 'Mods\mods.txt'))
if($text -notmatch 'OtherMod : 1' -or ([regex]::Matches($text,'ZoneFPV : 1')).Count -ne 1){throw 'mods.txt corruption'}
if(!$text.Contains($unicodeModName+' : 1')){throw 'Unrelated UTF-8 mod name corrupted'}
if([IO.File]::ReadAllText((Join-Path $runtime 'UE4SS.dll')) -ne 'fixture only'){throw 'Runtime overwritten'}
$safeRuntime=[IO.File]::ReadAllText((Join-Path $runtime 'UE4SS-settings.ini'))
if($safeRuntime -notmatch 'DefaultExecuteInGameThreadMethod = EngineTick' -or $safeRuntime -notmatch 'HookEngineTick = 1' -or $safeRuntime -notmatch 'HookUObjectProcessEvent = 0' -or $safeRuntime -notmatch 'UseCache = 1' -or $safeRuntime -notmatch 'HookLocalPlayerExec = 0'){throw 'Runtime dispatch migration changed unrelated options or retained unsafe worker callbacks'}
Write-Output 'PASS safe runtime scheduler flags; runtime DLL and unrelated options retained'
foreach($name in $retired){if(Test-Path -LiteralPath (Join-Path $mod ('Scripts\'+$name))){throw "Retired script still installed: $name"}}
if(Test-Path -LiteralPath (Join-Path $mod 'cnpp-probe.enabled')){throw 'Retired probe switch still enabled'}
if([IO.File]::ReadAllText((Join-Path $mod 'cnpp-probe.txt')) -ne 'keep-report'){throw 'Captured report overwritten'}
if([IO.File]::ReadAllText((Join-Path $mod 'Scripts\OtherUserScript.lua')) -ne 'keep-other-script'){throw 'Unrelated script changed'}
Write-Output 'PASS installer repeatability, preference preservation, other mods/runtime preserved, deployed hashes verified'
Write-Output 'PASS BOM-less UTF-8 mods.txt preserves unrelated Cyrillic mod name'
Write-Output 'PASS retired experiments removed; unrelated script and captured reports preserved'
function Get-TreeHashes([string]$Folder){
    $hashes=@{}
    if(Test-Path -LiteralPath $Folder){
        foreach($file in Get-ChildItem -LiteralPath $Folder -File -Recurse){
            $relative=$file.FullName.Substring($Folder.Length+1)
            $hashes[$relative]=(Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $file.FullName).Hash
        }
    }
    return $hashes
}
function Test-InstallRollback([string]$Fault,[switch]$NewInstall,[switch]$EmptyList){
    $faultFixture=Join-Path $project ('build\installer-fault-fixture-'+[guid]::NewGuid().ToString('N'))
    $faultWin64=Join-Path $faultFixture 'Stalker2\Binaries\Win64'
    $faultRuntime=Join-Path $faultWin64 'ue4ss'
    $faultMod=Join-Path $faultRuntime 'Mods\ZoneFPV'
    $faultList=Join-Path $faultRuntime 'Mods\mods.txt'
    $faultPakDirectory=Join-Path $faultFixture 'Stalker2\Content\Paks\~mods'
    $faultArmament=Join-Path $faultPakDirectory $armamentName
    $faultOtherPak=Join-Path $faultPakDirectory 'OtherUserMod_P.pak'
    $faultBasePak=Join-Path $faultFixture 'Stalker2\Content\Paks\pakchunk-fixture.pak'
    New-Item -ItemType Directory -Path (Join-Path $faultRuntime 'Mods') -Force | Out-Null
    New-Item -ItemType Directory -Path $faultPakDirectory -Force | Out-Null
    [IO.File]::WriteAllBytes($faultOtherPak,[byte[]]@(0,17,255,29))
    [IO.File]::WriteAllBytes($faultBasePak,[byte[]]@(255,127,0,255))
    if(!$NewInstall){[IO.File]::WriteAllBytes($faultArmament,[byte[]]@(0,1,255,239,27,35))}
    $beforeArmament=if(Test-Path -LiteralPath $faultArmament){[Convert]::ToBase64String([IO.File]::ReadAllBytes($faultArmament))}else{$null}
    $beforeOtherPak=[Convert]::ToBase64String([IO.File]::ReadAllBytes($faultOtherPak))
    $beforeBasePak=[Convert]::ToBase64String([IO.File]::ReadAllBytes($faultBasePak))
    [IO.File]::WriteAllText((Join-Path $faultWin64 'Stalker2-Win64-Shipping.exe'),'fixture only')
    [IO.File]::WriteAllText((Join-Path $faultRuntime 'UE4SS.dll'),'runtime must remain unchanged')
    $faultSettings=Join-Path $faultRuntime 'UE4SS-settings.ini'
    if(!$NewInstall){[IO.File]::WriteAllText($faultSettings,$runtimeConfig,[Text.UTF8Encoding]::new($true))}
    $beforeSettings=if(Test-Path -LiteralPath $faultSettings){[Convert]::ToBase64String([IO.File]::ReadAllBytes($faultSettings))}else{$null}
    if(!$NewInstall){
        New-Item -ItemType Directory -Path (Join-Path $faultMod 'Scripts'),(Join-Path $faultMod 'fonts') -Force | Out-Null
        foreach($name in @('Scripts\main.lua','Scripts\outdoor_weather.lua','fonts\README.txt','controller.txt','calibration-123.lua','user-report.txt','cnpp-probe.enabled')){
            [IO.File]::WriteAllText((Join-Path $faultMod $name),'previous bytes: '+$name)
        }
        [IO.File]::WriteAllText($faultList,$(if($EmptyList){''}else{"$unicodeModName : 1`r`nZoneFPV : 0`r`n"}),[Text.UTF8Encoding]::new($false))
    }
    $pak=Join-Path $faultFixture 'Stalker2\Content\Paks\~mods\ZoneFPV_PlayerScent_P.pak'
    if($Fault -eq 'Retirement'){
        New-Item -ItemType Directory -Path (Split-Path $pak -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($pak,'previous scent package bytes')
    }
    $beforeHashes=Get-TreeHashes $faultMod
    $beforeList=if(Test-Path -LiteralPath $faultList){[Convert]::ToBase64String([IO.File]::ReadAllBytes($faultList))}else{$null}
    $global:zoneFpvTestFaultEnabled=$true
    $global:zoneFpvTestFaultMode=$Fault
    $global:zoneFpvTestFailedCopy=Join-Path $project 'mod\Scripts'
    $global:zoneFpvTestFailedHash=Join-Path $faultMod 'fonts\README.txt'
    $global:zoneFpvTestFailedRetirement=Join-Path $faultMod 'Scripts\outdoor_weather.lua'
    $global:zoneFpvTestFailedArmamentSource=$armamentSource
    $global:zoneFpvTestFailedArmamentTarget=$faultArmament
    function global:Copy-Item {
        [CmdletBinding()]param([string[]]$LiteralPath,[string]$Destination,[switch]$Recurse,[switch]$Force)
        if($global:zoneFpvTestFaultEnabled -and $global:zoneFpvTestFaultMode -eq 'Copy' -and $LiteralPath[0] -eq $global:zoneFpvTestFailedCopy){$global:zoneFpvTestFaultEnabled=$false;throw 'Injected installer fault.'}
        if($global:zoneFpvTestFaultEnabled -and $global:zoneFpvTestFaultMode -eq 'PakCopy' -and $LiteralPath[0] -eq $global:zoneFpvTestFailedArmamentSource){
            [IO.File]::WriteAllBytes($global:zoneFpvTestFailedArmamentTarget,[byte[]]@(66,82,79,75,69,78))
            $global:zoneFpvTestFaultEnabled=$false;throw 'Injected installer fault.'
        }
        Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
    }
    function global:Get-FileHash {
        [CmdletBinding()]param([string]$LiteralPath)
        if($global:zoneFpvTestFaultEnabled -and $global:zoneFpvTestFaultMode -eq 'Hash' -and $LiteralPath -eq $global:zoneFpvTestFailedHash){$global:zoneFpvTestFaultEnabled=$false;throw 'Injected installer fault.'}
        if($global:zoneFpvTestFaultEnabled -and $global:zoneFpvTestFaultMode -eq 'PakHash' -and $LiteralPath -eq $global:zoneFpvTestFailedArmamentTarget){$global:zoneFpvTestFaultEnabled=$false;return [pscustomobject]@{Hash='CORRUPT INSTALLED PAK'}}
        Microsoft.PowerShell.Utility\Get-FileHash @PSBoundParameters
    }
    function global:Remove-Item {
        [CmdletBinding()]param([string]$LiteralPath)
        if($global:zoneFpvTestFaultEnabled -and $global:zoneFpvTestFaultMode -eq 'Retirement' -and $LiteralPath -eq $global:zoneFpvTestFailedRetirement){$global:zoneFpvTestFaultEnabled=$false;throw 'Injected installer fault.'}
        Microsoft.PowerShell.Management\Remove-Item @PSBoundParameters
    }
    $failure=$null
    try {& (Join-Path $project 'Install-Mod.ps1') -GameRoot $faultFixture} catch {$failure=$_.Exception.Message}
    finally {foreach($command in @('Copy-Item','Get-FileHash','Remove-Item')){Microsoft.PowerShell.Management\Remove-Item -LiteralPath ('Function:\'+$command)}}
    $expectedFailure=if($Fault -eq 'PakHash'){'Installed armament PAK mismatch.'}else{'Injected installer fault.'}
    if($failure -ne $expectedFailure -or $global:zoneFpvTestFaultEnabled){throw 'Expected fault was not preserved.'}
    $afterHashes=Get-TreeHashes $faultMod
    if($afterHashes.Count -ne $beforeHashes.Count){throw 'Rollback changed the mod file set.'}
    foreach($name in $beforeHashes.Keys){if($afterHashes[$name] -ne $beforeHashes[$name]){throw "Rollback changed mod bytes: $name"}}
    if($NewInstall){if(Test-Path -LiteralPath $faultMod){throw 'Failed new install left a partial mod.'}}
    if($null -eq $beforeList){if(Test-Path -LiteralPath $faultList){throw 'Rollback left a new mods.txt.'}}
    elseif([Convert]::ToBase64String([IO.File]::ReadAllBytes($faultList)) -ne $beforeList){throw 'Rollback changed mods.txt bytes.'}
    if([IO.File]::ReadAllText((Join-Path $faultRuntime 'UE4SS.dll')) -ne 'runtime must remain unchanged'){throw 'Rollback changed runtime.'}
    if($null -eq $beforeSettings){if(Test-Path -LiteralPath $faultSettings){throw 'Rollback left newly created runtime settings'}}
    elseif([Convert]::ToBase64String([IO.File]::ReadAllBytes($faultSettings)) -ne $beforeSettings){throw 'Rollback changed original runtime settings bytes'}
    if($Fault -eq 'Retirement' -and [IO.File]::ReadAllText($pak) -ne 'previous scent package bytes'){throw 'Rollback did not restore the scent package.'}
    if($null -eq $beforeArmament){if(Test-Path -LiteralPath $faultArmament){throw 'Rollback left newly created armament PAK'}}
    elseif([Convert]::ToBase64String([IO.File]::ReadAllBytes($faultArmament)) -ne $beforeArmament){throw 'Rollback changed original armament PAK bytes'}
    if([Convert]::ToBase64String([IO.File]::ReadAllBytes($faultOtherPak)) -ne $beforeOtherPak -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($faultBasePak)) -ne $beforeBasePak){throw 'Rollback changed unrelated PAK bytes'}
}
Test-InstallRollback -Fault Copy
Test-InstallRollback -Fault Hash -NewInstall
Test-InstallRollback -Fault Hash -EmptyList
Test-InstallRollback -Fault Retirement
Test-InstallRollback -Fault PakCopy
Test-InstallRollback -Fault PakCopy -NewInstall
Test-InstallRollback -Fault PakHash
Test-InstallRollback -Fault PakHash -NewInstall
Write-Output 'PASS copy/verification/retirement rollback: exact previous files and mods.txt, absent new install, empty list, armament and retired scent PAKs'
# A release missing its companion PAK must fail before modifying game files.
$missingRelease=Join-Path $project ('build\installer-missing-pak-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $missingRelease -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $project 'Install-Mod.ps1') -Destination $missingRelease
$beforePreflight=Get-TreeHashes $fixture
$preflightFailure=$null
try {& (Join-Path $missingRelease 'Install-Mod.ps1') -GameRoot $fixture}catch{$preflightFailure=$_.Exception.Message}
if($preflightFailure -notlike 'Required ZoneFPV armament PAK is missing.*'){throw 'Missing-package release did not fail preflight'}
$afterPreflight=Get-TreeHashes $fixture
if($beforePreflight.Count -ne $afterPreflight.Count){throw 'Missing-PAK preflight changed game file set'}
foreach($name in $beforePreflight.Keys){if($beforePreflight[$name] -ne $afterPreflight[$name]){throw "Missing-PAK preflight changed bytes: $name"}}
Write-Output 'PASS missing required PAK rejected before any game/runtime/mod mutation'
# The fixture remains under build for inspection. No real game files touched.
