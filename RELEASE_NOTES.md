# ZoneFPV 0.2.0 RC4 — 2026-10-02

Includes the complete installer, native helper, source and licenses. Compatible UE4SS is required separately.

Changes relative to RC3:

- Main FPV is the default, with clearer guidance for the alternative mode.
- Stronger sphere collision; player, weapon and subtitle hiding with state restoration; protection from NPC/mutant detection while preserving their fights with each other.
- Weather/time changes preserve drone position. World freeze keeps FPV usable, and closing F6 or losing focus keeps FPV active.
- Uniform geometry loading from 1× through 5× across all ten original grids, with exact restoration on exit.
- Explicit DualShock 4 DirectInput profile and less repeated physics, presentation, audio and OSD work. Physics remains at 240 Hz with all collision queries; in-game FPS gains have not been measured.

The rendering menu offers optional manual `gc.MaxObjectsInGame` input, **Save to Engine.ini** and **Game default**. A requested change backs up existing Engine.ini and preserves unrelated settings. This startup setting affects the whole game after a full restart. Higher capacity may increase RAM use, loading time and garbage collection pauses. Installation/startup do not change it automatically. See [OBJECT_LIMIT.md](OBJECT_LIMIT.md).

The CNPP black anomaly effect remains unresolved. Quest checkpoint fog is unchanged. Unloaded geometry and missing collision remain possible; higher loading multipliers can reduce FPS and increase RAM use. Physical DS4 testing is pending. The user reports that the tested RC4 build appears to work; actual startup object capacity remains unverified, and stability is not guaranteed.

Install with the game closed: extract the ZIP and run **Setup.cmd**. Preferences are preserved. **F6** opens the menu, **F8** toggles FPV, **F9** resets. Detailed changes: [CHANGELOG.md](CHANGELOG.md); installation: [SITE_INSTALL.md](SITE_INSTALL.md).

## Русский

ZoneFPV 0.2.0 RC4 от 2026-10-02. В архиве — установщик, нативный помощник, исходники и лицензии. Совместимый UE4SS нужен отдельно.

По сравнению с RC3:

- Основной FPV выбран по умолчанию; пояснения к альтернативному режиму стали понятнее.
- Усилены столкновения; скрываются игрок, оружие и субтитры с восстановлением состояния. NPC/мутанты не реагируют на игрока в FPV, но продолжают сражаться друг с другом.
- Смена погоды/времени сохраняет позицию дрона. Заморозка мира оставляет FPV рабочим; закрытие F6 и потеря фокуса сохраняют FPV.
- Равномерная подгрузка геометрии от 1× до 5× для всех десяти исходных сеток с точным восстановлением при выходе.
- Добавлен профиль DualShock 4 DirectInput и сокращена повторная работа физики, интерфейса, звука и OSD. Физика остаётся на 240 Гц со всеми проверками столкновений; прирост игрового FPS не измерен.

В меню «Прорисовка» доступен необязательный ручной ввод `gc.MaxObjectsInGame`, сохранение в Engine.ini и возврат к настройкам игры. Изменение выполняется только по явному действию пользователя: существующий Engine.ini резервируется, посторонние настройки сохраняются. Параметр действует на всю игру после полного перезапуска. Повышение лимита может увеличить расход RAM, время загрузки и паузы очистки памяти. Установка/запуск не меняют его автоматически. Подробности: [OBJECT_LIMIT.md](OBJECT_LIMIT.md).

Чёрный эффект аномалии у ЧАЭС не исправлен; квестовый туман у КПП оставлен. Неподгруженная геометрия и отсутствующие коллизии остаются возможными. Большой множитель может снизить FPS и увеличить расход RAM. Физический DS4 ещё не проверен. По сообщению пользователя, проверенная сборка RC4 работает; фактический лимит объектов после запуска не подтверждён, стабильность не гарантируется.

Установка при закрытой игре: распаковать ZIP → **Setup.cmd**. Настройки сохраняются. **F6** — меню, **F8** — переключение FPV, **F9** — сброс.
