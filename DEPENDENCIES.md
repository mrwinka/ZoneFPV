# Dependencies / Зависимости

- Windows 10/11 x64 and PC S.T.A.L.K.E.R. 2.
- A UE4SS runtime/loader compatible with your exact game version, installed under `Stalker2/Binaries/Win64/ue4ss`.
- A transmitter in USB Joystick mode or a gamepad exposed through DirectInput, XInput or WinMM.

UE4SS is distributed separately: [upstream](https://github.com/UE4SS-RE/RE-UE4SS) and [releases](https://github.com/UE4SS-RE/RE-UE4SS/releases). Follow the compatibility instructions for your game version. This release does not bundle runtime loaders, signatures, compatibility patches or game assets. Do not combine unrelated runtime fixes.

Setup configures EngineTick dispatch, `HookEngineTick=1` and `HookUObjectProcessEvent=0`, backing up existing settings when changed. UE4SS binaries are not replaced. The helper is statically linked: end users do not need Visual Studio or Python. Borderless/windowed play is recommended for the native OSD. Hardware profiles are starting mappings, not device certification.

Требуются Windows x64, игра и совместимый с её версией UE4SS. Пульт подключается в режиме USB Joystick. Среда UE4SS устанавливается отдельно, её бинарные файлы/патчи в архиве отсутствуют. Установщик настраивает EngineTick и сохраняет резервную копию изменённых параметров. Python и Visual Studio для запуска не нужны.
