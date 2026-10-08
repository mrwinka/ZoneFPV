#pragma once
#include <cstdint>

// Headless PDA settings transport. All UI algorithms live in weather_menu.h;
// this layer validates ownership and calls them without creating any HWND.
namespace pdaSettings {
using Integer=std::uint64_t;
constexpr Integer maxInteger=9007199254740991ULL;
constexpr ULONGLONG ownerLease=750;
struct Owner{Integer session=0,seq=0,epoch=0;bool open=false;int section=0;bool mouseBlocked=false;};
struct Request{Integer session=0,id=0,epoch=0;int section=0;std::string kind;std::vector<Integer> args;};
inline Integer epochMs(){FILETIME value{};GetSystemTimeAsFileTime(&value);ULARGE_INTEGER raw{};raw.LowPart=value.dwLowDateTime;raw.HighPart=value.dwHighDateTime;return (raw.QuadPart-116444736000000000ULL)/10000;}
inline bool integer(const std::string& token,Integer& value){
    if(token.empty()||token.size()>16||(token.size()>1&&token[0]=='0'))return false;
    Integer result=0;for(const auto c:token){if(c<'0'||c>'9')return false;const auto digit=static_cast<unsigned>(c-'0');if(result>(maxInteger-digit)/10)return false;result=result*10+digit;}
    value=result;return true;
}
inline bool section(Integer value){return value==1||value==9||value==10;}
inline std::vector<std::string> tokens(const std::string& text){std::istringstream input(text);std::vector<std::string> result;std::string value;while(input>>value){if(result.size()==16)return {};result.push_back(value);}return result;}
inline bool parseOwner(const std::string& text,Owner& owner){
    const auto fields=tokens(text);if(fields.size()!=8||fields[0]!="1")return false;
    std::array<Integer,7> values{};for(size_t i=0;i<values.size();++i)if(!integer(fields[i+1],values[i]))return false;
    if(!values[0]||!values[1]||!values[2]||values[3]>1||values[4]>10||values[5]>1||values[1]!=values[6]||(values[3]&&!section(values[4])))return false;
    owner={values[0],values[1],values[2],values[3]!=0,static_cast<int>(values[4]),values[5]!=0};return true;
}
inline bool parseRequest(const std::string& text,Request& request){
    const auto fields=tokens(text);if(fields.size()<8||fields[0]!="1")return false;
    Integer sessionId=0,id=0,epoch=0,page=0,tail=0;
    if(!integer(fields[1],sessionId)||!integer(fields[2],id)||!integer(fields[3],epoch)||!integer(fields[4],page)||!integer(fields.back(),tail)||!sessionId||!id||!epoch||!section(page)||tail!=id)return false;
    Request parsed{sessionId,id,epoch,static_cast<int>(page),fields[5],{}};
    for(size_t i=6;i+1<fields.size();++i){Integer value=0;if(!integer(fields[i],value))return false;parsed.args.push_back(value);}
    const auto& kind=parsed.kind;const auto& args=parsed.args;
    if(kind=="modes"){if(page!=9||args.size()!=2||args[0]>7||args[1]>1)return false;}
    else{
        if(args.size()!=1)return false;const auto value=args[0];
        if(kind=="device"){if(page!=1||value>std::numeric_limits<unsigned>::max())return false;}
        else if(kind=="profile"){if(page!=1||value>10)return false;}
        else if(kind=="calibrate"){if(page!=1||value>1)return false;}
        else if(kind=="capture"||kind=="clear"){if(page!=9||value>7)return false;}
        else if(kind=="cancel"){if(page!=9||value)return false;}
        else if(kind=="language"){if(page!=10||value>4)return false;}
        else if(kind=="theme"){if(page!=10||value>1)return false;}
        else if(kind=="audio"){if(page!=10||value>100)return false;}
        else if(kind=="limit"){if(page!=10||!value||value>2147483647)return false;}
        else if(kind=="limitreset"){if(page!=10||value)return false;}
        else return false;
    }
    request=std::move(parsed);return true;
}
inline bool read(const fs::path& path,size_t bound,std::string& text){
    std::error_code error;const auto size=fs::file_size(path,error);if(error||!size||size>bound)return false;
    std::ifstream file(path,std::ios::binary);std::string candidate(static_cast<size_t>(size),'\0');
    if(!file.read(candidate.data(),static_cast<std::streamsize>(size))||file.peek()!=std::char_traits<char>::eof())return false;
    for(const auto c:candidate)if((c<32&&c!='\n'&&c!='\r'&&c!='\t')||static_cast<unsigned char>(c)>126)return false;
    text=std::move(candidate);return true;
}
inline std::string hex(const std::wstring& text){
    if(text.empty())return "-";
    const auto length=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),nullptr,0,nullptr,nullptr);
    if(length<=0||length>4096)return "-";
    std::string utf8(static_cast<size_t>(length),'\0');if(!WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),utf8.data(),length,nullptr,nullptr))return "-";
    static const char digits[]="0123456789abcdef";std::string result;result.reserve(utf8.size()*2);
    for(const unsigned char byte:utf8){result+=digits[byte>>4];result+=digits[byte&15];}return result;
}
inline bool recent(Integer epoch,Integer current){return epoch>current?epoch-current<=2000:current-epoch<=2000;}

