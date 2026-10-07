local ADDON, ns = ...
local strsplit, strfind, strmatch, gmatch = strsplit, string.find, string.match, string.gmatch
local tinsert, tonumber, pairs = tinsert, tonumber, pairs
local FORMAT = 13
local EMPTY = {}
local function root()
    local r = PlayerRaids13
    if type(r) ~= "table" then return nil end
    return r
end
local function players()
    local r = root()
    return r and type(r.players) == "table" and r.players or EMPTY
end
ns.Players = players
function ns.Meta()
    local r = root()
    return r and type(r.meta) == "table" and r.meta or EMPTY
end
local function seasonFile(sn)
    local r = root()
    local f = r and type(r.seasons) == "table" and r.seasons[sn]
    if type(f) ~= "table" or type(f.players) ~= "table" then return nil end
    return f
end
local function modeFile(sn, mode)
    local r = root()
    local f = r and type(r.modes) == "table" and r.modes[tostring(sn) .. "." .. tostring(mode)]
    if type(f) ~= "table" or type(f.players) ~= "table" then return nil end
    return f
end
function ns.SeasonLoaded(sn)
    return type(sn) == "number" and seasonFile(sn) ~= nil
end
function ns.ModeLoaded(sn, mode)
    return type(sn) == "number" and modeFile(sn, mode) ~= nil
end
function ns.DataState()
    if not next(players()) then return "none" end
    local meta = ns.Meta()
    if tonumber(meta.v) ~= FORMAT then return "other" end
    if type(meta.baked) ~= "string" or meta.baked == "" then return "none" end
    return "ok"
end
function ns.DataOK()
    return ns.DataState() == "ok"
end
function ns.DataProblem()
    local st = ns.DataState()
    if st == "other" then return "данные другого формата — обновите аддон и данные в ManacodeUpdate" end
    if st == "none" then return "нет данных — скачайте их в ManacodeUpdate" end
    return nil
end
function ns.GM()
    local g = PlayerRaidsGM
    if type(g) ~= "table" or tonumber(g.v) ~= 1 or type(g.players) ~= "table" then return nil end
    return g
end
local gmRows = {}
ns.GM_LISTS = { ["Банки"] = true, ["Сумки"] = true, ["Банк"] = true }
function ns.GMRows(id)
    local g = id and ns.GM()
    local raw = g and g.players[id]
    if type(raw) ~= "string" or raw == "" then return nil end
    local hit = gmRows[id]
    if hit == nil then
        hit = {}
        for line in gmatch(raw, "[^\n]+") do
            local section, label, value, item = strsplit("\t", line)
            item = tonumber(item)
            if item and (item < 1 or item % 1 ~= 0) then item = nil end
            if section and label then tinsert(hit, { section = section, label = label, value = value or "", item = item }) end
        end
        gmRows[id] = hit
    end
    return #hit > 0 and hit or nil
end
function ns.MissingText()
    return "Не ходил в рейды или ходил до начала сбора рейд-логов (2023)"
end
local function parseBest(s)
    if not s or s == "" then return nil end
    local p, boss, mode, date, value, flag = strsplit(",", s)
    return { parse = tonumber(p), boss = boss, mode = mode, date = date, value = tonumber(value), unbuff = flag == "u" }
end
local function parseCell(c, ilvl)
    if not c or c == "" then return false end
    local role, v, p, i, flag = strmatch(c, "^([dht])(%d*):?(%d*):?(%d*):?(%a*)$")
    if not role then return false end
    return { role = role, value = tonumber(v), parse = tonumber(p), ilvl = tonumber(i) or ilvl, unbuff = flag == "u" }
end
local function parseStat(s, role)
    if not s or s == "" then return nil end
    local spec, L, w, better, of, avg, top, place, topOf = strsplit(",", s)
    local st = {
        spec = spec, L = tonumber(L), w = tonumber(w), better = tonumber(better), of = tonumber(of),
        avg = tonumber(avg), top = tonumber(top), place = tonumber(place), topOf = tonumber(topOf), role = role,
    }
    if not st.better and not st.top then return nil end
    return st
end
local BADGE_FAMILY = { top = true, bracket = true, parse = true }
local function badgeFamily(name)
    if BADGE_FAMILY[name] then return name, "d" end
    local base = strmatch(name, "^heal_?(%a+)$") or strmatch(name, "^h_?(%a+)$")
        or strmatch(name, "^(%a-)_?heal$") or strmatch(name, "^(%a-)_?h$")
    if base and BADGE_FAMILY[base] then return base, "h" end
    return nil
end
local function parseBadges(s)
    local out = {}
    for entry in gmatch(s or "", "[^,]+") do
        local name, tier, value, label = strmatch(entry, "^([%a_]-)(%d+):([^:]*):?(.*)$")
        local family, role = badgeFamily(name or "")
        tier, value = tonumber(tier), tonumber(value)
        if family and tier then
            tinsert(out, { family = family, role = role, tier = tier, value = value, label = label or "" })
        end
    end
    return out
