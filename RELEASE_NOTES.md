# ZoneFPV 0.3.0 RC1

Current release candidate based on 0.2.0. This release includes the accumulated 0.3.0 work and the latest offline scanner/visibility corrections. Full gameplay verification remains pending.

## Changes since 0.2.0

- Integrated ZoneFPV settings into the native PDA, including controller selection/calibration, press-to-bind keyboard/mouse/controller/CH assignments, General settings and OSD editing. External F6 remains available; both menus share preferences.
- Reorganized settings into Flight, Image, Equipment, World and signal, and Settings. Long lists scroll vertically. Relevant combat options appear for the selected drone type.
- Added an OSD preview with mouse selection/dragging, a vertical list of all 14 indicators, drone HP, artifact detector and remaining grenade charges. Normal and lower-camera crosshairs can be enabled and styled separately.
- Added a body-mounted lower camera, assignable flashlight, selectable night/infrared/thermal vision and analog camera effects. Every assigned action offers Toggle/Hold; held grenade release repeats at intervals and artifact collection retries on approach.
- Added kamikaze, grenade-drop and combined drones. Configure impact power/speed, RGD-5/F-1 grenades and 1–20 or unlimited charges. Grenades are prepared before release; the impact threshold allows gentle landing.
- Added artifact collection with configurable reach, simulated signal loss and world/anomaly scanning. Scanner projection follows the current FPV camera each frame, with complete alternating packets and stale/invalid-target rejection.
- Improved controller hotplug handling, input/focus restoration, effect cleanup and bounded runtime work. Achievement compatibility is retained.

## Latest corrections

- Retain bounded retries for living NPCs whose mesh, world or root becomes ready after the initial discovery window.
- Validate identity and ownership through the entire equipment attachment chain before changing/restoring visibility. Stop writing to descendants when an ancestor changes owner or identity.
- Retain the original player movement-component tick state and read-only NPC residency diagnostics introduced in v57.

## Verification and remaining limits

All 66 Lua suites passed; 139 Lua source/test files passed syntax checks. Installed runtime files were hash-verified. The existing v55 input/overlay helper and v51 native DLL are reused without a new binary build.

**`gameplay_verified=false`: the latest corrections were reviewed and tested offline. NPC disappearance and scanner recovery in a live game are not claimed fixed or fully verified.** No measured FPS improvement is claimed. Unloaded collision/remote simulation and the known CNPP regional effect remain limitations.

Close the game, extract the complete attached ZIP and run **Setup.cmd**. Compatible UE4SS is required separately. Updates preserve preferences and create a backup. F6 opens settings, F8 toggles FPV and F9 returns to launch by default; these keys can be reassigned. On GitHub, download the attached installer ZIP, not the automatic Source code archive.

[Installation (EN/RU)](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md) · [Source](https://github.com/mrwinka/ZoneFPV) · [Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799)

## Русский

Текущий кандидат в релиз на основе 0.2.0. Включает накопленные изменения 0.3.0 и последние офлайн-исправления сканера и проверки видимости.

- Все настройки встроены в КПК: пульт и калибровка, назначение произвольных кнопок/CH, общие настройки и редактор OSD. F6 остаётся доступным; настройки общие.
- Пять понятных групп, вертикальная прокрутка и параметры боевого режима по выбранному типу дрона.
- OSD с выбором и перетаскиванием мышью, списком всех 14 показателей, HP, детектором и боезапасом. Прицелы обычной и нижней камеры настраиваются отдельно.
- Нижняя камера вращается вместе с дроном; добавлены фонарик, ночное/инфракрасное/тепловизионное видение и эффекты аналога. Все назначения поддерживают переключение/удержание, включая интервальный сброс и сбор по мере приближения.
- Камикадзе, сброс гранат и совмещённый режим; мощность/порог удара, RGD-5/F-1 и 1–20 либо неограниченное количество зарядов. Добавлены сбор артефактов с регулируемой дистанцией, симуляция сигнала и сканирование мира.
- Рамки сканера рассчитываются по текущей камере; устаревшие/некорректные цели и неполные пакеты отбрасываются. Улучшены подключение пульта, возврат управления/фокуса и очистка эффектов. Совместимость с достижениями сохранена.

В этом выпуске сканер продолжает ограниченно ждать позднюю загрузку NPC. Проверка видимости учитывает владельца и личность каждого звена снаряжения; после передачи родителя NPC записи в дочерние объекты прекращаются. Исходное обновление компонента движения игрока и диагностика v57 сохранены.

Все 66 Lua-наборов и проверка синтаксиса 139 файлов прошли; установленная сборка сверена по хешам. **`gameplay_verified=false`: исчезновение моделей NPC и восстановление сканера в самой игре ещё не подтверждены.** Численный прирост FPS не заявляется.

Обновлять при закрытой игре: распаковать полный приложенный ZIP → **Setup.cmd**. UE4SS устанавливается отдельно. Настройки сохраняются, создаётся резервная копия.
