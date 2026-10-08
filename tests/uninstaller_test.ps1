$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
function Assert-Bytes([string]$Path,[byte[]]$Expected,[string]$Label){
    if(!(Test-Path -LiteralPath $Path) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) -ne [Convert]::ToBase64String($Expected)){throw "Changed or missing bytes: $Label"}
}
function Test-Uninstall([switch]$PakOnly,[switch]$UnrelatedOnly){
    $fixture=Join-Path $project ('build\uninstaller-fixture-'+[guid]::NewGuid().ToString('N'))
    $win64=Join-Path $fixture 'Stalker2\Binaries\Win64'
    $runtime=Join-Path $win64 'ue4ss'
    $mods=Join-Path $runtime 'Mods'
    $mod=Join-Path $mods 'ZoneFPV'
    $pakDirectory=Join-Path $fixture 'Stalker2\Content\Paks\~mods'
    New-Item -ItemType Directory -Path $runtime,$pakDirectory -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $win64 'Stalker2-Win64-Shipping.exe'),'fixture only - not executable')
    $dllBytes=[byte[]]@(78,65,84,73,86,69,0,255)
    $settingsBytes=[Text.Encoding]::UTF8.GetBytes("[General]`r`nUserOption = 27`r`n")
    [IO.File]::WriteAllBytes((Join-Path $runtime 'UE4SS.dll'),$dllBytes)
    [IO.File]::WriteAllBytes((Join-Path $runtime 'UE4SS-settings.ini'),$settingsBytes)
    $ownPaks=@{'ZoneFPV_Armament_P.pak'=[byte[]]@(0,27,255,65,82,77);'ZoneFPV_PlayerScent_P.pak'=[byte[]]@(255,0,83,67,69,78,84)}
    if($PakOnly){$ownPaks.Remove('ZoneFPV_PlayerScent_P.pak')}
    $otherPaks=@{'OtherUserMod_P.pak'=[byte[]]@(7,4,0,255);'ZoneFPV_OtherAddon_P.pak'=[byte[]]@(71,0,255)}
    if(!$UnrelatedOnly){foreach($name in $ownPaks.Keys){[IO.File]::WriteAllBytes((Join-Path $pakDirectory $name),$ownPaks[$name])}}
    foreach($name in $otherPaks.Keys){[IO.File]::WriteAllBytes((Join-Path $pakDirectory $name),$otherPaks[$name])}
    $basePak=Join-Path $fixture 'Stalker2\Content\Paks\pakchunk-fixture.pak'
    $baseBytes=[byte[]]@(255,17,0,128,6)
    [IO.File]::WriteAllBytes($basePak,$baseBytes)
    $preferences=[Text.Encoding]::UTF8.GetBytes('1 2 2.25 1 0')
    $oldScript=[Text.Encoding]::UTF8.GetBytes('fixture Lua bytes')
    $otherScript=[byte[]]@(33,35,0,255)
    if(!$PakOnly){
        New-Item -ItemType Directory -Path (Join-Path $mods 'OtherUserMod') -Force | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $mods 'OtherUserMod\script.lua'),$otherScript)
        $unicodeName=-join (@(0x041c,0x043e,0x0434) | ForEach-Object {[char]$_})
        [IO.File]::WriteAllText((Join-Path $mods 'mods.txt'),"$unicodeName : 1`r`nOtherUserMod : 1`r`nZoneFPV : 1`r`n",[Text.UTF8Encoding]::new($false))
        if(!$UnrelatedOnly){
            New-Item -ItemType Directory -Path (Join-Path $mod 'Scripts') -Force | Out-Null
            [IO.File]::WriteAllBytes((Join-Path $mod 'weapon-settings.txt'),$preferences)
            [IO.File]::WriteAllBytes((Join-Path $mod 'Scripts\main.lua'),$oldScript)
        }
    }
    if($PakOnly -and (Test-Path -LiteralPath $mods)){throw 'PAK-only fixture must have no Mods folder'}
    & (Join-Path $project 'Uninstall.ps1') -GameRoot $fixture
    if(Test-Path -LiteralPath $mod){throw 'Lua mod remains active after uninstall'}
    $backups=@(Get-ChildItem -LiteralPath $runtime -Directory -Filter 'ZoneFPV-uninstalled-*')
    if(!$UnrelatedOnly){
        if($backups.Count -ne 1){throw 'Expected one uniquely named preservation directory'}
        $backup=$backups[0].FullName
        foreach($name in $ownPaks.Keys){
            if(Test-Path -LiteralPath (Join-Path $pakDirectory $name)){throw "Own PAK remains active: $name"}
            Assert-Bytes (Join-Path $backup $name) $ownPaks[$name] $name
        }
        if(!$PakOnly){
            Assert-Bytes (Join-Path $backup 'weapon-settings.txt') $preferences 'saved preferences'
            Assert-Bytes (Join-Path $backup 'Scripts\main.lua') $oldScript 'saved Lua files'
        }
    }elseif($backups.Count){throw 'Unrelated-only uninstall must not create an empty backup'}
    foreach($name in $otherPaks.Keys){Assert-Bytes (Join-Path $pakDirectory $name) $otherPaks[$name] $name}
    Assert-Bytes $basePak $baseBytes 'base game PAK'
    Assert-Bytes (Join-Path $runtime 'UE4SS.dll') $dllBytes 'runtime DLL'
    Assert-Bytes (Join-Path $runtime 'UE4SS-settings.ini') $settingsBytes 'runtime settings'
    if(!$PakOnly){
        Assert-Bytes (Join-Path $mods 'OtherUserMod\script.lua') $otherScript 'other Lua mod'
        $list=[IO.File]::ReadAllText((Join-Path $mods 'mods.txt'))
        if(!$list.Contains($unicodeName+' : 1') -or !$list.Contains('OtherUserMod : 1') -or !$list.Contains('ZoneFPV : 0')){throw 'Uninstall changed unrelated mods or failed to disable ZoneFPV'}
    }
    & (Join-Path $project 'Uninstall.ps1') -GameRoot $fixture
    $afterRepeat=@(Get-ChildItem -LiteralPath $runtime -Directory -Filter 'ZoneFPV-uninstalled-*')
    if($afterRepeat.Count -ne $backups.Count){throw 'Repeated uninstall created/moved extra files'}
    if(!$UnrelatedOnly){foreach($name in $ownPaks.Keys){Assert-Bytes (Join-Path $backup $name) $ownPaks[$name] ('repeated '+$name)}}
}
Test-Uninstall
Test-Uninstall -PakOnly
Test-Uninstall -UnrelatedOnly
Write-Output 'PASS uninstall preserves own armament/scent PAK bytes and Lua/preferences, supports PAK-only without Mods, repeated removal and unrelated/base PAKs/runtime/mods'
# All fixtures are retained under build; no real game files are modified.
