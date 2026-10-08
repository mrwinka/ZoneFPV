#define wmain bridgeMain
#include "input.cpp"
#undef wmain
#include <cassert>

namespace{
constexpr pdaSettings::Integer epoch=1700000000000ULL,session=1700000000000123ULL;
void file(const fs::path& path,const std::string& text){std::ofstream out(path,std::ios::binary|std::ios::trunc);out<<text;assert(out.good());}
std::string content(const fs::path& path){std::ifstream in(path,std::ios::binary);return {std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>()};}
struct Harness{
    pdaSettings::Bridge bridge;action_bindings::Sample sample;fs::path root;ULONGLONG now=1000;
    pdaSettings::Integer ownerSeq=1,requestId=1;int page=10;bool focus=true,open=true,mouseBlocked=false;
    explicit Harness(const wchar_t* name){
        root=fs::current_path()/name;fs::create_directories(root);
        assert(fs::absolute(root).parent_path()==fs::current_path());
        for(const auto& entry:fs::directory_iterator(root))if(entry.is_regular_file())fs::remove(entry.path());
        weatherMenu::root=root;osd::root=root;weatherMenu::objectLimitPath=root/L"Engine.ini";
        file(weatherMenu::objectLimitPath,"[Other]\nForeignSetting=keep\n");
        controllers::available={{17,L"RadioMaster Pocket — Пульт",{},1,0},{23,L"Joystick",{},2,0}};
        controllers::requested=controllers::active=17;weatherMenu::joystickConnected=true;
        sample.controller.device=17;sample.controller.backend=1;sample.controller.connected=true;sample.controller.axes.fill(32768);
        weatherMenu::bindingsLoaded=false;weatherMenu::bindingsDirty=false;weatherMenu::pending=0;weatherMenu::commands.clear();weatherMenu::nextCommandAttempt=0;
        weatherMenu::profileChoice=0;language::current=0;droneAudio::volume=1;weatherMenu::statusText.clear();
        weatherMenu::cancelBindingCapture();weatherMenu::resetCalibration(L"");osd::items=osd::defaults;osd::editing=false;
        for(const auto* entry:{L"pda-settings-request.txt",L"bindings.txt",L"action-modes.txt",L"osd-layout.txt",L"theme.txt"}){std::error_code error;fs::remove(root/entry,error);}
    }
    void owner(){file(root/L"pda-settings-owner.txt","1 "+std::to_string(session)+" "+std::to_string(ownerSeq)+" "+std::to_string(epoch)+" "+std::to_string(open)+" "+std::to_string(page)+" "+std::to_string(mouseBlocked)+" "+std::to_string(ownerSeq)+"\n");}
    void tick(ULONGLONG delay=20,bool heartbeat=true){now+=delay;sample.controller.timestamp=now;if(heartbeat){++ownerSeq;owner();}bridge.pump(root,sample,focus,now,epoch);assert(!weatherMenu::window.load()&&!osd::editor.load()&&!weatherMenu::visible());}
    void command(const std::string& kind,const std::string& args){++requestId;file(root/L"pda-settings-request.txt","1 "+std::to_string(session)+" "+std::to_string(requestId)+" "+std::to_string(epoch)+" "+std::to_string(page)+" "+kind+" "+args+" "+std::to_string(requestId)+"\n");tick();}
    bool ack(){tick(50);std::istringstream input(content(root/L"pda-settings-state.txt"));std::array<std::string,21> fields;for(auto& value:fields)assert(input>>value);assert(fields[4]==std::to_string(requestId));return fields[5]=="1";}
};
void parsing(){
    pdaSettings::Owner owner;assert(pdaSettings::parseOwner("1 12 3 1700000000000 1 10 0 3",owner));
    for(const auto* value:{"1 12 3 1700000000000 1 10 0 4","1 12 3 1700000000000 1 4 0 3","1 12 3 1700000000000 2 10 0 3","1 9007199254740992 3 1700000000000 1 10 0 3","1 12 03 1700000000000 1 10 0 3","1 12 3 1700000000000 1 10 2 3","1 12 3 1700000000000 1 10 3"})assert(!pdaSettings::parseOwner(value,owner));
    pdaSettings::Request request;assert(pdaSettings::parseRequest("1 12 3 1700000000000 9 modes 7 1 3",request));
    for(const auto* value:{"1 12 3 1700000000000 10 capture 1 3","1 12 3 1700000000000 9 capture 8 3","1 12 3 1700000000000 9 modes 1 2 3","1 12 3 1700000000000 10 audio 101 3","1 12 3 1700000000000 10 limit 0 3","1 12 3 1700000000000 10 theme 1 4","1 12 3 1700000000000 10 language -1 3","1 12 3 1700000000000 10 open 1 3","1 12 3 1700000000000 10 audio 25 3 extra"})assert(!pdaSettings::parseRequest(value,request));
    std::cout<<"PASS bounded strict owner/request, section allowlist, exact arity, integer overflow and unknown external-open rejection\n";
}
void preferences(){
    Harness h(L"headless-preferences");h.owner();file(h.root/L"pda-settings-request.txt","1 "+std::to_string(session)+" 1 "+std::to_string(epoch)+" 10 audio 9 1\n");
    const auto foreground=GetForegroundWindow();h.tick();assert(droneAudio::volume==1&&!fs::exists(h.root/L"audio-volume.txt"));
    h.command("audio","73");assert(h.ack()&&std::abs(droneAudio::volume-.73f)<1e-6);assert(content(h.root/L"audio-volume.txt")=="0.730000\n");
    file(h.root/L"pda-settings-request.txt","1 "+std::to_string(session)+" 1 "+std::to_string(epoch)+" 10 audio 9 1\n");h.tick();assert(std::abs(droneAudio::volume-.73f)<1e-6);
    h.command("language","2");assert(h.ack()&&language::current==2);h.command("theme","1");assert(h.ack()&&!uiTheme::dark);
    h.command("limit","1500000");assert(h.ack());auto limit=objectLimit::read(weatherMenu::enginePath());assert(limit.ok&&limit.hasValue&&limit.value==1500000&&content(weatherMenu::enginePath()).find("ForeignSetting=keep")!=std::string::npos);
    h.command("limitreset","0");assert(h.ack()&&!objectLimit::read(weatherMenu::enginePath()).hasValue);assert(content(weatherMenu::enginePath()).find("ForeignSetting=keep")!=std::string::npos);
    h.page=1;h.command("device","999");assert(!h.ack()&&controllers::requested==17);
    h.command("profile","2");assert(h.ack()&&weatherMenu::profileChoice==2&&content(h.root/L"calibration-17.lua").find("axis=5")!=std::string::npos);
    h.command("profile","3");assert(h.ack());bool backup=false;for(const auto& entry:fs::directory_iterator(h.root))if(entry.path().filename().wstring().find(L"before-default")!=std::wstring::npos)backup=true;assert(backup);
    h.command("device","23");assert(h.ack()&&controllers::requested==23&&content(h.root/L"controller.txt")=="23\n");
    h.command("profile","1");assert(!h.ack());assert(GetForegroundWindow()==foreground);
    std::cout<<"PASS cold request discarded, monotonic no replay, shared device/profile backups, actual saved language/theme/audio, foreign INI preserved; no HWND or foreground change\n";
}
void requestDiagnostics(){
    Harness h(L"headless-controller-diagnostics");h.page=1;h.tick();
    h.sample.controller.connected=false;weatherMenu::setStatus(L"Сохранено");h.command("profile","2");assert(!h.ack());
    auto packet=content(h.root/L"pda-settings-state.txt");assert(packet.find(pdaSettings::hex(L"! Контроллер не подключён. Подключите пульт в режиме USB Joystick."))!=std::string::npos&&!fs::exists(h.root/L"calibration-17.lua"));
    h.sample.controller.connected=true;controllers::requested=0;
    auto actualLive=h.sample.controller;actualLive.timestamp=GetTickCount64();controllers::publishLive(actualLive);
    h.sample=weatherMenu::sampleSettingsHardware();assert(h.sample.controller.connected&&h.sample.controller.device==17);
    h.command("profile","2");assert(h.ack()&&fs::exists(h.root/L"calibration-17.lua"));
    assert(content(h.root/L"pda-settings-state.txt").find("2120")==std::string::npos); // positive response has no error prefix
    h.command("calibrate","0");assert(h.ack()&&weatherMenu::calibrationDevice==17);h.tick();assert(weatherMenu::calibrationState==1);
    h.command("calibrate","1");assert(h.ack()&&!weatherMenu::calibrationState);
    controllers::requested=23;actualLive.timestamp=GetTickCount64();controllers::publishLive(actualLive);h.sample=weatherMenu::sampleSettingsHardware();assert(!h.sample.controller.connected);
    h.command("profile","1");assert(!h.ack()&&!fs::exists(h.root/L"calibration-23.lua"));
    packet=content(h.root/L"pda-settings-state.txt");assert(packet.find(pdaSettings::hex(L"! Выбранный пульт ещё не готов. Подождите или выберите подключённый."))!=std::string::npos);
    h.command("device","999");assert(!h.ack());packet=content(h.root/L"pda-settings-state.txt");assert(packet.find(pdaSettings::hex(L"! Выбранный контроллер недоступен. Обновите список устройств."))!=std::string::npos);
    std::cout<<"PASS current failed-ack ! marker and natural reasons, actual automatic hardware sample/profile/calibration, explicit switch suppresses old device and preserves profiles\n";
}
void interruptedOwner(){
    Harness h(L"headless-owner-interruption");h.page=9;h.tick();h.command("capture","1");assert(weatherMenu::capturing());
    file(h.root/L"pda-settings-owner.txt","1 ");h.sample.keys['U']=true;h.tick(20,false);assert(!h.bridge.eligible()&&weatherMenu::capturing()&&weatherMenu::bindingCodes[1]!='U');
    h.sample.keys['U']=false;h.tick();assert(weatherMenu::capturing());h.sample.keys['U']=true;h.tick();assert(weatherMenu::bindingCodes[1]=='U');
    h.sample.keys['U']=false;h.page=1;h.command("calibrate","0");assert(weatherMenu::calibrationState==1);
    file(h.root/L"pda-settings-owner.txt","1 ");++h.requestId;file(h.root/L"pda-settings-request.txt","1 "+std::to_string(session)+" "+std::to_string(h.requestId)+" "+std::to_string(epoch)+" 1 calibrate 0 "+std::to_string(h.requestId)+"\n");
    h.tick(20,false);assert(weatherMenu::calibrationState==1);h.tick();assert(h.ack()&&weatherMenu::calibrationState==2);
    file(h.root/L"pda-settings-owner.txt","1 ");h.tick(751,false);assert(!weatherMenu::calibrationState&&!h.bridge.blocking());
    h.command("capture","1"); // wrong section rejects without creating capture
    assert(!weatherMenu::capturing());h.page=9;h.command("capture","1");file(h.root/L"pda-settings-owner.txt","1 ");h.focus=false;h.tick(20,false);assert(!weatherMenu::capturing());
    std::cout<<"PASS interrupted owner suspends without consuming requests or losing calibration/capture; valid renewal resumes, 750ms lease and focus loss cancel\n";
}
void publicationRetry(){
    Harness h(L"headless-publication-retry");h.page=1;h.tick();
    file(h.root/L"environment.txt","prior packet\n");
    const auto locked=CreateFileW((h.root/L"environment.txt").c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);assert(locked!=INVALID_HANDLE_VALUE);
    h.command("profile","2");assert(h.ack()&&fs::exists(h.root/L"calibration-17.lua")&&weatherMenu::pending==0&&weatherMenu::commands.size()==1&&content(h.root/L"environment.txt")=="prior packet\n");
    weatherMenu::send("calibration 1");assert(weatherMenu::commands.size()==1);CloseHandle(locked);Sleep(60);weatherMenu::sendNext();
    assert(weatherMenu::commands.empty()&&weatherMenu::pending);const auto once=content(h.root/L"environment.txt");assert(once.find("calibration 1")!=std::string::npos);weatherMenu::sendNext();assert(content(h.root/L"environment.txt")==once);
    file(h.root/L"language.txt","0\n");const auto pref=CreateFileW((h.root/L"language.txt").c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);assert(pref!=INVALID_HANDLE_VALUE);
    h.page=10;h.command("language","2");assert(!h.ack()&&weatherMenu::preferenceError==ERROR_SUCCESS); // later state publication succeeds; failed value remains unchanged
    assert(content(h.root/L"language.txt")=="0\n"&&language::current==0&&content(h.root/L"pda-settings-state.txt").find(pdaSettings::hex(L"! Не удалось сохранить настройки. Повторите попытку."))!=std::string::npos);CloseHandle(pref);
    std::cout<<"PASS real Win32 sharing violation retains/coalesces calibration reload, exactly one retry publish; preference failure preserves prior value and returns marked failure\n";
}
void capture(){
    Harness h(L"headless-capture");h.page=9;h.owner();h.tick();
    for(int row=0;row<8;++row){h.command("clear",std::to_string(row));assert(h.ack());}
    for(int row=0;row<8;++row){h.command("capture",std::to_string(row));assert(weatherMenu::headlessCapture&&weatherMenu::captureRow==row);
        h.sample.keys[100+row]=true;h.tick();assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes[row]==static_cast<unsigned>(100+row));h.sample.keys[100+row]=false;h.tick();
        h.command("modes",std::to_string(row)+" 1");assert(h.ack()&&action_bindings::loadModes(h.root).values()[row]==1);
    }
    h.command("capture","4");h.sample.keys[VK_XBUTTON1]=true;h.tick();assert(weatherMenu::capturing());h.tick(200);assert(weatherMenu::bindingCodes[4]==VK_XBUTTON1);h.sample.keys[VK_XBUTTON1]=false;
    h.command("capture","5");h.sample.controller.buttonStates[127]=true;h.tick();assert(weatherMenu::bindingCodes[5]==1128);h.sample.controller.buttonStates[127]=false;
    h.command("capture","6");h.sample.controller.hats[3]=31500;h.tick();assert(weatherMenu::bindingCodes[6]==2032);h.sample.controller.hats[3]=JOY_POVCENTERED;
    h.command("capture","7");h.sample.controller.axes[7]=65535;h.tick();assert(weatherMenu::capturing());h.tick(61);assert(weatherMenu::bindingCodes[7]==3024&&!weatherMenu::capturing());
    h.command("capture","0");h.sample.keys[101]=true;h.tick();assert(weatherMenu::bindingCodes[0]==100);h.sample.keys[101]=false; // duplicate rejects without changing old binding
    h.command("capture","0");h.command("cancel","0");assert(!h.bridge.blocking()&&weatherMenu::bindingCodes[0]==100);
    h.command("capture","0");h.tick(15001);assert(!weatherMenu::capturing());
    for(const auto& queued:weatherMenu::commands)assert(queued=="bindingsreload 1"||queued=="actionmodesreload 1");
    assert(std::count(weatherMenu::commands.begin(),weatherMenu::commands.end(),"bindingsreload 1")<=1&&std::count(weatherMenu::commands.begin(),weatherMenu::commands.end(),"actionmodesreload 1")<=1);
    std::cout<<"PASS all eight headless captures/clear/modes, arbitrary VK/mouse, 128th button, fourth hat, CH8High debounce, duplicate/timeout/cancel preserves previous binding\n";
    std::cout<<"PASS bindings/modes are atomically saved before ack, bounded coalesced reload-only notifications contain no stale preference snapshots\n";
}
void cancellations(){
    Harness h(L"headless-cancel");h.page=9;h.owner();h.tick();h.command("capture","0");h.page=10;h.tick();assert(!weatherMenu::capturing());
    h.page=9;h.command("capture","0");h.focus=false;h.tick();assert(!h.bridge.eligible()&&!weatherMenu::capturing());h.focus=true;
    h.command("capture","0");h.open=false;h.tick();assert(!weatherMenu::capturing());h.open=true;
    h.command("capture","0");h.tick(751,false);assert(!h.bridge.eligible()&&!weatherMenu::capturing());
    h.command("capture","0");h.sample.controller.connected=false;h.tick();assert(!weatherMenu::capturing());h.sample.controller.connected=true;
    h.command("capture","0");h.sample.controller.backend=2;h.tick();assert(!weatherMenu::capturing());h.sample.controller.backend=1;
    h.command("capture","0");h.page=10;h.owner();h.tick(20,false);assert(!h.bridge.eligible()&&!weatherMenu::capturing()); // same-seq mutation
    ++h.requestId;file(h.root/L"pda-settings-request.txt","1 "+std::to_string(session)+" "+std::to_string(h.requestId)+" "+std::to_string(epoch)+" 10 audio 11 "+std::to_string(h.requestId)+"\n");
    h.open=false;h.tick();assert(std::abs(droneAudio::volume-1)<1e-6&&!h.ack());
    h.open=true;h.page=1;h.command("calibrate","0");assert(weatherMenu::calibrationState==1&&h.bridge.blocking());h.page=10;h.tick();assert(weatherMenu::calibrationState==0&&!h.bridge.blocking());
    h.page=1;h.command("calibrate","0");controllers::requested=23;h.tick();assert(weatherMenu::calibrationState==0&&!h.bridge.blocking()&&!fs::exists(h.root/L"calibration-23.lua"));
    std::cout<<"PASS owner/tab/section/focus/lease/disconnect/backend changes cancel before polling/commit; pending command cannot apply after close; same-seq owner mutation rejected\n";
}
void reservedMouse(){
    Harness h(L"headless-reserved-mouse");h.page=9;h.owner();h.tick();const auto old=weatherMenu::bindingCodes[0];
    h.command("capture","0");h.sample.keys[VK_LBUTTON]=true;h.tick();h.tick(199);assert(weatherMenu::bindingCodes[0]==old&&weatherMenu::capturing());
    h.command("cancel","0");assert(weatherMenu::bindingCodes[0]==old&&!weatherMenu::capturing());h.sample.keys[VK_LBUTTON]=false;
    h.command("capture","0");h.mouseBlocked=true;h.sample.keys[VK_LBUTTON]=true;h.tick();h.tick(1000);assert(weatherMenu::bindingCodes[0]==old&&weatherMenu::capturing());
    h.mouseBlocked=false;h.tick(300);assert(weatherMenu::bindingCodes[0]==old&&weatherMenu::capturing()); // leaving a reserved row while still holding cannot capture
    h.sample.keys[VK_LBUTTON]=false;h.tick();h.sample.keys[VK_LBUTTON]=true;h.tick();h.tick(200);assert(weatherMenu::bindingCodes[0]==VK_LBUTTON&&!weatherMenu::capturing());
    h.sample.keys[VK_LBUTTON]=false;h.command("capture","1");h.sample.keys[VK_RBUTTON]=true;h.tick();h.command("clear","1");h.tick(250);assert(weatherMenu::bindingCodes[1]==0&&!weatherMenu::capturing());
    h.sample.keys[VK_RBUTTON]=false;h.command("capture","1");h.sample.keys[VK_MBUTTON]=true;h.tick();h.page=10;h.tick(250);assert(weatherMenu::bindingCodes[1]==0);
    h.sample.keys[VK_MBUTTON]=false;h.page=9;h.command("capture","1");h.mouseBlocked=true;h.sample.keys['Z']=true;h.tick();assert(weatherMenu::bindingCodes[1]=='Z');
    std::cout<<"PASS 200ms headless mouse reservation lets Cancel/Clear/context win; reserved native hover blocks long LMB holds and release re-primes; genuine empty-content Mouse1 and keyboard remain assignable\n";
}
void calibration(){
    Harness h(L"headless-calibration");h.page=1;h.owner();h.tick();h.command("calibrate","0");assert(weatherMenu::calibrationState==1);
    for(int axis=0;axis<4;++axis){h.sample.controller.axes.fill(32768);h.command("calibrate","0");assert(weatherMenu::calibrationState==2);
        const auto prompt=weatherMenu::statusText;weatherMenu::setStatus(L"Команда передана игре.");h.tick(50);
        assert(content(h.root/L"pda-settings-state.txt").find(pdaSettings::hex(prompt))!=std::string::npos); // a prior environment reply cannot replace wizard instructions
        h.sample.controller.axes[axis]=0;h.tick(100);h.sample.controller.axes[axis]=65535;h.tick(3000);h.tick(3000);assert(weatherMenu::calibrationState==4);
        h.command("calibrate","0");assert(h.ack());assert(weatherMenu::calibrationState==(axis==3?0:3));
    }
    const auto saved=content(h.root/L"calibration-17.lua");for(int axis=1;axis<=4;++axis)assert(saved.find("axis="+std::to_string(axis))!=std::string::npos);
    assert(!h.bridge.blocking()&&saved.find("min=0,max=65535,center=32768")!=std::string::npos);
    h.command("calibrate","0");h.command("calibrate","1");assert(!h.bridge.blocking());
    h.command("calibrate","0");h.command("calibrate","0");h.tick(6001);h.command("calibrate","0");assert(!h.ack()&&!h.bridge.blocking());
    std::cout<<"PASS actual shared four-axis wizard, timed samples + direction confirmation, per-device calibrated file, cancel and insufficient-motion failure without external controls\n";
}
void osdAndState(){
    Harness h(L"headless-state");h.owner();h.tick();
    osd::items[4].visible=false;osd::downCrossVisible=false;osd::crossStyle=5;osd::downCrossStyle=3;osd::items[0].x=.27;assert(osd::save());
    osd::items=osd::defaults;osd::crossStyle=0;osd::downCrossStyle=4;osd::downCrossVisible=true;
    h.tick(251);assert(osd::items[0].x==.27&&osd::crossStyle==5&&osd::downCrossStyle==3&&!osd::downCrossVisible&&!osd::items[4].visible);
    const auto valid=content(h.root/L"osd-layout.txt");file(h.root/L"osd-layout.txt","7 1 0 0 4 1\n.9 .9");h.tick(251);assert(osd::items[0].x==.27&&osd::crossStyle==5);
    fs::remove(h.root/L"osd-layout.txt");h.tick(251);assert(osd::items[0].x==.27&&osd::crossStyle==5);file(h.root/L"osd-layout.txt",valid);h.tick(251);
    const auto luaLayout=content(fs::current_path()/L"pda-osd-layout.txt");assert(!luaLayout.empty());file(h.root/L"osd-layout.txt",luaLayout);h.tick(251);
    assert(!osd::enabled&&osd::fontChoice==7&&osd::crossStyle==5&&osd::downCrossStyle==4&&!osd::downCrossVisible);
    assert(osd::items[13].x==.12345678901234566&&osd::items[13].y==.9876543210123456&&osd::items[13].size==72&&osd::items[13].color==4&&!osd::items[13].visible);
    weatherMenu::bindingCodes={117,119,120,VK_XBUTTON1,1128,2032,3024,'Z'};weatherMenu::bindingsDirty=true;
    h.command("audio","42");h.tick(50);const auto state=content(h.root/L"pda-settings-state.txt");
    std::istringstream input(state);std::string line;std::getline(input,line);std::istringstream header(line);std::vector<std::string> fields;std::string value;while(header>>value)fields.push_back(value);assert(fields.size()==21&&fields[20]=="2");
    assert(state.find("D 17 1 526164696f4d617374657220506f636b6574")!=std::string::npos&&state.find("\nL ")!=std::string::npos&&state.find("\nB 117 119 120 5 1128 2032 3024 90\n")!=std::string::npos);
    file(fs::current_path()/L"pda-settings-state.txt",state);
    assert(!weatherMenu::window.load()&&!osd::editor.load());
    std::cout<<"PASS actual C++ 21-field state + UTF8 D/P/B/L/M/A/trailer fixture, valid external OSD applied, invalid/missing file retains last valid independent normal/down layout\n";
    std::cout<<"PASS actual Lua pda_osd.serialize v7 layout loaded through production poll with exact17-significant-digit positions, fourteen items and separate normal/down visibility/style\n";
}
void luaInterop(){
    const auto owner=content(fs::current_path()/L"pda-settings-owner.txt");const auto request=content(fs::current_path()/L"pda-settings-request.txt");
    assert(!owner.empty()&&!request.empty());
    Harness h(L"headless-lua-interop");h.bridge.pump(h.root,h.sample,true,h.now,epoch); // cold start before Lua emits fresh commands
    file(h.root/L"pda-settings-owner.txt",owner);file(h.root/L"pda-settings-request.txt",request);
    h.tick(50,false);h.tick(50,false);assert(language::current==2&&content(h.root/L"language.txt")=="2\n");
    const auto state=content(h.root/L"pda-settings-state.txt");std::istringstream input(state);std::array<std::string,21> fields;for(auto& value:fields)assert(input>>value);
    assert(fields[3]==std::to_string(session)&&fields[4]=="123"&&fields[5]=="1"&&fields[20]=="2");
    file(fs::current_path()/L"pda-settings-state.txt",state);
    std::cout<<"PASS actual Lua owner/request emitted by pda_settings.lua parsed and dispatched headlessly; resulting actual C++ state fixture acknowledges123 language2\n";
}
}
int main(){parsing();preferences();requestDiagnostics();interruptedOwner();publicationRetry();capture();cancellations();reservedMouse();calibration();osdAndState();luaInterop();std::cout<<"PASS headless PDA settings bridge with F6/editor never created or activated\n";}
