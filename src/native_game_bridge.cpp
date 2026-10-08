// The exports are Lua C functions with an intentionally unused lua_State.
// Returning zero needs no Lua ABI symbols. package.loadlib loads this module
// in the game process; no remote injection or guessed UObject vtable slots.
// The PDA geometry query uses one exactly profiled exported UE4SS C++ wrapper.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cmath>
#include <string>
#include <array>
#include <cctype>
#include <atomic>
#include "third_party/minhook/include/MinHook.h"

namespace {
constexpr std::uint32_t gameTimestamp=0xcd15cbee;
constexpr std::uint32_t gameImageSize=0x0b963000;
constexpr std::uintptr_t receiveRva=0x650bee;
constexpr std::uintptr_t actorCoreOffset=0x650;
constexpr ULONGLONG leaseMilliseconds=1500;
using Receive=void(__fastcall*)(void*,const void*,std::uint32_t);
Receive originalReceive=nullptr;
HMODULE bridgeModule=nullptr;
INIT_ONCE initialized=INIT_ONCE_STATIC_INIT;
SRWLOCK stateLock=SRWLOCK_INIT;
struct ObjectIdentity {
    std::uintptr_t vtable=0,klass=0;
    std::int32_t internalIndex=-1;
    std::uint64_t name=0;
};
struct State {
    bool ready=false;
    std::uint32_t error=0;
    std::uintptr_t pawn=0,core=0;
    std::uint32_t guid=0;
    ObjectIdentity identity;
    std::uint64_t token=0,incoming=0,hits=0,buttstockHits=0;
    double total=0;
    unsigned source=0;
    ULONGLONG refreshed=0;
} state;
std::atomic<std::uintptr_t> receiveCore{0};
std::wstring root;
constexpr std::uintptr_t scalarRva=0x26dc18e;
using ScalarSetter=void(__fastcall*)(void*,const void*,float,std::uint32_t,void*);
ScalarSetter originalScalar=nullptr;
using ScalarIndexSetter=bool(__fastcall*)(void*,std::int32_t,float);
ScalarIndexSetter originalScalarIndex=nullptr;
SRWLOCK visualLock=SRWLOCK_INIT;
struct VisualTarget {
    std::uintptr_t mid=0;
    std::uint32_t comparison=0,number=0;
    ObjectIdentity identity;
};
struct VisualState {
    bool ready=false;
    std::uint32_t error=0,count=0;
    std::uint64_t token=0,intercepted=0;
    ULONGLONG refreshed=0;
    std::array<VisualTarget,32> targets{};
} visualState;
std::atomic<std::uint32_t> quickVisualCount{0};
std::array<std::atomic<std::uintptr_t>,32> quickVisualMids{};
bool metadataReady=false;
using RelationLevel=int(__fastcall*)(std::uint64_t,std::uint64_t);
using FactionName=std::uint64_t*(__fastcall*)(std::uint64_t*,std::uint64_t);
struct FactionDesc {std::uint64_t key=0;unsigned char valid=0,padding[7]{};};
using FactionParent=FactionDesc*(__fastcall*)(FactionDesc*,const FactionDesc*);
RelationLevel relationLevel=nullptr;
FactionName factionName=nullptr;
FactionParent factionParent=nullptr;
struct MetadataRow {
    std::uintptr_t actor=0;
    int relation=-1;
    unsigned count=0;
    std::array<std::uint32_t,8> names{};
};

bool objectIdentity(std::uintptr_t object,ObjectIdentity& identity) {
    if (object<0x10000 || object>=0x0000800000000000ull || (object&7)) return false;
    __try {
        identity.vtable=*reinterpret_cast<const std::uintptr_t*>(object);
        identity.internalIndex=*reinterpret_cast<const std::int32_t*>(object+0xc);
        identity.klass=*reinterpret_cast<const std::uintptr_t*>(object+0x10);
        identity.name=*reinterpret_cast<const std::uint64_t*>(object+0x18);
    } __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return identity.internalIndex>=0 && identity.vtable>=0x10000 && identity.klass>=0x10000;
}
bool sameIdentity(const ObjectIdentity& a,const ObjectIdentity& b) {
    return a.vtable==b.vtable && a.klass==b.klass && a.internalIndex==b.internalIndex && a.name==b.name;
}
void __fastcall scalarHook(void* mid,const void* parameters,float value,std::uint32_t flags,void* context) {
    bool candidate=false;
    const auto count=quickVisualCount.load(std::memory_order_acquire);
    for (std::uint32_t i=0;i<count;++i) if (quickVisualMids[i].load(std::memory_order_relaxed)==reinterpret_cast<std::uintptr_t>(mid)) {candidate=true;break;}
    if (!candidate) {originalScalar(mid,parameters,value,flags,context);return;}
    AcquireSRWLockExclusive(&visualLock);
    if (visualState.count && GetTickCount64()-visualState.refreshed<=leaseMilliseconds) {
        for (std::uint32_t i=0;i<visualState.count;++i) {
            const auto& target=visualState.targets[i];
            if (target.mid!=reinterpret_cast<std::uintptr_t>(mid)) continue;
            ObjectIdentity current;
            if (!objectIdentity(target.mid,current) || !sameIdentity(target.identity,current)) continue;
            std::uint32_t comparison=0,number=0;
            std::memcpy(&comparison,parameters,4);
            std::memcpy(&number,static_cast<const unsigned char*>(parameters)+4,4);
            const auto association=static_cast<const unsigned char*>(parameters)[8];
            if (comparison==target.comparison && number==target.number && association==2) {
                if (value!=0) ++visualState.intercepted;
                value=0;break;
            }
        }
    }
    ReleaseSRWLockExclusive(&visualLock);
    originalScalar(mid,parameters,value,flags,context);
}
bool scalarIndexInfo(std::uintptr_t mid,std::int32_t index,std::uint32_t& comparison,std::uint32_t& number,unsigned char& association) {
    // Exact native 0x20160: ScalarParameterValues at +0x180/count +0x188,
    // 36-byte entries, FMaterialParameterInfo first 16 bytes, float at +0x10.
    __try {
        const auto count=*reinterpret_cast<const std::int32_t*>(mid+0x188);
        const auto data=*reinterpret_cast<const std::uintptr_t*>(mid+0x180);
        if (index<0 || index>=count || count>4096 || data<0x10000) return false;
        const auto info=data+static_cast<std::uintptr_t>(index)*36;
        comparison=*reinterpret_cast<const std::uint32_t*>(info);
        number=*reinterpret_cast<const std::uint32_t*>(info+4);
        association=*reinterpret_cast<const unsigned char*>(info+8);
    } __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return true;
}
bool __fastcall scalarIndexHook(void* mid,std::int32_t index,float value) {
    bool candidate=false;
    const auto count=quickVisualCount.load(std::memory_order_acquire);
    for (std::uint32_t i=0;i<count;++i) if (quickVisualMids[i].load(std::memory_order_relaxed)==reinterpret_cast<std::uintptr_t>(mid)) {candidate=true;break;}
    if (!candidate) return originalScalarIndex(mid,index,value);
    AcquireSRWLockExclusive(&visualLock);
    if (visualState.count && GetTickCount64()-visualState.refreshed<=leaseMilliseconds) {
        std::uint32_t comparison=0,number=0;unsigned char association=0;
        if (scalarIndexInfo(reinterpret_cast<std::uintptr_t>(mid),index,comparison,number,association)) {
            for (std::uint32_t i=0;i<visualState.count;++i) {
                const auto& target=visualState.targets[i];
                if (target.mid!=reinterpret_cast<std::uintptr_t>(mid) || comparison!=target.comparison || number!=target.number || association!=2) continue;
                ObjectIdentity current;
                if (!objectIdentity(target.mid,current) || !sameIdentity(current,target.identity)) continue;
                if (value!=0) ++visualState.intercepted;
                value=0;break;
            }
        }
    }
    ReleaseSRWLockExclusive(&visualLock);
    return originalScalarIndex(mid,index,value);
}

bool attackSource(unsigned source) {
    // Installed EDamageSource: direct damage; bullets/explosions; bites, cuts,
    // rams, knife/butt; heavy bullets/buckshot; mutant fire breath/poltergeist;
    // stealth kill. Physics, hunger, bleeding and environmental ticks do not
    // become drone attacks. Their body damage is still canceled while leased.
    return source==0 || (source>=2 && source<=12) || source==23 || source==24 ||
        source==37 || (source>=40 && source<=43) || source==46;
}

void __fastcall receiveHook(void* core,const void* payload,std::uint32_t flags) {
    if (receiveCore.load(std::memory_order_acquire)!=reinterpret_cast<std::uintptr_t>(core)) {
        originalReceive(core,payload,flags);return;
    }
    bool cancel=false;
    AcquireSRWLockExclusive(&stateLock);
    if (state.core==reinterpret_cast<std::uintptr_t>(core) && state.core &&
        GetTickCount64()-state.refreshed<=leaseMilliseconds &&
        *reinterpret_cast<const std::uint32_t*>(static_cast<const unsigned char*>(core)+0x10)==state.guid) {
        // Native callers own a valid internal payload. This hook never follows
        // a stored pawn or reads unrelated receivers. The installed routine
        // reads this same float at 0x650c64 and source byte at 0x650d54.
        float amount=0;
        std::memcpy(&amount,payload,sizeof(amount));
        const auto source=static_cast<const unsigned char*>(payload)[0x79];
        ++state.incoming; state.source=source;
        if (std::isfinite(amount) && amount>0 && attackSource(source)) {
            if (source==12) ++state.buttstockHits;
            ++state.hits; state.total+=static_cast<double>(amount);
        }
        cancel=true;
    }
    ReleaseSRWLockExclusive(&stateLock);
    // Verified void ABI: RCX=ActorCore, RDX=payload, R8D=flags. The native
    // function's sole return epilogue sets no return value. Cancel before any
    // player HP, armor, effects or feedback side effects can run.
    if (!cancel) originalReceive(core,payload,flags);
}

bool bytesMatch(const unsigned char* image,std::uintptr_t rva,const unsigned char* bytes,std::size_t size) {
    return rva<=gameImageSize && size<=gameImageSize-rva && std::memcmp(image+rva,bytes,size)==0;
}

bool verifiedImageHeaders(const unsigned char* image) {
    if (!image) return false;
    const auto dos=reinterpret_cast<const IMAGE_DOS_HEADER*>(image);
    if (dos->e_magic!=IMAGE_DOS_SIGNATURE || dos->e_lfanew<=0 || dos->e_lfanew>0x100000) return false;
    const auto nt=reinterpret_cast<const IMAGE_NT_HEADERS64*>(image+dos->e_lfanew);
    return nt->Signature==IMAGE_NT_SIGNATURE && nt->FileHeader.Machine==IMAGE_FILE_MACHINE_AMD64 &&
        nt->OptionalHeader.Magic==IMAGE_NT_OPTIONAL_HDR64_MAGIC &&
        nt->FileHeader.TimeDateStamp==gameTimestamp && nt->OptionalHeader.SizeOfImage==gameImageSize;
}
bool verifiedImageIdentity(HMODULE game) {
    if (!game) return false;
    wchar_t name[MAX_PATH]{};
    if (!GetModuleFileNameW(game,name,MAX_PATH)) return false;
    const wchar_t* slash=std::wcsrchr(name,L'\\');
    if (_wcsicmp(slash?slash+1:name,L"Stalker2-Win64-Shipping.exe")!=0) return false;
    const auto image=reinterpret_cast<const unsigned char*>(game);
    return verifiedImageHeaders(image);
}
bool verifiedProfile(HMODULE game) {
    if (!verifiedImageIdentity(game)) return false;
    const auto image=reinterpret_cast<const unsigned char*>(game);
    constexpr unsigned char prologue[]={0x41,0x57,0x41,0x56,0x41,0x55,0x41,0x54,0x56,0x57,0x55,0x53,0x48,0x81,0xec,0x78,0x02,0x00,0x00,0x44,0x0f,0x29,0xac,0x24,0x60,0x02,0x00,0x00,0x44,0x0f,0x29,0xa4};
    constexpr unsigned char readDamage[]={0xf3,0x0f,0x10,0x02,0x0f,0x28,0x0d,0x31,0xdd,0x67,0x07,0x0f,0x54,0xc8,0xf3,0x44,0x0f,0x10,0x1d,0xad};
    constexpr unsigned char scalarCaller[]={0x48,0x8b,0x8e,0x50,0x06,0x00,0x00,0x48,0x89,0xfa,0x45,0x31,0xc0,0xe8,0x2d,0x02,0xd5,0xf9};
    constexpr unsigned char structCaller[]={0x48,0x8b,0x8e,0x50,0x06,0x00,0x00,0x48,0x89,0xfa,0x45,0x31,0xc0,0xe8,0xcb,0x01,0xd5,0xf9};
    return bytesMatch(image,receiveRva,prologue,sizeof(prologue)) &&
        bytesMatch(image,0x650c64,readDamage,sizeof(readDamage)) &&
        bytesMatch(image,0x69009af,scalarCaller,sizeof(scalarCaller)) &&
        bytesMatch(image,0x6900a11,structCaller,sizeof(structCaller));
}

void report() {
    State snapshot;
    AcquireSRWLockShared(&stateLock); snapshot=state; ReleaseSRWLockShared(&stateLock);
    const auto file=root+L"native-combat-status.txt";
    const auto temp=file+L".tmp";
    FILE* output=nullptr;
    if (_wfopen_s(&output,temp.c_str(),L"wb") || !output) return;
    const auto active=snapshot.core && GetTickCount64()-snapshot.refreshed<=leaseMilliseconds;
    const int written=std::fprintf(output,"ZFPVN7 %u %u %llu %llu %llu %.17g %u %u %llu\n",
        snapshot.ready?1u:0u,active?1u:0u,static_cast<unsigned long long>(snapshot.token),
        static_cast<unsigned long long>(snapshot.incoming),static_cast<unsigned long long>(snapshot.hits),
        snapshot.total,snapshot.source,snapshot.error,static_cast<unsigned long long>(snapshot.buttstockHits));
    const int closed=std::fclose(output);
    if (written>0 && closed==0) MoveFileExW(temp.c_str(),file.c_str(),MOVEFILE_REPLACE_EXISTING);
    else DeleteFileW(temp.c_str());
}
void visualReport() {
    VisualState snapshot;
    AcquireSRWLockShared(&visualLock);snapshot=visualState;ReleaseSRWLockShared(&visualLock);
    const auto file=root+L"native-visual-status.txt";
    const auto temp=file+L".tmp";
    FILE* output=nullptr;
    if (_wfopen_s(&output,temp.c_str(),L"wb") || !output) return;
    const auto active=snapshot.count && GetTickCount64()-snapshot.refreshed<=leaseMilliseconds;
    const int written=std::fprintf(output,"ZFPVV7 %u %u %llu %llu %u\n",snapshot.ready?1u:0u,active?1u:0u,
        static_cast<unsigned long long>(snapshot.token),static_cast<unsigned long long>(snapshot.intercepted),snapshot.error);
    const int closed=std::fclose(output);
    if (written>0 && closed==0) MoveFileExW(temp.c_str(),file.c_str(),MOVEFILE_REPLACE_EXISTING);
    else DeleteFileW(temp.c_str());
}

bool ensureMinHookInitialized() {
    const auto status=MH_Initialize();
    return status==MH_OK || status==MH_ERROR_ALREADY_INITIALIZED;
}
BOOL CALLBACK initialize(PINIT_ONCE,void*,void**) {
    wchar_t filename[32768]{};
    const auto size=GetModuleFileNameW(bridgeModule,filename,32768);
    if (!size || size>=32768) {state.error=1;return TRUE;}
    root.assign(filename,size);
    const auto slash=root.find_last_of(L"\\/");
    if (slash==std::wstring::npos) {state.error=1;return TRUE;}
    root.resize(slash+1);
    const auto game=GetModuleHandleW(nullptr);
    if (!verifiedProfile(game)) {state.error=2;visualState.error=2;return TRUE;}
    if (!ensureMinHookInitialized()) {state.error=3;return TRUE;}
    auto target=reinterpret_cast<unsigned char*>(game)+receiveRva;
    if (MH_CreateHook(target,reinterpret_cast<void*>(&receiveHook),reinterpret_cast<void**>(&originalReceive))!=MH_OK) {state.error=4;return TRUE;}
    // Keep the detour code resident even if UE4SS hot-reloads the Lua mod.
    HMODULE pinned=nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,
        reinterpret_cast<const wchar_t*>(&receiveHook),&pinned)) {MH_RemoveHook(target);state.error=5;return TRUE;}
    if (MH_EnableHook(target)!=MH_OK) {MH_RemoveHook(target);state.error=6;return TRUE;}
    state.ready=true;
    constexpr unsigned char relationPrologue[]={0x56,0x57,0x48,0x83,0xec,0x38,0x48,0x8b,0x05,0x18,0x3a,0xb4,0x07,0x48,0x31,0xe0,0x48,0x89,0x44,0x24,0x30};
    constexpr unsigned char factionPrologue[]={0x56,0x57,0x53,0x48,0x81,0xec,0xc0,0x00,0x00,0x00,0x48,0x89,0xd7,0x48,0x89,0xce};
    constexpr unsigned char parentPrologue[]={0x56,0x48,0x83,0xec,0x20,0x48,0x89,0xce,0x48,0x8b,0x12,0x48,0x8d,0x0d,0x18,0xa7,0x4a,0x04};
    const auto image=reinterpret_cast<unsigned char*>(game);
    metadataReady=bytesMatch(image,0x235809b,relationPrologue,sizeof(relationPrologue)) &&
        bytesMatch(image,0xc5ec67,factionPrologue,sizeof(factionPrologue)) &&
        bytesMatch(image,0x6b5b406,parentPrologue,sizeof(parentPrologue));
    if (metadataReady) {
        relationLevel=reinterpret_cast<RelationLevel>(image+0x235809b);
        factionName=reinterpret_cast<FactionName>(image+0xc5ec67);
        factionParent=reinterpret_cast<FactionParent>(image+0x6b5b406);
    }
    constexpr unsigned char scalarPrologue[]={0x41,0x57,0x41,0x56,0x41,0x55,0x41,0x54,0x56,0x57,0x55,0x53,0x48,0x81,0xec,0xd8,0x00,0x00,0x00,0x0f,0x29,0xb4,0x24,0xc0,0x00,0x00,0x00,0x0f,0x28,0xf2,0x48,0x89};
    auto scalarTarget=reinterpret_cast<unsigned char*>(game)+scalarRva;
    if (!bytesMatch(reinterpret_cast<const unsigned char*>(game),scalarRva,scalarPrologue,sizeof(scalarPrologue))) {visualState.error=2;return TRUE;}
    if (MH_CreateHook(scalarTarget,reinterpret_cast<void*>(&scalarHook),reinterpret_cast<void**>(&originalScalar))!=MH_OK) {visualState.error=4;return TRUE;}
    if (MH_EnableHook(scalarTarget)!=MH_OK) {MH_RemoveHook(scalarTarget);visualState.error=6;return TRUE;}
    constexpr unsigned char indexPrologue[]={0x56,0x48,0x83,0xec,0x20,0x48,0x63,0xc2,0x48,0x8d,0x34,0xc0,0x48,0xc1,0xe6,0x02,0x48,0x03,0xb1,0x80,0x01,0x00,0x00,0x31,0xd2,0x39,0x81,0x88,0x01,0x00,0x00,0x48};
    auto indexTarget=image+0x20160;
    if (!bytesMatch(image,0x20160,indexPrologue,sizeof(indexPrologue))) {visualState.error=2;return TRUE;}
    if (MH_CreateHook(indexTarget,reinterpret_cast<void*>(&scalarIndexHook),reinterpret_cast<void**>(&originalScalarIndex))!=MH_OK) {visualState.error=4;return TRUE;}
    if (MH_EnableHook(indexTarget)!=MH_OK) {MH_RemoveHook(indexTarget);visualState.error=6;return TRUE;}
    visualState.ready=true;
    return TRUE;
}

