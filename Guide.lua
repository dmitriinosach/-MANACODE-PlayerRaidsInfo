local ADDON, ns = ...

local GR, GG, GB = 1, 0.82, 0
local DIM_A = 0.72
local PAD = 5
local RING_PAD = 4
local CARD_W = 310
local REFRESH = 0.25
local HEAD_ROWS = 36
local GAP = 10
local MARGIN = 8
local GLOW = 12
local GLOW_A = 0.6
local GLOW_SLICES = 3
local SIDES = { "below", "above", "right", "left" }

local RING_BACKDROP = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
}

local STEPS = {
    {
        find = "left",
        side = "right",
        title = "Поиск и список",
        text = "Впишите ник или старый ник в поле «Ник» и нажмите Enter.\n\n«Все» — кого вы недавно встречали в игре, «Ренеймы» — кто менял ник. Щелчок по строке открывает игрока справа.",
    },
    {
        find = "head",
        side = "below",
        title = "Игрок",
        text = "Ник, звание и гильдия. Значок рядом с ником копирует его, «ГН» — Герой Нордскола. Наведите на ник или гильдию — появится история.\n\nЗаметку видите только вы, обновление данных её не сотрёт.",
    },
    {
        find = "seasons",
        side = "below",
        title = "Сезоны",
        text = "«ВСЕ» — все сезоны подряд, число — один сезон. Серый сезон пуст или не скачан: наведите, чтобы узнать почему.",
    },
    {
        find = "best",
        side = "below",
        title = "Лучший парс",
        text = "Лучший парс сезона за ДД, хила и танка. Наведите на плитку — босс, сложность и дата.\n\n«Средний» — средний дпс и хпс по выбранной сложности.\n\n«На своём гире» — парс среди игроков того же спека с таким же уровнем предметов.",
    },
    {
        find = "modes",
        side = "below",
        title = "Сложность",
        text = "Череп — героик, «А» — анбаф. Под плиткой — сколько рейдов, щелчок показывает рейды этой сложности.\n\n«Убито боссов» — сколько раз убит каждый босс и сколько килов за ДД, хила и танка.",
    },
    {
        find = "table",
        side = "above",
        title = "Рейды",
        text = "В ячейке — дпс или хпс, парс и парс на гире. Наведите на ячейку — подробности.\n\nЩелчок по заголовку столбца сортирует таблицу.",
    },
    {
        title = "Карточка по Alt",
        text = "Зажмите Alt и наведите на ник в чате или на игрока — появится карточка с его рейдами. Alt+клик по нику откроет игрока здесь.\n\nГде это работает — шестерёнка «Настройки» сверху.",
    },
    {
        find = "bottom",
        side = "above",
        align = "center",
        title = "Обновление данных",
        text = "Внизу — дата выгрузки и сколько в ней игроков. «Как обновить?» — как скачать свежие данные, «/reload» — перечитать их после обновления.",
    },
}

local host, ov, card, ring, glow, pulse
local bands = {}
local strips = {}
local corners = {}
local ui = {}
local step, since, dirty, escOff = 1, 0, false, nil
local acc, hole = {}, {}
local go

local function add(obj)
    if type(obj) ~= "table" or not obj.IsVisible or not obj:IsVisible() then return end
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

local function addAll(v)
    if type(v) ~= "table" then return end
    if v.IsVisible then
        add(v)
        return
    end
    for _, o in ipairs(v) do add(o) end
end

local function target(key)
    local gt = ns.GuideTargets
    return gt and gt[key]
end

local function scrollBar(sf)
    local name = type(sf) == "table" and sf.GetName and sf:GetName()
    return name and _G[name .. "ScrollBar"]
end

local FIND = {}

FIND.left = function()
    addAll(target("search"))
    addAll(target("listTabs"))
    addAll(target("list"))
    add(scrollBar(target("list")))
end

FIND.head = function()
    addAll(target("header"))
    addAll(target("note"))
end

FIND.seasons = function()
    addAll(target("seasons"))
    addAll(target("sort"))
end

FIND.best = function()
    addAll(target("bestTiles"))
end

FIND.modes = function()
    local tiles = target("diffTiles")
    if type(tiles) == "table" then
        for _, t in ipairs(tiles) do
            add(t)
            if type(t) == "table" and t.IsVisible and t:IsVisible() then add(t.caption) end
        end
    end
    addAll(target("kills"))
