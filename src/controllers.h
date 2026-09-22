#pragma once
#define DIRECTINPUT_VERSION 0x0800
#include <dinput.h>
#include <Xinput.h>
#include <mutex>
#pragma comment(lib,"dinput8.lib")
#pragma comment(lib,"dxguid.lib")
#pragma comment(lib,"xinput.lib")
namespace controllers {
struct Device { unsigned id; std::wstring name; GUID guid{}; int kind; DWORD product=0; };
inline std::mutex mutex;
inline std::vector<Device> available;
inline std::atomic<unsigned> requested{0},active{0};
inline IDirectInput8W* api=nullptr;
inline IDirectInputDevice8W* handle=nullptr;
inline unsigned opened=0;
inline DWORD extraAxes[2]{};
inline unsigned key(const GUID& g){unsigned h=2166136261u;const auto* p=reinterpret_cast<const unsigned char*>(&g);for(int i=0;i<16;++i)h=(h^p[i])*16777619u;return 1000+(h%2000000000u);}
inline BOOL CALLBACK enumerate(const DIDEVICEINSTANCEW* d,void* context){auto& out=*static_cast<std::vector<Device>*>(context);out.push_back({key(d->guidInstance),d->tszInstanceName,d->guidInstance,1,d->guidProduct.Data1});return DIENUM_CONTINUE;}
inline void scan(){
    if(!api)DirectInput8Create(GetModuleHandleW(nullptr),DIRECTINPUT_VERSION,IID_IDirectInput8W,reinterpret_cast<void**>(&api),nullptr);
    std::vector<Device> found;
    IDirectInput8W* enumerator=nullptr;
    if(SUCCEEDED(DirectInput8Create(GetModuleHandleW(nullptr),DIRECTINPUT_VERSION,IID_IDirectInput8W,reinterpret_cast<void**>(&enumerator),nullptr))){enumerator->EnumDevices(DI8DEVCLASS_GAMECTRL,enumerate,&found,DIEDFL_ATTACHEDONLY);enumerator->Release();}
    for(unsigned i=0;i<4;++i){XINPUT_STATE s{};if(XInputGetState(i,&s)==ERROR_SUCCESS)found.insert(found.begin(),{100+i,L"Xbox / XInput #"+std::to_wstring(i+1),{},2});}
    // Keep the original WinMM path available for existing radio calibration.
    for(UINT i=0;i<joyGetNumDevs();++i){JOYCAPSW c{};JOYINFOEX j{};j.dwSize=sizeof(j);j.dwFlags=JOY_RETURNALL;if(joyGetDevCapsW(i,&c,sizeof(c))==JOYERR_NOERROR&&joyGetPosEx(i,&j)==JOYERR_NOERROR)found.push_back({i+1,std::wstring(c.szPname)+L" [WinMM]",{},0});}
    std::lock_guard<std::mutex> lock(mutex);available=std::move(found);
}
inline bool read(unsigned id,JOYINFOEX& j){
    Device d{};{std::lock_guard<std::mutex> lock(mutex);auto it=std::find_if(available.begin(),available.end(),[&](const Device& x){return x.id==id;});if(it==available.end())return false;d=*it;}
    extraAxes[0]=extraAxes[1]=0;
    j={};j.dwSize=sizeof(j);j.dwFlags=JOY_RETURNALL;
    if(d.kind==0)return joyGetPosEx(id-1,&j)==JOYERR_NOERROR;
    if(d.kind==2){XINPUT_STATE s{};if(XInputGetState(id-100,&s)!=ERROR_SUCCESS)return false;const auto& g=s.Gamepad;j.dwXpos=static_cast<DWORD>(g.sThumbRX+32768);j.dwYpos=static_cast<DWORD>(g.sThumbRY+32768);j.dwZpos=static_cast<DWORD>(g.sThumbLY+32768);j.dwRpos=static_cast<DWORD>(g.sThumbLX+32768);j.dwUpos=g.bLeftTrigger*257u;j.dwVpos=g.bRightTrigger*257u;j.dwButtons=g.wButtons;return true;}
    if(opened!=id){if(handle){handle->Unacquire();handle->Release();handle=nullptr;}opened=0;
        if(!api||FAILED(api->CreateDevice(d.guid,&handle,nullptr)))return false;
        if(FAILED(handle->SetDataFormat(&c_dfDIJoystick))||FAILED(handle->SetCooperativeLevel(GetDesktopWindow(),DISCL_BACKGROUND|DISCL_NONEXCLUSIVE))){handle->Release();handle=nullptr;return false;}
        DIPROPRANGE range{};range.diph.dwSize=sizeof(range);range.diph.dwHeaderSize=sizeof(range.diph);range.diph.dwHow=DIPH_DEVICE;range.lMin=0;range.lMax=65535;handle->SetProperty(DIPROP_RANGE,&range.diph);opened=id;
    }
    DIJOYSTATE s{};handle->Poll();auto hr=handle->GetDeviceState(sizeof(s),&s);if(FAILED(hr)){handle->Acquire();handle->Poll();hr=handle->GetDeviceState(sizeof(s),&s);}if(FAILED(hr)){opened=0;return false;}
    extraAxes[0]=static_cast<DWORD>(std::clamp(s.rglSlider[0],0L,65535L));extraAxes[1]=static_cast<DWORD>(std::clamp(s.rglSlider[1],0L,65535L));
    j.dwXpos=static_cast<DWORD>(std::clamp(s.lX,0L,65535L));j.dwYpos=static_cast<DWORD>(std::clamp(s.lY,0L,65535L));j.dwZpos=static_cast<DWORD>(std::clamp(s.lZ,0L,65535L));j.dwRpos=static_cast<DWORD>(std::clamp(s.lRz,0L,65535L));j.dwUpos=static_cast<DWORD>(std::clamp(s.lRx,0L,65535L));j.dwVpos=static_cast<DWORD>(std::clamp(s.lRy,0L,65535L));for(int i=0;i<32;++i)if(s.rgbButtons[i]&0x80)j.dwButtons|=1u<<i;return true;
}
inline void cleanup(){if(handle){handle->Unacquire();handle->Release();}if(api)api->Release();}
}
