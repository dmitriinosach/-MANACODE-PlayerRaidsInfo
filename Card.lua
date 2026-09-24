local ADDON, ns = ...
local PAD = 10
local GAP = 8
local MAX_RAIDS = 6
local CW = 436
local W = CW + PAD * 2
local ROW_H = 18
local ICON = 22
local INDENT = ICON + 6
local TIP_BORDER = { 0.54, 0.56, 0.6 }
local CHIPS = 5
local COLS = {
    { 0, 40, "LEFT" }, { 44, 68, "LEFT" }, { 116, 36, "CENTER" },
    { 156, 90, "LEFT" }, { 250, 90, "LEFT" }, { 344, 92, "LEFT" },
}
local THIN = {
    bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local card, shownInfo, shownHow
local function hr(parent)
    local t = ns.Rect(parent, 1, 1, 1, 0.1, "ARTWORK")
    t:SetHeight(1)
    return t
end
local function label(text)
    local fs = ns.Text(card, 13)
    fs:SetTextColor(1, 0.82, 0)
    if text then fs:SetText(text) end
    return fs
end
local function wide(size, r, g, b, w)
    local fs = ns.Text(card, size)
    fs:SetWidth(w or CW)
    if r then fs:SetTextColor(r, g, b) end
    return fs
end
local function buildChips()
    card.chips = {}
    for i = 1, CHIPS do
        local c = CreateFrame("Frame", nil, card)
        c:SetHeight(18)
        c:SetBackdrop(THIN)
        c:SetBackdropColor(0.14, 0.13, 0.11, 0.9)
        c:SetBackdropBorderColor(0.42, 0.37, 0.25, 1)
        c.text = ns.Text(c, 12, "CENTER")
        c.text:SetPoint("CENTER", c, "CENTER", 0, 0)
        c:Hide()
        card.chips[i] = c
    end
end
local function withIcon(fs, size, h, w)
    fs.icon = card:CreateTexture(nil, "OVERLAY")
    fs.icon:SetWidth(size)
    fs.icon:SetHeight(size)
    fs.icon:Hide()
    fs.iconDy = math.floor((h - size) / 2)
    fs.baseW = w
    return fs
end
local function setIcon(fs, tex, l, r, t, b)
    fs.iconOn = tex and true or nil
    if not tex then return end
    fs.icon:SetTexture(tex)
    fs.icon:SetTexCoord(l or 0.08, r or 0.92, t or 0.08, b or 0.92)
end
local function buildTable()
    card.heads = {}
    for c = 1, #COLS do
        local fs = ns.Text(card, 11, COLS[c][3])
        fs:SetTextColor(0.5, 0.52, 0.55)
        fs:SetWidth(COLS[c][2])
        fs:SetHeight(14)
        if c >= 4 then withIcon(fs, 12, 14, COLS[c][2]) end
        card.heads[c] = fs
    end
    card.headLine = hr(card)
    card.rows = {}
    for r = 1, MAX_RAIDS do
        local row = { bg = ns.Rect(card, 1, 1, 1, 0.04, "BORDER") }
        row.bg:SetHeight(ROW_H)
        for c = 1, #COLS do
            local fs = ns.Text(card, 12, COLS[c][3])
            fs:SetWidth(COLS[c][2])
            fs:SetHeight(ROW_H)
            if c == 2 then withIcon(fs, 14, ROW_H, COLS[c][2]) end
            if c >= 4 then withIcon(fs, 13, ROW_H, COLS[c][2]) end
            row[c] = fs
        end
        card.rows[r] = row
    end
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
    card.art:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
    card.art:SetWidth(220)
    card.art:Hide()
    card.wash = card:CreateTexture(nil, "ARTWORK")
    card.wash:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    card.wash:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
    card.wash:Hide()
    card.stripe = card:CreateTexture(nil, "ARTWORK")
    card.stripe:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    card.stripe:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
    card.stripe:SetHeight(2)
    card.stripe:Hide()
    ns.MakeGlow(card, 4, 14)
    card.icon = card:CreateTexture(nil, "OVERLAY")
    card.icon:SetWidth(ICON)
    card.icon:SetHeight(ICON)
    card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
    card.name = ns.Text(card, 15, "LEFT", "head")
    card.hero = ns.Text(card, 12)
    card.hero:SetTextColor(1, 0.82, 0)
    card.hero:SetText("ГН")
    card.heroIcon = card:CreateTexture(nil, "OVERLAY")
    card.heroIcon:SetWidth(13)
    card.heroIcon:SetHeight(13)
    card.heroIcon:SetTexture(ns.HERO_ICON)
    card.heroIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.heroIcon:SetPoint("LEFT", card.name, "RIGHT", 6, 0)
    card.hero:SetPoint("LEFT", card.heroIcon, "RIGHT", 3, 0)
    card.heroIcon:Hide()
    card.season = ns.Text(card, 11, "RIGHT")
    card.season:SetTextColor(0.55, 0.57, 0.6)
    card.guild = ns.Text(card, 12)
    card.guild:SetTextColor(0.25, 1, 0.25)
    card.sub = withIcon(wide(13, 0.92, 0.92, 0.92, CW - INDENT), 15, 13, CW - INDENT)
    card.was = wide(12, 0.55, 0.57, 0.6, CW - INDENT)
    card.note = wide(13, 1, 0.6, 0.2)
    card.hist = wide(11, 0.6, 0.6, 0.6)
    card.msg = wide(13, 0.62, 0.62, 0.62)
    card.hr = { hr(card), hr(card), hr(card) }
    card.kvLabel = { label("Лучший парс ДД"), label("Лучший парс хил"), label("Лучший парс танк") }
    card.kvValue = { ns.Text(card, 13, "RIGHT"), ns.Text(card, 13, "RIGHT"), ns.Text(card, 13, "RIGHT") }
    card.countsLabel = label("Рейдов")
    card.recentLabel = label("Последние рейды")
    buildChips()
    buildTable()
    card.foot = wide(11, 0.5, 0.52, 0.55)
    return card
end
local function place(fs, x, y)
    if fs.icon then
        fs.icon:ClearAllPoints()
        if fs.iconOn then
            fs.icon:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + x, -(y + fs.iconDy))
            fs.icon:Show()
            local shift = fs.icon:GetWidth() + 3
            x = x + shift
            fs:SetWidth(fs.baseW - shift)
        else
            fs.icon:Hide()
            fs:SetWidth(fs.baseW)
        end
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + x, -y)
    fs:Show()
