# ZoneFPV 0.3.0 RC2 — installation and troubleshooting / Установка

## English

1. Install a UE4SS runtime compatible with your exact S.T.A.L.K.E.R. 2 update. See [dependencies](DEPENDENCIES.md) and [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases). Keep the runtime's required settings; EngineTick is supported.
2. Download **ZoneFPV-0.3.0-RC2.zip** from [Nexus](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) or [GitHub Releases](https://github.com/mrwinka/ZoneFPV/releases). Choose the attached installer, not GitHub's automatic Source code archive.
3. Close the game, extract the complete ZIP into a writable folder and run **Setup.cmd**. If prompted, select the installation folder containing `Stalker2`. Lua, EXE, DLL and PAK must be updated together. Restart the game after installation.
4. Connect a transmitter in **USB Joystick/HID** mode or a gamepad. Launch the game and load a save. The input helper starts automatically.
5. Open **PDA → ZoneFPV** or **F6 → Settings → Controller**. Select the device, check four-axis directions and calibrate if needed. Settings and calibration work inside the PDA; a separate F6 window is not required.
6. In **Settings → Buttons**, capture the keyboard/mouse/controller button or CH you want for each action. Toggle and Hold are available. Defaults: **F6 settings, F8 enter/leave FPV, F9 return to launch**.
7. Lower throttle in Acro/Angle or centre it in 3D before F8. Close the PDA/settings to fly.

### Battery and loadout

**Flight → Main** contains optional battery simulation: **300–20000 mAh, 2–8S**, default 1500 mAh/6S. A larger pack increases mass; voltage and load affect available thrust and consumption. New flights receive a full pack. F9 preserves remaining charge. Menus/focus pauses do not consume charge. Depletion cuts thrust, then returns control after a short fall. Changing battery settings during flight ends it; the next launch uses the new pack. Disable simulation for unrestricted battery duration.

In **Equipment → Combat mode**, select normal, kamikaze, grenade drop or combined. **Image → OSD** configures telemetry/crosshairs and the new battery item; select and drag preview labels to move them. The same preferences apply in the PDA and F6.

### Updating and removing

Updates preserve preferences, calibration and OSD positions and store the previous mod in `backups` beside the extracted installer. No compiler or Python is needed by players. UE4SS and other mods are not replaced. Vortex installation is not tested.

With the game closed, run `Uninstall.ps1 -GameRoot 'game folder'` in PowerShell to remove ZoneFPV while keeping UE4SS and other mods. See the script's parameters for the target game folder.

The optional global object limit is in **Settings → General**: `gc.MaxObjectsInGame` → Save to Engine.ini, followed by a game restart. Raising it does not improve FPS and can increase RAM use/loading/GC pauses. [Details and default reset](OBJECT_LIMIT.md).

### Troubleshooting

- **Game folder not found:** choose the folder containing `Stalker2`. If access is denied, run Setup.cmd as administrator.
- **F6/F8 do nothing:** load a save and check ZoneFPV in `ue4ss/Mods/mods.txt`; read `UE4SS.log`, `Mods/ZoneFPV/input-bridge-error.log` and `bridge-start-error.log`. A helper window alone does not establish that Lua loaded.
- **No controller or wrong axes:** use a data USB port/cable, choose Joystick/HID on the transmitter, select the actual device and calibrate. Physical and virtual controllers may appear separately.
- **FPV will not enter:** check throttle neutral for the chosen mode, fresh controller data and that menus are closed.
- **FPV loses thrust:** check battery and simulated signal status; a depleted pack requires a new flight.
- **Scanner report:** include whether NPC models or only markers disappear, selected vision and main/alternative mode. Attach `UE4SS.log` and `performance.txt`. The scanner logs whether game-frame UI or the fallback renderer is active.
- **Screenshot misses the external OSD:** try **Win + Print Screen**. Opening an area-selection tool takes focus and pauses/hides the external overlay.
- **Distant clipping/geometry:** main FPV follows the drone with the simulation anchor; Alternative FPV leaves it at launch. Allow streaming time. More loading distance can reduce FPS and cannot guarantee unloaded collision.
- **Regional CNPP black effect or quest weather:** these remain separate limitations; the RC2 kamikaze feedback fix does not claim to remove regional effects.
- **Lost menu binding:** with the game closed, remove only `bindings.txt` from the installed ZoneFPV folder to restore F6/F8/F9.

For bug reports, include game/UE4SS/ZoneFPV versions, controller/interface, main/alternative and Acro/Angle/3D, loading multiplier, other mods, reproduction steps and relevant logs/video. RC2 remains a release candidate.

## Русский

1. Отдельно установите UE4SS для вашей версии S.T.A.L.K.E.R. 2. Ссылки — [DEPENDENCIES.md](DEPENDENCIES.md). Сохраните настройки, требуемые UE4SS; EngineTick поддерживается.
2. Скачайте **ZoneFPV-0.3.0-RC2.zip** с [Nexus](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2799) или из [выпусков GitHub](https://github.com/mrwinka/ZoneFPV/releases). Нужен приложенный установщик, а не автоматический Source code.
3. Закройте игру, полностью распакуйте ZIP в доступную для записи папку и запустите **Setup.cmd**. Выберите папку, содержащую `Stalker2`, если нужно. Lua, EXE, DLL и PAK обновляются вместе. После установки запустите игру заново.
4. Подключите пульт в **USB Joystick/HID** или геймпад, запустите игру и загрузите сохранение. Программа ввода запускается автоматически.
5. Откройте **КПК → ZoneFPV** или **F6 → «Настройки → Пульт»**. Выберите устройство, проверьте четыре оси и при необходимости выполните калибровку. Всё работает прямо внутри КПК, отдельное окно F6 не требуется.
6. В **«Настройки → Кнопки»** нажмите назначение, затем нужную клавишу, кнопку мыши/пульта или CH. Доступны переключение и удержание. По умолчанию: **F6 — настройки, F8 — вход/выход из FPV, F9 — возврат к старту**.
7. В Acro/Angle опустите газ, в 3D держите по центру, затем F8. Закройте меню/КПК для полёта.

### Батарея и оснащение

В **«Полёт → Основное»** настраивается эмуляция батареи: **300–20000 mAh, 2–8S**, по умолчанию 1500 mAh/6S. Большая батарея увеличивает массу; напряжение и нагрузка влияют на тягу и расход. Новый полёт получает полный заряд, F9 сохраняет остаток. Меню и потеря фокуса заряд не расходуют. При разряде тяга отключается, после короткого падения управление возвращается персонажу. Изменение батареи завершает текущий полёт; следующий запуск использует новые параметры. Эмуляцию можно выключить.

В **«Оснащение → Боевой режим»** выберите обычный, камикадзе, сброс гранат или совмещённый вариант. В **«Изображение → OSD»** настраиваются показатели, прицелы и батарея; для перемещения нажмите и перетащите элемент предпросмотра. КПК и F6 используют общие настройки.

### Обновление и удаление

Настройки, калибровка и положение OSD сохраняются; предыдущий мод копируется в `backups` рядом с распакованным установщиком. Компилятор и Python игроку не нужны. UE4SS и другие моды не заменяются. Vortex не проверен.

Для удаления при закрытой игре выполните `Uninstall.ps1 -GameRoot 'папка игры'` в PowerShell. UE4SS и другие моды сохраняются.

Необязательный лимит объектов находится в **«Настройки → Общие»**: `gc.MaxObjectsInGame` → «Сохранить в Engine.ini», затем перезапуск игры. Это глобальная ёмкость Unreal-объектов, не настройка FPS; повышение может увеличить расход RAM, загрузку и паузы очистки памяти. [Подробности и возврат по умолчанию](OBJECT_LIMIT.md).

### Если что-то не работает

- **Нет папки игры:** выберите папку, содержащую `Stalker2`. При отказе доступа запустите Setup.cmd от администратора.
- **F6/F8 не работают:** загрузите сохранение, проверьте ZoneFPV в `ue4ss/Mods/mods.txt`, журналы `UE4SS.log`, `input-bridge-error.log`, `bridge-start-error.log`. Окно помощника само по себе не доказывает загрузку Lua.
- **Нет пульта/неверные оси:** используйте USB-порт и кабель передачи данных, выберите Joystick/HID на пульте, нужное устройство в меню и выполните калибровку. Физическое и виртуальное устройства могут отображаться отдельно.
- **FPV не включается:** проверьте нейтраль газа, свежие данные пульта и закрытие меню.
- **Пропала тяга:** проверьте батарею и симуляцию сигнала. Разряженную батарею заменяет новый полёт.
- **Проблема сканера:** уточните, исчезают сами модели NPC или только отметки, режим видения и основной/альтернативный FPV. Приложите `UE4SS.log` и `performance.txt`; журнал показывает активный способ отрисовки сканера.
- **На снимке нет внешнего OSD:** попробуйте **Win + Print Screen**. Выделение области забирает фокус, поэтому внешний интерфейс скрывается/приостанавливается.
- **Пролёты сквозь объекты/дальняя геометрия:** основной FPV переносит центр симуляции за дроном, альтернативный оставляет его на старте. Дайте миру прогрузиться; повышение дальности увеличивает нагрузку и не гарантирует отсутствующую коллизию.
- **Чёрный эффект у ЧАЭС/квестовая погода:** отдельные известные ограничения; исправление взрыва камикадзе не заявляется как их устранение.
- **Потеря кнопки меню:** при закрытой игре удалите только `bindings.txt` из папки ZoneFPV для возврата F6/F8/F9.

Для отчёта укажите версии игры/UE4SS/ZoneFPV, устройство/интерфейс, основной/альтернативный и Acro/Angle/3D, подгрузку, другие моды, шаги воспроизведения и журналы/видео. RC2 остаётся кандидатом в релиз.
