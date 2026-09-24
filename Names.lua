local ADDON, ns = ...

PlayerRaidsDB = PlayerRaidsDB or {}

function ns.IdFromGuid(guid)
    if type(guid) ~= "string" or #guid < 8 then return nil end
    return tonumber(strsub(guid, 7), 16)
end

local function today()
    return floor(time() / 86400)
end

local byLower

local function buildLower()
    byLower = {}
    for id, name in pairs(PlayerRaidsDB.names or {}) do
        byLower[ns.Lower(name)] = id
    end
end

local function remember(name, guid)
    if not name or name == "" then return end
    local id = ns.IdFromGuid(guid)
    if not id then return end

    PlayerRaidsDB.names = PlayerRaidsDB.names or {}
    PlayerRaidsDB.seen = PlayerRaidsDB.seen or {}
    local old = PlayerRaidsDB.names[id]
    PlayerRaidsDB.names[id] = name
    PlayerRaidsDB.seen[id] = today()
    if old ~= name then
        if byLower then byLower[ns.Lower(name)] = id end
        if ns.OnNameSeen then ns.OnNameSeen(id, name) end
    end
end

ns.Remember = remember

function ns.NameOf(id)
    local names = PlayerRaidsDB.names
    return names and names[id]
end

function ns.IdOf(name)
    if not name or name == "" then return nil end
    if not byLower then buildLower() end
    local low = ns.Lower(name)
    local id = byLower[low]
    local known = id and ns.NameOf(id)
    if known and ns.Lower(known) == low then return id end
    return nil
end

function ns.KnownNames()
    local n = 0
    for _ in pairs(PlayerRaidsDB.names or {}) do n = n + 1 end
    return n
end

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
}

local seenGuid = {}

local function isPlayerGuid(guid)
    return type(guid) == "string" and strsub(guid, 1, 5) == "0x000"
end

local watcher = CreateFrame("Frame")
for _, event in ipairs(CHAT_EVENTS) do watcher:RegisterEvent(event) end
watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
watcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

watcher:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local srcGuid, srcName = select(3, ...), select(4, ...)
        local dstGuid, dstName = select(6, ...), select(7, ...)
        if srcGuid and not seenGuid[srcGuid] then
            seenGuid[srcGuid] = true
            if isPlayerGuid(srcGuid) then remember(srcName, srcGuid) end
        end
        if dstGuid and not seenGuid[dstGuid] then
            seenGuid[dstGuid] = true
            if isPlayerGuid(dstGuid) then remember(dstName, dstGuid) end
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") and UnitIsPlayer("target") then
            remember(UnitName("target"), UnitGUID("target"))
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if UnitExists("mouseover") and UnitIsPlayer("mouseover") then
            remember(UnitName("mouseover"), UnitGUID("mouseover"))
        end
    elseif event == "PLAYER_LOGIN" then
        remember(UnitName("player"), UnitGUID("player"))
        for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do
            remember(UnitName("raid" .. i), UnitGUID("raid" .. i))
        end
        for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
            remember(UnitName("party" .. i), UnitGUID("party" .. i))
        end
    else
        local sender, guid = select(2, ...), select(12, ...)
        remember(sender, guid)
    end
end)

local MIN_CAP = 2000

local function prune()
    local names = PlayerRaidsDB.names
    if not names then return end
    local seen = PlayerRaidsDB.seen or {}

    local cap = 0
    for _ in pairs(PlayerRaidsData or {}) do cap = cap + 1 end
    if cap < MIN_CAP then cap = MIN_CAP end

    local total, ballast = 0, {}
    for id in pairs(names) do
        total = total + 1
        if not (PlayerRaidsData and PlayerRaidsData[id]) then
            tinsert(ballast, id)
        end
    end
    if total <= cap then return end

    table.sort(ballast, function(a, b) return (seen[a] or 0) < (seen[b] or 0) end)
    for _, id in ipairs(ballast) do
        if total <= cap then break end
        names[id], seen[id] = nil, nil
        total = total - 1
    end
    if total <= cap then return end

    local rest = {}
    for id in pairs(names) do tinsert(rest, id) end
    table.sort(rest, function(a, b) return (seen[a] or 0) < (seen[b] or 0) end)
    for _, id in ipairs(rest) do
        if total <= cap then break end
        names[id], seen[id] = nil, nil
        total = total - 1
    end
end

local pruner = CreateFrame("Frame")
pruner:RegisterEvent("PLAYER_LOGOUT")
pruner:SetScript("OnEvent", prune)
