#define wmain bridgeMain
#include "input.cpp"
#undef wmain
#include <cassert>
#include <cstdlib>
#include <iterator>

namespace {
RECT windowRect(HWND h){RECT r{};assert(GetWindowRect(h,&r));return r;}
RECT childRect(HWND h){auto r=windowRect(h);MapWindowPoints(nullptr,osd::editor.load(),reinterpret_cast<POINT*>(&r),2);return r;}
RECT clientRect(HWND h){RECT r{};assert(GetClientRect(h,&r));return r;}
LOGFONTW controlFont(HWND h){LOGFONTW font{};assert(GetObjectW(reinterpret_cast<HFONT>(SendMessageW(h,WM_GETFONT,0,0)),sizeof(font),&font));return font;}
BOOL CALLBACK collectControls(HWND h,LPARAM pointer){
    if(h!=osd::preview)reinterpret_cast<std::vector<HWND>*>(pointer)->push_back(h);
    return TRUE;
}
std::vector<HWND> controls(){std::vector<HWND> result;EnumChildWindows(osd::editor.load(),collectControls,reinterpret_cast<LPARAM>(&result));return result;}
std::vector<RECT> geometry(){std::vector<RECT> result;for(const auto h:controls())result.push_back(childRect(h));result.push_back(childRect(osd::preview));return result;}
void resize(int width,int height){
    assert(SetWindowPos(osd::editor.load(),nullptr,0,0,width,height,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOOWNERZORDER));
    const auto r=windowRect(osd::editor.load());assert(r.right-r.left==width&&r.bottom-r.top==height);
    assert(!IsWindowVisible(osd::editor.load()));
}
void checkBounds(){
    const auto client=clientRect(osd::editor.load());
    auto children=controls();children.push_back(osd::preview);
    for(const auto h:children){
        const auto r=childRect(h);
        if(!(r.left>=0&&r.top>=0&&r.right<=client.right&&r.bottom<=client.bottom&&r.right>r.left&&r.bottom>r.top)){
            std::cerr<<"OSD control outside client: "<<r.left<<","<<r.top<<","<<r.right<<","<<r.bottom<<"\n";std::exit(1);
        }
    }
}
void checkAspect(double aspect){
    const auto r=clientRect(osd::preview);assert(r.right>0&&r.bottom>0);
    // At most one pixel of rounding in each client dimension.
    assert(std::abs(r.right-aspect*r.bottom)<=aspect+1.0);
}
void checkDropdown(HWND combo){
    RECT dropped{};assert(SendMessageW(combo,CB_GETDROPPEDCONTROLRECT,0,reinterpret_cast<LPARAM>(&dropped)));
    const auto closed=windowRect(combo);const auto row=SendMessageW(combo,CB_GETITEMHEIGHT,0,0);
    assert(row>0&&dropped.bottom-dropped.top>closed.bottom-closed.top+3*row);
}
void destroyEditor(){if(const auto h=osd::editor.exchange(nullptr))assert(DestroyWindow(h));assert(!osd::editor.load());}
void settings(const char* text){std::ofstream f(osd::root/L"osd-editor-window.txt",std::ios::trunc);f<<text;assert(f.good());}
std::string layoutFile(){std::ifstream f(osd::root/L"osd-layout.txt",std::ios::binary);assert(f);return {std::istreambuf_iterator<char>(f),std::istreambuf_iterator<char>()};}
void checkItems(const decltype(osd::items)& expected){
    for(size_t i=0;i<expected.size();++i){const auto& actual=osd::items[i];const auto& item=expected[i];assert(actual.x==item.x&&actual.y==item.y&&actual.size==item.size&&actual.color==item.color&&actual.visible==item.visible);}
}
void pumpGame(HWND game,int width,int height){
    assert(SetWindowPos(game,nullptr,0,0,width,height,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE));
    assert(!IsWindowVisible(game));osd::nextPoll=0;osd::data.active=false;osd::pump(game,nullptr);
    assert(!osd::overlay&&!IsWindowVisible(osd::editor.load()));
    assert(std::abs(osd::screenAspect-static_cast<double>(width)/height)<1e-10);
    checkAspect(osd::screenAspect);checkBounds();
}
}

