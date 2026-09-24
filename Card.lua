local ADDON, ns = ...

local PAD = 11
local MAX_RAIDS = 6
local CW = 392
local W = CW + PAD * 2
local ROW_H = 17
local ART_H = 52
local TIP_BORDER = { 0.54, 0.56, 0.6 }
local COLS = {
    { 0, 38, "LEFT" }, { 40, 46, "LEFT" }, { 88, 30, "CENTER" },
    { 122, 88, "LEFT" }, { 212, 88, "LEFT" }, { 302, 90, "LEFT" },
}

local card, shownInfo, shownHow

local function hr(parent)
    local t = ns.Rect(parent, 1, 1, 1, 0.08, "ARTWORK")
    t:SetHeight(1)
    return t
end

local function label(text)
    local fs = ns.Text(card, 13)
    fs:SetTextColor(1, 0.82, 0)
    if text then fs:SetText(text) end
    return fs
end

local function wide(size, r, g, b)
    local fs = ns.Text(card, size)
    fs:SetWidth(CW)
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function build()
    if card then return card end
    card = CreateFrame("Frame", "PlayerRaidsCard", UIParent)
    card:SetWidth(W)
    card:SetHeight(100)
    card:SetFrameStrata("TOOLTIP")
    card:SetClampedToScreen(true)
    ns.StyleTip(card)
    card:Hide()

    card.art = card:CreateTexture(nil, "BORDER")
    card.art:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    card.art:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
    card.art:SetHeight(ART_H)
    card.art:Hide()
    ns.MakeGlow(card, 4, 16)

    card.name = ns.Text(card, 15, "LEFT", "head")
    card.hero = ns.Text(card, 12)
    card.hero:SetTextColor(1, 0.82, 0)
    card.guild = ns.Text(card, 12)
    card.guild:SetTextColor(0.25, 1, 0.25)
    card.season = ns.Text(card, 11, "RIGHT")
    card.season:SetTextColor(0.42, 0.44, 0.46)
    card.sub = wide(13)
    card.was = wide(12, 0.42, 0.44, 0.46)
    card.note = wide(13, 1, 0.6, 0.2)
    card.hist = wide(12, 0.62, 0.62, 0.62)
    card.msg = wide(13, 0.62, 0.62, 0.62)

    card.hr = { hr(card), hr(card), hr(card) }
    card.kvLabel = { label("Лучший парс ДД"), label("Лучший парс хил"), label("Лучший парс танк") }
    card.kvValue = { ns.Text(card, 13, "RIGHT"), ns.Text(card, 13, "RIGHT"), ns.Text(card, 13, "RIGHT") }

    card.countsLabel = label("Рейдов")
    card.counts = wide(13, 0.62, 0.62, 0.62)

    card.recentLabel = label("Последние рейды")

    card.heads = {}
    for c = 1, #COLS do
        local fs = ns.Text(card, 11, COLS[c][3])
        fs:SetTextColor(0.42, 0.44, 0.46)
        fs:SetWidth(COLS[c][2])
        fs:SetHeight(14)
        card.heads[c] = fs
    end
    card.headLine = hr(card)

    card.rows = {}
    for r = 1, MAX_RAIDS do
        local row = { bg = ns.Rect(card, 1, 1, 1, 0.035, "BORDER") }
        row.bg:SetHeight(ROW_H)
        for c = 1, #COLS do
            local fs = ns.Text(card, 12, COLS[c][3])
            fs:SetWidth(COLS[c][2])
            fs:SetHeight(ROW_H)
            row[c] = fs
        end
        card.rows[r] = row
    end

    card.foot = wide(11, 0.42, 0.44, 0.46)
    return card
end

local function place(fs, y, h)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    fs:Show()
    return y + (h or 16)
end

local function placeWrapped(fs, y, gap)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    fs:Show()
    return y + (fs:GetStringHeight() or 13) + (gap or 3)
end