end
local fileInfo = {}
local function modeInfo(sn, mode)
    local key = tostring(sn) .. "." .. tostring(mode)
    local hit = fileInfo[key]
    if hit ~= nil then return hit or nil end
    local m = modeFile(sn, mode)
    if not m then
        fileInfo[key] = false
        return nil
    end
    local bosses, index = {}, {}
    for code in gmatch(type(m.bosses) == "string" and m.bosses or "", "[^,%s]+") do
        tinsert(bosses, code)
        index[code] = #bosses
    end
    if #bosses == 0 then
        local z = ns.ZONE[ns.ModeZone(mode) or ""]
        for i, code in ipairs(z and z.bosses or {}) do
            bosses[i] = code
            index[code] = i
        end
    end
    hit = { season = sn, mode = mode, bosses = bosses, index = index, file = m }
    fileInfo[key] = hit
    return hit
end
function ns.ModeBosses(mode, sn)
    local info = type(sn) == "number" and modeInfo(sn, mode)
    if info then return info.bosses end
    local z = ns.ZONE[ns.ModeZone(mode) or ""]
    return z and z.bosses or EMPTY
end
local function raidHead(info, rid)
    local t = info.file.raids
    local raw = type(t) == "table" and rid and t[rid]
    if type(raw) ~= "string" then return nil, nil end
    local date, wipes = strmatch(raw, "^(%d*)|[^|]*|[^|]*|[^|]*|[^|]*|(%d*)")
    return date, tonumber(wipes)
end
local rowCache = {}
local function parseModeRow(raw, info, spec)
    local roles, kills, list = strsplit("|", raw)
    local out = { roleKills = { d = 0, h = 0, t = 0 }, bossKills = {}, raids = {} }
    local d, h, t = strmatch(roles or "", "^(%d*)%.(%d*)%.(%d*)")
    out.roleKills.d, out.roleKills.h, out.roleKills.t = tonumber(d) or 0, tonumber(h) or 0, tonumber(t) or 0
    local i = 0
    for entry in gmatch((kills or "") .. ",", "([^,]*),") do
        i = i + 1
        local k, first, flagged = strmatch(entry, "^(%d+)%.?(%d*)%.?(%d*)$")
        if k and info.bosses[i] then
            out.bossKills[info.bosses[i]] = { kills = tonumber(k), first = first, flagged = tonumber(flagged) }
        end
    end
    for entry in gmatch(list or "", "[^/]+") do
        local parts = { strsplit(",", entry) }
        local rid, il = tonumber(parts[1]), tonumber(parts[2])
        local raid = { season = info.season, mode = info.mode, rid = rid, ilvl = il, cells = {}, info = info, spec = spec }
        raid.date, raid.wipes = raidHead(info, rid)
        raid.date = raid.date or ""
        for b = 3, #parts do
            local c = parseCell(parts[b], il)
            raid.cells[b - 2] = c
            if c and c.unbuff then raid.unbuff = true end
        end
        tinsert(out.raids, raid)
    end
    return out
end
local function modeRow(id, sn, mode, spec)
    local key = id .. ":" .. sn .. ":" .. mode
    local hit = rowCache[key]
    if hit ~= nil then return hit or nil end
    local info = modeInfo(sn, mode)
    local raw = info and info.file.players[id]
    hit = type(raw) == "string" and parseModeRow(raw, info, spec) or false
    rowCache[key] = hit
    return hit or nil
end
local function lazyModes(fill)
    return setmetatable({}, { __index = function(t, mode)
        if type(mode) ~= "string" or not ns.MODE[mode] then return nil end
        local list = fill(mode)
        rawset(t, mode, list)
        return list
    end })
end
local function parseSeason(raw, sn, id)
    local gs, last, spec, raids, bd, bh, bt, rspec, stat, badges, statH = strsplit(";", raw)
    local s = {
        season = sn, id = id, gs = tonumber(gs), last = last, spec = spec ~= "" and spec or nil,
        raids = {}, flagged = {}, bestD = parseBest(bd), bestH = parseBest(bh), bestT = parseBest(bt),
    }
    for _, mode in ipairs(ns.MODES) do s.raids[mode] = 0 end
    for mode, n, f in gmatch(raids or "", "(%w+)%.(%d+)%.?(%d*)") do
        s.raids[mode] = tonumber(n) or 0
        s.flagged[mode] = tonumber(f)
    end
    s.stat = parseStat(stat, "d")
    s.statH = parseStat(statH, "h")
    s.badges = parseBadges(badges)
    s.roleSpecs = {}
    for role, rs, k in gmatch(rspec or "", "(%a)%.(%a+)%.(%d+)") do
        tinsert(s.roleSpecs, { role = role, spec = rs, n = tonumber(k) })
    end
    s.byMode = lazyModes(function(mode)
        local row = modeRow(id, sn, mode, s.spec)
        return row and row.raids or {}
    end)
    return s
