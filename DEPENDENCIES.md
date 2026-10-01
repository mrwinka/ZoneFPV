# Requirements / dependencies

- Windows 10/11 x64 and the PC version of S.T.A.L.K.E.R. 2.
- A game-version-compatible UE4SS runtime and loader installed in `Stalker2/Binaries/Win64/ue4ss`.
- A transmitter in USB Joystick mode or gamepad exposed through DirectInput, XInput or WinMM.

ZoneFPV's installer copies only its own mod. UE4SS, proxy DLLs, engine signatures and compatibility patches are not bundled or replaced. The input helper is statically linked; end users do not need Visual Studio or Python.

## Game-thread compatibility

RC3 and RC4 use the one-argument `ExecuteInGameThread(callback)` API and respect UE4SS's configured default, including **EngineTick**. They do not force ProcessEvent, change hooks on dispatch failure or edit UE4SS settings.

The original RC2 explicitly requested ProcessEvent. A reporter's game 2.0.6 / UE4SS `527a483b` setup with [compatibility package 2810](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2810) required EngineTick. The reporter subsequently confirmed RC3 worked without the reported freezes. Keep the settings required by the runtime for your exact game version; do not change them to ProcessEvent as a ZoneFPV workaround.

## Runtime links

- [UE4SS upstream](https://github.com/UE4SS-RE/RE-UE4SS)
- [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases)
- [Legacy STALKER 2 compatibility fix](https://www.nexusmods.com/stalker2heartofchornobyl/mods/2341): use only for game versions explicitly supported on that page.

Different game updates can need different runtime builds, settings or signatures. These links are not instructions to combine all compatibility fixes. Existing working installations do not need their runtime replaced just to update ZoneFPV.

## Controllers and display

Eight DirectInput axes (including sliders) are supported. Initial profiles include Xbox, DualSense, DualShock 4 and several radio layouts. USB/Bluetooth, adapters, Steam Input and custom radio channel mappings can expose different devices/axes; select one interface and verify directions. Physical DualShock 4 testing is pending.

Borderless/windowed play is recommended for the native OSD. The bridge uses background/nonexclusive input. Game focus changes pause FPV controls/audio without ending the session; stale or disconnected input still ends FPV.

## Ограничения совместимости

Нужен UE4SS именно для вашей версии игры. RC3/RC4 соблюдают выбранный в нём метод игрового потока, включая EngineTick; настройки UE4SS не меняются. Старый патч 2341 подходит только для версий игры, перечисленных на его странице. Готовые профили контроллеров требуют проверки направлений; настоящий DS4 ещё не проверен.

