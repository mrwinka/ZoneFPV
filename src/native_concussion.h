#pragma once
// Installed KismetMaterialLibrary SetScalarParameterValue -> native collection
// instance setter. Gate the exact world/asset/FName lease before its uniform
// resource update; later game writes cannot revive concussion/suppression blur.
namespace {
constexpr std::uintptr_t concussionSetterRva=0x24e51c2;
constexpr unsigned char concussion_setterPrologue[]={0x56,0x57,0x48,0x83,0xec,0x58,0x48,0x8b,0x05,0xf1,0x68,0x9b,0x07,0x48,0x31,0xe0,0x48,0x89,0x44,0x24,0x50,0x48,0x89,0x54,0x24,0x30,0xf3,0x0f,0x11,0x54,0x24,0x2c};
constexpr unsigned char concussion_worldBinding[]={0x48,0x89,0xce,0x44,0x8b,0x49,0x34,0x31,0xff,0x45,0x85,0xc9,0x78,0xdc,0x8b,0x0d,0xcd,0x16,0xc0,0x07,0x44,0x39,0xc9,0x7e,0xd1,0x45,0x0f,0xb7,0xd1,0x48,0x8b,0x05,0xa9,0x16,0xc0,0x07};
constexpr unsigned char concussion_collectionBinding[]={0x44,0x8b,0x4e,0x30,0x45,0x85,0xc9,0x0f,0x84,0x78,0x01,0x00,0x00,0x44,0x8b,0x56,0x2c,0x45,0x31,0xc0,0x45,0x85,0xd2};
constexpr unsigned char concussion_worldCollectionArray[]={0x41,0x57,0x41,0x56,0x56,0x57,0x53,0x49,0x89,0xd0,0x8b,0x91,0xe8,0x01,0x00,0x00,0x85,0xd2,0x0f,0x8e,0x83,0x00,0x00,0x00,0x4c,0x8b,0x89,0xe0,0x01,0x00,0x00,0x44,0x8b,0x15,0xf6,0x8b,0xe0,0x09};
constexpr unsigned char concussion_kismetSetterABI[]={0x48,0x89,0xc1,0x48,0x89,0xfa,0xe8,0x9b,0xc4,0xb2,0xfa,0x48,0x89,0xc6,0x48,0x89,0xc1,0x48,0x89,0xda,0x0f,0x28,0xd6,0xe8,0x84,0x39,0xd3,0xfc};
constexpr unsigned char concussion_collectionNameArray[]={0x41,0x8b,0x40,0x40,0x85,0xc0,0x0f,0x8e,0x2d,0xff,0xff,0xff,0x49,0x8b,0x48,0x38,0x48,0x39,0x11,0x74,0x0e,0x48,0x83,0xc1,0x1c,0x48,0xff,0xc8,0x75,0xf2,0xe9,0x16,0xff,0xff,0xff};
using ConcussionSetter=bool(__fastcall*)(void*,std::uint64_t,float);
ConcussionSetter originalConcussionSetter=nullptr;
INIT_ONCE concussionInitialized=INIT_ONCE_STATIC_INIT;
SRWLOCK concussionLock=SRWLOCK_INIT;
std::atomic<std::uintptr_t> quickConcussionInstance{0};
struct ConcussionArrayGlobals {std::uintptr_t chunks=0,count=0;} concussionArrayGlobals;
struct ConcussionState {
    bool ready=false;
    unsigned error=0;
    std::uint64_t token=0,blocked=0,name=0,secondaryName=0;
    std::uintptr_t world=0,collection=0,instance=0;
    ObjectIdentity worldIdentity{},collectionIdentity{},instanceIdentity{};
    std::int32_t worldSerial=0,collectionSerial=0,instanceSerial=0;
    std::int32_t instanceIndex=-1;
    ULONGLONG refreshed=0;
} concussion;
bool concussionProfileBytes(const unsigned char* image) {
    return bytesMatch(image,concussionSetterRva,concussion_setterPrologue,sizeof(concussion_setterPrologue)) &&
        bytesMatch(image,0x24e5203,concussion_worldBinding,sizeof(concussion_worldBinding)) &&
        bytesMatch(image,0x24e5255,concussion_collectionBinding,sizeof(concussion_collectionBinding)) &&
        bytesMatch(image,0x2ddcc8,concussion_worldCollectionArray,sizeof(concussion_worldCollectionArray)) &&
        bytesMatch(image,0x57b1822,concussion_kismetSetterABI,sizeof(concussion_kismetSetterABI)) &&
        bytesMatch(image,0x24e52b2,concussion_collectionNameArray,sizeof(concussion_collectionNameArray));
}
bool concussionSlot(std::int32_t index,std::uintptr_t expected,std::int32_t& serial,bool allowZeroSerial=false) {
    std::int32_t count=0;std::uintptr_t chunks=0,chunk=0,object=0;std::uint32_t flags=0;
    if (index<0 || !artifactRead(concussionArrayGlobals.count,count) || count<0 || count>32000000 || index>=count ||
        !artifactRead(concussionArrayGlobals.chunks,chunks) ||
        !artifactRead(chunks+static_cast<std::uintptr_t>(index/65536)*8,chunk)) return false;
    const auto slot=chunk+static_cast<std::uintptr_t>(index%65536)*24;
    return artifactRead(slot,object) && object==expected && artifactRead(slot+8,flags) && !(flags&0x10200000u) &&
        artifactRead(slot+16,serial) && (allowZeroSerial?serial>=0:serial>0);
}
bool concussionCapture(std::uintptr_t object,ObjectIdentity& identity,std::int32_t& serial,bool allowZeroSerial=false) {
    std::uint32_t flags=0;
    return objectIdentity(object,identity) && artifactRead(object+8,flags) && !(flags&0x18030u) &&
        concussionSlot(identity.internalIndex,object,serial,allowZeroSerial);
}
bool concussionLive(std::uintptr_t object,const ObjectIdentity& identity,std::int32_t serial) {
    ObjectIdentity current;std::int32_t currentSerial=0;
    return concussionCapture(object,current,currentSerial) && sameIdentity(current,identity) && currentSerial==serial;
}
bool concussionBinding(const ConcussionState& s) {
    std::int32_t collectionIndex=-1,collectionSerial=0,worldIndex=-1,worldSerial=0;
    return artifactRead(s.instance+0x2c,collectionIndex) && collectionIndex==s.collectionIdentity.internalIndex &&
        artifactRead(s.instance+0x30,collectionSerial) && collectionSerial==s.collectionSerial &&
        artifactRead(s.instance+0x34,worldIndex) && worldIndex==s.worldIdentity.internalIndex &&
        artifactRead(s.instance+0x38,worldSerial) && worldSerial==s.worldSerial;
}
bool concussionMembership(ConcussionState& s) {
    std::int32_t count=0;std::uintptr_t entries=0,object=0;
    if (!artifactRead(s.world+0x1e8,count) || count<1 || count>1024 || !artifactRead(s.world+0x1e0,entries)) return false;
    if (s.instanceIndex>=0 && s.instanceIndex<count &&
        artifactRead(entries+static_cast<std::uintptr_t>(s.instanceIndex)*8,object) && object==s.instance) return true;
    for (int i=0;i<count;++i) {
        if (!artifactRead(entries+static_cast<std::uintptr_t>(i)*8,object)) return false;
        if (object==s.instance) {s.instanceIndex=i;return true;}
    }
    return false;
}
bool concussionSame(ConcussionState& s) {
    ObjectIdentity instanceIdentity;std::int32_t serial=0;
    if (!concussionLive(s.world,s.worldIdentity,s.worldSerial) ||
        !concussionLive(s.collection,s.collectionIdentity,s.collectionSerial) ||
        !concussionCapture(s.instance,instanceIdentity,serial,true) || !sameIdentity(instanceIdentity,s.instanceIdentity) ||
        (s.instanceSerial!=0 && serial!=s.instanceSerial) || !concussionBinding(s) || !concussionMembership(s)) return false;
    // UWorld holds instances strongly. Their own serial can be0 until the first
    // FWeakObjectPtr is made. Accept that state without allocating/writing one;
    // latch a later positive serial so a subsequent reuse is still rejected.
    s.instanceSerial=serial;return true;
}
bool concussionParameter(std::uintptr_t collection,std::uint64_t name) {
    std::int32_t count=0;std::uintptr_t entries=0;
    if (!artifactRead(collection+0x40,count) || count<1 || count>1024 || !artifactRead(collection+0x38,entries)) return false;
    for (int i=0;i<count;++i) {
        std::uint64_t actual=0;
        if (!artifactRead(entries+static_cast<std::uintptr_t>(i)*28,actual)) return false;
        if (actual==name) return true;
    }
    return false;
}
bool concussionFindInstance(ConcussionState& s) {
    // This is the same owned UWorld array used by native GetParameterCollectionInstance.
    // Do not call its miss path, scan global UObjects or create a new instance.
    std::int32_t count=0;std::uintptr_t entries=0;
    if (!s.name || (s.secondaryName && s.secondaryName==s.name) ||
        !concussionCapture(s.world,s.worldIdentity,s.worldSerial) ||
        !concussionCapture(s.collection,s.collectionIdentity,s.collectionSerial) ||
        !concussionParameter(s.collection,s.name) ||
        (s.secondaryName && !concussionParameter(s.collection,s.secondaryName)) ||
        !artifactRead(s.world+0x1e8,count) || count<1 || count>1024 ||
        !artifactRead(s.world+0x1e0,entries)) return false;
    for (int i=0;i<count;++i) {
        if (!artifactRead(entries+static_cast<std::uintptr_t>(i)*8,s.instance)) return false;
        if (concussionCapture(s.instance,s.instanceIdentity,s.instanceSerial,true) && concussionBinding(s)) {s.instanceIndex=i;return true;}
    }
    s.instance=0;return false;
}
bool __fastcall concussionSetterHook(void* instance,std::uint64_t name,float value) {
    if (quickConcussionInstance.load(std::memory_order_acquire)!=reinterpret_cast<std::uintptr_t>(instance))
        return originalConcussionSetter(instance,name,value);
    AcquireSRWLockExclusive(&concussionLock);
    if (concussion.instance==reinterpret_cast<std::uintptr_t>(instance) &&
        (name==concussion.name || (concussion.secondaryName && name==concussion.secondaryName)) &&
        GetTickCount64()-concussion.refreshed<=leaseMilliseconds && concussionSame(concussion)) {
        if (value!=0) ++concussion.blocked;
        value=0;
    }
    ReleaseSRWLockExclusive(&concussionLock);
    // Always call the original, including zero: it owns the scalar cache,
    // render-resource publication/delegates and the bool return contract.
    return originalConcussionSetter(instance,name,value);
}
BOOL CALLBACK initializeConcussion(PINIT_ONCE,void*,void**) {
    const auto game=GetModuleHandleW(nullptr);const auto image=reinterpret_cast<const unsigned char*>(game);
    if (!verifiedImageIdentity(game) || !concussionProfileBytes(image)) {concussion.error=2;return TRUE;}
    if (!state.ready) {concussion.error=3;return TRUE;}
    concussionArrayGlobals={reinterpret_cast<std::uintptr_t>(image)+0xa0e68d0,reinterpret_cast<std::uintptr_t>(image)+0xa0e68e4};
    auto target=const_cast<unsigned char*>(image)+concussionSetterRva;
    if (MH_CreateHook(target,reinterpret_cast<void*>(&concussionSetterHook),reinterpret_cast<void**>(&originalConcussionSetter))!=MH_OK) {concussion.error=4;return TRUE;}
    if (MH_EnableHook(target)!=MH_OK) {MH_RemoveHook(target);concussion.error=6;return TRUE;}
    concussion.ready=true;return TRUE;
}
void concussionReport() {
    ConcussionState s;AcquireSRWLockShared(&concussionLock);s=concussion;ReleaseSRWLockShared(&concussionLock);
    const auto path=root+L"native-concussion-status.txt",temp=path+L".tmp";FILE* f=nullptr;
    if (_wfopen_s(&f,temp.c_str(),L"wb") || !f) return;
    const bool active=s.instance && GetTickCount64()-s.refreshed<=leaseMilliseconds;
    const bool wrote=std::fprintf(f,"ZFPVC21 %u %u %llu %llu %u\n",s.ready?1u:0u,active?1u:0u,
        static_cast<unsigned long long>(s.token),static_cast<unsigned long long>(s.blocked),s.error)>0;
    const int closed=std::fclose(f);
    if (wrote && !closed) MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);else DeleteFileW(temp.c_str());
}
bool concussionParseControl(const char* text,ConcussionState& candidate) {
    // Version44 is deliberately distinct: an older DLL must reject dual scope,
    // rather than silently report ready after accepting only the first name.
    if (!text || std::strchr(text,'-') || std::strchr(text,'+')) return false;
    unsigned long long token=0,world=0,collection=0;
    // Scan wide before narrowing: an overflowing decimal FName index must not
    // wrap onto an otherwise valid target in the collection's name table.
    unsigned long long comparison=0,number=0,secondaryComparison=0,secondaryNumber=0;char extra=0;
    bool parsed=false;
    if (!std::strncmp(text,"ZFPVC21 ",8)) {
        parsed=sscanf_s(text,"ZFPVC21 %llu %llx %llx %llu %llu %c",
            &token,&world,&collection,&comparison,&number,&extra,1u)==5;
    } else if (!std::strncmp(text,"ZFPVC44 ",8)) {
        parsed=sscanf_s(text,"ZFPVC44 %llu %llx %llx %llu %llu %llu %llu %c",
            &token,&world,&collection,&comparison,&number,&secondaryComparison,&secondaryNumber,&extra,1u)==7 &&
            secondaryComparison>0 && secondaryComparison<0xffffffffu && secondaryComparison!=comparison && secondaryNumber==0;
    }
    candidate.token=token;candidate.world=world;candidate.collection=collection;
    candidate.name=static_cast<std::uint64_t>(number)<<32|comparison;
    candidate.secondaryName=static_cast<std::uint64_t>(secondaryNumber)<<32|secondaryComparison;
    return parsed && token>0 && comparison>0 && comparison<0xffffffffu && number==0;
}
}
extern "C" __declspec(dllexport) int zonefpv_concussion_arm(void*) {
    InitOnceExecuteOnce(&initialized,initialize,nullptr,nullptr);
    InitOnceExecuteOnce(&concussionInitialized,initializeConcussion,nullptr,nullptr);
    quickConcussionInstance.store(0,std::memory_order_release);
    ConcussionState candidate;
    FILE* f=nullptr;bool parsed=false;const auto path=root+L"native-concussion-control.txt";
    if (!_wfopen_s(&f,path.c_str(),L"rb") && f) {
        char text[192]{};const auto size=std::fread(text,1,sizeof(text)-1,f);std::fclose(f);
        parsed=size>0 && size<sizeof(text)-1 && !std::memchr(text,0,size) && concussionParseControl(text,candidate);
    }
    DeleteFileW(path.c_str());
    const bool safe=concussion.ready && parsed && concussionFindInstance(candidate);
    AcquireSRWLockExclusive(&concussionLock);
    if (safe) {
        candidate.ready=true;candidate.refreshed=GetTickCount64();concussion=candidate;
        quickConcussionInstance.store(candidate.instance,std::memory_order_release);
    } else {concussion.instance=0;concussion.token=candidate.token;if (concussion.ready)concussion.error=parsed?9:8;}
    ReleaseSRWLockExclusive(&concussionLock);concussionReport();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_concussion_tick(void*) {
    AcquireSRWLockExclusive(&concussionLock);
    if (concussion.instance) {
        if (concussionSame(concussion)) concussion.refreshed=GetTickCount64();
        else {quickConcussionInstance.store(0,std::memory_order_release);concussion.instance=0;concussion.error=9;}
    }
    ReleaseSRWLockExclusive(&concussionLock);return 0;
}
extern "C" __declspec(dllexport) int zonefpv_concussion_poll(void*) {concussionReport();return 0;}
extern "C" __declspec(dllexport) int zonefpv_concussion_disarm(void*) {
    quickConcussionInstance.store(0,std::memory_order_release);
    AcquireSRWLockExclusive(&concussionLock);concussion.instance=0;ReleaseSRWLockExclusive(&concussionLock);
    concussionReport();return 0;
}
