local ADDON, ns = ...
local PAD = 10
local GAP = 8
local MAX_RAIDS = 7
local CW = 436
local W = CW + PAD * 2
local ROW_H = 18
local ICON = 22
local INDENT = ICON + 6
local TIP_BORDER = { 0.54, 0.56, 0.6 }
local CHIPS = 12
local LINK_H = 24
local LINK_ARROW = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local KILL_W = 200
local ACH_X = 214
local LIVE_ROWS = 5
local UNBUFF_HEX = "ff3326"
local COLS = {
    { 0, 46, "LEFT" }, { 50, 64, "LEFT" }, { 118, 32, "CENTER" },
    { 154, 42, "CENTER" }, { 200, 146, "LEFT" }, { 350, 86, "LEFT" },
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
    card:EnableMouse(false)
    card.link = ns.Rect(card, 1, 0.82, 0, 0.08, "BORDER")
    card.link:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 4, 4)
    card.link:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 4)
    card.link:SetHeight(LINK_H)
    card.linkLine = ns.Rect(card, 1, 0.82, 0, 0.35, "ARTWORK")
    card.linkLine:SetHeight(1)
    card.linkLine:SetPoint("BOTTOMLEFT", card.link, "TOPLEFT", 0, 0)
    card.linkLine:SetPoint("BOTTOMRIGHT", card.link, "TOPRIGHT", 0, 0)
    card.linkArrow = card:CreateTexture(nil, "OVERLAY")
    card.linkArrow:SetWidth(22)
    card.linkArrow:SetHeight(22)
    card.linkArrow:SetTexture(LINK_ARROW)
    card.linkArrow:SetPoint("RIGHT", card.link, "RIGHT", -2, 0)
    card.hint = ns.Text(card, 13, "RIGHT")
    card.hint:SetTextColor(1, 0.82, 0)
    card.hint:SetPoint("RIGHT", card.linkArrow, "LEFT", -2, 0)
    card.hint:SetText("Открыть в окне /raids")
    card.open = card:CreateTexture(nil, "OVERLAY")
    card.open:SetWidth(20)
    card.open:SetHeight(20)
    card.open:SetTexture(ns.ART .. "open.tga")
    card.open:SetPoint("TOPLEFT", card, "TOPLEFT", -7, 7)
    card.linkParts = { card.link, card.linkLine, card.linkArrow, card.hint, card.open }
    for _, o in ipairs(card.linkParts) do o:Hide() end
    card:SetScript("OnEnter", function(self)
        self.edge = { self:GetBackdropBorderColor() }
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
        self.link:SetVertexColor(1, 0.82, 0, 0.2)
        self.hint:SetTextColor(1, 1, 1)
        self.hovering = true
        SetCursor("INSPECT_CURSOR")
    end)
    card:SetScript("OnLeave", function(self)
        local e = self.edge
        if e and e[1] then self:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1) end
        self.link:SetVertexColor(1, 0.82, 0, 0.08)
        self.hint:SetTextColor(1, 0.82, 0)
        self.hovering = nil
        ResetCursor()
    end)
    card:SetScript("OnHide", function(self)
        if not self.hovering then return end
        self.hovering = nil
        self.link:SetVertexColor(1, 0.82, 0, 0.08)
        self.hint:SetTextColor(1, 0.82, 0)
        ResetCursor()
    end)
    card:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not shownInfo then return end
        local name = shownInfo.name
        ns.HideCard()
        if name and ns.OpenBrowser then ns.OpenBrowser(name) end
    end)
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
    card.gm = wide(12, 1, 0.82, 0)
    card.hist = wide(11, 0.6, 0.6, 0.6)
    card.msg = wide(13, 0.62, 0.62, 0.62)
    card.why = wide(12, 0.55, 0.57, 0.6)
    card.warnBg = ns.Rect(card, 1, 0.55, 0.1, 0.12, "BORDER")
    card.warn = wide(12, 1, 0.66, 0.26, CW - 8)
    card.killLabel = label("Убийств, 25 гер / об")
    card.achLabel = label("Ачивки")
    card.kills, card.achs = {}, {}
    for i = 1, LIVE_ROWS do
        card.kills[i] = withIcon(wide(12, 0.92, 0.92, 0.92, KILL_W), 14, 16, KILL_W)
        card.kills[i]:SetHeight(16)
        card.achs[i] = wide(12, 0.92, 0.92, 0.92, CW - ACH_X)
    end
    card.hr = { hr(card), hr(card), hr(card) }
    card.kvLabel = { label("Лучший парс ДД"), label("Лучший парс хил"), label("Лучший парс танк") }
    card.kvValue = { ns.Text(card, 13, "RIGHT"), ns.Text(card, 13, "RIGHT"), ns.Text(card, 13, "RIGHT") }
    card.statLabel = { label(), label() }
    card.statValue = { ns.Text(card, 13, "RIGHT"), ns.Text(card, 13, "RIGHT") }
    card.badgeLine = wide(12, 1, 0.82, 0)
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
        card.headLine, card.foot, card.guild, card.sub, card.hero, card.heroIcon,
        card.why, card.warn, card.warnBg, card.killLabel, card.achLabel, card.gm }) do hideFs(o) end
    for i = 1, LIVE_ROWS do hideFs(card.kills[i]); hideFs(card.achs[i]) end
    for _, t in ipairs(card.hr) do t:Hide() end
    for i = 1, 3 do card.kvLabel[i]:Hide(); card.kvValue[i]:Hide() end
    for i = 1, 2 do card.statLabel[i]:Hide(); card.statValue[i]:Hide() end
    hideFs(card.badgeLine)
    for _, c in ipairs(card.chips) do c:Hide() end
    for _, fs in ipairs(card.heads) do hideFs(fs) end
    for _, row in ipairs(card.rows) do
        row.bg:Hide()
        for _, fs in ipairs(row) do hideFs(fs) end
    end
