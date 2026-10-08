#pragma once
#include <windowsx.h>
#include <atomic>
#include <cmath>
#include <sstream>
#include "ui_theme.h"
#define SendMessageW language::message
namespace osd {
inline fs::path root;
inline HWND overlay=nullptr,preview=nullptr,list=nullptr,sizeBox=nullptr,colorBox=nullptr,enabledBox=nullptr,masterBox=nullptr,styleBox=nullptr,downStyleBox=nullptr,previewDownBox=nullptr,downVisibleBox=nullptr;
inline std::atomic<HWND> editor{nullptr};
inline bool editing=false,enabled=true,cursorMode=false;
inline int selected=0,drag=-1,crossStyle=0,downCrossStyle=4;
inline bool downCrossVisible=true;
inline bool previewCameraDown=false;
inline ULONGLONG nextPoll=0,nextTelemetryPoll=0,lastChange=0,lastSeq=0;
inline RECT overlayPlacement{};
inline HWND overlayOrder=nullptr;
inline int publishedViewportWidth=0,publishedViewportHeight=0;
struct Data {bool active=false;double speed=0,altitude=0,distance=0,pitch=0,roll=0,heading=0,home=0,seconds=0,climb=0,throttle=0;
    bool signalEnabled=false;double rssi=100;bool signalLost=false;
    int noiseStyle=0;bool hpEnabled=false;double hpPercent=100;
    bool detectorEnabled=false;double artifactDistance=-1;bool artifactReady=false;
    bool grenadeEnabled=false;int grenadeRemaining=0;bool cameraDown=false;};
inline Data data;
inline bool parseTelemetry(std::istream& f,Data& result,ULONGLONG& sequence){
    int version=0,on=0,signalOn=0,lost=0;ULONGLONG seq=0,end=0;Data d;
    if(!(f>>version>>seq>>on>>d.speed>>d.altitude>>d.distance>>d.pitch>>d.roll>>d.heading>>d.home>>d.seconds>>d.climb>>d.throttle)
       ||(version<1||version>5)||(on!=0&&on!=1))return false;
    if(version>=2){
        if(!(f>>signalOn>>d.rssi>>lost)||(signalOn!=0&&signalOn!=1)||(lost!=0&&lost!=1)||
           !std::isfinite(d.rssi)||d.rssi<0||d.rssi>100||(!signalOn&&lost))return false;
        d.signalEnabled=signalOn==1;d.signalLost=lost==1;
    }
    if(version>=3){
        int hp=0,detector=0,ready=0;
        // Lua computes readiness against the selected collection distance.
        // The packet does not carry that preference; validate its 10 m ceiling.
        if(!(f>>d.noiseStyle>>hp>>d.hpPercent>>detector>>d.artifactDistance>>ready)||
           d.noiseStyle<0||d.noiseStyle>4||(hp!=0&&hp!=1)||(detector!=0&&detector!=1)||(ready!=0&&ready!=1)||
           !std::isfinite(d.hpPercent)||d.hpPercent<0||d.hpPercent>100||
           !std::isfinite(d.artifactDistance)||d.artifactDistance< -1||d.artifactDistance>1e8||
           (ready&&(!detector||d.artifactDistance<0||d.artifactDistance>10)))return false;
        d.hpEnabled=hp==1;d.detectorEnabled=detector==1;d.artifactReady=ready==1;
    }
    if(version>=4){
        int grenadeOn=0;
        if(!(f>>grenadeOn>>d.grenadeRemaining)||(grenadeOn!=0&&grenadeOn!=1)||d.grenadeRemaining< -1||d.grenadeRemaining>20
            ||(!grenadeOn&&d.grenadeRemaining!=0))return false;
        d.grenadeEnabled=grenadeOn==1;
    }
    if(version>=5){int down=0;if(!(f>>down)||(down!=0&&down!=1)||(!on&&down))return false;d.cameraDown=down==1;}
    std::string extra;if(!(f>>end)||seq!=end||(f>>extra))return false;
    for(double v:{d.speed,d.altitude,d.distance,d.pitch,d.roll,d.heading,d.home,d.seconds,d.climb,d.throttle})
        if(!std::isfinite(v)||std::abs(v)>1e8)return false;
    d.active=on==1;result=d;sequence=seq;return true;
}
struct ScanMarker {int type=0;double x=0,y=0,distance=0,width=0,height=0;int relation=-1,faction=0;};
inline std::vector<ScanMarker> scanMarkers;
struct ScanLease {ULONGLONG generation=0,sequence=0,changed=0;bool observed=false,available=false,everV4=false;};
inline ScanLease scanLease;
inline bool parseScanFrame(std::istream& f,std::vector<ScanMarker>& result,ULONGLONG& sequence,ULONGLONG* generation=nullptr){
    int version=0,count=0;ULONGLONG epoch=0,seq=0,end=0;
    if(!(f>>version)||(version<1||version>4))return false;
    if(version==4&&(!(f>>epoch)||epoch==0||epoch>=0x20000000000000ull))return false;
    if(!(f>>seq>>count)||count<0||count>64||(version==4&&seq>=0x20000000000000ull))return false;
    std::vector<ScanMarker> markers;markers.reserve(static_cast<size_t>(count));
    for(int i=0;i<count;++i){ScanMarker m;
        if(!(f>>m.type>>m.x>>m.y))return false;
        if(version>=2&&(!(f>>m.width>>m.height)||!std::isfinite(m.width)||!std::isfinite(m.height)||
           m.width<=0||m.width>1||m.height<=0||m.height>1||
           m.x-m.width/2< -0.00001||m.x+m.width/2>1.00001||m.y-m.height/2< -0.00001||m.y+m.height/2>1.00001))return false;
        if(!(f>>m.distance)||m.type<1||m.type>4||!std::isfinite(m.x)||!std::isfinite(m.y)||
           !std::isfinite(m.distance)||m.x<0||m.x>1||m.y<0||m.y>1||m.distance<0||m.distance>1e8)return false;
        if(version>=3&&(!(f>>m.relation>>m.faction)||m.relation< -1||m.relation>4||m.faction<0||m.faction>14))return false;
        markers.push_back(m);
    }
    if(version==4){ULONGLONG trailerGeneration=0;if(!(f>>trailerGeneration)||trailerGeneration!=epoch)return false;}
    std::string extra;if(!(f>>end)||end!=seq||(f>>extra))return false;
    result=std::move(markers);sequence=seq;if(generation)*generation=epoch;return true;
}
// Screen-space brackets belong to one projected game frame. A duplicate read
// must never renew that frame; missing/torn packets and FPV exit revoke it.
// A newly numbered complete packet, including a Lua sequence restart, can
// acquire a fresh lease without interpolating unrelated distance-sorted rows.
inline void updateScanFrame(std::istream& input,bool active,ULONGLONG now,
                            std::vector<ScanMarker>& result,ScanLease& lease){
    if(!active){result.clear();lease.available=false;return;}
    std::vector<ScanMarker> markers;ULONGLONG sequence=0,generation=0;
    if(!parseScanFrame(input,markers,sequence,&generation)||generation!=0){result.clear();lease.available=false;return;}
    if(!lease.observed||sequence!=lease.sequence){
        lease.sequence=sequence;lease.changed=now;lease.observed=true;lease.available=true;
        result=std::move(markers);return;
    }
    if(!lease.available||now<lease.changed||now-lease.changed>=100){
        result.clear();lease.available=false;
    }
}
// Lua alternates two owned files on Windows: one complete slot survives while
// the other is being overwritten. Select a complete generation/sequence pair;
// never fall back to an older rectangle after observing a newer game frame.
inline void updateScanFrames(std::istream& first,std::istream& second,std::istream& legacy,
                            bool active,ULONGLONG now,std::vector<ScanMarker>& result,ScanLease& lease){
    if(!active){result.clear();lease.available=false;return;}
    std::vector<ScanMarker> a,b;ULONGLONG seqA=0,seqB=0,genA=0,genB=0;
    const bool validA=parseScanFrame(first,a,seqA,&genA)&&genA>0;
    const bool validB=parseScanFrame(second,b,seqB,&genB)&&genB>0;
    if(!validA&&!validB){
        if(!lease.everV4){updateScanFrame(legacy,active,now,result,lease);return;}
        result.clear();lease.available=false;return;
    }
    const bool useA=validA&&(!validB||genA>genB||(genA==genB&&seqA>=seqB));
    const auto generation=useA?genA:genB,sequence=useA?seqA:seqB;
    if(!lease.everV4||generation>lease.generation||(generation==lease.generation&&sequence>lease.sequence)){
        lease.generation=generation;lease.sequence=sequence;lease.changed=now;
        lease.observed=true;lease.available=true;lease.everV4=true;
        result=useA?std::move(a):std::move(b);return;
    }
    if(!lease.available||now<lease.changed||now-lease.changed>=100){result.clear();lease.available=false;}
}
inline DWORD scanPollInterval(const std::vector<ScanMarker>& markers){return markers.empty()?50u:8u;}
inline const wchar_t* factionIconNames[]={L"",L"bandits",L"corpus",L"duty",L"freedom",L"ipsf",L"loners",
    L"mercenaries",L"monolith",L"noontide",L"scientists",L"spark",L"ward",L"ndichaz",L"x"};
inline COLORREF scanColor(const ScanMarker& m){
    if(m.type==3)return RGB(255,211,60);
    if(m.type==4)return RGB(55,224,255);
    if(m.relation==0||m.relation==1)return RGB(239,70,78);
    if(m.relation==3||m.relation==4)return RGB(80,220,115);
    if(m.relation==2)return RGB(232,229,207);
    return RGB(170,170,165); // Missing metadata is not a fabricated neutral relation.
}
struct FactionIcon {bool checked=false;std::array<unsigned char,4096> alpha{};HDC dc=nullptr;HBITMAP bitmap=nullptr;
    HGDIOBJ previous=nullptr;DWORD* pixels=nullptr;COLORREF color=CLR_INVALID;};
inline std::array<FactionIcon,15> factionIcons;
inline void drawFactionIcon(HDC target,int faction,int x,int y,int size,COLORREF color){
    if(faction<1||faction>14)return;
    auto& icon=factionIcons[static_cast<size_t>(faction)];
    if(!icon.checked){
        icon.checked=true;
        std::ifstream file(root/L"icons"/L"binoculars"/(std::wstring(factionIconNames[faction])+L".mask"),std::ios::binary);
        if(!file.read(reinterpret_cast<char*>(icon.alpha.data()),4096)||file.peek()!=EOF)return;
        BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=64;info.bmiHeader.biHeight=-64;
        info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;
        void* pixels=nullptr;icon.bitmap=CreateDIBSection(nullptr,&info,DIB_RGB_COLORS,&pixels,nullptr,0);
        if(!icon.bitmap||!pixels)return;
        icon.pixels=static_cast<DWORD*>(pixels);icon.dc=CreateCompatibleDC(target);
        if(!icon.dc){DeleteObject(icon.bitmap);icon.bitmap=nullptr;return;}
        icon.previous=SelectObject(icon.dc,icon.bitmap);
    }
    if(!icon.dc)return;
    if(icon.color!=color){
        GdiFlush();
        for(size_t i=0;i<icon.alpha.size();++i){const DWORD a=icon.alpha[i];
            icon.pixels[i]=(a<<24)|((GetRValue(color)*a/255)<<16)|((GetGValue(color)*a/255)<<8)|(GetBValue(color)*a/255);
        }
        icon.color=color;
    }
    const BLENDFUNCTION blend{AC_SRC_OVER,0,255,AC_SRC_ALPHA};
    AlphaBlend(target,x,y,size,size,icon.dc,0,0,64,64,blend);
}
struct Item{double x,y;int size,color;bool visible;};
inline constexpr int itemCount=14;
inline const std::array<Item,itemCount> defaults={{{.14,.80,24,0,true},{.82,.80,24,0,true},{.82,.86,24,0,true},{.50,.50,24,0,true},{.50,.50,24,0,true},{.14,.86,24,0,true},{.50,.12,24,0,true},{.50,.21,24,0,true},{.14,.73,24,0,false},{.82,.73,24,0,false},{.14,.66,24,0,true},{.90,.09,14,0,true},{.90,.14,14,3,true},{.90,.19,14,2,true}}};
inline auto items=defaults;
inline const wchar_t* names[]={L"Speed / km/h",L"Altitude / m (home)",L"Home distance / m",L"Artificial horizon",L"Crosshair",L"Flight timer",L"Heading / degrees",L"Home direction",L"Throttle / %",L"Vertical speed / m/s",L"RSSI / % (simulated)",L"Здоровье дрона / %",L"Детектор артефактов",L"Запас гранат"};
static_assert(std::size(names)==itemCount);
inline COLORREF colors[]={RGB(255,255,255),RGB(80,255,110),RGB(255,220,60),RGB(60,225,255),RGB(255,110,110)};
inline RECT bounds[itemCount]{};
inline int fontChoice=0;
inline HWND fontBox=nullptr;
inline const wchar_t* fontNames[]={L"Consolas",L"Betaflight",L"Cascadia Mono",L"Courier New",L"Lucida Console",L"Segoe UI",L"Arial",L"Bahnschrift"};
inline HFONT fonts[8][87]{};
inline HDC glyphDC[5]{};
inline HBITMAP glyphBitmap[5]{};
inline HGDIOBJ glyphOld[5]{};
#pragma comment(lib,"msimg32.lib")
inline bool loadBetaflight(){
    if(glyphDC[0])return true;
    std::ifstream in(root/L"fonts"/L"betaflight.mcm");std::string text;
    if(!(in>>text)||text!="MAX7456")return false;
    std::array<unsigned char,256*64> bytes{};
    for(auto& b:bytes){if(!(in>>text)||text.size()!=8||text.find_first_not_of("01")!=std::string::npos)return false;b=static_cast<unsigned char>(std::stoi(text,nullptr,2));}
    for(int color=0;color<5;++color){
        BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=192;info.bmiHeader.biHeight=-288;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;
        void* pixels=nullptr;glyphBitmap[color]=CreateDIBSection(nullptr,&info,DIB_RGB_COLORS,&pixels,nullptr,0);if(!pixels)return false;
        auto* out=static_cast<DWORD*>(pixels);std::fill(out,out+192*288,0u);
        for(int ch=0;ch<256;++ch)for(int y=0;y<18;++y)for(int x=0;x<12;++x){const int pixel=y*12+x;const int value=(bytes[ch*64+pixel/4]>>(6-2*(pixel%4)))&3;const auto c=colors[color];const DWORD rgb=(GetRValue(c)<<16)|(GetGValue(c)<<8)|GetBValue(c);out[((ch/16)*18+y)*192+(ch%16)*12+x]=value==0?0x010101u:value==2?rgb:0;}
        glyphDC[color]=CreateCompatibleDC(nullptr);glyphOld[color]=SelectObject(glyphDC[color],glyphBitmap[color]);
    }
    return true;
}
inline SIZE bitmapText(HDC dc,const wchar_t* text,int x,int y,int height,int color,bool paint){
    const int width=std::max(1,height*12/18);int count=0;
    for(;text[count];++count){unsigned ch=static_cast<unsigned>(towupper(text[count]));if(ch>255)ch='?';if(paint)TransparentBlt(dc,x+count*width,y,width,height,glyphDC[color],(ch%16)*12,(ch/16)*18,12,18,RGB(0,0,0));}
    return {count*width,height};
}
inline double screenAspect=static_cast<double>(GetSystemMetrics(SM_CXSCREEN))/std::max(1,GetSystemMetrics(SM_CYSCREEN));
struct EditorControlLayout {HWND handle;int x,y,width,height;};
inline std::vector<EditorControlLayout> editorControls;
inline int editorWidth=0,editorHeight=0,editorFontHeight=0;
inline LOGFONTW editorBaseFont{};
inline HFONT editorFont=nullptr;
inline bool editorStartMaximized=false;
inline constexpr DWORD editorStyle=WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_THICKFRAME|WS_MAXIMIZEBOX|WS_CLIPCHILDREN;
inline SIZE editorWindowSize(HWND h){
    int width=1120,height=690,maximized=0;std::string extra;
    std::ifstream file(root/L"osd-editor-window.txt");
    if(!(file>>width>>height>>maximized)||(file>>extra)||width<800||height<520||
       width>8192||height>8192||(maximized!=0&&maximized!=1)){
        width=1120;height=690;maximized=0;
    }
    editorStartMaximized=maximized!=0;
    MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);
    if(GetMonitorInfoW(MonitorFromWindow(h,MONITOR_DEFAULTTONEAREST),&monitor)){
        width=std::min(width,static_cast<int>(monitor.rcWork.right-monitor.rcWork.left));
        height=std::min(height,static_cast<int>(monitor.rcWork.bottom-monitor.rcWork.top));
    }
    return {width,height};
}
inline void saveEditorWindowSize(HWND h=editor.load()){
    if(!h)return;
    WINDOWPLACEMENT placement{};placement.length=sizeof(placement);
    if(!GetWindowPlacement(h,&placement))return;
    const auto& rect=placement.rcNormalPosition;
    const auto temp=root/L"osd-editor-window.tmp",destination=root/L"osd-editor-window.txt";
    std::ofstream file(temp);file<<rect.right-rect.left<<' '<<rect.bottom-rect.top<<' '<<(IsZoomed(h)?1:0)<<'\n';file.close();
    if(file)MoveFileExW(temp.c_str(),destination.c_str(),MOVEFILE_REPLACE_EXISTING);
}
inline void resizeEditor(HWND h){
    if(editorWidth<=0||editorHeight<=0||editorControls.empty())return;
    RECT client{};if(!GetClientRect(h,&client)||client.right<=0||client.bottom<=0)return;
    const double scaleX=static_cast<double>(client.right)/editorWidth;
    const double scaleY=static_cast<double>(client.bottom)/editorHeight;
    const auto height=static_cast<int>(std::lround(editorBaseFont.lfHeight*std::min(scaleX,scaleY)));
    if(height!=editorFontHeight){
        auto font=editorBaseFont;font.lfHeight=height;
        if(const auto replacement=CreateFontIndirectW(&font)){
            for(const auto& item:editorControls)SendMessageW(item.handle,WM_SETFONT,reinterpret_cast<WPARAM>(replacement),FALSE);
            if(editorFont)DeleteObject(editorFont);
            editorFont=replacement;editorFontHeight=height;
        }
    }
    const auto scaled=[](int value,double scale){return static_cast<int>(std::lround(value*scale));};
    constexpr UINT flags=SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOOWNERZORDER|SWP_NOREDRAW;
    for(const auto& item:editorControls){
        int x=scaled(item.x,scaleX),y=scaled(item.y,scaleY);
        int width=scaled(item.width,scaleX),controlHeight=scaled(item.height,scaleY);
        if(item.handle==preview){
            // Fit the *client* preview to the game aspect, allowing for its border.
            // The editor window size never changes the saved OSD coordinates.
            RECT border{};AdjustWindowRectEx(&border,static_cast<DWORD>(GetWindowLongPtrW(preview,GWL_STYLE)),FALSE,0);
            const int borderWidth=border.right-border.left,borderHeight=border.bottom-border.top;
            const int availableHeight=scaled(500,scaleY);
            const int innerWidth=std::max(1,width-borderWidth),innerHeight=std::max(1,availableHeight-borderHeight);
            const auto aspect=std::isfinite(screenAspect)&&screenAspect>0?screenAspect:16./9.;
            const int fittedWidth=std::max(1,std::min(innerWidth,static_cast<int>(std::floor(innerHeight*aspect))));
            controlHeight=std::max(1,static_cast<int>(std::lround(fittedWidth/aspect)))+borderHeight;
            x+=(width-fittedWidth-borderWidth)/2;width=fittedWidth+borderWidth;
        }
        SetWindowPos(item.handle,nullptr,x,y,width,controlHeight,flags);
    }
    RedrawWindow(h,nullptr,nullptr,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN);
}
inline HFONT font(int size){size=std::clamp(size,10,96);auto& f=fonts[fontChoice][size-10];if(!f)f=CreateFontW(-size,0,0,0,FW_BOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,NONANTIALIASED_QUALITY,FIXED_PITCH,fontNames[fontChoice]);return f;}

