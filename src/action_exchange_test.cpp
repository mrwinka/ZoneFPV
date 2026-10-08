#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "action_exchange.h"
#include <cassert>
#include <fstream>
#include <iostream>
#include <string>

int main(){
    namespace fs=std::filesystem;
    const auto fixture=fs::temp_directory_path()/(L"ZoneFPV-action-exchange-"+std::to_wstring(GetCurrentProcessId()));
    assert(fs::create_directory(fixture));
    actionExchange::Writer writer;
    const auto read=[&](){
        std::ifstream file(fixture/L"action-input.txt");
        std::array<unsigned long long,14> fields{};
        for(auto& value:fields)assert(file>>value);
        std::string extra;assert(!(file>>extra));
        assert(fields[0]==5&&fields[1]==fields[13]&&fields[2]>0);
        return fields;
    };
    assert(writer.publish(fixture,true,{false,true,false,false,true,true,true,true},{true,true,true,true,true,true,true,true}));
    auto fields=read();assert(fields[1]==1&&fields[3]==1&&fields[4]==0&&fields[5]==1&&fields[6]==0&&fields[7]==0&&fields[8]==1&&fields[9]==1&&fields[10]==1&&fields[11]==1&&fields[12]==255);
    assert(writer.publish(fixture,true,{false,false,false,false}));
    fields=read();assert(fields[1]==2&&fields[5]==1&&fields[8]==1&&fields[9]==1&&fields[10]==1);
    assert(writer.publish(fixture,false,{true,false,false,true},{false,false,false,false,true,true,false,true}));
    fields=read();assert(fields[3]==0&&fields[4]==1&&fields[5]==1&&fields[6]==0&&fields[7]==1&&fields[12]==0);
    // A failed atomic replacement retains counted presses for the next good
    // publication; a consumer can reject the duplicate sequence and stale lease.
    const auto invalid=fixture/L"missing-directory";
    assert(!writer.publish(invalid,true,{false,false,true,false}));
    assert(writer.publish(fixture,true,{false,false,false,false}));
    fields=read();assert(fields[1]==5&&fields[6]==1&&fields[9]==1&&fields[10]==1);
    const auto destination=fixture/L"action-input.txt";
    const auto blockingReader=CreateFileW(destination.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    assert(blockingReader!=INVALID_HANDLE_VALUE);
    assert(!writer.publish(fixture,true,{false,false,false,false,false,false,true}));
    const auto sharingError=GetLastError();assert(sharingError==ERROR_SHARING_VIOLATION||sharingError==ERROR_ACCESS_DENIED);
    fields=read();assert(fields[1]==5&&fields[10]==1); // Previous snapshot stays intact.
    CloseHandle(blockingReader);
    assert(writer.publish(fixture,true,{}));fields=read();assert(fields[1]==7&&fields[10]==2); // Press is retained.
    const auto sharedReader=CreateFileW(destination.c_str(),GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    assert(sharedReader!=INVALID_HANDLE_VALUE);
    const auto sharedPublished=writer.publish(fixture,true,{false,false,false,false,false,true,false});
    const auto sharedError=sharedPublished?ERROR_SUCCESS:GetLastError();
    assert(sharedPublished||sharedError==ERROR_SHARING_VIOLATION||sharedError==ERROR_ACCESS_DENIED);
    fields=read();assert(fields[1]==(sharedPublished?8u:7u)&&fields[9]==(sharedPublished?2u:1u));
    std::cout<<"Reader sharing diagnostic: blocking error="<<sharingError<<" delete-shared published="<<sharedPublished<<" error="<<sharedError<<"\n";
    CloseHandle(sharedReader);
    assert(writer.publish(fixture,true,{}));
    fields=read();assert(fields[1]==9&&fields[9]==2&&fields[10]==2);
    assert(!fs::exists(fixture/L"action-input.tmp"));
    assert(fs::remove(fixture/L"action-input.txt")&&fs::remove(fixture));
    std::cout<<"PASS atomic action packet schema, retained short presses, eight counters, all eight hold bits, focus releases, failed-publication recovery and controlled reader sharing violation "<<sharingError<<"\n";
}