end
local function bestText(b)
    if not (b and b.parse) then return ns.Color("none", "—") end
    local out = ns.ParseText(b.parse) .. " " .. ns.Color("grey", ns.BossName(b.boss))
    if b.unbuff then out = out .. " " .. ns.Color(UNBUFF_HEX, "анбаф") end
    return out
end
local function cellText(cell)
    local out = cell.value and ns.Color("white", ns.Compact(cell.value)) or ns.Color("grey", "танк")
    if cell.parse then out = out .. "  " .. ns.ParseText(cell.parse) end
    if cell.unbuff then out = out .. " " .. ns.Color(UNBUFF_HEX, "А") end
    return out
end
local function fillCell(fs, cell, tail)
    if not cell then
        setIcon(fs, nil)
        fs:SetText(ns.Color("none", "—"))
        return
    end
    local c = ns.ROLE_COORD[cell.role]
    if c then setIcon(fs, ns.ROLE_TEX, c[1] / 64, c[2] / 64, c[3] / 64, c[4] / 64) else setIcon(fs, nil) end
    fs:SetText(cellText(cell) .. (tail or ""))
end
local function bestCell(raid)
    local best, bi
    for i, c in pairs(raid.cells) do
        if c and c.parse and (not best or c.parse > best.parse or (c.parse == best.parse and (c.value or 0) > (best.value or 0))) then
            best, bi = c, i
        end
    end
    return best, bi
