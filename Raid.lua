local ADDON, ns = ...

local ROW_H = 18
local SUM_H = 116
local LIST_Y = 82
local TILE = 36
local THROTTLE = 0.5
local ROLE_ORDER = { "t", "h", "d" }
local ROLE_HEAD = { t = "Танки", h = "Хилы", d = "ДД" }
local BOSS_GEN = { surf = "Саурфанга", prof = "Профессора", lich = "Лича", hal = "Халиона" }
local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }
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
    "У каждого берутся его последние рейды в этой сложности на нынешнем ilvl (до -2), хотя бы три.",
    "Дпс рейда — сумма средних дпс ДД и танков на этом боссе по тем рейдам. Хпс — так же по хилам.",
    "Худший случай — если каждый выдаст свой минимум.",
    "Закрывали — в какой доле тех рейдов босс убит. Танк весит x3, хил x2, ДД x1.",
    "Без вайпов — доля рейдов, где за весь вечер не вайпались ни разу: на каком боссе был вайп, сайт не пишет.",
    "Нет данных по дпс — игрок входит в сумму как 0, прогноз занижен.",
}

local panel, lscroll, sum
local rows, tiles, bossBtns = {}, {}, {}
local roster, list = {}, {}
local listeners = {}
local pick = { mode = "ih", boss = 3 }
local dirty = false

local FAKE_CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local FAKE_ATTEMPTS = 3000
local fakeOn = false

local function pool(rowH)
    local screen = (GetScreenHeight and GetScreenHeight()) or 1200
    local scale = UIParent:GetEffectiveScale() or 1
    local h = math.max(screen, UIParent:GetHeight() or 0, 1200 / scale)
    return math.ceil(h / rowH) + 1
end

function ns.InRaid()
    if fakeOn then return true end
    return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
end

local function scanRoster()
    if fakeOn then return end
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

local ALT_MODES = { ih = { "iu", "in" }, iu = { "ih", "in" }, ["in"] = { "ih", "iu" }, rh = { "rn" }, rn = { "rh" } }
local ALT_LABEL = { ih = "в гер", iu = "в анбафе", ["in"] = "в об", rh = "в гер", rn = "в об" }

local function altStat(rec)
    if not rec then return nil end
    local bi = ns.IsRS(pick.mode) and 1 or pick.boss
    for _, mode in ipairs(ALT_MODES[pick.mode] or {}) do
        local st = ns.RaidStat(rec, mode, bi)
        if st.avg then return st, ALT_LABEL[mode] end
    end
    return nil
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
            local c = ns.ROLE_COORD[e.head]
            row.headIcon:SetTexture(ns.ROLE_TEX)
            row.headIcon:SetTexCoord(c[1] / 64, c[2] / 64, c[3] / 64, c[4] / 64)
            row.headIcon:Show()
            row.head:SetText(ROLE_HEAD[e.head] .. ns.Color("dim", "  " .. e.count))
            row.head:Show()
            row.name:Hide(); row.avg:Hide(); row.min:Hide()
            row.id = nil
            row.odd:Hide()
            row:Show()
        elseif e then
            local st = e.stat
            row.head:Hide()
            row.headIcon:Hide()
            local spec = ns.SpecRu(st.spec)
            row.name:SetText("|cff" .. ns.ClassHex(st.class) .. e.name .. "|r" .. (spec and ns.Color("dim", "  " .. spec) or ""))
            if st.avg then
                row.avg:SetText(valueText(st.avg, st.season))
                row.min:SetText(ns.Color("grey", ns.Compact(st.min)))
            else
                local alt, label = altStat(st.rec)
                if alt then
                    row.avg:SetText(ns.Color("dim", ns.Compact(alt.avg) .. " " .. label))
                else
                    row.avg:SetText(ns.Color("grey", "нет данных"))
                end
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

local ROLE_WEIGHT = { t = 3, h = 2, d = 1 }

