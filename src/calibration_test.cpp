#define wmain bridgeMain
#include "input.cpp"
#undef wmain
#include <cassert>
int main(){
    const auto root=fs::temp_directory_path()/(L"ZoneFPV-calibration-test-"+std::to_wstring(GetCurrentProcessId()));fs::create_directories(root);
    controllers::available={{100,L"Xbox",{},2},{1234,L"Radiomaster Pocket Joystick",{},1},{2345,L"Unknown USB",{},1}};
    assert(controllerProfiles::detect(100)==0);assert(controllerProfiles::detect(1234)==1);assert(controllerProfiles::detect(2345)==-1);
    controllers::available.push_back({3456,L"Wireless Controller",{},1,0x0ce6054c});assert(controllerProfiles::detect(3456)==3);
    for(DWORD product:{0x05c4054cu,0x09cc054cu,0x0ba0054cu}){
        assert(controllers::dualShock4(product));
        controllers::available.push_back({product,L"Wireless Controller",{},1,product});
        assert(controllerProfiles::detect(product)==9);
    }
    assert(!controllers::dualShock4(0x0ce6054c));assert(!controllers::dualShock4(0x05c41234));
    const auto& ds4=controllerProfiles::presets[9];
    assert((ds4.axes==std::array<int,4>{3,4,2,1}));assert((ds4.invert==std::array<bool,4>{false,true,true,false}));
    controllers::available.push_back({3457,L"Jumper T-Lite",{},1});assert(controllerProfiles::detect(3457)==4);
    controllers::available.push_back({3458,L"FlySky USB",{},1});assert(controllerProfiles::detect(3458)==5);
    for(int preset=0;preset<10;++preset){assert(controllerProfiles::write(root,5000+preset,preset,false));std::array<bool,9> used{};for(int axis:controllerProfiles::presets[preset].axes){assert(axis>=1&&axis<=8&&!used[axis]);used[axis]=true;}}
    std::cout<<"PASS DS4 revisions/adapter, Sony VID, radio detection and ten valid preset files\n";
    controllerProfiles::ensure(root,2345);assert(!fs::exists(root/L"calibration-2345.lua"));
    controllerProfiles::ensure(root,1234);assert(fs::exists(root/L"calibration-1234.lua"));
    {std::ifstream f(root/L"calibration-1234.lua");std::string s((std::istreambuf_iterator<char>(f)),{});assert(s.find("yaw={axis=5")!=std::string::npos);}
    {std::ofstream f(root/L"calibration-1234.lua");f<<"custom";}
    controllerProfiles::ensure(root,1234);{std::ifstream f(root/L"calibration-1234.lua");std::string s;f>>s;assert(s=="custom");}
    assert(controllerProfiles::write(root,1234,1,true));bool backup=false;for(const auto& entry:fs::directory_iterator(root))if(entry.path().filename().wstring().find(L"before-default")!=std::wstring::npos)backup=true;assert(backup);
    std::cout<<"PASS profile detection, mapping, preservation and backup\n";
    weatherMenu::root=root;controllers::active=1234;
    weatherMenu::calibrationUsed.fill(false);weatherMenu::calibrationControl=0;
    for(int i=0;i<4;++i){
        const int axis=controllerProfiles::presets[1].axes[i]-1;
        weatherMenu::calibrationCenter.fill(32768);weatherMenu::calibrationLow.fill(32768);weatherMenu::calibrationHigh.fill(32768);weatherMenu::calibrationLast.fill(32768);
        weatherMenu::calibrationLow[axis]=0;weatherMenu::calibrationHigh[axis]=65535;
        weatherMenu::requestDirection();assert(weatherMenu::calibrationState==4);
        weatherMenu::finishAxisSample();assert(weatherMenu::calibrationState==4&&weatherMenu::calibrationControl==i); // centered confirmation must not reset progress
        weatherMenu::calibrationLast[axis]=65535;weatherMenu::finishAxisSample();
        assert(weatherMenu::calibrationState==(i==3?0:3));
    }
    {std::ifstream f(root/L"calibration-1234.lua");std::string s((std::istreambuf_iterator<char>(f)),{});assert(s.find("yaw={axis=5")!=std::string::npos);}
    std::cout<<"PASS four-step stick wizard and explicit direction confirmation\n";
    return 0;
}
