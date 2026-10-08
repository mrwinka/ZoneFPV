-- Native PDA controls share the command handler used by the desktop menu.
-- Building a page is pure: neither opening a tab nor repainting changes settings.
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local experiments=dofile(here..'experiments_settings.lua')
local modes=dofile(here..'vision_modes.lua')
local artifactSettings=dofile(here..'artifact_settings.lua')
local weaponSettings=dofile(here..'weapon_settings.lua')
local osdModel=dofile(here..'pda_osd.lua')
local M={}
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function finite(v,fallback)
    return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge and v or fallback
end
local function cycle(v,list,dir)
    local index=1;for i,x in ipairs(list)do if x==v then index=i;break end end
    return list[(index-1+(dir or 1))%#list+1]
end
local function precise(v)
    -- Settings files retain six decimal places. Changing a sibling control must
    -- not round an untouched multiplier to the slider's display precision.
    local text=string.format('%.6f',v):gsub('0+$',''):gsub('%.$','')
    return text
end
local function experimentCommand(current,key,value)
    local tokens={}
    for i,name in ipairs(experiments.names)do
        local v=name==key and value or current[name]
        -- false is a legitimate toggle value.
        if name==key then v=value end
        tokens[i]=i==1 and tostring(v or 0) or (v and '1' or '0')
    end
    return 'FPVExperiments '..table.concat(tokens,' ')
end
function M.sections(s,translate)
    s=s or {};local tr=translate or function(x)return x end
    local cfg,options,exp,radio=s.cfg or {},s.options or {},s.experiments or {},s.radio or {}
    local pages={}
    local function page(label,description)
        local p={id=#pages,label=tr(label),description=tr(description),rows={}};pages[#pages+1]=p;return p
    end
    local function row(p,label,value,command,kind,help)
        local r={key=label,label=tr(label),value=tostring(value),command=command,kind=kind or 'choice',help=help and tr(help)}
        p.rows[#p.rows+1]=r;return r
    end
    local function toggle(p,label,v,fn,help)
        return row(p,label,tr(v and 'Вкл.' or 'Выкл.'),function()return fn(not v)end,'toggle',help)
    end
    local function option(p,label,key,help)
        return toggle(p,label,options[key],function(v)return 'FPVOption '..key..' '..(v and '1' or '0')end,help)
    end
    local function feature(p,label,key,help)
        return toggle(p,label,exp[key],function(v)return experimentCommand(exp,key,v)end,help)
    end
    local function setting(kind,args)return 'settings',{action=kind,args=args}end
    local function backend(p,label,value,kind,args,help)
        return row(p,label,value,function()return setting(kind,args)end,'action',help)
    end
    local function status(p,label,value,help)
        return row(p,label,value,function()return nil end,'status',help)
    end
    local function slider(p,label,number,minimum,maximum,step,format,command,help)
        number=clamp(finite(number,minimum),minimum,maximum)
        local function rounded(value)
            value=clamp(finite(value,number),minimum,maximum)
            return clamp(minimum+math.floor((value-minimum)/step+.5)*step,minimum,maximum)
        end
        local r=row(p,label,format(number),function(direction)return command(rounded(number+(direction or 1)*step))end,'slider',help)
        r.number,r.min,r.max,r.step=number,minimum,maximum,step
        r.set=function(value)return command(rounded(value))end
        r.format=function(value)return format(rounded(value))end
        return r
    end
    local speed=clamp(finite(cfg.speed_preset,2),0,5)
    local tilt=clamp(finite(cfg.camera_tilt,25),0,60)
    local range=clamp(finite(radio.range,1500),50,20000)
    local attenuation=clamp(finite(radio.attenuation,2),0,5)
    local multiplier=function(value)return string.format('%.2f ×',value)end
    local p=page('Основное','Настройки применяются сразу. Закройте КПК, чтобы продолжить полёт.')
    row(p,'Режим полёта',string.upper(cfg.flight_mode or 'acro'),function(d)return 'FPVMode '..cycle(cfg.flight_mode,{'angle','acro','3d'},d)end,'choice',
        'ANGLE выравнивает дрон; ACRO даёт свободное вращение; 3D добавляет обратную тягу. Смена режима завершает полёт.')
    slider(p,'Множитель скорости',speed,0,5,.05,multiplier,function(value)return string.format('FPVSettings %.2f %d',value,tilt)end,
        '2× — обычная скорость. Больше значение — быстрее дрон; 0 отключает тягу, дрон падает.')
    option(p,'Альтернативный режим FPV','alternate','В альтернативном режиме персонаж остаётся на старте. Смена режима завершает полёт.')
    option(p,'Свободный полёт сквозь стены','noclip','Отключает столкновения с геометрией мира во время FPV.')
    option(p,'Разрешить запуск с поднятым газом','hotstart','Позволяет начать полёт, даже если стик газа не опущен.')

    p=page('Пульт','Выберите пульт и откалибруйте стики. Кнопки настраиваются в разделе «Настройки».')
    local settings=s.settings or {}
    local devices,ids={{id=0,name=tr('Автоматически')}},{0}
    for i,device in ipairs(settings.devices or {})do
        if i>64 then break end
        if type(device.id)=='number'and device.id>0 then devices[#devices+1]=device;ids[#ids+1]=device.id end
    end
    local selectedDevice=settings.device or settings.selectedDevice or 0
    local deviceName=selectedDevice==0 and tr('Автоматически')or tostring(selectedDevice)
    for _,device in ipairs(devices)do if device.id==selectedDevice then
        deviceName=device.name
        local backendName=({[0]='WinMM',[1]='DirectInput',[2]='XInput'})[device.backend]
        if backendName and not deviceName:find(backendName,1,true)then deviceName=deviceName..' ['..backendName..']'end
    end end
    row(p,'Устройство контроллера',deviceName,function(d)return setting('device',{cycle(selectedDevice,ids,d)})end,'choice',
        'Выбор подключённого пульта и готовой раскладки каналов.')
    local profileNames={'Автоматически','Xbox / USB AETR','RadioMaster Pocket DirectInput','RadioMaster Pocket WinMM','PlayStation','EdgeTX / OpenTX AETR','TAER DirectInput','AETR USB','TAER USB','Mode 1 AETR','DualShock 4'}
    local profile=clamp(finite(settings.profile,0),0,10)
    row(p,'Профиль контроллера',tr(profileNames[profile+1]),function(d)return setting('profile',{(profile+(d or 1))%#profileNames})end,'choice',
        'Профиль задаёт начальную раскладку. Если направления не совпадают, выполните калибровку. Ваш прежний профиль сохраняется в резервную копию.')
    status(p,'Состояние подключения',tr(settings.connected and 'Подключено'or 'Не подключено'),'Выберите подключённое устройство и проверьте живые оси.')
    local calibration=settings.calibration or {};local stage=calibration.stage or 0
    local calibrationLabel=stage==1 and 'Зафиксировать нейтраль'or stage==2 and 'Идёт измерение...'or stage==4 and 'Удерживаю — подтвердить'or 'Калибровать оси'
    local advance=backend(p,'Калибровка осей',tr(calibrationLabel),'calibrate',{0},'Пошаговая настройка центра, диапазона и направления стиков.')
    advance.disabled=stage==2 or not settings.connected
    local cancel=backend(p,'Отменить калибровку',tr('Отмена'),'calibrate',{1},'Отмена сохраняет прежнюю калибровку.')
    cancel.disabled=stage==0
    local stageLabels={'Калибровка не запущена','Оставьте стики в нейтральном положении.','Двигайте выбранный стик до упора в обе стороны.','Продолжите калибровку следующей оси.','Удерживайте стик в указанном направлении и подтвердите.'}
    local remaining=math.max(0,finite(calibration.remainingMs,0))/1000
    if stage>0 and type(settings.status)=='string'and settings.status~=''then p.description=tr(settings.status)end
    status(p,'Ход калибровки',tr(stageLabels[stage+1]or stageLabels[1])..(stage>1 and string.format('  %d/4  %.1f s',(calibration.axis or 0)+1,remaining)or ''),
        'Выполните указания по очереди для крена, тангажа, газа и рыскания.')
    for i=1,8 do
        status(p,'CH'..i,string.format('%d',clamp(finite((settings.axes or {})[i],32768),0,65535)),'Живое значение оси выбранного пульта: 0–65535.')
    end

    p=page('Камера','Наклон, ночное и тепловое видение, изображение.')
    slider(p,'Наклон камеры',tilt,0,60,1,function(value)return string.format('%d°',value)end,
        function(value)return string.format('FPVSettings %s %d',precise(speed),value)end,'Угол камеры вверх относительно корпуса дрона.')
    local mode=s.vision or 0
    local modeInfo=modes.modes and modes.modes[mode]
    row(p,'Режим видения',tr(mode==0 and 'Выкл.' or modeInfo and (modeInfo.label or modeInfo.name) or tostring(mode)),
        function(d)return 'FPVVision '..tostring((mode+d)%(modes.max+1))end,'choice',
        'Тепловое изображение выделяет загруженных персонажей; стены закрывают силуэты.')
    local styles={'Выкл.','Classic FPV','Clean analog','Monochrome','Worn VHS'}
    local style=cfg.analog_style or 0
    row(p,'Стиль аналоговой камеры',tr(styles[style+1] or styles[1]),function(d)return 'FPVStyle '..((style+d)%5)end,'choice',
        'Добавляет визуальный стиль FPV-камеры поверх выбранного режима видения.')
    toggle(p,'Фонарик дрона',not s.features or s.features.flashlightEnabled~=false,
        function(value)return 'FPVFlashlight '..(value and '1' or '0')end,'Разрешает фонарик дрона. Включение и выключение — назначенной кнопкой.')
    toggle(p,'Нижняя камера',not s.features or s.features.cameraDownEnabled~=false,
        function(value)return 'FPVCameraDown '..(value and '1' or '0')end,'Разрешает нижнюю камеру. Переключение — назначенной кнопкой; камера поворачивается вместе с дроном.')

    p=page('OSD','Выберите показатель в списке или на предпросмотре. Перетащите его или измените настройки справа.')
    local compact={'OSD','Шрифт','Показатель','Отображать','Размер','Цвет',
        'Обычный прицел','Форма обычного','Нижний прицел','Форма нижнего','Нижний вид','Сброс элемента','Сброс раскладки'}
    p.rows=osdModel.rows(s.osd,tr);p.preview=s.osd and s.osd.preview or {}
    p.osdItems=osdModel.itemList(s.osd,tr)
    for i,r in ipairs(p.rows)do r.compactLabel=tr(compact[i])end
    p.inlineRows=#p.rows;p.previewBounds=s.osd and s.osd.previewBounds or {}

    p=page('Мир','Погода, время и дальность видимости игрового мира.')
    option(p,'Сильно замедлить мир в FPV','freeze','Замедляет события вокруг дрона. При выходе из FPV обычная скорость возвращается.')
    local weather={'Clearly','Cloudy','Fogy','LightRainy','Rainy','Thundery','Stormy'}
    local weatherNames={Clearly='Ясно',Cloudy='Облачно',Fogy='Туман',LightRainy='Небольшой дождь',Rainy='Дождь',Thundery='Гроза',Stormy='Шторм'}
    row(p,'Погода',tr(weatherNames[s.weather]or 'Текущая'),function(d)return 'XForceWeather '..cycle(s.weather or 'Clearly',weather,d)end,'choice',
        'Меняет погоду в текущем мире.')
    row(p,'Время суток',s.hour and string.format('%02d:00',s.hour)or tr('Текущее'),function(d)return 'XSetWeatherTime '..(((s.hour or 12)+d)%24)..' 0 0' end,'choice',
        'Выбирает час суток в текущем мире.')
    local scales={1,1.25,1.5,2,3,4,5}
    slider(p,'Дальность загрузки геометрии',s.distance or 0,0,6,1,function(value)return string.format('%g ×',scales[value+1])end,
        function(value)return 'FPVDistance '..value end,'1× — обычная дальность. Больше значение — больше видимых деталей и нагрузка на компьютер.')

    p=page('Связь','Дальность и помехи радиосигнала. RSSI показывает связь с точкой старта.')
    local function signal(on,newRange,newAttenuation)return string.format('FPVSignal %d %d %s',on and 1 or 0,newRange,precise(newAttenuation))end
    toggle(p,'Симуляция RSSI',radio.enabled,function(value)return signal(value,range,attenuation)end,
        'Чем дальше дрон от старта, тем слабее связь. При 0% RSSI моторы отключаются и FPV завершается.')
    slider(p,'Максимальная дальность',range,50,20000,50,function(value)return string.format('%d m',value)end,
        function(value)return signal(radio.enabled,value,attenuation)end,'Расстояние от точки старта, на котором радиосигнал полностью теряется.')
    slider(p,'Множитель затухания',attenuation,0,5,.05,multiplier,function(value)return signal(radio.enabled,range,value)end,
        '2× — обычное затухание. Больше значение — связь слабеет раньше; 0 отключает затухание.')
    local noise={'Полосы','Цветной аналог','Монохромный снег','Цифровые блоки','Аналоговый видеосигнал'}
    row(p,'Вид помех',tr(noise[(exp.style or 0)+1]),function(d)return experimentCommand(exp,'style',((exp.style or 0)+d)%5)end,'choice',
        'Внешний вид экранных помех при слабом радиосигнале.')
    feature(p,'Препятствия ослабляют сигнал','obstacles','Стены и другие препятствия между дроном и точкой старта ухудшают связь.')
    feature(p,'Помехи рядом с аномалиями','anomalyInterference','Аномалии создают дополнительные помехи рядом с дроном.')
    local anomalyStyle=s.anomalyStyle or options.anomalyStyle or 0
    row(p,'Помехи аномалий',tr(anomalyStyle==0 and 'Как у радиосигнала' or noise[anomalyStyle] or noise[1]),
        function(d)return 'FPVAnomalyStyle '..((anomalyStyle+d)%6)end,'choice','Стиль помех от аномалий выбирается независимо от помех радиосигнала.')

    p=page('Сканер','Метки персонажей и аномалий, поиск и сбор артефактов.')
    feature(p,'Сканировать NPC и мутантов','characters','Показывает метки персонажей и расстояние до них.')
    feature(p,'Сканировать аномалии','anomaliesScan','Показывает метки обнаруженных аномалий и расстояние до них.')
    feature(p,'Детектор артефактов','detector','Помогает найти ближайший артефакт. Отображение детектора настраивается в OSD.')
    slider(p,'Расстояние для сбора артефакта',artifactSettings.value(s.collectRange or exp.collectRange),artifactSettings.min,
        artifactSettings.max,artifactSettings.step,function(value)return string.format('%.1f m',value)end,
        function(value)return string.format('FPVCollectRange %.1f',value)end,
        'Максимальное расстояние от дрона до артефакта для сбора. По умолчанию 3 м; детектор обнаруживает артефакты до 100 м.')

    p=page('Прочность','Повреждения дрона, атаки врагов и защита персонажа.')
    feature(p,'Прочность дрона','droneHP','Сильные столкновения повреждают дрон. При 0 HP он падает; мягкие посадки безопасны.')
    feature(p,'Реакция NPC и мутантов','reaction','Враги замечают и атакуют дрон. Эта настройка также включает его прочность.')
    feature(p,'Урон от аномалий','anomalyDamage','Аномалии повреждают дрон. Эта настройка также включает его прочность.')
    slider(p,'Множитель урона от столкновений',s.impact or 2,0,5,.05,multiplier,function(value)return string.format('FPVImpact %.2f',value)end,
        '2× — обычный урон от столкновений; 0 отключает его. Урон от врагов и аномалий не меняется.')
    option(p,'Неуязвимость персонажа','god','Защищает персонажа игрока. Прочность и повреждения дрона настраиваются отдельно.')

    p=page('Боевой режим','Выберите оснащение перед запуском. Изменение настроек завершает полёт; новый полёт пополняет заряды.')
    local armament=weaponSettings.value(s.armament)
    local function armamentCommand(key,value)
        local nextValues={mode=armament.mode,power=armament.power,grenade=armament.grenade,charges=armament.charges,impactSpeed=armament.impactSpeed}
        nextValues[key]=value
        return string.format('FPVArmament %d %s %d %d %d',nextValues.mode,precise(nextValues.power),nextValues.grenade,nextValues.charges,nextValues.impactSpeed)
    end
    local weaponModes={'Без вооружения','Камикадзе','Сброс гранат','Сброс + камикадзе'}
    local weaponModeRow=row(p,'Тип дрона',tr(weaponModes[armament.mode+1]),function(d)return armamentCommand('mode',(armament.mode+(d or 1))%#weaponModes)end,'choice',
        'Камикадзе взрывается при ударе быстрее выбранного порога; столкновения всегда включены. Дрон со сбросом несёт активированные гранаты.')
    weaponModeRow.help=weaponModeRow.help..' '..tr('Комбинированный режим позволяет сбрасывать гранаты и взрываться при ударе.')
    if weaponSettings.hasKamikaze(armament.mode)then
    slider(p,'Мощность взрыва',armament.power,weaponSettings.minPower,weaponSettings.maxPower,weaponSettings.powerStep,multiplier,
        function(value)return armamentCommand('power',value)end,'Множитель силы взрыва камикадзе. 1× — обычный взрыв.')
    slider(p,'Минимальная скорость удара',armament.impactSpeed,weaponSettings.minImpactSpeed,weaponSettings.maxImpactSpeed,weaponSettings.impactSpeedStep,
        function(value)return string.format('%d km/h',value)end,function(value)return armamentCommand('impactSpeed',value)end,
        'Скорость сближения с поверхностью для взрыва камикадзе. Быстрое скольжение вдоль стены не вызывает взрыв.')
    end
    if weaponSettings.hasGrenades(armament.mode)then
    local grenadeNames={'RGD-5','F-1'}
    row(p,'Тип гранаты',grenadeNames[armament.grenade+1],function(d)return armamentCommand('grenade',(armament.grenade+(d or 1))%#grenadeNames)end,'choice',
        'Выберите гранату для сброса. После сброса её взрыватель уже запущен.')
    local unlimitedCharges=weaponSettings.maxCharges+1
    local uiCharges=armament.charges==0 and unlimitedCharges or armament.charges
    slider(p,'Количество зарядов',uiCharges,1,unlimitedCharges,1,
        function(value)return value==unlimitedCharges and tr('Без ограничений')or string.format('%d',value)end,
        function(value)return armamentCommand('charges',value==unlimitedCharges and 0 or value)end,
        'Запас гранат на один полёт. После 20 справа — без ограничений. Возврат к старту не пополняет запас.')
    end
    p=page('Кнопки','Назначьте клавиши, кнопки мыши и пульта или положения переключателей на действия дрона.')
    local bindingNames={'Кнопка меню','Кнопка входа / выхода из FPV','Кнопка возврата к старту','Кнопка сбора артефакта','Кнопка фонарика','Кнопка камеры вниз','Кнопка сброса гранаты','Кнопка выбранного видения'}
    local function keyLabel(code)
        code=type(code)=='number'and code or 0
        if code==0 then return tr('Не назначено')end
        if code>=1001 and code<=1128 then return 'Button '..(code-1000)end
        if code>=2001 and code<=2032 then local n=code-2001;return 'Hat '..(n//8+1)..' '..({'↑','↗','→','↘','↓','↙','←','↖'})[n%8+1]end
        if code>=3001 and code<=3024 then local n=code-3001;return 'CH'..(n//3+1)..' '..({'Low','Center','High'})[n%3+1]end
        local mouse={[1]='Mouse Left',[2]='Mouse Right',[4]='Mouse Middle',[5]='Mouse X1',[6]='Mouse X2'}
        if mouse[code]then return mouse[code]end
        if code>=65 and code<=90 or code>=48 and code<=57 then return string.char(code)end
        if code>=112 and code<=135 then return 'F'..(code-111)end
        return 'VK '..code
    end
    local actionNames={'menu','pilot','reset','collect','flashlight','cameraDown','grenadeDrop','vision'}
    local holdHelps={'Удержание открывает меню до отпускания.','Удержание включает FPV до отпускания.','При удержании дрон остаётся в точке старта.','При удержании сбор повторяется, пока рядом есть артефакты.','Удержание включает фонарик до отпускания.','Удержание включает нижнюю камеру до отпускания.','Удержание сбрасывает гранаты по очереди, пока есть заряды.','Удержание включает выбранное видение до отпускания. Без назначенной кнопки выбранное видение включается автоматически.'}
    local actionModes=s.actionModes or {};local capture=settings.capture or {}
    for i,name in ipairs(bindingNames)do
        local bindingLabel=(settings.bindingLabels or {})[i]
        local code=(settings.bindings or {})[i];if code==nil then code=(s.keys or {})[i]end
        local r=backend(p,name,type(bindingLabel)=='string'and bindingLabel~=''and bindingLabel or keyLabel(code),'capture',{i-1},'Нажмите назначение и затем нужную кнопку. Поддерживаются клавиатура, мышь, кнопки пульта и положения CH.')
        r.kind='binding';r.capturing=capture.row==i-1
        if r.capturing then r.value=tr('Нажмите кнопку...')..string.format(' %.0f s',math.max(0,finite(capture.remainingMs,0))/1000)end
        r.clearValue=tr(r.capturing and 'Отмена'or 'Убрать')
        r.clearCommand=function()return setting(r.capturing and 'cancel'or 'clear',{r.capturing and 0 or i-1})end
        local key=actionNames[i];local value=(settings.modes and settings.modes[i]or actionModes[key])==1 and 1 or 0
        r.modeValue=tr(value==1 and 'Удержание'or 'Переключение')
        r.modeCommand=function()return setting('modes',{i-1,1-value})end
        r.help=r.help..' '..tr(holdHelps[i])
    end
    p=page('Общие','Язык, звук и дополнительные настройки.')
    local language=clamp(finite(settings.language,0),0,4)
    row(p,'Язык',({'Русский','Українська','English','Polski','Deutsch'})[language+1],function(d)return setting('language',{(language+(d or 1))%5})end,'choice','Язык меню.')
    slider(p,'Звук моторов и громкость',settings.volume or 20,0,100,1,function(v)return string.format('%d%%',v)end,
        function(v)return setting('audio',{v})end,'Громкость моторов дрона; 0% выключает звук.')
    local limit=settings.objectLimit or {};local savedLimit=limit.has and limit.value or ''
    local number=row(p,'Лимит объектов игры',savedLimit,function()return nil end,'number','Дополнительная настройка памяти. Изменение вступает в силу после перезапуска игры.')
    number.placeholder=tr('По умолчанию');number.min,number.max=1,2147483647
    number.set=function(v)
        if type(v)=='string'and v:match('^%d+$')then v=tonumber(v)end
        if type(v)~='number'or v%1~=0 or v<1 or v>2147483647 then return nil end
        return setting('limit',{v})
    end
    backend(p,'Восстановить лимит по умолчанию',tr('По умолчанию'),'limitreset',{0},'Удаляет только настройку лимита объектов; требуется перезапуск игры.')
    return pages
end
function M.pages(s,translate)
    local sections=M.sections(s,translate);local tr=translate or function(x)return x end
    local groups={
        {'Полёт','Режим и параметры полёта.',{1}},
        {'Изображение','Камера, эффекты видения и экранные показатели.',{3,4}},
        {'Оснащение','Вооружение, поиск целей и прочность дрона.',{9,7,8}},
        {'Мир и связь','Окружение и радиосигнал.',{5,6}},
        {'Настройки','Язык, пульт и кнопки.',{11,2,10}},
    }
    local result={}
    for _,entry in ipairs(groups)do
        local group={label=tr(entry[1]),description=tr(entry[2]),sections={}}
        for _,index in ipairs(entry[3])do group.sections[#group.sections+1]=sections[index]end
        result[#result+1]=group
    end
    return result
end
M.experimentCommand=experimentCommand
return M
