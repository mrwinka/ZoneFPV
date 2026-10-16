# ZoneFPV 0.3.0 RC2 — release status

Status on 2026-10-16: **published on GitHub and Nexus. GitHub downloads are hash-verified; Nexus RC2 is awaiting the site's antivirus scan and is not yet downloadable.**

## GitHub — complete

- [ZoneFPV 0.3.0 RC2](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.3.0-rc2), tag `v0.3.0-rc2`, release ID `415267341`, marked **Latest**. GitHub fields are `draft=false`, `prerelease=false`, matching the previous release's placement; the title/documentation still identify RC2 as a release candidate.
- Runtime/source commit: [`942cd0dbc579dd2325d87dbdcbdf3f0d09349f0d`](https://github.com/mrwinka/ZoneFPV/commit/942cd0dbc579dd2325d87dbdcbdf3f0d09349f0d); tree `3c4c3b3b74dbee7881a388f72b850a1d3d198680`. The published source tree matched all **290 files**, with **103 changed files** verified and no mismatches.
- README EN/RU, full feature descriptions, installation, quick start, changelog and release notes were updated for RC2. Post-publication status documents are recorded separately and do not change the tagged runtime or installer.
- All three release attachments were downloaded again and matched their expected SHA-256 values:

| Attachment | SHA-256 |
| --- | --- |
| `ZoneFPV-0.3.0-RC2.zip` | `B5D977DC3EAD23E43CC9B732468D6696E31F8E09362CDE23245BE463BF72F89C` |
| `ZoneFPV-0.3.0-RC2-verification.json` | `9C84102ADE7F4AE3E4C1269C6E7B0A285BE4CF1BC62AE252405A23E20158D15F` |
| `SHA256SUMS.txt` | `26A8513117C996C0465CF20ADC74BFC62DD5B6773BC02524A7BB3D11969927C6` |

## Nexus — published, antivirus pending

[ZoneFPV on Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) now shows version **0.3.0-RC2**. The new **ZoneFPV 0.3.0 RC2** file is **20686**, placed in **Main Files** and selected **Primary**. The preceding RC1 file **20277** is preserved under **Old Files**.

The public English/Russian main description and synopsis were read back after saving: RC2 version, battery range, PDA settings, RC2 changes and GitHub mirror are present. The public **0.3.0-RC2 changelog** was opened and its **12 EN/RU entries** were checked against the prepared changes. The corrected English file description was also read back from public Files. The earlier editor-loading failure no longer blocks publication.

The new file reports **Virus scanning in progress** and is **not yet downloadable on Nexus**. Upload/category/primary/version are confirmed; completed antivirus review and a successful Nexus re-download/hash check are not claimed. Until Nexus finishes its checks, use the [verified GitHub RC2 download](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.3.0-rc2). The prepared ZIP itself has not been changed.

## Scope and verification

RC2 adds optional LiPo battery simulation and scanner/PDA/thermal/camera/combat/performance corrections since public RC1. See [release notes](RELEASE_NOTES.md). Update the complete Lua/EXE/DLL/PAK set and restart the game. Settings, calibration and previous OSD positions are preserved.

The RC2 rerun passed **74 Lua suites** and syntax checks for **155 Lua files**. Matching helper/native binaries and the armament PAK retain their successful build/tests; exact artifact and installer checks are in the attached verification manifest. The author reported a satisfactory general gameplay smoke check and authorised RC2 publication; this is not an exhaustive matrix of all functions, models, hardware, scenes or other mods. No universal FPS/RAM gain or elimination of all crashes is claimed. Battery/infrared approximations and streaming/collision/Alternative FPV/regional-effect limits remain documented.

## Русский

**RC2 опубликована на GitHub и Nexus.** На GitHub она отмечена Latest; исходники и описания обновлены, все три вложения повторно скачаны и сверены. На Nexus файл **20686** находится в **Main Files / Primary**, страница показывает **0.3.0-RC2**, основное описание EN/RU, synopsis, журнал RC2 из 12 пунктов EN/RU и исправленное описание файла сохранены и проверены на публичной странице. RC1 сохранена в Old Files. **Новый файл Nexus ещё проходит антивирусную проверку и пока не скачивается**; завершение проверки и сверка скачивания Nexus не заявляются. Для немедленной загрузки доступен проверенный установщик GitHub.

