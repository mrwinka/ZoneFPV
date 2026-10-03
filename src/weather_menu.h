#pragma once
#include <sstream>
#include <atomic>
#include <deque>
#define SetWindowTextW language::set
#define SendMessageW language::message
namespace weatherMenu {
inline std::atomic<HWND> window{nullptr};
inline HWND hours=nullptr,minutes=nullptr,weather=nullptr,status=nullptr,previousWindow=nullptr,volume=nullptr;
inline HWND speed=nullptr,tilt=nullptr,analog=nullptr,distanceBox=nullptr,objectLimitBox=nullptr,objectLimitStatus=nullptr;
inline HWND modeBox=nullptr,styleBox=nullptr,themeBox=nullptr,keyBoxes[3]{},warning=nullptr;
inline unsigned menuKey=VK_F6;
inline int buildingPage=0,currentPage=0;
inline std::vector<std::pair<HWND,int>> pageControls;
inline fs::path root;
struct ControlLayout {HWND handle;int x,y,width,height;};
inline std::vector<ControlLayout> controlLayouts;
inline int layoutWidth=0,layoutHeight=0;
inline LOGFONTW baseFont{};
inline HFONT layoutFont=nullptr;
inline int layoutFontHeight=0;
inline bool startMaximized=false;
inline constexpr int minimumWindowSize=560,defaultWindowSize=700;
inline constexpr DWORD windowStyle=WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_THICKFRAME|WS_MAXIMIZEBOX|WS_CLIPCHILDREN;
inline SIZE savedWindowSize(HWND h){
    int width=defaultWindowSize,height=defaultWindowSize,maximized=0;
    std::string extra;
    std::ifstream file(root/L"menu-window.txt");
    // Ignore incomplete/damaged preferences, including enormous allocations.
    if(!(file>>width>>height>>maximized)||(file>>extra)||width<minimumWindowSize||height<minimumWindowSize||
       width>8192||height>8192||(maximized!=0&&maximized!=1)){
        width=height=defaultWindowSize;maximized=0;
    }
    startMaximized=maximized!=0;
    MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);
    if(GetMonitorInfoW(MonitorFromWindow(h,MONITOR_DEFAULTTONEAREST),&monitor)){
        width=std::min(width,static_cast<int>(monitor.rcWork.right-monitor.rcWork.left));
        height=std::min(height,static_cast<int>(monitor.rcWork.bottom-monitor.rcWork.top));
    }
    return {width,height};
}
inline void saveWindowSize(){
    const auto h=window.load();if(!h)return;
    WINDOWPLACEMENT placement{};placement.length=sizeof(placement);
    if(!GetWindowPlacement(h,&placement))return;
    const auto& rect=placement.rcNormalPosition;
    const auto temp=root/L"menu-window.tmp",destination=root/L"menu-window.txt";
    std::ofstream file(temp);
    file<<rect.right-rect.left<<' '<<rect.bottom-rect.top<<' '
        <<(IsZoomed(h)?1:0)<<'\n';file.close();
    if(file)MoveFileExW(temp.c_str(),destination.c_str(),MOVEFILE_REPLACE_EXISTING);
}
inline void resizeControls(HWND h){
    if(layoutWidth<=0||layoutHeight<=0||controlLayouts.empty())return;
    RECT client{};if(!GetClientRect(h,&client)||client.right<=0||client.bottom<=0)return;
    const double scaleX=static_cast<double>(client.right)/layoutWidth;
    const double scaleY=static_cast<double>(client.bottom)/layoutHeight;
    const auto fontHeight=static_cast<int>(std::lround(baseFont.lfHeight*std::min(scaleX,scaleY)));
    if(fontHeight!=layoutFontHeight){
        auto font=baseFont;font.lfHeight=fontHeight;
        if(const auto replacement=CreateFontIndirectW(&font)){
            for(const auto& item:controlLayouts)SendMessageW(item.handle,WM_SETFONT,reinterpret_cast<WPARAM>(replacement),FALSE);
            if(layoutFont)DeleteObject(layoutFont);
            layoutFont=replacement;layoutFontHeight=fontHeight;
        }
    }
    const auto scaled=[](int value,double scale){return static_cast<int>(std::lround(value*scale));};
    constexpr UINT flags=SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOOWNERZORDER|SWP_NOREDRAW;
    auto batch=BeginDeferWindowPos(static_cast<int>(controlLayouts.size()));
    for(const auto& item:controlLayouts){
        if(!batch)break;
        batch=DeferWindowPos(batch,item.handle,nullptr,scaled(item.x,scaleX),scaled(item.y,scaleY),
            scaled(item.width,scaleX),scaled(item.height,scaleY),flags);
    }
    const bool moved=batch&&EndDeferWindowPos(batch);
    if(!moved)for(const auto& item:controlLayouts)SetWindowPos(item.handle,nullptr,
        scaled(item.x,scaleX),scaled(item.y,scaleY),scaled(item.width,scaleX),scaled(item.height,scaleY),flags);
    RedrawWindow(h,nullptr,nullptr,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN);
}
inline std::vector<unsigned> keyCodes;
inline void selectPage(int page){currentPage=page;for(const auto& item:pageControls)ShowWindow(item.first,item.second<0||item.second==page?SW_SHOW:SW_HIDE);}
inline HWND calibrationButton=nullptr,languageBox=nullptr,profileBox=nullptr;
inline std::atomic<bool> joystickConnected{false};
inline HWND gameWindow=nullptr,deviceBox=nullptr,deviceStatus=nullptr,hotStart=nullptr;
inline void refreshObjectLimit(){
    const auto setting=objectLimit::read(objectLimit::defaultEnginePath());
    const auto text=std::to_wstring(setting.ok&&setting.hasValue?setting.value:objectLimit::suggested);
    SetWindowTextW(objectLimitBox,text.c_str());
    SetWindowTextW(objectLimitStatus,setting.ok?(setting.hasValue?
        L"В Engine.ini сохранён пользовательский лимит. Это не проверка текущего лимита игры.":
        L"В Engine.ini лимит не задан. Число в поле — пример; нажмите сохранить для изменения."):
        L"Не удалось прочитать лимит из Engine.ini. Другие настройки не изменены.");
}
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
inline const char* optionNames[]={"freeze","alternate","god"};
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
inline void hide(){saveWindowSize();calibrationState=0;EnableWindow(calibrationButton,TRUE);SetWindowTextW(calibrationButton,L"Калибровать оси");if(osd::editing)SendMessageW(osd::editor.load(),WM_CLOSE,0,0);ShowWindow(window,SW_HIDE);if(IsWindow(previousWindow))SetForegroundWindow(previousWindow);}
inline void cleanup(){saveWindowSize();if(const auto h=window.exchange(nullptr))DestroyWindow(h);}
inline const char* presets[]={"Clearly","Cloudy","Fogy","LightRainy","Rainy","Thundery","Stormy"};
inline HWND control(const wchar_t* cls,const wchar_t* label,DWORD style,int x,int y,int w,int h,int id=0){
    if(wcscmp(cls,L"BUTTON")==0&&(style&0xf)==BS_PUSHBUTTON)style|=BS_OWNERDRAW;
    HWND child=CreateWindowExW(0,cls,language::tr(label),WS_CHILD|WS_VISIBLE|style,x,y,w,h,window,reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),GetModuleHandleW(nullptr),nullptr);
    SendMessageW(child,WM_SETFONT,reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)),TRUE);
    pageControls.push_back({child,buildingPage});
    // A combo's measured rectangle excludes its dropdown. Keep the requested
    // height so resizing never collapses the list to a single row.
    controlLayouts.push_back({child,x,y,w,h});return child;
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
    if(message==WM_GETMINMAXINFO){
        auto info=reinterpret_cast<MINMAXINFO*>(lp);
        MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);
        int width=minimumWindowSize,height=minimumWindowSize;
        if(GetMonitorInfoW(MonitorFromWindow(h,MONITOR_DEFAULTTONEAREST),&monitor)){
            width=std::min(width,static_cast<int>(monitor.rcWork.right-monitor.rcWork.left));
            height=std::min(height,static_cast<int>(monitor.rcWork.bottom-monitor.rcWork.top));
        }
        info->ptMinTrackSize={width,height};return 0;
    }
    if(message==WM_SIZE){if(wp!=SIZE_MINIMIZED)resizeControls(h);return 0;}
    if(message==WM_EXITSIZEMOVE){saveWindowSize();return 0;}
    if(message==WM_NCDESTROY){
        controlLayouts.clear();pageControls.clear();layoutWidth=layoutHeight=layoutFontHeight=0;
        if(layoutFont){DeleteObject(layoutFont);layoutFont=nullptr;}
    }
    if(message==WM_CTLCOLORSTATIC&&(reinterpret_cast<HWND>(lp)==warning||reinterpret_cast<HWND>(lp)==status||reinterpret_cast<HWND>(lp)==objectLimitStatus)){
        auto dc=reinterpret_cast<HDC>(wp);SetBkColor(dc,uiTheme::background());SetTextColor(dc,uiTheme::dark?RGB(255,120,120):RGB(170,20,30));return reinterpret_cast<LRESULT>(uiTheme::brush());
    }
    LRESULT themed=0;if(uiTheme::paint(h,message,wp,lp,themed))return themed;
    if(message==WM_COMMAND&&LOWORD(wp)>=500&&LOWORD(wp)<=504){selectPage(LOWORD(wp)-500);return 0;}
    if(message==WM_COMMAND&&HIWORD(wp)==CBN_SELCHANGE){
        const auto id=LOWORD(wp);
        if(id==116){const auto choice=SendMessageW(modeBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<3){const char* values[]={"acro","angle","3d"};send(std::string("mode ")+values[choice]);}return 0;}
        if(id==117){const auto choice=SendMessageW(styleBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<5)send("style "+std::to_string(choice));return 0;}
        if(id==118){uiTheme::dark=SendMessageW(themeBox,CB_GETCURSEL,0,0)==0;std::ofstream f(root/L"theme.txt");f<<(uiTheme::dark?1:0);uiTheme::apply(window);if(const auto editorWindow=osd::editor.load())uiTheme::apply(editorWindow);return 0;}
    }
    if(message==WM_COMMAND&&LOWORD(wp)==112&&HIWORD(wp)==CBN_SELCHANGE){if(calibrationState!=0)return 0;language::current=static_cast<int>(SendMessageW(languageBox,CB_GETCURSEL,0,0));{std::ofstream f(root/L"language.txt");f<<language::current;}if(const auto editorWindow=osd::editor.exchange(nullptr)){DestroyWindow(editorWindow);osd::editing=false;}language::relabel(window);return 0;}
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
        if(LOWORD(wp)==123||LOWORD(wp)==124){
            const bool reset=LOWORD(wp)==124;int value=0;wchar_t text[64]{};
            if(!reset){
                GetWindowTextW(objectLimitBox,text,64);
                if(GetWindowTextLengthW(objectLimitBox)>=64||!objectLimit::parse(text,value)){SetWindowTextW(objectLimitStatus,L"Введите целое число от 1 до 2147483647, без разделителей.");return 0;}
            }
            const auto path=objectLimit::defaultEnginePath();
            const auto result=reset?objectLimit::reset(path):objectLimit::set(path,value);
            if(!result.ok){
                SetWindowTextW(objectLimitStatus,L"Не удалось изменить Engine.ini. Подробности — в журнале программы ввода.");
                std::wcerr<<L"Object limit update: "<<result.error<<L"\n";return 0;
            }
            refreshObjectLimit();
            SetWindowTextW(objectLimitStatus,reset?L"Пользовательский лимит удалён. Перезапустите игру для возврата её настроек.":
                L"Лимит сохранён в Engine.ini. Перезапустите игру.");
            return 0;
        }
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
        if(LOWORD(wp)==122){
            const auto v=SendMessageW(distanceBox,CB_GETCURSEL,0,0);
            if(v>=0&&v<=6)send("distance "+std::to_string(v));
            return 0;
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
inline void create(){
    if(!window){
        int dark=1;{std::ifstream f(root/L"theme.txt");f>>dark;}uiTheme::dark=dark!=0;
        WNDCLASSW cls{};cls.lpfnWndProc=proc;cls.hInstance=GetModuleHandleW(nullptr);cls.lpszClassName=L"ZoneFPVWeather";cls.hCursor=LoadCursorW(nullptr,MAKEINTRESOURCEW(32512));RegisterClassW(&cls);
        window=CreateWindowExW(WS_EX_TOPMOST,cls.lpszClassName,language::tr(L"ZoneFPV — настройки"),windowStyle,CW_USEDEFAULT,CW_USEDEFAULT,defaultWindowSize,defaultWindowSize,nullptr,nullptr,cls.hInstance,nullptr);
        if(!window)return;
        RECT client{};GetClientRect(window,&client);layoutWidth=client.right;layoutHeight=client.bottom;
        GetObjectW(GetStockObject(DEFAULT_GUI_FONT),sizeof(baseFont),&baseFont);
        // Control creation can generate size messages; the baseline is only
        // ready once all controls have been built.
        controlLayouts.clear();pageControls.clear();
        buildingPage=-1;
        const wchar_t* tabs[]={L"Полёт",L"Контроллер",L"Мир",L"Интерфейс",L"Прорисовка"};
        for(int i=0;i<5;++i)control(L"BUTTON",tabs[i],WS_TABSTOP,18+i*132,15,124,34,500+i);
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
        {double v=2;int angle=25,selected=2;std::ifstream f(root/L"flight-settings.txt");f>>v>>angle;for(int i=0;i<4;++i)if(v==std::stod(speedValues[i]))selected=i;SendMessageW(speed,CB_SETCURSEL,selected,0);SendMessageW(tilt,CB_SETCURSEL,std::clamp(angle,0,60),0);}
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
        for(auto name:{L"Авто: распознать устройство",L"Xbox / XInput",L"RadioMaster Pocket — DirectInput",L"RadioMaster Pocket — WinMM",L"DualSense — DirectInput",L"RadioMaster / Jumper / FrSky / TBS / BETAFPV — AETR DI",L"FlySky / TAER — DirectInput",L"Generic USB / AETR 1-2-3-4",L"Generic USB / TAER 2-3-1-4",L"Mode 1 / AETR — DirectInput",L"DualShock 4 — DirectInput (USB / Bluetooth)"})SendMessageW(profileBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));SendMessageW(profileBox,CB_SETCURSEL,0,0);
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
        const wchar_t* labels[]={L"Сильно замедлить мир в FPV",L"Альтернативный режим FPV",L"Режим бога"};
        const int optionY[]={296,336,476};
        for(int i=0;i<3;++i){worldOptions[i]=control(L"BUTTON",labels[i],BS_AUTOCHECKBOX|WS_TABSTOP,22,optionY[i],620,32,107+i);int on=0;std::ifstream f(root/(std::string(optionNames[i])+"-settings.txt"));f>>on;SendMessageW(worldOptions[i],BM_SETCHECK,on==1?BST_CHECKED:BST_UNCHECKED,0);}
        control(L"STATIC",L"По умолчанию: игрок скрыто следует за дроном для подгрузки мира и NPC.\nАльтернативный: игрок остаётся на старте; NPC вдали могут не появляться, некоторые стены могут пропускать камеру.",0,42,374,598,96);
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
        buildingPage=4;
        control(L"STATIC",L"Дальность загрузки геометрии в FPV",0,22,74,620,24);
        distanceBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,22,104,620,180);
        for(auto text:{L"Как сейчас",L"1.25×",L"1.5×",L"2×",L"3×",L"4×",L"5×"})SendMessageW(distanceBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));
        {int v=0;std::ifstream f(root/L"world-distance.txt");if(!(f>>v)||v<0||v>6)v=0;SendMessageW(distanceBox,CB_SETCURSEL,v,0);}
        control(L"BUTTON",L"Применить к FPV",WS_TABSTOP,22,148,620,32,122);
        control(L"STATIC",L"Общий множитель до 5×: земля, здания, объекты, лес и дальние модели.\nБольшие значения повышают нагрузку и могут снижать FPS.\nПри выходе из FPV исходная дальность возвращается.",0,22,195,620,76);
        control(L"STATIC",L"Лимит объектов всей игры — gc.MaxObjectsInGame",0,22,282,620,24);
        objectLimitBox=control(L"EDIT",L"",ES_NUMBER|ES_AUTOHSCROLL|WS_BORDER|WS_TABSTOP,22,314,180,28,125);
        SendMessageW(objectLimitBox,EM_SETLIMITTEXT,64,0);
        control(L"BUTTON",L"Сохранить в Engine.ini",WS_TABSTOP,218,312,204,32,123);
        control(L"BUTTON",L"По умолчанию",WS_TABSTOP,438,312,204,32,124);
        objectLimitStatus=control(L"STATIC",L"",0,22,354,620,46);
        refreshObjectLimit();
        control(L"STATIC",L"Максимум Unreal-объектов в игре: акторов, компонентов, ресурсов.\nПовышение даёт запас для подгрузки, но не ускоряет игру.\nБольше объектов может увеличить расход RAM, время загрузки и паузы GC.\nСлишком маленький лимит может вызвать краш при запуске.\nИзменение действует на всю игру после перезапуска и остаётся после FPV.",0,22,406,620,118);
        control(L"STATIC",L"Engine.ini: %LOCALAPPDATA%/Stalker2/Saved/Config/Windows",0,22,531,620,22);
        selectPage(currentPage);uiTheme::apply(window);
        const auto dimensions=savedWindowSize(window);
        SetWindowPos(window,nullptr,0,0,dimensions.cx,dimensions.cy,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
        resizeControls(window);
    }
}
inline void show(){
    if(GetForegroundWindow()!=window)previousWindow=GetForegroundWindow();
    const bool first=!window;create();if(!window)return;
    ShowWindow(window,first&&startMaximized?SW_SHOWMAXIMIZED:SW_SHOW);SetForegroundWindow(window);
}
inline bool focused(){return osd::focused()||(window&&IsWindowVisible(window)&&(GetForegroundWindow()==window||IsChild(window,GetForegroundWindow())));}
inline void pump(bool gameFocus){
    if(gameFocus)gameWindow=GetForegroundWindow();
    static bool loadedKeys=false;if(!loadedKeys){unsigned value=0;std::ifstream f(root/L"bindings.txt");if(f>>value&&value>0&&value<256)menuKey=value;loadedKeys=true;}
    if(window&&IsWindowVisible(window)&&GetTickCount64()>=nextDeviceRefresh){nextDeviceRefresh=GetTickCount64()+1000;refreshDevices();
        unsigned value=0;std::ifstream f(root/L"bindings.txt");if(f>>value&&value!=menuKey&&value>0&&value<256){if(hotkeyRegistered){UnregisterHotKey(nullptr,6006);hotkeyRegistered=false;}menuKey=value;}}
    const bool eligible=gameFocus||focused();
    osd::pump(eligible?gameWindow:nullptr,focused()?(osd::focused()?osd::editor.load():window.load()):nullptr);
    if(focused())ClipCursor(nullptr);
    if(eligible&&!hotkeyRegistered)hotkeyRegistered=RegisterHotKey(nullptr,6006,MOD_NOREPEAT,menuKey)!=0;
    if(!eligible&&hotkeyRegistered){UnregisterHotKey(nullptr,6006);hotkeyRegistered=false;}
    MSG message{};while(PeekMessageW(&message,nullptr,0,0,PM_REMOVE)){
        if(message.message==WM_HOTKEY&&message.wParam==6006){
            // A queued hotkey must not reopen/activate our menu after Alt+Tab.
            if(eligible){if(window&&IsWindowVisible(window))hide();else show();}continue;
        }
        HWND dialog=osd::focused()?osd::editor.load():window.load();
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
