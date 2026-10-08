param([string]$LuaPath='lua.exe', [string]$FixturePath=(Join-Path $PSScriptRoot 'tests/fixtures'))
$ErrorActionPreference='Stop'
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
foreach ($name in @('armament-environment.txt','armament-combined-environment.txt','pda-settings-state.txt')) {
    if (!(Test-Path -LiteralPath (Join-Path $FixturePath $name))) { throw "Missing cross-language fixture: $name" }
}
Push-Location $PSScriptRoot
try {
    $tests=Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tests') -Filter '*_test.lua' -File | Sort-Object Name
    if(!$tests){throw 'No Lua tests found.'}
    foreach($test in $tests){
        $arguments=@($test.FullName)
        switch ($test.BaseName) {
            'external_armament_packet_test' { $arguments+=Join-Path $FixturePath 'armament-environment.txt'; $arguments+=Join-Path $FixturePath 'armament-combined-environment.txt' }
            'pda_settings_test' { $arguments+=Join-Path $FixturePath 'pda-settings-state.txt' }
            'telemetry_visual_test' { $arguments+=Join-Path $build 'telemetry-fixture.txt' }
        }
        & $LuaPath @arguments
        if($LASTEXITCODE -ne 0){throw "$($test.Name) tests failed."}
    }
    Write-Output "PASS all $($tests.Count) Lua test suites"
} finally {Pop-Location}