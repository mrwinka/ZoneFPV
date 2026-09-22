param([string]$LuaPath='lua.exe')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    foreach($name in @('flight','flight_modes','lifecycle','environment','audio','analog','bridge','world_options','telemetry_visual')){
        & $LuaPath "tests\${name}_test.lua"
        if($LASTEXITCODE -ne 0){throw "$name tests failed."}
    }
} finally {Pop-Location}