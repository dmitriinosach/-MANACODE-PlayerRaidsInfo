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
    local ok, n = pcall(GetNumTalentTabs, true)
    if ok and n and n > 0 then tabs = n end
    local bestName, bestPts, bestBg
    for i = 1, tabs do
        local okTab, tabName, _, pts, bg = pcall(GetTalentTabInfo, i, true)
        if okTab and tabName and pts and (not bestPts or pts > bestPts) then
            bestName, bestPts, bestBg = tabName, pts, bg
        end
    end
    if bestName and bestPts and bestPts > 0 then
        cache[name] = { spec = bestName, bg = type(bestBg) == "string" and bestBg or nil, t = GetTime() }
        if ns.Refresh then ns.Refresh(name) end
    end
end)
