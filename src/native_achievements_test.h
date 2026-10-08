namespace {
std::atomic<unsigned> achievementOriginalCalls{0};
unsigned achievementManagerInitCalls=0;
void __fastcall achievementInitializeFixture(void* manager) {
    auto* bytes=static_cast<unsigned char*>(manager);
    assert(bytes[0x130]==1 && bytes[0x131]==0);
    ++achievementManagerInitCalls;
    bytes[0x131]=1; // Fixture models the game's legitimate Init, not a production write.
}
__declspec(noinline) bool __fastcall achievementPredicateFixture() {
    achievementOriginalCalls.fetch_add(1);return true;
}
void achievementFixtureTests() {
    assert(!verifiedImageIdentity(GetModuleHandleW(nullptr)) && "fixture is never a supported game process");
    zonefpv_achievements_init(nullptr);
    assert(!achievementReady && achievementError==2 && !achievementImage.load());
    assert(!originalAchievementPredicate && "unsupported host must not create a native hook");
    auto* image=static_cast<unsigned char*>(VirtualAlloc(nullptr,gameImageSize,MEM_RESERVE|MEM_COMMIT,PAGE_EXECUTE_READWRITE));
    assert(image);
    std::memcpy(image+achievementPredicateRva,achievementPredicateProof,sizeof(achievementPredicateProof));
    std::memcpy(image+0x3797b14,achievementInitProof,sizeof(achievementInitProof));
    std::memcpy(image+0x2e7ba64,achievementProgressProof,sizeof(achievementProgressProof));
    std::memcpy(image+0x37cc6be,achievementWarningProof,sizeof(achievementWarningProof));
    std::memcpy(image+0x6cf0335,achievementStartupWarningProof,sizeof(achievementStartupWarningProof));
    std::memcpy(image+0xc4f730,achievementBaseGuardProof,sizeof(achievementBaseGuardProof));
    std::memcpy(image+0x35e4297,achievementConstructorProof,sizeof(achievementConstructorProof));
    std::memcpy(image+0x3133a94,achievementArrayProof,sizeof(achievementArrayProof));
    std::memcpy(image+0x36e3d35,achievementSingletonProof,sizeof(achievementSingletonProof));
    const auto initializeAddress=reinterpret_cast<std::uintptr_t>(image)+0x3797b14;
    std::memcpy(image+0x8bbec88,&initializeAddress,8);
    assert(achievementProfileBytes(image));
    for (const auto rva:{achievementPredicateRva,std::uintptr_t{0x3797b14},std::uintptr_t{0x2e7ba64},std::uintptr_t{0x37cc6be},std::uintptr_t{0x6cf0335},
        std::uintptr_t{0xc4f730},std::uintptr_t{0x35e4297},std::uintptr_t{0x3133a94},std::uintptr_t{0x36e3d35},std::uintptr_t{0x8bbec88}}) {
        image[rva]^=1;assert(!achievementProfileBytes(image));image[rva]^=1;
    }
    assert(!achievementProfileBytes(nullptr));
    const auto base=reinterpret_cast<std::uintptr_t>(image);
    for (const auto rva:achievementReturns) {
        assert(achievementCaller(base+rva,base));
        assert(!achievementCaller(base+rva-1,base) && !achievementCaller(base+rva+1,base));
    }
    assert(!achievementCaller(base,0) && !achievementCaller(base-1,base) && !achievementCaller(base+gameImageSize,base));
    // Real machine-code calls place their return address at each allowed native
    // RVA; this proves the detour ABI and caller scope, without executing game.
    std::array<AchievementPredicate,3> callers{};
    const auto fixture=reinterpret_cast<std::uintptr_t>(&achievementPredicateFixture);
    for (std::size_t i=0;i<callers.size();++i) {
        auto* stub=image+achievementReturns[i]-16;
        constexpr unsigned char code[]={0x48,0x83,0xec,0x28,0x48,0xb8,0,0,0,0,0,0,0,0,0xff,0xd0,0x48,0x83,0xc4,0x28,0xc3};
        std::memcpy(stub,code,sizeof(code));std::memcpy(stub+6,&fixture,8);
        callers[i]=reinterpret_cast<AchievementPredicate>(stub);
    }
    FlushInstructionCache(GetCurrentProcess(),image,gameImageSize);
    assert(ensureMinHookInitialized() && ensureMinHookInitialized() && "achievement and combat init share MinHook safely");
    assert(MH_CreateHook(reinterpret_cast<void*>(&achievementPredicateFixture),reinterpret_cast<void*>(&achievementPredicateHook),
        reinterpret_cast<void**>(&originalAchievementPredicate))==MH_OK);
    achievementImage.store(base);assert(MH_EnableHook(reinterpret_cast<void*>(&achievementPredicateFixture))==MH_OK);
    achievementOriginalCalls.store(0);
    for (const auto invoke:callers) assert(!invoke() && "initialization and both warning paths receive the normal unmodded achievement result");
    assert(achievementOriginalCalls.load()==0);
    AchievementPredicate volatile unrelated=&achievementPredicateFixture;
    assert(unrelated() && achievementOriginalCalls.load()==1 && "any other caller preserves original mod detection");
    // A real live UObject fixture proves late recovery checks without touching
    // game, account, achievement records or Steam. Existing progress is sentinel data.
    alignas(8) std::array<unsigned char,0x138> manager{};
    constexpr int managerIndex=6;
    std::array<unsigned char,24*7> chunk{};
    const auto managerAddress=reinterpret_cast<std::uintptr_t>(manager.data());
    const auto chunkAddress=reinterpret_cast<std::uintptr_t>(chunk.data());
    std::array<std::uintptr_t,1> chunks{{chunkAddress}};
    const auto chunksAddress=reinterpret_cast<std::uintptr_t>(chunks.data());
    const auto vtable=base+0x8bbe990,klass=base+0x1000;
    std::memcpy(manager.data(),&vtable,8);std::memcpy(manager.data()+0xc,&managerIndex,4);std::memcpy(manager.data()+0x10,&klass,8);
    std::memcpy(chunk.data()+managerIndex*24,&managerAddress,8);
    const int count=7;
    std::memcpy(image+0xa0e68c0+0x24,&count,4);std::memcpy(image+0xa0e68c0+0x10,&chunksAddress,8);
    std::memcpy(image+0xa2da5a8,&managerAddress,8);
    manager[0x130]=0;manager[0x131]=1;manager[0x100]=77;
    achievementReady=true;achievementInitializeManager=&achievementInitializeFixture;
    auto checked=achievementCheckManager(0);
    assert(checked.valid==1 && checked.enabled==0 && checked.recovered==0 && checked.error==0 && achievementManagerInitCalls==0);
    manager[0x130]=1;manager[0x131]=0;
    checked=achievementCheckManager(0);
    assert(checked.valid==1 && checked.enabled==1 && checked.recovered==1 && checked.error==0 && achievementManagerInitCalls==1);
    assert(manager[0x100]==77 && "legitimate retry preserves existing progress");
    checked=achievementCheckManager(managerAddress);
    assert(checked.enabled==1 && checked.recovered==0 && checked.error==0 && achievementManagerInitCalls==1 && "enabled managers are never initialized again");
    std::uintptr_t missing=0;
    std::memcpy(image+0xa2da5a8,&missing,8);assert(achievementCheckManager(0).error==8);
    std::memcpy(image+0xa2da5a8,&managerAddress,8);
    assert(achievementCheckManager(managerAddress+8).error==8 && "valid previous-world pointers cannot replace active singleton");
    std::memcpy(chunk.data()+managerIndex*24,&missing,8);assert(achievementCheckManager(0).error==8);
    std::memcpy(chunk.data()+managerIndex*24,&managerAddress,8);
    for (const unsigned flags:{0x10u,0x20u,0x8000u,0x10000u}) {
        std::memcpy(manager.data()+8,&flags,4);assert(achievementCheckManager(0).error==8);
    }
    const unsigned noFlags=0;
    std::memcpy(manager.data()+8,&noFlags,4);
    for (const unsigned flags:{0x200000u,0x10000000u}) {
        std::memcpy(chunk.data()+managerIndex*24+8,&flags,4);assert(achievementCheckManager(0).error==8);
    }
    std::memcpy(chunk.data()+managerIndex*24+8,&noFlags,4);
    const auto foreignVtable=vtable+8;
    std::memcpy(manager.data(),&foreignVtable,8);assert(achievementCheckManager(0).error==8);
    std::memcpy(manager.data(),&vtable,8);
    const std::int32_t destroyedSerial=-1;
    std::memcpy(chunk.data()+managerIndex*24+16,&destroyedSerial,4);assert(achievementCheckManager(0).error==8);
    assert(achievementManagerInitCalls==1 && "all invalid and foreign objects were forwarded safely without reinitialization");
    achievementReady=false;achievementInitializeManager=nullptr;
    assert(MH_DisableHook(reinterpret_cast<void*>(&achievementPredicateFixture))==MH_OK);
    for (const auto invoke:callers) assert(invoke());
    assert(achievementOriginalCalls.load()==4 && "removing the hook restores the original predicate");
    assert(MH_RemoveHook(reinterpret_cast<void*>(&achievementPredicateFixture))==MH_OK);
    assert(MH_Uninitialize()==MH_OK);originalAchievementPredicate=nullptr;achievementImage.store(0);
    assert(VirtualFree(image,0,MEM_RELEASE));
    std::cout << "PASS native achievement guard: unsupported host rejected; all nine byte proofs plus relocated vtable and exact three callers checked; real detour enables initialization/warnings, forwards unknown callers; shared MinHook init and original restoration\n";
    std::cout << "PASS native achievement late recovery: only current singleton with exact live UObject membership/vtable/flags and initialized-disabled state retries legitimate Init once; pending constructor, already enabled, old manager, CDO/archetype, dying/unreachable objects rejected; progress sentinel preserved\n";
}
}
