#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <mmsystem.h>
namespace binding_test {
inline unsigned legacyEnumerationCalls=0;
inline UINT WINAPI legacyDeviceCount(){++legacyEnumerationCalls;return 0;}
}
#define joyGetNumDevs ::binding_test::legacyDeviceCount
#include "action_bindings.h"
#undef joyGetNumDevs
#include <cstdlib>
#include <iostream>
#include <sstream>

namespace {
using namespace action_bindings;
void require(bool value,const char* message){if(!value){std::cerr<<"FAIL "<<message<<'\n';std::exit(1);}}
bool any(const std::array<bool,actionCount>& edges){return std::any_of(edges.begin(),edges.end(),[](bool value){return value;});}
Sample sample(ULONGLONG now){
    Sample value;value.controller.device=1234;value.controller.backend=1;
    value.controller.connected=true;value.controller.timestamp=now;value.controller.axes.fill(32768);return value;
}
void stamp(Sample& value,ULONGLONG now){value.controller.timestamp=now;}
void discovery(){
    binding_test::legacyEnumerationCalls=0;
    controllers::scan();
    require(binding_test::legacyEnumerationCalls==0,"runtime discovery never enters the legacy WinMM enumeration API");
    controllers::scan(true);
    require(binding_test::legacyEnumerationCalls==1,"legacy WinMM enumeration requires explicit opt-in");
    controllers::cleanup();
}
void parsing(){
    Bindings output=defaults();
    {std::istringstream input("117 119 120\n");require(parse(input,output)&&output==defaults(),"legacy three actions retain default collect disabled");}
    {std::istringstream input("0 1128 2032 3024\n");require(parse(input,output)&&output==Bindings{0,1128,2032,3024},"all controller endpoints parse in decimal");}
    {std::istringstream input("0 0 0 0");require(parse(input,output),"disabled bindings may repeat");}
    {std::istringstream input("117 119 120 1 3001");require(parse(input,output)&&output[4]==3001,"fifth flashlight binding accepts controller CH");}
    {std::istringstream input("117 119 120 1 3001 1128 2032");require(parse(input,output)&&output==Bindings{117,119,120,1,3001,1128,2032},"seven bindings retain every legacy slot and append camera/drop");}
    {std::istringstream input("117 119 120 1 3001 1128 2032 255");require(parse(input,output)&&output[7]==255,"eighth vision binding preserves seven existing slots");}
    Modes modes;
    {std::istringstream input("1 1 0");require(parseModes(input,modes)&&modes.cameraDown==1&&modes.vision==0&&modes.flashlight==0,"two-mode legacy defaults flashlight to toggle");}
    {std::istringstream input("1 0 1 1");require(parseModes(input,modes)&&modes.cameraDown==0&&modes.vision==1&&modes.flashlight==1,"all three hold modes parse");}
    {std::istringstream input("2 1 0 1 0 1 0 1 1");require(parseModes(input,modes)&&modes.values()==(std::array<int,8>{1,0,1,0,1,0,1,1}),"all eight v2 modes preserve action order");}
    {std::istringstream input("1 0 1 1");require(parseModes(input,modes)&&modes.menu==0&&modes.pilot==0&&modes.reset==0&&modes.collect==0&&modes.grenadeDrop==0&&modes.cameraDown==0&&modes.vision==1&&modes.flashlight==1,"legacy v1 maps only original three holds");}
    for(const auto* invalidMode:{"", "1 0", "2 0 0", "1 2 0", "1 0 01", "1 0 0 -1", "1 0 0 0 extra", "2 0 0 0 0 0 0 0", "2 0 0 0 0 0 0 0 0 extra", "2 0 0 0 0 0 0 0 2", "2 0 0 0 0 0 0 0 01"}){std::istringstream input(invalidMode);require(!parseModes(input,modes)&&modes.vision==1&&modes.flashlight==1,"malformed modes reject atomically");}
    for(const auto* invalid:{"", "117 119", "117 119 120 0 1 2", "117 119 120 0 1 2 3 4 5", "117 119 120 0 119", "117 117 120", "-1 119 120", "+1 119 120", "0x75 119 120", "117.0 119 120", "117 119 120 junk", "256 119 120", "1000 119 120", "1129 119 120", "2000 119 120", "2033 119 120", "3000 119 120", "3025 119 120", "999999999999999999999999 119 120", "01 2 3 4", "00 119 120", "0117 0119 0120 03001"}){
        const auto previous=output;std::istringstream input(invalid);
        require(!parse(input,output)&&output==previous,"malformed bindings fail atomically without changing preferences");
    }
    const auto root=std::filesystem::temp_directory_path()/(L"ZoneFPV-bindings-test-"+std::to_wstring(GetCurrentProcessId()));
    std::filesystem::create_directories(root);
    {std::ofstream file(root/L"bindings.txt");file<<"117 119 120";}
    require(load(root)==defaults(),"legacy file load");
    {std::ofstream file(root/L"bindings.txt");file<<"117 117 120";}
    require(load(root)==defaults(),"invalid saved duplicate file keeps defaults");
    {std::ifstream file(root/L"bindings.txt");std::string text;std::getline(file,text);require(text=="117 117 120","load leaves invalid preference bytes untouched");}
    {std::ofstream file(root/L"bindings.txt");file<<"0117 0119 0120 03001";}
    require(load(root)==defaults(),"zero-padded saved codes use the same defaults as the Lua parser");
    {std::ifstream file(root/L"bindings.txt");std::string text;std::getline(file,text);require(text=="0117 0119 0120 03001","rejected padded preference bytes remain untouched");}
    require(label(1128)==L"Button 128"&&label(3024)==L"CH8 High"&&label(2032)==L"Hat 4 ↖", "human readable full-range controls");
    require(!label(VK_F6).empty()&&!label(VK_LBUTTON).empty()&&!label(0).empty(),"keyboard mouse and disabled labels");
    std::filesystem::remove(root/L"bindings.txt");std::filesystem::remove(root);
}
void backend(){
    DIJOYSTATE2 raw{};JOYINFOEX legacy{};controllers::LiveState live;
    raw.lX=-200;raw.lY=70000;raw.lZ=12345;raw.lRz=54321;raw.lRx=100;raw.lRy=200;
    raw.rglSlider[0]=40000;raw.rglSlider[1]=50000;
    for(auto& hat:raw.rgdwPOV)hat=JOY_POVCENTERED;
    raw.rgdwPOV[2]=31500;raw.rgdwPOV[3]=9000;
    raw.rgbButtons[0]=0x80;raw.rgbButtons[31]=0x80;raw.rgbButtons[32]=0x80;raw.rgbButtons[127]=0x80;
    controllers::directInputState(raw,legacy,live);
    require(legacy.dwButtons==0x80000001u,"DIJOYSTATE2 legacy first32 mask unchanged");
    require(live.buttonStates[0]&&live.buttonStates[31]&&live.buttonStates[32]&&live.buttonStates[127]&&!live.buttonStates[126],"all128 DirectInput buttons retained");
    require(live.hats[2]==31500&&live.hats[3]==9000,"all four DirectInput hats retained");
    require(legacy.dwXpos==0&&legacy.dwYpos==65535&&legacy.dwRpos==54321&&legacy.dwUpos==100&&legacy.dwVpos==200,
        "DirectInput axes clamp with existing public channel mapping");
    require(controllers::extraAxes[0]==40000&&controllers::extraAxes[1]==50000,"CH7/8 slider axes retained");
    DIJOYSTATE old{};old.rgbButtons[31]=0x80;old.lRz=999;
    controllers::directInputState(old,legacy);
    require(legacy.dwButtons==0x80000000u&&legacy.dwRpos==999,"legacy DIJOYSTATE overload retained");
    XINPUT_GAMEPAD xbox{};xbox.wButtons=XINPUT_GAMEPAD_DPAD_UP|XINPUT_GAMEPAD_DPAD_RIGHT|XINPUT_GAMEPAD_A;
    controllers::xinputState(xbox,legacy);
    require(legacy.dwButtons==xbox.wButtons&&legacy.dwPOV==4500,"XInput existing bit mapping and diagonal hat retained");
    live.connected=true;live.device=1234;live.timestamp=GetTickCount64();live.buttons=0xffffffffu;live.axes.fill(65535);controllers::publishLive(live);
    {std::lock_guard<std::mutex> lock(controllers::mutex);controllers::available.clear();}
    require(!controllers::read(9999,legacy),"missing device disconnects without touching hardware");
    const auto cleared=controllers::live();
    require(!cleared.connected&&cleared.timestamp==0&&cleared.buttons==0&&legacy.dwButtons==0,
        "disconnect clears legacy state and freshness");
    require(std::none_of(cleared.buttonStates.begin(),cleared.buttonStates.end(),[](bool value){return value;})
        &&std::all_of(cleared.hats.begin(),cleared.hats.end(),[](DWORD value){return value==JOY_POVCENTERED;}),"disconnect clears all128 buttons and four hats");
    controllers::publishLive(live);controllers::requested=4321;controllers::active=1234;
    require(!sampleHardware().controller.connected,"new selected controller cannot use previous live backend");
    controllers::cleanup();
}
void capture(){
    Capture capture;auto input=sample(1000);input.keys[VK_LBUTTON]=true;input.controller.buttonStates[127]=true;
    capture.begin(input,1000);require(capture.active()&&capture.poll(input,1001)==0,"opening mouse click and initial held button ignored");
    input.keys[VK_LBUTTON]=false;input.controller.buttonStates[127]=false;stamp(input,1002);require(capture.poll(input,1002)==0,"release arms initial held controls");
    input.controller.buttonStates[127]=true;stamp(input,1003);require(capture.poll(input,1003)==1128&&!capture.active(),"button128 captures after genuine release press");
    input=sample(1100);capture.begin(input,1100);input.keys[VK_CONTROL]=true;input.keys[VK_RCONTROL]=true;
    require(capture.poll(input,1101)==VK_RCONTROL,"capture prefers physical right modifier over generic Control");
    input=sample(1200);capture.begin(input,1200);input.keys[VK_XBUTTON2]=true;
    require(capture.poll(input,1201)==VK_XBUTTON2,"mouse auxiliary key captured");
    input=sample(1300);input.controller.hats[3]=0;capture.begin(input,1300);
    input.controller.hats[3]=31500;stamp(input,1301);require(capture.poll(input,1301)==0,"initial held hat ignored until neutral");
    input.controller.hats[3]=JOY_POVCENTERED;stamp(input,1302);capture.poll(input,1302);
    input.controller.hats[3]=31500;stamp(input,1303);require(capture.poll(input,1303)==2032,"fourth hat northwest captures");
    input=sample(1400);capture.begin(input,1400);input.controller.connected=false;capture.poll(input,1401);
    input.controller.connected=true;input.controller.buttonStates[127]=true;stamp(input,1402);
    require(capture.poll(input,1402)==0,"reconnect-held button primes capture without binding");
    input.controller.buttonStates[127]=false;stamp(input,1403);capture.poll(input,1403);
    input.controller.buttonStates[127]=true;stamp(input,1404);require(capture.poll(input,1404)==1128,"fresh post-reconnect edge captures");
    input=sample(1500);capture.begin(input,1500);input.controller.device=4321;input.controller.backend=0;input.controller.buttonStates[0]=true;stamp(input,1501);
    require(capture.poll(input,1501)==0,"backend and selected device changes adopt held baseline");
    capture.cancel();require(!capture.active()&&capture.poll(input,1502)==0,"UI cancellation stops capture");
    for(size_t axis=0;axis<8;++axis){
        input=sample(2000);capture.begin(input,2000);
        input.controller.axes[axis]=33000;stamp(input,2001);require(capture.poll(input,2001)==0,"small CH center jitter cannot capture");
        input.controller.axes[axis]=65535;stamp(input,2002);require(capture.poll(input,2002)==0,"CH candidate waits for stable position");
        stamp(input,2050);require(capture.poll(input,2050)==0,"CH stable period not prematurely accepted");
        stamp(input,2063);require(capture.poll(input,2063)==static_cast<unsigned>(3003+axis*3),"all eight CH high positions capture after60ms");
    }
    input=sample(2200);input.controller.axes[3]=65535;capture.begin(input,2200);
    input.controller.axes[3]=32768;stamp(input,2201);capture.poll(input,2201);stamp(input,2262);
    require(capture.poll(input,2262)==3011,"CH center captured from a different switch position");
    input=sample(2300);capture.begin(input,2300);input.controller.axes[0]=0;stamp(input,2301);capture.poll(input,2301);
    input.controller.axes[0]=32768;stamp(input,2340);capture.poll(input,2340);input.controller.axes[0]=0;stamp(input,2350);capture.poll(input,2350);
    stamp(input,2390);require(capture.poll(input,2390)==0,"leaving candidate restarts stability interval");
    stamp(input,2411);require(capture.poll(input,2411)==3001,"stable CH low captures");
    input=sample(2500);capture.begin(input,2500);input.controller.buttonStates[0]=true;
    require(capture.poll(input,2800)==0,"stale connected snapshot cannot capture controller action");
    stamp(input,2801);require(capture.poll(input,2801)==0,"fresh after stale adopts baseline");
}
void runtime(){
    RuntimeActions actions;auto input=sample(3000);auto bindings=defaults();input.keys[117]=true;
    require(!any(actions.poll(bindings,input,true,false,false,3000)),"startup held key is latched");
    input.keys[117]=false;actions.poll(bindings,input,true,false,false,3001);
    input.keys[117]=true;require(actions.poll(bindings,input,true,false,false,3002)[0],"fresh menu keyboard edge");
    require(!any(actions.poll(bindings,input,true,false,false,3003)),"held keyboard never repeats");
    actions.poll(bindings,input,false,false,false,3004);input.keys[117]=false;actions.poll(bindings,input,false,false,false,3005);
    input.keys[117]=true;require(!any(actions.poll(bindings,input,true,false,false,3006)),"focus return held key primes without action");
    input.keys.fill(false);actions.poll(bindings,input,true,false,false,3007);
    input.keys[119]=true;require(actions.poll(bindings,input,true,false,false,3008)[1],"pilot enabled only in game focus");
    actions.poll(bindings,input,false,true,false,3009);input.keys[119]=false;actions.poll(bindings,input,false,true,false,3010);
    input.keys[119]=true;input.keys[117]=true;
    const auto ownMenu=actions.poll(bindings,input,false,true,false,3011);
    require(ownMenu[0]&&!ownMenu[1],"own menu allows menu action but blocks game actions");
    input.keys.fill(false);actions.poll(bindings,input,true,false,true,3012);input.keys[119]=true;actions.poll(bindings,input,true,false,true,3013);
    require(!any(actions.poll(bindings,input,true,false,false,3014)),"capture unblock held key primes without executing");
    bindings[1]=VK_RBUTTON;input.keys[VK_RBUTTON]=true;
    require(!any(actions.poll(bindings,input,true,false,false,3015)),"new binding suppresses captured held source");
    input.keys[VK_RBUTTON]=false;actions.poll(bindings,input,true,false,false,3016);input.keys[VK_RBUTTON]=true;
    require(actions.poll(bindings,input,true,false,false,3017)[1],"new binding works after release");
    RuntimeActions controllerActions;bindings={0,1128,2032,3024};input=sample(4000);
    input.controller.buttonStates[127]=true;input.controller.hats[3]=31500;
    require(!any(controllerActions.poll(bindings,input,true,false,false,4000)),"startup held full-range controller controls are latched");
    input.controller.connected=false;controllerActions.poll(bindings,input,true,false,false,4001);
    input.controller.connected=true;stamp(input,4002);require(!any(controllerActions.poll(bindings,input,true,false,false,4002)),"reconnect held button and hat never execute");
    input.controller.buttonStates[127]=false;input.controller.hats[3]=JOY_POVCENTERED;stamp(input,4003);controllerActions.poll(bindings,input,true,false,false,4003);
    input.controller.buttonStates[127]=true;input.controller.hats[3]=31500;input.controller.axes[7]=65535;stamp(input,4004);
    const auto buttons=controllerActions.poll(bindings,input,true,false,false,4004);require(buttons[1]&&buttons[2]&&!buttons[3],"button128 and fourth hat route with stable CH deferred");
    stamp(input,4065);const auto axis=controllerActions.poll(bindings,input,true,false,false,4065);require(axis[3]&&!axis[1]&&!axis[2],"CH8 high action executes after stable entry once");
    stamp(input,4100);require(!any(controllerActions.poll(bindings,input,true,false,false,4100)),"held controller button hat and CH never repeat");
    input.controller.backend=0;stamp(input,4101);require(!any(controllerActions.poll(bindings,input,true,false,false,4101)),"same device different backend primes held state");
    require(!any(controllerActions.poll(bindings,input,true,false,false,4400)),"stale controller data cannot execute");
    stamp(input,4401);require(!any(controllerActions.poll(bindings,input,true,false,false,4401)),"freshness recovery primes held controller controls");
    RuntimeActions noisy;bindings={0,3001,0,0};input=sample(5000);input.controller.axes[0]=16001;
    noisy.poll(bindings,input,true,false,false,5000);
    for(unsigned tick=1;tick<=20;++tick){input.controller.axes[0]=(tick%2)?15999:16001;stamp(input,5000+tick*20);require(!any(noisy.poll(bindings,input,true,false,false,5000+tick*20)),"tiny threshold noise cannot trigger CH action");}
    input.controller.axes[0]=0;stamp(input,5500);noisy.poll(bindings,input,true,false,false,5500);stamp(input,5561);
    require(noisy.poll(bindings,input,true,false,false,5561)[1],"meaningful stable low switch entry triggers");
    for(unsigned tick=1;tick<=20;++tick){input.controller.axes[0]=(tick%2)?15999:16001;stamp(input,5561+tick*20);require(!any(noisy.poll(bindings,input,true,false,false,5561+tick*20)),"hysteresis prevents held edge-boundary repeats");}
    input.controller.axes[0]=32768;stamp(input,6000);noisy.poll(bindings,input,true,false,false,6000);
    input.controller.axes[0]=0;stamp(input,6001);noisy.poll(bindings,input,true,false,false,6001);stamp(input,6062);
    require(noisy.poll(bindings,input,true,false,false,6062)[1],"CH low rearmed after meaningful release and stable reentry");
    RuntimeActions flashlight;bindings={117,119,120,0,1001};input=sample(7000);
    flashlight.poll(bindings,input,true,false,false,7000);
    input.controller.buttonStates[0]=true;stamp(input,7001);
    require(flashlight.poll(bindings,input,true,false,false,7001)[4],"fifth flashlight action dispatches controller edge");
    stamp(input,7002);require(!any(flashlight.poll(bindings,input,true,false,false,7002)),"held flashlight never repeats");
    flashlight.poll(bindings,input,false,true,false,7003);input.controller.buttonStates[0]=false;stamp(input,7004);
    flashlight.poll(bindings,input,false,true,false,7004);input.controller.buttonStates[0]=true;stamp(input,7005);
    require(!any(flashlight.poll(bindings,input,false,true,false,7005)),"flashlight is blocked inside menu");
    RuntimeActions combat;bindings={117,119,120,0,0,'C',1128};input=sample(8000);
    input.keys['C']=true;input.controller.buttonStates[127]=true;
    require(!any(combat.poll(bindings,input,true,false,false,8000)),"new camera/drop actions ignore initial held controls");
    input.keys['C']=false;input.controller.buttonStates[127]=false;stamp(input,8001);combat.poll(bindings,input,true,false,false,8001);
    input.keys['C']=true;input.controller.buttonStates[127]=true;stamp(input,8002);
    auto edges=combat.poll(bindings,input,true,false,false,8002);require(edges[5]&&edges[6]&&!edges[4],"camera keyboard and grenade button128 use their independent appended actions");
    stamp(input,8003);require(!any(combat.poll(bindings,input,true,false,false,8003)),"held camera/drop actions never repeat");
    combat.poll(bindings,input,true,true,false,8004);input.keys['C']=false;input.controller.buttonStates[127]=false;stamp(input,8005);combat.poll(bindings,input,true,true,false,8005);
    input.keys['C']=true;input.controller.buttonStates[127]=true;stamp(input,8006);require(!any(combat.poll(bindings,input,true,true,false,8006)),"new armament actions are blocked while F6 is visible");
    stamp(input,8007);require(!any(combat.poll(bindings,input,true,false,false,8007)),"closing menu with camera/drop controls held does not execute actions");
    input.keys['C']=false;input.controller.buttonStates[127]=false;stamp(input,8008);combat.poll(bindings,input,true,false,false,8008);
    input.keys['C']=true;input.controller.buttonStates[127]=true;stamp(input,8009);edges=combat.poll(bindings,input,true,false,false,8009);
    require(edges[5]&&edges[6],"camera/drop rearm after release and genuine new press");
}
void hold(){
    RuntimeActions state;Bindings bindings={117,119,120,0,1001,'C',0,3024};auto input=sample(9000);
    input.keys['C']=true;input.controller.buttonStates[0]=true;input.controller.axes[7]=65535;
    state.poll(bindings,input,true,false,false,9000);require(!any(state.held()),"startup-held camera flashlight CH vision are inactive");
    input.keys['C']=false;input.controller.buttonStates[0]=false;input.controller.axes[7]=32768;stamp(input,9001);state.poll(bindings,input,true,false,false,9001);
    input.keys['C']=true;input.controller.buttonStates[0]=true;input.controller.axes[7]=65535;stamp(input,9002);
    auto edges=state.poll(bindings,input,true,false,false,9002);require(edges[4]&&edges[5]&&!edges[7]&&state.held()[4]&&state.held()[5]&&!state.held()[7],"digital holds activate instantly and CH awaits stability");
    stamp(input,9063);edges=state.poll(bindings,input,true,false,false,9063);require(edges[7]&&state.held()[7],"stable CH8 high activates selected-vision hold");
    stamp(input,9064);require(!any(state.poll(bindings,input,true,false,false,9064))&&state.held()[4]&&state.held()[5]&&state.held()[7],"held state persists independently of one-shot counters");
    state.poll(bindings,input,false,false,false,9065);require(!any(state.held()),"focus loss releases all holds");
    stamp(input,9066);state.poll(bindings,input,true,false,false,9066);require(!any(state.held()),"held focus regain cannot activate");
    input.keys['C']=false;input.controller.buttonStates[0]=false;input.controller.axes[7]=32768;stamp(input,9067);state.poll(bindings,input,true,false,false,9067);
    input.keys['C']=true;input.controller.buttonStates[0]=true;input.controller.axes[7]=65535;stamp(input,9068);state.poll(bindings,input,true,false,false,9068);stamp(input,9130);state.poll(bindings,input,true,false,false,9130);
    input.controller.connected=false;state.poll(bindings,input,true,false,false,9131);require(!state.held()[4]&&!state.held()[7]&&state.held()[5],"controller disconnect releases controller holds without cancelling keyboard hold");
    input.controller.connected=true;stamp(input,9132);state.poll(bindings,input,true,false,false,9132);require(!state.held()[4]&&!state.held()[7],"reconnect held controller primes inactive");
    state.poll(bindings,input,true,true,false,9133);require(!any(state.held()),"menu releases all holds");
    state.poll(bindings,input,true,false,true,9134);require(!any(state.held()),"capture blocks holds");
    bindings[5]='V';input.keys['V']=true;stamp(input,9135);state.poll(bindings,input,true,false,false,9135);require(!any(state.held()),"rebinding while held requires release");
    input.keys['V']=false;stamp(input,9136);state.poll(bindings,input,true,false,false,9136);input.keys['V']=true;stamp(input,9137);state.poll(bindings,input,true,false,false,9137);require(state.held()[5],"rebound control activates after real new press");
    input.keys['V']=false;stamp(input,9138);state.poll(bindings,input,true,false,false,9138);require(!any(state.held()),"release clears camera hold in the same sample");
    RuntimeActions all;bindings={65,66,67,68,69,70,71,72};input={};
    all.poll(bindings,input,true,false,false,10000);
    for(const auto code:bindings)input.keys[code]=true;
    edges=all.poll(bindings,input,true,false,false,10001);require(std::all_of(edges.begin(),edges.end(),[](bool v){return v;})&&std::all_of(all.held().begin(),all.held().end(),[](bool v){return v;}),"all eight hold bits activate after fresh presses");
    all.poll(bindings,input,false,true,false,10002);require(all.held()[0]&&std::count(all.held().begin(),all.held().end(),true)==1,"menu focus handoff preserves only menu hold");
    all.poll(bindings,input,false,false,false,10003);require(!any(all.held()),"foreign focus releases menu and all actions");
    all.poll(bindings,input,true,false,false,10004);require(!any(all.held()),"all initial held controls re-prime after focus return");
    for(const auto code:bindings)input.keys[code]=false;all.poll(bindings,input,true,false,false,10005);
    for(const auto code:bindings)input.keys[code]=true;all.poll(bindings,input,true,false,false,10006);require(std::count(all.held().begin(),all.held().end(),true)==8,"release and new press rearm every action");
    all.poll(bindings,input,true,false,true,10007);require(!any(all.held()),"capture releases all eight holds");

}
void delayedHolds(){
    const Bindings configured={117,119,120,0,1001,3018,1002,'V'};
    const auto established=[&](){RuntimeActions actions;auto input=sample(20000);actions.poll(configured,input,true,false,false,20000);
        input.controller.axes[5]=65535;input.controller.buttonStates[0]=true;stamp(input,20001);auto edges=actions.poll(configured,input,true,false,false,20001);require(edges[4]&&!edges[5],"fresh button edge and CH debounce precede delay");
        stamp(input,20062);edges=actions.poll(configured,input,true,false,false,20062);require(edges[5]&&actions.held()[4]&&actions.held()[5],"actual CH6High camera hold is established");return std::make_pair(actions,input);};
    auto pair=established();auto& actions=pair.first;auto& input=pair.second;
    require(!any(actions.poll(configured,input,true,false,false,20312))&&actions.held()[5],"age250 remains fresh");
    input.controller.buttonStates[1]=true;input.keys['V']=true;
    auto edges=actions.poll(configured,input,true,false,false,20313);
    require(edges[7]&&!edges[6]&&actions.held()[4]&&actions.held()[5]&&actions.held()[7],"age251 preserves established controller holds, rejects stale new presses and keeps keyboard fresh");
    require(!any(actions.poll(configured,input,true,false,false,20712))&&actions.held()[4]&&actions.held()[5],"age650 retains CH mask without generating another edge");
    input.controller.buttonStates[1]=false;stamp(input,20713);
    require(!any(actions.poll(configured,input,true,false,false,20713))&&actions.held()[5],"same fresh device continues held CH without reprime or pulse");
    input.controller.axes[5]=32768;input.controller.buttonStates[0]=false;stamp(input,20714);
    require(!any(actions.poll(configured,input,true,false,false,20714))&&!actions.held()[4]&&!actions.held()[5],"fresh physical release ends preserved holds immediately");
    pair=established();require(!any(actions.poll(configured,input,true,false,false,20812))&&actions.held()[5],"age750 is the fixed last allowed delayed frame");
    require(!any(actions.poll(configured,input,true,false,false,20813))&&!actions.held()[4]&&!actions.held()[5],"age751 ends grace without extending deadline on polling");
    stamp(input,20814);require(!any(actions.poll(configured,input,true,false,false,20814))&&!actions.held()[5],"expired grace requires release and fresh press after reconnect");
    for(int reason=0;reason<6;++reason){pair=established();auto changed=configured;
        if(reason==0)input.controller.connected=false;
        if(reason==1)++input.controller.device;
        if(reason==2)input.controller.backend=0;
        if(reason==3)changed[4]=1003;
        actions.poll(changed,input,reason!=4,reason==5,false,20400);
        require(!actions.held()[5]&&!actions.held()[4],"disconnect/device/backend/rebinding/focus/menu changes cancel delayed controller holds");
        input.controller.connected=true;stamp(input,20401);actions.poll(changed,input,true,false,false,20401);
        require(!actions.held()[5],"cancelled delayed CH cannot resurrect from fresh held source");
    }
    pair=established();actions.poll(configured,input,true,false,true,20400);require(!actions.held()[5],"capture cancels grace");
    stamp(input,20401);actions.poll(configured,input,true,false,false,20401);require(!actions.held()[5],"capture release primes depressed CH");
    RuntimeActions cold;input=sample(30000);input.controller.axes[5]=65535;input.controller.buttonStates[0]=true;
    cold.poll(configured,input,true,false,false,30000);cold.poll(configured,input,true,false,false,30650);
    require(!any(cold.held()),"startup-held sources never gain delayed grace activation");
    stamp(input,30651);require(!any(cold.poll(configured,input,true,false,false,30651))&&!any(cold.held()),"startup-held sources remain inactive after fresh same-device return");
    std::cout<<"PASS bounded established-controller Hold grace at250/650/750ms, no stale edges, fresh physical release, safe750ms expiry/disconnect/identity/focus/menu/capture/rebind priming and live keyboard\n";
}
}
int main(){parsing();discovery();backend();capture();runtime();hold();delayedHolds();std::cout<<"PASS strict legacy/eight-action bindings and debounced hold/release leases, safe runtime discovery,128-button DI backend, capture edges/stability/reconnect, camera/grenade action slots and runtime focus/hysteresis\n";}
