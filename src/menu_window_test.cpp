#define wmain bridgeMain
#include "input.cpp"
#undef wmain
#include <cassert>
#include <cstdlib>

namespace {
RECT windowRect(HWND h){RECT r{};assert(GetWindowRect(h,&r));return r;}
RECT childRect(HWND h){auto r=windowRect(h);MapWindowPoints(nullptr,weatherMenu::window.load(),reinterpret_cast<POINT*>(&r),2);return r;}
LOGFONTW controlFont(HWND h){LOGFONTW font{};assert(GetObjectW(reinterpret_cast<HFONT>(SendMessageW(h,WM_GETFONT,0,0)),sizeof(font),&font));return font;}
void resize(int width,int height){
    assert(SetWindowPos(weatherMenu::window.load(),nullptr,0,0,width,height,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOOWNERZORDER));
    const auto r=windowRect(weatherMenu::window.load());assert(r.right-r.left==width&&r.bottom-r.top==height);
    assert(!IsWindowVisible(weatherMenu::window.load()));
}
std::vector<RECT> geometry(){
    std::vector<RECT> result;for(const auto& item:weatherMenu::pageControls)result.push_back(childRect(item.first));return result;
}
void checkPages(){
    const auto h=weatherMenu::window.load();RECT client{};assert(GetClientRect(h,&client));
    for(int page=0;page<5;++page){
        weatherMenu::selectPage(page);int pageCount=0;
        for(const auto& item:weatherMenu::pageControls){
            const bool visible=(GetWindowLongPtrW(item.first,GWL_STYLE)&WS_VISIBLE)!=0;
            assert(visible==(item.second<0||item.second==page));
            if(item.second==page)++pageCount;
            const auto r=childRect(item.first);
            if(!(r.left>=0&&r.top>=0&&r.right<=client.right&&r.bottom<=client.bottom&&r.right>r.left&&r.bottom>r.top)){
                std::cerr<<"Control outside client on page "<<page<<": "<<r.left<<","<<r.top<<","<<r.right<<","<<r.bottom<<"\n";std::exit(1);
            }
        }
        assert(pageCount>0);
    }
    weatherMenu::selectPage(0);
}
void checkDropdown(HWND combo){
    RECT dropped{};assert(SendMessageW(combo,CB_GETDROPPEDCONTROLRECT,0,reinterpret_cast<LPARAM>(&dropped)));
    const auto closed=windowRect(combo);const auto row=SendMessageW(combo,CB_GETITEMHEIGHT,0,0);
    assert(row>0&&dropped.bottom-dropped.top>closed.bottom-closed.top+3*row);
}
void settings(const char* text){std::ofstream f(weatherMenu::root/L"menu-window.txt",std::ios::trunc);f<<text;assert(f.good());}
void checkDefault(){const auto r=windowRect(weatherMenu::window.load());assert(r.right-r.left==700&&r.bottom-r.top==700);}
}

int main(){
    const auto foreground=GetForegroundWindow();
    const auto fixture=fs::temp_directory_path()/(L"ZoneFPV-menu-test-"+std::to_wstring(GetCurrentProcessId()));
    fs::create_directories(fixture);weatherMenu::root=fixture;
    weatherMenu::create();const auto h=weatherMenu::window.load();assert(h&&IsWindow(h)&&!IsWindowVisible(h));checkDefault();
    assert((GetWindowLongPtrW(h,GWL_STYLE)&(WS_THICKFRAME|WS_MAXIMIZEBOX))==(WS_THICKFRAME|WS_MAXIMIZEBOX));
    MINMAXINFO limits{};SendMessageW(h,WM_GETMINMAXINFO,0,reinterpret_cast<LPARAM>(&limits));assert(limits.ptMinTrackSize.x==560&&limits.ptMinTrackSize.y==560);
    const auto original=geometry();const auto font=controlFont(weatherMenu::status);
    const HWND combos[]={weatherMenu::modeBox,weatherMenu::tilt,weatherMenu::deviceBox,weatherMenu::profileBox,weatherMenu::languageBox,weatherMenu::distanceBox};
    std::vector<LRESULT> selections;for(const auto combo:combos){
        if(SendMessageW(combo,CB_GETCOUNT,0,0)<2)for(const auto text:{L"Fixture A",L"Fixture B"})SendMessageW(combo,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(text));
        assert(SendMessageW(combo,CB_SETCURSEL,1,0)==1);selections.push_back(SendMessageW(combo,CB_GETCURSEL,0,0));
    }
    resize(560,560);checkPages();assert(std::abs(controlFont(weatherMenu::status).lfHeight)<std::abs(font.lfHeight));
    for(const auto combo:combos)checkDropdown(combo);
    resize(1000,900);checkPages();assert(std::abs(controlFont(weatherMenu::status).lfHeight)>std::abs(font.lfHeight));
    for(const auto combo:combos)checkDropdown(combo);
    for(int cycle=0;cycle<5;++cycle){resize(560,560);resize(1000,900);resize(700,700);}
    const auto restored=geometry();assert(restored.size()==original.size());
    for(size_t i=0;i<original.size();++i)assert(EqualRect(&restored[i],&original[i]));
    assert(controlFont(weatherMenu::status).lfHeight==font.lfHeight);
    for(size_t i=0;i<selections.size();++i)assert(SendMessageW(combos[i],CB_GETCURSEL,0,0)==selections[i]);
    std::cout<<"PASS hidden menu: five-page bounds, fonts, dropdowns, selections and resize stability\n";

    MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);assert(GetMonitorInfoW(MonitorFromWindow(h,MONITOR_DEFAULTTONEAREST),&monitor));
    const int savedWidth=std::min(820L,monitor.rcWork.right-monitor.rcWork.left),savedHeight=std::min(760L,monitor.rcWork.bottom-monitor.rcWork.top);
    resize(savedWidth,savedHeight);weatherMenu::cleanup();assert(!weatherMenu::window.load()&&weatherMenu::pageControls.empty());
    {std::ifstream f(fixture/L"menu-window.txt");int width=0,height=0,maximized=-1;assert((f>>width>>height>>maximized)&&width==savedWidth&&height==savedHeight&&maximized==0);}
    weatherMenu::create();const auto saved=windowRect(weatherMenu::window.load());assert(saved.right-saved.left==savedWidth&&saved.bottom-saved.top==savedHeight);assert(!IsWindowVisible(weatherMenu::window.load()));
    weatherMenu::cleanup();
    for(const auto malformed:{"invalid","700 700","559 700 0","700 8193 0","700 700 2","700 700 0 extra"}){
        settings(malformed);weatherMenu::create();checkDefault();assert(!IsWindowVisible(weatherMenu::window.load()));weatherMenu::cleanup();
    }
    assert(GetForegroundWindow()==foreground);
    std::cout<<"PASS menu dimensions persistence, malformed-config rejection and no focus changes\n";
    fs::remove_all(fixture);return 0;
}
