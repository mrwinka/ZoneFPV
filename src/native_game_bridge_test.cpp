#include "native_game_bridge.cpp"
#include <array>
#include <atomic>
#include <thread>
#include <vector>
#include <cassert>
#include <iostream>
#include "native_artifact_test.h"
#include "native_geiger_test.h"
#include "native_resources_test.h"
#include "native_concussion_test.h"
#include "native_concussion_source_test.h"
#include "native_achievements_test.h"
#include "native_pda_geometry_test.h"

namespace {
std::atomic<unsigned> originalCalls{0};
std::atomic<std::uint32_t> forwardedFlags{0};
std::atomic<float> lastPlayerAmount{0};
std::atomic<float> lastScalar{0};
std::atomic<std::uint32_t> lastScalarFlags{0};
std::atomic<void*> lastScalarContext{nullptr};
std::atomic<const void*> lastScalarParameters{nullptr};
std::atomic<std::int32_t> lastScalarIndex{-1};
__declspec(noinline) bool __fastcall scalarIndexFixture(void*,std::int32_t index,float value) {
    lastScalar.store(value);lastScalarIndex.store(index);return index>=0 && index<2;
}
std::uint32_t* mutateGuid=nullptr;
bool longParents=false;
int __fastcall relationFixture(std::uint64_t playerKey,std::uint64_t actorKey) {
    assert(playerKey==11 && actorKey==99);
    if (mutateGuid) ++*mutateGuid;
    return 0;
}
std::uint64_t* __fastcall factionFixture(std::uint64_t* output,std::uint64_t key) {
    if (longParents) *output=100+key;
    else *output=key==1?111ull:key==2?222ull:key==4?((1ull<<32)|444ull):~std::uint64_t{0};
    return output;
}
FactionDesc* __fastcall parentFixture(FactionDesc* output,const FactionDesc* input) {
    if (longParents) {output->key=input->key+1;output->valid=1;}
    else if (input->key>=1 && input->key<=3) {output->key=input->key==3?1:input->key+1;output->valid=1;}
    else {output->key=0;output->valid=0;}
    return output;
}
__declspec(noinline) void __fastcall scalarFixture(void*,const void* parameters,float value,std::uint32_t flags,void* context) {
    lastScalar.store(value);lastScalarFlags.store(flags);lastScalarContext.store(context);lastScalarParameters.store(parameters);
}
__declspec(noinline) void __fastcall nativeFixture(void*,const void* payload,std::uint32_t flags) {
    float amount=0;
    std::memcpy(&amount,payload,sizeof(amount));
    originalCalls.fetch_add(1);
    forwardedFlags.store(flags);
    lastPlayerAmount.store(amount);
}
void fixtureArm(std::uintptr_t core) {
    AcquireSRWLockExclusive(&stateLock);
    state=State{};state.ready=true;state.core=core;state.token=11;state.refreshed=GetTickCount64();
    assert(coreGuid(core,state.guid));
    receiveCore.store(core,std::memory_order_release);
    ReleaseSRWLockExclusive(&stateLock);
}
std::array<unsigned char,0x90> attack(float damage,unsigned source) {
    std::array<unsigned char,0x90> payload{};
    std::memcpy(payload.data(),&damage,sizeof(damage));payload[0x79]=static_cast<unsigned char>(source);
    return payload;
}
}

