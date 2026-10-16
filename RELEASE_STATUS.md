# ZoneFPV 0.3.0 RC2 — publication status

Status on 2026-10-16: **the corrected RC2 installer is published on GitHub and Nexus. GitHub downloads are verified. Nexus has quarantined the new file and does not currently allow its download.**

## Installer-only refresh

Setup now skips unavailable Steam libraries, including disconnected drives, and continues searching for the game. Manual folder selection and explicit `-GameRoot` remain available. See [installer instructions](INSTALLER_UPDATE.md). The version remains **0.3.0 RC2**; all **114 runtime files and the armament PAK are byte-identical** to the previous RC2. This refresh adds no gameplay features.

## GitHub

The existing [RC2 release](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.3.0-rc2), release ID **415267341**, remains the download destination. Its three refreshed attachments were downloaded again and matched:

| Attachment | Asset ID | SHA-256 |
| --- | --- | --- |
| `ZoneFPV-0.3.0-RC2.zip` | 648329625 | `45CC7827C917A14DAF0446BFA0851E9F74BA8B1B211D55DD1945E6EF3B2BA2B4` |
| `ZoneFPV-0.3.0-RC2-verification.json` | 648329770 | `3D065716F3A301642A2A11B87EFF85FDD821D3226A11A67BDE8AF0F0819B804E` |
| `SHA256SUMS.txt` | 648329806 | `B48BD2CEFF79E8734C8850FCF40990C07DCB0DB4C20D7015916192D81983A181` |

The ZIP contains **132 files**, **1,136,193 bytes**. Installer source and its regression test are published in [commit `4354613`](https://github.com/mrwinka/ZoneFPV/commit/435461369da80b5c4a5beeae295fe2cd5ab60dd8), tree `5b9268aa81d5bf31e8827c311d98bcc04f7d798d`. All **292 source files** and the exact five-file update were verified. The release body links that commit and the installer note. Tag `v0.3.0-rc2` retains the original game-code baseline `942cd0dbc579dd2325d87dbdcbdf3f0d09349f0d`; download the attached installer ZIP rather than GitHub's automatic source archive to obtain the corrected Setup.

## Nexus

On [ZoneFPV at Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799), file **20688 — ZoneFPV 0.3.0 RC2 - installer fix** is in **Main Files / Primary**. The public file description was saved and read back, and its public VirusTotal link identifies the matching archive SHA-256. Initial RC2 file **20686** and RC1 file **20277** are retained in Old Files; stable **0.2.0 / 20042** remains in Main Files.

**File 20688 is quarantined by Nexus automated safety checks, not merely awaiting a routine scan. It cannot currently be downloaded there.** Use the verified [GitHub release](https://github.com/mrwinka/ZoneFPV/releases/tag/v0.3.0-rc2) while that external restriction remains. No completed Nexus review or Nexus re-download is claimed.

The two new installer-fix changelog lines (EN/RU) were published and read back publicly. Nexus renders **26 entries / 14 unique entries**: its Add changelog action appended to the same version and duplicated the older 12 entries. Three cleanup attempts through Edit changelog failed with HTTP 403; those duplicate historical entries remain. The existing full RC2 feature description remains valid. An attempt to append installer information to the main description also returned HTTP 403, so that appended main-description note is **not claimed as published**.

## Validation limits

The setup regression and full install/update/rollback, uninstall and runtime-settings fixture suites passed under **Windows PowerShell 5.1.26100.9444**. Earlier **74 Lua suites / 155 Lua syntax files** and native/helper/PAK proofs are reused because runtime bytes did not change; those suites were not rerun for this installer refresh. Preferences, calibration and OSD/battery settings remain preserved. No new gameplay verification or measured FPS improvement is claimed.

## Русский

Исправленный установщик RC2 опубликован на обоих сайтах. На GitHub все три вложения повторно скачаны и сверены. На Nexus новый файл **20688** находится в **Main Files / Primary**, но сайт поместил его в **карантин автоматической проверки**, поэтому скачать его там пока нельзя. Рабочее зеркало — GitHub. Изменён только поиск папки игры; сам мод, бинарники, PAK и настройки не менялись. Примечание в главное описание Nexus добавить не удалось из-за HTTP 403; основное описание функций RC2 сохраняется.
