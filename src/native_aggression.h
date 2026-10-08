#pragma once
// Include at the end of native_game_bridge.cpp, after its identity helpers.
// Installed SDK: CppMediator::GetFocusedEnemy(const AObj*) -> AObj*.
// Exec 0x6702046 calls 0x6b6ea52, which reads actor+650 -> core+660 AI.
// XResetAI exec 0x670add2 -> 0x6bb3ca6 resolves UID pool slot+670 and
// tail-calls 0x32cb53c with RCX=AI. Call that same AI instance directly,
// after target/core/GUID checks; never run the unchecked UID pool resolver.
namespace {
using AggressionFocus=std::uintptr_t(__fastcall*)(void*);
using AggressionReset=void(__fastcall*)(void*);
struct AggressionRow {
    std::uintptr_t actor=0,core=0,focus=0,expectedCore=0;
    std::uint32_t guid=0xffffffffu,expectedGuid=0xffffffffu;
    int index=-1,expectedIndex=-1;
    unsigned cleared=0,acquired=0,attempted=0,reason=0;
};
bool aggressionPointer(std::uintptr_t p,std::size_t size) {
    if (p<0x10000 || p>=0x0000800000000000ull || (p&7) || size>0x10000) return false;
    MEMORY_BASIC_INFORMATION m{};
    return VirtualQuery(reinterpret_cast<void*>(p),&m,sizeof(m))==sizeof(m) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && p+size>=p &&
        p+size<=reinterpret_cast<std::uintptr_t>(m.BaseAddress)+m.RegionSize;
}
bool aggressionReadPointer(std::uintptr_t at,std::uintptr_t& value) {
    __try {value=*reinterpret_cast<const std::uintptr_t*>(at);}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return aggressionPointer(value,sizeof(std::uintptr_t));
}
bool aggressionSame(const CoreInfo& a,const CoreInfo& b) {
    return a.core==b.core && a.guid==b.guid && sameIdentity(a.identity,b.identity);
}
bool aggressionProfile() {
    const auto game=GetModuleHandleW(nullptr);
    // The damage receiver has already been detoured by initialize(). Keep
    // image identity and this feature's exact guards independent of its hook.
    if (!verifiedImageIdentity(game)) return false;
    const auto image=reinterpret_cast<const unsigned char*>(game);
    constexpr unsigned char focus[]={0x56,0x57,0x48,0x83,0xec,0x48,0x48,0x8b,0x05,0x61,0xd0,0x32,0x03,0x48,0x31,0xe0,0x48,0x89,0x44,0x24,0x40,0x48,0x8b,0x81,0x50,0x06,0x00,0x00,0x48,0x8b,0x88,0x60,0x06,0x00,0x00};
    constexpr unsigned char reset[]={0x56,0x48,0x83,0xec,0x20,0x48,0x89,0xce,0x48,0x8b,0x49,0x10,0xb2,0x01,0xe8,0x17,0x06,0xdc,0xfd,0xc6,0x46,0x4c,0x00,0x48,0x8b,0x4e,0x38,0x48,0x8b,0x01,0xff,0x50,0x68};
    constexpr unsigned char resolver[]={0x48,0x69,0xc9,0x00,0x07,0x00,0x00,0x48,0x8b,0x8c,0x08,0x70,0x06,0x00,0x00};
    return bytesMatch(image,0x6b6ea52,focus,sizeof(focus)) && bytesMatch(image,0x32cb53c,reset,sizeof(reset)) &&
        bytesMatch(image,0x6bb3cc2,resolver,sizeof(resolver));
}
bool aggressionCallFocus(std::uintptr_t actor,std::uintptr_t& focus) {
    const auto fn=reinterpret_cast<AggressionFocus>(reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr))+0x6b6ea52);
    __try {focus=fn(reinterpret_cast<void*>(actor));}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    if (!focus) return true;
    ObjectIdentity identity;
    const auto base=reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr));
    return objectIdentity(focus,identity) && identity.vtable>=base && identity.vtable<base+gameImageSize;
}
bool aggressionCallReset(std::uintptr_t ai) {
    const auto fn=reinterpret_cast<AggressionReset>(reinterpret_cast<std::uintptr_t>(GetModuleHandleW(nullptr))+0x32cb53c);
    __try {fn(reinterpret_cast<void*>(ai));}
    __except(EXCEPTION_EXECUTE_HANDLER) {return false;}
    return true;
}
bool aggressionSnapshot(std::uintptr_t actor,CoreInfo& before,std::uintptr_t& ai,std::uintptr_t& focus) {
    if (!coreInfo(actor,before) || !aggressionReadPointer(before.core+0x660,ai) || !aggressionPointer(ai,0x50)) return false;
    // Both native routines dereference AI+38; focus follows its +50 object.
    std::uintptr_t model=0,focusProvider=0,owner=0;
    if (!aggressionReadPointer(ai+0x38,model) || !aggressionPointer(model,0x58) ||
        !aggressionReadPointer(model+0x50,focusProvider) || !aggressionReadPointer(ai+0x10,owner)) return false;
    if (!aggressionCallFocus(actor,focus)) return false;
    CoreInfo after;std::uintptr_t stillAI=0;
    return coreInfo(actor,after) && aggressionSame(before,after) &&
        aggressionReadPointer(after.core+0x660,stillAI) && stillAI==ai;
}
template<class Snapshot,class Reset>
void aggressionProcessGuarded(const CoreInfo& player,std::uintptr_t pawn,AggressionRow& row,bool clear,Snapshot snapshot,Reset reset) {
    CoreInfo before;std::uintptr_t ai=0,focus=0;
    if (row.actor==pawn || !snapshot(row.actor,before,ai,focus)) {row.reason=3;return;}
    row.guid=before.guid;row.core=before.core;row.index=before.identity.internalIndex;row.focus=focus;
    if (!clear) return;
    // Parking the proxy can remove current aim before persistent AI/search
    // state is reset. A verified in-flight acquisition authorizes that zero-
    // focus case, but never an actor now pursuing a different target.
    if (focus!=pawn && (focus!=0 || row.acquired!=1)) {row.reason=focus?2u:1u;return;}
    if (row.guid!=row.expectedGuid || row.core!=row.expectedCore || row.index!=row.expectedIndex) {row.reason=3;return;}
    CoreInfo currentPlayer,current;std::uintptr_t currentAI=0,currentFocus=0;
    if (!coreInfo(pawn,currentPlayer) || !aggressionSame(player,currentPlayer) ||
        !snapshot(row.actor,current,currentAI,currentFocus) || !aggressionSame(before,current) ||
        currentAI!=ai || currentFocus!=focus) {row.reason=4;return;}
    // Lua authorizes only baseline-with-no-target actors. Relationships and
    // faction tables are never read-modified-written by this cleanup.
    row.attempted=1;
    if (!reset(ai)) {row.reason=5;return;}
    CoreInfo after;std::uintptr_t afterAI=0,afterFocus=0;
    if (snapshot(row.actor,after,afterAI,afterFocus) && aggressionSame(before,after) && afterAI==ai) {
        row.focus=afterFocus;row.cleared=afterFocus!=pawn?1u:0u;row.reason=row.cleared?0u:6u;
    } else row.reason=4;
}
void aggressionProcess(const CoreInfo& player,std::uintptr_t pawn,AggressionRow& row,bool clear) {
    aggressionProcessGuarded(player,pawn,row,clear,aggressionSnapshot,aggressionCallReset);
}
int aggressionRequest(bool clear) {
    InitOnceExecuteOnce(&initialized,initialize,nullptr,nullptr);
    const bool ready=state.ready && aggressionProfile();
    const auto request=root+L"native-aggression-control.txt";
    FILE* input=nullptr;unsigned long long tokenValue=0,pawn=0;unsigned mode=0,playerGuid=0xffffffffu,count=0;
    std::array<AggressionRow,16> rows{};bool parsed=false;
    if (!_wfopen_s(&input,request.c_str(),L"rb") && input) {
        parsed=fscanf_s(input,"ZFPVAG12 %llu %u %llx %u %u",&tokenValue,&mode,&pawn,&playerGuid,&count)==5 &&
            tokenValue>0 && mode==(clear?1u:0u) && count>0 && count<=rows.size();
        if (parsed) for (unsigned i=0;i<count;++i) {
            unsigned long long actor=0,core=0;auto& row=rows[i];
            if (fscanf_s(input," %llx %u %llx %d %u",&actor,&row.expectedGuid,&core,&row.expectedIndex,&row.acquired)!=5 || row.acquired>1) {parsed=false;break;}
            row.actor=static_cast<std::uintptr_t>(actor);row.expectedCore=static_cast<std::uintptr_t>(core);
        }
        if (parsed) {int c=0;while ((c=std::fgetc(input))!=EOF) if (!std::isspace(static_cast<unsigned char>(c))) {parsed=false;break;}}
        std::fclose(input);
    }
    DeleteFileW(request.c_str());unsigned error=ready?0u:2u;CoreInfo player;
    if (!parsed) {error=7;count=0;}
    else if (!coreInfo(static_cast<std::uintptr_t>(pawn),player) || (playerGuid!=0xffffffffu && playerGuid!=player.guid)) error=8;
    if (!error) for (unsigned i=0;i<count;++i) aggressionProcess(player,static_cast<std::uintptr_t>(pawn),rows[i],clear);
    CoreInfo after;
    if (!error && (!coreInfo(static_cast<std::uintptr_t>(pawn),after) || !aggressionSame(player,after))) error=8;
    const auto response=root+L"native-aggression-status.txt";const auto temp=response+L".tmp";
    FILE* output=nullptr;if (_wfopen_s(&output,temp.c_str(),L"wb") || !output) return 0;
    bool good=std::fprintf(output,"ZFPVAG12 %u %llu %u %u %u\n",ready?1u:0u,tokenValue,player.guid,count,error)>0;
    for (unsigned i=0;i<count && good;++i) {
        const auto& row=rows[i];
        good=std::fprintf(output,"%llx %u %llx %d %llx %u %u %u\n",static_cast<unsigned long long>(row.actor),row.guid,
            static_cast<unsigned long long>(row.core),row.index,static_cast<unsigned long long>(row.focus),row.cleared,row.attempted,row.reason)>0;
    }
    const int closed=std::fclose(output);
    if (good && closed==0) MoveFileExW(temp.c_str(),response.c_str(),MOVEFILE_REPLACE_EXISTING);else DeleteFileW(temp.c_str());
    return 0;
}
}
extern "C" __declspec(dllexport) int zonefpv_aggression_query(void*) {return aggressionRequest(false);}
extern "C" __declspec(dllexport) int zonefpv_aggression_clear(void*) {return aggressionRequest(true);}