int main(){
    const auto foreground=GetForegroundWindow();
    const auto fixture=fs::absolute(fs::path(__FILE__).parent_path().parent_path()/L"build"/L"native-tests"/(L"osd-window-fixture-"+std::to_wstring(GetCurrentProcessId())));
    fs::create_directories(fixture);osd::root=fixture;
    osd::items=osd::defaults;osd::items[0]={.31,.67,48,3,false};osd::enabled=true;osd::crossStyle=2;osd::fontChoice=7;osd::selected=0;
    const auto expectedItems=osd::items;assert(osd::save());const auto expectedLayout=layoutFile();
    osd::screenAspect=16.0/9;osd::createEditor(nullptr);
    const auto h=osd::editor.load();assert(h&&IsWindow(h)&&!IsWindowVisible(h)&&!osd::editing&&!osd::overlay);
    assert(SendMessageW(osd::list,LB_GETCOUNT,0,0)==14);
    assert(SendMessageW(osd::styleBox,CB_GETCOUNT,0,0)==6&&SendMessageW(osd::downStyleBox,CB_GETCOUNT,0,0)==6);
    SendMessageW(osd::downStyleBox,CB_SETCURSEL,5,0);SendMessageW(h,WM_COMMAND,MAKEWPARAM(210,CBN_SELCHANGE),reinterpret_cast<LPARAM>(osd::downStyleBox));
    assert(osd::downCrossStyle==5&&osd::crossStyle==2&&osd::previewCameraDown);
    osd::selected=4;osd::items[4].visible=false;osd::refreshControls();assert(SendMessageW(osd::enabledBox,BM_GETCHECK,0,0)==BST_UNCHECKED);
    SendMessageW(osd::downVisibleBox,BM_SETCHECK,BST_UNCHECKED,0);SendMessageW(h,WM_COMMAND,MAKEWPARAM(212,BN_CLICKED),reinterpret_cast<LPARAM>(osd::downVisibleBox));
    assert(!osd::downCrossVisible&&!osd::items[4].visible);
    SendMessageW(osd::downVisibleBox,BM_SETCHECK,BST_CHECKED,0);SendMessageW(h,WM_COMMAND,MAKEWPARAM(212,BN_CLICKED),reinterpret_cast<LPARAM>(osd::downVisibleBox));
    assert(osd::downCrossVisible&&!osd::items[4].visible);osd::items[4].visible=true;
    osd::downCrossStyle=4;SendMessageW(osd::downStyleBox,CB_SETCURSEL,4,0);osd::previewCameraDown=false;SendMessageW(osd::previewDownBox,BM_SETCHECK,BST_UNCHECKED,0);osd::save();
    wchar_t ammoName[100]{};assert(SendMessageW(osd::list,LB_GETTEXT,13,reinterpret_cast<LPARAM>(ammoName))>0);
    assert(wcscmp(ammoName,language::tr(L"Запас гранат"))==0);
    assert(SendMessageW(osd::list,LB_SETCURSEL,13,0)==13);
    SendMessageW(h,WM_COMMAND,MAKEWPARAM(201,LBN_SELCHANGE),reinterpret_cast<LPARAM>(osd::list));assert(osd::selected==13);
    SendMessageW(osd::enabledBox,BM_SETCHECK,BST_UNCHECKED,0);
    SendMessageW(h,WM_COMMAND,MAKEWPARAM(202,BN_CLICKED),reinterpret_cast<LPARAM>(osd::enabledBox));assert(!osd::items[13].visible);
    osd::items=expectedItems;osd::selected=0;osd::save();osd::refreshControls();
    std::cout<<"PASS common F6/PDA OSD editor exposes selectable ammunition visibility and preserves earlier items\n";
    assert((GetWindowLongPtrW(h,GWL_STYLE)&(WS_THICKFRAME|WS_MAXIMIZEBOX))==(WS_THICKFRAME|WS_MAXIMIZEBOX));
    MINMAXINFO limits{};SendMessageW(h,WM_GETMINMAXINFO,0,reinterpret_cast<LPARAM>(&limits));assert(limits.ptMinTrackSize.x==800&&limits.ptMinTrackSize.y==520);
    MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);assert(GetMonitorInfoW(MonitorFromWindow(h,MONITOR_DEFAULTTONEAREST),&monitor));
    const int defaultWidth=std::min(1120L,monitor.rcWork.right-monitor.rcWork.left),defaultHeight=std::min(690L,monitor.rcWork.bottom-monitor.rcWork.top);
    const auto initial=windowRect(h);assert(initial.right-initial.left==defaultWidth&&initial.bottom-initial.top==defaultHeight);
    resize(1120,690);const auto original=geometry();const auto font=controlFont(osd::masterBox);const auto originalMaster=childRect(osd::masterBox);
    const HWND combos[]={osd::colorBox,osd::styleBox,osd::fontBox};const int selections[]={3,2,7};
    for(size_t i=0;i<std::size(combos);++i)assert(SendMessageW(combos[i],CB_SETCURSEL,selections[i],0)==selections[i]);
    resize(800,520);checkBounds();checkAspect(16.0/9);assert(std::abs(controlFont(osd::masterBox).lfHeight)<std::abs(font.lfHeight));
    assert(childRect(osd::masterBox).right-childRect(osd::masterBox).left<originalMaster.right-originalMaster.left);
    for(const auto combo:combos)checkDropdown(combo);
    resize(1400,900);checkBounds();checkAspect(16.0/9);assert(std::abs(controlFont(osd::masterBox).lfHeight)>std::abs(font.lfHeight));
    assert(childRect(osd::masterBox).right-childRect(osd::masterBox).left>originalMaster.right-originalMaster.left);
    for(const auto combo:combos)checkDropdown(combo);
    for(int cycle=0;cycle<5;++cycle){resize(800,520);resize(1400,900);resize(1120,690);}
    const auto restored=geometry();assert(restored.size()==original.size());
    for(size_t i=0;i<original.size();++i)assert(EqualRect(&restored[i],&original[i]));
    assert(controlFont(osd::masterBox).lfHeight==font.lfHeight);
    for(size_t i=0;i<std::size(combos);++i)assert(SendMessageW(combos[i],CB_GETCURSEL,0,0)==selections[i]);
    std::cout<<"PASS hidden OSD: bounds, proportional fonts/controls, dropdowns and resize stability\n";

    const auto game=CreateWindowExW(0,L"STATIC",L"OSD test viewport",WS_POPUP,0,0,1920,1080,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);assert(game&&!IsWindowVisible(game));
    for(const auto size:{SIZE{800,520},SIZE{1400,900}}){
        resize(size.cx,size.cy);pumpGame(game,1920,1080);const auto before=childRect(osd::preview);pumpGame(game,1920,1080);const auto after=childRect(osd::preview);assert(EqualRect(&before,&after));
        pumpGame(game,3440,1440);const auto wideBefore=childRect(osd::preview);pumpGame(game,3440,1440);const auto wideAfter=childRect(osd::preview);assert(EqualRect(&wideBefore,&wideAfter));
    }
    assert(DestroyWindow(game));checkItems(expectedItems);assert(osd::enabled&&osd::crossStyle==2&&osd::fontChoice==7&&osd::selected==0&&!osd::overlay);
    assert(layoutFile()==expectedLayout);
    std::cout<<"PASS OSD preview client aspect at 16:9/3440:1440, stable polling and unchanged flight layout\n";

    const int savedWidth=std::min(1000L,monitor.rcWork.right-monitor.rcWork.left),savedHeight=std::min(750L,monitor.rcWork.bottom-monitor.rcWork.top);
    resize(savedWidth,savedHeight);osd::saveEditorWindowSize();destroyEditor();
    {std::ifstream f(fixture/L"osd-editor-window.txt");int width=0,height=0,maximized=-1;assert((f>>width>>height>>maximized)&&width==savedWidth&&height==savedHeight&&maximized==0);}
    osd::createEditor(nullptr);const auto saved=windowRect(osd::editor.load());assert(saved.right-saved.left==savedWidth&&saved.bottom-saved.top==savedHeight);assert(!IsWindowVisible(osd::editor.load()));checkBounds();destroyEditor();
    for(const auto malformed:{"invalid","1120 690","799 690 0","1120 519 0","8193 690 0","1120 8193 0","1120 690 2","1120 690 0 extra"}){
        settings(malformed);osd::createEditor(nullptr);const auto r=windowRect(osd::editor.load());assert(r.right-r.left==defaultWidth&&r.bottom-r.top==defaultHeight);assert(!IsWindowVisible(osd::editor.load()));checkBounds();destroyEditor();
    }
    checkItems(expectedItems);assert(osd::enabled&&osd::crossStyle==2&&osd::fontChoice==7&&layoutFile()==expectedLayout&&!osd::overlay);
    assert(!weatherMenu::window.load()&&GetForegroundWindow()==foreground);
    osd::cleanup();fs::remove_all(fixture);
    std::cout<<"PASS OSD editor dimensions persistence, malformed-config rejection and no focus/overlay changes\n";
    return 0;
}
