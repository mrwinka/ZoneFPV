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
struct ResourceStatusFile {
    HANDLE handle=INVALID_HANDLE_VALUE;
    DWORD previousLength=0;
    std::wstring requestedPath,openedName;
    ResourceStatusFile()=default;
    ResourceStatusFile(const ResourceStatusFile&)=delete;
    ResourceStatusFile& operator=(const ResourceStatusFile&)=delete;
    ~ResourceStatusFile() {close();}
    void close() {
        if (handle!=INVALID_HANDLE_VALUE) CloseHandle(handle);
        handle=INVALID_HANDLE_VALUE;previousLength=0;requestedPath.clear();openedName.clear();
    }
    bool sameName(bool first) {
        wchar_t name[32768]{};
        const DWORD length=GetFinalPathNameByHandleW(handle,name,32768,FILE_NAME_NORMALIZED|VOLUME_NAME_DOS);
        if (!length || length>=32768) return false;
        if (first) {openedName.assign(name,length);return true;}
        return openedName.size()==length && std::memcmp(openedName.data(),name,length*sizeof(wchar_t))==0;
    }
    bool write(const std::wstring& path,const char* packet,DWORD length) {
        // The Lua owner reads this snapshot synchronously after poll returns.
        // Reuse one shared handle instead of creating, closing and renaming
        // a temporary file on every game-thread sample. No disk durability is
        // needed for this disposable status; WriteFile completion makes the
        // bytes available to that subsequent reader through the system cache.
        if (handle!=INVALID_HANDLE_VALUE) {
            FILE_STANDARD_INFO info{};
            if (requestedPath!=path || !GetFileInformationByHandleEx(handle,FileStandardInfo,&info,sizeof(info)) ||
                info.DeletePending || !sameName(false)) close();
        }
        if (handle==INVALID_HANDLE_VALUE) {
            handle=CreateFileW(path.c_str(),GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
                nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
            if (handle==INVALID_HANDLE_VALUE) return false;
            requestedPath=path;
            if (!sameName(true)) {close();return false;}
        }
        const LARGE_INTEGER start{};
        DWORD written=0;
        const bool good=SetFilePointerEx(handle,start,nullptr,FILE_BEGIN) &&
            WriteFile(handle,packet,length,&written,nullptr) && written==length &&
            (length>=previousLength || SetEndOfFile(handle));
        if (!good) {
            close();DeleteFileW(path.c_str());return false;
        }
        previousLength=length;return true;
    }
};
struct ResourcePollLock {
    SRWLOCK* lock;
    explicit ResourcePollLock(SRWLOCK& value):lock(&value) {AcquireSRWLockExclusive(lock);}
    ~ResourcePollLock() {ReleaseSRWLockExclusive(lock);}
    ResourcePollLock(const ResourcePollLock&)=delete;
    ResourcePollLock& operator=(const ResourcePollLock&)=delete;
};
}
// Capability marker only. New Lua can retain an unbuffered reader because
// this DLL overwrites the same status file instead of replacing its inode.
// Older DLLs lack this export and keep the open/read/close reader path.
extern "C" __declspec(dllexport) int zonefpv_resources_persistent_io(void*) {return 0;}
extern "C" __declspec(dllexport) int zonefpv_resources_poll(void*) {
    MEMORYSTATUSEX memory{};memory.dwLength=sizeof(memory);
    if (!GlobalMemoryStatusEx(&memory)) return 0;
    ResourceArray array;const bool known=resourceArray(array);
    static SRWLOCK lock=SRWLOCK_INIT;
    const ResourcePollLock held(lock);
    static std::wstring path;
    static ResourceStatusFile output;
    if (path.empty()) {
        wchar_t filename[32768]{};
        const auto length=GetModuleFileNameW(bridgeModule,filename,32768);
        if (!length || length>=32768) return 0;
        path.assign(filename,length);
        const auto slash=path.find_last_of(L"\\/");
        if (slash==std::wstring::npos) {path.clear();return 0;}
        path.resize(slash+1);path+=L"native-resources-status.txt";
    }
    static unsigned long long sequence=0;
    char packet[160]{};
    const int length=std::snprintf(packet,sizeof(packet),"ZFPVR11 %llu %llu %llu %u %d %d\n",++sequence,
        memory.ullAvailPhys/1048576ull,memory.ullAvailPageFile/1048576ull,known?1u:0u,array.highWater,array.maximum);
    if (length>0 && static_cast<std::size_t>(length)<sizeof(packet)) output.write(path,packet,static_cast<DWORD>(length));
    return 0;
}
