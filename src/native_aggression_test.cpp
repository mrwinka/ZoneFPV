#include "native_game_bridge.cpp"
#include <cassert>
#include <iostream>

namespace {
struct Fixture {
    alignas(8) std::array<unsigned char,0x658> pawn{};
    alignas(8) std::array<unsigned char,0x148> playerCore{};
    CoreInfo player,actor;
    std::uintptr_t pawnAddress=0,ai=0x900000,focus=0;
    unsigned reads=0,resets=0;
    bool failRead=false,failReset=false,retainFocus=false;
    int changeSecond=0,changeAfter=0;
    Fixture() {
        pawnAddress=reinterpret_cast<std::uintptr_t>(pawn.data());
        const auto vtable=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
        const auto core=reinterpret_cast<std::uintptr_t>(playerCore.data());
        const std::uintptr_t klass=0x200000;
        const std::int32_t index=2;
        const std::uint32_t guid=11;
        std::memcpy(pawn.data(),&vtable,8);std::memcpy(pawn.data()+0xc,&index,4);
        std::memcpy(pawn.data()+0x10,&klass,8);std::memcpy(pawn.data()+0x650,&core,8);
        std::memcpy(playerCore.data()+0x10,&guid,4);
        assert(coreInfo(pawnAddress,player));
        actor.core=0x500000;actor.guid=23;actor.identity=player.identity;actor.identity.internalIndex=7;
        focus=pawnAddress;
    }
    AggressionRow row() const {
        AggressionRow r;r.actor=0x300000;r.expectedGuid=actor.guid;r.expectedCore=actor.core;r.expectedIndex=actor.identity.internalIndex;
        return r;
    }
    void mutate(CoreInfo& out,std::uintptr_t& outAI,std::uintptr_t& outFocus,int change) const {
        switch(change) {
        case 1: ++out.guid;break;
        case 2: out.core+=8;break;
        case 3: ++out.identity.internalIndex;break;
        case 4: ++out.identity.name;break;
        case 5: out.identity.vtable+=8;break;
        case 6: out.identity.klass+=8;break;
        case 7: outAI+=8;break;
        case 8: outFocus=0x600000;break;
        default: break;
        }
    }
    void process(AggressionRow& r,bool clear=true) {
        auto snapshot=[this](std::uintptr_t at,CoreInfo& out,std::uintptr_t& outAI,std::uintptr_t& outFocus) {
            assert(at==0x300000);++reads;if(failRead)return false;
            out=actor;outAI=ai;outFocus=focus;
            mutate(out,outAI,outFocus,reads==2?changeSecond:reads>=3?changeAfter:0);
            return true;
        };
        auto reset=[this](std::uintptr_t at) {
            assert(at==ai && reads==2);++resets;
            if(failReset)return false;
            if(!retainFocus)focus=0;
            return true;
        };
        aggressionProcessGuarded(player,pawnAddress,r,clear,snapshot,reset);
    }
};
}
int main() {
    assert(!aggressionProfile() && "the fixture process must never call the installed game profile");
    {
        Fixture f;auto r=f.row();f.process(r,false);
        assert(f.reads==1 && f.resets==0 && r.guid==23 && r.core==0x500000 && r.index==7 && r.focus==f.pawnAddress && !r.cleared);
    }
    {
        Fixture f;auto r=f.row();f.process(r);
        assert(f.reads==3 && f.resets==1 && r.focus==0 && r.cleared==1);
    }
    {
        Fixture f;auto r=f.row();f.focus=0;f.process(r);
        assert(f.reads==1 && f.resets==0 && r.reason==1 && !r.attempted);
    }
    {
        // The proxy was parked after this NPC acquired it. Current aim is
        // already null, but XResetAI must still clear its persistent search.
        Fixture f;auto r=f.row();f.focus=0;r.acquired=1;f.process(r);
        assert(f.reads==3 && f.resets==1 && r.attempted==1 && r.cleared==1 && r.reason==0);
    }
    {
        Fixture f;auto r=f.row();f.focus=0x600000;r.acquired=1;f.process(r);
        assert(f.reads==1 && f.resets==0 && r.reason==2 && !r.attempted);
    }
    for(unsigned mismatch=0;mismatch<4;++mismatch) {
        Fixture f;auto r=f.row();
        switch(mismatch) {case 0:f.focus=0x600000;break;case 1:++r.expectedGuid;break;case 2:r.expectedCore+=8;break;case 3:++r.expectedIndex;break;}
        f.process(r);assert(f.reads==1 && f.resets==0 && !r.cleared);
    }
    for(int change=1;change<=8;++change) {
        Fixture f;auto r=f.row();f.changeSecond=change;f.process(r);
        assert(f.reads==2 && f.resets==0 && !r.cleared && f.focus==f.pawnAddress);
    }
    {
        Fixture f;auto r=f.row();const std::uint32_t changedGuid=12;
        std::memcpy(f.playerCore.data()+0x10,&changedGuid,4);f.process(r);
        assert(f.reads==1 && f.resets==0 && !r.cleared);
    }
    {
        Fixture f;auto r=f.row();r.actor=f.pawnAddress;f.process(r);
        assert(f.reads==0 && f.resets==0 && !r.cleared);
    }
    {
        Fixture f;auto r=f.row();f.failRead=true;f.process(r);assert(f.reads==1 && f.resets==0 && !r.cleared);
    }
    {
        Fixture f;auto r=f.row();f.failReset=true;f.process(r);assert(f.reads==2 && f.resets==1 && !r.cleared);
    }
    {
        Fixture f;auto r=f.row();f.retainFocus=true;f.process(r);assert(f.reads==3 && f.resets==1 && !r.cleared);
    }
    for(int change=1;change<=7;++change) {
        Fixture f;auto r=f.row();f.changeAfter=change;f.process(r);assert(f.resets==1 && !r.cleared);
    }
    assert(!aggressionPointer(0,8) && !aggressionPointer(0x10001,8) && !aggressionPointer(0x800000000000ull,8));
    auto* allocation=VirtualAlloc(nullptr,0x2000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);assert(allocation);
    const auto address=reinterpret_cast<std::uintptr_t>(allocation);
    assert(aggressionPointer(address,0x50) && !aggressionPointer(address,0x10001));
    std::memcpy(allocation,&address,8);std::uintptr_t value=0;
    assert(aggressionReadPointer(address,value) && value==address);
    DWORD old=0;assert(VirtualProtect(allocation,0x2000,PAGE_NOACCESS,&old));
    assert(!aggressionPointer(address,8) && !aggressionReadPointer(address,value));
    assert(VirtualFree(allocation,0,MEM_RELEASE));assert(!aggressionPointer(address,8));
    std::cout << "PASS native aggression v12: matching current pawn focus OR proven acquisition with lost focus resets native AI state; unobserved null focus and third targets preserved, identity/races and readback checked\n";
}
