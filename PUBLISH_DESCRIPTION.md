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
- Sphere-based collision, adjustable geometry loading distance up to 5×, time/weather controls and world freeze.
- Configurable OSD, synthesized drone sound, four analog styles, five interface languages and customizable keys.
- Player/weapon/subtitle hiding and restoration of supported player state after flight. NPCs/mutants retain their interactions with each other.

## Installation

1. Install UE4SS compatible with your exact game version separately. Keep its required settings; EngineTick is supported.
2. Close the game, extract the complete ZoneFPV installer ZIP and run **Setup.cmd**.
3. Connect a transmitter in USB Joystick mode or a gamepad, launch the game and load a save.
4. Press **F6**, select your controller and check directions. Calibrate if needed.
5. Lower throttle in Acro/Angle or center it in 3D; **F8** enters/exits FPV, **F9** returns the drone to launch.

Updates preserve settings/calibration and back up the previous mod. On GitHub, download the attached ZoneFPV installer ZIP; the automatic Source code archive is not the installer.

Higher geometry loading distances increase load and do not guarantee the whole map or all collision is resident. The CNPP anomaly's black effect and quest-driven checkpoint fog can remain. The flight model approximates a quadcopter. Borderless/windowed play is recommended for the native OSD.

## Object limit

The rendering tab has an optional, manually editable `gc.MaxObjectsInGame` setting. Save writes it to Engine.ini; restart the game to apply it. This is a game-wide object capacity, not an FPS setting. More loaded objects can use more RAM and increase loading/garbage-collection pauses. Game default removes only this override. Full 5× applies to all ten original geometry/foliage/HLOD grids. See [object-limit instructions](OBJECT_LIMIT.md).

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
- DirectInput, XInput и WinMM; выбор устройства, исходные профили и пошаговая калибровка. Добавлен профиль DS4; настоящий контроллер ещё не проверен.
- Основной FPV переносит центр симуляции вслед за дроном. Альтернативный оставляет игрока на старте: NPC вдали не подгружаются вслед за дроном, через многие объекты можно пролететь.
- Проверки столкновений объёмом дрона, подгрузка геометрии до 5×, время/погода и заморозка мира.
- Настраиваемый OSD, звук дрона, четыре аналоговых стиля, пять языков и переназначение кнопок.
- Скрытие игрока, оружия и субтитров; восстановление поддерживаемых значений состояния после полёта. NPC и мутанты продолжают взаимодействовать между собой.

### Установка

1. Отдельно установите UE4SS для вашей версии игры. Сохраните требуемые им настройки; EngineTick поддерживается.
2. Закройте игру, распакуйте установочный ZIP ZoneFPV целиком и запустите **Setup.cmd**.
3. Подключите пульт в режиме USB Joystick или геймпад, запустите игру и загрузите сохранение.
4. Нажмите **F6**, выберите устройство и проверьте направления. При необходимости пройдите калибровку.
5. В Acro/Angle опустите газ, в 3D держите его по центру. **F8** включает/выключает FPV, **F9** возвращает дрон к старту.

Обновление сохраняет настройки/калибровки и создаёт резервную копию. На GitHub нужен приложенный установочный ZIP, а не автоматический Source code.

Повышенная подгрузка увеличивает нагрузку и не гарантирует загрузку всей карты/коллизий. Чёрный эффект аномалии у ЧАЭС и квестовый туман у КПП могут оставаться. Модель полёта приближённая. Для внешнего OSD рекомендуется окно без рамки.

### Лимит объектов

В «Прорисовке» можно вручную задать `gc.MaxObjectsInGame` и сохранить в Engine.ini. Требуется перезапуск игры. Это максимальное число Unreal-объектов всей игры, а не настройка FPS. Больше загруженных объектов может увеличить расход RAM, время загрузки и паузы очистки памяти. «По умолчанию» удаляет только этот параметр. Общий множитель до 5× снова применяется ко всем десяти прежним слоям геометрии, леса и дальних моделей. [Подробности](https://github.com/mrwinka/ZoneFPV/blob/main/OBJECT_LIMIT.md).

### Лицензии

Код ZoneFPV — MIT (`LICENSE.txt`). Шрифт Betaflight OSD — отдельно GPL-3.0-or-later, его исходник и лицензия находятся в `mod/fonts`. UE4SS, сторонние патчи и игровые ассеты в архив не входят.


