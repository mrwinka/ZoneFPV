namespace {
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
    std::cout << "PASS native resource telemetry: relocated GUObjectArray proof, 720896 capacity/high-water read without writes, malformed counts and operand rejected\n";
}
}
