#pragma once
#include <uxtheme.h>
#pragma comment(lib,"uxtheme.lib")
namespace uiTheme {
inline bool dark=true;
inline HBRUSH darkBrush=CreateSolidBrush(RGB(28,31,37)),lightBrush=CreateSolidBrush(RGB(246,247,250));
inline COLORREF background(){return dark?RGB(28,31,37):RGB(246,247,250);}
inline COLORREF foreground(){return dark?RGB(235,238,243):RGB(24,28,35);}
inline HBRUSH brush(){return dark?darkBrush:lightBrush;}
inline void apply(HWND h){
    EnumChildWindows(h,[](HWND child,LPARAM)->BOOL{SetWindowTheme(child,dark?L"":L"Explorer",nullptr);InvalidateRect(child,nullptr,TRUE);return TRUE;},0);
    InvalidateRect(h,nullptr,TRUE);
}
inline bool paint(HWND h,UINT m,WPARAM wp,LPARAM lp,LRESULT& result){
    if(m==WM_ERASEBKGND){RECT rc{};GetClientRect(h,&rc);FillRect(reinterpret_cast<HDC>(wp),&rc,brush());result=1;return true;}
    if(m==WM_CTLCOLORSTATIC||m==WM_CTLCOLORBTN||m==WM_CTLCOLOREDIT||m==WM_CTLCOLORLISTBOX){auto dc=reinterpret_cast<HDC>(wp);SetBkColor(dc,background());SetTextColor(dc,foreground());result=reinterpret_cast<LRESULT>(brush());return true;}
    if(m==WM_DRAWITEM){auto d=reinterpret_cast<DRAWITEMSTRUCT*>(lp);if(d->CtlType!=ODT_BUTTON)return false;
        auto fill=CreateSolidBrush(dark?RGB(48,54,65):RGB(225,230,238));FillRect(d->hDC,&d->rcItem,fill);DeleteObject(fill);SetBkMode(d->hDC,TRANSPARENT);SetTextColor(d->hDC,foreground());
        const auto font=reinterpret_cast<HFONT>(SendMessageW(d->hwndItem,WM_GETFONT,0,0));
        const auto previous=font?SelectObject(d->hDC,font):nullptr;
        wchar_t text[256]{};GetWindowTextW(d->hwndItem,text,256);auto rc=d->rcItem;DrawTextW(d->hDC,text,-1,&rc,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
        if(previous)SelectObject(d->hDC,previous);
        if(d->itemState&ODS_FOCUS)DrawFocusRect(d->hDC,&rc);result=TRUE;return true;
    }
    return false;
}
}
