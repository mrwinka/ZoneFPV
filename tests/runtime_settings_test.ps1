$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Runtime-Settings.ps1')
$before="[General]`r`nDefaultExecuteInGameThreadMethod = ProcessEvent`r`nUseCache = 1`r`n[Hooks]`r`nHookEngineTick = 0`r`nHookUObjectProcessEvent = 1`r`nHookLocalPlayerExec = 0`r`n"
$after=Get-ZoneFpvRuntimeSettings $before
foreach($pair in @(@('DefaultExecuteInGameThreadMethod','EngineTick'),@('HookEngineTick','1'),@('HookUObjectProcessEvent','0'))){
    if($after -notmatch ($pair[0]+' = '+$pair[1])){throw 'Safe scheduler option missing'}
}
if($after -notmatch 'UseCache = 1' -or $after -notmatch 'HookLocalPlayerExec = 0'){throw 'Unrelated runtime option changed'}
if((Get-ZoneFpvRuntimeSettings $after) -ne $after){throw 'Runtime migration is not idempotent'}
foreach($text in @('',"[General]`nUseCache = 0`n[Hooks]`nHookLocalPlayerExec = 0`n")){
    $new=Get-ZoneFpvRuntimeSettings $text
    foreach($key in @('DefaultExecuteInGameThreadMethod','HookEngineTick','HookUObjectProcessEvent')){
        if(([regex]::Matches($new,'(?m)^'+$key+' = ')).Count -ne 1){throw 'Missing/duplicated added runtime option'}
    }
}
$caught=$false
try {Get-ZoneFpvRuntimeSettings ($before+'HookEngineTick = 1')|Out-Null}catch{$caught=$true}
if(!$caught){throw 'Duplicate option ambiguity must fail before writing settings'}
Write-Output 'PASS EngineTick-only runtime migration, ProcessEvent pump disabled, unrelated options preserved, repeatability and malformed config rejection'
