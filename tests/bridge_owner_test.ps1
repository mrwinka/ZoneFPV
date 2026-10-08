$ErrorActionPreference='Stop'
$taskSource=[IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'mod\Start-Bridge.ps1'))
# Execute the production launch policy with fake processes. Returns replace
# process exits so the fixture can inspect which helpers it would reuse/retire.
$taskSource=$taskSource.Replace('exit 0','return').Replace('exit 1',"throw 'fixture launcher failed'")
$script:taskRoot=$PSScriptRoot
$taskSource=$taskSource.Replace('$PSScriptRoot','$script:taskRoot')
$script:taskExe=Join-Path $script:taskRoot 'ZoneFPVInput.exe'
function Test-Path {param($LiteralPath,$Path) return $true}
function Get-Process {
    param($Name,$ErrorAction)
    if($Name -eq 'Stalker2-Win64-Shipping' -and $script:taskGame){return [pscustomobject]@{Id=500}}
    if($Name -eq 'ZoneFPVInput' -and $script:taskHelper){
        $taskProcess=[pscustomobject]@{Id=600;Path=$script:taskExe}
        $taskProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {param($milliseconds) $script:taskWaits++;return $true}
        return $taskProcess
    }
}
function Get-CimInstance {param($ClassName,$Filter,$ErrorAction) return [pscustomobject]@{CommandLine=$script:taskCommand}}
function Stop-Process {param($Id,$ErrorAction) if($Id -ne 600){throw 'Wrong process retired'};$script:taskStops++}
function Start-Process {
    param($FilePath,$ArgumentList,$WorkingDirectory,$WindowStyle,[switch]$PassThru,$RedirectStandardOutput,$RedirectStandardError)
    if($FilePath -ne $script:taskExe -or $WindowStyle -ne 'Hidden'){throw 'Wrong/visible helper launch'}
    $script:taskStarts++;$script:taskArguments=$ArgumentList
    return [pscustomobject]@{HasExited=$false;ExitCode=0}
}
function Start-Sleep {param($Milliseconds)}
function Set-Content {param($LiteralPath,$Encoding) throw 'Unexpected launch-policy failure'}
foreach($taskCase in @(
    @{game=$true;helper=$false;command='';stops=0;starts=1},
    @{game=$true;helper=$true;command='helper --device -1 --parent-pid 500';stops=0;starts=0},
    @{game=$true;helper=$true;command='helper --parent-pid "500" --device -1';stops=0;starts=0},
    @{game=$true;helper=$true;command='helper --parent-pid 5000';stops=1;starts=1},
    @{game=$true;helper=$true;command='helper --parent-pid 499';stops=1;starts=1},
    @{game=$true;helper=$true;command='helper --settings --device -1';stops=1;starts=1},
    @{game=$false;helper=$true;command='helper --settings';stops=0;starts=0}
)){
    $script:taskGame=$taskCase.game;$script:taskHelper=$taskCase.helper;$script:taskCommand=$taskCase.command
    $script:taskStops=0;$script:taskWaits=0;$script:taskStarts=0;$script:taskArguments=@()
    & ([scriptblock]::Create($taskSource))
    if($script:taskStops -ne $taskCase.stops -or $script:taskStarts -ne $taskCase.starts -or $script:taskWaits -ne $taskCase.stops){throw ('Ownership case failed: '+$taskCase.command)}
    if($taskCase.starts -and $taskCase.game -and ($script:taskArguments -join ' ') -ne '--device -1 --parent-pid 500'){throw 'New helper must belong to current game and start with menu closed'}
}
Write-Output 'PASS production bridge policy: current game reuse, previous/standalone helper retirement, quoted PID and hidden fresh startup'
