local ADDON, ns = ...

local GR, GG, GB = 1, 0.82, 0
local VEIL_A = 0.66
local PAD = 5
local GAP = 6
local ARROW = 16
local EDGE = 8
local CARD_W = 318
local REFRESH = 0.25
local GLOW = 12
local ARROW_TEX = "Interface\\Buttons\\Arrow-Up-Up"
local RING_TEX = "Interface\\Tooltips\\UI-Tooltip-Border"

local STEPS = {
    {
        find = "left",
        title = "Поиск и список",
        text = "Впишите ник или старый ник в поле «Ник» и нажмите Enter.\n\n«Все» — кого вы недавно встречали в игре, «Ренеймы» — кто менял ник. Щелчок по строке открывает игрока справа.",
    },
    {
        find = "head", need = true,
        title = "Игрок",
        text = "Ник, звание и гильдия. Значок рядом с ником копирует его, «ГН» — Герой Нордскола. Наведите на ник или гильдию — появится история.\n\nЗаметку видите только вы, обновление данных её не сотрёт.",
    },
    {
        find = "seasons", need = true,
        title = "Сезоны",
        text = "«ВСЕ» — все сезоны подряд, число — один сезон. Серый сезон пуст или не скачан: наведите, чтобы узнать почему.",
    },
    {
        find = "best", need = true,
        title = "Лучший парс",
        text = "Лучший парс сезона за ДД, хила и танка. Наведите на плитку — босс, сложность и дата.\n\n«На своём гире» — парс среди игроков того же спека с таким же уровнем предметов.",
    },
    {
        find = "modes", need = true,
        title = "Сложность",
        text = "Череп — героик, «А» — анбаф. Под плиткой — сколько рейдов, щелчок показывает рейды этой сложности.\n\n«Убито боссов» — сколько раз убит каждый босс и сколько килов за ДД, хила и танка.",
    },
    {
        find = "table", need = true,
        title = "Рейды",
        text = "В ячейке — дпс или хпс, парс и парс на гире. Наведите на ячейку — подробности.\n\nЩелчок по заголовку столбца сортирует таблицу. «по дате» и «по лучшему парсу» — справа в строке сезонов.",
    },
    {
        title = "Карточка по Alt",
        text = "Зажмите Alt и наведите на ник в чате или на игрока — появится карточка с его рейдами. Alt+клик по нику откроет игрока здесь.\n\nГде это работает — шестерёнка «Настройки» сверху.",
    },
    {
        find = "bottom",
        title = "Обновление данных",
        text = "Внизу — дата выгрузки и сколько в ней игроков. «Как обновить?» — как скачать свежие данные, «/reload» — перечитать их после обновления.",
    },
}

local host, ov, card, ring, arrow
local bands, dots = {}, {}
local step, since, dirty, picked, escOff = 1, 0, false, nil, nil
local acc, hole = {}, {}
local kidsN, kidsList = -1, {}
local labels = {}
local go

local function clamp(v, lo, hi)
    if hi < lo then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function kids()
    local n = host:GetNumChildren()
    if n ~= kidsN then
        kidsN = n
        kidsList = { host:GetChildren() }
    end
    return kidsList
end

local function label(text)
    local fs = labels[text]
    if fs and fs:GetText() == text then return fs end
    labels[text] = nil
    for _, r in ipairs({ host:GetRegions() }) do
        if r:GetObjectType() == "FontString" and r:GetText() == text then
            labels[text] = r
            return r
        end
    end
end

local function add(obj)
    if not obj or not obj.IsVisible or not obj:IsVisible() then return end
    local l, r, t, b = obj:GetLeft(), obj:GetRight(), obj:GetTop(), obj:GetBottom()
    if not (l and r and t and b) then return end
    local sc = ov:GetEffectiveScale()
    local k = (obj.GetEffectiveScale and obj:GetEffectiveScale() or sc) / sc
    local ox, oy = ov:GetLeft(), ov:GetTop()
    l, r = l * k - ox, r * k - ox
    t, b = oy - t * k, oy - b * k
    if acc.l then
        acc.l, acc.r = math.min(acc.l, l), math.max(acc.r, r)
        acc.t, acc.b = math.min(acc.t, t), math.max(acc.b, b)
    else
        acc.l, acc.r, acc.t, acc.b = l, r, t, b
    end
end

local function each(field, fn)
    for _, c in ipairs(kids()) do
        if c[field] ~= nil then fn(c) end
    end
end

local function textOf(c)
    local fs = c.text
    if type(fs) ~= "table" or not fs.GetText then return nil end
    return fs:GetText()
end

local FIND = {}

