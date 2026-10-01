$ErrorActionPreference='Stop'
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if(!(Test-Path -LiteralPath $vswhere)){throw 'Visual Studio C++ Build Tools required.'}
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(!$vs){throw 'MSVC x64 compiler not installed.'}
$vcvars=Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$build=Join-Path $PSScriptRoot 'build\native-tests'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$commands=@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b 1
cd /d "$build"
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT "$PSScriptRoot\src\calibration_test.cpp" /Fe:calibration_test.exe /link winmm.lib user32.lib gdi32.lib
if errorlevel 1 exit /b 1
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT "$PSScriptRoot\src\osd_test.cpp" /Fe:osd_test.exe /link user32.lib gdi32.lib
if errorlevel 1 exit /b 1
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT "$PSScriptRoot\src\object_limit_test.cpp" /Fe:object_limit_test.exe
if errorlevel 1 exit /b 1
calibration_test.exe
if not "%errorlevel%"=="0" exit /b 1
osd_test.exe
if not "%errorlevel%"=="0" exit /b 1
object_limit_test.exe
if not "%errorlevel%"=="0" exit /b 1
"@
$batch=Join-Path $build 'test.cmd'
[IO.File]::WriteAllText($batch,$commands,[Text.Encoding]::Default)
& $batch
if($LASTEXITCODE -ne 0){throw 'Native tests failed.'}
Write-Output 'PASS native controller profiles/calibration, OSD layout/font and object-limit config tests'
