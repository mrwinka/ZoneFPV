#pragma once
namespace {
unsigned concussionOriginalCalls=0;
float concussionForwardedValue=-1;
std::uint64_t concussionForwardedName=0;
void* concussionForwardedInstance=nullptr;
bool concussionOriginalResult=true;
bool __fastcall concussionOriginalFixture(void* instance,std::uint64_t name,float value) {
    ++concussionOriginalCalls;concussionForwardedInstance=instance;
    concussionForwardedName=name;concussionForwardedValue=value;
    return concussionOriginalResult;
}
void concussionFixtureTests() {
    alignas(8) std::array<unsigned char,0x200> world{};
    alignas(8) std::array<unsigned char,0x80> collection{};
    alignas(8) std::array<unsigned char,0x100> instance{},otherInstance{};
    alignas(8) std::array<unsigned char,4*24> slots{};
    alignas(8) std::array<unsigned char,3*28> parameters{};
    const auto put=[](auto& bytes,std::size_t offset,const auto& value){std::memcpy(bytes.data()+offset,&value,sizeof(value));};
    const auto worldAddress=reinterpret_cast<std::uintptr_t>(world.data());
    const auto collectionAddress=reinterpret_cast<std::uintptr_t>(collection.data());
    const auto instanceAddress=reinterpret_cast<std::uintptr_t>(instance.data());
    const auto otherAddress=reinterpret_cast<std::uintptr_t>(otherInstance.data());
    const auto initObject=[&](auto& object,int index){
        put(object,0,std::uintptr_t{0x20000});put(object,0xc,index);put(object,0x10,std::uintptr_t{0x30000});
        put(slots,static_cast<std::size_t>(index)*24,reinterpret_cast<std::uintptr_t>(object.data()));
        put(slots,static_cast<std::size_t>(index)*24+16,100+index);
    };
    initObject(world,0);initObject(collection,1);initObject(instance,2);initObject(otherInstance,3);
    std::uintptr_t chunk=reinterpret_cast<std::uintptr_t>(slots.data());
    std::uintptr_t chunks=reinterpret_cast<std::uintptr_t>(&chunk);
    std::int32_t count=4;
    concussionArrayGlobals={reinterpret_cast<std::uintptr_t>(&chunks),reinterpret_cast<std::uintptr_t>(&count)};
    constexpr std::uint64_t targetName=123,foreignName=456,secondaryName=789;
    put(parameters,0,targetName);put(parameters,28,foreignName);put(parameters,56,secondaryName);
    put(collection,0x38,reinterpret_cast<std::uintptr_t>(parameters.data()));put(collection,0x40,3);
    put(instance,0x2c,1);put(instance,0x30,101);put(instance,0x34,0);put(instance,0x38,100);
    // A valid object with another collection/world must be skipped in the list.
    put(otherInstance,0x2c,1);put(otherInstance,0x30,999);put(otherInstance,0x34,0);put(otherInstance,0x38,100);
    std::array<std::uintptr_t,2> owned={otherAddress,instanceAddress};
    put(world,0x1e0,reinterpret_cast<std::uintptr_t>(owned.data()));put(world,0x1e8,2);
    ConcussionState candidate;candidate.world=worldAddress;candidate.collection=collectionAddress;candidate.name=targetName;
    assert(concussionFindInstance(candidate) && candidate.instance==instanceAddress && concussionSame(candidate));
    assert(concussionParameter(collectionAddress,targetName) && !concussionParameter(collectionAddress,targetName|(1ull<<32)));
    candidate.ready=true;candidate.refreshed=GetTickCount64();candidate.token=21;concussion=candidate;
    originalConcussionSetter=&concussionOriginalFixture;quickConcussionInstance.store(instanceAddress);
    assert(concussionSetterHook(instance.data(),targetName,.5f));
    assert(concussion.blocked==1 && concussionOriginalCalls==1 && concussionForwardedValue==0 &&
        concussionForwardedName==targetName && concussionForwardedInstance==instance.data());
    // Zero is forwarded too, preserving publication and the original bool ABI.
    concussionOriginalResult=false;
    assert(!concussionSetterHook(instance.data(),targetName,0));
    assert(concussionOriginalCalls==2 && concussion.blocked==1 && concussionForwardedValue==0);
    concussionOriginalResult=true;
    assert(concussionSetterHook(instance.data(),foreignName,.7f) && concussionForwardedValue==.7f);
    assert(concussionSetterHook(instance.data(),0,.27f) && concussionForwardedValue==.27f && concussion.blocked==1);
    assert(concussionSetterHook(instance.data(),targetName|(1ull<<32),.8f) && concussionForwardedValue==.8f);
    assert(concussionSetterHook(otherInstance.data(),targetName,.6f) && concussionForwardedValue==.6f);
    assert(concussion.blocked==1);
    concussion.refreshed=GetTickCount64()-leaseMilliseconds-1;
    concussionSetterHook(instance.data(),targetName,.9f);assert(concussionForwardedValue==.9f && concussion.blocked==1);
    concussion.refreshed=GetTickCount64();
    put(instance,0x34,3);concussionSetterHook(instance.data(),targetName,.4f);assert(concussionForwardedValue==.4f);put(instance,0x34,0);
    put(instance,0x30,102);concussionSetterHook(instance.data(),targetName,.4f);assert(concussionForwardedValue==.4f);put(instance,0x30,101);
    put(instance,0x18,std::uint64_t{2});concussionSetterHook(instance.data(),targetName,.4f);assert(concussionForwardedValue==.4f);put(instance,0x18,std::uint64_t{0});
    // Same pointer/class/name/index with a newer GUObject serial is a different object.
    put(slots,2*24+16,200);concussionSetterHook(instance.data(),targetName,.4f);assert(concussionForwardedValue==.4f);put(slots,2*24+16,102);
    put(slots,0*24+8,0x10200000u);concussionSetterHook(instance.data(),targetName,.4f);assert(concussionForwardedValue==.4f);put(slots,0*24+8,0u);
    put(collection,8,0x8000u);concussionSetterHook(instance.data(),targetName,.4f);assert(concussionForwardedValue==.4f);put(collection,8,0u);
    assert(concussion.blocked==1);
    // This models engine writes after Lua's every-frame correction: every one
    // reaches the native publisher as zero rather than reviving the blur.
    for (int i=0;i<240;++i) {concussionSetterHook(instance.data(),targetName,.5f);assert(concussionForwardedValue==0);}
    assert(concussion.blocked==241);
    quickConcussionInstance.store(0);concussionSetterHook(instance.data(),targetName,.35f);
    assert(concussionForwardedValue==.35f && concussion.blocked==241);
    put(world,0x1e8,1025);assert(!concussionFindInstance(candidate));put(world,0x1e8,2);
    put(collection,0x40,1025);assert(!concussionFindInstance(candidate));put(collection,0x40,3);
    candidate.name=999;assert(!concussionFindInstance(candidate));candidate.name=targetName;
    put(instance,0x38,999);assert(!concussionFindInstance(candidate));put(instance,0x38,100);
    assert(concussionFindInstance(candidate));
    // Collection instances are strong UWorld references; unlike their World /
    // Collection weak bindings, their own GUObject serial may legitimately be0.
    put(slots,2*24+16,0);candidate=ConcussionState{};
    candidate.world=worldAddress;candidate.collection=collectionAddress;candidate.name=targetName;
    assert(concussionFindInstance(candidate) && candidate.instanceSerial==0 && concussionSame(candidate));
    candidate.refreshed=GetTickCount64();concussion=candidate;quickConcussionInstance.store(instanceAddress);
    concussionSetterHook(instance.data(),targetName,.5f);assert(concussionForwardedValue==0 && concussion.blocked==1);
    // A later weak-reference allocation assigns the serial; no mod memory write
    // is involved. Latch it, then reject a different generation at same address.
    put(slots,2*24+16,302);concussionSetterHook(instance.data(),targetName,.5f);
    assert(concussionForwardedValue==0 && concussion.instanceSerial==302 && concussion.blocked==2);
    put(slots,2*24+16,303);concussionSetterHook(instance.data(),targetName,.5f);
    assert(concussionForwardedValue==.5f && concussion.blocked==2);put(slots,2*24+16,302);
    // Reordering the owned array is allowed; removal from it disarms the scope.
    owned={instanceAddress,otherAddress};concussionSetterHook(instance.data(),targetName,.5f);
    assert(concussionForwardedValue==0 && concussion.instanceIndex==0 && concussion.blocked==3);
    owned={otherAddress,otherAddress};concussionSetterHook(instance.data(),targetName,.5f);
    assert(concussionForwardedValue==.5f && concussion.blocked==3);owned={otherAddress,instanceAddress};
    put(slots,0*24+16,0);assert(!concussionFindInstance(candidate));put(slots,0*24+16,100);
    put(slots,1*24+16,0);assert(!concussionFindInstance(candidate));put(slots,1*24+16,101);
    // Literal control packets exercise the production parser, not a fixture-only
    // reconstructed name list. Both names belong to the exact same collection.
    char packet[192]{};ConcussionState parsed;
    std::snprintf(packet,sizeof(packet),"ZFPVC21 44 %llx %llx 123 0\n",
        static_cast<unsigned long long>(worldAddress),static_cast<unsigned long long>(collectionAddress));
    assert(concussionParseControl(packet,parsed) && parsed.name==targetName && !parsed.secondaryName && concussionFindInstance(parsed));
    std::snprintf(packet,sizeof(packet),"ZFPVC44 45 %llx %llx 123 0 789 0\n",
        static_cast<unsigned long long>(worldAddress),static_cast<unsigned long long>(collectionAddress));
    assert(concussionParseControl(packet,parsed) && parsed.token==45 && parsed.name==targetName &&
        parsed.secondaryName==secondaryName && concussionFindInstance(parsed));
    parsed.ready=true;parsed.refreshed=GetTickCount64();concussion=parsed;quickConcussionInstance.store(instanceAddress);
    // Engine writes after either Lua correction must publish zeros for both
    // ConcussionIntensity and SuppressionIntensity, while a third valid effect
    // still passes its own value through the same collection setter.
    for (int i=0;i<240;++i) {
        assert(concussionSetterHook(instance.data(),targetName,.53f) && concussionForwardedValue==0);
        assert(concussionSetterHook(instance.data(),secondaryName,.91f) && concussionForwardedValue==0);
        assert(concussionSetterHook(instance.data(),foreignName,.37f) && concussionForwardedValue==.37f);
    }
    assert(concussion.blocked==480 && concussionForwardedName==foreignName);
    assert(concussionSetterHook(instance.data(),0,.47f) && concussionForwardedValue==.47f && concussion.blocked==480);
    for (const auto name:{targetName,secondaryName}) {
        assert(concussionSetterHook(instance.data(),name|(1ull<<32),.81f) && concussionForwardedValue==.81f);
        assert(concussionSetterHook(otherInstance.data(),name,.71f) && concussionForwardedValue==.71f);
        put(instance,0x34,3);assert(concussionSetterHook(instance.data(),name,.61f) && concussionForwardedValue==.61f);put(instance,0x34,0);
        put(instance,0x30,999);assert(concussionSetterHook(instance.data(),name,.51f) && concussionForwardedValue==.51f);put(instance,0x30,101);
        put(collection,0x18,std::uint64_t{7});assert(concussionSetterHook(instance.data(),name,.41f) && concussionForwardedValue==.41f);put(collection,0x18,std::uint64_t{0});
        put(slots,2*24+16,303);assert(concussionSetterHook(instance.data(),name,.31f) && concussionForwardedValue==.31f);put(slots,2*24+16,302);
    }
    assert(concussion.blocked==480);
    concussion.refreshed=GetTickCount64()-leaseMilliseconds-1;
    for (const auto name:{targetName,secondaryName}) {
        assert(concussionSetterHook(instance.data(),name,.21f) && concussionForwardedValue==.21f);
    }
    assert(concussion.blocked==480);
    // Unknown full FName cannot arm even when the first parameter is valid.
    parsed.secondaryName=999;assert(!concussionFindInstance(parsed));
    parsed.secondaryName=secondaryName|(1ull<<32);assert(!concussionFindInstance(parsed));
    parsed.secondaryName=targetName;assert(!concussionFindInstance(parsed));
    for (const auto* invalid:{"ZFPVC44 45 10000 20000 123 0", // missing second name
        "ZFPVC21 45 10000 20000 123 0 789 0", // old DLL must never accept dual control
        "ZFPVC44 45 10000 20000 123 0 789 0 456 0", // maximum two
        "ZFPVC44 45 10000 20000 123 0 123 0", // duplicate
        "ZFPVC44 45 10000 20000 123 0 0 0", // no second parameter
        "ZFPVC44 45 10000 20000 123 0 789 1", // wrong full FName
        "ZFPVC44 45 10000 20000 123 1 789 0",
        "ZFPVC44 0 10000 20000 123 0 789 0",
        "ZFPVC44 45 10000 20000 0 0 789 0",
        "ZFPVC44 45 10000 20000 123 0 4294967295 0",
        "ZFPVC21 45 10000 20000 4294967295 0",
        "ZFPVC21 45 10000 20000 4294967419 0", // must not wrap to123
        "ZFPVC44 45 10000 20000 123 0 4294968085 0", // must not wrap to789
        "ZFPVC21 45 10000 20000 123 4294967296", // must not wrap number to0
        "ZFPVC44 -45 10000 20000 123 0 789 0",
        "ZFPVC21 45 10000 20000 +123 0",
        "ZFPVC44 45 10000 20000 123 0 789 0 garbage"}) {
        assert(!concussionParseControl(invalid,parsed));
    }
    quickConcussionInstance.store(0);
    for (const auto name:{targetName,secondaryName}) {
        assert(concussionSetterHook(instance.data(),name,.17f) && concussionForwardedValue==.17f);
    }
    quickConcussionInstance.store(0);
    // The standalone test executable cannot arm the real game ABI profile.
    assert(!verifiedImageIdentity(GetModuleHandleW(nullptr)));
    concussion=ConcussionState{};concussionArrayGlobals={};originalConcussionSetter=nullptr;
    std::cout<<"PASS native concussion: exact world/collection/instance/full FName, 240 late writes zeroed, original bool/zero forwarding, foreign effects, expired lease, serial reuse, destroyed objects, bounds and disarm restoration\n";
    std::cout<<"PASS native concussion strong instance: zero serial accepted, lazy serial latched, subsequent generation rejected, exact owner-array membership and positive weak-owner serials retained\n";
    std::cout<<"PASS native dual MPC: literal ZFPVC44 and legacy ZFPVC21 controls, 480 late writes for two exact full FNames zeroed; None FName0, third effect, foreign instance/world/asset, suffixed names, changed identities, 1500 ms lease expiry and disarm forwarded; malformed/unknown/duplicate/third target rejected\n";
}
}
