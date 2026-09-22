# RC2 source review notes

This snapshot is supplied for review of the existing Nexus upload, not as a replacement binary or a way to avoid its quarantine.

- Mod: https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799
- Release: ZoneFPV 0.2.0 RC2
- Original ZIP SHA256: `9e744373c0400de42e079b04979c70d7c93076144588452bf1a94eff0734f7fb`
- `RELEASE_SHA256SUMS.txt` records the original release manifest, including the original executable hash. The executable is intentionally absent from this source repository.
- RC2 source, scripts and font files are unchanged from that ZIP. Repository README, review notes and ignore rules are added documentation.

## Helper behavior

`ZoneFPVInput.exe` reads attached controllers through DirectInput/XInput/WinMM, displays a native settings window and OSD, synthesizes drone audio, and exchanges input/settings/telemetry with Lua using local files in the mod directory. It queries the foreground process identity and watches a supplied parent process handle to manage game focus and helper lifetime. The helper does not implement a network client, updater, credential collection or code injection. UE4SS, installed independently, hosts the in-game Lua scripts.

## Startup scripts

`bridge.lua` starts the local `Start-Bridge.ps1` through PowerShell using `-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand`. The encoded text is a UTF-16LE/Base64 command invoking the literal local script path, used to preserve Unicode and shell-sensitive characters in installation paths. The encoder and unencoded command construction are fully visible in the Lua source; no remote payload is retrieved.

`Setup.cmd` also invokes its adjacent PowerShell script using process-scoped `-ExecutionPolicy Bypass`. This is part of the exact published source and is documented here for review; it does not change the machine-wide execution policy. No script disables antivirus, configures exclusions or changes Windows App Control. `Start-Bridge.ps1` launches the helper hidden and redirects output/errors to local logs.

The installer reads Steam library paths, copies the mod into the selected game directory, updates only its entry in `mods.txt`, retains settings and creates a backup. It may stop an existing helper at that exact install path. The uninstaller disables and moves the mod to a backup location; it does not remove UE4SS.

## Build correspondence

The entry point and build flags are in `Build.ps1`; build instructions are in README.md. A rebuild with a different MSVC version, build path or timestamp may not have the same executable hash. The release hash identifies the original upload and is not a promise of byte-identical reproducible compilation.

The repository is not a malware clearance certificate. Please review the source and scan results before determining whether the original file should be released from quarantine.

## Source snapshot verification (2026-09-22)

The helper compiled successfully from this extracted source snapshot, and the OSD test executable passed. The calibration test compiled, but Windows Device Guard blocked its execution in this snapshot directory; no policy changes or bypass attempts were made. Earlier RC2 preparation results remain recorded in RELEASE_STATUS.md. No new in-game test was performed.

