$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $project ('build\installer-fixture-'+[guid]::NewGuid().ToString('N'))
$win64=Join-Path $fixture 'Stalker2\Binaries\Win64'
$runtime=Join-Path $win64 'ue4ss'
$mod=Join-Path $runtime 'Mods\ZoneFPV'
New-Item -ItemType Directory -Path $mod -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $win64 'Stalker2-Win64-Shipping.exe'),'fixture only - not executable')
[IO.File]::WriteAllText((Join-Path $runtime 'UE4SS.dll'),'fixture only')
$unicodeModName=-join (@(0x041c,0x043e,0x0434) | ForEach-Object {[char]$_})
[IO.File]::WriteAllText((Join-Path $runtime 'Mods\mods.txt'),"OtherMod : 1`r`n$unicodeModName : 1`r`nZoneFPV : 0`r`n",[Text.UTF8Encoding]::new($false))
$preferences=@{'calibration-123.lua'='custom';'calibration.lua'='legacy';'bindings.txt'='117 119 120';'osd-layout.txt'='keep-layout';'controller.txt'='123'}
foreach($name in $preferences.Keys){[IO.File]::WriteAllText((Join-Path $mod $name),$preferences[$name])}
$retired=@('outdoor_weather.lua','cnpp_probe.lua','effect_diagnostic.lua','mutant_diagnostic.lua','terrain_guard.lua')
New-Item -ItemType Directory -Path (Join-Path $mod 'Scripts') -Force | Out-Null
foreach($name in $retired){[IO.File]::WriteAllText((Join-Path $mod ('Scripts\'+$name)),'retired fixture')}
[IO.File]::WriteAllText((Join-Path $mod 'Scripts\OtherUserScript.lua'),'keep-other-script')
[IO.File]::WriteAllText((Join-Path $mod 'cnpp-probe.enabled'),'1')
[IO.File]::WriteAllText((Join-Path $mod 'cnpp-probe.txt'),'keep-report')
& (Join-Path $project 'Install-Mod.ps1') -GameRoot $fixture
& (Join-Path $project 'Install-Mod.ps1') -GameRoot $fixture
foreach($name in $preferences.Keys){if([IO.File]::ReadAllText((Join-Path $mod $name)) -ne $preferences[$name]){throw "Preference overwritten: $name"}}
$text=[IO.File]::ReadAllText((Join-Path $runtime 'Mods\mods.txt'))
if($text -notmatch 'OtherMod : 1' -or ([regex]::Matches($text,'ZoneFPV : 1')).Count -ne 1){throw 'mods.txt corruption'}
if(!$text.Contains($unicodeModName+' : 1')){throw 'Unrelated UTF-8 mod name corrupted'}
if([IO.File]::ReadAllText((Join-Path $runtime 'UE4SS.dll')) -ne 'fixture only'){throw 'Runtime overwritten'}
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
    New-Item -ItemType Directory -Path (Join-Path $faultRuntime 'Mods') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $faultWin64 'Stalker2-Win64-Shipping.exe'),'fixture only')
    [IO.File]::WriteAllText((Join-Path $faultRuntime 'UE4SS.dll'),'runtime must remain unchanged')
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
    function global:Copy-Item {
        [CmdletBinding()]param([string[]]$LiteralPath,[string]$Destination,[switch]$Recurse,[switch]$Force)
        if($global:zoneFpvTestFaultEnabled -and $global:zoneFpvTestFaultMode -eq 'Copy' -and $LiteralPath[0] -eq $global:zoneFpvTestFailedCopy){$global:zoneFpvTestFaultEnabled=$false;throw 'Injected installer fault.'}
        Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
    }
    function global:Get-FileHash {
        [CmdletBinding()]param([string]$LiteralPath)
        if($global:zoneFpvTestFaultEnabled -and $global:zoneFpvTestFaultMode -eq 'Hash' -and $LiteralPath -eq $global:zoneFpvTestFailedHash){$global:zoneFpvTestFaultEnabled=$false;throw 'Injected installer fault.'}
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
    if($failure -ne 'Injected installer fault.' -or $global:zoneFpvTestFaultEnabled){throw 'Expected fault was not preserved.'}
    $afterHashes=Get-TreeHashes $faultMod
    if($afterHashes.Count -ne $beforeHashes.Count){throw 'Rollback changed the mod file set.'}
    foreach($name in $beforeHashes.Keys){if($afterHashes[$name] -ne $beforeHashes[$name]){throw "Rollback changed mod bytes: $name"}}
    if($NewInstall){if(Test-Path -LiteralPath $faultMod){throw 'Failed new install left a partial mod.'}}
    if($null -eq $beforeList){if(Test-Path -LiteralPath $faultList){throw 'Rollback left a new mods.txt.'}}
    elseif([Convert]::ToBase64String([IO.File]::ReadAllBytes($faultList)) -ne $beforeList){throw 'Rollback changed mods.txt bytes.'}
    if([IO.File]::ReadAllText((Join-Path $faultRuntime 'UE4SS.dll')) -ne 'runtime must remain unchanged'){throw 'Rollback changed runtime.'}
    if($Fault -eq 'Retirement' -and [IO.File]::ReadAllText($pak) -ne 'previous scent package bytes'){throw 'Rollback did not restore the scent package.'}
}
Test-InstallRollback -Fault Copy
Test-InstallRollback -Fault Hash -NewInstall
Test-InstallRollback -Fault Hash -EmptyList
Test-InstallRollback -Fault Retirement
Write-Output 'PASS copy/verification/retirement rollback: exact previous files and mods.txt, absent new install, empty list and retired scent package'
# The fixture remains under build for inspection. No real game files touched.