class Bridge{
    fs::path root_;
    bool initialized_=false,eligible_=false,ackOk_=false;
    Owner owner_;
    Integer seenSession_=0,seenRequest_=0,ack_=0,stateSeq_=0;
    ULONGLONG ownerAt_=0,nextPublish_=0,nextLimit_=0,nextOsd_=0;
    unsigned operationDevice_=0;int operationBackend_=-1;
    unsigned mouseCandidate_=0;int mouseRow_=-1;ULONGLONG mouseAt_=0;bool blockedPress_=false;
    objectLimit::ReadResult limit_;
    std::wstring calibrationStatus_;
    std::wstring ackError_;
    bool publishFailed_=false;
    fs::file_time_type osdTime_{};std::uintmax_t osdSize_=0;bool osdKnown_=false;
    void cancel(){
        if(weatherMenu::headlessCapture)weatherMenu::cancelBindingCapture(L"Назначение отменено. Прежняя кнопка сохранена.");
        if(weatherMenu::headlessCalibration)weatherMenu::resetCalibration(L"Выберите настройки и нажмите кнопку.");
        operationDevice_=0;operationBackend_=-1;
        mouseCandidate_=0;mouseRow_=-1;mouseAt_=0;blockedPress_=false;
        calibrationStatus_.clear();
    }
    void rememberDevice(const action_bindings::Sample& sample){operationDevice_=sample.controller.connected?sample.controller.device:0;operationBackend_=operationDevice_?sample.controller.backend:-1;}
    bool reject(const char* code,const wchar_t* message){
        weatherMenu::setStatus(message);ackError_=weatherMenu::statusText;
        std::cerr<<"PDA setting rejected: request="<<ack_<<" code="<<code<<" requested="<<controllers::requested.load()<<" active="<<controllers::active.load()<<"\n";return false;
    }
    bool controllerReady(const action_bindings::Sample& sample,ULONGLONG now){
        if(!sample.controller.connected){
            if(controllers::active.load()&&controllers::requested.load()!=controllers::active.load())return reject("device_pending",L"Выбранный пульт ещё не готов. Подождите или выберите подключённый.");
            return reject("controller_disconnected",L"Контроллер не подключён. Подключите пульт в режиме USB Joystick.");
        }
        if(!weatherMenu::selectedDeviceMatches(sample.controller.device))return reject("device_pending",L"Выбранный пульт ещё не готов. Подождите или выберите подключённый.");
        if(!action_bindings::fresh(sample.controller,now))return reject("controller_stale",L"Ожидаются свежие данные пульта. Повторите после подключения.");
        return true;
    }
    bool execute(const Request& request,const action_bindings::Sample& sample,ULONGLONG now){
        const auto arg=static_cast<unsigned>(request.args[0]);const auto& kind=request.kind;
        if(kind=="device"){
            if(arg){std::lock_guard<std::mutex> lock(controllers::mutex);if(std::none_of(controllers::available.begin(),controllers::available.end(),[&](const controllers::Device& device){return device.id==arg;}))return reject("device_unavailable",L"Выбранный контроллер недоступен. Обновите список устройств.");}
            cancel();return weatherMenu::selectDevice(arg);
        }
        if(kind=="profile"){
            if(!controllerReady(sample,now))return false;
            return weatherMenu::applyProfile(static_cast<int>(arg));
        }
        if(kind=="calibrate"){
            if(arg==1){cancel();return true;}
            if(!controllerReady(sample,now))return false;
            if(!weatherMenu::calibrationState)rememberDevice(sample);
            const bool result=weatherMenu::advanceCalibration(now);weatherMenu::headlessCalibration=weatherMenu::calibrationState!=0;
            if(weatherMenu::headlessCalibration)calibrationStatus_=weatherMenu::statusText;return result;
        }
        if(kind=="capture"){
            mouseCandidate_=0;mouseRow_=-1;mouseAt_=0;
            rememberDevice(sample);weatherMenu::beginBindingCapture(static_cast<int>(arg),sample,now);
            weatherMenu::headlessCapture=weatherMenu::capturing();return true;
        }
        if(kind=="clear"){cancel();weatherMenu::getCurrentBindings();return weatherMenu::assignBinding(static_cast<int>(arg),0);}
        if(kind=="cancel"){cancel();return true;}
        if(kind=="modes"){cancel();return weatherMenu::applyActionMode(static_cast<int>(arg),static_cast<int>(request.args[1]));}
        if(kind=="language")return weatherMenu::applyLanguage(static_cast<int>(arg));
        if(kind=="theme")return weatherMenu::applyTheme(static_cast<int>(arg));
        if(kind=="audio")return weatherMenu::applyAudio(static_cast<int>(arg));
        if(kind=="limit"||kind=="limitreset"){
            const bool result=weatherMenu::applyObjectLimit(static_cast<int>(arg),kind=="limitreset");limit_=objectLimit::read(weatherMenu::enginePath());return result;
        }
        return false;
    }
    void pollOsd(ULONGLONG now){
        if(now<nextOsd_||osd::editing)return;nextOsd_=now+250;
        std::error_code error;const auto path=root_/L"osd-layout.txt";const auto time=fs::last_write_time(path,error);if(error)return;
        const auto size=fs::file_size(path,error);if(error||!size||size>32768)return;
        if(osdKnown_&&time==osdTime_&&size==osdSize_)return;
        if(osd::load()){osdKnown_=true;osdTime_=time;osdSize_=size;}
    }
    void publish(const action_bindings::Sample& sample,ULONGLONG now,Integer epoch){
        if(now<nextPublish_)return;nextPublish_=now+50;
        if(now>=nextLimit_){nextLimit_=now+1000;limit_=objectLimit::read(weatherMenu::enginePath());}
        std::vector<controllers::Device> devices;{std::lock_guard<std::mutex> lock(controllers::mutex);devices=controllers::available;}
        if(devices.size()>64)devices.resize(64);
        const bool connected=action_bindings::fresh(sample.controller,now);
        const auto remaining=weatherMenu::headlessCapture&&weatherMenu::captureEnds>now?weatherMenu::captureEnds-now:
            weatherMenu::calibrationState==2&&weatherMenu::calibrationEnds>now?weatherMenu::calibrationEnds-now:0;
        std::ostringstream state;
        const auto status=ack_&&!ackOk_?L"! "+ackError_:(weatherMenu::headlessCalibration?calibrationStatus_:weatherMenu::statusText);
        if(stateSeq_>=maxInteger)stateSeq_=0;++stateSeq_;
        state<<"1 "<<stateSeq_<<' '<<epoch<<' '<<owner_.session<<' '<<ack_<<' '<<ackOk_<<' '<<eligible_<<' '
             <<(weatherMenu::headlessCapture?weatherMenu::captureRow:-1)<<' '<<(weatherMenu::headlessCalibration?weatherMenu::calibrationState:0)<<' '
             <<weatherMenu::calibrationControl<<' '<<remaining<<' '<<controllers::requested.load()<<' '<<connected<<' '
             <<(connected?sample.controller.backend:-1)<<' '<<language::current<<' '<<(uiTheme::dark?0:1)<<' '
             <<static_cast<int>(std::lround(droneAudio::volume.load()*100))<<' '<<(limit_.ok&&limit_.hasValue)<<' '
             <<(limit_.ok&&limit_.hasValue?limit_.value:objectLimit::suggested)<<' '
             <<hex(status)<<' '<<devices.size()<<'\n';
        for(const auto& device:devices)state<<"D "<<device.id<<' '<<device.kind<<' '<<hex(device.name)<<'\n';
        state<<"P "<<weatherMenu::profileChoice<<"\nB";for(const auto value:weatherMenu::getCurrentBindings())state<<' '<<value;
        state<<"\nL";for(const auto value:weatherMenu::bindingCodes)state<<' '<<hex(weatherMenu::bindingLabel(value));
        state<<"\nM";for(const auto value:action_bindings::loadModes(root_).values())state<<' '<<value;
        state<<"\nA";for(const auto value:sample.controller.axes)state<<' '<<value;
        state<<"\n1 "<<stateSeq_<<'\n';
        const bool saved=weatherMenu::savePreference(L"pda-settings-state.txt",state.str());
        if(!saved&&!publishFailed_)std::cerr<<"PDA state publication failed: error="<<weatherMenu::preferenceError<<"\n";
        publishFailed_=!saved;
    }
public:
    bool blocking()const{return weatherMenu::headlessCapture||weatherMenu::headlessCalibration;}
    bool eligible()const{return eligible_;}
    void pump(const fs::path& root,const action_bindings::Sample& sample,bool gameFocus,ULONGLONG now,Integer epoch=epochMs()){
        if(!initialized_||root!=root_){
            cancel();*this=Bridge{};initialized_=true;root_=root;
            std::string text;Request old;if(read(root_/L"pda-settings-request.txt",1024,text)&&parseRequest(text,old)){seenSession_=old.session;seenRequest_=old.id;}
            int theme=1;std::ifstream themeFile(root_/L"theme.txt");if(themeFile>>theme&&(theme==0||theme==1))uiTheme::dark=theme!=0;
        }
        std::string text;Owner next;
        const bool validOwner=read(root_/L"pda-settings-owner.txt",1024,text)&&parseOwner(text,next)&&recent(next.epoch,epoch);
        if(validOwner){
            if(next.session==owner_.session&&next.seq==owner_.seq&&
               (next.epoch!=owner_.epoch||next.open!=owner_.open||next.section!=owner_.section||next.mouseBlocked!=owner_.mouseBlocked)){
                cancel();eligible_=false;publish(sample,now,epoch);pollOsd(now);return;
            }
            // A rewound owner sequence cannot renew the lease or reopen tools.
            if(next.session==owner_.session&&next.seq<owner_.seq){cancel();eligible_=false;publish(sample,now,epoch);pollOsd(now);return;}
            const bool changed=next.session!=owner_.session||next.section!=owner_.section||next.open!=owner_.open;
            if(changed){cancel();if(next.session!=owner_.session){ack_=0;ackOk_=false;ackError_.clear();}ownerAt_=now;}
            if(next.session!=owner_.session||next.seq!=owner_.seq)ownerAt_=now;
            owner_=next;
        }
        eligible_=validOwner&&owner_.open&&now>=ownerAt_&&now-ownerAt_<=ownerLease&&gameFocus&&!weatherMenu::visible();
        if(!validOwner){
            // An interrupted atomic owner read suspends tools, but cannot
            // consume a request or cancel the last verified unexpired lease.
            if(!owner_.open||now<ownerAt_||now-ownerAt_>ownerLease||!gameFocus||weatherMenu::visible())cancel();
            if(blocking()&&operationDevice_&&(!action_bindings::fresh(sample.controller,now)||sample.controller.device!=operationDevice_||sample.controller.backend!=operationBackend_||!weatherMenu::selectedDeviceMatches(operationDevice_)))cancel();
            pollOsd(now);publish(sample,now,epoch);return;
        }
        if(!eligible_)cancel();
        if(blocking()&&operationDevice_&&(!sample.controller.connected||sample.controller.device!=operationDevice_||sample.controller.backend!=operationBackend_||!weatherMenu::selectedDeviceMatches(operationDevice_)))cancel();
        if(weatherMenu::headlessCalibration&&!action_bindings::fresh(sample.controller,now))cancel();
        Request request;
        if(read(root_/L"pda-settings-request.txt",1024,text)&&parseRequest(text,request)&&
           request.session==owner_.session&&(request.session!=seenSession_||request.id>seenRequest_)){
            seenSession_=request.session;seenRequest_=request.id;
            if(request.session==owner_.session){
                ack_=request.id;ackOk_=false;ackError_.clear();weatherMenu::statusText.clear();
                if(eligible_&&request.section==owner_.section&&recent(request.epoch,epoch)){
                    weatherMenu::currentInput=&sample;ackOk_=execute(request,sample,now);weatherMenu::currentInput=nullptr;
                    if(!ackOk_){if(weatherMenu::statusText.empty())reject("save_failed",L"Не удалось сохранить настройки. Повторите попытку.");else ackError_=weatherMenu::statusText;}
                }else{
                    reject(recent(request.epoch,epoch)?"context_ineligible":"request_expired",recent(request.epoch,epoch)?L"КПК потерял фокус. Откройте нужный раздел и повторите.":L"Запрос устарел. Повторите настройку.");
                }
            }
        }
        if(eligible_){
            weatherMenu::currentInput=&sample;
            if(weatherMenu::headlessCapture){
                if(!sample.keys[VK_LBUTTON])blockedPress_=false;
                else if(owner_.mouseBlocked)blockedPress_=true;
                auto captureSample=sample;if(owner_.mouseBlocked||blockedPress_)captureSample.keys[VK_LBUTTON]=false;
                if(mouseCandidate_==VK_LBUTTON&&(owner_.mouseBlocked||blockedPress_)){
                    mouseCandidate_=0;mouseRow_=-1;mouseAt_=0;weatherMenu::bindingCapture.begin(captureSample,now);
                }
                if(mouseCandidate_){
                    if(weatherMenu::captureRow!=mouseRow_||now>=weatherMenu::captureEnds){cancel();}
                    else if(now>=mouseAt_&&now-mouseAt_>=200){
                        const auto row=mouseRow_;const auto code=mouseCandidate_;weatherMenu::cancelBindingCapture();weatherMenu::assignBinding(row,code);
                        mouseCandidate_=0;mouseRow_=-1;mouseAt_=0;
                    }
                }else{
                    const auto code=weatherMenu::pollBindingCapture(captureSample,now,true,true);
                    if(weatherMenu::headlessCapture&&weatherMenu::mouseBinding(code)){mouseCandidate_=code;mouseRow_=weatherMenu::captureRow;mouseAt_=now;}
                }
            }else{mouseCandidate_=0;mouseRow_=-1;mouseAt_=0;blockedPress_=false;}
            if(weatherMenu::headlessCalibration){
                const auto stage=weatherMenu::calibrationState;weatherMenu::tickCalibration(now);
                weatherMenu::headlessCalibration=weatherMenu::calibrationState!=0;
                if(weatherMenu::headlessCalibration&&weatherMenu::calibrationState!=stage)calibrationStatus_=weatherMenu::statusText;
            }
            weatherMenu::currentInput=nullptr;
        }
        pollOsd(now);publish(sample,now,epoch);
    }
};
inline Bridge bridge;
}
