#pragma once
// Native InventoryNew::InventoryWidgetTakeAllItems -> 10bf72e transfers the
// existing container into the player's inventory. The old interaction event
// 2f92496 opens loot UI; it is deliberately not called. No substitute is spawned.
namespace {
struct ArtifactPickupState {
    std::uint64_t token=0;
    std::uintptr_t pawn=0,actor=0,component=0,container=0;
    std::uintptr_t playerCore=0,inventory=0,destination=0,manager=0,wrapper=0,detail=0;
    std::uint32_t item=0xffffffffu,containerUID=0xffffffffu,ownerUID=0xffffffffu;
    std::uint32_t destinationUID=0xffffffffu;
    ObjectIdentity actorIdentity{},pawnIdentity{},componentIdentity{};
    ULONGLONG started=0;
    unsigned code=0,validationStage=0,cleanup=0;
    std::uint32_t playerGuid=0xffffffffu,expectedPlayerGuid=0xffffffffu;
} artifactPickup;
SRWLOCK artifactLock=SRWLOCK_INIT;
struct ArtifactLockGuard {
    bool held=TryAcquireSRWLockExclusive(&artifactLock)!=FALSE;
    ~ArtifactLockGuard() {if (held) ReleaseSRWLockExclusive(&artifactLock);}
};
template<class T> bool artifactRead(std::uintptr_t at,T& value) {
    if (at<0x10000 || at>=0x0000800000000000ull) return false;
    __try {std::memcpy(&value,reinterpret_cast<const void*>(at),sizeof(value));}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return true;
}
bool artifactItems(std::uintptr_t container,std::uint32_t& item,int& count) {
    std::uintptr_t data=0;
    if (!artifactRead(container+0x118,count) || count<0 || count>1) return false;
    if (!count) return true;
    return artifactRead(container+0x110,data) && artifactRead(data,item) && item<0xfffffff0u;
}
constexpr unsigned char artifactPrologue[]={0x41,0x57,0x41,0x56,0x56,0x57,0x53,0x48,0x83,0xec,0x20,0x48,0x89,0xd6,0x48,0x8b,0xb9,0x98,0,0,0,0x48,0x85,0xff};
// Read the same player UID global as the native callback. v10 used a mistyped
// absolute RVA (aefc140); the installed RIP-relative operand resolves to 9eec140.
constexpr unsigned char artifactPlayerGuidLoad[]={0x48,0x8b,0x86,0x50,0x06,0,0,0x8b,0x40,0x10,0x3b,0x05,0x5f,0x8a,0x69,0x03};
constexpr unsigned char artifactTransferPrologue[]={0x41,0x57,0x41,0x56,0x41,0x55,0x41,0x54,0x56,0x57,0x55,0x53,0x48,0x83,0xec,0x48};
constexpr unsigned char artifactTransferABI[]={0x48,0x8b,0x80,0xc0,0x01,0,0,0x44,0x8b,0x40,0x08,0x48,0x8b,0x86,0xe0,0x06,0,0,0x8b,0x50,0x08,0x48,0x89,0xf9,0x41,0xb1,0x01,0xe8,0x0a,0x1a,0xd5,0xfd};
constexpr unsigned char artifactManagerLoad[]={0x48,0x8b,0x3d,0xc1,0xc7,0xf6,0x06};
constexpr unsigned char artifactPoolLoad[]={0x48,0x8d,0x1d,0xf2,0x4d,0xd5,0x09};
constexpr unsigned char artifactInventoryChain[]={0x48,0x8b,0x81,0x50,0x06,0,0,0x48,0x8b,0x88,0x78,0x06,0,0,0x48,0x85,0xc9,0x74,0x2e,0xe8,0x99,0x96,0x41,0xfa};
constexpr unsigned char artifactInventoryGetter[]={0x48,0x89,0xd0,0x48,0x8b,0x89,0xc0,0x01,0,0,0x8b,0x49,0x08,0x89,0x0a,0xc3};
constexpr unsigned char artifactCleanupPrologue[]={0x56,0x48,0x83,0xec,0x40,0x48,0x89,0xce,0x48,0x8b,0x05,0x93,0x1a,0x5b,0x03};
struct ArtifactProfileProof {
    // image, callback, transfer, ABI, manager, pool, inventory, getter, cleanup, UID.
    unsigned failures=0;
    std::uintptr_t image=0,transfer=0,playerGuidAddress=0,managerAddress=0,poolAddress=0;
} artifactProfileProof;
ArtifactProfileProof artifactProfileBytes(const unsigned char* image) {
    ArtifactProfileProof proof;proof.image=reinterpret_cast<std::uintptr_t>(image);
    if (!bytesMatch(image,0x6853690,artifactPrologue,sizeof(artifactPrologue))) proof.failures|=2;
    if (!bytesMatch(image,0x10bf72e,artifactTransferPrologue,sizeof(artifactTransferPrologue))) proof.failures|=4;
    if (!bytesMatch(image,0x336dd04,artifactTransferABI,sizeof(artifactTransferABI))) proof.failures|=8;
    proof.transfer=proof.image+0x10bf72e;
    std::int32_t displacement=0;
    if (!bytesMatch(image,0x336dce8,artifactManagerLoad,sizeof(artifactManagerLoad)) ||
        !artifactRead(proof.image+0x336dceb,displacement)) proof.failures|=16;
    else proof.managerAddress=proof.image+0x336dcef+displacement;
    if (!bytesMatch(image,0xab8bb7,artifactPoolLoad,sizeof(artifactPoolLoad)) ||
        !artifactRead(proof.image+0xab8bba,displacement)) proof.failures|=32;
    else proof.poolAddress=proof.image+0xab8bbe+displacement;
    if (!bytesMatch(image,0x6b6e74f,artifactInventoryChain,sizeof(artifactInventoryChain))) proof.failures|=64;
    if (!bytesMatch(image,0x5378e8,artifactInventoryGetter,sizeof(artifactInventoryGetter))) proof.failures|=128;
    if (!bytesMatch(image,0x68ea01e,artifactCleanupPrologue,sizeof(artifactCleanupPrologue))) proof.failures|=256;
    std::int32_t uidDisplacement=0;
    if (!bytesMatch(image,0x68536d1,artifactPlayerGuidLoad,sizeof(artifactPlayerGuidLoad)) ||
        !artifactRead(proof.image+0x68536dd,uidDisplacement)) proof.failures|=512;
    else proof.playerGuidAddress=proof.image+0x68536e1+uidDisplacement;
    return proof;
}
bool artifactProfile() {
    const auto game=GetModuleHandleW(nullptr);
    // initialize() detours the damage receiver. The receiver's original byte
    // profile must only be checked before hooking; it is not an artifact ABI.
    // Retain the executable identity and all artifact-specific runtime guards.
    artifactProfileProof=ArtifactProfileProof{};
    artifactProfileProof.image=reinterpret_cast<std::uintptr_t>(game);
    if (!verifiedImageIdentity(game)) {artifactProfileProof.failures=1;return false;}
    artifactProfileProof=artifactProfileBytes(reinterpret_cast<const unsigned char*>(game));
    return artifactProfileProof.failures==0;
}
bool artifactPoolContainer(std::uint32_t uid,std::uintptr_t expected) {
    if (uid>=0xfffffff0u || !expected) return false;
    auto index=uid&0x7ffffffu;auto block=artifactProfileProof.poolAddress;
    // The native resolver masks UID generations then walks 0x800-slot blocks.
    // Bound that walk and verify the complete UID and exact original pointer.
    if (index>=0x100000u) return false;
    while (index>=0x800u) {if (!artifactRead(block,block) || !block) return false;index-=0x800u;}
    const auto slot=block+static_cast<std::uintptr_t>(index)*0x1d0+0x10;
    std::uint32_t actual=0;
    return slot==expected && artifactRead(slot+8,actual) && actual==uid;
}
bool artifactMembership(std::uintptr_t container,std::uint32_t item,bool& found,int& count) {
    std::uintptr_t data=0;int capacity=0;found=false;
    if (!artifactRead(container+0x118,count) || !artifactRead(container+0x11c,capacity) ||
        count<0 || count>16384 || capacity<count || capacity>65536) return false;
    if (!count) return true;
    if (!artifactRead(container+0x110,data) || !data) return false;
    for (int i=0;i<count;++i) {
        std::uint32_t got=0;
        if (!artifactRead(data+static_cast<std::uintptr_t>(i)*16,got)) return false;
        if (got==item) found=true;
    }
    return true;
}
bool artifactDestinationSame(const ArtifactPickupState& s) {
    CoreInfo player;std::uintptr_t inventory=0,destination=0,manager=0;
    return coreInfo(s.pawn,player) && sameIdentity(player.identity,s.pawnIdentity) &&
        player.core==s.playerCore && player.guid==s.playerGuid &&
        artifactRead(player.core+0x678,inventory) && inventory==s.inventory &&
        artifactRead(inventory+0x1c0,destination) && destination==s.destination &&
        artifactRead(artifactProfileProof.managerAddress,manager) && manager==s.manager &&
        artifactPoolContainer(s.destinationUID,destination);
}
unsigned artifactValidate(ArtifactPickupState& s) {
    const auto image=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    CoreInfo player;
    std::uintptr_t owner=0,component=0,container=0,wrapper=0,detail=0,pending=0;
    std::uint32_t flags=0;
    unsigned char removed=0;
    s.validationStage=1;if (!coreInfo(s.pawn,player)) return 8;
    s.playerGuid=player.guid;
    s.validationStage=2;if (player.identity.vtable!=image+0x8d8df10) return 8;
    s.validationStage=3;if (!artifactRead(artifactProfileProof.playerGuidAddress,s.expectedPlayerGuid)) return 8;
    s.validationStage=4;if (s.playerGuid!=s.expectedPlayerGuid) return 8;
    s.validationStage=5;if (!objectIdentity(s.actor,s.actorIdentity) || s.actorIdentity.vtable!=image+0x8c0bad0) return 8;
    s.validationStage=6;if (!artifactRead(s.actor+8,flags) || (flags&0x18030)) return 8;
    s.validationStage=7;if (!artifactRead(s.actor+0x2f0,component) || !objectIdentity(component,s.componentIdentity)) return 8;
    s.validationStage=8;if (s.componentIdentity.vtable!=image+0x8c13f10) return 8;
    s.validationStage=9;if (!artifactRead(component+0x98,owner) || owner!=s.actor) return 8;
    s.validationStage=10;if (!artifactRead(s.actor+0x2b8,container) || !container) return 8;
    s.validationStage=11;if (!artifactRead(s.actor+0x3d8,wrapper) || !artifactRead(wrapper+0x30,detail)) return 8;
    s.validationStage=12;if (!artifactRead(detail+0xb2,removed) || removed) return 8;
    // PC already owns an animation pickup container. Do not replace that
    // pending native transaction with a second artifact interaction.
    s.validationStage=13;if (!artifactRead(s.pawn+0x1190,pending) || pending) return 3;
    int count=0;
    s.validationStage=14;if (!artifactItems(container,s.item,count) || count!=1) return 9;
    s.validationStage=15;if (!artifactRead(container+8,s.containerUID) || !artifactRead(container+0xdc,s.ownerUID)) return 9;
    s.pawnIdentity=player.identity;s.component=component;s.container=container;s.wrapper=wrapper;s.detail=detail;
    s.playerCore=player.core;
    s.validationStage=16;
    if (!artifactPoolContainer(s.containerUID,container)) return 8;
    s.validationStage=17;
    if (!artifactRead(player.core+0x678,s.inventory) || !s.inventory ||
        !artifactRead(s.inventory+0x1c0,s.destination) || s.destination==container ||
        !artifactRead(s.destination+8,s.destinationUID) || !artifactPoolContainer(s.destinationUID,s.destination)) return 8;
    s.validationStage=18;
    if (!artifactRead(artifactProfileProof.managerAddress,s.manager) ||
        s.manager<0x10000 || s.manager>=0x0000800000000000ull || (s.manager&7)) return 8;
    bool found=false;int destinationCount=0;
    s.validationStage=19;
    if (!artifactMembership(s.destination,s.item,found,destinationCount) || found) return 9;
    s.validationStage=0;
    return 0;
}
using ArtifactTransferCallback=void(__fastcall*)(void*,std::uint32_t,std::uint32_t,bool);
using ArtifactCleanupCallback=void(__fastcall*)(void*);
bool artifactContainerSame(const ArtifactPickupState& s) {
    ObjectIdentity identity;std::uintptr_t container=0;std::uint32_t uid=0,owner=0;
    return objectIdentity(s.actor,identity) && sameIdentity(identity,s.actorIdentity) &&
        artifactRead(s.actor+0x2b8,container) && container==s.container &&
        artifactRead(container+8,uid) && uid==s.containerUID &&
        artifactRead(container+0xdc,owner) && owner==s.ownerUID;
}
bool artifactInvokeTransfer(const ArtifactPickupState& s,ArtifactTransferCallback callback) {
    ObjectIdentity pawn,component;std::uint32_t pawnFlags=0,componentFlags=0;std::uintptr_t owner=0;
    if (!callback || !objectIdentity(s.pawn,pawn) || !sameIdentity(pawn,s.pawnIdentity) ||
        !objectIdentity(s.component,component) || !sameIdentity(component,s.componentIdentity) ||
        !artifactRead(s.pawn+8,pawnFlags) || (pawnFlags&0x18030) ||
        !artifactRead(s.component+8,componentFlags) || (componentFlags&0x18030) ||
        !artifactRead(s.component+0x98,owner) || owner!=s.actor || !artifactContainerSame(s) ||
        !artifactPoolContainer(s.containerUID,s.container) || !artifactDestinationSame(s)) return false;
    std::uint32_t item=0;int count=0,destinationCount=0;bool found=false;
    if (!artifactItems(s.container,item,count) || count!=1 || item!=s.item ||
        !artifactMembership(s.destination,s.item,found,destinationCount) || found) return false;
    // Same manager/container ABI used by native Take All. A validated source
    // contains exactly our original artifact, so no unrelated item can move.
    // Native inventory code retains its quest/state/container processing.
    __try {
        callback(reinterpret_cast<void*>(s.manager),s.containerUID,s.destinationUID,true);
    } __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return true;
}
bool artifactInvoke(const ArtifactPickupState& s) {
    return artifactInvokeTransfer(s,reinterpret_cast<ArtifactTransferCallback>(artifactProfileProof.transfer));
}
unsigned artifactObserve(ArtifactPickupState& s) {
    bool found=false;int destinationCount=0;
    if (!artifactDestinationSame(s) || !artifactMembership(s.destination,s.item,found,destinationCount)) return 8;
    std::uint32_t item=0xffffffffu;int count=0;
    if (!artifactPoolContainer(s.containerUID,s.container) || !artifactItems(s.container,item,count)) return 8;
    // Both sides must prove the transfer: exact original UID now belongs to
    // the verified player inventory AND its original container is empty.
    // UI opening, a disappearing actor or an empty source alone never succeeds.
    if (count==0 && found) return 1;
    if (count==0 || found) return 12;
    if (item!=s.item) return 8;
    return GetTickCount64()-s.started>10000?10u:0u;
}
unsigned artifactTransferResult(ArtifactPickupState& s,bool invoked) {
    // Take All can finish the inventory mutation before a later callback
    // raises an exception. The exact UID/source proof decides success, not
    // whether the callback returned normally. Never retry a completed move.
    const auto observed=artifactObserve(s);
    return observed==1?1u:invoked?observed:11u;
}
void artifactFinalize(ArtifactPickupState& s,ArtifactCleanupCallback cleanup) {
    if (s.code!=1 || s.cleanup) return;
    s.cleanup=2;
    ObjectIdentity actor;std::uintptr_t wrapper=0,detail=0;std::uint32_t flags=0;
    if (!cleanup || !objectIdentity(s.actor,actor) || !sameIdentity(actor,s.actorIdentity) ||
        !artifactRead(s.actor+8,flags) || (flags&0x18030) ||
        !artifactRead(s.actor+0x3d8,wrapper) || wrapper!=s.wrapper ||
        !artifactRead(wrapper+0x30,detail) || detail!=s.detail) return;
    // The original artifact interaction calls this exact native retirement
    // routine. Invoke it only AFTER confirmed transfer, never on a failed move.
    // It updates the genuine artifact state/effects; no DestroyActor substitute.
    __try {cleanup(reinterpret_cast<void*>(s.actor));s.cleanup=1;}
    __except(EXCEPTION_EXECUTE_HANDLER) {s.cleanup=3;}
}
void artifactReport(bool ready,const ArtifactPickupState& s) {
    const auto validation=root+L"native-artifact-validation.txt",validationTemp=validation+L".tmp";
    FILE* detail=nullptr;
    if (!_wfopen_s(&detail,validationTemp.c_str(),L"wb") && detail) {
        const bool wrote=std::fprintf(detail,"ZFPVAV12 %llu %u %u %u %u %u %u\n",
            static_cast<unsigned long long>(s.token),s.validationStage,s.playerGuid,s.expectedPlayerGuid,
            s.containerUID,s.destinationUID,s.cleanup)>0;
        const int closed=std::fclose(detail);
        if (wrote && !closed) MoveFileExW(validationTemp.c_str(),validation.c_str(),MOVEFILE_REPLACE_EXISTING);
        else DeleteFileW(validationTemp.c_str());
    }
    const auto profile=root+L"native-artifact-profile.txt",profileTemp=profile+L".tmp";
    FILE* diagnostic=nullptr;
    if (!_wfopen_s(&diagnostic,profileTemp.c_str(),L"wb") && diagnostic) {
        const bool wrote=std::fprintf(diagnostic,"ZFPVAP12 %llu %u %llx %llx\n",
            static_cast<unsigned long long>(s.token),artifactProfileProof.failures,
            static_cast<unsigned long long>(artifactProfileProof.image),
            static_cast<unsigned long long>(artifactProfileProof.transfer))>0;
        const int closed=std::fclose(diagnostic);
        if (wrote && !closed) MoveFileExW(profileTemp.c_str(),profile.c_str(),MOVEFILE_REPLACE_EXISTING);
        else DeleteFileW(profileTemp.c_str());
    }
    const auto path=root+L"native-artifact-status.txt",temp=path+L".tmp";
    FILE* f=nullptr;if (_wfopen_s(&f,temp.c_str(),L"wb") || !f) return;
    const bool good=std::fprintf(f,"ZFPVA12 %u %llu %llx %u %u\n",ready?1u:0u,
        static_cast<unsigned long long>(s.token),static_cast<unsigned long long>(s.actor),s.item,s.code)>0;
    const int closed=std::fclose(f);
    if (good && !closed) MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);
    else DeleteFileW(temp.c_str());
}
}
extern "C" __declspec(dllexport) int zonefpv_artifact_start(void*) {
    InitOnceExecuteOnce(&initialized,initialize,nullptr,nullptr);
    ArtifactLockGuard guard;if (!guard.held) return 0;
    ArtifactPickupState candidate;unsigned long long token=0,pawn=0,actor=0;FILE* f=nullptr;
    bool parsed=false;const auto path=root+L"native-artifact-control.txt";
    if (!_wfopen_s(&f,path.c_str(),L"rb") && f) {
        parsed=fscanf_s(f,"ZFPVA12 %llu %llx %llx",&token,&pawn,&actor)==3 && token>0;
        int c=0;while ((c=std::fgetc(f))!=EOF) if (!std::isspace(static_cast<unsigned char>(c))) parsed=false;
        std::fclose(f);
    }
    DeleteFileW(path.c_str());candidate.token=token;candidate.pawn=pawn;candidate.actor=actor;
    const bool ready=artifactProfile();candidate.code=!ready?2u:!parsed?7u:artifactValidate(candidate);
    if (artifactPickup.token && artifactPickup.code==0) {
        artifactPickup.code=artifactObserve(artifactPickup);
        if (!artifactPickup.code) {candidate.code=3;artifactReport(ready,candidate);return 0;}
    }
    if (!candidate.code) {
        candidate.started=GetTickCount64();
        candidate.code=artifactTransferResult(candidate,artifactInvoke(candidate));
    }
    artifactFinalize(candidate,reinterpret_cast<ArtifactCleanupCallback>(artifactProfileProof.image+0x68ea01e));
    artifactPickup=candidate;artifactReport(ready,artifactPickup);return 0;
}
extern "C" __declspec(dllexport) int zonefpv_artifact_poll(void*) {
    InitOnceExecuteOnce(&initialized,initialize,nullptr,nullptr);
    ArtifactLockGuard guard;if (!guard.held) return 0;
    if (artifactPickup.token && artifactPickup.code==0) artifactPickup.code=artifactObserve(artifactPickup);
    artifactFinalize(artifactPickup,reinterpret_cast<ArtifactCleanupCallback>(artifactProfileProof.image+0x68ea01e));
    artifactReport(artifactProfile(),artifactPickup);return 0;
}
