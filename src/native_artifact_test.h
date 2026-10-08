// Native fixture: a genuine source container and a distinct player inventory.
#include <utility>
namespace {
ArtifactPickupState* artifactFixtureState=nullptr;
unsigned artifactFixtureMode=0,artifactFixtureCalls=0,artifactFixtureCleanups=0;
void __fastcall artifactTransferFixture(void* manager,std::uint32_t source,std::uint32_t destination,bool all) {
    const auto& s=*artifactFixtureState;++artifactFixtureCalls;
    assert(manager==reinterpret_cast<void*>(s.manager) && source==s.containerUID && destination==s.destinationUID && all);
    assert(*reinterpret_cast<unsigned char*>(s.container+0x198)==4 && "transfer must not flip the loot UI flag");
    if (artifactFixtureMode==4) RaiseException(0xe0000042,0,0,nullptr);
    if (!artifactFixtureMode) return; // Opening UI/no mutation cannot be success.
    *reinterpret_cast<int*>(s.container+0x118)=0;
    if (artifactFixtureMode==2) return; // Empty source alone is insufficient.
    auto* data=*reinterpret_cast<std::uint32_t**>(s.destination+0x110);
    data[0]=artifactFixtureMode==3?s.item+1:s.item;
    *reinterpret_cast<int*>(s.destination+0x118)=1;
    if (artifactFixtureMode==5) RaiseException(0xe0000042,0,0,nullptr);
}
void __fastcall artifactCleanupFixture(void* actor) {
    assert(actor==reinterpret_cast<void*>(artifactFixtureState->actor));
    assert(artifactObserve(*artifactFixtureState)==1 && "cleanup must follow verified inventory transfer");
    ++artifactFixtureCleanups;
}
void artifactPickupFixtureTests() {
    auto* mapped=static_cast<unsigned char*>(VirtualAlloc(nullptr,gameImageSize,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE));
    assert(mapped);const auto base=reinterpret_cast<std::uintptr_t>(mapped);
    std::memcpy(mapped+0x6853690,artifactPrologue,sizeof(artifactPrologue));
    std::memcpy(mapped+0x68536d1,artifactPlayerGuidLoad,sizeof(artifactPlayerGuidLoad));
    std::memcpy(mapped+0x10bf72e,artifactTransferPrologue,sizeof(artifactTransferPrologue));
    std::memcpy(mapped+0x336dd04,artifactTransferABI,sizeof(artifactTransferABI));
    std::memcpy(mapped+0x336dce8,artifactManagerLoad,sizeof(artifactManagerLoad));
    std::memcpy(mapped+0xab8bb7,artifactPoolLoad,sizeof(artifactPoolLoad));
    std::memcpy(mapped+0x6b6e74f,artifactInventoryChain,sizeof(artifactInventoryChain));
    std::memcpy(mapped+0x5378e8,artifactInventoryGetter,sizeof(artifactInventoryGetter));
    std::memcpy(mapped+0x68ea01e,artifactCleanupPrologue,sizeof(artifactCleanupPrologue));
    assert(artifactProfileBytes(mapped).failures==0);
    assert(artifactProfileBytes(mapped).playerGuidAddress==base+0x9eec140);
    assert(artifactProfileBytes(mapped).managerAddress==base+0xa2da4b0);
    assert(artifactProfileBytes(mapped).poolAddress==base+0xa80d9b0);
    mapped[receiveRva]=0xe9;assert(artifactProfileBytes(mapped).failures==0);
    for (const auto check:std::array<std::pair<std::uintptr_t,unsigned>,9>{{{0x6853690,2},{0x10bf72e,4},{0x336dd04,8},
        {0x336dceb,16},{0xab8bba,32},{0x6b6e74f,64},{0x5378e8,128},{0x68ea01e,256},{0x68536dd,512}}}) {
        mapped[check.first]^=1;assert(artifactProfileBytes(mapped).failures==check.second);mapped[check.first]^=1;
    }
    artifactProfileProof=artifactProfileBytes(mapped);
    alignas(8) std::array<unsigned char,0x400> actor{};
    alignas(8) std::array<unsigned char,0x11a0> pawn{};
    alignas(8) std::array<unsigned char,0x680> core{};
    alignas(8) std::array<unsigned char,0x1c8> inventory{};
    alignas(8) std::array<unsigned char,0xa0> component{};
    alignas(8) std::array<unsigned char,0x38> wrapper{};
    alignas(8) std::array<unsigned char,0xb8> detail{};
    alignas(8) std::array<std::uint32_t,8> sourceItems{},destinationItems{};
    const auto image=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    const auto source=artifactProfileProof.poolAddress+17*0x1d0+0x10;
    const auto destination=artifactProfileProof.poolAddress+18*0x1d0+0x10;
    const std::uint32_t uid=17,wrongUID=23,item=123,sourceUID=0x30000011,destinationUID=0x40000012;
    const std::uintptr_t klass=0x200000,manager=0x400000;
    const auto put=[](std::uintptr_t address,std::size_t offset,const auto& value){std::memcpy(reinterpret_cast<void*>(address+offset),&value,sizeof(value));};
    const auto a=reinterpret_cast<std::uintptr_t>(actor.data()),p=reinterpret_cast<std::uintptr_t>(pawn.data());
    const auto c=reinterpret_cast<std::uintptr_t>(component.data()),k=reinterpret_cast<std::uintptr_t>(core.data());
    const auto inv=reinterpret_cast<std::uintptr_t>(inventory.data());
    put(a,0,image+0x8c0bad0);put(a,0x10,klass);put(a,0x2b8,source);put(a,0x2f0,c);
    put(a,0x3d8,reinterpret_cast<std::uintptr_t>(wrapper.data()));
    put(reinterpret_cast<std::uintptr_t>(wrapper.data()),0x30,reinterpret_cast<std::uintptr_t>(detail.data()));
    put(p,0,image+0x8d8df10);put(p,0x10,klass);put(p,0x650,k);put(k,0x10,uid);put(k,0x678,inv);put(inv,0x1c0,destination);
    put(c,0,image+0x8c13f10);put(c,0x10,klass);put(c,0x98,a);
    put(artifactProfileProof.playerGuidAddress,0,uid);put(base+0xaefc140,0,wrongUID);
    put(artifactProfileProof.managerAddress,0,manager);
    put(source,8,sourceUID);put(source,0xdc,6u);put(source,0x110,reinterpret_cast<std::uintptr_t>(sourceItems.data()));
    put(source,0x118,1);put(source,0x11c,2);put(source,0x198,static_cast<unsigned char>(4));sourceItems[0]=item;
    put(destination,8,destinationUID);put(destination,0x110,reinterpret_cast<std::uintptr_t>(destinationItems.data()));
    put(destination,0x11c,2);
    ArtifactPickupState s;s.actor=a;s.pawn=p;s.started=GetTickCount64();
    assert(artifactValidate(s)==0 && s.item==item && s.destination==destination && s.destinationUID==destinationUID);
    put(artifactProfileProof.playerGuidAddress,0,wrongUID);assert(artifactValidate(s)==8 && s.validationStage==4);
    put(artifactProfileProof.playerGuidAddress,0,uid);
    put(source,8,sourceUID+1);assert(artifactValidate(s)==8 && s.validationStage==16);put(source,8,sourceUID);
    put(inv,0x1c0,source);assert(artifactValidate(s)==8 && s.validationStage==17);put(inv,0x1c0,destination);
    put(artifactProfileProof.managerAddress,0,std::uintptr_t{0});assert(artifactValidate(s)==8 && s.validationStage==18);
    put(artifactProfileProof.managerAddress,0,manager);
    destinationItems[0]=item;put(destination,0x118,1);assert(artifactValidate(s)==9 && s.validationStage==19);put(destination,0x118,0);
    put(p,0x1190,source);assert(artifactValidate(s)==3 && s.validationStage==13);put(p,0x1190,std::uintptr_t{0});
    assert(artifactValidate(s)==0);artifactFixtureState=&s;
    put(c,8,0x10000u);assert(!artifactInvokeTransfer(s,artifactTransferFixture));put(c,8,0u);
    put(p,8,0x8000u);assert(!artifactInvokeTransfer(s,artifactTransferFixture));put(p,8,0u);
    assert(artifactFixtureCalls==0);
    assert(artifactInvokeTransfer(s,artifactTransferFixture) && artifactObserve(s)==0);
    s.started=GetTickCount64()-10001;assert(artifactObserve(s)==10);s.started=GetTickCount64();
    for (unsigned mode=1;mode<=3;++mode) {
        put(source,0x118,1);put(destination,0x118,0);artifactFixtureMode=mode;
        assert(artifactInvokeTransfer(s,artifactTransferFixture));s.code=artifactObserve(s);s.cleanup=0;
        assert(s.code==(mode==1?1u:12u));
        artifactFinalize(s,artifactCleanupFixture);artifactFinalize(s,artifactCleanupFixture);
        assert(artifactFixtureCleanups==1 && "only successful original UID transfer retires the artifact, once");
    }
    put(source,0x118,1);put(destination,0x118,0);artifactFixtureMode=4;
    assert(!artifactInvokeTransfer(s,artifactTransferFixture) && artifactObserve(s)==0);
    assert(artifactTransferResult(s,false)==11 && "an exception before mutation must still fail");
    artifactFixtureMode=5;
    assert(artifactTransferResult(s,artifactInvokeTransfer(s,artifactTransferFixture))==1 && "confirmed transfer followed by callback exception must report success");
    put(source,0x118,1);put(destination,0x118,0);
    artifactFixtureMode=1;assert(artifactInvokeTransfer(s,artifactTransferFixture) && artifactObserve(s)==1);
    put(destination,8,destinationUID+1);assert(artifactObserve(s)==8);put(destination,8,destinationUID);
    put(source,8,sourceUID+1);assert(artifactObserve(s)==8);put(source,8,sourceUID);
    assert(!artifactPoolContainer(0xffffffffu,source) && !artifactPoolContainer(0x100000u,source));
    bool found=false;int n=0;put(destination,0x118,16385);assert(!artifactMembership(destination,item,found,n));
    put(destination,0x118,1);put(destination,0x11c,0);assert(!artifactMembership(destination,item,found,n));
    put(destination,0x11c,2);put(destination,0x118,2);destinationItems[0]=456;destinationItems[4]=item;
    assert(artifactMembership(destination,item,found,n) && found && n==2 && "native item entries have stride sixteen");
    assert(VirtualFree(mapped,0,MEM_RELEASE));artifactProfileProof=ArtifactProfileProof{};artifactFixtureState=nullptr;
    std::cout << "PASS native artifact v12: proven Take All ABI, original source/player inventory pool identities, both-side exact item UID confirmation, no loot flag write, guarded post-transfer native retirement, no false UI/empty-source/substitute success\n";
}
}
