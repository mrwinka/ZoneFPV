# ZoneFPV 0.3.0 RC1 — publication status, 2026-10-08

## GitHub — published and downloaded

[ZoneFPV 0.3.0 RC1](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.3.0-rc1) is the current recommended download and is marked **Latest**. The version remains a release candidate. Tag `v0.3.0-rc1` targets source commit `90f85ffc781a98718462cdc644fefbf9a28fdf60`. Source, README EN/RU, installation, description, changelog and verification documentation were updated. Public release/package/documentation names consistently use **0.3.0 RC1**, without the internal debugging number. Older releases, including author-tested 0.2.0, are preserved.

The release now has exactly three attachments: **ZoneFPV-0.3.0-RC1.zip**, **ZoneFPV-0.3.0-RC1-verification.json** and **SHA256SUMS.txt**. All were downloaded again and SHA-256 verified. Three obsolete attachments were deleted after explicit user confirmation. The installer contains 126 files, including 109 runtime files; SHA-256: `36d620a5c317650378862f66d97f697dabd048e3054d2a784e8907a5c67f2afb`.

## Nexus — Optional file quarantined, Main update blocked

[ZoneFPV on Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) lists version **0.3.0-RC1**, with updated summary, full EN/RU description and changelog. File **20277**, **ZoneFPV 0.3.0 RC1 - Experimental prerelease**, uses the exact clean ZIP and still appears in **Optional Files**; the site displays 1.0 MB and 08 October 2026, 8:01 AM. Nexus returned **403** when saving the Main/primary/name change; it did not apply. The older stable file remains primary. The editor also returned 403 after a normal sign-out/sign-in. A Cloudflare CAPTCHA checkbox now blocks further editing; its completion is still pending. Manual download only. The original publication used the website; no API key or separate script was needed.

Nexus file 20277 currently displays **QUARANTINED** and cannot be downloaded. A Nexus download/hash comparison must wait until the file becomes available; no scan clearance or Nexus download verification is claimed. The GitHub installer is available meanwhile.

## Validation and remaining checks

Latest corrections retain bounded delayed-NPC discovery and validate identity/ownership throughout equipment attachment ancestors before visibility/restoration writes. The naming update changes one FPV log string; the other 108 runtime files, helper/native binaries and Armament PAK are unchanged.

All 66 Lua suites, 139-file syntax checks and isolated install/update/uninstall checks passed. **`gameplay_verified=false`: live NPC preservation/scanner recovery remains unverified.** No new binary build or measured FPS improvement is claimed. In-game checks still include simultaneous NPC scanning in ordinary/thermal vision and after leaving FPV, PDA OSD editing, button/CH assignments and controller hotplug/calibration.
