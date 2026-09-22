# Installation — ZoneFPV 0.2.0 RC2

## English — copy to the mod page

**Requirements:** Windows 10/11 x64, STALKER 2 PC, a working UE4SS runtime compatible with your exact game update. UE4SS is not included. See DEPENDENCIES.md for the tested base build and compatibility patch. This is a UE4SS mod with a native helper, not a PAK mod. Borderless/windowed mode is recommended for the external OSD.

1. Install and verify compatible UE4SS following the compatibility patch author's instructions for your game version.
2. Close the game. Extract the entire ZoneFPV ZIP to a folder; do not run Setup from inside the archive.
3. Run **Setup.cmd**. It detects Steam libraries or asks you to select the game root containing the `Stalker2` folder. Use administrator privileges only if access to that installation folder is denied.
4. Connect a controller; transmitters must use **USB Joystick** mode. Start the game normally and load a save.
5. Press **F6**, select the device in Controller, and verify stick directions. Initial profiles are supplied; use guided calibration if a mapping is wrong.
6. **F8** enters/exits FPV. **F9** returns the camera home. Acro/Angle require low throttle, while 3D requires centered throttle, unless nonzero-throttle entry is enabled. A centered gamepad throttle stick is 50% in Acro/Angle. Keys can be changed in Interface.

**Updating:** close the game and run Setup from the new extracted release. Existing preferences/calibrations are preserved; backups are created beside the installer. Keep that folder if you need the backup.

**Uninstalling:** close the game, open PowerShell in the extracted release folder and run `./Uninstall.ps1 -GameRoot "D:\path\to\S.T.A.L.K.E.R. 2 Heart of Chornobyl"` with your actual path. It disables/moves ZoneFPV while retaining a backup; it leaves UE4SS and other mods alone.

**F6/F8 do nothing / No response from mod:** verify UE4SS loads on your game build; inspect `Stalker2/Binaries/Win64/ue4ss/UE4SS.log` and any `input-bridge-error.log` / `bridge-start-error.log` in `ue4ss/Mods/ZoneFPV`. The helper is unsigned and may be rejected by restrictive application-control policies. Do not disable Windows protection. If custom menu keys are lost, close the game and remove only `bindings.txt` from ZoneFPV to restore F6/F8/F9.

**Controller troubleshooting:** select one physical or virtual device, check its live axes and try the matching profile. Steam Input, Bluetooth and custom transmitter models can change mappings. Brand presets are starting layouts, not a guarantee for every model. After disconnecting, reconnect, select the device and re-enter flight.

## Русский — для страницы мода

**Требования:** Windows 10/11 x64, STALKER 2 на ПК и работающий UE4SS, совместимый с вашей версией игры. UE4SS скачивается отдельно; ссылки и проверенная базовая сборка — в DEPENDENCIES.md. Это не PAK: не кладите архив в `~mods`. Для внешнего OSD рекомендуется оконный режим или окно без рамки.

1. Установите совместимый UE4SS по инструкции автора патча для вашей версии игры.
2. Закройте игру. Полностью распакуйте ZIP в отдельную папку.
3. Запустите **Setup.cmd**. Установщик найдёт Steam-библиотеку или попросит выбрать корень игры с папкой `Stalker2`. Права администратора нужны только при отказе в доступе к папке игры.
4. Подключите геймпад или пульт в режиме **USB Joystick**, запустите игру обычным способом и загрузите сохранение.
5. Нажмите **F6**, выберите устройство во вкладке «Контроллер», проверьте направления. Если готовый профиль не подходит — выполните калибровку.
6. **F8** — вход/выход из FPV, **F9** — возврат камеры домой. Для Acro/Angle нужен газ внизу; для 3D — посередине. Вход с ненулевым газом можно разрешить в меню. У геймпада центр стика в Acro/Angle означает 50% газа. Кнопки меняются во вкладке «Интерфейс».

**Обновление:** закройте игру и запустите Setup из новой версии. Настройки сохранятся, резервная копия появится рядом с установщиком.

**Удаление:** при закрытой игре откройте PowerShell в папке распакованного релиза и выполните `./Uninstall.ps1 -GameRoot "D:\путь\к\папке игры"`. Скрипт отключит и перенесёт мод в резервную папку, сохранив UE4SS и другие моды.

**Нет реакции на F6/F8:** проверьте совместимость и загрузку UE4SS, затем UE4SS.log и журналы моста в `ue4ss/Mods/ZoneFPV`. «Нет ответа мода» не обязательно связано с калибровкой. Не отключайте защиту Windows. Если забыли назначенную кнопку меню, при закрытой игре удалите только `bindings.txt` в папке ZoneFPV.

**Неверные оси:** выберите нужный физический/виртуальный интерфейс и подходящий профиль, при необходимости откалибруйте. USB/Bluetooth, Steam Input и настройка модели передатчика могут менять раскладку. После отключения устройства подключите его снова, выберите в меню и повторно войдите в FPV.
