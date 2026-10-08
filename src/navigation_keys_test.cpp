#define wmain bridgeMain
#include "input.cpp"
#undef wmain
#include <cassert>
int main(){
    navigationKeys::State state;
    state.sample(false,false,false);state.sample(true,true,false);
    assert(state.qSequence==0&&state.eSequence==0);
    state.sample(true,false,false);state.sample(true,true,false);
    state.sample(true,true,false);state.sample(true,false,false);
    assert(state.qSequence==1&&state.eSequence==0&&!state.qHeld);
    state.sample(true,false,true);state.sample(true,false,false);
    assert(state.eSequence==1&&!state.eHeld);
    state.sample(false,false,false);state.sample(true,true,true);
    assert(state.qSequence==1&&state.eSequence==1);
    state.sample(true,false,false);state.sample(true,true,false);
    assert(state.qSequence==2&&state.eSequence==1);
    const auto root=fs::temp_directory_path()/(L"ZoneFPV-navigation-test-"+std::to_wstring(GetCurrentProcessId()));
    fs::create_directories(root);
    assert(navigationKeys::publish(root,state,true,false,false));
    std::ifstream packet(root/L"pda-navigation.txt");
    int version=0,focus=0,q=0,e=0;ULONGLONG seq=0,qSeq=0,eSeq=0,end=0;long long epoch=0;std::string extra;
    assert(packet>>version>>seq>>epoch>>focus>>q>>e>>qSeq>>eSeq>>end);
    assert(!(packet>>extra));packet.close();
    assert(version==1&&seq==state.sequence&&end==seq&&epoch>0&&focus==1&&q==0&&e==0&&qSeq==2&&eSeq==1);
    assert(!fs::exists(root/L"pda-navigation.tmp"));
    assert(fs::remove(root/L"pda-navigation.txt")&&fs::remove(root));
    std::cout<<"PASS short PDA taps, held keys, focus return and atomic keyboard packet publication\n";
}
