param([string]$LuaPath='lua.exe')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    foreach($name in @('world_distance','scheduler','ai_guard','focus_guard','collision','flight','flight_modes','lifecycle','environment','environment_guard','player_visibility','player_guard','player_ui','regional_fog','audio','analog','bridge','world_options','telemetry_visual')){
        & $LuaPath "tests\${name}_test.lua"
        if($LASTEXITCODE -ne 0){throw "$name tests failed."}
    }
} finally {Pop-Location}
