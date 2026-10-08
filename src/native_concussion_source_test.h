#pragma once
namespace {
unsigned sourceRetains=0,sourceCalls=0;
bool sourceInvalidate=false,sourceParent=false,sourceDeferred=false;
std::uintptr_t sourceFixturePawn=0;
void __fastcall sourceRetainFixture(void*,std::int32_t) {++sourceRetains;}
void __fastcall sourceRemoveFixture(void* processor,std::int32_t* sid,std::uint32_t guid,unsigned char type) {
    ++sourceCalls;
    auto address=reinterpret_cast<std::uintptr_t>(processor);std::uintptr_t entries=0;int count=0;
    assert(artifactRead(address+0xb0,entries) && artifactRead(address+0xb8,count));
    if (!sourceDeferred) for (int i=count-1;i>=0;--i) {
        SourceDescriptor d;assert(sourceDescriptor(entries+static_cast<std::uintptr_t>(i)*128,d));
        if ((d.sid==*sid || sourceParent) && d.guid==guid && d.type==type) {
            std::memmove(reinterpret_cast<void*>(entries+static_cast<std::uintptr_t>(i)*128),
                reinterpret_cast<void*>(entries+static_cast<std::uintptr_t>(i+1)*128),static_cast<std::size_t>(count-i-1)*128);
            --count;
        }
    }
    std::memcpy(reinterpret_cast<void*>(address+0xb8),&count,4);*sid=0;
    if (sourceInvalidate) {std::uint64_t changed=123;std::memcpy(reinterpret_cast<void*>(sourceFixturePawn+0x18),&changed,8);}
}
void sourceHookOrderFixtureTests() {
    assert(MH_Initialize()==MH_OK);
    auto* image=static_cast<unsigned char*>(VirtualAlloc(nullptr,gameImageSize,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE));
    assert(image);
    const auto window=[&](std::uintptr_t rva,const auto& bytes){std::memcpy(image+rva,bytes,sizeof(bytes));};
    window(0x292b6c,source_remove);window(0x2636a70,source_retain);window(0x2f54785,source_core);
    window(0x292cae,source_registry);window(0x292e84,source_stride);window(0x293185,source_match);
    window(0x292fdb,source_callbacks);window(0x6bb8dcd,source_manager);window(0x2930e5,source_signedTable);
    window(0x293076,source_sidField);window(0x2930fc,source_signedKey);window(0x293162,source_stringSlot);
    window(0x68ffb40,source_pawnCore);
    window(concussionSetterRva,concussion_setterPrologue);window(0x24e5203,concussion_worldBinding);
    window(0x24e5255,concussion_collectionBinding);window(0x2ddcc8,concussion_worldCollectionArray);
    window(0x57b1822,concussion_kismetSetterABI);window(0x24e52b2,concussion_collectionNameArray);
    assert(sourceProfile(image) && concussionProfileBytes(image));
    // Reproduce production order using the real MinHook, not a hand-written
    // E9 byte. The gate first installs its setter detour during FPV; source
    // cleanup initializes only at exit and must not reject our own detour.
    void* original=nullptr;void* target=image+concussionSetterRva;
    assert(MH_CreateHook(target,reinterpret_cast<void*>(&concussionOriginalFixture),&original)==MH_OK);
    assert(original && MH_EnableHook(target)==MH_OK);
    assert(!concussionProfileBytes(image) && "v45 source profile incorrectly rejected its own setter detour");
    assert(sourceProfile(image));
    // Immutable proof windows remain strict even with an owned detour present.
    for (const auto rva:{std::uintptr_t{0x24e5203},std::uintptr_t{0x68ffb40},std::uintptr_t{0x292b6c},std::uintptr_t{0x293162}}) {
        const auto saved=image[rva];image[rva]^=1;assert(!sourceProfile(image));image[rva]=saved;
    }
    assert(sourceProfile(image) && MH_DisableHook(target)==MH_OK && MH_RemoveHook(target)==MH_OK);
    assert(concussionProfileBytes(image) && sourceProfile(image));
    assert(VirtualFree(image,0,MEM_RELEASE));
    assert(MH_Uninitialize()==MH_OK);
    std::cout << "PASS v46 source profile: real MPC MinHook first, original v45 profile rejects own detour, immutable source/capture profile accepts; source ABI/pawn-core/GUObject corruption still rejects\n";
}
void concussionSourceFixtureTests() {
    sourceHookOrderFixtureTests();
    alignas(8) std::array<unsigned char,0x680> pawn{},core{};
    alignas(8) std::array<unsigned char,0x80> world{};
    alignas(8) std::array<unsigned char,0xc0> processor{};
    alignas(8) std::array<unsigned char,512*128> entries{};
    alignas(8) std::array<unsigned char,2*24> slots{};
    alignas(8) std::array<unsigned char,0x20098> strings{};
    alignas(8) std::array<unsigned char,8*32> dynamic{},fixed{};
    const auto put=[](auto& bytes,std::size_t offset,const auto& value){std::memcpy(bytes.data()+offset,&value,sizeof(value));};
    const auto p=reinterpret_cast<std::uintptr_t>(pawn.data()),w=reinterpret_cast<std::uintptr_t>(world.data());
    const auto c=reinterpret_cast<std::uintptr_t>(core.data()),ep=reinterpret_cast<std::uintptr_t>(processor.data());
    const auto initObject=[&](auto& object,int i) {
        put(object,0,std::uintptr_t{0x20000});put(object,0xc,i);put(object,0x10,std::uintptr_t{0x30000});
        put(slots,static_cast<std::size_t>(i)*24,i?w:p);put(slots,static_cast<std::size_t>(i)*24+16,100+i);
    };
    initObject(pawn,0);initObject(world,1);
    std::uintptr_t chunk=reinterpret_cast<std::uintptr_t>(slots.data()),chunks=reinterpret_cast<std::uintptr_t>(&chunk);int objectCount=2;
    concussionArrayGlobals={reinterpret_cast<std::uintptr_t>(&chunks),reinterpret_cast<std::uintptr_t>(&objectCount)};
    put(pawn,0x650,c);put(core,0x10,23u);put(core,0x668,ep);
    put(processor,0xb0,reinterpret_cast<std::uintptr_t>(entries.data()));put(processor,0xbc,512);
    put(strings,0,reinterpret_cast<std::uintptr_t>(dynamic.data()));put(strings,0x20090,reinterpret_cast<std::uintptr_t>(fixed.data()));
    const wchar_t* names[]={L"",L"ConcussionBlurPostProcess",L"ExplosionDirtPostProcess",L"HealthRegen",L"ConcussionBlurPostProcess_suffix",L"SFXConcussionLoopStop",L"ConcussionComposite"};
    for (std::size_t i=0;i<7;++i) for (auto* table:{&dynamic,&fixed}) {
        put(*table,i*32,reinterpret_cast<std::uintptr_t>(names[i]));put(*table,i*32+8,static_cast<int>(std::wcslen(names[i])+1));
    }
    sourceStringManager=reinterpret_cast<std::uintptr_t>(strings.data());
    sourceRetain=&sourceRetainFixture;sourceRemove=&sourceRemoveFixture;sourceFixturePawn=p;
    assert(sourceNamed(1) && sourceNamed(~1) && sourceNamed(2) && !sourceNamed(0) && !sourceNamed(3) && !sourceNamed(4) && !sourceNamed(5));
    const auto row=[&](int i,std::int32_t sid,std::uint32_t guid,unsigned char type) {
        put(entries,static_cast<std::size_t>(i)*128+8,sid);put(entries,static_cast<std::size_t>(i)*128+0x10,guid);put(entries,static_cast<std::size_t>(i)*128+0x20,type);
    };
    const auto arm=[&]() {SourceState s;s.ready=true;s.active=true;s.pawn=p;s.world=w;s.token=45;s.refreshed=GetTickCount64();assert(sourceCapture(s));return s;};
    row(0,1,777,2);row(1,~1,888,8);row(2,2,999,255);row(3,3,777,2);row(4,4,777,2);row(5,5,777,2);put(processor,0xb8,6);
    auto s=arm();assert(sourceClean(s)==0 && s.matched==3 && s.removed==3 && sourceCalls==3 && sourceRetains==3);
    int remaining=0;assert(artifactRead(ep+0xb8,remaining) && remaining==3);
    assert(sourceClean(s)==0 && s.removed==3 && sourceCalls==3);
    // Normal parent cleanup retires children before later snapshot rows; no duplicate calls.
    row(0,6,11,4);row(1,1,11,4);put(processor,0xb8,2);s=arm();sourceParent=true;
    assert(sourceClean(s)==0 && s.removed==2 && sourceCalls==4);sourceParent=false;
    // A deferred engine removal request is not counted as successful absence.
    row(0,1,11,4);put(processor,0xb8,1);s=arm();sourceDeferred=true;
    assert(sourceClean(s)==0 && s.removed==0);sourceDeferred=false;
    // 300 selected feedback entries drain in bounded 128-descriptor slices.
    for (int i=0;i<300;++i)row(i,1,static_cast<unsigned>(i),4);put(processor,0xb8,300);s=arm();
    assert(sourceClean(s)==0 && s.removed==128);assert(sourceClean(s)==0 && s.removed==256);assert(sourceClean(s)==0 && s.removed==300);
    for (int i=0;i<300;++i)row(i,1,77,4);put(processor,0xb8,300);s=arm();
    assert(sourceClean(s)==0 && s.matched==300 && s.removed==300);
    row(0,1,11,4);row(1,2,11,4);put(processor,0xb8,2);s=arm();sourceInvalidate=true;const auto before=sourceCalls;
    assert(sourceClean(s)==9 && sourceCalls==before+1);sourceInvalidate=false;put(pawn,0x18,std::uint64_t{0});
    for (int mutation=0;mutation<5;++mutation) {
        s=arm();const auto calls=sourceCalls;
        switch(mutation) {
        case 0:put(core,0x10,24u);break;
        case 1:put(pawn,0x650,c+8);break;
        case 2:put(core,0x668,ep+8);break;
        case 3:put(slots,16,999);break;
        case 4:put(slots,24+16,999);break;
        }
        assert(sourceClean(s)==9 && sourceCalls==calls);
        put(core,0x10,23u);put(pawn,0x650,c);put(core,0x668,ep);put(slots,16,100);put(slots,24+16,101);
    }
    s=arm();s.refreshed=GetTickCount64()-leaseMilliseconds-1;assert(sourceClean(s)==9);
    put(processor,0xb8,513);s=arm();assert(sourceClean(s)==10);put(processor,0xb8,1);
    // An observed late blast at4.99sec is really removed before lease disarm.
    s=arm();row(0,1,99,4);assert(sourceClean(s)==0 && s.removed==1);s.active=false;
    // A genuine fresh5.01sec effect survives: disarmed native cleaner does not act.
    row(0,1,99,4);put(processor,0xb8,1);const auto calls=sourceCalls;assert(sourceClean(s)==9 && sourceCalls==calls);
    SourceState parsed;assert(sourceParse("ZFPVCS45 45 10000 20000\n",parsed));
    for (const auto* bad:{"ZFPVCS45 0 10000 20000","ZFPVCS45 45 10001 20000","ZFPVCS45 45 800000000000 20000",
        "ZFPVCS45 -45 10000 20000","ZFPVCS45 +45 10000 20000","ZFPVCS45 45 10000 20000 extra","ZFPVCS45 45 10000",
        "ZFPVCS45 18446744073709551616 10000 20000","ZFPVCS45 18446744073709551615 10000 20000",
        "ZFPVCS45 45 10000000000010000 20000","ZFPVCS45 45 0x10000 20000","ZFPVCS45 45 10000; 20000"})assert(!sourceParse(bad,parsed));
    std::cout << "PASS native source cleanup v45: exact signed SID whitelist, actual source GUID/type, retained normal callbacks, parent-child/deferred outcomes, 512 registry and128 removal bounds, late blast cleanup and post-deadline passthrough, captured world/pawn/core/UID/positive serial validation\n";
}
}