FIND.left = function()
    add(_G.PlayerRaidsSearch)
    add(_G.PlayerRaidsList)
    add(_G.PlayerRaidsListScrollBar)
    each("list", add)
end

FIND.head = function()
    local note = _G.PlayerRaidsNote
    if not note or not note:IsVisible() then return end
    add(note)
    add(label("Заметка:"))
    if not acc.l then return end
    acc.l = acc.l - 4
    acc.r = ov:GetWidth() - 10
    acc.t = 42
end

FIND.seasons = function()
    each("season", add)
    each("textX", add)
    if acc.l then add(label("СЕЗОН")) end
end

FIND.best = function()
    each("big", add)
end

FIND.modes = function()
    each("caption", function(c)
        if c:IsVisible() then
            add(c)
            add(c.caption)
        end
    end)
    if not acc.l then return end
    each("boss", add)
    each("lines", add)
end

FIND.table = function()
    local rs = _G.PlayerRaidsRaids
    if not rs or not rs:IsVisible() then return end
    add(rs)
    add(_G.PlayerRaidsRaidsScrollBar)
    each("key", function(c)
        if c.text == nil then add(c) end
    end)
end

FIND.bottom = function()
    each("text", function(c)
        local s = textOf(c)
        if s == "Как обновить?" or s == "/reload" then add(c) end
    end)
    if not acc.l then return end
    acc.l = 8
    acc.r = ov:GetWidth() - 8
end

local function resolve(key)
    acc.l, acc.r, acc.t, acc.b = nil, nil, nil, nil
    local fn = key and FIND[key]
    if not fn then return nil end
    fn()
    if not acc.l or acc.r - acc.l < 2 or acc.b - acc.t < 2 then return nil end
    local W, H = ov:GetWidth(), ov:GetHeight()
    hole.l = math.max(math.floor(acc.l - PAD), 0)
    hole.t = math.max(math.floor(acc.t - PAD), 0)
    hole.r = math.min(math.ceil(acc.r + PAD), W)
    hole.b = math.min(math.ceil(acc.b + PAD), H)
    if hole.r - hole.l < 2 or hole.b - hole.t < 2 then return nil end
    return hole
end

local function pickPlayer()
    if picked then return end
    picked = true
    for _, c in ipairs(kids()) do
        if c.caption and c:IsVisible() then return end
    end
    local own = ns.IdFromGuid and ns.IdFromGuid(UnitGUID("player"))
    local row
    for _, c in ipairs(kids()) do
        if c.id and c.sel and c:IsVisible() and ns.Get(c.id) then
            if c.id == own then
                row = c
                break
            end
            row = row or c
        end
    end
    local click = row and row:GetScript("OnClick")
    if click then click(row, "LeftButton") end
end

local function band(i, x, y, w, h)
    local b = bands[i]
    if w < 1 or h < 1 then
        b:Hide()
        return
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", ov, "TOPLEFT", x, -y)
    b:SetWidth(w)
    b:SetHeight(h)
    b:Show()
end

local function pointArrow(side, ax, ay)
    arrow:ClearAllPoints()
    if side == "below" then
        arrow:SetTexCoord(0, 1, 0, 1)
        arrow:SetPoint("BOTTOM", card, "TOPLEFT", ax, -3)
    elseif side == "above" then
        arrow:SetTexCoord(0, 1, 1, 0)
        arrow:SetPoint("TOP", card, "BOTTOMLEFT", ax, 3)
    elseif side == "right" then
        arrow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        arrow:SetPoint("RIGHT", card, "TOPLEFT", 3, -ay)
    else
        arrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
        arrow:SetPoint("LEFT", card, "TOPRIGHT", -3, -ay)
    end
    arrow:Show()
end

local SIDES_WIDE = { "below", "above", "right", "left" }
local SIDES_TALL = { "right", "left", "below", "above" }

