# ZoneFPV — FPV Drone Camera

ZoneFPV adds a controllable FPV camera to S.T.A.L.K.E.R. 2 with quadcopter-style flight, transmitter/gamepad input and a configurable telemetry OSD.

## Links

- [ZoneFPV source code](https://github.com/mrwinka/ZoneFPV)
- [Build instructions](https://github.com/mrwinka/ZoneFPV#build-the-native-helper)
- [Installation and troubleshooting (EN/RU)](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md)
- [Legacy compatibility fix — only for game versions listed on its page](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2341)
- [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases)
- [GitHub release list / download mirror](https://github.com/mrwinka/ZoneFPV/releases)

## Features

- Acro, self-leveling Angle and reversible-thrust 3D flight; speed, rates, expo and camera tilt settings.
- DirectInput, XInput and WinMM; controller selection, initial profiles and guided calibration. Includes a DualShock 4 profile; physical DS4 testing is pending.
- Main FPV follows the drone with the simulation anchor. Optional Alternative FPV leaves the player at launch: distant NPC simulation does not follow and many objects can be passed through.
- Sphere-based collision and an adjustable rendering-distance multiplier up to 5× for geometry, foliage and distant models. Previous loading distances are restored after flight.
- Time/weather controls and world freeze. Native rain, falling leaves and ambient crows remain visible in FPV.
- Configurable OSD, synthesized drone sound, four analog styles, five interface languages and customizable keys.
- Resizable F6 settings menu and OSD editor, with scaled controls/text and saved window sizes. The OSD preview keeps the game's aspect ratio.
- Player body, weapon, shadow and subtitle hiding during flight; the game HUD and supported player state return after exit. NPCs and mutants leave the player alone during FPV and retain their interactions with each other.

## Installation

1. Install UE4SS compatible with your exact game version separately. Keep its required settings; EngineTick is supported.
2. Close the game, extract the complete ZoneFPV installer ZIP and run **Setup.cmd**.
3. Connect a transmitter in USB Joystick mode or a gamepad, launch the game and load a save.
4. Press **F6**, select your controller and check directions. Calibrate if needed.
5. Lower throttle in Acro/Angle or center it in 3D; **F8** enters/exits FPV, **F9** returns the drone to launch.

Updates preserve settings/calibration and back up the previous mod. On GitHub, download the attached ZoneFPV installer ZIP; the automatic Source code archive is not the installer.

Higher geometry loading distances increase load and do not guarantee the whole map or all collision is resident. The CNPP anomaly's black effect and quest-driven checkpoint fog can remain. The flight model approximates a quadcopter. Borderless/windowed play is recommended for the native OSD.

## Object limit

The rendering tab has an optional, manually editable `gc.MaxObjectsInGame` setting. Save writes it to Engine.ini; restart the game to apply it. This is a game-wide object capacity, not an FPS setting. Increasing rendering distance can reduce FPS and use more RAM; a higher object limit can also increase loading and garbage-collection pauses. Raising the limit does not guarantee stability. Game default removes only this override. The selected multiplier, up to 5×, applies to all ten original geometry/foliage/HLOD grids. See [object-limit instructions](https://github.com/mrwinka/ZoneFPV/blob/main/OBJECT_LIMIT.md).

## Licensing

ZoneFPV code: MIT (`LICENSE.txt`). Included Betaflight OSD font: separately GPL-3.0-or-later, with source and license in `mod/fonts`. UE4SS, compatibility patches and game assets are not bundled.

## Русский

ZoneFPV добавляет в S.T.A.L.K.E.R. 2 управляемую FPV-камеру с моделью полёта квадрокоптера. Можно летать с пультом или геймпадом, переключаться между персонажем и FPV и настроить экран телеметрии.

### Ссылки

- [Исходный код ZoneFPV](https://github.com/mrwinka/ZoneFPV)
- [Инструкция по сборке](https://github.com/mrwinka/ZoneFPV#build-the-native-helper)
- [Установка и устранение неполадок (EN/RU)](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md)
- [Старый патч совместимости — только для версий игры, указанных на его странице](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2341)
- [Выпуски UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases)
- [Список выпусков GitHub / зеркало загрузки](https://github.com/mrwinka/ZoneFPV/releases)

### Возможности

- Acro, самовыравнивание Angle и двунаправленная тяга 3D; скорость, rates, expo и наклон камеры.
- DirectInput, XInput и WinMM; выбор устройства, исходные профили и пошаговая калибровка. Есть профиль DualShock 4; проверка на настоящем DS4 ещё не проводилась.
- Основной FPV переносит центр симуляции вслед за дроном. Альтернативный оставляет игрока на старте: NPC вдали не подгружаются вслед за дроном, через многие объекты можно пролететь.
- Проверки столкновений объёмом дрона и множитель дальности прорисовки до 5× для геометрии, растительности и дальних моделей. После полёта возвращаются прежние расстояния подгрузки.
- Управление временем/погодой и заморозка мира. В FPV сохраняется отображение дождя, падающих листьев и ворон.
- Настраиваемый OSD, звук дрона, четыре аналоговых стиля, пять языков и переназначение кнопок.
- Изменяемый размер меню F6 и редактора OSD: элементы и текст масштабируются, размеры окон сохраняются. Предпросмотр OSD учитывает соотношение сторон игры.
- Скрытие тела игрока, оружия, тени и субтитров во время полёта; интерфейс игры и поддерживаемые значения состояния восстанавливаются после выхода. NPC и мутанты не атакуют игрока в FPV и продолжают взаимодействовать между собой.

### Установка

1. Отдельно установите UE4SS для вашей версии игры. Сохраните требуемые им настройки; EngineTick поддерживается.
2. Закройте игру, распакуйте установочный ZIP ZoneFPV целиком и запустите **Setup.cmd**.
3. Подключите пульт в режиме USB Joystick или геймпад, запустите игру и загрузите сохранение.
4. Нажмите **F6**, выберите устройство и проверьте направления. При необходимости пройдите калибровку.
5. В Acro/Angle опустите газ, в 3D держите его по центру. **F8** включает/выключает FPV, **F9** возвращает дрон к старту.

Обновление сохраняет настройки/калибровки и создаёт резервную копию. На GitHub нужен приложенный установочный ZIP, а не автоматический Source code.

Повышенная подгрузка увеличивает нагрузку и не гарантирует загрузку всей карты/коллизий. Чёрный эффект аномалии у ЧАЭС и квестовый туман у КПП могут оставаться. Модель полёта приближённая. Для внешнего OSD рекомендуется окно без рамки.

### Лимит объектов

В «Прорисовке» можно вручную задать `gc.MaxObjectsInGame` и сохранить в Engine.ini. Требуется перезапуск игры. Это максимальное число Unreal-объектов всей игры, а не настройка FPS. Повышение дальности прорисовки может снизить FPS и увеличить расход RAM; повышенный лимит объектов также может увеличить время загрузки и паузы очистки памяти. Увеличение лимита не гарантирует стабильность. «По умолчанию» удаляет только этот параметр. Выбранный множитель, вплоть до 5×, применяется ко всем десяти исходным слоям геометрии, растительности и дальних моделей. [Подробности](https://github.com/mrwinka/ZoneFPV/blob/main/OBJECT_LIMIT.md).

### Лицензии

Код ZoneFPV — MIT (`LICENSE.txt`). Шрифт Betaflight OSD — отдельно GPL-3.0-or-later, его исходник и лицензия находятся в `mod/fonts`. UE4SS, сторонние патчи и игровые ассеты в архив не входят.


