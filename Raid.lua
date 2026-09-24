local ADDON, ns = ...

local ROW_H = 18
local SUM_H = 116
local LIST_Y = 82
local TILE = 36
local THROTTLE = 0.5
local ROLE_ORDER = { "t", "h", "d" }
local ROLE_HEAD = { t = "Танки", h = "Хилы", d = "ДД" }
local BOSS_GEN = { surf = "Саурфанга", prof = "Профессора", lich = "Лича", hal = "Халиона" }
local THIN = {
    bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local TILE_BACKDROP = {
    bgFile = ns.WHITE,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local HOW = {
    "Дпс рейда — сумма средних дпс ДД и танков на выбранном боссе.",
    "Худший случай — сумма их минимумов.",
    "Процент — место среди рейдов сезона, убивших этого босса, по сумме дпс.",
    "Шанс без вайпов — доля таких рейдов, прошедших вечер без вайпов.",
    "Нет данных — игрок в сумму не входит, как 0: оценка занижена.",
}

local panel, lscroll, sum
local rows, tiles, bossBtns = {}, {}, {}
local roster, list = {}, {}
local listeners = {}
local pick = { mode = "ih", boss = 3 }
local dirty = false

local function pool(rowH)
    local screen = (GetScreenHeight and GetScreenHeight()) or 1200
    local scale = UIParent:GetEffectiveScale() or 1
    local h = math.max(screen, UIParent:GetHeight() or 0, 1200 / scale)
    return math.ceil(h / rowH) + 1
end

function ns.InRaid()
    return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
end

local function scanRoster()
    roster = {}
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        local name, _, subgroup, _, _, fileName = GetRaidRosterInfo(i)
        if name and subgroup and subgroup <= 5 then
            local guid = UnitGUID("raid" .. i)
            local id = ns.IdFromGuid(guid)
            if id then ns.Remember(name, guid) else id = ns.FindId(name) end
            tinsert(roster, { name = name, class = fileName, id = id })
        end
    end
end

function ns.RaidRoster()
    return roster
end

function ns.RaidIds()
    if #roster == 0 and ns.InRaid() then scanRoster() end
    local out = {}
    for _, m in ipairs(roster) do
        if m.id then tinsert(out, m.id) end
    end
    return out
end

function ns.OnRaidChanged(fn)
    tinsert(listeners, fn)
end

local function chanceRGB(p)
    local t = math.max(0, math.min(1, (p or 0) / 100))
    return math.min(1, 2 * (1 - t)), math.min(1, 2 * t), 0.2
end

local function chanceText(p)
    local r, g, b = chanceRGB(p)
    return string.format("|cff%02x%02x%02x%d%%|r", floor(r * 255), floor(g * 255), floor(b * 255), floor(p + 0.5))
end

local function statFor(m)
    local rec = m.id and ns.Get(m.id)
    local st = ns.RaidStat(rec, pick.mode, ns.IsRS(pick.mode) and 1 or pick.boss)
    st.class = (rec and rec.class) or m.class
    st.rec = rec
    if not st.role then st.role = "d" end
    return st
end

local function buildList()
    list = {}
    local groups = { t = {}, h = {}, d = {} }
    for _, m in ipairs(roster) do
        m.stat = statFor(m)
        tinsert(groups[m.stat.role], m)
    end
    for _, role in ipairs(ROLE_ORDER) do
        local g = groups[role]
        table.sort(g, function(a, b)
            local va, vb = a.stat.avg or -1, b.stat.avg or -1
            if va ~= vb then return va > vb end
            return a.name < b.name
        end)
        if #g > 0 then
            tinsert(list, { head = role, count = #g })
            for _, m in ipairs(g) do tinsert(list, m) end
        end
    end
end

local function valueText(v, season)
    local out = ns.Color("white", ns.Compact(v))
    if season then out = out .. ns.Color("dim", " с" .. season) end
    return out
end

local function updateRows()
    if not panel then return end
    local offset = FauxScrollFrame_GetOffset(lscroll) or 0
    for i, row in ipairs(rows) do
        local e = i <= panel.nrows and list[offset + i]
        if e and e.head then
            row.head:SetText(ns.RoleIcon(e.head, 14) .. " " .. ROLE_HEAD[e.head] .. ns.Color("dim", "  " .. e.count))
            row.head:Show()
            row.name:Hide(); row.avg:Hide(); row.min:Hide()
            row.id = nil
            row.odd:Hide()
            row:Show()
        elseif e then
            local st = e.stat
            row.head:Hide()
            local spec = ns.SpecRu(st.spec)
            row.name:SetText("|cff" .. ns.ClassHex(st.class) .. e.name .. "|r" .. (spec and ns.Color("dim", "  " .. spec) or ""))
            if st.avg then
                row.avg:SetText(valueText(st.avg, st.season))
                row.min:SetText(ns.Color("grey", ns.Compact(st.min)))
            else
                row.avg:SetText(ns.Color("grey", "нет данных"))
                row.min:SetText("")
            end
            row.name:Show(); row.avg:Show(); row.min:Show()
            row.id = e.id
            if (offset + i) % 2 == 1 then row.odd:Show() else row.odd:Hide() end
            row:Show()
        else
            row.id = nil
            row:Hide()
        end
    end
    FauxScrollFrame_Update(lscroll, #list, panel.nrows, ROW_H)
end

local function compute()
    local r = { exp = 0, worst = 0, hps = 0, noData = 0, t = 0, h = 0, d = 0 }
    for _, m in ipairs(roster) do
        local st = m.stat or statFor(m)
        r[st.role] = r[st.role] + 1
        if st.avg then
            if st.role == "h" then
                r.hps = r.hps + st.avg
            else
                r.exp = r.exp + st.avg
                r.worst = r.worst + st.min
            end
        else
            r.noData = r.noData + 1
        end
    end
    return r
end

local function bossKey()
    if ns.IsRS(pick.mode) then return "hal" end
    return ns.ICC_BOSSES[pick.boss]
end

local function renderSummary()
    local r = compute()
    local boss = bossKey()
    local bench = ns.Bench(pick.mode, boss)
    local L = sum.lines
    L[1]:SetText("Дпс рейда: " .. ns.Color("white", ns.Compact(r.exp)) .. " ожидаемо, "
        .. ns.Color("grey", ns.Compact(r.worst)) .. " в худшем случае")
    if bench then
        local p, pw = ns.BenchPercent(bench, r.exp), ns.BenchPercent(bench, r.worst)
        L[2]:SetText("Сильнее " .. ns.Color("white", floor(p + 0.5) .. "%") .. " составов, убивших "
            .. (BOSS_GEN[boss] or ns.BOSS[boss]) .. "; в худшем — " .. ns.Color("grey", floor(pw + 0.5) .. "%"))
        L[3]:SetText("Шанс без вайпов: " .. chanceText(ns.BenchNoWipe(bench, p)) .. ", в худшем — "
            .. chanceText(ns.BenchNoWipe(bench, pw)))
        local h, verdict = bench.hps, "около медианы"
        if h[1] and r.hps < h[1] then verdict = ns.Color("ff8040", "ниже большинства")
        elseif h[3] and r.hps > h[3] then verdict = ns.Color("green", "выше большинства") end
        L[4]:SetText("Хпс рейда: " .. ns.Color("white", ns.Compact(r.hps)) .. " — " .. verdict)
        L[5]:SetText("по " .. bench.n .. " " .. ns.Plural(bench.n, "рейду", "рейдам", "рейдам")
            .. " сезона, вайпы — на весь рейд")
    else
        L[2]:SetText(ns.Color("grey", "Эталонов для «" .. ns.BOSS[boss] .. ", " .. ns.MODE_FULL[pick.mode] .. "» нет — мало рейдов в выгрузке"))
        L[3]:SetText("")
        L[4]:SetText("Хпс рейда: " .. ns.Color("white", ns.Compact(r.hps)))
        L[5]:SetText("")
    end
    local warn = {}
    if r.t < 2 then tinsert(warn, "танков " .. r.t .. " из 2") end
    if r.h < 5 then tinsert(warn, "хилов " .. r.h .. " из 5") end
    if r.noData > 0 then
        tinsert(warn, "нет данных у " .. r.noData .. " — в сумме как 0")
    end
    L[6]:SetText(#warn > 0 and ns.Color("ff9933", table.concat(warn, ", ")) or "")
end

local function renderPick()
    for _, t in ipairs(tiles) do
        local on = t.mode == pick.mode
        if on then
            t:SetBackdropBorderColor(1, 0.82, 0, 1)
            t.mark:Show()
        else
            t:SetBackdropBorderColor(0.4, 0.4, 0.42, 1)
            t.mark:Hide()
        end
    end
    local rs = ns.IsRS(pick.mode)
    for i, b in ipairs(bossBtns) do
        if rs then
            if i == 1 then
                ns.FitButton(b, ns.BossHead("hal", 14), 16)
                ns.SetButton(b, true)
                b:Show()
            else
                b:Hide()
            end
        else
            ns.FitButton(b, ns.BossHead(ns.ICC_BOSSES[i], 14), 16)
            ns.SetButton(b, pick.boss == i)
            b:Show()
        end
    end
    local x = 5 * (TILE + 4) + 22
    for _, b in ipairs(bossBtns) do
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -(24 + 7))
            x = x + b:GetWidth() + 4
        end
    end
end

local function refresh()
    if not panel or not panel:IsShown() then return end
    buildList()
    panel.count:SetText("группы 1-5: " .. #roster .. " " .. ns.Plural(#roster, "игрок", "игрока", "игроков"))
    renderPick()
    updateRows()
    renderSummary()
end

local function setPick(mode, boss)
    pick.mode = mode or pick.mode
    pick.boss = boss or pick.boss
    PlayerRaidsDB.raidPick = { mode = pick.mode, boss = pick.boss }
    if panel then FauxScrollFrame_SetOffset(lscroll, 0) end
    refresh()
end

local function buildTile(i, mode)
    local t = CreateFrame("Button", nil, panel)
    t:SetWidth(TILE)
    t:SetHeight(TILE)
    t:SetBackdrop(TILE_BACKDROP)
    t:SetBackdropColor(0, 0, 0, 0.5)
    t:SetHighlightTexture(ns.WHITE)
    t:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.12)
    local x = (i - 1) * (TILE + 4) + (ns.IsRS(mode) and 10 or 0)
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -24)
    local icon = t:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(ns.IsRS(mode) and ns.RS_LFG or ns.ICC_LFG)
    if ns.HEROIC[mode] then
        local skull = t:CreateTexture(nil, "OVERLAY")
        skull:SetTexture(ns.SKULL.tex)
        skull:SetTexCoord(ns.SKULL.coord[1], ns.SKULL.coord[2], ns.SKULL.coord[3], ns.SKULL.coord[4])
        skull:SetHeight(16)
        skull:SetWidth(math.floor(16 * ns.SKULL.ratio + 0.5))
        skull:SetPoint("CENTER", t, "TOPRIGHT", -3, -3)
    end
    local size = t:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    size:SetPoint("CENTER", 0, 0)
    size:SetText(mode == "iu" and "25А" or "25")
    t.mark = ns.Rect(panel, 1, 0.82, 0, 0.9, "ARTWORK")
    t.mark:SetHeight(2)
    t.mark:SetWidth(TILE - 8)
    t.mark:SetPoint("TOP", t, "BOTTOM", 0, -1)
    t.mode = mode
    t:SetScript("OnClick", function(self) setPick(self.mode) end)
    t:SetScript("OnEnter", function(self) ns.TipTable(self, "ANCHOR_TOP", ns.MODE_FULL[self.mode]) end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return t
end

local function buildRow(i)
    local row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", lscroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", lscroll, "TOPRIGHT", 0, -(i - 1) * ROW_H)
    row.odd = ns.Rect(row, 1, 1, 1, 0.03)
    row.odd:SetAllPoints()
    row:SetHighlightTexture(ns.WHITE)
    row:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.08)
    row.head = ns.Text(row, 12, "LEFT", "head")
    row.head:SetTextColor(1, 0.82, 0)
    row.head:SetPoint("LEFT", 2, 0)
    row.name = ns.Text(row, 13)
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetHeight(ROW_H)
    row.min = ns.Text(row, 13, "RIGHT")
    row.min:SetWidth(70)
    row.min:SetPoint("RIGHT", -4, 0)
    row.avg = ns.Text(row, 13, "RIGHT")
    row.avg:SetWidth(90)
    row.avg:SetPoint("RIGHT", row.min, "LEFT", -6, 0)
    row:SetScript("OnClick", function(self)
        if self.id and ns.BrowserSelect then ns.BrowserSelect(self.id) end
    end)
    row:Hide()
    return row
end

local function buildSummary()
    sum = CreateFrame("Frame", nil, panel)
    sum:SetHeight(SUM_H)
    sum:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    sum:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    sum:SetBackdrop(THIN)
    sum:SetBackdropColor(0, 0, 0, 0.4)
    sum:SetBackdropBorderColor(0.3, 0.26, 0.18, 1)
    sum:EnableMouse(true)
    sum:SetScript("OnEnter", function(self) ns.TipTable(self, "ANCHOR_TOP", "Как считается", HOW) end)
    sum:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local title = ns.Text(sum, 12)
    title:SetTextColor(1, 0.82, 0)
    title:SetPoint("TOPLEFT", 9, -5)
    title:SetText("Прогноз на босса")
    sum.lines = {}
    local y = 21
    for i = 1, 6 do
        local size = (i == 5) and 11 or 13
        local fs = ns.Text(sum, size)
        fs:SetPoint("TOPLEFT", 9, -y)
        fs:SetPoint("RIGHT", sum, "RIGHT", -9, 0)
        fs:SetHeight(size + 3)
        if i == 5 then fs:SetTextColor(0.5, 0.52, 0.55) end
        sum.lines[i] = fs
        y = y + size + 3
    end
end

local function build(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetFrameLevel(parent:GetFrameLevel() + 2)
    panel:Hide()
    local saved = PlayerRaidsDB.raidPick
    if type(saved) == "table" and ns.MODE_INDEX[saved.mode] then
        pick.mode, pick.boss = saved.mode, tonumber(saved.boss) or 3
    end

    local title = ns.Text(panel, 15, "LEFT", "head")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Мой рейд")
    panel.count = ns.Text(panel, 12, "RIGHT")
    panel.count:SetTextColor(0.55, 0.57, 0.6)
    panel.count:SetPoint("TOPRIGHT", 0, -2)

    for i, mode in ipairs(ns.MODES) do tiles[i] = buildTile(i, mode) end
    for i = 1, 3 do
        local b = ns.MakeButton(panel, 12, nil, 22)
        b.index = i
        b.onClick = function(self)
            if not ns.IsRS(pick.mode) then setPick(nil, self.index) end
        end
        bossBtns[i] = b
    end

    local hName = ns.Text(panel, 11)
    hName:SetTextColor(0.5, 0.52, 0.55)
    hName:SetPoint("TOPLEFT", 6, -(LIST_Y - 16))
    hName:SetText("игрок, роль по его рейдам")
    panel.hMin = ns.Text(panel, 11, "RIGHT")
    panel.hMin:SetTextColor(0.5, 0.52, 0.55)
    panel.hMin:SetWidth(70)
    panel.hMin:SetText("минимум")
    panel.hAvg = ns.Text(panel, 11, "RIGHT")
    panel.hAvg:SetTextColor(0.5, 0.52, 0.55)
    panel.hAvg:SetWidth(90)
    panel.hAvg:SetText("среднее, дпс/хпс")

    lscroll = CreateFrame("ScrollFrame", "PlayerRaidsRaidList", panel, "FauxScrollFrameTemplate")
    lscroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -LIST_Y)
    lscroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, updateRows)
    end)
    for i = 1, pool(ROW_H) do rows[i] = buildRow(i) end
    buildSummary()
end

local function layout(w, h)
    panel:SetWidth(w)
    panel:SetHeight(h)
    local listH = h - LIST_Y - SUM_H - 8
    panel.nrows = math.max(1, math.min(math.floor(listH / ROW_H), #rows))
    lscroll:SetWidth(w - 24)
    lscroll:SetHeight(panel.nrows * ROW_H)
    panel.hMin:ClearAllPoints()
    panel.hMin:SetPoint("TOPRIGHT", panel, "TOPLEFT", w - 24 - 4, -(LIST_Y - 16))
    panel.hAvg:ClearAllPoints()
    panel.hAvg:SetPoint("RIGHT", panel.hMin, "LEFT", -6, 0)
end

function ns.RaidPanelShow(parent, x, y, w, h)
    if not panel then build(parent) end
    if #roster == 0 and ns.InRaid() then scanRoster() end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    layout(w, h)
    panel:Show()
    refresh()
end

function ns.RaidPanelHide()
    if panel then panel:Hide() end
end

local ticker = CreateFrame("Frame")
ticker:Hide()
ticker.left = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
    self.left = self.left - (elapsed or 0)
    if self.left > 0 then return end
    self:Hide()
    dirty = false
    scanRoster()
    refresh()
    for _, fn in ipairs(listeners) do fn() end
end)

local function markDirty()
    if dirty then return end
    dirty = true
    ticker.left = THROTTLE
    ticker:Show()
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("RAID_ROSTER_UPDATE")
watcher:RegisterEvent("PARTY_MEMBERS_CHANGED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", markDirty)
