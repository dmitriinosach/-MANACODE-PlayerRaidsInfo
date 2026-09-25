local ADDON, ns = ...
local cache = {}
local pending, asked
local ASK_TIMEOUT = 3
local FRESH = 1800
local function unitFor(name)
    if not name then return nil end
    local candidates = { "mouseover", "target", "focus" }
    for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do
        tinsert(candidates, "raid" .. i)
    end
    for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
        tinsert(candidates, "party" .. i)
    end
    for _, unit in ipairs(candidates) do
        if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit) == name then
            return unit
        end
    end
    return nil
end
ns.UnitFor = unitFor
local function canAsk()
    return type(NotifyInspect) == "function"
       and type(GetTalentTabInfo) == "function"
       and type(CanInspect) == "function"
end
function ns.LiveSpec(name)
    if not name then return nil end
    local hit = cache[name]
    if hit and GetTime() - hit.t < FRESH then return hit.spec end
    if not canAsk() then return nil end
    if pending and (GetTime() - (asked or 0)) < ASK_TIMEOUT then return nil end
    if InspectFrame and InspectFrame:IsShown() then return nil end
    local unit = unitFor(name)
    if not unit or not CanInspect(unit) then return nil end
    pending, asked = name, GetTime()
    pcall(NotifyInspect, unit)
    return nil
end
function ns.LiveArt(name)
    local hit = name and cache[name]
    if hit and GetTime() - hit.t < FRESH then return ns.ArtPath(hit.bg) end
    return nil
end
function ns.ArtFor(name, classFile, siteSpec)
    return ns.LiveArt(name) or ns.SpecArt(classFile, siteSpec)
end
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("INSPECT_TALENT_READY")
watcher:SetScript("OnEvent", function()
    if not pending then return end
    local name = pending
    pending = nil
    local unit = unitFor(name)
    if not unit or UnitName(unit) ~= name then return end
    local tabs = 3
    local group
    if type(GetActiveTalentGroup) == "function" then
        local okG, g = pcall(GetActiveTalentGroup, true)
        if okG and (g == 1 or g == 2) then group = g end
    end
    local ok, n = pcall(GetNumTalentTabs, true)
    if ok and n and n > 0 then tabs = n end
    local bestName, bestPts, bestBg
    for i = 1, tabs do
        local okTab, tabName, tabIcon, pts, bg = pcall(GetTalentTabInfo, i, true, false, group)
        if okTab and tabName and ns.LearnSpecIcon then ns.LearnSpecIcon(select(2, UnitClass(unit)), tabName, tabIcon) end
        if okTab and tabName and pts and (not bestPts or pts > bestPts) then
            bestName, bestPts, bestBg = tabName, pts, bg
        end
    end
    if bestName and bestPts and bestPts > 0 then
        cache[name] = { spec = bestName, bg = type(bestBg) == "string" and bestBg or nil, t = GetTime() }
        if ns.Refresh then ns.Refresh(name) end
    end
end)
local STATS = {
    { boss = "lich", h = 4688, n = 4687 },
    { boss = "prof", h = 4679, n = 4678 },
    { boss = "surf", h = 4664, n = 4663 },
}
local ACH_HERO = { 4584, 4637, 4603 }
local ACH_NORMAL = { 4597, 4608 }
local RETRY = 15
local kills = {}
local killPending, killAsked
local function comparisonBusy()
    return AchievementFrameComparison and AchievementFrameComparison:IsShown()
end
local function canCompare()
    return type(SetAchievementComparisonUnit) == "function"
       and type(GetComparisonStatistic) == "function"
       and type(GetAchievementComparisonInfo) == "function"
       and type(CanInspect) == "function"
end
local killWatch = CreateFrame("Frame")
killWatch:Hide()
function ns.LiveKills(name)
    if not name then return nil end
    local hit = kills[name]
    if hit and GetTime() - hit.t < (hit.fail and RETRY or FRESH) then
        if hit.fail then return nil end
        return hit
    end
    if not canCompare() then return nil end
    if killPending then return nil, killPending == name and "wait" or nil end
    if comparisonBusy() then return nil end
    local unit = unitFor(name)
    if not unit then return nil, "far" end
    if not CanInspect(unit) then return nil end
    killPending, killAsked = name, GetTime()
    if type(ClearAchievementComparisonUnit) == "function" then pcall(ClearAchievementComparisonUnit) end
    if not pcall(SetAchievementComparisonUnit, unit) then
        killPending = nil
        return nil
    end
    killWatch:Show()
    return nil, "wait"
end
local function statCount(id)
    local ok, v = pcall(GetComparisonStatistic, id)
    return ok and tonumber(v) or 0
end
local function readKills()
    local out = { t = GetTime(), bosses = {} }
    for i, st in ipairs(STATS) do
        local h, n = statCount(st.h), statCount(st.n)
        out.bosses[i] = { boss = st.boss, h = h, n = n }
        if h + n > 0 then out.any = true end
        if h > 0 then out.hero = true end
    end
    out.ach = {}
    for _, id in ipairs(out.hero and ACH_HERO or ACH_NORMAL) do
        local okI, _, title = pcall(GetAchievementInfo, id)
        local okC, done, month, day, year = pcall(GetAchievementComparisonInfo, id)
        if okI and type(title) == "string" then
            local a = { title = title, done = okC and done and true or false }
            if a.done and day and month and year then
                a.date = string.format("%02d.%02d.%02d", day, month, year % 100)
            end
            tinsert(out.ach, a)
        end
    end
    return out
end
killWatch:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
killWatch:SetScript("OnEvent", function(self)
    if not killPending then return end
    local name = killPending
    killPending = nil
    self:Hide()
    if comparisonBusy() then
        kills[name] = { t = GetTime(), fail = true }
        return
    end
    kills[name] = readKills()
    if type(ClearAchievementComparisonUnit) == "function" then pcall(ClearAchievementComparisonUnit) end
    if ns.Refresh then ns.Refresh(name) end
end)
killWatch:SetScript("OnUpdate", function(self)
    if not killPending then
        self:Hide()
        return
    end
    if GetTime() - (killAsked or 0) < ASK_TIMEOUT then return end
    local name = killPending
    killPending = nil
    self:Hide()
    kills[name] = { t = GetTime(), fail = true }
    if ns.Refresh then ns.Refresh(name) end
end)
local own = CreateFrame("Frame")
own:RegisterEvent("PLAYER_LOGIN")
own:SetScript("OnEvent", function()
    if type(GetTalentTabInfo) ~= "function" or not ns.LearnSpecIcon then return end
    local _, classFile = UnitClass("player")
    local ok, n = pcall(GetNumTalentTabs)
    for i = 1, (ok and n) or 3 do
        local okTab, tabName, tabIcon = pcall(GetTalentTabInfo, i)
        if okTab then ns.LearnSpecIcon(classFile, tabName, tabIcon) end
    end
end)
