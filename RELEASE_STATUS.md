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

GitHub source and the prerelease [v0.3.0-rc1-v58](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.3.0-rc1-v58) were published on 2026-10-08. The tag points to f9fc1eca4f83fbc37d3f8b4fc97575fbaedfd0e7. All 267 source-tree file hashes were checked; all three attached assets were downloaded again and matched the prepared package. Stable 0.2.0 remains Latest and previous downloads are preserved.

The public installer has 126 entries including 109 unchanged verified runtime files and the mod's own armament PAK. Its SHA-256 is e1085ce4d23318a6b9d5daa13ec16987201cda9795e43cedc7910c1d65e79929. It also passed isolated mock installation/update/uninstall checks. Local logs, private preferences and installation receipts are excluded.

Nexus publication is still pending: the available browser requires login. The matching archive, bilingual description and file notes are prepared. No Nexus upload, description change or clearance is claimed. This publication status does not change gameplay_verified=false.
