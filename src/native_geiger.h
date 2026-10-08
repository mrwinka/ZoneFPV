#pragma once
// PlayerEffectsSFXComponent's native update writes RTPC and starts its event
// without ComponentTick. Gate only the verified player's Geiger instance.
namespace {
constexpr std::uintptr_t geigerUpdateRva=0x2910a2;
constexpr unsigned char geigerUpdatePrologue[]={0x56,0x57,0x53,0x48,0x83,0xec,0x40,0x48,0x89,0xce,0x48,0x8b,0x05,0x0d,0xaa,0xc0,0x09,0x48,0x31,0xe0,0x48,0x89,0x44,0x24,0x38,0x48,0x8b,0x89,0xb8,0,0,0};
constexpr unsigned char geigerStartOwner[]={0x48,0x8b,0x96,0xa8,0,0,0,0x4c,0x8b,0x86,0xc0,0,0,0,0x48,0x89,0x5c,0x24,0x20,0x48,0x89,0xf9,0x41,0xb1,0x01};
constexpr unsigned char geigerStopPrologue[]={0x56,0x57,0x53,0x48,0x83,0xec,0x40,0x48,0x89,0xce,0x48,0x8b,0x05,0x59,0x9f,0x91,0x09,0x48,0x31,0xe0,0x48,0x89,0x44,0x24,0x38,0x48,0x8b,0x89,0xb8,0,0,0};
constexpr unsigned char geigerStopOwner[]={0x48,0x8b,0x96,0xb0,0,0,0,0x4c,0x8b,0x86,0xc0,0,0,0,0x48,0x89,0x5c,0x24,0x20,0x48,0x89,0xf9,0x41,0xb1,0x01};
using GeigerUpdate=void(__fastcall*)(void*);
GeigerUpdate originalGeigerUpdate=nullptr;
GeigerUpdate stopGeiger=nullptr;
INIT_ONCE geigerInitialized=INIT_ONCE_STATIC_INIT;
SRWLOCK geigerLock=SRWLOCK_INIT;
std::atomic<std::uintptr_t> quickGeiger{0};
struct GeigerState {
    bool ready=false;
    unsigned error=0;
    std::uint64_t token=0,blocked=0,stopped=0;
    std::uintptr_t component=0,pawn=0;
    ObjectIdentity componentIdentity{},pawnIdentity{};
    ULONGLONG refreshed=0;
} geiger;
bool geigerSame(const GeigerState& s) {
    ObjectIdentity component,pawn;std::uintptr_t owner=0;std::uint32_t flags=0;
    return objectIdentity(s.component,component) && sameIdentity(component,s.componentIdentity) &&
        objectIdentity(s.pawn,pawn) && sameIdentity(pawn,s.pawnIdentity) &&
        artifactRead(s.component+8,flags) && !(flags&0x18030) &&
        artifactRead(s.pawn+8,flags) && !(flags&0x18030) &&
        artifactRead(s.component+0xc0,owner) && owner==s.pawn;
}
bool stopOwnedGeiger(const GeigerState& s,bool& stopped) {
    stopped=false;
    unsigned char playing=0;
    if (!stopGeiger || !geigerSame(s) || !artifactRead(s.component+0xc8,playing)) return false;
    if (!playing) return true;
    // Game stop path zeroes its RTPC, posts this component's SFXStopEvent on
    // its verified pawn and clears its playing bit. No all-actor/global stop.
    __try {stopGeiger(reinterpret_cast<void*>(s.component));}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    if (!artifactRead(s.component+0xc8,playing) || playing) return false;
    stopped=true;return true;
}
void maintainGeigerStop() {
    GeigerState snapshot;
    AcquireSRWLockShared(&geigerLock);snapshot=geiger;ReleaseSRWLockShared(&geigerLock);
    if (!snapshot.component) return;
    bool stopped=false;const bool safe=stopOwnedGeiger(snapshot,stopped);
    AcquireSRWLockExclusive(&geigerLock);
    if (geiger.token==snapshot.token && geiger.component==snapshot.component) {
        if (safe) {if (stopped) ++geiger.stopped;}
        else {quickGeiger.store(0,std::memory_order_release);geiger.component=0;geiger.error=9;}
    }
    ReleaseSRWLockExclusive(&geigerLock);
}
void __fastcall geigerUpdateHook(void* component) {
    if (quickGeiger.load(std::memory_order_acquire)!=reinterpret_cast<std::uintptr_t>(component)) {
        originalGeigerUpdate(component);return;
    }
    bool suppress=false;
    AcquireSRWLockExclusive(&geigerLock);
    if (geiger.component==reinterpret_cast<std::uintptr_t>(component) &&
        GetTickCount64()-geiger.refreshed<=leaseMilliseconds && geigerSame(geiger)) {
        ++geiger.blocked;suppress=true;
    }
    ReleaseSRWLockExclusive(&geigerLock);
    if (!suppress) originalGeigerUpdate(component);
}
BOOL CALLBACK initializeGeiger(PINIT_ONCE,void*,void**) {
    const auto game=GetModuleHandleW(nullptr);
    const auto image=reinterpret_cast<const unsigned char*>(game);
    if (!verifiedImageIdentity(game) ||
        !bytesMatch(image,0x2910a2,geigerUpdatePrologue,sizeof(geigerUpdatePrologue)) ||
        !bytesMatch(image,0x29111e,geigerStartOwner,sizeof(geigerStartOwner)) ||
        !bytesMatch(image,0x581b56,geigerStopPrologue,sizeof(geigerStopPrologue)) ||
        !bytesMatch(image,0x581bcd,geigerStopOwner,sizeof(geigerStopOwner))) {geiger.error=2;return TRUE;}
    // The main bridge initializes MinHook and pins this DLL before this export.
    if (!state.ready) {geiger.error=3;return TRUE;}
    auto target=const_cast<unsigned char*>(image)+geigerUpdateRva;
    if (MH_CreateHook(target,reinterpret_cast<void*>(&geigerUpdateHook),reinterpret_cast<void**>(&originalGeigerUpdate))!=MH_OK) {geiger.error=4;return TRUE;}
    if (MH_EnableHook(target)!=MH_OK) {MH_RemoveHook(target);geiger.error=6;return TRUE;}
    stopGeiger=reinterpret_cast<GeigerUpdate>(const_cast<unsigned char*>(image)+0x581b56);
    geiger.ready=true;return TRUE;
}
void geigerReport() {
    GeigerState snapshot;AcquireSRWLockShared(&geigerLock);snapshot=geiger;ReleaseSRWLockShared(&geigerLock);
    const auto path=root+L"native-geiger-status.txt",temp=path+L".tmp";FILE* f=nullptr;
    if (_wfopen_s(&f,temp.c_str(),L"wb") || !f) return;
    const bool active=snapshot.component && GetTickCount64()-snapshot.refreshed<=leaseMilliseconds;
    const bool wrote=std::fprintf(f,"ZFPVG12 %u %u %llu %llu %llu %u\n",snapshot.ready?1u:0u,active?1u:0u,
        static_cast<unsigned long long>(snapshot.token),static_cast<unsigned long long>(snapshot.blocked),
        static_cast<unsigned long long>(snapshot.stopped),snapshot.error)>0;
    const int closed=std::fclose(f);
    if (wrote && !closed) MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);else DeleteFileW(temp.c_str());
}
}
extern "C" __declspec(dllexport) int zonefpv_geiger_arm(void*) {
    InitOnceExecuteOnce(&initialized,initialize,nullptr,nullptr);
    InitOnceExecuteOnce(&geigerInitialized,initializeGeiger,nullptr,nullptr);
    quickGeiger.store(0,std::memory_order_release);
    GeigerState candidate;unsigned long long token=0,component=0,pawn=0;FILE* f=nullptr;bool parsed=false;
    const auto path=root+L"native-geiger-control.txt";
    if (!_wfopen_s(&f,path.c_str(),L"rb") && f) {
        char text[160]{};const auto size=std::fread(text,1,sizeof(text)-1,f);std::fclose(f);char extra=0;
        parsed=size>0 && size<sizeof(text)-1 && sscanf_s(text,"ZFPVG12 %llu %llx %llx %c",&token,&component,&pawn,&extra,1u)==3 && token>0;
    }
    DeleteFileW(path.c_str());candidate.token=token;candidate.component=component;candidate.pawn=pawn;
    const auto image=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    const bool safe=parsed && objectIdentity(component,candidate.componentIdentity) && candidate.componentIdentity.vtable==image+0x8ccc0c0 &&
        objectIdentity(pawn,candidate.pawnIdentity) && candidate.pawnIdentity.vtable==image+0x8d8df10 && geigerSame(candidate);
    AcquireSRWLockExclusive(&geigerLock);
    if (geiger.ready && safe) {
        candidate.ready=true;candidate.refreshed=GetTickCount64();geiger=candidate;
        quickGeiger.store(component,std::memory_order_release);
    } else {geiger.component=0;if (geiger.ready)geiger.error=8;geiger.token=token;}
    ReleaseSRWLockExclusive(&geigerLock);maintainGeigerStop();geigerReport();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_geiger_tick(void*) {
    AcquireSRWLockExclusive(&geigerLock);
    if (geiger.component) {
        if (geigerSame(geiger)) geiger.refreshed=GetTickCount64();
        else {quickGeiger.store(0,std::memory_order_release);geiger.component=0;geiger.error=8;}
    }
    ReleaseSRWLockExclusive(&geigerLock);maintainGeigerStop();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_geiger_poll(void*) {geigerReport();return 0;}
extern "C" __declspec(dllexport) int zonefpv_geiger_disarm(void*) {
    quickGeiger.store(0,std::memory_order_release);
    AcquireSRWLockExclusive(&geigerLock);geiger.component=0;ReleaseSRWLockExclusive(&geigerLock);geigerReport();return 0;
}
