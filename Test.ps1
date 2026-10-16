param([string]$LuaPath='lua.exe')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'build') -Force | Out-Null
    $tests=@(Get-ChildItem -LiteralPath 'tests' -Filter '*_test.lua' -File | Sort-Object Name)
    foreach($test in $tests){
        $arguments=@($test.FullName)
        if($test.BaseName -eq 'external_armament_packet_test'){$arguments+=@('tests/fixtures/armament-environment.txt','tests/fixtures/armament-combined-environment.txt')}
        if($test.BaseName -eq 'pda_settings_test'){$arguments+='tests/fixtures/pda-settings-state.txt'}
        if($test.BaseName -eq 'telemetry_visual_test'){$arguments+='build/telemetry-fixture.txt'}
        & $LuaPath @arguments
        if($LASTEXITCODE -ne 0){throw ($test.Name+' tests failed')}
    }
    Write-Output ('PASS all '+$tests.Count+' Lua test suites')
} finally {Pop-Location}
