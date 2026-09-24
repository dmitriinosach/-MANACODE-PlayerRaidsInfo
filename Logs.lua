local ADDON, ns = ...

local strsplit, strfind, strmatch, gmatch = strsplit, string.find, string.match, string.gmatch
local tinsert, tonumber, pairs = tinsert, tonumber, pairs

local FORMAT = 11

function ns.Meta()
    return type(PlayerRaidsMeta) == "table" and PlayerRaidsMeta or {}
end

function ns.DataState()
    local meta = ns.Meta()
    if tonumber(meta.v) ~= FORMAT then
        if type(PlayerRaidsData) == "table" and next(PlayerRaidsData) then return "old" end
        return "none"
    end
    if not meta.baked or meta.baked == "" or not next(PlayerRaidsData or {}) then return "none" end
    return "ok"
end

function ns.DataOK()
    return ns.DataState() == "ok"
end

function ns.DataProblem()
    local st = ns.DataState()
    if st == "old" then return "выгрузка старого формата — запустите ОбновитьДанные" end
    if st == "none" then return "нет выгрузки — запустите ОбновитьДанные" end
    return nil
end

local function parseBest(s)
    if not s or s == "" then return nil end
    local p, boss, mode, date, value = strsplit(",", s)
    return { parse = tonumber(p), boss = boss, mode = mode, date = date, value = tonumber(value) }
end

local function parseCell(c)
    if not c or c == "" then return false end
    local role, v, p, g, i = strmatch(c, "^([dht])(%d*):?(%d*):?(%d*):?(%d*)$")
    if not role then return false end
    return { role = role, value = tonumber(v), parse = tonumber(p), gear = tonumber(g), ilvl = tonumber(i) }
end

local function parseRaids(s, season)
    local all, byMode = {}, {}
    for _, mode in ipairs(ns.MODES) do byMode[mode] = {} end
    if not s or s == "" then return all, byMode end
    for entry in gmatch(s, "[^/]+") do
        local date, mode, wipes, c1, c2, c3 = strsplit(",", entry)
        if mode then
            local raid = {
                season = season, date = date, mode = mode, wipes = tonumber(wipes),
                cells = { parseCell(c1), parseCell(c2), parseCell(c3) },
            }
            tinsert(all, raid)
            if byMode[mode] then tinsert(byMode[mode], raid) end
        end
    end
    return all, byMode
end

local parseHistory

local function parseSeason(block)
    local sn, gs, last, spec, raids, bd, bh, list, kills, roles, bt = strsplit(";", block)
    local s = {
        season = tonumber(sn), gs = tonumber(gs), last = last, spec = spec,
        raids = {}, bestD = parseBest(bd), bestH = parseBest(bh),
    }
    local r = { strsplit(",", raids or "") }
    for i, mode in ipairs(ns.MODES) do s.raids[mode] = tonumber(r[i]) or 0 end
    s.recent, s.byMode = parseRaids(list, s.season)
    s.hist = parseHistory(kills)
    for _, raid in ipairs(s.recent) do raid.spec = s.spec end
    s.bestT = parseBest(bt)
    s.roleKills = {}
    for mode, d, h, t in gmatch(roles or "", "(%a+)%.(%d+)%.(%d+)%.(%d+)") do
        s.roleKills[mode] = { d = tonumber(d), h = tonumber(h), t = tonumber(t) }
    end
    return s
end

function parseHistory(s)
    local hist = {}
    for _, mode in ipairs(ns.MODES) do hist[mode] = {} end
    for mode, boss, kills, first in gmatch(s or "", "(%a+)%.(%a+)%.(%d+)%.(%d*)") do
        if hist[mode] then hist[mode][boss] = { kills = tonumber(kills), first = first } end
    end
    return hist
end