end

FIND.table = function()
    local rs = target("raids")
    if type(rs) ~= "table" or not rs.IsVisible or not rs:IsVisible() then return end
    add(rs)
    add(scrollBar(rs))
    if acc.l then acc.t = acc.t - HEAD_ROWS end
end

FIND.bottom = function()
    addAll(target("update"))
    addAll(target("reload"))
    if not acc.l then return end
    acc.l = 8
    acc.r = ov:GetWidth() - 8
end

local function resolve(key)
    acc.l, acc.r, acc.t, acc.b = nil, nil, nil, nil
    local fn = key and FIND[key]
    if not fn or not ov:GetLeft() then return nil end
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

local function band(i, x, y, w, hh)
    local b = bands[i]
    if w < 1 or hh < 1 then
        b:Hide()
        return
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", ov, "TOPLEFT", x, -y)
    b:SetWidth(w)
    b:SetHeight(hh)
    b:Show()
end

local function maskAround(h)
    local ow, oh = ov:GetWidth(), ov:GetHeight()
    band(1, 0, 0, ow, h.t)
    band(2, 0, h.b, ow, oh - h.b)
    band(3, 0, h.t, h.l, h.b - h.t)
    band(4, h.r, h.t, ow - h.r, h.b - h.t)
end

local function putGlow(t, x, y, w, hh, ow, oh)
    local x2, y2 = x + w, y + hh
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x2 > ow then x2 = ow end
    if y2 > oh then y2 = oh end
    if x2 - x < 1 or y2 - y < 1 then
        t:Hide()
        return
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", glow, "TOPLEFT", x, -y)
    t:SetWidth(x2 - x)
    t:SetHeight(y2 - y)
    t:Show()
end

local function fade(t, orient, aNear, aFar, nearIsStart)
    if nearIsStart then
        t:SetGradientAlpha(orient, GR, GG, GB, aNear, GR, GG, GB, aFar)
    else
        t:SetGradientAlpha(orient, GR, GG, GB, aFar, GR, GG, GB, aNear)
    end
end

local function glowAround(h)
    local ow, oh = ov:GetWidth(), ov:GetHeight()
    local w, hh = h.r - h.l, h.b - h.t
    putGlow(strips[1], h.l, h.t - GLOW, w, GLOW, ow, oh)
    fade(strips[1], "VERTICAL", GLOW_A, 0, true)
    putGlow(strips[2], h.l, h.b, w, GLOW, ow, oh)
    fade(strips[2], "VERTICAL", GLOW_A, 0, false)
    putGlow(strips[3], h.l - GLOW, h.t, GLOW, hh, ow, oh)
    fade(strips[3], "HORIZONTAL", GLOW_A, 0, false)
    putGlow(strips[4], h.r, h.t, GLOW, hh, ow, oh)
    fade(strips[4], "HORIZONTAL", GLOW_A, 0, true)

    local s = GLOW / GLOW_SLICES
    for i = 1, GLOW_SLICES do
        local a = GLOW_A * (1 - (i - 0.5) / GLOW_SLICES)
        local c = corners[i]
        putGlow(c[1], h.l - i * s, h.t - GLOW, s, GLOW, ow, oh)
        fade(c[1], "VERTICAL", a, 0, true)
        putGlow(c[2], h.r + (i - 1) * s, h.t - GLOW, s, GLOW, ow, oh)
        fade(c[2], "VERTICAL", a, 0, true)
        putGlow(c[3], h.l - i * s, h.b, s, GLOW, ow, oh)
        fade(c[3], "VERTICAL", a, 0, false)
        putGlow(c[4], h.r + (i - 1) * s, h.b, s, GLOW, ow, oh)
        fade(c[4], "VERTICAL", a, 0, false)
    end
    glow:Show()
end

local function overlap(x, y, w, hh, h)
    local dx = math.min(x + w, h.r) - math.max(x, h.l)
    local dy = math.min(y + hh, h.b) - math.max(y, h.t)
    if dx <= 0 or dy <= 0 then return 0 end
    return dx * dy
end

local function clamp(v, lo, hi)
    if v > hi then v = hi end
    if v < lo then v = lo end
    return v
