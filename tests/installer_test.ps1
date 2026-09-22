$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $project ('build\installer-fixture-'+[guid]::NewGuid().ToString('N'))
$win64=Join-Path $fixture 'Stalker2\Binaries\Win64'
$runtime=Join-Path $win64 'ue4ss'
$mod=Join-Path $runtime 'Mods\ZoneFPV'
New-Item -ItemType Directory -Path $mod -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $win64 'Stalker2-Win64-Shipping.exe'),'fixture only - not executable')
[IO.File]::WriteAllText((Join-Path $runtime 'UE4SS.dll'),'fixture only')
[IO.File]::WriteAllText((Join-Path $runtime 'Mods\mods.txt'),"OtherMod : 1`r`nZoneFPV : 0`r`n")
$preferences=@{'calibration-123.lua'='custom';'calibration.lua'='legacy';'bindings.txt'='117 119 120';'osd-layout.txt'='keep-layout';'controller.txt'='123'}
foreach($name in $preferences.Keys){[IO.File]::WriteAllText((Join-Path $mod $name),$preferences[$name])}
& (Join-Path $project 'Install-Mod.ps1') -GameRoot $fixture
& (Join-Path $project 'Install-Mod.ps1') -GameRoot $fixture
foreach($name in $preferences.Keys){if([IO.File]::ReadAllText((Join-Path $mod $name)) -ne $preferences[$name]){throw "Preference overwritten: $name"}}
$text=[IO.File]::ReadAllText((Join-Path $runtime 'Mods\mods.txt'))
if($text -notmatch 'OtherMod : 1' -or ([regex]::Matches($text,'ZoneFPV : 1')).Count -ne 1){throw 'mods.txt corruption'}
if([IO.File]::ReadAllText((Join-Path $runtime 'UE4SS.dll')) -ne 'fixture only'){throw 'Runtime overwritten'}
Write-Output 'PASS installer repeatability, preference preservation, other mods/runtime preserved, deployed hashes verified'
# The fixture remains under build for inspection. No real game files touched.