bool readCore(std::uintptr_t pawn,std::uintptr_t& core) {
    if (pawn<0x10000 || pawn>=0x0000800000000000ull || (pawn&7)) return false;
    __try {core=*reinterpret_cast<const std::uintptr_t*>(pawn+actorCoreOffset);}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    if (core<0x10000 || core>=0x0000800000000000ull || (core&7)) return false;
    MEMORY_BASIC_INFORMATION memory{};
    return VirtualQuery(reinterpret_cast<void*>(core),&memory,sizeof(memory))==sizeof(memory) &&
        memory.State==MEM_COMMIT && !(memory.Protect&(PAGE_GUARD|PAGE_NOACCESS));
}
bool coreGuid(std::uintptr_t core,std::uint32_t& guid) {
    __try {guid=*reinterpret_cast<const std::uint32_t*>(core+0x10);}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return guid<0xfffffff0u;
}
struct CoreInfo {
    std::uintptr_t core=0;
    std::uint32_t guid=0;
    std::uint64_t faction=0,relation=0;
    ObjectIdentity identity;
};
bool coreInfo(std::uintptr_t actor,CoreInfo& info) {
    if (!objectIdentity(actor,info.identity) || !readCore(actor,info.core)) return false;
    const auto base=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    if (info.identity.vtable<base || info.identity.vtable>=base+gameImageSize) return false;
    __try {
        info.guid=*reinterpret_cast<const std::uint32_t*>(info.core+0x10);
        info.faction=*reinterpret_cast<const std::uint64_t*>(info.core+0x120);
        info.relation=*reinterpret_cast<const std::uint64_t*>(info.core+0x140);
    } __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return info.guid<0xfffffff0u;
}
bool factionMapReady() {
    const auto image=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    __try {
        const auto buckets=*reinterpret_cast<const std::uintptr_t*>(image+0xb105b30);
        const auto count=*reinterpret_cast<const std::uint32_t*>(image+0xb105b38);
        if (buckets<0x10000 || count==0 || count>0x100000) return false;
        volatile auto first=*reinterpret_cast<const unsigned char*>(buckets);
        (void)first;
        return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
}
void collectFactionNames(std::uint64_t key,MetadataRow& row) {
    std::array<std::uint64_t,8> seen{};
    for (unsigned depth=0;key && depth<seen.size();++depth) {
        bool repeated=false;
        for (unsigned i=0;i<depth;++i) if (seen[i]==key) {repeated=true;break;}
        if (repeated) break;
        seen[depth]=key;
        std::uint64_t name=~std::uint64_t{0};
        factionName(&name,key);
        const auto comparison=static_cast<std::uint32_t>(name);
        // The native icon map uses FNames. Export only ordinary names;
        // the Lua comparison-index constructor cannot represent Number.
        if (comparison && comparison!=0xffffffffu && (name>>32)==0) row.names[row.count++]=comparison;
        FactionDesc input{key,1,{}},parent{};
        factionParent(&parent,&input);
        if (!parent.valid) break;
        key=parent.key;
    }
}
bool queryMetadata(const CoreInfo& player,std::uintptr_t actor,MetadataRow& row) {
    CoreInfo before;
    if (!coreInfo(actor,before)) return false;
    const bool factions=factionMapReady();
    __try {
        if (player.relation && before.relation) {
            const int level=relationLevel(player.relation,before.relation);
            if (level>=0 && level<=4) row.relation=level;
        }
        if (factions) collectFactionNames(before.faction,row);
    } __except(EXCEPTION_EXECUTE_HANDLER) {row.relation=-1;row.count=0;return false;}
    CoreInfo after;
    if (!coreInfo(actor,after) || before.core!=after.core || before.guid!=after.guid ||
        !sameIdentity(before.identity,after.identity)) {row.relation=-1;row.count=0;return false;}
    return true;
}
}

