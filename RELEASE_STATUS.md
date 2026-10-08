# ZoneFPV 0.3.0 RC1 — validation status

0.3.0 RC1 is the current recommended release candidate, based on author-tested 0.2.0. **`gameplay_verified=false`** for the latest changes. Offline checks pass; live NPC model preservation and scanner recovery remain open. Latest placement does not change this validation status.

## Current evidence

- All 66 Lua test suites passed after the latest corrections.
- Syntax checks passed for 139 Lua source/test files.
- Installed runtime files were compared with source hashes; the installation preserves existing preferences.
- Regression tests reproduce delayed NPC readiness and changed ownership within an equipment attachment chain, and verify the bounded corrections.
- Existing input/overlay helper and native DLL are reused; this release does not include a new binary build.

The scanner tests cover late model/world/root readiness, queue and time bounds, current-camera projection, simultaneous visible NPCs, stale/invalid identities and complete protocol packets. Visibility tests cover 23 scenarios including ancestor transfer, identity/world changes, repeated updates, exit and discovery order.

Tests use fixtures/mocks and do not establish in-game FPS, absence of all crashes or restoration of models already removed by the game. The relationship between native movement ticking and live NPC residency is still a hypothesis. No forced NPC visibility or guessed native position writes are used.

## In-game validation still needed

Check simultaneous NPC/mutant scanning in ordinary and thermal vision, moving/rolling FPV, lower-camera view, late streaming and leaving FPV. Confirm actual NPC models remain present. Check PDA OSD dragging and controller/calibration against the physical device. The known CNPP regional effect, unloaded collision and Alternative FPV simulation limits remain.

## Publication

**GitHub is published and marked Latest:** [ZoneFPV 0.3.0 RC1](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.3.0-rc1) is the current recommended download. Tag `v0.3.0-rc1` targets commit `90f85ffc781a98718462cdc644fefbf9a28fdf60`; the version remains a release candidate. The clean installer, public verification and SHA256SUMS were downloaded again and SHA-256 verified. These are now the only three release attachments; three obsolete attachments were deleted after explicit user confirmation. Older releases, including author-tested 0.2.0, remain preserved.

**ZoneFPV-0.3.0-RC1.zip** contains 126 files, including 109 runtime files; SHA-256: `36d620a5c317650378862f66d97f697dabd048e3054d2a784e8907a5c67f2afb`. Public names use 0.3.0 RC1 without the internal debugging number. The naming update changes one FPV log string and public documentation/file names. The other 108 runtime files, helper/native binaries and Armament PAK are unchanged. All 66 Lua suites, 139-file syntax checks and isolated install/update/uninstall checks passed.

**Nexus page is updated, but the Main update is blocked:** [mod 2799](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) lists version 0.3.0-RC1 with updated summary, full EN/RU description and changelog. File **20277**, **ZoneFPV 0.3.0 RC1 - Experimental prerelease**, contains the exact clean ZIP and still appears in **Optional Files**. Nexus returned **403** when saving the Main/primary/name change; it did not apply. The older stable file remains primary. The editor also returned 403 after a normal sign-out/sign-in. A Cloudflare CAPTCHA checkbox now blocks further editing; its completion is still pending. The site displays 1.0 MB and 08 October 2026, 8:01 AM. Manual download only.

**Nexus file 20277 is QUARANTINED:** it is not currently downloadable. Nexus post-download/hash verification cannot be completed until the file becomes available; no scan clearance is claimed. Use the GitHub installer meanwhile.

These publication/naming changes do not change **`gameplay_verified=false`**. Live NPC preservation/scanner recovery, PDA OSD editing, button/CH assignments and controller hotplug/calibration still require in-game checks.
