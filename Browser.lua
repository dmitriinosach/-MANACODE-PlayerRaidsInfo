local ADDON, ns = ...

local MIN_W, MIN_H = 720, 570
local LEFT_W = 180
local LROW_H = 17
local LIST_TOP = 110
local RX = 238
local RROW_H = 30
local BOTTOM = 34
local GAP = 8
local BAR_W = 34
local TILE, TILE_STEP = 44, 50
local SEARCH_LIMIT = 200
local RECENT_LIMIT = 50
local HEAD_Y, HEAD_H = 36, 68
local SEASON_W = 24
local ALL_W = 38
local ALL = "all"
local BOSS_X = 170
local ROLE_W = 58
local PANEL_BORDER = { 0.43, 0.35, 0.2 }
local EDGE = { 0.4, 0.4, 0.42 }
local EDGE_UNBUFF = { 1, 0.15, 0.1 }
local EDGE_UNBUFF_EMPTY = { 0.55, 0.1, 0.08 }
local HIST_X = 5 * TILE_STEP + 12 + 10
local GEAR_TITLE = "Парс на гире"
local GEAR_TIP = "Место среди игроков того же спека с таким же уровнем предметов (±2)."
local GEAR_EMPTY = "Пусто — таких килов меньше 20."
local HEAD_KEYS = { nil, "date", "wipes", "ilvl", "b1", "b2", "b3" }
local ARROW_UP = "|TInterface\\Buttons\\Arrow-Up-Up:12:12:0:-3|t"
local ARROW_DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:12:12:0:-3|t"
local THIN = {
    bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local frame, searchBox, placeholder, listLabel, lscroll, rscroll, status, ticker
local right = {}
local lrows, rrows = {}, {}
local ids, raids, nums = {}, {}, {}
local state = { search = "", id = nil, season = nil, mode = "ih", list = "all", seasonMsg = nil }
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

local function gearTip(owner)
    ns.Tip(owner, "ANCHOR_TOP", GEAR_TITLE, GEAR_TIP, GEAR_EMPTY)
end

local function sortOpt()
    local o = PlayerRaidsDB.opts
    local r = o and o.raidSort
    if type(r) ~= "table" or not r.key then return "date", true end
    return r.key, r.desc ~= false
end

local function setSort(key, desc)
    PlayerRaidsDB.opts = PlayerRaidsDB.opts or {}
    PlayerRaidsDB.opts.raidSort = { key = key, desc = desc and true or false }
end

local function sortValue(raid, key)
    if key == "date" then return tonumber(raid.date) end
    if key == "wipes" then return raid.wipes end
    if key == "ilvl" then return ns.RaidIlvl(raid) end
    if key == "best" then
        local m
        for b = 1, 3 do
            local c = raid.cells[b]
            if c and c.parse and (not m or c.parse > m) then m = c.parse end
        end
        return m
    end
    local b = tonumber(string.match(key, "^b(%d)$"))
    local c = b and raid.cells[b]
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

local function headLabel(i, text)
    local key, desc = sortOpt()
    if HEAD_KEYS[i] and HEAD_KEYS[i] == key then
        return ns.Color("gold", text) .. " " .. (desc and ARROW_DOWN or ARROW_UP)
    end
    return ns.Color("grey", text)
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

local function setBar(bar, cell)
    if cell and cell.parse then
        bar.bg:Show()
        local fw = math.floor(BAR_W * math.min(cell.parse, 100) / 100 + 0.5)
        if fw > 0 then
            bar.fill:SetWidth(fw)
            bar.fill:SetVertexColor(ns.ParseRGB(cell.parse))
            bar.fill:Show()
        else
            bar.fill:Hide()
        end
    else
        bar.bg:Hide()
        bar.fill:Hide()
    end
end

local function showRaidRow(row, on)
    for _, fs in ipairs(row.cols) do
        if on then fs:Show() else fs:Hide() end
    end
    for _, cs in ipairs(row.cells) do
        if on then
            cs.top:Show()
            cs.bot:Show()
        else
            cs.top:Hide()
            cs.bot:Hide()
            cs.bar.bg:Hide()
            cs.bar.fill:Hide()
        end
    end
    if on then row.sep:Hide() else row.sep:Show() end
end

local function updateRaids()
    local offset = FauxScrollFrame_GetOffset(rscroll) or 0
    local rs = ns.IsRS(state.mode)
    local tableShown = rscroll:IsShown()
    local tagSeason = state.season == ALL and sortOpt() ~= "date"
    for i, row in ipairs(rrows) do
        local raid = tableShown and i <= size.rrows and raids[offset + i]
        if raid and raid.sep then
            showRaidRow(row, false)
            row.sep:SetText("Сезон " .. raid.sep)
            row.odd:Hide()
            row:Show()
        elseif raid then
            showRaidRow(row, true)
            local c = row.cols
            c[1]:SetText(ns.Color("dim", nums[offset + i] or ""))
            local date = ns.Color("grey", ns.DayMonthYear(raid.date))
            if tagSeason and raid.season then date = date .. ns.Color("dim", " с" .. raid.season) end
            c[2]:SetText(date)
            c[3]:SetText(ns.WipesText(raid.wipes))
            local il = ns.RaidIlvl(raid)
            c[4]:SetText(il and ns.Color("white", il) or ns.Color("none", "—"))
            for b = 1, 3 do
                local cell, cs = raid.cells[b], row.cells[b]
                if rs and b > 1 then
                    cs.top:SetText("")
                    cs.bot:SetText("")
                    setBar(cs.bar, nil)
                else
                    cs.top:SetText(ns.CellMain(cell))
                    cs.bot:SetText(ns.CellSub(cell))
                    setBar(cs.bar, cell)
                end
            end
            if (nums[offset + i] or 0) % 2 == 1 then row.odd:Show() else row.odd:Hide() end
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(rscroll, #raids, size.rrows, RROW_H)
    if tableShown and #raids == 0 then
        right.empty:SetText(state.seasonMsg or "Нет рейдов в этой сложности")
        right.empty:Show()
    else
        right.empty:Hide()
    end
end

local function styleTile(tile, mode, n, on)
    local empty = n == 0
    tile.icon:SetDesaturated(empty and 1 or nil)
    tile.icon:SetAlpha(empty and 0.45 or 1)
    tile.skull:SetAlpha(empty and 0.45 or 1)
    tile.size:SetAlpha(empty and 0.5 or 1)
    if tile.unbuff then tile.unbuff:SetAlpha(empty and 0.5 or 1) end
    local edge = EDGE
    if on then
        edge = { 1, 0.82, 0 }
    elseif mode == "iu" then
        edge = empty and EDGE_UNBUFF_EMPTY or EDGE_UNBUFF
    end
    tile:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    if on then tile.mark:Show() else tile.mark:Hide() end
    if empty then
        tile.caption:SetText(ns.Color("none", n))
    elseif on then
        tile.caption:SetText(ns.Color("gold", n))
    else
        tile.caption:SetText(ns.Color("white", n))
    end
end

local function tileFill(t, b, role)
    if b and b.parse then
        t.big:SetText("|cff" .. ns.ParseHex(b.parse) .. b.parse .. "|r")
        local bits = {}
        if b.boss then tinsert(bits, ns.BOSS[b.boss] or b.boss) end
        if b.mode then tinsert(bits, ns.MODE_FULL[b.mode] or b.mode) end
        if b.date then tinsert(bits, ns.DayMonthYear(b.date)) end
        local s = table.concat(bits, ", ")
        if b.value then s = s .. "\n" .. ns.Compact(b.value) .. (role == "h" and " хпс" or " дпс") end
        t.s:SetText(s)
        t.accent:SetVertexColor(ns.ParseRGB(b.parse))
        t.accent:Show()
    else
        t.big:SetText(ns.Color("none", "—"))
        t.s:SetText(role == "h" and "не хилил в этом сезоне" or "не дамажил в этом сезоне")
        t.accent:Hide()
    end
end

local function showRight(on)
    for _, obj in ipairs(right.all) do
        if on then obj:Show() else obj:Hide() end
    end
    for _, obj in ipairs(right.cond) do obj:Hide() end
    if on then right.none:Hide() else right.none:Show() end
end

local function renderCrest(class, shown)
    local r, g, b = ns.ClassColor(class)
    right.crestBox:SetBackdropBorderColor(r, g, b, 1)
    if ns.SetClassTexture(right.crest, class) then
        right.crest:SetVertexColor(1, 1, 1, 1)
        right.letter:Hide()
    else
        right.crest:SetTexture(ns.WHITE)
        right.crest:SetTexCoord(0, 1, 0, 1)
        right.crest:SetVertexColor(r, g, b, 1)
        right.letter:SetText(ns.FirstChar(shown))
        right.letter:Show()
    end
end

local function renderHistory(rec, s)
    local bosses = ns.BossesOf(state.mode)
    local src = s and s.hist
    if state.season == ALL then src = rec and rec.hist end
    local hist = src and src[state.mode] or {}
    for i, fs in ipairs(right.hist) do
        local boss = bosses[i]
        if boss then
            local h = hist[boss]
            local icon = string.format("|T%s:14:14:0:0:64:64:5:59:5:59|t ", ns.BOSS_ICON[boss])
            if h and (h.kills or 0) > 0 then
                fs:SetText(icon .. ns.Color("white", "×" .. h.kills) .. ns.Color("grey", "  первый " .. ns.DayMonthYearFull(h.first)))
            else
                fs:SetText(icon .. ns.Color("none", "—"))
            end
            fs:Show()
        else
            fs:Hide()
        end
    end
end

local function renderNote()
    if right.noteBox:HasFocus() then return end
    right.noteBox:SetText(ns.Note(state.id) or "")
end

local function fitLine(b, text, maxW)
    b.text:SetWidth(maxW)
    b.text:SetText(text)
    local w = math.min(math.floor((b.text:GetStringWidth() or maxW) + 4), maxW)
    b.text:SetWidth(w)
    b:SetWidth(w)
end

local function renderAka(others)
    local names = right.names
    if others and #others > 0 then
        local text = ns.Color("grey", "также известен как ") .. "|cffbfbfd9" .. others[1] .. "|r"
        if #others > 1 then text = text .. " " .. ns.Color("gold", "+" .. (#others - 1)) end
        fitLine(names, text, size.rw - 44 - 110)
        place(names, RX + 44, 82)
        names:Show()
    else
        names:Hide()
    end
end

local function renderGuild(anchor, used)
    local guild = right.guild
    local e = ns.GuildOf(state.id)
    if not e or e.cur == nil then
        guild:Hide()
        return
    end
    local past = 0
    for g in pairs(e.hist or {}) do
        if g ~= e.cur then past = past + 1 end
    end
    local maxW = math.max(size.rw - used - 150, 50)
    if e.cur then
        guild.text:SetTextColor(0.25, 1, 0.25)
        ns.FitText(guild.text, "<" .. e.cur .. ">", maxW - (past > 0 and 22 or 0))
    else
        guild.text:SetTextColor(0.62, 0.62, 0.62)
        guild.text:SetText("без гильдии")
    end
    if past > 0 then guild.text:SetText(guild.text:GetText() .. " " .. ns.Color("gold", "+" .. past)) end
    guild:ClearAllPoints()
    guild:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    guild:SetWidth(math.floor((guild.text:GetStringWidth() or 40) + 4))
    guild:Show()
end

local function renderNameLine(rec, shown)
    right.copy.value = shown
    right.copy:ClearAllPoints()
    right.copy:SetPoint("LEFT", right.name, "RIGHT", 5, 0)
    right.copy:Show()
    local used = 44 + (right.name:GetStringWidth() or 80) + 5 + 16
    local anchor = right.copy
    local hero = rec and ns.HeroDate(rec)
    right.hero.date = hero
    if hero then
        right.hero:ClearAllPoints()
        right.hero:SetPoint("LEFT", right.copy, "RIGHT", 6, 0)
        right.hero:Show()
        anchor = right.hero
        used = used + 6 + right.hero:GetWidth()
    else
        right.hero:Hide()
    end
    renderGuild(anchor, used)
end

local function seasonCaption()
    if state.season == ALL then return "все сезоны" end
    return "сезон " .. tostring(state.season)
end

local function renderGearTile(s)
    local t = right.tiles[4]
    local med = ns.GearMedian(s, state.mode)
    if not med then
        t:Hide()
        return
    end
    t.big:SetText("|cff" .. ns.ParseHex(med) .. med .. "|r")
    t.s:SetText("медиана парса на гире\n" .. seasonCaption() .. ", " .. (ns.MODE_FULL[state.mode] or state.mode))
    t.accent:SetVertexColor(ns.ParseRGB(med))
    t.accent:Show()
    t:Show()
end

local function renderHeader(rec, shown, s)
    renderCrest(rec.class, shown)
    right.name:SetText(shown)
    right.name:SetTextColor(ns.ClassColor(rec.class))
    right.last:SetText((s and s.last and s.last ~= "") and ("последний рейд " .. ns.DayMonthYear(s.last)) or "")

    local sub = {}
    local title = ns.TitleOf(state.id)
    if title then tinsert(sub, ns.Color("grey", title)) end
    local spec = ns.LiveSpec and ns.LiveSpec(shown)
    if not spec and s then spec = ns.SpecRu(s.spec) end
    if spec then tinsert(sub, spec) end
    if s and s.gs then tinsert(sub, "илвл " .. s.gs) end
    right.sub:SetText(table.concat(sub, ns.Color("dim", ", ")))

    ns.Ambient(frame, rec.class, PANEL_BORDER, 0.5, 0.1)
    local r, g, b = ns.ClassColor(rec.class)
    right.bandLine:SetVertexColor(r, g, b, 0.45)
    local anySpec = (s and s.spec) or (rec.seasons[1] and rec.seasons[1].spec)
    state.art = ns.ArtFor(shown, rec.class, anySpec)

    renderNameLine(rec, shown)
    renderAka(ns.OtherNames(rec, shown))
end

local function seasonList(rec)
    local seasons = {}
    for _, sn in ipairs(ns.Meta().seasons or {}) do
        sn = tonumber(sn)
        if sn then tinsert(seasons, sn) end
    end
    if #seasons == 0 and rec then
        for _, rs in ipairs(rec.seasons) do tinsert(seasons, rs.season) end
    end
    return seasons
end

local function seasonEmpty(rec, sn)
    if sn == ALL then return false end
    if sn == ns.CurrentSeason() then return not ns.SeasonOf(rec, sn) end
    if ns.ArchiveLoaded() then return not ns.SeasonBlock(rec, sn, true) end
    return not ns.SeasonWanted(sn)
end

local function seasonTip(self)
    if not self.empty or not self.season or self.season == ALL then return end
    local rec = ns.Get(state.id)
    local _, why, reason = ns.SeasonBlock(rec, self.season, true)
    local msg = ns.SeasonMessage(self.season, why, reason)
    if not msg and not ns.SeasonWanted(self.season) then msg = ns.SeasonMessage(self.season, "notdownloaded") end
    if msg then ns.Tip(self, "ANCHOR_TOP", "Сезон " .. self.season, msg) end
end

local function seasonLabel(sn)
    if sn == ALL then return "ВСЕ" end
    return tostring(sn)
end

local function renderSeasons(rec)
    local seasons = seasonList(rec)
    tinsert(seasons, 1, ALL)
    right.seasonN = #seasons
    for i, b in ipairs(right.seasons) do
        local sn = seasons[i]
        b.season = sn
        if sn then
            b.text:SetText(seasonLabel(sn))
            b:SetWidth(sn == ALL and ALL_W or SEASON_W)
            ns.SetButton(b, state.season == sn, false, seasonEmpty(rec, sn))
        end
    end
    for i, b in ipairs(right.seasonList.items) do
        local sn = seasons[i]
        b.season = sn
        if sn then
            b.text:SetText(seasonLabel(sn))
            ns.SetButton(b, state.season == sn, false, seasonEmpty(rec, sn))
            b:Show()
        else
            b:Hide()
        end
    end
    right.seasonList:SetHeight(math.max(#seasons, 1) * 21 + 7)
    right.seasonDrop.text:SetText(state.season and seasonLabel(state.season) or "?")
    ns.PaintButton(right.seasonDrop)
end

local function renderRoles(s)
    local box = right.roleBox
    local k = s and s.roleKills and s.roleKills[state.mode]
    if not k then
        box:Hide()
        return
    end
    for i, role in ipairs({ "d", "h", "t" }) do
        local n = k[role] or 0
        local fs = box.lines[i]
        fs:SetText(ns.RoleIcon(role, 14) .. " " .. n)
        if n > 0 then fs:SetTextColor(0.95, 0.95, 0.95) else fs:SetTextColor(0.35, 0.36, 0.38) end
        fs:SetAlpha(n > 0 and 1 or 0.55)
    end
    box:Show()
end

local function renderTiles(rec, s)
    local best = { s and s.bestD, s and s.bestH, s and s.bestT }
    local roles = { "d", "h", "t" }
    local any = false
    for i = 1, 3 do
        local t = right.tiles[i]
        if best[i] and best[i].parse then
            tileFill(t, best[i], roles[i])
            t:Show()
            any = true
        else
            t:Hide()
        end
    end
    if not any then
        tileFill(right.tiles[1], nil, "d")
        right.tiles[1].s:SetText("нет парсов в этом сезоне")
        right.tiles[1]:Show()
    end
    renderGearTile(s)
    renderRoles(s)
    for i, mode in ipairs(ns.MODES) do
        styleTile(right.tiles5[i], mode, s and s.raids[mode] or 0, state.mode == mode)
    end
end

local function layoutColumns()
    local tw = size.rw - 24
    local bossW = math.floor((tw - BOSS_X) / 3)
    local cols = { { 0, 22 }, { 28, 60 }, { 90, 38 }, { 130, 34 } }
    local rs = ns.IsRS(state.mode)
    rscroll:SetWidth(tw)
    for i, fs in ipairs(right.heads) do
        local x, w
        if i <= 4 then
            x, w = cols[i][1], cols[i][2]
        else
            x, w = BOSS_X + (i - 5) * bossW, bossW - 4
            if rs and i == 5 then w = bossW * 3 - 4 end
        end
        local hb = right.headBtns[i]
        if hb then
            hb:SetWidth(w)
            hb:ClearAllPoints()
            hb:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", x - 2, 2)
        end
        fs:SetWidth(w)
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMLEFT", rscroll, "TOPLEFT", x, 6)
    end
    for _, row in ipairs(rrows) do
        row:SetWidth(tw)
        for c, fs in ipairs(row.cols) do
            fs:SetWidth(cols[c][2])
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", cols[c][1], 0)
        end
        for b = 1, 3 do
            local cs = row.cells[b]
            local x = BOSS_X + (b - 1) * bossW
            local w = (rs and b == 1) and (bossW * 3 - 4) or (bossW - 4)
            cs.top:SetWidth(w)
            cs.top:ClearAllPoints()
            cs.top:SetPoint("TOPLEFT", row, "TOPLEFT", x, -2)
            cs.bot:SetWidth(math.max(w - 17, 10))
            cs.bot:ClearAllPoints()
            cs.bot:SetPoint("TOPLEFT", row, "TOPLEFT", x + 17, -17)
            cs.bar.bg:ClearAllPoints()
            cs.bar.bg:SetPoint("TOPLEFT", row, "TOPLEFT", x + 17, -15)
            cs.bar.fill:ClearAllPoints()
            cs.bar.fill:SetPoint("TOPLEFT", row, "TOPLEFT", x + 17, -15)
        end
    end
end

local function layoutCtx(y)
    local n = right.seasonN or 0
    local total = math.max(n - 1, 0) * 3
    for i = 1, math.min(n, #right.seasons) do total = total + right.seasons[i]:GetWidth() end
    local labelW = right.seasonLabel:GetStringWidth() or 40
    local x = RX + math.floor(labelW + 0.5) + 8
    right.seasonLabel:ClearAllPoints()
    right.seasonLabel:SetPoint("LEFT", frame, "TOPLEFT", RX, -(y + 11))
    right.seasonLabel:Show()
    if total > size.rw - labelW - 8 or n > #right.seasons then
        for _, b in ipairs(right.seasons) do b:Hide() end
        place(right.seasonDrop, x, y + 1)
        right.seasonDrop:Show()
        return
    end
    right.seasonDrop:Hide()
    for i, b in ipairs(right.seasons) do
        if i <= n then
            place(b, x, y + 1)
            x = x + b:GetWidth() + 3
            b:Show()
        else
            b:Hide()
        end
    end
end

local function layoutRight()
    local rw = size.rw
    right.noteBox:SetWidth(rw - 72)
    right.sub:SetWidth(rw - 44 - 170)
    right.none:SetWidth(rw - 20)
    right.none:ClearAllPoints()
    right.none:SetPoint("CENTER", frame, "TOPLEFT", RX + rw / 2, -200)
    right.empty:SetWidth(rw - 60)
    right.empty:ClearAllPoints()
    right.empty:SetPoint("TOP", rscroll, "TOP", 0, -30)
    ns.PaintArt(right.art, state.art, size.w - (RX - 11) - 5, HEAD_H)

    local y = HEAD_Y + HEAD_H + 6
    place(right.noteLabel, RX, y + 4)
    place(right.noteBox, RX + 66, y)
    y = y + 20 + GAP

    if not right.tiles5[1]:IsShown() then return end

    layoutCtx(y)
    y = y + 22 + GAP

    local shownTiles = {}
    for _, t in ipairs(right.tiles) do
        if t:IsShown() then tinsert(shownTiles, t) end
    end
    local nt = math.max(#shownTiles, 1)
    local tw = math.floor((rw - 8 * (nt - 1)) / nt)
    local th = 44
    for _, t in ipairs(shownTiles) do
        t:SetWidth(tw)
        t.s:SetWidth(tw - 56)
        th = math.max(th, 20 + (t.s:GetStringHeight() or 14) + 8)
    end
    for i, t in ipairs(shownTiles) do
        t:SetHeight(th)
        place(t, RX + (i - 1) * (tw + 8), y)
    end
    y = y + th + GAP

    local x = 0
    for i, mode in ipairs(ns.MODES) do
        if mode == "rh" then x = x + 12 end
        place(right.tiles5[i], RX + x, y)
        x = x + TILE_STEP
    end
    for i, fs in ipairs(right.hist) do
        fs:SetWidth(math.max(rw - HIST_X - ROLE_W - 6, 60))
        place(fs, RX + HIST_X, y + (i - 1) * 18)
    end
    right.roleBox:SetWidth(ROLE_W)
    place(right.roleBox, RX + rw - ROLE_W, y)
    y = y + TILE + 18 + GAP

    place(right.sortBox, RX, y)
    local top = y + 24 + 20
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

local function resetAmbient()
    ns.Ambient(frame, nil, PANEL_BORDER)
    state.art = nil
    right.art:Hide()
    right.bandLine:SetVertexColor(1, 0.82, 0, 0.2)
end

local function renderMissing()
    showRight(true)
    for _, obj in ipairs(right.dataOnly) do obj:Hide() end
    right.empty:Hide()
    raids = {}
    resetAmbient()
    local shown = ns.NameOf(state.id) or ("#" .. tostring(state.id))
    renderCrest(nil, shown)
    right.name:SetText(shown)
    right.name:SetTextColor(0.9, 0.9, 0.9)
    right.id:SetText("id " .. tostring(state.id))
    right.last:SetText("")
    right.sub:SetText(ns.DataProblem() or "нет в логах")
    renderNameLine(nil, shown)
    renderNote()
    layoutRight()
    updateRaids()
end

local function renderRight(keepScroll)
    hideSeasonList()
    local rec = state.id and ns.Get(state.id)
    if not rec then
        if state.id then
            renderMissing()
            return
        end
        showRight(false)
        resetAmbient()
        right.none:SetText(ns.DataProblem() or "Выберите игрока слева")
        raids = {}
        updateRaids()
        return
    end
    showRight(true)
    right.id:SetText("id " .. tostring(state.id))
    renderNote()

    local s, why, reason
    if state.season == ALL then
        s = ns.AllSeasons(rec, seasonList(rec))
        state.seasonMsg = not s and "Ни в одном сезоне килов нет" or nil
    else
        s, why, reason = ns.SeasonBlock(rec, state.season)
        state.seasonMsg = not s and ns.SeasonMessage(state.season, why, reason) or nil
    end
    local shown = ns.NameOf(state.id) or rec.name
    renderHeader(rec, shown, s)
    renderTiles(rec, s)
    renderSeasons(rec)
    renderHistory(rec, s)

    local bosses = ns.BossesOf(state.mode)
    right.heads[1]:SetText(ns.Color("grey", "№"))
    right.heads[2]:SetText(headLabel(2, "Дата"))
    right.heads[3]:SetText(headLabel(3, "Вайпы"))
    right.heads[4]:SetText(headLabel(4, "Илвл"))
    for b = 1, 3 do
        right.heads[4 + b]:SetText(bosses[b] and headLabel(4 + b, ns.BossHead(bosses[b], 14)) or "")
        if bosses[b] then right.headBtns[4 + b]:Show() else right.headBtns[4 + b]:Hide() end
    end
    local key = sortOpt()
    for _, b in ipairs(right.sortBtns) do ns.SetButton(b, b.key == key) end

    buildRaidList(s)
    layoutRight()
    if not keepScroll then resetScroll(rscroll) end
    updateRaids()
end

local function pickMode(s)
    if not s then return end
    if (s.raids[state.mode] or 0) > 0 or #(s.byMode[state.mode] or {}) > 0 then return end
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
    state.id = id
    ns.HideCopy()
    local rec = id and ns.Get(id)
    local s = rec and rec.seasons[1]
    if state.season == ALL then
        pickMode(ns.AllSeasons(rec, seasonList(rec)))
    else
        state.season = ns.CurrentSeason() or (s and s.season)
        pickMode(ns.SeasonOf(rec, state.season))
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
    local full = meta.complete == false and "|cffff8000неполная|r" or ns.Color("green", "полная")
    status:SetText("выгрузка " .. ns.BakedText() .. ", " .. full .. ", "
        .. n .. " " .. ns.Plural(n, "игрок", "игрока", "игроков"))
end

local function applySize()
    size.w = math.floor(frame:GetWidth() + 0.5)
    size.h = math.floor(frame:GetHeight() + 0.5)
    size.rw = size.w - RX - 12
    local lrowsN = math.floor((size.h - BOTTOM - LIST_TOP) / LROW_H)
    size.lrows = math.max(1, math.min(lrowsN, #lrows))
    lscroll:SetHeight(size.lrows * LROW_H)
    status:SetWidth(math.max(size.w - 240, 100))
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

    listSeg = {}
    local bw = math.floor((LEFT_W - 2) / 2)
    for i, it in ipairs({ { "all", "Все" }, { "ren", "Ренеймы" } }) do
        local b = ns.MakeButton(frame, 13, bw, 20)
        b.text:SetText(it[2])
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * (bw + 2), -68)
        b.list = it[1]
        b.onClick = function(self)
            state.list = self.list
            for _, o in ipairs(listSeg) do ns.SetButton(o, o.list == state.list) end
            fillLeft()
        end
        ns.SetButton(b, it[1] == state.list)
        listSeg[i] = b
    end

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
    t:SetHeight(44)
    t:SetBackdrop(THIN)
    t:SetBackdropColor(0, 0, 0, 0.38)
    t:SetBackdropBorderColor(0.3, 0.26, 0.18, 1)
    t.accent = ns.Rect(t, 1, 1, 1, 1, "ARTWORK")
    t.accent:SetWidth(2)
    t.accent:SetPoint("TOPLEFT", 1, -1)
    t.accent:SetPoint("BOTTOMLEFT", 1, 1)
    t.k = ns.Text(t, 12)
    gold(t.k)
    t.k:SetPoint("TOPLEFT", 9, -5)
    t.k:SetText(({ "Лучший парс ДД", "Лучший парс хил", "Лучший парс танк", "На своём гире" })[i])
    if i == 4 then
        t:EnableMouse(true)
        t:SetScript("OnEnter", gearTip)
        t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    t.big = ns.Text(t, 22)
    t.big:SetPoint("TOPLEFT", 9, -20)
    t.s = ns.Text(t, 12)
    grey(t.s)
    t.s:SetJustifyV("TOP")
    t.s:SetPoint("TOPLEFT", 48, -21)
    return t
end

local TILE_BACKDROP = {
    bgFile = ns.WHITE,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function buildModeTile(i, mode)
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
    tile.icon:SetTexture(ns.IsRS(mode) and ns.RS_LFG or ns.ICC_LFG)

    tile.skull = tile:CreateTexture(nil, "OVERLAY")
    tile.skull:SetTexture(ns.SKULL.tex)
    tile.skull:SetTexCoord(ns.SKULL.coord[1], ns.SKULL.coord[2], ns.SKULL.coord[3], ns.SKULL.coord[4])
    tile.skull:SetHeight(20)
    tile.skull:SetWidth(math.floor(20 * ns.SKULL.ratio + 0.5))
    tile.skull:SetPoint("CENTER", tile, "TOPRIGHT", -3, -3)
    if not ns.HEROIC[mode] then tile.skull:Hide() end

    tile.size = tile:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    tile.size:SetPoint("CENTER", tile, "CENTER", 0, 0)
    tile.size:SetShadowColor(0, 0, 0, 1)
    tile.size:SetShadowOffset(1, -1)
    tile.size:SetText("25")

    if mode == "iu" then
        tile.unbuff = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.unbuff:SetFont(ns.FONT_BODY, 13)
        tile.unbuff:SetTextColor(1, 0.2, 0.15)
        tile.unbuff:SetShadowColor(0, 0, 0, 1)
        tile.unbuff:SetShadowOffset(1, -1)
        tile.unbuff:SetPoint("TOP", tile.skull, "BOTTOM", 0, 2)
        tile.unbuff:SetText("А")
    end

    tile.mark = ns.Rect(frame, 1, 0.82, 0, 0.9, "ARTWORK")
    tile.mark:SetHeight(2)
    tile.mark:SetWidth(TILE - 8)
    tile.mark:SetPoint("TOP", tile, "BOTTOM", 0, -1)

    tile.caption = ns.Text(frame, 12, "CENTER")
    tile.caption:SetWidth(TILE + 10)
    tile.caption:SetPoint("TOP", tile, "BOTTOM", 0, -3)

    tile:SetScript("OnClick", function()
        state.mode = mode
        renderRight()
    end)
    tile:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.MODE_FULL[mode], 1, 0.82, 0)
        GameTooltip:Show()
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
    for c = 1, 4 do
        local fs = ns.Text(row, 13, c == 1 and "RIGHT" or ((c == 3 or c == 4) and "CENTER" or "LEFT"))
        fs:SetHeight(RROW_H)
        row.cols[c] = fs
    end
    row.cells = {}
    for b = 1, 3 do
        local top = ns.Text(row, 13)
        top:SetHeight(14)
        local bot = ns.Text(row, 11)
        bot:SetHeight(12)
        local bg = ns.Rect(row, 1, 1, 1, 0.08, "ARTWORK")
        bg:SetWidth(BAR_W)
        bg:SetHeight(2)
        local fill = ns.Rect(row, 1, 1, 1, 1, "OVERLAY")
        fill:SetHeight(2)
        row.cells[b] = { top = top, bot = bot, bar = { bg = bg, fill = fill } }
    end
    row.sep = ns.Text(row, 11, "LEFT", "head")
    row.sep:SetTextColor(1, 0.82, 0)
    row.sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 5)
    row.sep:Hide()
    row:Hide()
    return row
end

local function nameTip(self)
    local rec = ns.Get(state.id)
    local lines = ns.NameHistory(state.id, rec)
    if #lines == 0 then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("История ников", 1, 0.82, 0)
    for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1) end
    GameTooltip:Show()
end

local function guildTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Где был", 1, 0.82, 0)
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
    ns.Tip(self, "ANCHOR_BOTTOM", "Герой Нордскола",
        "ЦЛК 25 анбаф без вайпов, " .. ns.DayMonthYearFull(self.date))
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
    right.art = frame:CreateTexture(nil, "BORDER")
    right.art:SetPoint("TOPLEFT", frame, "TOPLEFT", RX - 11, -HEAD_Y)
    right.art:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -HEAD_Y)
    right.art:SetHeight(HEAD_H)
    right.art:Hide()
    right.bandLine = keep(ns.Rect(frame, 1, 1, 1, 0.45, "ARTWORK"))
    right.bandLine:SetHeight(1)
    right.bandLine:SetPoint("TOPLEFT", frame, "TOPLEFT", RX - 11, -(HEAD_Y + HEAD_H))
    right.bandLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -(HEAD_Y + HEAD_H))

    right.crestBox = keep(CreateFrame("Frame", nil, frame))
    right.crestBox:SetWidth(36)
    right.crestBox:SetHeight(36)
    right.crestBox:SetPoint("TOPLEFT", RX - 1, -42)
    right.crestBox:SetBackdrop({ edgeFile = ns.WHITE, edgeSize = 1 })
    right.crest = right.crestBox:CreateTexture(nil, "ARTWORK")
    right.crest:SetPoint("TOPLEFT", 1, -1)
    right.crest:SetPoint("BOTTOMRIGHT", -1, 1)
    right.letter = ns.Text(right.crestBox, 17, "CENTER", "head")
    right.letter:SetTextColor(0, 0, 0)
    right.letter:SetPoint("CENTER", 0, 0)

    right.name = keep(ns.Text(frame, 17, "LEFT", "head"))
    right.name:SetPoint("TOPLEFT", RX + 44, -42)
    right.last = keep(ns.Text(frame, 12, "RIGHT"))
    grey(right.last)
    right.last:SetPoint("TOPRIGHT", -14, -45)
    right.sub = keep(ns.Text(frame, 13))
    right.sub:SetHeight(14)
    right.sub:SetPoint("TOPLEFT", RX + 44, -64)
    right.id = keep(ns.Text(frame, 11, "RIGHT"))
    dim(right.id)
    right.id:SetPoint("TOPRIGHT", -14, -84)

    right.copy = CreateFrame("Button", nil, frame)
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
    right.guild = hoverLine(guildTip)
    right.guild.text:SetFont(ns.FONT_BODY, 12)
    right.cond = { right.copy, right.hero, right.names, right.guild }
end

local function buildCtx(keep, data)
    right.seasonLabel = keep(data(ns.Text(frame, 11, "LEFT", "head")))
    right.seasonLabel:SetTextColor(0.75, 0.62, 0.3)
    right.seasonLabel:SetText("СЕЗОН")

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

local function buildTable(keep, data)
    local function raidOnly(obj) tinsert(right.raidOnly, obj); return obj end

    rscroll = CreateFrame("ScrollFrame", "PlayerRaidsRaids", frame, "FauxScrollFrameTemplate")
    rscroll:SetWidth(400)
    rscroll:SetHeight(size.rrows * RROW_H)
    rscroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, RROW_H, updateRaids)
    end)
    keep(data(raidOnly(rscroll)))

    right.heads = {}
    for i = 1, 7 do
        local fs = keep(data(raidOnly(ns.Text(frame, 12, i == 1 and "RIGHT" or ((i == 3 or i == 4) and "CENTER" or "LEFT")))))
        dim(fs)
        right.heads[i] = fs
    end
    right.headBtns = {}
    for i = 2, 7 do
        local t = CreateFrame("Button", nil, frame)
        t:SetHeight(18)
        t.key = HEAD_KEYS[i]
        t:SetHighlightTexture(ns.WHITE)
        t:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.12)
        if i >= 5 then
            t:SetScript("OnEnter", function(self)
                ns.Tip(self, "ANCHOR_TOP", GEAR_TITLE, GEAR_TIP, GEAR_EMPTY, "Клик по заголовку — сортировка по парсу босса.")
            end)
            t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        t:SetScript("OnClick", function(self)
            local key, desc = sortOpt()
            if key == self.key then setSort(key, not desc) else setSort(self.key, true) end
            renderRight()
        end)
        right.headBtns[i] = keep(data(raidOnly(t)))
    end

    right.sortBox = keep(data(raidOnly(CreateFrame("Frame", nil, frame))))
    right.sortBox:SetHeight(18)
    right.sortBtns = {}
    local x = 0
    for i, it in ipairs({ { "date", "по дате" }, { "best", "по лучшему парсу" } }) do
        local b = ns.MakeButton(right.sortBox, 12, nil, 18)
        ns.FitButton(b, it[2], 16)
        b.key = it[1]
        b:SetPoint("TOPLEFT", right.sortBox, "TOPLEFT", x, 0)
        b.onClick = function(self)
            setSort(self.key, true)
            renderRight()
        end
        x = x + b:GetWidth() + 2
        right.sortBtns[i] = b
    end
    right.sortBox:SetWidth(math.max(x - 2, 1))
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

    right.noteLabel = keep(ns.Text(frame, 13))
    gold(right.noteLabel)
    right.noteLabel:SetText("Заметка:")
    right.noteBox = keep(CreateFrame("EditBox", "PlayerRaidsNote", frame, "InputBoxTemplate"))
    right.noteBox:SetHeight(20)
    right.noteBox:SetAutoFocus(false)
    right.noteBox:SetMaxLetters(ns.NOTE_MAX)
    right.noteBox:SetFont(ns.FONT_BODY, 13)
    right.noteBox:SetTextColor(1, 0.6, 0.2)
    right.noteBox:SetScript("OnEnterPressed", function(self)
        local id = state.id
        self:ClearFocus()
        if id then ns.SetNote(id, self:GetText()) end
    end)
    right.noteBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText(ns.Note(state.id) or "")
    end)

    buildCtx(keep, data)

    right.tiles = { keep(data(buildTile(1))), keep(data(buildTile(2))), keep(data(buildTile(3))), keep(data(buildTile(4))) }

    right.tiles5 = {}
    for i, mode in ipairs(ns.MODES) do
        local tile = keep(data(buildModeTile(i, mode)))
        keep(data(tile.caption))
        keep(data(tile.mark))
        right.tiles5[i] = tile
    end

    right.hist = {}
    for i = 1, 3 do
        local fs = keep(data(ns.Text(frame, 12)))
        fs:SetHeight(16)
        right.hist[i] = fs
    end

    right.roleBox = keep(data(CreateFrame("Frame", nil, frame)))
    right.roleBox:SetHeight(54)
    right.roleBox:EnableMouse(true)
    right.roleBox:SetScript("OnEnter", function(self)
        ns.Tip(self, "ANCHOR_TOP", "Сколько боссов убито в каждой роли — все килы сезона")
    end)
    right.roleBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    right.roleBox.lines = {}
    for i = 1, 3 do
        local fs = ns.Text(right.roleBox, 13)
        fs:SetHeight(16)
        fs:SetPoint("TOPLEFT", right.roleBox, "TOPLEFT", 0, -(i - 1) * 18)
        right.roleBox.lines[i] = fs
    end

    buildTable(keep, data)

    right.empty = ns.Text(frame, 13, "CENTER")
    dim(right.empty)
    right.empty:SetWidth(400)
    right.empty:SetText("Нет рейдов в этой сложности")

    right.none = ns.Text(frame, 14, "CENTER")
    dim(right.none)
