# 0.2.0 RC3 — 2026-09-27

- Respect UE4SS's configured game-thread method, including EngineTick; remove the RC2 ProcessEvent override.
- Catch dispatch errors, release the pending flag and rate-limit retries without switching hooks.
- Reduce worker polling from 1 ms to 4 ms while keeping at most one queued callback; no measured FPS improvement claimed.
- Stop hiding a potentially inherited console during the PowerShell bootstrap.
- Restrict native game focus/hotkeys/OSD targeting to the Unreal viewport; ignore queued hotkeys after focus leaves eligible windows.
- Document the reported 2.0.6/UE4SS 527a483b incompatibility and pending in-game verification.

# 0.2.0 RC2 — 2026-09-21

- Camera tilt dropdown now has a scrollbar and supports mouse-wheel scrolling; verified in the native menu.
- Explicitly select ProcessEvent for game-thread dispatch when available, matching the supported runtime configuration.
- Added publication guide, English/Russian page descriptions and installation/troubleshooting text.
- Clarified UE4SS base-build requirements and version-specific compatibility patch instructions.
- Rechecked native build/tests, installer preservation and Lua syntax. See RELEASE_STATUS.md for limits.

# 0.2.0 RC1

- Acro / Angle / reversible-thrust 3D selection.
- Additional controller profiles and hotplug handling improvements.
- German localization, five interface languages, dark/light themes and configurable keys.
- Four analog styles, configurable telemetry OSD, guided calibration and tabbed menu.
- Steam-aware installer, update backups and uninstall script.