end

local function spot(side, align, h, w, hh, ow, oh)
    local x, y
    if side == "below" then
        y = h.b + GAP
    elseif side == "above" then
        y = h.t - GAP - hh
    elseif side == "right" then
        x = h.r + GAP
    else
        x = h.l - GAP - w
    end
    if x == nil then
        if align == "center" then
            x = (h.l + h.r) / 2 - w / 2
        elseif align == "end" then
            x = h.r - w
        else
            x = h.l
        end
    else
        if align == "center" then
            y = (h.t + h.b) / 2 - hh / 2
        elseif align == "end" then
            y = h.b - hh
        else
            y = h.t
        end
    end
    x = clamp(x, MARGIN, ow - MARGIN - w)
    y = clamp(y, MARGIN, oh - MARGIN - hh)
    return math.floor(x), math.floor(y)
end

local function placeCard(h, side, align, w, hh, ow, oh)
    local x, y = spot(side, align, h, w, hh, ow, oh)
    local best = overlap(x, y, w, hh, h)
    if best == 0 then return x, y end
    local bx, by = x, y
    for _, s in ipairs(SIDES) do
        if s ~= side then
            x, y = spot(s, align, h, w, hh, ow, oh)
            local o = overlap(x, y, w, hh, h)
            if o == 0 then return x, y end
            if o < best then best, bx, by = o, x, y end
        end
    end
    return bx, by
end

local function layout()
    since, dirty = 0, false
    if not ov:GetLeft() then return end

    local ow, oh = ov:GetWidth(), ov:GetHeight()
    local cardW = CARD_W
    if cardW > ow - 24 then cardW = ow - 24 end
    card:SetWidth(cardW)
    ui.body:SetWidth(cardW - 24)

    local s = STEPS[step]
    local h = resolve(s.find)

    local bodyH = ui.body:GetStringHeight()
    if bodyH < 12 then bodyH = 12 end
    local cardH = 11 + 16 + 6 + bodyH + 10 + 16 + 11
    card:SetHeight(cardH)

    card:ClearAllPoints()
    if h then
        ui.dim:Hide()
        maskAround(h)
        glowAround(h)
        ring:ClearAllPoints()
        ring:SetPoint("TOPLEFT", ov, "TOPLEFT", h.l - RING_PAD, -(h.t - RING_PAD))
        ring:SetPoint("BOTTOMRIGHT", ov, "TOPLEFT", h.r + RING_PAD, -(h.b + RING_PAD))
        ring:Show()
        local x, y = placeCard(h, s.side or "below", s.align, cardW, cardH, ow, oh)
        card:SetPoint("TOPLEFT", ov, "TOPLEFT", x, -y)
    else
        for _, b in ipairs(bands) do b:Hide() end
        glow:Hide()
        ring:Hide()
        ui.dim:Show()
        card:SetPoint("CENTER", ov, "CENTER", 0, 0)
    end
    card:Show()
end

