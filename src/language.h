#pragma once
namespace language {
inline int current=0;
struct Text{const wchar_t* ru;const wchar_t* uk;const wchar_t* en;const wchar_t* pl;const wchar_t* de;};
inline const Text texts[]={
{L"По умолчанию",L"За замовчуванням",L"Game default",L"Domyślny gry",L"Spielstandard"},
{L"Общий множитель до 5×: земля, здания, объекты, лес и дальние модели.\nБольшие значения повышают нагрузку и могут снижать FPS.\nПри выходе из FPV исходная дальность возвращается.",L"Загальний множник до 5×: земля, будівлі, об’єкти, ліс та далекі моделі.\nВеликі значення збільшують навантаження та можуть знижувати FPS.\nПісля виходу з FPV початкова дальність відновлюється.",L"Uniform multiplier up to 5×: terrain, buildings, props, trees and distant models.\nLarger values increase load and may reduce FPS.\nOriginal distances are restored on FPV exit.",L"Wspólny mnożnik do 5×: teren, budynki, obiekty, las i dalekie modele.\nWiększe wartości zwiększają obciążenie i mogą obniżać FPS.\nPo wyjściu z FPV wracają oryginalne zasięgi.",L"Einheitlicher Faktor bis 5×: Gelände, Gebäude, Objekte, Wald und Fernmodelle.\nHöhere Werte erhöhen die Last und können FPS senken.\nBeim Verlassen von FPV werden die Originalweiten wiederhergestellt."},
{L"Лимит объектов всей игры — gc.MaxObjectsInGame",L"Ліміт об’єктів усієї гри — gc.MaxObjectsInGame",L"Game-wide object limit — gc.MaxObjectsInGame",L"Limit obiektów całej gry — gc.MaxObjectsInGame",L"Objektlimit für das gesamte Spiel — gc.MaxObjectsInGame"},
{L"Сохранить в Engine.ini",L"Зберегти в Engine.ini",L"Save to Engine.ini",L"Zapisz w Engine.ini",L"In Engine.ini speichern"},
{L"В Engine.ini сохранён пользовательский лимит. Это не проверка текущего лимита игры.",L"В Engine.ini збережено власний ліміт. Це не перевірка поточного ліміту гри.",L"A custom limit is saved in Engine.ini. This does not verify the running game's limit.",L"W Engine.ini zapisano własny limit. To nie sprawdza limitu uruchomionej gry.",L"Engine.ini enthält ein eigenes Limit. Das bestätigt nicht das Limit des laufenden Spiels."},
{L"В Engine.ini лимит не задан. Число в поле — пример; нажмите сохранить для изменения.",L"В Engine.ini ліміт не задано. Число в полі — приклад; натисніть зберегти для зміни.",L"No override in Engine.ini. The field shows a suggestion; Save changes it.",L"Brak limitu w Engine.ini. Pole pokazuje przykład; Zapisz zmienia ustawienie.",L"Keine Vorgabe in Engine.ini. Das Feld zeigt einen Vorschlag; Speichern ändert den Wert."},
{L"Не удалось прочитать лимит из Engine.ini. Другие настройки не изменены.",L"Не вдалося прочитати ліміт з Engine.ini. Інші налаштування не змінено.",L"Cannot read the Engine.ini limit. Other settings were not changed.",L"Nie można odczytać limitu Engine.ini. Inne ustawienia pozostają bez zmian.",L"Das Engine.ini-Limit kann nicht gelesen werden. Andere Einstellungen bleiben unverändert."},
{L"Введите целое число от 1 до 2147483647, без разделителей.",L"Введіть ціле число від 1 до 2147483647 без роздільників.",L"Enter a whole number from 1 to 2147483647, without separators.",L"Wpisz liczbę całkowitą od 1 do 2147483647, bez separatorów.",L"Eine ganze Zahl von 1 bis 2147483647 ohne Trennzeichen eingeben."},
{L"Не удалось изменить Engine.ini. Подробности — в журнале программы ввода.",L"Не вдалося змінити Engine.ini. Подробиці — у журналі програми введення.",L"Cannot update Engine.ini. See the input-helper log for details.",L"Nie można zmienić Engine.ini. Szczegóły w dzienniku programu wejścia.",L"Engine.ini kann nicht geändert werden. Details stehen im Eingabeprogramm-Protokoll."},
{L"Пользовательский лимит удалён. Перезапустите игру для возврата её настроек.",L"Власний ліміт видалено. Перезапустіть гру для повернення її налаштувань.",L"Custom limit removed. Restart the game to use its default settings.",L"Własny limit usunięty. Uruchom grę ponownie, aby użyć jej ustawień domyślnych.",L"Eigenes Limit entfernt. Spiel neu starten, um die Standardwerte zu verwenden."},
{L"Лимит сохранён в Engine.ini. Перезапустите игру.",L"Ліміт збережено в Engine.ini. Перезапустіть гру.",L"Limit saved in Engine.ini. Restart the game.",L"Limit zapisany w Engine.ini. Uruchom grę ponownie.",L"Limit in Engine.ini gespeichert. Spiel neu starten."},
{L"Максимум Unreal-объектов в игре: акторов, компонентов, ресурсов.\nПовышение даёт запас для подгрузки, но не ускоряет игру.\nБольше объектов может увеличить расход RAM, время загрузки и паузы GC.\nСлишком маленький лимит может вызвать краш при запуске.\nИзменение действует на всю игру после перезапуска и остаётся после FPV.",L"Максимум Unreal-об’єктів у грі: акторів, компонентів, ресурсів.\nПідвищення дає запас для завантаження, але не прискорює гру.\nБільше об’єктів може збільшити витрати RAM, час завантаження та паузи GC.\nЗанадто малий ліміт може спричинити краш під час запуску.\nЗміна діє на всю гру після перезапуску й залишається після FPV.",L"Maximum Unreal objects: actors, components and resources.\nRaising it allows more loading; it does not speed up the game.\nMore objects may use more RAM, take longer to load and cause GC pauses.\nA very small limit may crash the game on startup.\nThis affects the whole game after restart and persists after FPV.",L"Maksymalna liczba obiektów Unreal: aktorów, komponentów i zasobów.\nWiększy limit pozwala wczytać więcej, ale nie przyspiesza gry.\nWięcej obiektów może zużywać więcej RAM i wydłużać ładowanie oraz pauzy GC.\nZbyt mały limit może spowodować awarię przy uruchamianiu.\nZmiana działa na całą grę po restarcie i pozostaje po wyjściu z FPV.",L"Maximale Unreal-Objekte: Akteure, Komponenten und Ressourcen.\nEin höheres Limit erlaubt mehr Laden; es beschleunigt das Spiel nicht.\nMehr Objekte können mehr RAM, längere Ladezeiten und GC-Pausen verursachen.\nEin sehr kleines Limit kann beim Spielstart zum Absturz führen.\nGilt nach Neustart für das ganze Spiel und bleibt nach FPV bestehen."},
{L"Engine.ini: %LOCALAPPDATA%/Stalker2/Saved/Config/Windows",L"Engine.ini: %LOCALAPPDATA%/Stalker2/Saved/Config/Windows",L"Engine.ini: %LOCALAPPDATA%/Stalker2/Saved/Config/Windows",L"Engine.ini: %LOCALAPPDATA%/Stalker2/Saved/Config/Windows",L"Engine.ini: %LOCALAPPDATA%/Stalker2/Saved/Config/Windows"},
{L"Дальность загрузки геометрии в FPV",L"Дальність завантаження геометрії у FPV",L"Geometry loading distance in FPV",L"Zasięg wczytywania geometrii w FPV",L"Geometrie-Ladedistanz in FPV"},

{L"Подгрузка карты вокруг дрона (эксперимент)",L"Завантаження карти навколо дрона (експеримент)",L"Map loading around drone (experimental)",L"Wczytywanie mapy wokół drona (eksperyment)",L"Karte um die Drohne laden (experimentell)"},
{L"Загружает участки мира; возможны просадки FPS.\nНе ограничивается только графикой. Начните с 200 м.",L"Завантажує ділянки світу; можливе падіння FPS.\nНе обмежується графікою. Почніть із 200 м.",L"Loads world cells; may reduce FPS.\nNot limited to graphics. Start with 200 m.",L"Wczytuje obszary świata; może obniżyć FPS.\nNie tylko grafika. Zacznij od 200 m.",L"Lädt Weltbereiche; kann FPS senken.\nNicht auf Grafik beschränkt. Mit 200 m beginnen."},

{L"Прорисовка",L"Промальовування",L"Rendering",L"Renderowanie",L"Darstellung"},
{L"Дальность объектов в FPV",L"Дальність об’єктів у FPV",L"Object draw distance in FPV",L"Zasięg obiektów w FPV",L"Objektsichtweite in FPV"},
{L"Детализация деревьев вдали",L"Деталізація дерев здалеку",L"Distant tree detail",L"Szczegóły odległych drzew",L"Details entfernter Bäume"},
{L"Как сейчас",L"Як зараз",L"Unchanged",L"Bez zmian",L"Unverändert"},
{L"Только в FPV. При выходе прежние значения возвращаются.\nБольше дальность и деталей — выше нагрузка, возможен меньший FPS.",L"Лише у FPV. Після виходу попередні значення відновлюються.\nБільша дальність і деталізація можуть знизити FPS.",L"Only in FPV. Previous values are restored on exit.\nGreater distance and detail may reduce FPS.",L"Tylko w FPV. Poprzednie wartości wracają po wyjściu.\nWiększy zasięg i szczegółowość mogą obniżyć FPS.",L"Nur in FPV. Vorherige Werte werden beim Verlassen wiederhergestellt.\nMehr Sichtweite und Details können die FPS senken."},
{L"Меняет отображение уже загруженных объектов.\nНе подгружает новые участки карты и не расширяет область NPC.\nЗагрузка мира выбирается отдельно во вкладке «Мир».",L"Змінює відображення вже завантажених об’єктів.\nНе завантажує нові ділянки карти та не розширює область NPC.\nЗавантаження світу обирається окремо у вкладці «Світ».",L"Changes rendering of already loaded objects.\nDoes not load new map cells or expand the NPC area.\nWorld loading is selected separately in the World tab.",L"Zmienia wygląd już wczytanych obiektów.\nNie wczytuje nowych obszarów ani nie zwiększa zasięgu NPC.\nWczytywanie świata wybiera się w zakładce Świat.",L"Ändert die Darstellung bereits geladener Objekte.\nLädt keine neuen Kartenbereiche und erweitert nicht den NPC-Bereich.\nWeltladen wird separat im Reiter Welt gewählt."},

{L"Альтернативный режим FPV",L"Альтернативний режим FPV",L"Alternative FPV mode",L"Alternatywny tryb FPV",L"Alternativer FPV-Modus"},
{L"По умолчанию: игрок скрыто следует за дроном для подгрузки мира и NPC.\nАльтернативный: игрок остаётся на старте; NPC вдали могут не появляться, некоторые стены могут пропускать камеру.",L"Типово: прихований гравець слідує за дроном для завантаження світу та NPC.\nАльтернативний: гравець лишається на старті; NPC вдалині можуть не з'являтися, деякі стіни можуть пропускати камеру.",L"Default: the hidden player follows the drone for world and NPC loading.\nAlternative: the player stays at the start; distant NPCs may not appear and some walls may let the camera through.",L"Domyślnie: ukryty gracz podąża za dronem, aby wczytywać świat i NPC.\nAlternatywnie: gracz zostaje na starcie; odlegli NPC mogą się nie pojawiać, a kamera może przenikać przez niektóre ściany.",L"Standard: Der unsichtbare Spieler folgt der Drohne zum Laden von Welt und NPCs.\nAlternativ: Spieler bleibt am Start; entfernte NPCs fehlen eventuell, manche Wände lassen die Kamera durch."},
{L"Правый стик: лево / право",L"Правий стік: ліворуч / праворуч",L"Right stick: left / right",L"Prawy drążek: lewo / prawo",L"Rechter Stick: links / rechts"},
{L"Правый стик: вниз / вверх",L"Правий стік: вниз / угору",L"Right stick: down / up",L"Prawy drążek: dół / góra",L"Rechter Stick: unten / oben"},
{L"Левый стик: вниз / вверх",L"Лівий стік: вниз / угору",L"Left stick: down / up",L"Lewy drążek: dół / góra",L"Linker Stick: unten / oben"},
{L"Левый стик: лево / право",L"Лівий стік: ліворуч / праворуч",L"Left stick: left / right",L"Lewy drążek: lewo / prawo",L"Linker Stick: links / rechts"},
{L"Удерживаю — подтвердить",L"Утримую — підтвердити",L"Holding — confirm",L"Trzymam — potwierdź",L"Gehalten — bestätigen"},
{L"Исходный профиль (Mode 2)",L"Початковий профіль (Mode 2)",L"Initial profile (Mode 2)",L"Profil początkowy (Mode 2)",L"Startprofil (Mode 2)"},
{L"Авто: распознать устройство",L"Авто: розпізнати пристрій",L"Auto: recognize device",L"Auto: rozpoznaj urządzenie",L"Auto: Gerät erkennen"},
{L"Применить исходный профиль",L"Застосувати початковий профіль",L"Apply initial profile",L"Zastosuj profil początkowy",L"Startprofil anwenden"},
{L"Нет точного автопрофиля. Выберите базовый профиль или калибруйте стики.",L"Немає точного автопрофілю. Виберіть базовий профіль або калібруйте стіки.",L"No exact auto profile. Select a base profile or calibrate sticks.",L"Brak dokładnego profilu. Wybierz profil bazowy lub skalibruj drążki.",L"Kein passendes Autoprofil. Basisprofil wählen oder Sticks kalibrieren."},
{L"Сначала завершите калибровку или закройте меню.",L"Спочатку завершіть калібрування або закрийте меню.",L"Finish calibration or close the menu first.",L"Najpierw zakończ kalibrację lub zamknij menu.",L"Zuerst Kalibrierung beenden oder Menü schließen."},
{L"Профиль задаёт начальную раскладку. Если направления не совпадают, выполните калибровку. Ваш прежний профиль сохраняется в резервную копию.",L"Профіль задає початкову розкладку. Якщо напрямки не збігаються, виконайте калібрування. Попередній профіль зберігається в резервну копію.",L"A profile provides initial mapping. Calibrate if directions differ. Your previous profile is backed up.",L"Profil ustawia początkowe osie. Skalibruj, jeśli kierunki są inne. Poprzedni profil zostanie zachowany.",L"Ein Profil legt die anfängliche Belegung fest. Bei falschen Richtungen bitte kalibrieren. Das bisherige Profil wird gesichert."},
{L"Правый стик ВПРАВО: удерживайте и нажмите кнопку.",L"Правий стік ПРАВОРУЧ: утримуйте й натисніть кнопку.",L"RIGHT stick RIGHT: hold and press the button.",L"PRAWY drążek W PRAWO: przytrzymaj i naciśnij przycisk.",L"RECHTEN Stick RECHTS halten und bestätigen."},
{L"Правый стик ВВЕРХ: удерживайте и нажмите кнопку.",L"Правий стік УГОРУ: утримуйте й натисніть кнопку.",L"RIGHT stick UP: hold and press the button.",L"PRAWY drążek W GÓRĘ: przytrzymaj i naciśnij przycisk.",L"RECHTEN Stick OBEN halten und bestätigen."},
{L"Левый стик ВПРАВО: удерживайте и нажмите кнопку.",L"Лівий стік ПРАВОРУЧ: утримуйте й натисніть кнопку.",L"LEFT stick RIGHT: hold and press the button.",L"LEWY drążek W PRAWO: przytrzymaj i naciśnij przycisk.",L"LINKEN Stick RECHTS halten und bestätigen."},
{L"Левый стик ВВЕРХ: удерживайте и нажмите кнопку.",L"Лівий стік УГОРУ: утримуйте й натисніть кнопку.",L"LEFT stick UP: hold and press the button.",L"LEWY drążek W GÓRĘ: przytrzymaj i naciśnij przycisk.",L"LINKEN Stick OBEN halten und bestätigen."},
{L"Подключено",L"Підключено",L"Connected",L"Połączono",L"Verbunden"},
{L"Не подключено",L"Не підключено",L"Disconnected",L"Rozłączono",L"Nicht verbunden"},
{L"Устройство управления",L"Пристрій керування",L"Controller",L"Kontroler",L"Controller"},
{L"Разрешить вход с поднятым газом",L"Дозволити вхід із піднятим газом",L"Allow entry with throttle above zero",L"Start z gazem powyżej zera",L"FPV-Start mit Gas über Null erlauben"},
{L"Новое устройство: сначала откалибруйте оси.\nXbox: правый стик — крен/тангаж, левый — газ/рыскание.\nОдно устройство может иметь несколько интерфейсов.",L"Новий пристрій: спочатку калібруйте осі.\nXbox: правий стік — крен/тангаж, лівий — газ/рискання.\nПристрій може мати кілька інтерфейсів.",L"New device: calibrate axes first.\nXbox: right stick = roll/pitch, left = throttle/yaw.\nOne controller may expose multiple interfaces.",L"Nowe urządzenie: skalibruj osie.\nXbox: prawy drążek = przechylenie/pochylenie, lewy = gaz/obrót.\nUrządzenie może mieć kilka interfejsów.",L"Neues Gerät: zunächst Achsen kalibrieren. Xbox: rechts Rollen/Nicken, links Gas/Gieren. Ein Gerät kann mehrere Schnittstellen haben."},
{L"ZoneFPV — настройки",L"ZoneFPV — налаштування",L"ZoneFPV — settings",L"ZoneFPV — ustawienia",L"ZoneFPV — Einstellungen"},
{L"Время суток",L"Час доби",L"Time of day",L"Pora dnia",L"Tageszeit"},
{L"Установить время",L"Установити час",L"Set time",L"Ustaw czas",L"Zeit einstellen"},
{L"Погода",L"Погода",L"Weather",L"Pogoda",L"Wetter"},
{L"Установить погоду",L"Установити погоду",L"Set weather",L"Ustaw pogodę",L"Wetter einstellen"},
{L"Ясно",L"Ясно",L"Clear",L"Bezchmurnie",L"Klar"},
{L"Облачно",L"Хмарно",L"Cloudy",L"Pochmurno",L"Bewölkt"},
{L"Туман",L"Туман",L"Fog",L"Mgła",L"Nebel"},
{L"Небольшой дождь",L"Невеликий дощ",L"Light rain",L"Lekki deszcz",L"Leichter Regen"},
{L"Дождь",L"Дощ",L"Rain",L"Deszcz",L"Regen"},
{L"Гроза",L"Гроза",L"Thunderstorm",L"Burza",L"Gewitter"},
{L"Шторм",L"Шторм",L"Storm",L"Nawałnica",L"Sturm"},
{L"Во время выбора FPV-камера неподвижна.\nЗначения выше — ваш выбор, не показания игры.",L"Під час налаштування FPV-камера нерухома.\nВище — ваш вибір, а не поточний стан гри.",L"FPV holds position while this menu is open.\nValues above are your selection, not game readings.",L"Kamera FPV stoi podczas ustawiania.\nPowyżej jest wybór, a nie bieżący stan gry.",L"Die FPV-Kamera bleibt im Menü stehen. Die Werte zeigen Ihre Auswahl, keine aktuellen Spielwerte."},
{L"Скорость (2× — прежняя)",L"Швидкість (2× — початкова)",L"Speed (2× — original)",L"Prędkość (2× — pierwotna)",L"Geschwindigkeit (2× — ursprünglich)"},
{L"Наклон камеры",L"Нахил камери",L"Camera tilt",L"Nachylenie kamery",L"Kameraneigung"},
{L"Применить к FPV",L"Застосувати до FPV",L"Apply to FPV",L"Zastosuj do FPV",L"Auf FPV anwenden"},
{L"Громкость дрона",L"Гучність дрона",L"Drone volume",L"Głośność drona",L"Drohnenlautstärke"},
{L"Выключен",L"Вимкнено",L"Off",L"Wyłączony",L"Aus"},
{L"Аналоговая FPV-камера",L"Аналогова FPV-камера",L"Analog FPV camera",L"Analogowa kamera FPV",L"Analoge FPV-Kamera"},
{L"Сильно замедлить мир в FPV",L"Сильно сповільнити світ у FPV",L"Slow world to near-freeze in FPV",L"Silnie spowolnij świat w FPV",L"Welt in FPV stark verlangsamen"},
{L"FPV со свойствами игрока",L"FPV із властивостями гравця",L"FPV with player properties",L"FPV z właściwościami gracza",L"FPV mit Spielereigenschaften"},
{L"Режим бога",L"Режим бога",L"God mode",L"Tryb boga",L"Unverwundbarkeit"},
{L"Свойства игрока: скрытый персонаж следует за дроном и затем\nвозвращается; NPC не должны видеть его или реагировать на него.",L"Прихований персонаж слідує за дроном під землею.\nПісля виходу він повертається на місце старту.",L"The hidden player follows the drone underground.\nExiting FPV returns the player to the launch point.",L"Ukryty gracz podąża za dronem pod ziemią.\nWyjście z FPV przywraca pozycję startową.",L"Der unsichtbare Spieler folgt der Drohne unterirdisch. Beim Verlassen von FPV kehrt er zum Start zurück."},
{L"Калибровать оси",L"Калібрувати осі",L"Calibrate axes",L"Kalibruj osie",L"Achsen kalibrieren"},
{L"Закрыть / F6",L"Закрити / F6",L"Close / F6",L"Zamknij / F6",L"Schließen / F6"},
{L"Выберите настройки и нажмите кнопку.",L"Виберіть налаштування та натисніть кнопку.",L"Choose settings and press a button.",L"Wybierz ustawienia i naciśnij przycisk.",L"Einstellungen wählen und Taste drücken."},
{L"Не удалось отправить. Повторите.",L"Не вдалося надіслати. Повторіть.",L"Send failed. Please retry.",L"Nie udało się wysłać. Spróbuj ponownie.",L"Senden fehlgeschlagen. Erneut versuchen."},
{L"Ожидание игры...",L"Очікування гри...",L"Waiting for game...",L"Oczekiwanie na grę...",L"Warte auf das Spiel …"},
{L"Команда передана игре.",L"Команду передано грі.",L"Applied by the mod.",L"Zastosowano w modzie.",L"Vom Mod angewendet."},
{L"Не применено: загрузите сохранение и повторите.",L"Не застосовано: завантажте збереження і повторіть.",L"Not applied: load a save and retry.",L"Nie zastosowano: wczytaj zapis i ponów.",L"Nicht angewendet: Spielstand laden und erneut versuchen."},
{L"Нет ответа мода. Перезапустите игру.",L"Мод не відповідає. Перезапустіть гру.",L"Mod not responding. Restart the game.",L"Mod nie odpowiada. Uruchom grę ponownie.",L"Mod antwortet nicht. Spiel neu starten."},
{L"Зафиксировать нейтраль",L"Зберегти нейтраль",L"Capture neutral",L"Zapisz pozycję neutralną",L"Neutralstellung erfassen"},
{L"Стики по центру, газ полностью вниз. Затем нажмите кнопку ещё раз.",L"Стіки по центру, газ повністю вниз. Потім натисніть кнопку ще раз.",L"Center sticks, throttle fully down. Then press the button again.",L"Wycentruj drążki, gaz na minimum. Naciśnij ponownie.",L"Sticks zentrieren, Gas ganz nach unten. Dann erneut drücken."},
{L"Контроллер не подключён.",L"Контролер не підключено.",L"Controller disconnected.",L"Kontroler nie jest podłączony.",L"Controller nicht verbunden."},
{L"Идёт измерение...",L"Триває вимірювання...",L"Measuring...",L"Pomiar...",L"Messung läuft …"},
{L"Ось не распознана. Нажмите калибровку и повторите.",L"Вісь не розпізнано. Повторіть калібрування.",L"Axis not detected. Restart calibration.",L"Nie wykryto osi. Powtórz kalibrację.",L"Achse nicht erkannt. Kalibrierung neu starten."},
{L"В конце нужно удерживать указанное направление. Повторите.",L"Наприкінці утримуйте вказаний напрямок. Повторіть.",L"Hold the requested direction at the end. Retry.",L"Na końcu przytrzymaj wskazany kierunek. Powtórz.",L"Zum Schluss die angegebene Richtung halten und wiederholen."},
{L"Верните стики в исходное положение, затем начните следующую ось.",L"Поверніть стіки у вихідне положення та почніть наступну вісь.",L"Return sticks to neutral, then start the next axis.",L"Wróć do pozycji neutralnej i rozpocznij kolejną oś.",L"Sticks in Ausgangsstellung bringen, dann nächste Achse starten."},
{L"Начать: крен",L"Почати: крен",L"Start: roll",L"Rozpocznij: przechylenie",L"Start: rechter Stick links/rechts"},
{L"Начать: тангаж",L"Почати: тангаж",L"Start: pitch",L"Rozpocznij: pochylenie",L"Start: rechter Stick unten/oben"},
{L"Начать: газ",L"Почати: газ",L"Start: throttle",L"Rozpocznij: gaz",L"Start: linker Stick unten/oben"},
{L"Начать: рыскание",L"Почати: рискання",L"Start: yaw",L"Rozpocznij: obrót",L"Start: linker Stick links/rechts"},
{L"Не удалось сохранить calibration.lua.",L"Не вдалося зберегти калібрування.",L"Could not save calibration.",L"Nie można zapisać kalibracji.",L"Kalibrierung konnte nicht gespeichert werden."},
{L"Калибровка сохранена и применяется к FPV.",L"Калібрування збережено та застосовується до FPV.",L"Calibration saved; applying to FPV.",L"Zapisano kalibrację; stosowanie w FPV.",L"Kalibrierung gespeichert und auf FPV angewendet."},
{L"Редактор OSD",L"Редактор OSD",L"OSD editor",L"Edytor OSD",L"OSD-Editor"},
{L"Speed / km/h",L"Швидкість / км/год",L"Speed / km/h",L"Prędkość / km/h",L"Geschwindigkeit / km/h"},
{L"Altitude / m (home)",L"Висота / м (від старту)",L"Altitude / m (home)",L"Wysokość / m (od startu)",L"Höhe / m (Startpunkt)"},
{L"Home distance / m",L"Відстань додому / м",L"Home distance / m",L"Odległość od startu / m",L"Entfernung zum Start / m"},
{L"Artificial horizon",L"Штучний горизонт",L"Artificial horizon",L"Sztuczny horyzont",L"Künstlicher Horizont"},
{L"Crosshair",L"Перехрестя",L"Crosshair",L"Celownik",L"Fadenkreuz"},
{L"Flight timer",L"Час польоту",L"Flight timer",L"Czas lotu",L"Flugzeit"},
{L"Heading / degrees",L"Курс / градуси",L"Heading / degrees",L"Kurs / stopnie",L"Kurs / Grad"},
{L"Home direction",L"Напрямок додому",L"Home direction",L"Kierunek do startu",L"Richtung zum Start"},
{L"Throttle / %",L"Газ / %",L"Throttle / %",L"Gaz / %",L"Gas / %"},
{L"Vertical speed / m/s",L"Вертикальна швидкість / м/с",L"Vertical speed / m/s",L"Prędkość pionowa / m/s",L"Vertikalgeschwindigkeit / m/s"},
{L"OSD on",L"Увімкнути OSD",L"OSD on",L"Włącz OSD",L"OSD aktiv"},
{L"Visible",L"Показувати",L"Visible",L"Widoczny",L"Sichtbar"},
{L"Size (14-72)",L"Розмір (14-72)",L"Size (14-72)",L"Rozmiar (14-72)",L"Größe (14–72)"},
{L"White",L"Білий",L"White",L"Biały",L"Weiß"},
{L"Green",L"Зелений",L"Green",L"Zielony",L"Grün"},
{L"Yellow",L"Жовтий",L"Yellow",L"Żółty",L"Gelb"},
{L"Cyan",L"Блакитний",L"Cyan",L"Błękitny",L"Cyan"},
{L"Red",L"Червоний",L"Red",L"Czerwony",L"Rot"},
{L"Cross +",L"Перехрестя +",L"Cross +",L"Krzyżyk +",L"Kreuz +"},
{L"Dot",L"Крапка",L"Dot",L"Kropka",L"Punkt"},
{L"Split cross",L"Розділене перехрестя",L"Split cross",L"Rozdzielony krzyżyk",L"Geteiltes Kreuz"},
{L"Reset layout",L"Скинути розкладку",L"Reset layout",L"Resetuj układ",L"Layout zurücksetzen"},
{L"Save / close",L"Зберегти / закрити",L"Save / close",L"Zapisz / zamknij",L"Speichern / schließen"},
{L"Drag elements. Changes are saved automatically. Preview uses sample values when not flying.",L"Перетягуйте елементи. Зміни зберігаються автоматично. Поза польотом показано приклад.",L"Drag elements. Changes are saved automatically. Preview uses sample values when not flying.",L"Przeciągaj elementy. Zmiany zapisują się automatycznie. Poza lotem widać przykładowe dane.",L"Elemente ziehen. Änderungen werden automatisch gespeichert. Außerhalb des Flugs werden Beispielwerte angezeigt."},
{L"Полёт",L"Політ",L"Flight",L"Lot",L"Flug"},
{L"Контроллер",L"Контролер",L"Controller",L"Kontroler",L"Controller"},
{L"Мир",L"Світ",L"World",L"Świat",L"Welt"},
{L"Интерфейс",L"Інтерфейс",L"Interface",L"Interfejs",L"Oberfläche"},
{L"Режим полёта",L"Режим польоту",L"Flight mode",L"Tryb lotu",L"Flugmodus"},
{L"Закрыть",L"Закрити",L"Close",L"Zamknij",L"Schließen"},
{L"Вид аналоговой камеры",L"Стиль аналогової камери",L"Analog camera style",L"Styl kamery analogowej",L"Analoger Kamerastil"},
{L"Тёмная тема",L"Темна тема",L"Dark theme",L"Ciemny motyw",L"Dunkles Design"},
{L"Светлая тема",L"Світла тема",L"Light theme",L"Jasny motyw",L"Helles Design"},
{L"Открыть меню",L"Відкрити меню",L"Open menu",L"Otwórz menu",L"Menü öffnen"},
{L"Войти / выйти из FPV",L"Увійти / вийти з FPV",L"Enter / exit FPV",L"Wejdź / wyjdź z FPV",L"FPV ein / aus"},
{L"Вернуть дрон к старту",L"Повернути дрон до старту",L"Reset drone to launch",L"Wróć dronem do startu",L"Drohne zum Start zurücksetzen"},
{L"Применить кнопки",L"Застосувати кнопки",L"Apply keys",L"Zastosuj klawisze",L"Tasten anwenden"},
{L"Для каждого действия выберите отдельную кнопку.",L"Для кожної дії виберіть окрему кнопку.",L"Choose a different key for each action.",L"Wybierz inny klawisz dla każdej akcji.",L"Für jede Aktion eine andere Taste wählen."},
{L"Выберите разные кнопки. Изменения применяются при запущенной игре.",L"Виберіть різні кнопки. Зміни застосовуються, коли гру запущено.",L"Choose distinct keys. Changes apply while the game is running.",L"Wybierz różne klawisze. Zmiany działają przy uruchomionej grze.",L"Unterschiedliche Tasten wählen. Änderungen werden bei laufendem Spiel angewendet."},
{L"Контроллер не подключён. Выберите подключённое устройство.",L"Контролер не підключено. Виберіть підключений пристрій.",L"Controller disconnected. Select a connected device.",L"Kontroler odłączony. Wybierz podłączone urządzenie.",L"Controller getrennt. Ein verbundenes Gerät wählen."},
{L"Новое устройство: выберите профиль или откалибруйте стики.",L"Новий пристрій: виберіть профіль або калібруйте стіки.",L"New device: select a profile or calibrate sticks.",L"Nowe urządzenie: wybierz profil lub skalibruj drążki.",L"Neues Gerät: Profil wählen oder Sticks kalibrieren."},
{L"Исходный профиль: проверьте направления. Если они неверны — калибруйте.",L"Початковий профіль: перевірте напрямки. Якщо неправильні — калібруйте.",L"Initial profile: check directions. Calibrate if incorrect.",L"Profil początkowy: sprawdź kierunki. Skalibruj, jeśli są błędne.",L"Startprofil: Richtungen prüfen. Bei Abweichungen kalibrieren."},
{L"Angle: выравнивание. Acro: свободное вращение.\n3D: середина газа — ноль, ниже — обратная тяга.\nСмена режима завершает полёт; войдите в FPV снова.",L"Angle: вирівнювання. Acro: вільне обертання.\n3D: середина газу — нуль, нижче — зворотна тяга.\nЗміна режиму завершує політ; увійдіть у FPV знову.",L"Angle: self-leveling. Acro: free rotation.\n3D: center throttle is zero; below is reverse thrust.\nChanging mode ends flight; enter FPV again.",L"Angle: poziomowanie. Acro: swobodny obrót.\n3D: środek gazu to zero, poniżej ciąg odwrotny.\nZmiana trybu kończy lot; włącz FPV ponownie.",L"Angle: Selbstnivellierung. Acro: freie Drehung.\n3D: Gasmitte ist Null, darunter Umkehrschub.\nModuswechsel beendet den Flug; FPV erneut aktivieren."},
};
inline const wchar_t* tr(const wchar_t* text){
    if(current==0){
        const wchar_t* ru[][2]={{L"Speed / km/h",L"Скорость / км/ч"},{L"Altitude / m (home)",L"Высота / м (от старта)"},{L"Home distance / m",L"Расстояние домой / м"},{L"Artificial horizon",L"Искусственный горизонт"},{L"Crosshair",L"Перекрестие"},{L"Flight timer",L"Время полёта"},{L"Heading / degrees",L"Курс / градусы"},{L"Home direction",L"Направление домой"},{L"Throttle / %",L"Газ / %"},{L"Vertical speed / m/s",L"Вертикальная скорость / м/с"},{L"OSD on",L"Включить OSD"},{L"Visible",L"Показывать"},{L"Size (14-72)",L"Размер (14–72)"},{L"White",L"Белый"},{L"Green",L"Зелёный"},{L"Yellow",L"Жёлтый"},{L"Cyan",L"Голубой"},{L"Red",L"Красный"},{L"Cross +",L"Перекрестие +"},{L"Dot",L"Точка"},{L"Split cross",L"Раздельное перекрестие"},{L"Reset layout",L"Сбросить раскладку"},{L"Save / close",L"Сохранить / закрыть"},{L"Drag elements. Changes are saved automatically. Preview uses sample values when not flying.",L"Перетаскивайте элементы. Изменения сохраняются автоматически. Вне полёта показан пример."}};
        for(const auto& t:ru)if(wcscmp(t[0],text)==0)return t[1];
    }
    for(const auto& t:texts)if(wcscmp(t.ru,text)==0){return current==1?t.uk:current==2?t.en:current==3?t.pl:current==4?t.de:t.ru;}return text;
}
inline BOOL set(HWND h,const wchar_t* text){return SetWindowTextW(h,tr(text));}
inline const wchar_t* translateAny(const wchar_t* text){for(const auto& t:texts)if(wcscmp(t.ru,text)==0||wcscmp(t.uk,text)==0||wcscmp(t.en,text)==0||wcscmp(t.pl,text)==0||wcscmp(t.de,text)==0)return tr(t.ru);return text;}
inline void relabel(HWND window){
    wchar_t title[512]{};GetWindowTextW(window,title,512);SetWindowTextW(window,translateAny(title));
    EnumChildWindows(window,[](HWND child,LPARAM)->BOOL{
        wchar_t cls[64]{};GetClassNameW(child,cls,64);
        if(wcscmp(cls,L"ComboBox")==0){
            const auto count=SendMessageW(child,CB_GETCOUNT,0,0),selected=SendMessageW(child,CB_GETCURSEL,0,0);
            for(LRESULT i=0;i<count;++i){wchar_t text[512]{};if(SendMessageW(child,CB_GETLBTEXTLEN,i,0)>=511)continue;SendMessageW(child,CB_GETLBTEXT,i,reinterpret_cast<LPARAM>(text));const std::wstring translated=translateAny(text);const auto data=SendMessageW(child,CB_GETITEMDATA,i,0);SendMessageW(child,CB_DELETESTRING,i,0);const auto inserted=SendMessageW(child,CB_INSERTSTRING,i,reinterpret_cast<LPARAM>(translated.c_str()));SendMessageW(child,CB_SETITEMDATA,inserted,data);}
            SendMessageW(child,CB_SETCURSEL,selected,0);
        }else{wchar_t text[512]{};GetWindowTextW(child,text,512);SetWindowTextW(child,translateAny(text));}
        return TRUE;
    },0);
}
inline LRESULT message(HWND h,UINT msg,WPARAM wp,LPARAM lp){if((msg==CB_ADDSTRING||msg==LB_ADDSTRING)&&lp)lp=reinterpret_cast<LPARAM>(tr(reinterpret_cast<const wchar_t*>(lp)));return SendMessageW(h,msg,wp,lp);}
}