local function placeCard(h, ch)
    card:ClearAllPoints()
    if not h then
        card:SetPoint("CENTER", ov, "CENTER", 0, 0)
        arrow:Hide()
        return
    end
    local W, H = ov:GetWidth(), ov:GetHeight()
    local cw = CARD_W
    local cx, cy = (h.l + h.r) / 2, (h.t + h.b) / 2
    local off = GAP + ARROW
    local sides = (h.b - h.t > h.r - h.l) and SIDES_TALL or SIDES_WIDE
    for _, side in ipairs(sides) do
        local x, y
        if side == "below" and H - h.b - off - EDGE >= ch then
            x, y = clamp(cx - cw / 2, EDGE, W - cw - EDGE), h.b + off
        elseif side == "above" and h.t - off - EDGE >= ch then
            x, y = clamp(cx - cw / 2, EDGE, W - cw - EDGE), h.t - off - ch
        elseif side == "right" and W - h.r - off - EDGE >= cw then
            x, y = h.r + off, clamp(cy - ch / 2, EDGE, H - ch - EDGE)
        elseif side == "left" and h.l - off - EDGE >= cw then
            x, y = h.l - off - cw, clamp(cy - ch / 2, EDGE, H - ch - EDGE)
        end
        if x then
            x, y = math.floor(x), math.floor(y)
            card:SetPoint("TOPLEFT", ov, "TOPLEFT", x, -y)
            pointArrow(side, clamp(cx - x, 20, cw - 20), clamp(cy - y, 20, ch - 20))
            return
        end
    end
    card:SetPoint("CENTER", ov, "CENTER", 0, 0)
    arrow:Hide()
end

local function layout()
    since, dirty = 0, false
    if not ov:GetLeft() then return end
    local s = STEPS[step]
    local h = resolve(s.find)
    if not h and s.need then
        pickPlayer()
        h = resolve(s.find)
    end

    local bh = card.body:GetStringHeight() or 14
    local ch = math.floor(46 + bh + 16 + 22 + 12 + 0.5)
    card:SetHeight(ch)

    local W, H = ov:GetWidth(), ov:GetHeight()
    if h then
        band(1, 0, 0, W, h.t)
        band(2, 0, h.b, W, H - h.b)
        band(3, 0, h.t, h.l, h.b - h.t)
        band(4, h.r, h.t, W - h.r, h.b - h.t)
        ring:ClearAllPoints()
        ring:SetPoint("TOPLEFT", ov, "TOPLEFT", h.l - 4, -(h.t - 4))
        ring:SetWidth(h.r - h.l + 8)
        ring:SetHeight(h.b - h.t + 8)
        ring:Show()
    else
        band(1, 0, 0, W, H)
        for i = 2, 4 do bands[i]:Hide() end
        ring:Hide()
    end
    placeCard(h, ch)
    card:Show()
end

local function paintDots()
    for i, d in ipairs(dots) do
        local sz = (i == step) and 8 or 6
        d.dot:SetWidth(sz)
        d.dot:SetHeight(sz)
        if i == step then
            d.dot:SetVertexColor(GR, GG, GB, 1)
        elseif i < step then
            d.dot:SetVertexColor(GR, GG, GB, 0.45)
        else
            d.dot:SetVertexColor(0.55, 0.55, 0.58, 0.6)
        end
    end
end

