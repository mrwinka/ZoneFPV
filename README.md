# ZoneFPV

Fly a transmitter/gamepad-controlled FPV drone, explore the Zone, scan nearby targets, collect artifacts or equip a combat payload.

**Current version: 0.3.0 RC2 — release candidate.** Download the attached **ZoneFPV-0.3.0-RC2.zip** from [Releases](https://github.com/mrwinka/ZoneFPV/releases), rather than the automatic Source code archive. Older releases remain available.

**Stable alternative: [0.2.1](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.2.1).** It retains the game files from the author-tested stable 0.2.0 and fixes only installer discovery of unavailable Steam library drives. Extract the full ZIP and run Setup.cmd; manual commands are unnecessary for normal installation. The feature list below describes 0.3.0 RC2.

[Русский](README_RU.md) · [Release notes](RELEASE_NOTES.md) · [Install / troubleshooting](SITE_INSTALL.md) · [Verification status](RELEASE_STATUS.md)

## Features

- **Flight:** Acro, self-leveling Angle and reversible-thrust 3D; adjustable speed, rates, expo and camera tilt, collision checks and drone audio.
- **Settings in the PDA and F6:** the F6 settings menu is duplicated in **PDA → ZoneFPV**. Flight, Image, Equipment, World and signal, and Settings use the same saved preferences. Controller selection, calibration and button assignments open directly inside the PDA. Lists scroll vertically.
- **Controllers and assignments:** DirectInput, XInput and WinMM devices, USB hot connection, profiles and guided four-axis calibration. Capture the keyboard key, mouse button, controller button or CH you actually press. Assignments support Toggle and Hold.
- **Combat drones:** unarmed, kamikaze, grenade-drop or **grenade drop + kamikaze**. Adjust impact speed and blast power; gentle contact need not detonate. Drop activated **RGD-5 or F-1** grenades with **1–20 or unlimited charges**. Held release repeats at intervals; ammunition is shown in flight. Only settings relevant to the selected loadout are shown.
- **Vision:** night/infrared-style options including Starlight IR, NIR, SWIR and IR LED, thermal palettes including White Hot, Black Hot, Rainbow and Ironbow, plus independent analog-camera effects. Toggle the selected vision with an assigned button; an unbound selected vision starts on FPV entry.
- **Lower camera and flashlight:** look directly below through a camera attached to the drone's body; Toggle/Hold support and an independently configurable downward crosshair. The horizon hides in downward view. Enable the flashlight feature in settings, then operate it with its binding.
- **Artifact collection:** collect the nearest artifact with an assigned action; choose a **0.5–10 m** range. Held collection retries as you approach.
- **Scanner:** configurable frames and distances for loaded NPCs, mutants and anomalies, with native faction icons for NPCs. Brackets render in the game's current frame; the scanner does not force NPC visibility or change their AI.
- **Battery simulation — new in RC2:** optional LiPo **300–20000 mAh, 2–8S**, default 1500 mAh/6S. Thrust-dependent consumption, pack mass, voltage sag/recovery and temperature influence flight. A movable OSD item shows charge, voltage, current, used mAh and LOW/LAND warnings. New flights start full; return-to-launch preserves charge; menus/focus pauses do not drain it. This is a physical approximation, not a calibrated replica of specific hardware.
- **OSD:** configurable telemetry placement, size, colour and crosshair styles. Select and drag preview elements inside the PDA; the external editor uses the same layout.
- **World and signal:** configurable distance/obstacle/anomaly interference, weather/time, world freeze and geometry loading distance. RU/UK/EN/PL/DE interface.

## RC2 changes from RC1

- Added battery simulation and its OSD telemetry.
- Improved discovery of reactivated/pool-reused NPCs; moved scanner brackets into game-frame UI, restored compact colours/sizing and faction icons, and improved modular thermal coverage.
- Restored PDA-tab compatibility, kept technician screens separate and applied the **field-instrument** look with native PDA backing/fonts and restrained amber accents.
- Corrected stale cursor restoration after FPV/PDA/Alt+Tab.
- Prevented the kamikaze drone's own blast from leaving player dirt/concussion feedback, including immediate reentry into FPV. Ordinary game grenades remain unchanged.
- Restored cleanup of aggression acquired from the drone while preserving hostility present before flight.
- Reduced repeated controller searches, resource-file operations, unavailable-effect loads and redundant same-frame collision checks. No guaranteed FPS gain or universal crash fix is claimed.

Combat, vision effects, artifact collection, button/CH capture and the duplicated PDA/F6 settings were already included in RC1 and remain available in RC2.

## Requirements and installation

Windows 10/11 x64, S.T.A.L.K.E.R. 2 PC, a separately installed **game-compatible UE4SS runtime**, and a USB Joystick transmitter or supported gamepad.

1. Close the game. Extract the complete **ZoneFPV-0.3.0-RC2.zip** archive and run **Setup.cmd**; choose the game folder if needed.
2. Connect your transmitter in **USB Joystick** mode or a gamepad, start the game and load a save.
3. Open **PDA → ZoneFPV** or **F6 → Settings → Controller**, select the device, check directions and calibrate.
4. Defaults: **F6 settings, F8 enter/leave FPV, F9 return to launch**. Lower throttle in Acro/Angle or centre it in 3D before entering. Close settings/PDA to fly.

Update the entire archive together, including EXE, DLL and PAK, and restart the game. Preferences, calibration and OSD positions are preserved; the installer backs up the previous mod. Players do not need a compiler or Python. ZoneFPV does not bundle or replace UE4SS or other mods. Vortex installation is not tested.

## Limits and support

RC2 is a release candidate. Loading-distance increases can raise RAM/streaming cost and do not create collision for unloaded objects. Main FPV follows the drone with the simulation anchor; Alternative FPV leaves it at launch with reduced remote NPC/collision coverage. NIR/SWIR and battery behaviour are approximations. Regional quest weather/CNPP effects and game-update compatibility remain limitations. Borderless/windowed play is recommended for the external OSD. Achievement compatibility is retained.

For reports, include the game/UE4SS/mod version, reproduction steps, **UE4SS.log** and the mod's **performance.txt**. To uninstall with the game closed, use **Uninstall.ps1** from the extracted installer; see the installation guide for options.

[GitHub download mirror](https://github.com/mrwinka/ZoneFPV/releases/latest) · [Public source code](https://github.com/mrwinka/ZoneFPV) · [Install / troubleshooting EN/RU](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md)


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