local function placeHr(t, y)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(y + 4))
    t:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y + 4))
    t:Show()
    return y + 9
end

local function hideBody()
    card.was:Hide()
    card.msg:Hide()
    for _, t in ipairs(card.hr) do t:Hide() end
    for i = 1, 3 do card.kvLabel[i]:Hide(); card.kvValue[i]:Hide() end
    card.countsLabel:Hide()
    card.counts:Hide()
    card.note:Hide()
    card.hist:Hide()
    card.recentLabel:Hide()
    for _, fs in ipairs(card.heads) do fs:Hide() end
    card.headLine:Hide()
    for _, row in ipairs(card.rows) do
        row.bg:Hide()
        for _, fs in ipairs(row) do fs:Hide() end
    end
    card.foot:Hide()
end

local function bestText(b)
    if not b or not b.parse then return ns.Color("none", "—") end
    return "|cff" .. ns.ParseHex(b.parse) .. b.parse .. "|r " .. ns.Color("grey", ns.BOSS[b.boss] or b.boss or "")
end

local function countsText(s)
    local bits = {}
    for _, mode in ipairs(ns.MODES) do
        local n = s.raids[mode] or 0
        if n > 0 then tinsert(bits, ns.MODE_COUNT[mode] .. " " .. ns.Color("white", n)) end
    end
    if #bits == 0 then return ns.Color("none", "—") end
    return table.concat(bits, "   ")
end

local function fillRow(row, raid)
    row[1]:SetText(ns.Color("grey", ns.DayMonthYear(raid.date)))
    row[2]:SetText(ns.Color("note", ns.MODE_SHORT[raid.mode] or raid.mode or ""))
    row[3]:SetText(ns.WipesText(raid.wipes))
    if ns.IsRS(raid.mode) then
        row[4]:SetText(ns.Color("none", "—"))
        row[5]:SetText(ns.Color("none", "—"))
        row[6]:SetText(ns.CellMain(raid.cells[1]))
    else
        for c = 1, 3 do row[3 + c]:SetText(ns.CellMain(raid.cells[c])) end
    end
end

local function renderHead(y, hasRS, hasIcc)
    card.heads[1]:SetText("дата")
    card.heads[2]:SetText("режим")
    card.heads[3]:SetText("вайпы")
    card.heads[4]:SetText(hasIcc and ns.BossHead("surf", 12) or "")
    card.heads[5]:SetText(hasIcc and ns.BossHead("prof", 12) or "")
    local last = hasIcc and ns.BossHead("lich", 12) or ns.BossHead("hal", 12)
    if hasIcc and hasRS then last = last .. " / " .. ns.BOSS.hal end
    card.heads[6]:SetText(last)
    for c = 1, #COLS do
        local fs = card.heads[c]
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + COLS[c][1], -y)
        fs:Show()
    end
    card.headLine:ClearAllPoints()
    card.headLine:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(y + 15))
    card.headLine:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y + 15))
    card.headLine:Show()
    return y + 18
end

local function renderName(id, rec, shown, class, s)
    local y = 9
    local icon = ns.ClassIcon(class, 16)
    card.name:SetText(icon ~= "" and (icon .. " " .. shown) or shown)
    card.name:SetTextColor(ns.ClassColor(class))
    card.name:ClearAllPoints()
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)

    card.season:SetText(s and s.season and ("сезон " .. s.season) or "")
    card.season:ClearAllPoints()
    card.season:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y + 2))

    local used = (card.name:GetStringWidth() or 80) + 6
    local anchor = card.name
    local hero = ns.HeroDate(rec)
    card.hero:ClearAllPoints()
    if hero then
        card.hero:SetText(string.format("|T%s:13:13:0:0:64:64:5:59:5:59|t ГН", ns.HERO_ICON))
        card.hero:SetPoint("LEFT", card.name, "RIGHT", 6, 0)
        card.hero:Show()
        anchor = card.hero
        used = used + (card.hero:GetStringWidth() or 30) + 6
    else
        card.hero:Hide()
    end

    local e = ns.GuildOf(id)
    card.guild:ClearAllPoints()
    if id and e and e.cur then
        card.guild:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
        ns.FitText(card.guild, "<" .. e.cur .. ">", math.max(CW - used - 60, 40))
        card.guild:Show()
    else
        card.guild:Hide()
    end
    return y + 21
