# ZoneFPV installation and troubleshooting / Установка и устранение неполадок

## English

1. Install UE4SS compatible with your exact game update. See [requirements](DEPENDENCIES.md) and [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases). Keep the runtime's required settings; EngineTick is supported.
2. Download the complete ZoneFPV installer ZIP from [Nexus](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) or the [GitHub release list](https://github.com/mrwinka/ZoneFPV/releases). On GitHub, choose the attached ZoneFPV ZIP, not the automatically generated Source code archive.
3. Close the game, extract the ZIP into a writable folder and run **Setup.cmd**. If prompted, select the game's installation folder containing `Stalker2`.
4. Connect a transmitter in USB Joystick mode or a gamepad. Launch the game and load a save. The input helper starts automatically.
5. Press **F6**, select the controller and verify all four control directions. Use guided calibration if the mapping is wrong.
6. Lower throttle for Acro/Angle or center it for 3D, then press **F8**. F8 exits FPV; F9 resets the drone.

Main FPV is the default. Alternative FPV leaves the player's simulation anchor at launch; remote NPC simulation and collision can be incomplete. Geometry loading distance is selectable through 5×; larger values can reduce FPS and do not ensure the whole map is loaded.

Updates preserve installed preferences/calibration and back up the previous mod beside the installer. To remove ZoneFPV, close the game and run `Uninstall.ps1 -GameRoot 'game folder'` in PowerShell. UE4SS and other mods remain installed.

For an optional higher object limit, use F6 → Rendering → `gc.MaxObjectsInGame` → Save to Engine.ini, then restart the game. This affects the entire game and persists after FPV; more loaded objects can use more RAM and worsen loading/GC pauses. [Details and default reset](OBJECT_LIMIT.md).

### Troubleshooting

- **Installer cannot find the game:** select the installation folder containing `Stalker2`. If access is denied, run Setup.cmd as administrator.
- **F6/F8 do nothing:** confirm a save is loaded and ZoneFPV is enabled in `ue4ss/Mods/mods.txt`; check `UE4SS.log`, `Mods/ZoneFPV/input-bridge-error.log` and `bridge-start-error.log`. A helper menu alone does not prove the Lua mod loaded.
- **Wrong axes or no device:** select the physical/virtual interface you use, check directions and calibrate. Custom transmitter models can use different channel orders. A physical Sony controller and a virtual Xbox controller may appear separately.
- **FPV will not enter:** check throttle neutral for the selected flight mode and that controller data is current.
- **Black CNPP view or quest fog:** these regional effects remain a known limitation, not a confirmed RC4 fix.
- **Clipping or missing distant geometry:** try main FPV, allow streaming time and use a suitable loading distance. Unloaded collision cannot be guaranteed by this mod.
- **Lost custom menu key:** close the game and remove only `bindings.txt` from the installed mod to restore F6/F8/F9.

For a bug report, include ZoneFPV/game/UE4SS versions, controller/interface, main/alternative and Acro/Angle/3D modes, loading multiplier, other mods, reproduction steps and relevant logs/video.

## Русский

1. Установите UE4SS, совместимый с вашей версией игры. Ссылки и требования — [DEPENDENCIES.md](DEPENDENCIES.md). Сохраните настройки, рекомендованные автором UE4SS; EngineTick поддерживается.
2. Скачайте установочный ZIP ZoneFPV с [Nexus](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) или из [списка выпусков GitHub](https://github.com/mrwinka/ZoneFPV/releases). На GitHub нужен приложенный ZIP ZoneFPV, а не автоматический архив Source code.
3. Закройте игру, распакуйте архив в доступную для записи папку и запустите **Setup.cmd**. При необходимости выберите папку установки, содержащую `Stalker2`.
4. Подключите пульт в режиме USB Joystick или геймпад, запустите игру и загрузите сохранение. Программа ввода запускается автоматически.
5. Нажмите **F6**, выберите устройство и проверьте четыре направления управления. При необходимости выполните калибровку.
6. В Acro/Angle опустите газ, в 3D поставьте его по центру. **F8** включает/выключает FPV; **F9** возвращает дрон к старту.

Основной FPV включён по умолчанию. Альтернативный оставляет игрока на старте: NPC вдали не подгружаются вслед за дроном, коллизии могут быть неполными. Множитель подгрузки до 5× увеличивает нагрузку и не гарантирует загрузку всей карты.

При обновлении сохраняются настройки и калибровки, предыдущий мод копируется в `backups` рядом с установщиком. Для удаления при закрытой игре выполните `Uninstall.ps1 -GameRoot 'папка игры'` в PowerShell.

Лимит объектов можно изменить вручную: F6 → «Прорисовка» → `gc.MaxObjectsInGame` → «Сохранить в Engine.ini», затем перезапустить игру. Это общая настройка всей игры, она остаётся после FPV. Дополнительные объекты могут увеличить расход RAM, время загрузки и паузы очистки памяти. [Подробности и возврат по умолчанию](OBJECT_LIMIT.md).

### Если что-то не работает

- Нет меню/FPV: загрузите сохранение, проверьте включение ZoneFPV в `mods.txt` и журналы `UE4SS.log`, `input-bridge-error.log`, `bridge-start-error.log`.
- Неверные оси: выберите нужный интерфейс и выполните калибровку. Пользовательская модель пульта или Steam Input могут менять каналы.
- FPV не включается: проверьте нейтраль газа для выбранного режима и наличие свежих данных устройства.
- Чёрный эффект у ЧАЭС/квестовый туман: известные ограничения, исправление не заявлено.
- Пролёты сквозь объекты/пропавшая геометрия: используйте основной режим и дайте миру прогрузиться. Отсутствующую коллизию мод гарантировать не может.
- Потеря кнопки меню: при закрытой игре удалите только `bindings.txt` из папки мода.

Для отчёта укажите версии мода/игры/UE4SS, устройство и интерфейс, оба выбранных режима, множитель подгрузки, другие моды и шаги воспроизведения; приложите журнал или видео.

