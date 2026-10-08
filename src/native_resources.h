#pragma once
// Read-only pressure telemetry. The signature and offsets are proven against
// this exact game build and the installed UE4SS GUObjectArray resolver.
namespace {
struct ResourceArray {int maximum=0,highWater=0;};
bool resourceArrayBytes(const unsigned char* image,ResourceArray& out) {
    if (!image) return false;
    constexpr unsigned char proof[]={0x56,0x53,0x48,0x83,0xec,0x28,0x44,0x89,0xc3,0x89,0xce,0x89,0x15,0x23,0x2e,0xfb,0x06,0x31,0xc0,0x85,0xd2,0x0f,0x9f,0xc0};
    if (!bytesMatch(image,0x3133a94,proof,sizeof(proof))) return false;
    __try {
        std::int32_t displacement=0;
        std::memcpy(&displacement,image+0x3133a94+13,4);
        const auto array=image+0x3133a94+17+displacement-8;
        if (array!=image+0xa0e68c0) return false;
        const auto chunks=*reinterpret_cast<const std::uintptr_t*>(array+0x10);
        const auto maximum=*reinterpret_cast<const int*>(array+0x20);
        const auto highWater=*reinterpret_cast<const int*>(array+0x24);
        const auto maxChunks=*reinterpret_cast<const int*>(array+0x28);
        const auto numChunks=*reinterpret_cast<const int*>(array+0x2c);
        if (chunks<0x10000 || maximum<65536 || maximum>32000000 || highWater<0 || highWater>maximum ||
            maxChunks<1 || maxChunks>512 || numChunks<1 || numChunks>maxChunks || maximum>maxChunks*65536 || highWater>numChunks*65536) return false;
        out={maximum,highWater};return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
}
bool resourceArray(ResourceArray& out) {
    const auto game=GetModuleHandleW(nullptr);
    return verifiedImageIdentity(game) && resourceArrayBytes(reinterpret_cast<const unsigned char*>(game),out);
}
}
extern "C" __declspec(dllexport) int zonefpv_resources_poll(void*) {
    wchar_t filename[32768]{};
    const auto length=GetModuleFileNameW(bridgeModule,filename,32768);
    if (!length || length>=32768) return 0;
    std::wstring directory(filename,length);
    const auto slash=directory.find_last_of(L"\\/");if (slash==std::wstring::npos) return 0;
    directory.resize(slash+1);
    MEMORYSTATUSEX memory{};memory.dwLength=sizeof(memory);
    if (!GlobalMemoryStatusEx(&memory)) return 0;
    ResourceArray array;const bool known=resourceArray(array);
    static unsigned long long sequence=0;
    const auto path=directory+L"native-resources-status.txt",temp=path+L".tmp";
    FILE* output=nullptr;if (_wfopen_s(&output,temp.c_str(),L"wb") || !output) return 0;
    const bool wrote=std::fprintf(output,"ZFPVR11 %llu %llu %llu %u %d %d\n",++sequence,
        memory.ullAvailPhys/1048576ull,memory.ullAvailPageFile/1048576ull,known?1u:0u,array.highWater,array.maximum)>0;
    const int closed=std::fclose(output);
    if (wrote && closed==0) MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING);
    else DeleteFileW(temp.c_str());
    return 0;
}