local function experience(rec, mode, bi)
    if not rec then return nil end
    local list = {}
    for _, bl in ipairs(ns.StatBlocks(rec)) do
        for _, raid in ipairs(bl.s.byMode[mode] or {}) do
            tinsert(list, { il = ns.RaidIlvl(raid), date = tonumber(raid.date) or 0, raid = raid })
        end
    end
    local picked = ns.PickRecent(list)
    local total, killed, clean = #picked, 0, 0
    for _, e in ipairs(picked) do
        if e.raid.cells[bi] then killed = killed + 1 end
        if e.raid.wipes == 0 then clean = clean + 1 end
    end
    if total == 0 then return nil end
    return killed / total, clean / total
end

local function compute()
    local r = { exp = 0, worst = 0, hps = 0, noData = 0, t = 0, h = 0, d = 0, kw = 0, cw = 0, ww = 0 }
    local bi = ns.IsRS(pick.mode) and 1 or pick.boss
    for _, m in ipairs(roster) do
        local st = m.stat or statFor(m)
        r[st.role] = r[st.role] + 1
        local k, c = experience(st.rec, pick.mode, bi)
        if k then
            local w = ROLE_WEIGHT[st.role] or 1
            r.kw, r.cw, r.ww = r.kw + k * w, r.cw + c * w, r.ww + w
        end
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
    local L = sum.lines
    L[1]:SetText("Дпс рейда: " .. ns.Color("white", ns.Compact(r.exp))
        .. ns.Color("grey", ", в худшем случае " .. ns.Compact(r.worst)))
    L[2]:SetText("Хпс рейда: " .. ns.Color("white", ns.Compact(r.hps)))
    if r.ww > 0 then
        L[3]:SetText("Закрывали " .. (BOSS_GEN[boss] or ns.BOSS[boss]) .. ": " .. chanceText(r.kw / r.ww * 100)
            .. ns.Color("grey", " своих рейдов"))
        L[4]:SetText("Без вайпов за вечер: " .. chanceText(r.cw / r.ww * 100)
            .. ns.Color("grey", " (весь рейд, не один босс)"))
    else
        L[3]:SetText(ns.Color("grey", "Никто из состава не ходил в " .. (ns.MODE_FULL[pick.mode] or pick.mode)))
        L[4]:SetText("")
    end
    L[5]:SetText("по последним рейдам каждого, наведи — как считается")
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
        local boss = rs and (i == 1 and "hal") or (not rs and ns.ICC_BOSSES[i])
        if boss then
            b:SetIcon(ns.BOSS_ICON[boss], ICON_CROP)
            ns.FitButton(b, ns.BOSS[boss] or boss, 16)
            ns.SetButton(b, rs or pick.boss == i)
            b:Show()
        else
            b:Hide()
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
    row.headIcon = row:CreateTexture(nil, "ARTWORK")
    row.headIcon:SetWidth(14)
    row.headIcon:SetHeight(14)
    row.headIcon:SetPoint("LEFT", 2, 0)
    row.headIcon:Hide()
    row.head = ns.Text(row, 12, "LEFT", "head")
    row.head:SetTextColor(1, 0.82, 0)
    row.head:SetPoint("LEFT", row.headIcon, "RIGHT", 4, 0)
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

