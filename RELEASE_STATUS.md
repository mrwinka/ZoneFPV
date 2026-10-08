# ZoneFPV 0.3.0 RC1 debug v58 — validation status

This is an experimental prerelease based on stable 0.2.0. **`gameplay_verified=false`** for the latest v58 changes. Offline checks pass; live NPC model preservation and scanner recovery remain open.

## Current evidence

- All 66 Lua test suites passed after the v58 corrections.
- Syntax checks passed for 139 Lua source/test files.
- Installed runtime files were compared with source hashes; the installation preserves existing preferences.
- Regression tests reproduce delayed NPC readiness and changed ownership within an equipment attachment chain, and verify the bounded corrections.
- Existing v55 input/overlay helper and v51 native DLL are reused; v58 does not include a new binary build.

The scanner tests cover late model/world/root readiness, queue and time bounds, current-camera projection, simultaneous visible NPCs, stale/invalid identities and complete protocol packets. Visibility tests cover 23 scenarios including ancestor transfer, identity/world changes, repeated updates, exit and discovery order.

Tests use fixtures/mocks and do not establish in-game FPS, absence of all crashes or restoration of models already removed by the game. The relationship between native movement ticking and live NPC residency is still a hypothesis. No forced NPC visibility or guessed native position writes are used.

## In-game validation still needed

Check simultaneous NPC/mutant scanning in ordinary and thermal vision, moving/rolling FPV, lower-camera view, late streaming and leaving FPV. Confirm actual NPC models remain present. Check PDA OSD dragging and controller/calibration against the physical device. The known CNPP regional effect, unloaded collision and Alternative FPV simulation limits remain.

## Publication

The intended destinations are the existing [GitHub repository/releases](https://github.com/mrwinka/ZoneFPV/releases) and [Nexus page](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799). Release notes and descriptions identify v58 as experimental; stable 0.2.0 and earlier downloads remain separate. A prepared archive or description does not by itself confirm publication. Final publication URLs and availability must be verified on each service.