end
local function parseHistory(s)
    local hist = {}
    for _, mode in ipairs(ns.MODES) do hist[mode] = {} end
    for mode, boss, kills, first in gmatch(s or "", "(%w+)%.(%a+)%.(%d+)%.(%d*)") do
        if hist[mode] then hist[mode][boss] = { kills = tonumber(kills), first = first } end
    end
    return hist
end
local function parseRow(id, raw)
    local name, class, prev, hist, badges, roles, seasons = strsplit("|", raw)
    if not class then return nil end
    local rec = { id = id, name = name, class = class, prev = {}, prevInfo = {}, seasonList = {} }
    for entry in gmatch(prev or "", "[^,]+") do
        local n, first, last = strsplit(":", entry)
        if n and n ~= "" then
            tinsert(rec.prev, n)
            tinsert(rec.prevInfo, { name = n, first = first, last = last })
        end
    end
    rec.hist = parseHistory(hist)
    rec.badges = {}
    for entry in gmatch(badges or "", "[^,]+") do
        local key, val = strmatch(entry, "^(%a+):?(.*)$")
        if key then rec.badges[key] = val or "" end
    end
    rec.roleKills = {}
    for mode, d, h, t in gmatch(roles or "", "(%w+)%.(%d+)%.(%d+)%.(%d+)") do
        rec.roleKills[mode] = { d = tonumber(d), h = tonumber(h), t = tonumber(t) }
    end
    for sn in gmatch(seasons or "", "%d+") do tinsert(rec.seasonList, tonumber(sn)) end
    return rec
end
local cache = {}
function ns.Get(id)
    if not id or not ns.DataOK() then return nil end
    local hit = cache[id]
    if hit ~= nil then return hit or nil end
    local raw = players()[id]
    local rec = type(raw) == "string" and parseRow(id, raw) or nil
    cache[id] = rec or false
    return rec
end
function ns.OtherNames(rec, shown)
    local out, seen = {}, {}
    seen[ns.Lower(shown or "")] = true
    local function add(n)
        if not n or n == "" then return end
        local low = ns.Lower(n)
        if not seen[low] then
            seen[low] = true
            tinsert(out, n)
        end
    end
    if rec then
        add(rec.name)
        for _, n in ipairs(rec.prev) do add(n) end
    end
    return out
end
local byName, hay, siteName, siteClass, sitePrev, total
local renames
function ns.Total()
    if total then return total end
    local n = 0
    for _ in pairs(players()) do n = n + 1 end
    return n
end
local function buildIndex()
    if byName then return end
    byName, hay, siteName, siteClass, sitePrev, total = {}, {}, {}, {}, {}, 0
    if not ns.DataOK() then return end
    local all = players()
    local prevOf = {}
    for id, raw in pairs(all) do
        total = total + 1
        local name, class, prev = strmatch(raw, "^([^|]*)|([^|]*)|([^|]*)")
        if name then
            siteName[id], siteClass[id] = name, class
            local low = ns.Lower(name)
            if not byName[low] then byName[low] = id end
            local h = low
            if prev and prev ~= "" then
                sitePrev[id] = strmatch(prev, "^[^,:]+")
                local lp = ns.Lower((string.gsub(prev, ":%d*", "")))
                prevOf[id] = lp
                h = h .. "," .. lp
            end
            local own = ns.NameOf(id)
            if own then
                local lo = ns.Lower(own)
                if lo ~= low then h = h .. "," .. lo end
            end
            hay[id] = h
        end
    end
    for id, lp in pairs(prevOf) do
        for n in gmatch(lp, "[^,]+") do
            if not byName[n] then byName[n] = id end
        end
    end
    for id, own in pairs(PlayerRaidsDB.names or {}) do
        if all[id] then byName[ns.Lower(own)] = id end
    end
end
ns.BuildIndex = buildIndex
function ns.OnNameSeen(id, name)
    renames = nil
    if not byName or not players()[id] then return end
    local low = ns.Lower(name)
    byName[low] = id
    if hay[id] and not strfind(hay[id], low, 1, true) then
        hay[id] = hay[id] .. "," .. low
    end
end
function ns.FindId(name)
    if not name or name == "" then return nil end
    local id = ns.IdOf(name)
    if not ns.DataOK() then return id end
    if id and players()[id] then return id end
    buildIndex()
    return byName[ns.Lower(name)] or id
end
function ns.Matches(id, lowQuery)
    if lowQuery == "" then return true end
    buildIndex()
    local h = hay[id]
    return h and strfind(h, lowQuery, 1, true) and true or false
