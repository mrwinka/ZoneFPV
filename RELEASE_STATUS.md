# ZoneFPV 0.3.0 RC1 — validation status

This is an experimental prerelease based on stable 0.2.0. **`gameplay_verified=false`** for the latest changes. Offline checks pass; live NPC model preservation and scanner recovery remain open.

## Current evidence

- All 66 Lua test suites passed after the latest corrections.
- Syntax checks passed for 139 Lua source/test files.
- Installed runtime files were compared with source hashes; the installation preserves existing preferences.
- Regression tests reproduce delayed NPC readiness and changed ownership within an equipment attachment chain, and verify the bounded corrections.
- Existing v55 input/overlay helper and v51 native DLL are reused; This release does not include a new binary build.

The scanner tests cover late model/world/root readiness, queue and time bounds, current-camera projection, simultaneous visible NPCs, stale/invalid identities and complete protocol packets. Visibility tests cover 23 scenarios including ancestor transfer, identity/world changes, repeated updates, exit and discovery order.

Tests use fixtures/mocks and do not establish in-game FPS, absence of all crashes or restoration of models already removed by the game. The relationship between native movement ticking and live NPC residency is still a hypothesis. No forced NPC visibility or guessed native position writes are used.

## In-game validation still needed

Check simultaneous NPC/mutant scanning in ordinary and thermal vision, moving/rolling FPV, lower-camera view, late streaming and leaving FPV. Confirm actual NPC models remain present. Check PDA OSD dragging and controller/calibration against the physical device. The known CNPP regional effect, unloaded collision and Alternative FPV simulation limits remain.

## Publication

The prepared public release is named **0.3.0 RC1**. Its attached installer is **ZoneFPV-0.3.0-RC1.zip** (126 files, 109 runtime files); SHA-256: 36d620a5c317650378862f66d97f697dabd048e3054d2a784e8907a5c67f2afb.

The source/package update changes one runtime log label and public documentation/file names. The 108 other runtime files, native/helper binaries and Armament PAK are byte-identical to the reviewed build. Existing tests cover the unchanged runtime behavior; the log-only substitution is checked separately. The installer is tested in an isolated install/update/uninstall fixture.

Publication and post-download checks must be recorded after GitHub/Nexus upload. Stable 0.2.0 remains separate. This naming change does not change **gameplay_verified=false**.
