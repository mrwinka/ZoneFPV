#include "object_limit.h"
#include <cassert>
#include <iostream>

namespace fs=std::filesystem;
static void write(const fs::path& path,const std::string& bytes) {
    std::ofstream file(path,std::ios::binary);assert(file);file.write(bytes.data(),static_cast<std::streamsize>(bytes.size()));assert(file);
}
static std::string bytes(const fs::path& path) {
    std::ifstream file(path,std::ios::binary);assert(file);
    return {std::istreambuf_iterator<char>(file),std::istreambuf_iterator<char>()};
}
int main() {
    const auto folder=fs::temp_directory_path()/(L"ZoneFPV-object-limit-test-"+std::to_wstring(GetCurrentProcessId())+L"-"+std::to_wstring(GetTickCount64()));
    fs::create_directories(folder);
    const auto path=folder/L"Engine.ini";
    int number=77;
    assert(objectLimit::parse(L" 1200000 \t",number)&&number==1200000);
    assert(objectLimit::parse(L"2147483647",number)&&number==2147483647);
    for(const auto* invalid:{L"",L"0",L"-1",L"+1",L"1.5",L"1e6",L"1,200,000",L"2147483648",L"1200000x",L"1\n2"})assert(!objectLimit::parse(invalid,number));
    std::cout<<"PASS strict positive int32 input\n";
    auto state=objectLimit::read(path);assert(state.ok&&!state.fileExists&&!state.hasValue);
    auto result=objectLimit::reset(path);assert(result.ok&&!result.changed&&!fs::exists(path));
    result=objectLimit::set(path,1200000);assert(result.ok&&result.changed&&result.backupPath.empty());
    state=objectLimit::read(path);assert(state.ok&&state.fileExists&&state.hasValue&&state.value==1200000);
    const auto created=bytes(path);
    result=objectLimit::set(path,1200000);assert(result.ok&&!result.changed&&result.backupPath.empty());
    result=objectLimit::set(path,1500000);assert(result.ok&&result.changed&&bytes(result.backupPath)==created);
    result=objectLimit::set(path,0);assert(!result.ok&&objectLimit::read(path).value==1500000);
    std::cout<<"PASS create, explicit setting, unchanged setting, backup and invalid setter\n";
    const std::string duplicate="; keep comment\r\n[Other]\r\ngc.MaxObjectsInGame=81\r\nOther=one\r\n[/script/engine.garbagecollectionsettings] ; section comment\r\n  GC.MAXOBJECTSINGAME = 800000 ; old limit note\r\nKeep = \"unchanged\"\r\n[/Script/Engine.GarbageCollectionSettings]\r\ngc.MaxObjectsInGame=900000 # duplicate note\r\nOtherGC=3\r\n[Tail]\r\nEnd=last";
    write(path,duplicate);
    state=objectLimit::read(path);assert(!state.ok&&state.hasValue);
    result=objectLimit::set(path,1200000);assert(result.ok&&result.changed&&bytes(result.backupPath)==duplicate);
    state=objectLimit::read(path);assert(state.ok&&state.hasValue&&state.value==1200000);
    const auto corrected=bytes(path);
    assert(corrected.find("gc.MaxObjectsInGame=81\r\nOther=one")!=std::string::npos);
    assert(corrected.find("  gc.MaxObjectsInGame=1200000 ; old limit note\r\nKeep = \"unchanged\"")!=std::string::npos);
    assert(corrected.find("# duplicate note\r\nOtherGC=3")!=std::string::npos);
    assert(corrected.substr(corrected.size()-std::string("End=last").size())=="End=last");
    result=objectLimit::reset(path);assert(result.ok&&result.changed&&bytes(result.backupPath)==corrected);
    state=objectLimit::read(path);assert(state.ok&&state.fileExists&&!state.hasValue);
    const auto reset=bytes(path);assert(reset.find("gc.MaxObjectsInGame=81")!=std::string::npos&&reset.find("Keep = \"unchanged\"")!=std::string::npos&&reset.find("; old limit note")!=std::string::npos&&reset.find("OtherGC=3")!=std::string::npos);
    result=objectLimit::reset(path);assert(result.ok&&!result.changed);
    std::cout<<"PASS case-insensitive sections, duplicate cleanup, comments and targeted default reset\n";
    const std::string invalid="[/Script/Engine.GarbageCollectionSettings]\ngc.MaxObjectsInGame=broken\n";
    write(path,invalid);assert(!objectLimit::read(path).ok);
    result=objectLimit::reset(path);assert(result.ok&&bytes(result.backupPath)==invalid&&!objectLimit::read(path).hasValue);
    write(path,"; header\n[Other]\nUnrelated=present");
    result=objectLimit::set(path,1200000);assert(result.ok&&bytes(path).find("; header\n[Other]\nUnrelated=present\n\n[/Script/Engine.GarbageCollectionSettings]\ngc.MaxObjectsInGame=1200000\n")==0);
    std::cout<<"PASS malformed target removal, append and newline preservation\n";
    for(const auto encoding:{objectLimit::detail::Encoding::Utf8,objectLimit::detail::Encoding::Utf8Bom,objectLimit::detail::Encoding::Utf16LE}) {
        const auto original=objectLimit::detail::encode(L"; Сохрани этот текст\r\n[Other]\r\nPath=日本語\r\n[/Script/Engine.GarbageCollectionSettings]\r\nOtherGC=5\r\n",encoding);
        write(path,original);result=objectLimit::set(path,1200000);assert(result.ok&&bytes(result.backupPath)==original);
        const auto expected=objectLimit::detail::encode(L"; Сохрани этот текст\r\n[Other]\r\nPath=日本語\r\n[/Script/Engine.GarbageCollectionSettings]\r\ngc.MaxObjectsInGame=1200000\r\nOtherGC=5\r\n",encoding);
        assert(bytes(path)==expected&&objectLimit::read(path).value==1200000);
        result=objectLimit::reset(path);assert(result.ok&&bytes(path)==original);
    }
    std::cout<<"PASS UTF-8, BOM and UTF-16LE roundtrip preserve unrelated Unicode\n";
    for(const auto& unsupported:{std::string("\xfe\xff\x00[",4),std::string("\xff\xfeg",3),std::string("\xff\xfe\x00\xd8",4),std::string("\xffgarbage",8),std::string("binary\0data",11)}) {
        write(path,unsupported);assert(!objectLimit::read(path).ok);result=objectLimit::set(path,1200000);assert(!result.ok&&!result.changed&&bytes(path)==unsupported);
        result=objectLimit::reset(path);assert(!result.ok&&bytes(path)==unsupported);
    }
    assert(!objectLimit::set(fs::path(),1200000).ok);
    assert(!objectLimit::set(folder,1200000).ok);
    assert(!objectLimit::defaultEnginePath().empty());
    std::cout<<"PASS unsupported encoding/binary rejection and inaccessible target\n";
    // Delete only the exact temporary directory created by this test.
    assert(fs::equivalent(folder.parent_path(),fs::temp_directory_path())&&folder.filename().wstring().find(L"ZoneFPV-object-limit-test-")==0);
    fs::remove_all(folder);
    std::cout<<"6 object-limit config contract tests passed\n";
}
