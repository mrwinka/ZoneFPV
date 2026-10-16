namespace {
FILE* openResourceFixture(const std::wstring& path) {
    // Lua's liolib uses ordinary fopen. Secure fopen_s uses _SH_SECURE and
    // intentionally denies an already-open writer, unlike that real reader.
#pragma warning(push)
#pragma warning(disable:4996)
    FILE* input=_wfopen(path.c_str(),L"rb");
#pragma warning(pop)
    assert(input);return input;
}
std::string readResourceFixture(FILE* input) {
    assert(std::fseek(input,0,SEEK_SET)==0);
    char packet[161]{};
    const auto length=std::fread(packet,1,sizeof(packet),input);
    assert(!std::ferror(input));
    return std::string(packet,length);
}
std::string readResourceFixture(const std::wstring& path) {
    FILE* input=openResourceFixture(path);const auto packet=readResourceFixture(input);
    assert(std::fclose(input)==0);return packet;
}
void resourceWriterFixtureTests() {
    wchar_t temporary[MAX_PATH]{},directory[MAX_PATH]{};
    assert(GetTempPathW(MAX_PATH,temporary)>0 && GetTempFileNameW(temporary,L"zfr",0,directory));
    assert(DeleteFileW(directory));
    const std::wstring rootPath=directory;
    const auto path=rootPath+L"\\native-resources-status.txt";
    const auto renamed=path+L".old";
    const std::string longPacket="ZFPVR11 123456789012345 1099511627776 1099511627776 1 31999999 32000000\n";
    const std::string shortPacket="ZFPVR11 2 1 1 0 0 0\n";
    ResourceStatusFile writer;
    assert(!writer.write(path,longPacket.data(),static_cast<DWORD>(longPacket.size())) && writer.handle==INVALID_HANDLE_VALUE);
    assert(CreateDirectoryW(directory,nullptr));
    assert(writer.write(path,longPacket.data(),static_cast<DWORD>(longPacket.size())));
    const auto persistent=writer.handle;
    FILE* retained=openResourceFixture(path);assert(std::setvbuf(retained,nullptr,_IONBF,0)==0);
    for (int i=0;i<500;++i) {
        const auto& packet=i%2?longPacket:shortPacket;
        assert(writer.write(path,packet.data(),static_cast<DWORD>(packet.size())));
        assert(writer.handle==persistent && "Successful polls reuse exactly one file handle");
        assert(readResourceFixture(path)==packet && "A shorter packet must never retain bytes from its predecessor");
        assert(readResourceFixture(retained)==packet && "A retained unbuffered CRT reader observes changing RAM/commit/object fields and packet lengths");
    }
    assert(std::fclose(retained)==0);
    const HANDLE shared=CreateFileW(path.c_str(),GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
        nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    assert(shared!=INVALID_HANDLE_VALUE && "The cached writer permits shared readers, writers and deletion");
    assert(writer.write(path,shortPacket.data(),static_cast<DWORD>(shortPacket.size())));
    assert(CloseHandle(shared));
    assert(DeleteFileW(path.c_str()));
    assert(writer.write(path,longPacket.data(),static_cast<DWORD>(longPacket.size())));
    assert(readResourceFixture(path)==longPacket && "Deleting an open shared snapshot must recover on the next sample");
    assert(MoveFileExW(path.c_str(),renamed.c_str(),0));
    FILE* replacement=nullptr;
    assert(_wfopen_s(&replacement,path.c_str(),L"wb")==0 && replacement);
    assert(std::fputs("stale replacement",replacement)>=0 && std::fclose(replacement)==0);
    assert(writer.write(path,shortPacket.data(),static_cast<DWORD>(shortPacket.size())));
    assert(readResourceFixture(path)==shortPacket && readResourceFixture(renamed)==longPacket &&
        "A replacement at the old path cannot leave the publisher writing the renamed inode");
    writer.close();
    const HANDLE blocked=CreateFileW(path.c_str(),GENERIC_READ,0,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    assert(blocked!=INVALID_HANDLE_VALUE);
    assert(!writer.write(path,longPacket.data(),static_cast<DWORD>(longPacket.size())) && writer.handle==INVALID_HANDLE_VALUE);
    assert(CloseHandle(blocked));
    assert(writer.write(path,longPacket.data(),static_cast<DWORD>(longPacket.size())) && readResourceFixture(path)==longPacket);
    writer.close();
    assert(DeleteFileW(path.c_str()) && DeleteFileW(renamed.c_str()) && RemoveDirectoryW(directory));
    std::cout << "PASS resource snapshot writer: one shared handle, 500 alternating packet lengths and memory fields, immediate/reused unbuffered CRT reads, missing directory/sharing failure/delete/rename-and-replace recovery\n";
}
void resourceFixtureTests() {
    auto* image=static_cast<unsigned char*>(VirtualAlloc(nullptr,gameImageSize,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE));
    assert(image);
    constexpr unsigned char proof[]={0x56,0x53,0x48,0x83,0xec,0x28,0x44,0x89,0xc3,0x89,0xce,0x89,0x15,0x23,0x2e,0xfb,0x06,0x31,0xc0,0x85,0xd2,0x0f,0x9f,0xc0};
    std::memcpy(image+0x3133a94,proof,sizeof(proof));
    auto* array=image+0xa0e68c0;
    const std::uintptr_t chunks=0x20000;std::memcpy(array+0x10,&chunks,8);
    const int maximum=720896,highWater=700000,maxChunks=11,numChunks=11;
    std::memcpy(array+0x20,&maximum,4);std::memcpy(array+0x24,&highWater,4);
    std::memcpy(array+0x28,&maxChunks,4);std::memcpy(array+0x2c,&numChunks,4);
    std::array<unsigned char,0x30> before{};std::memcpy(before.data(),array,before.size());
    ResourceArray sampled;assert(resourceArrayBytes(image,sampled) && sampled.maximum==maximum && sampled.highWater==highWater);
    assert(std::memcmp(before.data(),array,before.size())==0 && "pressure telemetry never writes the live object array");
    array[0x2c]=10;assert(!resourceArrayBytes(image,sampled));array[0x2c]=11;
    const int tooMany=maximum+1;std::memcpy(array+0x24,&tooMany,4);assert(!resourceArrayBytes(image,sampled));
    std::memcpy(array+0x24,&highWater,4);image[0x3133a94+13]^=1;assert(!resourceArrayBytes(image,sampled));
    assert(!resourceArrayBytes(nullptr,sampled));assert(VirtualFree(image,0,MEM_RELEASE));
    resourceWriterFixtureTests();
    std::cout << "PASS native resource telemetry: relocated GUObjectArray proof, 720896 capacity/high-water read without writes, malformed counts and operand rejected\n";
}
}
