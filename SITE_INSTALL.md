# ZoneFPV installation and troubleshooting / Установка и устранение неполадок

**Current experimental prerelease: 0.3.0 RC1.** Latest NPC/scanner fixes have offline verification only (`gameplay_verified=false`). Stable 0.2.0 remains separate.

## English

1. Install UE4SS compatible with your exact game update separately. See [requirements](DEPENDENCIES.md) and [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases). Keep the settings required by that runtime. The 0.3.0 native paths require supported game-thread execution; never switch to unsafe ProcessEvent as a workaround.
2. Download the complete ZoneFPV installer ZIP from [Nexus](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) or [GitHub releases](https://github.com/mrwinka/ZoneFPV/releases). On GitHub, choose the attached installer ZIP, not the automatic Source code archive.
3. Close the game. Extract the complete ZIP into a writable folder and run **Setup.cmd**. If prompted, select the installation folder containing `Stalker2`.
4. Connect a transmitter in **USB Joystick/HID** mode or a gamepad, launch the game and load a save. The input helper starts automatically.
5. Open **PDA → ZoneFPV → Settings → Controller**, or **F6 → Settings → Controller**. Select the device and profile, verify stick directions and run the four-axis calibration wizard if needed. No external F6 window is needed for PDA calibration.
6. In **Settings → Buttons**, click the action and press the desired keyboard/mouse/controller button or move the CH switch. Choose Toggle or Hold. Defaults are **F6 settings, F8 FPV, F9 return to launch**; other actions start unbound.
7. Lower throttle for Acro/Angle or center it for 3D, then press F8. Close settings/PDA to fly; F8 exits FPV.

Both menus share preferences and offer Flight, Image, Equipment, World and signal, and Settings. Long lists scroll with the wheel, Up/Down or PageUp/PageDown. **Image → OSD** contains the draggable preview, all 14 indicator choices and independent normal/lower-camera crosshairs. Flashlight/lower-camera checkboxes permit their assigned inputs; enabling a permission does not itself activate the feature.

**Equipment → Combat mode** offers unarmed, kamikaze, grenade-drop and combined modes. Choose the loadout before a new flight. Capacity has 1–20 charges then Unlimited at the right end. F9 does not refill; a new flight does. With no vision binding, the selected vision starts on FPV entry.

Updates preserve preferences, calibration and OSD, and back up the previous mod beside the extracted installer. UE4SS and other mods are not bundled/replaced. End users do not need Visual Studio or Python. Vortex installation is not tested. To remove ZoneFPV with the game closed, run `Uninstall.ps1 -GameRoot 'game folder'` in PowerShell.

For the optional manual `gc.MaxObjectsInGame` override, use **Settings → General**, save to Engine.ini and restart the game. This changes game-wide object capacity and persists after FPV. Higher capacity can increase RAM use, loading time and garbage-collection pauses. [Details and reset](OBJECT_LIMIT.md).

Main FPV moves the simulation anchor with the drone. Alternative FPV keeps it at launch; distant NPC simulation and collision can be incomplete. Increased loading distance increases load and does not guarantee all geometry/collision. The CNPP regional black effect and quest weather remain known limitations. Borderless/windowed play is recommended for the native overlay.

### Troubleshooting

- **Installer cannot find the game:** select the folder containing `Stalker2`. If access is denied, check folder permissions or run Setup.cmd as administrator.
- **F6/F8 or the PDA page do nothing:** load a save, check ZoneFPV is enabled in `ue4ss/Mods/mods.txt`, and inspect `ue4ss/UE4SS.log`, `Mods/ZoneFPV/input-bridge-error.log` and `bridge-start-error.log`. A helper window alone does not prove the Lua mod is running.
- **Controller is missing:** confirm USB DATA and Joystick/HID mode, a data-capable cable and the device's presence in Windows. Reopen Settings → Controller to select the detected physical/virtual interface. The mod cannot read a device Windows does not expose.
- **Wrong axes/calibration fails:** select the intended device, inspect the current error and check directions before calibration. Custom radio models, adapters and Steam Input can expose different channels or duplicate physical/virtual devices.
- **FPV will not enter:** check neutral throttle for the selected mode and fresh controller data. Changing flight mode ends a current flight. Real disconnect/stale input still ends FPV; brief sample delays may pause it.
- **OSD placement:** click/select an indicator in the preview and drag it; the vertical list also selects hidden indicators. Release saves the change. Leaving the section/focus cancels unfinished dragging/capture/calibration.
- **Lost custom menu key:** with the game closed, remove only `bindings.txt` from the installed mod to restore F6/F8/F9.
- **NPC models disappear or scanner misses them:** latest recovery is not verified in a live game. Include the full relevant `UE4SS.log`, vision/main-or-alternative mode, reproduction steps and whether models return after exiting FPV. Do not treat offline tests as proof that this symptom is resolved.
- **Missing distant collision or black CNPP view:** these are known limits. Try main FPV and allow streaming time; missing collision cannot be guaranteed by this mod.

For a report, include ZoneFPV/game/UE4SS versions, device/interface, flight/FPV/vision modes, loading multiplier, other mods, reproduction steps and relevant logs/video.

## Русский

**Текущий экспериментальный выпуск — 0.3.0 RC1.** Последние исправления NPC/сканера проверены вне игры (`gameplay_verified=false`). Стабильная 0.2.0 остаётся отдельным выпуском.

1. Отдельно установите UE4SS для точной версии игры. [Требования](DEPENDENCIES.md), [выпуски UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases). Сохраните нужные ему настройки; не переключайте выполнение на небезопасный ProcessEvent как обход ошибки.
2. Скачайте полный установочный ZIP с [Nexus](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) или [GitHub](https://github.com/mrwinka/ZoneFPV/releases). На GitHub нужен приложенный установочный ZIP, а не автоматический Source code.
3. Закройте игру, распакуйте архив целиком и запустите **Setup.cmd**. При необходимости выберите папку, содержащую `Stalker2`.
4. Подключите пульт через USB DATA в режиме **Joystick/HID** или геймпад. Запустите игру и загрузите сохранение; помощник ввода запускается автоматически.
5. Откройте **КПК → ZoneFPV → Настройки → Пульт** либо **F6 → Настройки → Пульт**. Выберите устройство/профиль, проверьте направления и при необходимости пройдите калибровку четырёх осей. В КПК внешний F6 не открывается.
6. В **«Настройки → Кнопки»** нажмите действие и нужную кнопку клавиатуры/мыши/пульта либо переведите CH. Для каждого назначения доступны переключение/удержание. По умолчанию **F6 — настройки, F8 — FPV, F9 — возврат к старту**; остальные действия не назначены.
7. В Acro/Angle опустите газ, в 3D держите по центру; нажмите F8. Закройте меню/КПК для полёта. F8 выходит из FPV.

Меню имеют общие настройки и пять групп: «Полёт», «Изображение», «Оснащение», «Мир и связь», «Настройки». Списки прокручиваются колёсиком, вверх/вниз или PageUp/PageDown. В **«Изображение → OSD»** находятся перетаскиваемый предпросмотр, все 14 показателей и отдельные прицелы камер. Переключатели фонарика/нижней камеры разрешают работу назначенных кнопок, сами функцию не активируют.

В **«Оснащение → Боевой режим»** доступны обычный дрон, камикадзе, сброс гранат и совмещённый режим. Оснащение выбирается перед новым полётом. Количество — 1–20, затем «Неограниченно» справа. F9 не пополняет боезапас; новый полёт пополняет. Без кнопки видения выбранный эффект включается при входе в FPV.

Обновление сохраняет настройки, калибровки и OSD; предыдущий мод резервируется рядом с распакованным установщиком. UE4SS и другие моды не заменяются, компилятор/Python не требуются. Vortex не проверен. Удаление при закрытой игре: `Uninstall.ps1 -GameRoot 'папка игры'`.

Лимит `gc.MaxObjectsInGame`: **«Настройки → Общие»** → сохранить в Engine.ini → перезапустить игру. Это общая ёмкость объектов, действующая после FPV; увеличение может повысить RAM, время загрузки и паузы очистки. [Подробности и сброс](OBJECT_LIMIT.md).

Основной FPV переносит центр симуляции с дроном, альтернативный оставляет его на старте. NPC вдали и коллизии могут быть неподгружены. Большая дальность повышает нагрузку и не гарантирует всю карту. Чёрный эффект у ЧАЭС/квестовая погода могут оставаться; для внешнего OSD рекомендуется окно без рамки.

### Если что-то не работает

- Нет F6/F8/вкладки: загрузить сохранение, проверить `mods.txt`, `UE4SS.log`, `input-bridge-error.log`, `bridge-start-error.log`.
- Нет пульта: проверить USB DATA, Joystick/HID, кабель с передачей данных и устройство в Windows. Выбрать нужный физический/виртуальный интерфейс в «Настройки → Пульт».
- Неверные оси/ошибка калибровки: проверить выбранное устройство, конкретный текст ошибки и направления. Модель пульта, адаптер и Steam Input могут менять каналы.
- Нет входа в FPV: проверить нейтраль газа и свежие данные пульта. Смена режима завершает полёт; реальное отключение/устаревание данных сохраняет выход по безопасности.
- OSD: выбрать показатель в предпросмотре/списке и перетащить. Отпускание сохраняет; выход из раздела/потеря фокуса отменяет незавершённые действия.
- Потеря кнопки меню: при закрытой игре удалить только `bindings.txt` для возврата F6/F8/F9.
- Исчезают NPC/не ловит сканер: исправление в живой игре ещё не подтверждено. Приложить журнал, режимы FPV/видения, шаги и информацию, появляются ли NPC после выхода.
- Чёрный эффект ЧАЭС/неподгруженные коллизии: известные ограничения; использовать основной FPV и дать миру загрузиться.

Для отчёта нужны версии мода/игры/UE4SS, устройство/интерфейс, режимы, множитель подгрузки, другие моды, шаги и журнал/видео.
