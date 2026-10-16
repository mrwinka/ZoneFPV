# ZoneFPV 0.2.1 — installer-only stable update

**0.2.1 is an installer-only update to stable 0.2.0.** Steam libraries on unavailable drives are now skipped, so automatic detection can continue or the game folder can be selected manually. Extract the complete archive, close the game and run **Setup.cmd**; no command is normally required. The game runtime and native helper are byte-for-byte identical to stable 0.2.0. The in-game version may still read 0.2.0. This release does not include 0.3.0 RC features.

**0.2.1 — обновление только установщика стабильной 0.2.0.** Недоступные диски библиотек Steam теперь пропускаются: поиск игры продолжается, а при необходимости можно выбрать папку вручную. Полностью распакуйте архив, закройте игру и запустите **Setup.cmd** — обычно вводить команды не нужно. Игровые файлы и нативный помощник побайтово совпадают со стабильной 0.2.0. В игре номер версии может оставаться 0.2.0. Функции 0.3.0 RC в этот выпуск не включены.

## Verification scope

- Base: exact published `ZoneFPV-0.2.0.zip`, SHA-256 `499298b348a63998472dc0e82baf2142b1e27e55a9d52c9b366e5808084cfc6a`.
- All files under `mod/`, all native source files under `src/`, `Install-Mod.ps1` and `Uninstall.ps1` are unchanged.
- Windows PowerShell 5.1 regression checks cover unavailable Steam libraries, discovery of a subsequent valid library, missing-only lists, explicit game paths and automatic preflight.
- Existing stable installer fixtures cover repeat installation, preserved preferences, other mods/runtime preservation and exact rollback after copy, hash or retirement failures. Uninstall is checked in an isolated fixture.
- Installer tests use synthetic game folders only. This release does not claim new live-game or performance testing; previous 0.2.0 game checks remain the baseline because runtime bytes are unchanged.
- Final archive CRC, complete SHA-256 manifest and runtime equivalence are recorded in the separate `ZoneFPV-0.2.1-verification.json` release asset.

The existing 0.2.0 limitations remain: CNPP black regional anomaly effect, geometry/collision limitations and pending physical DS4 testing. No RC2 gameplay features are added.
