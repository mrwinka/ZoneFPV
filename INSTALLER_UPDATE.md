# ZoneFPV 0.3.0 RC2 - installer discovery update

This is an installer-only refresh of RC2. Setup now skips unavailable Steam libraries, including folders on disconnected or removed drives, and continues looking for a valid game installation. If automatic discovery cannot select one game folder, manual selection remains available. The game runtime, EXE, DLL, armament PAK, features and saved settings are unchanged.

Extract the complete refreshed archive and run Setup.cmd with the game closed. A folder can also be specified explicitly from PowerShell opened in the extracted folder:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Setup.ps1 -GameRoot 'X:\Your Steam Library\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl'
```

Replace the example path with your actual game folder containing Stalker2. Add -CheckOnly to validate the folder/UE4SS prerequisite without installing. A stale library is not an administrator-permission problem; elevation does not reconnect a missing drive.

## Русский

Обновлён только установщик RC2. Недоступные библиотеки Steam, в том числе на отключённых или удалённых дисках, теперь пропускаются; поиск продолжается в следующих библиотеках. Если папка не выбрана автоматически, остаётся ручной выбор. Файлы самого мода, EXE/DLL/PAK, функции и сохранённые настройки не менялись.

Полностью распакуйте новый архив, закройте игру и запустите Setup.cmd. Для ручного пути используйте команду выше, заменив пример на настоящую папку игры, содержащую Stalker2. Параметр -CheckOnly проверяет путь и наличие UE4SS без установки. Права администратора не устраняют ссылку Steam на отсутствующий диск.

Validation: the new setup regression and existing full-install/update/uninstall/rollback fixtures run under Windows PowerShell 5.1. Earlier Lua/native proofs are reused because all 114 runtime files and the companion PAK remain byte-identical to the published RC2. No new in-game result is claimed.
