# ZoneFPV 0.2.0 RC3 — 2026-09-27

Public release candidate. On 2026-09-27 the user reported testing in-game successfully. The exact game/UE4SS versions and individual console/focus/stutter checks were not supplied, so this does not yet establish resolution on the original reporter's 2.0.6/UE4SS 527a483b setup. Native MSVC /W4 /WX build, RadioMaster input probe, static syntax checks for 29 Lua files and installer preference-preservation checks passed. New scheduler regression tests cover configured-default dispatch, deferred execution and failure backoff without hook fallback. Execution of Lua tests remains blocked by Windows App Control after a retry with the user's current permissions on 2026-09-27; security settings were not changed.

Required reporter checks: preserve EngineTick settings; start with the UE4SS console open; verify the log says `UE4SS configured default`; load a save and test F6/F8, flight and exit; Alt+Tab to console/overlays and check focus; compare stutters with RC2; return UE4SS.log and mod/stall-diagnostic.txt if still failing.

## Previous RC2 results — 2026-09-21

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