local function parseRow(id, raw)
    local parts = { strsplit("|", raw) }
    if #parts < 5 then return nil end
    local rec = { id = id, name = parts[1], class = parts[2], prev = {}, seasons = {} }
    rec.prevInfo = {}
    for entry in gmatch(parts[3] or "", "[^,]+") do
        local name, first, last = strsplit(":", entry)
        if name and name ~= "" then
            tinsert(rec.prev, name)
            tinsert(rec.prevInfo, { name = name, first = first, last = last })
        end
    end
    rec.hist = parseHistory(parts[4])
    rec.badges = {}
    for entry in gmatch(parts[5] or "", "[^,]+") do
        local key, val = strmatch(entry, "^(%a+):?(.*)$")
        if key then rec.badges[key] = val or "" end
    end
    rec.roleKills = {}
    for mode, d, h, t in gmatch(parts[6] or "", "(%a+)%.(%d+)%.(%d+)%.(%d+)") do
        rec.roleKills[mode] = { d = tonumber(d), h = tonumber(h), t = tonumber(t) }
    end
    for i = 7, #parts do
        if parts[i] ~= "" then tinsert(rec.seasons, parseSeason(parts[i])) end
    end
    return rec
end

ns.ParseRow = parseRow

local cache = {}

function ns.Get(id)
    if not id or not ns.DataOK() then return nil end
    local hit = cache[id]
    if hit ~= nil then return hit or nil end
    local raw = PlayerRaidsData[id]
    local rec = raw and parseRow(id, raw)
    cache[id] = rec or false
    return rec
end

function ns.SeasonOf(rec, season)
    if not rec then return nil end
    for _, s in ipairs(rec.seasons) do
        if s.season == season then return s end
    end
    return nil
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
    for _ in pairs(PlayerRaidsData or {}) do n = n + 1 end
    return n
end

local function buildIndex()
    if byName then return end
    byName, hay, siteName, siteClass, sitePrev, total = {}, {}, {}, {}, {}, 0
    if not ns.DataOK() then return end
    local prevOf = {}
    for id, raw in pairs(PlayerRaidsData) do
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
        if PlayerRaidsData[id] then byName[ns.Lower(own)] = id end
    end
end

ns.BuildIndex = buildIndex

function ns.OnNameSeen(id, name)
    renames = nil
    if not byName or not PlayerRaidsData[id] then return end
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
    if id and PlayerRaidsData[id] then return id end
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
    local names = PlayerRaidsDB.names or {}
    local seen = PlayerRaidsDB.seen or {}
    for id in pairs(names) do
        if PlayerRaidsData[id] then tinsert(out, id) end
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

function ns.Renames()
    if renames then return renames end
    renames = {}
    if not ns.DataOK() then return renames end
    buildIndex()
    local pick = {}
    for id, raw in pairs(PlayerRaidsData) do
        if strfind(raw, "^[^|]*|[^|]*|[^|]") then pick[id] = true end
    end
    for id, own in pairs(PlayerRaidsDB.names or {}) do
        if siteName[id] and ns.Lower(own) ~= ns.Lower(siteName[id]) then pick[id] = true end
    end
    local last = {}
    for id in pairs(pick) do
        tinsert(renames, id)
        last[id] = strmatch(PlayerRaidsData[id], "^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|%d+;[^;]*;(%d*)") or ""
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
    local raw = PlayerRaidsData[id]
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

local HIST_SHORT = { ih = "25 гер", iu = "25 анбаф", ["in"] = "25 об", rh = "25 гер", rn = "25 об" }

function ns.HistLine(rec)
    if not rec or not rec.hist then return nil end
    local bits = {}
    for _, group in ipairs({ { "lich", { "ih", "iu", "in" } }, { "hal", { "rh", "rn" } } }) do
        local boss, bestMode, bestN = group[1], nil, 0
        for _, mode in ipairs(group[2]) do
            local h = rec.hist[mode] and rec.hist[mode][boss]
            if h and (h.kills or 0) > bestN then bestMode, bestN = mode, h.kills end
        end
        if bestMode then
            tinsert(bits, ns.BOSS[boss] .. " " .. HIST_SHORT[bestMode] .. " " .. ns.Color("white", "×" .. bestN))
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

local ARCHIVE = "Manacode_PlayerRaidsInfo_Archive"
local archiveTried, archiveReason
local archCache = {}

