# 0.2.0 RC4 — 2026-10-02

Changes relative to RC3:

- Main FPV is the default, with an explained alternative mode.
- Stronger simple/complex sphere collision using both trace channel and player profile.
- Player/weapon/shadow/subtitle hiding, supported exposure/audio suppression and state restoration.
- RC2/RC3-style hidden simulation anchor prevents player detection without stopping NPC/mutant fights with each other.
- Weather/time changes preserve drone position; world freeze keeps FPV usable; F6 closing and focus loss do not end FPV.
- Full uniform geometry loading multipliers 1×, 1.25×, 1.5×, 2×, 3×, 4×, 5× across all ten original terrain/building/prop/tree/foliage/HLOD grids. Exact original values are restored on exit.
- Rendering tab: optional, manually entered `gc.MaxObjectsInGame`, with Save to Engine.ini and Game default actions. Changes require explicit user input and a full game restart, affect the whole game and can increase RAM/loading/GC costs. Existing Engine.ini is backed up before a requested change; unrelated settings and UTF-8/UTF-16LE content are preserved. Installation/startup do not edit this setting automatically.
- Explicit DualShock 4 DirectInput identification/profile; physical hardware test pending.
- Reduce physics allocations/repeated math, cache unchanged packets, skip held-camera writes and duplicate presentation setters; audio-state reads at 50 Hz and cached OSD positioning. Keep 240 Hz physics and all collision queries.
- Remove unused experimental tools; update build, tests, documentation and installer cleanup checks.

The CNPP black effect remains unresolved; quest checkpoint fog is unchanged. Unloaded geometry and missing collision remain possible. Higher rendering multipliers can reduce FPS and increase RAM use; changing the object limit does not guarantee stability. Physical DS4 testing is pending. These optimizations have no measured in-game FPS result.

# 0.2.0 RC3 — 2026-09-27

- Respect UE4SS's configured game-thread method, including EngineTick; remove the RC2 ProcessEvent override.
- Catch dispatch errors, release the pending flag and rate-limit retries without switching hooks.
- Reduce worker polling from 1 ms to 4 ms while keeping at most one queued callback.
- Stop hiding a potentially inherited console during the PowerShell bootstrap.
- Restrict native game focus/hotkeys/OSD targeting to the Unreal viewport; ignore queued hotkeys after focus leaves eligible windows.
- Document the reported game 2.0.6 / UE4SS 527a483b setup. The reporter confirmed RC3 worked without the earlier freezes.

# 0.2.0 RC2 — 2026-09-21

- Camera tilt dropdown has a scrollbar and supports mouse-wheel scrolling.
- Explicitly select ProcessEvent for game-thread dispatch when available, matching the original runtime configuration.
- Add publication, installation and build documentation.
- Clarify runtime and version-specific compatibility requirements.

# 0.2.0 RC1

- Acro / Angle / reversible-thrust 3D selection.
- Controller profiles, guided calibration and hotplug handling.
- Five languages, dark/light themes and configurable keys.
- Four analog styles and configurable telemetry OSD.
- Steam-aware installer, update backups and uninstall script.

