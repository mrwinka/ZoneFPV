# ZoneFPV 0.3.0 RC2 — release status

Status on 2026-10-16: **prepared for publication; not yet confirmed published**. The publisher must update this file after verifying the GitHub release and Nexus file independently.

## Scope

RC2 packages optional LiPo battery simulation and the scanner/PDA/thermal/camera/combat/performance corrections since the public RC1 of 2026-10-08. See [release notes](RELEASE_NOTES.md). The complete Lua/EXE/DLL/PAK set must be updated together. Current settings, calibration and old OSD positions are preserved.

## Evidence and limits

- The RC2 rerun passed **74 Lua suites** and syntax checks for **155 Lua files**. The unchanged matching helper/native binaries and armament PAK carry the latest successful build/tests. The final RC2 manifest also records archive hashes and installer checks; it is the authority for the published artifact.
- The author reported that the current build generally worked and authorised publication as RC2. This is a general gameplay smoke check, not a complete matrix for every NPC/model, loadout, controller, game scene or third-party mod.
- No measured universal FPS/RAM improvement, elimination of all crashes or exhaustive live-game verification is claimed. Battery and infrared modes are approximations; loading/collision/Alternative FPV/regional-effect limits remain documented.
- The new battery item migrates older OSD layouts without moving existing items. New flights start with full batteries; return-to-launch preserves charge.

## Publication targets

- GitHub repository: https://github.com/mrwinka/ZoneFPV
- Intended tag: `v0.3.0-rc2`
- Intended installer: `ZoneFPV-0.3.0-RC2.zip`, with verification JSON and `SHA256SUMS.txt`.
- Nexus page: https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799
- Nexus category: **Main Files**, selected as **Primary**, while preserving older versions. File availability/quarantine must be read from the site after upload; upload alone does not prove download availability.

## Русский

На 16 октября 2026 RC2 подготовлена к публикации; факт размещения ещё не подтверждён. Автор выполнил общую пробную проверку и разрешил выпуск, но это не исчерпывающая проверка всех функций и сочетаний. Точные проверки и хеши — в финальном манифесте RC2. После загрузки отдельно подтвердить GitHub и Nexus, включая категорию Main/Primary и фактическую доступность файла на Nexus. Старые версии сохраняются.

