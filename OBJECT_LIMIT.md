# Optional game object limit / Необязательный лимит объектов игры

## English

`gc.MaxObjectsInGame` is the configured maximum number of Unreal objects for the game, including actors, components and resources. It is not a number of NPCs and not an FPS multiplier. More object capacity can allow additional world loading; more resident objects may consume more RAM and make streaming or garbage collection slower. A small value can prevent the game from starting. Raising the limit does not fix leaks or guarantee that 5× streaming fits the available memory.

1. F6 → **Rendering** → enter a positive whole number for `gc.MaxObjectsInGame` (no separators; for example `1200000`).
2. Choose **Save to Engine.ini**. This stores the requested value; it does not resize the running game's object array.
3. Fully close and restart the game before testing. Whether this game build accepts the stored startup override still needs in-game confirmation.
4. **Game default** removes only this key; restart again. Other Engine.ini settings are retained. If a previous custom value was needed, restore it manually or use the adjacent backup.

File: `%LOCALAPPDATA%/Stalker2/Saved/Config/Windows/Engine.ini` (the Steam/Windows profile used for testing). This setting applies to the whole game and remains after FPV or mod removal. ZoneFPV installation/startup never changes it automatically. A missing file is created only when Save is explicitly used; existing files are backed up beside Engine.ini using `Engine.ini.ZoneFPV-object-limit-….bak`. UTF-8/BOM and UTF-16LE are preserved. Other encodings are rejected without modification.

```ini
[/Script/Engine.GarbageCollectionSettings]
gc.MaxObjectsInGame=1200000
```

For a recovery or offline change, run the native helper from the extracted mod folder:

```powershell
.\ZoneFPVInput.exe --object-limit 1200000
.\ZoneFPVInput.exe --object-limit-default
```

These commands change only the stored configuration; restart the game. The field can accept positive 32-bit values, but very large values are not a recommendation. Begin with a modest increase and monitor memory, loading pauses and crashes. Full 5× now applies to all ten original geometry/foliage/HLOD grids and remains experimental.

[Epic GC settings](https://dev.epicgames.com/documentation/en-us/unreal-engine/garbage-collection-settings-in-the-unreal-engine-project-settings) · [Console-variable reference](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-console-variables-reference): the live console value is a placeholder, not verification of the allocated object capacity.

## Русский

`gc.MaxObjectsInGame` — заданный максимум Unreal-объектов всей игры: игровых акторов, компонентов и ресурсов. Это не число NPC и не множитель FPS. Повышение даёт запас для подгрузки мира; дополнительные загруженные объекты могут увеличить расход RAM, время загрузки и паузы очистки памяти. Слишком малое число может привести к крашу при запуске. Повышение лимита не исправляет утечки и не гарантирует, что прорисовка 5× поместится в память.

1. **F6 → «Прорисовка»** → впиши целое положительное число без разделителей, например `1200000`.
2. Нажми **«Сохранить в Engine.ini»**. Это сохраняет значение для следующего запуска; действующий массив объектов не расширяется.
3. Полностью закрой и перезапусти игру, затем повтори маршрут теста. Применение параметра этой сборкой игры ещё нужно подтвердить.
4. **«По умолчанию»** удаляет только этот ключ; требуется повторный перезапуск. Остальные настройки остаются. Если раньше был нужен собственный лимит, верни его вручную или из резервной копии.

Файл: `%LOCALAPPDATA%/Stalker2/Saved/Config/Windows/Engine.ini`. Это профиль Steam/Windows, использованный для тестирования. Настройка действует на всю игру и остаётся после FPV/удаления мода. Установка и запуск ZoneFPV не меняют её автоматически. Новый Engine.ini создаётся только при явном сохранении; существующий предварительно копируется рядом в файл `Engine.ini.ZoneFPV-object-limit-….bak`. Сохраняются UTF-8/BOM и UTF-16LE; другие кодировки не изменяются.

Если малое значение мешает запуску игры, открой папку установленного ZoneFPV в PowerShell и выполни `./ZoneFPVInput.exe --object-limit-default`, затем запусти игру снова. Для задания числа без меню: `./ZoneFPVInput.exe --object-limit 1200000`.

Допустим ввод положительного 32-битного числа, но очень большие значения не рекомендуются как исходные. Начни с умеренного увеличения и проверь память, загрузку и краши. Общий множитель до 5× снова применяется ко всем десяти прежним слоям геометрии, леса и HLOD; функция экспериментальная.
