#pragma once
#include <sstream>
#include <iomanip>
#include <atomic>
#include <deque>
#include <commctrl.h>
#include "action_bindings.h"
#pragma comment(lib,"comctl32.lib")
#define SetWindowTextW language::set
#define SendMessageW language::message
namespace weatherMenu {
inline std::atomic<HWND> window{nullptr};
// Modality follows visibility, including creation/activation in progress. A
// failed foreground request must never let game controls reach the character.
inline std::atomic<bool> modalRequested{false};
inline HANDLE modalChanged=nullptr;
inline bool visible(){const auto h=window.load(),editor=osd::editor.load();return modalRequested.load()||(h&&IsWindowVisible(h))||(editor&&IsWindowVisible(editor));}
inline void notifyModal(){if(modalChanged)SetEvent(modalChanged);}
inline int cursorShows=0;
inline void showMenuCursor(bool setPointer=true){
    ClipCursor(nullptr);
    const bool first=!cursorShows;
    if(first){int count=ShowCursor(TRUE);++cursorShows;while(count<0&&cursorShows<64){count=ShowCursor(TRUE);++cursorShows;}}
    if(first||setPointer)SetCursor(LoadCursorW(nullptr,MAKEINTRESOURCEW(32512)));
}
inline void releaseMenuCursor(){while(cursorShows>0){ShowCursor(FALSE);--cursorShows;}}
inline bool activateWindow(HWND target,HWND focus=nullptr,HWND expectedForeground=nullptr){
    if(!IsWindow(target))return false;
    // Async hardware polling is not a Win32 hotkey event. Briefly share the
    // foreground input queue to perform the user-requested activation, without
    // generating synthetic Alt/key events or changing foreground timeouts.
    const auto foreground=GetForegroundWindow();
    if(expectedForeground&&foreground!=expectedForeground)return false;
    const auto foregroundThread=foreground?GetWindowThreadProcessId(foreground,nullptr):0;
    const auto currentThread=GetCurrentThreadId();
    const bool attached=foregroundThread&&foregroundThread!=currentThread&&AttachThreadInput(currentThread,foregroundThread,TRUE);
    if(expectedForeground&&GetForegroundWindow()!=expectedForeground){if(attached)AttachThreadInput(currentThread,foregroundThread,FALSE);return false;}
    BringWindowToTop(target);SetForegroundWindow(target);SetActiveWindow(target);
    if(GetForegroundWindow()==target)SetFocus(focus&&IsWindow(focus)?focus:target);
    if(attached)AttachThreadInput(currentThread,foregroundThread,FALSE);
    return GetForegroundWindow()==target;
}
inline HWND hours=nullptr,minutes=nullptr,weather=nullptr,status=nullptr,previousWindow=nullptr,volume=nullptr;
inline HWND speed=nullptr,tilt=nullptr,analog=nullptr,distanceBox=nullptr,objectLimitBox=nullptr,objectLimitStatus=nullptr;
inline HWND modeBox=nullptr,styleBox=nullptr,themeBox=nullptr,warning=nullptr;
inline HWND bindingButtons[action_bindings::actionCount]{},clearBindingButtons[action_bindings::actionCount]{},captureCancel=nullptr;
inline action_bindings::Bindings bindingCodes=action_bindings::defaults();
inline bool bindingsLoaded=false,bindingsDirty=false;
inline ULONGLONG nextBindingsRefresh=0,captureEnds=0;
inline int captureRow=-1;
inline action_bindings::Capture bindingCapture;
inline const action_bindings::Sample* currentInput=nullptr;
inline bool headlessCapture=false,headlessCalibration=false;
inline std::wstring statusText;
inline void setStatus(const wchar_t* text){statusText=language::tr(text?text:L"");if(status)SetWindowTextW(status,text?text:L"");}
inline bool capturing(){return captureRow>=0;}
inline int bindingPage(int){return 9;}
inline void cancelBindingCapture(const wchar_t* message=nullptr);
inline HWND signalBox=nullptr,signalRange=nullptr,signalMultiplierBox=nullptr,impactMultiplierBox=nullptr;
inline HWND artifactRange=nullptr,flashlightPermission=nullptr,cameraDownPermission=nullptr;
inline HWND weaponModeBox=nullptr,weaponPower=nullptr,grenadeTypeBox=nullptr,grenadeCharges=nullptr,weaponImpact=nullptr;
inline HWND actionModeBoxes[action_bindings::actionCount]{};
inline HWND sectionBox=nullptr;
inline bool menuHoldOwned=false;
inline int lastMenuMode=0;
inline HWND noiseStyleBox=nullptr,anomalyStyleBox=nullptr,visionModeBox=nullptr,experimentFlags[8]{},pageTitle=nullptr,pageIntro=nullptr;
inline HWND navigation[5]{};
inline const wchar_t* groupNames[]={L"Полёт",L"Изображение",L"Оснащение",L"Мир и связь",L"Настройки"};
inline const int groupSections[5][3]={{0,-1,-1},{2,3,-1},{8,6,7},{4,5,-1},{10,1,9}};
inline int currentGroup=0;
inline int groupOf(int page){for(int g=0;g<5;++g)for(const auto section:groupSections[g])if(section==page)return g;return 0;}
inline const wchar_t* pageNames[]={L"Основное",L"Пульт",L"Камера",L"OSD",L"Мир",L"Связь",L"Сканер",L"Прочность",L"Боевой режим",L"Кнопки",L"Общие"};
inline const wchar_t* pageIntros[]={
    L"Скорость, режим полёта и поведение дрона.",
    L"Выберите пульт, затем профиль или калибровку стиков.",
    L"Наклон, ночное и тепловое видение, изображение.",
    L"Экранные показания, их размер и положение.",
    L"Погода, время и дальность загрузки мира в FPV.",
    L"Дальность радиосигнала и помехи во время полёта.",
    L"Метки целей, аномалий и поиск артефактов.",
    L"Здоровье дрона, атаки врагов и урон от столкновений.",
    L"Выберите оснащение и порог удара камикадзе.",
    L"Нажмите назначение, затем нужную кнопку или переключатель.\nПереключение сохраняет состояние; удержание действует до отпускания.",
    L"Язык, громкость и общие настройки."};
inline bool advancedWorld=false,buildingAdvanced=false;
inline std::vector<HWND> advancedControls;
struct SliderSetting{HWND handle=nullptr,badge=nullptr;int id=0,minimum=0,maximum=500,scale=100;double value=0,committed=0;};
inline std::vector<SliderSetting> sliders;
inline int buildingPage=0,currentPage=0;
inline std::vector<std::pair<HWND,int>> pageControls;
inline fs::path root;
inline fs::path objectLimitPath;
inline fs::path enginePath(){return objectLimitPath.empty()?objectLimit::defaultEnginePath():objectLimitPath;}
inline DWORD preferenceError=ERROR_SUCCESS;
inline bool savePreference(const wchar_t* name,const std::string& value){
    const auto destination=root/name,temp=fs::path(destination.wstring()+L".tmp");
    std::ofstream out(temp,std::ios::binary|std::ios::trunc);out<<value<<'\n';out.close();
    preferenceError=ERROR_SUCCESS;
    if(!out){preferenceError=ERROR_WRITE_FAULT;std::wcerr<<L"Preference write failed: "<<destination.c_str()<<L" error="<<preferenceError<<L"\n";return false;}
    for(int attempt=0;attempt<3;++attempt){
        if(MoveFileExW(temp.c_str(),destination.c_str(),MOVEFILE_REPLACE_EXISTING)){preferenceError=ERROR_SUCCESS;return true;}
        preferenceError=GetLastError();
        if((preferenceError!=ERROR_SHARING_VIOLATION&&preferenceError!=ERROR_LOCK_VIOLATION)||attempt==2)break;
        Sleep(1);
    }
    std::wcerr<<L"Preference replace failed: "<<destination.c_str()<<L" error="<<preferenceError<<L"\n";return false;
}
struct ControlLayout {HWND handle;int x,y,width,height;};
inline std::vector<ControlLayout> controlLayouts;
struct WeaponControl{HWND handle;int capability;};
inline std::vector<WeaponControl> weaponControls;
inline void refreshWeaponControls();
inline bool weaponControlVisible(HWND handle){
    const auto mode=static_cast<int>(SendMessageW(weaponModeBox,CB_GETCURSEL,0,0));
    for(const auto& control:weaponControls)if(control.handle==handle)return control.capability==0?mode!=0:control.capability==1?(mode==1||mode==3):(mode==2||mode==3);
    return true;
}
inline void markWeaponControls(size_t first,int capability){for(size_t i=first;i<pageControls.size();++i)weaponControls.push_back({pageControls[i].first,capability});}
inline int layoutWidth=0,layoutHeight=0;
inline LOGFONTW baseFont{};
inline HFONT layoutFont=nullptr;
inline int layoutFontHeight=0;
inline bool startMaximized=false;
// Platform placement in production; UI regressions can construct the actual
// first menu window offscreen without interrupting the user's foreground app.
inline POINT initialPosition{CW_USEDEFAULT,CW_USEDEFAULT};
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
inline void selectPage(int page){
    if(page!=currentPage)cancelBindingCapture();
    currentPage=std::clamp(page,0,10);currentGroup=groupOf(currentPage);
    if(sectionBox){SendMessageW(sectionBox,CB_RESETCONTENT,0,0);for(const auto section:groupSections[currentGroup])if(section>=0){const auto i=SendMessageW(sectionBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(pageNames[section]));SendMessageW(sectionBox,CB_SETITEMDATA,i,section);if(section==currentPage)SendMessageW(sectionBox,CB_SETCURSEL,i,0);}}
    for(const auto& item:pageControls)ShowWindow(item.first,item.second<0||item.second==currentPage?SW_SHOW:SW_HIDE);
    for(const auto child:advancedControls)ShowWindow(child,currentPage==4&&advancedWorld?SW_SHOW:SW_HIDE);
    if(captureCancel)ShowWindow(captureCancel,currentPage==9&&capturing()?SW_SHOW:SW_HIDE);
    refreshWeaponControls();
    SetWindowTextW(pageTitle,pageNames[currentPage]);SetWindowTextW(pageIntro,pageIntros[currentPage]);
    for(const auto button:navigation)InvalidateRect(button,nullptr,TRUE);
}
inline bool parseChoice(std::istream& f,int maximum,int& result){
    std::string value,extra;
    if(!(f>>value)||(f>>extra)||value.empty()||value.size()>2||(value.size()>1&&value[0]=='0'))return false;
    int parsed=0;for(const auto c:value){if(c<'0'||c>'9')return false;parsed=parsed*10+c-'0';}
    if(parsed>maximum)return false;result=parsed;return true;
}
inline bool parseVisionSettings(std::istream& f,int& result){return parseChoice(f,15,result);}
inline bool parseFeatureSettings(std::istream& file,bool& flashlight,bool& down){
    std::string version,onLight,onDown,extra;if(!(file>>version>>onLight>>onDown)||version!="1"||(file>>extra)||(onLight!="0"&&onLight!="1")||(onDown!="0"&&onDown!="1"))return false;
    flashlight=onLight=="1";down=onDown=="1";return true;
}
inline bool selectedDeviceMatches(unsigned id){
    if(!id||id!=controllers::active.load())return false;
    const auto requested=controllers::requested.load();if(requested)return requested==id;
    std::lock_guard<std::mutex> lock(controllers::mutex);return !controllers::available.empty()&&controllers::available.front().id==id;
}
// Auto selection has a short interval before the reader commits requested ID.
// Only its actual first candidate may supply a fresh sample; explicit changes
// still suppress the old device in action_bindings::sampleHardware().
inline action_bindings::Sample sampleSettingsHardware(){
    auto sample=action_bindings::sampleHardware();
    if(!sample.controller.connected&&controllers::requested.load()==0){const auto live=controllers::live();if(selectedDeviceMatches(live.device)&&action_bindings::fresh(live,GetTickCount64()))sample.controller=live;}
    return sample;
}
inline bool parseExperimentSettings(std::istream& f,std::array<int,9>& result){
    int version=0;std::array<int,9> values{};std::string extra;
    if(!(f>>version)||version!=1)return false;
    for(auto& value:values)if(!(f>>value))return false;
    if(values[0]<0||values[0]>4)return false;
    for(size_t i=1;i<values.size();++i)if(values[i]!=0&&values[i]!=1)return false;
    if(f>>extra)return false;
    result=values;return true;
}
inline HWND calibrationButton=nullptr,languageBox=nullptr,profileBox=nullptr;
inline std::atomic<bool> joystickConnected{false};
inline HWND gameWindow=nullptr,deviceBox=nullptr,deviceStatus=nullptr,hotStart=nullptr;
inline void refreshObjectLimit(){
    const auto setting=objectLimit::read(enginePath());
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
inline void show(bool activate=true);
inline HWND worldOptions[4]={nullptr,nullptr,nullptr,nullptr};
inline const char* optionNames[]={"freeze","alternate","god","noclip"};
inline ULONGLONG pending=0;
inline ULONGLONG sentAt=0,lastId=0,nextCommandAttempt=0;
inline std::deque<std::string> commands;
inline std::array<std::atomic<DWORD>,8> liveAxes{};

inline int calibrationState=0,calibrationControl=0;
inline unsigned calibrationDevice=0;
inline ULONGLONG calibrationEnds=0;
inline std::array<DWORD,8> calibrationCenter{},calibrationLow{},calibrationHigh{},calibrationLast{};
inline std::array<bool,8> calibrationUsed{};
struct CalibrationEntry{int axis=0;DWORD low=0,high=0,center=0;bool invert=false;};
inline std::array<CalibrationEntry,4> calibrationEntries{};
inline void hide(bool restoreFocus=true){cancelBindingCapture();saveWindowSize();calibrationState=0;EnableWindow(calibrationButton,TRUE);SetWindowTextW(calibrationButton,L"Калибровать оси");if(osd::editing)SendMessageW(osd::editor.load(),WM_CLOSE,0,0);ShowWindow(window,SW_HIDE);modalRequested=false;notifyModal();releaseMenuCursor();if(restoreFocus&&IsWindow(previousWindow))activateWindow(previousWindow);}
inline void cleanup(){cancelBindingCapture();saveWindowSize();if(const auto h=window.exchange(nullptr))DestroyWindow(h);modalRequested=false;notifyModal();releaseMenuCursor();}
inline const char* presets[]={"Clearly","Cloudy","Fogy","LightRainy","Rainy","Thundery","Stormy"};
inline HWND control(const wchar_t* cls,const wchar_t* label,DWORD style,int x,int y,int w,int h,int id=0){
    if(wcscmp(cls,L"BUTTON")==0&&(style&0xf)==BS_PUSHBUTTON)style|=BS_OWNERDRAW;
    HWND child=CreateWindowExW(0,cls,language::tr(label),WS_CHILD|WS_VISIBLE|style,x,y,w,h,window,reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),GetModuleHandleW(nullptr),nullptr);
    SendMessageW(child,WM_SETFONT,reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)),TRUE);
    pageControls.push_back({child,buildingPage});
    if(buildingAdvanced)advancedControls.push_back(child);
    // A combo's measured rectangle excludes its dropdown. Keep the requested
    // height so resizing never collapses the list to a single row.
    controlLayouts.push_back({child,x,y,w,h});return child;
}
inline SliderSetting* sliderSetting(HWND handle){for(auto& item:sliders)if(item.handle==handle)return &item;return nullptr;}
// The UI orders finite capacity left-to-right, followed by unlimited. Storage
// and the game's command retain the legacy zero sentinel for unlimited.
inline int grenadeChargesToThumb(int charges){return charges==0?21:std::clamp(charges,1,20);}
inline int grenadeThumbToCharges(int thumb){const auto position=std::clamp(thumb,1,21);return position==21?0:position;}
inline std::wstring sliderText(const SliderSetting& item){
    if(item.id==122){const wchar_t* values[]={L"1×",L"1.25×",L"1.5×",L"2×",L"3×",L"4×",L"5×"};return values[std::clamp(static_cast<int>(item.value),0,6)];}
    if(item.id==104)return std::to_wstring(static_cast<int>(std::lround(item.value*100)))+L"%";
    if(item.id==150)return std::to_wstring(static_cast<int>(item.value))+L"°";
    if(item.id==151){wchar_t meters[32]{};swprintf_s(meters,L"%.1f m",item.value);return meters;}
    if(item.id==174)return grenadeThumbToCharges(static_cast<int>(item.value))==0?L"∞":std::to_wstring(grenadeThumbToCharges(static_cast<int>(item.value)));
    if(item.id==180)return std::to_wstring(static_cast<int>(item.value))+L" km/h";
    wchar_t text[32]{};swprintf_s(text,L"%.2f×",item.value);return text;
}
inline void setSliderValue(HWND handle,double value){
    if(auto item=sliderSetting(handle)){
        item->value=std::clamp(value,static_cast<double>(item->minimum)/item->scale,static_cast<double>(item->maximum)/item->scale);
        item->committed=item->value;
        SendMessageW(handle,TBM_SETPOS,TRUE,static_cast<LPARAM>(std::lround(item->value*item->scale)));
        const auto text=sliderText(*item);SetWindowTextW(item->badge,text.c_str());
    }
}
inline double sliderValue(HWND handle){const auto item=sliderSetting(handle);return item?item->value:0;}
inline HWND slider(const wchar_t* caption,int y,int id,double value,int maximum=500,int scale=100,int minimum=0){
    control(L"STATIC",caption,0,178,y,405,22);
    const auto badge=control(L"STATIC",L"",SS_RIGHT,580,y,72,22);
    const auto handle=control(TRACKBAR_CLASSW,L"",TBS_HORZ|TBS_NOTICKS|WS_TABSTOP,178,y+24,474,30,id);
    SendMessageW(handle,TBM_SETRANGEMIN,FALSE,minimum);SendMessageW(handle,TBM_SETRANGEMAX,TRUE,maximum);
    SendMessageW(handle,TBM_SETPAGESIZE,0,scale==100?25:1);
    sliders.push_back({handle,badge,id,minimum,maximum,scale,0,0});setSliderValue(handle,value);return handle;
}
inline std::string number(double value){std::ostringstream text;text<<std::fixed<<std::setprecision(6)<<value;return text.str();}
inline void sendNext(){
    const auto now=GetTickCount64();if(pending||commands.empty()||now<nextCommandAttempt)return;
    const auto command=commands.front();
    sentAt=now;pending=sentAt>lastId?sentAt:lastId+1;
    const auto temp=root/L"environment.tmp",dest=root/L"environment.txt";
    std::ofstream out(temp);out<<pending<<" "<<command<<"\n";out.close();
    if(!out||!MoveFileExW(temp.c_str(),dest.c_str(),MOVEFILE_REPLACE_EXISTING)){
        const auto error=out?GetLastError():ERROR_WRITE_FAULT;
        std::wcerr<<L"Environment publication failed: "<<dest.c_str()<<L" error="<<error<<L"; retained queued command\n";
        setStatus(L"Не удалось отправить. Повторите.");pending=0;nextCommandAttempt=now+50;return;
    }
    commands.pop_front();lastId=pending;nextCommandAttempt=0;
    setStatus(L"Ожидание игры...");
}
inline void send(const std::string& command){
    // Reload notifications read the latest atomic preferences in the game.
    // Coalesce queued notifications instead of delivering stale snapshots.
    if((command=="bindingsreload 1"||command=="actionmodesreload 1"||command=="calibration 1")&&std::find(commands.begin(),commands.end(),command)!=commands.end())return;
    commands.push_back(command);sendNext();
}
inline std::wstring bindingLabel(unsigned code){
    if(!code)return language::tr(L"Не назначено");
    if(code>=1001&&code<=1128)return std::wstring(language::tr(L"Кнопка пульта"))+L" "+std::to_wstring(code-1000);
    if(code>=3001&&code<=3024){const wchar_t* positions[]={L"Низ",L"Центр",L"Верх"};const auto value=code-3001;
        return L"CH"+std::to_wstring(value/3+1)+L" "+language::tr(positions[value%3]);}
    const auto label=action_bindings::label(code);return language::tr(label.c_str());
}
inline void refreshBindingLabels(){
    for(size_t i=0;i<bindingCodes.size();++i){
        if(!bindingButtons[i])continue;
        const auto label=static_cast<int>(i)==captureRow?std::wstring(language::tr(L"Нажмите кнопку...")):bindingLabel(bindingCodes[i]);
        SetWindowTextW(bindingButtons[i],label.c_str());
        EnableWindow(clearBindingButtons[i],!capturing()&&bindingCodes[i]!=0);
    }
    if(captureCancel)ShowWindow(captureCancel,currentPage==9&&capturing()?SW_SHOW:SW_HIDE);
}
inline const action_bindings::Bindings& getCurrentBindings(){
    const auto now=GetTickCount64();
    if(!bindingsLoaded||(!capturing()&&now>=nextBindingsRefresh)){
        nextBindingsRefresh=now+250;const auto saved=action_bindings::load(root);
        // Pending assignments stay live locally until Lua saves that exact
        // version. Opening the menu cannot restore an older file over them.
        if(!bindingsDirty){const auto changed=bindingsLoaded&&bindingCodes!=saved;bindingCodes=saved;if(changed)refreshBindingLabels();}
        else if(saved==bindingCodes)bindingsDirty=false;
        bindingsLoaded=true;
    }
    return bindingCodes;
}
inline const action_bindings::Bindings& currentBindings(){return getCurrentBindings();}
inline void cancelBindingCapture(const wchar_t* message){
    if(!capturing())return;
    bindingCapture.cancel();captureRow=-1;captureEnds=0;headlessCapture=false;refreshBindingLabels();
    if(message)setStatus(message);
}
inline bool assignBinding(int row,unsigned code){
    if(row<0||static_cast<size_t>(row)>=bindingCodes.size()||!action_bindings::valid(code))return false;
    if(code)for(size_t i=0;i<bindingCodes.size();++i)if(static_cast<int>(i)!=row&&bindingCodes[i]==code){
        setStatus(L"Эта кнопка уже назначена другому действию. Выберите другую.");return false;}
    auto candidate=bindingCodes;candidate[row]=code;std::string saved;for(const auto value:candidate)saved+=(saved.empty()?"":" ")+std::to_string(value);
    if(!savePreference(L"bindings.txt",saved)){setStatus(L"Не удалось сохранить calibration.lua.");return false;}
    bindingCodes=candidate;bindingsLoaded=true;bindingsDirty=true;refreshBindingLabels();
    send("bindingsreload 1");return true;
}
inline void beginBindingCapture(int row,const action_bindings::Sample& sample,ULONGLONG now){
    if(row<0||static_cast<size_t>(row)>=bindingCodes.size())return;
    if(captureRow==row){cancelBindingCapture(L"Назначение отменено. Прежняя кнопка сохранена.");return;}
    cancelBindingCapture();getCurrentBindings();captureRow=row;captureEnds=now+15000;
    bindingCapture.begin(sample,now);refreshBindingLabels();
    setStatus(L"Жду ввод: клавиатура, мышь, кнопка или переключатель пульта.\nОтмена сохраняет прежнее назначение.");
}
inline void beginBindingCapture(int row){
    if(currentInput)beginBindingCapture(row,*currentInput,GetTickCount64());
    else beginBindingCapture(row,action_bindings::sampleHardware(),GetTickCount64());
}
inline bool mouseBinding(unsigned code){return code==VK_LBUTTON||code==VK_RBUTTON||code==VK_MBUTTON||code==VK_XBUTTON1||code==VK_XBUTTON2;}
inline unsigned pollBindingCapture(const action_bindings::Sample& sample,ULONGLONG now,bool eligible,bool deferMouse=false){
    if(!capturing())return 0;
    if(!eligible||(!headlessCapture&&currentPage!=bindingPage(captureRow))){cancelBindingCapture(L"Назначение отменено. Прежняя кнопка сохранена.");return 0;}
    if(now>=captureEnds){cancelBindingCapture(L"Время назначения истекло. Прежняя кнопка сохранена.");return 0;}
    const auto code=bindingCapture.poll(sample,now);if(!code)return 0;
    if(deferMouse&&mouseBinding(code))return code;
    const auto row=captureRow;cancelBindingCapture();assignBinding(row,code);
    return code;
}
inline action_bindings::Sample captureInput(const action_bindings::Sample& sample,HWND target=nullptr){
    auto result=sample;if(!sample.keys[VK_LBUTTON])return result;
    POINT point{};if(!target)target=GetCapture();if(!target&&GetCursorPos(&point))target=WindowFromPoint(point);
    // A click that cancels, changes the page or selects another assignment
    // must reach its UI command on release, rather than assign Mouse1 first.
    bool reserved=target==captureCancel||target==GetDlgItem(window,103);
    for(const auto button:bindingButtons)reserved=reserved||target==button;
    for(const auto button:clearBindingButtons)reserved=reserved||target==button;
    const auto comboTarget=[&](HWND box){COMBOBOXINFO info{};info.cbSize=sizeof(info);return box&&(target==box||IsChild(box,target)||(GetComboBoxInfo(box,&info)&&(target==info.hwndList||IsChild(info.hwndList,target))));};
    for(const auto box:actionModeBoxes)reserved=reserved||comboTarget(box);
    for(const auto button:navigation)reserved=reserved||target==button;reserved=reserved||comboTarget(sectionBox);
    if(reserved)result.keys[VK_LBUTTON]=false;
    return result;
}
inline std::string experimentCommand(){
    auto style=SendMessageW(noiseStyleBox,CB_GETCURSEL,0,0);
    std::string command="experiments "+std::to_string(std::clamp(static_cast<int>(style),0,4));
    for(auto flag:experimentFlags)command+=SendMessageW(flag,BM_GETCHECK,0,0)==BST_CHECKED?" 1":" 0";
    return command;
}
inline bool readSignalRange(int& value){
    wchar_t text[16]{};GetWindowTextW(signalRange,text,16);
    if(!text[0]||GetWindowTextLengthW(signalRange)>5)return false;
    value=0;
    for(const auto* p=text;*p;++p){if(*p<L'0'||*p>L'9')return false;value=value*10+(*p-L'0');}
    return value>=50&&value<=20000;
}
inline bool parseImpactMultiplier(const std::wstring& text,double& result){
    if(text.empty()||text.size()>15)return false;
    bool decimal=false,digits=false;double value=0,scale=1;
    for(const auto ch:text){
        if(ch==L'.'||ch==L','){if(decimal)return false;decimal=true;continue;}
        if(ch<L'0'||ch>L'9')return false;
        digits=true;
        if(decimal){scale*=.1;value+=(ch-L'0')*scale;}else value=value*10+(ch-L'0');
        if(value>5)return false;
    }
    if(!digits||!std::isfinite(value)||value<0||value>5)return false;
    result=value;return true;
}
inline bool readImpactMultiplier(double& result){
    result=sliderValue(impactMultiplierBox);return true;
}
inline bool readMultiplier(HWND field,double& result){
    if(!sliderSetting(field))return false;result=sliderValue(field);return true;
}
inline bool parseArtifactRange(std::istream& file,double& result){
    std::string token,extra;double value=0,scale=1;bool decimal=false;
    if(!(file>>token)||(file>>extra)||token.empty()||token.size()>24||token.front()<'0'||token.front()>'9'||token.back()<'0'||token.back()>'9')return false;
    for(const auto c:token){
        if(c=='.'){if(decimal)return false;decimal=true;continue;}
        if(c<'0'||c>'9')return false;
        if(decimal){scale*=.1;value+=(c-'0')*scale;}else value=value*10+(c-'0');
    }
    if(!std::isfinite(value)||value<.5||value>10)return false;
    result=value;return true;
}
inline bool parseSignalSettings(std::istream& f,int& enabled,int& range,double& multiplier){
    int on=0,meters=0;double attenuation=2;std::string text,extra;
    if(!(f>>on>>meters)||(on!=0&&on!=1)||meters<50||meters>20000)return false;
    if(f>>text){if(!parseImpactMultiplier(std::wstring(text.begin(),text.end()),attenuation)||f>>extra)return false;}
    enabled=on;range=meters;multiplier=attenuation;return true;
}
struct WeaponSettings{int mode=0;double power=1;int grenade=0,charges=3,impactSpeed=30;};
inline bool parseWeaponSettings(std::istream& file,WeaponSettings& result){
    std::string version,mode,power,grenade,charges,impact,extra;
    if(!(file>>version>>mode>>power>>grenade>>charges)||version!="1")return false;
    WeaponSettings parsed;
    std::istringstream modeInput(mode),grenadeInput(grenade),chargeInput(charges);
    if(!parseChoice(modeInput,3,parsed.mode)||!parseChoice(grenadeInput,1,parsed.grenade)||!parseChoice(chargeInput,20,parsed.charges)
        ||!parseImpactMultiplier(std::wstring(power.begin(),power.end()),parsed.power)||parsed.power<.25
        ||std::abs(parsed.power*4-std::round(parsed.power*4))>1e-9)return false;
    if(file>>impact){std::istringstream input(impact);if(!parseChoice(input,150,parsed.impactSpeed)||parsed.impactSpeed<5||parsed.impactSpeed%5||(file>>extra))return false;}
    if(file.bad())return false;
    result=parsed;return true;
}
inline void refreshWeaponControls(){
    const auto mode=SendMessageW(weaponModeBox,CB_GETCURSEL,0,0);
    const bool kamikaze=mode==1||mode==3,grenades=mode==2||mode==3;
    EnableWindow(weaponPower,kamikaze);EnableWindow(weaponImpact,kamikaze);EnableWindow(grenadeTypeBox,grenades);EnableWindow(grenadeCharges,grenades);
    for(const auto& control:weaponControls)ShowWindow(control.handle,currentPage==8&&weaponControlVisible(control.handle)?SW_SHOW:SW_HIDE);
}
inline std::string weaponCommand(){
    const auto mode=static_cast<int>(SendMessageW(weaponModeBox,CB_GETCURSEL,0,0));
    const auto grenade=static_cast<int>(SendMessageW(grenadeTypeBox,CB_GETCURSEL,0,0));
    // environment.txt carries transport kinds; environment.lua maps this kind
    // to the FPVArmament console command after validating the payload.
    return "armament "+std::to_string(std::clamp(mode,0,3))+" "+number(sliderValue(weaponPower))+" "
        +std::to_string(std::clamp(grenade,0,1))+" "+std::to_string(grenadeThumbToCharges(static_cast<int>(sliderValue(grenadeCharges))))+" "+std::to_string(static_cast<int>(sliderValue(weaponImpact)));
}
inline void readLive(std::array<DWORD,8>& values){if(currentInput){values=currentInput->controller.axes;return;}for(int i=0;i<8;++i)values[i]=liveAxes[i].load();}
inline void resetCalibration(const wchar_t* message){
    calibrationState=0;calibrationControl=0;calibrationDevice=0;headlessCalibration=false;
    SetWindowTextW(calibrationButton,L"Калибровать оси");setStatus(message);
}
inline void beginAxisSample(ULONGLONG now=GetTickCount64()){
    readLive(calibrationLow);calibrationHigh=calibrationLow;calibrationLast=calibrationLow;
    calibrationEnds=now+6000;calibrationState=2;
    const wchar_t* prompts[5][4]={{L"Правый стик: двигайте ВЛЕВО — ВПРАВО до упора.",L"Правый стик: двигайте ВНИЗ — ВВЕРХ до упора.",L"Левый стик: двигайте ВНИЗ — ВВЕРХ до упора (газ).",L"Левый стик: двигайте ВЛЕВО — ВПРАВО до упора."},
{L"Правий стік: рухайте ЛІВОРУЧ — ПРАВОРУЧ до упору.",L"Правий стік: рухайте ВНИЗ — УГОРУ до упору.",L"Лівий стік: рухайте ВНИЗ — УГОРУ до упору (газ).",L"Лівий стік: рухайте ЛІВОРУЧ — ПРАВОРУЧ до упору."},
{L"RIGHT stick: move fully LEFT and RIGHT.",L"RIGHT stick: move fully DOWN and UP.",L"LEFT stick: move fully DOWN and UP (throttle).",L"LEFT stick: move fully LEFT and RIGHT."},
{L"PRAWY drążek: pełny ruch W LEWO i W PRAWO.",L"PRAWY drążek: pełny ruch W DÓŁ i W GÓRĘ.",L"LEWY drążek: pełny ruch W DÓŁ i W GÓRĘ (gaz).",L"LEWY drążek: pełny ruch W LEWO i W PRAWO."},
{L"RECHTEN Stick ganz LINKS und RECHTS bewegen.",L"RECHTEN Stick ganz UNTEN und OBEN bewegen.",L"LINKEN Stick ganz UNTEN und OBEN bewegen (Gas).",L"LINKEN Stick ganz LINKS und RECHTS bewegen."}};
    std::wstring text=prompts[language::current][calibrationControl];
    setStatus(text.c_str());SetWindowTextW(calibrationButton,L"Идёт измерение...");EnableWindow(calibrationButton,FALSE);
}
inline void requestDirection(){
    calibrationState=4;EnableWindow(calibrationButton,TRUE);SetWindowTextW(calibrationButton,L"Удерживаю — подтвердить");
    const wchar_t* directions[]={L"Правый стик ВПРАВО: удерживайте и нажмите кнопку.",L"Правый стик ВВЕРХ: удерживайте и нажмите кнопку.",L"Левый стик ВВЕРХ: удерживайте и нажмите кнопку.",L"Левый стик ВПРАВО: удерживайте и нажмите кнопку."};
    setStatus(directions[calibrationControl]);
}
inline bool finishAxisSample(){
    const auto device=calibrationDevice;
    if(!selectedDeviceMatches(device)){
        resetCalibration(L"Контроллер не подключён.");return false;
    }
    int best=-1;DWORD range=0;
    for(int i=0;i<8;++i)if(!calibrationUsed[i]&&calibrationHigh[i]-calibrationLow[i]>range){best=i;range=calibrationHigh[i]-calibrationLow[i];}
    if(best<0||range<10000){resetCalibration(L"Ось не распознана. Нажмите калибровку и повторите.");EnableWindow(calibrationButton,TRUE);return false;}
    const DWORD mid=calibrationLow[best]+range/2;
    if(calibrationControl!=2&&(calibrationCenter[best]<=calibrationLow[best]+range/10||calibrationCenter[best]>=calibrationHigh[best]-range/10)){
        resetCalibration(L"Ось не распознана. Нажмите калибровку и повторите.");EnableWindow(calibrationButton,TRUE);return false;
    }
    if(std::abs(static_cast<int>(calibrationLast[best])-static_cast<int>(mid))<static_cast<int>(range/4)){
        requestDirection();return true;
    }
    calibrationUsed[best]=true;
    calibrationEntries[calibrationControl]={best+1,calibrationLow[best],calibrationHigh[best],calibrationControl==2?mid:calibrationCenter[best],calibrationLast[best]<mid};
    ++calibrationControl;EnableWindow(calibrationButton,TRUE);
    if(calibrationControl<4){
        const wchar_t* next[]={L"Правый стик: лево / право",L"Правый стик: вниз / вверх",L"Левый стик: вниз / вверх",L"Левый стик: лево / право"};
        calibrationState=3;SetWindowTextW(calibrationButton,next[calibrationControl]);setStatus(L"Верните стики в исходное положение, затем начните следующую ось.");return true;
    }
    const char* names[]={"roll","pitch","throttle","yaw"};
    const auto temp=root/L"calibration.tmp",dest=root/L"calibration.lua";
    std::ofstream out(temp);out<<"-- Generated in the ZoneFPV menu. Device axes are one-based.\nreturn {\n";
    for(int i=0;i<4;++i){const auto& e=calibrationEntries[i];out<<"  "<<names[i]<<"={axis="<<e.axis<<",min="<<e.low<<",max="<<e.high<<",center="<<e.center<<",invert="<<(e.invert?"true":"false")<<"},\n";}
    out<<"}\n";out.close();
    if(!out||!MoveFileExW(temp.c_str(),dest.c_str(),MOVEFILE_REPLACE_EXISTING)){resetCalibration(L"Не удалось сохранить calibration.lua.");return false;}
    std::lock_guard<std::mutex> lock(controllerProfiles::mutex);
    const auto profile=root/("calibration-"+std::to_string(device)+".lua"),profileTemp=fs::path(profile.wstring()+L".tmp");
    std::error_code ec;const bool exists=fs::exists(profile,ec);
    if(!ec&&exists)fs::copy_file(profile,fs::path(profile.wstring()+L".before-manual-"+std::to_wstring(GetTickCount64())),ec);
    if(!ec)fs::copy_file(dest,profileTemp,fs::copy_options::overwrite_existing,ec);
    if(ec||!MoveFileExW(profileTemp.c_str(),profile.c_str(),MOVEFILE_REPLACE_EXISTING)){resetCalibration(L"Не удалось сохранить calibration.lua.");return false;}
    resetCalibration(L"Калибровка сохранена и применяется к FPV.");send("calibration 1");return true;
}
// Both UIs use these operations; none creates or activates a window.
inline bool advanceCalibration(ULONGLONG now=GetTickCount64()){
    const auto live=currentInput?currentInput->controller:controllers::live();
    if(!action_bindings::fresh(live,now)||!selectedDeviceMatches(live.device)){setStatus(L"Контроллер не подключён. Подключите пульт в режиме USB Joystick.");return false;}
    if(calibrationState==0){calibrationUsed.fill(false);calibrationControl=0;calibrationState=1;calibrationDevice=controllers::active.load();
        SetWindowTextW(calibrationButton,L"Зафиксировать нейтраль");
        setStatus(L"Стики по центру, газ полностью вниз. Затем нажмите кнопку ещё раз.");
    }else if(calibrationState==1){readLive(calibrationCenter);beginAxisSample(now);}
    else if(calibrationState==3)beginAxisSample(now);
    else if(calibrationState==4){readLive(calibrationLast);return finishAxisSample();}
    else return false;
    return true;
}
inline void tickCalibration(ULONGLONG now){
    if(calibrationState!=0&&(!(currentInput?currentInput->controller.connected:joystickConnected.load())||
       !selectedDeviceMatches(calibrationDevice))){resetCalibration(L"Контроллер не подключён.");EnableWindow(calibrationButton,TRUE);}
    if(calibrationState==2){readLive(calibrationLast);
        for(int i=0;i<8;++i){calibrationLow[i]=std::min(calibrationLow[i],calibrationLast[i]);calibrationHigh[i]=std::max(calibrationHigh[i],calibrationLast[i]);}
        if(now>=calibrationEnds)requestDirection();
    }
}
inline int profileChoice=0;
inline bool selectDevice(unsigned id){
    if(!savePreference(L"controller.txt",std::to_string(id)))return false;
    cancelBindingCapture();if(calibrationState)resetCalibration(L"Выберите настройки и нажмите кнопку.");
    controllers::requested=id;profileChoice=0;refreshDevices();return true;
}
inline bool applyProfile(int choice){
    if(calibrationState){setStatus(L"Сначала завершите калибровку или закройте меню.");return false;}
    const auto live=currentInput?currentInput->controller:controllers::live();
    if(!live.connected||!selectedDeviceMatches(live.device)||(!currentInput&&!action_bindings::fresh(live,GetTickCount64()))){setStatus(L"Контроллер не подключён. Подключите пульт в режиме USB Joystick.");return false;}
    const auto id=live.device;int preset=choice-1;if(choice==0)preset=controllerProfiles::detect(id);
    if(preset<0){setStatus(L"Нет точного автопрофиля. Выберите базовый профиль или калибруйте стики.");return false;}
    if(!controllerProfiles::write(root,id,preset,true)){setStatus(L"Не удалось сохранить calibration.lua.");return false;}
    profileChoice=choice;if(profileBox)SendMessageW(profileBox,CB_SETCURSEL,choice,0);send("calibration 1");return true;
}
inline bool applyActionMode(int row,int value){
    if(row<0||row>=static_cast<int>(action_bindings::actionCount)||(value!=0&&value!=1))return false;
    auto values=action_bindings::loadModes(root).values();values[row]=value;
    std::string saved="2";for(const auto mode:values)saved+=" "+std::to_string(mode);
    if(!savePreference(L"action-modes.txt",saved))return false;
    cancelBindingCapture();if(actionModeBoxes[row])SendMessageW(actionModeBoxes[row],CB_SETCURSEL,value,0);
    send("actionmodesreload 1");return true;
}
inline bool applyLanguage(int value){
    if(value<0||value>4||!savePreference(L"language.txt",std::to_string(value)))return false;
    language::current=value;if(languageBox)SendMessageW(languageBox,CB_SETCURSEL,value,0);
    if(window){language::relabel(window);refreshBindingLabels();selectPage(currentPage);}
    // Recreate lazily when F6 explicitly opens the editor: combobox items and
    // bitmap-font choices also need translation, not just window captions.
    if(const auto editorWindow=osd::editor.exchange(nullptr)){DestroyWindow(editorWindow);osd::editing=false;}
    return true;
}
inline bool applyTheme(int value){
    if(value<0||value>1||!savePreference(L"theme.txt",value==0?"1":"0"))return false;
    uiTheme::dark=value==0;if(themeBox)SendMessageW(themeBox,CB_SETCURSEL,value,0);
    if(window)uiTheme::apply(window);if(const auto editorWindow=osd::editor.load())uiTheme::apply(editorWindow);return true;
}
inline bool applyAudio(int percent){
    if(percent<0||percent>100||!savePreference(L"audio-volume.txt",number(percent/100.)))return false;
    droneAudio::volume=static_cast<float>(percent/100.);setSliderValue(volume,percent/100.);return true;
}
inline bool applyObjectLimit(int value,bool reset){
    const auto result=reset?objectLimit::reset(enginePath()):objectLimit::set(enginePath(),value);
    if(!result.ok){setStatus(L"Не удалось изменить Engine.ini. Подробности — в журнале программы ввода.");return false;}
    refreshObjectLimit();const auto message=reset?L"Пользовательский лимит удалён. Перезапустите игру для возврата её настроек.":L"Лимит сохранён в Engine.ini. Перезапустите игру.";
    SetWindowTextW(objectLimitStatus,message);setStatus(message);return true;
}
inline void moveSlider(HWND handle,UINT event){
    auto item=sliderSetting(handle);if(!item)return;
    item->value=static_cast<double>(SendMessageW(handle,TBM_GETPOS,0,0))/item->scale;
    if(item->id==180){item->value=std::clamp(std::round(item->value/5)*5,5.,150.);SendMessageW(handle,TBM_SETPOS,TRUE,static_cast<LPARAM>(item->value));}
    const auto label=sliderText(*item);SetWindowTextW(item->badge,label.c_str());
    // Preview while dragging; one command at release prevents an input backlog.
    if(event==TB_THUMBTRACK||event==TB_THUMBPOSITION)return;
    if(std::abs(item->committed-item->value)<1e-9)return;
    if(item->id==145){
        int range=0;if(!readSignalRange(range)){setStatus(L"Введите дальность от 50 до 20000 метров.");return;}
        send(std::string("signal ")+(SendMessageW(signalBox,BM_GETCHECK,0,0)==BST_CHECKED?"1 ":"0 ")+std::to_string(range)+" "+number(item->value));
    }else if(item->id==105||item->id==150){send("flight "+number(sliderValue(speed))+" "+std::to_string(static_cast<int>(sliderValue(tilt))));}
    else if(item->id==143)send("impact "+number(item->value));
    else if(item->id==151)send("collectrange "+number(item->value));
    else if(item->id==172||item->id==174||item->id==180)send(weaponCommand());
    else if(item->id==122)send("distance "+std::to_string(static_cast<int>(item->value)));
    else if(item->id==104){if(!applyAudio(static_cast<int>(std::lround(item->value*100))))return;}
    item->committed=item->value;
}
inline LRESULT CALLBACK proc(HWND h,UINT message,WPARAM wp,LPARAM lp){
    if(message==WM_ACTIVATE&&LOWORD(wp)==WA_INACTIVE){cancelBindingCapture(L"Назначение отменено. Прежняя кнопка сохранена.");releaseMenuCursor();}
    if(message==WM_ACTIVATE&&LOWORD(wp)!=WA_INACTIVE&&modalRequested)showMenuCursor();
    if(message==WM_SETCURSOR&&LOWORD(lp)==HTCLIENT&&modalRequested){showMenuCursor();return TRUE;}
    if(message==WM_HSCROLL&&lp){moveSlider(reinterpret_cast<HWND>(lp),LOWORD(wp));return 0;}
    if(message==WM_DRAWITEM&&wp>=500&&wp<=504){
        const auto draw=reinterpret_cast<DRAWITEMSTRUCT*>(lp);const bool selected=static_cast<int>(wp)-500==currentGroup;
        const auto fill=CreateSolidBrush(selected?(uiTheme::dark?RGB(91,75,41):RGB(239,213,158)):uiTheme::background());
        FillRect(draw->hDC,&draw->rcItem,fill);DeleteObject(fill);
        if(selected){auto edge=draw->rcItem;edge.right=edge.left+4;const auto gold=CreateSolidBrush(RGB(244,188,81));FillRect(draw->hDC,&edge,gold);DeleteObject(gold);}
        SetBkMode(draw->hDC,TRANSPARENT);SetTextColor(draw->hDC,selected&&uiTheme::dark?RGB(255,209,123):uiTheme::foreground());
        const auto font=reinterpret_cast<HFONT>(SendMessageW(draw->hwndItem,WM_GETFONT,0,0));const auto old=SelectObject(draw->hDC,font);
        wchar_t caption[128]{};GetWindowTextW(draw->hwndItem,caption,128);auto rect=draw->rcItem;rect.left+=14;
        DrawTextW(draw->hDC,caption,-1,&rect,DT_LEFT|DT_VCENTER|DT_SINGLELINE);SelectObject(draw->hDC,old);
        if(draw->itemState&ODS_FOCUS)DrawFocusRect(draw->hDC,&draw->rcItem);return TRUE;
    }
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
        controlLayouts.clear();pageControls.clear();advancedControls.clear();sliders.clear();layoutWidth=layoutHeight=layoutFontHeight=0;
        for(auto& button:bindingButtons)button=nullptr;for(auto& button:clearBindingButtons)button=nullptr;captureCancel=nullptr;sectionBox=nullptr;for(auto& box:actionModeBoxes)box=nullptr;menuHoldOwned=false;
        if(layoutFont){DeleteObject(layoutFont);layoutFont=nullptr;}
    }
    if(message==WM_CTLCOLORSTATIC&&(reinterpret_cast<HWND>(lp)==warning)){
        auto dc=reinterpret_cast<HDC>(wp);SetBkColor(dc,uiTheme::background());SetTextColor(dc,uiTheme::dark?RGB(255,120,120):RGB(170,20,30));return reinterpret_cast<LRESULT>(uiTheme::brush());
    }
    LRESULT themed=0;if(uiTheme::paint(h,message,wp,lp,themed))return themed;
    if(message==WM_COMMAND&&LOWORD(wp)>=500&&LOWORD(wp)<=504){selectPage(groupSections[LOWORD(wp)-500][0]);return 0;}
    if(message==WM_COMMAND&&HIWORD(wp)==CBN_SELCHANGE){
        const auto id=LOWORD(wp);
        if(id==510){const auto i=SendMessageW(sectionBox,CB_GETCURSEL,0,0);if(i!=CB_ERR)selectPage(static_cast<int>(SendMessageW(sectionBox,CB_GETITEMDATA,i,0)));return 0;}
        if(id>=190&&id<=197){
            const auto value=SendMessageW(reinterpret_cast<HWND>(lp),CB_GETCURSEL,0,0);
            applyActionMode(id-190,static_cast<int>(value));return 0;
        }
        if(id==171||id==173){refreshWeaponControls();send(weaponCommand());return 0;}
        if(id==140){send(experimentCommand());return 0;}
        if(id==146){const auto choice=SendMessageW(visionModeBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<16)send("vision "+std::to_string(choice));return 0;}
        if(id==148){const auto choice=SendMessageW(anomalyStyleBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<6)send("anomalystyle "+std::to_string(choice));return 0;}
        if(id==116){const auto choice=SendMessageW(modeBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<3){const char* values[]={"acro","angle","3d"};send(std::string("mode ")+values[choice]);}return 0;}
        if(id==117){const auto choice=SendMessageW(styleBox,CB_GETCURSEL,0,0);if(choice>=0&&choice<5)send("style "+std::to_string(choice));return 0;}
    }
    if(message==WM_COMMAND&&LOWORD(wp)==112&&HIWORD(wp)==CBN_SELCHANGE){if(!calibrationState)applyLanguage(static_cast<int>(SendMessageW(languageBox,CB_GETCURSEL,0,0)));return 0;}
    if(message==WM_COMMAND&&LOWORD(wp)==113&&HIWORD(wp)==CBN_SELCHANGE){
        const auto index=SendMessageW(deviceBox,CB_GETCURSEL,0,0);if(index!=CB_ERR)selectDevice(static_cast<unsigned>(SendMessageW(deviceBox,CB_GETITEMDATA,index,0)));return 0;
    }
    if(message==WM_CLOSE){hide();return 0;}
    if(message==WM_COMMAND && HIWORD(wp)==BN_CLICKED){
        if(LOWORD(wp)>=160&&LOWORD(wp)<=163){beginBindingCapture(LOWORD(wp)-160);return 0;}
        if(LOWORD(wp)>=164&&LOWORD(wp)<=167){cancelBindingCapture();assignBinding(LOWORD(wp)-164,0);return 0;}
        if(LOWORD(wp)==169){beginBindingCapture(4);return 0;}
        if(LOWORD(wp)==170){cancelBindingCapture();assignBinding(4,0);return 0;}
        if(LOWORD(wp)==175||LOWORD(wp)==177){beginBindingCapture(LOWORD(wp)==175?5:6);return 0;}
        if(LOWORD(wp)==176||LOWORD(wp)==178){cancelBindingCapture();assignBinding(LOWORD(wp)==176?5:6,0);return 0;}
        if(LOWORD(wp)==184){beginBindingCapture(7);return 0;}
        if(LOWORD(wp)==185){cancelBindingCapture();assignBinding(7,0);return 0;}
        if(LOWORD(wp)==168){cancelBindingCapture(L"Назначение отменено. Прежняя кнопка сохранена.");return 0;}
        if(LOWORD(wp)==149){advancedWorld=!advancedWorld;selectPage(currentPage);return 0;}
        if(LOWORD(wp)>=131&&LOWORD(wp)<=138){
            if((LOWORD(wp)==135||LOWORD(wp)==137)&&SendMessageW(reinterpret_cast<HWND>(lp),BM_GETCHECK,0,0)==BST_CHECKED)
                SendMessageW(experimentFlags[3],BM_SETCHECK,BST_CHECKED,0);
            send(experimentCommand());return 0;
        }
        if(LOWORD(wp)==126){
            int range=0;if(readSignalRange(range))send(std::string("signal ")+(SendMessageW(signalBox,BM_GETCHECK,0,0)==BST_CHECKED?"1 ":"0 ")+std::to_string(range)+" "+number(sliderValue(signalMultiplierBox)));
            else setStatus(L"Введите дальность от 50 до 20000 метров.");return 0;
        }
        if(LOWORD(wp)==144){
            double multiplier=0;
            if(!readImpactMultiplier(multiplier)){setStatus(L"Введите множитель от 0 до 5, например 2 или 0.5.");return 0;}
            send("impact "+std::to_string(multiplier));return 0;
        }
        if(LOWORD(wp)==141){send(experimentCommand());return 0;}
        if(LOWORD(wp)==186||LOWORD(wp)==187){const auto controlHandle=reinterpret_cast<HWND>(lp);send(std::string(LOWORD(wp)==186?"flashlight ":"cameradown ")+(SendMessageW(controlHandle,BM_GETCHECK,0,0)==BST_CHECKED?"1":"0"));return 0;}
        if(LOWORD(wp)==128){
            int range=0;if(!readSignalRange(range)){setStatus(L"Введите дальность от 50 до 20000 метров.");return 0;}
            double multiplier=0;if(!readMultiplier(signalMultiplierBox,multiplier)){setStatus(L"Введите множитель от 0 до 5, например 2 или 0.5.");return 0;}
            const bool enabled=SendMessageW(signalBox,BM_GETCHECK,0,0)==BST_CHECKED;
            send(std::string("signal ")+(enabled?"1 ":"0 ")+std::to_string(range)+" "+std::to_string(multiplier));return 0;
        }
        if(LOWORD(wp)==123||LOWORD(wp)==124){
            const bool reset=LOWORD(wp)==124;int value=0;wchar_t text[64]{};
            if(!reset){
                GetWindowTextW(objectLimitBox,text,64);
                if(GetWindowTextLengthW(objectLimitBox)>=64||!objectLimit::parse(text,value)){SetWindowTextW(objectLimitStatus,L"Введите целое число от 1 до 2147483647, без разделителей.");return 0;}
            }
            applyObjectLimit(value,reset);return 0;
        }
        if(LOWORD(wp)==115){applyProfile(static_cast<int>(SendMessageW(profileBox,CB_GETCURSEL,0,0)));return 0;}

        if(LOWORD(wp)==114){send(SendMessageW(hotStart,BM_GETCHECK,0,0)==BST_CHECKED?"option hotstart 1":"option hotstart 0");return 0;}
        if(LOWORD(wp)==111){osd::showEditor(window);return 0;}
        if(LOWORD(wp)==101){
            const auto hour=SendMessageW(hours,CB_GETCURSEL,0,0),minute=SendMessageW(minutes,CB_GETCURSEL,0,0);
            if(hour>=0&&hour<24&&minute>=0&&minute<60)send("time "+std::to_string(hour)+" "+std::to_string(minute));
        }else if(LOWORD(wp)==102){
            const auto index=SendMessageW(weather,CB_GETCURSEL,0,0);
            if(index>=0&&index<7)send(std::string("weather ")+presets[index]);
        }else if(LOWORD(wp)==106){
            send(SendMessageW(analog,BM_GETCHECK,0,0)==BST_CHECKED?"analog 1":"analog 0");
        }else if((LOWORD(wp)>=107&&LOWORD(wp)<=109)||LOWORD(wp)==147){
            const int index=LOWORD(wp)==147?3:LOWORD(wp)-107;
            send(std::string("option ")+optionNames[index]+(SendMessageW(worldOptions[index],BM_GETCHECK,0,0)==BST_CHECKED?" 1":" 0"));
        }else if(LOWORD(wp)==110){
            advanceCalibration();
        }else if(LOWORD(wp)==103){hide();}
        return 0;
    }
    return DefWindowProcW(h,message,wp,lp);
}
inline void refreshPreferences();
inline void create(){
    if(window)return;
    INITCOMMONCONTROLSEX common{sizeof(common),ICC_BAR_CLASSES};InitCommonControlsEx(&common);
    int dark=1;{std::ifstream f(root/L"theme.txt");f>>dark;}uiTheme::dark=dark!=0;
    WNDCLASSW cls{};cls.lpfnWndProc=proc;cls.hInstance=GetModuleHandleW(nullptr);cls.lpszClassName=L"ZoneFPVWeather";
    cls.hCursor=LoadCursorW(nullptr,MAKEINTRESOURCEW(32512));RegisterClassW(&cls);
    window=CreateWindowExW(WS_EX_TOPMOST,cls.lpszClassName,language::tr(L"ZoneFPV — настройки"),windowStyle,
        initialPosition.x,initialPosition.y,defaultWindowSize,defaultWindowSize,nullptr,nullptr,cls.hInstance,nullptr);
    if(!window)return;
    RECT client{};GetClientRect(window,&client);layoutWidth=client.right;layoutHeight=client.bottom;
    GetObjectW(GetStockObject(DEFAULT_GUI_FONT),sizeof(baseFont),&baseFont);
    controlLayouts.clear();pageControls.clear();advancedControls.clear();sliders.clear();weaponControls.clear();themeBox=nullptr;buildingAdvanced=false;
    buildingPage=-1;
    control(L"STATIC",L"ZoneFPV",0,22,26,130,26);
    control(L"STATIC",L"Настройки дрона",0,22,58,135,24);
    for(int i=0;i<5;++i)navigation[i]=control(L"BUTTON",groupNames[i],WS_TABSTOP,16,105+i*46,140,38,500+i);
    control(L"STATIC",L"Раздел",0,16,345,140,22);
    sectionBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,16,373,140,160,510);
    pageTitle=control(L"STATIC",L"",0,178,22,474,24);
    pageIntro=control(L"STATIC",L"",0,178,53,474,42);
    status=control(L"STATIC",L"Изменения применяются сразу. Ползунок — после отпускания.",0,178,571,474,40);
    control(L"BUTTON",L"Закрыть",WS_TABSTOP,492,617,160,28,103);
    const auto label=[](const wchar_t* text,int y,int height=22){return control(L"STATIC",text,0,178,y,474,height);};
    const auto combo=[](int y,int id,std::initializer_list<const wchar_t*> values){
        const auto h=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,178,y,474,230,id);
        for(const auto value:values)SendMessageW(h,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(value));SendMessageW(h,CB_SETCURSEL,0,0);return h;};
    const auto option=[](int index,const wchar_t* text,int y){
        const int ids[]={107,108,109,147};worldOptions[index]=control(L"BUTTON",text,BS_AUTOCHECKBOX|WS_TABSTOP,178,y,474,30,ids[index]);};
    const auto flag=[](int index,const wchar_t* text,int y){experimentFlags[index]=control(L"BUTTON",text,BS_AUTOCHECKBOX|WS_TABSTOP,178,y,474,30,131+index);};
    buildingPage=0;
    label(L"Режим полёта",104);modeBox=combo(132,116,{L"Acro",L"Angle",L"3D"});
    label(L"Angle: выравнивание. Acro: свободное вращение.\n3D: середина газа — ноль, ниже — обратная тяга.\nСмена режима завершает полёт; войдите в FPV снова.",178,64);
    speed=slider(L"Множитель скорости",258,105,2);
    label(L"0 выключает моторы; 2× — обычная скорость.\nИнерция и падение сохраняются.",320,40);
    option(1,L"Альтернативный режим FPV",372);option(3,L"Пролёт сквозь стены",409);
    hotStart=control(L"BUTTON",L"Разрешить вход с поднятым газом",BS_AUTOCHECKBOX|WS_TABSTOP,178,446,474,30,114);
    label(L"Обычный режим подгружает мир возле дрона.\nАльтернативный режим оставляет игрока на старте.\nСмена режима завершает текущий полёт.",495,58);
    buildingPage=1;
    label(L"Устройство управления",104);deviceBox=combo(133,113,{});
    deviceStatus=label(L"",173,36);warning=label(L"",216,42);
    label(L"Исходный профиль (Mode 2)",274);
    profileBox=combo(304,0,{L"Авто: распознать устройство",L"Xbox / XInput",L"RadioMaster Pocket — DirectInput",L"RadioMaster Pocket — WinMM",L"DualSense — DirectInput",L"RadioMaster / Jumper / FrSky / TBS / BETAFPV — AETR DI",L"FlySky / TAER — DirectInput",L"Generic USB / AETR 1-2-3-4",L"Generic USB / TAER 2-3-1-4",L"Mode 1 / AETR — DirectInput",L"DualShock 4 — DirectInput (USB / Bluetooth)"});
    control(L"BUTTON",L"Применить исходный профиль",WS_TABSTOP,178,347,474,32,115);
    label(L"Профиль задаёт начальную раскладку. Если направления не совпадают, выполните калибровку. Ваш прежний профиль сохраняется в резервную копию.",401,78);
    calibrationButton=control(L"BUTTON",L"Калибровать оси",WS_TABSTOP,178,497,474,38,110);
    buildingPage=2;
    tilt=slider(L"Наклон камеры",105,150,25,60,1);
    label(L"Режим видения",182);
    visionModeBox=combo(210,146,{L"Выключен",L"Starlight IR",L"NIR",L"White Hot",L"Black Hot",L"Rainbow",L"Ironbow",L"Lava",L"Graded Fire",L"Fusion",L"SWIR",L"Red Hot / High Contrast",L"IR LED",L"Arctic",L"Sepia",L"Green Hot"});
    label(L"Ночное видение усиливает свет; тепловизор выделяет живые цели.",252,40);
    label(L"Вид аналоговой камеры",302);styleBox=combo(330,117,{L"Выключен",L"Classic FPV",L"Clean analog",L"Monochrome",L"Worn VHS"});
    flashlightPermission=control(L"BUTTON",L"Разрешить фонарик дрона",BS_AUTOCHECKBOX|WS_TABSTOP,178,411,474,30,186);
    cameraDownPermission=control(L"BUTTON",L"Разрешить камеру вниз",BS_AUTOCHECKBOX|WS_TABSTOP,178,451,474,30,187);
    label(L"Разрешение позволяет включать функцию назначенной кнопкой. Само включение разрешения не активирует её.",495,58);
    buildingPage=3;
    control(L"BUTTON",L"Редактор OSD",WS_TABSTOP,178,105,474,34,111);
    label(L"Показания, их размер и положение на экране.",149,28);
    buildingPage=10;
    languageBox=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,178,211,474,210,112);
    for(auto value:{L"Русский",L"Українська",L"English",L"Polski",L"Deutsch"})SendMessageW(languageBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(value));
    control(L"STATIC",L"Язык",0,178,184,474,22);
    SendMessageW(languageBox,CB_SETCURSEL,language::current,0);
    buildingPage=4;
    label(L"Время суток",105);hours=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,178,133,72,250);
    minutes=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,262,133,72,250);
    for(int i=0;i<60;++i){const auto text=std::to_wstring(i);if(i<24)SendMessageW(hours,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text.c_str()));SendMessageW(minutes,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text.c_str()));}
    SendMessageW(hours,CB_SETCURSEL,12,0);SendMessageW(minutes,CB_SETCURSEL,0,0);
    control(L"BUTTON",L"Установить время",WS_TABSTOP,350,132,302,30,101);
    label(L"Погода",178);weather=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,178,206,232,230);
    for(auto text:{L"Ясно",L"Облачно",L"Туман",L"Небольшой дождь",L"Дождь",L"Гроза",L"Шторм"})SendMessageW(weather,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));SendMessageW(weather,CB_SETCURSEL,0,0);
    control(L"BUTTON",L"Установить погоду",WS_TABSTOP,426,205,226,30,102);
    option(0,L"Сильно замедлить мир в FPV",246);
    distanceBox=slider(L"Дальность загрузки мира",292,122,0,6,1);
    label(L"1× — исходная дальность. Большие значения повышают нагрузку.\nПосле выхода из FPV возвращается исходная дальность.",352,40);
    buildingPage=10;
    volume=slider(L"Громкость дрона",284,104,droneAudio::volume.load(),100,100);
    label(L"Лимит объектов всей игры",410);
    objectLimitBox=control(L"EDIT",L"",ES_NUMBER|ES_AUTOHSCROLL|WS_BORDER|WS_TABSTOP,178,446,142,28,125);SendMessageW(objectLimitBox,EM_SETLIMITTEXT,64,0);
    control(L"BUTTON",L"Сохранить лимит",WS_TABSTOP,332,444,170,32,123);control(L"BUTTON",L"По умолчанию",WS_TABSTOP,514,444,138,32,124);
    objectLimitStatus=label(L"",485,34);
    label(L"Лимит объектов всей игры. Изменение требует перезапуска; слишком низкий лимит может вызвать вылет.",525,34);
    buildingPage=5;
    signalBox=control(L"BUTTON",L"Симуляция радиосигнала",BS_AUTOCHECKBOX|WS_TABSTOP,178,104,474,30,126);
    label(L"Дальность до потери сигнала, м (50–20000)",147);
    signalRange=control(L"EDIT",L"1500",ES_NUMBER|ES_AUTOHSCROLL|WS_BORDER|WS_TABSTOP,178,175,140,28,127);SendMessageW(signalRange,EM_SETLIMITTEXT,5,0);
    control(L"BUTTON",L"Применить дальность",WS_TABSTOP,335,173,317,32,128);
    signalMultiplierBox=slider(L"Множитель затухания сигнала",220,145,2);
    label(L"Вид помех",285);noiseStyleBox=combo(312,140,{L"Полосы",L"Аналоговые цветные помехи",L"Монохромный снег и срыв строк",L"Цифровые блоки",L"Аналоговый видеосигнал"});
    flag(0,L"Препятствия ослабляют сигнал",356);flag(5,L"Помехи рядом с аномалиями",394);
    anomalyStyleBox=combo(437,148,{L"Помехи аномалий: как у радиосигнала",L"Полосы",L"Аналоговые цветные помехи",L"Монохромный снег и срыв строк",L"Цифровые блоки",L"Аналоговый видеосигнал"});
    label(L"2× — обычное затухание; 0 выключает затухание.\nПри 0% сигнала моторы выключаются, дрон падает.\nЭти настройки имитируют радиосвязь в игре.",488,62);
    buildingPage=6;
    flag(1,L"Сканировать NPC и мутантов",110);flag(2,L"Сканировать аномалии",154);
    label(L"Рамки и расстояние в FPV, как у сканирования биноклем.\nБелые — персонажи, красные — мутанты, жёлтые — аномалии.\nРаботает с загруженными объектами в пределах 300 м.\nАртефакты отмечаются отдельным детектором.",207,98);
    flag(7,L"Детектор артефактов на дроне",331);
    artifactRange=slider(L"Расстояние для сбора артефакта",384,151,3,20,2,1);
    label(L"Детектор показывает артефакты в пределах 100 м.\nПодлетите на выбранное расстояние и нажмите кнопку сбора.\nСбор доступен в FPV с включённым детектором.",451,55);
    buildingPage=7;
    flag(3,L"Прочность дрона: 100 HP и урон при столкновении",110);
    flag(4,L"NPC и мутанты замечают и атакуют дрон",155);flag(6,L"Аномалии повреждают дрон",200);
    impactMultiplierBox=slider(L"Множитель урона от столкновений",263,143,2);
    label(L"0 выключает урон от ударов; 2× — обычный урон.\nМягкие посадки безопасны; при 0 HP дрон падает.\nАтаки врагов и урон аномалий включают прочность автоматически.",331,82);
    option(2,L"Неуязвимость персонажа",457);
    label(L"Защищает игрока. Прочность дрона настраивается отдельно.",508,42);
    buildingPage=8;
    label(L"Тип вооружения",104);weaponModeBox=combo(131,171,{L"Без вооружения",L"Камикадзе",L"Сброс гранат",L"Сброс + камикадзе"});
    const auto kamikazeFirst=pageControls.size();
    label(L"Взрыв требует удар по поверхности быстрее заданного порога.\nСкольжение вдоль поверхности безопасно.\nСмена вооружения завершает полёт; войдите в FPV снова.",172,60);
    weaponPower=slider(L"Мощность взрыва камикадзе",240,172,1,20,4,1);
    weaponImpact=slider(L"Минимальная скорость удара / км/ч",304,180,30,150,1,5);
    markWeaponControls(kamikazeFirst,1);const auto grenadeFirst=pageControls.size();
    label(L"Тип гранаты",369);grenadeTypeBox=combo(393,173,{L"RGD-5",L"F-1"});
    grenadeCharges=slider(L"Запас гранат",432,174,3,21,1,1);
    label(L"Запас пополняется при новом входе в FPV. Возврат к старту не пополняет его.\nУдержание кнопки сброса выпускает гранаты по очереди.",494,60);
    markWeaponControls(grenadeFirst,2);
    buildingPage=9;
    const wchar_t* names[]={L"Открыть меню",L"Войти / выйти из FPV",L"Вернуть дрон к старту",L"Собрать ближайший артефакт",L"Фонарик дрона",L"Камера вниз / обычная",L"Сбросить гранату",L"Включить выбранное видение"};
    const int bindingIds[]={160,161,162,163,169,175,177,184},clearIds[]={164,165,166,167,170,176,178,185};
    control(L"STATIC",L"Действие",0,178,105,175,22);
    control(L"STATIC",L"Назначение",0,355,105,168,22);
    control(L"STATIC",L"Режим",0,532,105,120,22);
    for(int i=0;i<8;++i){
        control(L"STATIC",names[i],0,178,137+i*48,175,36);
        bindingButtons[i]=control(L"BUTTON",L"",WS_TABSTOP,355,133+i*48,125,30,bindingIds[i]);
        clearBindingButtons[i]=control(L"BUTTON",L"Убрать",WS_TABSTOP,484,133+i*48,43,30,clearIds[i]);
        actionModeBoxes[i]=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,532,133+i*48,120,120,190+i);
        for(auto name:{L"Переключение",L"Удержание"})SendMessageW(actionModeBoxes[i],CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));
    }
    captureCancel=control(L"BUTTON",L"Отменить назначение",WS_TABSTOP,178,537,474,26,168);
    refreshPreferences();selectPage(currentPage);uiTheme::apply(window);
    const auto dimensions=savedWindowSize(window);SetWindowPos(window,nullptr,0,0,dimensions.cx,dimensions.cy,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);resizeControls(window);
}
inline void refreshPreferences(){
    if(!window||calibrationState!=0||pending||!commands.empty())return;
    {std::string value;std::ifstream f(root/L"pilot-mode.txt");f>>value;SendMessageW(modeBox,CB_SETCURSEL,value=="angle"?1:value=="3d"?2:0,0);}
    {std::string value;double multiplier=2;int angle=25;std::ifstream f(root/L"flight-settings.txt");
        if(f>>value>>angle)parseImpactMultiplier(std::wstring(value.begin(),value.end()),multiplier);
        setSliderValue(speed,multiplier);setSliderValue(tilt,std::clamp(angle,0,60));}
    for(int i=0;i<4;++i){int on=0;std::ifstream f(root/(std::string(optionNames[i])+"-settings.txt"));f>>on;SendMessageW(worldOptions[i],BM_SETCHECK,on==1?BST_CHECKED:BST_UNCHECKED,0);}
    {int on=0;std::ifstream f(root/L"hotstart-settings.txt");f>>on;SendMessageW(hotStart,BM_SETCHECK,on==1?BST_CHECKED:BST_UNCHECKED,0);}
    const auto choice=[&](const wchar_t* name,HWND box,int maximum){int value=0;std::ifstream f(root/name);parseChoice(f,maximum,value);SendMessageW(box,CB_SETCURSEL,value,0);};
    choice(L"vision-settings.txt",visionModeBox,15);choice(L"analog-style.txt",styleBox,4);
    {bool light=true,down=true;std::ifstream file(root/L"drone-features.txt");parseFeatureSettings(file,light,down);
        SendMessageW(flashlightPermission,BM_SETCHECK,light?BST_CHECKED:BST_UNCHECKED,0);SendMessageW(cameraDownPermission,BM_SETCHECK,down?BST_CHECKED:BST_UNCHECKED,0);}
    {int value=0;std::ifstream f(root/L"world-distance.txt");parseChoice(f,6,value);setSliderValue(distanceBox,value);}
    choice(L"anomaly-noise-style.txt",anomalyStyleBox,5);
    std::array<int,9> experiments{};{std::ifstream f(root/L"experiment-settings.txt");parseExperimentSettings(f,experiments);}
    SendMessageW(noiseStyleBox,CB_SETCURSEL,experiments[0],0);
    for(size_t i=0;i<8;++i)SendMessageW(experimentFlags[i],BM_SETCHECK,experiments[i+1]?BST_CHECKED:BST_UNCHECKED,0);
    {int on=0,range=1500;double multiplier=2;std::ifstream f(root/L"signal-settings.txt");parseSignalSettings(f,on,range,multiplier);
        SendMessageW(signalBox,BM_SETCHECK,on?BST_CHECKED:BST_UNCHECKED,0);SetWindowTextW(signalRange,std::to_wstring(range).c_str());
        setSliderValue(signalMultiplierBox,multiplier);}
    {std::string value;double multiplier=2;std::ifstream f(root/L"impact-settings.txt");if(f>>value)parseImpactMultiplier(std::wstring(value.begin(),value.end()),multiplier);
        setSliderValue(impactMultiplierBox,multiplier);}
    {double value=3;std::ifstream f(root/L"artifact-settings.txt");parseArtifactRange(f,value);setSliderValue(artifactRange,value);}
    {WeaponSettings value;std::ifstream f(root/L"weapon-settings.txt");parseWeaponSettings(f,value);
        SendMessageW(weaponModeBox,CB_SETCURSEL,value.mode,0);setSliderValue(weaponPower,value.power);
        SendMessageW(grenadeTypeBox,CB_SETCURSEL,value.grenade,0);setSliderValue(grenadeCharges,grenadeChargesToThumb(value.charges));setSliderValue(weaponImpact,value.impactSpeed);refreshWeaponControls();}
    {const auto modes=action_bindings::loadModes(root).values();for(size_t i=0;i<modes.size();++i)SendMessageW(actionModeBoxes[i],CB_SETCURSEL,modes[i],0);}
    {double value=1;std::ifstream f(root/L"audio-volume.txt");if(f>>value){value=std::clamp(value,0.0,1.0);droneAudio::volume=static_cast<float>(value);}
        setSliderValue(volume,droneAudio::volume.load());}
    getCurrentBindings();refreshBindingLabels();
    refreshObjectLimit();refreshDevices();
}
inline void show(bool activate){
    if(activate&&GetForegroundWindow()!=window)previousWindow=GetForegroundWindow();
    modalRequested=true;notifyModal();
    const bool first=!window;create();if(!window){modalRequested=false;notifyModal();return;}refreshPreferences();
    ShowWindow(window,activate?(first&&startMaximized?SW_SHOWMAXIMIZED:SW_SHOW):SW_SHOWNOACTIVATE);
    if(activate){activateWindow(window,navigation[currentGroup]);showMenuCursor();}
}
inline bool dispatchMenuAction(bool edge,unsigned binding,bool ownMenu,bool activate=true){
    if(!edge)return false;
    const bool mouse=binding==VK_LBUTTON||binding==VK_RBUTTON||binding==VK_MBUTTON||binding==VK_XBUTTON1||binding==VK_XBUTTON2;
    if(ownMenu&&mouse)return false;
    if(window&&IsWindowVisible(window))hide(activate);
    else show(activate);
    return window!=nullptr;
}
// The menu action is local; Lua receives its counter but does not own Win32 focus.
inline action_bindings::Modes currentModes(){
    static action_bindings::Modes value;static ULONGLONG next=0;
    const auto now=GetTickCount64();if(now>=next){value=action_bindings::loadModes(root);next=now+250;}return value;
}
inline bool dispatchMenuState(bool edge,bool held,unsigned binding,bool ownMenu,int mode,bool activate=true){
    if(mode!=lastMenuMode){menuHoldOwned=false;lastMenuMode=mode;}
    if(!mode)return dispatchMenuAction(edge,binding,ownMenu,activate);
    if(menuHoldOwned){
        if(!window||!IsWindowVisible(window)){menuHoldOwned=false;return false;}
        if(!held){menuHoldOwned=false;hide(activate&&ownMenu);return true;}
        return false;
    }
    if(!edge||!held||visible())return false;
    const auto accepted=dispatchMenuAction(true,binding,ownMenu,activate);
    menuHoldOwned=accepted&&window&&IsWindowVisible(window);return accepted;
}
inline bool focused(){return osd::focused()||(window&&IsWindowVisible(window)&&(GetForegroundWindow()==window||IsChild(window,GetForegroundWindow())));}
inline HWND modalFocusTarget(){
    if(const auto editor=osd::editor.load();editor&&IsWindowVisible(editor))return editor;
    const auto h=window.load();return h&&IsWindowVisible(h)?h:nullptr;
}
inline HWND modalRecoveryTarget(HWND foreground,HWND foregroundGame){
    // Clicking the game must not let its hidden-cursor input mode take over a
    // visible settings dialog. Alt-Tab to another app remains unrestricted.
    if(!foregroundGame||foreground!=foregroundGame||!IsWindow(foregroundGame)||!visible())return nullptr;
    const auto target=modalFocusTarget();return target&&target!=foreground?target:nullptr;
}
inline bool recoverModalFocus(HWND foregroundGame){
    const auto target=modalRecoveryTarget(GetForegroundWindow(),foregroundGame);
    if(!target)return false;
    if(IsIconic(target))ShowWindow(target,SW_SHOWNOACTIVATE);
    // Recheck after restoring a minimized window: never activate over an app
    // that acquired foreground since the game HWND was validated.
    if(GetForegroundWindow()!=foregroundGame)return false;
    if(!activateWindow(target,target==window.load()?navigation[currentGroup]:nullptr,foregroundGame))return false;
    showMenuCursor();return true;
}
inline void pump(bool gameFocus,const action_bindings::Sample* supplied=nullptr,HWND foregroundGame=nullptr){
    currentInput=supplied;
    if(gameFocus&&foregroundGame)gameWindow=foregroundGame;
    if(window&&IsWindowVisible(window)&&GetTickCount64()>=nextDeviceRefresh){nextDeviceRefresh=GetTickCount64()+1000;refreshDevices();}
    const bool eligible=gameFocus||focused();
    osd::pump(eligible?gameWindow:nullptr,focused()?(osd::focused()?osd::editor.load():window.load()):nullptr);
    MSG message{};while(PeekMessageW(&message,nullptr,0,0,PM_REMOVE)){
        if(capturing()&&message.message>=WM_KEYFIRST&&message.message<=WM_KEYLAST)continue;
        HWND dialog=osd::focused()?osd::editor.load():window.load();
        if(!dialog||!IsDialogMessageW(dialog,&message)){TranslateMessage(&message);DispatchMessageW(&message);}
    }
    // Run after WM_ACTIVATE has released the previous menu cursor state.
    // Only a verified game foreground may be redirected to the open dialog.
    if(gameFocus&&foregroundGame)recoverModalFocus(foregroundGame);
    if(visible()&&focused())showMenuCursor(false);else releaseMenuCursor();
    if(capturing()&&!headlessCapture){
        if(supplied)pollBindingCapture(captureInput(*supplied),GetTickCount64(),focused());
        else pollBindingCapture(captureInput(action_bindings::sampleHardware()),GetTickCount64(),focused());
    }
    if(!headlessCalibration)tickCalibration(GetTickCount64());
    currentInput=nullptr;
    if(pending){
        std::ifstream in(root/L"environment-response.txt");ULONGLONG id=0;std::string result,code;in>>id>>result>>code;
        if(id==pending){
            const wchar_t* text=result=="sent"?L"Команда передана игре.":L"Не применено. Подробности в UE4SS.log.";
            if(code=="fpv_required")text=L"Сбор доступен во время полёта FPV.";
            else if(code=="detector_required")text=L"Включите детектор артефактов.";
            else if(code=="artifact_missing")text=L"Поблизости нет доступного артефакта.";
            else if(code=="artifact_too_far")text=L"Подлетите к артефакту на выбранное расстояние сбора.";
            else if(code=="pickup_unavailable"||code=="pickup_failed")text=L"Не удалось собрать артефакт. Подробности в UE4SS.log.";
            else if(code=="artifact_collected")text=L"Артефакт собран.";
            else if(code=="artifact_collecting")text=L"Артефакт собирается. Дождитесь завершения.";
            setStatus(text);pending=0;
        }
        else if(GetTickCount64()-sentAt>4000){setStatus(L"Нет ответа мода. Перезапустите игру.");pending=0;}
    }
    sendNext();
}
}

#undef SetWindowTextW
#undef SendMessageW
