# ZoneFPV 0.2.0 RC2 — 2026-09-21

Previous RC1 installation preserved all 16 existing preference/calibration files, and the installed executable detected DualSense Wireless Controller. The user reported the version working; this does not individually confirm all feature checks below.

Passed:
- RC2 camera-tilt scrollbar and physical mouse-wheel scrolling in the native menu.
- RC2 native rebuild, repeated profile/OSD tests and isolated two-install preservation test.
- MSVC C++17 /W4 /WX build; native smoke run and protocol v4 output.
- Sony vendor identification, RadioMaster/Jumper/FlySky profile detection, nine profile variants, no overwrite of manual calibration, backup on explicit replacement, four-step calibration direction confirmation.
- OSD persistence, corrupt-file rejection, old-layout migration, actual Betaflight glyph decode, German localization.
- Visual inspection: tab layout, German, dark/light theme, disconnected controller warning.
- Steam auto-discovery and two consecutive installer runs against an isolated fixture; settings, other mods and runtime preserved; deployed file hashes verified.
- DualSense live input read and automatic initial profile creation.
- Static Lua syntax analysis: all 27 runtime/test files pass.

Not yet verified:
- Lua behavioral tests: Windows App Control blocks the existing test interpreter. No security controls were changed. Test.ps1 accepts a Lua 5.4 interpreter on an approved environment.
- In-game Angle leveling, inverted 3D, remapped hotkeys, all analog profiles and physical disconnect/reconnect.
- Other controller hardware, Bluetooth/virtual-device combinations, clean-machine installation and additional game versions.

Release candidate only. Do not advertise universal compatibility or measured FPS gains. New bridge is unsigned; application control may reject it on other computers. UE4SS and its game-specific compatibility patch are separate dependencies. RC2 explicitly requests ProcessEvent dispatch where the runtime exposes this option; in-game regression checking after this change remains outstanding.

RC2 deployment: installed file hashes match the release sources; 30 existing state/settings/calibration files retained byte-for-byte. Installed bridge --probe exits successfully; no controller was enumerated at this final check. No new in-game flight test was performed after installation.