struct Surface{HDC dc=nullptr;HBITMAP bitmap=nullptr;HGDIOBJ old=nullptr;int w=0,h=0;
    void clear(){if(dc){SelectObject(dc,old);DeleteObject(bitmap);DeleteDC(dc);}dc=nullptr;}
    HDC get(HDC target,int width,int height){if(!dc||w!=width||h!=height){clear();w=width;h=height;dc=CreateCompatibleDC(target);bitmap=CreateCompatibleBitmap(target,w,h);old=SelectObject(dc,bitmap);}return dc;}
};
inline Surface overlaySurface,previewSurface;
inline bool save(){
    auto path=root/L"osd-layout.tmp";std::ofstream f(path);f<<"7 "<<enabled<<' '<<crossStyle<<' '<<fontChoice<<' '<<downCrossStyle<<' '<<downCrossVisible<<'\n';
    for(const auto& e:items)f<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';
    f.close();return f&&MoveFileExW(path.c_str(),(root/L"osd-layout.txt").c_str(),MOVEFILE_REPLACE_EXISTING);
}
inline bool load(){
    std::ifstream f(root/L"osd-layout.txt");int v=0,on=1,style=0,downStyle=4,downVisible=1;auto candidate=defaults;
    if(!(f>>v>>on>>style)||(v<1||v>7)||on<0||on>1||style<0||style>(v>=6?5:2))return false;
    int face=0;if(v>=2&&(!(f>>face)||face<0||face>=8))return false;
    if(v>=6&&(!(f>>downStyle)||downStyle<0||downStyle>5))return false;
    if(v>=7&&(!(f>>downVisible)||downVisible<0||downVisible>1))return false;
    for(int i=0;i<(v>=5?itemCount:v==4?13:v==3?11:10);++i){auto& e=candidate[i];int visible=0;if(!(f>>e.x>>e.y>>e.size>>e.color>>visible)||!std::isfinite(e.x)||!std::isfinite(e.y)||e.x<0||e.x>1||e.y<0||e.y>1||e.size<14||e.size>72||e.color<0||e.color>4||visible<0||visible>1)return false;e.visible=visible!=0;}
    std::string extra;if(v>=6&&(f>>extra))return false;
    items=candidate;enabled=on!=0;crossStyle=style;fontChoice=face;downCrossStyle=downStyle;downCrossVisible=downVisible!=0;return true;
}
inline void line(HDC dc,int x1,int y1,int x2,int y2,COLORREF color,int width=2){
    auto pen=CreatePen(PS_SOLID,width+2,RGB(1,1,1));auto old=SelectObject(dc,pen);MoveToEx(dc,x1,y1,nullptr);LineTo(dc,x2,y2);SelectObject(dc,old);DeleteObject(pen);
    pen=CreatePen(PS_SOLID,width,color);old=SelectObject(dc,pen);MoveToEx(dc,x1,y1,nullptr);LineTo(dc,x2,y2);SelectObject(dc,old);DeleteObject(pen);
}
inline bool itemVisible(int i,const Data& value){return i==4&&value.cameraDown?downCrossVisible:items[i].visible;}
inline int crossStyleFor(const Data& value){return value.cameraDown?downCrossStyle:crossStyle;}
inline void circle(HDC dc,int x,int y,int radius,COLORREF color){
    auto brush=SelectObject(dc,GetStockObject(HOLLOW_BRUSH));
    for(int pass=0;pass<2;++pass){auto pen=CreatePen(PS_SOLID,pass?2:4,pass?color:RGB(1,1,1));auto old=SelectObject(dc,pen);
        Ellipse(dc,x-radius,y-radius,x+radius+1,y+radius+1);SelectObject(dc,old);DeleteObject(pen);}
    SelectObject(dc,brush);
}
inline std::wstring grenadeText(const Data& d){return d.grenadeRemaining<0?L"GRENADES INF":L"GRENADES "+std::to_wstring(d.grenadeRemaining);}
inline void draw(HDC dc,RECT area,bool sample){
    const double w=area.right-area.left,h=area.bottom-area.top;
    Data d=data;if(sample&&!d.active){d={true,64,25,120,10,12,85,35,125,2.1,42,true,63,false,0,true,86,true,28.9,false,true,3};}
    if(sample)d.cameraDown=previewCameraDown;
    SetBkMode(dc,TRANSPARENT);
    for(int i=0;i<itemCount;++i){const auto& e=items[i];
        if(!itemVisible(i,d)||(i==3&&d.cameraDown)||(i==10&&!d.signalEnabled&&!sample)||
           (i==11&&!sample&&(!d.hpEnabled||d.signalLost||cursorMode))||
           (i==12&&!sample&&(!d.detectorEnabled||d.signalLost||cursorMode))||
           (i==13&&!sample&&(!d.grenadeEnabled||d.signalLost||cursorMode))){bounds[i]={};continue;}
        const int px=static_cast<int>(e.x*w),py=static_cast<int>(e.y*h);
        const int sz=std::clamp(static_cast<int>(e.size*h/900.0),10,90);
        const int colorIndex=i==11&&d.hpPercent<=25?4:e.color;
        const auto color=colors[colorIndex];wchar_t text[100]{};
        if(i==3){
            const double a=-d.roll*3.141592653589793/180;
            const int offset=static_cast<int>(std::clamp(d.pitch,-70.,70.)*sz/15);
            const int cx=px+static_cast<int>(std::sin(a)*offset),cy=py+static_cast<int>(std::cos(a)*offset);
            for(int side:{-1,1})line(dc,cx+static_cast<int>(std::cos(a)*sz*side),cy+static_cast<int>(std::sin(a)*sz*side),cx+static_cast<int>(std::cos(a)*sz*4*side),cy+static_cast<int>(std::sin(a)*sz*4*side),color);
            bounds[i]={px-5*sz,py-4*sz,px+5*sz,py+4*sz};
        }else if(i==4){
            const auto style=crossStyleFor(d);
            if(style==1){line(dc,px-1,py,px+2,py,color,3);}
            else if(style==3||style==4){circle(dc,px,py,sz/2,color);if(style==4)line(dc,px-1,py,px+2,py,color,3);}
            else if(style==5){const int radius=sz/2,segment=std::max(2,sz/4);for(int sx:{-1,1})for(int sy:{-1,1}){
                line(dc,px+sx*radius,py+sy*radius,px+sx*(radius-segment),py+sy*radius,color);
                line(dc,px+sx*radius,py+sy*radius,px+sx*radius,py+sy*(radius-segment),color);}}
            else{const int gap=style==2?sz/3:0;for(int sign:{-1,1}){line(dc,px+sign*gap,py,px+sign*sz/2,py,color);line(dc,px,py+sign*gap,px,py+sign*sz/2,color);}}
            bounds[i]={px-sz,py-sz,px+sz,py+sz};
        }else if(i==7){
            const double a=d.home*3.141592653589793/180;const int dx=static_cast<int>(std::sin(a)*sz),dy=static_cast<int>(-std::cos(a)*sz);
            line(dc,px-dx,py-dy,px+dx,py+dy,color);line(dc,px+dx,py+dy,px+dy/2,py-dx/2,color);line(dc,px+dx,py+dy,px-dy/2,py+dx/2,color);
            bounds[i]={px-2*sz,py-2*sz,px+2*sz,py+2*sz};
        }else{
            if(i==0)swprintf_s(text,L"SPD %.0f km/h",d.speed);
            if(i==1)swprintf_s(text,L"ALT %+.1f m",d.altitude);
            if(i==2)swprintf_s(text,L"HOME %.0f m",d.distance);
            if(i==5)swprintf_s(text,L"%02d:%02d",static_cast<int>(d.seconds)/60,static_cast<int>(d.seconds)%60);
            if(i==6)swprintf_s(text,L"HDG %03.0f",d.heading);
            if(i==8)swprintf_s(text,L"THR %.0f%%",d.throttle);
            if(i==9)swprintf_s(text,L"V/S %+.1f m/s",d.climb);
            if(i==10){if(d.signalLost)swprintf_s(text,L"RSSI 0%% / LOST");else swprintf_s(text,L"RSSI %.0f%%",d.rssi);}
            if(i==11)swprintf_s(text,L"DRONE HP  %.0f%%",d.hpPercent);
            if(i==12){
                if(d.artifactDistance<0)swprintf_s(text,L"DETECTOR  --");
                else if(d.artifactReady)swprintf_s(text,L"ARTIFACT  %.1f m / COLLECT",d.artifactDistance);
                else swprintf_s(text,L"DETECTOR  %.1f m",d.artifactDistance);
            }
            if(i==13)swprintf_s(text,L"%s",grenadeText(d).c_str());
            auto old=SelectObject(dc,font(sz));SIZE extent{};GetTextExtentPoint32W(dc,text,static_cast<int>(wcslen(text)),&extent);
            const bool bitmap=fontChoice==1&&loadBetaflight();if(bitmap)extent=bitmapText(dc,text,0,0,sz,colorIndex,false);
            const int x=std::clamp(px-static_cast<int>(extent.cx)/2,0,std::max(0,static_cast<int>(w)-static_cast<int>(extent.cx))),y=std::clamp(py-static_cast<int>(extent.cy)/2,0,std::max(0,static_cast<int>(h)-static_cast<int>(extent.cy)));
            if(bitmap){bitmapText(dc,text,x,y,sz,colorIndex,true);}else{
            SetTextColor(dc,RGB(1,1,1));for(int ox:{-1,1})for(int oy:{-1,1})TextOutW(dc,x+ox,y+oy,text,static_cast<int>(wcslen(text)));
            SetTextColor(dc,color);TextOutW(dc,x,y,text,static_cast<int>(wcslen(text)));}SelectObject(dc,old);bounds[i]={x,y,x+extent.cx,y+extent.cy};
        }
        if(sample&&selected==i){auto brush=CreateSolidBrush(RGB(80,150,255));FrameRect(dc,&bounds[i],brush);DeleteObject(brush);}
    }
}
inline const wchar_t* visibilityLabel(bool crosshair=false){
    static const wchar_t* labels[2][5]={
        {L"Отображать",L"Відображати",L"Show",L"Wyświetlaj",L"Anzeigen"},
        {L"Обычный прицел: отображать",L"Звичайний приціл: відображати",L"Show normal crosshair",L"Wyświetlaj zwykły celownik",L"Normales Fadenkreuz anzeigen"}};
    return labels[crosshair?1:0][std::clamp(language::current,0,4)];
}
inline void refreshControls(){const auto& e=items[selected];SendMessageW(enabledBox,BM_SETCHECK,e.visible?BST_CHECKED:BST_UNCHECKED,0);SendMessageW(downVisibleBox,BM_SETCHECK,downCrossVisible?BST_CHECKED:BST_UNCHECKED,0);SetWindowTextW(enabledBox,visibilityLabel(selected==4));SetWindowTextW(sizeBox,std::to_wstring(e.size).c_str());SendMessageW(colorBox,CB_SETCURSEL,e.color,0);InvalidateRect(preview,nullptr,FALSE);}
// Bounded GDI work, 20 Hz with the existing overlay. No post-process/world scans.
inline unsigned noiseSeed=1;
template<int Width,int Height> struct BasicNoiseTexture {
    HDC dc=nullptr;HBITMAP bitmap=nullptr;HGDIOBJ old=nullptr;DWORD* pixels=nullptr;
    static constexpr int width=Width,height=Height;
    bool create(){
        if(dc)return true;
        BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=width;
        info.bmiHeader.biHeight=-height;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;
        void* memory=nullptr;bitmap=CreateDIBSection(nullptr,&info,DIB_RGB_COLORS,&memory,nullptr,0);
        if(!bitmap||!memory){if(bitmap)DeleteObject(bitmap);bitmap=nullptr;return false;}
        pixels=static_cast<DWORD*>(memory);dc=CreateCompatibleDC(nullptr);if(!dc){DeleteObject(bitmap);bitmap=nullptr;pixels=nullptr;return false;}
        old=SelectObject(dc,bitmap);return true;
    }
    void clear(){if(dc){SelectObject(dc,old);DeleteDC(dc);}if(bitmap)DeleteObject(bitmap);dc=nullptr;bitmap=nullptr;pixels=nullptr;}
};
using NoiseTexture=BasicNoiseTexture<384,216>;
using FineNoiseTexture=BasicNoiseTexture<640,360>;
inline NoiseTexture noiseTexture;
inline FineNoiseTexture fineNoiseTexture;
inline ULONGLONG nextFineNoise=0;
inline double fineNoiseStrength=-1;
inline bool fineNoiseLost=false;
inline unsigned noiseRandom(){noiseSeed=noiseSeed*1664525u+1013904223u;return noiseSeed;}
inline double fineNoiseDensity(double strength){return std::clamp(std::pow(strength,1.12)*1.02,0.,.985);}
inline void drawFineSignalNoise(HDC dc,RECT rc,double strength){
    if(!fineNoiseTexture.create())return;
    const auto now=GetTickCount64();
    if(now>=nextFineNoise||fineNoiseStrength<0||fineNoiseLost!=data.signalLost){
        nextFineNoise=now+50;fineNoiseStrength=strength;fineNoiseLost=data.signalLost;
        // Bounded 640x360 texture generated at 20 Hz, regardless of scan refresh.
        // Colour-keyed gaps show the live game; no game capture or GPU readback.
        const auto threshold=static_cast<unsigned>(fineNoiseDensity(strength)*65536);
        for(int y=0;y<FineNoiseTexture::height;++y){
            const auto row=noiseRandom();const auto chroma=static_cast<unsigned>(32+96*strength);
            for(int x=0;x<FineNoiseTexture::width;++x){
                const auto value=noiseRandom();DWORD pixel=0;
                if((value>>16)<threshold){
                    const unsigned light=24+((value>>3)&191);
                    const unsigned r=std::min(255u,light+((value>>26)&31));
                    const unsigned g=(light+((row>>19)&chroma))&255;
                    const unsigned b=(light+((value>>24)&chroma))&255;
                    pixel=(r<<16)|(g<<8)|b;
                }
                fineNoiseTexture.pixels[y*FineNoiseTexture::width+x]=pixel;
            }
        }
        // Full-width receiver synchronisation tears. Low RSSI adds rolling
        // near-black intervals, rather than large opaque digital rectangles.
        const int tears=1+static_cast<int>(strength*strength*26);
        for(int i=0;i<tears;++i){
            const int row=static_cast<int>(noiseRandom()%FineNoiseTexture::height);
            const int thick=1+static_cast<int>(noiseRandom()%3);
            for(int y=row;y<std::min(FineNoiseTexture::height,row+thick);++y)
                for(int x=0;x<FineNoiseTexture::width;++x){
                    const auto value=noiseRandom();const unsigned light=120+((value>>16)&127);
                    fineNoiseTexture.pixels[y*FineNoiseTexture::width+x]=(light<<16)|(light<<8)|light;
                }
        }
        if(strength>.6){
            const int count=1+static_cast<int>((strength-.6)*7);
            const int offset=static_cast<int>((now/6)%FineNoiseTexture::height);
            for(int i=0;i<count;++i){
                const int row=(offset+i*97)%FineNoiseTexture::height;
                const int thick=3+static_cast<int>((strength-.6)*35);
                for(int y=row;y<std::min(FineNoiseTexture::height,row+thick);++y)
                    for(int x=0;x<FineNoiseTexture::width;++x)
                        fineNoiseTexture.pixels[y*FineNoiseTexture::width+x]=(noiseRandom()%11)*0x010101u+0x010101u;
            }
        }
    }
    TransparentBlt(dc,0,0,rc.right,rc.bottom,fineNoiseTexture.dc,0,0,FineNoiseTexture::width,FineNoiseTexture::height,RGB(0,0,0));
}
inline void drawSignalNoise(HDC dc,RECT rc){
    if(!data.active||!data.signalEnabled)return;
    const double strength=std::clamp(((data.noiseStyle==4?82.:60.)-data.rssi)/(data.noiseStyle==4?82.:60.),0.,1.);
    if(strength<=0)return;
    auto random=[](){return noiseRandom();};
    const int width=rc.right,height=rc.bottom;if(width<1||height<1)return;
    if(data.signalLost){SetDCBrushColor(dc,RGB(16,16,16));FillRect(dc,&rc,static_cast<HBRUSH>(GetStockObject(DC_BRUSH)));}
    if(data.noiseStyle==4)drawFineSignalNoise(dc,rc,strength);
    // Low-resolution colour-keyed texture: bounded CPU work, no capture/readback
    // of game pixels. Transparent gaps leave the original game image intact.
    if((data.noiseStyle==1||data.noiseStyle==2)&&noiseTexture.create()){
        const auto threshold=static_cast<unsigned>(strength*(data.signalLost?100:38));
        for(int y=0;y<NoiseTexture::height;++y)for(int x=0;x<NoiseTexture::width;++x){
            const auto value=random();DWORD pixel=0;
            if(value%100<threshold){
                const auto brightness=48+((value>>12)&159);
                if(data.noiseStyle==2)pixel=(brightness<<16)|(brightness<<8)|brightness;
                else {const auto channel=(value>>24)%3;pixel=channel==0?(brightness<<16)|(35<<8)|82:channel==1?(25<<16)|(brightness<<8)|76:(80<<16)|(45<<8)|brightness;}
            }
            noiseTexture.pixels[y*NoiseTexture::width+x]=pixel;
        }
        TransparentBlt(dc,0,0,width,height,noiseTexture.dc,0,0,NoiseTexture::width,NoiseTexture::height,RGB(0,0,0));
    }
    if(data.noiseStyle==3){
        const int blocks=static_cast<int>(strength*150)+(data.signalLost?50:0);
        for(int i=0;i<blocks;++i){
            const int blockWidth=std::max(6,width/55),blockHeight=std::max(3,height/70);
            const int x=static_cast<int>(random()%static_cast<unsigned>(width/blockWidth+1))*blockWidth;
            const int y=static_cast<int>(random()%static_cast<unsigned>(height/blockHeight+1))*blockHeight;
            RECT block{x,y,std::min(width,x+blockWidth*(1+static_cast<int>(random()%5))),std::min(height,y+blockHeight)};
            const auto value=random();SetDCBrushColor(dc,RGB(24+(value&159),20+((value>>8)&159),22+((value>>16)&159)));
            FillRect(dc,&block,static_cast<HBRUSH>(GetStockObject(DC_BRUSH)));
        }
    }
    const int bands=data.noiseStyle==4?0:static_cast<int>(strength*(data.noiseStyle==0?42:18))+(data.signalLost?16:0);
    for(int i=0;i<bands;++i){
        const int x=static_cast<int>(random()%static_cast<unsigned>(width));
        const int y=static_cast<int>(random()%static_cast<unsigned>(height));
        const int length=std::min(width-x,8+static_cast<int>(random()%static_cast<unsigned>(std::max(1,width/2))));
        const int thick=1+static_cast<int>(random()%static_cast<unsigned>(data.signalLost?12:3));
        RECT band{x,y,x+length,std::min(height,y+thick)};
        SetDCBrushColor(dc,(random()&1)?RGB(190,190,190):RGB(3,3,3));
        FillRect(dc,&band,static_cast<HBRUSH>(GetStockObject(DC_BRUSH)));
    }
    if(data.signalLost){
        const auto old=SelectObject(dc,font(std::max(18,height/30)));SetBkMode(dc,TRANSPARENT);
        RECT label{0,height/3,width,height/3+height/12};SetTextColor(dc,RGB(1,1,1));
        const auto message=data.hpEnabled&&data.hpPercent<=0?L"DRONE DESTROYED":L"SIGNAL LOST";
        DrawTextW(dc,message,-1,&label,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
        OffsetRect(&label,-1,-1);SetTextColor(dc,RGB(255,255,255));
        DrawTextW(dc,message,-1,&label,DT_CENTER|DT_VCENTER|DT_SINGLELINE);SelectObject(dc,old);
    }
}
inline void drawExperiments(HDC dc,RECT rc){
    if(!data.active)return;
    const int width=rc.right,height=rc.bottom;if(width<1||height<1)return;
    SetBkMode(dc,TRANSPARENT);
    const int labelHeight=std::clamp(height/75,12,20);
    const auto oldFont=SelectObject(dc,font(labelHeight));
    const wchar_t* labels[]={L"PERSON",L"MUTANT",L"ANOMALY",L"ARTIFACT"};
    for(int type=1;type<=4;++type){
        for(const auto& marker:scanMarkers)if(marker.type==type){
            const auto color=scanColor(marker);
            auto pen=CreatePen(PS_SOLID,std::clamp(height/550,2,3),color);const auto oldPen=SelectObject(dc,pen);
            SetTextColor(dc,color);
            const int x=static_cast<int>(marker.x*width),y=static_cast<int>(marker.y*height);
            const int fallback=std::clamp(static_cast<int>(height*(type<=2?.033:.023)),12,60);
            const int halfX=marker.width>0?std::max(2,static_cast<int>(std::lround(marker.width*width/2))):fallback;
            const int halfY=marker.height>0?std::max(2,static_cast<int>(std::lround(marker.height*height/2))):fallback;
            const int corner=std::min(std::min(halfX,halfY),std::clamp(std::min(halfX,halfY)/5,3,14));
            const int rounding=std::min(4,corner/2);
            for(int sx:{-1,1})for(int sy:{-1,1}){
                const int px=x+sx*halfX,py=y+sy*halfY;
                const POINT points[]={{px-sx*corner,py},{px-sx*rounding,py},{px,py-sy*rounding},{px,py-sy*corner}};
                Polyline(dc,points,4);
            }
            wchar_t text[64]{};
            if(type<=2)swprintf_s(text,L"%.0f m",marker.distance);
            else swprintf_s(text,L"%s  %.0f m",labels[type-1],marker.distance);
            const int iconSize=std::clamp(height/45,16,32);
            const int iconGap=type<=2&&marker.faction>0?iconSize+4:0;
            if(iconGap)drawFactionIcon(dc,marker.faction,x-iconSize/2,std::min(height-iconSize,y+halfY+4),iconSize,color);
            RECT label{std::max(0,x-100),std::min(height-labelHeight-2,y+halfY+3+iconGap),std::min(width,x+100),std::min(height,y+halfY+labelHeight+5+iconGap)};
            DrawTextW(dc,text,-1,&label,DT_CENTER|DT_SINGLELINE|DT_NOPREFIX);
            SelectObject(dc,oldPen);DeleteObject(pen);
        }
    }
    SelectObject(dc,oldFont);
}
inline LRESULT CALLBACK previewProc(HWND h,UINT m,WPARAM wp,LPARAM lp){
    if(m==WM_ERASEBKGND)return 1;
    if(m==WM_PAINT){PAINTSTRUCT ps{};auto dc=BeginPaint(h,&ps);RECT rc{};GetClientRect(h,&rc);auto mem=previewSurface.get(dc,rc.right,rc.bottom);auto bg=CreateSolidBrush(RGB(25,31,39));FillRect(mem,&rc,bg);DeleteObject(bg);
        for(int x=0;x<rc.right;x+=40)line(mem,x,0,x,rc.bottom,RGB(38,45,53),1);
        for(int y=0;y<rc.bottom;y+=40)line(mem,0,y,rc.right,y,RGB(38,45,53),1);
        draw(mem,rc,true);BitBlt(dc,0,0,rc.right,rc.bottom,mem,0,0,SRCCOPY);EndPaint(h,&ps);return 0;}
    if(m==WM_LBUTTONDOWN){POINT pt{GET_X_LPARAM(lp),GET_Y_LPARAM(lp)};for(int i=itemCount-1;i>=0;--i)if((i==4&&previewCameraDown?downCrossVisible:items[i].visible)&&PtInRect(&bounds[i],pt)){selected=drag=i;SendMessageW(list,LB_SETCURSEL,i,0);SetCapture(h);refreshControls();break;}return 0;}
    if(m==WM_MOUSEMOVE&&drag>=0){RECT rc{};GetClientRect(h,&rc);items[drag].x=std::clamp(static_cast<double>(GET_X_LPARAM(lp))/rc.right,.02,.98);items[drag].y=std::clamp(static_cast<double>(GET_Y_LPARAM(lp))/rc.bottom,.02,.98);InvalidateRect(h,nullptr,FALSE);return 0;}
    if(m==WM_LBUTTONUP){drag=-1;ReleaseCapture();save();return 0;}
    if(m==WM_CAPTURECHANGED){drag=-1;return 0;}
    return DefWindowProcW(h,m,wp,lp);
}
inline LRESULT CALLBACK overlayProc(HWND h,UINT m,WPARAM wp,LPARAM lp){
    if(m==WM_MOUSEACTIVATE)return MA_NOACTIVATE;
    if(m==WM_SETCURSOR){SetCursor(LoadCursorW(nullptr,MAKEINTRESOURCEW(32512)));return TRUE;}
    if(m==WM_ERASEBKGND)return 1;
    if(m==WM_PAINT){PAINTSTRUCT ps{};auto dc=BeginPaint(h,&ps);RECT rc{};GetClientRect(h,&rc);auto mem=overlaySurface.get(dc,rc.right,rc.bottom);FillRect(mem,&rc,static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));if(!cursorMode&&!editing){drawSignalNoise(mem,rc);if(!data.signalLost)drawExperiments(mem,rc);}if(enabled&&data.active&&!editing)draw(mem,rc,false);if(cursorMode){POINT pt{};GetCursorPos(&pt);ScreenToClient(h,&pt);DrawIconEx(mem,pt.x,pt.y,LoadCursorW(nullptr,MAKEINTRESOURCEW(32512)),0,0,0,nullptr,DI_NORMAL);}BitBlt(dc,0,0,rc.right,rc.bottom,mem,0,0,SRCCOPY);EndPaint(h,&ps);return 0;}
    return DefWindowProcW(h,m,wp,lp);
}
inline LRESULT CALLBACK editorProc(HWND h,UINT m,WPARAM wp,LPARAM lp){
    if(m==WM_GETMINMAXINFO){
        auto limits=reinterpret_cast<MINMAXINFO*>(lp);
        int width=800,height=520;MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);
        if(GetMonitorInfoW(MonitorFromWindow(h,MONITOR_DEFAULTTONEAREST),&monitor)){
            width=std::min(width,static_cast<int>(monitor.rcWork.right-monitor.rcWork.left));
            height=std::min(height,static_cast<int>(monitor.rcWork.bottom-monitor.rcWork.top));
        }
        limits->ptMinTrackSize={width,height};return 0;
    }
    if(m==WM_SIZE){if(wp!=SIZE_MINIMIZED)resizeEditor(h);return 0;}
    if(m==WM_EXITSIZEMOVE){saveEditorWindowSize(h);return 0;}
    if(m==WM_DESTROY)saveEditorWindowSize(h);
    if(m==WM_NCDESTROY){
        editorControls.clear();editorWidth=editorHeight=editorFontHeight=0;
        if(editorFont){DeleteObject(editorFont);editorFont=nullptr;}
        previewSurface.clear();preview=nullptr;drag=-1;editing=false;
    }
    LRESULT themed=0;if(uiTheme::paint(h,m,wp,lp,themed))return themed;
    if(m==WM_CLOSE){save();saveEditorWindowSize(h);editing=false;ShowWindow(h,SW_HIDE);return 0;}
    if(m==WM_COMMAND){const int id=LOWORD(wp),event=HIWORD(wp);
        if(id==201&&event==LBN_SELCHANGE){selected=static_cast<int>(SendMessageW(list,LB_GETCURSEL,0,0));refreshControls();}
        if(id==202&&event==BN_CLICKED){items[selected].visible=SendMessageW(enabledBox,BM_GETCHECK,0,0)==BST_CHECKED;save();refreshControls();}
        if(id==203&&event==EN_KILLFOCUS){wchar_t text[16];GetWindowTextW(sizeBox,text,16);items[selected].size=std::clamp(_wtoi(text),14,72);save();refreshControls();}
        if(id==204&&event==CBN_SELCHANGE){items[selected].color=static_cast<int>(SendMessageW(colorBox,CB_GETCURSEL,0,0));save();refreshControls();}
        if(id==205&&event==BN_CLICKED){enabled=SendMessageW(masterBox,BM_GETCHECK,0,0)==BST_CHECKED;save();}
        if(id==206&&event==BN_CLICKED){items=defaults;crossStyle=0;downCrossStyle=4;downCrossVisible=true;SendMessageW(styleBox,CB_SETCURSEL,0,0);SendMessageW(downStyleBox,CB_SETCURSEL,4,0);save();refreshControls();}
        if(id==207&&event==CBN_SELCHANGE){crossStyle=static_cast<int>(SendMessageW(styleBox,CB_GETCURSEL,0,0));previewCameraDown=false;SendMessageW(previewDownBox,BM_SETCHECK,BST_UNCHECKED,0);save();refreshControls();}
        if(id==210&&event==CBN_SELCHANGE){downCrossStyle=static_cast<int>(SendMessageW(downStyleBox,CB_GETCURSEL,0,0));previewCameraDown=true;SendMessageW(previewDownBox,BM_SETCHECK,BST_CHECKED,0);save();refreshControls();}
        if(id==211&&event==BN_CLICKED){previewCameraDown=SendMessageW(previewDownBox,BM_GETCHECK,0,0)==BST_CHECKED;refreshControls();}
        if(id==212&&event==BN_CLICKED){downCrossVisible=SendMessageW(downVisibleBox,BM_GETCHECK,0,0)==BST_CHECKED;save();refreshControls();}
        if(id==209&&event==CBN_SELCHANGE){fontChoice=static_cast<int>(SendMessageW(fontBox,CB_GETCURSEL,0,0));save();refreshControls();}
        if(id==208&&event==BN_CLICKED)SendMessageW(h,WM_CLOSE,0,0);
        return 0;
    }
    return DefWindowProcW(h,m,wp,lp);
}
inline HWND child(const wchar_t* cls,const wchar_t* text,DWORD style,int x,int y,int w,int h,int id=0){auto c=CreateWindowW(cls,language::tr(text),WS_CHILD|WS_VISIBLE|WS_TABSTOP|style,x,y,w,h,editor.load(),reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),GetModuleHandleW(nullptr),nullptr);SendMessageW(c,WM_SETFONT,reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)),TRUE);editorControls.push_back({c,x,y,w,h});return c;}
inline void createEditor(HWND owner){
    if(!editor.load()){WNDCLASSW c{};c.hInstance=GetModuleHandleW(nullptr);c.hCursor=LoadCursorW(nullptr,MAKEINTRESOURCEW(32512));c.hbrBackground=reinterpret_cast<HBRUSH>(COLOR_WINDOW+1);c.lpfnWndProc=editorProc;c.lpszClassName=L"ZoneFPVOSDEditor";RegisterClassW(&c);editor=CreateWindowExW(WS_EX_TOPMOST,c.lpszClassName,L"ZoneFPV OSD",editorStyle,CW_USEDEFAULT,CW_USEDEFAULT,1120,690,owner,nullptr,c.hInstance,nullptr);
        if(!editor.load())return;
        RECT client{};GetClientRect(editor.load(),&client);editorWidth=client.right;editorHeight=client.bottom;
        GetObjectW(GetStockObject(DEFAULT_GUI_FONT),sizeof(editorBaseFont),&editorBaseFont);editorControls.clear();
        masterBox=child(L"BUTTON",L"OSD on",BS_AUTOCHECKBOX,20,15,200,28,205);SendMessageW(masterBox,BM_SETCHECK,enabled?BST_CHECKED:BST_UNCHECKED,0);
        list=child(L"LISTBOX",L"",LBS_NOTIFY|WS_BORDER|WS_VSCROLL,20,55,235,230,201);for(auto n:names)SendMessageW(list,LB_ADDSTRING,0,reinterpret_cast<LPARAM>(n));SendMessageW(list,LB_SETCURSEL,selected,0);
        enabledBox=child(L"BUTTON",visibilityLabel(),BS_AUTOCHECKBOX,20,295,210,25,202);
        child(L"STATIC",L"Size (14-72)",0,20,327,130,24);sizeBox=child(L"EDIT",L"24",ES_NUMBER|WS_BORDER,160,322,80,26,203);
        colorBox=child(L"COMBOBOX",L"",CBS_DROPDOWNLIST,20,360,220,160,204);for(auto name:{L"White",L"Green",L"Yellow",L"Cyan",L"Red"})SendMessageW(colorBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));
        child(L"STATIC",L"Обычный прицел",0,20,395,235,20);
        styleBox=child(L"COMBOBOX",L"",CBS_DROPDOWNLIST,20,415,220,180,207);
        child(L"STATIC",L"Прицел нижней камеры",0,20,450,235,20);
        downStyleBox=child(L"COMBOBOX",L"",CBS_DROPDOWNLIST,20,470,220,180,210);
        for(auto box:{styleBox,downStyleBox})for(auto name:{L"Cross +",L"Dot",L"Split cross",L"Кольцо",L"Кольцо с точкой",L"Уголки"})SendMessageW(box,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));
        SendMessageW(styleBox,CB_SETCURSEL,crossStyle,0);SendMessageW(downStyleBox,CB_SETCURSEL,downCrossStyle,0);
        fontBox=child(L"COMBOBOX",L"",CBS_DROPDOWNLIST,20,515,220,230,209);for(auto name:fontNames)SendMessageW(fontBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));SendMessageW(fontBox,CB_SETCURSEL,fontChoice,0);
        child(L"BUTTON",L"Reset layout",0,20,555,220,30,206);child(L"BUTTON",L"Save / close",0,20,600,220,30,208);
        previewDownBox=child(L"BUTTON",L"Нижняя камера: предпросмотр",BS_AUTOCHECKBOX,280,15,800,25,211);SendMessageW(previewDownBox,BM_SETCHECK,previewCameraDown?BST_CHECKED:BST_UNCHECKED,0);
        downVisibleBox=child(L"BUTTON",L"Нижний прицел: показывать",BS_AUTOCHECKBOX,280,45,800,25,212);
        child(L"STATIC",L"Drag elements. Changes are saved automatically. Preview uses sample values when not flying.",0,280,75,800,40);
        c.lpszClassName=L"ZoneFPVOSDPreview";c.lpfnWndProc=previewProc;RegisterClassW(&c);preview=child(c.lpszClassName,L"",WS_BORDER,280,120,800,static_cast<int>(std::min(470.,800./screenAspect)));refreshControls();
        const auto dimensions=editorWindowSize(editor.load());
        SetWindowPos(editor.load(),nullptr,0,0,dimensions.cx,dimensions.cy,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
        resizeEditor(editor.load());
    }
}
inline void showEditor(HWND owner){
    const bool first=!editor.load();createEditor(owner);
    const auto editorWindow=editor.load();if(!editorWindow)return;
    uiTheme::apply(editorWindow);refreshControls();editing=true;ShowWindow(editorWindow,first&&editorStartMaximized?SW_SHOWMAXIMIZED:SW_SHOW);SetForegroundWindow(editorWindow);
}
inline bool focused(){const auto editorWindow=editor.load();auto fg=GetForegroundWindow();return editorWindow&&IsWindowVisible(editorWindow)&&(fg==editorWindow||IsChild(editorWindow,fg));}
inline void pump(HWND game,HWND menuWindow){
    const bool menuOpen=menuWindow!=nullptr;
    const auto now=GetTickCount64();if(now<nextPoll)return;nextPoll=now+50;
    if(editing&&!IsWindowVisible(editor.load()))editing=false;
    if(!game&&!editing){if(overlay)ShowWindow(overlay,SW_HIDE);return;}
    if(now>=nextTelemetryPoll){
        nextTelemetryPoll=now+50;std::ifstream f(root/L"telemetry.txt");ULONGLONG seq=0;Data d;
        if(parseTelemetry(f,d,seq)){if(seq!=lastSeq){lastSeq=seq;lastChange=now;}data=d;}
    }
    if(now-lastChange>500)data.active=false;
    {std::ifstream first(root/L"scan-frame-a.txt"),second(root/L"scan-frame-b.txt");
        if(scanLease.everV4){std::istringstream unused;updateScanFrames(first,second,unused,data.active,now,scanMarkers,scanLease);}
        else {std::ifstream legacy(root/L"scan-frame.txt");updateScanFrames(first,second,legacy,data.active,now,scanMarkers,scanLease);}}
    nextPoll=now+scanPollInterval(scanMarkers);
    if(editing)InvalidateRect(preview,nullptr,FALSE);
    if(!game||IsIconic(game)){if(overlay)ShowWindow(overlay,SW_HIDE);return;}
    RECT rc{};GetClientRect(game,&rc);if(rc.right<1||rc.bottom<1)return;
    if(publishedViewportWidth!=rc.right||publishedViewportHeight!=rc.bottom){
        const auto temporary=root/L"scan-aspect.tmp",destination=root/L"scan-aspect.txt";
        std::ofstream aspectFile(temporary);aspectFile<<rc.right<<' '<<rc.bottom<<'\n';aspectFile.close();
        if(aspectFile&&MoveFileExW(temporary.c_str(),destination.c_str(),MOVEFILE_REPLACE_EXISTING)){
            publishedViewportWidth=rc.right;publishedViewportHeight=rc.bottom;
        }
    }
    const auto aspect=static_cast<double>(rc.right)/rc.bottom;
    if(aspect!=screenAspect){screenAspect=aspect;if(const auto editorWindow=editor.load())resizeEditor(editorWindow);}
    if(!(data.active&&(enabled||data.signalEnabled||data.hpEnabled||data.detectorEnabled||!scanMarkers.empty()))&&!menuOpen){if(overlay)ShowWindow(overlay,SW_HIDE);return;}
    if(!overlay){WNDCLASSW c{};c.hInstance=GetModuleHandleW(nullptr);c.lpfnWndProc=overlayProc;c.lpszClassName=L"ZoneFPVOSD";c.hCursor=LoadCursorW(nullptr,MAKEINTRESOURCEW(32512));RegisterClassW(&c);overlay=CreateWindowExW(WS_EX_TOPMOST|WS_EX_LAYERED|WS_EX_TRANSPARENT|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW,c.lpszClassName,L"",WS_POPUP,0,0,1,1,nullptr,nullptr,c.hInstance,nullptr);SetLayeredWindowAttributes(overlay,RGB(0,0,0),255,LWA_COLORKEY);}
    if(cursorMode!=menuOpen){cursorMode=menuOpen;SetWindowLongPtrW(overlay,GWL_EXSTYLE,WS_EX_TOPMOST|WS_EX_LAYERED|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW|(menuOpen?0:WS_EX_TRANSPARENT));}
    POINT pos{};ClientToScreen(game,&pos);
    const RECT placement{pos.x,pos.y,pos.x+rc.right,pos.y+rc.bottom};
    const auto order=menuOpen?menuWindow:HWND_TOPMOST;
    if(!IsWindowVisible(overlay)||overlayOrder!=order||!EqualRect(&overlayPlacement,&placement)){
        if(SetWindowPos(overlay,order,pos.x,pos.y,rc.right,rc.bottom,SWP_NOACTIVATE|SWP_SHOWWINDOW)){
            overlayPlacement=placement;overlayOrder=order;
        }
    }
    InvalidateRect(overlay,nullptr,FALSE);
}
inline void cleanup(){overlaySurface.clear();previewSurface.clear();noiseTexture.clear();fineNoiseTexture.clear();for(auto& family:fonts)for(auto f:family)if(f)DeleteObject(f);for(int i=0;i<5;++i)if(glyphDC[i]){SelectObject(glyphDC[i],glyphOld[i]);DeleteObject(glyphBitmap[i]);DeleteDC(glyphDC[i]);glyphDC[i]=nullptr;}
    for(auto& icon:factionIcons){if(icon.dc){SelectObject(icon.dc,icon.previous);DeleteDC(icon.dc);}if(icon.bitmap)DeleteObject(icon.bitmap);icon={};}
    if(overlay)DestroyWindow(overlay);if(const auto editorWindow=editor.exchange(nullptr))DestroyWindow(editorWindow);}
}

#undef SendMessageW
