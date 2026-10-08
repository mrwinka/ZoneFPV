# ZoneFPV — FPV Drone Camera

ZoneFPV adds a transmitter/gamepad-controlled FPV drone camera to S.T.A.L.K.E.R. 2. Fly in Acro, self-leveling Angle or reversible-thrust 3D, with configurable speed, rates, expo and camera tilt.

**0.3.0 RC1 is the current recommended release candidate.** Older releases, including author-tested 0.2.0, remain available.

## What was added in 0.3.0 RC1

- **Settings inside the PDA.** The F6 settings menu is duplicated in PDA → ZoneFPV. Controller setup, calibration and button assignments open inside the PDA. Both menus use the same saved preferences.
- **Kamikaze drone.** Detonate on impact above a configurable minimum impact speed. Adjust explosion power and set the threshold high enough to allow gentle landings.
- **Grenade-drop drone.** Drop activated RGD-5 or F-1 grenades with an assigned button. Choose 1–20 grenades or unlimited ammunition; remaining charges are shown during flight.
- **Combined combat mode.** Carry and drop grenades while retaining kamikaze impact detonation on the same drone. Combat settings are shown only when relevant to the selected drone type.
- **Vision effects.** Select night/infrared-style modes such as Starlight IR, NIR, SWIR and IR LED, or thermal palettes such as White Hot, Black Hot, Rainbow and Ironbow. Toggle the chosen mode with an assigned button. Analog camera effects have their own switch.
- **Lower camera.** Switch to a camera mounted under the drone to see directly below it. It rotates with the drone and can stay active only while an assigned button or CH is held.
- **Drone flashlight.** Enable it in settings and switch it on or off with an assigned button.
- **Artifact collection.** Pick up a nearby artifact from the drone with an assigned button. Collection distance is adjustable from 0.5 to 10 m. Holding the button retries collection as you approach an artifact.
- **World scanner.** Display frames and distance markers for loaded NPCs, mutants and anomalies in the FPV view. Scanner visibility is configurable.
- **Button assignments.** Capture the keyboard key, mouse button, controller button or CH you actually press. All assigned actions support Toggle or Hold; holding grenade release repeats drops at intervals.
- **Controller setup.** Select a transmitter/gamepad, apply a profile and calibrate four flight axes. USB controllers can be connected while the game is running.
- **Signal simulation.** Configure radio interference and signal loss caused by distance, obstacles and anomalies.

## Corrections and verification

Settings use vertically scrolling lists and five groups: Flight, Image, Equipment, World and signal, and Settings. Input/focus restoration and cleanup of player camera effects were revised. The latest scanner changes continue waiting for NPCs that load late; visibility restoration now checks that equipment still belongs to the same actor.

66 Lua suites passed, 139 Lua files passed syntax checks, and installed runtime files were hash-verified. The existing helper and native binaries are reused; this publication does not add a new binary build. **gameplay_verified=false: NPC disappearance and scanner recovery in a live game have not yet been confirmed.** Unloaded geometry/collision, reduced remote simulation in Alternative FPV and the known CNPP regional camera effect remain limitations. NIR/SWIR are visual approximations, not spectral simulations.

## Requirements and installation

Windows 10/11 x64, S.T.A.L.K.E.R. 2 PC and a compatible UE4SS runtime installed separately. A USB transmitter/gamepad must be available through DirectInput, XInput or WinMM. Physical DualShock 4 testing remains pending.

1. Install UE4SS compatible with your exact S.T.A.L.K.E.R. 2 PC update separately.
2. Close the game, extract the complete **ZoneFPV-0.3.0-RC1.zip** archive into a writable folder and run **Setup.cmd**. Select the game folder if needed.
3. Connect a transmitter in USB Joystick mode or a gamepad, start the game and load a save.
4. Open **PDA → ZoneFPV** or press **F6**; select/calibrate the device in **Settings → Controller** and check stick directions.
5. Lower throttle in Acro/Angle or center it in 3D before entering FPV. Defaults: **F6 settings, F8 enter/leave FPV, F9 return to launch**; all can be reassigned. Close settings/PDA to fly.

