# ZoneFPV 0.2.0 RC4 — 2026-10-02

The user tested the current RC4 build and reports that everything appears to work. They authorized publishing RC4 as a new version, preserving RC2/RC3 and the existing general Nexus description and mirror. Final publication is being prepared.

Actual startup object capacity has not been verified. User feedback and automated checks do not establish crash-free behavior or measured in-game FPS gains. Higher geometry multipliers through full 5× can reduce FPS and increase RAM use. Unloaded geometry and missing collision remain possible. The CNPP black regional effect remains unresolved; checkpoint quest fog is unchanged. Physical DS4 DirectInput testing is pending.

The optional `gc.MaxObjectsInGame` startup override affects the whole game and requires a full restart. Save/Game default changes require explicit user input, back up existing Engine.ini before a change and preserve unrelated settings and supported encoding. Higher capacity may increase RAM, loading and garbage collection costs. Installation/startup do not edit this setting automatically.

Completed checks for the tested RC4 code:

- Optimized MSVC x64 build with warnings treated as errors passed.
- All 19 Lua suites and syntax loading for 45 Lua files passed, including uniform 5× on all ten original geometry grids and exact restoration.
- Native controller, OSD and six Engine.ini configuration contract tests passed. Tests cover positive int32 validation, missing file creation, backups, duplicate handling, comments, targeted reset, UTF-8/UTF-16LE preservation and rejection of unsupported files.
- The tested ZIP contained 86 allowlisted files with verified CRC and SHA-256 manifest. Personal settings, Engine.ini, backups and retired experiments were excluded.
- Installation with the game closed verified all 31 updated mod files against their packaged hashes and preserved all 45 existing preference/report files exactly. The previous installation was backed up.

The final RC4 package contains 86 allowlisted files, with CRC and every SHA-256 manifest entry verified. Its native executable is unchanged from the tested candidate; the runtime change for release is the RC4 version log. Syntax loading of all 45 Lua files and all 20 lifecycle/adapter contract tests passed again for the final version. The package excludes personal settings, Engine.ini, backups and retired experiments. Publication and scan status are shown on the GitHub/Nexus release pages.
