#pragma once
// FGeometry is not a reflected-property value: the installed Lua bridge turns
// its return into an empty table. Keep all 56 native bytes in native storage
// through GetCachedGeometry -> GetLocalSize / AbsoluteToLocal. Only four doubles
// cross the file boundary. Calls run synchronously from the owner's EngineTick.
namespace {
using PdaProcessEvent=void(__fastcall*)(void*,void*,void*);
constexpr char pdaProcessEventExport[]="?ProcessEvent@UObject@Unreal@RC@@QEAAXPEAVUFunction@23@PEAX@Z";
constexpr std::uintptr_t pdaRuntimeProcessEventRva=0x3647c0;
constexpr unsigned char pdaRuntimeProcessEventBytes[]={
    0x48,0x89,0x5c,0x24,0x10,0x48,0x89,0x74,0x24,0x18,0x57,0x48,0x83,0xec,0x40,
    0x49,0x8b,0xf8,0x48,0x8b,0xf2,0x48,0x8b,0xd9,0x44,0x8b,0x0d,0xd5,0xe3,0xc0,0x00,0x65};
constexpr std::array<std::uintptr_t,4> pdaThunkRvas={0x536990a,0x538e82a,0x538e04a,0x53a1d1c};
// Exact native exec registrations in the shipping PE, independently identified
// by ANSI-name/function pairs at 848f6b0,849d8d0,849d890,84ab810. These pointers
// identify the four UFunctions independently of caller-provided object names.
constexpr unsigned char pdaGeometryThunkBytes[]={0x56,0x48,0x83,0xec,0x20,0x4c,0x89,0xc6,0x48,0x8b,0x42,0x20,0x48,0x83,0xf8,0x01,0x48,0x83,0xd8,0xff,0x48,0x89,0x42,0x20,0xe8,0x81,0x79,0x82,0xfb};
constexpr unsigned char pdaSizeThunkBytes[]={0x56,0x57,0x48,0x83,0xec,0x68,0x4c,0x89,0xc6,0x48,0x89,0xd7,0x48,0x8b,0x05,0x83,0xd2,0xb0,0x04};
constexpr unsigned char pdaAbsoluteThunkBytes[]={0x56,0x57,0x53,0x48,0x81,0xec,0xb0,0x00,0x00,0x00,0x44,0x0f,0x29,0x8c,0x24,0xa0,0x00,0x00,0x00,0x44,0x0f,0x29,0x84,0x24,0x90,0x00,0x00,0x00};
constexpr unsigned char pdaMouseThunkBytes[]={0x56,0x57,0x48,0x83,0xec,0x38,0x48,0x8b,0x05,0x97,0x9d,0xaf,0x04,0x48,0x31,0xe0};
constexpr unsigned char pdaGeometryCopyBytes[]={0x48,0x89,0xc8,0x48,0x39,0xd1,0x74,0x1e,0x48,0x8b,0x4a,0x30,0x48,0x89,0x48,0x30};
struct PdaGeometryProfile {
    bool ready=false;
    std::uintptr_t image=0,chunksAddress=0,countAddress=0;
    PdaProcessEvent processEvent=nullptr;
    DWORD thread=0;
    unsigned error=2;
} pdaGeometryProfile;
INIT_ONCE pdaGeometryInitialized=INIT_ONCE_STATIC_INIT;
struct PdaGeometryRequest {std::uint64_t token=0;std::array<std::uintptr_t,7> addresses{};};
struct PdaGeometryResult {std::uint64_t token=0;unsigned code=0;double width=0,height=0,x=0,y=0;};
struct PdaObject {std::uintptr_t address=0;ObjectIdentity identity{};std::int32_t serial=0;};
struct PdaProperty {std::uintptr_t address=0,structure=0;int offset=0,size=0;std::uint64_t flags=0;};
struct PdaFunction {
    PdaObject object{};
    unsigned size=0,returnOffset=0,inputCount=0;
    std::array<PdaProperty,2> inputs{};
    PdaProperty output{};
};
bool pdaGameProfileBytes(const unsigned char* image) {
    return bytesMatch(image,pdaThunkRvas[0],pdaGeometryThunkBytes,sizeof(pdaGeometryThunkBytes)) &&
        bytesMatch(image,pdaThunkRvas[1],pdaSizeThunkBytes,sizeof(pdaSizeThunkBytes)) &&
        bytesMatch(image,pdaThunkRvas[2],pdaAbsoluteThunkBytes,sizeof(pdaAbsoluteThunkBytes)) &&
        bytesMatch(image,pdaThunkRvas[3],pdaMouseThunkBytes,sizeof(pdaMouseThunkBytes)) &&
        bytesMatch(image,0x26ec732,pdaGeometryCopyBytes,sizeof(pdaGeometryCopyBytes));
}
bool pdaRuntimeProfile(HMODULE runtime,PdaProcessEvent& processEvent) {
    if (!runtime) return false;
    const auto image=reinterpret_cast<const unsigned char*>(runtime);
    __try {
        const auto dos=reinterpret_cast<const IMAGE_DOS_HEADER*>(image);
        if (dos->e_magic!=IMAGE_DOS_SIGNATURE || dos->e_lfanew<=0 || dos->e_lfanew>4096) return false;
        const auto nt=reinterpret_cast<const IMAGE_NT_HEADERS64*>(image+dos->e_lfanew);
        if (nt->Signature!=IMAGE_NT_SIGNATURE || nt->FileHeader.Machine!=IMAGE_FILE_MACHINE_AMD64 ||
            nt->FileHeader.TimeDateStamp!=0x6a880a94 || nt->OptionalHeader.SizeOfImage!=0xfca000) return false;
        const auto exported=GetProcAddress(runtime,pdaProcessEventExport);
        if (reinterpret_cast<const unsigned char*>(exported)!=image+pdaRuntimeProcessEventRva ||
            std::memcmp(image+pdaRuntimeProcessEventRva,pdaRuntimeProcessEventBytes,sizeof(pdaRuntimeProcessEventBytes))) return false;
        processEvent=reinterpret_cast<PdaProcessEvent>(exported);return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
}
BOOL CALLBACK initializePdaGeometry(PINIT_ONCE,void*,void**) {
    const auto game=GetModuleHandleW(nullptr);const auto image=reinterpret_cast<const unsigned char*>(game);
    if (!verifiedImageIdentity(game) || !pdaGameProfileBytes(image)) {pdaGeometryProfile.error=2;return TRUE;}
    // This exact installed UE4SS wrapper is also used by LuaUObject.cpp:244.
    // It resolves its configured runtime vtable map itself; no slot is guessed,
    // no FFrame is fabricated and ProcessEvent/action-pump hooks are not enabled.
    if (!pdaRuntimeProfile(GetModuleHandleW(L"UE4SS.dll"),pdaGeometryProfile.processEvent)) {pdaGeometryProfile.error=3;return TRUE;}
    pdaGeometryProfile.image=reinterpret_cast<std::uintptr_t>(image);
    pdaGeometryProfile.chunksAddress=pdaGeometryProfile.image+0xa0e68d0;
    pdaGeometryProfile.countAddress=pdaGeometryProfile.image+0xa0e68e4;
    pdaGeometryProfile.thread=GetCurrentThreadId();pdaGeometryProfile.ready=true;pdaGeometryProfile.error=0;return TRUE;
}
bool pdaPointer(std::uintptr_t value) {return value>=0x10000 && value<0x0000800000000000ull && !(value&7);}
bool pdaCapture(std::uintptr_t address,PdaObject& object) {
    object.address=address;
    std::uint32_t flags=0,slotFlags=0;std::int32_t count=0;std::uintptr_t chunks=0,chunk=0,actual=0;
    if (!pdaPointer(address) || !objectIdentity(address,object.identity) || !artifactRead(address+8,flags) ||
        (flags&0x18000u) || !artifactRead(pdaGeometryProfile.countAddress,count) || count<1 || count>32000000 ||
        object.identity.internalIndex>=count || !artifactRead(pdaGeometryProfile.chunksAddress,chunks) ||
        !pdaPointer(chunks) || !artifactRead(chunks+static_cast<std::uintptr_t>(object.identity.internalIndex/65536)*8,chunk) || !pdaPointer(chunk)) return false;
    const auto slot=chunk+static_cast<std::uintptr_t>(object.identity.internalIndex%65536)*24;
    return artifactRead(slot,actual) && actual==address && artifactRead(slot+8,slotFlags) && !(slotFlags&0x10200000u) &&
        artifactRead(slot+16,object.serial) && object.serial>=0;
}
bool pdaLive(PdaObject& object) {
    PdaObject current;
    if (!pdaCapture(object.address,current) || !sameIdentity(current.identity,object.identity) ||
        (object.serial>0 && object.serial!=current.serial)) return false;
    object.serial=current.serial;return true;
}
bool pdaContext(const PdaObject& context,std::uintptr_t function) {
    std::uintptr_t owner=0,klass=context.identity.klass;
    if (!artifactRead(function+0x20,owner) || !pdaPointer(owner)) return false;
    for (unsigned depth=0;depth<32 && klass;++depth) {
        PdaObject current;
        if (!pdaCapture(klass,current)) return false;
        if (klass==owner) return true;
        if (!artifactRead(klass+0x40,klass)) return false;
    }
    return false;
}
bool pdaFunction(std::uintptr_t address,unsigned kind,const PdaObject& context,PdaFunction& function) {
    std::uint32_t flags=0;std::uint8_t count=0;std::uint16_t size=0,returnOffset=0;
    std::uintptr_t thunk=0,field=0;std::array<std::uintptr_t,3> seen{};
    if (kind>=pdaThunkRvas.size() || !pdaCapture(address,function.object) || !pdaContext(context,address) ||
        !artifactRead(address+0xb0,flags) || !(flags&0x400u) || ((kind>0)!=((flags&0x2000u)!=0)) ||
        !artifactRead(address+0xb4,count) || count!=(kind==1?2u:kind==2?3u:1u) ||
        !artifactRead(address+0xb6,size) || !size || size>256 ||
        !artifactRead(address+0xb8,returnOffset) || returnOffset>=size ||
        !artifactRead(address+0xd8,thunk) || thunk!=pdaGeometryProfile.image+pdaThunkRvas[kind] ||
        !artifactRead(address+0x50,field)) return false;
    function.size=size;function.returnOffset=returnOffset;
    for (unsigned i=0;i<count;++i) {
        if (!pdaPointer(field)) return false;
        for (unsigned j=0;j<i;++j) if (seen[j]==field) return false;
        seen[i]=field;PdaProperty property;property.address=field;int arrayDim=0;
        if (!artifactRead(field+0x30,arrayDim) || arrayDim!=1 || !artifactRead(field+0x34,property.size) ||
            (property.size!=56 && property.size!=16) || !artifactRead(field+0x38,property.flags) || !(property.flags&0x80ull) ||
            !artifactRead(field+0x44,property.offset) || property.offset<0 ||
            static_cast<unsigned>(property.offset)>size || static_cast<unsigned>(property.size)>size-static_cast<unsigned>(property.offset) ||
            !artifactRead(field+0x70,property.structure)) return false;
        PdaObject structure;int structSize=0;
        if (!pdaCapture(property.structure,structure) || !artifactRead(property.structure+0x58,structSize) || structSize!=property.size) return false;
        if (property.flags&0x400ull) {
            if (function.output.address || property.offset!=returnOffset) return false;
            function.output=property;
        } else {
            if (function.inputCount>=function.inputs.size()) return false;
            function.inputs[function.inputCount++]=property;
        }
        if (!artifactRead(field+0x18,field)) return false;
    }
    if (field || !function.output.address || function.inputCount+1!=count) return false;
    std::array<PdaProperty,3> regions={function.output,function.inputs[0],function.inputs[1]};
    for (unsigned i=0;i<count;++i) for (unsigned j=i+1;j<count;++j)
        if (regions[i].offset<regions[j].offset+regions[j].size && regions[j].offset<regions[i].offset+regions[i].size) return false;
    return function.output.size==(kind==0?56:16);
}
bool pdaDescriptors(const std::array<PdaFunction,4>& functions) {
    const auto geometry=functions[0].output.structure,vector=functions[1].output.structure;
    return functions[0].inputCount==0 && functions[1].inputCount==1 && functions[2].inputCount==2 && functions[3].inputCount==0 &&
        functions[1].inputs[0].size==56 && functions[1].inputs[0].structure==geometry &&
        functions[2].inputs[0].size==56 && functions[2].inputs[0].structure==geometry &&
        functions[2].inputs[1].size==16 && functions[2].inputs[1].structure==vector &&
        functions[2].output.structure==vector && functions[3].output.structure==vector;
}
// Keep SEH separate from C++ unwinding. The wrapper's missing-map exception is
// handled by the outer C++ catch; invalid memory faults reject the sample.
int pdaExceptionFilter(unsigned code) {return code==0xe06d7363u?EXCEPTION_CONTINUE_SEARCH:EXCEPTION_EXECUTE_HANDLER;}
bool pdaInvokeSeh(PdaProcessEvent invoke,std::uintptr_t context,std::uintptr_t function,void* parameters) {
    __try {invoke(reinterpret_cast<void*>(context),reinterpret_cast<void*>(function),parameters);return true;}
    __except(pdaExceptionFilter(GetExceptionCode())) {return false;}
}
bool pdaInvoke(PdaObject& context,PdaFunction& function,void* parameters) {
    if (!pdaLive(context) || !pdaLive(function.object)) return false;
    bool called=false;
    try {called=pdaInvokeSeh(pdaGeometryProfile.processEvent,context.address,function.object.address,parameters);} catch (...) {return false;}
    return called && pdaLive(context) && pdaLive(function.object);
}
bool pdaGeometrySample(const PdaGeometryRequest& request,PdaGeometryResult& result) {
    result.token=request.token;
    if (!pdaGeometryProfile.ready) {result.code=pdaGeometryProfile.error;return false;}
    if (pdaGeometryProfile.thread!=GetCurrentThreadId()) {result.code=4;return false;}
    std::array<PdaObject,3> contexts{};
    if (!pdaCapture(request.addresses[0],contexts[0]) || !pdaCapture(request.addresses[2],contexts[1]) ||
        !pdaCapture(request.addresses[5],contexts[2])) {result.code=5;return false;}
    std::array<PdaFunction,4> functions{};
    const std::array<unsigned,4> requestIndices={1,3,4,6},contextIndices={0,1,1,2};
    for (unsigned i=0;i<functions.size();++i) if (!pdaFunction(request.addresses[requestIndices[i]],i,contexts[contextIndices[i]],functions[i])) {
        result.code=6+i;return false;
    }
    if (!pdaDescriptors(functions)) {result.code=10;return false;}
    alignas(16) std::array<unsigned char,256> geometry{},size{},mouse{},local{};
    if (!pdaInvoke(contexts[0],functions[0],geometry.data())) {result.code=11;return false;}
    // Never reinterpret FGeometry or rebuild it from a Lua table. Preserve all
    // native bytes, including render/layout transforms and padding, unchanged.
    std::memcpy(size.data()+functions[1].inputs[0].offset,geometry.data()+functions[0].returnOffset,56);
    std::memcpy(local.data()+functions[2].inputs[0].offset,geometry.data()+functions[0].returnOffset,56);
    if (!pdaInvoke(contexts[1],functions[1],size.data())) {result.code=12;return false;}
    if (!pdaInvoke(contexts[2],functions[3],mouse.data())) {result.code=13;return false;}
    std::memcpy(local.data()+functions[2].inputs[1].offset,mouse.data()+functions[3].returnOffset,16);
    if (!pdaInvoke(contexts[1],functions[2],local.data())) {result.code=14;return false;}
    std::memcpy(&result.width,size.data()+functions[1].returnOffset,8);
    std::memcpy(&result.height,size.data()+functions[1].returnOffset+8,8);
    std::memcpy(&result.x,local.data()+functions[2].returnOffset,8);
    std::memcpy(&result.y,local.data()+functions[2].returnOffset+8,8);
    for (auto& context:contexts) if (!pdaLive(context)) {result.code=15;return false;}
    if (!std::isfinite(result.width) || !std::isfinite(result.height) || result.width<=1 || result.height<=1 ||
        result.width>1000000 || result.height>1000000 || !std::isfinite(result.x) || !std::isfinite(result.y) ||
        std::abs(result.x)>1000000000 || std::abs(result.y)>1000000000) {result.code=16;return false;}
    result.code=0;return true;
}
bool pdaParseRequest(const char* text,PdaGeometryRequest& request) {
    if (!text || std::strncmp(text,"ZFPVPG51 ",9) || std::strchr(text,'-') || std::strchr(text,'+')) return false;
    unsigned long long token=0,values[7]{};char trailing=0;
    const auto parsed=sscanf_s(text,"ZFPVPG51 %llu %llx %llx %llx %llx %llx %llx %llx %c",&token,
        &values[0],&values[1],&values[2],&values[3],&values[4],&values[5],&values[6],&trailing,1u);
    request.token=token;
    if (parsed!=8 || !token) return false;
    for (unsigned i=0;i<request.addresses.size();++i) {request.addresses[i]=values[i];if (!pdaPointer(request.addresses[i])) return false;}
    return true;
}
std::wstring pdaDirectory() {
    if (!root.empty()) return root;
    wchar_t filename[32768]{};const auto count=GetModuleFileNameW(bridgeModule,filename,32768);
    if (!count || count>=32768) return {};
    std::wstring directory(filename,count);const auto slash=directory.find_last_of(L"\\/");
    if (slash==std::wstring::npos) return {};
    directory.resize(slash+1);return directory;
}
void pdaReport(const std::wstring& directory,const PdaGeometryResult& result,bool ok) {
    const auto path=directory+L"native-pda-geometry-status.txt",temporary=path+L".tmp";FILE* file=nullptr;
    if (_wfopen_s(&file,temporary.c_str(),L"wb") || !file) return;
    // A failed call must never expose partially sampled or stale coordinates.
    const bool wrote=std::fprintf(file,"ZFPVPG51 %llu %u %u %.17g %.17g %.17g %.17g\n",
        static_cast<unsigned long long>(result.token),ok?1u:0u,result.code,
        ok?result.width:0.0,ok?result.height:0.0,ok?result.x:0.0,ok?result.y:0.0)>0;
    const int closed=std::fclose(file);
    if (wrote && !closed) MoveFileExW(temporary.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);else DeleteFileW(temporary.c_str());
}
}
extern "C" __declspec(dllexport) int zonefpv_pda_geometry_query(void*) {
    const auto directory=pdaDirectory();if (directory.empty()) return 0;
    InitOnceExecuteOnce(&pdaGeometryInitialized,initializePdaGeometry,nullptr,nullptr);
    PdaGeometryRequest request;FILE* file=nullptr;bool parsed=false;
    const auto path=directory+L"native-pda-geometry-control.txt";
    if (!_wfopen_s(&file,path.c_str(),L"rb") && file) {
        char text[512]{};const auto count=std::fread(text,1,sizeof(text)-1,file);const int extra=std::fgetc(file);std::fclose(file);
        parsed=count>0 && count<sizeof(text)-1 && extra==EOF && !std::memchr(text,0,count) && pdaParseRequest(text,request);
    }
    DeleteFileW(path.c_str());
    PdaGeometryResult result;result.token=request.token;bool ok=false;
    if (!parsed) result.code=1;else ok=pdaGeometrySample(request,result);
    pdaReport(directory,result,ok);return 0;
}
