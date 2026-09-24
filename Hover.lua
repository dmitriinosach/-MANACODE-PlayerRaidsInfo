local ADDON, ns = ...
local frozen
local hovered
local watch = CreateFrame("Frame")
watch:Hide()
watch:SetScript("OnUpdate", function(self)
    if not IsAltKeyDown() then
        frozen = nil
        self:Hide()
        ns.HideCard()
    end
end)
local function showFrozen(info)
    if not info then return end
    frozen = true
    watch:Show()
    ns.ShowCard(info, "cursor")
end
local function playerFromLink(link)
    if type(link) ~= "string" then return nil end
    local kind, data = string.match(link, "^(%a+):(.*)$")
    if kind ~= "player" then return nil end
    return string.match(data, "^([^:]+)")
end
local function openInWindow(name)
    if not name or name == "" then return false end
    name = string.match(name, "^([^%-]+)") or name
    if ns.BrowserShown() then
        ns.OpenBrowser(name)
        return true
    end
    if ns.Opt("altOpen") then
        ns.OpenBrowser(name)
        return true
    end
    return false
end
local function onLinkEnter(frame, link)
    local name = playerFromLink(link)
    if not name or name == "" then return end
    hovered = { kind = "name", name = name }
    if frozen or not IsAltKeyDown() or not ns.Opt("chat") then return end
    showFrozen(ns.InfoForName(name))
end
local function onLeave()
    hovered = nil
end
local function guildName(button)
    local index = button.guildIndex
    if index and GetGuildRosterInfo then
        local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(index)
        if name and name ~= "" then return name, classFile end
    end
    local frameName = button.GetName and button:GetName()
    local label = frameName and _G[frameName .. "Name"]
    return label and label.GetText and label:GetText()
end
local function guildInfo(button)
    local name, classFile = guildName(button)
    local info = ns.InfoForName(name)
    if info then info.class = info.class or classFile end
    return info
end
local function onGuildEnter(self)
    hovered = { kind = "guild", button = self }
    if frozen or not IsAltKeyDown() or not ns.Opt("guild") then return end
    showFrozen(guildInfo(self))
end
local function onGuildClick(self)
    if not IsAltKeyDown() then return end
    openInWindow((guildName(self)))
end
local function hookGuildRows()
    local hooked = 0
    for _, prefix in ipairs({ "GuildFrameButton", "GuildFrameGuildStatusButton" }) do
        for i = 1, 30 do
            local button = _G[prefix .. i]
            if button and button.HookScript and not button.prHooked then
                button.prHooked = true
                button:HookScript("OnEnter", onGuildEnter)
                button:HookScript("OnLeave", onLeave)
                button:HookScript("OnClick", onGuildClick)
                hooked = hooked + 1
            end
        end
    end
    return hooked
end
local function fromWorld()
    return GetMouseFocus and WorldFrame and GetMouseFocus() == WorldFrame
end
local function showUnit()
    local _, unit = GameTooltip:GetUnit()
    local world = fromWorld()
    if world then
        if not ns.Opt("world") then return end
        unit = "mouseover"
    else
        if frozen or not ns.Opt("frames") then return end
    end
    if not unit then return end
    local info = ns.InfoForUnit(unit)
    if not info then return end
    if world then
        if frozen and ns.CardName() == info.name then return end
        showFrozen(info)
        return
    end
    watch:Show()
    ns.ShowCard(info, "tooltip")
end
local function onTooltipUnit()
    if IsAltKeyDown() then showUnit() end
end
local function onTooltipHide()
    if ns.CardHow() == "tooltip" then ns.HideCard() end
end
local function hookItemRef()
    local orig = SetItemRef
    if type(orig) ~= "function" then return end
    SetItemRef = function(link, text, button, chatFrame)
        if IsAltKeyDown() and (button == nil or button == "LeftButton") then
            local name = playerFromLink(link)
            if name and openInWindow(name) then return end
        end
        return orig(link, text, button, chatFrame)
    end
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MODIFIER_STATE_CHANGED")
events:SetScript("OnEvent", function(self, event, key, state)
    if event == "PLAYER_LOGIN" then
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local frame = _G["ChatFrame" .. i]
            if frame and frame.HookScript then
                frame:HookScript("OnHyperlinkEnter", onLinkEnter)
                frame:HookScript("OnHyperlinkLeave", onLeave)
            end
        end
        if hookGuildRows() == 0 and GuildFrame and GuildFrame.HookScript then
            GuildFrame:HookScript("OnShow", hookGuildRows)
        end
        GameTooltip:HookScript("OnTooltipSetUnit", onTooltipUnit)
        GameTooltip:HookScript("OnHide", onTooltipHide)
        hookItemRef()
        return
    end
    if (key ~= "LALT" and key ~= "RALT") or state ~= 1 or frozen then return end
    if hovered then
        if hovered.kind == "guild" then
            if ns.Opt("guild") then showFrozen(guildInfo(hovered.button)) end
        elseif ns.Opt("chat") then
            showFrozen(ns.InfoForName(hovered.name))
        end
    elseif GameTooltip:IsShown() and GameTooltip:GetUnit() then
        showUnit()
    end
end)
