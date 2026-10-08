$ErrorActionPreference='Stop'
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(!$vs){throw 'MSVC x64 compiler not installed.'}
$vcvars=Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$build=Join-Path $PSScriptRoot 'build/native-game'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$minhook=Join-Path $PSScriptRoot 'src/third_party/minhook/minhook'
$commands=@"
@echo off
call "$vcvars" >nul
if not "%errorlevel%"=="0" exit /b 1
cd /d "$build"
cl /nologo /W3 /O2 /MT /c /TC "$minhook\buffer.c" "$minhook\hook.c" "$minhook\trampoline.c" "$minhook\hde\hde64.c"
if not "%errorlevel%"=="0" exit /b 1
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT /LD "$PSScriptRoot\src\native_game_bridge.cpp" buffer.obj hook.obj trampoline.obj hde64.obj /Fe:ZoneFPVNative.dll
if not "%errorlevel%"=="0" exit /b 1
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT "$PSScriptRoot\src\native_game_bridge_test.cpp" buffer.obj hook.obj trampoline.obj hde64.obj /Fe:NativeCombatTest.exe
if not "%errorlevel%"=="0" exit /b 1
NativeCombatTest.exe
if not "%errorlevel%"=="0" exit /b 1
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT "$PSScriptRoot\src\native_aggression_test.cpp" buffer.obj hook.obj trampoline.obj hde64.obj /Fe:NativeAggressionTest.exe
if not "%errorlevel%"=="0" exit /b 1
NativeAggressionTest.exe
if not "%errorlevel%"=="0" exit /b 1
"@
$batch=Join-Path $build 'compile.cmd'
[IO.File]::WriteAllText($batch,$commands,[Text.Encoding]::Default)
& $batch
if($LASTEXITCODE -ne 0){throw 'Native game bridge build or tests failed.'}
Copy-Item -LiteralPath (Join-Path $build 'ZoneFPVNative.dll') -Destination (Join-Path $PSScriptRoot 'mod/ZoneFPVNative.dll') -Force
Write-Output 'Native game bridge rebuilt and tested.'