end
local function hideFs(fs)
    fs:Hide()
    if fs.icon then fs.icon:Hide() end
end
local function placeLine(fs, y, x, gap)
    place(fs, x or 0, y)
    return y + (fs:GetStringHeight() or 13) + (gap or 2)
end
local function placeHr(t, y)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(y + GAP / 2))
    t:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y + GAP / 2))
    t:Show()
    return y + GAP + 1
end
local function hideBody()
    for _, o in ipairs({ card.was, card.msg, card.note, card.hist, card.countsLabel, card.recentLabel,
        card.headLine, card.foot, card.guild, card.sub, card.hero, card.heroIcon }) do hideFs(o) end
    for _, t in ipairs(card.hr) do t:Hide() end
    for i = 1, 3 do card.kvLabel[i]:Hide(); card.kvValue[i]:Hide() end
    for _, c in ipairs(card.chips) do c:Hide() end
    for _, fs in ipairs(card.heads) do hideFs(fs) end
    for _, row in ipairs(card.rows) do
        row.bg:Hide()
        for _, fs in ipairs(row) do hideFs(fs) end
    end
end
local function bestText(b)
    if not b or not b.parse then return ns.Color("none", "—") end
    return "|cff" .. ns.ParseHex(b.parse) .. b.parse .. "|r " .. ns.Color("grey", ns.BOSS[b.boss] or b.boss or "")
end
local function fillCell(fs, cell)
    if not cell then
        setIcon(fs, nil)
        fs:SetText(ns.Color("none", "—"))
        return
    end
    local c = ns.ROLE_COORD[cell.role]
    if c then setIcon(fs, ns.ROLE_TEX, c[1] / 64, c[2] / 64, c[3] / 64, c[4] / 64) else setIcon(fs, nil) end
    local out = cell.value and ns.Color("white", ns.Compact(cell.value)) or ns.Color("grey", "танк")
    if cell.parse then out = out .. "  |cff" .. ns.ParseHex(cell.parse) .. cell.parse .. "|r" end
    fs:SetText(out)
