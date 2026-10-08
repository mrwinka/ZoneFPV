#pragma once
namespace navigationKeys {
struct State {
    bool focused=false,qHeld=false,eHeld=false;
    ULONGLONG sequence=0,qSequence=0,eSequence=0;
    void sample(bool focus,bool q,bool e){
        // A held key on focus return is a baseline, never a fresh press.
        if(focus&&focused){if(q&&!qHeld)++qSequence;if(e&&!eHeld)++eSequence;}
        focused=focus;qHeld=q;eHeld=e;++sequence;
    }
};
inline bool publish(const fs::path& root,State& state,bool focus,bool q,bool e){
    state.sample(focus,q,e);
    const auto epoch=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
    char line[256];const int count=snprintf(line,sizeof(line),"1 %llu %lld %d %d %d %llu %llu %llu\n",
        state.sequence,epoch,focus?1:0,focus&&q?1:0,focus&&e?1:0,state.qSequence,state.eSequence,state.sequence);
    const auto temp=root/L"pda-navigation.tmp",dest=root/L"pda-navigation.txt";
    HANDLE file=CreateFileW(temp.c_str(),GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_TEMPORARY,nullptr);
    if(file==INVALID_HANDLE_VALUE)return false;
    DWORD written=0;const bool ok=WriteFile(file,line,static_cast<DWORD>(count),&written,nullptr)&&written==static_cast<DWORD>(count);
    CloseHandle(file);
    return ok&&MoveFileExW(temp.c_str(),dest.c_str(),MOVEFILE_REPLACE_EXISTING)!=0;
}
}