function ns.CurrentSeason()
    return tonumber(ns.Meta().season)
end

function ns.ArchiveLoaded()
    return IsAddOnLoaded and IsAddOnLoaded(ARCHIVE) and true or false
end

function ns.LoadArchive()
    if ns.ArchiveLoaded() then return true end
    if archiveTried then return false, archiveReason end
    archiveTried = true
    if type(LoadAddOn) ~= "function" then
        archiveReason = "MISSING"
        return false, archiveReason
    end
    local ok, loaded, reason = pcall(LoadAddOn, ARCHIVE)
    if ok and loaded then return true end
    archiveReason = ok and reason or "FAILED"
    return false, archiveReason
end

function ns.ArchiveProblem(reason)
    if reason == "MISSING" then
        return "Архив сезонов не установлен — запустите ОбновитьДанные.exe"
    end
    if reason == "DISABLED" then
        return "Архив сезонов выключен в списке аддонов — включите Manacode_PlayerRaidsInfo_Archive"
    end
    if reason == "INTERFACE_VERSION" then
        return "Архив сезонов устарел — запустите ОбновитьДанные.exe"
    end
    return "Архив сезонов не загрузился (" .. tostring(reason) .. ")"
end

function ns.SeasonBlock(rec, season, noLoad)
    if not rec or not season then return nil, "none" end
    local cur = ns.SeasonOf(rec, season)
    if cur then return cur end
    if season == ns.CurrentSeason() then return nil, "empty" end
    if not ns.ArchiveLoaded() then
        if noLoad then return nil, "notloaded" end
        local ok, reason = ns.LoadArchive()
        if not ok then return nil, "archive", reason end
    end
    local arch
    if type(PlayerRaidsArchive) == "table" then arch = PlayerRaidsArchive[season] end
    if arch == false then return nil, "notdownloaded" end
    if type(arch) ~= "table" then return nil, "nofile" end
    local key = rec.id .. ":" .. season
    local hit = archCache[key]
    if hit == nil then
        local raw = arch[rec.id]
        hit = type(raw) == "string" and raw ~= "" and parseSeason(raw) or false
        archCache[key] = hit
    end
    if not hit then return nil, "empty" end
    return hit
end

function ns.SeasonMessage(season, why, reason)
    if why == "archive" then return ns.ArchiveProblem(reason) end
    if why == "notdownloaded" then
        return "Сезон " .. season .. " не скачан — отметьте его в настройках (шестерёнка) и запустите ОбновитьДанные.exe"
    end
    if why == "nofile" then
        return "Сезона " .. season .. " нет в архиве — запустите ОбновитьДанные.exe"
    end
    if why == "empty" then return "В сезоне " .. season .. " килов нет" end
    return nil
end

function ns.BossesOf(mode)
    return ns.IsRS(mode) and ns.RS_BOSSES or ns.ICC_BOSSES
end

function ns.RaidIlvl(raid)
    local best
    for b = 1, 3 do
        local c = raid and raid.cells[b]
        if c and c.ilvl and (not best or c.ilvl > best) then best = c.ilvl end
    end
    return best
end

function ns.GearMedian(s, mode, roles)
    local v = {}
    for _, raid in ipairs(s and s.byMode[mode] or {}) do
        for b = 1, 3 do
            local c = raid.cells[b]
            if c and c.gear and (not roles or roles[c.role]) then tinsert(v, c.gear) end
        end
    end
    local n = #v
    if n == 0 then return nil, 0 end
    table.sort(v)
    if n % 2 == 1 then return v[(n + 1) / 2], n end
    return floor((v[n / 2] + v[n / 2 + 1]) / 2 + 0.5), n
end

function ns.RoleTally(s, mode)
    local bosses = ns.BossesOf(mode)
    local out = { total = { d = 0, h = 0, t = 0, all = 0 } }
    for i, boss in ipairs(bosses) do out[i] = { boss = boss, d = 0, h = 0, t = 0, all = 0 } end
    local list = s and s.byMode[mode] or {}
    for _, raid in ipairs(list) do
        for i = 1, #bosses do
            local c = raid.cells[i]
            if c and out[i][c.role] then
                out[i][c.role] = out[i][c.role] + 1
                out[i].all = out[i].all + 1
                out.total[c.role] = out.total[c.role] + 1
                out.total.all = out.total.all + 1
            end
        end
    end
    out.raids = #list
    out.of = s and s.raids[mode] or 0
    return out
