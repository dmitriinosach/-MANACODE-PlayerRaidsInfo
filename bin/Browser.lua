local ADDON, ns = ...
local MIN_W, MIN_H = 760, 540
local LEFT_W = 180
local LROW_H = 17
local LIST_TOP = 110
local RX = 238
local RROW_H = 20
local BOTTOM = 34
local GAP = 6
local TILE, TILE_STEP, BEST_H, SKULL_PAD = 44, 50, 46, 9
local SEARCH_LIMIT = 200
local RECENT_LIMIT = 50
local HEAD_Y, BAND_H, AKA_H = 38, 42, 13
local SEASON_W = 24
local ALL_W = 38
local ALL = "all"
local TCOLS = { { 18, "RIGHT" }, { 38, "CENTER" }, { 44, "LEFT" }, { 40, "CENTER" }, { 36, "CENTER" } }
local HEAD_TOP = 34
local VAL_W, PAR_MIN, ICON_W = 52, 24, 12
local RING_TEX = "Interface\\Buttons\\UI-Quickslot2"
local EDGE = { 0.4, 0.4, 0.42 }
local ROW2_GAP = 12
local BADGE_H = 18
local RT = {
    gap = 4, max = 11, colMax = 160, zoneGap = 12, killGap = 12,
    unbuffRGB = { 1, 0.2, 0.15 }, unbuffHex = "ff3326",
    bestFrom = "Лучший парс берётся из ЦЛК 25 гер, ЦЛК 25 об и РС 25 гер",
    roleWord = { d = "Урон", h = "Исцеление", t = "Танк, урон" },
    bossDefault = {
        icc = { saurfang = true, putricide = true, sindragosa = true, lichking = true },
        rs = { halion = true },
        toc = { northrendbeasts = true, jaraxxus = true, valkyr = true, anubarak = true },
    },
    PREV = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-",
    NEXT = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-",
}
local HEAD_KEYS = { nil, "season", "date", "wipes", "ilvl" }
function RT.picked(zone)
    local o = PlayerRaidsDB.opts
    local saved = o and type(o.bossCols) == "table" and o.bossCols[zone]
    if type(saved) == "table" and next(saved) then return saved end
    return RT.bossDefault[zone] or {}
end
function RT.setPicked(zone, code, on)
    local cur = {}
    for k, v in pairs(RT.picked(zone)) do cur[k] = v end
    cur[code] = on and true or nil
    if not next(cur) then return false end
    PlayerRaidsDB.opts = PlayerRaidsDB.opts or {}
    PlayerRaidsDB.opts.bossCols = PlayerRaidsDB.opts.bossCols or {}
    PlayerRaidsDB.opts.bossCols[zone] = cur
    return true
end
function RT.columns(all, zone)
    local sel, out = RT.picked(zone), {}
    for _, code in ipairs(all) do
        if sel[code] then tinsert(out, code) end
    end
    if #out == 0 then
        for i, code in ipairs(all) do out[i] = code end
    end
    return out