end

local OPTIONS = {
    { "chat", "Alt на нике в чате" },
    { "world", "Alt на игроке в мире" },
    { "frames", "Alt на рамках: группа, рейд, цель, VuhDo" },
    { "guild", "Alt в списке гильдии" },
    { "altOpen", "Alt+клик по нику открывает окно" },
    { "follow", "Окно следует за целью" },
    { "updates", "Сообщать об обновлениях" },
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
    local seasons = seasonList(nil)
    local current = ns.CurrentSeason()
    optPanel = CreateFrame("Frame", nil, frame)
    optPanel:SetWidth(320)
    optPanel:SetHeight(34 + #OPTIONS * 24 + 16 + 40 + math.max(#seasons, 1) * 22 + 34)
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
    for i, o in ipairs(OPTIONS) do
        local cb = checkRow(optPanel, 8 + i * 24, o[2])
        cb.key = o[1]
        cb:SetScript("OnClick", function(self)
            ns.SetOpt(self.key, self:GetChecked())
        end)
        optPanel.checks[i] = cb
    end

    local y = 8 + (#OPTIONS + 1) * 24 + 8
    local sep = line(optPanel, 0.2)
    sep:SetPoint("TOPLEFT", optPanel, "TOPLEFT", 10, -y)
    sep:SetPoint("TOPRIGHT", optPanel, "TOPRIGHT", -10, -y)
    local head = ns.Text(optPanel, 13)
    gold(head)
    head:SetWidth(296)
    head:SetPoint("TOPLEFT", 12, -(y + 8))
    head:SetText("Синхронизация с обновлялкой: какие сезоны скачивать")
    y = y + 8 + 34

    optPanel.seasonChecks = {}
    for i, sn in ipairs(seasons) do
        local text = "Сезон " .. sn
        if sn == current then text = text .. " — текущий, всегда" end
        local cb = checkRow(optPanel, y + (i - 1) * 22, text)
        cb.season = sn
        cb:SetScript("OnClick", function(self)
            ns.SetSeasonWanted(self.season, self:GetChecked())
        end)
        optPanel.seasonChecks[i] = cb
    end
    if #seasons == 0 then
        local none = ns.Text(optPanel, 12)
        dim(none)
        none:SetPoint("TOPLEFT", 14, -(y + 4))
        none:SetText("Сезоны появятся после первого обновления")
    end
    y = y + math.max(#seasons, 1) * 22 + 6
    local hint = ns.Text(optPanel, 12)
    dim(hint)
    hint:SetWidth(296)
    hint:SetPoint("TOPLEFT", 14, -y)
    hint:SetText("ОбновитьДанные.exe возьмёт это при следующем запуске")
end

local function showOptions(on)
    if on == nil then on = not optPanel:IsShown() end
    if not on then
        optPanel:Hide()
        return
    end
    if howPanel then howPanel:Hide() end
    ns.SyncSeasons()
    local current = ns.CurrentSeason()
    for _, cb in ipairs(optPanel.checks) do cb:SetChecked(ns.Opt(cb.key) and 1 or nil) end
    for _, cb in ipairs(optPanel.seasonChecks) do
        cb:SetChecked(ns.SeasonWanted(cb.season) and 1 or nil)
        if cb.season == current then
            cb:Disable()
            cb.label:SetTextColor(0.62, 0.62, 0.62)
        else
            cb:Enable()
            cb.label:SetTextColor(0.95, 0.95, 0.95)
        end
    end
    optPanel:Show()
end

local function reloadButton(parent)
    local b = ns.MakeButton(parent, 12, nil, 18)
    ns.FitButton(b, "/reload", 18)
    b.tip = function(self) ns.Tip(self, "ANCHOR_TOP", "Перезагрузить интерфейс", "Перечитать данные после ОбновитьДанные.exe") end
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

    local h1 = ns.Text(howPanel, 13, "LEFT", "head")
    h1:SetPoint("TOPLEFT", 16, -44)
    h1:SetText("1. Обновлялкой")
    local b1 = ns.Text(howPanel, 13)
    b1:SetWidth(408)
    b1:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -4)
    b1:SetText("Запустите ОбновитьДанные.exe в папке Interface\\AddOns\\Manacode_PlayerRaidsInfo, выберите сезоны и дождитесь конца загрузки. Потом в игре — /reload.")

    local h2 = ns.Text(howPanel, 13, "LEFT", "head")
    h2:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -12)
    h2:SetText("2. Вручную")
    local b2 = ns.Text(howPanel, 13)
    b2:SetWidth(408)
    b2:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -4)
    b2:SetText("Скачайте архив по ссылке и распакуйте в Interface\\AddOns с заменой файлов. Потом — /reload.")

    howPanel.url = urlBox(howPanel)
    howPanel.url:SetPoint("TOPLEFT", b2, "BOTTOMLEFT", 6, -8)
    howPanel.url:SetWidth(400)
    local hint = ns.Text(howPanel, 12)
    dim(hint)
    hint:SetPoint("TOPLEFT", howPanel.url, "BOTTOMLEFT", -6, -4)
    hint:SetText("Ссылку в игре не открыть: щёлкните по полю, Ctrl+C — скопировать")

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
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(18)
    b:SetHeight(18)
    b:SetPoint("RIGHT", anchor, "LEFT", -3, 0)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(tex)
    t:SetTexCoord(coord, 1 - coord, coord, 1 - coord)
    b:SetHighlightTexture(ns.WHITE)
    b:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.25)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) ns.Tip(self, "ANCHOR_BOTTOM", title) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    ns.MakeGlow(frame, 4, 24)
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

    applySize()
    return frame
end

function ns.OpenBrowser(query)
    local f = build()
    f:Show()
    applySize()
    updateStatus()
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
