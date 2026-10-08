#define wmain bridgeMain
#include "input.cpp"
#undef wmain
#include <cassert>
#include <cstdlib>

namespace {
RECT windowRect(HWND h){RECT r{};assert(GetWindowRect(h,&r));return r;}
RECT childRect(HWND h){auto r=windowRect(h);MapWindowPoints(nullptr,weatherMenu::window.load(),reinterpret_cast<POINT*>(&r),2);return r;}
std::wstring text(HWND h){wchar_t value[2048]{};GetWindowTextW(h,value,2048);return value;}
void idle(){weatherMenu::pending=0;weatherMenu::commands.clear();weatherMenu::nextCommandAttempt=0;}
std::string command(){std::ifstream file(weatherMenu::root/L"environment.txt");ULONGLONG id=0;std::string line;assert(file>>id&&id);std::getline(file,line);assert(!line.empty()&&line[0]==' ');return line.substr(1);}
void click(int id){SendMessageW(weatherMenu::window.load(),WM_COMMAND,MAKEWPARAM(id,BN_CLICKED),reinterpret_cast<LPARAM>(GetDlgItem(weatherMenu::window.load(),id)));}
void choose(HWND control,int id,int value){idle();assert(SendMessageW(control,CB_SETCURSEL,value,0)==value);SendMessageW(weatherMenu::window.load(),WM_COMMAND,MAKEWPARAM(id,CBN_SELCHANGE),reinterpret_cast<LPARAM>(control));}
void move(HWND control,int value,UINT event){SendMessageW(control,TBM_SETPOS,TRUE,value);SendMessageW(weatherMenu::window.load(),WM_HSCROLL,MAKEWPARAM(event,0),reinterpret_cast<LPARAM>(control));}
LOGFONTW controlFont(HWND h){LOGFONTW font{};assert(GetObjectW(reinterpret_cast<HFONT>(SendMessageW(h,WM_GETFONT,0,0)),sizeof(font),&font));return font;}
void resize(int width,int height){assert(SetWindowPos(weatherMenu::window.load(),nullptr,0,0,width,height,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOOWNERZORDER));const auto r=windowRect(weatherMenu::window.load());assert(r.right-r.left==width&&r.bottom-r.top==height);assert(!IsWindowVisible(weatherMenu::window.load()));}
std::vector<RECT> geometry(){std::vector<RECT> result;for(const auto& item:weatherMenu::pageControls)result.push_back(childRect(item.first));return result;}
void checkPages(){
    RECT client{};assert(GetClientRect(weatherMenu::window.load(),&client));
    for(int page=0;page<11;++page){
        weatherMenu::selectPage(page);int count=0;assert(text(weatherMenu::pageTitle)==language::tr(weatherMenu::pageNames[page]));
        for(const auto& item:weatherMenu::pageControls){
            const bool visible=(GetWindowLongPtrW(item.first,GWL_STYLE)&WS_VISIBLE)!=0;bool expected=item.second<0||item.second==page;
            if(std::find(weatherMenu::advancedControls.begin(),weatherMenu::advancedControls.end(),item.first)!=weatherMenu::advancedControls.end())expected=page==4&&weatherMenu::advancedWorld;
            if(item.first==weatherMenu::captureCancel)expected=page==9&&weatherMenu::capturing();
            if(item.second==8&&!weatherMenu::weaponControlVisible(item.first))expected=false;
            assert(visible==expected);if(visible&&item.second==page)++count;
            const auto r=childRect(item.first);if(!(r.left>=0&&r.top>=0&&r.right<=client.right&&r.bottom<=client.bottom&&r.right>r.left&&r.bottom>r.top)){
                std::cerr<<"Control outside client on page "<<page<<": "<<r.left<<","<<r.top<<","<<r.right<<","<<r.bottom<<"\n";std::exit(1);}
            if(visible){const auto label=text(item.first);assert(label.find(L"эксперимент")==std::wstring::npos&&label.find(L"Эксперимент")==std::wstring::npos&&label.find(L"Диагностика")==std::wstring::npos);}
        }
        assert(count>0);
    }
}
void checkDropdown(HWND combo){RECT dropped{};assert(SendMessageW(combo,CB_GETDROPPEDCONTROLRECT,0,reinterpret_cast<LPARAM>(&dropped)));const auto closed=windowRect(combo);const auto row=SendMessageW(combo,CB_GETITEMHEIGHT,0,0);assert(row>0&&dropped.bottom-dropped.top>closed.bottom-closed.top+3*row);}
void checkGrouping(){
    assert(weatherMenu::groupOf(1)==4&&weatherMenu::groupOf(0)==0&&weatherMenu::groupOf(8)==2);
    assert(wcscmp(weatherMenu::groupNames[2],L"Оснащение")==0&&wcscmp(weatherMenu::pageNames[8],L"Боевой режим")==0);
    const auto pageOf=[](HWND control){for(const auto& item:weatherMenu::pageControls)if(item.first==control)return item.second;return -99;};
    const int expected[]={5,6,6,7,7,5,7,6};for(size_t i=0;i<8;++i)assert(pageOf(weatherMenu::experimentFlags[i])==expected[i]);
    assert(pageOf(weatherMenu::speed)==0&&pageOf(weatherMenu::worldOptions[1])==0&&pageOf(weatherMenu::worldOptions[3])==0);
    assert(pageOf(weatherMenu::visionModeBox)==2&&pageOf(weatherMenu::volume)==10&&pageOf(weatherMenu::distanceBox)==4&&pageOf(weatherMenu::worldOptions[2])==7&&pageOf(weatherMenu::artifactRange)==6);
    assert(!GetDlgItem(weatherMenu::window.load(),130)&&!GetDlgItem(weatherMenu::window.load(),141));
    assert(!GetDlgItem(weatherMenu::window.load(),149));
    assert(pageOf(weatherMenu::objectLimitBox)==10&&pageOf(weatherMenu::languageBox)==10&&!weatherMenu::themeBox);
    for(const auto id:{118,129,130,141,142})assert(!GetDlgItem(weatherMenu::window.load(),id));
    assert(pageOf(weatherMenu::flashlightPermission)==2&&pageOf(weatherMenu::cameraDownPermission)==2);
    for(int group=0;group<5;++group){click(500+group);assert(weatherMenu::currentGroup==group&&weatherMenu::currentPage==weatherMenu::groupSections[group][0]);
        int count=0;for(const auto section:weatherMenu::groupSections[group])if(section>=0){choose(weatherMenu::sectionBox,510,count++);assert(weatherMenu::currentPage==section&&weatherMenu::currentGroup==group);}
        assert(SendMessageW(weatherMenu::sectionBox,CB_GETCOUNT,0,0)==count);}
    checkPages();
    for(const auto button:weatherMenu::bindingButtons)assert(pageOf(button)==9);for(const auto button:weatherMenu::clearBindingButtons)assert(pageOf(button)==9);
    for(const auto box:weatherMenu::actionModeBoxes)assert(pageOf(box)==9);
    std::cout<<"PASS five primary groups and eleven sections, all eight assignments in Buttons, general preferences and removed diagnostic routes\n";
}
void checkSliders(){
    assert(weatherMenu::sliders.size()==10);
    for(const auto& item:weatherMenu::sliders){wchar_t cls[64]{};GetClassNameW(item.handle,cls,64);assert(wcscmp(cls,TRACKBAR_CLASSW)==0);assert(SendMessageW(item.handle,TBM_GETRANGEMIN,0,0)==item.minimum&&SendMessageW(item.handle,TBM_GETRANGEMAX,0,0)==item.maximum);}
    idle();move(weatherMenu::speed,175,TB_THUMBTRACK);assert(!weatherMenu::pending&&weatherMenu::commands.empty());assert(weatherMenu::sliderValue(weatherMenu::speed)==1.75);assert(text(weatherMenu::sliderSetting(weatherMenu::speed)->badge)==L"1.75×");
    move(weatherMenu::speed,175,TB_ENDTRACK);assert(command()=="flight 1.750000 25");idle();move(weatherMenu::speed,175,TB_ENDTRACK);assert(!weatherMenu::pending&&weatherMenu::commands.empty());
    for(const auto value:{0,500}){idle();move(weatherMenu::speed,value,TB_LINEUP);assert(command()=="flight "+weatherMenu::number(value/100.)+" 25");}
    idle();move(weatherMenu::impactMultiplierBox,75,TB_ENDTRACK);assert(command()=="impact 0.750000");
    idle();move(weatherMenu::signalMultiplierBox,125,TB_ENDTRACK);assert(command()=="signal 0 1500 1.250000");
    for(int index=1;index<=6;++index){idle();move(weatherMenu::distanceBox,index,TB_ENDTRACK);assert(command()=="distance "+std::to_string(index));}
    assert(text(weatherMenu::sliderSetting(weatherMenu::distanceBox)->badge)==L"5×");
    idle();move(weatherMenu::tilt,36,TB_ENDTRACK);assert(command()=="flight 5.000000 36");
    idle();move(weatherMenu::volume,37,TB_ENDTRACK);assert(!weatherMenu::pending&&weatherMenu::commands.empty());std::ifstream prefs(weatherMenu::root/L"audio-volume.txt");double volume=0;assert(prefs>>volume&&std::abs(volume-.37)<1e-9);
    for(const auto position:{1,9,20}){idle();move(weatherMenu::artifactRange,position,TB_THUMBTRACK);assert(!weatherMenu::pending&&weatherMenu::commands.empty());move(weatherMenu::artifactRange,position,TB_ENDTRACK);assert(command()=="collectrange "+weatherMenu::number(position/2.));}
    assert(weatherMenu::sliderValue(weatherMenu::artifactRange)==10&&text(weatherMenu::sliderSetting(weatherMenu::artifactRange)->badge)==L"10.0 m");
    std::cout<<"PASS real slider ranges, drag preview, release commands, keyboard changes and discrete geometry factors\n";
}
void checkPreferences(){
    const auto file=[](const wchar_t* name,const char* value){std::ofstream f(weatherMenu::root/name);f<<value;};
    file(L"flight-settings.txt","0.123456 17\n");file(L"signal-settings.txt","1 2800 3.234567\n");file(L"impact-settings.txt","1.345678\n");file(L"experiment-settings.txt","1 4 1 1 0 1 0 1 0 1\n");file(L"world-distance.txt","3\n");file(L"vision-settings.txt","13\n");file(L"anomaly-noise-style.txt","2\n");file(L"artifact-settings.txt","4.5\n");
    idle();weatherMenu::refreshPreferences();assert(!weatherMenu::pending&&weatherMenu::commands.empty());
    assert(std::abs(weatherMenu::sliderValue(weatherMenu::speed)-.123456)<1e-9&&std::abs(weatherMenu::sliderValue(weatherMenu::signalMultiplierBox)-3.234567)<1e-9&&std::abs(weatherMenu::sliderValue(weatherMenu::impactMultiplierBox)-1.345678)<1e-9);
    assert(SendMessageW(weatherMenu::visionModeBox,CB_GETCURSEL,0,0)==13&&SendMessageW(weatherMenu::anomalyStyleBox,CB_GETCURSEL,0,0)==2&&weatherMenu::sliderValue(weatherMenu::distanceBox)==3);
    assert(weatherMenu::experimentCommand()=="experiments 4 1 1 0 1 0 1 0 1");
    assert(weatherMenu::sliderValue(weatherMenu::artifactRange)==4.5);
    for(const auto value:{"", "0", "0.49", "10.01", "NaN", "inf", "5 extra", "+3", ".5", "3.", "1e0", "3.5.1", "0000000000000000000000003"}){std::istringstream invalid(value);double previous=3;assert(!weatherMenu::parseArtifactRange(invalid,previous)&&previous==3);}
    file(L"artifact-settings.txt","invalid\n");idle();weatherMenu::refreshPreferences();assert(weatherMenu::sliderValue(weatherMenu::artifactRange)==3);
    assert(SendMessageW(weatherMenu::flashlightPermission,BM_GETCHECK,0,0)==BST_CHECKED&&SendMessageW(weatherMenu::cameraDownPermission,BM_GETCHECK,0,0)==BST_CHECKED);
    for(const auto invalid:{"", "1 0", "2 0 0", "1 0 2", "1 0 0 extra", "1 00 1"}){bool light=true,down=true;std::istringstream input(invalid);assert(!weatherMenu::parseFeatureSettings(input,light,down)&&light&&down);}
    file(L"drone-features.txt","1 0 1\n");idle();weatherMenu::refreshPreferences();assert(SendMessageW(weatherMenu::flashlightPermission,BM_GETCHECK,0,0)==BST_UNCHECKED&&SendMessageW(weatherMenu::cameraDownPermission,BM_GETCHECK,0,0)==BST_CHECKED);
    SendMessageW(weatherMenu::flashlightPermission,BM_SETCHECK,BST_CHECKED,0);idle();click(186);assert(command()=="flashlight 1");
    SendMessageW(weatherMenu::cameraDownPermission,BM_SETCHECK,BST_UNCHECKED,0);idle();click(187);assert(command()=="cameradown 0");
    {std::ifstream input(weatherMenu::root/L"drone-features.txt");std::string row;std::getline(input,row);assert(row=="1 0 1");} // only Lua persists/activates permissions
    idle();
    // Opening or refreshing must never quantize persistent values, including the sibling value in a command.
    move(weatherMenu::tilt,18,TB_ENDTRACK);assert(command()=="flight 0.123456 18");idle();click(128);assert(command()=="signal 1 2800 3.234567");
    for(const auto name:{L"flight-settings.txt",L"signal-settings.txt",L"impact-settings.txt"}){std::ifstream f(weatherMenu::root/name);std::string line;std::getline(f,line);assert(line.find(".123456")!=std::string::npos||line.find("3.234567")!=std::string::npos||line.find("1.345678")!=std::string::npos);}
    idle();SendMessageW(weatherMenu::experimentFlags[4],BM_SETCHECK,BST_CHECKED,0);click(135);assert(command()=="experiments 4 1 1 0 1 1 1 0 1");
    std::cout<<"PASS precision-preserving refresh, sibling values, legacy storage and promoted feature commands\n";
}
void checkBindings(){
    weatherMenu::selectPage(9);idle();
    assert(weatherMenu::getCurrentBindings()==action_bindings::defaults());
    assert(text(weatherMenu::bindingButtons[3])==language::tr(L"Не назначено")&&!IsWindowEnabled(weatherMenu::clearBindingButtons[3]));
    for(int row=0;row<8;++row){wchar_t cls[32]{};GetClassNameW(weatherMenu::bindingButtons[row],cls,32);assert(wcscmp(cls,L"Button")==0);}
    action_bindings::Sample sample;sample.keys[VK_LBUTTON]=true;
    weatherMenu::beginBindingCapture(0,sample,1000);assert(weatherMenu::capturing()&&text(weatherMenu::bindingButtons[0])==language::tr(L"Нажмите кнопку..."));
    weatherMenu::pollBindingCapture(sample,1001,true);assert(weatherMenu::capturing()&&!weatherMenu::pending);
    sample.keys[VK_LBUTTON]=false;weatherMenu::pollBindingCapture(sample,1002,true);sample.keys[VK_DELETE]=true;weatherMenu::pollBindingCapture(sample,1003,true);
    assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes[0]==VK_DELETE&&command()=="bindingsreload 1");
    // Mouse input outside the assignment controls is a normal binding.
    idle();sample={};weatherMenu::beginBindingCapture(1,sample,2000);sample.keys[VK_RBUTTON]=true;weatherMenu::pollBindingCapture(sample,2001,true);
    assert(weatherMenu::bindingCodes[1]==VK_RBUTTON&&command()=="bindingsreload 1");
    // A duplicate fails without changing any previously assigned action.
    idle();sample={};weatherMenu::beginBindingCapture(2,sample,3000);sample.keys[VK_DELETE]=true;weatherMenu::pollBindingCapture(sample,3001,true);
    assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes[2]==120&&!weatherMenu::pending&&weatherMenu::commands.empty());
    // DirectInput exposes buttons beyond the old 32-button mask.
    sample={};sample.controller.connected=true;sample.controller.device=42;sample.controller.backend=1;sample.controller.timestamp=4000;sample.controller.hats.fill(JOY_POVCENTERED);sample.controller.axes.fill(32768);
    weatherMenu::beginBindingCapture(2,sample,4000);sample.controller.timestamp=4001;sample.controller.buttonStates[127]=true;weatherMenu::pollBindingCapture(sample,4001,true);
    assert(weatherMenu::bindingCodes[2]==1128&&command()=="bindingsreload 1");
    idle();sample.controller.buttonStates[127]=false;sample.controller.timestamp=5000;weatherMenu::beginBindingCapture(3,sample,5000);
    sample.controller.timestamp=5001;sample.controller.hats[3]=22500;weatherMenu::pollBindingCapture(sample,5001,true);
    assert(weatherMenu::bindingCodes[3]==2030&&command()=="bindingsreload 1");
    idle();const auto assigned=weatherMenu::bindingCodes;sample={};weatherMenu::beginBindingCapture(3,sample,6000);click(168);
    assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes==assigned&&!weatherMenu::pending);
    weatherMenu::beginBindingCapture(3,sample,7000);weatherMenu::selectPage(0);assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes==assigned);weatherMenu::selectPage(9);
    weatherMenu::beginBindingCapture(3,sample,8000);weatherMenu::pollBindingCapture(sample,8001,false);assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes==assigned);
    weatherMenu::beginBindingCapture(3,sample,9000);weatherMenu::pollBindingCapture(sample,24000,true);assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes==assigned&&!weatherMenu::pending);
    // Cancel/navigation clicks must not become Mouse1 assignments on mouse-down.
    weatherMenu::beginBindingCapture(3,sample,25000);sample.keys[VK_LBUTTON]=true;sample.keys[VK_RBUTTON]=true;
    const auto filtered=weatherMenu::captureInput(sample,weatherMenu::captureCancel);assert(!filtered.keys[VK_LBUTTON]&&filtered.keys[VK_RBUTTON]);weatherMenu::cancelBindingCapture();
    weatherMenu::beginBindingCapture(3,sample,25500);COMBOBOXINFO dropdown{};dropdown.cbSize=sizeof(dropdown);assert(GetComboBoxInfo(weatherMenu::actionModeBoxes[3],&dropdown));
    assert(!weatherMenu::captureInput(sample,dropdown.hwndList).keys[VK_LBUTTON]);
    choose(weatherMenu::actionModeBoxes[3],193,1);assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes==assigned);idle();
    // Escape remains assignable; cancellation has a dedicated button.
    sample={};weatherMenu::beginBindingCapture(3,sample,26000);sample.keys[VK_ESCAPE]=true;weatherMenu::pollBindingCapture(sample,26001,true);
    assert(weatherMenu::bindingCodes[3]==VK_ESCAPE&&command()=="bindingsreload 1");
    idle();click(167);assert(weatherMenu::bindingCodes[3]==0&&command()=="bindingsreload 1");
    idle();sample={};weatherMenu::beginBindingCapture(4,sample,27000);sample.keys['L']=true;weatherMenu::pollBindingCapture(sample,27001,true);
    assert(weatherMenu::bindingCodes[4]=='L'&&command()=="bindingsreload 1");idle();click(170);
    assert(weatherMenu::bindingCodes[4]==0&&command()=="bindingsreload 1");
    // A pending UI edit wins over the old on-disk configuration until Lua saves it.
    idle();{std::ofstream f(weatherMenu::root/L"bindings.txt");f<<"117 119 120\n";}weatherMenu::nextBindingsRefresh=0;
    assert(weatherMenu::getCurrentBindings()==(action_bindings::Bindings{46,2,1128,0}));
    {std::ofstream f(weatherMenu::root/L"bindings.txt");f<<"46 2 1128 0\n";}weatherMenu::nextBindingsRefresh=0;
    assert(weatherMenu::getCurrentBindings()==(action_bindings::Bindings{46,2,1128,0})&&!weatherMenu::bindingsDirty);
    {std::ofstream f(weatherMenu::root/L"bindings.txt");f<<"117 119 120\n";}weatherMenu::nextBindingsRefresh=0;
    assert(weatherMenu::getCurrentBindings()==action_bindings::defaults()&&text(weatherMenu::bindingButtons[3])==language::tr(L"Не назначено"));
    for(int lang=0;lang<5;++lang){language::current=lang;weatherMenu::refreshBindingLabels();assert(text(weatherMenu::bindingButtons[3])==language::tr(L"Не назначено"));assert(weatherMenu::bindingLabel(1)==language::tr(L"ЛКМ"));assert(weatherMenu::bindingLabel(1128).find(L"128")!=std::wstring::npos);assert(weatherMenu::bindingLabel(3024).find(L"CH8")!=std::wstring::npos);}
    language::current=0;weatherMenu::refreshBindingLabels();idle();
    std::cout<<"PASS eight press-to-bind controls, arbitrary keyboard/mouse/controller inputs, held suppression, duplicate rejection, cancel/timeout/clear and legacy precision\n";
}
void checkArmament(){
    weatherMenu::selectPage(8);idle();
    assert(weatherMenu::weaponCommand()=="armament 0 1.000000 0 3 30");
    assert(!IsWindowEnabled(weatherMenu::weaponPower)&&!IsWindowEnabled(weatherMenu::grenadeTypeBox)&&!IsWindowEnabled(weatherMenu::grenadeCharges));
    for(const auto& control:weatherMenu::weaponControls)assert(!(GetWindowLongPtrW(control.handle,GWL_STYLE)&WS_VISIBLE));
    choose(weatherMenu::weaponModeBox,171,1);assert(command()=="armament 1 1.000000 0 3 30");
    assert(IsWindowEnabled(weatherMenu::weaponPower)&&!IsWindowEnabled(weatherMenu::grenadeTypeBox)&&!IsWindowEnabled(weatherMenu::grenadeCharges));
    for(const auto& control:weatherMenu::weaponControls)assert(((GetWindowLongPtrW(control.handle,GWL_STYLE)&WS_VISIBLE)!=0)==(control.capability==1));
    for(const auto power:{1,7,20}){idle();move(weatherMenu::weaponPower,power,TB_THUMBTRACK);assert(!weatherMenu::pending&&weatherMenu::commands.empty());move(weatherMenu::weaponPower,power,TB_ENDTRACK);assert(command()=="armament 1 "+weatherMenu::number(power/4.)+" 0 3 30");}
    choose(weatherMenu::weaponModeBox,171,2);assert(command()=="armament 2 5.000000 0 3 30");
    assert(!IsWindowEnabled(weatherMenu::weaponPower)&&IsWindowEnabled(weatherMenu::grenadeTypeBox)&&IsWindowEnabled(weatherMenu::grenadeCharges));
    for(const auto& control:weatherMenu::weaponControls)assert(((GetWindowLongPtrW(control.handle,GWL_STYLE)&WS_VISIBLE)!=0)==(control.capability==2));
    choose(weatherMenu::grenadeTypeBox,173,1);assert(command()=="armament 2 5.000000 1 3 30");
    assert(SendMessageW(weatherMenu::grenadeCharges,TBM_GETRANGEMIN,0,0)==1&&SendMessageW(weatherMenu::grenadeCharges,TBM_GETRANGEMAX,0,0)==21);
    for(int thumb=1;thumb<=21;++thumb){const auto charges=thumb==21?0:thumb;
        idle();move(weatherMenu::grenadeCharges,thumb,TB_THUMBTRACK);assert(!weatherMenu::pending);move(weatherMenu::grenadeCharges,thumb,TB_ENDTRACK);
        assert(command()=="armament 2 5.000000 1 "+std::to_string(charges)+" 30");assert(text(weatherMenu::sliderSetting(weatherMenu::grenadeCharges)->badge)==(charges?std::to_wstring(charges):L"∞"));
        assert(weatherMenu::grenadeChargesToThumb(charges)==thumb&&weatherMenu::grenadeThumbToCharges(thumb)==charges);
        if(thumb==21){std::ifstream packet(weatherMenu::root/L"environment.txt",std::ios::binary);std::ofstream fixture(fs::current_path()/"armament-environment.txt",std::ios::binary);fixture<<packet.rdbuf();assert(packet&&fixture);}}
    idle();move(weatherMenu::grenadeCharges,20,TB_LINEUP);assert(command()=="armament 2 5.000000 1 20 30");
    assert(weatherMenu::grenadeThumbToCharges(0)==1&&weatherMenu::grenadeThumbToCharges(-1)==1&&weatherMenu::grenadeThumbToCharges(22)==0);
    choose(weatherMenu::weaponModeBox,171,3);assert(command()=="armament 3 5.000000 1 20 30");
    assert(IsWindowEnabled(weatherMenu::weaponPower)&&IsWindowEnabled(weatherMenu::weaponImpact)&&IsWindowEnabled(weatherMenu::grenadeTypeBox)&&IsWindowEnabled(weatherMenu::grenadeCharges));
    for(const auto& control:weatherMenu::weaponControls)assert(GetWindowLongPtrW(control.handle,GWL_STYLE)&WS_VISIBLE);
    idle();move(weatherMenu::weaponPower,7,TB_ENDTRACK);assert(command()=="armament 3 1.750000 1 20 30");
    idle();move(weatherMenu::grenadeCharges,21,TB_ENDTRACK);assert(command()=="armament 3 1.750000 1 0 30");
    idle();move(weatherMenu::weaponImpact,45,TB_ENDTRACK);assert(command()=="armament 3 1.750000 1 0 45");
    {std::ifstream packet(weatherMenu::root/L"environment.txt",std::ios::binary);std::ofstream fixture(fs::current_path()/"armament-combined-environment.txt",std::ios::binary);fixture<<packet.rdbuf();assert(packet&&fixture);}
    {std::ofstream prefs(weatherMenu::root/L"weapon-settings.txt");prefs<<"1 3 1.75 1 0 45\n";}idle();weatherMenu::refreshPreferences();
    assert(weatherMenu::weaponCommand()=="armament 3 1.750000 1 0 45"&&IsWindowEnabled(weatherMenu::weaponPower)&&IsWindowEnabled(weatherMenu::weaponImpact)&&IsWindowEnabled(weatherMenu::grenadeTypeBox)&&IsWindowEnabled(weatherMenu::grenadeCharges));
    assert(weatherMenu::sliderValue(weatherMenu::grenadeCharges)==21&&text(weatherMenu::sliderSetting(weatherMenu::grenadeCharges)->badge)==L"∞");
    {std::ifstream stored(weatherMenu::root/L"weapon-settings.txt");std::string line;std::getline(stored,line);assert(line=="1 3 1.75 1 0 45");} // refreshing legacy0 is read-only
    for(int charges=1;charges<=20;++charges){std::ofstream stored(weatherMenu::root/L"weapon-settings.txt");stored<<"1 3 1.75 1 "<<charges<<" 45\n";stored.close();idle();weatherMenu::refreshPreferences();
        assert(weatherMenu::sliderValue(weatherMenu::grenadeCharges)==charges&&weatherMenu::weaponCommand()=="armament 3 1.750000 1 "+std::to_string(charges)+" 45");}
    {std::ofstream stored(weatherMenu::root/L"weapon-settings.txt");stored<<"1 3 1.75 1 0 45\n";}idle();weatherMenu::refreshPreferences();
    {weatherMenu::WeaponSettings stored;std::istringstream legacy("1 3 2.5 0 20");assert(weatherMenu::parseWeaponSettings(legacy,stored)&&stored.mode==3&&stored.impactSpeed==30&&stored.power==2.5&&stored.charges==20);}
    choose(weatherMenu::weaponModeBox,171,0);assert(!IsWindowEnabled(weatherMenu::weaponPower)&&!IsWindowEnabled(weatherMenu::weaponImpact)&&!IsWindowEnabled(weatherMenu::grenadeTypeBox)&&!IsWindowEnabled(weatherMenu::grenadeCharges));
    weatherMenu::selectPage(9);idle();action_bindings::Sample sample;weatherMenu::beginBindingCapture(5,sample,30000);sample.keys['B']=true;weatherMenu::pollBindingCapture(sample,30001,true);
    assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes[5]=='B'&&command()=="bindingsreload 1");
    idle();sample={};weatherMenu::beginBindingCapture(6,sample,31000);sample.keys[VK_XBUTTON2]=true;weatherMenu::pollBindingCapture(sample,31001,true);
    assert(!weatherMenu::capturing()&&weatherMenu::bindingCodes[6]==VK_XBUTTON2&&command()=="bindingsreload 1");
    idle();weatherMenu::beginBindingCapture(6,sample,32000);assert(IsWindowVisible(weatherMenu::captureCancel)==FALSE); // Hidden offscreen parent: inspect own style.
    assert((GetWindowLongPtrW(weatherMenu::captureCancel,GWL_STYLE)&WS_VISIBLE)!=0);
    sample.keys[VK_LBUTTON]=true;assert(!weatherMenu::captureInput(sample,weatherMenu::captureCancel).keys[VK_LBUTTON]);click(168);assert(!weatherMenu::capturing());
    weatherMenu::beginBindingCapture(5,sample,33000);weatherMenu::selectPage(3);assert(!weatherMenu::capturing());weatherMenu::selectPage(9);idle();click(176);assert(weatherMenu::bindingCodes[5]==0);idle();click(178);assert(weatherMenu::bindingCodes[6]==0);
    {std::ofstream prefs(weatherMenu::root/L"weapon-settings.txt");prefs<<"1 2 1.75 1 0\n";}idle();weatherMenu::refreshPreferences();
    assert(weatherMenu::weaponCommand()=="armament 2 1.750000 1 0 30");
    for(const auto malformed:{"", "1 2 1 0", "2 2 1 0 3", "1 4 1 0 3", "1 0 .24 0 3", "1 0 0.24 0 3", "1 0 0.26 0 3", "1 0 1.01 0 3", "1 0 5.01 0 3", "1 0 NaN 0 3", "1 0 inf 0 3", "1 0 1 2 3", "1 0 1 0 21", "1 0 1 0 -1", "1 0 1 0 03", "1 0 1 0 3 extra"}){
        weatherMenu::WeaponSettings previous;std::istringstream file(malformed);assert(!weatherMenu::parseWeaponSettings(file,previous)&&previous.mode==0&&previous.power==1&&previous.grenade==0&&previous.charges==3);
    }
    weatherMenu::selectPage(8);choose(weatherMenu::weaponModeBox,171,1);
    for(const auto position:{5,32,33,150}){idle();move(weatherMenu::weaponImpact,position,TB_THUMBTRACK);assert(!weatherMenu::pending);move(weatherMenu::weaponImpact,position,TB_ENDTRACK);
        assert(weatherMenu::sliderValue(weatherMenu::weaponImpact)==std::clamp(std::round(position/5.)*5,5.,150.));assert(command()==weatherMenu::weaponCommand());}
    for(const auto bad:{"1 1 1 0 3 0","1 1 1 0 3 6","1 1 1 0 3 151","1 1 1 0 3 030","1 1 1 0 3 30 extra"}){weatherMenu::WeaponSettings value;std::istringstream input(bad);assert(!weatherMenu::parseWeaponSettings(input,value)&&value.impactSpeed==30);}
    weatherMenu::selectPage(9);idle();sample={};weatherMenu::beginBindingCapture(7,sample,35000);sample.keys[255]=true;weatherMenu::pollBindingCapture(sample,35001,true);
    assert(weatherMenu::bindingCodes[7]==255&&command()=="bindingsreload 1");idle();click(185);assert(weatherMenu::bindingCodes[7]==0);
    for(int i=0;i<8;++i){choose(weatherMenu::actionModeBoxes[i],190+i,1);assert(command()=="actionmodesreload 1"&&action_bindings::loadModes(weatherMenu::root).values()[i]==1);
        choose(weatherMenu::actionModeBoxes[i],190+i,0);assert(command()=="actionmodesreload 1"&&action_bindings::loadModes(weatherMenu::root).values()[i]==0);}
    {std::ofstream modes(weatherMenu::root/L"action-modes.txt");modes<<"2 1 0 1 0 1 0 1 0\n";}idle();weatherMenu::refreshPreferences();
    for(int i=0;i<8;++i)assert(SendMessageW(weatherMenu::actionModeBoxes[i],CB_GETCURSEL,0,0)==(i%2==0));
    for(int lang=0;lang<5;++lang){language::current=lang;language::relabel(weatherMenu::window.load());weatherMenu::selectPage(8);assert(text(weatherMenu::navigation[2])==language::tr(L"Оснащение"));assert(text(weatherMenu::pageTitle)==language::tr(L"Боевой режим"));assert(SendMessageW(weatherMenu::weaponModeBox,CB_GETCOUNT,0,0)==4&&SendMessageW(weatherMenu::grenadeTypeBox,CB_GETCOUNT,0,0)==2);}
    language::current=0;language::relabel(weatherMenu::window.load());idle();
    std::cout<<"PASS four armament modes including combined live controls, exact external payload and storage round trip, power/types/capacity and impact speed5..150 step5, all eight captures, eight Toggle/Hold commands, cancellation, strict storage and five languages\n";
}
void checkVisionLanguages(){
    int parsed=0;for(int mode=0;mode<16;++mode){std::istringstream valid(std::to_string(mode));assert(weatherMenu::parseVisionSettings(valid,parsed)&&parsed==mode);choose(weatherMenu::visionModeBox,146,mode);assert(command()=="vision "+std::to_string(mode));}
    for(const auto malformed:{"", "-1", "16", "3.5", "1 extra", "night", "01", "+1"}){std::istringstream invalid(malformed);assert(!weatherMenu::parseVisionSettings(invalid,parsed)&&parsed==15);}
    for(int style=0;style<6;++style){choose(weatherMenu::anomalyStyleBox,148,style);assert(command()=="anomalystyle "+std::to_string(style));}
    for(int lang=0;lang<5;++lang){language::current=lang;language::relabel(weatherMenu::window.load());weatherMenu::selectPage(2);assert(text(weatherMenu::navigation[1])==language::tr(L"Изображение"));assert(text(weatherMenu::clearBindingButtons[0])==language::tr(L"Убрать"));assert(SendMessageW(weatherMenu::visionModeBox,CB_GETCOUNT,0,0)==16&&SendMessageW(weatherMenu::visionModeBox,CB_GETCURSEL,0,0)==15);checkPages();}
    language::current=0;language::relabel(weatherMenu::window.load());idle();
    std::cout<<"PASS sixteen vision commands, six anomaly styles, strict parsing and five-language navigation\n";
}
void checkWorkerMenuDispatch(){
    const auto originalRoot=weatherMenu::root;weatherMenu::cleanup();
    const auto fixture=originalRoot/L"worker-menu";fs::create_directories(fixture);
    weatherMenu::root=fixture;weatherMenu::initialPosition={-20000,-20000};weatherMenu::bindingsLoaded=false;weatherMenu::bindingsDirty=false;
    const auto foreground=GetForegroundWindow();
    weatherMenu::modalChanged=CreateEventW(nullptr,FALSE,FALSE,nullptr);assert(weatherMenu::modalChanged);
    std::thread worker([&](){
        action_bindings::RuntimeActions actions;action_bindings::Sample sample;ULONGLONG now=GetTickCount64();
        const auto step=[&](bool focus,bool menu,bool pressed){
            sample.keys[VK_F6]=pressed;weatherMenu::pump(focus,&sample);
            const auto codes=weatherMenu::getCurrentBindings();const auto edges=actions.poll(codes,sample,focus,menu,weatherMenu::capturing(),++now);
            return weatherMenu::dispatchMenuAction(edges[0],codes[0],menu,false);
        };
        // First F6 creates the real menu on a worker thread, just as the bridge
        // does. Only focus activation is disabled for this offscreen fixture.
        assert(!weatherMenu::window);assert(!step(true,false,false));assert(step(true,false,true));
        assert(weatherMenu::window&&IsWindowVisible(weatherMenu::window));
        assert(weatherMenu::visible()&&weatherMenu::modalRequested&&!weatherMenu::focused()&&weatherMenu::cursorShows==0);
        assert(WaitForSingleObject(weatherMenu::modalChanged,0)==WAIT_OBJECT_0);
        assert(!step(false,true,true)&&IsWindowVisible(weatherMenu::window));assert(!step(false,true,false));
        assert(step(false,true,true)&&!IsWindowVisible(weatherMenu::window));
        assert(!weatherMenu::visible()&&!weatherMenu::modalRequested&&WaitForSingleObject(weatherMenu::modalChanged,0)==WAIT_OBJECT_0);
        for(int cycle=0;cycle<100;++cycle){
            assert(!step(true,false,false));assert(step(true,false,true)&&IsWindowVisible(weatherMenu::window));
            assert(!step(false,true,true)&&IsWindowVisible(weatherMenu::window));assert(!step(false,true,false));
            assert(step(false,true,true)&&!IsWindowVisible(weatherMenu::window));
        }
        // Menu Hold is owned only by a real press; handoff to own foreground
        // preserves eligibility, release closes immediately without another edge.
        actions=action_bindings::RuntimeActions{};sample={};weatherMenu::lastMenuMode=0;weatherMenu::menuHoldOwned=false;
        const auto heldStep=[&](bool focus,bool menu,bool pressed,bool blocked=false){sample.keys[VK_F6]=pressed;
            const auto codes=weatherMenu::getCurrentBindings();const auto holdEdges=actions.poll(codes,sample,focus,menu,blocked,++now);
            return weatherMenu::dispatchMenuState(holdEdges[0],actions.held()[0],codes[0],menu,1,false);};
        assert(!heldStep(true,false,true)&&!weatherMenu::visible()); // Startup-held primes.
        assert(!heldStep(true,false,false));assert(heldStep(true,false,true)&&weatherMenu::visible());
        assert(!heldStep(false,true,true)&&weatherMenu::visible()&&actions.held()[0]);
        assert(heldStep(false,true,false)&&!weatherMenu::visible());
        assert(heldStep(true,false,true)&&weatherMenu::visible());
        assert(heldStep(false,false,true)&&!weatherMenu::visible()); // Alt-Tab loss closes without stealing focus.
        assert(!heldStep(true,false,true)&&!weatherMenu::visible());assert(!heldStep(true,false,false));
        assert(heldStep(true,false,true));assert(heldStep(false,true,true,true)&&!weatherMenu::visible());
        assert(!heldStep(true,false,true));assert(!heldStep(true,false,false));
        weatherMenu::show(false);assert(!heldStep(false,true,false)&&weatherMenu::visible()); // Tool-opened menu is not owned by Hold.
        weatherMenu::hide(false);weatherMenu::lastMenuMode=0;weatherMenu::menuHoldOwned=false;
        // Existing bindings files retain F6 through both legacy and new formats.
        {std::ofstream f(fixture/L"bindings.txt");f<<"117 119 120\n";}weatherMenu::nextBindingsRefresh=0;
        assert(weatherMenu::getCurrentBindings()==action_bindings::defaults());
        {std::ofstream f(fixture/L"bindings.txt");f<<"117 2 1128 2030\n";}weatherMenu::nextBindingsRefresh=0;
        assert(weatherMenu::getCurrentBindings()==(action_bindings::Bindings{117,2,1128,2030}));
        actions=action_bindings::RuntimeActions{};assert(!step(true,false,false));assert(step(true,false,true));assert(!step(false,true,false));assert(step(false,true,true));
        // Focus return with F6 already held and a capture suppress menu actions.
        actions=action_bindings::RuntimeActions{};assert(!step(false,false,false));assert(!step(true,false,true)&&!IsWindowVisible(weatherMenu::window));
        weatherMenu::selectPage(3);weatherMenu::beginBindingCapture(1,sample,now);
        const auto captureEdges=actions.poll(weatherMenu::getCurrentBindings(),sample,true,false,true,++now);
        assert(!captureEdges[0]&&!weatherMenu::dispatchMenuAction(captureEdges[0],117,false,false));weatherMenu::cancelBindingCapture();
        assert(!weatherMenu::dispatchMenuAction(true,VK_LBUTTON,true,false));
        // A visible menu whose activation failed blocks flight/action keys,
        // while retaining F6 to close it when the game still has foreground.
        {std::ofstream f(fixture/L"bindings.txt");f<<"117 119 120 75 76\n";}weatherMenu::nextBindingsRefresh=0;
        actions=action_bindings::RuntimeActions{};sample={};weatherMenu::show(false);assert(weatherMenu::visible()&&!weatherMenu::focused());
        auto blockedEdges=actions.poll(weatherMenu::getCurrentBindings(),sample,true,weatherMenu::visible(),false,++now);
        assert(std::none_of(blockedEdges.begin(),blockedEdges.end(),[](bool value){return value;}));
        sample.keys[VK_F8]=true;sample.keys[VK_F9]=true;sample.keys['K']=true;sample.keys['L']=true;sample.keys[VK_F6]=true;
        blockedEdges=actions.poll(weatherMenu::getCurrentBindings(),sample,true,weatherMenu::visible(),false,++now);
        assert(blockedEdges[0]&&!blockedEdges[1]&&!blockedEdges[2]&&!blockedEdges[3]&&!blockedEdges[4]);
        assert(weatherMenu::dispatchMenuAction(blockedEdges[0],117,true,false)&&!weatherMenu::visible());
        assert(!fs::exists(fixture/L"pda-request.txt"));weatherMenu::cleanup();
    });
    worker.join();assert(GetForegroundWindow()==foreground);CloseHandle(weatherMenu::modalChanged);weatherMenu::modalChanged=nullptr;
    weatherMenu::initialPosition={CW_USEDEFAULT,CW_USEDEFAULT};weatherMenu::root=originalRoot;weatherMenu::bindingsLoaded=false;weatherMenu::bindingsDirty=false;
    std::cout<<"PASS production menu edge dispatcher on worker thread: first F6 creates external menu,101 toggles once/no repeat, modal visibility before focus/click, writer wake, legacy bindings, action blocking and no foreground change\n";
}
void checkModalFocusRecovery(){
    const auto foreground=GetForegroundWindow();
    weatherMenu::initialPosition={-20000,-20000};weatherMenu::show(false);
    const auto menu=weatherMenu::window.load();
    // Actual offscreen Win32 windows supply visibility/ownership to the same
    // recovery selector used by production. Never activate a fixture over the
    // user's application or synthesize keyboard/mouse input.
    const auto fixture=[](const wchar_t* title){
        const auto h=CreateWindowExW(WS_EX_NOACTIVATE,L"STATIC",title,WS_POPUP,-20000,-20000,64,64,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);
        assert(h);ShowWindow(h,SW_SHOWNOACTIVATE);return h;
    };
    const auto game=fixture(L"Game viewport fixture"),other=fixture(L"Other application fixture"),editor=fixture(L"OSD editor fixture");
    assert(weatherMenu::visible()&&!weatherMenu::focused()&&weatherMenu::cursorShows==0);
    assert(weatherMenu::modalRecoveryTarget(game,game)==menu);
    assert(!weatherMenu::modalRecoveryTarget(other,game)&&!weatherMenu::modalRecoveryTarget(menu,game));
    assert(!weatherMenu::modalRecoveryTarget(game,nullptr));
    assert(!weatherMenu::recoverModalFocus(game)&&GetForegroundWindow()==foreground);
    assert(!weatherMenu::activateWindow(menu,nullptr,game)&&GetForegroundWindow()==foreground);
    // OSD has priority when it is visible, even after it loses foreground.
    const auto originalEditor=osd::editor.exchange(editor);
    assert(weatherMenu::modalRecoveryTarget(game,game)==editor);
    ShowWindow(editor,SW_HIDE);assert(weatherMenu::modalRecoveryTarget(game,game)==menu);
    osd::editor=originalEditor;
    // A validated HWND from an earlier sample cannot redirect a different app.
    action_bindings::Sample sample;weatherMenu::pump(true,&sample,game);
    assert(GetForegroundWindow()==foreground&&weatherMenu::visible()&&weatherMenu::cursorShows==0);
    weatherMenu::hide(false);assert(!weatherMenu::visible()&&!weatherMenu::modalRecoveryTarget(game,game));
    DestroyWindow(game);DestroyWindow(other);DestroyWindow(editor);weatherMenu::cleanup();
    weatherMenu::initialPosition={CW_USEDEFAULT,CW_USEDEFAULT};
    std::cout<<"PASS scoped modal focus recovery: game click selects menu/visible OSD, other apps and changed foreground remain untouched, hidden startup/close has no modal target\n";
}
void screenshot(const fs::path& destination){
    const auto h=weatherMenu::window.load();const auto bounds=windowRect(h);const int width=bounds.right-bounds.left,height=bounds.bottom-bounds.top;
    // Native combo/edit children only print their text after initial layout in
    // a visible parent. Render our own test window outside every monitor and
    // without activation, then immediately return it to its hidden position.
    SetWindowPos(h,nullptr,-20000,-20000,width,height,SWP_NOZORDER|SWP_NOACTIVATE|SWP_SHOWWINDOW);
    const auto dc=GetDC(h),memory=CreateCompatibleDC(dc);const auto bitmap=CreateCompatibleBitmap(dc,width,height);const auto previous=SelectObject(memory,bitmap);
    SendMessageW(h,WM_PRINT,reinterpret_cast<WPARAM>(memory),PRF_NONCLIENT|PRF_CLIENT|PRF_CHILDREN|PRF_ERASEBKGND);SelectObject(memory,previous);
    BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=width;info.bmiHeader.biHeight=-height;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;
    std::vector<unsigned char> pixels(static_cast<size_t>(width)*height*4);assert(GetDIBits(memory,bitmap,0,height,pixels.data(),&info,DIB_RGB_COLORS));
    BITMAPFILEHEADER header{};header.bfType=0x4d42;header.bfOffBits=sizeof(header)+sizeof(info.bmiHeader);header.bfSize=header.bfOffBits+static_cast<DWORD>(pixels.size());
    std::ofstream out(destination,std::ios::binary);out.write(reinterpret_cast<const char*>(&header),sizeof(header));out.write(reinterpret_cast<const char*>(&info.bmiHeader),sizeof(info.bmiHeader));out.write(reinterpret_cast<const char*>(pixels.data()),static_cast<std::streamsize>(pixels.size()));assert(out.good());
    DeleteObject(bitmap);DeleteDC(memory);ReleaseDC(h,dc);ShowWindow(h,SW_HIDE);SetWindowPos(h,nullptr,bounds.left,bounds.top,width,height,SWP_NOZORDER|SWP_NOACTIVATE);
}
}
int main(){
    _set_error_mode(_OUT_TO_STDERR);std::cout<<std::unitbuf;const auto fixture=fs::temp_directory_path()/(L"ZoneFPV-menu-test-"+std::to_wstring(GetCurrentProcessId()));fs::create_directories(fixture);weatherMenu::root=fixture;
    assert(!weatherMenu::visible()&&!weatherMenu::modalRequested&&weatherMenu::cursorShows==0);
    weatherMenu::create();const auto h=weatherMenu::window.load();assert(h&&IsWindow(h)&&!IsWindowVisible(h));
    assert(weatherMenu::experimentCommand()=="experiments 0 0 0 0 0 0 0 0 0");checkGrouping();checkSliders();checkPreferences();checkBindings();checkArmament();checkVisionLanguages();
    const auto original=geometry();const auto font=controlFont(weatherMenu::status);const HWND combos[]={weatherMenu::modeBox,weatherMenu::deviceBox,weatherMenu::profileBox,weatherMenu::languageBox,weatherMenu::visionModeBox};
    for(const auto size:{SIZE{560,560},SIZE{1000,900},SIZE{700,700}}){resize(size.cx,size.cy);checkPages();for(const auto combo:combos){if(SendMessageW(combo,CB_GETCOUNT,0,0)<2){SendMessageW(combo,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(L"Fixture A"));SendMessageW(combo,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(L"Fixture B"));}checkDropdown(combo);}}
    const auto restored=geometry();assert(restored.size()==original.size());for(size_t i=0;i<original.size();++i)assert(EqualRect(&restored[i],&original[i]));assert(controlFont(weatherMenu::status).lfHeight==font.lfHeight);
    MINMAXINFO limits{};SendMessageW(h,WM_GETMINMAXINFO,0,reinterpret_cast<LPARAM>(&limits));assert(limits.ptMinTrackSize.x==560&&limits.ptMinTrackSize.y==560);
    for(int page=0;page<11;++page){weatherMenu::selectPage(page);screenshot(fs::current_path()/("menu-v41-page-"+std::to_string(page)+".bmp"));}
    weatherMenu::advancedWorld=true;weatherMenu::selectPage(4);screenshot(fs::current_path()/"menu-v41-world-advanced.bmp");
    resize(560,560);weatherMenu::selectPage(2);screenshot(fs::current_path()/"menu-v41-camera-minimum.bmp");
    weatherMenu::selectPage(9);screenshot(fs::current_path()/"menu-v41-bindings-minimum.bmp");
    resize(700,700);action_bindings::Sample capture;weatherMenu::beginBindingCapture(3,capture,GetTickCount64());screenshot(fs::current_path()/"menu-v41-bindings-capture.bmp");weatherMenu::cancelBindingCapture();
    resize(820,760);weatherMenu::cleanup();weatherMenu::create();const auto saved=windowRect(weatherMenu::window.load());assert(saved.right-saved.left==820&&saved.bottom-saved.top==760&&!IsWindowVisible(weatherMenu::window.load()));weatherMenu::cleanup();
    for(const auto malformed:{"invalid","700 700","559 700 0","700 8193 0","700 700 2","700 700 0 extra"}){std::ofstream f(fixture/L"menu-window.txt");f<<malformed;f.close();weatherMenu::create();const auto rect=windowRect(weatherMenu::window.load());assert(rect.right-rect.left==700&&rect.bottom-rect.top==700);weatherMenu::cleanup();}
    assert(GetForegroundWindow()!=h);checkWorkerMenuDispatch();checkModalFocusRecovery();assert(fs::equivalent(fixture.parent_path(),fs::temp_directory_path())&&fixture.filename().wstring().find(L"ZoneFPV-menu-test-")==0);fs::remove_all(fixture);
    std::cout<<"PASS hidden menu: bounds at 560/700/1000, dropdowns, stable resize, saved dimensions and no foreground change\n";
    return 0;
}
