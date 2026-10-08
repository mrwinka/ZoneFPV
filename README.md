# ZoneFPV

A transmitter/gamepad-controlled FPV drone camera for S.T.A.L.K.E.R. 2, with quadcopter-style flight, configurable OSD and camera effects.

**Stable release: 0.2.0. Latest experimental prerelease: 0.3.0 RC1 debug v58.** Choose the corresponding attached installer ZIP in [Releases](https://github.com/mrwinka/ZoneFPV/releases). The automatic Source code archive is for development and does not contain a ready-to-use runtime.

[Русская инструкция](README_RU.md) · [Install and troubleshoot](SITE_INSTALL.md) · [Release notes](RELEASE_NOTES.md) · [Validation status](RELEASE_STATUS.md) · [Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799)

The latest v58 NPC/scanner corrections passed offline checks. **`gameplay_verified=false`: NPC disappearance and scanner recovery remain unverified in a live game.** This is a prerelease, not a replacement claim for author-tested stable 0.2.0.

## Features

- Acro, self-leveling Angle and reversible-thrust 3D flight, with adjustable rates, expo, speed and camera tilt.
- DirectInput, XInput and WinMM controller selection/profiles and four-axis calibration. Transmitters use USB Joystick/HID mode.
- All settings inside the native PDA, with independent external F6 and shared preferences. Long lists scroll vertically.
- Arbitrary keyboard/mouse/controller button/CH assignments, each with Toggle/Hold. Held grenade release repeats at intervals; artifact collection retries on approach.
- Draggable OSD preview and a vertical selector for all 14 indicators, including drone HP, detector and grenade stock. Independently enabled/styled normal and lower-camera crosshairs.
- Night/infrared/thermal vision and analog effects, assignable flashlight and a lower camera that rotates with the body. NIR/SWIR approximate visible-light imagery.
- Kamikaze, grenade-drop and combined modes; impact power/speed, RGD-5/F-1 and 1–20/unlimited charges.
- NPC/mutant/anomaly scanning, artifact collection with adjustable reach, simulated interference/loss, time/weather/world-loading controls and five interface languages.

## Menus and controls

Open **PDA → ZoneFPV** or press **F6**. Both menus contain **Flight**, **Image**, **Equipment**, **World and signal**, **Settings**. Controller/calibration is in **Settings → Controller**, assignments in **Settings → Buttons**, and the OSD preview in **Image → OSD**. General contains language/audio/object-limit settings.

Defaults: **F6 settings, F8 enter/exit FPV, F9 return to launch**. Lower throttle in Acro/Angle or center it in 3D before entering. Close settings/PDA to fly. Flashlight/lower-camera checkboxes permit assigned inputs to activate them; they do not activate the feature by themselves.

## Installation

Install a game-compatible UE4SS runtime separately. Close the game, extract the complete attached installer ZIP and run **Setup.cmd**. Connect the controller, load a save, select/calibrate it and verify stick directions. Updates preserve preferences and create a backup; UE4SS/other mods are not bundled or replaced. End users need neither a compiler nor Python. Vortex installation is not tested. See [installation](SITE_INSTALL.md) and [dependencies](DEPENDENCIES.md).

## Latest corrections and limits

v58 retains bounded retries for living NPCs whose model/world/root becomes ready late and validates ownership/identity across the full player-equipment attachment chain. Transferred descendants stop receiving visibility writes. Original movement-component ticking and read-only residency diagnostics remain from v57.

All **66 Lua suites** passed and **139 Lua files** parsed; installed runtime files were hash-verified. Existing v55 helper/v51 native DLL are reused without a new binary build. These checks do not establish live model recovery, absence of all crashes or measured FPS gains. [Review evidence](REVIEW_NOTES.md).

Main FPV moves the simulation anchor with the drone; Alternative FPV leaves it at launch and can lack distant NPC simulation/collision. Unloaded geometry/collision, the CNPP regional black effect and quest weather remain possible. Increased loading/object limits can increase RAM and pauses; object-capacity changes in **Settings → General** require a game restart. [Object limit](OBJECT_LIMIT.md).

## Build the native helper

Install Visual Studio C++ Build Tools with the x64 compiler. From a source checkout, run PowerShell:

```powershell
.\Build.ps1
.\Native-Build.ps1
```

`Build.ps1` builds/copies `mod/ZoneFPVInput.exe`. `Native-Build.ps1` builds/tests/copies `mod/ZoneFPVNative.dll`. Lua runs from `mod/Scripts`. The public installer includes the verified binaries and the mod's own armament PAK; developers rebuilding binaries must keep the matching runtime/assets. These source scripts do not install UE4SS.

```powershell
.\Test.ps1 -LuaPath 'C:\path\to\lua.exe'
.\Test-Native.ps1
.\tests\installer_test.ps1
```

Lua tests require Lua 5.4; it is not bundled. Native tests require MSVC. Tests use fixtures/mocks and cannot validate every game API, physical controller or game FPS. Native sources are in `src` and runtime Lua in `mod/Scripts`.

## Licensing

ZoneFPV code is MIT (`LICENSE.txt`). The included Betaflight OSD font is separately GPL-3.0-or-later; source/license are in `mod/fonts`. MinHook has its own included license. UE4SS, compatibility patches and proprietary game assets are not bundled.
