# ZoneFPV 0.2.0 RC2

## Установка

1. Установите совместимый с вашей версией игры **UE4SS** — ссылки в `DEPENDENCIES.md`. Если ZoneFPV уже работал, повторять этот шаг не нужно.
2. Закройте игру. Распакуйте архив, запустите **Setup.cmd**. Установщик найдёт Steam-библиотеку или предложит выбрать папку игры. При отказе в доступе запустите Setup.cmd от имени администратора.
3. Подключите пульт в режиме **USB Joystick** либо геймпад. Запустите игру через Steam и загрузите сохранение.
4. **F6** — меню. Во вкладке «Контроллер» выберите устройство. Исходный профиль создаётся для известных устройств; калибруйте только при несовпадении направлений.
5. В Acro/Angle опустите газ и нажмите **F8**. **F8** возвращает персонажа; **F9** возвращает дрон к старту. В 3D для входа держите газ посередине. Галочка старта с ненулевым газом снимает эту проверку.

Настройки, калибровки и OSD сохраняются при обновлении. Резервные копии предыдущих установок — в `backups` рядом с установщиком.

## Управление

Mode 2: правый стик влево/вправо — наклон вбок, вверх/вниз — наклон вперёд/назад; левый влево/вправо — поворот, вверх/вниз — газ. У геймпада центр левого стика соответствует **50% газа** в Acro/Angle, а не нулю. Калибровка позволяет задать собственную раскладку.

- **Acro:** стики задают скорость вращения, самовыравнивания нет.
- **Angle:** правый стик задаёт наклон; в центре дрон выравнивается. Пределы крена и тангажа — по 50°. Высота автоматически не удерживается.
- **3D:** вращение как в Acro, тяга двунаправленная. Центр газа — ноль, выше — обычная тяга, ниже — обратная. Для перевёрнутого полёта нужен отрицательный газ. Это не стереоскопический режим.
- Смена режима завершает полёт. Войдите снова с газом в подходящей нейтрали.

Вкладки: «Полёт» — режим, скорость, камера, аналог, звук; «Контроллер» — устройство, профили и калибровка; «Мир» — время, погода, заморозка и свойства игрока; «Интерфейс» — OSD, пять языков, тема и кнопки.

Кнопки: F1–F12, A–Z, Insert/Delete, Home/End и Page Up/Down. Выбирайте три разные кнопки, желательно не занятые игрой. Изменение применяется при работающем моде. Если потеряли кнопку меню, при закрытой игре удалите только `bindings.txt` в папке мода для возврата F6/F8/F9.

## Контроллеры

Исходные профили: Xbox/XInput; DualSense/DualShock USB HID; RadioMaster Pocket DirectInput/WinMM; базовый EdgeTX/OpenTX AETR для RadioMaster/Jumper/FrSky/TBS/BETAFPV; FlySky/TAER; универсальные AETR/TAER; вариант Mode 1.

Название бренда не определяет порядок каналов пользовательской модели передатчика. Красное предупреждение напоминает проверить раскладку. При неправильных направлениях используйте калибровку. Ручная настройка автоматически не перезаписывается; каждый интерфейс имеет отдельный профиль. Поддерживаются восемь осей DirectInput, включая два слайдера.

Отключение устройства завершает полёт. После подключения выберите устройство в меню и включите FPV снова. Если доступны физический DualSense и виртуальный Xbox через Steam Input, выберите один из них. Устройство может отображаться несколько раз через разные интерфейсы.

## Удаление и помощь

При закрытой игре выполните `Uninstall.ps1 -GameRoot "папка игры"` в PowerShell. Скрипт сохраняет мод и настройки в отдельную папку, не удаляет UE4SS и другие моды.

Если F6/F8 не работают, проверьте `ue4ss/UE4SS.log`, `Mods/ZoneFPV/input-bridge-error.log` и `bridge-start-error.log`. «Нет ответа мода» означает отсутствие ответа игрового скрипта, а не обязательно ошибку калибровки. Не выключайте защиту Windows ради мода. Ограничения совместимости — `DEPENDENCIES.md`.

Это **кандидат в релиз**: новые режимы требуют проверки в игре. Выполненные проверки — в `RELEASE_STATUS.md`.

## English

Install game-compatible UE4SS. Close the game, extract this archive and run **Setup.cmd**. Load a save and open **F6**. Select your controller, verify its initial mapping and calibrate only if necessary. **F8** enters/exits FPV; **F9** resets the drone. Acro/Angle require low throttle; 3D requires centered throttle. Mode changes end flight. Interface settings change language, theme and keys. Updates preserve preferences. Universal hardware or game-version compatibility is not claimed.

## Deutsch

Eine zur Spielversion passende UE4SS-Version installieren. Spiel schließen, Archiv entpacken, **Setup.cmd** starten. Spielstand laden; **F6** öffnet das Menü. Controller wählen und Richtungen prüfen; bei Bedarf kalibrieren. **F8** schaltet FPV ein/aus, **F9** setzt die Drohne zurück. Acro/Angle: Gas unten; 3D: Gas in der Mitte. Moduswechsel beendet den Flug. Unter „Oberfläche“ Sprache, Design und Tasten ändern. Aktualisierungen erhalten Einstellungen. Neue Flugmodi müssen noch im Spiel geprüft werden.