end
function ns.Brief(id)
    buildIndex()
    local own = ns.NameOf(id)
    local site = siteName[id]
    local shown, was = site, sitePrev[id]
    if own and site and own ~= site then shown, was = own, site end
    return shown or own or ("#" .. tostring(id)), siteClass[id], was
end
function ns.Search(query, limit)
    local out = {}
    if not ns.DataOK() then return out, 0 end
    buildIndex()
    local q = ns.Lower(string.match(query or "", "^%s*(.-)%s*$") or "")
    q = string.gsub(q, ",", "")
    if q == "" then return out, 0 end
    local rank = {}
    for id, h in pairs(hay) do
        local at = strfind(h, q, 1, true)
        if at then
            local r = 3
            if byName[q] == id then r = 1
            elseif at == 1 or strfind(h, "," .. q, 1, true) then r = 2 end
            rank[id] = r
            tinsert(out, id)
        end
    end
    table.sort(out, function(a, b)
        if rank[a] ~= rank[b] then return rank[a] < rank[b] end
        local na, nb = siteName[a] or "", siteName[b] or ""
        if na ~= nb then return na < nb end
        return a < b
    end)
    for id in pairs(PlayerRaidsNotes or {}) do
        local own = not hay[id] and ns.NameOf(id)
        if own and strfind(ns.Lower(own), q, 1, true) then
            rank[id] = 3
            tinsert(out, id)
        end
    end
    local found = #out
    if limit then
        for i = found, limit + 1, -1 do out[i] = nil end
    end
    return out, found
end
function ns.RecentSeen(limit)
    local out = {}
    if not ns.DataOK() then return out end
    local all = players()
    local names = PlayerRaidsDB.names or {}
    local seen = PlayerRaidsDB.seen or {}
    for id in pairs(names) do
        if all[id] then tinsert(out, id) end
    end
    table.sort(out, function(a, b)
        local sa, sb = seen[a] or 0, seen[b] or 0
        if sa ~= sb then return sa > sb end
        return (names[a] or "") < (names[b] or "")
    end)
    if limit then
        for i = #out, limit + 1, -1 do out[i] = nil end
    end
    return out
end
local function seasonsDesc()
    local list = {}
    for _, sn in ipairs(ns.Meta().seasons or EMPTY) do
        sn = tonumber(sn)
        if sn then tinsert(list, sn) end
    end
    table.sort(list, function(x, y) return x > y end)
    return list
end
ns.SeasonsDesc = seasonsDesc
local function lastKill(id, order)
    for _, sn in ipairs(order) do
        local f = seasonFile(sn)
        local raw = f and f.players[id]
        if type(raw) == "string" then return strmatch(raw, "^[^;]*;(%d*)") or "" end
    end
    return ""
end
function ns.Renames()
    if renames then return renames end
    renames = {}
    if not ns.DataOK() then return renames end
    buildIndex()
    local all = players()
    local pick = {}
    for id, raw in pairs(all) do
        if strfind(raw, "^[^|]*|[^|]*|[^|]") then pick[id] = true end
    end
    for id, own in pairs(PlayerRaidsDB.names or {}) do
        if siteName[id] and ns.Lower(own) ~= ns.Lower(siteName[id]) then pick[id] = true end
    end
    local order = seasonsDesc()
    local last = {}
    for id in pairs(pick) do
        tinsert(renames, id)
        last[id] = lastKill(id, order)
    end
    table.sort(renames, function(a, b)
        if last[a] ~= last[b] then return last[a] > last[b] end
        local na, nb = siteName[a] or "", siteName[b] or ""
        if na ~= nb then return na < nb end
        return a < b
    end)
    return renames
end
function ns.RenameLine(id)
    buildIndex()
    local site = siteName[id]
    local shown = ns.NameOf(id) or site or ("#" .. tostring(id))
    local olds, seen = {}, { [ns.Lower(shown)] = true }
    local function add(n)
        if n and n ~= "" and not seen[ns.Lower(n)] then
            seen[ns.Lower(n)] = true
            tinsert(olds, n)
        end
    end
    add(site)
    local raw = players()[id]
    local prev = raw and strmatch(raw, "^[^|]*|[^|]*|([^|]*)")
    for n in gmatch(prev or "", "[^,]+") do add(strmatch(n, "^[^:]+")) end
    local text = "|cff" .. ns.ClassHex(siteClass[id]) .. shown .. "|r"
    if #olds > 0 then text = text .. " " .. ns.Color("dim", "< " .. table.concat(olds, ", ")) end
    return text
end
function ns.GameRename(id, rec)
    local own = ns.NameOf(id)
    if own and rec and rec.name and ns.Lower(own) ~= ns.Lower(rec.name) then
        return "в игре: " .. own .. ", на сайте: " .. rec.name
    end
    return nil
