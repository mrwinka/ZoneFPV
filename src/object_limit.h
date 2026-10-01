#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
#include <atomic>
#include <limits>
#include <cwctype>
#include <cstdint>

// An opt-in, startup-only Engine.ini setting. This code never changes the live
// UObject array or applies a value merely because the helper was started.
namespace objectLimit {
namespace fs = std::filesystem;
inline constexpr int suggested = 1200000;
struct ReadResult {
    bool ok=false;
    bool fileExists=false;
    bool hasValue=false;
    int value=0;
    std::wstring error;
};
struct ChangeResult {
    bool ok=false;
    bool changed=false;
    fs::path backupPath;
    std::wstring error;
};
inline std::wstring trim(const std::wstring& text) {
    const auto begin=text.find_first_not_of(L" \t\r\n");
    if(begin==std::wstring::npos)return {};
    return text.substr(begin,text.find_last_not_of(L" \t\r\n")-begin+1);
}
inline bool equal(const std::wstring& a,const std::wstring& b) {
    if(a.size()!=b.size())return false;
    for(size_t i=0;i<a.size();++i)if(towlower(a[i])!=towlower(b[i]))return false;
    return true;
}
inline bool parse(const std::wstring& text,int& value) {
    const auto clean=trim(text);
    if(clean.empty())return false;
    int n=0;
    for(const auto ch:clean) {
        if(ch<L'0'||ch>L'9')return false;
        const int digit=ch-L'0';
        if(n>(std::numeric_limits<int>::max()-digit)/10)return false;
        n=n*10+digit;
    }
    if(n==0)return false;
    value=n;
    return true;
}
inline fs::path defaultEnginePath() {
    const DWORD size=GetEnvironmentVariableW(L"LOCALAPPDATA",nullptr,0);
    if(size==0)return {};
    std::wstring local(size,L'\0');
    const DWORD written=GetEnvironmentVariableW(L"LOCALAPPDATA",local.data(),size);
    if(written==0||written>=size)return {};
    local.resize(written);
    return fs::path(local)/L"Stalker2"/L"Saved"/L"Config"/L"Windows"/L"Engine.ini";
}
namespace detail {
inline constexpr wchar_t sectionName[]=L"/Script/Engine.GarbageCollectionSettings";
inline constexpr wchar_t keyName[]=L"gc.MaxObjectsInGame";
enum class Encoding { Utf8, Utf8Bom, Utf16LE };
struct Document {
    bool exists=false;
    Encoding encoding=Encoding::Utf8;
    std::string bytes;
    std::wstring text;
};
struct Line {std::wstring text;std::wstring ending;};
inline bool decode(Document& doc,std::wstring& error) {
    const auto& bytes=doc.bytes;
    if(bytes.size()>=2&&static_cast<unsigned char>(bytes[0])==0xfe&&static_cast<unsigned char>(bytes[1])==0xff) {
        error=L"UTF-16BE Engine.ini is not supported; the file was not changed.";return false;
    }
    if(bytes.size()>=2&&static_cast<unsigned char>(bytes[0])==0xff&&static_cast<unsigned char>(bytes[1])==0xfe) {
        doc.encoding=Encoding::Utf16LE;
        if((bytes.size()-2)%2!=0){error=L"Invalid UTF-16LE Engine.ini.";return false;}
        for(size_t i=2;i<bytes.size();i+=2)doc.text.push_back(static_cast<wchar_t>(static_cast<unsigned char>(bytes[i])|(static_cast<unsigned char>(bytes[i+1])<<8)));
        if(!doc.text.empty()&&WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,doc.text.data(),static_cast<int>(doc.text.size()),nullptr,0,nullptr,nullptr)==0) {
            error=L"Invalid UTF-16LE Engine.ini.";return false;
        }
    }else {
        size_t offset=0;
        if(bytes.size()>=3&&bytes.compare(0,3,"\xef\xbb\xbf")==0){doc.encoding=Encoding::Utf8Bom;offset=3;}
        const auto length=static_cast<int>(bytes.size()-offset);
        if(length) {
            const int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,bytes.data()+offset,length,nullptr,0);
            if(count==0){error=L"Engine.ini is not valid UTF-8 or UTF-16LE; the file was not changed.";return false;}
            doc.text.resize(count);
            MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,bytes.data()+offset,length,doc.text.data(),count);
        }
    }
    if(doc.text.find(L'\0')!=std::wstring::npos){error=L"Engine.ini contains binary data; the file was not changed.";return false;}
    return true;
}
inline bool load(const fs::path& path,Document& doc,std::wstring& error) {
    if(path.empty()){error=L"The Engine.ini path is unavailable.";return false;}
    std::error_code ec;
    doc.exists=fs::exists(path,ec);
    if(ec){error=L"Cannot inspect Engine.ini: "+std::to_wstring(ec.value());return false;}
    if(!doc.exists)return true;
    const auto length=fs::file_size(path,ec);
    if(ec||length>4*1024*1024){error=L"Cannot read Engine.ini, or it exceeds 4 MB.";return false;}
    std::ifstream file(path,std::ios::binary);
    if(!file){error=L"Cannot read Engine.ini.";return false;}
    doc.bytes.resize(static_cast<size_t>(length));
    if(length&&!file.read(doc.bytes.data(),static_cast<std::streamsize>(length))){error=L"Cannot read the complete Engine.ini.";return false;}
    return decode(doc,error);
}
inline std::vector<Line> lines(const std::wstring& text) {
    std::vector<Line> out;
    size_t begin=0;
    while(begin<text.size()) {
        const auto end=text.find_first_of(L"\r\n",begin);
        if(end==std::wstring::npos){out.push_back({text.substr(begin),{}});break;}
        const size_t length=text[end]==L'\r'&&end+1<text.size()&&text[end+1]==L'\n'?2:1;
        out.push_back({text.substr(begin,end-begin),text.substr(end,length)});
        begin=end+length;
    }
    return out;
}
inline bool section(const std::wstring& text,std::wstring& name) {
    const auto clean=trim(text);
    if(clean.empty()||clean.front()!=L'[')return false;
    const auto end=clean.find(L']');
    if(end==std::wstring::npos)return false;
    const auto suffix=trim(clean.substr(end+1));
    if(!suffix.empty()&&suffix.front()!=L';'&&suffix.front()!=L'#')return false;
    name=trim(clean.substr(1,end-1));return true;
}
inline bool key(const std::wstring& text,std::wstring& value,std::wstring& comment) {
    const auto clean=trim(text);
    if(clean.empty()||clean.front()==L';'||clean.front()==L'#')return false;
    const auto equals=clean.find(L'=');
    if(equals==std::wstring::npos||!equal(trim(clean.substr(0,equals)),keyName))return false;
    const auto raw=clean.substr(equals+1);
    const auto startComment=raw.find_first_of(L";#");
    value=trim(raw.substr(0,startComment));
    comment=startComment==std::wstring::npos?L"":raw.substr(startComment);
    return true;
}
inline std::wstring edited(const Document& doc,const int* value) {
    auto source=lines(doc.text);
    std::wstring newline=L"\r\n";
    for(const auto& line:source)if(!line.ending.empty()){newline=line.ending;break;}
    std::vector<Line> out;
    bool inTarget=false,inserted=false,foundSection=false;
    size_t firstSection=0;
    for(auto line:source) {
        std::wstring name;
        if(section(line.text,name)) {
            inTarget=equal(name,sectionName);
            if(inTarget&&!foundSection){foundSection=true;firstSection=out.size();}
        }
        std::wstring current,comment;
        if(inTarget&&key(line.text,current,comment)) {
            if(value&&!inserted) {
                const auto indent=line.text.substr(0,line.text.find_first_not_of(L" \t"));
                line.text=indent+keyName+L"="+std::to_wstring(*value)+(comment.empty()?L"":L" "+comment);
                inserted=true;out.push_back(line);
            }else if(!comment.empty())out.push_back({comment,line.ending});
        }else out.push_back(line);
    }
    if(value&&!inserted) {
        const Line newKey{std::wstring(keyName)+L"="+std::to_wstring(*value),newline};
        if(foundSection) {
            if(out[firstSection].ending.empty())out[firstSection].ending=newline;
            out.insert(out.begin()+static_cast<std::ptrdiff_t>(firstSection+1),newKey);
        }else {
            if(!out.empty()&&out.back().ending.empty())out.back().ending=newline;
            if(!out.empty()&&!out.back().text.empty())out.push_back({L"",newline});
            out.push_back({L"["+std::wstring(sectionName)+L"]",newline});
            out.push_back(newKey);
        }
    }
    std::wstring result;
    for(const auto& line:out)result+=line.text+line.ending;
    return result;
}
inline std::string encode(const std::wstring& text,Encoding encoding) {
    std::string bytes;
    if(encoding==Encoding::Utf16LE) {
        bytes="\xff\xfe";
        for(const auto ch:text){bytes.push_back(static_cast<char>(ch&0xff));bytes.push_back(static_cast<char>((ch>>8)&0xff));}
    }else {
        if(encoding==Encoding::Utf8Bom)bytes="\xef\xbb\xbf";
        if(!text.empty()) {
            const int count=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),nullptr,0,nullptr,nullptr);
            const auto start=bytes.size();bytes.resize(start+count);
            WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),bytes.data()+start,count,nullptr,nullptr);
        }
    }
    return bytes;
}
inline fs::path unique(const fs::path& path,const wchar_t* extension) {
    static std::atomic<unsigned> sequence{0};
    return fs::path(path.wstring()+L".ZoneFPV-object-limit-"+std::to_wstring(GetTickCount64())+L"-"+std::to_wstring(GetCurrentProcessId())+L"-"+std::to_wstring(sequence.fetch_add(1))+extension);
}
inline ChangeResult change(const fs::path& path,const int* value) {
    ChangeResult result;
    Document doc;
    if(!load(path,doc,result.error))return result;
    const auto bytes=encode(edited(doc,value),doc.encoding);
    if(bytes==doc.bytes){result.ok=true;return result;}
    std::error_code ec;
    if(!path.parent_path().empty())fs::create_directories(path.parent_path(),ec);
    if(ec){result.error=L"Cannot create the Engine.ini folder: "+std::to_wstring(ec.value());return result;}
    if(doc.exists) {
        result.backupPath=unique(path,L".bak");
        if(!fs::copy_file(path,result.backupPath,fs::copy_options::none,ec)) {
            result.error=L"Cannot back up Engine.ini: "+std::to_wstring(ec.value());return result;
        }
    }
    const auto temporary=unique(path,L".tmp");
    const HANDLE file=CreateFileW(temporary.c_str(),GENERIC_WRITE,0,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(file==INVALID_HANDLE_VALUE){result.error=L"Cannot create a temporary Engine.ini: "+std::to_wstring(GetLastError());return result;}
    DWORD written=0;
    const bool complete=WriteFile(file,bytes.data(),static_cast<DWORD>(bytes.size()),&written,nullptr)&&written==bytes.size()&&FlushFileBuffers(file);
    const DWORD writeError=GetLastError();CloseHandle(file);
    if(!complete){DeleteFileW(temporary.c_str());result.error=L"Cannot write Engine.ini: "+std::to_wstring(writeError);return result;}
    // Refuse to overwrite changes made by the game or another config editor
    // while this operation was preparing its backup and replacement.
    Document current;std::wstring error;
    if(!load(path,current,error)||current.exists!=doc.exists||current.bytes!=doc.bytes) {
        DeleteFileW(temporary.c_str());result.error=L"Engine.ini changed during editing; please try again.";return result;
    }
    if(!MoveFileExW(temporary.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)) {
        const DWORD moveError=GetLastError();DeleteFileW(temporary.c_str());result.error=L"Cannot replace Engine.ini: "+std::to_wstring(moveError);return result;
    }
    result.ok=true;result.changed=true;return result;
}
} // namespace detail
inline ReadResult read(const fs::path& path) {
    ReadResult result;detail::Document doc;
    if(!detail::load(path,doc,result.error))return result;
    result.fileExists=doc.exists;
    bool inTarget=false;
    for(const auto& line:detail::lines(doc.text)) {
        std::wstring name;
        if(detail::section(line.text,name))inTarget=equal(name,detail::sectionName);
        std::wstring value,comment;
        if(inTarget&&detail::key(line.text,value,comment)) {
            int parsed=0;
            if(!parse(value,parsed)){result.hasValue=true;result.error=L"Engine.ini has an invalid gc.MaxObjectsInGame value.";return result;}
            if(result.hasValue&&result.value!=parsed){result.error=L"Engine.ini has conflicting gc.MaxObjectsInGame values.";return result;}
            result.hasValue=true;result.value=parsed;
        }
    }
    result.ok=true;return result;
}
inline ChangeResult set(const fs::path& path,int value) {
    if(value<=0){ChangeResult result;result.error=L"The object limit must be a positive decimal integer.";return result;}
    return detail::change(path,&value);
}
inline ChangeResult reset(const fs::path& path) {return detail::change(path,nullptr);}
} // namespace objectLimit
