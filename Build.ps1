$ErrorActionPreference='Stop'
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if(!(Test-Path -LiteralPath $vswhere)){throw 'Visual Studio C++ Build Tools required.'}
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(!$vs){throw 'MSVC x64 compiler not installed.'}
$vcvars=Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$build=Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$commands=@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b 1
cd /d "$build"
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT "$PSScriptRoot\src\input.cpp" /Fe:ZoneFPVInput.exe /link winmm.lib user32.lib gdi32.lib
if errorlevel 1 exit /b 1
"@
$batch=Join-Path $build 'compile.cmd'
[IO.File]::WriteAllText($batch,$commands,[Text.Encoding]::Default)
& $batch
if($LASTEXITCODE -ne 0){throw 'MSVC build failed.'}
Copy-Item -LiteralPath (Join-Path $build 'ZoneFPVInput.exe') -Destination (Join-Path $PSScriptRoot 'mod\ZoneFPVInput.exe') -Force
Write-Host 'Input bridge rebuilt. The Lua mod uses source files directly.'