end

local function renderSub(id, shown, s, y)
    local sub = {}
    local title = ns.TitleOf(id)
    if title then tinsert(sub, ns.Color("grey", title)) end
    local spec = ns.LiveSpec and ns.LiveSpec(shown)
    if not spec and s then spec = ns.SpecRu(s.spec) end
    if spec then tinsert(sub, spec) end
    if s and s.gs then tinsert(sub, "илвл " .. s.gs) end
    card.sub:SetText(table.concat(sub, ns.Color("dim", ", ")))
    if #sub > 0 then return placeWrapped(card.sub, y, 1) end
    card.sub:Hide()
    return y
end

local function paintAmbient(shown, class, s)
    ns.Ambient(card, class, TIP_BORDER, 0.6, 0.12)
    ns.PaintArt(card.art, ns.ArtFor(shown, class, s and s.spec), W - 8, ART_H)
end

local function problemText(id, rec)
    local problem = ns.DataProblem()
    if problem then return problem end
    if not id then return "нет в выгрузке: персонаж не встречался, id неизвестен" end
    if rec then return "в сезоне " .. tostring(ns.CurrentSeason() or "?") .. " килов нет" end
    if ns.Meta().complete == false then return "нет в логах (выгрузка неполная)" end
    return "нет в логах"
end

local function renderRaids(rec, y)
    local raids, more = {}, 0
    for _, season in ipairs(rec.seasons) do
        for _, raid in ipairs(season.recent) do
            if #raids < MAX_RAIDS then tinsert(raids, raid) else more = more + 1 end
        end
    end
    if #raids == 0 then return y end

    y = placeHr(card.hr[3], y)
    y = place(card.recentLabel, y, 18)
    local hasIcc, hasRS = false, false
    for r = 1, #raids do
        if ns.IsRS(raids[r].mode) then hasRS = true else hasIcc = true end
    end
    y = renderHead(y, hasRS, hasIcc)
    for r = 1, #raids do
        local row = card.rows[r]
        fillRow(row, raids[r])
        for c = 1, #COLS do
            row[c]:ClearAllPoints()
            row[c]:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + COLS[c][1], -y)
            row[c]:Show()
        end
        row.bg:ClearAllPoints()
        row.bg:SetPoint("TOPLEFT", card, "TOPLEFT", PAD - 3, -y)
        row.bg:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD + 3, -y)
        if r % 2 == 1 then row.bg:Show() end
        y = y + ROW_H
    end
    if more > 0 then
        card.foot:SetText("ещё " .. more .. " " .. ns.Plural(more, "рейд", "рейда", "рейдов") .. " в /raids")
        y = placeWrapped(card.foot, y + 4, 0)
    end
    return y
end

