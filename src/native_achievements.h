#pragma once
// Installed AchievementManager.cpp uses one private mod predicate in its
// initialization and two achievement-warning paths. Preserve the original
// predicate for every other caller; normal tracking and Steam APIs are intact.
#include <intrin.h>
namespace {
constexpr std::uintptr_t achievementPredicateRva=0x3797b68;
constexpr std::array<std::uintptr_t,3> achievementReturns{{0x3797b26,0x37cc6c3,0x6cf033a}};
constexpr unsigned char achievementPredicateProof[]={0x56,0x48,0x83,0xec,0x20,0xe8,0x60,0xb4,0x85,0xfd,0x48,0x89,0xc1,0xe8,0x0e,0x2f,0x1e,0xfd,0x48,0x85,0xc0,0x74,0x2f,0x48,0x89,0xc6,0x8b,0x40,0x08,0x0f,0xba,0xe0};
constexpr unsigned char achievementInitProof[]={0x56,0x48,0x83,0xec,0x20,0x48,0x89,0xce,0xe8,0xd5,0x7b,0x4b,0xfd,0xe8,0x42,0x00,0x00,0x00,0x84,0xc0,0x75,0x14,0xc6,0x86,0x31,0x01,0x00,0x00,0x01,0x48,0x89,0xf1};
constexpr unsigned char achievementProgressProof[]={0x80,0xb9,0x31,0x01,0x00,0x00,0x00,0x0f,0x84,0x3a,0x01,0x00,0x00};
constexpr unsigned char achievementWarningProof[]={0xe8,0xa5,0xb4,0xfc,0xff,0x8b,0x8b,0x90,0x00};
constexpr unsigned char achievementStartupWarningProof[]={0xe8,0x2e,0x78,0xaa,0xfc,0x84,0xc0,0x0f,0x84,0x81,0x00,0x00,0x00};
constexpr unsigned char achievementBaseGuardProof[]={0x80,0xb9,0x30,0x01,0x00,0x00,0x00,0x0f,0x85,0xf3,0x03,0x00,0x00};
constexpr unsigned char achievementConstructorProof[]={0x48,0x8d,0x05,0xf2,0xa6,0x5d,0x05,0x48,0x89,0x06};
constexpr unsigned char achievementArrayProof[]={0x56,0x53,0x48,0x83,0xec,0x28,0x44,0x89,0xc3,0x89,0xce,0x89,0x15,0x23,0x2e,0xfb,0x06,0x31,0xc0,0x85,0xd2,0x0f,0x9f,0xc0};
constexpr unsigned char achievementSingletonProof[]={0x48,0x89,0x35,0x6c,0x68,0xbf,0x06};
using AchievementPredicate=bool(__fastcall*)();
using AchievementInitializeManager=void(__fastcall*)(void*);
AchievementPredicate originalAchievementPredicate=nullptr;
AchievementInitializeManager achievementInitializeManager=nullptr;
std::atomic<std::uintptr_t> achievementImage{0};
INIT_ONCE achievementInitialized=INIT_ONCE_STATIC_INIT;
bool achievementReady=false;
unsigned achievementError=0;

bool achievementCaller(std::uintptr_t address,std::uintptr_t image) {
    if (!image || address<image || address-image>=gameImageSize) return false;
    for (const auto rva:achievementReturns) if (address-image==rva) return true;
    return false;
}
__declspec(noinline) bool __fastcall achievementPredicateHook() {
    const auto caller=reinterpret_cast<std::uintptr_t>(_ReturnAddress());
    if (achievementCaller(caller,achievementImage.load(std::memory_order_acquire))) return false;
    return originalAchievementPredicate();
}
bool achievementProfileBytes(const unsigned char* image) {
    std::uintptr_t init=0;
    return image && bytesMatch(image,achievementPredicateRva,achievementPredicateProof,sizeof(achievementPredicateProof)) &&
        bytesMatch(image,0x3797b14,achievementInitProof,sizeof(achievementInitProof)) &&
        bytesMatch(image,0x2e7ba64,achievementProgressProof,sizeof(achievementProgressProof)) &&
        bytesMatch(image,0x37cc6be,achievementWarningProof,sizeof(achievementWarningProof)) &&
        bytesMatch(image,0x6cf0335,achievementStartupWarningProof,sizeof(achievementStartupWarningProof)) &&
        bytesMatch(image,0xc4f730,achievementBaseGuardProof,sizeof(achievementBaseGuardProof)) &&
        bytesMatch(image,0x35e4297,achievementConstructorProof,sizeof(achievementConstructorProof)) &&
        bytesMatch(image,0x3133a94,achievementArrayProof,sizeof(achievementArrayProof)) &&
        bytesMatch(image,0x36e3d35,achievementSingletonProof,sizeof(achievementSingletonProof)) &&
        artifactRead(reinterpret_cast<std::uintptr_t>(image)+0x8bbec88,init) &&
        init==reinterpret_cast<std::uintptr_t>(image)+0x3797b14;
}
BOOL CALLBACK initializeAchievements(PINIT_ONCE,void*,void**) {
    const auto game=GetModuleHandleW(nullptr);
    if (!verifiedImageIdentity(game) || !achievementProfileBytes(reinterpret_cast<const unsigned char*>(game))) {achievementError=2;return TRUE;}
    if (!ensureMinHookInitialized()) {achievementError=3;return TRUE;}
    auto* target=reinterpret_cast<unsigned char*>(game)+achievementPredicateRva;
    if (MH_CreateHook(target,reinterpret_cast<void*>(&achievementPredicateHook),
        reinterpret_cast<void**>(&originalAchievementPredicate))!=MH_OK) {achievementError=4;return TRUE;}
    // package.loadlib must not unload this callback after a Lua hot reload.
    HMODULE pinned=nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,
        reinterpret_cast<const wchar_t*>(&achievementPredicateHook),&pinned)) {MH_RemoveHook(target);achievementError=6;return TRUE;}
    achievementImage.store(reinterpret_cast<std::uintptr_t>(game),std::memory_order_release);
    achievementInitializeManager=reinterpret_cast<AchievementInitializeManager>(reinterpret_cast<unsigned char*>(game)+0x3797b14);
    if (MH_EnableHook(target)!=MH_OK) {
        achievementImage.store(0,std::memory_order_release);MH_RemoveHook(target);achievementError=5;return TRUE;
    }
    achievementReady=true;return TRUE;
}
std::wstring achievementsDirectory() {
    wchar_t filename[32768]{};
    const auto length=GetModuleFileNameW(bridgeModule,filename,32768);
    if (!length || length>=32768) return {};
    std::wstring directory(filename,length);
    const auto slash=directory.find_last_of(L"\\/");if (slash==std::wstring::npos) return {};
    directory.resize(slash+1);
    return directory;
}
void reportAchievements() {
    const auto directory=achievementsDirectory();if (directory.empty()) return;
    const auto path=directory+L"native-achievements-status.txt",temp=path+L".tmp";
    FILE* output=nullptr;if (_wfopen_s(&output,temp.c_str(),L"wb") || !output) return;
    const bool good=std::fprintf(output,"ZFPVA42 %u %u\n",achievementReady?1u:0u,achievementError)>0;
    const int closed=std::fclose(output);
    if (good && closed==0) MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);
    else DeleteFileW(temp.c_str());
}
struct AchievementCheck {unsigned valid=0,enabled=0,recovered=0,error=0;};
// UObject membership is read from the same proven GUObjectArray as telemetry.
// No weak serial is allocated: the game's manager reference holds it strongly.
bool achievementManager(std::uintptr_t image,std::uintptr_t manager,ObjectIdentity& identity,unsigned char& baseInitialized,unsigned char& enabled) {
    std::uint32_t flags=0,slotFlags=0;int count=0;std::int32_t serial=-1;
    std::uintptr_t chunks=0,chunk=0,object=0;
    if (!image || !objectIdentity(manager,identity) || identity.vtable!=image+0x8bbe990 ||
        !artifactRead(manager+8,flags) || (flags&0x18030u) ||
        !artifactRead(image+0xa0e68c0+0x24,count) || count<0 || count>32000000 || identity.internalIndex>=count ||
        !artifactRead(image+0xa0e68c0+0x10,chunks) ||
        !artifactRead(chunks+static_cast<std::uintptr_t>(identity.internalIndex/65536)*8,chunk)) return false;
    const auto slot=chunk+static_cast<std::uintptr_t>(identity.internalIndex%65536)*24;
    return artifactRead(slot,object) && object==manager && artifactRead(slot+8,slotFlags) && !(slotFlags&0x10200000u) &&
        artifactRead(slot+16,serial) && serial>=0 && artifactRead(manager+0x130,baseInitialized) && baseInitialized<=1 &&
        artifactRead(manager+0x131,enabled) && enabled<=1;
}
AchievementCheck achievementCheckManager(std::uintptr_t manager) {
    AchievementCheck result;
    const auto image=achievementImage.load(std::memory_order_acquire);
    if (!achievementReady || !image || !achievementInitializeManager) {result.error=2;return result;}
    std::uintptr_t active=0;
    if (!artifactRead(image+0xa2da5a8,active) || !active || (manager && manager!=active)) {result.error=8;return result;}
    if (!manager) manager=active;
    ObjectIdentity identity;unsigned char baseInitialized=0,enabled=0;
    if (!achievementManager(image,manager,identity,baseInitialized,enabled)) {result.error=8;return result;}
    result.valid=1;result.enabled=baseInitialized?enabled:0;
    // Constructor defaults enabled=1. Wait for the game's own first base Init;
    // only its previously rejected (initialized=1, enabled=0) state is retried.
    if (!baseInitialized || enabled) return result;
    achievementInitializeManager(reinterpret_cast<void*>(manager));
    ObjectIdentity after;unsigned char afterInitialized=0,afterEnabled=0;
    if (!achievementManager(image,manager,after,afterInitialized,afterEnabled) || !sameIdentity(identity,after) ||
        !afterInitialized || !afterEnabled) {result.error=9;return result;}
    result.enabled=1;result.recovered=1;return result;
}
void reportAchievementCheck(const AchievementCheck& result,const std::wstring& directory) {
    const auto path=directory+L"native-achievements-check-status.txt",temp=path+L".tmp";
    FILE* output=nullptr;if (_wfopen_s(&output,temp.c_str(),L"wb") || !output) return;
    const bool good=std::fprintf(output,"ZFPVA42C %u %u %u %u\n",result.valid,result.enabled,result.recovered,result.error)>0;
    const int closed=std::fclose(output);
    if (good && closed==0) MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);
    else DeleteFileW(temp.c_str());
}
}
extern "C" __declspec(dllexport) int zonefpv_achievements_init(void*) {
    InitOnceExecuteOnce(&achievementInitialized,initializeAchievements,nullptr,nullptr);
    reportAchievements();return 0;
}
// Invoke only on the game thread. Lua supplies the existing live manager;
// this export never finds/creates one or modifies saved/account achievement data.
extern "C" __declspec(dllexport) int zonefpv_achievements_check(void*) {
    const auto directory=achievementsDirectory();if (directory.empty()) return 0;
    AchievementCheck result;result.error=7;
    const auto request=directory+L"native-achievements-manager.txt";
    FILE* input=nullptr;
    if (_wfopen_s(&input,request.c_str(),L"rb")==0 && input) {
        char marker[16]{},extra=0;unsigned long long address=0;
        const int fields=fscanf_s(input,"%15s %llx %c",marker,static_cast<unsigned>(sizeof(marker)),&address,&extra,1u);
        std::fclose(input);
        if (fields==2 && std::strcmp(marker,"ZFPVA42")==0) result=achievementCheckManager(static_cast<std::uintptr_t>(address));
    }
    reportAchievementCheck(result,directory);return 0;
}
