#pragma once
#include "controllers.h"
#include <filesystem>
#include <fstream>
#include <istream>
#include <iterator>
#include <limits>

namespace action_bindings {
constexpr size_t actionCount=8;
using Bindings=std::array<unsigned,actionCount>;
inline Bindings defaults(){return {117,119,120,0,0,0,0,0};}
inline bool valid(unsigned code){
    return code<=255 || (code>=1001&&code<=1128) || (code>=2001&&code<=2032) || (code>=3001&&code<=3024);
}
inline bool parse(std::istream& input,Bindings& output){
    Bindings candidate{};std::string token;size_t count=0;
    while(input>>token){
        if(count==candidate.size()||token.empty()||(token.size()>1&&token[0]=='0'))return false;
        unsigned value=0;
        for(const auto character:token){
            if(character<'0'||character>'9')return false;
            const auto digit=static_cast<unsigned>(character-'0');
            if(value>(3024u-digit)/10u)return false;
            value=value*10u+digit;
        }
        if(!valid(value))return false;
        for(size_t previous=0;previous<count;++previous)if(value&&candidate[previous]==value)return false;
        candidate[count++]=value;
    }
    if(input.bad()||count<3||count==6)return false;
    output=candidate;return true; // Legacy three/four/five/seven-action files leave the new actions unbound.
}
inline Bindings load(const std::filesystem::path& root){
    auto result=defaults();std::ifstream file(root/L"bindings.txt");
    Bindings candidate{};if(file&&parse(file,candidate))result=candidate;
    return result;
}
struct Modes{
    int menu=0,pilot=0,reset=0,collect=0,flashlight=0,cameraDown=0,grenadeDrop=0,vision=0;
    std::array<int,actionCount> values()const{return {menu,pilot,reset,collect,flashlight,cameraDown,grenadeDrop,vision};}
};
inline bool parseModes(std::istream& input,Modes& result){
    std::string version,token;Modes parsed;
    if(!(input>>version)||(version!="1"&&version!="2"))return false;
    if(version=="1"){
        int* fields[]={&parsed.cameraDown,&parsed.vision,&parsed.flashlight};
        for(int i=0;i<3;++i){if(!(input>>token)){if(i==2&&!input.bad())break;return false;}if(token!="0"&&token!="1")return false;*fields[i]=token=="1";}
    }else{
        int* fields[]={&parsed.menu,&parsed.pilot,&parsed.reset,&parsed.collect,&parsed.flashlight,&parsed.cameraDown,&parsed.grenadeDrop,&parsed.vision};
        for(auto field:fields){if(!(input>>token)||(token!="0"&&token!="1"))return false;*field=token=="1";}
    }
    if(input.bad()||(input>>token))return false;result=parsed;return true;
}
inline Modes loadModes(const std::filesystem::path& root){Modes result;std::ifstream input(root/L"action-modes.txt");parseModes(input,result);return result;}
inline std::wstring label(unsigned code){
    if(!code)return L"Не назначено";
    if(code>=1001&&code<=1128)return L"Button "+std::to_wstring(code-1000);
    if(code>=2001&&code<=2032){
        static const wchar_t* directions[]={L"↑",L"↗",L"→",L"↘",L"↓",L"↙",L"←",L"↖"};
        const auto value=code-2001;
        return L"Hat "+std::to_wstring(value/8+1)+L" "+directions[value%8];
    }
    if(code>=3001&&code<=3024){
        static const wchar_t* positions[]={L"Low",L"Center",L"High"};
        const auto value=code-3001;
        return L"CH"+std::to_wstring(value/3+1)+L" "+positions[value%3];
    }
    switch(code){
    case VK_LBUTTON:return L"ЛКМ";
    case VK_RBUTTON:return L"ПКМ";
    case VK_MBUTTON:return L"СКМ";
    case VK_XBUTTON1:return L"Mouse X1";
    case VK_XBUTTON2:return L"Mouse X2";
    default:break;
    }
    if(code<=255){
        const auto scan=MapVirtualKeyW(code,MAPVK_VK_TO_VSC_EX);
        LONG parameter=static_cast<LONG>((scan&0xffu)<<16);
        if(scan&0xff00u)parameter|=1L<<24;
        wchar_t text[96]{};
        if(GetKeyNameTextW(parameter,text,static_cast<int>(std::size(text)))>0)return text;
    }
    return L"VK "+std::to_wstring(code);
}

struct Sample {
    std::array<bool,256> keys{};
    controllers::LiveState controller;
};
inline Sample sampleHardware(){
    Sample sample;
    for(unsigned key=1;key<sample.keys.size();++key)sample.keys[key]=(GetAsyncKeyState(static_cast<int>(key))&0x8000)!=0;
    sample.controller=controllers::live();
    // Switching the selected backend must never keep the previous device's
    // buttons active until the reader publishes the newly selected device.
    if(sample.controller.device!=controllers::requested.load()||sample.controller.device!=controllers::active.load())sample.controller={};
    return sample;
}
inline bool fresh(const controllers::LiveState& controller,ULONGLONG now){
    if(!controller.connected||!controller.device||!controller.timestamp)return false;
    // The reader can publish a few milliseconds after the caller obtained now.
    return controller.timestamp>now ? controller.timestamp-now<=20 : now-controller.timestamp<=250;
}
inline int hatDirection(DWORD value){
    if((value&0xffffu)==0xffffu||value>=36000u)return -1;
    return static_cast<int>(((value+2250u)/4500u)%8u);
}
inline int axisPosition(DWORD value){
    if(value<=16000u)return 0;
    if(value>=26000u&&value<=39535u)return 1;
    if(value>=49535u&&value<=65535u)return 2;
    return -1;
}
inline bool controllerCode(unsigned code){return code>=1001&&valid(code);}
inline bool axisCode(unsigned code){return code>=3001&&code<=3024;}
inline bool axisHeld(unsigned code,DWORD value,bool held){
    const auto position=(code-3001)%3;
    if(!held)return axisPosition(value)==static_cast<int>(position);
    // Separate entry and release regions so small ADC noise cannot repeatedly
    // retrigger a switch that is sitting at a classification boundary.
    if(position==0)return value<28000u;
    if(position==2)return value>37535u;
    return value>20000u&&value<45535u;
}
inline bool down(unsigned code,const Sample& sample,ULONGLONG now){
    if(code&&code<=255)return sample.keys[code];
    if(!fresh(sample.controller,now))return false;
    if(code>=1001&&code<=1128)return sample.controller.buttonStates[code-1001];
    if(code>=2001&&code<=2032){const auto value=code-2001;return hatDirection(sample.controller.hats[value/8])==static_cast<int>(value%8);}
    if(axisCode(code)){const auto value=code-3001;return axisPosition(sample.controller.axes[value/3])==static_cast<int>(value%3);}
    return false;
}

class Capture {
    bool running_=false,controllerReady_=false;
    Sample previous_;
    std::array<DWORD,8> origin_{};
    std::array<int,8> originPosition_{},candidate_{};
    std::array<ULONGLONG,8> candidateSince_{};
    std::array<bool,4> hatArmed_{};
    void primeController(const Sample& sample,ULONGLONG now){
        controllerReady_=fresh(sample.controller,now);
        previous_.controller=sample.controller;
        candidate_.fill(-1);candidateSince_.fill(0);
        for(size_t i=0;i<origin_.size();++i){origin_[i]=sample.controller.axes[i];originPosition_[i]=axisPosition(origin_[i]);}
        for(size_t i=0;i<hatArmed_.size();++i)hatArmed_[i]=hatDirection(sample.controller.hats[i])<0;
    }
    unsigned finish(unsigned code){running_=false;return code;}
public:
    void begin(const Sample& sample,ULONGLONG now){running_=true;previous_=sample;primeController(sample,now);}
    void cancel(){running_=false;candidate_.fill(-1);}
    bool active()const{return running_;}
    unsigned poll(const Sample& sample,ULONGLONG now){
        if(!running_)return 0;
        for(unsigned key=1;key<sample.keys.size();++key){
            if((key==VK_SHIFT&&(sample.keys[VK_LSHIFT]||sample.keys[VK_RSHIFT]))
                ||(key==VK_CONTROL&&(sample.keys[VK_LCONTROL]||sample.keys[VK_RCONTROL]))
                ||(key==VK_MENU&&(sample.keys[VK_LMENU]||sample.keys[VK_RMENU])))continue;
            if(sample.keys[key]&&!previous_.keys[key])return finish(key);
        }
        previous_.keys=sample.keys;
        if(!fresh(sample.controller,now)){controllerReady_=false;candidate_.fill(-1);return 0;}
        if(!controllerReady_||sample.controller.device!=previous_.controller.device||sample.controller.backend!=previous_.controller.backend){primeController(sample,now);return 0;}
        for(size_t button=0;button<sample.controller.buttonStates.size();++button){
            if(sample.controller.buttonStates[button]&&!previous_.controller.buttonStates[button])return finish(static_cast<unsigned>(1001+button));
        }
        for(size_t hat=0;hat<sample.controller.hats.size();++hat){
            const auto direction=hatDirection(sample.controller.hats[hat]);
            if(direction<0)hatArmed_[hat]=true;
            else if(hatArmed_[hat]&&direction!=hatDirection(previous_.controller.hats[hat]))return finish(static_cast<unsigned>(2001+hat*8+direction));
        }
        for(size_t axis=0;axis<sample.controller.axes.size();++axis){
            const auto value=sample.controller.axes[axis];const auto position=axisPosition(value);
            const auto delta=value>origin_[axis]?value-origin_[axis]:origin_[axis]-value;
            if(position<0||position==originPosition_[axis]||delta<12000){candidate_[axis]=-1;continue;}
            if(candidate_[axis]!=position){candidate_[axis]=position;candidateSince_[axis]=now;}
            else if(now>=candidateSince_[axis]&&now-candidateSince_[axis]>=60)return finish(static_cast<unsigned>(3001+axis*3+position));
        }
        previous_.controller=sample.controller;
        return 0;
    }
};

class RuntimeActions {
    bool initialized_=false,controllerReady_=false;
    unsigned device_=0;int backend_=-1;
    Bindings bindings_{};
    std::array<bool,actionCount> previousDown_{},previousEligible_{},axisPending_{},axisDelivered_{},activated_{},held_{},delayedNeedsPrime_{};
    std::array<ULONGLONG,actionCount> axisSince_{};
    std::array<DWORD,actionCount> axisOrigin_{};
public:
    const std::array<bool,actionCount>& held()const{return held_;}
    std::array<bool,actionCount> poll(const Bindings& bindings,const Sample& sample,bool gameFocus,bool menuFocus,bool blocked,ULONGLONG now){
        std::array<bool,actionCount> result{};
        const auto connected=fresh(sample.controller,now);
        // A briefly blocked device read must not turn an already held CH
        // camera switch into a permanent "release then press" requirement.
        // This grace only retains established holds; axis flight data keeps
        // its separate250ms lease and no new press is delivered from old data.
        const auto delayed=!connected&&controllerReady_&&sample.controller.connected&&sample.controller.device==device_&&
            sample.controller.backend==backend_&&sample.controller.timestamp&&sample.controller.timestamp<=now&&now-sample.controller.timestamp<=750;
        const auto deviceChanged=(!delayed&&connected!=controllerReady_)||(connected&&(device_!=sample.controller.device||backend_!=sample.controller.backend));
        const auto bindingsChanged=!initialized_||bindings!=bindings_;
        for(size_t action=0;action<bindings.size();++action){
            const auto eligible=!blocked&&(action==0?(gameFocus||menuFocus):(gameFocus&&!menuFocus));
            const auto prime=bindingsChanged||eligible!=previousEligible_[action]||(controllerCode(bindings[action])&&(deviceChanged||(connected&&delayedNeedsPrime_[action])));
            if(delayed&&eligible&&!prime&&controllerCode(bindings[action])&&activated_[action]&&previousDown_[action]&&held_[action]){
                axisPending_[action]=false;continue;
            }
            // A control that was not already active cannot acquire an edge
            // during the delay, or turn the first fresh snapshot into a press.
            delayedNeedsPrime_[action]=delayed&&controllerCode(bindings[action]);
            const auto value=axisCode(bindings[action])?sample.controller.axes[(bindings[action]-3001)/3]:0;
            const auto held=axisCode(bindings[action]) ? connected&&axisHeld(bindings[action],value,!prime&&previousDown_[action]) : down(bindings[action],sample,now);
            if(prime||!eligible){axisPending_[action]=false;axisDelivered_[action]=held;axisOrigin_[action]=value;activated_[action]=false;}
            else if(axisCode(bindings[action])){
                if(!held){
                    axisPending_[action]=false;axisDelivered_[action]=false;
                    if(previousDown_[action])axisOrigin_[action]=value;
                }else if(!axisDelivered_[action]){
                    const auto delta=value>axisOrigin_[action]?value-axisOrigin_[action]:axisOrigin_[action]-value;
                    if(delta<12000)axisPending_[action]=false;
                    else if(!axisPending_[action]){axisPending_[action]=true;axisSince_[action]=now;}
                    else if(now>=axisSince_[action]&&now-axisSince_[action]>=60){result[action]=true;axisPending_[action]=false;axisDelivered_[action]=true;}
                }
            }else result[action]=held&&!previousDown_[action];
            if(!held)activated_[action]=false;
            if(result[action])activated_[action]=true;
            // A held switch at startup/reconnect/focus regain must be released
            // before it can activate a hold action, just like a press action.
            held_[action]=eligible&&activated_[action]&&held;
            previousDown_[action]=held;previousEligible_[action]=eligible;
        }
        initialized_=true;bindings_=bindings;controllerReady_=connected||delayed;
        device_=sample.controller.device;backend_=sample.controller.backend;
        return result;
    }
};
using State=RuntimeActions;
}
