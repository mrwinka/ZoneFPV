# ZoneFPV 0.2.0 — 2026-10-03

Stable release, verified in game by the author. The full download includes the installer, native helper, source and licenses. Compatible UE4SS is required separately.

Changes since RC3:

- Main FPV is now the default, with an explained alternative mode. Stronger simple/complex sphere collision checks use both the trace channel and player profile.
- Hide the player, weapon, shadow and subtitles during FPV; restore saved player/UI states on exit. Isolate player detection without stopping NPCs and mutants from fighting each other.
- Keep drone position when changing weather/time. World freeze remains usable, and closing F6 or losing game focus keeps FPV active.
- Add uniform geometry loading multipliers from 1× to 5× across all ten original streaming grids, restoring their original settings on exit.
- Add a DualShock 4 DirectInput profile. Physical DS4 testing is still pending.
- Preserve rain, falling leaves and crows across the FPV transition, with bounded recovery when the game replaces particle components.
- Resize or maximize the F6 menu and OSD settings window, with saved dimensions and scaled controls/fonts. The OSD preview follows the game's aspect ratio without changing saved element positions.
- Restore the game HUD immediately after leaving FPV; opening and closing Esc/settings is no longer needed.
- Reduce repeated physics, camera, UI, audio and particle work while keeping 240 Hz physics and all collision checks. Improve state restoration and installation rollback; remove obsolete diagnostics from the package.

The Rendering menu also offers optional manual `gc.MaxObjectsInGame` input, **Save to Engine.ini** and **Game default**. This is the game's startup object-capacity setting: changes affect the whole game after a full restart. Existing Engine.ini is backed up before a requested change, and unrelated settings are preserved. Higher capacity can increase RAM use, loading time and garbage collection pauses. Installation/startup do not change it automatically. See [OBJECT_LIMIT.md](https://github.com/mrwinka/ZoneFPV/blob/main/OBJECT_LIMIT.md).

Known limitations: the black anomaly effect near CNPP remains unresolved, and checkpoint quest fog is unchanged. Unloaded geometry and missing collision remain possible. Higher loading multipliers can reduce FPS and increase RAM use. Actual startup object capacity has not been verified, and no numerical FPS improvement is claimed.

Install with the game closed: extract the full ZIP and run **Setup.cmd**. Existing preferences are preserved. **F6** opens the menu, **F8** toggles FPV and **F9** resets. [Installation and troubleshooting (EN/RU)](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md) · [Full changelog](https://github.com/mrwinka/ZoneFPV/blob/main/CHANGELOG.md)

## Русский

**ZoneFPV 0.2.0 — стабильный выпуск от 3 октября 2026.** Автор проверил сборку в игре. Полный архив содержит установщик, нативный помощник, исходники и лицензии. Совместимый UE4SS нужно установить отдельно.

По сравнению с RC3:

- Основной FPV теперь выбран по умолчанию; к альтернативному режиму добавлено объяснение. Усилены простые и сложные проверки столкновений сферой с использованием канала трассировки и профиля игрока.
- Во время FPV скрываются игрок, оружие, тень и субтитры; после выхода восстанавливается сохранённое состояние игрока и интерфейса. NPC и мутанты не обнаруживают игрока в FPV, но продолжают сражаться друг с другом.
- Смена погоды/времени сохраняет положение дрона. Заморозка мира оставляет FPV рабочим; закрытие F6 и потеря фокуса игры не выключают FPV.
- Добавлены равномерные множители подгрузки геометрии от 1× до 5× для всех десяти исходных сеток. При выходе возвращаются исходные настройки.
- Добавлен профиль DualShock 4 DirectInput; проверка на физическом DS4 ещё не выполнена.
- При переходе в FPV сохраняются дождь, падающие листья и вороны. Если игра заменяет компоненты частиц, используется ограниченный повторный поиск.
- Окна F6 и настроек OSD можно растягивать и разворачивать. Размер сохраняется, элементы и шрифты масштабируются. Предпросмотр OSD учитывает пропорции игрового окна и не меняет сохранённые позиции элементов.
- Игровой HUD возвращается сразу после выхода из FPV; открывать и закрывать настройки через Esc больше не требуется.
- Сокращена повторная работа физики, камеры, интерфейса, звука и частиц при сохранении физики 240 Гц и всех проверок столкновений. Улучшены восстановление состояния и откат неудачной установки; устаревшая диагностика исключена из пакета.

В меню «Прорисовка» также доступен необязательный ручной ввод `gc.MaxObjectsInGame`, сохранение в Engine.ini и возврат к настройкам игры. Это лимит объектов движка при запуске: изменение действует на всю игру после полного перезапуска. Перед изменением существующий Engine.ini резервируется, посторонние настройки сохраняются. Повышение лимита может увеличить расход RAM, время загрузки и паузы очистки памяти. Установка и обычный запуск не меняют параметр автоматически. [Подробнее о лимите объектов](https://github.com/mrwinka/ZoneFPV/blob/main/OBJECT_LIMIT.md).

Известные ограничения: чёрный эффект аномалии у ЧАЭС не исправлен; квестовый туман у КПП оставлен. Неподгруженная геометрия и отсутствующие коллизии остаются возможными. Большой множитель может снизить FPS и увеличить расход RAM. Фактическая ёмкость объектов после запуска не подтверждена; численный прирост FPS не заявляется.

Установка при закрытой игре: распаковать полный ZIP → **Setup.cmd**. Настройки сохраняются. **F6** — меню, **F8** — переключение FPV, **F9** — сброс. [Установка и устранение неполадок (EN/RU)](https://github.com/mrwinka/ZoneFPV/blob/main/SITE_INSTALL.md) · [Журнал изменений](https://github.com/mrwinka/ZoneFPV/blob/main/CHANGELOG.md)
