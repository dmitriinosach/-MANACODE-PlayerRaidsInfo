local ADDON, ns = ...
local W, PAD = 470, 16
local CW = W - PAD * 2
local LABEL_W = 84
local ROW_H = 24
local TILE_W, TILE_H, TILE_GAP = (CW - 8) / 2, 52, 8
local SITE_URL = "https://wow-addons.manacode.su/"
local OTHERS = {
    { folder = "ManaCode_RaidHelper", name = "Raid Helper", url = "https://github.com/dmitriinosach/-MANACODE-RaidHelper",
        desc = "Разбор рейда по боевому логу, Косячница, сбор состава" },
    { name = "ManacodeUpdate", url = "https://github.com/dmitriinosach/-MANACODE-Update/releases/latest",
        desc = "Ставит и обновляет аддоны ManaCode и данные этого аддона" },
    { folder = "ManaCode_RaidWaitingArcade", name = "Raid Waiting Arcade", url = "https://github.com/dmitriinosach/-MANACODE-RaidWaitingArcade",
        desc = "Мини-игры, пока собирается рейд" },
    { folder = "ManaCode_LazyBuffBar", name = "LazyBuffBar", url = "https://github.com/dmitriinosach/-MANACODE-LazyBuffBar",
        desc = "Панель бафов: что держать классу и спеку, проки, кулдауны" },
    { folder = "ManaCode_Vendor", name = "Vendor", url = "https://github.com/dmitriinosach/-MANACODE-Vendor",
        desc = "Весь товар торговца одним списком, покупка пачкой" },
    { folder = "VuhDo_KickFix", name = "VuhDo KickFix", url = "https://github.com/dmitriinosach/-MANACODE-VuhDo-KickFix",
        desc = "Фикс панелей VuhDo 2.22 после кика в бою" },
}
local panel
local function installed(folder)
    local name, _, _, _, _, reason = GetAddOnInfo(folder)
    return name ~= nil and reason ~= "MISSING"
end
local function head(text, y)
    local fs = ns.Text(panel, 13, "LEFT", "head")
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
    fs:SetText(text)
    return y + 20
end
local function linkRow(caption, url, y)
    local fs = ns.Text(panel, 12)
    fs:SetTextColor(0.62, 0.62, 0.62)
    fs:SetWidth(LABEL_W)
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(y + 4))
    fs:SetText(ns.T(caption))
    local eb = ns.UrlBox(panel, nil, url)
    eb:SetText(url)
    eb:SetCursorPosition(0)
    eb:SetWidth(CW - LABEL_W - 6)
    eb:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + LABEL_W + 6, -y)
    tinsert(panel.boxes, eb)
    return y + ROW_H
end
local function tile(addon, i, y)
    local t = CreateFrame("Button", nil, panel)
    t:SetWidth(TILE_W)
    t:SetHeight(TILE_H)
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + ((i - 1) % 2) * (TILE_W + 8), -(y + math.floor((i - 1) / 2) * (TILE_H + TILE_GAP)))
    t:SetBackdrop(ns.TIP_BACKDROP)
    t:SetBackdropColor(0.1, 0.09, 0.07, 0.9)
    t:SetBackdropBorderColor(0.43, 0.35, 0.2, 1)
    local name = ns.Text(t, 13, "LEFT", "head")
    name:SetPoint("TOPLEFT", t, "TOPLEFT", 9, -8)
    name:SetText(addon.name)
    t.state = ns.Text(t, 11, "RIGHT")
    t.state:SetPoint("TOPRIGHT", t, "TOPRIGHT", -9, -9)
    local desc = ns.Text(t, 12)
    desc:SetTextColor(0.78, 0.78, 0.78)
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    desc:SetWidth(TILE_W - 18)
    desc:SetHeight(28)
    desc:SetJustifyV("TOP")
    desc:SetText(ns.T(addon.desc))
    t.addon = addon
    t:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
        ns.Tip(self, "ANCHOR_TOP", addon.name, addon.url)
    end)
    t:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.43, 0.35, 0.2, 1)
        GameTooltip:Hide()
    end)
    t:SetScript("OnClick", function(self) ns.ShowCopy(self, addon.url, 360, true) end)
    tinsert(panel.tiles, t)
