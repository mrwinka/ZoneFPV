#pragma once
#include <cwchar>
#include <cerrno>
#include <cstdlib>
// Remove only captured local-pawn concussion/blast feedback through the game's
// normal effect lifecycle. SID is the game's signed string-table key, not FName.
namespace {
constexpr unsigned char source_remove[]={0x41,0x57,0x41,0x56,0x56,0x57,0x55,0x53,0x48,0x81,0xec,0x98,0x00,0x00,0x00,0x44,0x89,0xcd,0x44,0x89,0xc7,0x48,0x89,0xd6,0x48,0x89,0xcb};
constexpr unsigned char source_retain[]={0x56,0x57,0x53,0x48,0x83,0xec,0x20,0x85,0xd2,0x7e,0x3b,0x89,0xd6,0x48,0x89,0xcf,0x48,0x8d,0x99,0x68,0x00,0x02,0x00};
constexpr unsigned char source_core[]={0x4c,0x8b,0xb3,0x68,0x06,0x00,0x00,0x44,0x8b,0x7b,0x10};
constexpr unsigned char source_registry[]={0x48,0x8d,0x93,0xb0,0x00,0x00,0x00,0x40,0x88,0x6c,0x24,0x20,0x4c,0x8d,0x44,0x24,0x34,0x48,0x89,0xd9,0x41,0x89,0xf9};
constexpr unsigned char source_stride[]={0x4c,0x63,0xe5,0x49,0xc1,0xe4,0x07,0x4c,0x8b,0x2f,0x4d,0x01,0xe5};
constexpr unsigned char source_match[]={0x8a,0x43,0x20,0x48,0x8b,0x4f,0x08,0x3a,0x01,0x0f,0x85,0x34,0xff,0xff,0xff,0x8b,0x43,0x10,0x48,0x8b,0x4f,0x10,0x3b,0x01};
constexpr unsigned char source_callbacks[]={0x49,0x8b,0x07,0x4c,0x89,0xf9,0x48,0x8d,0x5c,0x24,0x30,0x48,0x89,0xda,0xff,0x50,0x20,0x48,0x89,0xf9,0x89,0xea,0x41,0xb8,0x01,0x00,0x00,0x00};
constexpr unsigned char source_manager[]={0x48,0x8d,0x0d,0x8c,0x79,0x56,0x04,0x48,0x89,0xf2,0x45,0x31,0xc0};
constexpr unsigned char source_signedTable[]={0x85,0xf6,0x4c,0x8d,0x15,0x02,0xd7,0xea,0x0a,0x48,0x8d,0x05,0x6b,0xd6,0xe8,0x0a,0x48,0x89,0xc2,0x49,0x0f,0x48,0xd2};
constexpr unsigned char source_sidField[]={0x8b,0x72,0x08,0x85,0xf6};
constexpr unsigned char source_signedKey[]={0x41,0x89,0xf0,0x41,0xc1,0xf8,0x1f,0x41,0x31,0xf0};
constexpr unsigned char source_stringSlot[]={0x49,0x63,0xca,0x48,0xc1,0xe1,0x05,0x46,0x8b,0x4c,0x02,0x08,0x44,0x8b,0x54,0x08,0x08};
constexpr unsigned char source_pawnCore[]={0x48,0x8b,0x81,0x50,0x06,0x00,0x00};
constexpr const wchar_t* sourceNames[]={
    L"ConcussionComposite",L"ConcussionBlurPostProcess",L"SFXConcussionLoopStart",L"ConcussionCameraShake",
    L"ConcussionVelocityChange",L"ConcussionModifyRotate2DAxis",L"ConcussionBlockJump",L"ConcussionInputInertia2DAxis",
    L"ConcussionBlockAim",L"ConcussionBlockSprint",L"ApplyBaseConcussion",
    L"ConcussionComposite_Buttstock",L"ConcussionBlurPostProcess_Buttstock",L"ButtStroke_CameraShake",
    L"ConcussionVelocityChange_Buttstock",L"ConcussionModifyRotate2DAxis_Buttstock",L"ConcussionBlockJump_Buttstock",
    L"ConcussionInputInertia2DAxis_Buttstock",L"ConcussionBlockAim_Buttstock",L"ConcussionBlockSprint_Buttstock",
    L"FaustPSYStrikeConcussionComposite",L"ConcussionBlurPostProcess_2",L"SFXConcussionLoopStart_2",L"ConcussionCameraShake_2",
    L"ConcussionVelocityChange_2",L"ConcussionModifyRotate2DAxis_2",L"ConcussionBlockMovement",L"ConcussionInputInertia2DAxis_2",
    L"ConcussionBlockAim_2",L"ConcussionBlockShoot",L"ConcussionBlockThrow",
    L"ExplosionDirtPostProcess",L"ExplosionWaterPostProcess",L"ExplosionRockPostProcess",L"ExplosionWoodPostProcess",L"ExplosionSandPostProcess"
};
using SourceRetain=void(__fastcall*)(void*,std::int32_t);
using SourceRemove=void(__fastcall*)(void*,std::int32_t*,std::uint32_t,unsigned char);
SourceRetain sourceRetain=nullptr;SourceRemove sourceRemove=nullptr;
std::uintptr_t sourceStringManager=0;
INIT_ONCE sourceInitialized=INIT_ONCE_STATIC_INIT;
struct SourceDescriptor {std::int32_t sid=0;std::uint32_t guid=0;unsigned char type=0;};
struct SourceState {
    bool ready=false,active=false;unsigned error=0;
    std::uint64_t token=0,matched=0,removed=0;
    std::uintptr_t pawn=0,world=0,core=0,processor=0;
    std::uint32_t guid=0;
    ObjectIdentity pawnIdentity{},worldIdentity{};
    std::int32_t pawnSerial=0,worldSerial=0;
    ULONGLONG refreshed=0;
} sourceState;
bool sourceProfile(const unsigned char* image) {
    return bytesMatch(image,0x292b6c,source_remove,sizeof(source_remove)) &&
        bytesMatch(image,0x2636a70,source_retain,sizeof(source_retain)) &&
        bytesMatch(image,0x2f54785,source_core,sizeof(source_core)) &&
        bytesMatch(image,0x292cae,source_registry,sizeof(source_registry)) &&
        bytesMatch(image,0x292e84,source_stride,sizeof(source_stride)) &&
        bytesMatch(image,0x293185,source_match,sizeof(source_match)) &&
        bytesMatch(image,0x292fdb,source_callbacks,sizeof(source_callbacks)) &&
        bytesMatch(image,0x6bb8dcd,source_manager,sizeof(source_manager)) &&
        bytesMatch(image,0x2930e5,source_signedTable,sizeof(source_signedTable)) &&
        bytesMatch(image,0x293076,source_sidField,sizeof(source_sidField)) &&
        bytesMatch(image,0x2930fc,source_signedKey,sizeof(source_signedKey)) &&
        bytesMatch(image,0x293162,source_stringSlot,sizeof(source_stringSlot)) &&
        bytesMatch(image,0x68ffb40,source_pawnCore,sizeof(source_pawnCore)) &&
        // This immutable interior instruction window proves the GUObject
        // globals used by capture. The MPC setter's entry is already detoured
        // by our own concussion gate when source cleanup first starts; source
        // cleanup does not call that setter or need its mutable prologue.
        bytesMatch(image,0x24e5203,concussion_worldBinding,sizeof(concussion_worldBinding));
}
bool sourceNamed(std::int32_t sid) {
    if (!sid) return false;
    // Native SID equality resolves positive dynamic keys and complemented
    // negative static keys through separate arrays of 32-byte string entries.
    const auto key=sid<0?~static_cast<std::uint32_t>(sid):static_cast<std::uint32_t>(sid);
    if (key>=0x1000000u) return false;
    std::uintptr_t chunk=0,data=0;std::int32_t length=0;
    const auto table=sourceStringManager+(sid<0?0x20090:0);
    if (!artifactRead(table+static_cast<std::uintptr_t>(key>>10)*8,chunk) || !chunk) return false;
    const auto entry=chunk+static_cast<std::uintptr_t>(key&0x3ffu)*32;
    if (!artifactRead(entry,data) || !artifactRead(entry+8,length) || !data || length<2 || length>64) return false;
    wchar_t text[64]{};
    for (int i=0;i<length;++i) if (!artifactRead(data+static_cast<std::uintptr_t>(i)*2,text[i])) return false;
    if (text[length-1]!=0) return false;
    for (int i=0;i<length-1;++i) if (text[i]<32 || text[i]>126) return false;
    for (const auto* name:sourceNames) if (!std::wcscmp(text,name)) return true;
    return false;
}
bool sourceSame(const SourceState& s) {
    std::uintptr_t core=0,processor=0;std::uint32_t guid=0;
    return concussionLive(s.pawn,s.pawnIdentity,s.pawnSerial) && concussionLive(s.world,s.worldIdentity,s.worldSerial) &&
        readCore(s.pawn,core) && core==s.core && coreGuid(core,guid) && guid==s.guid &&
        artifactRead(core+0x668,processor) && processor==s.processor;
}
bool sourceCapture(SourceState& s) {
    return concussionCapture(s.pawn,s.pawnIdentity,s.pawnSerial) && concussionCapture(s.world,s.worldIdentity,s.worldSerial) &&
        readCore(s.pawn,s.core) && coreGuid(s.core,s.guid) && artifactRead(s.core+0x668,s.processor) &&
        s.processor>=0x10000 && s.processor<0x0000800000000000ull && !(s.processor&7);
}
bool sourceArray(std::uintptr_t processor,std::uintptr_t& entries,std::int32_t& count) {
    std::int32_t capacity=0;
    return artifactRead(processor+0xb0,entries) && artifactRead(processor+0xb8,count) && artifactRead(processor+0xbc,capacity) &&
        count>=0 && count<=512 && capacity>=count && capacity<=65536 && (!count || (entries>=0x10000 && !(entries&7)));
}
bool sourceDescriptor(std::uintptr_t entry,SourceDescriptor& d) {
    return artifactRead(entry+8,d.sid) && artifactRead(entry+0x10,d.guid) && artifactRead(entry+0x20,d.type);
}
bool sourceEqual(const SourceDescriptor& a,const SourceDescriptor& b) {return a.sid==b.sid && a.guid==b.guid && a.type==b.type;}
bool sourceCount(const SourceState& s,const SourceDescriptor& d,unsigned& matches) {
    std::uintptr_t entries=0;std::int32_t count=0;matches=0;
    if (!sourceSame(s) || !sourceArray(s.processor,entries,count)) return false;
    for (int i=0;i<count;++i) {
        SourceDescriptor current;if (!sourceDescriptor(entries+static_cast<std::uintptr_t>(i)*128,current)) return false;
        if (sourceEqual(d,current)) ++matches;
    }
    return true;
}
bool sourceSelectedCount(const SourceState& s,const SourceDescriptor* selected,unsigned size,unsigned& matches) {
    std::uintptr_t entries=0;std::int32_t count=0;matches=0;
    if (!sourceSame(s) || !sourceArray(s.processor,entries,count)) return false;
    for (int i=0;i<count;++i) {
        SourceDescriptor current;if (!sourceDescriptor(entries+static_cast<std::uintptr_t>(i)*128,current)) return false;
        for (unsigned j=0;j<size;++j) if (sourceEqual(current,selected[j])) {++matches;break;}
    }
    return true;
}
bool sourceNormalRemove(std::uintptr_t processor,const SourceDescriptor& d) {
    // The ordinary removal takes ownership of an added SID reference and
    // zeroes its argument. Never pass borrowed entry storage or clear arrays.
    std::int32_t owned=d.sid;
    __try {sourceRetain(reinterpret_cast<void*>(sourceStringManager),owned);
        sourceRemove(reinterpret_cast<void*>(processor),&owned,d.guid,d.type);}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return owned==0;
}
unsigned sourceClean(SourceState& s) {
    if (!s.active || GetTickCount64()-s.refreshed>leaseMilliseconds || !sourceSame(s)) return 9;
    std::uintptr_t entries=0;std::int32_t count=0;
    if (!sourceArray(s.processor,entries,count)) return 10;
    std::array<SourceDescriptor,128> selected{};unsigned size=0,observed=0;
    for (int i=0;i<count;++i) {
        SourceDescriptor d;if (!sourceDescriptor(entries+static_cast<std::uintptr_t>(i)*128,d)) return 10;
        if (!sourceNamed(d.sid)) continue;
        ++observed;
        if (size<selected.size()) selected[size++]=d;
    }
    s.matched+=observed;
    for (unsigned i=0;i<size;++i) {
        unsigned before=0,after=0,totalBefore=0;
        if (!sourceCount(s,selected[i],before)) return 9;
        // A parent callback may already have retired later snapshot children.
        if (!before) continue;
        if (!sourceSelectedCount(s,selected.data(),size,totalBefore)) return 9;
        if (!sourceNamed(selected[i].sid) || !sourceSame(s) || !sourceNormalRemove(s.processor,selected[i])) return 12;
        if (!sourceSelectedCount(s,selected.data(),size,after)) return 9;
        if (after<totalBefore) s.removed+=totalBefore-after;
    }
    s.refreshed=GetTickCount64();return 0;
}
bool sourceParse(const char* text,SourceState& s) {
    if (!text || std::strncmp(text,"ZFPVCS45 ",9)) return false;
    const char* cursor=text+9;unsigned long long values[3]{};
    for (unsigned i=0;i<3;++i) {
        char field[21]{};unsigned size=0;
        while (*cursor && !std::isspace(static_cast<unsigned char>(*cursor))) {
            const bool digit=*cursor>='0' && *cursor<='9';
            const bool hex=(*cursor>='a' && *cursor<='f') || (*cursor>='A' && *cursor<='F');
            if (size>=20 || !(digit || (i && hex))) return false;
            field[size++]=*cursor++;
        }
        if (!size) return false;
        errno=0;values[i]=std::strtoull(field,nullptr,i?16:10);if (errno==ERANGE) return false;
        while (std::isspace(static_cast<unsigned char>(*cursor))) ++cursor;
    }
    if (*cursor) return false;
    s.token=values[0];s.pawn=values[1];s.world=values[2];
    return s.token>0 && s.token<=0x1fffffffffffffull && s.pawn>=0x10000 && s.pawn<0x0000800000000000ull && !(s.pawn&7) &&
        s.world>=0x10000 && s.world<0x0000800000000000ull && !(s.world&7);
}
BOOL CALLBACK initializeSource(PINIT_ONCE,void*,void**) {
    const auto game=GetModuleHandleW(nullptr);const auto image=reinterpret_cast<const unsigned char*>(game);
    if (!verifiedImageIdentity(game) || !sourceProfile(image)) {sourceState.error=2;return TRUE;}
    const auto base=reinterpret_cast<std::uintptr_t>(image);
    concussionArrayGlobals={base+0xa0e68d0,base+0xa0e68e4};
    sourceStringManager=base+0xb120760;sourceRetain=reinterpret_cast<SourceRetain>(base+0x2636a70);
    sourceRemove=reinterpret_cast<SourceRemove>(base+0x292b6c);sourceState.ready=true;return TRUE;
}
void sourceReport() {
    const auto path=root+L"native-concussion-source-status.txt",temp=path+L".tmp";FILE* f=nullptr;
    if (_wfopen_s(&f,temp.c_str(),L"wb") || !f) return;
    const bool active=sourceState.active && GetTickCount64()-sourceState.refreshed<=leaseMilliseconds;
    const bool wrote=std::fprintf(f,"ZFPVCS45 %u %u %llu %llu %llu %u\n",sourceState.ready?1u:0u,active?1u:0u,
        static_cast<unsigned long long>(sourceState.token),static_cast<unsigned long long>(sourceState.matched),
        static_cast<unsigned long long>(sourceState.removed),sourceState.error)>0;
    const int closed=std::fclose(f);
    if (wrote && !closed) MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);else DeleteFileW(temp.c_str());
}
}
extern "C" __declspec(dllexport) int zonefpv_concussion_source_arm(void*) {
    InitOnceExecuteOnce(&initialized,initialize,nullptr,nullptr);
    InitOnceExecuteOnce(&sourceInitialized,initializeSource,nullptr,nullptr);
    SourceState candidate;candidate.ready=sourceState.ready;FILE* f=nullptr;bool parsed=false;
    const auto path=root+L"native-concussion-source-control.txt";
    if (!_wfopen_s(&f,path.c_str(),L"rb") && f) {
        char text[160]{};const auto size=std::fread(text,1,sizeof(text)-1,f);std::fclose(f);
        parsed=size>0 && size<sizeof(text)-1 && !std::memchr(text,0,size) && sourceParse(text,candidate);
    }
    DeleteFileW(path.c_str());
    if (!candidate.ready) candidate.error=sourceState.error;
    else if (!parsed) candidate.error=8;
    else if (!sourceCapture(candidate)) candidate.error=9;
    else {candidate.active=true;candidate.refreshed=GetTickCount64();candidate.error=sourceClean(candidate);}
    if (candidate.error) candidate.active=false;
    sourceState=candidate;sourceReport();return 0;
}
extern "C" __declspec(dllexport) int zonefpv_concussion_source_tick(void*) {
    if (sourceState.active) {sourceState.error=sourceClean(sourceState);if (sourceState.error) sourceState.active=false;}
    return 0;
}
extern "C" __declspec(dllexport) int zonefpv_concussion_source_poll(void*) {sourceReport();return 0;}
extern "C" __declspec(dllexport) int zonefpv_concussion_source_disarm(void*) {sourceState.active=false;sourceReport();return 0;}
