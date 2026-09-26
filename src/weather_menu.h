#pragma once
#include <sstream>
#include <atomic>
#include <deque>
#define SetWindowTextW language::set
#define SendMessageW language::message
namespace weatherMenu {
inline std::atomic<HWND> window{nullptr};
inline HWND hours=nullptr,minutes=nullptr,weather=nullptr,status=nullptr,previousWindow=nullptr,volume=nullptr;
inline HWND speed=nullptr,tilt=nullptr,analog=nullptr;
inline HWND modeBox=nullptr,styleBox=nullptr,themeBox=nullptr,keyBoxes[3]{},warning=nullptr;
inline unsigned menuKey=VK_F6;
inline int buildingPage=0,currentPage=0;
inline std::vector<std::pair<HWND,int>> pageControls;
inline std::vector<unsigned> keyCodes;
inline void selectPage(int page){currentPage=page;for(const auto& item:pageControls)ShowWindow(item.first,item.second<0||item.second==page?SW_SHOW:SW_HIDE);}
inline HWND calibrationButton=nullptr,languageBox=nullptr,profileBox=nullptr;
inline std::atomic<bool> joystickConnected{false};
inline HWND gameWindow=nullptr,deviceBox=nullptr,deviceStatus=nullptr,hotStart=nullptr;
inline fs::path root;
inline ULONGLONG nextDeviceRefresh=0;
inline void refreshDevices(){
    if(!deviceBox||SendMessageW(deviceBox,CB_GETDROPPEDSTATE,0,0))return;
    SendMessageW(deviceBox,CB_RESETCONTENT,0,0);
    const auto selectedDevice=controllers::requested.load();
    std::wstring label=language::tr(joystickConnected?L"Подключено":L"Не подключено");
    std::lock_guard<std::mutex> lock(controllers::mutex);
    bool found=false;
    for(const auto& d:controllers::available){auto index=SendMessageW(deviceBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(d.name.c_str()));SendMessageW(deviceBox,CB_SETITEMDATA,index,d.id);if(d.id==selectedDevice){SendMessageW(deviceBox,CB_SETCURSEL,index,0);label+=L": "+d.name;found=true;}}
    if(!found&&selectedDevice){std::wstring missing=L"ID "+std::to_wstring(selectedDevice);auto index=SendMessageW(deviceBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(missing.c_str()));SendMessageW(deviceBox,CB_SETITEMDATA,index,selectedDevice);SendMessageW(deviceBox,CB_SETCURSEL,index,0);}
    SetWindowTextW(deviceStatus,label.c_str());
    std::wstring note;
    if(!joystickConnected)note=language::tr(L"Контроллер не подключён. Выберите подключённое устройство.");
    else {
        const auto profile=root/("calibration-"+std::to_string(selectedDevice)+".lua");
        std::ifstream f(profile);std::string first;std::getline(f,first);
        if(!f)note=language::tr(L"Новое устройство: выберите профиль или откалибруйте стики.");
        else if(first.find("Initial Mode 2")!=std::string::npos)note=language::tr(L"Исходный профиль: проверьте направления. Если они неверны — калибруйте.");
    }
    SetWindowTextW(warning,note.c_str());
}
inline void show();
inline HWND worldOptions[3]={nullptr,nullptr,nullptr};
inline const char* optionNames[]={"freeze","npcs","god"};
inline const char* speedValues[]={"0.5","1","2","3","4"};
inline ULONGLONG pending=0;
inline ULONGLONG sentAt=0,lastId=0;
inline std::deque<std::string> commands;
inline bool hotkeyRegistered=false;
inline std::array<std::atomic<DWORD>,8> liveAxes{};

inline int calibrationState=0,calibrationControl=0;
inline ULONGLONG calibrationEnds=0;
inline std::array<DWORD,8> calibrationCenter{},calibrationLow{},calibrationHigh{},calibrationLast{};
inline std::array<bool,8> calibrationUsed{};
struct CalibrationEntry{int axis=0;DWORD low=0,high=0,center=0;bool invert=false;};
inline std::array<CalibrationEntry,4> calibrationEntries{};
inline void hide(){calibrationState=0;EnableWindow(calibrationButton,TRUE);SetWindowTextW(calibrationButton,L"Калибровать оси");if(osd::editing)SendMessageW(osd::editor,WM_CLOSE,0,0);ShowWindow(window,SW_HIDE);if(IsWindow(previousWindow))SetForegroundWindow(previousWindow);}
inline const char* presets[]={"Clearly","Cloudy","Fogy","LightRainy","Rainy","Thundery","Stormy"};
inline HWND control(const wchar_t* cls,const wchar_t* label,DWORD style,int x,int y,int w,int h,int id=0){
    if(wcscmp(cls,L"BUTTON")==0&&(style&0xf)==BS_PUSHBUTTON)style|=BS_OWNERDRAW;
    HWND child=CreateWindowExW(0,cls,language::tr(label),WS_CHILD|WS_VISIBLE|style,x,y,w,h,window,reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),GetModuleHandleW(nullptr),nullptr);
    SendMessageW(child,WM_SETFONT,reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)),TRUE);
    pageControls.push_back({child,buildingPage});return child;
}
inline void sendNext(){
    if(pending||commands.empty())return;
    const auto command=commands.front();commands.pop_front();
    sentAt=GetTickCount64();pending=sentAt>lastId?sentAt:lastId+1;lastId=pending;
    const auto temp=root/L"environment.tmp",dest=root/L"environment.txt";
    std::ofstream out(temp);out<<pending<<" "<<command<<"\n";out.close();
    if(!out||!MoveFileExW(temp.c_str(),dest.c_str(),MOVEFILE_REPLACE_EXISTING)){
        SetWindowTextW(status,L"Не удалось отправить. Повторите.");pending=0;return;
    }
    SetWindowTextW(status,L"Ожидание игры...");
}
inline void send(const std::string& command){commands.push_back(command);sendNext();}
inline void readLive(std::array<DWORD,8>& values){for(int i=0;i<8;++i)values[i]=liveAxes[i].load();}
inline void resetCalibration(const wchar_t* message){
    calibrationState=0;calibrationControl=0;
    SetWindowTextW(calibrationButton,L"Калибровать оси");SetWindowTextW(status,message);
}
inline void beginAxisSample(){
    readLive(calibrationLow);calibrationHigh=calibrationLow;calibrationLast=calibrationLow;
    calibrationEnds=GetTickCount64()+6000;calibrationState=2;
    const wchar_t* prompts[5][4]={{L"Правый стик: двигайте ВЛЕВО — ВПРАВО до упора.",L"Правый стик: двигайте ВНИЗ — ВВЕРХ до упора.",L"Левый стик: двигайте ВНИЗ — ВВЕРХ до упора (газ).",L"Левый стик: двигайте ВЛЕВО — ВПРАВО до упора."},
{L"Правий стік: рухайте ЛІВОРУЧ — ПРАВОРУЧ до упору.",L"Правий стік: рухайте ВНИЗ — УГОРУ до упору.",L"Лівий стік: рухайте ВНИЗ — УГОРУ до упору (газ).",L"Лівий стік: рухайте ЛІВОРУЧ — ПРАВОРУЧ до упору."},
{L"RIGHT stick: move fully LEFT and RIGHT.",L"RIGHT stick: move fully DOWN and UP.",L"LEFT stick: move fully DOWN and UP (throttle).",L"LEFT stick: move fully LEFT and RIGHT."},
{L"PRAWY drążek: pełny ruch W LEWO i W PRAWO.",L"PRAWY drążek: pełny ruch W DÓŁ i W GÓRĘ.",L"LEWY drążek: pełny ruch W DÓŁ i W GÓRĘ (gaz).",L"LEWY drążek: pełny ruch W LEWO i W PRAWO."},
{L"RECHTEN Stick ganz LINKS und RECHTS bewegen.",L"RECHTEN Stick ganz UNTEN und OBEN bewegen.",L"LINKEN Stick ganz UNTEN und OBEN bewegen (Gas).",L"LINKEN Stick ganz LINKS und RECHTS bewegen."}};
    std::wstring text=prompts[language::current][calibrationControl];
    SetWindowTextW(status,text.c_str());SetWindowTextW(calibrationButton,L"Идёт измерение...");EnableWindow(calibrationButton,FALSE);
}
inline void requestDirection(){
    calibrationState=4;EnableWindow(calibrationButton,TRUE);SetWindowTextW(calibrationButton,L"Удерживаю — подтвердить");
    const wchar_t* directions[]={L"Правый стик ВПРАВО: удерживайте и нажмите кнопку.",L"Правый стик ВВЕРХ: удерживайте и нажмите кнопку.",L"Левый стик ВВЕРХ: удерживайте и нажмите кнопку.",L"Левый стик ВПРАВО: удерживайте и нажмите кнопку."};
    SetWindowTextW(status,directions[calibrationControl]);
}
inline void finishAxisSample(){
    int best=-1;DWORD range=0;
    for(int i=0;i<8;++i)if(!calibrationUsed[i]&&calibrationHigh[i]-calibrationLow[i]>range){best=i;range=calibrationHigh[i]-calibrationLow[i];}
    if(best<0||range<10000){resetCalibration(L"Ось не распознана. Нажмите калибровку и повторите.");EnableWindow(calibrationButton,TRUE);return;}
    const DWORD mid=calibrationLow[best]+range/2;
    if(calibrationControl!=2&&(calibrationCenter[best]<=calibrationLow[best]+range/10||calibrationCenter[best]>=calibrationHigh[best]-range/10)){
        resetCalibration(L"Ось не распознана. Нажмите калибровку и повторите.");EnableWindow(calibrationButton,TRUE);return;
    }
    if(std::abs(static_cast<int>(calibrationLast[best])-static_cast<int>(mid))<static_cast<int>(range/4)){
        requestDirection();return;
    }
    calibrationUsed[best]=true;
    calibrationEntries[calibrationControl]={best+1,calibrationLow[best],calibrationHigh[best],calibrationControl==2?mid:calibrationCenter[best],calibrationLast[best]<mid};
    ++calibrationControl;EnableWindow(calibrationButton,TRUE);
    if(calibrationControl<4){
        const wchar_t* next[]={L"Правый стик: лево / право",L"Правый стик: вниз / вверх",L"Левый стик: вниз / вверх",L"Левый стик: лево / право"};
        calibrationState=3;SetWindowTextW(calibrationButton,next[calibrationControl]);SetWindowTextW(status,L"Верните стики в исходное положение, затем начните следующую ось.");return;
    }
    const char* names[]={"roll","pitch","throttle","yaw"};
    const auto temp=root/L"calibration.tmp",dest=root/L"calibration.lua";
    std::ofstream out(temp);out<<"-- Generated in the ZoneFPV menu. Device axes are one-based.\nreturn {\n";
    for(int i=0;i<4;++i){const auto& e=calibrationEntries[i];out<<"  "<<names[i]<<"={axis="<<e.axis<<",min="<<e.low<<",max="<<e.high<<",center="<<e.center<<",invert="<<(e.invert?"true":"false")<<"},\n";}
    out<<"}\n";out.close();
    if(!out||!MoveFileExW(temp.c_str(),dest.c_str(),MOVEFILE_REPLACE_EXISTING)){resetCalibration(L"Не удалось сохранить calibration.lua.");return;}
    std::error_code ec;fs::copy_file(dest,root/("calibration-"+std::to_string(controllers::active.load())+".lua"),fs::copy_options::overwrite_existing,ec);
    if(ec){resetCalibration(L"Не удалось сохранить calibration.lua.");return;}
    resetCalibration(L"Калибровка сохранена и применяется к FPV.");send("calibration 1");
}
inline LRESULT CALLBACK proc(HWND h,UINT message,WPARAM wp,LPARAM lp){
    if(message==WM_CTLCOLORSTATIC&&(reinterpret_cast<HWND>(lp)==warning||reinterpret_cast<HWND>(lp)==status)){
        auto dc=reinterpret_cast<HDC>(wp);SetBkColor(dc,uiTheme::background());SetTextColor(dc,uiTheme::dark?RGB(255,120,120):RGB(170,20,30));return reinterpret_cast<LRESULT>(uiTheme::brush());
    }
    LRESULT themed=0;if(uiTheme::paint(h,message,wp,lp,themed))return themed;
    if(message==WM_COMMAND&&LOWORD(wp)>=500&&LOWORD(wp)<=503){selectPage(LOWORD(wp)-500);return 0;}
    if(message==WM_COMMAND&&HIWORD(wp)==CBN_SELCHANGE){
        const auto id=LOWORD(wp);
        if(id==116){const auto choice=SendMessageW(modeBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<3){const char* values[]={"acro","angle","3d"};send(std::string("mode ")+values[choice]);}return 0;}
        if(id==117){const auto choice=SendMessageW(styleBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<5)send("style "+std::to_string(choice));return 0;}
        if(id==118){uiTheme::dark=SendMessageW(themeBox,CB_GETCURSEL,0,0)==0;std::ofstream f(root/L"theme.txt");f<<(uiTheme::dark?1:0);uiTheme::apply(window);if(osd::editor)uiTheme::apply(osd::editor);return 0;}
    }
    if(message==WM_COMMAND&&LOWORD(wp)==112&&HIWORD(wp)==CBN_SELCHANGE){if(calibrationState!=0)return 0;language::current=static_cast<int>(SendMessageW(languageBox,CB_GETCURSEL,0,0));{std::ofstream f(root/L"language.txt");f<<language::current;}if(osd::editor){DestroyWindow(osd::editor);osd::editor=nullptr;osd::editing=false;}language::relabel(window);return 0;}
    if(message==WM_COMMAND&&LOWORD(wp)==113&&HIWORD(wp)==CBN_SELCHANGE){
        if(calibrationState){resetCalibration(L"Выберите настройки и нажмите кнопку.");EnableWindow(calibrationButton,TRUE);}
        const auto index=SendMessageW(deviceBox,CB_GETCURSEL,0,0);if(index!=CB_ERR){const auto id=static_cast<unsigned>(SendMessageW(deviceBox,CB_GETITEMDATA,index,0));controllers::requested=id;std::ofstream f(root/L"controller.txt");f<<id;}return 0;
    }
    if(message==WM_CLOSE){hide();return 0;}
    if(message==WM_COMMAND && LOWORD(wp)==104 && HIWORD(wp)==CBN_SELCHANGE){
        const auto value=SendMessageW(volume,CB_GETCURSEL,0,0);
        if(value>=0&&value<=4){
            droneAudio::volume=static_cast<float>(value)*0.25f;
            std::ofstream prefs(root/L"audio-volume.txt");prefs<<droneAudio::volume.load();
        }
        return 0;
    }
    if(message==WM_COMMAND && HIWORD(wp)==BN_CLICKED){
        if(LOWORD(wp)==119){
            unsigned keys[3]{};for(int i=0;i<3;++i){const auto selected=SendMessageW(keyBoxes[i],CB_GETCURSEL,0,0);if(selected<0||static_cast<size_t>(selected)>=keyCodes.size())return 0;keys[i]=keyCodes[selected];}
            if(keys[0]==keys[1]||keys[0]==keys[2]||keys[1]==keys[2]){SetWindowTextW(status,L"Для каждого действия выберите отдельную кнопку.");return 0;}
            send("bindings "+std::to_string(keys[0])+" "+std::to_string(keys[1])+" "+std::to_string(keys[2]));return 0;
        }
        if(LOWORD(wp)==115){
            if(calibrationState){SetWindowTextW(status,L"Сначала завершите калибровку или закройте меню.");return 0;}
            const auto id=controllers::active.load();int preset=static_cast<int>(SendMessageW(profileBox,CB_GETCURSEL,0,0))-1;
            if(preset<0)preset=controllerProfiles::detect(id);
            if(preset<0){SetWindowTextW(status,L"Нет точного автопрофиля. Выберите базовый профиль или калибруйте стики.");return 0;}
            if(controllerProfiles::write(root,id,preset,true)){send("calibration 1");}else SetWindowTextW(status,L"Не удалось сохранить calibration.lua.");return 0;
        }
        if(LOWORD(wp)==114){send(SendMessageW(hotStart,BM_GETCHECK,0,0)==BST_CHECKED?"option hotstart 1":"option hotstart 0");return 0;}
        if(LOWORD(wp)==111){osd::showEditor(window);return 0;}
        if(LOWORD(wp)==101){
            const auto hour=SendMessageW(hours,CB_GETCURSEL,0,0),minute=SendMessageW(minutes,CB_GETCURSEL,0,0);
            if(hour>=0&&hour<24&&minute>=0&&minute<60)send("time "+std::to_string(hour)+" "+std::to_string(minute));
        }else if(LOWORD(wp)==102){
            const auto index=SendMessageW(weather,CB_GETCURSEL,0,0);
            if(index>=0&&index<7)send(std::string("weather ")+presets[index]);
        }else if(LOWORD(wp)==105){
            const auto selectedSpeed=SendMessageW(speed,CB_GETCURSEL,0,0),selectedTilt=SendMessageW(tilt,CB_GETCURSEL,0,0);
            if(selectedSpeed>=0&&selectedSpeed<5&&selectedTilt>=0&&selectedTilt<=60)
                send(std::string("flight ")+speedValues[selectedSpeed]+" "+std::to_string(selectedTilt));
        }else if(LOWORD(wp)==106){
            send(SendMessageW(analog,BM_GETCHECK,0,0)==BST_CHECKED?"analog 1":"analog 0");
        }else if(LOWORD(wp)>=107&&LOWORD(wp)<=109){
            const int index=LOWORD(wp)-107;
            send(std::string("option ")+optionNames[index]+(SendMessageW(worldOptions[index],BM_GETCHECK,0,0)==BST_CHECKED?" 1":" 0"));
        }else if(LOWORD(wp)==110){
            if(!joystickConnected){SetWindowTextW(status,L"Контроллер не подключён.");return 0;}
            if(calibrationState==0){
                calibrationUsed.fill(false);calibrationControl=0;calibrationState=1;
                SetWindowTextW(calibrationButton,L"Зафиксировать нейтраль");
                SetWindowTextW(status,L"Стики по центру, газ полностью вниз. Затем нажмите кнопку ещё раз.");
            }else if(calibrationState==1){readLive(calibrationCenter);beginAxisSample();}
            else if(calibrationState==3)beginAxisSample();
            else if(calibrationState==4){readLive(calibrationLast);finishAxisSample();}
        }else if(LOWORD(wp)==103){hide();}
        return 0;
    }
    return DefWindowProcW(h,message,wp,lp);
}
inline void show(){
    if(GetForegroundWindow()!=window)previousWindow=GetForegroundWindow();
    if(!window){
        int dark=1;{std::ifstream f(root/L"theme.txt");f>>dark;}uiTheme::dark=dark!=0;
        WNDCLASSW cls{};cls.lpfnWndProc=proc;cls.hInstance=GetModuleHandleW(nullptr);cls.lpszClassName=L"ZoneFPVWeather";cls.hCursor=LoadCursorW(nullptr,MAKEINTRESOURCEW(32512));RegisterClassW(&cls);
        window=CreateWindowExW(WS_EX_TOPMOST,cls.lpszClassName,language::tr(L"ZoneFPV — настройки"),WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU,CW_USEDEFAULT,CW_USEDEFAULT,700,700,nullptr,nullptr,cls.hInstance,nullptr);ShowWindow(window,SW_HIDE);
        buildingPage=-1;
        const wchar_t* tabs[]={L"Полёт",L"Контроллер",L"Мир",L"Интерфейс"};
        for(int i=0;i<4;++i)control(L"BUTTON",tabs[i],WS_TABSTOP,18+i*165,15,155,34,500+i);
        status=control(L"STATIC",L"Выберите настройки и нажмите кнопку.",0,22,566,625,48);
        control(L"BUTTON",L"Закрыть",WS_TABSTOP,455,616,200,28,103);
        buildingPage=0;
        control(L"STATIC",L"Режим полёта",0,22,78,220,24);
        modeBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,265,74,365,150,116);
        for(auto name:{L"Acro",L"Angle",L"3D"})SendMessageW(modeBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));
        {std::string v;std::ifstream f(root/L"pilot-mode.txt");f>>v;SendMessageW(modeBox,CB_SETCURSEL,v=="angle"?1:v=="3d"?2:0,0);}
        control(L"STATIC",L"Angle: выравнивание. Acro: свободное вращение.\n3D: середина газа — ноль, ниже — обратная тяга.\nСмена режима завершает полёт; войдите в FPV снова.",0,22,116,620,62);
        control(L"STATIC",L"Скорость (2× — прежняя)",0,22,196,225,24);
        speed=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,265,192,365,160);
        for(auto text:{L"0.5×",L"1×",L"2×",L"3×",L"4×"})SendMessageW(speed,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));
        control(L"STATIC",L"Наклон камеры",0,22,240,220,24);tilt=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,265,236,365,250);
        for(int i=0;i<=60;++i){const auto text=std::to_wstring(i)+L"°";SendMessageW(tilt,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text.c_str()));}
        {double v=2;int angle=25,selected=2;std::ifstream f(root/L"flight-settings.txt");f>>v>>angle;for(int i=0;i<5;++i)if(v==std::stod(speedValues[i]))selected=i;SendMessageW(speed,CB_SETCURSEL,selected,0);SendMessageW(tilt,CB_SETCURSEL,std::clamp(angle,0,60),0);}
        control(L"BUTTON",L"Применить к FPV",WS_TABSTOP,265,276,365,30,105);
        control(L"STATIC",L"Вид аналоговой камеры",0,22,328,225,24);styleBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,265,324,365,180,117);
        for(auto text:{L"Выключен",L"Classic FPV",L"Clean analog",L"Monochrome",L"Worn VHS"})SendMessageW(styleBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));
        {int v=0;std::ifstream f(root/L"analog-style.txt");if(!(f>>v)){std::ifstream old(root/L"analog-settings.txt");old>>v;}SendMessageW(styleBox,CB_SETCURSEL,std::clamp(v,0,4),0);}
        control(L"STATIC",L"Громкость дрона",0,22,373,220,24);volume=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,265,369,365,160,104);
        for(auto text:{L"Выключен",L"25%",L"50%",L"75%",L"100%"})SendMessageW(volume,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));SendMessageW(volume,CB_SETCURSEL,static_cast<WPARAM>(droneAudio::volume.load()*4),0);
        hotStart=control(L"BUTTON",L"Разрешить вход с поднятым газом",BS_AUTOCHECKBOX|WS_TABSTOP,22,425,610,32,114);
        {int on=0;std::ifstream f(root/L"hotstart-settings.txt");f>>on;SendMessageW(hotStart,BM_SETCHECK,on==1?BST_CHECKED:BST_UNCHECKED,0);}
        buildingPage=1;
        control(L"STATIC",L"Устройство управления",0,22,74,620,24);deviceBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,22,103,625,250,113);
        deviceStatus=control(L"STATIC",L"",0,22,142,625,42);warning=control(L"STATIC",L"",0,22,190,625,52);
        control(L"STATIC",L"Исходный профиль (Mode 2)",0,22,258,625,24);profileBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,22,289,625,260);
        for(auto name:{L"Авто: распознать устройство",L"Xbox / XInput",L"RadioMaster Pocket — DirectInput",L"RadioMaster Pocket — WinMM",L"DualSense / DualShock — USB HID",L"RadioMaster / Jumper / FrSky / TBS / BETAFPV — AETR DI",L"FlySky / TAER — DirectInput",L"Generic USB / AETR 1-2-3-4",L"Generic USB / TAER 2-3-1-4",L"Mode 1 / AETR — DirectInput"})SendMessageW(profileBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));SendMessageW(profileBox,CB_SETCURSEL,0,0);
        control(L"BUTTON",L"Применить исходный профиль",WS_TABSTOP,22,332,625,32,115);
        control(L"STATIC",L"Профиль задаёт начальную раскладку. Если направления не совпадают, выполните калибровку. Ваш прежний профиль сохраняется в резервную копию.",0,22,384,625,70);
        calibrationButton=control(L"BUTTON",L"Калибровать оси",WS_TABSTOP,22,479,625,38,110);
        buildingPage=2;
        control(L"STATIC",L"Время суток",0,22,75,620,22);hours=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,22,108,90,250);minutes=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,128,108,90,250);
        for(int i=0;i<60;++i){const auto text=std::to_wstring(i);if(i<24)SendMessageW(hours,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text.c_str()));SendMessageW(minutes,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text.c_str()));}SendMessageW(hours,CB_SETCURSEL,12,0);SendMessageW(minutes,CB_SETCURSEL,0,0);
        control(L"BUTTON",L"Установить время",WS_TABSTOP,265,106,365,30,101);
        control(L"STATIC",L"Погода",0,22,161,620,22);weather=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,22,190,223,230);
        for(auto text:{L"Ясно",L"Облачно",L"Туман",L"Небольшой дождь",L"Дождь",L"Гроза",L"Шторм"})SendMessageW(weather,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));SendMessageW(weather,CB_SETCURSEL,0,0);
        control(L"BUTTON",L"Установить погоду",WS_TABSTOP,265,188,365,30,102);
        control(L"STATIC",L"Во время выбора FPV-камера неподвижна.\nЗначения выше — ваш выбор, не показания игры.",0,22,240,620,45);
        const wchar_t* labels[]={L"Заморозить мир в FPV",L"FPV со свойствами игрока",L"Режим бога"};
        for(int i=0;i<3;++i){worldOptions[i]=control(L"BUTTON",labels[i],BS_AUTOCHECKBOX|WS_TABSTOP,22,310+i*45,620,32,107+i);int on=0;std::ifstream f(root/(std::string(optionNames[i])+"-settings.txt"));f>>on;SendMessageW(worldOptions[i],BM_SETCHECK,on==1?BST_CHECKED:BST_UNCHECKED,0);}
        buildingPage=3;
        control(L"BUTTON",L"Редактор OSD",WS_TABSTOP,22,78,625,36,111);
        languageBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,22,138,300,210,112);for(auto text:{L"Русский",L"Українська",L"English",L"Polski",L"Deutsch"})SendMessageW(languageBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));SendMessageW(languageBox,CB_SETCURSEL,language::current,0);
        themeBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,345,138,302,120,118);for(auto text:{L"Тёмная тема",L"Светлая тема"})SendMessageW(themeBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));SendMessageW(themeBox,CB_SETCURSEL,uiTheme::dark?0:1,0);
        keyCodes={33,34,35,36,45,46};for(unsigned k=65;k<=90;++k)keyCodes.push_back(k);for(unsigned k=112;k<=123;++k)keyCodes.push_back(k);
        unsigned saved[3]={117,119,120};{std::ifstream f(root/L"bindings.txt");f>>saved[0]>>saved[1]>>saved[2];}
        const wchar_t* names[]={L"Открыть меню",L"Войти / выйти из FPV",L"Вернуть дрон к старту"};
        for(int i=0;i<3;++i){control(L"STATIC",names[i],0,22,221+i*48,310,24);keyBoxes[i]=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,345,217+i*48,302,230);for(size_t j=0;j<keyCodes.size();++j){const auto k=keyCodes[j];std::wstring text;if(k>=112)text=L"F"+std::to_wstring(k-111);else if(k>=65)text=std::wstring(1,static_cast<wchar_t>(k));else{const wchar_t* special[]={L"Page Up",L"Page Down",L"End",L"Home",L"Insert",L"Delete"};text=special[j];}SendMessageW(keyBoxes[i],CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text.c_str()));if(k==saved[i])SendMessageW(keyBoxes[i],CB_SETCURSEL,j,0);}}
        control(L"BUTTON",L"Применить кнопки",WS_TABSTOP,22,390,625,34,119);
        control(L"STATIC",L"Выберите разные кнопки. Изменения применяются при запущенной игре.",0,22,444,625,56);
        selectPage(currentPage);uiTheme::apply(window);
    }
    ShowWindow(window,SW_SHOW);SetForegroundWindow(window);
}
inline bool focused(){return osd::focused()||(window&&IsWindowVisible(window)&&(GetForegroundWindow()==window||IsChild(window,GetForegroundWindow())));}
inline void pump(bool gameFocus){
    if(gameFocus)gameWindow=GetForegroundWindow();
    static bool loadedKeys=false;if(!loadedKeys){unsigned value=0;std::ifstream f(root/L"bindings.txt");if(f>>value&&value>0&&value<256)menuKey=value;loadedKeys=true;}
    if(window&&IsWindowVisible(window)&&GetTickCount64()>=nextDeviceRefresh){nextDeviceRefresh=GetTickCount64()+1000;refreshDevices();
        unsigned value=0;std::ifstream f(root/L"bindings.txt");if(f>>value&&value!=menuKey&&value>0&&value<256){if(hotkeyRegistered){UnregisterHotKey(nullptr,6006);hotkeyRegistered=false;}menuKey=value;}}
    const bool eligible=gameFocus||focused();
    osd::pump(eligible?gameWindow:nullptr,focused()?(osd::focused()?osd::editor:window.load()):nullptr);
    if(focused())ClipCursor(nullptr);
    if(eligible&&!hotkeyRegistered)hotkeyRegistered=RegisterHotKey(nullptr,6006,MOD_NOREPEAT,menuKey)!=0;
    if(!eligible&&hotkeyRegistered){UnregisterHotKey(nullptr,6006);hotkeyRegistered=false;}
    MSG message{};while(PeekMessageW(&message,nullptr,0,0,PM_REMOVE)){
        if(message.message==WM_HOTKEY&&message.wParam==6006){
            // A queued hotkey must not reopen/activate our menu after Alt+Tab.
            if(eligible){if(window&&IsWindowVisible(window))hide();else show();}continue;
        }
        HWND dialog=osd::focused()?osd::editor:window.load();
        if(!dialog||!IsDialogMessageW(dialog,&message)){TranslateMessage(&message);DispatchMessageW(&message);}
    }
    if(calibrationState!=0&&!joystickConnected){resetCalibration(L"Контроллер не подключён.");EnableWindow(calibrationButton,TRUE);}
    if(calibrationState==2){
        readLive(calibrationLast);
        for(int i=0;i<8;++i){calibrationLow[i]=std::min(calibrationLow[i],calibrationLast[i]);calibrationHigh[i]=std::max(calibrationHigh[i],calibrationLast[i]);}
        if(GetTickCount64()>=calibrationEnds)requestDirection();
    }
    if(pending){
        std::ifstream in(root/L"environment-response.txt");ULONGLONG id=0;std::string result;in>>id>>result;
        if(id==pending){SetWindowTextW(status,result=="sent"?L"Команда передана игре.":L"Не применено: загрузите сохранение и повторите.");pending=0;}
        else if(GetTickCount64()-sentAt>4000){SetWindowTextW(status,L"Нет ответа мода. Перезапустите игру.");pending=0;}
    }
    sendNext();
}
}

#undef SetWindowTextW
#undef SendMessageW