Updates preserve preferences, calibration and the OSD layout, and create a backup of the previous mod. Download the attached installer ZIP rather than GitHub's automatic Source code archive. ZoneFPV does not bundle or replace UE4SS or other mods. End users do not need a compiler or Python. Vortex installation is not tested.

Main FPV moves the simulation anchor with the drone; Alternative FPV keeps it at launch and has reduced remote NPC/collision coverage. World controls include sphere collision checks, time/weather, world freeze and geometry loading distance. Increasing loading distance can increase RAM use and cannot guarantee collision across the entire map.

The optional manual gc.MaxObjectsInGame override is in **Settings → General**. Saving it to Engine.ini affects the whole game after a restart. This changes object capacity, not FPS; higher limits can increase RAM use, loading times and garbage-collection pauses. Game default removes only this override. Borderless/windowed play is recommended for the native overlay.

Five interface languages and synthesized drone audio are included. Achievement compatibility is retained. ZoneFPV code is MIT; the included Betaflight OSD font is separately GPL-3.0-or-later with source/license in mod/fonts. UE4SS, compatibility patches and proprietary game assets are not bundled.

[Installation (EN/RU)](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md) · [Source](https://github.com/mrwinka/ZoneFPV) · [Nexus Mods](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) · [Dependencies](https://github.com/mrwinka/ZoneFPV/blob/main/DEPENDENCIES.md)

## Русский

ZoneFPV добавляет управляемую пультом/геймпадом FPV-камеру дрона в S.T.A.L.K.E.R. 2. Режимы полёта: Acro, самовыравнивание Angle и двунаправленная тяга 3D. Настраиваются скорость, rates, expo и наклон камеры.

**0.3.0 RC1 — текущий рекомендуемый кандидат в релиз.** Старые выпуски, включая проверенную автором 0.2.0, сохранены.

### Что добавилось в 0.3.0 RC1

- **Меню в КПК.** Меню настроек F6 продублировано в КПК → ZoneFPV. Настройка пульта, калибровка и назначение кнопок открываются прямо внутри КПК. Оба меню используют общие сохранённые параметры.
- **Дрон-камикадзе.** Взрывается при столкновении, если скорость удара превышает заданный порог. Можно настроить мощность взрыва и минимальную скорость удара, чтобы оставить возможность мягкой посадки.
- **Дрон со сбросом гранат.** Сбрасывает активированные RGD-5 или F-1 по назначенной кнопке. Боезапас — от 1 до 20 гранат либо неограниченный. Остаток зарядов отображается во время полёта.
- **Совмещённый боевой режим.** Один дрон может сбрасывать гранаты и одновременно работать как камикадзе. В меню показываются только параметры, подходящие выбранному типу дрона.
- **Эффекты видения.** Добавлены ночные/инфракрасные режимы Starlight IR, NIR, SWIR и IR LED, а также тепловизионные палитры, включая White Hot, Black Hot, Rainbow и Ironbow. Выбранное видение включается назначенной кнопкой. Эффект аналоговой камеры переключается отдельно.
- **Нижняя камера.** Позволяет смотреть прямо под дроном и вращается вместе с его корпусом. Можно включать переключением или держать активной только пока зажата кнопка/CH.
- **Фонарик дрона.** После включения возможности в настройках переключается назначенной кнопкой.
- **Сбор артефактов.** Дрон подбирает ближайший артефакт по назначенной кнопке. Дистанция сбора регулируется от 0,5 до 10 м. При удержании кнопки сбор повторяется по мере приближения к артефакту.
- **Сканирование мира.** В FPV отображаются рамки и расстояния до загруженных NPC, мутантов и аномалий. Отображение сканера настраивается.
- **Назначение кнопок.** Закрепляется та клавиша, кнопка мыши, кнопка пульта/геймпада или CH, которую вы нажали. Для всех назначений доступны «Переключение» и «Пока зажата»; при удержании кнопки сброса гранаты сбрасываются с интервалом.
- **Настройка пульта.** Выбор устройства, профили и калибровка четырёх осей управления. USB-пульт можно подключать во время работы игры.
- **Симуляция связи.** Настраиваются помехи и потеря сигнала из-за расстояния, препятствий и аномалий.

### Исправления и проверка

Списки настроек прокручиваются вверх/вниз. Разделы: «Полёт», «Изображение», «Оснащение», «Мир и связь», «Настройки». Переработаны возврат управления/фокуса и очистка эффектов камеры игрока. Сканер продолжает ждать позднюю загрузку NPC; перед восстановлением видимости проверяется, что снаряжение всё ещё принадлежит тому же персонажу.

Прошли 66 Lua-наборов, проверка синтаксиса 139 файлов и сверка установленных файлов по хешам. Используются прежние вспомогательные и нативные бинарные файлы; новой бинарной сборки в этой публикации нет. **gameplay_verified=false: исчезновение NPC и восстановление сканера в живой игре ещё не подтверждены.** Остаются ограничения подгрузки геометрии/коллизий, удалённой симуляции в альтернативном FPV и региональный эффект у ЧАЭС. NIR/SWIR имитируют изображение, а не спектральную съёмку.

### Требования и установка

Windows 10/11 x64, S.T.A.L.K.E.R. 2 PC и отдельно установленный совместимый UE4SS. Пульт/геймпад должен определяться через DirectInput, XInput или WinMM. Проверка настоящего DualShock 4 ещё не выполнена.

1. Отдельно установить UE4SS, совместимый с вашей версией S.T.A.L.K.E.R. 2.
2. Закрыть игру, полностью распаковать **ZoneFPV-0.3.0-RC1.zip** в доступную для записи папку и запустить **Setup.cmd**. При необходимости выбрать папку игры.
3. Подключить пульт в USB-режиме Joystick или геймпад, запустить игру и загрузить сохранение.
4. Открыть **КПК → ZoneFPV** или нажать **F6** → **«Настройки → Пульт»**, выбрать устройство, проверить направления и выполнить калибровку.
5. В Acro/Angle опустить газ, в 3D держать по центру. По умолчанию: **F6 — настройки, F8 — вход/выход из FPV, F9 — возврат к старту**; кнопки переназначаются. Закрыть меню/КПК для полёта.

При обновлении настройки, калибровка и расположение OSD сохраняются, создаётся резервная копия предыдущего мода. На GitHub скачивать приложенный установочный ZIP, а не автоматический архив Source code. UE4SS и другие моды не включены и не заменяются. Компилятор и Python пользователю не нужны. Установка через Vortex не проверена.

Основной FPV переносит центр симуляции вслед за дроном; альтернативный оставляет его на старте и ограничивает удалённую симуляцию NPC/коллизий. Сохраняются объёмные проверки столкновений, настройка времени/погоды, заморозка мира и расстояние подгрузки геометрии. Повышение подгрузки увеличивает нагрузку и не гарантирует коллизии по всей карте.

Ручной лимит gc.MaxObjectsInGame находится в «Настройки → Общие». Сохранение в Engine.ini требует перезапуска и действует на всю игру. Это ёмкость объектов, не настройка FPS. Повышение лимита может увеличить RAM, загрузку и паузы сборки мусора. «По умолчанию игры» удаляет только этот параметр. Для внешнего интерфейса рекомендуется оконный режим без рамки.

Доступны пять языков интерфейса и синтезированный звук дрона. Совместимость с достижениями сохранена. Код — MIT; шрифт Betaflight — отдельно GPL-3.0-or-later с исходником/лицензией в mod/fonts. UE4SS, сторонние патчи и игровые ассеты не поставляются.
