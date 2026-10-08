#define wmain bridgeMain
#include "input.cpp"
#undef wmain
#include <cstdlib>
#include <initializer_list>
#include <iterator>

namespace {
void require(bool condition,const char* message){
    if(!condition){std::cerr<<"FAIL "<<message<<"\n";std::exit(1);}
}
void snapshot(std::initializer_list<controllers::Device> devices){
    std::lock_guard<std::mutex> lock(controllers::mutex);
    controllers::available=devices;
}
void expectSelection(unsigned expected,const char* message){
    const auto selected=controllers::selectAvailable();
    require(selected==expected&&controllers::requested.load()==expected,message);
}
std::string contents(const fs::path& path){
    std::ifstream file(path,std::ios::binary);
    require(static_cast<bool>(file),"saved controller preference remains readable");
    return std::string(std::istreambuf_iterator<char>(file),std::istreambuf_iterator<char>());
}
}

int main(){
    require(controllers::ensureDeviceWindow(),"create process-owned DirectInput window");
    DWORD owner=0;GetWindowThreadProcessId(controllers::deviceWindow,&owner);
    require(owner==GetCurrentProcessId()&&GetAncestor(controllers::deviceWindow,GA_ROOT)==controllers::deviceWindow,
        "DirectInput cooperative window is top-level and belongs to reader process");
    require(!IsWindowVisible(controllers::deviceWindow),"DirectInput window remains hidden");
    constexpr unsigned savedId=123456789u,newId=234567891u;
    const controllers::Device radio{newId,L"Radio [DirectInput]",{},1};
    const controllers::Device xbox{100u,L"Xbox [XInput]",{},2};
    const controllers::Device legacy{1u,L"Radio [WinMM]",{},0};
    const auto root=fs::temp_directory_path()/(L"ZoneFPV-hotplug-test-"+
        std::to_wstring(GetCurrentProcessId())+L"-"+std::to_wstring(GetTickCount64()));
    require(fs::create_directory(root),"create isolated preference directory");
    const auto preference=root/L"controller.txt";
    const auto savedText=std::to_string(savedId)+"\n";
    {std::ofstream file(preference,std::ios::binary);file<<savedText;require(static_cast<bool>(file),"write saved preference");}
    weatherMenu::root=root;
    controllers::requested=savedId;

    // A bridge started before USB attachment must keep retrying discovery even
    // when a previously saved controller ID is unavailable.
    snapshot({});
    expectSelection(savedId,"empty startup preserves saved request");
    JOYINFOEX state{};state.dwButtons=1;state.dwPOV=0;
    require(!controllers::read(savedId,state),"missing startup device is disconnected");
    require(state.dwButtons==0&&state.dwPOV==JOY_POVCENTERED,"missing device clears stale controls");
    snapshot({radio});
    expectSelection(newId,"late attachment replaces unavailable saved ID");
    expectSelection(newId,"attached controller remains selected on the next input tick");
    require(contents(preference)==savedText,"automatic attachment does not overwrite preference");

    snapshot({});
    expectSelection(newId,"unplug with no alternatives preserves current request");
    require(!controllers::read(newId,state),"unplugged controller reports disconnected");
    snapshot({radio});
    expectSelection(newId,"same controller reconnects without restarting bridge");

    // Adding an earlier backend must not override a controller the user chose.
    snapshot({xbox,radio,legacy});
    expectSelection(newId,"XInput discovery does not override available DirectInput choice");
    controllers::requested=legacy.id;
    expectSelection(legacy.id,"explicit WinMM choice survives earlier backends");
    controllers::requested=radio.id;
    expectSelection(radio.id,"explicit DirectInput choice is honored");

    snapshot({xbox});
    expectSelection(xbox.id,"disconnect selects remaining attached controller");
    snapshot({radio,xbox});
    expectSelection(xbox.id,"returning earlier device does not steal active selection");
    controllers::requested=radio.id;
    expectSelection(radio.id,"user can reselect returning device");
    require(contents(preference)==savedText,"selection fallback preserves saved preference bytes");

    controllers::requested=0;
    snapshot({});
    expectSelection(0,"fresh startup without controllers remains unselected");
    snapshot({legacy,radio});
    expectSelection(legacy.id,"fresh late attachment follows first discovered device");

    const auto ownedWindow=controllers::deviceWindow;
    snapshot({});controllers::requested=0;controllers::cleanup();
    require(!IsWindow(ownedWindow)&&!controllers::deviceWindow,"cleanup destroys owned DirectInput window");
    require(fs::remove(preference)&&fs::remove(root),"remove isolated preference fixture");
    std::cout<<"PASS late USB attachment, unplug/reconnect, explicit backend selection and saved preference preservation\n";
}
