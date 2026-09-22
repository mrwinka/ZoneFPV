#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <filesystem>
#include <fstream>
#include <string>
#include <array>
#include <algorithm>
#include <atomic>
#include <iostream>
#include <cassert>
namespace fs=std::filesystem;
#include "language.h"
#include "osd.h"
int main(){
    osd::root=fs::temp_directory_path()/(L"ZoneFPV-layout-test-"+std::to_wstring(GetCurrentProcessId()));fs::create_directories(osd::root);
    osd::items=osd::defaults;osd::items[0]={.31,.67,48,3,false};osd::crossStyle=2;osd::enabled=false;osd::fontChoice=7;
    assert(osd::save());osd::items=osd::defaults;osd::enabled=true;osd::crossStyle=0;osd::fontChoice=0;osd::load();assert(osd::fontChoice==7);
    assert(osd::items[0].x==.31&&osd::items[0].y==.67&&osd::items[0].size==48&&osd::items[0].color==3&&!osd::items[0].visible&&!osd::enabled&&osd::crossStyle==2);
    std::cout<<"PASS layout persistence\n";
    {std::ofstream f(osd::root/L"osd-layout.txt");f<<"1 1 0\n0.1 0.5 999 7 1\n";}
    osd::load();assert(osd::items[0].size==48&&!osd::enabled);std::cout<<"PASS damaged layout rejected atomically\n";
    for(int i=0;i<4;++i){language::current=i;assert(wcslen(language::tr(L"Редактор OSD"))>0);assert(wcslen(language::tr(L"Speed / km/h"))>0);}
    language::current=1;assert(wcscmp(language::tr(L"Время суток"),L"Час доби")==0);language::current=3;assert(wcscmp(language::tr(L"Погода"),L"Pogoda")==0);
    language::current=4;assert(wcscmp(language::tr(L"Погода"),L"Wetter")==0);assert(wcscmp(language::translateAny(L"Prędkość (2× — pierwotna)"),L"Geschwindigkeit (2× — ursprünglich)")==0);
    std::cout<<"PASS localization\n";
    {std::ofstream f(osd::root/L"osd-layout.txt");f<<"1 1 0\n";for(const auto& e:osd::defaults)f<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';}
    osd::load();assert(osd::fontChoice==0&&osd::enabled);std::cout<<"PASS version 1 migration\n";
    osd::root=fs::path(__FILE__).parent_path().parent_path()/L"mod";
    assert(osd::loadBetaflight());assert(osd::bitmapText(nullptr,L"SPD 123",0,0,36,0,false).cx==168);
    BITMAP b{};assert(GetObjectW(osd::glyphBitmap[0],sizeof(b),&b));const auto* pixels=static_cast<const DWORD*>(b.bmBits);int lit=0;
    for(int y=0;y<18;++y)for(int x=0;x<12;++x)if(pixels[((65/16)*18+y)*192+(65%16)*12+x]==0xffffff)++lit;
    assert(lit>0);osd::cleanup();std::cout<<"PASS actual Betaflight glyph decode\n";return 0;
}
