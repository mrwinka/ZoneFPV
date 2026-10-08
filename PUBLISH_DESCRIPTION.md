# ZoneFPV — FPV Drone Camera

ZoneFPV adds a transmitter/gamepad-controlled FPV camera to S.T.A.L.K.E.R. 2, with a quadcopter flight model, configurable OSD and camera effects.

**0.3.0 RC1 is the current recommended release candidate. Older releases, including author-tested 0.2.0, remain available.** The latest NPC/scanner corrections were tested offline; full gameplay validation remains pending (`gameplay_verified=false`).

## Features

- Acro, self-leveling Angle and reversible-thrust 3D flight, with speed, rates, expo and camera tilt controls.
- DirectInput, XInput and WinMM device selection, initial profiles and guided four-axis calibration. Physical DualShock 4 testing remains pending.
- Native PDA settings and an independent external F6 menu, sharing preferences. Five groups: Flight, Image, Equipment, World and signal, Settings. Lists scroll vertically.
- Press-to-bind keyboard, mouse, controller button and CH assignments in Settings → Buttons. Every action supports Toggle/Hold; held grenade release repeats at intervals and collection retries on approach.
- Draggable OSD preview, a vertical list of all 14 indicators, drone HP, artifact detector and remaining grenade stock. Normal/lower-camera crosshairs have independent visibility and six styles.
- Selectable night/infrared/thermal vision, analog camera effects, assignable flashlight and a lower camera that rotates with the drone. NIR/SWIR are visible-light approximations, not spectral simulations.
- Kamikaze, grenade-drop and combined drones; configurable impact power/speed, RGD-5/F-1 grenades and 1–20 or unlimited charges. Gentle landing can remain below the impact threshold.
- NPC/mutant/anomaly scanning, artifact detection/collection with configurable reach, and simulated distance/obstacle/anomaly radio interference and signal loss.
- Main FPV moves the simulation anchor with the drone. Alternative FPV keeps it at launch, with reduced remote NPC/collision coverage. Sphere collision checks, time/weather controls, world freeze and geometry loading controls remain available.
- Five interface languages, synthesized drone audio, scoped player-effect cleanup and state restoration. Achievement compatibility is retained.

## Latest corrections and verification

Scanner brackets project through the current FPV camera on each camera frame. Complete alternating packets and freshness checks reject partial/old output. Visible targets receive the output budget; offscreen targets no longer consume all marker slots.

This release retains bounded retries for living NPCs whose model/world/root loads late. Equipment visibility changes and restoration require unchanged identity and ownership throughout every attachment ancestor; transferred descendants stop receiving writes. The original player movement-component tick state and read-only residency diagnostics from v57 remain.

66 Lua suites and syntax checks for 139 Lua files passed; installed runtime files were hash-verified. Existing v55 helper/v51 native binaries are reused without a new binary build. **NPC disappearance and scanner recovery in a live game are not claimed fixed or fully verified.** No measured FPS increase is claimed.

## Installation and controls