local function render()
    local s = STEPS[step]
    card.title:SetText(s.title)
    card.body:SetText(s.text)
    card.count:SetText(step .. " / " .. #STEPS)
    ns.SetButton(card.back, false, step <= 1)
    card.next.text:SetText(step < #STEPS and "Далее" or "Готово")
    ns.SetButton(card.next, true)
    paintDots()
end

local function finish()
    if ov and ov:IsShown() then ov:Hide() end
end

go = function(n)
    if n < 1 then return end
    if n > #STEPS then
        finish()
        return
    end
    step = n
    render()
    layout()
end

local function escape(on)
    local list = UISpecialFrames
    if not list then return end
    if on then
        if escOff then
            table.insert(list, "PlayerRaidsBrowser")
            escOff = nil
        end
        return
    end
    for i = #list, 1, -1 do
        if list[i] == "PlayerRaidsBrowser" then
            table.remove(list, i)
            escOff = true
        end
    end
end

local function veilClick(self, button)
    if button == "RightButton" then go(step - 1) else go(step + 1) end
end

local function buildRing()
    ring = CreateFrame("Frame", nil, ov)
    ring:SetFrameLevel(ov:GetFrameLevel() + 3)
    ring:SetBackdrop({ edgeFile = RING_TEX, edgeSize = 14 })
    ring:SetBackdropBorderColor(GR, GG, GB, 1)
    local sides = {
        { "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", "VERTICAL", 0.4, 0 },
        { "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", "VERTICAL", 0, 0.4 },
        { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "HORIZONTAL", 0, 0.4 },
        { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "HORIZONTAL", 0.4, 0 },
    }
    for i, s in ipairs(sides) do
        local t = ring:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(ns.WHITE)
        t:SetBlendMode("ADD")
        t:SetPoint(s[1], ring, s[2], 0, 0)
        t:SetPoint(s[3], ring, s[4], 0, 0)
        if i <= 2 then t:SetHeight(GLOW) else t:SetWidth(GLOW) end
        t:SetGradientAlpha(s[5], GR, GG, GB, s[6], GR, GG, GB, s[7])
    end
    local ag = ring:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha")
    a:SetChange(-0.6)
    a:SetDuration(0.75)
    a:SetSmoothing("IN_OUT")
    ag:SetLooping("BOUNCE")
    ring:SetScript("OnShow", function() ag:Play() end)
    ring:SetScript("OnHide", function() ag:Stop() end)
    ring:Hide()
end

local function buildCard()
    card = CreateFrame("Frame", nil, ov)
    card:SetFrameLevel(ov:GetFrameLevel() + 6)
    card:SetWidth(CARD_W)
    card:SetHeight(160)
    card:EnableMouse(true)
    card:SetBackdrop(ns.TIP_BACKDROP)
    card:SetBackdropColor(0.05, 0.045, 0.035, 0.97)
    card:SetBackdropBorderColor(GR, GG, GB, 0.95)

    local stripe = ns.Rect(card, GR, GG, GB, 0.85, "ARTWORK")
    stripe:SetHeight(2)
    stripe:SetPoint("TOPLEFT", 5, -5)
    stripe:SetPoint("TOPRIGHT", -5, -5)

    card.title = ns.Text(card, 15, "LEFT", "head")
    card.title:SetPoint("TOPLEFT", 16, -15)
    card.count = ns.Text(card, 12, "RIGHT")
    card.count:SetTextColor(0.55, 0.56, 0.58)
    card.count:SetPoint("TOPRIGHT", -34, -18)

    local close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
    close:SetWidth(26)
    close:SetHeight(26)
    close:SetPoint("TOPRIGHT", 0, -3)
    close:SetScript("OnClick", finish)

    local sep = ns.Rect(card, GR, GG, GB, 0.2, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 14, -38)
    sep:SetPoint("TOPRIGHT", -14, -38)

    card.body = ns.Text(card, 13)
    card.body:SetWidth(CARD_W - 32)
    card.body:SetJustifyV("TOP")
    card.body:SetPoint("TOPLEFT", 16, -46)

    card.next = ns.MakeButton(card, 13, 80, 22)
    card.next:SetPoint("BOTTOMRIGHT", -14, 12)
    card.next.onClick = function() go(step + 1) end
    card.back = ns.MakeButton(card, 13, 70, 22)
    card.back.text:SetText("Назад")
    card.back:SetPoint("RIGHT", card.next, "LEFT", -6, 0)
    card.back.onClick = function() go(step - 1) end

    for i = 1, #STEPS do
        local d = CreateFrame("Button", nil, card)
        d:SetWidth(12)
        d:SetHeight(12)
        d:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14 + (i - 1) * 14, 17)
        d.dot = ns.Rect(d, 1, 1, 1, 1, "ARTWORK")
        d.dot:SetPoint("CENTER", d, "CENTER", 0, 0)
        d:SetScript("OnClick", function() go(i) end)
        d:SetScript("OnEnter", function(self) ns.Tip(self, "ANCHOR_TOP", STEPS[i].title) end)
        d:SetScript("OnLeave", function() GameTooltip:Hide() end)
        dots[i] = d
    end

    arrow = card:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(ARROW_TEX)
    arrow:SetWidth(ARROW)
    arrow:SetHeight(ARROW)
    arrow:Hide()
    card:Hide()
end

local function build(parent)
    if ov then return end
    host = parent
    ov = CreateFrame("Frame", "PlayerRaidsGuide", host)
    ov:SetFrameStrata("FULLSCREEN_DIALOG")
    ov:SetAllPoints(host)
    ov:Hide()
    tinsert(UISpecialFrames, "PlayerRaidsGuide")

    for i = 1, 4 do
        local b = CreateFrame("Button", nil, ov)
        b:SetFrameLevel(ov:GetFrameLevel() + 1)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", veilClick)
        local t = ns.Rect(b, 0, 0, 0, VEIL_A, "BACKGROUND")
        t:SetAllPoints(b)
        b:Hide()
        bands[i] = b
    end

    buildRing()
    buildCard()

    ov:SetScript("OnUpdate", function(self, e)
        since = since + e
        if dirty or since >= REFRESH then layout() end
    end)
    ov:SetScript("OnShow", function() escape(false) end)
    ov:SetScript("OnHide", function(self)
        escape(true)
        if self:IsShown() then self:Hide() end
    end)
end

function ns.ShowGuide(parent)
    build(parent)
    step, picked = 1, nil
    render()
    card:Hide()
    ring:Hide()
    for _, b in ipairs(bands) do b:Hide() end
    dirty = true
    ov:Show()
end

function ns.ToggleGuide(parent)
    if ov and ov:IsShown() then finish() else ns.ShowGuide(parent) end
end
