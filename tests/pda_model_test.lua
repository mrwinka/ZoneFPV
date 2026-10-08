local M=dofile('mod/Scripts/pda_model.lua')
local s={cfg={flight_mode='acro',speed_preset=5,camera_tilt=60},options={alternate=true,noclip=false},
    experiments={style=4,obstacles=true,characters=true,anomaliesScan=true,droneHP=true,reaction=true,anomalyInterference=true,anomalyDamage=true,detector=true},
    radio={enabled=true,range=20000,attenuation=5},vision=15,anomalyStyle=5,impact=5,distance=6,collectRange=10,
    armament={mode=3,power=1.25,grenade=1,charges=0}}
local pages=M.sections(s)
local pageNames={'Основное','Пульт','Камера','OSD','Мир','Связь','Сканер','Прочность','Боевой режим','Кнопки','Общие'}
assert(#pages==#pageNames)
local rows,location={},{}
for i,p in ipairs(pages)do
    assert(p.label==pageNames[i] and p.description~='')
    assert(#p.rows<=16)
    for _,r in ipairs(p.rows)do
        assert(not rows[r.label],'Duplicate setting/action: '..r.label)
        assert(type(r.command)=='function' and type(r.help)=='string' and r.help~='')
        assert(r.kind=='slider' or r.kind=='choice' or r.kind=='toggle' or r.kind=='action' or r.kind=='binding' or r.kind=='status' or r.kind=='number')
        rows[r.label],location[r.label]=r,i
    end
end
local expected={
    ['Основное']={'Режим полёта','Множитель скорости','Альтернативный режим FPV','Свободный полёт сквозь стены','Разрешить запуск с поднятым газом'},
    ['Пульт']={'Устройство контроллера','Профиль контроллера','Состояние подключения','Калибровка осей','Отменить калибровку','Ход калибровки','CH1','CH2','CH3','CH4','CH5','CH6','CH7','CH8'},
    ['Камера']={'Наклон камеры','Режим видения','Стиль аналоговой камеры','Фонарик дрона','Нижняя камера'},
    ['OSD']={'Показывать OSD','Шрифт OSD','Элемент OSD','Показывать элемент','Размер элемента','Цвет элемента','Показывать обычный прицел','Обычный прицел','Показывать нижний прицел','Прицел нижней камеры','Предпросмотр нижней камеры','Сбросить выбранный элемент','Сбросить расположение OSD'},
    ['Мир']={'Сильно замедлить мир в FPV','Погода','Время суток','Дальность загрузки геометрии'},
    ['Связь']={'Симуляция RSSI','Максимальная дальность','Множитель затухания','Вид помех','Препятствия ослабляют сигнал','Помехи рядом с аномалиями','Помехи аномалий'},
    ['Сканер']={'Сканировать NPC и мутантов','Сканировать аномалии','Детектор артефактов','Расстояние для сбора артефакта'},
    ['Прочность']={'Прочность дрона','Реакция NPC и мутантов','Урон от аномалий','Множитель урона от столкновений','Неуязвимость персонажа'},
    ['Боевой режим']={'Тип дрона','Мощность взрыва','Минимальная скорость удара','Тип гранаты','Количество зарядов'},
    ['Кнопки']={'Кнопка меню','Кнопка входа / выхода из FPV','Кнопка возврата к старту','Кнопка сбора артефакта','Кнопка фонарика','Кнопка камеры вниз','Кнопка сброса гранаты','Кнопка выбранного видения'},
    ['Общие']={'Язык','Звук моторов и громкость','Лимит объектов игры','Восстановить лимит по умолчанию'},
}
local count=0
for i,name in ipairs(pageNames)do
    assert(#pages[i].rows==#expected[name])
    for _,label in ipairs(expected[name])do assert(location[label]==i,label..' in wrong section');count=count+1 end
end
assert(count==74,'Complete inline controller/OSD without XY rows and all combined combat settings')
local osdPage=M.sections({})[4]
assert(osdPage.inlineRows==13 and #osdPage.rows==13 and osdPage.rows[5].compactLabel=='Размер'
 and osdPage.rows[6].compactLabel=='Цвет','Compact OSD inspector omits XY sliders and retains all other operations')
assert(osdPage.rows[4].compactLabel=='Отображать'and osdPage.rows[3].kind=='status'and osdPage.rows[3].command(1)==nil
 and #osdPage.osdItems==14,'All indicators belong to a vertical selector, with a read-only selected-item inspector label')
assert(not rows['Положение по горизонтали']and not rows['Положение по вертикали'])
assert(not rows['Диагностика кнопок контроллера'] and not expected['Эксперименты'])
local function row(label)return assert(rows[label],'Missing row '..label)end
local sliders={
    ['Множитель скорости']={0,5,.05},
    ['Наклон камеры']={0,60,1},
    ['Дальность загрузки геометрии']={0,6,1},
    ['Максимальная дальность']={50,20000,50},
    ['Множитель затухания']={0,5,.05},
    ['Множитель урона от столкновений']={0,5,.05},
    ['Расстояние для сбора артефакта']={.5,10,.5},
    ['Мощность взрыва']={.25,5,.25},
    ['Количество зарядов']={1,21,1},
    ['Минимальная скорость удара']={5,150,5},
}
for label,bounds in pairs(sliders)do
    local r=row(label)
    assert(r.kind=='slider' and r.min==bounds[1] and r.max==bounds[2] and r.step==bounds[3],label)
    assert(type(r.number)=='number' and type(r.set)=='function' and type(r.format)=='function')
    assert(r.set(-100)==r.set(r.min) and r.set(99999)==r.set(r.max),label..' bounds')
    assert(type(r.format(r.number))=='string')
end
assert(row('Множитель скорости').command(1)=='FPVSettings 5.00 60')
assert(row('Множитель скорости').set(.124)=='FPVSettings 0.10 60')
assert(row('Множитель скорости').set(.126)=='FPVSettings 0.15 60')
assert(row('Множитель скорости').format(.126)=='0.15 ×')
assert(row('Наклон камеры').command(1)=='FPVSettings 5 60')
assert(row('Наклон камеры').set(12.6)=='FPVSettings 5 13')
assert(row('Дальность загрузки геометрии').command(1)=='FPVDistance 6')
local factors={'1 ×','1.25 ×','1.5 ×','2 ×','3 ×','4 ×','5 ×'}
for i=0,6 do
    assert(row('Дальность загрузки геометрии').format(i)==factors[i+1])
    assert(row('Дальность загрузки геометрии').set(i)=='FPVDistance '..i)
end
assert(row('Дальность загрузки геометрии').set(2.6)=='FPVDistance 3')
assert(row('Альтернативный режим FPV').command(1)=='FPVOption alternate 0')
assert(row('Свободный полёт сквозь стены').command(1)=='FPVOption noclip 1')
assert(row('Неуязвимость персонажа').command(1)=='FPVOption god 1')
assert(row('Режим видения').command(1)=='FPVVision 0')
assert(row('Режим видения').value=='Green Hot')
assert(row('Помехи аномалий').command(1)=='FPVAnomalyStyle 0')
assert(row('Максимальная дальность').command(1)=='FPVSignal 1 20000 5')
assert(row('Максимальная дальность').set(19774)=='FPVSignal 1 19750 5')
assert(row('Максимальная дальность').set(19775)=='FPVSignal 1 19800 5')
assert(row('Множитель затухания').set(2.625)=='FPVSignal 1 20000 2.65')
assert(row('Множитель урона от столкновений').set(.01)=='FPVImpact 0.00')
assert(row('Расстояние для сбора артефакта').set(4.24)=='FPVCollectRange 4.0')
assert(row('Расстояние для сбора артефакта').set(4.25)=='FPVCollectRange 4.5')
assert(row('Расстояние для сбора артефакта').command(1)=='FPVCollectRange 10.0')
assert(row('Фонарик дрона').kind=='toggle' and row('Фонарик дрона').command()=='FPVFlashlight 0')
local litPages=M.sections({features={flashlightEnabled=false,cameraDownEnabled=false},session={flashlightEnabled=true,cameraDown=true}})
assert(litPages[3].rows[4].command()=='FPVFlashlight 1','Saved permission is independent of active light state')
assert(row('Нижняя камера').command()=='FPVCameraDown 0')
assert(litPages[3].rows[5].command()=='FPVCameraDown 1','Disabled downward permission wins over session state')
assert(row('Тип дрона').value=='Сброс + камикадзе'and row('Тип дрона').command(1)=='FPVArmament 0 1.25 1 0 30')
assert(row('Тип дрона').command(-1)=='FPVArmament 2 1.25 1 0 30')
assert(row('Мощность взрыва').set(2.124)=='FPVArmament 3 2 1 0 30')
assert(row('Мощность взрыва').set(2.125)=='FPVArmament 3 2.25 1 0 30')
assert(row('Тип гранаты').value=='F-1'and row('Тип гранаты').command(1)=='FPVArmament 3 1.25 0 0 30')
assert(row('Количество зарядов').value=='Без ограничений'and row('Количество зарядов').set(4.5)=='FPVArmament 3 1.25 1 5 30')
assert(row('Количество зарядов').number==21 and row('Количество зарядов').set(21)=='FPVArmament 3 1.25 1 0 30')
assert(row('Количество зарядов').set(0)=='FPVArmament 3 1.25 1 1 30','Left edge is one real grenade')
for stored=0,20 do
 local data={mode=3,power=2.25,grenade=1,charges=stored,impactSpeed=65}
 local stock=M.sections({armament=data})[9].rows[5]
 local expectedUI=stored==0 and 21 or stored
 assert(stock.min==1 and stock.max==21 and stock.number==expectedUI)
 assert(stock.value==(stored==0 and 'Без ограничений'or tostring(stored)),'Every persisted finite/unlimited stock reopens at the correct UI point')
 for ui=1,21 do
  local command=stock.set(ui)
  assert(command==string.format('FPVArmament 3 2.25 1 %d 65',ui==21 and 0 or ui),'UI stock point serializes using the existing zero sentinel')
 end
 assert(data.charges==stored and data.power==2.25,'Rendering and changing stock commands do not mutate the supplied settings')
end
local rightEdge=M.sections({armament={mode=2,charges=20}})[9].rows[3]
assert(rightEdge.command(1)=='FPVArmament 2 1 0 0 30'and rightEdge.set(20.49)=='FPVArmament 2 1 0 20 30'
 and rightEdge.set(20.5)=='FPVArmament 2 1 0 0 30','Moving right from20 reaches unlimited without changing the file schema')
local unlimitedEdge=M.sections({armament={mode=2,charges=0}})[9].rows[3]
assert(unlimitedEdge.command(-1)=='FPVArmament 2 1 0 20 30'and unlimitedEdge.format(21)=='Без ограничений')
assert(s.armament.power==1.25 and s.armament.charges==0,'Painting and commands must retain armament settings')
local combined=M.sections({armament={mode=3,power=2.25,grenade=1,charges=7,impactSpeed=65}})[9]
assert(combined.label=='Боевой режим'and #combined.rows==5 and combined.rows[1].value=='Сброс + камикадзе')
assert(combined.rows[1].command(1)=='FPVArmament 0 2.25 1 7 65'
 and combined.rows[1].command(-1)=='FPVArmament 2 2.25 1 7 65','Fourth mode cycles both ways without losing payload settings')
assert(M.sections({armament={mode=0}})[9].rows[1].command(-1)=='FPVArmament 3 1 0 3 30')
assert(combined.rows[2].set(3)=='FPVArmament 3 3 1 7 65'
 and combined.rows[3].set(70)=='FPVArmament 3 2.25 1 7 70'
 and combined.rows[4].command(1)=='FPVArmament 3 2.25 0 7 65'
 and combined.rows[5].set(8)=='FPVArmament 3 2.25 1 8 65',
 'Combined mode exposes both kamikaze and grenade settings and preserves untouched siblings')
local combatLabels={
 {'Тип дрона'},
 {'Тип дрона','Мощность взрыва','Минимальная скорость удара'},
 {'Тип дрона','Тип гранаты','Количество зарядов'},
 {'Тип дрона','Мощность взрыва','Минимальная скорость удара','Тип гранаты','Количество зарядов'},
}
for mode=0,3 do
 local data={mode=mode,power=2.25,grenade=1,charges=7,impactSpeed=65}
 local combat=M.sections({armament=data})[9]
 assert(#combat.rows==#combatLabels[mode+1])
 for i,label in ipairs(combatLabels[mode+1])do assert(combat.rows[i].label==label,'Only relevant combat parameter shown')end
 assert(combat.rows[1].command(1)==string.format('FPVArmament %d 2.25 1 7 65',(mode+1)%4),'Switching mode retains hidden saved parameters')
 assert(data.mode==mode and data.power==2.25,'Rendering never mutates saved combat fields')
end
local defaultCount=0;for _,p in ipairs(M.sections({}))do defaultCount=defaultCount+#p.rows end
assert(defaultCount==70)
assert(row('Вид помех').command(1)=='FPVExperiments 0 1 1 1 1 1 1 1 1')
local featureTokens={obstacles=2,characters=3,anomaliesScan=4,droneHP=5,reaction=6,anomalyInterference=7,anomalyDamage=8,detector=9}
local featureLabels={obstacles='Препятствия ослабляют сигнал',characters='Сканировать NPC и мутантов',anomaliesScan='Сканировать аномалии',
    droneHP='Прочность дрона',reaction='Реакция NPC и мутантов',anomalyInterference='Помехи рядом с аномалиями',anomalyDamage='Урон от аномалий',detector='Детектор артефактов'}
for name,index in pairs(featureTokens)do
    local parts={}
    for token in row(featureLabels[name]).command(1):gmatch('%S+')do parts[#parts+1]=token end
    assert(#parts==10 and parts[1]=='FPVExperiments' and parts[2]=='4')
    for i=2,9 do assert(parts[i+1]==(i==index and '0' or '1'),name..' sibling flag changed')end
    assert(s.experiments[name]==true,'Painting/commands must not mutate accepted settings')
end
assert(s.options.alternate==true and s.cfg.speed_preset==5)
for _,label in ipairs({'Войти / выйти из FPV','Вернуть дрон к старту','Выдать все 3 вида биноклей','Собрать ближайший артефакт','Тема'})do assert(not rows[label],label..' removed from menu')end
-- Every former external tool now dispatches a local operation.
local function backend(label,action,arg)
    local kind,payload=row(label).command(1)
    assert(kind=='settings' and payload.action==action and payload.args[1]==arg,label)
end
backend('Устройство контроллера','device',0)
backend('Профиль контроллера','profile',1)
backend('Калибровка осей','calibrate',0)
backend('Отменить калибровку','calibrate',1)
backend('Язык','language',1)
backend('Восстановить лимит по умолчанию','limitreset',0)
local kind,payload=row('Звук моторов и громкость').set(53.6)
assert(kind=='settings' and payload.action=='audio' and payload.args[1]==54)
local limit=row('Лимит объектов игры')
assert(limit.kind=='number'and limit.set('2147483647')=='settings')
for _,bad in ipairs({'0','-1','12.5','2147483648','1e6','NaN',' 12'})do assert(limit.set(bad)==nil,bad)end
local k,n=limit.set('3000000');assert(k=='settings'and n.action=='limit'and n.args[1]==3000000)
for _,p in ipairs(pages)do for _,r in ipairs(p.rows)do assert(r.command(1)~='tool','No external tool jump')end end
local inline=M.sections({settings={device=44,profile=10,connected=true,devices={{id=44,backend=1,name='Pocket'}},
 axes={1,2,3,4,5,6,7,65535},capture={row=6,remainingMs=4000},modes={0,0,0,0,0,0,1,0},
 bindingLabels={'Localized arbitrary key'},calibration={stage=4,axis=2,remainingMs=6000},status='Hold throttle up'}})
assert(inline[2].rows[1].value=='Pocket [DirectInput]' and inline[2].rows[2].value=='DualShock 4')
assert(inline[2].rows[3].value=='Подключено' and inline[2].description=='Hold throttle up')
assert(inline[2].rows[14].value=='65535')
assert(inline[10].rows[1].value=='Localized arbitrary key')
assert(inline[10].rows[7].capturing and inline[10].rows[7].value:find('4 s',1,true))
local ck,cp=inline[10].rows[7].clearCommand();assert(ck=='settings'and cp.action=='cancel'and cp.args[1]==0)
local mk,mp=inline[10].rows[7].modeCommand();assert(mk=='settings'and mp.action=='modes'and mp.args[1]==6 and mp.args[2]==0)
local connected=M.sections({settings={connected=true,calibration={stage=2}}})[2]
assert(connected.rows[4].disabled and not connected.rows[5].disabled)

-- Loading or repainting keeps saved values; changing one slider preserves its sibling.
local saved={cfg={speed_preset=1.234567,camera_tilt=29},radio={enabled=false,range=1537,attenuation=.123456},impact=1.234567,distance=3}
local savedPages=M.sections(saved)
local savedRows={}
for _,p in ipairs(savedPages)do for _,r in ipairs(p.rows)do savedRows[r.label]=r end end
assert(savedRows['Множитель скорости'].number==1.234567 and savedRows['Множитель скорости'].value=='1.23 ×')
assert(savedRows['Множитель урона от столкновений'].number==1.234567)
assert(savedRows['Максимальная дальность'].number==1537)
assert(savedRows['Множитель затухания'].number==.123456)
assert(savedRows['Расстояние для сбора артефакта'].number==3,'Existing settings retain 3 m default')
assert(savedRows['Наклон камеры'].set(30)=='FPVSettings 1.234567 30')
assert(savedRows['Симуляция RSSI'].command(1)=='FPVSignal 1 1537 0.123456')
assert(savedRows['Максимальная дальность'].set(1600)=='FPVSignal 0 1600 0.123456')
assert(savedRows['Множитель затухания'].set(1.5)=='FPVSignal 0 1537 1.5')
assert(saved.cfg.speed_preset==1.234567 and saved.radio.range==1537 and saved.radio.attenuation==.123456)
assert(savedRows['Множитель скорости'].set(0/0)==savedRows['Множитель скорости'].set(1.234567),'Ignore non-finite slider input')
assert(savedRows['Множитель скорости'].set(math.huge)==savedRows['Множитель скорости'].set(1.234567))
local zeroPages=M.sections({cfg={speed_preset=0,camera_tilt=0},radio={range=50,attenuation=0},impact=0,distance=0})
assert(zeroPages[1].rows[2].number==0 and zeroPages[3].rows[1].number==0 and zeroPages[8].rows[4].number==0)
local modePages=M.sections({vision=12})
assert(modePages[3].rows[2].value=='IR LED','Keep every saved numeric vision mode ID')

-- Every row and help text remains usable in the supported five menu languages.
local prefix=os.tmpname()..'-'
local languageFile=prefix..'language.txt'
local text=dofile('mod/Scripts/pda_text.lua').new(prefix)
local function cyrillic(value)return value:find('[\208\209][\128-\191]')end
for language=0,4 do
    local f=assert(io.open(languageFile,'w'));f:write(tostring(language));f:close()
    text.update(language*2)
    local localized=M.sections({armament={mode=3}},text.translate)
    assert(#localized==11)
    if language==1 then assert(localized[6].label=='Зв’язок')end
    if language==2 then assert(localized[6].label=='Signal' and localized[8].label=='Durability')end
    if language>=2 then
        for _,status in ipairs({'Контроллер не подключён. Подключите пульт в режиме USB Joystick.',
          'Ожидаются свежие данные пульта. Повторите после подключения.',
          'Выбранный пульт ещё не готов. Подождите или выберите подключённый.',
          'Выбранный контроллер недоступен. Обновите список устройств.',
          'Не удалось сохранить настройки. Повторите попытку.',
          'КПК потерял фокус. Откройте нужный раздел и повторите.',
          'Запрос устарел. Повторите настройку.'})do assert(not cyrillic(text.translate(status)),'Backend failure is translated')end
        assert(not cyrillic(localized[9].rows[1].value),'Combined mode label needs an explicit translation')
        for _,p in ipairs(localized)do
            assert(not cyrillic(p.label) and not cyrillic(p.description),p.label..' missing translation')
            for _,r in ipairs(p.rows)do
                assert(not cyrillic(r.label),r.label..' missing label translation')
                assert(not cyrillic(r.help),r.help..' missing help translation')
            end
        end
    end
end
assert(row('Минимальная скорость удара').set(32.49)=='FPVArmament 3 1.25 1 0 30')
assert(row('Минимальная скорость удара').set(32.5)=='FPVArmament 3 1.25 1 0 35')
local assigned=M.sections({keys={117,119,120,1,1128,3024,2032,255},actionModes={cameraDown=1,vision=0,flashlight=1}})[10]
local values={'F6','F8','F9','Mouse Left','Button 128','CH8 High','Hat 4 ↖','VK 255'}
for i=1,8 do assert(assigned.rows[i].value==values[i]and assigned.rows[i].command()=='settings')end
local actionNames={'menu','pilot','reset','collect','flashlight','cameraDown','grenadeDrop','vision'}
for i=1,8 do
    local held=i==5 or i==6
    assert(assigned.rows[i].kind=='binding'and assigned.rows[i].modeValue==(held and 'Удержание'or 'Переключение'))
    local k,p=assigned.rows[i].modeCommand();assert(k=='settings'and p.action=='modes'and p.args[1]==i-1 and p.args[2]==(held and 0 or 1))
    local ck,cp=assigned.rows[i].clearCommand();assert(ck=='settings'and cp.action=='clear'and cp.args[1]==i-1)
end
local groups=M.pages(s)
local groupLabels={'Полёт','Изображение','Оснащение','Мир и связь','Настройки'}
local groupSections={{'Основное'},{'Камера','OSD'},{'Боевой режим','Сканер','Прочность'},{'Мир','Связь'},{'Общие','Пульт','Кнопки'}}
assert(#groups==5)
local groupedCount=0
for i,g in ipairs(groups)do
    assert(g.label==groupLabels[i]and #g.sections==#groupSections[i])
    for j,section in ipairs(g.sections)do assert(section.label==groupSections[i][j]);groupedCount=groupedCount+#section.rows end
end
assert(groupedCount==74 and #groups[5].sections[3].rows==8 and #groups[5].sections[2].rows==14,
 'Controller belongs inside Settings, alongside General and all eight button assignments')
for lang=0,4 do
    local f=assert(io.open(languageFile,'w'));f:write(tostring(lang));f:close();text.update(20+lang*2)
    for _,g in ipairs(M.pages({},text.translate))do
        if lang>=2 then assert(not cyrillic(g.label)and not cyrillic(g.description))end
        for _,section in ipairs(g.sections)do
            if lang>=2 then assert(not cyrillic(section.label)and not cyrillic(section.description))end
            for _,r in ipairs(section.rows)do if r.kind=='binding'then assert(r.modeValue~=''and not(lang>=2 and cyrillic(r.modeValue)))end end
        end
    end
    local osd=dofile('mod/Scripts/pda_osd.lua').defaults()
    for id=0,13 do
        osd.selectedItemID=id;osd.fontChoice=id%8;osd.crossStyle=id%6;osd.downCrossStyle=(id+1)%6;osd.items[id+1].color=id%5
        local section=M.sections({osd=osd},text.translate)[4]
        local r=section.rows
        assert(#section.osdItems==14 and section.osdItems[id+1].selected)
        for i,item in ipairs(section.osdItems)do
            assert(item.id==i-1 and item.selected==(i-1==id))
            if lang>=2 then assert(not cyrillic(item.label),'Missing indicator list translation: '..item.label)end
        end
        if lang>=2 then for _,v in ipairs(r)do
            assert(not cyrillic(v.label)and not cyrillic(v.compactLabel)and not cyrillic(v.help)and not cyrillic(v.value),'Missing translation: '..v.label..' / '..v.value..' / '..v.help)
        end end
        local kind,payload=r[5].set(27);assert(kind=='osd'and payload.action=='item'and payload.args.id==id and payload.args.field=='size'and payload.args.value==27)
    end
end
os.remove(languageFile);os.remove(prefix:sub(1,-2))
print('PASS PDA five groups/eleven sections, Equipment restored, 74 maximum rows/70 unarmed, OSD13/no XY rows, charges1..20 then unlimited at right21/stored0, complete inline settings/12 sliders/eight captures and modes, precision and five languages')