local function render()
    local s = STEPS[step]
    ui.count:SetText(step .. " / " .. #STEPS)
    ui.title:SetText(s.title)
    ui.body:SetText(s.text)

    local GREY = { 0.55, 0.55, 0.55 }
    local function place(btn, base)
        btn.base = base
        btn.fs:SetTextColor(base[1], base[2], base[3])
        btn:SetWidth(btn.fs:GetStringWidth() + 6)
    end

    ui.skip:ClearAllPoints(); ui.skip:SetPoint("BOTTOMLEFT", 12, 11)
    place(ui.skip, GREY)

    ui.next.fs:SetText(step < #STEPS and "Далее" or "Готово")
    ui.next:ClearAllPoints(); ui.next:SetPoint("BOTTOMRIGHT", -12, 11)
    place(ui.next, { GR, GG, GB })

    ui.back:ClearAllPoints(); ui.back:SetPoint("BOTTOMRIGHT", ui.next, "BOTTOMLEFT", -14, 0)
    place(ui.back, GREY)
    if step > 1 then ui.back:Show() else ui.back:Hide() end
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

local function textBtn(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(16)
    local fs = ns.Text(b, 13, "CENTER")
    fs:SetAllPoints(b)
    b.fs = fs
    b:SetScript("OnEnter", function(self) self.fs:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self)
        local c = self.base or { 0.6, 0.6, 0.6 }
        self.fs:SetTextColor(c[1], c[2], c[3])
    end)
    b:SetScript("OnClick", function() onClick() end)
    return b
end

local function ensureFrames(parent)
    if ov then return end
    host = parent
    if not host then return end

    ov = CreateFrame("Frame", "PlayerRaidsGuide", host)
    ov:SetAllPoints(host)
    ov:SetFrameStrata("FULLSCREEN_DIALOG")
    ov:EnableMouse(true)
    ov:Hide()
    tinsert(UISpecialFrames, "PlayerRaidsGuide")

    ui.dim = ov:CreateTexture(nil, "BACKGROUND")
    ui.dim:SetTexture(0, 0, 0, DIM_A)
    ui.dim:SetAllPoints(ov)

    local base = ov:GetFrameLevel()
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, ov)
        b:SetFrameLevel(base + 1)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", veilClick)
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(0, 0, 0, DIM_A)
        t:SetAllPoints(b)
        b:Hide()
        bands[i] = b
    end

    glow = CreateFrame("Frame", nil, ov)
    glow:SetAllPoints(ov)
    glow:SetFrameLevel(base + 2)
    glow:Hide()
    for i = 1, 4 do
        local t = glow:CreateTexture(nil, "ARTWORK")
        t:SetTexture(ns.WHITE)
        t:Hide()
        strips[i] = t
    end
    for i = 1, GLOW_SLICES do
        local c = {}
        for j = 1, 4 do
            local t = glow:CreateTexture(nil, "ARTWORK")
            t:SetTexture(ns.WHITE)
            t:Hide()
            c[j] = t
        end
        corners[i] = c
    end
    pulse = glow:CreateAnimationGroup()
    local fadeAnim = pulse:CreateAnimation("Alpha")
    fadeAnim:SetChange(-0.45)
    fadeAnim:SetDuration(0.9)
    pulse:SetLooping("BOUNCE")

    ring = CreateFrame("Frame", nil, ov)
    ring:SetFrameLevel(base + 3)
    ring:SetBackdrop(RING_BACKDROP)
    ring:SetBackdropBorderColor(GR, GG, GB, 1)
    ring:Hide()

    card = CreateFrame("Frame", "PlayerRaidsGuideCard", ov)
    card:SetFrameStrata("FULLSCREEN_DIALOG")
    card:SetFrameLevel(base + 5)
    ns.StyleTip(card)
    card:SetBackdropBorderColor(GR, GG, GB, 1)
    card:SetWidth(CARD_W)

    ui.count = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ui.count:SetPoint("TOPRIGHT", -12, -11)

    ui.title = ns.Text(card, 15, "LEFT", "head")
    ui.title:SetPoint("TOPLEFT", 12, -11)
    ui.title:SetPoint("TOPRIGHT", -46, -11)

    ui.body = ns.Text(card, 13)
    ui.body:SetPoint("TOPLEFT", ui.title, "BOTTOMLEFT", 0, -6)
    ui.body:SetWidth(CARD_W - 24)
    ui.body:SetJustifyV("TOP")

    ui.skip = textBtn(card, finish)
    ui.skip.fs:SetText("Пропустить")

    ui.back = textBtn(card, function() go(step - 1) end)
    ui.back.fs:SetText("Назад")

    ui.next = textBtn(card, function()
        if step >= #STEPS then finish() else go(step + 1) end
    end)

    ov:SetScript("OnUpdate", function(self, e)
        since = since + e
        if dirty or since >= REFRESH then layout() end
    end)
    ov:SetScript("OnShow", function()
        escape(false)
        pulse:Play()
    end)
    ov:SetScript("OnHide", function(self)
        escape(true)
        pulse:Stop()
        if self:IsShown() then self:Hide() end
    end)
end

function ns.ShowGuide(parent)
    ensureFrames(parent)
    if not ov then return end
    step = 1
    render()
    card:Hide()
    ring:Hide()
    glow:Hide()
    for _, b in ipairs(bands) do b:Hide() end
    dirty = true
    ov:Show()
end

function ns.ToggleGuide(parent)
    if ov and ov:IsShown() then finish() else ns.ShowGuide(parent) end
end
