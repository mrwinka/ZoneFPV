#pragma once
namespace language {
inline int current=0;
struct Text{const wchar_t* ru;const wchar_t* uk;const wchar_t* en;const wchar_t* pl;const wchar_t* de;};
inline const Text texts[]={
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
{L"Заморозить мир в FPV",L"Заморозити світ у FPV",L"Freeze world in FPV",L"Zamroź świat w FPV",L"Welt im FPV-Modus anhalten"},
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
