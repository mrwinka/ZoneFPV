#pragma once
#include <windowsx.h>
#include <cmath>
#include "ui_theme.h"
#define SendMessageW language::message
namespace osd {
inline fs::path root;
inline HWND overlay=nullptr,editor=nullptr,preview=nullptr,list=nullptr,sizeBox=nullptr,colorBox=nullptr,enabledBox=nullptr,masterBox=nullptr,styleBox=nullptr;
inline bool editing=false,enabled=true,cursorMode=false;
inline int selected=0,drag=-1,crossStyle=0;
inline ULONGLONG nextPoll=0,lastChange=0,lastSeq=0;
struct Data {bool active=false;double speed=0,altitude=0,distance=0,pitch=0,roll=0,heading=0,home=0,seconds=0,climb=0,throttle=0;};
inline Data data;
struct Item{double x,y;int size,color;bool visible;};
inline const std::array<Item,10> defaults={{{.14,.80,24,0,true},{.82,.80,24,0,true},{.82,.86,24,0,true},{.50,.50,24,0,true},{.50,.50,24,0,true},{.14,.86,24,0,true},{.50,.12,24,0,true},{.50,.21,24,0,true},{.14,.73,24,0,false},{.82,.73,24,0,false}}};
inline auto items=defaults;
inline const wchar_t* names[]={L"Speed / km/h",L"Altitude / m (home)",L"Home distance / m",L"Artificial horizon",L"Crosshair",L"Flight timer",L"Heading / degrees",L"Home direction",L"Throttle / %",L"Vertical speed / m/s"};
inline COLORREF colors[]={RGB(255,255,255),RGB(80,255,110),RGB(255,220,60),RGB(60,225,255),RGB(255,110,110)};
inline RECT bounds[10]{};
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
inline HFONT font(int size){size=std::clamp(size,10,96);auto& f=fonts[fontChoice][size-10];if(!f)f=CreateFontW(-size,0,0,0,FW_BOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,NONANTIALIASED_QUALITY,FIXED_PITCH,fontNames[fontChoice]);return f;}

struct Surface{HDC dc=nullptr;HBITMAP bitmap=nullptr;HGDIOBJ old=nullptr;int w=0,h=0;
    void clear(){if(dc){SelectObject(dc,old);DeleteObject(bitmap);DeleteDC(dc);}dc=nullptr;}
    HDC get(HDC target,int width,int height){if(!dc||w!=width||h!=height){clear();w=width;h=height;dc=CreateCompatibleDC(target);bitmap=CreateCompatibleBitmap(target,w,h);old=SelectObject(dc,bitmap);}return dc;}
};
inline Surface overlaySurface,previewSurface;
inline bool save(){
    auto path=root/L"osd-layout.tmp";std::ofstream f(path);f<<"2 "<<enabled<<' '<<crossStyle<<' '<<fontChoice<<'\n';
    for(const auto& e:items)f<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';
    f.close();return f&&MoveFileExW(path.c_str(),(root/L"osd-layout.txt").c_str(),MOVEFILE_REPLACE_EXISTING);
}
inline void load(){
    std::ifstream f(root/L"osd-layout.txt");int v=0,on=1,style=0;auto candidate=defaults;
    if(!(f>>v>>on>>style)||(v!=1&&v!=2)||on<0||on>1||style<0||style>2)return;
    int face=0;if(v==2&&(!(f>>face)||face<0||face>=8))return;
    for(auto& e:candidate){int visible=0;if(!(f>>e.x>>e.y>>e.size>>e.color>>visible)||!std::isfinite(e.x)||!std::isfinite(e.y)||e.x<0||e.x>1||e.y<0||e.y>1||e.size<14||e.size>72||e.color<0||e.color>4||visible<0||visible>1)return;e.visible=visible!=0;}
    items=candidate;enabled=on!=0;crossStyle=style;fontChoice=face;
}
inline void line(HDC dc,int x1,int y1,int x2,int y2,COLORREF color,int width=2){
    auto pen=CreatePen(PS_SOLID,width+2,RGB(1,1,1));auto old=SelectObject(dc,pen);MoveToEx(dc,x1,y1,nullptr);LineTo(dc,x2,y2);SelectObject(dc,old);DeleteObject(pen);
    pen=CreatePen(PS_SOLID,width,color);old=SelectObject(dc,pen);MoveToEx(dc,x1,y1,nullptr);LineTo(dc,x2,y2);SelectObject(dc,old);DeleteObject(pen);
}
inline void draw(HDC dc,RECT area,bool sample){
    const double w=area.right-area.left,h=area.bottom-area.top;
    Data d=data;if(sample&&!d.active){d={true,64,25,120,10,12,85,35,125,2.1,42};}
    SetBkMode(dc,TRANSPARENT);
    for(int i=0;i<10;++i){const auto& e=items[i];if(!e.visible){bounds[i]={};continue;}
        const int px=static_cast<int>(e.x*w),py=static_cast<int>(e.y*h);
        const int sz=std::clamp(static_cast<int>(e.size*h/900.0),10,90);
        const auto color=colors[e.color];wchar_t text[100]{};
        if(i==3){
            const double a=-d.roll*3.141592653589793/180;
            const int offset=static_cast<int>(std::clamp(d.pitch,-70.,70.)*sz/15);
            const int cx=px+static_cast<int>(std::sin(a)*offset),cy=py+static_cast<int>(std::cos(a)*offset);
            for(int side:{-1,1})line(dc,cx+static_cast<int>(std::cos(a)*sz*side),cy+static_cast<int>(std::sin(a)*sz*side),cx+static_cast<int>(std::cos(a)*sz*4*side),cy+static_cast<int>(std::sin(a)*sz*4*side),color);
            bounds[i]={px-5*sz,py-4*sz,px+5*sz,py+4*sz};
        }else if(i==4){
            if(crossStyle==1){line(dc,px-1,py,px+2,py,color,3);}
            else{const int gap=crossStyle==2?sz/3:0;for(int sign:{-1,1}){line(dc,px+sign*gap,py,px+sign*sz/2,py,color);line(dc,px,py+sign*gap,px,py+sign*sz/2,color);}}
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
            auto old=SelectObject(dc,font(sz));SIZE extent{};GetTextExtentPoint32W(dc,text,static_cast<int>(wcslen(text)),&extent);
            const bool bitmap=fontChoice==1&&loadBetaflight();if(bitmap)extent=bitmapText(dc,text,0,0,sz,e.color,false);
            const int x=std::clamp(px-static_cast<int>(extent.cx)/2,0,std::max(0,static_cast<int>(w)-static_cast<int>(extent.cx))),y=std::clamp(py-static_cast<int>(extent.cy)/2,0,std::max(0,static_cast<int>(h)-static_cast<int>(extent.cy)));
            if(bitmap){bitmapText(dc,text,x,y,sz,e.color,true);}else{
            SetTextColor(dc,RGB(1,1,1));for(int ox:{-1,1})for(int oy:{-1,1})TextOutW(dc,x+ox,y+oy,text,static_cast<int>(wcslen(text)));
            SetTextColor(dc,color);TextOutW(dc,x,y,text,static_cast<int>(wcslen(text)));}SelectObject(dc,old);bounds[i]={x,y,x+extent.cx,y+extent.cy};
        }
        if(sample&&selected==i){auto brush=CreateSolidBrush(RGB(80,150,255));FrameRect(dc,&bounds[i],brush);DeleteObject(brush);}
    }
}
inline void refreshControls(){const auto& e=items[selected];SendMessageW(enabledBox,BM_SETCHECK,e.visible?BST_CHECKED:BST_UNCHECKED,0);SetWindowTextW(sizeBox,std::to_wstring(e.size).c_str());SendMessageW(colorBox,CB_SETCURSEL,e.color,0);InvalidateRect(preview,nullptr,FALSE);}
inline LRESULT CALLBACK previewProc(HWND h,UINT m,WPARAM wp,LPARAM lp){
    if(m==WM_ERASEBKGND)return 1;
    if(m==WM_PAINT){PAINTSTRUCT ps{};auto dc=BeginPaint(h,&ps);RECT rc{};GetClientRect(h,&rc);auto mem=previewSurface.get(dc,rc.right,rc.bottom);auto bg=CreateSolidBrush(RGB(25,31,39));FillRect(mem,&rc,bg);DeleteObject(bg);
        for(int x=0;x<rc.right;x+=40)line(mem,x,0,x,rc.bottom,RGB(38,45,53),1);
        for(int y=0;y<rc.bottom;y+=40)line(mem,0,y,rc.right,y,RGB(38,45,53),1);
        draw(mem,rc,true);BitBlt(dc,0,0,rc.right,rc.bottom,mem,0,0,SRCCOPY);EndPaint(h,&ps);return 0;}
    if(m==WM_LBUTTONDOWN){POINT pt{GET_X_LPARAM(lp),GET_Y_LPARAM(lp)};for(int i=9;i>=0;--i)if(items[i].visible&&PtInRect(&bounds[i],pt)){selected=drag=i;SendMessageW(list,LB_SETCURSEL,i,0);SetCapture(h);refreshControls();break;}return 0;}
    if(m==WM_MOUSEMOVE&&drag>=0){RECT rc{};GetClientRect(h,&rc);items[drag].x=std::clamp(static_cast<double>(GET_X_LPARAM(lp))/rc.right,.02,.98);items[drag].y=std::clamp(static_cast<double>(GET_Y_LPARAM(lp))/rc.bottom,.02,.98);InvalidateRect(h,nullptr,FALSE);return 0;}
    if(m==WM_LBUTTONUP){drag=-1;ReleaseCapture();save();return 0;}
    if(m==WM_CAPTURECHANGED){drag=-1;return 0;}
    return DefWindowProcW(h,m,wp,lp);
}
inline LRESULT CALLBACK overlayProc(HWND h,UINT m,WPARAM wp,LPARAM lp){
    if(m==WM_MOUSEACTIVATE)return MA_NOACTIVATE;
    if(m==WM_SETCURSOR){SetCursor(LoadCursorW(nullptr,MAKEINTRESOURCEW(32512)));return TRUE;}
    if(m==WM_ERASEBKGND)return 1;
    if(m==WM_PAINT){PAINTSTRUCT ps{};auto dc=BeginPaint(h,&ps);RECT rc{};GetClientRect(h,&rc);auto mem=overlaySurface.get(dc,rc.right,rc.bottom);FillRect(mem,&rc,static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));if(enabled&&data.active&&!editing)draw(mem,rc,false);if(cursorMode){POINT pt{};GetCursorPos(&pt);ScreenToClient(h,&pt);DrawIconEx(mem,pt.x,pt.y,LoadCursorW(nullptr,MAKEINTRESOURCEW(32512)),0,0,0,nullptr,DI_NORMAL);}BitBlt(dc,0,0,rc.right,rc.bottom,mem,0,0,SRCCOPY);EndPaint(h,&ps);return 0;}
    return DefWindowProcW(h,m,wp,lp);
}
inline LRESULT CALLBACK editorProc(HWND h,UINT m,WPARAM wp,LPARAM lp){
    LRESULT themed=0;if(uiTheme::paint(h,m,wp,lp,themed))return themed;
    if(m==WM_CLOSE){save();editing=false;ShowWindow(h,SW_HIDE);return 0;}
    if(m==WM_COMMAND){const int id=LOWORD(wp),event=HIWORD(wp);
        if(id==201&&event==LBN_SELCHANGE){selected=static_cast<int>(SendMessageW(list,LB_GETCURSEL,0,0));refreshControls();}
        if(id==202&&event==BN_CLICKED){items[selected].visible=SendMessageW(enabledBox,BM_GETCHECK,0,0)==BST_CHECKED;save();refreshControls();}
        if(id==203&&event==EN_KILLFOCUS){wchar_t text[16];GetWindowTextW(sizeBox,text,16);items[selected].size=std::clamp(_wtoi(text),14,72);save();refreshControls();}
        if(id==204&&event==CBN_SELCHANGE){items[selected].color=static_cast<int>(SendMessageW(colorBox,CB_GETCURSEL,0,0));save();refreshControls();}
        if(id==205&&event==BN_CLICKED){enabled=SendMessageW(masterBox,BM_GETCHECK,0,0)==BST_CHECKED;save();}
        if(id==206&&event==BN_CLICKED){items=defaults;crossStyle=0;SendMessageW(styleBox,CB_SETCURSEL,0,0);save();refreshControls();}
        if(id==207&&event==CBN_SELCHANGE){crossStyle=static_cast<int>(SendMessageW(styleBox,CB_GETCURSEL,0,0));save();refreshControls();}
        if(id==209&&event==CBN_SELCHANGE){fontChoice=static_cast<int>(SendMessageW(fontBox,CB_GETCURSEL,0,0));save();refreshControls();}
        if(id==208&&event==BN_CLICKED)SendMessageW(h,WM_CLOSE,0,0);
        return 0;
    }
    return DefWindowProcW(h,m,wp,lp);
}
inline HWND child(const wchar_t* cls,const wchar_t* text,DWORD style,int x,int y,int w,int h,int id=0){auto c=CreateWindowW(cls,language::tr(text),WS_CHILD|WS_VISIBLE|WS_TABSTOP|style,x,y,w,h,editor,reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),GetModuleHandleW(nullptr),nullptr);SendMessageW(c,WM_SETFONT,reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)),TRUE);return c;}
inline void showEditor(HWND owner){
    if(!editor){WNDCLASSW c{};c.hInstance=GetModuleHandleW(nullptr);c.hCursor=LoadCursorW(nullptr,MAKEINTRESOURCEW(32512));c.hbrBackground=reinterpret_cast<HBRUSH>(COLOR_WINDOW+1);c.lpfnWndProc=editorProc;c.lpszClassName=L"ZoneFPVOSDEditor";RegisterClassW(&c);editor=CreateWindowExW(WS_EX_TOPMOST,c.lpszClassName,L"ZoneFPV OSD",WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU,CW_USEDEFAULT,CW_USEDEFAULT,1120,690,owner,nullptr,c.hInstance,nullptr);
        masterBox=child(L"BUTTON",L"OSD on",BS_AUTOCHECKBOX,20,15,200,28,205);SendMessageW(masterBox,BM_SETCHECK,enabled?BST_CHECKED:BST_UNCHECKED,0);
        list=child(L"LISTBOX",L"",LBS_NOTIFY|WS_BORDER,20,55,235,265,201);for(auto n:names)SendMessageW(list,LB_ADDSTRING,0,reinterpret_cast<LPARAM>(n));SendMessageW(list,LB_SETCURSEL,0,0);
        enabledBox=child(L"BUTTON",L"Visible",BS_AUTOCHECKBOX,20,330,210,25,202);
        child(L"STATIC",L"Size (14-72)",0,20,365,130,24);sizeBox=child(L"EDIT",L"24",ES_NUMBER|WS_BORDER,160,360,80,26,203);
        colorBox=child(L"COMBOBOX",L"",CBS_DROPDOWNLIST,20,405,220,160,204);for(auto name:{L"White",L"Green",L"Yellow",L"Cyan",L"Red"})SendMessageW(colorBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));
        styleBox=child(L"COMBOBOX",L"",CBS_DROPDOWNLIST,20,450,220,140,207);for(auto name:{L"Cross +",L"Dot",L"Split cross"})SendMessageW(styleBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));SendMessageW(styleBox,CB_SETCURSEL,crossStyle,0);
        fontBox=child(L"COMBOBOX",L"",CBS_DROPDOWNLIST,20,490,220,230,209);for(auto name:fontNames)SendMessageW(fontBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(name));SendMessageW(fontBox,CB_SETCURSEL,fontChoice,0);
        child(L"BUTTON",L"Reset layout",0,20,535,220,30,206);child(L"BUTTON",L"Save / close",0,20,580,220,30,208);
        child(L"STATIC",L"Drag elements. Changes are saved automatically. Preview uses sample values when not flying.",0,280,15,800,40);
        c.lpszClassName=L"ZoneFPVOSDPreview";c.lpfnWndProc=previewProc;RegisterClassW(&c);preview=child(c.lpszClassName,L"",WS_BORDER,280,65,800,static_cast<int>(std::min(530.,800./screenAspect)));refreshControls();
    }
    uiTheme::apply(editor);editing=true;ShowWindow(editor,SW_SHOW);SetForegroundWindow(editor);
}
inline bool focused(){auto fg=GetForegroundWindow();return editor&&IsWindowVisible(editor)&&(fg==editor||IsChild(editor,fg));}
inline void pump(HWND game,HWND menuWindow){
    const bool menuOpen=menuWindow!=nullptr;
    const auto now=GetTickCount64();if(now<nextPoll)return;nextPoll=now+50;
    if(editing&&!IsWindowVisible(editor))editing=false;
    if(!game&&!editing){if(overlay)ShowWindow(overlay,SW_HIDE);return;}
    std::ifstream f(root/L"telemetry.txt");int ver=0,on=0;ULONGLONG seq=0,end=0;Data d;
    if(f>>ver>>seq>>on>>d.speed>>d.altitude>>d.distance>>d.pitch>>d.roll>>d.heading>>d.home>>d.seconds>>d.climb>>d.throttle>>end&&ver==1&&seq==end){
        bool finite=true;for(double v:{d.speed,d.altitude,d.distance,d.pitch,d.roll,d.heading,d.home,d.seconds,d.climb,d.throttle})if(!std::isfinite(v)||std::abs(v)>1e8)finite=false;
        if(finite){if(seq!=lastSeq){lastSeq=seq;lastChange=now;}d.active=on==1;data=d;}
    }
    if(now-lastChange>500)data.active=false;
    if(editing)InvalidateRect(preview,nullptr,FALSE);
    if(!game||IsIconic(game)||(!(data.active&&enabled)&&!menuOpen)){if(overlay)ShowWindow(overlay,SW_HIDE);return;}
    if(!overlay){WNDCLASSW c{};c.hInstance=GetModuleHandleW(nullptr);c.lpfnWndProc=overlayProc;c.lpszClassName=L"ZoneFPVOSD";c.hCursor=LoadCursorW(nullptr,MAKEINTRESOURCEW(32512));RegisterClassW(&c);overlay=CreateWindowExW(WS_EX_TOPMOST|WS_EX_LAYERED|WS_EX_TRANSPARENT|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW,c.lpszClassName,L"",WS_POPUP,0,0,1,1,nullptr,nullptr,c.hInstance,nullptr);SetLayeredWindowAttributes(overlay,RGB(0,0,0),255,LWA_COLORKEY);}
    if(cursorMode!=menuOpen){cursorMode=menuOpen;SetWindowLongPtrW(overlay,GWL_EXSTYLE,WS_EX_TOPMOST|WS_EX_LAYERED|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW|(menuOpen?0:WS_EX_TRANSPARENT));}
    RECT rc{};GetClientRect(game,&rc);if(rc.right<1||rc.bottom<1)return;screenAspect=static_cast<double>(rc.right)/rc.bottom;if(editing)SetWindowPos(preview,nullptr,0,0,800,static_cast<int>(std::min(530.,800./screenAspect)),SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);POINT pos{};ClientToScreen(game,&pos);
    SetWindowPos(overlay,menuOpen?menuWindow:HWND_TOPMOST,pos.x,pos.y,rc.right,rc.bottom,SWP_NOACTIVATE|SWP_SHOWWINDOW);
    InvalidateRect(overlay,nullptr,FALSE);
}
inline void cleanup(){overlaySurface.clear();previewSurface.clear();for(auto& family:fonts)for(auto f:family)if(f)DeleteObject(f);for(int i=0;i<5;++i)if(glyphDC[i]){SelectObject(glyphDC[i],glyphOld[i]);DeleteObject(glyphBitmap[i]);DeleteDC(glyphDC[i]);glyphDC[i]=nullptr;}if(overlay)DestroyWindow(overlay);if(editor)DestroyWindow(editor);}
}

#undef SendMessageW
