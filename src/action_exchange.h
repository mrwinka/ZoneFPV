#pragma once
#include <array>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <windows.h>

// Independent of joystick packet availability: short presses are retained in
// counters until Lua samples them, and publication never simulates OS keys.
namespace actionExchange {
struct Writer {
    ULONGLONG sequence=0;
    std::array<ULONGLONG,8> presses{};
    bool publish(const std::filesystem::path& root,bool gameEligible,const std::array<bool,8>& edges,const std::array<bool,8>& held={}){
        ++sequence;
        for(size_t i=0;i<presses.size();++i)if(edges[i])++presses[i];
        const auto epoch=std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
        char line[256]{};
        unsigned mask=0;if(gameEligible)for(size_t i=0;i<held.size();++i)if(held[i])mask|=1u<<i;
        const auto count=snprintf(line,sizeof(line),"5 %llu %lld %d %llu %llu %llu %llu %llu %llu %llu %llu %u %llu\n",
            sequence,epoch,gameEligible?1:0,presses[0],presses[1],presses[2],presses[3],presses[4],presses[5],presses[6],presses[7],mask,sequence);
        if(count<=0||count>=static_cast<int>(sizeof(line)))return false;
        const auto temp=root/L"action-input.tmp",destination=root/L"action-input.txt";
        const auto file=CreateFileW(temp.c_str(),GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_TEMPORARY,nullptr);
        if(file==INVALID_HANDLE_VALUE)return false;
        DWORD written=0;
        const bool success=WriteFile(file,line,static_cast<DWORD>(count),&written,nullptr)&&written==static_cast<DWORD>(count);
        CloseHandle(file);
        return success&&MoveFileExW(temp.c_str(),destination.c_str(),MOVEFILE_REPLACE_EXISTING)!=0;
    }
};
}
