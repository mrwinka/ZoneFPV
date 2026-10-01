#pragma once
namespace controllerProfiles {
inline std::mutex mutex;
struct Profile {std::array<int,4> axes;std::array<bool,4> invert;};
// Order: right horizontal, right vertical, left vertical, left horizontal.
inline const Profile presets[]={
    {{1,2,3,4},{false,false,false,false}}, // XInput Mode 2 / USB AETR
    {{1,2,3,5},{false,false,false,false}}, // observed Pocket DirectInput
    {{1,2,3,6},{false,false,false,false}}, // observed Pocket WinMM
    {{3,4,2,1},{false,true,true,false}},
    {{1,2,3,5},{false,false,false,false}}, // EdgeTX/OpenTX AETR DirectInput
    {{2,3,1,5},{false,false,false,false}}, // TAER DirectInput
    {{1,2,3,4},{false,false,false,false}}, // AETR sequential USB
    {{2,3,1,4},{false,false,false,false}}, // TAER sequential USB
    {{1,3,2,5},{false,false,false,false}}, // Mode 1 AETR DirectInput
    {{3,4,2,1},{false,true,true,false}}    // DualShock 4: Z/Rz right stick, Y/X left stick
};
inline int detect(unsigned id){
    std::lock_guard<std::mutex> lock(controllers::mutex);
    for(const auto& d:controllers::available)if(d.id==id){
        if(d.kind==2)return 0;
        if(d.kind==1&&controllers::dualShock4(d.product))return 9;
        if(d.kind==1&&(d.product&0xffff)==0x054c)return 3;
        auto name=d.name;for(auto& c:name)c=static_cast<wchar_t>(towlower(c));
        if(name.find(L"radiomaster pocket")!=std::wstring::npos)return d.kind==0?2:1;
    }
    for(const auto& d:controllers::available)if(d.id==id){
        auto name=d.name;for(auto& c:name)c=static_cast<wchar_t>(towlower(c));
        if(d.kind==1&&name.find(L"dualshock")!=std::wstring::npos)return 9;
        if(d.kind==1&&name.find(L"dualsense")!=std::wstring::npos)return 3;
        for(auto brand:{L"radiomaster",L"jumper",L"frsky",L"tbs",L"edgetx",L"opentx",L"betafpv"})if(name.find(brand)!=std::wstring::npos)return d.kind==1?4:6;
        if(name.find(L"flysky")!=std::wstring::npos||name.find(L"fly sky")!=std::wstring::npos)return d.kind==1?5:7;
    }
    return -1;
}
inline bool write(const fs::path& root,unsigned id,int preset,bool replace){
    if(!id||preset<0||preset>=static_cast<int>(std::size(presets)))return false;
    std::lock_guard<std::mutex> lock(mutex);
    const auto path=root/("calibration-"+std::to_string(id)+".lua");
    std::error_code ec;const bool exists=fs::exists(path,ec);if(ec)return false;
    if(exists&&!replace)return true;
    if(exists){fs::copy_file(path,fs::path(path.wstring()+L".before-default-"+std::to_wstring(GetTickCount64())),ec);if(ec)return false;}
    const auto temp=fs::path(path.wstring()+L".tmp");std::ofstream f(temp);
    f<<"-- Initial Mode 2 profile; manual calibration overrides it.\nreturn {\n";
    const auto& p=presets[preset];const char* names[]={"roll","pitch","throttle","yaw"};
    for(int i=0;i<4;++i)f<<names[i]<<"={axis="<<p.axes[i]<<",min=0,max=65535,center=32768,invert="<<(p.invert[i]?"true":"false")<<"},\n";
    f<<"}\n";f.close();return f&&MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);
}
inline void ensure(const fs::path& root,unsigned id){const int preset=detect(id);if(preset>=0)write(root,id,preset,false);}
}
