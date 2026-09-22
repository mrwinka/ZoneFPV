param([string]$GameRoot, [switch]$CheckOnly)
$ErrorActionPreference='Stop'
function Test-GameRoot([string]$Path){
    return $Path -and (Test-Path -LiteralPath (Join-Path $Path 'Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe'))
}
function Find-GameRoots {
    $libraries=[System.Collections.Generic.List[string]]::new()
    $steam=(Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if($steam){
        $libraries.Add($steam)
        $vdf=Join-Path $steam 'steamapps\libraryfolders.vdf'
        if(Test-Path -LiteralPath $vdf){
            foreach($match in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s+"([^"]+)"')){$libraries.Add($match.Groups[1].Value.Replace('\\','\'))}
        }
    }
    foreach($library in $libraries | Select-Object -Unique){
        $path=Join-Path $library 'steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl'
        if(Test-GameRoot $path){$path}
    }
}
try {
    if(!$GameRoot){$found=@(Find-GameRoots);if($found.Count -eq 1){$GameRoot=$found[0]}}
    if(!(Test-GameRoot $GameRoot)){
        if($CheckOnly){throw 'Game folder not found. Pass -GameRoot with the installation folder.'}
        Add-Type -AssemblyName System.Windows.Forms
        $picker=New-Object System.Windows.Forms.FolderBrowserDialog
        $picker.Description='Choose the STALKER 2 installation folder (contains Stalker2).'
        if($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){exit 2}
        $GameRoot=$picker.SelectedPath
        if(!(Test-GameRoot $GameRoot)){throw 'This folder does not contain the STALKER 2 executable.'}
    }
    $GameRoot=(Resolve-Path -LiteralPath $GameRoot).Path
    $runtime=Join-Path $GameRoot 'Stalker2\Binaries\Win64\ue4ss\UE4SS.dll'
    if(!(Test-Path -LiteralPath $runtime)){
        throw "Compatible UE4SS is required first. Follow DEPENDENCIES.md, then run Setup.cmd again. No game files were changed."
    }
    if($CheckOnly){Write-Output "Ready: $GameRoot (UE4SS present; game-version compatibility still requires validation).";exit 0}
    & (Join-Path $PSScriptRoot 'Install-Mod.ps1') -GameRoot $GameRoot
    Write-Host 'Installed. Launch the game, load a save. F6: settings. F8: FPV. F9: reset.'
    Write-Host 'Existing profiles and OSD preferences were preserved.'
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host 'If access was denied, run Setup.cmd as administrator. Do not disable Windows security.'
    exit 1
}