local function shuffleFake(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function fakeCandidate(id, season)
    local rec = ns.Get(id)
    if not rec then return nil end
    local s = ns.SeasonOf(rec, season)
    if not s or (s.raids.ih or 0) == 0 then return nil end
    local st = ns.RaidStat(rec, "ih", 1)
    if not st.role then return nil end
    return st.role, { name = rec.name, class = rec.class, id = id }
end

local function buildFakeRoster()
    local season = ns.CurrentSeason()
    local blanks = math.random(1, 2)
    local needT, needH, needD = 2, 5, 18 - blanks
    local gotT, gotH, gotD = {}, {}, {}
    if ns.DataOK() and season and type(PlayerRaidsData) == "table" then
        local attempts = 0
        for id in pairs(PlayerRaidsData) do
            attempts = attempts + 1
            if attempts > FAKE_ATTEMPTS or (#gotT >= needT and #gotH >= needH and #gotD >= needD) then break end
            local role, m = fakeCandidate(id, season)
            if role == "t" and #gotT < needT then
                tinsert(gotT, m)
            elseif role == "h" and #gotH < needH then
                tinsert(gotH, m)
            elseif role == "d" and #gotD < needD then
                tinsert(gotD, m)
            end
        end
    end
    local out = {}
    for _, m in ipairs(gotT) do tinsert(out, m) end
    for _, m in ipairs(gotH) do tinsert(out, m) end
    for _, m in ipairs(gotD) do tinsert(out, m) end
    for i = 1, blanks do
        tinsert(out, { name = "Тестовый" .. i, class = FAKE_CLASSES[math.random(#FAKE_CLASSES)], id = nil })
    end
    shuffleFake(out)
    for i, m in ipairs(out) do
        m.subgroup = ((i - 1) % 5) + 1
    end
    roster = out
    fakeOn = true
    return #out
end

local function buildGuildRoster()
    if not IsInGuild or not IsInGuild() then return nil, "вы не в гильдии" end
    local showOff = GetGuildRosterShowOffline and GetGuildRosterShowOffline()
    if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
    local total = GetNumGuildMembers(true) or 0
    local bi = ns.IsRS(pick.mode) and 1 or pick.boss
    local byRole = { t = {}, h = {}, d = {} }
    for i = 1, total do
        local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
        local id = name and (ns.IdOf(name) or ns.FindId(name))
        local rec = id and ns.Get(id)
        if rec then
            local st = ns.RaidStat(rec, pick.mode, bi)
            if st.n and st.n > 0 and st.role and byRole[st.role] then
                tinsert(byRole[st.role], { name = name, class = rec.class or classFile, id = id, n = st.n })
            end
        end
    end
    if SetGuildRosterShowOffline and not showOff then SetGuildRosterShowOffline(false) end
    if total == 0 then
        if GuildRoster then GuildRoster() end
        return nil, "список гильдии ещё не загружен, повторите через пару секунд"
    end
    local need = { t = 2, h = 5, d = 18 }
    local out, got = {}, {}
    for _, role in ipairs({ "t", "h", "d" }) do
        local l = byRole[role]
        shuffleFake(l)
        table.sort(l, function(a, b) return a.n > b.n end)
        got[role] = math.min(#l, need[role])
        for i = 1, got[role] do tinsert(out, l[i]) end
    end
    if #out == 0 then return nil, "в гильдии никто не проходил " .. (ns.MODE_FULL[pick.mode] or pick.mode) end
    for i, m in ipairs(out) do m.subgroup = ((i - 1) % 5) + 1 end
    roster = out
    fakeOn = true
    return #out, string.format("танки %d, хилы %d, ДД %d", got.t, got.h, got.d)
end

SLASH_PLAYERRAIDSFAKE1 = "/raidsfake"
SlashCmdList["PLAYERRAIDSFAKE"] = function(msg)
    local q = string.match(msg or "", "^%s*(.-)%s*$")
    if q == "off" then
        if not fakeOn then
            ns.Print("фейковый рейд и так выключен")
            return
        end
        fakeOn = false
        if ns.InRaid() then scanRoster() else roster = {} end
        refresh()
        for _, fn in ipairs(listeners) do fn() end
        ns.Print("фейковый рейд выключен")
        return
    end
    if q == "guild" or q == "г" or q == "ги" then
        local gn, info = buildGuildRoster()
        if not gn then
            ns.Print(info)
            return
        end
        refresh()
        for _, fn in ipairs(listeners) do fn() end
        ns.Print("рейд из гильдии, " .. (ns.MODE_FULL[pick.mode] or pick.mode) .. ": " .. info)
        return
    end
    local n = buildFakeRoster()
    refresh()
    for _, fn in ipairs(listeners) do fn() end
    ns.Print("фейковый рейд: собрано " .. n .. " " .. ns.Plural(n, "игрок", "игрока", "игроков"))
end