end

function ns.HeroDate(rec)
    local d = rec and rec.badges and rec.badges.hero
    if not d or not string.match(d, "^%d%d%d%d%d%d$") then return nil end
    return d
end

local function betterBest(a, b)
    if not b or not b.parse then return a end
    if not a or not a.parse or b.parse > a.parse then return b end
    return a
end

function ns.AllSeasons(rec, list)
    if not rec then return nil end
    local all = { season = "all", raids = {}, byMode = {}, recent = {}, hist = rec.hist, count = 0, roleKills = {} }
    for _, mode in ipairs(ns.MODES) do
        all.raids[mode] = 0
        all.byMode[mode] = {}
    end
    for _, sn in ipairs(list or {}) do
        local s = ns.SeasonBlock(rec, sn)
        if s then
            all.count = all.count + 1
            for _, mode in ipairs(ns.MODES) do
                all.raids[mode] = all.raids[mode] + (s.raids[mode] or 0)
                for _, raid in ipairs(s.byMode[mode] or {}) do tinsert(all.byMode[mode], raid) end
            end
            for _, raid in ipairs(s.recent or {}) do tinsert(all.recent, raid) end
            if s.gs and (not all.gs or s.gs > all.gs) then all.gs = s.gs end
            if s.last and s.last ~= "" and (not all.last or s.last > all.last) then all.last = s.last end
            all.spec = all.spec or s.spec
            all.bestD = betterBest(all.bestD, s.bestD)
            all.bestH = betterBest(all.bestH, s.bestH)
            all.bestT = betterBest(all.bestT, s.bestT)
            for mode, k in pairs(s.roleKills or {}) do
                local a = all.roleKills[mode] or { d = 0, h = 0, t = 0 }
                a.d, a.h, a.t = a.d + (k.d or 0), a.h + (k.h or 0), a.t + (k.t or 0)
                all.roleKills[mode] = a
            end
        end
    end
    if all.count == 0 then return nil end
    return all
end

local benchCache = {}

function ns.Bench(mode, boss)
    local all = ns.Meta().bench
    if type(all) ~= "table" or not mode or not boss then return nil end
    local key = mode .. "." .. boss
    local hit = benchCache[key]
    if hit ~= nil then return hit or nil end
    local out = false
    local raw = all[key]
    if type(raw) == "string" then
        local c, z, h, n = strsplit("|", raw)
        local cuts, zero, hps = {}, {}, {}
        for v in gmatch(c or "", "[%d%.]+") do tinsert(cuts, tonumber(v)) end
        for v in gmatch(z or "", "[%d%.]+") do tinsert(zero, tonumber(v)) end
        for v in gmatch(h or "", "[%d%.]+") do tinsert(hps, tonumber(v)) end
        if #cuts == 9 and #zero == 10 then
            out = { cuts = cuts, zero = zero, hps = hps, n = tonumber(n) or 0 }
        end
    end
    benchCache[key] = out
    return out or nil
end

function ns.BenchPercent(bench, v)
    local c = bench.cuts
    if not v or v <= 0 then return 0 end
    if v < c[1] then return 10 * v / c[1] end
    for k = 1, 8 do
        if v < c[k + 1] then return 10 * k + 10 * (v - c[k]) / math.max(c[k + 1] - c[k], 1) end
    end
    return math.min(90 + 10 * (v - c[9]) / math.max(c[9] - c[8], 1), 99)
end

function ns.BenchNoWipe(bench, pct)
    local d = floor(pct / 10) + 1
    if d < 1 then d = 1 elseif d > 10 then d = 10 end
    return bench.zero[d]
end

local HEAL_SPECS = { holy = true, discipline = true, restoration = true }
local TANK_SPECS = { protection = true, guardian = true }

