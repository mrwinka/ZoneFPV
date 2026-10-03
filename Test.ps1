param([string]$LuaPath='lua.exe')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    $tests=Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tests') -Filter '*_test.lua' -File | Sort-Object Name
    if(!$tests){throw 'No Lua tests found.'}
    foreach($test in $tests){
        & $LuaPath $test.FullName
        if($LASTEXITCODE -ne 0){throw "$($test.Name) tests failed."}
    }
    Write-Output "PASS all $($tests.Count) Lua test suites"
} finally {Pop-Location}