end
local function fillRow(row, raid)
    row[1]:SetText(ns.Color("grey", ns.DayMonthYear(raid.date)))
    setIcon(row[2], ns.IsRS(raid.mode) and ns.RS_LFG or ns.ICC_LFG, 6 / 64, 58 / 64, 6 / 64, 58 / 64)
    row[2]:SetText(ns.Color("note", ns.MODE_CELL[raid.mode] or raid.mode))
    row[3]:SetText(ns.WipesText(raid.wipes))
    if ns.IsRS(raid.mode) then
        fillCell(row[4], nil)
        fillCell(row[5], nil)
        fillCell(row[6], raid.cells[1])
    else
        for c = 1, 3 do fillCell(row[3 + c], raid.cells[c]) end
    end
end
local function bossHead(fs, boss, text)
    setIcon(fs, boss and ns.BOSS_ICON[boss])
    fs:SetText(text or (boss and ns.BOSS[boss]) or "")
end
local function renderHead(y, hasRS, hasIcc)
    card.heads[1]:SetText("дата")
    card.heads[2]:SetText("режим")
    card.heads[3]:SetText("вайпы")
    bossHead(card.heads[4], hasIcc and "surf")
    bossHead(card.heads[5], hasIcc and "prof")
    local lastBoss = hasIcc and "lich" or "hal"
    bossHead(card.heads[6], lastBoss, (hasIcc and hasRS) and (ns.BOSS.lich .. " / " .. ns.BOSS.hal) or nil)
    for c = 1, #COLS do place(card.heads[c], COLS[c][1], y) end
    card.headLine:ClearAllPoints()
    card.headLine:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(y + 15))
    card.headLine:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y + 15))
    card.headLine:Show()
    return y + 18
end
local function renderName(id, rec, shown, class, s)
    local y = PAD
    if ns.SetClassTexture(card.icon, class) then card.icon:Show() else card.icon:Hide() end
    local title = ns.TitleOf(id)
    card.name:SetText(title and (shown .. "|cffe8e8e8, " .. title .. "|r") or shown)
    card.name:SetTextColor(ns.ClassColor(class))
    card.name:ClearAllPoints()
    card.name:SetPoint("LEFT", card.icon, "RIGHT", 6, 0)
    card.season:SetText(s and s.season and ("сезон " .. s.season) or "")
    card.season:ClearAllPoints()
    card.season:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y + 4))
    if ns.HeroDate(rec) then
        card.heroIcon:Show()
        card.hero:Show()
    end
    y = y + ICON + 2
    local e = ns.GuildOf(id)
    if id and e and e.cur then
        ns.FitText(card.guild, e.cur, CW - INDENT - 10)
        y = placeLine(card.guild, y, INDENT, 1)
    end
    return y
end
local function renderSub(shown, class, s, y, id)
    local sub = {}
    local live = ns.LiveSpec and ns.LiveSpec(shown)
    local spec = live or (s and ns.SpecRu(s.spec))
    local icon = ns.SpecIcon(class, live or (s and s.spec))
    setIcon(card.sub, icon)
    if not icon and spec then tinsert(sub, spec) end
    if s and s.gs then tinsert(sub, "ilvl " .. s.gs) end
    local gsText = ns.GearScoreText and ns.GearScoreText(id)
    if gsText then tinsert(sub, gsText) end
    if #sub == 0 and not icon then return y end
    card.sub:SetText(table.concat(sub, ", "))
    return math.max(placeLine(card.sub, y, INDENT, 1), icon and (y + 16) or 0)
end
local function renderWas(info, id, rec, shown, y)
    local text
    if info.viaOld and rec then
        text = "найден по прошлому имени, на сайте " .. rec.name
    else
        local others = ns.OtherNames(rec, shown)
        if #others > 0 then text = "раньше: " .. ns.NamesShort(others, 48) end
    end
    if not text then return y end
    card.was:SetText(text)
    return placeLine(card.was, y, INDENT, 1)
end
local function paintAmbient(shown, class, s, headH)
    ns.Ambient(card, class, TIP_BORDER, 0.65, 0.18)
    card.wash:SetHeight(headH)
    card.art:SetHeight(headH)
    ns.PaintWash(card.wash, class, 0.3, 0)
    ns.PaintWash(card.stripe, class, 0.9, 0.1)
    ns.PaintArt(card.art, ns.ArtFor(shown, class, s and s.spec), 220, headH, 0.45)
end
local function problemText(id, rec)
    local problem = ns.DataProblem()
    if problem then return problem end
    if not id then return "нет в выгрузке: персонаж не встречался, id неизвестен" end
    if rec then return "в сезоне " .. tostring(ns.CurrentSeason() or "?") .. " килов нет" end
    if ns.Meta().complete == false then return "нет в логах (выгрузка неполная)" end
    return "нет в логах"
