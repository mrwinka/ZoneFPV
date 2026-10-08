namespace {
unsigned geigerOriginalCalls=0;
void __fastcall geigerOriginalFixture(void*) {++geigerOriginalCalls;}
unsigned geigerStopCalls=0;
void __fastcall geigerStopFixture(void* component) {
    ++geigerStopCalls;reinterpret_cast<unsigned char*>(component)[0xc8]=0;
}
void geigerFixtureTests() {
    alignas(8) std::array<unsigned char,0xe0> component{},other{};
    alignas(8) std::array<unsigned char,0x30> pawn{};
    const auto put=[](auto& bytes,std::size_t offset,const auto& value){std::memcpy(bytes.data()+offset,&value,sizeof(value));};
    const auto image=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    const auto actor=reinterpret_cast<std::uintptr_t>(pawn.data());
    const auto object=reinterpret_cast<std::uintptr_t>(component.data());
    put(component,0,image+0x8ccc0c0);put(component,0x10,std::uintptr_t{0x20000});put(component,0xc0,actor);
    put(pawn,0,image+0x8d8df10);put(pawn,0x10,std::uintptr_t{0x30000});
    originalGeigerUpdate=&geigerOriginalFixture;geiger=GeigerState{};geiger.component=object;geiger.pawn=actor;
    assert(objectIdentity(object,geiger.componentIdentity) && objectIdentity(actor,geiger.pawnIdentity));
    geiger.refreshed=GetTickCount64();quickGeiger.store(object);
    geigerUpdateHook(component.data());assert(geiger.blocked==1 && geigerOriginalCalls==0);
    geigerUpdateHook(other.data());assert(geiger.blocked==1 && geigerOriginalCalls==1);
    geiger.refreshed=GetTickCount64()-leaseMilliseconds-1;
    geigerUpdateHook(component.data());assert(geigerOriginalCalls==2);
    geiger.refreshed=GetTickCount64();component[0x18]=1;
    geigerUpdateHook(component.data());assert(geigerOriginalCalls==3);component[0x18]=0;
    put(component,0xc0,std::uintptr_t{0});geigerUpdateHook(component.data());assert(geigerOriginalCalls==4);put(component,0xc0,actor);
    put(pawn,8,0x8000u);geigerUpdateHook(component.data());assert(geigerOriginalCalls==5);put(pawn,8,0u);
    quickGeiger.store(0);geigerUpdateHook(component.data());assert(geigerOriginalCalls==6);
    assert(geiger.blocked==1);
    bool stopped=false;stopGeiger=&geigerStopFixture;
    assert(stopOwnedGeiger(geiger,stopped) && !stopped && geigerStopCalls==0);
    component[0xc8]=1;
    assert(stopOwnedGeiger(geiger,stopped) && stopped && geigerStopCalls==1 && component[0xc8]==0);
    assert(stopOwnedGeiger(geiger,stopped) && !stopped && geigerStopCalls==1);
    component[0xc8]=1;put(component,0xc0,std::uintptr_t{0});
    assert(!stopOwnedGeiger(geiger,stopped) && !stopped && geigerStopCalls==1 && component[0xc8]==1);
    put(component,0xc0,actor);geiger.component=object;geiger.token=12;
    maintainGeigerStop();assert(geiger.stopped==1 && geigerStopCalls==2);
    maintainGeigerStop();assert(geiger.stopped==1 && geigerStopCalls==2);
    geiger=GeigerState{};originalGeigerUpdate=nullptr;stopGeiger=nullptr;
    std::cout << "PASS native Geiger gate: only owned live component blocked; foreign component, changed identity/owner, destroying pawn, expired lease and disarm forwarded\n";
}
}
