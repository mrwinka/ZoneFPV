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
#include <sstream>
#include <tuple>
namespace fs=std::filesystem;
#include "language.h"
#include "osd.h"
void checkCrosshairs(){
    auto dc=CreateCompatibleDC(nullptr);BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);
    constexpr int width=320,height=180;info.bmiHeader.biWidth=width;info.bmiHeader.biHeight=-height;
    info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;void* memory=nullptr;
    const auto bitmap=CreateDIBSection(dc,&info,DIB_RGB_COLORS,&memory,nullptr,0);assert(bitmap&&memory);
    const auto old=SelectObject(dc,bitmap);auto* pixels=static_cast<DWORD*>(memory);RECT area{0,0,width,height};
    osd::items=osd::defaults;for(auto& item:osd::items)item.visible=false;
    osd::items[4]={.5,.5,72,0,true};osd::data={};osd::data.active=true;
    const auto render=[&](){std::fill(pixels,pixels+width*height,0x335577u);osd::draw(dc,area,false);GdiFlush();
        unsigned long long hash=1469598103934665603ull;for(int i=0;i<width*height;++i){hash^=pixels[i];hash*=1099511628211ull;}return hash;};
    std::array<unsigned long long,6> styles{};
    for(int style=0;style<6;++style){osd::crossStyle=style;styles[style]=render();assert(osd::bounds[4].right>osd::bounds[4].left);
        for(int previous=0;previous<style;++previous)assert(styles[previous]!=styles[style]);}
    osd::crossStyle=0;osd::downCrossStyle=4;osd::data.cameraDown=true;
    assert(osd::crossStyleFor(osd::data)==4&&render()==styles[4]);
    osd::items[4].visible=false;assert(osd::itemVisible(4,osd::data));render();assert(!IsRectEmpty(&osd::bounds[4]));
    osd::downCrossVisible=false;render();assert(IsRectEmpty(&osd::bounds[4]));osd::items[4].visible=true;render();assert(IsRectEmpty(&osd::bounds[4]));
    osd::downCrossVisible=true;
    osd::items[3].visible=true;render();assert(osd::bounds[3].right==0&&osd::items[3].visible);
    osd::data.cameraDown=false;assert(osd::crossStyleFor(osd::data)==0);render();assert(osd::bounds[3].right>osd::bounds[3].left&&osd::items[3].visible);
    osd::previewCameraDown=true;osd::draw(dc,area,true);assert(osd::bounds[3].right==0&&osd::items[3].visible);osd::previewCameraDown=false;
    osd::items=osd::defaults;osd::data={};osd::crossStyle=0;
    SelectObject(dc,old);DeleteObject(bitmap);DeleteDC(dc);
    std::cout<<"PASS six distinct actual GDI crosshair rasters, independent lower-camera choice, automatic horizon hide and restoration without preference mutation\n";
}
void exportVisualPreview(const fs::path& directory){
    fs::create_directories(directory);
    constexpr int width=1280,height=720;
    auto dc=CreateCompatibleDC(nullptr);BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth=width;info.bmiHeader.biHeight=-height;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;
    void* pixels=nullptr;const auto bitmap=CreateDIBSection(dc,&info,DIB_RGB_COLORS,&pixels,nullptr,0);assert(bitmap&&pixels);
    const auto old=SelectObject(dc,bitmap);auto* values=static_cast<DWORD*>(pixels);const RECT area{0,0,width,height};
    osd::data={};osd::data.active=true;osd::data.signalEnabled=true;osd::data.noiseStyle=4;
    for(const int rssi:{100,65,35,8,0}){
        std::fill(values,values+width*height,0u);osd::data.rssi=rssi;osd::data.signalLost=rssi==0;
        osd::nextFineNoise=0;osd::noiseSeed=13817;osd::drawSignalNoise(dc,area);GdiFlush();
        std::ofstream out(directory/("analog-rssi-"+std::to_string(rssi)+".ppm"),std::ios::binary);
        out<<"P6\n"<<width<<' '<<height<<"\n255\n";
        for(int i=0;i<width*height;++i){const char rgb[]={static_cast<char>(values[i]>>16),static_cast<char>(values[i]>>8),static_cast<char>(values[i])};out.write(rgb,3);}
        assert(out.good());
    }
    osd::data={};osd::data.active=true;osd::scanMarkers={{1,.2,.4,15,.10,.40,0,1},{1,.5,.4,20,.10,.40,2,6},{1,.8,.4,8,.10,.40,3,4}};
    std::fill(values,values+width*height,0u);osd::drawExperiments(dc,area);GdiFlush();
    std::ofstream out(directory/"scan-rectangles.ppm",std::ios::binary);out<<"P6\n"<<width<<' '<<height<<"\n255\n";
    for(int i=0;i<width*height;++i){const char rgb[]={static_cast<char>(values[i]>>16),static_cast<char>(values[i]>>8),static_cast<char>(values[i])};out.write(rgb,3);}
    assert(out.good());osd::scanMarkers.clear();SelectObject(dc,old);DeleteObject(bitmap);DeleteDC(dc);
}
void checkScanFrameLease(){
    osd::ScanLease lease;std::vector<osd::ScanMarker> markers;
    osd::Data telemetry;telemetry.active=true;telemetry.hpEnabled=true;telemetry.hpPercent=73;
    telemetry.detectorEnabled=true;telemetry.artifactDistance=4.25;
    const auto packet=[](ULONGLONG sequence,double x,int count=1){
        std::ostringstream text;text<<"3 "<<sequence<<' '<<count<<'\n';
        if(count)text<<"1 "<<x<<" .4 .1 .2 10 2 6\n";
        text<<sequence<<'\n';return text.str();
    };
    const auto read=[&](const std::string& text,ULONGLONG now,bool active=true){
        std::istringstream input(text);osd::updateScanFrame(input,active,now,markers,lease);
    };
    read(packet(90,.3),1000);assert(markers.size()==1&&markers[0].x==.3&&lease.changed==1000);
    assert(osd::scanPollInterval(markers)==8);
    read(packet(90,.8),1099);assert(markers.size()==1&&markers[0].x==.3&&lease.changed==1000);
    read(packet(91,.4),1099);assert(markers.size()==1&&markers[0].x==.4&&lease.changed==1099);
    read("3 92 1\n1 .5 .4 .1 .2 10 2 6\n",1100);
    assert(markers.empty()&&!lease.available&&lease.sequence==91&&osd::scanPollInterval(markers)==50);
    read(packet(91,.4),1101);assert(markers.empty()&&lease.changed==1099);
    read(packet(92,.5),1102);assert(markers.size()==1&&markers[0].x==.5);
    read(packet(93,.6,0),1103);assert(markers.empty()&&lease.sequence==93);
    read(packet(94,.6),1104);assert(markers.size()==1);
    read(packet(94,.6),1203);assert(markers.size()==1&&lease.changed==1104);
    read(packet(94,.6),1204);assert(markers.empty()&&!lease.available);
    read(packet(94,.6),1205);assert(markers.empty());
    read(packet(1,.2),1206);assert(markers.size()==1&&markers[0].x==.2&&lease.sequence==1&&lease.changed==1206);
    read(packet(1,.2),1207,false);assert(markers.empty()&&!lease.available);
    read(packet(1,.2),1208);assert(markers.empty());
    read(packet(2,.7),1209);assert(markers.size()==1&&markers[0].x==.7);
    std::ifstream missing(osd::root/L"never-written-scan-lease-fixture.txt");
    assert(!missing);osd::updateScanFrame(missing,true,1210,markers,lease);
    assert(markers.empty()&&!lease.available);
    read(packet(2,.7),1211);assert(markers.empty());
    read(packet(3,.8),1212);assert(markers.size()==1);
    read(packet(3,.8),1211);assert(markers.empty()&&!lease.available);
    read("4 10000 4 0\n10000 4\n",1213);assert(markers.empty()&&!lease.everV4&&lease.sequence==3);
    assert(telemetry.active&&telemetry.hpEnabled&&telemetry.hpPercent==73&&telemetry.detectorEnabled&&telemetry.artifactDistance==4.25);
    std::cout<<"PASS fresh scan-frame lease: consecutive frames, duplicates, immediate torn/missing withdrawal, empty frame,100ms expiry, restart, FPV exit and isolated telemetry\n";
}
void checkAlternatingScanFrameLease(){
    osd::ScanLease lease;std::vector<osd::ScanMarker> markers;
    const std::string old="3 999 1\n1 .9 .4 .1 .2 10 2 6\n999\n";
    const auto packet=[](ULONGLONG generation,ULONGLONG sequence,double x,int count=1){
        std::ostringstream text;text<<"4 "<<generation<<' '<<sequence<<' '<<count<<'\n';
        if(count)text<<"1 "<<x<<" .4 .1 .2 10 2 6\n";
        text<<generation<<' '<<sequence<<'\n';return text.str();
    };
    const auto read=[&](const std::string& a,const std::string& b,ULONGLONG now,bool active=true){
        std::istringstream first(a),second(b),legacy(old);
        osd::updateScanFrames(first,second,legacy,active,now,markers,lease);
    };
    read("","",1000);assert(markers.size()==1&&markers[0].x==.9&&!lease.everV4);
    read(packet(10000,1,.2),packet(10000,2,.3),1001);
    assert(markers.size()==1&&markers[0].x==.3&&lease.everV4&&lease.sequence==2&&lease.generation==10000);
    read("4 10000 3 1\n1 .8 .4 .1 .2 10 2 6\n",packet(10000,2,.3),1002);
    assert(markers.size()==1&&markers[0].x==.3&&lease.sequence==2&&lease.changed==1001);
    read(packet(10000,3,.4),packet(10000,2,.3),1003);
    assert(markers.size()==1&&markers[0].x==.4&&lease.sequence==3&&lease.changed==1003);
    read("4 10000 5 1\n",packet(10000,2,.3),1004);
    assert(markers.size()==1&&markers[0].x==.4&&lease.sequence==3&&lease.changed==1003);
    read(packet(10000,3,.4),packet(10000,4,.5,0),1005);
    assert(markers.empty()&&lease.sequence==4);
    read(packet(10000,5,.5),packet(10000,4,.5,0),1006);assert(markers.size()==1);
    read(packet(10000,5,.5),"",1105);assert(markers.size()==1&&lease.changed==1006);
    read(packet(10000,5,.5),"",1106);assert(markers.empty()&&!lease.available);
    read(packet(10000,5,.5),"",1107);assert(markers.empty());
    read(packet(10000,800,.7),packet(10001,1,.6),1108);
    assert(markers.size()==1&&markers[0].x==.6&&lease.generation==10001&&lease.sequence==1);
    read(packet(10000,900,.8),packet(10001,1,.6),1109);
    assert(markers.size()==1&&markers[0].x==.6&&lease.changed==1108);
    read("4 10001 2 1\n","",1110);assert(markers.empty()&&!lease.available&&lease.everV4);
    read(packet(10001,1,.6),"",1111);assert(markers.empty());
    read(packet(10001,2,.7),"",1112);assert(markers.size()==1&&markers[0].x==.7);
    read("","",1113);assert(markers.empty()&&!lease.available&&lease.everV4);
    read("","",1114);assert(markers.empty()); // Valid legacy999 cannot resurrect a v4 scanner.
    read(packet(10001,3,.8),"",1115);assert(markers.size()==1);
    read(packet(10001,3,.8),"",1116,false);assert(markers.empty());
    read(packet(10001,3,.8),"",1117);assert(markers.empty());
    read(packet(10001,4,.4),"",1118);assert(markers.size()==1&&markers[0].x==.4);
    {std::vector<osd::ScanMarker> parsed;ULONGLONG sequence=17,generation=25;
        for(const auto* bad:{"4 0 1 0\n0 1\n","4 9007199254740992 1 0\n9007199254740992 1\n",
            "4 10001 9007199254740992 0\n10001 9007199254740992\n","4 10001 5 0\n10002 5\n",
            "4 10001 5 0\n10001 4\n","4 10001 5 0\n10001 5 extra\n"}){
            std::istringstream input(bad);assert(!osd::parseScanFrame(input,parsed,sequence,&generation)&&sequence==17&&generation==25);
        }
        std::istringstream good(packet(10002,1,.2));
        assert(osd::parseScanFrame(good,parsed,sequence,&generation)&&generation==10002&&sequence==1&&parsed.size()==1);
    }
    std::cout<<"PASS alternating v4 scan snapshots: complete-slot selection, interrupted writes, no sequence rollback,100ms lease, empty/exit withdrawal, generation restart and permanent legacy retirement\n";
}
int main(int argc,char* argv[]){
    checkCrosshairs();
    checkScanFrameLease();
    checkAlternatingScanFrameLease();
    osd::root=fs::path(__FILE__).parent_path().parent_path()/L"mod";
    osd::Data telemetry;ULONGLONG sequence=0;
    {std::istringstream in("2 42 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 42");
        assert(osd::parseTelemetry(in,telemetry,sequence)&&sequence==42&&telemetry.rssi==23.5&&telemetry.signalEnabled&&!telemetry.signalLost);}
    {std::istringstream in("1 43 1 10 20 30 0 0 45 0 60 0 50 43");
        assert(osd::parseTelemetry(in,telemetry,sequence)&&!telemetry.signalEnabled&&telemetry.rssi==100);}
    for(const auto* packet:{"2 44 1 10 20 30 0 0 45 0 60 0 50 1 0 1 45",
         "2 44 1 10 20 30 0 0 45 0 60 0 50 1 101 0 44",
         "2 44 1 10 20 30 0 0 45 0 60 0 50 0 0 1 44",
         "2 44 1 10 20 30 0 0 45 0 60 0 50 1 0 1"}){
        std::istringstream in(packet);assert(!osd::parseTelemetry(in,telemetry,sequence)&&sequence==43);}
    std::cout<<"PASS RSSI telemetry, old bridge packets and atomic rejection\n";
    {std::istringstream in("3 50 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 3 1 67.5 1 2.5 1 50");
        assert(osd::parseTelemetry(in,telemetry,sequence)&&sequence==50&&telemetry.noiseStyle==3&&telemetry.hpEnabled&&telemetry.hpPercent==67.5&&telemetry.detectorEnabled&&telemetry.artifactDistance==2.5&&telemetry.artifactReady);}
    {std::istringstream in("3 50 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 50");
        assert(osd::parseTelemetry(in,telemetry,sequence)&&telemetry.noiseStyle==4);}
    for(const auto* packet:{"3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 5 1 50 1 4 0 51",
         "3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 1 1 101 1 4 0 51",
         "3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 1 1 50 1 -2 0 51",
         "3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 1 1 50 0 4 1 51",
         "3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 1 1 50 1 4 0"}){
        std::istringstream in(packet);assert(!osd::parseTelemetry(in,telemetry,sequence)&&sequence==50&&telemetry.hpPercent==67.5);}
    std::cout<<"PASS v3 HP, detector and interference telemetry with atomic range rejection\n";
    for(const int count:{0,1,20,-1}){
        std::ostringstream packet;packet<<"4 52 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 "<<count<<" 52";
        std::istringstream in(packet.str());assert(osd::parseTelemetry(in,telemetry,sequence)&&sequence==52&&telemetry.grenadeEnabled&&telemetry.grenadeRemaining==count);
        assert(osd::grenadeText(telemetry)==(count<0?L"GRENADES INF":L"GRENADES "+std::to_wstring(count)));
    }
    for(const auto* packet:{"4 53 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 -2 53",
        "4 53 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 21 53",
        "4 53 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 2 1 53",
        "4 53 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 0 1 53",
        "4 53 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 0.5 53",
        "4 53 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 1 54",
        "4 53 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 1 53 extra"}){
        std::istringstream in(packet);assert(!osd::parseTelemetry(in,telemetry,sequence)&&sequence==52&&telemetry.grenadeRemaining==-1);
    }
    {std::istringstream legacy("3 50 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 50");
        assert(osd::parseTelemetry(legacy,telemetry,sequence)&&!telemetry.grenadeEnabled&&telemetry.grenadeRemaining==0);}
    if(argc>1){std::ifstream actual(argv[1]);osd::Data parsed;ULONGLONG seq=0;
        assert(actual&&osd::parseTelemetry(actual,parsed,seq)&&parsed.active&&parsed.grenadeEnabled&&parsed.grenadeRemaining==0&&seq==3);
        std::cout<<"PASS real Lua ammo publication consumed by production C++ telemetry parser\n";}
    if(argc>3){std::ifstream first(argv[2]),second(argv[3]);std::istringstream legacy;
        assert(first&&second);osd::ScanLease lease;std::vector<osd::ScanMarker> markers;
        osd::updateScanFrames(first,second,legacy,true,1000,markers,lease);
        assert(lease.everV4&&lease.generation>0&&lease.sequence==2&&markers.size()==1&&markers[0].type==3);
        assert(markers[0].x>0&&markers[0].x<1&&markers[0].width>0&&markers[0].height>0);
        std::cout<<"PASS actual Lua current-camera scan packets consumed by production C++ paired-v4 reader with matching generation and newest sequence\n";}
    std::cout<<"PASS v4 ammunition finite/zero/unlimited framing, v1-v3 migration and atomic malformed rejection\n";
    {osd::Data value;ULONGLONG seq=0;
        for(const int down:{0,1}){std::istringstream input(std::string("5 54 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 3 ")+std::to_string(down)+" 54");
            assert(osd::parseTelemetry(input,value,seq)&&value.cameraDown==(down==1)&&value.grenadeRemaining==3&&seq==54);}
        for(const auto* bad:{"5 55 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 3 2 55",
            "5 55 0 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 3 1 55",
            "5 55 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 3 1 56",
            "5 55 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 3 1 55 extra"}){
            std::istringstream input(bad);assert(!osd::parseTelemetry(input,value,seq)&&seq==54&&value.cameraDown);}
        std::istringstream legacy("4 54 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 2.5 1 1 3 54");
        assert(osd::parseTelemetry(legacy,value,seq)&&!value.cameraDown);}
    std::cout<<"PASS v5 lower-camera framing, legacy normal-camera default and malformed camera flags rejected atomically\n";
    // Collection readiness comes from the Lua distance gate. Adjustable ranges
    // can exceed the old 3 m default, but never the supported maximum of 10 m.
    for(const double distance:{.5,3.5,5.,10.}){
        std::ostringstream packet;packet<<"3 50 1 10 20 30 0 0 45 0 60 0 50 1 23.5 0 4 1 67.5 1 "<<distance<<" 1 50";
        std::istringstream in(packet.str());
        assert(osd::parseTelemetry(in,telemetry,sequence)&&telemetry.artifactReady&&telemetry.artifactDistance==distance);
    }
    for(const auto* packet:{"3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 1 1 50 1 10.01 1 51",
        "3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 1 1 50 1 -1 1 51",
        "3 51 1 10 20 30 0 0 45 0 60 0 50 1 20 0 1 1 50 0 5 1 51"}){
        std::istringstream in(packet);assert(!osd::parseTelemetry(in,telemetry,sequence)&&sequence==50&&telemetry.artifactDistance==10);
    }
    std::cout<<"PASS adjustable artifact readiness from 0.5 to 10 m, bounded by the Lua collection gate\n";
    {const auto expected=telemetry;const auto expectedSequence=sequence;
        const auto fields=[](const osd::Data& d){return std::tie(d.active,d.speed,d.altitude,d.distance,d.pitch,d.roll,
            d.heading,d.home,d.seconds,d.climb,d.throttle,d.signalEnabled,d.rssi,d.signalLost,d.noiseStyle,
            d.hpEnabled,d.hpPercent,d.detectorEnabled,d.artifactDistance,d.artifactReady,d.grenadeEnabled,d.grenadeRemaining);};
        for(const auto* packet:{"1 51 0 11 21 31 1 2 46 1 61 1 51 51 junk",
             "2 51 0 11 21 31 1 2 46 1 61 1 51 1 20 0 51 junk",
             "3 51 0 11 21 31 1 2 46 1 61 1 51 1 20 0 1 1 50 1 4 0 51 junk"}){
            std::istringstream in(packet);assert(!osd::parseTelemetry(in,telemetry,sequence));
            assert(sequence==expectedSequence&&fields(telemetry)==fields(expected));}
        std::istringstream whitespace("3 51 0 11 21 31 1 2 46 1 61 1 51 1 20 0 1 1 50 1 4 0 51 \t\n");
        osd::Data parsed;ULONGLONG parsedSequence=0;
        assert(osd::parseTelemetry(whitespace,parsed,parsedSequence)&&parsedSequence==51);}
    std::cout<<"PASS telemetry trailing tokens rejected without changing the prior frame\n";
    {std::vector<osd::ScanMarker> markers;ULONGLONG frameSeq=0;std::istringstream in("1 60 4 1 .2 .3 30 2 .4 .5 40 3 .6 .7 50 4 .8 .9 60 60");
        assert(osd::parseScanFrame(in,markers,frameSeq)&&frameSeq==60&&markers.size()==4&&markers[3].type==4);
        for(const auto* packet:{"1 61 65","1 61 1 0 .5 .5 10 61","1 61 1 1 1.1 .5 10 61","1 61 1 1 .5 .5 -1 61","1 61 1 1 .5 .5 10 60","1 61 1 1 .5 .5 10 61 extra"}){
            std::istringstream bad(packet);assert(!osd::parseScanFrame(bad,markers,frameSeq)&&frameSeq==60&&markers.size()==4);}
        std::cout<<"PASS bounded scan markers and malformed-frame rejection\n";}
    {std::vector<osd::ScanMarker> markers;ULONGLONG frameSeq=0;
        std::istringstream in("2 62 2 1 .5 .4 .2 .5 30 3 .9 .8 .2 .4 50 62");
        assert(osd::parseScanFrame(in,markers,frameSeq)&&frameSeq==62&&markers.size()==2&&markers[0].width==.2&&markers[0].height==.5);
        for(const auto* packet:{"2 63 1 1 .5 .5 0 .1 10 63","2 63 1 1 .5 .5 .1 -1 10 63",
             "2 63 1 1 .95 .5 .2 .1 10 63","2 63 1 1 .5 .05 .1 .2 10 63","2 63 1 1 .5 .5 .1 .1 10 62",
             "2 63 1 1 .5 .5 .1 .1 10 63 extra","4 63 0 63"}){
            std::istringstream bad(packet);assert(!osd::parseScanFrame(bad,markers,frameSeq)&&frameSeq==62&&markers.size()==2);}
        std::cout<<"PASS projected scan rectangles v2 and atomic bounds validation\n";}
    {std::vector<osd::ScanMarker> markers;ULONGLONG frameSeq=0;
        std::istringstream in("3 64 3 1 .3 .4 .1 .2 10 0 6 1 .5 .4 .1 .2 11 2 3 1 .7 .4 .1 .2 12 3 4 64");
        assert(osd::parseScanFrame(in,markers,frameSeq)&&markers.size()==3&&markers[0].faction==6);
        assert(osd::scanColor(markers[0])==RGB(239,70,78)&&osd::scanColor(markers[1])==RGB(232,229,207)&&osd::scanColor(markers[2])==RGB(80,220,115));
        for(const auto* packet:{"3 65 1 1 .5 .5 .1 .1 10 5 6 65","3 65 1 1 .5 .5 .1 .1 10 2 15 65",
            "3 65 1 1 .5 .5 .1 .1 10 -2 6 65","3 65 1 1 .5 .5 .1 .1 10 2 6 64"}){
            std::istringstream bad(packet);assert(!osd::parseScanFrame(bad,markers,frameSeq)&&frameSeq==64&&markers.size()==3);
        }
        std::cout<<"PASS exact faction ids, real relationship colours and malformed v3 rejection\n";
    }
    {auto dc=CreateCompatibleDC(nullptr);BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);
        info.bmiHeader.biWidth=320;info.bmiHeader.biHeight=-180;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;
        void* pixels=nullptr;auto bitmap=CreateDIBSection(dc,&info,DIB_RGB_COLORS,&pixels,nullptr,0);assert(bitmap&&pixels);
        auto old=SelectObject(dc,bitmap);auto* values=static_cast<DWORD*>(pixels);RECT area{0,0,320,180};
        for(int faction=1;faction<=14;++faction){
            std::fill(values,values+320*180,0u);osd::drawFactionIcon(dc,faction,0,0,64,RGB(232,229,207));GdiFlush();
            assert(osd::factionIcons[static_cast<size_t>(faction)].dc);
            assert(std::any_of(values,values+320*180,[](DWORD v){return v!=0;}));
            assert(std::any_of(osd::factionIcons[static_cast<size_t>(faction)].alpha.begin(),osd::factionIcons[static_cast<size_t>(faction)].alpha.end(),[](unsigned char a){return a==0;}));
        }
        osd::data.active=true;osd::data.signalEnabled=true;osd::data.rssi=100;
        std::fill(values,values+320*180,0x335577u);osd::drawSignalNoise(dc,area);GdiFlush();
        assert(std::all_of(values,values+320*180,[](DWORD value){return value==0x335577u;}));
        for(int style=0;style<5;++style){
            osd::data.rssi=100;osd::data.noiseStyle=style;std::fill(values,values+320*180,0x335577u);osd::drawSignalNoise(dc,area);GdiFlush();
            assert(std::all_of(values,values+320*180,[](DWORD value){return value==0x335577u;}));
            osd::data.rssi=30;osd::drawSignalNoise(dc,area);GdiFlush();
            assert(std::any_of(values,values+320*180,[](DWORD value){return value!=0x335577u;}));
        }
        assert(osd::fineNoiseDensity(.1)<osd::fineNoiseDensity(.4)&&osd::fineNoiseDensity(.4)<osd::fineNoiseDensity(.9));
        osd::data.noiseStyle=4;osd::data.rssi=0;osd::data.signalLost=true;osd::nextFineNoise=0;
        std::fill(values,values+320*180,0x335577u);osd::drawSignalNoise(dc,area);GdiFlush();
        assert(std::count(values,values+320*180,0x335577u)<320*180/20);
        osd::data.signalLost=false;osd::data.signalEnabled=false;osd::scanMarkers={{1,.5,.5,10,.25,.5}};
        std::fill(values,values+320*180,0u);osd::drawExperiments(dc,area);GdiFlush();
        assert(values[45*320+123]!=0&&values[48*320+120]!=0
            &&values[90*320+160]==0&&values[40*320+115]==0);
        osd::scanMarkers.clear();osd::data.signalEnabled=true;osd::data.noiseStyle=0;
        osd::data.rssi=0;osd::data.signalLost=true;osd::drawSignalNoise(dc,area);GdiFlush();
        assert(values[0]==0x101010u);SelectObject(dc,old);DeleteObject(bitmap);DeleteDC(dc);
        osd::data={};std::cout<<"PASS clean strong signal, weak-signal interference and complete video loss\n";}
    osd::root=fs::temp_directory_path()/(L"ZoneFPV-layout-test-"+std::to_wstring(GetCurrentProcessId()));fs::create_directories(osd::root);
    osd::items=osd::defaults;osd::items[0]={.31,.67,48,3,false};osd::crossStyle=2;osd::enabled=false;osd::fontChoice=7;
    assert(osd::save());osd::items=osd::defaults;osd::enabled=true;osd::crossStyle=0;osd::fontChoice=0;osd::load();assert(osd::fontChoice==7);
    assert(osd::items[0].x==.31&&osd::items[0].y==.67&&osd::items[0].size==48&&osd::items[0].color==3&&!osd::items[0].visible&&!osd::enabled&&osd::crossStyle==2);
    std::cout<<"PASS layout persistence\n";
    {osd::crossStyle=5;osd::downCrossStyle=3;osd::downCrossVisible=false;assert(osd::save());osd::crossStyle=0;osd::downCrossStyle=4;osd::downCrossVisible=true;osd::load();assert(osd::crossStyle==5&&osd::downCrossStyle==3&&!osd::downCrossVisible);
        std::ofstream file(osd::root/L"osd-layout.txt");file<<"5 0 2 7\n";for(const auto& item:osd::items)file<<item.x<<' '<<item.y<<' '<<item.size<<' '<<item.color<<' '<<item.visible<<'\n';file.close();
        osd::load();assert(osd::crossStyle==2&&osd::downCrossStyle==4&&osd::downCrossVisible&&!osd::items[0].visible&&osd::items[0].x==.31);
        for(const auto* header:{"6 1 6 0 4","6 1 0 0 6","6 1 0 0 -1","6 1 0 0 4 extra","7 1 0 0 4 -1","7 1 0 0 4 2","7 1 0 0 4 1 extra"}){std::ofstream bad(osd::root/L"osd-layout.txt");bad<<header<<'\n';for(const auto& item:osd::defaults)bad<<item.x<<' '<<item.y<<' '<<item.size<<' '<<item.color<<' '<<item.visible<<'\n';bad.close();
            osd::load();assert(osd::crossStyle==2&&osd::downCrossStyle==4&&osd::downCrossVisible&&!osd::items[0].visible&&osd::items[0].x==.31);}}
    std::cout<<"PASS v7 independent lower visibility/style persistence, v5 all14-item migration and atomic malformed style rejection\n";
    {std::ofstream file(osd::root/L"osd-layout.txt");file<<"6 0 5 7 3\n";for(const auto& item:osd::items)file<<item.x<<' '<<item.y<<' '<<item.size<<' '<<item.color<<' '<<item.visible<<'\n';file.close();
        const auto before=osd::items;osd::downCrossVisible=false;osd::load();assert(!osd::enabled&&osd::crossStyle==5&&osd::fontChoice==7&&osd::downCrossStyle==3&&osd::downCrossVisible);
        for(size_t i=0;i<before.size();++i){const auto& a=before[i];const auto& b=osd::items[i];assert(a.x==b.x&&a.y==b.y&&a.size==b.size&&a.color==b.color&&a.visible==b.visible);}
        osd::crossStyle=2;osd::save();}
    std::cout<<"PASS legacy v6 migration preserves both styles and all14 positions with lower visibility enabled\n";
    {std::ofstream f(osd::root/L"osd-layout.txt");f<<"1 1 0\n0.1 0.5 999 7 1\n";}
    osd::load();assert(osd::items[0].size==48&&!osd::enabled);std::cout<<"PASS damaged layout rejected atomically\n";
    for(int i=0;i<4;++i){language::current=i;assert(wcslen(language::tr(L"Редактор OSD"))>0);assert(wcslen(language::tr(L"Speed / km/h"))>0);}
    language::current=1;assert(wcscmp(language::tr(L"Время суток"),L"Час доби")==0);language::current=3;assert(wcscmp(language::tr(L"Погода"),L"Pogoda")==0);
    language::current=4;assert(wcscmp(language::tr(L"Погода"),L"Wetter")==0);assert(wcscmp(language::translateAny(L"Prędkość (2× — pierwotna)"),L"Geschwindigkeit (2× — ursprünglich)")==0);
    for(int i=1;i<5;++i){language::current=i;
        for(const auto* source:{L"Фонарик дрона",L"Расстояние для сбора артефакта",
            L"Детектор показывает артефакты в пределах 100 м.\nПодлетите на выбранное расстояние и нажмите кнопку сбора.\nСбор доступен в FPV с включённым детектором.",
            L"Подлетите к артефакту на выбранное расстояние сбора."}){
            const auto translated=language::tr(source);
            assert(wcscmp(source,translated)!=0&&wcscmp(language::translateAny(translated),translated)==0);
        }
    }
    std::cout<<"PASS localization\n";
    {std::ofstream f(osd::root/L"osd-layout.txt");f<<"1 1 0\n";for(const auto& e:osd::defaults)f<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';}
    osd::load();assert(osd::fontChoice==0&&osd::enabled);std::cout<<"PASS version 1 migration\n";
    {std::ofstream f(osd::root/L"osd-layout.txt");f<<"2 1 0 7\n";for(int i=0;i<10;++i){const auto& e=osd::defaults[i];f<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';}}
    osd::load();assert(osd::fontChoice==7&&osd::items[10].visible&&osd::items[10].x==osd::defaults[10].x);
    std::cout<<"PASS stable v2 layout migration adds RSSI without changing prior elements\n";

    const auto legacy=osd::items;
    {std::ofstream f(osd::root/L"osd-layout.txt");f<<"3 0 2 7\n";for(int i=0;i<11;++i){const auto& e=legacy[i];f<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';}}
    osd::items[11]={.4,.4,60,4,false};osd::items[12]={.5,.5,60,4,false};osd::load();
    for(int i=0;i<11;++i){const auto& a=osd::items[i];const auto& b=legacy[i];assert(std::tie(a.x,a.y,a.size,a.color,a.visible)==std::tie(b.x,b.y,b.size,b.color,b.visible));}
    assert(osd::items[11].visible&&osd::items[12].visible&&osd::fontChoice==7&&!osd::enabled&&osd::crossStyle==2);
    osd::items[11]={.22,.33,48,1,false};osd::items[12]={.62,.73,36,2,true};assert(osd::save());
    osd::items=osd::defaults;osd::load();
    assert(osd::items[11].x==.22&&osd::items[11].y==.33&&osd::items[11].size==48&&osd::items[11].color==1&&!osd::items[11].visible);
    assert(osd::items[12].x==.62&&osd::items[12].y==.73&&osd::items[12].size==36&&osd::items[12].color==2&&osd::items[12].visible);
    {std::ofstream f(osd::root/L"osd-layout.txt");f<<"4 1 0 0\n";for(int i=0;i<12;++i){const auto& e=osd::defaults[i];f<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';}f<<".5 .5 24 99 1\n";}
    osd::load();assert(osd::items[11].x==.22&&!osd::items[11].visible&&osd::items[12].color==2&&!osd::enabled);
    std::cout<<"PASS v3 layout migration preserves every existing item; v4 HP/detector round trip and atomic rejection\n";
    {const auto existing=osd::items;
        std::ofstream legacyFile(osd::root/L"osd-layout.txt");legacyFile<<"4 0 2 7\n";
        for(int i=0;i<13;++i){const auto& e=existing[i];legacyFile<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';}legacyFile.close();
        osd::items[13]={.1,.2,72,4,false};osd::load();
        for(int i=0;i<13;++i){const auto& a=osd::items[i];const auto& b=existing[i];assert(std::tie(a.x,a.y,a.size,a.color,a.visible)==std::tie(b.x,b.y,b.size,b.color,b.visible));}
        const auto& ammoDefault=osd::defaults[13];const auto& added=osd::items[13];assert(added.x==ammoDefault.x&&added.y==ammoDefault.y&&added.visible&&osd::fontChoice==7&&!osd::enabled&&osd::crossStyle==2);
        osd::items[13]={.44,.17,32,3,false};assert(osd::save());osd::items=osd::defaults;osd::load();
        assert(osd::items[13].x==.44&&osd::items[13].y==.17&&osd::items[13].size==32&&osd::items[13].color==3&&!osd::items[13].visible);
        const auto preserved=osd::items;
        std::ofstream damaged(osd::root/L"osd-layout.txt");damaged<<"5 1 0 0\n";
        for(int i=0;i<13;++i){const auto& e=osd::defaults[i];damaged<<e.x<<' '<<e.y<<' '<<e.size<<' '<<e.color<<' '<<e.visible<<'\n';}damaged<<".5 .5 24 99 1\n";damaged.close();
        osd::load();for(size_t i=0;i<preserved.size();++i){const auto& a=osd::items[i];const auto& b=preserved[i];assert(std::tie(a.x,a.y,a.size,a.color,a.visible)==std::tie(b.x,b.y,b.size,b.color,b.visible));}
        std::cout<<"PASS v4 layout migration appends ammo preserving13items; v5 ammo position/visibility/size/color round trip and atomic rejection\n";
    }
    {auto dc=CreateCompatibleDC(nullptr);BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);
        info.bmiHeader.biWidth=1600;info.bmiHeader.biHeight=-900;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;
        void* memory=nullptr;auto bitmap=CreateDIBSection(dc,&info,DIB_RGB_COLORS,&memory,nullptr,0);assert(bitmap&&memory);
        const auto old=SelectObject(dc,bitmap);auto* pixels=static_cast<DWORD*>(memory);const RECT area{0,0,1600,900};
        osd::items=osd::defaults;for(auto& item:osd::items)item.visible=false;
        osd::items[11]={.25,.30,48,1,true};osd::items[12]={.65,.70,36,2,true};osd::fontChoice=0;
        osd::data={};osd::data.active=true;osd::data.hpEnabled=osd::data.detectorEnabled=true;osd::data.hpPercent=86;osd::data.artifactDistance=28.9;
        std::fill(pixels,pixels+1600*900,0u);osd::draw(dc,area,false);GdiFlush();
        const auto hp=osd::bounds[11],detector=osd::bounds[12];
        assert(hp.right>hp.left&&detector.right>detector.left&&std::abs((hp.left+hp.right)/2-400)<=1&&std::abs((detector.top+detector.bottom)/2-630)<=1);
        assert(std::any_of(pixels,pixels+1600*900,[](DWORD v){return (v&0xffffff)==0x50ff6e;}));
        assert(std::any_of(pixels,pixels+1600*900,[](DWORD v){return (v&0xffffff)==0xffdc3c;}));
        osd::items[11].visible=false;osd::items[12].visible=false;std::fill(pixels,pixels+1600*900,0u);osd::draw(dc,area,false);GdiFlush();
        assert(IsRectEmpty(&osd::bounds[11])&&IsRectEmpty(&osd::bounds[12])&&std::all_of(pixels,pixels+1600*900,[](DWORD v){return v==0;}));
        osd::items[11].visible=osd::items[12].visible=true;osd::data.hpEnabled=osd::data.detectorEnabled=false;osd::draw(dc,area,false);
        assert(IsRectEmpty(&osd::bounds[11])&&IsRectEmpty(&osd::bounds[12]));
        osd::data.active=false;osd::draw(dc,area,true);assert(!IsRectEmpty(&osd::bounds[11])&&!IsRectEmpty(&osd::bounds[12]));
        osd::data.hpEnabled=osd::data.detectorEnabled=true;osd::data.signalLost=true;osd::draw(dc,area,false);
        assert(IsRectEmpty(&osd::bounds[11])&&IsRectEmpty(&osd::bounds[12]));
        for(auto& item:osd::items)item.visible=false;
        osd::items[13]={.4,.2,36,3,true};osd::data={};osd::data.active=true;osd::data.grenadeEnabled=true;
        for(const int count:{3,0,-1}){
            osd::data.grenadeRemaining=count;std::fill(pixels,pixels+1600*900,0u);osd::draw(dc,area,false);GdiFlush();
            const auto ammo=osd::bounds[13];assert(ammo.right>ammo.left&&ammo.bottom>ammo.top&&std::abs((ammo.left+ammo.right)/2-640)<=1&&std::abs((ammo.top+ammo.bottom)/2-180)<=1);
            assert(std::any_of(pixels,pixels+1600*900,[](DWORD v){return (v&0xffffff)==0x3ce1ff;}));
        }
        osd::items[13].visible=false;std::fill(pixels,pixels+1600*900,0u);osd::draw(dc,area,false);GdiFlush();
        assert(IsRectEmpty(&osd::bounds[13])&&std::all_of(pixels,pixels+1600*900,[](DWORD v){return v==0;}));
        osd::items[13].visible=true;osd::data.grenadeEnabled=false;osd::draw(dc,area,false);assert(IsRectEmpty(&osd::bounds[13]));
        osd::data.active=false;osd::draw(dc,area,true);assert(!IsRectEmpty(&osd::bounds[13]));
        osd::data.grenadeEnabled=true;osd::data.signalLost=true;osd::draw(dc,area,false);assert(IsRectEmpty(&osd::bounds[13]));
        osd::data.signalLost=false;osd::cursorMode=true;osd::draw(dc,area,false);assert(IsRectEmpty(&osd::bounds[13]));osd::cursorMode=false;
        std::cout<<"PASS rendered grenade count/zero/unlimited positions and selected colour, visibility, unarmed mode, video loss/menu hiding and editor sample\n";
        SelectObject(dc,old);DeleteObject(bitmap);DeleteDC(dc);osd::data={};osd::items=osd::defaults;
        std::cout<<"PASS rendered HP/detector positions, sizes, chosen colours, hide switches, disabled features, video loss and editor samples\n";}
    osd::root=fs::path(__FILE__).parent_path().parent_path()/L"mod";
    assert(osd::loadBetaflight());assert(osd::bitmapText(nullptr,L"SPD 123",0,0,36,0,false).cx==168);
    BITMAP b{};assert(GetObjectW(osd::glyphBitmap[0],sizeof(b),&b));const auto* pixels=static_cast<const DWORD*>(b.bmBits);int lit=0;
    for(int y=0;y<18;++y)for(int x=0;x<12;++x)if(pixels[((65/16)*18+y)*192+(65%16)*12+x]==0xffffff)++lit;
    assert(lit>0);
    wchar_t directory[32768]{};
    const auto count=GetEnvironmentVariableW(L"ZONEFPV_VISUAL_QA_DIR",directory,32768);
    if(count>0&&count<32768)exportVisualPreview(directory);
    osd::cleanup();std::cout<<"PASS actual Betaflight glyph decode\n";return 0;
}