end
local ARROW_UP = "Interface\\Buttons\\Arrow-Up-Up"
local ARROW_DOWN = "Interface\\Buttons\\Arrow-Down-Up"
local THIN = {
    bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local frame, searchBox, placeholder, listLabel, lscroll, rscroll, status, ticker
local right = {}
local lrows, rrows = {}, {}
local ids, raids, nums = {}, {}, {}
local state = { search = "", id = nil, season = nil, mode = ns.MODES[1], list = "all", seasonMsg = nil }
local listSeg, optPanel, howPanel, howBtn
local size = { w = MIN_W, h = MIN_H, rw = MIN_W - RX - 12, lrows = 19, rrows = 6 }
local function dim(fs) fs:SetTextColor(0.42, 0.44, 0.46) end
local function grey(fs) fs:SetTextColor(0.62, 0.62, 0.62) end
local function gold(fs) fs:SetTextColor(1, 0.82, 0) end
local function line(parent, a)
    local t = ns.Rect(parent, 1, 0.82, 0, a or 0.15, "ARTWORK")
    t:SetHeight(1)
    return t
end
local function place(obj, x, y)
    obj:ClearAllPoints()
    obj:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
end
local function seasonCaption()
    if state.season == ALL then return "все сезоны" end
    return "сезон " .. tostring(state.season)
end
local function parseCode(p)
    if not p then return ns.Color("none", "—") end
    return "|cff" .. ns.ParseHex(p) .. p .. "|r"
end
local function sortOpt()
    local o = PlayerRaidsDB.opts
    local r = o and o.raidSort
    if type(r) ~= "table" or not r.key or r.key == "best" then return "date", true end
    return r.key, r.desc ~= false
end
local function setSort(key, desc)
    PlayerRaidsDB.opts = PlayerRaidsDB.opts or {}
    PlayerRaidsDB.opts.raidSort = { key = key, desc = desc and true or false }
end
local function sortValue(raid, key)
    if key == "date" then return tonumber(raid.date) end
    if key == "season" then return raid.season end
    if key == "wipes" then return raid.wipes end
    if key == "ilvl" then return ns.RaidIlvl(raid) end
    local code = string.match(key, "^b:(%a+)$")
    local bi = code and ns.BossIndex(raid, code)
    local c = bi and raid.cells[bi]
    return c and c.parse or nil
end
local function sortRaids(list)
    local key, desc = sortOpt()
    local out, idx = {}, {}
    for i, r in ipairs(list or {}) do
        out[i] = r
        idx[r] = i
    end
    table.sort(out, function(a, b)
        local va, vb = sortValue(a, key), sortValue(b, key)
        if va == nil or vb == nil then
            if va == nil and vb == nil then return idx[a] < idx[b] end
            return vb == nil
        end
        if va ~= vb then
            if desc then return va > vb end
            return va < vb
        end
        return idx[a] < idx[b]
    end)
    return out
end
local function headLabel(i, text, icon)
    local fs = right.heads[i]
    local key, desc = sortOpt()
    local on = HEAD_KEYS[i] and HEAD_KEYS[i] == key and text ~= ""
    fs:SetText(ns.Color(on and "gold" or "grey", text))
    local hi = right.headIcons[i]
    if hi then
        if icon then
            hi:SetTexture(icon)
            hi:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            hi:Show()
        else
            hi:Hide()
        end
    end
    local ar = right.headArrows[i]
    if not on then
        ar:Hide()
        return
    end
    ar:SetTexture(desc and ARROW_DOWN or ARROW_UP)
    ar:ClearAllPoints()
    local sw = math.floor((fs:GetStringWidth() or 0) + 0.5)
    if fs.justify == "CENTER" then
        ar:SetPoint("LEFT", fs, "CENTER", math.floor(sw / 2) + 1, -2)
    else
        ar:SetPoint("LEFT", fs, "LEFT", sw + 1, -2)
    end
    ar:Show()
end
local function updateLeft()
    local offset = FauxScrollFrame_GetOffset(lscroll) or 0
    for i, row in ipairs(lrows) do
        local id = i <= size.lrows and ids[offset + i]
        if id then
            if state.list == "ren" then
                row.text:SetText(ns.RenameLine(id) .. ns.NoteMark(id))
            else
                local shown, class, was = ns.Brief(id)
                local text = "|cff" .. ns.ClassHex(class) .. shown .. "|r"
                if was then text = text .. " " .. ns.Color("dim", "был " .. was) end
                row.text:SetText(text .. ns.NoteMark(id))
            end
            row.id = id
            if state.id == id then
                row.sel:Show()
                row.accent:Show()
            else
                row.sel:Hide()
                row.accent:Hide()
            end
            row:Show()
        else
            row.id = nil
            row:Hide()
        end
    end
    FauxScrollFrame_Update(lscroll, #ids, size.lrows, LROW_H)
end
local function resetScroll(scroll)
    if FauxScrollFrame_SetOffset then FauxScrollFrame_SetOffset(scroll, 0) end
    local bar = _G[scroll:GetName() .. "ScrollBar"]
    if bar then bar:SetValue(0) end
end
local function fillLeft()
    local problem = ns.DataProblem()
    if problem then
        ids = {}
        listLabel:SetText(problem)
    elseif state.list == "raid" then
        ids = ns.RaidIds and ns.RaidIds() or {}
        listLabel:SetText("Состав рейда, группы 1-5: " .. #ids)
    elseif state.list == "ren" then
        local base = ns.Renames()
        local q = ns.Lower(string.match(state.search or "", "^%s*(.-)%s*$") or "")
        q = string.gsub(q, ",", "")
        if q == "" then
            ids = base
            listLabel:SetText(#base > 0 and ("Ренеймов: " .. #base) or "Ренеймов нет")
        else
            ids = {}
            for _, id in ipairs(base) do
                if ns.Matches(id, q) then tinsert(ids, id) end
            end
            listLabel:SetText("Найдено " .. #ids .. " из " .. #base)
        end
    elseif string.match(state.search, "^%s*$") then
        ids = ns.RecentSeen(RECENT_LIMIT)
        listLabel:SetText(#ids > 0 and "Недавно встречены" or "Пока никого не встретили — введите ник")
    else
        local found
        ids, found = ns.Search(state.search, SEARCH_LIMIT)
        if found == 0 then
            listLabel:SetText("Никого с таким ником")
        elseif found > SEARCH_LIMIT then
            listLabel:SetText("Найдено " .. found .. ", показаны " .. SEARCH_LIMIT)
        else
            listLabel:SetText("Найдено " .. found)
        end
    end
    resetScroll(lscroll)
    updateLeft()
end
local function hideCell(cs)
    for _, o in ipairs({ cs.icon, cs.val, cs.par, cs.btn, cs.mark }) do o:Hide() end
end
local function showRaidRow(row, on)
    for _, fs in ipairs(row.cols) do
        if on then fs:Show() else fs:Hide() end
    end
    if not on then
        for _, cs in ipairs(row.cells) do hideCell(cs) end
    end
    if on then row.sep:Hide() else row.sep:Show() end
end
function RT.cellAt(raid, b)
    local code = right.tab and right.tab.bosses[b]
    local bi = code and ns.BossIndex(raid, code)
    return bi and raid.cells[bi] or nil, bi
end
local function fillCell(cs, raid, b)
    local cell, bi = RT.cellAt(raid, b)
    cs.btn.raid, cs.btn.bi = cell and raid or nil, bi
    cs.val:Show()
    cs.par:Show()
    cs.btn:Show()
    if cell and cell.unbuff then cs.mark:Show() else cs.mark:Hide() end
    if not cell then
        cs.icon:Hide()
        cs.val:SetText(ns.Color("none", "—"))
        cs.par:SetText("")
        return
    end
    local c = ns.ROLE_COORD[cell.role]
    if c then
        cs.icon:SetTexture(ns.ROLE_TEX)
        cs.icon:SetTexCoord(c[1] / 64, c[2] / 64, c[3] / 64, c[4] / 64)
        cs.icon:Show()
    else
        cs.icon:Hide()
    end
    cs.val:SetText(cell.value and ns.Color("white", ns.Compact(cell.value)) or ns.Color("grey", "танк"))
    cs.par:SetText(parseCode(cell.parse))
end
local function cellTip(self)
    local raid, bi = self.raid, self.bi
    local cell = raid and bi and raid.cells[bi]
    if not cell then return end
    local boss = ns.RaidBosses(raid)[bi]
    local rows = { { "Дата", ns.DayMonthYearFull(raid.date) } }
    tinsert(rows, { RT.roleWord[cell.role] or "Значение", cell.value and (ns.Thousands(cell.value) .. (cell.role == "h" and " хпс" or " дпс")) or "—" })
    tinsert(rows, { "Парс", parseCode(cell.parse) })
    if cell.unbuff then tinsert(rows, { "Анбаф", ns.Color(RT.unbuffHex, "да") }) end
    local ctx = {}
    local spec = ns.SpecRu(raid.spec)
    if not spec or ns.SpecRole(raid.spec) ~= cell.role then spec = ({ d = "ДД", h = "хил", t = "танк" })[cell.role] end
    if spec then tinsert(ctx, spec) end
    if cell.ilvl then tinsert(ctx, "ilvl " .. cell.ilvl) end
    local foot
    if #ctx > 0 then foot = table.concat(ctx, ", ") end
    ns.TipTable(self, "ANCHOR_TOP", ns.BossName(boss) .. " — " .. ns.ModeFull(raid.mode), rows, foot)
end
local function durationText(m)
    if not m or m <= 0 or m >= 24 * 60 then return nil end
    local h = floor(m / 60)
    if h == 0 then return m .. " мин" end
    return h .. " ч " .. (m % 60) .. " мин"
end
local function raidTip(self)
    local raid = self.raid
    local info = raid and ns.RaidInfo(raid)
    if not info then return end
    local rows = {}
    if info.leader then tinsert(rows, { "Лидер", info.leader }) end
    tinsert(rows, { "Гильдия", info.guild and ns.Color("green", info.guild) or ns.Color("grey", "сборный рейд") })
    if info.killed and info.total then tinsert(rows, { "Убито боссов", info.killed .. " из " .. info.total }) end
    tinsert(rows, { "Вайпов за вечер", ns.WipesText(info.wipes) })
    local dur = durationText(info.minutes)
    if dur then tinsert(rows, { "Длительность", dur }) end
    if info.hero then tinsert(rows, { "Герой Нордскола", "получен в этом рейде" }) end
    if raid.unbuff then tinsert(rows, { "Анбаф", ns.Color(RT.unbuffHex, "был на части боссов") }) end
    if #info.bossWipes > 0 then
        tinsert(rows, ns.Color("gold", "Вайпы по боссам"))
        for _, e in ipairs(info.bossWipes) do tinsert(rows, { ns.BossName(e.code), ns.WipesText(e.n) }) end
    end
    ns.TipTable(self, "ANCHOR_TOP", ns.ModeFull(raid.mode) .. ", " .. ns.DayMonthYearFull(info.date or raid.date), rows)
end
function RT.liveRS(mode)
    local zone = ns.ModeZone(mode)
    if zone == "rs" then return true end
    if zone == "icc" then return false end
    return nil
end
local function liveNote(name, rs)
    if not name or not ns.LiveKills then return nil end
    local live, st = ns.LiveKills(name)
    if live then
        local has = (rs == nil and live.any) or (rs == true and live.anyRs) or (rs == false and live.anyIcc)
        if not has then return ns.Color("grey", "По статистике из игры килов тоже нет") end
        return ns.Color("grey", "Статистика из игры:") .. "\n" .. table.concat(ns.LiveKillsLines(live, rs), "\n")
    end
    if st == "wait" then return "Смотрю статистику персонажа..." end
    if st == "far" then return "Когда персонаж рядом, покажу его ачивки и килы боссов." end
    return nil
end
local function updateRaids()
    local offset = FauxScrollFrame_GetOffset(rscroll) or 0
    local tableShown = rscroll:IsShown()
    local tab = right.tab or { nb = 0, bosses = {} }
    for i, row in ipairs(rrows) do
        local raid = tableShown and i <= size.rrows and raids[offset + i]
        row.raid = raid and not raid.sep and raid or nil
        if raid and raid.sep then
            showRaidRow(row, false)
            row.sep:SetText("Сезон " .. raid.sep)
            row.odd:Hide()
            row:Show()
        elseif raid then
            showRaidRow(row, true)
            local c = row.cols
            c[1]:SetText(ns.Color("dim", nums[offset + i] or ""))
            c[2]:SetText(ns.Color("note", raid.season or ""))
            c[3]:SetText(ns.Color("grey", ns.DayMonthYear(raid.date)))
            c[4]:SetText(ns.WipesText(raid.wipes))
            local il = ns.RaidIlvl(raid)
            c[5]:SetText(il and ns.Color("white", il) or ns.Color("none", "—"))
            if not tab.season then c[2]:Hide() end
            for b = 1, RT.max do
                local cs = row.cells[b]
                if b <= tab.nb then fillCell(cs, raid, b) else hideCell(cs) end
            end
            if (nums[offset + i] or 0) % 2 == 1 then row.odd:Show() else row.odd:Hide() end
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(rscroll, #raids, size.rrows, RROW_H)
    if tableShown and #raids == 0 then
        local text = state.modeMsg or state.seasonMsg
        if not text then
            text = type(state.season) == "number" and ns.SeasonEmptyText(state.season, "рейдов в этой сложности")
                or "Нет рейдов в этой сложности"
        end
        local extra = state.id and not state.modeMsg and liveNote(ns.NameOf(state.id), RT.liveRS(state.mode))
        if extra then text = text .. "\n\n" .. extra end
        right.empty:SetText(text)
        right.empty:Show()
    else
        right.empty:Hide()
    end
end
local function styleTile(tile, n, on, missing, flagged)
    local dark = n == 0 or missing
    tile.icon:SetDesaturated(dark and 1 or nil)
    tile.icon:SetAlpha(dark and 0.45 or 1)
    tile.skull:SetAlpha(dark and 0.45 or 1)
    tile.size:SetAlpha(n == 0 and 0.5 or 1)
    tile.tag:SetAlpha(dark and 0.5 or 1)
    if (flagged or 0) > 0 then
        tile.unbuff:SetAlpha(dark and 0.5 or 1)
        tile.unbuff:Show()
    else
        tile.unbuff:Hide()
    end
    local edge = on and { 1, 0.82, 0 } or EDGE
    tile:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    tile.count, tile.flagged, tile.missing = n, flagged, missing
    if on then tile.mark:Show() else tile.mark:Hide() end
    tile.size:SetText(n)
    if n == 0 then
        tile.size:SetTextColor(0.6, 0.6, 0.6)
    elseif missing then
        tile.size:SetTextColor(1, 0.6, 0.2)
    elseif on then
        tile.size:SetTextColor(1, 0.82, 0)
    else
        tile.size:SetTextColor(1, 1, 1)
    end
end
local function tileWash(t, r, g, b)
    t.wash:SetTexture(ns.WHITE)
    t.wash:SetGradientAlpha("HORIZONTAL", r, g, b, 0.16, r, g, b, 0)
    t.wash:Show()
    t.accent:SetVertexColor(r, g, b, 1)
    t.accent:Show()
end
local function tileFill(t, b, role)
    t.best, t.role = b, role
    local p = ns.BestParse(b)
    if p then
        t.big:SetText("|cff" .. ns.ParseHex(p) .. p .. "|r")
        local l1, l2 = {}, {}
        if b.boss then tinsert(l1, ns.BossName(b.boss)) end
        if b.mode then tinsert(l1, ns.ModeShort(b.mode)) end
        if b.value then tinsert(l2, ns.Compact(b.value) .. (role == "h" and " хпс" or " дпс")) end
        if b.date then tinsert(l2, ns.DayMonthYear(b.date)) end
        local head = table.concat(l1, ", ")
        t.l1 = b.unbuff and { head .. ", " .. ns.Color(RT.unbuffHex, "анбаф"), head, cut = true } or head
        t.l2 = table.concat(l2, ", ")
        tileWash(t, ns.ParseRGB(p))
    else
        t.big:SetText(ns.Color("none", "—"))
        t.l1 = role == "h" and "не хилил" or "не дамажил"
        t.l2 = seasonCaption()
        t.accent:Hide()
        t.wash:Hide()
    end
end
local function fitAvgRow(row, r, a, w)
    local sp = right.avgSpec and right.avgSpec[r]
    if sp and sp.icon then
        row.icon:SetTexture(sp.icon)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        local c = ns.ROLE_COORD[r]
        row.icon:SetTexture(ns.ROLE_TEX)
        row.icon:SetTexCoord(c[1] / 64, c[2] / 64, c[3] / 64, c[4] / 64)
    end
    local label = ns.Color("grey", r == "h" and "Хил" or "ДД") .. "  "
    local val = ns.Compact(a.avg)
    local tries = {
        label .. ns.Color("white", val .. (r == "h" and " хпс" or " дпс")) .. "  " .. ns.Color("dim", a.raids .. " " .. ns.Plural(a.raids, "рейд", "рейда", "рейдов")),
        label .. ns.Color("white", val) .. "  " .. ns.Color("dim", a.raids .. " " .. ns.Plural(a.raids, "рейд", "рейда", "рейдов")),
        label .. ns.Color("white", val) .. "  " .. ns.Color("dim", a.raids),
    }
    row.fs:SetWidth(w + 400)
    for _, text in ipairs(tries) do
        row.fs:SetText(text)
        if (row.fs:GetStringWidth() or 0) <= w then break end
    end
    row.fs:SetWidth(w + 2)
end
local function fitTile(t, tw)
    t.k:SetWidth(tw + 400)
    t.k:SetText(t.kText or "")
    if t.kShort and (t.k:GetStringWidth() or 0) > tw - 14 then
        ns.FitText(t.k, t.kShort, tw - 14)
    else
        ns.FitText(t.k, t.kText or "", tw - 14)
    end
    t.k:SetWidth(tw - 12)
    if t.rows then
        local n = #(t.lines or {})
        for i, row in ipairs(t.rows) do
            local r = t.lines and t.lines[i]
            if r then
                row.icon:ClearAllPoints()
                row.icon:SetPoint("TOPLEFT", t, "TOPLEFT", 10, n == 1 and -26 or (-6 - 13 * i))
                fitAvgRow(row, r, t.avg[r], tw - 10 - 15 - 6)
                row.icon:Show()
                row.fs:Show()
            else
                row.icon:Hide()
                row.fs:Hide()
            end
        end
        t.wash:SetWidth(math.max(math.floor(tw * 0.6), 1))
        return
    end
    local x = 10 + math.floor((t.big:GetStringWidth() or 20) + 0.5) + 7
    local w = math.max(tw - x - 6, 12)
    for i, fs in ipairs({ t.s1, t.s2 }) do
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", t, "TOPLEFT", x, -9 - 12 * i)
        fs:SetWidth(w + 400)
        local v = (i == 1 and t.l1 or t.l2) or ""
        if type(v) == "table" then
            fs:SetText("")
            for _, text in ipairs(v) do
                fs:SetText(text)
                if (fs:GetStringWidth() or 0) <= w then break end
                fs:SetText("")
            end
            if v.cut and (fs:GetText() or "") == "" then ns.FitText(fs, v[#v], w) end
        else
            ns.FitText(fs, v, w)
        end
        fs:SetWidth(w + 2)
    end
    t.wash:SetWidth(math.max(math.floor(tw * 0.6), 1))
end
local gmPanel, fillGM
local gmTab = "Банки"
local GM = {
    S = 30, STEP = 34, PAD = 4, MID_GAP = 12, COL_GAP = 14, ROW_GAP = 6, GRID_GAP = 8, FONT = 12,
    HDR = 16, ROW = 14, PROF = 19, SUB = 14, STAT = 13, BLOCK_GAP = 8, TAB_H = 20, TAB_GAP = 4,
    QMARK = "Interface\\Icons\\INV_Misc_QuestionMark",
    SLOT_TEX = "Interface\\Buttons\\UI-Quickslot2",
    SLOT_CUT = { 0.1875, 0.796875 },
    GLOW_TEX = "Interface\\Buttons\\UI-ActionButton-Border",
    GLOW_SCALE = 1.8,
    HILITE = "Interface\\Buttons\\ButtonHilight-Square",
    COIN = "Interface\\MoneyFrame\\UI-GoldIcon",
    SLOTS = {
        { "Голова", "HeadSlot", 1, 1 }, { "Шея", "NeckSlot", 1, 2 }, { "Плечи", "ShoulderSlot", 1, 3 },
        { "Спина", "BackSlot", 1, 4 }, { "Грудь", "ChestSlot", 1, 5 }, { "Рубашка", "ShirtSlot", 1, 6 },
        { "Гербовая накидка", "TabardSlot", 1, 7 }, { "Запястья", "WristSlot", 1, 8 },
        { "Кисти рук", "HandsSlot", 2, 1 }, { "Пояс", "WaistSlot", 2, 2 }, { "Ноги", "LegsSlot", 2, 3 },
        { "Ступни", "FeetSlot", 2, 4 }, { "Палец", "Finger0Slot", 2, 5 }, { "Палец", "Finger1Slot", 2, 6 },
        { "Аксессуар", "Trinket0Slot", 2, 7 }, { "Аксессуар", "Trinket1Slot", 2, 8 },
        { "Правая рука", "MainHandSlot", 3, 1 }, { "Левая рука", "SecondaryHandSlot", 3, 2 }, { "Дальний бой", "RangedSlot", 3, 3 },
    },
    WORN = "Надето", STATS = "Характеристики",
    ORDER = { "Гильдия", "Золото", "Таланты", "Профессии" },
    TABS = { "Банки", "Сумки", "Банк" },
    GROUPS = {
        { "Основные", { "Здоровье", "Сила", "Ловкость", "Выносливость", "Интеллект", "Дух", "Броня" } },
        { "Урон", { "Сила атаки", "Сила заклинаний", "Крит", "Крит заклинаний", "Скорость", "Меткость", "Мастерство" } },
        { "Оборона", { "Защита", "Уклонение", "Парирование", "Блок", "Устойчивость" } },
    },
    WHITE = { 0.95, 0.95, 0.95 }, GREY = { 0.62, 0.62, 0.62 }, GOLD = { 1, 0.82, 0 }, SUBGOLD = { 0.78, 0.71, 0.54 },
    GOOD = { 0.12, 1, 0 }, BAD = { 1, 0.3, 0.25 },
    LINE = { 1, 0.82, 0, 0.22 }, BAR_BG = { 1, 1, 1, 0.08 }, BAR = { 1, 0.82, 0, 0.75 },
}
local function gmPaint(b)
    b.glow:Hide()
    if not b.item then
        b.link = nil
        b.icon:SetTexture(b.value and GM.QMARK or b.empty)
        return true
    end
    local name, link, quality, _, _, _, _, _, _, tex = GetItemInfo(b.item)
    b.link = link
    b.icon:SetTexture(GetItemIcon(b.item) or tex or GM.QMARK)
    if quality and quality >= 2 then
        local r, g, bl = GetItemQualityColor(quality)
        b.glow:SetVertexColor(r, g, bl, 0.8)
        b.glow:Show()
    end
    return name ~= nil
end
local function gmView()
    local top = gmPanel.sf:GetVerticalScroll() or 0
    local bottom = top + (gmPanel.sf:GetHeight() or 0)
    if bottom <= top then bottom = math.huge end
    return top, bottom
end
local function gmClip()
    local top, bottom = gmView()
    for _, b in ipairs(gmPanel.live) do
        b:EnableMouse(b.y >= top and b.y + GM.S <= bottom)
    end
    for _, b in ipairs(gmPanel.tabs) do
        b:EnableMouse((b.y or 0) >= top and (b.y or 0) + GM.TAB_H <= bottom)
    end
end
local function gmWait()
    local wait = gmPanel.wait
    wait.stop, wait.tick = GetTime() + 10, 0
    wait:Show()
end
local function gmEnter(self)
    local x = (self:GetCenter() or 0) * self:GetEffectiveScale()
    local half = UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2
    GameTooltip:SetOwner(self, x > half and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    if self.item then
        GameTooltip:SetHyperlink(self.link or ("item:" .. self.item .. ":0:0:0:0:0:0:0"))
        if not self.ok then gmWait() end
    elseif self.value then
        GameTooltip:SetText(self.value, 1, 1, 1)
        if self.slotName then GameTooltip:AddLine(self.slotName, 0.62, 0.62, 0.62) end
    else
        GameTooltip:SetText(self.slotName or "", 1, 0.82, 0)
    end
    GameTooltip:Show()
end
local function gmButton()
    local S = GM.S
    local b = CreateFrame("Button", nil, gmPanel.child)
    b:SetWidth(S)
    b:SetHeight(S)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.slot = b:CreateTexture(nil, "OVERLAY")
    b.slot:SetTexture(GM.SLOT_TEX)
    b.slot:SetTexCoord(GM.SLOT_CUT[1], GM.SLOT_CUT[2], GM.SLOT_CUT[1], GM.SLOT_CUT[2])
    b.slot:SetWidth(S + 4)
    b.slot:SetHeight(S + 4)
    b.slot:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.slot:SetAlpha(0.8)
    b.over = CreateFrame("Frame", nil, b)
    b.over:SetAllPoints(b)
    b.over:SetFrameLevel(b:GetFrameLevel() + 1)
    b.glow = b.over:CreateTexture(nil, "OVERLAY")
    b.glow:SetTexture(GM.GLOW_TEX)
    b.glow:SetBlendMode("ADD")
    b.glow:SetWidth(math.floor(S * GM.GLOW_SCALE))
    b.glow:SetHeight(math.floor(S * GM.GLOW_SCALE))
    b.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.glow:Hide()
    b.count = b.over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.count:Hide()
    b:SetHighlightTexture(GM.HILITE, "ADD")
    b:SetScript("OnEnter", gmEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if self.link then HandleModifiedItemClick(self.link) end
    end)
    b:Hide()
    return b
end
local function gmCell(i)
    local b = gmPanel.cells[i]
    if b then return b end
    b = gmButton()
    gmPanel.cells[i] = b
    return b
end
local function gmPlace(b, x, y)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", gmPanel.child, "TOPLEFT", x, -y)
    b.x, b.y = x, y
    local key = tostring(b.item or b.value or b.empty)
    if b.key ~= key or not b.ok then
        b.key = key
        b.ok = gmPaint(b)
    end
    b:Show()
    tinsert(gmPanel.live, b)
    return b.ok
end
local function gmWorn(r)
    for _, b in ipairs(gmPanel.slots) do
        if b.slotName == r.label and not b.taken then
            b.taken, b.item, b.value = true, r.item, r.value
            return true
        end
    end
    return false
end
local function gmFS(head, size)
    local pool = gmPanel.fs
    pool.n = pool.n + 1
    local fs = pool[pool.n]
    if not fs then
        fs = ns.Text(gmPanel.child, GM.FONT)
        pool[pool.n] = fs
    end
    local path = head and ((GameFontNormal and GameFontNormal:GetFont()) or ns.FONT_HEAD) or ns.FONT_BODY
    fs:SetFont(path, size or GM.FONT)
    fs:ClearAllPoints()
    fs:Show()
    return fs
end
local function gmTex(path, c, w, h)
    local pool = gmPanel.tex
    pool.n = pool.n + 1
    local t = pool[pool.n]
    if not t then
        t = gmPanel.child:CreateTexture(nil, "ARTWORK")
        pool[pool.n] = t
    end
    t:SetTexture(path)
    t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    t:SetWidth(w)
    t:SetHeight(h)
    t:ClearAllPoints()
    t:Show()
    return t
end
local function gmAt(o, x, y)
    o:SetPoint("TOPLEFT", gmPanel.child, "TOPLEFT", x, -y)
end
local function gmText(x, y, maxW, text, c, size, head)
    local fs = gmFS(head, size)
    fs:SetTextColor(c[1], c[2], c[3])
    local w = ns.FitText(fs, text, math.max(maxW, 8))
    gmAt(fs, x, y)
    return w
end
local function gmHeader(x, y, w, title)
    local tw = gmText(x, y, w, title, GM.GOLD, 12, true)
    if tw + 12 < w then gmAt(gmTex(ns.WHITE, GM.LINE, w - tw - 6, 1), x + tw + 6, y + 7) end
    return GM.HDR
end
local function gmPair(x, y, w, label, value, c, coin)
    local right = x + w
    if coin then
        gmAt(gmTex(GM.COIN, GM.WHITE, 12, 12), right - 12, y)
        right = right - 14
    end
    local fs = gmFS()
    fs:SetTextColor(c[1], c[2], c[3])
    local vw = ns.FitText(fs, value, math.max(math.floor(w * 0.7), 8))
    gmAt(fs, right - vw, y)
    if label then gmText(x, y, right - vw - 6 - x, label, GM.GREY) end
end
local function gmGold(s)
    local out = {}
    for n in string.gmatch(string.gsub(s or "", "\226\136\146", "-"), "([%+%-]?%d[%d ]*)%s*з") do
        tinsert(out, (string.gsub(n, "%s+$", "")))
    end
    return out
end
local function gmGoldRow(x, y, w, r)
    local n = gmGold(r.value)
    if #n == 1 then
        local c = GM.WHITE
        if string.sub(n[1], 1, 1) == "+" then c = GM.GOOD elseif string.sub(n[1], 1, 1) == "-" then c = GM.BAD end
        gmPair(x, y, w, r.label, n[1], c, true)
    elseif #n == 2 then
        gmPair(x, y, w, r.label, n[1] .. " — " .. n[2], GM.WHITE, true)
    else
        gmPair(x, y, w, r.label, r.value, GM.WHITE)
    end
    return GM.ROW
end
local function gmTalentRow(x, y, w, r)
    local tree = string.match(r.value, "^(.-) %d+")
    local a, b, c = string.match(r.value, "%((%d+)/(%d+)/(%d+)%)%s*$")
    if not (tree and a) then
        gmPair(x, y, w, r.label, r.value, GM.WHITE)
        return GM.ROW
    end
    local pts = { tonumber(a), tonumber(b), tonumber(c) }
    local top = math.max(pts[1], pts[2], pts[3])
    local parts = {}
    for i = 1, 3 do parts[i] = ns.Color(pts[i] == top and top > 0 and "white" or "dim", tostring(pts[i])) end
    local fs = gmFS()
    fs:SetText(table.concat(parts, ns.Color("dim", "/")))
    local pw = fs:GetStringWidth() or 0
    gmAt(fs, x + w - pw, y)
    local lw = gmText(x, y, w, r.label, GM.GREY)
    gmText(x + lw + 6, y, w - lw - 6 - pw - 6, tree, GM.WHITE)
    return GM.ROW
end
local function gmProfRow(x, y, w, r)
    local a, b = string.match(r.value, "^(%d+)%s*/%s*(%d+)$")
    a, b = tonumber(a), tonumber(b)
    if not (a and b and b > 0) then
        gmPair(x, y, w, r.label, r.value, GM.WHITE)
        return GM.ROW
    end
    local fs = gmFS()
    fs:SetTextColor(GM.GREY[1], GM.GREY[2], GM.GREY[3])
    fs:SetText(a .. " / " .. b)
    local vw = fs:GetStringWidth() or 0
    gmAt(fs, x + w - vw, y)
    gmText(x, y, w - vw - 6, r.label, GM.WHITE)
    gmAt(gmTex(ns.WHITE, GM.BAR_BG, w, 3), x, y + 14)
    gmAt(gmTex(ns.WHITE, GM.BAR, math.max(math.floor(w * math.min(a / b, 1) + 0.5), 1), 3), x, y + 14)
    return GM.PROF
end
local function gmBlock(x, y, w, rows)
    local h = gmHeader(x, y, w, rows[1].section)
    for _, r in ipairs(rows) do
        if r.label == r.section then
            gmText(x, y + h, w, r.value, GM.WHITE)
            h = h + GM.ROW
        elseif r.section == "Золото" then
            h = h + gmGoldRow(x, y + h, w, r)
        elseif r.section == "Таланты" then
            h = h + gmTalentRow(x, y + h, w, r)
        elseif r.section == "Профессии" then
            h = h + gmProfRow(x, y + h, w, r)
        else
            gmPair(x, y + h, w, r.label, r.value, GM.WHITE)
            h = h + GM.ROW
        end
    end
    return h
end
local function gmStats(x, y, w, rows)
    local h = gmHeader(x, y, w, GM.STATS)
    local cols, where = {}, {}
    for gi, g in ipairs(GM.GROUPS) do
        cols[gi] = { title = g[1] }
        for _, label in ipairs(g[2]) do where[label] = gi end
    end
    for _, r in ipairs(rows) do tinsert(cols[where[r.label] or 1], r) end
    local cw = math.floor((w - 2 * GM.COL_GAP) / 3)
    local cx, deepest = x, 0
    for _, col in ipairs(cols) do
        if #col > 0 then
            gmText(cx, y + h, cw, col.title, GM.SUBGOLD, 11)
            for i, r in ipairs(col) do gmPair(cx, y + h + GM.SUB + (i - 1) * GM.STAT, cw, r.label, r.value, GM.WHITE) end
            deepest = math.max(deepest, #col)
            cx = cx + cw + GM.COL_GAP
        end
    end
    return h + GM.SUB + deepest * GM.STAT
end
local function gmMiddle(x, y0, w, blocks, stats)
    local cw = math.floor((w - GM.COL_GAP) / 2)
    local y = y0
    for i = 1, #blocks, 2 do
        local hl = gmBlock(x, y, cw, blocks[i])
        local hr = blocks[i + 1] and gmBlock(x + cw + GM.COL_GAP, y, cw, blocks[i + 1]) or 0
        y = y + math.max(hl, hr) + GM.BLOCK_GAP
    end
    if #stats > 0 then
        y = y + gmStats(x, y, w, stats)
    elseif y > y0 then
        y = y - GM.BLOCK_GAP
    end
    return y - y0
end
local function buildGM()
    gmPanel = CreateFrame("Frame", nil, frame)
    gmPanel:SetFrameLevel(frame:GetFrameLevel() + 30)
    gmPanel:EnableMouse(true)
    ns.StyleTip(gmPanel)
    gmPanel.title = ns.Text(gmPanel, 14, "LEFT", "head")
    gmPanel.title:SetPoint("TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, gmPanel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local sf = CreateFrame("ScrollFrame", "PlayerRaidsGMScroll", gmPanel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -34)
    sf:SetPoint("BOTTOMRIGHT", -30, 12)
    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(100)
    child:SetHeight(100)
    sf:SetScrollChild(child)
    gmPanel.sf, gmPanel.child = sf, child
    gmPanel.slots, gmPanel.cells, gmPanel.live, gmPanel.tabs = {}, {}, {}, {}
    gmPanel.fs, gmPanel.tex = { n = 0 }, { n = 0 }
    sf:HookScript("OnVerticalScroll", gmClip)
    sf:HookScript("OnSizeChanged", gmClip)
    for i, def in ipairs(GM.SLOTS) do
        local b = gmButton()
        local _, tex = GetInventorySlotInfo(def[2])
        b.slotName, b.empty = def[1], tex
        gmPanel.slots[i] = b
    end
    for i = 1, 26 do gmCell(i) end
    for i, name in ipairs(GM.TABS) do
        local b = ns.MakeButton(child, 12, nil, GM.TAB_H)
        ns.FitButton(b, name, 16)
        b.sec = name
        b.onClick = function(self)
            gmTab = self.sec
            fillGM()
        end
        b.tip = function(self)
            if self.off then ns.Tip(self, "ANCHOR_TOP", self.sec, "Нет в выгрузке") end
        end
        b:Hide()
        gmPanel.tabs[i] = b
    end
    local wait = CreateFrame("Frame", nil, gmPanel)
    wait:Hide()
    wait:SetScript("OnUpdate", function(self, e)
        self.tick = self.tick + e
        if self.tick < 0.5 then return end
        self.tick = 0
        local top, bottom = gmView()
        local done = true
        for _, b in ipairs(gmPanel.live) do
            if not b.ok and b.y + GM.S > top and b.y < bottom then b.ok = gmPaint(b) end
            if not b.ok then done = false end
        end
        if done or GetTime() > self.stop then self:Hide() end
    end)
    gmPanel.wait = wait
    gmPanel:Hide()
end
local function gmGrid(x, y, w, list)
    local S, STEP = GM.S, GM.STEP
    local cols = math.max(1, math.floor((w + STEP - S) / STEP))
    local pending = false
    for i, r in ipairs(list) do
        local b = gmCell(i)
        b.item, b.value, b.slotName = r.item, r.value, nil
        local n = tonumber(string.match(r.label or "", "^%s*(%d+)"))
        if n and n > 1 then
            b.count:SetText(n)
            b.count:Show()
        else
            b.count:Hide()
        end
        if not gmPlace(b, x + ((i - 1) % cols) * STEP, y + math.floor((i - 1) / cols) * STEP) then pending = true end
    end
    return math.ceil(#list / cols) * STEP - (STEP - S), pending
end
function fillGM()
    if not gmPanel or not gmPanel:IsShown() then return end
    local rows = ns.GMRows(state.id)
    if not rows then
        gmPanel:Hide()
        return
    end
    gmPanel:ClearAllPoints()
    gmPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", RX - 6, -(HEAD_Y + (state.bandH or BAND_H)))
    gmPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 32)
    gmPanel.title:SetText("Вещи: " .. (ns.NameOf(state.id) or ("#" .. tostring(state.id))))
    local w = math.max(size.rw - 36, 100)
    local S, STEP, P = GM.S, GM.STEP, GM.PAD
    gmPanel.child:SetWidth(w)
    for _, b in ipairs(gmPanel.slots) do
        b.taken, b.item, b.value = nil, nil, nil
        b:Hide()
    end
    for _, b in ipairs(gmPanel.cells) do b:Hide() end
    for i = 1, gmPanel.fs.n do gmPanel.fs[i]:Hide() end
    for i = 1, gmPanel.tex.n do gmPanel.tex[i]:Hide() end
    gmPanel.fs.n, gmPanel.tex.n = 0, 0
    wipe(gmPanel.live)
    local bySec, blocks, stats, lists, worn = {}, {}, {}, {}, false
    for _, name in ipairs(GM.TABS) do lists[name] = {} end
    for _, r in ipairs(rows) do
        if lists[r.section] then
            tinsert(lists[r.section], r)
        elseif r.section == GM.STATS then
            tinsert(stats, r)
        elseif r.section == GM.WORN and gmWorn(r) then
            worn = true
        else
            if not bySec[r.section] then
                bySec[r.section] = {}
                tinsert(blocks, bySec[r.section])
            end
            tinsert(bySec[r.section], r)
        end
    end
    local ordered = {}
    for _, name in ipairs(GM.ORDER) do
        if bySec[name] then tinsert(ordered, bySec[name]) end
    end
    for _, blk in ipairs(blocks) do
        local known = false
        for _, name in ipairs(GM.ORDER) do known = known or blk[1].section == name end
        if not known then tinsert(ordered, blk) end
    end
    local midX = worn and (P + S + GM.MID_GAP) or P
    local y0 = P
    local body = gmMiddle(midX, y0, w - 2 * midX, ordered, stats)
    local pending, y = false, y0 + body
    local tabY
    if worn then
        body = math.max(body, 8 * STEP - (STEP - S))
        local wy = y0 + body + GM.ROW_GAP
        for i, b in ipairs(gmPanel.slots) do
            local col, row = GM.SLOTS[i][3], GM.SLOTS[i][4]
            local x, by
            if col == 1 then
                x, by = P, y0 + (row - 1) * STEP
            elseif col == 2 then
                x, by = w - P - S, y0 + (row - 1) * STEP
            else
                x, by = math.floor((w - S) / 2) + (row - 2) * STEP, wy
            end
            if not gmPlace(b, x, by) then pending = true end
        end
        y = wy + S
        tabY = wy + S - GM.TAB_H
        local tw = (#GM.TABS - 1) * GM.TAB_GAP
        for _, b in ipairs(gmPanel.tabs) do tw = tw + b:GetWidth() end
        if P + tw > math.floor((w - S) / 2) - STEP - GM.MID_GAP then tabY = nil end
    end
    if not tabY then
        tabY = y + GM.GRID_GAP
        y = tabY + GM.TAB_H
    end
    local cur
    for _, name in ipairs({ gmTab, unpack(GM.TABS) }) do
        if not cur and #lists[name] > 0 then cur = name end
    end
    local tx = P
    for _, b in ipairs(gmPanel.tabs) do
        ns.SetButton(b, b.sec == cur, #lists[b.sec] == 0)
        b:ClearAllPoints()
        gmAt(b, tx, tabY)
        b.y = tabY
        b:Show()
        tx = tx + b:GetWidth() + GM.TAB_GAP
    end
    if cur then
        local h, wait = gmGrid(P, y + GM.GRID_GAP, w - 2 * P, lists[cur])
        y = y + GM.GRID_GAP + h
        pending = pending or wait
    end
    if pending then gmWait() else gmPanel.wait:Hide() end
    gmPanel.child:SetHeight(math.max(y + P, 1))
    if gmPanel.id ~= state.id then gmPanel.sf:SetVerticalScroll(0) end
    gmPanel.id = state.id
    gmClip()
end
local function toggleGM()
    if not gmPanel then buildGM() end
    if gmPanel:IsShown() then
        gmPanel:Hide()
        return
    end
    gmPanel:Show()
    fillGM()
end
local function showRight(on)
    for _, obj in ipairs(right.all) do
        if on then obj:Show() else obj:Hide() end
    end
    for _, obj in ipairs(right.cond) do obj:Hide() end
    if on then right.none:Hide() else right.none:Show() end
    if not on then
        if right.gm then right.gm:Hide() end
        if gmPanel then gmPanel:Hide() end
    end
end
local function renderCrest(class, shown)
    if ns.SetClassTexture(right.crest, class) then
        right.crest:SetVertexColor(1, 1, 1, 1)
        right.letter:Hide()
    else
        right.crest:SetTexture(ns.WHITE)
        right.crest:SetTexCoord(0, 1, 0, 1)
        right.crest:SetVertexColor(0.2, 0.2, 0.22, 1)
        right.letter:SetText(ns.FirstChar(shown))
        right.letter:Show()
    end
end
local function killLine(fs, n)
    fs:SetText(tostring(n))
    local a = n > 0 and 1 or 0.45
    if n > 0 then fs:SetTextColor(0.95, 0.95, 0.95) else fs:SetTextColor(0.36, 0.37, 0.4) end
    fs.icon:SetAlpha(a)
end
local function killItemW(fs)
    return 16 + 4 + math.floor((fs:GetStringWidth() or 12) + 0.5)
end
local function layoutKills(kw)
    local kt = right.killTile
    local step, nb = 0, 0
    for i, fs in ipairs(kt.boss) do
        if fs:IsShown() then
            nb = i
            step = math.max(step, killItemW(fs))
        end
    end
    local roles = {}
    for _, fs in ipairs(kt.role) do
        if fs:IsShown() then
            tinsert(roles, fs)
            step = math.max(step, killItemW(fs))
        end
    end
    step = step + 10
    local bossesW = math.max(nb, 1) * step - 10
    local rolesW = math.max(#roles, 1) * step - 10
    local oneRow = 9 + bossesW + 21 + rolesW + 9 <= kw
    local y2 = oneRow and 23 or 41
    for i, fs in ipairs(kt.boss) do
        fs.icon:ClearAllPoints()
        fs.icon:SetPoint("TOPLEFT", kt, "TOPLEFT", 9 + (i - 1) * step, -23)
    end
    local rx = oneRow and (9 + bossesW + 21) or 9
    for i, fs in ipairs(roles) do
        fs.icon:ClearAllPoints()
        fs.icon:SetPoint("TOPLEFT", kt, "TOPLEFT", rx + (i - 1) * step, -y2)
    end
    kt.sep:ClearAllPoints()
    if oneRow then
        kt.sep:SetPoint("TOPLEFT", kt, "TOPLEFT", 9 + bossesW + 10, -23)
        kt.sep:Show()
    else
        kt.sep:Hide()
    end
    kt:SetHeight(oneRow and TILE or (TILE + 18))
end
local function renderKills(rec, s)
    local kt = right.killTile
    local z = ns.ZONE[ns.ModeZone(state.mode) or ""] or ns.ZONES[1]
    local hist = rec and rec.hist and rec.hist[state.mode] or {}
    local h = hist[z.last]
    local n = h and h.kills or 0
    local fs = kt.boss[1]
    fs.icon:SetTexture(ns.BossIcon(z.last, state.mode))
    fs.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    killLine(fs, n)
    fs:Show()
    fs.icon:Show()
    kt.bossRows = { { ns.BossName(z.last), n } }
    kt.seasonRows = {}
    local row = s and #(state.allBosses or {}) > 1 and ns.ModeRow(s, state.mode)
    for _, code in ipairs(row and state.allBosses or {}) do
        local k = row.bossKills[code]
        if k then
            local text = tostring(k.kills or 0)
            if (k.flagged or 0) > 0 then text = text .. ns.Color(RT.unbuffHex, ", в анбафе " .. k.flagged) end
            tinsert(kt.seasonRows, { ns.BossName(code), text })
        end
    end
    local k = rec and rec.roleKills and rec.roleKills[state.mode] or {}
    kt.roleRows = {}
    local can = ns.ClassRoles(rec and rec.class)
    for i, role in ipairs({ "d", "h", "t" }) do
        local fs = kt.role[i]
        if can[role] then
            local n = k[role] or 0
            killLine(fs, n)
            tinsert(kt.roleRows, { ({ "ДД", "Хил", "Танк" })[i], n })
            fs:Show()
            fs.icon:Show()
        else
            fs:Hide()
            fs.icon:Hide()
        end
    end
end
local function killTip(self)
    local rows = {}
    for _, r in ipairs(self.bossRows or {}) do tinsert(rows, r) end
    for _, r in ipairs(self.roleRows or {}) do tinsert(rows, r) end
    if #(self.seasonRows or {}) > 0 then
        tinsert(rows, ns.Color("gold", "По боссам, " .. seasonCaption()))
        for _, r in ipairs(self.seasonRows) do tinsert(rows, r) end
    end
    ns.TipTable(self, "ANCHOR_TOP", "Убито боссов за все сезоны — " .. ns.ModeFull(state.mode), rows)
end
local function renderNote()
    if right.noteBox:HasFocus() then return end
    local text = ns.Note(state.id) or ""
    right.noteBox:SetText(text)
    if text == "" then right.notePh:Show() else right.notePh:Hide() end
end
local function fitLine(b, text, maxW)
    b.text:SetWidth(maxW)
    b.text:SetText(text)
    local w = math.min(math.floor((b.text:GetStringWidth() or maxW) + 4), maxW)
    b.text:SetWidth(w)
    b:SetWidth(w)
end
local function renderAka(rec, shown, x, rowMax)
    local names = right.names
    local others = ns.OtherNames(rec, shown)
    if #others == 0 then
        names:Hide()
        return BAND_H
    end
    local text = ns.Color("grey", "также известен как ") .. "|cffbfbfd9" .. others[1] .. "|r"
    if #others > 1 then text = text .. " " .. ns.Color("gold", "+" .. (#others - 1)) end
    names.text:SetWidth(rowMax - RX - 40)
    names.text:SetText(text)
    local w = math.floor((names.text:GetStringWidth() or 0) + 4)
    names:Show()
    if x + w <= rowMax then
        fitLine(names, text, rowMax - x)
        place(names, x, HEAD_Y + 23)
        return BAND_H
    end
    fitLine(names, text, rowMax - RX - 40)
    place(names, RX + 40, HEAD_Y + 25 + AKA_H)
    return BAND_H + AKA_H
end
local function renderGuild(x, maxW)
    local guild = right.guild
    local e = ns.GuildOf(state.id)
    if not e or e.cur == nil or maxW < 40 then
        guild:Hide()
        return 0
    end
    local past = 0
    for g in pairs(e.hist or {}) do
        if g ~= e.cur then past = past + 1 end
    end
    if e.cur then
        guild.text:SetTextColor(0.25, 1, 0.25)
        ns.FitText(guild.text, e.cur, maxW - (past > 0 and 22 or 0))
    else
        guild.text:SetTextColor(0.62, 0.62, 0.62)
        guild.text:SetText("без гильдии")
    end
    if past > 0 then guild.text:SetText(guild.text:GetText() .. " " .. ns.Color("gold", "+" .. past)) end
    local w = math.floor((guild.text:GetStringWidth() or 40) + 4)
    guild:SetWidth(w)
    place(guild, x, HEAD_Y + 23)
    guild:Show()
    return w + 8
end
local function renderName(rec, shown, maxW)
    local fs = right.name.text
    local text = shown
    local title = rec and ns.TitleOf(state.id)
    right.name.title = nil
    fs:SetWidth(maxW + 400)
    if title then
        local n, cut = ns.Utf8Len(title), title
        local minN = math.min(3, n)
        while n >= minN and n > 0 do
            fs:SetText(shown .. "|cffe8e8e8, " .. cut .. "|r")
            if (fs:GetStringWidth() or 0) <= maxW then
                text = fs:GetText()
                break
            end
            n = n - 1
            cut = ns.Utf8Cut(title, n) .. "…"
        end
        if cut ~= title or text == shown then right.name.title = title end
    end
    fs:SetText(text)
    fitLine(right.name, text, math.max(maxW, math.floor((fs:GetStringWidth() or 0) + 4)))
    if rec then fs:SetTextColor(ns.ClassColor(rec.class)) else fs:SetTextColor(0.9, 0.9, 0.9) end
end
local function paintAmbient(rec, shown, s)
    local class = rec and rec.class
    local ok = ns.HasClass(class)
    for _, t in ipairs({ right.glow, right.glowFade, right.glowLine, right.body1, right.body2, right.art }) do
        if ok then t:Show() else t:Hide() end
    end
    if not ok then return end
    local r, g, b = ns.AmbientRGB(class)
    ns.PaintWash(right.glow, class, 0, 0.3, "VERTICAL")
    ns.PaintWash(right.glowLine, class, 0.85, 0.05)
    ns.PaintWash(right.body1, class, 0.05, 0.14, "VERTICAL")
    ns.PaintWash(right.body2, class, 0.035, 0.05, "VERTICAL")
    local k = 0.13 * 0.78
    local fr, fg, fb = 0.085 * (1 - 0.13) + r * k, 0.073 * (1 - 0.13) + g * k, 0.058 * (1 - 0.13) + b * k
    right.glowFade:SetTexture(ns.WHITE)
    right.glowFade:SetGradientAlpha("HORIZONTAL", fr, fg, fb, 0, fr, fg, fb, 0.85)
    right.glowFade:SetWidth(math.max(math.floor(size.rw * 0.45), 1))
    local path = ns.ArtFor and ns.ArtFor(shown, class, s and s.spec)
    if not path then
        right.art:Hide()
        return
    end
    local w, h = size.rw + 10, state.bandH or BAND_H
    local frac = math.min(h / w, 1)
    right.art:SetTexture(path)
    right.art:SetTexCoord(0, 1, 0.1, 0.1 + frac)
    right.art:SetGradientAlpha("VERTICAL", 0.9, 0.9, 0.9, 0, 0.9, 0.9, 0.9, 0.45)
end
local function renderHeader(rec, shown, s, subText)
    local rw = size.rw
    local rowMax = RX + rw - 8
    local noteW = math.max(140, math.min(220, math.floor(rw * 0.34)))
    right.noteBox:SetWidth(noteW)
    renderCrest(rec and rec.class, shown)
    local hero = rec and ns.HeroDate(rec)
    right.hero.date = hero
    if hero then right.hero:Show() else right.hero:Hide() end
    local gm = ns.GMRows(state.id) and true or false
    if gm then right.gm:Show() else right.gm:Hide() end
    local nameMax = rw - 40 - noteW - 14 - 20 - (hero and (right.hero:GetWidth() + 6) or 0) - (gm and (right.gm:GetWidth() + 10) or 0)
    renderName(rec, shown, math.max(nameMax, 80))
    right.copy.value = shown
    right.copy:Show()
    local x = RX + 40
    right.spec:Hide()
    if not subText then
        local bits = {}
        local live = ns.LiveSpec and ns.LiveSpec(shown)
        local spec = live or (s and ns.SpecRu(s.spec))
        local icon = rec and ns.SpecIcon(rec.class, live or (s and s.spec))
        if icon then
            right.spec.icon:SetTexture(icon)
            right.spec.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            right.spec.name = spec
            right.spec.live = live
            right.spec.raid = s and ns.SpecRu(s.spec)
            place(right.spec, x, HEAD_Y + 22)
            right.spec:Show()
            x = x + 20
        elseif spec then
            tinsert(bits, spec)
        end
        if s and s.gs then tinsert(bits, "ilvl " .. s.gs) end
        local gsText = ns.GearScoreText and ns.GearScoreText(state.id)
        if gsText then tinsert(bits, gsText) end
        subText = table.concat(bits, ns.Color("dim", ", "))
    end
    local sub = right.sub
    sub:SetWidth(rowMax - x)
    sub:SetText(subText)
    local subW = math.min(math.floor((sub:GetStringWidth() or 0) + 1), rowMax - x)
    sub:SetWidth(math.max(subW, 1))
    place(sub, x, HEAD_Y + 23)
    if subW > 0 then x = x + subW + 8 end
    local lastText = (s and s.last and s.last ~= "") and ("последний рейд " .. ns.DayMonthYear(s.last)) or ""
    right.last:SetWidth(600)
    right.last:SetText(lastText)
    local lastW = lastText ~= "" and math.floor((right.last:GetStringWidth() or 0) + 2) or 0
    x = x + renderGuild(x, rowMax - x - (lastW > 0 and lastW + 8 or 0))
    if lastW > 0 then
        right.last:SetWidth(lastW)
        place(right.last, x, HEAD_Y + 23)
        x = x + lastW + 8
    end
    state.bandH = renderAka(rec, shown, x, rowMax)
    paintAmbient(rec, shown, s)
end
local function renderStatTile(t, st, season, badges, role)
    t.stat, t.badges, t.statSeason, t.role = st, badges, season, role
    if not st then
        t:Hide()
        return
    end
    local p = ns.StatScore(st)
    t.big:SetText("|cff" .. ns.ParseHex(p) .. p .. "|r")
    local spec = ns.SpecRu(st.spec) or st.spec or ""
    local ilvl = st.L and string.gsub(ns.StatIlvl(st), "^Илвл", "илвл") or nil
    t.l1 = { spec }
    if st.top and st.better then
        local b = math.floor(st.better)
        local mark = "|cff" .. ns.ParseHex(b) .. b .. "|r"
        t.l2 = { (ilvl or "илвл") .. ": " .. mark, "илвл: " .. mark }
    elseif st.top then
        t.l2 = nil
    else
        t.l2 = { ilvl or "по илвлу", "по илвлу" }
    end
    tileWash(t, ns.ParseRGB(p))
    t:Show()
end
local function statTip(self)
    local st = self.stat
    local unit = self.role == "h" and "хпс" or "дпс"
    local rows = {}
    if st.top then
        tinsert(rows, { "Лучше, чем у", ns.StatScore(st) .. "% спека" })
        if st.place and st.topOf then tinsert(rows, { "Место", ns.Thousands(st.place) .. " из " .. ns.Thousands(st.topOf) }) end
    end
    if st.better then tinsert(rows, { ns.StatIlvl(st), ns.StatBracket(st) }) end
    if st.avg then tinsert(rows, { "Средний " .. unit, ns.Thousands(st.avg) }) end
    local marks = {}
    for _, b in ipairs(ns.TopBadges(self.badges, self.role)) do tinsert(marks, ns.BadgeText(b)) end
    if #marks > 0 then tinsert(rows, { "Значки", ns.Color("gold", table.concat(marks, ", ")) }) end
    if st.top then tinsert(rows, "Место — по лучшему " .. unit .. " на каждом боссе.") end
    if st.better then tinsert(rows, "Илвл — средний " .. unit .. " среди одетых так же.") end
    ns.TipTable(self, "ANCHOR_TOP", (self.kText or "") .. ": " .. (ns.SpecRu(st.spec) or st.spec or "?"), rows,
        self.statSeason and ("сезон " .. self.statSeason) or nil)
end
local function renderAvgTile(rec, s)
    local t = right.tiles[4]
    local a = ns.RoleAverage(s, state.mode)
    if not ns.ClassRoles(rec and rec.class).h then a.h = nil end
    t.avg = a
    right.avgSpec = {}
    local cur = rec and ns.SeasonOf(rec, ns.CurrentSeason())
    for _, block in ipairs({ s or false, cur or false }) do
        for _, rs in ipairs(block and block.roleSpecs or {}) do
            if not right.avgSpec[rs.role] then
                right.avgSpec[rs.role] = { name = ns.SpecRu(rs.spec), icon = ns.SpecIcon(rec.class, rs.spec), n = rs.n }
            end
        end
    end
    t.lines = {}
    for _, r in ipairs({ "d", "h" }) do
        if a[r] then tinsert(t.lines, r) end
    end
    if #t.lines == 0 then
        t:Hide()
        return
    end
    tileWash(t, 1, 0.82, 0)
    t:Show()
end
local function seasonList(rec)
    local seasons = ns.SeasonsDesc()
    if #seasons == 0 and rec then
        for _, sn in ipairs(rec.seasonList) do tinsert(seasons, sn) end
    end
    return seasons
end
local function seasonEmpty(rec, sn)
    if not rec then return true end
    if sn == ALL then
        for _, x in ipairs(seasonList(rec)) do
            if not seasonEmpty(rec, x) then return false end
        end
        return true
    end
    return not ns.SeasonBlock(rec, sn)
end
local function seasonTip(self)
    if not self.off or not self.season then return end
    if self.season == ALL then
        ns.Tip(self, "ANCHOR_TOP", "Все сезоны", "Нет данных по игроку ни в одном скачанном сезоне")
        return
    end
    local rec = ns.Get(state.id)
    local _, why = ns.SeasonBlock(rec, self.season)
    local msg = ns.SeasonMessage(self.season, why)
    if why == "notdownloaded" and ns.HadSeason(rec, self.season) then
        msg = "Рейды в этом сезоне есть, но " .. string.gsub(msg, "^Сезон", "сезон")
    end
    ns.Tip(self, "ANCHOR_TOP", "Сезон " .. self.season, msg or ("Нет данных по игроку в сезоне " .. self.season))
end
local function fullSeason(rec, sn)
    if not rec or not seasonEmpty(rec, sn) then return sn end
    for _, x in ipairs(seasonList(rec)) do
        if not seasonEmpty(rec, x) then return x end
    end
    return sn
end
local function seasonLabel(sn)
    if sn == ALL then return "ВСЕ" end
    return tostring(sn)
end
local function renderSeasons(rec)
    local seasons = seasonList(rec)
    tinsert(seasons, 1, ALL)
    right.seasonN = #seasons
    local off, any = {}, false
    for i = 2, #seasons do
        off[i] = seasonEmpty(rec, seasons[i])
        if not off[i] then any = true end
    end
    off[1] = not any
    for i, b in ipairs(right.seasons) do
        local sn = seasons[i]
        b.season = sn
        if sn then
            b.text:SetText(seasonLabel(sn))
            b:SetWidth(sn == ALL and ALL_W or SEASON_W)
            ns.SetButton(b, state.season == sn, off[i])
        end
    end
    for i, b in ipairs(right.seasonList.items) do
        local sn = seasons[i]
        b.season = sn
        if sn then
            b.text:SetText(seasonLabel(sn))
            ns.SetButton(b, state.season == sn, off[i])
            b:Show()
        else
            b:Hide()
        end
    end
    right.seasonList:SetHeight(math.max(#seasons, 1) * 21 + 7)
    right.seasonDrop.text:SetText(state.season and seasonLabel(state.season) or "?")
    ns.PaintButton(right.seasonDrop)
end
local function tileTip(self)
    if self.stat then
        statTip(self)
        return
    end
    if self.avg then
        local rows = {}
        for _, r in ipairs({ "d", "h" }) do
            local a = self.avg[r]
            if a then
                local who = r == "h" and "Хил" or "ДД"
                local sp = right.avgSpec and right.avgSpec[r]
                if sp and sp.name then tinsert(rows, { who .. ", чаще всего", sp.name }) end
                tinsert(rows, { who .. ", в среднем", ns.Compact(a.avg) .. (r == "h" and " хпс" or " дпс") })
                tinsert(rows, { who .. ", боссов и рейдов", a.n .. " / " .. a.raids })
            end
        end
        ns.TipTable(self, "ANCHOR_TOP", "Средние показатели", rows, ns.ModeFull(state.mode) .. ", " .. seasonCaption())
        return
    end
    local b = self.best
    if not b then
        ns.TipTable(self, "ANCHOR_TOP", self.kText or "", { RT.bestFrom }, seasonCaption())
        return
    end
    local rows = { { "Босс", ns.BossName(b.boss) } }
    tinsert(rows, { "Сложность", ns.ModeFull(b.mode) })
    if b.unbuff then tinsert(rows, { "Анбаф", ns.Color(RT.unbuffHex, "да") }) end
    tinsert(rows, { "Дата", ns.DayMonthYearFull(b.date) })
    if b.value then
        tinsert(rows, { self.role == "h" and "Исцеление" or "Урон", ns.Compact(b.value) .. (self.role == "h" and " хпс" or " дпс") })
    end
    tinsert(rows, RT.bestFrom)
    ns.TipTable(self, "ANCHOR_TOP", self.kText or "", rows, seasonCaption())
end
function RT.modeDownloaded(mode)
    if state.season == ALL then
        for _, sn in ipairs(seasonList()) do
            if ns.ModeLoaded(sn, mode) then return true end
        end
        return false
    end
    return ns.ModeLoaded(state.season, mode)
end
local function renderTiles(rec, s)
    local best = { s and s.bestD, s and s.bestH, s and s.bestT }
    local roles = { "d", "h", "t" }
    local any = false
    local can = ns.ClassRoles(rec and rec.class)
    for i = 1, 3 do
        local t = right.tiles[i]
        if can[roles[i]] and ns.BestParse(best[i]) then
            tileFill(t, best[i], roles[i])
            t:Show()
            any = true
        else
            t:Hide()
        end
    end
    if not any then
        tileFill(right.tiles[1], nil, "d")
        right.tiles[1].l1 = "нет парсов"
        right.tiles[1]:Show()
    end
    renderAvgTile(rec, s)
    renderStatTile(right.tiles[5], s and s.stat, s and (s.statSeason or s.season), s and s.badges, "d")
    renderStatTile(right.tiles[6], s and s.statH, s and (s.statHSeason or s.season), s and s.badges, "h")
    right.badgeList = ns.TopBadges(s and s.badges)
    right.badgeSeason = s and (s.badgeSeason or s.season)
    for i, mode in ipairs(ns.MODES) do
        local tile = right.tiles5[i]
        local n = s and s.raids[mode] or 0
        tile.shown = n > 0 or mode == state.mode or RT.modeDownloaded(mode)
        styleTile(tile, n, state.mode == mode, ns.ModeMissing(s, mode), s and s.flagged[mode])
        if not tile.shown then
            tile:Hide()
            tile.mark:Hide()
        end
    end
end
local function subCols(x, w)
    local v = VAL_W + math.floor(math.max(w - VAL_W - PAR_MIN, 0) / 3)
    return { { x, v }, { x + v, math.max(w - v, 16) } }
end
function RT.fullMin()
    return VAL_W + PAR_MIN + 6
end
local function computeTab()
    local tw = size.rw - 24
    local cols = state.bosses or {}
    local withSeason = state.season == ALL
    local xs, x = {}, 0
    for c = 1, #TCOLS do
        if c ~= 2 or withSeason then
            xs[c] = x
            x = x + TCOLS[c][1] + RT.gap
        end
    end
    local area = tw - x
    local fit = math.max(1, math.floor(area / RT.fullMin()))
    local n = math.min(#cols, RT.max)
    local shown = math.min(n, fit)
    local off = 0
    if n > shown then off = math.max(0, math.min(state.bossOff or 0, n - shown)) end
    state.bossOff = off
    local tab = {
        tw = tw, nb = shown, bosses = {}, total = n, off = off, paged = n > shown,
        season = withSeason, xs = xs, x = x,
    }
    for i = 1, shown do tab.bosses[i] = cols[off + i] end
    tab.bw = shown > 0 and math.min(math.floor(area / shown), RT.colMax) or 0
    right.tab = tab
    return tab
end
local function bossHead(i, code)
    local tab = right.tab
    local fs = right.heads[i]
    HEAD_KEYS[i] = "b:" .. code
    local text = ns.BossName(code)
    fs:SetText(text)
    if (fs:GetStringWidth() or 0) > tab.bw - 6 - 17 then text = ns.BossShort(code) end
    headLabel(i, text, ns.BossIcon(code, state.mode))
end
function RT.layoutPager(tab)
    local p = right.pager
    local multi = #(ns.ModeBosses(state.mode, nil)) > 1
    if multi then p.pick:Show() else p.pick:Hide() end
    p.pick:ClearAllPoints()
    p.pick:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", 0, 18)
    if not tab.paged then
        p.prev:Hide()
        p.next:Hide()
        p.text:Hide()
        return
    end
    p.prev:ClearAllPoints()
    p.prev:SetPoint("LEFT", p.pick, "RIGHT", 4, 0)
    p.text:SetText((tab.off + 1) .. "-" .. (tab.off + tab.nb) .. " из " .. tab.total)
    p.text:ClearAllPoints()
    p.text:SetPoint("LEFT", p.prev, "RIGHT", 1, 0)
    p.next:ClearAllPoints()
    p.next:SetPoint("LEFT", p.prev, "RIGHT", math.floor((p.text:GetStringWidth() or 30) + 2), 0)
    if tab.off > 0 then p.prev:Enable() else p.prev:Disable() end
    if tab.off + tab.nb < tab.total then p.next:Enable() else p.next:Disable() end
    p.prev:Show()
    p.next:Show()
    p.text:Show()
end
local function layoutColumns()
    local tab = right.tab or computeTab()
    rscroll:SetWidth(tab.tw)
    RT.layoutPager(tab)
    for i, fs in ipairs(right.heads) do
        local x, w, y, on
        if i <= #TCOLS then
            x, w, y, on = tab.xs[i], TCOLS[i][1], 4, tab.xs[i] ~= nil
        else
            local b = i - #TCOLS
            on = b <= tab.nb
            x, w, y = tab.x + (b - 1) * tab.bw, tab.bw - 6, 19
        end
        local hb = right.headBtns[i]
        local hi = right.headIcons[i]
        if not on then
            fs:Hide()
            right.headArrows[i]:Hide()
            if hb then hb:Hide() end
            if hi then hi:Hide() end
        else
            fs:Show()
            if hb then
                hb.key = HEAD_KEYS[i]
                hb:SetWidth(w + 2)
                hb:ClearAllPoints()
                hb:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", x - 2, y - 2)
                hb:Show()
            end
            if hi and hi:IsShown() then
                hi:ClearAllPoints()
                hi:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", x, y)
                x, w = x + 17, w - 17
            end
            fs:SetWidth(math.max(w, 8))
            fs:ClearAllPoints()
            fs:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", x, y)
        end
    end
    for b = 1, RT.max do
        local on = b <= tab.nb
        local sc = subCols(tab.x + (b - 1) * tab.bw, tab.bw - 6)
        for k = 1, 2 do
            local fs = right.subs[(b - 1) * 2 + k]
            if on then
                fs:SetWidth(sc[k][2])
                fs:ClearAllPoints()
                fs:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", sc[k][1], 4)
                fs:Show()
            else
                fs:Hide()
            end
        end
    end
    for _, row in ipairs(rrows) do
        row:SetWidth(tab.tw)
        for c, fs in ipairs(row.cols) do
            fs:SetWidth(TCOLS[c][1])
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", tab.xs[c] or 0, 0)
        end
        for b = 1, math.max(tab.nb, 1) do
            local cs = row.cells[b]
            local x = tab.x + (b - 1) * tab.bw
            local sc = subCols(x, tab.bw - 6)
            cs.mark:ClearAllPoints()
            cs.mark:SetPoint("LEFT", row, "TOPLEFT", x - 4, -RROW_H / 2)
            cs.icon:ClearAllPoints()
            cs.icon:SetPoint("LEFT", row, "TOPLEFT", x, -RROW_H / 2)
            cs.val:SetWidth(sc[1][2] - ICON_W - 3)
            cs.val:ClearAllPoints()
            cs.val:SetPoint("TOPLEFT", row, "TOPLEFT", x + ICON_W + 3, 0)
            cs.par:SetWidth(sc[2][2])
            cs.par:ClearAllPoints()
            cs.par:SetPoint("TOPLEFT", row, "TOPLEFT", sc[2][1], 0)
            cs.btn:SetWidth(tab.bw - 2)
            cs.btn:ClearAllPoints()
            cs.btn:SetPoint("TOPLEFT", row, "TOPLEFT", x - 2, 0)
        end
    end
end
local function layoutBadges(y, left)
    local chips = right.badgeChips
    for _, c in ipairs(chips) do c:Hide() end
    local list = right.badgeList or {}
    local ws, total = {}, 0
    for i = 1, math.min(#list, #chips) do
        local c = chips[i]
        c.badge, c.season = list[i], right.badgeSeason
        c.text:SetText(ns.BadgeText(list[i]))
        ws[i] = math.floor((c.text:GetStringWidth() or 40) + 14)
        c:SetWidth(ws[i])
    end
    local n = #ws
    for i = 1, n do total = total + ws[i] + (i > 1 and 4 or 0) end
    local right0 = RX + size.rw - 8
    while n > 0 and right0 - total < left do
        total = total - ws[n] - (n > 1 and 4 or 0)
        n = n - 1
    end
    local x = right0 - total
    for i = 1, n do
        place(chips[i], x, y + 1)
        chips[i]:Show()
        x = x + ws[i] + 4
    end
end
local function badgeTip(self)
    if not self.badge then return end
    ns.TipTable(self, "ANCHOR_TOP", ns.BadgeText(self.badge), { ns.BadgeLine(self.badge) },
        self.season and ("сезон " .. self.season) or nil)
end
local function layoutCtx(y)
    local n = right.seasonN or 0
    local total = math.max(n - 1, 0) * 3 + 26
    for i = 1, math.min(n, #right.seasons) do total = total + right.seasons[i]:GetWidth() end
    local labelW = right.seasonLabel:GetStringWidth() or 40
    local x = RX + math.floor(labelW + 0.5) + 8
    right.seasonLabel:ClearAllPoints()
    right.seasonLabel:SetPoint("LEFT", frame, "TOPLEFT", RX, -(y + 10))
    right.seasonLabel:Show()
    if total > size.rw - 8 - labelW - 8 or n > #right.seasons then
        for _, b in ipairs(right.seasons) do b:Hide() end
        place(right.seasonDrop, x, y)
        right.seasonDrop:Show()
        x = x + right.seasonDrop:GetWidth() + 6
        place(right.seasonInfo, x, y)
        right.seasonInfo:Show()
        layoutBadges(y, x + right.seasonInfo:GetWidth() + 12)
        return
    end
    right.seasonDrop:Hide()
    for i, b in ipairs(right.seasons) do
        if i <= n then
            place(b, x, y)
            x = x + b:GetWidth() + 3
            b:Show()
        else
            b:Hide()
        end
    end
    place(right.seasonInfo, x + 3, y)
    right.seasonInfo:Show()
    layoutBadges(y, x + 3 + right.seasonInfo:GetWidth() + 12)
end
function RT.layoutModeTiles(y)
    local slot, nz, has25 = {}, 0, false
    for _, z in ipairs(ns.ZONES) do
        local any = false
        for i, mode in ipairs(ns.MODES) do
            local m = ns.MODE[mode]
            if m.zone == z.code and right.tiles5[i].shown then
                any = true
                if m.size == 25 then has25 = true end
            end
        end
        if any then
            slot[z.code] = nz
            nz = nz + 1
        end
    end
    local two = false
    for i, mode in ipairs(ns.MODES) do
        local t = right.tiles5[i]
        if t.shown then
            local m = ns.MODE[mode]
            local r = (m.size == 10 and has25) and 2 or 1
            if r == 2 then two = true end
            local x = slot[m.zone] * (2 * TILE_STEP + RT.zoneGap) + (m.heroic and 0 or TILE_STEP)
            place(t, RX + x, y + (r - 1) * (TILE + ROW2_GAP))
        end
    end
    return math.max(nz, 1) * (2 * TILE_STEP + RT.zoneGap) - RT.zoneGap - (TILE_STEP - TILE), two
end
local function layoutRight()
    local rw = size.rw
    right.none:SetWidth(rw - 20)
    right.none:ClearAllPoints()
    right.none:SetPoint("CENTER", frame, "TOPLEFT", RX + rw / 2, -200)
    right.empty:SetWidth(rw - 60)
    right.empty:ClearAllPoints()
    right.empty:SetPoint("TOP", rscroll, "TOP", 0, -30)
    local bandH = state.bandH or BAND_H
    right.band:SetHeight(bandH)
    local y = HEAD_Y + bandH + GAP
    if not state.dataView then return end
    layoutCtx(y)
    y = y + 20 + GAP
    local shownTiles = {}
    for _, t in ipairs(right.tiles) do
        if t:IsShown() then tinsert(shownTiles, t) end
    end
    local nt = math.max(#shownTiles, 1)
    local tw = math.floor((rw - 6 * (nt - 1)) / nt)
    for i, t in ipairs(shownTiles) do
        t:SetWidth(tw)
        t:SetHeight(BEST_H)
        fitTile(t, tw)
        place(t, RX + (i - 1) * (tw + 6), y)
    end
    y = y + BEST_H + GAP + SKULL_PAD
    local gridW, two = RT.layoutModeTiles(y)
    local kx = gridW + RT.killGap
    local kw = math.max(rw - kx, 120)
    right.killTile:SetWidth(kw)
    place(right.killTile, RX + kx, y)
    layoutKills(kw)
    y = y + (two and (2 * TILE + ROW2_GAP + 8) or (TILE + 18)) + GAP
    local top = y + HEAD_TOP
    place(rscroll, RX, top)
    local rows = math.floor((size.h - BOTTOM - top) / RROW_H)
    rows = math.max(1, math.min(rows, #rrows))
    size.rrows = rows
    rscroll:SetHeight(rows * RROW_H)
    layoutColumns()
end
local function buildRaidList(s)
    raids, nums = {}, {}
    if not s then return end
    local sorted = sortRaids(s.byMode[state.mode])
    local split = state.season == ALL and sortOpt() == "date"
    local last, n = nil, 0
    for _, raid in ipairs(sorted) do
        if split and raid.season ~= last then
            tinsert(raids, { sep = raid.season })
            last = raid.season
        end
        n = n + 1
        tinsert(raids, raid)
        nums[#raids] = n
    end
end
local function hideSeasonList()
    if right.seasonList then right.seasonList:Hide() end
end
local function renderMissing()
    showRight(true)
    for _, obj in ipairs(right.dataOnly) do obj:Hide() end
    right.empty:Hide()
    raids = {}
    state.dataView = false
    local shown = ns.NameOf(state.id) or ("#" .. tostring(state.id))
    renderHeader(nil, shown, nil, ns.Color("grey", ns.DataProblem() or ns.MissingText()))
    renderNote()
    layoutRight()
    updateRaids()
    local note = not ns.DataProblem() and liveNote(ns.NameOf(state.id), nil)
    if note then
        right.empty:SetText(note)
        right.empty:Show()
    end
    fillGM()
end
local function renderRaidView()
    showRight(false)
    right.none:Hide()
    raids = {}
    updateRaids()
    right.empty:Hide()
    ns.RaidPanelShow(frame, RX, HEAD_Y, size.rw, size.h - BOTTOM - HEAD_Y - 4)
end
function RT.columnSeason()
    if state.season ~= ALL then return state.season end
    for _, sn in ipairs(seasonList()) do
        if ns.ModeLoaded(sn, state.mode) then return sn end
    end
    return nil
end
function RT.allMessage()
    for _, sn in ipairs(seasonList()) do
        if ns.SeasonLoaded(sn) then return "Ни в одном скачанном сезоне у персонажа нет рейдов" end
    end
    return "Сезоны не скачаны — отметьте их в ManacodeUpdate"
end
local function renderRight(keepScroll)
    hideSeasonList()
    if state.list == "raid" and state.raidView and ns.RaidPanelShow then
        renderRaidView()
        return
    end
    if ns.RaidPanelHide then ns.RaidPanelHide() end
    local rec = state.id and ns.Get(state.id)
    if not rec then
        if state.id then
            renderMissing()
            return
        end
        showRight(false)
        right.none:SetText(ns.DataProblem() or "Выберите игрока слева")
        raids = {}
        updateRaids()
        return
    end
    showRight(true)
    renderNote()
    state.dataView = true
    local s, why
    if state.season == ALL then
        s = ns.AllSeasons(rec, seasonList(rec))
        state.seasonMsg = not s and RT.allMessage() or nil
    else
        s, why = ns.SeasonBlock(rec, state.season)
        state.seasonMsg = not s and ns.SeasonMessage(state.season, why) or nil
    end
    state.allBosses = ns.ModeBosses(state.mode, RT.columnSeason())
    state.bosses = RT.columns(state.allBosses, ns.ModeZone(state.mode) or "icc")
    state.modeMsg = ns.ModeMissing(s, state.mode) and ns.ModeMessage(type(state.season) == "number" and state.season or nil, state.mode) or nil
    local shown = ns.NameOf(state.id) or rec.name
    renderHeader(rec, shown, s)
    renderTiles(rec, s)
    renderSeasons(rec)
    renderKills(rec, s)
    for i, text in ipairs({ "№", "Сезон", "Дата", "Вайпы", "Ilvl" }) do headLabel(i, text) end
    if state.offMode ~= state.mode then
        state.bossOff, state.offMode = 0, state.mode
    end
    local tab = computeTab()
    for b = 1, RT.max do
        if b <= tab.nb then bossHead(#TCOLS + b, tab.bosses[b]) else headLabel(#TCOLS + b, "") end
    end
    buildRaidList(s)
    RT.fillPicker()
    layoutRight()
    if not keepScroll then resetScroll(rscroll) end
    updateRaids()
    fillGM()
end
local function pickMode(s)
    if not ns.MODE[state.mode] then state.mode = ns.MODES[1] end
    if not s then return end
    if #s.byMode[state.mode] > 0 then return end
    for _, mode in ipairs(ns.MODES) do
        if #s.byMode[mode] > 0 then
            state.mode = mode
            return
        end
    end
    if (s.raids[state.mode] or 0) > 0 then return end
    for _, mode in ipairs(ns.MODES) do
        if (s.raids[mode] or 0) > 0 then
            state.mode = mode
            return
        end
    end
end
local function pickSeason(sn)
    state.season = sn
    local rec = ns.Get(state.id)
    if sn == ALL then
        pickMode(ns.AllSeasons(rec, seasonList(rec)))
    else
        pickMode((ns.SeasonBlock(rec, sn)))
    end
    renderRight()
end
local function selectId(id)
    state.raidView = false
    if right.noteBox and right.noteBox:HasFocus() then right.noteBox:ClearFocus() end
    state.id = id
    ns.HideCopy()
    local rec = id and ns.Get(id)
    state.season = fullSeason(rec, state.season or ns.CurrentSeason() or (rec and rec.seasonList[1]))
    if state.season == ALL then
        pickMode(ns.AllSeasons(rec, seasonList(rec)))
    else
        pickMode((ns.SeasonBlock(rec, state.season)))
    end
    updateLeft()
    renderRight()
end
local function updateStatus()
    local problem = ns.DataProblem()
    if problem then
        status:SetText(problem)
        ns.SetButton(howBtn, true)
        return
    end
    ns.SetButton(howBtn, false)
    local meta = ns.Meta()
    local n = tonumber(meta.count) or ns.Total()
    status:SetText("выгрузка " .. ns.BakedText() .. ", "
        .. n .. " " .. ns.Plural(n, "игрок", "игрока", "игроков"))
    if right.placeVer then right.placeVer() end
end
local function applySize()
    size.w = math.floor(frame:GetWidth() + 0.5)
    size.h = math.floor(frame:GetHeight() + 0.5)
    size.rw = size.w - RX - 12
    local lrowsN = math.floor((size.h - BOTTOM - LIST_TOP) / LROW_H)
    size.lrows = math.max(1, math.min(lrowsN, #lrows))
    lscroll:SetHeight(size.lrows * LROW_H)
    status:SetWidth(math.max(size.w - 240, 100))
    if right.placeVer then right.placeVer() end
end
local function relayout()
    applySize()
    updateLeft()
    renderRight(true)
end
local function poolSize(rowH, top)
    local screen = (GetScreenHeight and GetScreenHeight()) or 1200
    local scale = UIParent:GetEffectiveScale() or 1
    local h = math.max(screen, UIParent:GetHeight() or 0, 1200 / scale)
    return math.ceil((h - top) / rowH) + 1
end
local function layoutTabs()
    local inRaid = ns.InRaid and ns.InRaid()
    if not inRaid and state.list == "raid" then
        state.list = "all"
        state.raidView = false
    end
    local n = inRaid and 3 or 2
    local bw = math.floor((LEFT_W - 2 * (n - 1)) / n)
    for i, b in ipairs(listSeg) do
        if i <= n then
            b:SetWidth(bw)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * (bw + 2), -68)
            ns.SetButton(b, b.list == state.list)
            b:Show()
        else
            b:Hide()
        end
    end
end
local function buildLeft()
    searchBox = CreateFrame("EditBox", "PlayerRaidsSearch", frame, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", 20, -44)
    searchBox:SetWidth(LEFT_W - 4)
    searchBox:SetHeight(20)
    searchBox:SetAutoFocus(false)
    searchBox:SetFont(ns.FONT_BODY, 13)
    placeholder = ns.Text(searchBox, 13)
    placeholder:SetTextColor(0.4, 0.4, 0.4)
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText("Ник")
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then placeholder:Show() else placeholder:Hide() end
        if text == state.search then return end
        state.search = text
        fillLeft()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if ids[1] then selectId(ids[1]) end
    end)
    ns.BlurOnClick(searchBox)
    listSeg = {}
    for i, it in ipairs({ { "all", "Все" }, { "ren", "Ренеймы" }, { "raid", "Рейд" } }) do
        local b = ns.MakeButton(frame, 13, 60, 20)
        b.text:SetText(it[2])
        b.list = it[1]
        b.onClick = function(self)
            local was = state.list
            state.list = self.list
            state.raidView = self.list == "raid"
            for _, o in ipairs(listSeg) do ns.SetButton(o, o.list == state.list) end
            fillLeft()
            if state.raidView or was == "raid" then renderRight() end
        end
        ns.SetButton(b, it[1] == state.list)
        listSeg[i] = b
    end
    layoutTabs()
    listLabel = ns.Text(frame, 12)
    dim(listLabel)
    listLabel:SetWidth(LEFT_W + 20)
    listLabel:SetPoint("TOPLEFT", 14, -94)
    lscroll = CreateFrame("ScrollFrame", "PlayerRaidsList", frame, "FauxScrollFrameTemplate")
    lscroll:SetPoint("TOPLEFT", 12, -LIST_TOP)
    lscroll:SetWidth(LEFT_W)
    lscroll:SetHeight(size.lrows * LROW_H)
    lscroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LROW_H, updateLeft)
    end)
    for i = 1, poolSize(LROW_H, LIST_TOP) do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(LROW_H)
        row:SetWidth(LEFT_W)
        row:SetPoint("TOPLEFT", lscroll, "TOPLEFT", 0, -(i - 1) * LROW_H)
        row.sel = ns.Rect(row, 1, 0.82, 0, 0.14, "BORDER")
        row.sel:SetAllPoints()
        row.accent = ns.Rect(row, 1, 0.82, 0, 0.9, "ARTWORK")
        row.accent:SetWidth(2)
        row.accent:SetPoint("TOPLEFT", 0, 0)
        row.accent:SetPoint("BOTTOMLEFT", 0, 0)
        row:SetHighlightTexture(ns.WHITE)
        row:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.08)
        row.text = ns.Text(row, 13)
        row.text:SetPoint("LEFT", 6, 0)
        row.text:SetWidth(LEFT_W - 8)
        row.text:SetHeight(LROW_H)
        row:SetScript("OnClick", function(self)
            if self.id then selectId(self.id) end
        end)
        row:Hide()
        lrows[i] = row
    end
end
local function buildTile(i)
    local t = CreateFrame("Frame", nil, frame)
    t:SetWidth(200)
    t:SetHeight(BEST_H)
    t:SetBackdrop(THIN)
    t:SetBackdropColor(0, 0, 0, 0.38)
    t:SetBackdropBorderColor(0.3, 0.26, 0.18, 1)
    t.wash = t:CreateTexture(nil, "BORDER")
    t.wash:SetPoint("TOPLEFT", 1, -1)
    t.wash:SetPoint("BOTTOMLEFT", 1, 1)
    t.wash:SetWidth(100)
    t.wash:Hide()
    t.accent = ns.Rect(t, 1, 1, 1, 1, "ARTWORK")
    t.accent:SetWidth(3)
    t.accent:SetPoint("TOPLEFT", 1, -1)
    t.accent:SetPoint("BOTTOMLEFT", 1, 1)
    t.k = ns.Text(t, 12)
    gold(t.k)
    t.k:SetHeight(14)
    t.k:SetPoint("TOPLEFT", 10, -4)
    t.kText = ({ "Лучший парс ДД", "Лучший парс хил", "Лучший парс танк", "Средние показатели", "Рейтинг ДД", "Рейтинг хил" })[i]
    t.kShort = ({ "Парс ДД", "Парс хил", "Парс танк", "Средние" })[i]
    t:EnableMouse(true)
    t:SetScript("OnEnter", tileTip)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t.big = ns.Text(t, 22)
    t.big:SetHeight(24)
    t.big:SetPoint("TOPLEFT", 10, -19)
    t.s1 = ns.Text(t, 11)
    t.s1:SetTextColor(0.78, 0.78, 0.78)
    t.s2 = ns.Text(t, 11)
    grey(t.s2)
    for _, fs in ipairs({ t.s1, t.s2 }) do fs:SetHeight(12) end
    if i == 4 then
        t.rows = {}
        for k = 1, 2 do
            local row = { icon = t:CreateTexture(nil, "ARTWORK"), fs = ns.Text(t, 12) }
            row.icon:SetWidth(12)
            row.icon:SetHeight(12)
            row.fs:SetHeight(13)
            row.fs:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
            t.rows[k] = row
        end
    end
    return t
end
local TILE_BACKDROP = {
    bgFile = ns.WHITE,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local function buildModeTile(i, mode)
    local m = ns.MODE[mode]
    local tile = CreateFrame("Button", nil, frame)
    tile:SetWidth(TILE)
    tile:SetHeight(TILE)
    tile:SetBackdrop(TILE_BACKDROP)
    tile:SetBackdropColor(0, 0, 0, 0.5)
    tile:SetHighlightTexture(ns.WHITE)
    tile:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.12)
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
    tile.icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -3, 3)
    tile.icon:SetTexture(ns.ZoneIcon(mode))
    tile.skull = tile:CreateTexture(nil, "OVERLAY")
    tile.skull:SetTexture(ns.SKULL.tex)
    tile.skull:SetTexCoord(ns.SKULL.coord[1], ns.SKULL.coord[2], ns.SKULL.coord[3], ns.SKULL.coord[4])
    tile.skull:SetHeight(20)
    tile.skull:SetWidth(math.floor(20 * ns.SKULL.ratio + 0.5))
    tile.skull:SetPoint("CENTER", tile, "TOPRIGHT", -3, -3)
    if not m.heroic then tile.skull:Hide() end
    tile.size = tile:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    tile.size:SetPoint("CENTER", tile, "CENTER", 0, 0)
    tile.size:SetShadowColor(0, 0, 0, 1)
    tile.size:SetShadowOffset(1, -1)
    tile.size:SetText("0")
    tile.tag = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.tag:SetFont(ns.FONT_BODY, 11)
    tile.tag:SetTextColor(0.9, 0.9, 0.9)
    tile.tag:SetShadowColor(0, 0, 0, 1)
    tile.tag:SetShadowOffset(1, -1)
    tile.tag:SetPoint("TOPLEFT", tile, "TOPLEFT", 5, -4)
    tile.tag:SetText(m.size)
    tile.unbuff = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.unbuff:SetFont(ns.FONT_BODY, 13)
    tile.unbuff:SetTextColor(RT.unbuffRGB[1], RT.unbuffRGB[2], RT.unbuffRGB[3])
    tile.unbuff:SetShadowColor(0, 0, 0, 1)
    tile.unbuff:SetShadowOffset(1, -1)
    if m.heroic then
        tile.unbuff:SetPoint("TOP", tile.skull, "BOTTOM", 0, 2)
    else
        tile.unbuff:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -5, -4)
    end
    tile.unbuff:SetText("А")
    tile.unbuff:Hide()
    tile.mark = ns.Rect(frame, 1, 0.82, 0, 0.9, "ARTWORK")
    tile.mark:SetHeight(2)
    tile.mark:SetWidth(TILE - 8)
    tile.mark:SetPoint("TOP", tile, "BOTTOM", 0, -1)
    tile:SetScript("OnClick", function()
        state.mode = mode
        renderRight()
    end)
    tile:SetScript("OnEnter", function(self)
        local rows = { { "Рейдов", self.count or 0 } }
        if (self.flagged or 0) > 0 then tinsert(rows, { "Из них с анбафом", ns.Color(RT.unbuffHex, self.flagged) }) end
        if self.missing then tinsert(rows, ns.Color("ff9933", "Не скачаны — отметьте их в ManacodeUpdate")) end
        ns.TipTable(self, "ANCHOR_TOP", m.full, rows, seasonCaption())
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return tile
end
local function buildRaidRow(i)
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(RROW_H)
    row:SetWidth(400)
    row:SetPoint("TOPLEFT", rscroll, "TOPLEFT", 0, -(i - 1) * RROW_H)
    row.odd = ns.Rect(row, 1, 1, 1, 0.03)
    row.odd:SetAllPoints()
    row:SetHighlightTexture(ns.WHITE)
    row:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.08)
    row.cols = {}
    for c = 1, #TCOLS do
        local fs = ns.Text(row, 13, TCOLS[c][2])
        fs:SetHeight(RROW_H)
        row.cols[c] = fs
    end
    row.cells = {}
    for b = 1, RT.max do
        local cs = {}
        cs.icon = row:CreateTexture(nil, "ARTWORK")
        cs.icon:SetWidth(ICON_W)
        cs.icon:SetHeight(ICON_W)
        cs.mark = ns.Rect(row, RT.unbuffRGB[1], RT.unbuffRGB[2], RT.unbuffRGB[3], 1, "ARTWORK")
        cs.mark:SetWidth(2)
        cs.mark:SetHeight(12)
        cs.val = ns.Text(row, 13)
        cs.par = ns.Text(row, 12)
        for _, fs in ipairs({ cs.val, cs.par }) do fs:SetHeight(RROW_H) end
        cs.btn = CreateFrame("Button", nil, row)
        cs.btn:SetHeight(RROW_H)
        cs.btn:SetHighlightTexture(ns.WHITE)
        cs.btn:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.1)
        cs.btn:SetScript("OnEnter", cellTip)
        cs.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        hideCell(cs)
        row.cells[b] = cs
    end
    row.sep = ns.Text(row, 11, "LEFT", "head")
    row.sep:SetTextColor(1, 0.82, 0)
    row.sep:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.sep:Hide()
    row:SetScript("OnEnter", raidTip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:Hide()
    return row
end
local function nameTip(self)
    local rec = ns.Get(state.id)
    local lines = ns.NameHistory(state.id, rec)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if #lines > 0 then
        GameTooltip:SetText("История ников", 1, 0.82, 0)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1) end
    else
        GameTooltip:SetText(ns.NameOf(state.id) or (rec and rec.name) or "", 1, 0.82, 0)
    end
    if right.name.title then GameTooltip:AddLine(right.name.title, 0.91, 0.91, 0.91) end
    local class = rec and ns.ClassRu(rec.class)
    if class then GameTooltip:AddLine(class, 0.9, 0.9, 0.9) end
    GameTooltip:AddLine("id " .. tostring(state.id), 0.5, 0.52, 0.55)
    GameTooltip:Show()
end
local function guildTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Гильдии", 1, 0.82, 0)
    local lines = ns.GuildLines(state.id)
    if #lines == 0 then
        GameTooltip:AddLine("гильдия ещё не встречалась", 0.62, 0.62, 0.62)
    end
    for _, g in ipairs(lines) do
        GameTooltip:AddDoubleLine(g.name, ns.DayText(g.first) .. " - " .. ns.DayText(g.last), 1, 1, 1, 0.62, 0.62, 0.62)
    end
    GameTooltip:AddLine("по вашим наблюдениям", 0.42, 0.44, 0.46)
    GameTooltip:Show()
end
local function heroTip(self)
    if not self.date then return end
    ns.TipTable(self, "ANCHOR_BOTTOM", "Герой Нордскола",
        { "Король-лич в ЦЛК 25 анбаф, у рейда ни одного вайпа", { "Дата", ns.DayMonthYearFull(self.date) } })
end
local function hoverLine(onEnter, justify)
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(100)
    b:SetHeight(16)
    b.text = ns.Text(b, 13, justify)
    b.text:SetPoint(justify == "RIGHT" and "RIGHT" or "LEFT", 0, 0)
    b.text:SetHeight(16)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
local function buildHeader(keep)
    local lvl = frame:GetFrameLevel() + 2
    right.band = keep(CreateFrame("Frame", nil, frame))
    right.band:SetPoint("TOPLEFT", frame, "TOPLEFT", RX - 6, -HEAD_Y)
    right.band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -HEAD_Y)
    right.band:SetHeight(BAND_H)
    right.band:SetBackdrop({ bgFile = ns.WHITE })
    right.band:SetBackdropColor(0, 0, 0, 0.22)
    local bandLine = line(right.band, 0.18)
    bandLine:SetPoint("BOTTOMLEFT", right.band, "BOTTOMLEFT", 0, 0)
    bandLine:SetPoint("BOTTOMRIGHT", right.band, "BOTTOMRIGHT", 0, 0)
    right.glow = right.band:CreateTexture(nil, "BORDER")
    right.glow:SetPoint("TOPLEFT", right.band, "TOPLEFT", 0, 0)
    right.glow:SetPoint("BOTTOMRIGHT", right.band, "BOTTOMRIGHT", 0, 1)
    right.glowFade = right.band:CreateTexture(nil, "ARTWORK")
    right.glowFade:SetPoint("TOPRIGHT", right.band, "TOPRIGHT", 0, 0)
    right.glowFade:SetPoint("BOTTOMRIGHT", right.band, "BOTTOMRIGHT", 0, 1)
    right.glowFade:SetWidth(180)
    right.glowLine = right.band:CreateTexture(nil, "OVERLAY")
    right.glowLine:SetPoint("TOPLEFT", right.band, "TOPLEFT", 0, 0)
    right.glowLine:SetPoint("TOPRIGHT", right.band, "TOPRIGHT", 0, 0)
    right.glowLine:SetHeight(2)
    right.body1 = keep(frame:CreateTexture(nil, "BORDER"))
    right.body1:SetPoint("TOPLEFT", frame, "TOPLEFT", RX - 6, -HEAD_Y)
    right.body1:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -HEAD_Y)
    right.body1:SetHeight(220)
    right.body2 = keep(frame:CreateTexture(nil, "BORDER"))
    right.body2:SetPoint("TOPLEFT", right.body1, "BOTTOMLEFT", 0, 0)
    right.body2:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 32)
    right.art = keep(frame:CreateTexture(nil, "ARTWORK"))
    right.art:SetPoint("TOPLEFT", right.band, "TOPLEFT", 0, 0)
    right.art:SetPoint("BOTTOMRIGHT", right.band, "BOTTOMRIGHT", 0, 1)
    right.crestBox = keep(CreateFrame("Frame", nil, frame))
    right.crestBox:SetWidth(32)
    right.crestBox:SetHeight(32)
    right.crestBox:SetPoint("TOPLEFT", RX, -(HEAD_Y + 5))
    right.crestBox:SetFrameLevel(lvl)
    local shadow = ns.Rect(right.crestBox, 0, 0, 0, 0.6, "BACKGROUND")
    shadow:SetPoint("TOPLEFT", 2, -2)
    shadow:SetPoint("BOTTOMRIGHT", 2, -2)
    right.crest = right.crestBox:CreateTexture(nil, "ARTWORK")
    right.crest:SetAllPoints()
    local ring = right.crestBox:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(RING_TEX)
    ring:SetWidth(54)
    ring:SetHeight(54)
    ring:SetPoint("CENTER", 0, 0)
    right.letter = ns.Text(right.crestBox, 17, "CENTER", "head")
    right.letter:SetTextColor(0.9, 0.9, 0.9)
    right.letter:SetPoint("CENTER", 0, 0)
    right.name = keep(hoverLine(nameTip))
    right.name:SetFrameLevel(lvl)
    right.name:SetHeight(18)
    right.name.text:SetFont((GameFontNormal and GameFontNormal:GetFont()) or ns.FONT_HEAD, 17)
    right.name.text:SetHeight(18)
    right.name:SetPoint("TOPLEFT", frame, "TOPLEFT", RX + 40, -(HEAD_Y + 3))
    right.last = ns.Text(right.band, 11)
    grey(right.last)
    right.last:SetHeight(14)
    right.sub = ns.Text(right.band, 13)
    right.sub:SetHeight(14)
    right.noteBox = keep(CreateFrame("EditBox", "PlayerRaidsNote", frame, "InputBoxTemplate"))
    right.noteBox:SetHeight(20)
    right.noteBox:SetWidth(160)
    right.noteBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -(HEAD_Y + 4))
    right.noteBox:SetFrameLevel(lvl)
    right.noteBox:SetAutoFocus(false)
    right.noteBox:SetMaxLetters(ns.NOTE_MAX)
    right.noteBox:SetFont(ns.FONT_BODY, 13)
    right.noteBox:SetTextColor(1, 0.6, 0.2)
    right.notePh = ns.Text(right.noteBox, 12)
    dim(right.notePh)
    right.notePh:SetPoint("LEFT", 2, 0)
    right.notePh:SetText("заметка")
    right.noteBox:SetScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" then right.notePh:Show() else right.notePh:Hide() end
    end)
    right.noteBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    right.noteBox:SetScript("OnEscapePressed", function(self)
        self:SetText(ns.Note(state.id) or "")
        self:ClearFocus()
    end)
    right.noteBox:SetScript("OnEditFocusLost", function(self)
        if state.id then ns.SetNote(state.id, self:GetText()) end
    end)
    right.noteBox:SetScript("OnEnter", function(self)
        ns.Tip(self, "ANCHOR_TOP", "Заметка", "Ваша пометка об игроке, до " .. ns.NOTE_MAX .. " знаков", "Enter — сохранить, Esc — отменить")
    end)
    right.noteBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.BlurOnClick(right.noteBox)
    right.gm = ns.MakeButton(frame, 12, nil, 20)
    ns.FitButton(right.gm, "Вещи", 18)
    right.gm:SetFrameLevel(lvl)
    right.gm:SetPoint("RIGHT", right.noteBox, "LEFT", -10, 0)
    right.gm.onClick = function() toggleGM() end
    right.gm.tip = function(self) ns.Tip(self, "ANCHOR_TOP", "Данные для ГМ", "Надетые вещи, банки, золото, таланты и профессии", "Кнопка есть только у ГМ с ключом") end
    right.gm:Hide()
    right.copy = CreateFrame("Button", nil, frame)
    right.copy:SetFrameLevel(lvl)
    right.copy:SetPoint("LEFT", right.name, "RIGHT", 4, 0)
    right.copy:SetWidth(16)
    right.copy:SetHeight(16)
    local ct = right.copy:CreateTexture(nil, "ARTWORK")
    ct:SetAllPoints()
    ct:SetTexture(ns.COPY_TEX)
    right.copy:SetHighlightTexture(ns.WHITE)
    right.copy:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.22)
    right.copy:SetScript("OnEnter", function(self) ns.Tip(self, "ANCHOR_TOP", "Скопировать ник") end)
    right.copy:SetScript("OnLeave", function() GameTooltip:Hide() end)
    right.copy:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        if self.value then ns.ShowCopy(self, self.value, 240) end
    end)
    right.hero = CreateFrame("Button", nil, frame)
    right.hero:SetFrameLevel(lvl)
    right.hero:SetPoint("LEFT", right.copy, "RIGHT", 6, 0)
    right.hero:SetHeight(18)
    right.hero:SetBackdrop(THIN)
    right.hero:SetBackdropColor(0.2, 0.15, 0.02, 0.95)
    right.hero:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    local hi = right.hero:CreateTexture(nil, "ARTWORK")
    hi:SetWidth(14)
    hi:SetHeight(14)
    hi:SetPoint("LEFT", 2, 0)
    hi:SetTexture(ns.HERO_ICON)
    hi:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ht = ns.Text(right.hero, 12, "LEFT", "head")
    ht:SetPoint("LEFT", hi, "RIGHT", 3, 0)
    ht:SetText("ГН")
    right.hero:SetWidth(math.floor(2 + 14 + 3 + (ht:GetStringWidth() or 16) + 6))
    right.hero:SetScript("OnEnter", heroTip)
    right.hero:SetScript("OnLeave", function() GameTooltip:Hide() end)
    right.names = hoverLine(nameTip)
    right.names:SetFrameLevel(lvl)
    right.names.text:SetFont(ns.FONT_BODY, 11)
    right.names:SetHeight(14)
    right.names.text:SetHeight(14)
    right.guild = hoverLine(guildTip)
    right.guild:SetFrameLevel(lvl)
    right.guild:SetHeight(14)
    right.guild.text:SetHeight(14)
    right.spec = CreateFrame("Button", nil, frame)
    right.spec:SetFrameLevel(lvl)
    right.spec:SetWidth(16)
    right.spec:SetHeight(16)
    right.spec.icon = right.spec:CreateTexture(nil, "ARTWORK")
    right.spec.icon:SetAllPoints()
    right.spec:SetScript("OnEnter", function(self)
        if not self.name then return end
        local lines = {}
        if self.live then tinsert(lines, "сейчас, по осмотру: " .. self.live) end
        if self.raid then tinsert(lines, "в рейдах: " .. self.raid) end
        ns.Tip(self, "ANCHOR_TOP", self.name, unpack(lines))
    end)
    right.spec:SetScript("OnLeave", function() GameTooltip:Hide() end)
    right.cond = { right.copy, right.hero, right.names, right.guild, right.spec }
end
local function roundButton(tex, coord, tip)
    local disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(20)
    b:SetHeight(20)
    b.ring = b:CreateTexture(nil, "BORDER")
    b.ring:SetTexture(disc)
    b.ring:SetAllPoints()
    b.ring:SetVertexColor(1, 0.82, 0)
    local inner = b:CreateTexture(nil, "ARTWORK")
    inner:SetTexture(disc)
    inner:SetVertexColor(0.07, 0.07, 0.08, 0.95)
    inner:SetWidth(17)
    inner:SetHeight(17)
    inner:SetPoint("CENTER")
    b.icon = b:CreateTexture(nil, "OVERLAY")
    if coord > 0.065 and SetPortraitToTexture then
        SetPortraitToTexture(b.icon, tex)
    else
        b.icon:SetTexture(tex)
        b.icon:SetTexCoord(coord, 1 - coord, coord, 1 - coord)
    end
    b.icon:SetWidth(13)
    b.icon:SetHeight(13)
    b.icon:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self)
        self.ring:SetVertexColor(1, 1, 1)
        self.icon:SetWidth(15)
        self.icon:SetHeight(15)
        tip(self)
    end)
    b:SetScript("OnLeave", function(self)
        self.ring:SetVertexColor(1, 0.82, 0)
        self.icon:SetWidth(13)
        self.icon:SetHeight(13)
        GameTooltip:Hide()
    end)
    return b
end
local function seasonsInfoTip(self)
    local rows = {}
    for _, e in ipairs(ns.SEASON_CIRCLE) do
        tinsert(rows, { "Сезон " .. e.sn, e.dates })
    end
    ns.TipTable(self, "ANCHOR_TOP", "Сезоны WoW Circle", rows)
end
local function buildCtx(keep, data)
    right.seasonInfo = keep(data(roundButton("Interface\\FriendsFrame\\InformationIcon", 0.0625, seasonsInfoTip)))
    right.seasonLabel = keep(data(ns.Text(frame, 11, "LEFT", "head")))
    right.seasonLabel:SetTextColor(0.75, 0.62, 0.3)
    right.seasonLabel:SetText("СЕЗОН")
    right.badgeChips = {}
    for i = 1, 3 do
        local c = CreateFrame("Frame", nil, frame)
        c:SetHeight(BADGE_H)
        c:SetBackdrop(THIN)
        c:SetBackdropColor(0.2, 0.15, 0.02, 0.95)
        c:SetBackdropBorderColor(1, 0.82, 0, 0.6)
        c.text = ns.Text(c, 12, "CENTER")
        c.text:SetPoint("CENTER", c, "CENTER", 0, 0)
        c.text:SetTextColor(1, 0.82, 0)
        c:EnableMouse(true)
        c:SetScript("OnEnter", badgeTip)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c:Hide()
        right.badgeChips[i] = c
        tinsert(right.cond, c)
    end
    right.seasons = {}
    for i = 1, 10 do
        local b = keep(data(ns.MakeButton(frame, 13, SEASON_W, 20)))
        b.onClick = function(self) if self.season then pickSeason(self.season) end end
        b.tip = seasonTip
        right.seasons[i] = b
    end
    right.seasonDrop = keep(data(ns.MakeButton(frame, 13, 42, 20)))
    right.seasonDrop.textX = -6
    right.seasonDrop.text:SetPoint("CENTER", right.seasonDrop, "CENTER", -6, 0)
    local arrow = right.seasonDrop:CreateTexture(nil, "OVERLAY")
    arrow:SetWidth(12)
    arrow:SetHeight(12)
    arrow:SetPoint("RIGHT", -3, -1)
    arrow:SetTexture(ns.ARROW_DOWN_TEX)
    right.seasonDrop.onClick = function(self)
        if right.seasonList:IsShown() then
            right.seasonList:Hide()
            return
        end
        right.seasonList:ClearAllPoints()
        right.seasonList:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        right.seasonList:Show()
    end
    right.seasonList = CreateFrame("Frame", nil, frame)
    right.seasonList:SetWidth(54)
    right.seasonList:SetFrameLevel(frame:GetFrameLevel() + 15)
    right.seasonList:EnableMouse(true)
    ns.StyleTip(right.seasonList)
    right.seasonList:Hide()
    right.seasonList.items = {}
    for i = 1, 16 do
        local b = ns.MakeButton(right.seasonList, 13, 42, 20)
        b:SetPoint("TOP", right.seasonList, "TOP", 0, -4 - (i - 1) * 21)
        b.onClick = function(self)
            right.seasonList:Hide()
            if self.season then pickSeason(self.season) end
        end
        b.tip = seasonTip
        right.seasonList.items[i] = b
    end
end
local function headTip(self)
    local tab = right.tab
    local code = tab and tab.bosses[self.boss]
    if not code then return end
    local rows = { { "дпс", "урон, у хилов — исцеление" }, { "парс", "0-100, лучший кил — 100" } }
    if ns.UNBUFF_ZONE[ns.ModeZone(state.mode) or ""] then tinsert(rows, { ns.Color(RT.unbuffHex, "Красная черта"), "кил в анбафе" }) end
    tinsert(rows, "Парс — сколько процентов килов этого босса хуже, среди того же спека, сложности и сезона.")
    ns.TipTable(self, "ANCHOR_TOP", ns.BossName(code), rows, "клик по заголовку — сортировка по парсу")
end
function RT.fillPicker()
    local p = right.picker
    if not p or not p:IsShown() then return end
    local zone = ns.ModeZone(state.mode) or "icc"
    local z = ns.ZONE[zone]
    p.zone = zone
    p.title:SetText("Боссы в таблице: " .. z.title)
    local sel = RT.picked(zone)
    local y = 30
    for i, row in ipairs(p.rows) do
        local code = z.bosses[i]
        row.code = code
        if code then
            row.cb:SetChecked(sel[code] and 1 or nil)
            row.icon:SetTexture(ns.BossIcon(code, state.mode))
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.label:SetText(ns.BossName(code))
            row.cb:ClearAllPoints()
            row.cb:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -y)
            row.cb:Show()
            row.icon:Show()
            row.label:Show()
            y = y + 22
        else
            row.cb:Hide()
            row.icon:Hide()
            row.label:Hide()
        end
    end
    p.reset:ClearAllPoints()
    p.reset:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -(y + 6))
    p:SetHeight(y + 6 + 20 + 12)
end
function RT.buildPicker()
    local p = CreateFrame("Frame", nil, frame)
    p:SetWidth(210)
    p:SetFrameLevel(frame:GetFrameLevel() + 20)
    p:EnableMouse(true)
    ns.StyleTip(p)
    p:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    p:Hide()
    p.title = ns.Text(p, 13, "LEFT", "head")
    p.title:SetPoint("TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    p.rows = {}
    for i = 1, RT.max do
        local row = {}
        row.cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        row.cb:SetWidth(24)
        row.cb:SetHeight(24)
        row.icon = p:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(16)
        row.icon:SetHeight(16)
        row.icon:SetPoint("LEFT", row.cb, "RIGHT", 2, 0)
        row.label = ns.Text(p, 13)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
        row.cb:SetScript("OnClick", function(self)
            if not row.code then return end
            if not RT.setPicked(p.zone, row.code, self:GetChecked()) then
                self:SetChecked(1)
                return
            end
            state.bossOff = 0
            renderRight(true)
        end)
        p.rows[i] = row
    end
    p.reset = ns.MakeButton(p, 12, nil, 20)
    ns.FitButton(p.reset, "Сбросить", 18)
    p.reset.tip = function(self) ns.Tip(self, "ANCHOR_TOP", "Сбросить", "Вернуть боссов по умолчанию") end
    p.reset.onClick = function()
        if PlayerRaidsDB.opts and type(PlayerRaidsDB.opts.bossCols) == "table" then PlayerRaidsDB.opts.bossCols[p.zone] = nil end
        state.bossOff = 0
        renderRight(true)
        RT.fillPicker()
    end
    right.picker = p
end
function RT.togglePicker(anchor)
    if not right.picker then RT.buildPicker() end
    local p = right.picker
    if p:IsShown() then
        p:Hide()
        return
    end
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    p:Show()
    RT.fillPicker()
end
local function buildTable(keep, data)
    local function raidOnly(obj) tinsert(right.raidOnly, obj); return obj end
    rscroll = CreateFrame("ScrollFrame", "PlayerRaidsRaidTable", frame, "FauxScrollFrameTemplate")
    rscroll:SetWidth(400)
    rscroll:SetHeight(size.rrows * RROW_H)
    rscroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, RROW_H, updateRaids)
    end)
    keep(data(raidOnly(rscroll)))
    right.heads, right.headIcons, right.headArrows = {}, {}, {}
    for i = 1, #TCOLS + RT.max do
        local justify = i <= #TCOLS and TCOLS[i][2] or "LEFT"
        local fs = keep(data(raidOnly(ns.Text(frame, 12, justify))))
        fs:SetHeight(14)
        fs.justify = justify
        dim(fs)
        right.heads[i] = fs
        local ar = keep(data(raidOnly(frame:CreateTexture(nil, "OVERLAY"))))
        ar:SetWidth(12)
        ar:SetHeight(12)
        right.headArrows[i] = ar
        if i > #TCOLS then
            local hi = keep(data(raidOnly(frame:CreateTexture(nil, "OVERLAY"))))
            hi:SetWidth(14)
            hi:SetHeight(14)
            right.headIcons[i] = hi
        end
    end
    local meter = ns.Text(frame, 13)
    meter:Hide()
    meter:SetText("88.8к")
    VAL_W = ICON_W + 3 + math.floor((meter:GetStringWidth() or 30) + 4)
    meter:SetFont(ns.FONT_BODY, 12)
    meter:SetText("100")
    PAR_MIN = math.floor((meter:GetStringWidth() or 32) + 2)
    right.subs = {}
    for b = 1, RT.max do
        for k, text in ipairs({ "дпс", "парс" }) do
            local fs = keep(data(raidOnly(ns.Text(frame, 11))))
            fs:SetHeight(13)
            fs:SetTextColor(0.5, 0.52, 0.55)
            fs:SetText(text)
            right.subs[(b - 1) * 2 + k] = fs
        end
    end
    right.headBtns = {}
    for i = 2, #TCOLS + RT.max do
        local t = CreateFrame("Button", nil, frame)
        t:SetHeight(18)
        t.key = HEAD_KEYS[i]
        t:SetHighlightTexture(ns.WHITE)
        t:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.12)
        if i > #TCOLS then
            t.boss = i - #TCOLS
            t:SetScript("OnEnter", headTip)
            t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        t:SetScript("OnClick", function(self)
            local key, desc = sortOpt()
            if key == self.key then setSort(key, not desc) else setSort(self.key, true) end
            renderRight()
        end)
        right.headBtns[i] = keep(data(raidOnly(t)))
    end
    local pager = {}
    pager.pick = keep(data(raidOnly(ns.MakeButton(frame, 12, nil, 16))))
    ns.FitButton(pager.pick, "Боссы", 14)
    pager.pick.onClick = function(self) RT.togglePicker(self) end
    pager.pick.tip = function(self) ns.Tip(self, "ANCHOR_TOP", "Боссы в таблице", "Какие столбцы показывать в этом рейде") end
    for _, it in ipairs({ { "prev", RT.PREV, -1 }, { "next", RT.NEXT, 1 } }) do
        local b = keep(data(raidOnly(CreateFrame("Button", nil, frame))))
        b:SetWidth(18)
        b:SetHeight(18)
        b:SetNormalTexture(it[2] .. "Up")
        b:SetPushedTexture(it[2] .. "Down")
        b:SetDisabledTexture(it[2] .. "Disabled")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        local dir = it[3]
        b:SetScript("OnClick", function()
            local tab = right.tab
            if not tab or not tab.paged then return end
            state.bossOff = tab.off + dir * tab.nb
            renderRight(true)
        end)
        b:SetScript("OnEnter", function(self)
            ns.Tip(self, "ANCHOR_TOP", dir < 0 and "Предыдущие боссы" or "Следующие боссы", "Все отмеченные не влезают в ширину окна")
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pager[it[1]] = b
    end
    pager.text = keep(data(raidOnly(ns.Text(frame, 11))))
    grey(pager.text)
    pager.text:SetHeight(14)
    right.pager = pager
    local headLine = keep(data(raidOnly(line(frame, 0.18))))
    headLine:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", 0, 2)
    headLine:SetPoint("BOTTOMRIGHT", rscroll, "TOPRIGHT", 0, 2)
    for i = 1, poolSize(RROW_H, 200) do rrows[i] = buildRaidRow(i) end
end
local function buildRight()
    right.all, right.dataOnly, right.raidOnly = {}, {}, {}
    local function keep(obj) tinsert(right.all, obj); return obj end
    local function data(obj) tinsert(right.dataOnly, obj); return obj end
    buildHeader(keep)
    buildCtx(keep, data)
    right.tiles = {}
    for i = 1, 6 do right.tiles[i] = keep(data(buildTile(i))) end
    right.tiles5 = {}
    for i, mode in ipairs(ns.MODES) do
        local tile = keep(data(buildModeTile(i, mode)))
        keep(data(tile.mark))
        right.tiles5[i] = tile
    end
    local kt = keep(data(CreateFrame("Frame", nil, frame)))
    kt:SetHeight(TILE + 18)
    kt:SetBackdrop(THIN)
    kt:SetBackdropColor(0, 0, 0, 0.38)
    kt:SetBackdropBorderColor(0.3, 0.26, 0.18, 1)
    kt:EnableMouse(true)
    kt:SetScript("OnEnter", killTip)
    kt:SetScript("OnLeave", function() GameTooltip:Hide() end)
    kt.title = ns.Text(kt, 12)
    gold(kt.title)
    kt.title:SetPoint("TOPLEFT", 9, -4)
    kt.title:SetText("Убито боссов за все сезоны")
    kt.sep = ns.Rect(kt, 1, 0.82, 0, 0.2, "ARTWORK")
    kt.sep:SetWidth(1)
    kt.sep:SetHeight(16)
    kt.boss, kt.role = {}, {}
    local b = ns.Text(kt, 13)
    b:SetHeight(16)
    b.icon = kt:CreateTexture(nil, "ARTWORK")
    b.icon:SetWidth(16)
    b.icon:SetHeight(16)
    b:ClearAllPoints()
    b:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    kt.boss[1] = b
    for i = 1, 3 do
        local r = ns.Text(kt, 13)
        r:SetHeight(16)
        r.icon = kt:CreateTexture(nil, "ARTWORK")
        r.icon:SetWidth(16)
        r.icon:SetHeight(16)
        r.icon:SetTexture(ns.ROLE_TEX)
        local rc = ns.ROLE_COORD[({ "d", "h", "t" })[i]]
        r.icon:SetTexCoord(rc[1] / 64, rc[2] / 64, rc[3] / 64, rc[4] / 64)
        r:ClearAllPoints()
        r:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
        kt.role[i] = r
    end
    right.killTile = kt
    buildTable(keep, data)
    right.empty = ns.Text(frame, 13, "CENTER")
    dim(right.empty)
    right.empty:SetWidth(400)
    right.empty:SetText("Нет рейдов в этой сложности")
    right.none = ns.Text(frame, 14, "CENTER")
    dim(right.none)
end
local OPTIONS = {
    { head = "Карточка игрока по Alt" },
    { note = "Зажмите Alt и наведите на ник: рядом появится карточка с рейдами игрока. Где она работает:" },
    { "chat", "ники в чате" },
    { "world", "игроки в мире под курсором" },
    { "frames", "рамки группы, рейда и цели, VuhDo" },
    { "guild", "список гильдии" },
    { head = "Окно «Рейды игроков»" },
    { "altOpen", "Alt+клик по нику открывает игрока в окне" },
    { "follow", "взяли игрока в цель — окно показывает его" },
    { "updates", "сообщать в чат о новой версии аддона" },
}
local function checkRow(parent, y, text)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", 8, -y)
    local label = ns.Text(parent, 13)
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(text)
    cb.label = label
    return cb
end
local function buildOptions()
    optPanel = CreateFrame("Frame", nil, frame)
    optPanel:SetWidth(320)
    optPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -32)
    optPanel:SetFrameLevel(frame:GetFrameLevel() + 20)
    optPanel:EnableMouse(true)
    ns.StyleTip(optPanel)
    optPanel:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    optPanel:Hide()
    local title = ns.Text(optPanel, 14, "LEFT", "head")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Настройки")
    local close = CreateFrame("Button", nil, optPanel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    optPanel.checks = {}
    local y = 34
    for _, o in ipairs(OPTIONS) do
        if o.head then
            local h = ns.Text(optPanel, 13)
            gold(h)
            h:SetPoint("TOPLEFT", 12, -(y + 6))
            h:SetText(o.head)
            y = y + 26
        elseif o.note then
            local t = ns.Text(optPanel, 12)
            grey(t)
            t:SetWidth(296)
            t:SetPoint("TOPLEFT", 12, -y)
            t:SetText(o.note)
            y = y + math.floor((t:GetStringHeight() or 14) + 6)
        else
            local cb = checkRow(optPanel, y, o[2])
            cb.key = o[1]
            cb:SetScript("OnClick", function(self)
                ns.SetOpt(self.key, self:GetChecked())
            end)
            tinsert(optPanel.checks, cb)
            y = y + 24
        end
    end
    y = y + 8
    local sep = line(optPanel, 0.2)
    sep:SetPoint("TOPLEFT", optPanel, "TOPLEFT", 10, -y)
    sep:SetPoint("TOPRIGHT", optPanel, "TOPRIGHT", -10, -y)
    local hint = ns.Text(optPanel, 12)
    grey(hint)
    hint:SetWidth(296)
    hint:SetPoint("TOPLEFT", 12, -(y + 8))
    hint:SetText("Какие сезоны и рейды скачивать, выбирается в ManacodeUpdate.")
    y = y + 8 + math.floor((hint:GetStringHeight() or 14) + 0.5)
    optPanel:SetHeight(y + 16)
end
local function showOptions(on)
    if on == nil then on = not optPanel:IsShown() end
    if not on then
        optPanel:Hide()
        return
    end
    if howPanel then howPanel:Hide() end
    for _, cb in ipairs(optPanel.checks) do cb:SetChecked(ns.Opt(cb.key) and 1 or nil) end
    optPanel:Show()
end
local function reloadButton(parent)
    local b = ns.MakeButton(parent, 12, nil, 18)
    ns.FitButton(b, "/reload", 18)
    b.tip = function(self) ns.Tip(self, "ANCHOR_TOP", "Перезагрузить интерфейс", "Перечитать данные после ManacodeUpdate") end
    b.onClick = function() ReloadUI() end
    return b
end
local function urlBox(parent)
    local eb = CreateFrame("EditBox", "PlayerRaidsUrl", parent, "InputBoxTemplate")
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetFont(ns.FONT_BODY, 12)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= ns.DATA_URL then
            self:SetText(ns.DATA_URL)
            self:HighlightText()
        end
    end)
    return eb
end
local function buildHow()
    howPanel = CreateFrame("Frame", nil, frame)
    howPanel:SetWidth(440)
    howPanel:SetHeight(262)
    howPanel:SetPoint("CENTER", frame, "CENTER", 0, 10)
    howPanel:SetFrameLevel(frame:GetFrameLevel() + 30)
    howPanel:EnableMouse(true)
    ns.StyleTip(howPanel)
    howPanel:SetBackdropColor(0.05, 0.045, 0.035, 0.98)
    howPanel:SetBackdropBorderColor(1, 0.82, 0, 1)
    howPanel:Hide()
    local title = ns.Text(howPanel, 16, "LEFT", "head")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Как обновить данные")
    local close = CreateFrame("Button", nil, howPanel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local intro = ns.Text(howPanel, 13)
    intro:SetWidth(408)
    intro:SetPoint("TOPLEFT", 16, -42)
    grey(intro)
    intro:SetText("Правила аддонов не дают им выходить в интернет и получать данные на лету. Поэтому статистику рейдов нужно скачать готовыми файлами. Выберите один из двух способов.")
    local h1 = ns.Text(howPanel, 13, "LEFT", "head")
    h1:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -12)
    h1:SetText("1. Через ManacodeUpdate")
    local b1 = ns.Text(howPanel, 13)
    b1:SetWidth(408)
    b1:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -4)
    b1:SetText("Запустите ManacodeUpdate, выберите PlayerRaidsInfo, отметьте сезоны и рейды и нажмите «Скачать выбранное». Затем в игре наберите /reload.")
    local h2 = ns.Text(howPanel, 13, "LEFT", "head")
    h2:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -12)
    h2:SetText("2. Вручную")
    local b2 = ns.Text(howPanel, 13)
    b2:SetWidth(408)
    b2:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -4)
    local cur = ns.CurrentSeason() or 7
    b2:SetText("Откройте страницу по ссылке. all.zip — всё сразу, если не знаете, что выбрать, качайте его. Остальные архивы — по одному файлу: players.zip нужен всегда, s"
        .. cur .. ".zip — сезон " .. cur .. ", s" .. cur .. "_icc25h.zip — его ЦЛК 25 гер, и так далее."
        .. " Распакуйте в Interface\\AddOns с заменой файлов, пароль raids-circle. Затем /reload.")
    howPanel.url = urlBox(howPanel)
    howPanel.url:SetPoint("TOPLEFT", b2, "BOTTOMLEFT", 6, -8)
    howPanel.url:SetWidth(400)
    local hint = ns.Text(howPanel, 12)
    dim(hint)
    hint:SetPoint("TOPLEFT", howPanel.url, "BOTTOMLEFT", -6, -4)
    hint:SetText("Ссылку в игре не открыть: щёлкните по полю, Ctrl+C — скопировать")
    local textH = 0
    for _, fs in ipairs({ intro, h1, b1, h2, b2, hint }) do textH = textH + (fs:GetStringHeight() or 14) end
    howPanel:SetHeight(math.floor(42 + textH + 12 + 4 + 12 + 4 + 8 + 20 + 4 + 16 + 22 + 14 + 0.5))
    local ok = ns.MakeButton(howPanel, 13, 96, 22)
    ok.text:SetText("Закрыть")
    ok:SetPoint("BOTTOMLEFT", howPanel, "BOTTOM", 5, 12)
    local reload = reloadButton(howPanel)
    reload:SetHeight(22)
    reload:SetPoint("BOTTOMRIGHT", howPanel, "BOTTOM", -5, 12)
    ok.onClick = function() howPanel:Hide() end
end
local function toggleHow()
    if not howPanel then buildHow() end
    if howPanel:IsShown() then
        howPanel:Hide()
        return
    end
    if optPanel then optPanel:Hide() end
    howPanel:Show()
    howPanel.url:SetText(ns.DATA_URL)
    howPanel.url:SetFocus()
    howPanel.url:HighlightText()
end
local function headButton(anchor, tex, coord, title, onClick)
    local b = roundButton(tex, coord, function(self) ns.Tip(self, "ANCHOR_BOTTOM", title) end)
    b:SetPoint("RIGHT", anchor, "LEFT", -2, 0)
    b:SetScript("OnClick", onClick)
    return b
end
local function saveSize()
    PlayerRaidsDB.size = { w = math.floor(frame:GetWidth() + 0.5), h = math.floor(frame:GetHeight() + 0.5) }
end
local function buildGrip()
    local g = CreateFrame("Button", nil, frame)
    g:SetWidth(16)
    g:SetHeight(16)
    g:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    g:SetFrameLevel(frame:GetFrameLevel() + 25)
    g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.sizing = true
        frame:StartSizing("BOTTOMRIGHT")
    end)
    g:SetScript("OnMouseUp", function(self)
        if not self.sizing then return end
        self.sizing = nil
        frame:StopMovingOrSizing()
        saveSize()
        relayout()
    end)
    g:SetScript("OnHide", function(self)
        if self.sizing then self:GetScript("OnMouseUp")(self) end
    end)
    return g
end
local function screenMax()
    local w = UIParent:GetWidth() or 1600
    local h = UIParent:GetHeight() or 1000
    return math.max(w, MIN_W), math.max(h, MIN_H)
end
local function buildStatus()
    local statusLine = line(frame, 0.12)
    statusLine:SetPoint("BOTTOMLEFT", 6, 28)
    statusLine:SetPoint("BOTTOMRIGHT", -6, 28)
    status = ns.Text(frame, 12)
    dim(status)
    status:SetHeight(14)
    status:SetPoint("BOTTOMLEFT", 14, 9)
    howBtn = ns.MakeButton(frame, 12, nil, 18)
    ns.FitButton(howBtn, "Как обновить?", 18)
    howBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 6)
    howBtn.onClick = toggleHow
    local reload = reloadButton(frame)
    reload:SetPoint("RIGHT", howBtn, "LEFT", -4, 0)
    ns.GuideTargets.reload = reload
    local function fakeOn()
        return ns.InRaid() and (GetNumRaidMembers() or 0) == 0
    end
    local function fake(arg)
        local cmd = SlashCmdList and SlashCmdList.PLAYERRAIDSFAKE
        if not cmd then return end
        if arg == "off" then
            cmd("off")
        else
            if IsInGuild and IsInGuild() then cmd("guild") end
            if not fakeOn() then cmd("") end
            if fakeOn() and state.list ~= "raid" and listSeg[3] then listSeg[3].onClick(listSeg[3]) end
        end
        right.syncFake()
    end
    local show = ns.MakeButton(frame, 12, nil, 18)
    ns.FitButton(show, "Тестовый рейд", 18)
    show:SetPoint("RIGHT", reload, "LEFT", -12, 0)
    show.onClick = function() fake() end
    show.tip = function(self)
        ns.Tip(self, "ANCHOR_TOP", "Тестовый рейд", "Собирает 25 человек из гильдии, кто ходил в выбранную сложность, и открывает «Мой рейд». Не в гильдии — случайных из базы.")
    end
    local off = ns.MakeButton(frame, 12, nil, 18)
    ns.FitButton(off, "Убрать тестовый", 18)
    off:SetPoint("RIGHT", reload, "LEFT", -12, 0)
    off.onClick = function() fake("off") end
    local again = ns.MakeButton(frame, 12, nil, 18)
    ns.FitButton(again, "Пересобрать", 18)
    again:SetPoint("RIGHT", off, "LEFT", -4, 0)
    again.onClick = function() fake() end
    again.tip = show.tip
    right.syncFake = function()
        local on = fakeOn()
        local real = (GetNumRaidMembers() or 0) > 0
        if on then off:Show(); again:Show() else off:Hide(); again:Hide() end
        if on or real then show:Hide() else show:Show() end
    end
    right.syncFake()
    local built = GetAddOnMetadata and GetAddOnMetadata(ADDON, "X-Date")
    local y4, m2, d2 = string.match(built or "", "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    local mine = "v" .. (ns.LinkVersion and ns.LinkVersion() or "?")
    local ver = ns.Text(frame, 12)
    dim(ver)
    local links = {}
    for _, it in ipairs({
        { "Откуда данные", false, "Рейды, парсы и рейтинг спека — из логов WoW Circle." },
        { "Релизы", ns.RELEASES_URL, "Все версии аддона для скачивания" },
        { "Discord", ns.DISCORD_URL, "Сервер Manacode: вопросы, новости и новые версии" },
    }) do
        local b = ns.MakeButton(frame, 12, nil, 18)
        ns.FitButton(b, it[1], 14)
        if it[2] then b.onClick = function(self) ns.ShowCopy(self, it[2], 320, true) end end
        b.tip = function(self) ns.Tip(self, "ANCHOR_TOP", it[1], it[3]) end
        tinsert(links, b)
    end
    local newText = ns.Text(frame, 12)
    gold(newText)
    newText:Hide()
    local get = ns.MakeButton(frame, 12, nil, 18)
    ns.FitButton(get, "Скачать", 16)
    get.onClick = function(self) ns.ShowCopy(self, ns.RELEASE_URL, 400, true) end
    get.tip = function(self)
        ns.Tip(self, "ANCHOR_TOP", "Новая версия аддона", "Запустите ManacodeUpdate и нажмите «Обновить» у PlayerRaidsInfo, потом перезапустите игру.", "Кнопка покажет ссылку на релиз, если хотите скачать сами.")
    end
    get:Hide()
    local function rightEdge()
        local edge = reload:GetLeft()
        for _, btn in ipairs({ show, off, again }) do
            if btn:IsShown() and btn:GetLeft() and (not edge or btn:GetLeft() < edge) then edge = btn:GetLeft() end
        end
        local left = frame:GetLeft()
        if not edge or not left then return nil end
        return edge - left - 12
    end
    local function placeAt(obj, x)
        obj:ClearAllPoints()
        obj:SetPoint("LEFT", status, "LEFT", x, 0)
    end
    right.placeVer = function()
        local limit = rightEdge()
        local x0 = math.floor((status:GetStringWidth() or 0) + 14)
        local v = ns.NewestVersion and ns.NewestVersion()
        local newW = 0
        if v then
            newText:SetText("Вышла версия " .. v)
            newW = math.floor((newText:GetStringWidth() or 0) + 6 + get:GetWidth() + 14)
        end
        local linksW = 0
        for _, b in ipairs(links) do linksW = linksW + 6 + b:GetWidth() end
        local full = mine .. (y4 and (" от " .. d2 .. "." .. m2 .. "." .. y4) or "")
        local plans = { { full, true }, { mine, true }, { full, false }, { mine, false } }
        local text, withLinks = mine, false
        for _, plan in ipairs(plans) do
            ver:SetText(plan[1])
            local w = (ver:GetStringWidth() or 0) + (plan[2] and linksW or 0) + newW
            if not limit or 14 + x0 + w <= limit then
                text, withLinks = plan[1], plan[2]
                break
            end
        end
        ver:SetText(text)
        placeAt(ver, x0)
        local x = x0 + math.floor((ver:GetStringWidth() or 0))
        for _, b in ipairs(links) do
            if withLinks then
                placeAt(b, x + 6)
                x = x + 6 + b:GetWidth()
                b:Show()
            else
                b:Hide()
            end
        end
        if v then
            placeAt(newText, x + 14)
            newText:Show()
            get:ClearAllPoints()
            get:SetPoint("LEFT", newText, "RIGHT", 6, 0)
            get:Show()
        end
    end
    local syncFake = right.syncFake
    right.syncFake = function()
        syncFake()
        right.placeVer()
    end
    if ns.OnNewVersion then ns.OnNewVersion(function() right.placeVer() end) end
    right.placeVer()
end
local function buildWatchers()
    ticker = CreateFrame("Frame", nil, frame)
    ticker:Hide()
    ticker:SetScript("OnUpdate", function(self)
        self:Hide()
        relayout()
    end)
    frame:SetScript("OnSizeChanged", function()
        ticker:Show()
    end)
    frame:SetScript("OnHide", function()
        ns.HideCopy()
        hideSeasonList()
        if right.picker then right.picker:Hide() end
    end)
    local follower = CreateFrame("Frame")
    follower:RegisterEvent("PLAYER_TARGET_CHANGED")
    follower:SetScript("OnEvent", function()
        if not frame:IsShown() or not ns.Opt("follow") then return end
        if not UnitExists("target") or not UnitIsPlayer("target") then return end
        local id = ns.IdFromGuid(UnitGUID("target"))
        if id and id ~= state.id and ns.Get(id) then selectId(id) end
    end)
    ns.OnNotesChanged(function()
        if not frame:IsShown() then return end
        updateLeft()
        renderNote()
    end)
    ns.OnRefresh(function(name)
        if frame:IsShown() and state.id and ns.NameOf(state.id) == name then renderRight(true) end
    end)
    if ns.OnRaidChanged then
        ns.OnRaidChanged(function()
            if right.syncFake then right.syncFake() end
            if not frame:IsShown() then return end
            local was = state.list
            layoutTabs()
            if was == "raid" then
                fillLeft()
                if state.list ~= "raid" then renderRight() end
            end
        end)
    end
end
local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", "PlayerRaidsBrowser", UIParent)
    local maxW, maxH = screenMax()
    local saved = PlayerRaidsDB.size
    local w = saved and tonumber(saved.w) or MIN_W
    local h = saved and tonumber(saved.h) or MIN_H
    frame:SetWidth(math.max(MIN_W, math.min(w, maxW)))
    frame:SetHeight(math.max(MIN_H, math.min(h, maxH)))
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    ns.StylePanel(frame)
    ns.GuideTargets = {}
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetMinResize(MIN_W, MIN_H)
    frame:SetMaxResize(maxW, maxH)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "PlayerRaidsBrowser")
    frame:Hide()
    local title = ns.Text(frame, 16, "LEFT", "head")
    title:SetPoint("TOPLEFT", 14, -11)
    title:SetText("Рейды игроков")
    local titleLine = line(frame, 0.15)
    titleLine:SetPoint("TOPLEFT", 6, -34)
    titleLine:SetPoint("TOPRIGHT", -6, -34)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local gear = headButton(close, "Interface\\Icons\\INV_Misc_Gear_01", 0.07, "Настройки", function() showOptions() end)
    headButton(gear, "Interface\\FriendsFrame\\InformationIcon", 0.0625, "Как пользоваться", function() ns.ToggleGuide(frame) end)
    local split = ns.Rect(frame, 1, 0.82, 0, 0.12, "ARTWORK")
    split:SetWidth(1)
    split:SetPoint("TOPLEFT", RX - 12, -40)
    split:SetPoint("BOTTOMLEFT", RX - 12, 32)
    buildLeft()
    buildRight()
    buildStatus()
    buildOptions()
    buildGrip()
    buildWatchers()
    local gt = ns.GuideTargets
    gt.search, gt.listTabs, gt.list = searchBox, listSeg, lscroll
    gt.header, gt.note = right.band, right.noteBox
    gt.seasons = { right.seasonLabel, right.seasonDrop, unpack(right.seasons) }
    for _, c in ipairs(right.badgeChips) do tinsert(gt.seasons, c) end
    gt.bestTiles, gt.diffTiles, gt.kills = right.tiles, right.tiles5, right.killTile
    gt.raids, gt.update = rscroll, howBtn
    applySize()
    return frame
end
function ns.OpenBrowser(query)
    local f = build()
    f:Show()
    applySize()
    updateStatus()
    layoutTabs()
    if not PlayerRaidsDB.guideSeen then
        PlayerRaidsDB.guideSeen = true
        ns.ShowGuide(f)
    end
    if query then
        searchBox:SetText(query)
        state.search = query
        fillLeft()
        selectId(ns.FindId(query) or ids[1])
        return
    end
    fillLeft()
    if not state.id then
        local own = ns.IdFromGuid(UnitGUID("player"))
        if own and not ns.Get(own) then own = nil end
        selectId(own or ids[1])
    else
        selectId(state.id)
    end
end
function ns.BrowserSelect(id)
    if not frame then return end
    selectId(id)
end
function ns.BrowserShown()
    return frame and frame:IsShown() and true or false
end
function ns.OpenOptions()
    if not ns.BrowserShown() then ns.OpenBrowser() end
    showOptions(true)
end
function ns.ToggleBrowser()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ns.OpenBrowser()
    end
end
local function buildIcon()
    PlayerRaidsDB.iconPoint = PlayerRaidsDB.iconPoint or { "CENTER", "CENTER", 120, 0 }
    local icon = CreateFrame("Button", "PlayerRaidsIcon", UIParent)
    icon:SetWidth(32)
    icon:SetHeight(32)
    icon:SetMovable(true)
    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")
    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\Achievement_Boss_Lichking")
    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("CENTER")
    border:SetWidth(52)
    border:SetHeight(52)
    icon:SetScript("OnDragStart", function(self) self:StartMoving() end)
    icon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PlayerRaidsDB.iconPoint = { point, relPoint, x, y }
    end)
    icon:SetScript("OnClick", function() ns.ToggleBrowser() end)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Рейды игроков")
        GameTooltip:AddLine("Клик — окно, перетаскивание — переместить.", 1, 1, 1)
        GameTooltip:AddLine("Alt + наведение на игрока — карточка.", 1, 1, 1)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local p = PlayerRaidsDB.iconPoint
    icon:ClearAllPoints()
    icon:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", buildIcon)
SLASH_PLAYERRAIDS1 = "/raids"
SlashCmdList["PLAYERRAIDS"] = function(msg)
    local q = string.match(msg or "", "^%s*(.-)%s*$")
    local noteName, noteText = string.match(q, "^note%s+(%S+)%s*(.-)$")
    if q == "opt" then
        ns.OpenOptions()
    elseif noteName then
        local id = ns.FindId(noteName)
        if not id then
            ns.Print("не знаю id для «" .. noteName .. "»: персонажа нет в выгрузке и он не встречался в игре")
            return
        end
        ns.SetNote(id, noteText)
        local who = ns.NameOf(id) or noteName
        if ns.Note(id) then
            ns.Print("заметка для " .. who .. " (id " .. id .. "): " .. ns.Note(id))
        else
            ns.Print("заметка для " .. who .. " удалена")
        end
    elseif q ~= "" then
        ns.OpenBrowser(q)
    else
        ns.ToggleBrowser()
    end
end
