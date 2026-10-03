# ZoneFPV 0.2.0 — 2026-10-03

The author completed the final in-game check and reports that everything works. They authorized publishing stable 0.2.0 as a new release on GitHub and Nexus, preserving previous versions. They also authorized updating the general description with the new features. The existing GitHub release-list mirror is retained.

**Release: stable 0.2.0.** Current download and scan status are shown on the [GitHub release](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.2.0) and [Nexus Files page](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799?tab=files). Stable version designation does not imply Nexus scan approval.

## Verified candidate

- Latest optimized MSVC x64 helper build passed with `/O2 /W4 /WX`.
- All **21 Lua test suites** passed after the HUD restoration changes. The full code audit also checked syntax for all **28 production Lua files** and **8 production PowerShell scripts**.
- All **5 native test executables** passed after the OSD settings resize change: controller/calibration profiles, OSD layout/font, object-limit configuration, F6 menu resizing and OSD editor resizing.
- Native window tests verified proportional controls/fonts, saved dimensions, malformed-settings rejection, game aspect ratios at 16:9 and 3440:1440, unchanged OSD layout and no unwanted focus/overlay changes.
- Windows PowerShell 5.1 installer checks passed, including UTF-8 mod-name preservation and rollback after copy, verification and legacy PAK retirement failures.
- The latest helper was installed with the game/helper closed and verified by SHA-256; **85 other installed files were unchanged**. Its SHA-256 is `44E2E9000C4BC828ABD89F20A6BE264E3D86ACE9E07C3D05F8FD6B0EBBF2AD52`.
- The author confirmed working HUD restoration, resizable F6/OSD settings and the final overall in-game check.

Distribution excludes personal preferences, Engine.ini, backups, transient reports and retired experiments. The installer ZIP includes a SHA-256 manifest for all packaged files. Its native helper is identical to the tested binary above; the final runtime change is the stable version banner only. Archive CRCs, manifest hashes and equivalence to the installed tested runtime are checked before uploading.

## Known limitations

The CNPP black anomaly effect remains unresolved; checkpoint quest fog is unchanged. Unloaded geometry and missing collision remain possible. Physical DualShock 4 DirectInput testing is pending. User feedback and automated checks do not establish crash-free behavior or measured numerical FPS gains.

Higher geometry multipliers through 5× can reduce FPS and increase RAM use. Optional `gc.MaxObjectsInGame` changes affect the whole game after a full restart, may increase RAM/loading/garbage collection costs and do not guarantee stability. Save/Game default actions require explicit input, back up existing Engine.ini and preserve unrelated settings and supported encoding. Installation/startup do not edit this setting automatically. Actual startup object capacity has not been verified.
