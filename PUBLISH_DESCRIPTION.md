# ZoneFPV — FPV Drone Camera for S.T.A.L.K.E.R. 2

Fly a transmitter/gamepad-controlled FPV drone, explore the Zone, scan nearby targets, collect artifacts or equip a combat payload.

**Current version: 0.3.0 RC2 — release candidate.** Older releases, including the author-tested stable 0.2.0, remain available.

## Features

- **Flight:** Acro, self-leveling Angle and reversible-thrust 3D; adjustable speed, rates, expo and camera tilt, collision checks and drone audio.
- **Settings in the PDA and F6:** the F6 settings menu is duplicated in **PDA → ZoneFPV**. Flight, Image, Equipment, World and signal, and Settings use the same saved preferences. Controller selection, calibration and button assignments open directly inside the PDA. Lists scroll vertically.
- **Controllers and assignments:** DirectInput, XInput and WinMM devices, USB hot connection, profiles and guided four-axis calibration. Capture the keyboard key, mouse button, controller button or CH you actually press. Assignments support Toggle and Hold.
- **Combat drones:** unarmed, kamikaze, grenade-drop or **grenade drop + kamikaze**. Adjust impact speed and blast power; gentle contact need not detonate. Drop activated **RGD-5 or F-1** grenades with **1–20 or unlimited charges**. Held release repeats at intervals; ammunition is shown in flight. Only settings relevant to the selected loadout are shown.
- **Vision:** night/infrared-style options including Starlight IR, NIR, SWIR and IR LED, thermal palettes including White Hot, Black Hot, Rainbow and Ironbow, plus independent analog-camera effects. Toggle the selected vision with an assigned button; an unbound selected vision starts on FPV entry.
- **Lower camera and flashlight:** look directly below through a camera attached to the drone's body; Toggle/Hold support and an independently configurable downward crosshair. The horizon hides in downward view. Enable the flashlight feature in settings, then operate it with its binding.
- **Artifact collection:** collect the nearest artifact with an assigned action; choose a **0.5–10 m** range. Held collection retries as you approach.
- **Scanner:** configurable frames and distances for loaded NPCs, mutants and anomalies, with native faction icons for NPCs. Brackets render in the game's current frame; the scanner does not force NPC visibility or change their AI.
- **Battery simulation — new in RC2:** optional LiPo **300–20000 mAh, 2–8S**, default 1500 mAh/6S. Thrust-dependent consumption, pack mass, voltage sag/recovery and temperature influence flight. A movable OSD item shows charge, voltage, current, used mAh and LOW/LAND warnings. New flights start full; return-to-launch preserves charge; menus/focus pauses do not drain it. This is a physical approximation, not a calibrated replica of specific hardware.
- **OSD:** configurable telemetry placement, size, colour and crosshair styles. Select and drag preview elements inside the PDA; the external editor uses the same layout.
- **World and signal:** configurable distance/obstacle/anomaly interference, weather/time, world freeze and geometry loading distance. RU/UK/EN/PL/DE interface.

## RC2 changes from RC1

- Added battery simulation and its OSD telemetry.
- Improved discovery of reactivated/pool-reused NPCs; moved scanner brackets into game-frame UI, restored compact colours/sizing and faction icons, and improved modular thermal coverage.
- Restored PDA-tab compatibility, kept technician screens separate and applied the **field-instrument** look with native PDA backing/fonts and restrained amber accents.
- Corrected stale cursor restoration after FPV/PDA/Alt+Tab.
- Prevented the kamikaze drone's own blast from leaving player dirt/concussion feedback, including immediate reentry into FPV. Ordinary game grenades remain unchanged.
- Restored cleanup of aggression acquired from the drone while preserving hostility present before flight.
- Reduced repeated controller searches, resource-file operations, unavailable-effect loads and redundant same-frame collision checks. No guaranteed FPS gain or universal crash fix is claimed.

Combat, vision effects, artifact collection, button/CH capture and the duplicated PDA/F6 settings were already included in RC1 and remain available in RC2.

## Requirements and installation

Windows 10/11 x64, S.T.A.L.K.E.R. 2 PC, a separately installed **game-compatible UE4SS runtime**, and a USB Joystick transmitter or supported gamepad.

1. Close the game. Extract the complete **ZoneFPV-0.3.0-RC2.zip** archive and run **Setup.cmd**; choose the game folder if needed.
2. Connect your transmitter in **USB Joystick** mode or a gamepad, start the game and load a save.
3. Open **PDA → ZoneFPV** or **F6 → Settings → Controller**, select the device, check directions and calibrate.
4. Defaults: **F6 settings, F8 enter/leave FPV, F9 return to launch**. Lower throttle in Acro/Angle or centre it in 3D before entering. Close settings/PDA to fly.