local function render(info)
    build()
    hideBody()

    local id = info.id
    local rec = id and ns.Get(id)
    local s = rec and rec.seasons[1]
    local shown = info.name or (id and ns.NameOf(id)) or (rec and rec.name) or "?"
    local class = (rec and rec.class) or info.class

    paintAmbient(shown, class, s)
    local y = renderName(id, rec, shown, class, s)
    y = renderSub(id, shown, s, y)

    local others = ns.OtherNames(rec, shown)
    if info.viaOld and rec then
        card.was:SetText("найден по прошлому имени, на сайте " .. rec.name)
        y = placeWrapped(card.was, y, 1)
    elseif id and rec and ns.NameChain(id, rec) then
        card.was:SetText(ns.NameChain(id, rec))
        y = placeWrapped(card.was, y, 1)
    elseif #others > 0 then
        card.was:SetText("раньше " .. table.concat(others, ", "))
        y = placeWrapped(card.was, y, 1)
    end

    local note = ns.Note(id)
    if note then
        card.note:SetText("Заметка: " .. note)
        y = placeWrapped(card.note, y + 2, 1)
    end

    if ns.DataProblem() or not s then
        y = placeHr(card.hr[1], y)
        card.msg:SetText(problemText(id, rec))
        y = placeWrapped(card.msg, y, 0)
        local histOnly = rec and ns.HistLine(rec)
        if histOnly and not ns.DataProblem() then
            card.hist:SetText("за всё время: " .. histOnly)
            y = placeWrapped(card.hist, y + 2, 0)
        end
        card:SetHeight(y + 10)
        return
    end

    y = placeHr(card.hr[1], y)
    local best = { s.bestD, s.bestH, s.bestT }
    local rows = {}
    for i = 1, 3 do
        if best[i] and best[i].parse then tinsert(rows, i) end
    end
    if #rows == 0 then rows[1] = 1 end
    for _, i in ipairs(rows) do
        card.kvValue[i]:SetText(bestText(best[i]))
        card.kvValue[i]:ClearAllPoints()
        card.kvValue[i]:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
        card.kvValue[i]:Show()
        y = place(card.kvLabel[i], y)
    end

    y = placeHr(card.hr[2], y)
    y = place(card.countsLabel, y)
    card.counts:SetText(countsText(s))
    y = placeWrapped(card.counts, y, 0)
    local hist = ns.HistLine(rec)
    if hist then
        card.hist:SetText("за всё время: " .. hist)
        y = placeWrapped(card.hist, y + 1, 0)
    end

    y = renderRaids(rec, y)
    card:SetHeight(y + 10)
end

local function anchorTooltip()
    card:ClearAllPoints()
    local right = GameTooltip:GetRight() or 0
    local screen = UIParent:GetRight() or 0
    if right + W + 4 > screen then
        card:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -2, 0)
    else
        card:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 2, 0)
    end
end

function ns.ShowCard(info, how)
    if not info then return end
    build()
    shownInfo, shownHow = info, how
    render(info)
    if how == "tooltip" then
        anchorTooltip()
    else
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        card:ClearAllPoints()
        card:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / scale + 12, cy / scale + 12)
    end
    card:Show()
end

function ns.HideCard()
    shownInfo, shownHow = nil, nil
    if card then card:Hide() end
end

function ns.CardHow()
    return card and card:IsShown() and shownHow or nil
end

local refreshers = {}

function ns.OnRefresh(fn)
    tinsert(refreshers, fn)
end

function ns.Refresh(name)
    for _, fn in ipairs(refreshers) do fn(name) end
    if not card or not card:IsShown() or not shownInfo then return end
    if shownInfo.name ~= name then return end
    render(shownInfo)
    if shownHow == "tooltip" then anchorTooltip() end
end

function ns.InfoForName(name)
    if not name or name == "" then return nil end
    name = string.match(name, "^([^%-]+)") or name
    local id = ns.FindId(name)
    local info = { name = name, id = id }
    if id and not ns.IdOf(name) then
        local rec = ns.Get(id)
        if rec and ns.Lower(rec.name) ~= ns.Lower(name) then info.viaOld = true end
    end
    return info
end

function ns.InfoForUnit(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local guid = UnitGUID(unit)
    local _, class = UnitClass(unit)
    local info = { name = UnitName(unit), guid = guid, id = ns.IdFromGuid(guid), class = class }
    if info.id and ns.TitleFrom and PlayerRaidsGuilds then
        local title = ns.TitleFrom(unit, info.name)
        local e = PlayerRaidsGuilds[info.id]
        if title ~= nil and e then e.title = title end
    end
    return info
end