int main() {
    assert(!verifiedProfile(GetModuleHandleW(nullptr)) && "test host must never match installed game");
    assert(MH_Initialize()==MH_OK);
    assert(MH_CreateHook(reinterpret_cast<void*>(&nativeFixture),reinterpret_cast<void*>(&receiveHook),
        reinterpret_cast<void**>(&originalReceive))==MH_OK);
    assert(MH_EnableHook(reinterpret_cast<void*>(&nativeFixture))==MH_OK);
    Receive volatile invoke=&nativeFixture;
    struct alignas(8) NativeCore {std::uint64_t first=0,second=0;std::uint32_t guid=11,padding=0;} player,other;
    fixtureArm(reinterpret_cast<std::uintptr_t>(&player));
    auto bullet=attack(17.5f,2);
    invoke(&player,bullet.data(),19);
    assert(state.incoming==1 && state.hits==1 && state.total==17.5 && originalCalls.load()==0);
    auto bite=attack(11,5);invoke(&player,bite.data(),0);
    assert(state.hits==2 && state.total==28.5 && originalCalls.load()==0);
    invoke(&other,bullet.data(),73);
    assert(originalCalls.load()==1 && forwardedFlags.load()==73 && lastPlayerAmount.load()==17.5f && state.hits==2);
    for (unsigned source:{1u,19u,20u,21u,22u,44u,45u,47u}) {
        auto environment=attack(30,source);invoke(&player,environment.data(),0);
    }
    assert(state.hits==2 && state.total==28.5 && originalCalls.load()==1);
    for (float amount:{0.f,-2.f,INFINITY,NAN}) {
        auto invalid=attack(amount,2);invoke(&player,invalid.data(),0);
    }
    assert(state.hits==2 && state.total==28.5 && originalCalls.load()==1);
    state.refreshed=GetTickCount64()-leaseMilliseconds-1;
    invoke(&player,bullet.data(),3);
    assert(originalCalls.load()==2 && state.hits==2);
    fixtureArm(reinterpret_cast<std::uintptr_t>(&player));
    std::vector<std::thread> workers;
    for (int i=0;i<4;++i) workers.emplace_back([&](){
        auto shot=attack(.5f,2);
        for (int n=0;n<4000;++n) invoke(&player,shot.data(),0);
    });
    for (auto& worker:workers) worker.join();
    assert(state.hits==16000 && state.incoming==16000 && state.total==8000);
    // A synchronous disarm must preserve final counters and stop interception.
    AcquireSRWLockExclusive(&stateLock);state.core=0;ReleaseSRWLockExclusive(&stateLock);
    invoke(&player,bullet.data(),42);
    assert(originalCalls.load()==3 && forwardedFlags.load()==42 && state.hits==16000);
    fixtureArm(reinterpret_cast<std::uintptr_t>(&player));
    auto buttstock=attack(25.f,12);invoke(&player,buttstock.data(),0);
    invoke(&player,bullet.data(),0);
    assert(state.hits==2 && state.buttstockHits==1 && state.source==2 && state.total==42.5);
    auto emptyButtstock=attack(0.f,12);invoke(&player,emptyButtstock.data(),0);
    assert(state.buttstockHits==1 && originalCalls.load()==3);
    fixtureArm(reinterpret_cast<std::uintptr_t>(&player));assert(state.buttstockHits==0);
    assert(MH_DisableHook(reinterpret_cast<void*>(&nativeFixture))==MH_OK);
    assert(MH_RemoveHook(reinterpret_cast<void*>(&nativeFixture))==MH_OK);
    assert(MH_CreateHook(reinterpret_cast<void*>(&scalarFixture),reinterpret_cast<void*>(&scalarHook),
        reinterpret_cast<void**>(&originalScalar))==MH_OK);
    assert(MH_EnableHook(reinterpret_cast<void*>(&scalarFixture))==MH_OK);
    ScalarSetter volatile setScalar=&scalarFixture;
    struct alignas(8) FakeMID {std::uintptr_t vtable=0x100000;std::uint32_t flags=0;std::int32_t index=9;std::uintptr_t klass=0x200000;std::uint64_t name=77;} mid,unrelated;
    visualState=VisualState{};visualState.ready=true;visualState.count=1;visualState.refreshed=GetTickCount64();
    auto& target=visualState.targets[0];target.mid=reinterpret_cast<std::uintptr_t>(&mid);target.comparison=123;target.number=0;
    assert(objectIdentity(target.mid,target.identity));
    quickVisualMids[0].store(target.mid);quickVisualCount.store(1);
    struct ParameterInfo {std::uint32_t comparison=123,number=0;unsigned char association=2,padding[3]{};std::int32_t index=-1;} parameters;
    setScalar(&mid,&parameters,.7f,49,&player);
    assert(lastScalar.load()==0 && lastScalarFlags.load()==49 && lastScalarContext.load()==&player && lastScalarParameters.load()==&parameters);
    assert(visualState.intercepted==1 && parameters.comparison==123 && parameters.association==2);
    setScalar(&unrelated,&parameters,.8f,1,&other);assert(lastScalar.load()==.8f && visualState.intercepted==1);
    parameters.number=1;setScalar(&mid,&parameters,.6f,1,&other);assert(lastScalar.load()==.6f);
    parameters.number=0;parameters.association=1;setScalar(&mid,&parameters,.5f,1,&other);assert(lastScalar.load()==.5f);
    parameters.association=2;parameters.comparison=124;setScalar(&mid,&parameters,.4f,1,&other);assert(lastScalar.load()==.4f);
    parameters.comparison=123;mid.name=78;setScalar(&mid,&parameters,.3f,1,&other);assert(lastScalar.load()==.3f);
    mid.name=77;visualState.refreshed=GetTickCount64()-leaseMilliseconds-1;
    setScalar(&mid,&parameters,.2f,1,&other);assert(lastScalar.load()==.2f && visualState.intercepted==1);
    assert(MH_DisableHook(reinterpret_cast<void*>(&scalarFixture))==MH_OK);
    assert(MH_RemoveHook(reinterpret_cast<void*>(&scalarFixture))==MH_OK);
    assert(MH_CreateHook(reinterpret_cast<void*>(&scalarIndexFixture),reinterpret_cast<void*>(&scalarIndexHook),
        reinterpret_cast<void**>(&originalScalarIndex))==MH_OK);
    assert(MH_EnableHook(reinterpret_cast<void*>(&scalarIndexFixture))==MH_OK);
    ScalarIndexSetter volatile setByIndex=&scalarIndexFixture;
    alignas(8) std::array<unsigned char,0x190> indexedMid{};
    std::memcpy(indexedMid.data(),&mid,sizeof(mid));
    struct ScalarEntry {ParameterInfo info;float value=0;std::uint32_t expressionGuid[4]{};};
    static_assert(sizeof(ScalarEntry)==36);
    std::array<ScalarEntry,2> entries{};
    entries[0].info.comparison=123;entries[1].info.comparison=124;
    const auto data=reinterpret_cast<std::uintptr_t>(entries.data());
    const std::int32_t parameterCount=2;
    std::memcpy(indexedMid.data()+0x180,&data,8);std::memcpy(indexedMid.data()+0x188,&parameterCount,4);
    visualState.refreshed=GetTickCount64();visualState.intercepted=0;
    target.mid=reinterpret_cast<std::uintptr_t>(indexedMid.data());
    assert(objectIdentity(target.mid,target.identity));quickVisualMids[0].store(target.mid);
    assert(setByIndex(indexedMid.data(),0,.7f) && lastScalar.load()==0 && lastScalarIndex.load()==0 && visualState.intercepted==1);
    assert(setByIndex(indexedMid.data(),1,.8f) && lastScalar.load()==.8f && visualState.intercepted==1);
    entries[0].info.number=1;assert(setByIndex(indexedMid.data(),0,.6f) && lastScalar.load()==.6f);
    entries[0].info.number=0;entries[0].info.association=1;assert(setByIndex(indexedMid.data(),0,.5f) && lastScalar.load()==.5f);
    entries[0].info.association=2;
    assert(!setByIndex(indexedMid.data(),-1,.4f) && lastScalar.load()==.4f && lastScalarIndex.load()==-1);
    assert(!setByIndex(indexedMid.data(),9,.3f) && lastScalar.load()==.3f && visualState.intercepted==1);
    visualState.refreshed=GetTickCount64()-leaseMilliseconds-1;
    assert(setByIndex(indexedMid.data(),0,.2f) && lastScalar.load()==.2f);
    assert(MH_DisableHook(reinterpret_cast<void*>(&scalarIndexFixture))==MH_OK);
    assert(MH_RemoveHook(reinterpret_cast<void*>(&scalarIndexFixture))==MH_OK);
    assert(MH_Uninitialize()==MH_OK);
    relationLevel=&relationFixture;factionName=&factionFixture;factionParent=&parentFixture;
    MetadataRow factionRow;
    collectFactionNames(1,factionRow);
    assert(factionRow.count==2 && factionRow.names[0]==111 && factionRow.names[1]==222);
    factionRow=MetadataRow{};collectFactionNames(4,factionRow);assert(factionRow.count==0);
    longParents=true;factionRow=MetadataRow{};collectFactionNames(1,factionRow);
    assert(factionRow.count==8 && factionRow.names[7]==108);
    alignas(8) std::array<unsigned char,0x658> actor{};
    alignas(8) std::array<std::uint64_t,0x148/8> core{};
    const auto vtable=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    const auto coreAddress=reinterpret_cast<std::uintptr_t>(core.data());
    const std::uintptr_t klass=0x200000;
    std::memcpy(actor.data(),&vtable,8);std::memcpy(actor.data()+0x10,&klass,8);
    std::memcpy(actor.data()+0x650,&coreAddress,8);
    core[0x10/8]=1;core[0x140/8]=99;
    CoreInfo playerInfo;playerInfo.relation=11;
    MetadataRow actorRow;
    assert(queryMetadata(playerInfo,reinterpret_cast<std::uintptr_t>(actor.data()),actorRow) && actorRow.relation==0);
    mutateGuid=reinterpret_cast<std::uint32_t*>(reinterpret_cast<unsigned char*>(core.data())+0x10);
    actorRow=MetadataRow{};
    assert(!queryMetadata(playerInfo,reinterpret_cast<std::uintptr_t>(actor.data()),actorRow) && actorRow.relation==-1 && actorRow.count==0);
    CoreInfo invalidInfo;
    assert(!coreInfo(0,invalidInfo));
    artifactPickupFixtureTests();
    geigerFixtureTests();
    resourceFixtureTests();
    concussionFixtureTests();
    concussionSourceFixtureTests();
    achievementFixtureTests();
    pdaGeometryFixtureTests();
    std::cout << "PASS native detour: bullet and mutant damage intercepted, body calls canceled, other actors and expired leases forwarded, concurrent hits retained\n";
    std::cout << "PASS native buttstock counter: mixed melee/gun polling retains WeaponButt evidence; invalid damage ignored and new lease resets counter\n";
    std::cout << "PASS native scalar detour: exact MID/FName/global parameter zeroed, other materials/names/layers/identities/expired leases forwarded, five-argument ABI preserved\n";
    std::cout << "PASS native indexed scalar detour: cached index resolves exact FName/global entry, unrelated params and invalid indices forwarded, bool ABI preserved\n";
    std::cout << "PASS native metadata: actual core keys passed to relation ABI, faction parent cycles/depth/suffixed names bounded, stale core GUID and null actors rejected\n";
}