end
local function build(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(W)
    panel:SetPoint("CENTER", parent, "CENTER", 0, 10)
    panel:SetFrameLevel(parent:GetFrameLevel() + 30)
    panel:EnableMouse(true)
    ns.StyleTip(panel)
    panel:SetBackdropColor(0.05, 0.045, 0.035, 0.98)
    panel:SetBackdropBorderColor(1, 0.82, 0, 1)
    panel:Hide()
    panel.boxes, panel.tiles = {}, {}
    local title = ns.Text(panel, 16, "LEFT", "head")
    title:SetPoint("TOPLEFT", PAD, -14)
    title:SetText(ns.T("Об аддоне"))
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    panel.ver = ns.Text(panel, 13)
    panel.ver:SetPoint("TOPLEFT", PAD, -42)
    local from = ns.Text(panel, 12)
    from:SetTextColor(0.62, 0.62, 0.62)
    from:SetWidth(CW)
    from:SetPoint("TOPLEFT", PAD, -60)
    from:SetText(ns.T("Рейды, парсы и рейтинг спека — из логов WoW Circle. Аддон сам не ходит в интернет: данные кладёт ManacodeUpdate."))
    local y = 60 + math.floor((from:GetStringHeight() or 14) + 0.5) + 10
    y = linkRow("Скачать", ns.RELEASES_URL, y)
    y = linkRow("Обновлялка", ns.UPDATER_URL, y)
    y = linkRow("Данные", ns.DATA_URL, y)
    y = linkRow("Репозиторий", ns.REPO_URL, y)
    y = linkRow("Discord", ns.DISCORD_URL, y)
    y = linkRow("Сайт", SITE_URL, y)
    y = head("Другие аддоны ManaCode", y + 8)
    for i, addon in ipairs(OTHERS) do tile(addon, i, y) end
    y = y + math.ceil(#OTHERS / 2) * (TILE_H + TILE_GAP) + 4
    y = head("Авторы", y)
    local authors = ns.Text(panel, 13)
    authors:SetPoint("TOPLEFT", PAD, -y)
    authors:SetText("|cffffffffFutex|r   |cfff58cbaSyncpool|r")
    panel:SetHeight(y + 18 + PAD)
    panel:SetScript("OnHide", function()
        for _, eb in ipairs(panel.boxes) do eb:ClearFocus() end
        ns.HideCopy()
    end)
end
local function refresh()
    local built = GetAddOnMetadata and GetAddOnMetadata(ADDON, "X-Date")
    local y4, m2, d2 = string.match(built or "", "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    local version = ns.LinkVersion and ns.LinkVersion() or "?"
    local dateText = y4 and (ns.ENGLISH and (" on " .. m2 .. "/" .. d2 .. "/" .. y4) or (ns.T(" от ") .. d2 .. "." .. m2 .. "." .. y4)) or ""
    local text = ns.T("Версия ") .. version .. dateText
    local newest = ns.NewestVersion and ns.NewestVersion()
    if newest then text = text .. "   " .. ns.Color("green", ns.T("вышла ") .. newest) end
    panel.ver:SetText(text)
    for _, t in ipairs(panel.tiles) do
        if t.addon.folder then
            local on = installed(t.addon.folder)
            t.state:SetText(on and ns.T("установлен") or ns.T("нет"))
            if on then t.state:SetTextColor(0.4, 0.9, 0.4) else t.state:SetTextColor(0.5, 0.52, 0.55) end
        else
            t.state:SetText("")
        end
    end
end
function ns.ToggleAbout(parent)
    if not panel then build(parent) end
    if panel:IsShown() then
        panel:Hide()
        return
    end
    refresh()
    panel:Show()
end
function ns.HideAbout()
    if panel then panel:Hide() end
end