1. Install UE4SS compatible with your exact game update separately. See [requirements](https://github.com/mrwinka/ZoneFPV/blob/main/DEPENDENCIES.md).
2. Close the game, extract the complete attached installer ZIP and run **Setup.cmd**.
3. Connect a transmitter in USB Joystick mode or a gamepad, launch the game and load a save.
4. Open PDA → ZoneFPV or press F6; select/calibrate the controller in **Settings → Controller** and verify stick directions.
5. Lower throttle in Acro/Angle or center it in 3D. Defaults: **F6 settings, F8 FPV, F9 return to launch**; all can be reassigned. Close settings/PDA to fly.

Updates preserve preferences, calibration and OSD, and back up the previous mod. On GitHub, choose the attached installer ZIP rather than the automatic Source code archive. UE4SS and other mods are not bundled/replaced. Vortex installation is not tested.

The optional manual `gc.MaxObjectsInGame` setting is in **Settings → General**. Saving it to Engine.ini affects the whole game after a restart. It changes object capacity, not FPS; higher limits can increase RAM use, loading time and garbage-collection pauses. Game default removes only this override.

Unloaded collision and geometry remain possible. Greater loading distances increase load and cannot guarantee the entire map. CNPP's black regional effect and quest-driven weather can remain. Borderless/windowed play is recommended for the native overlay.

[Source and build instructions](https://github.com/mrwinka/ZoneFPV) · [Installation (EN/RU)](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md) · [GitHub releases](https://github.com/mrwinka/ZoneFPV/releases) · [Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799)

ZoneFPV code is MIT. The included Betaflight OSD font is separately GPL-3.0-or-later with source/license in `mod/fonts`. UE4SS, compatibility patches and proprietary game assets are not bundled.

## Русский

ZoneFPV добавляет управляемую пультом/геймпадом FPV-камеру с моделью полёта квадрокоптера, настраиваемым OSD и эффектами видения.

**0.3.0 RC1 — текущий рекомендуемый кандидат в релиз. Старые выпуски, включая проверенную автором 0.2.0, сохранены.** Последние исправления NPC/сканера проверены вне игры; полное игровое подтверждение остаётся открытым (`gameplay_verified=false`).

- Acro, самовыравнивание Angle и двунаправленная тяга 3D; скорость, rates, expo и наклон камеры.
- Выбор DirectInput/XInput/WinMM, профили и мастер калибровки четырёх осей. Проверка настоящего DS4 ещё не выполнена.
- Все настройки внутри КПК и независимое меню F6 с общими настройками. Пять групп: «Полёт», «Изображение», «Оснащение», «Мир и связь», «Настройки». Длинные списки прокручиваются вертикально.
- Произвольные кнопки клавиатуры, мыши, пульта и CH в «Настройки → Кнопки». Переключение/удержание доступны для всех действий; сброс повторяется с интервалом, сбор — по мере приближения.
- OSD с перетаскиванием мышью и списком всех 14 показателей, HP, детектором и боезапасом. Прицелы обычной/нижней камеры включаются и оформляются отдельно.
- Ночное/инфракрасное/тепловизионное видение, аналоговые эффекты, фонарик и нижняя камера, вращающаяся вместе с дроном. NIR/SWIR — имитация на основе видимого изображения.
- Камикадзе, сброс гранат и совмещённый режим; мощность/скорость удара, RGD-5/F-1 и 1–20 либо неограниченное количество зарядов. Порог удара позволяет мягко приземлиться.
- Сканирование NPC/мутантов/аномалий, обнаружение и сбор артефактов с регулируемой дистанцией, симуляция помех/потери сигнала.
- Основной FPV переносит центр симуляции вслед за дроном; альтернативный оставляет его на старте. Сохраняются столкновения объёмом, управление временем/погодой, заморозка мира и настройки подгрузки.
- Пять языков, звук дрона, очистка поддерживаемых эффектов и возврат состояния игрока. Совместимость с достижениями сохранена.

Рамки сканера используют текущую камеру и отбрасывают неполные/устаревшие пакеты. В этом выпуске сохраняется ограниченное ожидание поздней готовности NPC, а проверка видимости учитывает личность/владельца всей цепочки снаряжения. После передачи родителя NPC записи в дочерние объекты прекращаются. Исходное обновление компонента движения игрока и диагностика v57 сохранены.

Все 66 Lua-наборов и синтаксис 139 файлов прошли; установка сверена по хешам. **Исчезновение моделей NPC и восстановление сканера в живой игре ещё не подтверждены.** Численный прирост FPS не заявляется.

Установить совместимый UE4SS отдельно. При закрытой игре распаковать полный приложенный ZIP → **Setup.cmd**. После загрузки сохранения: КПК → ZoneFPV или F6 → «Настройки → Пульт», выбрать устройство и проверить направления/калибровку. В Acro/Angle опустить газ, в 3D держать по центру. F6 — настройки, F8 — FPV, F9 — возврат к старту; кнопки переназначаются. Закрыть меню/КПК для полёта. Настройки сохраняются, предыдущий мод резервируется.

Лимит `gc.MaxObjectsInGame` находится в «Настройки → Общие»: сохранение в Engine.ini требует перезапуска и действует на всю игру. Это ёмкость объектов, не настройка FPS. Повышение лимита/подгрузки может увеличить RAM и паузы; отсутствующие коллизии не гарантируются. Чёрный эффект у ЧАЭС и квестовая погода могут оставаться.

Код — MIT; шрифт Betaflight — отдельно GPL-3.0-or-later. UE4SS, сторонние патчи и игровые ассеты не поставляются. Для внешнего OSD рекомендуется окно без рамки; установка через Vortex не проверена.