Update the entire archive together, including EXE, DLL and PAK, and restart the game. Preferences, calibration and OSD positions are preserved; the installer backs up the previous mod. Players do not need a compiler or Python. ZoneFPV does not bundle or replace UE4SS or other mods. Vortex installation is not tested.

## Limits and support

RC2 is a release candidate. Loading-distance increases can raise RAM/streaming cost and do not create collision for unloaded objects. Main FPV follows the drone with the simulation anchor; Alternative FPV leaves it at launch with reduced remote NPC/collision coverage. NIR/SWIR and battery behaviour are approximations. Regional quest weather/CNPP effects and game-update compatibility remain limitations. Borderless/windowed play is recommended for the external OSD. Achievement compatibility is retained.

For reports, include the game/UE4SS/mod version, reproduction steps, **UE4SS.log** and the mod's **performance.txt**. To uninstall with the game closed, use **Uninstall.ps1** from the extracted installer; see the installation guide for options.

[GitHub download mirror](https://github.com/mrwinka/ZoneFPV/releases/latest) · [Public source code](https://github.com/mrwinka/ZoneFPV) · [Install / troubleshooting EN/RU](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md)

ZoneFPV code is MIT. The included Betaflight OSD font is separately GPL-3.0-or-later, with source/license in mod/fonts. UE4SS, compatibility patches and proprietary game assets are not bundled.

---

# ZoneFPV — FPV-дрон для S.T.A.L.K.E.R. 2

Управляйте FPV-дроном с пульта или геймпада: исследуйте Зону, сканируйте цели, собирайте артефакты или установите боевое оснащение.

**Текущая версия: 0.3.0 RC2 — кандидат в релиз.** Старые выпуски, включая проверенную автором стабильную 0.2.0, сохранены.

## Возможности

- **Полёт:** Acro, самовыравнивание Angle и двунаправленная тяга 3D; настройка скорости, rates, expo и наклона камеры, проверки столкновений и звук дрона.
- **Меню в КПК и F6:** меню настроек F6 продублировано в **КПК → ZoneFPV**. Пять групп: «Полёт», «Изображение», «Оснащение», «Мир и связь», «Настройки». Выбор пульта, калибровка и назначения кнопок открываются прямо внутри КПК. Оба меню используют общие параметры; длинные списки прокручиваются.
- **Пульты и кнопки:** DirectInput, XInput и WinMM, подключение USB-устройств во время игры, профили и мастер калибровки четырёх осей. Назначается именно нажатая клавиша клавиатуры, кнопка мыши, кнопка пульта/геймпада или CH. Для назначений доступны «Переключение» и «Пока зажата».
- **Боевые дроны:** обычный, камикадзе, со сбросом гранат или **«Сброс + камикадзе»**. Регулируются мощность взрыва и минимальная скорость удара, чтобы можно было мягко приземлиться. Сбрасываются активированные **RGD-5 или F-1**; запас **1–20 гранат либо неограниченный**. Удержание кнопки повторяет сброс с интервалом, остаток отображается в полёте. В меню видны только подходящие выбранному типу параметры.
- **Видение:** ночные/инфракрасные режимы Starlight IR, NIR, SWIR, IR LED; тепловизионные палитры White Hot, Black Hot, Rainbow, Ironbow и другие; отдельные эффекты аналоговой камеры. Выбранное видение переключается назначенной кнопкой; если кнопка не назначена, включается при входе в FPV.
- **Нижняя камера и фонарик:** камера смотрит под дрон и вращается вместе с корпусом, поддерживает переключение и удержание. Нижний прицел настраивается отдельно; горизонт при взгляде вниз скрывается. Фонарик разрешается в настройках и управляется назначенной кнопкой.
- **Сбор артефактов:** подбор ближайшего артефакта назначенной кнопкой, дистанция **0,5–10 м**. При удержании попытки повторяются по мере приближения.
- **Сканер:** настраиваемые рамки и расстояния для загруженных NPC, мутантов и аномалий; для NPC отображаются игровые значки фракций. Рамки отрисовываются в текущем кадре игры; сканер не меняет видимость и AI персонажей.
- **Батарея — новое в RC2:** отключаемая эмуляция LiPo **300–20000 mAh, 2–8S**, по умолчанию 1500 mAh/6S. Учитываются расход от тяги и манёвров, масса, просадка/восстановление напряжения и температура. Перемещаемый показатель OSD отображает заряд, напряжение, ток, потраченные mAh и предупреждения LOW/LAND. Новый полёт получает полную батарею, возврат к старту сохраняет заряд; меню и потеря фокуса его не расходуют. Это физическое приближение, а не точная копия конкретного оборудования.
- **OSD:** расположение, размер и цвет показателей, несколько видов прицела. Элементы предпросмотра выбираются и перетаскиваются мышью внутри КПК; внешний редактор использует тот же макет.
- **Мир и связь:** помехи от расстояния, препятствий и аномалий; время/погода, заморозка мира и дальность подгрузки. Интерфейс RU/UK/EN/PL/DE.

## Что изменилось в RC2 после RC1

- Добавлены батарея и её телеметрия в OSD.
- Доработано обнаружение повторно активированных NPC; рамки перенесены в игровой кадр, восстановлены компактный вид, цвета и значки фракций; улучшено покрытие модульных NPC тепловизором.
- Восстановлена совместимость вкладки обычного КПК, сохранено отделение от экрана техника. Применено оформление **«Полевой прибор»** с родной подложкой/шрифтами КПК и сдержанным янтарным выделением.
- Исправлено восстановление устаревшего состояния курсора после FPV, КПК и Alt+Tab.
- Собственный взрыв камикадзе больше не оставляет источник налёта и контузии у игрока, включая немедленный повторный вход в FPV. Обычные игровые гранаты не изменены.
- Исправлен сброс вызванной дроном агрессии; враждебность, существовавшая до полёта, сохраняется.
- Сокращены повторные поиски контроллера, операции с файлами ресурсов, загрузки недоступных эффектов и дубли проверок столкновений в одном кадре. Гарантированный прирост FPS или устранение всех вылетов не заявляются.

Вооружение, эффекты видения, сбор артефактов, свободные назначения кнопок/CH и дублирование меню F6 внутри КПК уже были в RC1 и сохранены в RC2.

## Требования и установка

Windows 10/11 x64, S.T.A.L.K.E.R. 2 PC, отдельно установленный **совместимый с версией игры UE4SS**, пульт в режиме USB Joystick или поддерживаемый геймпад.

1. Закрыть игру. Полностью распаковать **ZoneFPV-0.3.0-RC2.zip**, запустить **Setup.cmd**, при необходимости выбрать папку игры.
2. Подключить пульт в режиме **USB Joystick** или геймпад, запустить игру и загрузить сохранение.
3. Открыть **КПК → ZoneFPV** или **F6 → «Настройки → Пульт»**, выбрать устройство, проверить направления и выполнить калибровку.
4. По умолчанию: **F6 — настройки, F8 — вход/выход из FPV, F9 — возврат к старту**. Перед входом в Acro/Angle опустить газ, в 3D — держать по центру. Для полёта закрыть меню/КПК.

Обновлять весь комплект вместе, включая EXE, DLL и PAK, после установки перезапустить игру. Настройки, калибровка и расположение OSD сохраняются; установщик создаёт резервную копию предыдущего мода. Компилятор и Python игроку не нужны. UE4SS и другие моды не включены и не заменяются. Установка через Vortex не проверена.

## Ограничения и помощь

RC2 остаётся кандидатом в релиз. Повышение дальности подгрузки увеличивает нагрузку на RAM/стриминг и не создаёт коллизии отсутствующих объектов. Основной FPV переносит центр симуляции за дроном; альтернативный оставляет его на старте с ограниченной удалённой симуляцией NPC/коллизий. NIR/SWIR и батарея — приближённые модели. Региональная квестовая погода/эффекты у ЧАЭС и совместимость после обновлений игры остаются ограничениями. Для внешнего OSD рекомендуется окно без рамки. Совместимость достижений сохранена.

В отчёте об ошибке укажите версии игры/UE4SS/мода, шаги воспроизведения, приложите **UE4SS.log** и **performance.txt** из папки мода. Для удаления при закрытой игре используйте **Uninstall.ps1** из распакованного установщика; параметры описаны в инструкции.

[Зеркало загрузки на GitHub](https://github.com/mrwinka/ZoneFPV/releases/latest) · [Открытый исходный код](https://github.com/mrwinka/ZoneFPV) · [Установка / решение проблем EN/RU](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md)

Код ZoneFPV — MIT. Шрифт Betaflight отдельно лицензирован по GPL-3.0-or-later, исходник и лицензия находятся в mod/fonts. UE4SS, патчи совместимости и игровые ассеты не поставляются.


