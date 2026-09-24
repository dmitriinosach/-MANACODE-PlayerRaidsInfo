local ADDON, ns = ...

local STEPS = {
    {
        "Что это",
        "Рейды игроков: ЦЛК 25 и РС 25, парсы, последние рейды.\n\nКак обновить данные — кнопка «Как обновить?» внизу окна.",
    },
    {
        "Поиск",
        "Впишите ник или старый ник и нажмите Enter.\n\nПока поле пустое, слева недавно встреченные в игре. «Ренеймы» — кто менял ник.",
    },
    {
        "Карточка",
        "Сверху лучший парс за сезон. Плитки — сложность: череп — героик, «А» — анбаф, число под плиткой — сколько рейдов.\n\nСезон — числа после слова «СЕЗОН», «ВСЕ» — все сезоны подряд. Справа от плиток — сколько боссов убито в роли ДД, хила и танка.",
    },
    {
        "Рейды",
        "В ячейке дпс или хпс и парс, цвет как на сайте. Строкой ниже — парс на гире и илвл: место среди игроков того же спека с таким же уровнем предметов.\n\nРядом с плитками — сколько раз убит каждый босс и когда впервые.",
    },
    {
        "Alt",
        "Зажмите Alt и наведите на ник в чате или на игрока — появится карточка. Alt+клик по нику откроет его здесь.\n\nГде это работает — шестерёнка сверху.",
    },
    {
        "Заметки и гильдии",
        "Заметку видите только вы, обновление данных её не сотрёт.\n\nГильдии и звания копятся сами — по тому, что вы видели в игре.",
    },
}

local guide, step

local function render()
    local s = STEPS[step]
    guide.title:SetText(s[1])
    guide.body:SetText(s[2])
    guide.count:SetText(step .. " / " .. #STEPS)
    ns.SetButton(guide.back, false, step <= 1)
    guide.next.text:SetText(step < #STEPS and "Далее" or "Готово")
end

local function button(text, onClick)
    local b = ns.MakeButton(guide, 13, 90, 22)
    b.text:SetText(text)
    b.onClick = onClick
    return b
end

local function build(parent)
    if guide then return guide end
    guide = CreateFrame("Frame", nil, parent)
    guide:SetWidth(400)
    guide:SetHeight(210)
    guide:SetPoint("CENTER", parent, "CENTER", 0, 0)
    guide:SetFrameLevel(parent:GetFrameLevel() + 30)
    guide:EnableMouse(true)
    ns.StyleTip(guide)
    guide:SetBackdropColor(0.05, 0.045, 0.035, 0.98)
    guide:SetBackdropBorderColor(1, 0.82, 0, 1)
    guide:Hide()

    guide.title = ns.Text(guide, 16, "LEFT", "head")
    guide.title:SetPoint("TOPLEFT", 16, -14)
    guide.count = ns.Text(guide, 12, "RIGHT")
    guide.count:SetTextColor(0.42, 0.44, 0.46)
    guide.count:SetPoint("TOPRIGHT", -16, -16)
    guide.body = ns.Text(guide, 14)
    guide.body:SetWidth(368)
    guide.body:SetJustifyV("TOP")
    guide.body:SetPoint("TOPLEFT", 16, -44)

    guide.back = button("Назад", function()
        if step > 1 then step = step - 1; render() end
    end)
    guide.back:SetPoint("BOTTOMLEFT", 14, 12)
    guide.close = button("Закрыть", function() guide:Hide() end)
    guide.close:SetPoint("BOTTOM", 0, 12)
    guide.next = button("Далее", function()
        if step < #STEPS then
            step = step + 1
            render()
        else
            guide:Hide()
        end
    end)
    guide.next:SetPoint("BOTTOMRIGHT", -14, 12)
    return guide
end

function ns.ShowGuide(parent)
    build(parent)
    step = 1
    render()
    guide:Show()
end

function ns.ToggleGuide(parent)
    build(parent)
    if guide:IsShown() then guide:Hide() else ns.ShowGuide(parent) end
end
