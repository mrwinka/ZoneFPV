# ZoneFPV 0.2.0 source review notes

This repository contains the source for the stable 0.2.0 release. Ready-to-install binaries are attached to the GitHub release; UE4SS and game assets are not included. Previous release candidates remain available in their tags/releases. `RELEASE_SHA256SUMS.txt` identifies the current installer archive.

## Helper behavior

`ZoneFPVInput.exe` reads controllers through DirectInput/XInput/WinMM, displays native settings and OSD windows, synthesizes drone audio and exchanges input/settings/telemetry with Lua through local files in the mod directory. It checks game focus and watches the supplied game process handle. UE4SS hosts the in-game scripts. The helper has no network client, updater or credential collection.

## Startup and configuration

`bridge.lua` invokes local `Start-Bridge.ps1` using PowerShell `-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand`. The UTF-16LE/Base64 command preserves literal installation paths; its encoder and plain command construction are visible in source. The bootstrap does not hide an inherited UE4SS console; the separately launched helper starts hidden. No remote payload is retrieved.

`Setup.cmd` invokes its adjacent script with process-scoped ExecutionPolicy Bypass. This does not change machine-wide policy. The installer discovers Steam libraries, copies ZoneFPV, updates its entry in mods.txt, preserves preferences and backs up the previous mod. Failed updates roll back the previous mod and list. The uninstaller disables and moves ZoneFPV to a backup; it does not remove UE4SS.

The optional object-capacity field writes `gc.MaxObjectsInGame` to the user's Engine.ini only after an explicit Save action, preserving unrelated settings and backing up existing files. Game default removes that override. A full game restart is required. Installation and normal startup do not change object capacity. No script disables antivirus, configures exclusions or changes Windows App Control.

## Build and validation

Build entry point and flags are in Build.ps1. A different compiler version, path or timestamp may produce a different binary hash; byte-identical reproducible compilation is not promised. The released helper is the exact binary used for the author's final in-game checks. See RELEASE_STATUS.md for automated checks and remaining limitations.

Source publication is not a Nexus scan approval. Nexus controls its own quarantine and review status.
