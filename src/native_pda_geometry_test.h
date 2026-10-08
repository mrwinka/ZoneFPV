#pragma once
#include <stdexcept>
namespace {
struct PdaFixture {
    alignas(8) std::array<std::array<unsigned char,0xe0>,13> objects{};
    alignas(8) std::array<std::array<unsigned char,0x78>,7> properties{};
    alignas(8) std::array<unsigned char,13*24> slots{};
    std::uintptr_t chunk=0,chunks=0;
    std::int32_t count=13;
    std::array<unsigned char,56> opaque{};
    unsigned calls=0,mode=0;
    PdaGeometryRequest request{};
    template<class T> void put(unsigned object,std::size_t offset,T value) {std::memcpy(objects[object].data()+offset,&value,sizeof(value));}
    template<class T> void propertyPut(unsigned property,std::size_t offset,T value) {std::memcpy(properties[property].data()+offset,&value,sizeof(value));}
    std::uintptr_t address(unsigned object)const {return reinterpret_cast<std::uintptr_t>(objects[object].data());}
    std::uintptr_t propertyAddress(unsigned property)const {return reinterpret_cast<std::uintptr_t>(properties[property].data());}
    void slotPut(unsigned object,std::size_t offset,std::uint32_t value) {std::memcpy(slots.data()+object*24+offset,&value,sizeof(value));}
    PdaFixture() {
        for (unsigned i=0;i<objects.size();++i) {
            put(i,0,std::uintptr_t{0x20000});put(i,0xc,static_cast<int>(i));put(i,0x10,address(12));put(i,0x18,std::uint64_t{100+i});
            const auto object=address(i);std::memcpy(slots.data()+i*24,&object,8);slotPut(i,16,100+i);
        }
        // Metadata and CDOs may never have had a weak reference/serial assigned.
        for (unsigned i=1;i<objects.size();++i) slotPut(i,16,0);
        put(0,0x10,address(3));put(1,0x10,address(4));put(2,0x10,address(5));put(1,8,0x10u);put(2,8,0x10u);
        put(10,0x58,56);put(11,0x58,16);
        constexpr unsigned counts[]={1,2,3,1},sizes[]={56,72,88,16},returns[]={0,56,72,0},owners[]={3,4,4,5},firsts[]={0,1,3,6};
        for (unsigned i=0;i<4;++i) {
            put(6+i,0x20,address(owners[i]));put(6+i,0xb0,0x400u|(i?0x2000u:0u));
            put(6+i,0xb4,static_cast<unsigned char>(counts[i]));put(6+i,0xb6,static_cast<std::uint16_t>(sizes[i]));
            put(6+i,0xb8,static_cast<std::uint16_t>(returns[i]));put(6+i,0xd8,pdaGeometryProfile.image+pdaThunkRvas[i]);
            put(6+i,0x50,propertyAddress(firsts[i]));
        }
        constexpr unsigned propertySizes[]={56,56,16,56,16,16,16},offsets[]={0,0,56,0,56,72,0};
        for (unsigned i=0;i<properties.size();++i) {
            propertyPut(i,0x30,1);propertyPut(i,0x34,static_cast<int>(propertySizes[i]));
            propertyPut(i,0x38,std::uint64_t{0x80ull|((i==0||i==2||i==5||i==6)?0x400ull:0ull)});
            propertyPut(i,0x44,static_cast<int>(offsets[i]));propertyPut(i,0x70,address(propertySizes[i]==56?10:11));
        }
        propertyPut(1,0x18,propertyAddress(2));propertyPut(3,0x18,propertyAddress(4));propertyPut(4,0x18,propertyAddress(5));
        chunk=reinterpret_cast<std::uintptr_t>(slots.data());chunks=reinterpret_cast<std::uintptr_t>(&chunk);
        pdaGeometryProfile.chunksAddress=reinterpret_cast<std::uintptr_t>(&chunks);
        pdaGeometryProfile.countAddress=reinterpret_cast<std::uintptr_t>(&count);
        request.token=51;request.addresses={address(0),address(6),address(1),address(7),address(8),address(2),address(9)};
        for (unsigned i=0;i<opaque.size();++i) opaque[i]=static_cast<unsigned char>(i*3+17);
    }
};
PdaFixture* activePdaFixture=nullptr;
void __fastcall pdaProcessEventFixture(void* context,void* function,void* parameters) {
    auto& fixture=*activePdaFixture;++fixture.calls;
    if (fixture.mode==1) RaiseException(EXCEPTION_ACCESS_VIOLATION,0,0,nullptr);
    if (fixture.mode==2) throw std::runtime_error("missing configured ProcessEvent entry");
    auto* data=static_cast<unsigned char*>(parameters);const auto fn=reinterpret_cast<std::uintptr_t>(function);
    if (fn==fixture.address(6)) {
        assert(context==reinterpret_cast<void*>(fixture.address(0)));std::memcpy(data,fixture.opaque.data(),56);
        if (fixture.mode==3) fixture.slotPut(0,16,999);
    } else if (fn==fixture.address(7)) {
        assert(context==reinterpret_cast<void*>(fixture.address(1)));
        assert(!std::memcmp(data,fixture.opaque.data(),56) && "all opaque FGeometry bytes must remain native and unchanged");
        const double dimensions[]={fixture.mode==4?NAN:400.0,200.0};std::memcpy(data+56,dimensions,16);
    } else if (fn==fixture.address(9)) {
        assert(context==reinterpret_cast<void*>(fixture.address(2)));
        const double cursor[]={350.0,225.0};std::memcpy(data,cursor,16);
    } else {
        assert(fn==fixture.address(8) && context==reinterpret_cast<void*>(fixture.address(1)));
        assert(!std::memcmp(data,fixture.opaque.data(),56));double absolute[2]{};std::memcpy(absolute,data+56,16);
        assert(absolute[0]==350 && absolute[1]==225);
        // Represent a transformed/native-widget snapshot: absolute mouse350/225
        // is local100/50 after origin150/125 and scale2. No Lua struct is involved.
        const double local[]={100.0,50.0};std::memcpy(data+72,local,16);
        if (fixture.mode==5) fixture.slotPut(0,16,999);
    }
}
void pdaGeometryFixtureTests() {
    InitOnceExecuteOnce(&pdaGeometryInitialized,initializePdaGeometry,nullptr,nullptr);
    assert(!pdaGeometryProfile.ready && "test host must reject real game/runtime profile");
    const auto originalProfile=pdaGeometryProfile;const auto originalRoot=root;
    pdaGeometryProfile={true,0x50000000,0,0,&pdaProcessEventFixture,GetCurrentThreadId(),0};
    PdaFixture fixture;activePdaFixture=&fixture;
    PdaGeometryResult result;
    assert(pdaGeometrySample(fixture.request,result) && result.token==51 && result.width==400 && result.height==200 && result.x==100 && result.y==50 && fixture.calls==4);
    for (unsigned i=0;i<240;++i) {result={};assert(pdaGeometrySample(fixture.request,result));}
    assert(fixture.calls==964 && "fresh geometry/cursor sampled on every request; native profile not rescanned per frame");
    PdaGeometryRequest parsed;char text[512]{};
    std::snprintf(text,sizeof(text),"ZFPVPG51 51 %llx %llx %llx %llx %llx %llx %llx\n",
        static_cast<unsigned long long>(fixture.request.addresses[0]),static_cast<unsigned long long>(fixture.request.addresses[1]),
        static_cast<unsigned long long>(fixture.request.addresses[2]),static_cast<unsigned long long>(fixture.request.addresses[3]),
        static_cast<unsigned long long>(fixture.request.addresses[4]),static_cast<unsigned long long>(fixture.request.addresses[5]),static_cast<unsigned long long>(fixture.request.addresses[6]));
    assert(pdaParseRequest(text,parsed) && parsed.token==51 && parsed.addresses==fixture.request.addresses);
    for (const char* bad:{"ZFPVPG50 51 10000 20000 30000 40000 50000 60000 70000","ZFPVPG51 0 10000 20000 30000 40000 50000 60000 70000",
        "ZFPVPG51 -51 10000 20000 30000 40000 50000 60000 70000","ZFPVPG51 51 10001 20000 30000 40000 50000 60000 70000",
        "ZFPVPG51 51 800000000000 20000 30000 40000 50000 60000 70000","ZFPVPG51 51 10000 20000 30000 40000 50000 60000 70000 extra"}) assert(!pdaParseRequest(bad,parsed));
    const auto rejected=[&](unsigned code){const auto calls=fixture.calls;result={};assert(!pdaGeometrySample(fixture.request,result) && result.code==code && fixture.calls==calls);};
    auto request=fixture.request;fixture.request.addresses[0]=0;rejected(5);fixture.request=request;
    fixture.slotPut(0,8,0x10200000u);rejected(5);fixture.slotPut(0,8,0);
    fixture.put(0,8,0x8000u);rejected(5);fixture.put(0,8,0u);
    fixture.count=0;rejected(5);fixture.count=13;
    fixture.put(6,0xd8,pdaGeometryProfile.image+pdaThunkRvas[1]);rejected(6);fixture.put(6,0xd8,pdaGeometryProfile.image+pdaThunkRvas[0]);
    fixture.put(7,0x20,fixture.address(5));rejected(7);fixture.put(7,0x20,fixture.address(4));
    fixture.put(8,0xb6,std::uint16_t{257});rejected(8);fixture.put(8,0xb6,std::uint16_t{88});
    fixture.put(9,0xb0,0x2000u);rejected(9);fixture.put(9,0xb0,0x2400u);
    fixture.propertyPut(1,0x18,fixture.propertyAddress(1));rejected(7);fixture.propertyPut(1,0x18,fixture.propertyAddress(2));
    fixture.propertyPut(2,0x44,48);rejected(7);fixture.propertyPut(2,0x44,56);
    fixture.propertyPut(4,0x30,2);rejected(8);fixture.propertyPut(4,0x30,1);
    fixture.propertyPut(4,0x70,fixture.address(10));rejected(8);fixture.propertyPut(4,0x70,fixture.address(11));
    fixture.put(9,0xb8,std::uint16_t{16});rejected(9);fixture.put(9,0xb8,std::uint16_t{0});
    // Valid static-struct size with another identity still must not be mixed.
    fixture.put(12,0x58,16);fixture.propertyPut(6,0x70,fixture.address(12));rejected(10);fixture.propertyPut(6,0x70,fixture.address(11));
    PdaGeometryResult wrongThread;std::thread worker([&]{assert(!pdaGeometrySample(fixture.request,wrongThread) && wrongThread.code==4);});worker.join();
    for (unsigned mode:{1u,2u,3u,4u,5u}) {
        fixture.mode=mode;result={};assert(!pdaGeometrySample(fixture.request,result) && result.code==(mode<=3?11u:mode==4?16u:15u));
        fixture.slotPut(0,16,100);
    }
    fixture.mode=0;
    // Serial0 on strong metadata/CDO is allowed; later allocation is latched,
    // while destruction/reuse of the widget between native calls is rejected.
    PdaObject cdo;assert(pdaCapture(fixture.address(1),cdo) && cdo.serial==0);fixture.slotPut(1,16,123);
    assert(pdaLive(cdo) && cdo.serial==123);fixture.slotPut(1,16,124);assert(!pdaLive(cdo));fixture.slotPut(1,16,0);
    auto* image=static_cast<unsigned char*>(VirtualAlloc(nullptr,gameImageSize,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE));assert(image);
    std::memcpy(image+pdaThunkRvas[0],pdaGeometryThunkBytes,sizeof(pdaGeometryThunkBytes));
    std::memcpy(image+pdaThunkRvas[1],pdaSizeThunkBytes,sizeof(pdaSizeThunkBytes));
    std::memcpy(image+pdaThunkRvas[2],pdaAbsoluteThunkBytes,sizeof(pdaAbsoluteThunkBytes));
    std::memcpy(image+pdaThunkRvas[3],pdaMouseThunkBytes,sizeof(pdaMouseThunkBytes));
    std::memcpy(image+0x26ec732,pdaGeometryCopyBytes,sizeof(pdaGeometryCopyBytes));assert(pdaGameProfileBytes(image));
    for (const auto rva:{pdaThunkRvas[0],pdaThunkRvas[1],pdaThunkRvas[2],pdaThunkRvas[3],std::uintptr_t{0x26ec732}}) {
        image[rva]^=1;assert(!pdaGameProfileBytes(image));image[rva]^=1;
    }
    assert(VirtualFree(image,0,MEM_RELEASE));PdaProcessEvent unsafe=nullptr;
    assert(!pdaRuntimeProfile(nullptr,unsafe) && !pdaRuntimeProfile(GetModuleHandleW(nullptr),unsafe));
    // Exercise the real synchronous file export and atomic response replacement.
    wchar_t temporary[MAX_PATH]{},directory[MAX_PATH]{};assert(GetTempPathW(MAX_PATH,temporary));
    assert(GetTempFileNameW(temporary,L"PG5",0,directory));assert(DeleteFileW(directory));assert(CreateDirectoryW(directory,nullptr));
    root=directory;root+=L"\\";const auto control=root+L"native-pda-geometry-control.txt",status=root+L"native-pda-geometry-status.txt";
    FILE* file=nullptr;assert(!_wfopen_s(&file,control.c_str(),L"wb") && file);assert(std::fputs(text,file)>=0);assert(!std::fclose(file));
    assert(zonefpv_pda_geometry_query(nullptr)==0);assert(GetFileAttributesW(control.c_str())==INVALID_FILE_ATTRIBUTES);
    assert(!_wfopen_s(&file,status.c_str(),L"rb") && file);char reply[512]{};assert(std::fread(reply,1,sizeof(reply)-1,file)>0);std::fclose(file);
    assert(!std::strcmp(reply,"ZFPVPG51 51 1 0 400 200 100 50\n"));
    assert(!_wfopen_s(&file,control.c_str(),L"wb") && file);assert(std::fputs("ZFPVPG51 52 invalid\n",file)>=0);assert(!std::fclose(file));
    zonefpv_pda_geometry_query(nullptr);assert(!_wfopen_s(&file,status.c_str(),L"rb") && file);
    std::memset(reply,0,sizeof(reply));assert(std::fread(reply,1,sizeof(reply)-1,file)>0);std::fclose(file);
    assert(!std::strcmp(reply,"ZFPVPG51 52 0 1 0 0 0 0\n") && "rejected request cannot reuse successful coordinates");
    assert(DeleteFileW(status.c_str()));assert(RemoveDirectoryW(directory));
    pdaGeometryProfile=originalProfile;root=originalRoot;activePdaFixture=nullptr;
    std::cout << "PASS native PDA geometry51: opaque56-byte snapshot retained across4 reflected calls; scaled local coordinates; fresh requests; exact thunk/owner/descriptor/serial/thread guards; SEH/C++ failures; strict request and atomic scalar-only IPC\n";
}
}