function ns.SpecRole(spec)
    local key = string.gsub(ns.Lower(spec or ""), "[%s_%-]", "")
    if HEAL_SPECS[key] then return "h" end
    if TANK_SPECS[key] then return "t" end
    return "d"
end

function ns.RoleAverage(s, mode)
    local out = {}
    for _, raid in ipairs(s and s.byMode[mode] or {}) do
        local seen = {}
        for b = 1, 3 do
            local c = raid.cells[b]
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
    for _, raid in ipairs(s.byMode[mode] or {}) do
        for b = 1, 3 do
            local c = raid.cells[b]
            if c and n[c.role] then n[c.role] = n[c.role] + 1 end
        end
    end
    local best, bestN = nil, 0
    for _, r in ipairs({ "t", "h", "d" }) do
        if n[r] > bestN then best, bestN = r, n[r] end
    end
    return best
end

function ns.PrevSeason()
    local cur, seen = ns.CurrentSeason(), false
    for _, sn in ipairs(ns.Meta().seasons or {}) do
        sn = tonumber(sn)
        if seen and sn then return sn end
        if sn == cur then seen = true end
    end
    return nil
end

function ns.TopIlvl(blocks)
    local top
    for _, bl in ipairs(blocks) do
        local s = bl.s
        if s then
            if s.gs and (not top or s.gs > top) then top = s.gs end
            for _, list in pairs(s.byMode or {}) do
                for _, raid in ipairs(list) do
                    local il = ns.RaidIlvl(raid)
                    if il and (not top or il > top) then top = il end
                end
            end
        end
    end
    return top
end

function ns.StatBlocks(rec)
    local cur, prev = ns.CurrentSeason(), ns.PrevSeason()
    local blocks = { { sn = cur, s = rec and ns.SeasonOf(rec, cur) } }
    if prev and rec then blocks[2] = { sn = prev, s = (ns.SeasonBlock(rec, prev)) } end
    return blocks
end

function ns.RaidStat(rec, mode, bi)
    local out = {}
    if not rec then return out end
    local cur, prev = ns.CurrentSeason(), ns.PrevSeason()
    local blocks = { { sn = cur, s = ns.SeasonOf(rec, cur) } }
    if prev then blocks[2] = { sn = prev, s = (ns.SeasonBlock(rec, prev)) } end
    for _, b in ipairs(blocks) do
        if b.s and not out.role then out.role = roleIn(b.s, mode) end
        if b.s and not out.spec then out.spec = b.s.spec end
    end
    if not out.role and out.spec then out.role = ns.SpecRole(out.spec) end
    local role = out.role or "d"
    local top = ns.TopIlvl(blocks)
    if top then
        local sum, n, mn, fromCur = 0, 0, nil, false
        for _, bl in ipairs(blocks) do
            for _, raid in ipairs(bl.s and bl.s.byMode[mode] or {}) do
                local c = raid.cells[bi]
                local il = ns.RaidIlvl(raid)
                if c and c.value and c.role == role and (not il or il >= top - 2) then
                    sum, n = sum + c.value, n + 1
                    if not mn or c.value < mn then mn = c.value end
                    if bl.sn == cur then fromCur = true end
                end
            end
        end
        if n > 0 then
            out.avg, out.min, out.n, out.ilvl = floor(sum / n + 0.5), mn, n, top
            if not fromCur and prev then out.season = prev end
            return out
        end
    end
    out.wide = true
    for _, b in ipairs(blocks) do
        local s = b.s
        if s then
            local sum, n, mn = 0, 0, nil
            for _, raid in ipairs(s.byMode[mode] or {}) do
                local c = raid.cells[bi]
                if c and c.value and c.role == role then
                    sum, n = sum + c.value, n + 1
                    if not mn or c.value < mn then mn = c.value end
                end
            end
            if n > 0 then
                out.avg, out.min, out.n = floor(sum / n + 0.5), mn, n
                if b.sn ~= cur then out.season = b.sn end
                return out
            end
        end
    end
    return out
end
