# Requirements / dependencies

Windows 10/11 x64, STALKER 2 PC, and a **game-version-compatible UE4SS runtime** installed in `Stalker2/Binaries/Win64/ue4ss` with a working loader.

The installer copies ZoneFPV only. It does not replace an existing UE4SS runtime, proxy DLL, engine signatures or other mods. This avoids silently breaking an existing mod installation. No compiler, Python or Visual C++ redistributable is required for the statically linked bridge.

- UE4SS upstream: https://github.com/UE4SS-RE/RE-UE4SS
- Compatibility fix used on the development machine: https://www.nexusmods.com/stalker2heartofchornobyl/mods/2341
- Follow the runtime author's instructions for your exact game update. A newer game update can require a different compatibility fix.
- The development installation uses base **UE4SS_v3.0.1-1028-gd7e7826d.zip**, with the game-specific compatibility fix. The base release is available through the upstream releases page: https://github.com/UE4SS-RE/RE-UE4SS/releases . Do not substitute an arbitrary stable UE4SS 3.0.1 ZIP.
- As checked on 2026-09-21, the compatibility page offers v1.2 for game patch 2.0.5. Its settings/signatures differ from the v1.1 installation used locally (including the FNameToString method). Follow that page for your version; do not reuse old INI settings blindly. ZoneFPV has not been retested against every compatibility patch.
- Third-party runtime/patch files are **not bundled**; this package does not assume permission to redistribute them.

If Windows App Control rejects the unsigned bridge, this package is not runnable under that policy until it is accepted through the computer's legitimate software approval process. The installer never disables security, adds exclusions, or modifies App Control. Code signing is not provided; testing on a clean machine remains outstanding.

Controllers: USB Joystick/HID via DirectInput; Xbox-compatible XInput; legacy WinMM. Sony USB HID devices are identified by Sony vendor ID. Bluetooth, adapters, Steam Input and custom transmitter models can expose different axes or virtual devices: select the actual interface in the Controller tab, then verify directions. Factory profiles are starting mappings, not measured calibration. Unknown devices can be calibrated manually using any four of the eight exposed axes.
