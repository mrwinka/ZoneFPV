#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <mmsystem.h>
#define DIRECTINPUT_VERSION 0x0800
#include <dinput.h>
#include <Xinput.h>
#include <algorithm>
#include <atomic>
#include <mutex>
#include <array>
#include <string>
#include <vector>
#pragma comment(lib,"dinput8.lib")
#pragma comment(lib,"dxguid.lib")
#pragma comment(lib,"xinput.lib")
namespace controllers {
struct Device { unsigned id; std::wstring name; GUID guid{}; int kind; DWORD product=0; };
inline std::mutex mutex;
inline std::vector<Device> available;
inline std::atomic<unsigned> requested{0},active{0};
inline unsigned selectAvailable(){
    auto selected=requested.load();
    std::lock_guard<std::mutex> lock(mutex);
    if(!available.empty()&&std::none_of(available.begin(),available.end(),[&](const Device& d){return d.id==selected;})){
        // A saved or unplugged ID must not block a controller attached later.
        // Preserve a simultaneous explicit menu selection and leave the saved
        // preference file alone when using an automatic fallback.
        requested.compare_exchange_strong(selected,available.front().id);
    }
    return requested.load();
}
inline IDirectInput8W* api=nullptr;
inline IDirectInputDevice8W* handle=nullptr;
inline unsigned opened=0;
inline HWND deviceWindow=nullptr;
inline bool ensureDeviceWindow(){
    if(!deviceWindow)deviceWindow=CreateWindowExW(0,L"STATIC",L"ZoneFPV DirectInput",WS_POPUP,0,0,0,0,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);
    return deviceWindow!=nullptr;
}
inline void closeDevice(){if(handle){handle->Unacquire();handle->Release();handle=nullptr;}opened=0;}
inline DWORD extraAxes[2]{};
struct LiveState {
    unsigned device=0;int backend=-1;bool connected=false;DWORD buttons=0;
    std::array<bool,128> buttonStates{};
    std::array<DWORD,4> hats{JOY_POVCENTERED,JOY_POVCENTERED,JOY_POVCENTERED,JOY_POVCENTERED};
    std::array<DWORD,8> axes{};
    ULONGLONG timestamp=0;
};
inline std::mutex liveMutex;
inline LiveState liveState;
inline void publishLive(const LiveState& state){std::lock_guard<std::mutex> lock(liveMutex);liveState=state;}
inline LiveState live(){std::lock_guard<std::mutex> lock(liveMutex);return liveState;}
inline DWORD dpadPov(WORD buttons){
    const int x=((buttons&XINPUT_GAMEPAD_DPAD_RIGHT)?1:0)-((buttons&XINPUT_GAMEPAD_DPAD_LEFT)?1:0);
    const int y=((buttons&XINPUT_GAMEPAD_DPAD_DOWN)?1:0)-((buttons&XINPUT_GAMEPAD_DPAD_UP)?1:0);
    if(!x&&!y)return JOY_POVCENTERED;
    if(y<0)return x<0?31500u:x>0?4500u:0u;
    if(y>0)return x<0?22500u:x>0?13500u:18000u;
    return x<0?27000u:9000u;
}
inline void xinputState(const XINPUT_GAMEPAD& g,JOYINFOEX& j){
    j.dwXpos=static_cast<DWORD>(g.sThumbRX+32768);j.dwYpos=static_cast<DWORD>(g.sThumbRY+32768);
    j.dwZpos=static_cast<DWORD>(g.sThumbLY+32768);j.dwRpos=static_cast<DWORD>(g.sThumbLX+32768);
    j.dwUpos=g.bLeftTrigger*257u;j.dwVpos=g.bRightTrigger*257u;j.dwButtons=g.wButtons;j.dwPOV=dpadPov(g.wButtons);
}
template<class State> inline void directInputAxes(const State& s,JOYINFOEX& j){
    extraAxes[0]=static_cast<DWORD>(std::clamp(s.rglSlider[0],0L,65535L));extraAxes[1]=static_cast<DWORD>(std::clamp(s.rglSlider[1],0L,65535L));
    j.dwXpos=static_cast<DWORD>(std::clamp(s.lX,0L,65535L));j.dwYpos=static_cast<DWORD>(std::clamp(s.lY,0L,65535L));
    j.dwZpos=static_cast<DWORD>(std::clamp(s.lZ,0L,65535L));j.dwRpos=static_cast<DWORD>(std::clamp(s.lRz,0L,65535L));
    j.dwUpos=static_cast<DWORD>(std::clamp(s.lRx,0L,65535L));j.dwVpos=static_cast<DWORD>(std::clamp(s.lRy,0L,65535L));
    j.dwButtons=0;for(int i=0;i<32;++i)if(s.rgbButtons[i]&0x80)j.dwButtons|=1u<<i;
    j.dwPOV=s.rgdwPOV[0];
}
inline void directInputState(const DIJOYSTATE& s,JOYINFOEX& j){directInputAxes(s,j);}
inline void directInputState(const DIJOYSTATE2& s,JOYINFOEX& j){directInputAxes(s,j);}
inline void directInputState(const DIJOYSTATE2& s,JOYINFOEX& j,LiveState& state){
    directInputAxes(s,j);
    for(size_t i=0;i<state.buttonStates.size();++i)state.buttonStates[i]=(s.rgbButtons[i]&0x80)!=0;
    for(size_t i=0;i<state.hats.size();++i)state.hats[i]=s.rgdwPOV[i];
}
inline unsigned key(const GUID& g){unsigned h=2166136261u;const auto* p=reinterpret_cast<const unsigned char*>(&g);for(int i=0;i<16;++i)h=(h^p[i])*16777619u;return 1000+(h%2000000000u);}
inline bool dualShock4(DWORD product){
    if((product&0xffff)!=0x054c)return false;
    const DWORD pid=product>>16;return pid==0x05c4||pid==0x09cc||pid==0x0ba0;
}
inline BOOL CALLBACK enumerate(const DIDEVICEINSTANCEW* d,void* context){
    auto& out=*static_cast<std::vector<Device>*>(context);
    const auto name=dualShock4(d->guidProduct.Data1)?L"DualShock 4 [DirectInput] - "+std::wstring(d->tszInstanceName):std::wstring(d->tszInstanceName);
    out.push_back({key(d->guidInstance),name,d->guidInstance,1,d->guidProduct.Data1});return DIENUM_CONTINUE;
}
inline void scan(bool includeLegacy=false){
    std::vector<Device> found;
    IDirectInput8W* enumerator=nullptr;
    if(SUCCEEDED(DirectInput8Create(GetModuleHandleW(nullptr),DIRECTINPUT_VERSION,IID_IDirectInput8W,reinterpret_cast<void**>(&enumerator),nullptr))){enumerator->EnumDevices(DI8DEVCLASS_GAMECTRL,enumerate,&found,DIEDFL_ATTACHEDONLY);enumerator->Release();}
    for(unsigned i=0;i<4;++i){XINPUT_STATE s{};if(XInputGetState(i,&s)==ERROR_SUCCESS)found.insert(found.begin(),{100+i,L"Xbox / XInput #"+std::to_wstring(i+1),{},2});}
    // Repeated WinMM enumeration can fail inside the legacy driver shim even
    // when DirectInput discovery succeeds. Keep that path explicitly opt-in;
    // normal hotplug discovery uses DirectInput and XInput device identities.
    if(includeLegacy)for(UINT i=0;i<joyGetNumDevs();++i){JOYCAPSW c{};JOYINFOEX j{};j.dwSize=sizeof(j);j.dwFlags=JOY_RETURNALL;if(joyGetDevCapsW(i,&c,sizeof(c))==JOYERR_NOERROR&&joyGetPosEx(i,&j)==JOYERR_NOERROR)found.push_back({i+1,std::wstring(c.szPname)+L" [WinMM]",{},0});}
    std::lock_guard<std::mutex> lock(mutex);available=std::move(found);
}
inline bool readDevice(const Device& d,JOYINFOEX& j,LiveState& state){
    const auto id=d.id;
    if(d.kind==0)return joyGetPosEx(id-1,&j)==JOYERR_NOERROR;
    if(d.kind==2){XINPUT_STATE s{};if(XInputGetState(id-100,&s)!=ERROR_SUCCESS)return false;xinputState(s.Gamepad,j);return true;}
    // The reader thread owns its DirectInput API/device. Enumeration uses its
    // own API, so USB rescans cannot modify a live device from another thread.
    if(!api&&FAILED(DirectInput8Create(GetModuleHandleW(nullptr),DIRECTINPUT_VERSION,IID_IDirectInput8W,reinterpret_cast<void**>(&api),nullptr)))return false;
    if(opened!=id){closeDevice();
        if(!api||FAILED(api->CreateDevice(d.guid,&handle,nullptr)))return false;
        // DirectInput requires a top-level window owned by this process.
        // It remains hidden and lives on the reader thread with the device.
        if(!ensureDeviceWindow()||FAILED(handle->SetDataFormat(&c_dfDIJoystick2))||FAILED(handle->SetCooperativeLevel(deviceWindow,DISCL_BACKGROUND|DISCL_NONEXCLUSIVE))){closeDevice();return false;}
        DIPROPRANGE range{};range.diph.dwSize=sizeof(range);range.diph.dwHeaderSize=sizeof(range.diph);range.diph.dwHow=DIPH_DEVICE;range.lMin=0;range.lMax=65535;handle->SetProperty(DIPROP_RANGE,&range.diph);opened=id;
        handle->Acquire();
    }
    DIJOYSTATE2 s{};handle->Poll();auto hr=handle->GetDeviceState(sizeof(s),&s);if(FAILED(hr)){handle->Acquire();handle->Poll();hr=handle->GetDeviceState(sizeof(s),&s);}if(FAILED(hr)){closeDevice();return false;}
    directInputState(s,j,state);return true;
}
inline bool read(unsigned id,JOYINFOEX& j){
    extraAxes[0]=extraAxes[1]=0;j={};j.dwSize=sizeof(j);j.dwFlags=JOY_RETURNALL;j.dwPOV=JOY_POVCENTERED;
    LiveState state;state.device=id;Device d{};bool found=false;
    {std::lock_guard<std::mutex> lock(mutex);auto it=std::find_if(available.begin(),available.end(),[&](const Device& x){return x.id==id;});if(it!=available.end()){d=*it;found=true;}}
    // Only the reader thread touches this handle; USB enumeration stays on
    // its own thread and cannot release a device while it is being polled.
    if(!found||d.kind!=1)closeDevice();
    if(found){state.backend=d.kind;state.connected=readDevice(d,j,state);}
    if(state.connected){
        state.buttons=j.dwButtons;state.hats[0]=j.dwPOV;
        if(d.kind!=1)for(size_t i=0;i<32;++i)state.buttonStates[i]=(j.dwButtons&(1u<<i))!=0;
        state.axes={j.dwXpos,j.dwYpos,j.dwZpos,j.dwRpos,j.dwUpos,j.dwVpos,extraAxes[0],extraAxes[1]};
        state.timestamp=GetTickCount64();
    }else{j={};j.dwSize=sizeof(j);j.dwFlags=JOY_RETURNALL;j.dwPOV=JOY_POVCENTERED;extraAxes[0]=extraAxes[1]=0;}
    publishLive(state);return state.connected;
}
inline void cleanup(){closeDevice();if(api){api->Release();api=nullptr;}if(deviceWindow){DestroyWindow(deviceWindow);deviceWindow=nullptr;}publishLive({});}
}