end
local function renderChips(s, y)
    local x = 0
    local n = 0
    for _, mode in ipairs(ns.MODES) do
        local k = s.raids[mode] or 0
        if k > 0 and n < CHIPS then
            n = n + 1
            local c = card.chips[n]
            c.text:SetText(ns.Color("note", ns.MODE_COUNT[mode]) .. " " .. ns.Color("white", k))
            c:SetWidth(math.floor((c.text:GetStringWidth() or 40) + 12))
            place(c, x, y)
            x = x + c:GetWidth() + 4
        end
    end
    if n == 0 then
        card.chips[1].text:SetText(ns.Color("none", "—"))
        card.chips[1]:SetWidth(24)
        place(card.chips[1], 0, y)
    end
    return y + 18 + 4
end
local function renderBest(s, y, class)
    local best = { s.bestD, s.bestH, s.bestT }
    local can = ns.ClassRoles(class)
    local rows = {}
    for i, role in ipairs({ "d", "h", "t" }) do
        if can[role] and best[i] and best[i].parse then tinsert(rows, i) end
    end
    if #rows == 0 then rows[1] = 1 end
    for _, i in ipairs(rows) do
        card.kvValue[i]:SetText(bestText(best[i]))
        card.kvValue[i]:ClearAllPoints()
        card.kvValue[i]:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
        card.kvValue[i]:Show()
        place(card.kvLabel[i], 0, y)
        y = y + 17
    end
    return y
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
    place(card.recentLabel, 0, y)
    y = y + 18
    local hasIcc, hasRS = false, false
    for r = 1, #raids do
        if ns.IsRS(raids[r].mode) then hasRS = true else hasIcc = true end
    end
    y = renderHead(y, hasRS, hasIcc)
    for r = 1, #raids do
        local row = card.rows[r]
        fillRow(row, raids[r])
        for c = 1, #COLS do place(row[c], COLS[c][1], y) end
        row.bg:ClearAllPoints()
        row.bg:SetPoint("TOPLEFT", card, "TOPLEFT", PAD - 3, -y)
        row.bg:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD + 3, -y)
        if r % 2 == 1 then row.bg:Show() end
        y = y + ROW_H
    end
    if more > 0 then
        card.foot:SetText("ещё " .. more .. " " .. ns.Plural(more, "рейд", "рейда", "рейдов") .. " — /raids")
        y = placeLine(card.foot, y + 4, 0, 0)
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
    local y = renderName(id, rec, shown, class, s)
    y = renderSub(shown, class, s, y, id)
    y = renderWas(info, id, rec, shown, y)
    paintAmbient(shown, class, s, y + 2)
    local note = ns.Note(id)
    if note then
        card.note:SetText("Заметка: " .. note)
        y = placeLine(card.note, y + 3, 0, 1)
    end
    if ns.DataProblem() or not s then
        y = placeHr(card.hr[1], y)
        card.msg:SetText(problemText(id, rec))
        y = placeLine(card.msg, y, 0, 0)
        local histOnly = rec and ns.HistLine(rec)
        if histOnly and not ns.DataProblem() then
            card.hist:SetText("за всё время: " .. histOnly)
            y = placeLine(card.hist, y + 2, 0, 0)
        end
        card:SetHeight(y + PAD)
        return
    end
    y = placeHr(card.hr[1], y)
    y = renderBest(s, y, class)
    y = placeHr(card.hr[2], y)
    place(card.countsLabel, 0, y)
    y = y + 18
    y = renderChips(s, y)
    local hist = ns.HistLine(rec)
    if hist then
        card.hist:SetText("за всё время: " .. hist)
        y = placeLine(card.hist, y, 0, 0)
    end
    y = renderRaids(rec, y)
    card:SetHeight(y + PAD)
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
        local scale = card:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        local w, h = card:GetWidth() or W, card:GetHeight() or 200
        local sw, sh = UIParent:GetWidth() * UIParent:GetEffectiveScale() / scale, UIParent:GetHeight() * UIParent:GetEffectiveScale() / scale
        local x, top = cx + 18, cy - 12
        if x + w > sw - 8 then x = cx - 18 - w end
        if top - h < 8 then top = h + 8 end
        if top > sh - 8 then top = sh - 8 end
        if x < 8 then x = 8 end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
    end
    card:Show()
end
function ns.CardName()
    return card and card:IsShown() and shownInfo and shownInfo.name or nil
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
