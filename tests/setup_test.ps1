$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$setup=Join-Path $project 'Setup.ps1'
$fixture=Join-Path $project ('build\setup-fixture-'+[guid]::NewGuid().ToString('N'))
$steam=Join-Path $fixture 'Steam'
$library=Join-Path $fixture 'Library'
$game=Join-Path $library 'steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl'
$win64=Join-Path $game 'Stalker2\Binaries\Win64'
New-Item -ItemType Directory -Path (Join-Path $steam 'steamapps'),(Join-Path $win64 'ue4ss') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $win64 'Stalker2-Win64-Shipping.exe'),'fixture only')
[IO.File]::WriteAllText((Join-Path $win64 'ue4ss\UE4SS.dll'),'fixture only')
$missingDrive=@('M')+@(65..90 | ForEach-Object {[string][char]$_}) | Select-Object -Unique | Where-Object {!(Get-PSDrive -Name $_ -ErrorAction SilentlyContinue)} | Select-Object -First 1
if(!$missingDrive){throw 'Setup fixture requires one unused drive letter.'}
$missing=$missingDrive+':\Removed Steam Library'
$vdf=Join-Path $steam 'steamapps\libraryfolders.vdf'
function Write-Libraries([string[]]$Libraries){
    $rows=@('"libraryfolders"','{')
    foreach($entry in $Libraries){$rows+=('"path" "'+$entry.Replace('\','\\')+'"')}
    $rows+='}'
    [IO.File]::WriteAllLines($vdf,$rows)
}

# Load only the discovery functions; do not run the installer or open a picker.
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($setup,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'Setup.ps1 did not parse.'}
foreach($name in @('Test-GameRoot','Find-GameRoots')){
    $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$false)
    if(!$definition){throw "Setup function missing: $name"}
    . ([scriptblock]::Create($definition.Extent.Text))
}
$script:fixtureSteamPath=$steam
function Get-ItemProperty {
    [CmdletBinding()]param([string]$Path)
    if($Path -ne 'HKCU:\Software\Valve\Steam'){throw 'Unexpected registry query.'}
    return [pscustomobject]@{SteamPath=$script:fixtureSteamPath}
}
Write-Libraries @($missing,$library,$library)
$found=@(Find-GameRoots)
if($found.Count -ne 1 -or $found[0] -ne $game){throw 'A missing Steam drive blocked discovery of a later valid library.'}
if(Test-GameRoot $missing){throw 'Missing-drive root accepted.'}
if(Test-GameRoot ''){throw 'Empty root accepted.'}
if(Test-GameRoot (Join-Path $fixture 'NotAGame')){throw 'Non-game folder accepted.'}
Write-Output 'PASS unavailable Steam drive skipped; later valid library discovered once'
Write-Libraries @($missing)
if(@(Find-GameRoots).Count){throw 'Missing-only library list produced a game folder.'}
$script:fixtureSteamPath=$missing
if(@(Find-GameRoots).Count){throw 'Missing Steam root produced a game folder.'}
Write-Output 'PASS unavailable Steam installation/list returns no roots without blocking manual selection'

# Exercise the actual entry point in Windows PowerShell: explicit roots must
# bypass discovery completely, even with a broken registered Steam library.
$explicitWrapper=Join-Path $fixture 'explicit.ps1'
$quotedSetup=$setup.Replace("'","''")
$quotedGame=$game.Replace("'","''")
[IO.File]::WriteAllText($explicitWrapper,@"
function Get-ItemProperty { throw 'Explicit -GameRoot unexpectedly searched Steam.' }
& '$quotedSetup' -GameRoot '$quotedGame' -CheckOnly
"@)
$result=& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $explicitWrapper 2>&1
if($LASTEXITCODE -ne 0 -or ($result -join "`n") -notlike 'Ready:*UE4SS present*'){throw ('Explicit -GameRoot preflight failed: '+($result -join "`n"))}
Write-Output 'PASS explicit -GameRoot bypasses discovery in Windows PowerShell; preflight only, no installation'

$quotedSteam=$steam.Replace("'","''")
$automaticWrapper=Join-Path $fixture 'automatic.ps1'
Write-Libraries @($missing,$library)
[IO.File]::WriteAllText($automaticWrapper,@"
function Get-ItemProperty { [pscustomobject]@{SteamPath='$quotedSteam'} }
& '$quotedSetup' -CheckOnly
"@)
$result=& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $automaticWrapper 2>&1
if($LASTEXITCODE -ne 0 -or ($result -join "`n") -notlike 'Ready:*UE4SS present*'){throw ('Automatic preflight with missing-drive library failed: '+($result -join "`n"))}
Write-Output 'PASS actual setup preflight discovers valid library after a removed drive'