extern "C" __declspec(dllexport) int zonefpv_combat_init(void*) {
    InitOnceExecuteOnce(&initialized,initialize,nullptr,nullptr); report();visualReport();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_combat_arm(void*) {
    receiveCore.store(0,std::memory_order_release);
    AcquireSRWLockExclusive(&stateLock); state.core=0; state.pawn=0; ReleaseSRWLockExclusive(&stateLock);
    unsigned long long token=0,pawn=0;
    FILE* input=nullptr;
    const auto file=root+L"native-combat-control.txt";
    bool parsed=false;
    if (!_wfopen_s(&input,file.c_str(),L"rb") && input) {
        char text[256]{};
        const auto length=std::fread(text,1,sizeof(text)-1,input);
        std::fclose(input);
        char extra=0;
        parsed=length>0 && length<sizeof(text)-1 &&
            sscanf_s(text,"ZFPVN7 %llu %llx %c",&token,&pawn,&extra,1u)==2 && token>0;
    }
    DeleteFileW(file.c_str());
    std::uintptr_t core=0;
    std::uint32_t guid=0;
    ObjectIdentity identity;
    const bool safe=parsed && readCore(static_cast<std::uintptr_t>(pawn),core) && coreGuid(core,guid) &&
        objectIdentity(static_cast<std::uintptr_t>(pawn),identity);
    AcquireSRWLockExclusive(&stateLock);
    if (state.ready && safe) {
        state.pawn=static_cast<std::uintptr_t>(pawn); state.core=core; state.token=token;
        state.guid=guid;state.identity=identity;
        state.incoming=0; state.hits=0; state.buttstockHits=0; state.total=0; state.source=0; state.error=0;
        state.refreshed=GetTickCount64();
        receiveCore.store(core,std::memory_order_release);
    } else if (state.ready) state.error=7;
    ReleaseSRWLockExclusive(&stateLock);
    report();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_combat_tick(void*) {
    // Lua calls this only after its current pawn identity is checked. Validate
    // its current ActorCore too: a changed native pool slot cannot inherit a
    // flight's shield or attack counters.
    AcquireSRWLockExclusive(&stateLock);
    std::uintptr_t core=0;
    std::uint32_t guid=0;
    ObjectIdentity identity;
    if (state.core) {
        if (readCore(state.pawn,core) && core==state.core && coreGuid(core,guid) && guid==state.guid &&
            objectIdentity(state.pawn,identity) && sameIdentity(identity,state.identity)) state.refreshed=GetTickCount64();
        else {receiveCore.store(0,std::memory_order_release);state.core=0;state.pawn=0;state.error=8;}
    }
    ReleaseSRWLockExclusive(&stateLock);return 0;
}
extern "C" __declspec(dllexport) int zonefpv_combat_poll(void*) {report();return 0;}
extern "C" __declspec(dllexport) int zonefpv_combat_disarm(void*) {
    // Synchronous lock handoff drains any callback state access before the Lua
    // caller returns the character and restores its original damage flags.
    receiveCore.store(0,std::memory_order_release);
    AcquireSRWLockExclusive(&stateLock);state.core=0;state.pawn=0;ReleaseSRWLockExclusive(&stateLock);
    report();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_visual_arm(void*) {
    quickVisualCount.store(0,std::memory_order_release);
    AcquireSRWLockExclusive(&visualLock);visualState.count=0;ReleaseSRWLockExclusive(&visualLock);
    const auto file=root+L"native-visual-control.txt";
    FILE* input=nullptr;
    VisualState candidate;
    unsigned long long token=0;
    unsigned count=0;
    bool parsed=false;
    if (!_wfopen_s(&input,file.c_str(),L"rb") && input) {
        parsed=fscanf_s(input,"ZFPVV7 %llu %u",&token,&count)==2 && token>0 && count>0 && count<=candidate.targets.size();
        if (parsed) for (unsigned i=0;i<count;++i) {
            unsigned long long address=0;
            auto& target=candidate.targets[i];
            if (fscanf_s(input," %llx %u %u",&address,&target.comparison,&target.number)!=3 || target.comparison==0) {parsed=false;break;}
            target.mid=static_cast<std::uintptr_t>(address);
            if (!objectIdentity(target.mid,target.identity)) {parsed=false;break;}
            const auto base=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
            if (target.identity.vtable<base || target.identity.vtable>=base+gameImageSize) {parsed=false;break;}
        }
        if (parsed) {
            int trailing=0;
            while ((trailing=std::fgetc(input))!=EOF) if (!std::isspace(static_cast<unsigned char>(trailing))) {parsed=false;break;}
        }
        std::fclose(input);
    }
    DeleteFileW(file.c_str());
    AcquireSRWLockExclusive(&visualLock);
    if (visualState.ready && parsed) {
        candidate.ready=true;candidate.token=token;candidate.count=count;candidate.refreshed=GetTickCount64();visualState=candidate;
        for (unsigned i=0;i<count;++i) quickVisualMids[i].store(candidate.targets[i].mid,std::memory_order_relaxed);
        quickVisualCount.store(count,std::memory_order_release);
    } else if (visualState.ready) visualState.error=7;
    ReleaseSRWLockExclusive(&visualLock);
    visualReport();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_visual_tick(void*) {
    AcquireSRWLockExclusive(&visualLock);
    if (visualState.count) {
        bool same=true;
        for (std::uint32_t i=0;i<visualState.count;++i) {
            ObjectIdentity current;
            const auto& target=visualState.targets[i];
            if (!objectIdentity(target.mid,current) || !sameIdentity(target.identity,current)) {same=false;break;}
        }
        if (same) visualState.refreshed=GetTickCount64();
        else {quickVisualCount.store(0,std::memory_order_release);visualState.count=0;visualState.error=8;}
    }
    ReleaseSRWLockExclusive(&visualLock);return 0;
}
extern "C" __declspec(dllexport) int zonefpv_visual_poll(void*) {visualReport();return 0;}
extern "C" __declspec(dllexport) int zonefpv_visual_disarm(void*) {
    quickVisualCount.store(0,std::memory_order_release);
    AcquireSRWLockExclusive(&visualLock);visualState.count=0;ReleaseSRWLockExclusive(&visualLock);
    visualReport();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_metadata_query(void*) {
    const auto request=root+L"native-metadata-control.txt";
    FILE* input=nullptr;
    unsigned long long token=0,pawn=0;
    unsigned count=0;
    std::array<MetadataRow,16> rows{};
    bool parsed=false;
    if (!_wfopen_s(&input,request.c_str(),L"rb") && input) {
        parsed=fscanf_s(input,"ZFPVM7 %llu %llx %u",&token,&pawn,&count)==3 && token>0 && count>0 && count<=rows.size();
        if (parsed) for (unsigned i=0;i<count;++i) {
            unsigned long long address=0;
            if (fscanf_s(input," %llx",&address)!=1) {parsed=false;break;}
            rows[i].actor=static_cast<std::uintptr_t>(address);
        }
        if (parsed) {
            int trailing=0;
            while ((trailing=std::fgetc(input))!=EOF) if (!std::isspace(static_cast<unsigned char>(trailing))) {parsed=false;break;}
        }
        std::fclose(input);
    }
    DeleteFileW(request.c_str());
    unsigned error=metadataReady?0u:2u;
    CoreInfo player;
    if (!parsed) {error=7;count=0;}
    else if (!coreInfo(static_cast<std::uintptr_t>(pawn),player)) error=8;
    if (!error) for (unsigned i=0;i<count;++i) queryMetadata(player,rows[i].actor,rows[i]);
    CoreInfo stillPlayer;
    if (!error && (!coreInfo(static_cast<std::uintptr_t>(pawn),stillPlayer) || player.core!=stillPlayer.core ||
        player.guid!=stillPlayer.guid || !sameIdentity(player.identity,stillPlayer.identity))) {
        error=8;for (unsigned i=0;i<count;++i) {rows[i].relation=-1;rows[i].count=0;}
    }
    const auto response=root+L"native-metadata-status.txt";
    const auto temp=response+L".tmp";
    FILE* output=nullptr;
    if (_wfopen_s(&output,temp.c_str(),L"wb") || !output) return 0;
    bool good=std::fprintf(output,"ZFPVM7 %u %llu %u %u\n",metadataReady?1u:0u,token,count,error)>0;
    for (unsigned i=0;i<count && good;++i) {
        good=std::fprintf(output,"%llx %d %u",static_cast<unsigned long long>(rows[i].actor),rows[i].relation,rows[i].count)>0;
        for (unsigned j=0;j<rows[i].count && good;++j) good=std::fprintf(output," %u",rows[i].names[j])>0;
        good=good && std::fputc('\n',output)!=EOF;
    }
    const int closed=std::fclose(output);
    if (good && closed==0) MoveFileExW(temp.c_str(),response.c_str(),MOVEFILE_REPLACE_EXISTING);
    else DeleteFileW(temp.c_str());
    return 0;
}

BOOL APIENTRY DllMain(HMODULE module,DWORD reason,LPVOID) {
    if (reason==DLL_PROCESS_ATTACH) {bridgeModule=module;DisableThreadLibraryCalls(module);}
    return TRUE;
}

#include "native_aggression.h"
#include "native_artifact.h"
#include "native_resources.h"
#include "native_geiger.h"
#include "native_concussion.h"
#include "native_concussion_source.h"
#include "native_achievements.h"
#include "native_pda_geometry.h"
