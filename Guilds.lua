local ADDON, ns = ...

PlayerRaidsGuilds = PlayerRaidsGuilds or {}

local WRITE_EVERY = 60
local lastWrite = {}

local function today()
    return floor(time() / 86400)
end

local function record(id, guild)
    if not id then return end
    local now = GetTime()
    if lastWrite[id] and now - lastWrite[id] < WRITE_EVERY then return end
    PlayerRaidsGuilds = PlayerRaidsGuilds or {}
    local e = PlayerRaidsGuilds[id] or { hist = {} }
    e.hist = e.hist or {}
    if guild then
        lastWrite[id] = now
        e.cur = guild
        local h = e.hist[guild] or {}
        h.first = h.first or today()
        h.last = today()
        e.hist[guild] = h
    else
        e.cur = false
    end
    PlayerRaidsGuilds[id] = e
end

ns.RecordGuild = record

local function titleFrom(unit, name)
    if type(UnitPVPName) ~= "function" then return nil end
    local full = UnitPVPName(unit)
    if type(full) ~= "string" or full == "" then return nil end
    local a, b = string.find(full, name, 1, true)
    if not a then
        a, b = string.find(ns.Lower(full), ns.Lower(name), 1, true)
    end
    if not a then return nil end
    local t = strsub(full, 1, a - 1) .. strsub(full, b + 1)
    t = string.gsub(t, "^[%s,]+", "")
    t = string.gsub(t, "[%s,]+$", "")
    if t == "" then return false end
    return t
end

ns.TitleFrom = titleFrom

local function scan(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    local name = UnitName(unit)
    if not name or name == "" or name == UNKNOWNOBJECT then return end
    local id = ns.IdFromGuid(UnitGUID(unit))
    if not id then return end
    record(id, (GetGuildInfo(unit)))
    local title = titleFrom(unit, name)
    if title ~= nil then
        local e = PlayerRaidsGuilds[id] or { hist = {} }
        e.title = title
        PlayerRaidsGuilds[id] = e
    end
    if ns.GearScoreOf then ns.GearScoreOf(id) end
end

local rescan, rescanAt = nil, 0
local later = CreateFrame("Frame")
later:Hide()
later:SetScript("OnUpdate", function(self)
    if GetTime() < rescanAt then return end
    self:Hide()
    if rescan then scan(rescan) end
end)

local function scanTwice(unit)
    scan(unit)
    rescan, rescanAt = unit, GetTime() + 0.6
    later:Show()
end

local function scanGroup()
    for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do scan("raid" .. i) end
    for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do scan("party" .. i) end
end

local function scanRoster()
    local guild = GetGuildInfo("player")
    if not guild or not GetNumGuildMembers then return end
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        local id = name and ns.IdOf(name)
        if id then record(id, guild) end
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
watcher:RegisterEvent("PLAYER_FOCUS_CHANGED")
watcher:RegisterEvent("RAID_ROSTER_UPDATE")
watcher:RegisterEvent("PARTY_MEMBERS_CHANGED")
watcher:RegisterEvent("GUILD_ROSTER_UPDATE")
watcher:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_MOUSEOVER_UNIT" then
        scan("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        scanTwice("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        scanTwice("focus")
    elseif event == "GUILD_ROSTER_UPDATE" then
        scanRoster()
    elseif event == "PLAYER_LOGIN" then
        scan("player")
        scanGroup()
        if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
    else
        scanGroup()
    end
end)

function ns.GuildOf(id)
    return id and PlayerRaidsGuilds and PlayerRaidsGuilds[id] or nil
end

function ns.TitleOf(id)
    local name = id and ns.NameOf and ns.NameOf(id)
    local unit = name and ns.UnitFor and ns.UnitFor(name)
    if unit then scan(unit) end
    local e = ns.GuildOf(id)
    return e and e.title or nil
end

function ns.GuildText(id)
    local e = ns.GuildOf(id)
    if not e or e.cur == nil then return "гильдия неизвестна", false end
    if e.cur == false then return "без гильдии", true end
    return "<" .. e.cur .. ">", true
end

function ns.GuildLines(id)
    local e = ns.GuildOf(id)
    local out = {}
    if not e or not e.hist then return out end
    for name, h in pairs(e.hist) do
        tinsert(out, { name = name, first = h.first or 0, last = h.last or 0 })
    end
    table.sort(out, function(a, b) return a.last > b.last end)
    return out
end

local function gsDay(stamp)
    stamp = tonumber(stamp)
    if not stamp or stamp < 190000000000 then return nil end
    local y = floor(stamp / 100000000)
    local m = floor(stamp / 1000000) % 100
    local d = floor(stamp / 10000) % 100
    local ok, t = pcall(time, { year = y, month = m, day = d, hour = 12 })
    if not ok or not t then return nil end
    return floor(t / 86400)
end

local function gsFromAddon(name)
    local realm = type(GS_Data) == "table" and GetRealmName and GS_Data[GetRealmName()]
    local p = realm and realm.Players and name and realm.Players[name]
    local v = p and tonumber(p.GearScore)
    if not v or v <= 0 then return nil end
    return v, gsDay(p.Date) or today()
end

function ns.GearScoreOf(id)
    if not id then return nil end
    local name = ns.NameOf and ns.NameOf(id)
    local v, day = gsFromAddon(name)
    local e = PlayerRaidsGuilds and PlayerRaidsGuilds[id]
    if v then
        if not e or not e.gsd or day >= e.gsd then
            e = e or { hist = {} }
            e.gs, e.gsd = v, day
            PlayerRaidsGuilds[id] = e
        end
    end
    if e and e.gs then return e.gs, e.gsd and (today() - e.gsd) or nil end
    return nil
end

function ns.GearScoreRGB(v)
    if type(GearScore_GetQuality) == "function" then
        local ok, r, b, g = pcall(GearScore_GetQuality, v)
        if ok and r then return r, g, b end
    end
    return 0.9, 0.9, 0.9
end

function ns.GearScoreText(id)
    local v, age = ns.GearScoreOf(id)
    if not v then return nil end
    local r, g, b = ns.GearScoreRGB(v)
    local t = string.format("GS |cff%02x%02x%02x%d|r", floor(r * 255), floor(g * 255), floor(b * 255), v)
    if age and age > 7 then t = t .. ns.Color("dim", " (" .. age .. " дн.)") end
    return t
end