end
function ns.HistLine(rec)
    if not rec or not rec.hist then return nil end
    local bits = {}
    for _, z in ipairs(ns.ZONES) do
        local bestMode, bestN = nil, 0
        for _, mode in ipairs(ns.MODES) do
            local h = ns.MODE[mode].zone == z.code and rec.hist[mode] and rec.hist[mode][z.last]
            if h and (h.kills or 0) > bestN then bestMode, bestN = mode, h.kills end
        end
        if bestMode then
            tinsert(bits, ns.BossName(z.last) .. " " .. ns.MODE[bestMode].cell .. " " .. ns.Color("white", "x" .. bestN))
        end
    end
    if #bits == 0 then return nil end
    return table.concat(bits, ", ")
end
function ns.NameHistory(id, rec)
    local lines = {}
    if not rec then return lines end
    local own = ns.NameOf(id)
    if own and ns.Lower(own) ~= ns.Lower(rec.name) then
        tinsert(lines, "сейчас в игре: " .. own .. " (с сайта: " .. rec.name .. ")")
    end
    local p = rec.prevInfo or {}
    if #p == 0 then return lines end
    local hex = ns.ClassHex(rec.class)
    local function grey(n) return ns.Color("grey", n) end
    tinsert(lines, "после " .. ns.DayMonthYearFull(p[1].last) .. "  " .. grey(p[1].name) .. ns.ARROW .. "|cff" .. hex .. rec.name .. "|r")
    for i = 1, #p - 1 do
        tinsert(lines, ns.DayMonthYearFull(p[i].first) .. "  " .. grey(p[i + 1].name) .. ns.ARROW .. grey(p[i].name))
    end
    tinsert(lines, "с " .. ns.DayMonthYearFull(p[#p].first) .. "  " .. grey(p[#p].name))
    return lines
end
function ns.NameChain(id, rec)
    if not rec then return nil end
    local chain = {}
    for i = #rec.prev, 1, -1 do tinsert(chain, rec.prev[i]) end
    tinsert(chain, rec.name)
    local own = ns.NameOf(id)
    if own and ns.Lower(own) ~= ns.Lower(rec.name) then tinsert(chain, own .. " (в игре)") end
    if #chain < 2 then return nil end
    return table.concat(chain, ns.ARROW)
end
function ns.NamesShort(list, maxChars)
    local out, used = {}, 0
    for i, n in ipairs(list) do
        local chars = ns.Utf8Len(n)
        if i > 1 and used + chars + 2 > maxChars then
            return table.concat(out, ", ") .. " +" .. (#list - i + 1)
        end
        tinsert(out, n)
        used = used + chars + 2
    end
    return table.concat(out, ", ")
end
function ns.CurrentSeason()
    return tonumber(ns.Meta().season)
end
ns.SEASON_CIRCLE = {
    { sn = 7, from = "01.04.2026", dates = "с 01.04.2026" },
    { sn = 6, from = "12.08.2025", dates = "12.08.2025 - 31.03.2026" },
    { sn = 5, from = "01.11.2024", dates = "01.11.2024 - 11.08.2025" },
    { sn = 4, from = "20.12.2023", dates = "20.12.2023 - 31.10.2024" },
}
local function circleOf(sn)
    for _, e in ipairs(ns.SEASON_CIRCLE) do
        if e.sn == sn then return e end
    end
    return nil
end
function ns.SeasonEmptyText(sn, what)
    what = what or "рейдов"
    local e = circleOf(sn)
    if sn == ns.CurrentSeason() then
        if e then return "Логи текущего сезона собираются с " .. e.from .. " — за это время у персонажа нет " .. what end
        return "В текущем сезоне у персонажа нет " .. what
    end
    if e then return "В сезоне " .. sn .. " (" .. e.dates .. ") у персонажа нет " .. what end
    return "В сезоне " .. sn .. " у персонажа нет " .. what
end
local blockCache = {}
function ns.SeasonBlock(rec, sn)
    if not rec or type(sn) ~= "number" then return nil, "none" end
    local f = seasonFile(sn)
    if not f then return nil, "notdownloaded" end
    local key = rec.id .. ":" .. sn
    local hit = blockCache[key]
    if hit == nil then
        local raw = f.players[rec.id]
        hit = type(raw) == "string" and parseSeason(raw, sn, rec.id) or false
        blockCache[key] = hit
    end
    if not hit then return nil, "empty" end
    return hit
end
function ns.SeasonOf(rec, sn)
    return (ns.SeasonBlock(rec, sn))
end
function ns.HadSeason(rec, sn)
    for _, x in ipairs(rec and rec.seasonList or EMPTY) do
        if x == sn then return true end
    end
    return false
end
function ns.SeasonMessage(sn, why)
    if why == "notdownloaded" then return "Сезон " .. sn .. " не скачан — отметьте его в ManacodeUpdate" end
    if why == "empty" then return ns.SeasonEmptyText(sn) end
    return nil
end
function ns.ModeMessage(sn, mode)
    local what = "Рейды «" .. ns.ModeFull(mode) .. "»" .. (type(sn) == "number" and (" сезона " .. sn) or "")
    return what .. " не скачаны — отметьте их в ManacodeUpdate, нажмите «Скачать выбранное» и наберите /reload"
end
function ns.ModeRow(s, mode)
    if not s or not mode then return nil end
    if s.blocks then
        local sum = { roleKills = { d = 0, h = 0, t = 0 }, bossKills = {}, any = false }
        for _, b in ipairs(s.blocks) do
            local row = ns.ModeRow(b, mode)
            if row then
                sum.any = true
                for r, n in pairs(row.roleKills) do sum.roleKills[r] = sum.roleKills[r] + n end
                for boss, k in pairs(row.bossKills) do
                    local a = sum.bossKills[boss] or { kills = 0, flagged = 0 }
                    a.kills = a.kills + (k.kills or 0)
                    a.flagged = a.flagged + (k.flagged or 0)
                    if k.first and k.first ~= "" and (not a.first or k.first < a.first) then a.first = k.first end
                    sum.bossKills[boss] = a
                end
            end
        end
        return sum.any and sum or nil
    end
    return modeRow(s.id, s.season, mode, s.spec)
end
function ns.ModeMissing(s, mode)
    if not s or not mode then return false end
    if s.blocks then
        for _, b in ipairs(s.blocks) do
            if ns.ModeMissing(b, mode) then return true end
        end
        return false
    end
    return (s.raids[mode] or 0) > 0 and not ns.ModeLoaded(s.season, mode)
end
function ns.BossIndex(raid, boss)
    return raid and raid.info and raid.info.index[boss]
end
function ns.RaidBosses(raid)
    return raid and raid.info and raid.info.bosses or EMPTY
end
function ns.RaidIlvl(raid)
    if not raid then return nil end
    if raid.ilvl then return raid.ilvl end
    local best
    for _, c in pairs(raid.cells) do
        if c and c.ilvl and (not best or c.ilvl > best) then best = c.ilvl end
    end
    return best
end
function ns.HeroDate(rec)
    local d = rec and rec.badges and rec.badges.hero
    if not d or not string.match(d, "^%d%d%d%d%d%d$") then return nil end
    return d
end
local function bestKey(b)
    return b and b.parse
end
ns.BestParse = bestKey
local function betterBest(a, b)
    local kb = bestKey(b)
    if not kb then return a end
    local ka = bestKey(a)
    if not ka or kb > ka or (kb == ka and (b.value or 0) > (a.value or 0)) then return b end
    return a
end
function ns.AllSeasons(rec, list)
    if not rec then return nil end
    local all = { season = "all", raids = {}, flagged = {}, count = 0, blocks = {} }
    for _, mode in ipairs(ns.MODES) do all.raids[mode] = 0 end
    for _, sn in ipairs(list or EMPTY) do
        local s = ns.SeasonBlock(rec, sn)
        if s then
            all.count = all.count + 1
            tinsert(all.blocks, s)
            for _, mode in ipairs(ns.MODES) do
                all.raids[mode] = all.raids[mode] + (s.raids[mode] or 0)
                if s.flagged[mode] then all.flagged[mode] = (all.flagged[mode] or 0) + s.flagged[mode] end
            end
            if s.gs and (not all.gs or s.gs > all.gs) then all.gs = s.gs end
            if s.last and s.last ~= "" and (not all.last or s.last > all.last) then all.last = s.last end
            all.spec = all.spec or s.spec
            all.roleSpecs = all.roleSpecs or (#s.roleSpecs > 0 and s.roleSpecs or nil)
            if not all.stat and s.stat then all.stat, all.statSeason = s.stat, sn end
            if not all.statH and s.statH then all.statH, all.statHSeason = s.statH, sn end
            if not all.badges and s.badges and #s.badges > 0 then all.badges, all.badgeSeason = s.badges, sn end
            all.bestD = betterBest(all.bestD, s.bestD)
            all.bestH = betterBest(all.bestH, s.bestH)
            all.bestT = betterBest(all.bestT, s.bestT)
        end
    end
    if all.count == 0 then return nil end
    all.roleSpecs = all.roleSpecs or {}
    all.byMode = lazyModes(function(mode)
        local out = {}
        for _, s in ipairs(all.blocks) do
            for _, raid in ipairs(s.byMode[mode]) do tinsert(out, raid) end
        end
        return out
    end)
    return all
end
local HEAL_SPECS = { holy = true, discipline = true, restoration = true }
local TANK_SPECS = { protection = true, guardian = true }
function ns.SpecRole(spec)
    local key = string.gsub(ns.Lower(spec or ""), "[%s_%-]", "")
    if HEAL_SPECS[key] then return "h" end
    if TANK_SPECS[key] then return "t" end
    return "d"
end
function ns.RaidRole(raid)
    local n = { d = 0, h = 0, t = 0 }
    for _, c in pairs(raid and raid.cells or EMPTY) do
        if c and n[c.role] then n[c.role] = n[c.role] + 1 end
    end
    local best, bestN = nil, 0
    for _, r in ipairs({ "t", "h", "d" }) do
        if n[r] > bestN then best, bestN = r, n[r] end
    end
    return best
end
function ns.RoleAverage(s, mode)
    local out = {}
    for _, raid in ipairs(s and s.byMode[mode] or EMPTY) do
        local seen = {}
        for _, c in pairs(raid.cells) do
            if c and c.value and (c.role == "d" or c.role == "h") then
                local a = out[c.role] or { sum = 0, n = 0, raids = 0 }
                a.sum, a.n = a.sum + c.value, a.n + 1
                if not seen[c.role] then
                    seen[c.role] = true
                    a.raids = a.raids + 1
                end
                out[c.role] = a
            end
        end
    end
    for _, a in pairs(out) do a.avg = floor(a.sum / a.n + 0.5) end
    return out
end
local function roleIn(s, mode)
    local n = { d = 0, h = 0, t = 0 }
    for _, raid in ipairs(s.byMode[mode]) do
        for _, c in pairs(raid.cells) do
            if c and n[c.role] then n[c.role] = n[c.role] + 1 end
        end
    end
    local best, bestN = nil, 0
    for _, r in ipairs({ "t", "h", "d" }) do
        if n[r] > bestN then best, bestN = r, n[r] end
    end
    return best
end
function ns.StatBlocks(rec)
    local out = {}
    if not rec then return out end
    local list = seasonsDesc()
    local cur = ns.CurrentSeason()
    if cur and #list == 0 then list[1] = cur end
    for _, sn in ipairs(list) do
        local s = ns.SeasonBlock(rec, sn)
        if s then tinsert(out, { sn = sn, s = s }) end
    end
    return out
end
function ns.RecentRaids(rec, limit)
    local list = {}
    for _, b in ipairs(ns.StatBlocks(rec)) do
        for _, mode in ipairs(ns.MODES) do
            for _, raid in ipairs(b.s.byMode[mode]) do tinsert(list, raid) end
        end
    end
    table.sort(list, function(x, y)
        if x.date ~= y.date then return x.date > y.date end
        return (x.rid or 0) > (y.rid or 0)
    end)
    local n = #list
    if limit then
        for i = n, limit + 1, -1 do list[i] = nil end
    end
    return list, n
end
function ns.PickRecent(list, need, fill)
    need, fill = need or 3, fill or 5
    table.sort(list, function(x, y) return x.date > y.date end)
    local out = {}
    local ref = list[1] and list[1].il
    local i = 1
    while list[i] do
        local e = list[i]
        if ref and e.il and e.il < ref - 2 then break end
        tinsert(out, e)
        i = i + 1
    end
    if #out < need then
        while list[i] and #out < fill do
            tinsert(out, list[i])
            i = i + 1
        end
    end
    return out, ref
end
function ns.RaidStat(rec, mode, boss)
    local out = {}
    if not rec then return out end
    local cur = ns.CurrentSeason()
    local blocks = ns.StatBlocks(rec)
    for _, b in ipairs(blocks) do
        if not out.role then out.role = roleIn(b.s, mode) end
        if not out.spec then out.spec = b.s.spec end
    end
    if not out.role and out.spec then out.role = ns.SpecRole(out.spec) end
    local role = out.role or "d"
    local list = {}
    for _, bl in ipairs(blocks) do
        for _, raid in ipairs(bl.s.byMode[mode]) do
            local bi = ns.BossIndex(raid, boss)
            local c = bi and raid.cells[bi]
            if c and c.value and c.role == role then
                tinsert(list, { v = c.value, il = ns.RaidIlvl(raid), date = tonumber(raid.date) or 0, sn = bl.sn })
            end
        end
    end
    local picked, ref = ns.PickRecent(list)
    if #picked == 0 then return out end
    local sum, mn, low = 0, nil, nil
    for _, e in ipairs(picked) do
        sum = sum + e.v
        if not mn or e.v < mn then mn = e.v end
        if e.il and (not low or e.il < low) then low = e.il end
    end
    out.avg, out.min, out.n, out.ilvl, out.ilvlLow = floor(sum / #picked + 0.5), mn, #picked, ref, low
    if picked[1].sn ~= cur then out.season = picked[1].sn end
    return out
end
local raidCache = {}
function ns.RaidInfo(raid)
    local info = raid and raid.info
    local t = info and info.file.raids
    if type(t) ~= "table" or not raid.rid then return nil end
    local key = info.season .. "." .. info.mode .. ":" .. raid.rid
    local hit = raidCache[key]
    if hit ~= nil then return hit or nil end
    local raw = t[raid.rid]
    local out = false
    if type(raw) == "string" then
        local date, mode, leader, guild, bosses, wipes, minutes, hero, perBoss = strsplit("|", raw)
        local killed, of = strmatch(bosses or "", "^(%d+)/(%d+)$")
        out = {
            date = date, mode = mode, leader = leader ~= "" and leader or nil, guild = guild ~= "" and guild or nil,
            killed = tonumber(killed), total = tonumber(of), wipes = tonumber(wipes), minutes = tonumber(minutes),
            hero = hero == "1", bossWipes = {},
        }
        for code, n in gmatch(perBoss or "", "(%a+)%.(%d+)") do
            tinsert(out.bossWipes, { code = code, n = tonumber(n) })
        end
        table.sort(out.bossWipes, function(a, b)
            local oa, ob = ns.BOSS_ORDER[a.code] or 99, ns.BOSS_ORDER[b.code] or 99
            if oa ~= ob then return oa < ob end
            return a.code < b.code
        end)
    end
    raidCache[key] = out
    return out or nil
end
local BADGE_ORDER = { "top", "bracket", "parse" }
function ns.Pct(x)
    if not x then return "" end
    if x >= 10 then return floor(x + 0.5) .. "%" end
    return ns.Decimal(floor(x * 10 + 0.5) / 10) .. "%"
end
function ns.StatScore(st)
    if not st then return nil end
    if st.top then return floor(math.max(math.min(100 - st.top, 100), 0)) end
    if st.better then return floor(math.max(math.min(st.better, 100), 0)) end
    return nil
end
function ns.BadgeText(b)
    local heal = b.role == "h"
    if b.family == "top" then return "Топ-" .. b.tier .. "% спека" .. (heal and " по хилу" or "") end
    if b.family == "bracket" then return "Лучше " .. b.tier .. "% своего илвла" .. (heal and " по хилу" or "") end
    local n = floor((b.value or 0) + 0.5)
    return "Парс " .. (heal and "хил " or "") .. b.tier .. (n > 1 and (" x" .. n) or "")
end
function ns.BadgeLine(b)
    local unit = b.role == "h" and "хпс" or "дпс"
    if b.family == "top" then
        local place, of = strmatch(b.label or "", "#(%d+)/(%d+)")
        local text = "Топ " .. ns.Pct(b.value) .. " игроков спека по лучшему " .. unit .. " сезона"
        if place then text = "#" .. ns.Thousands(tonumber(place)) .. " из " .. ns.Thousands(tonumber(of)) .. ", топ " .. ns.Pct(b.value) .. " по лучшему " .. unit .. " сезона" end
        return text
    end
    if b.family == "bracket" then
        local of = strmatch(b.label or "", "(%d+)")
        return "Средний " .. unit .. " выше, чем у " .. ns.Pct(b.value) .. " игроков спека с таким же илвлом"
            .. (of and (" (из " .. ns.Thousands(tonumber(of)) .. ")") or "")
    end
    return "Килов с парсом " .. b.tier .. (b.role == "h" and " за хила" or "") .. " за сезон: " .. floor((b.value or 0) + 0.5)
end
function ns.TopBadges(list, role)
    local best = {}
    for _, b in ipairs(list or EMPTY) do
        if not role or b.role == role then
            local key = b.family .. (b.role or "d")
            local cur = best[key]
            if not cur or (b.family == "top" and b.tier < cur.tier) or (b.family ~= "top" and b.tier > cur.tier) then
                best[key] = b
            end
        end
    end
    local out = {}
    for _, r in ipairs({ "d", "h" }) do
        for _, f in ipairs(BADGE_ORDER) do
            if best[f .. r] then tinsert(out, best[f .. r]) end
        end
    end
    return out
end
function ns.StatTop(st)
    if not st or not st.top then return nil end
    local text = "топ " .. ns.Pct(st.top)
    if st.place and st.topOf then text = "#" .. ns.Thousands(st.place) .. " из " .. ns.Thousands(st.topOf) .. ", " .. text end
    return text
end
function ns.StatIlvl(st)
    if not st or not st.L then return nil end
    local w = st.w or 0
    if w == 0 then return "Илвл " .. st.L end
    return "Илвл " .. (st.L - w) .. "-" .. (st.L + w)
end
function ns.StatBracket(st)
    if not st or not st.better then return nil end
    local text = "лучше " .. floor(st.better) .. "%"
    if st.of and st.of > 0 then text = text .. " из " .. ns.Thousands(st.of) end
    return text
end