end
local function fillRow(row, raid)
    row[1]:SetText(ns.Color("grey", ns.DayMonthYear(raid.date)))
    setIcon(row[2], ns.ZoneIcon(raid.mode), 6 / 64, 58 / 64, 6 / 64, 58 / 64)
    row[2]:SetText(ns.Color("note", ns.MODE[raid.mode] and ns.MODE[raid.mode].cell or raid.mode))
    row[3]:SetText(ns.WipesText(raid.wipes))
    local bosses = ns.RaidBosses(raid)
    local n = 0
    for _, c in pairs(raid.cells) do
        if c then n = n + 1 end
    end
    row[4]:SetText(ns.Color(n > 0 and "white" or "none", n) .. ns.Color("dim", "/" .. #bosses))
    local best, bi = bestCell(raid)
    fillCell(row[5], best, bi and ("  " .. ns.Color("grey", ns.BossShort(bosses[bi]))) or nil)
    local z = ns.ZONE[ns.ModeZone(raid.mode) or ""]
    local li = z and ns.BossIndex(raid, z.last)
    fillCell(row[6], li and raid.cells[li] or nil)
end
local function renderHead(y, raids)
    card.heads[1]:SetText("дата")
    card.heads[2]:SetText("режим")
    card.heads[3]:SetText("вайпы")
    card.heads[4]:SetText("боссов")
    card.heads[5]:SetText("лучший парс")
    local lasts, seen = {}, {}
    for _, raid in ipairs(raids) do
        local z = ns.ZONE[ns.ModeZone(raid.mode) or ""]
        if z and not seen[z.last] then
            seen[z.last] = true
            tinsert(lasts, z.last)
        end
    end
    local names = {}
    for i, code in ipairs(lasts) do names[i] = ns.BossName(code) end
    local text = table.concat(names, " / ")
    if ns.Utf8Len(text) > 14 then
        for i, code in ipairs(lasts) do names[i] = ns.BossShort(code) end
        text = table.concat(names, " / ")
    end
    if ns.Utf8Len(text) > 14 then text = "последний босс" end
    setIcon(card.heads[6], #lasts == 1 and ns.BossIcon(lasts[1], raids[1].mode) or nil)
    card.heads[6]:SetText(text)
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
    card.guild:Hide()
    return y
end
local function renderSub(shown, class, s, y, id, who)
    local sub = {}
    local live = ns.LiveSpec and ns.LiveSpec(shown)
    local spec = live or (s and ns.SpecRu(s.spec))
    local icon = ns.SpecIcon(class, live or (s and s.spec))
    setIcon(card.sub, icon)
    if not icon and spec then tinsert(sub, spec) end
    if s and s.gs then tinsert(sub, "ilvl " .. s.gs) end
    local gsText = ns.GearScoreText and ns.GearScoreText(id, shown)
    if gsText then tinsert(sub, gsText) end
    local e = id and ns.GuildOf(id)
    local text = table.concat(sub, ", ")
    local guild = (e and e.cur) or (who and who.guild)
    if guild then text = text .. (text ~= "" and "   " or "") .. "|cff40ff40" .. guild .. "|r" end
    if who then
        local bits = {}
        if who.level and who.level < 80 then tinsert(bits, who.level .. " ур.") end
        if who.zone and who.zone ~= "" then tinsert(bits, who.zone) end
        if #bits > 0 then text = text .. (text ~= "" and "   " or "") .. ns.Color("grey", table.concat(bits, ", ")) end
    end
    if text == "" and not icon then return y end
    card.sub:SetText(text)
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
local function pastSeason(rec)
    local cur, missing = ns.CurrentSeason(), false
    for _, sn in ipairs(ns.Meta().seasons or {}) do
        sn = tonumber(sn)
        if sn and sn ~= cur then
            local block, why = ns.SeasonBlock(rec, sn)
            if block then return block, missing end
            if why == "notdownloaded" and ns.HadSeason(rec, sn) then missing = true end
        end
    end
    return nil, missing
end
local function countText(n, mode)
    if n > 0 then return ns.Color("note", mode) .. " " .. ns.Color("white", n) end
    return ns.Color("none", mode .. " 0")
end
local function renderLiveKills(live, y)
    local top = y
    place(card.killLabel, 0, y)
    local ly = y + 18
    for i, b in ipairs(live.bosses) do
        if i > LIVE_ROWS then break end
        local fs = card.kills[i]
        setIcon(fs, ns.BossIcon(b.boss))
        fs:SetText(ns.BossName(b.boss) .. "   " .. countText(b.h, "гер") .. "   " .. countText(b.n, "об"))
        place(fs, 0, ly)
        ly = ly + 18
    end
    place(card.achLabel, ACH_X, top)
    local ay = top + 18
    for i, a in ipairs(live.ach) do
        if i > LIVE_ROWS then break end
        local fs = card.achs[i]
        if a.done then
            fs:SetText(ns.Color("white", a.title) .. (a.date and ns.Color("grey", "  " .. a.date) or ""))
        else
            fs:SetText(ns.Color("none", a.title .. " — нет"))
        end
        ay = placeLine(fs, ay, ACH_X, 3)
    end
    return math.max(ly, ay)
end
local function renderNotInBase(name, y, whoState)
    local short, long = ns.MissingText()
    local live, state = ns.LiveKills and ns.LiveKills(name)
    if live then
        if live.any then
            card.msg:SetText(ns.Color("white", "Записей рейдов нет, но ходил"))
            card.why:SetText("Статистика из игры. Его рейды — до начала сбора рейд-логов (2023).")
        else
            card.msg:SetText("Не ходил в ЦЛК 25 и РС 25: по статистике из игры ни одного кила")
            card.why:SetText(nil)
        end
        y = placeLine(card.msg, y, 0, 0)
        if live.any then
            y = placeLine(card.why, y + 3, 0, 0)
            y = renderLiveKills(live, y + 6)
        end
        return y
    end
    card.msg:SetText(short)
    y = placeLine(card.msg, y, 0, 0)
    local lines = {}
    if long then tinsert(lines, long) end
    if state == "wait" then
        tinsert(lines, "Смотрю статистику персонажа...")
    elseif state == "far" then
        tinsert(lines, "Когда персонаж рядом, покажу его ачивки и килы боссов.")
    end
    if whoState == "wait" then tinsert(lines, "Узнаю гильдию и класс через /who...") end
    if #lines == 0 then return y end
    card.why:SetText(table.concat(lines, "\n"))
    return placeLine(card.why, y + 3, 0, 0)
end
local function renderMissing(rec, name, missing, y, whoState, curWhy)
    y = placeHr(card.hr[1], y)
    local problem = ns.DataProblem()
    if problem then
        card.msg:SetText(problem)
        return placeLine(card.msg, y, 0, 0)
    end
    if not rec then return renderNotInBase(name, y, whoState) end
    card.msg:SetText(curWhy == "notdownloaded" and ns.SeasonMessage(ns.CurrentSeason(), curWhy) or ns.SeasonEmptyText(ns.CurrentSeason()))
    y = placeLine(card.msg, y, 0, 0)
    local hist = ns.HistLine(rec)
    if hist then
        card.hist:SetText("за всё время: " .. hist)
        y = placeLine(card.hist, y + 2, 0, 0)
    end
    if missing then
        card.why:SetText("Прошлые сезоны не скачаны — отметьте их в ManacodeUpdate")
        y = placeLine(card.why, y + 3, 0, 0)
    end
    local live = ns.LiveKills and ns.LiveKills(name)
    if live and live.any then y = renderLiveKills(live, y + 8) end
    return y
end
local function renderWarn(season, y, curWhy)
    local cur = tostring(ns.CurrentSeason() or "?")
    local why = curWhy == "notdownloaded" and ("сезон " .. cur .. " не скачан") or ("в сезоне " .. cur .. " рейдов не было")
    card.warn:SetText("|cffffd040!|r  Прошлый сезон " .. season .. ": " .. why)
    place(card.warn, 4, y + 3)
    local h = (card.warn:GetStringHeight() or 13) + 6
    card.warnBg:ClearAllPoints()
    card.warnBg:SetPoint("TOPLEFT", card, "TOPLEFT", PAD - 3, -y)
    card.warnBg:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD + 3, -y)
    card.warnBg:SetHeight(h)
    card.warnBg:Show()
    return y + h + 4
end
local function renderChips(s, y)
    local x = 0
    local n = 0
    for _, mode in ipairs(ns.MODES) do
        local k = s.raids[mode] or 0
        if k > 0 and n < CHIPS then
            n = n + 1
            local c = card.chips[n]
            c.text:SetText(ns.Color("note", ns.ModeFull(mode)) .. " " .. ns.Color("white", k))
            c:SetWidth(math.floor((c.text:GetStringWidth() or 40) + 12))
            if x > 0 and x + c:GetWidth() > CW then
                x = 0
                y = y + 18 + 4
            end
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
        if can[role] and ns.BestParse(best[i]) then tinsert(rows, i) end
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
local function statRow(i, labelText, value, y)
    card.statLabel[i]:SetText(labelText)
    place(card.statLabel[i], 0, y)
    card.statValue[i]:SetText(value)
    card.statValue[i]:ClearAllPoints()
    card.statValue[i]:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
    card.statValue[i]:Show()
    return y + 17
end
local function renderStat(s, y)
    local st = s.stat
    if st and st.top then
        local lbl = "Место в спеке"
        if st.spec and st.spec ~= s.spec then lbl = lbl .. " " .. (ns.SpecRu(st.spec) or st.spec) end
        y = statRow(1, lbl, ns.Color("white", ns.StatTop(st)), y)
    end
    if st and st.better then
        local v = ns.StatBracket(st)
        if st.avg then v = v .. ", средний дпс " .. ns.Thousands(st.avg) end
        y = statRow(2, ns.StatIlvl(st), ns.Color("white", v), y)
    end
    local marks = {}
    for _, b in ipairs(ns.TopBadges(s.badges)) do tinsert(marks, ns.BadgeText(b)) end
    if #marks > 0 then
        card.badgeLine:SetText(table.concat(marks, ", "))
        y = placeLine(card.badgeLine, y + 1, 0, 2)
    end
    return y
end
local function renderRaids(rec, y)
    local raids, total = ns.RecentRaids(rec, MAX_RAIDS)
    if #raids == 0 then return y end
    local more = total - #raids
    y = placeHr(card.hr[3], y)
    place(card.recentLabel, 0, y)
    y = y + 18
    y = renderHead(y, raids)
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
        card.foot:SetText("+ ещё " .. more .. " " .. ns.Plural(more, "рейд", "рейда", "рейдов") .. " — в окне /raids")
        y = placeLine(card.foot, y + 4, 0, 0)
    end
    return y
end
local function linkSpace()
    return card.clickable and (LINK_H + 4) or 0
end
local function render(info)
    build()
    hideBody()
    local id = info.id
    local rec = id and ns.Get(id)
    local s, curWhy = ns.SeasonBlock(rec, ns.CurrentSeason())
    local old, missing
    if rec and not s and not ns.DataProblem() then
        s, missing = pastSeason(rec)
        old = s and true
    end
    local shown = info.name or (id and ns.NameOf(id)) or (rec and rec.name) or "?"
    local who, whoState
    local seen = id and ns.GuildOf(id)
    if not rec and not (seen and seen.cur ~= nil) and not ns.DataProblem() and not (ns.UnitFor and ns.UnitFor(shown)) and ns.WhoInfo then
        who, whoState = ns.WhoInfo(shown)
    end
    local class = (rec and rec.class) or info.class or (who and who.class)
    local y = renderName(id, rec, shown, class, s)
    y = renderSub(shown, class, s, y, id, who)
    y = renderWas(info, id, rec, shown, y)
    paintAmbient(shown, class, s, y + 2)
    local note = ns.Note(id)
    if note then
        card.note:SetText("Заметка: " .. note)
        y = placeLine(card.note, y + 3, 0, 1)
    end
    local gmRows = ns.GMRows and ns.GMRows(id)
    if gmRows then
        local n = 0
        for _, r in ipairs(gmRows) do
            if not ns.GM_LISTS[r.section] then n = n + 1 end
        end
        card.gm:SetText("ГМ: " .. (n > 0 and (n .. " " .. ns.Plural(n, "запись", "записи", "записей") .. " — ") or "") .. "в окне /raids, кнопка «Вещи»")
        y = placeLine(card.gm, y + 3, 0, 1)
    end
    if ns.DataProblem() or not s then
        y = renderMissing(rec, shown, missing, y, whoState, curWhy)
        card:SetHeight(y + PAD + linkSpace())
        return
    end
    y = placeHr(card.hr[1], y)
    if old then y = renderWarn(s.season, y, curWhy) end
    y = renderBest(s, y, class)
    y = renderStat(s, y)
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
    card:SetHeight(y + PAD + linkSpace())
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
    local clickable = how ~= "tooltip"
    card.clickable = clickable
    render(info)
    card:EnableMouse(clickable)
    for _, o in ipairs(card.linkParts) do
        if clickable then o:Show() else o:Hide() end
    end
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
function ns.CardHovered()
    return card and card:IsShown() and card:IsMouseEnabled() and MouseIsOver and MouseIsOver(card) and true or false
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
    local guid = ns.ChatGuid and ns.ChatGuid(name)
    if guid then
        info.guid = guid
        info.id = ns.IdFromGuid(guid) or id
        id = info.id
        if type(GetPlayerInfoByGUID) == "function" then
            local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
            if ok and classFile then info.class = classFile end
        end
    end
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
