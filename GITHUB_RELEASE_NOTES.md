# ZoneFPV 0.3.0 RC2

RC2 adds optional battery simulation and includes the scanner, PDA, camera and combat fixes developed after the published RC1.

## Added since RC1

- **LiPo battery simulation:** enable it in **Flight → Main** in the PDA or F6 menu; select **300–20000 mAh** and **2–8S**. Default: 1500 mAh, 6S.
- Consumption follows thrust and manoeuvres. Pack mass, a nonlinear discharge curve, internal resistance, voltage sag/recovery and heating/cooling affect available thrust. This approximates a five-inch quad rather than a specific motor/propeller/battery combination.
- **Movable battery OSD indicator:** remaining charge, voltage, current, used mAh and LOW/LAND warnings. Existing OSD positions are retained.
- A new flight receives a full battery; returning to launch preserves charge. Menus and focus pauses do not drain it. Depletion cuts motor thrust, followed by a short fall and return to the player. Battery simulation can be disabled.

## Corrected since RC1

- **NPC discovery:** recover existing NPCs reactivated from the game's pool without a new creation notification; retain bounded retries for loading models without duplicate pending entries.
- **Scanner tracking:** render brackets in the game UI using the current game frame, removing the independent desktop-overlay delay during camera turns. Small skeletal-pose jitter is filtered without smoothing camera or actor movement.
- **Scanner appearance:** compact DPI-aware brackets and corrected colours; restore native faction icons with distance labels in the game-rendered scanner.
- **Thermal coverage:** handle modular NPC components, including separate head parts, with identity/ownership checks when applying and restoring materials. The scanner does not change NPC visibility or AI.
- **PDA compatibility:** restore the ZoneFPV tab for the runtime's supported class-path formats; keep it out of technician upgrade screens and reject replaced/stale native panels.
- **Field-instrument styling:** native PDA backing, subdued amber selection, cream labels and native fonts; keep the existing menu organisation and functions.
- **Player mouse capture:** stop restoring stale cursor state after FPV, PDA use and Alt+Tab, which could restrict mouse turning to the screen edges.
- **Kamikaze feedback:** prevent the drone's own blast from starting player concussion/dirt sources; retain protection when immediately reentering FPV. NPC damage, impulse, sound and blast visuals remain; ordinary game grenades are unchanged.
- **Aggression reset:** account for confirmed attacks on the drone even when an NPC has no current focused enemy between bursts. Hostility/targets present before flight are preserved.
- **Performance work:** avoid recurring global controller searches, reuse resource-check file handles, remove blocking retries for unavailable effects and reuse collision clearance within the same frame. Precise obstacle checks remain. These changes do not establish a universal FPS gain or eliminate every crash.

## Retained from RC1

Kamikaze, grenade-drop and combined combat modes; selectable vision/thermal palettes; lower camera and flashlight; artifact collection; world scanning; keyboard/mouse/controller/CH capture with Toggle/Hold; controller calibration; **the F6 settings menu duplicated inside PDA → ZoneFPV**. These are existing RC1 features, not new RC2 additions.

## Install / update

1. Install UE4SS compatible with your exact S.T.A.L.K.E.R. 2 PC version separately.
2. Close the game. Extract the complete **ZoneFPV-0.3.0-RC2.zip** archive and run **Setup.cmd**. Update Lua, EXE, DLL and PAK together, then restart the game.
3. Open **PDA → ZoneFPV** or **F6**. Select/calibrate your USB Joystick transmitter or gamepad in **Settings → Controller**.
4. Defaults: **F6 settings, F8 enter/leave FPV, F9 return to launch**. Lower throttle in Acro/Angle or centre it in 3D before entering FPV. Close the menu/PDA to fly.

Updates preserve preferences, calibration and the OSD layout and back up the previous mod. Download the attached installer ZIP; GitHub's automatic Source code archive is for development. No compiler or Python is required by players. UE4SS and other mods are not replaced. Vortex installation is untested.

RC2 remains a release candidate. Automated tests cannot validate every game scene, NPC appearance or other-mod combination. Loading distance can increase RAM/streaming cost and cannot create missing collision; Alternative FPV retains reduced remote simulation. NIR/SWIR and battery behaviour are approximations. Older releases, including the author-tested stable 0.2.0, remain available.

[Full feature list and source](https://github.com/mrwinka/ZoneFPV) · [Installation / troubleshooting](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md) · [Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799)

## Русский

**Новое в RC2:** отключаемая эмуляция LiPo 300–20000 mAh, 2–8S с расходом от нагрузки, влиянием массы/напряжения на тягу, просадкой и восстановлением напряжения; показатель батареи в OSD и предупреждения LOW/LAND. Меню — **«Полёт → Основное»**. Новый полёт заряжает батарею, F9 сохраняет остаток.

**Исправления после опубликованной RC1:** повторное обнаружение активированных NPC; отрисовка рамок в текущем кадре игры и компактный вид сканера со значками фракций; покрытие модульных NPC тепловизором; появление вкладки ZoneFPV в обычном КПК и защита экрана техника; оформление «Полевой прибор»; захват мыши после FPV/КПК/Alt+Tab; налёт и контузия от собственного камикадзе, в том числе при немедленном повторном входе; сброс только вызванной дроном агрессии; сокращение лишних поисков, операций с файлами и повторных проверок столкновений.

**Сохранены возможности RC1:** вооружение, видение, сбор артефактов, нижняя камера, фонарик, свободные назначения кнопок/CH и **дублирование меню F6 в КПК**. При обновлении закрыть игру, распаковать весь архив и запустить **Setup.cmd**; настройки и калибровка сохраняются. Модель батареи приблизительная, гарантированный прирост FPS и устранение всех вылетов не заявляются.
