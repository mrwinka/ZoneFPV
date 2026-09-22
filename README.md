# ZoneFPV — FPV Drone Camera

Source snapshot for **0.2.0 RC2**, a public-beta UE4SS mod for STALKER 2 on Windows x64.

[Nexus Mods page](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799)

This repository provides the source for review and local compilation. It does not contain a prebuilt executable, UE4SS binaries, game assets, personal settings or logs. The Nexus archive is undergoing quarantine review; this source publication does not establish antivirus clearance.

## Build the native helper

Prerequisites: Windows x64, Windows PowerShell, Visual Studio 2022 or newer / Build Tools with **Desktop development with C++**, MSVC x64 tools and a Windows SDK. No Python, npm, NuGet or downloaded source dependencies are used by the build script.

Download this repository through Code → Download ZIP and extract it, or clone it. Open PowerShell in the repository root:

```powershell
.\Build.ps1
```

The script locates MSVC through vswhere, loads vcvars64.bat and compiles `src/input.cpp` with C++17, `/O2 /MT /W4 /WX`. Output: `build/ZoneFPVInput.exe`, also copied to `mod/ZoneFPVInput.exe`. Additional headers are in `src/`. Windows libraries used include WinMM, User32, GDI32, DirectInput8, DXGUID and XInput. Lua files in `mod/Scripts` are loaded directly by UE4SS and need no compilation.

Build does not install or start the mod. To install a locally compiled copy, close the game and run `Setup.cmd`; install the separately required compatible UE4SS first. See [installation](SITE_INSTALL.md) and [dependencies](DEPENDENCIES.md). Follow your computer's script/application approval policy if execution is restricted.

## Tests

In an x64 Native Tools Command Prompt for Visual Studio, from the repository root:

```bat
mkdir build
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT src\osd_test.cpp /Fe:build\osd_test.exe /Fo:build\osd_test.obj /link winmm.lib user32.lib gdi32.lib
build\osd_test.exe
cl /nologo /utf-8 /W4 /WX /EHsc /std:c++17 /O2 /MT src\calibration_test.cpp /Fe:build\calibration_test.exe /Fo:build\calibration_test.obj /link winmm.lib user32.lib gdi32.lib
build\calibration_test.exe
```

PowerShell, from the repository root:

```powershell
.\tests\installer_test.ps1
.\Test.ps1 -LuaPath 'C:\path\to\approved\lua.exe'
```

The second command requires an independently installed Lua 5.4 interpreter approved for your machine. Native tests and installer fixture tests passed during RC2 preparation; Lua runtime tests were not executed because the available interpreter was blocked by local application control. Static syntax checking passed for the Lua runtime/test files. New in-game modes and additional computers still require validation; see [release status](RELEASE_STATUS.md).

## Review map

- `src/input.cpp`, `controllers.h`, `controller_profiles.h`: controller enumeration, local input state and calibration.
- `src/weather_menu.h`, `language.h`, `ui_theme.h`: settings UI and localization.
- `src/osd.h`, `drone_audio.h`: telemetry overlay and synthesized audio.
- `mod/Scripts`: UE4SS camera/flight/world scripts.
- `mod/Scripts/bridge.lua`, `mod/Start-Bridge.ps1`: helper startup; see [review notes](REVIEW_NOTES.md).
- `Setup.ps1`, `Install-Mod.ps1`, `Uninstall.ps1`: game discovery, installation, backups and removal.

## Licenses and attribution

ZoneFPV code: [MIT](LICENSE.txt). The separate, unmodified Betaflight bitmap font is distributed with its source and GPL-3.0-or-later license under `mod/fonts`. UE4SS and its game-specific compatibility patch are separate dependencies. Project code, UI text and documentation were developed with generative AI assistance; validation limits are documented above.
