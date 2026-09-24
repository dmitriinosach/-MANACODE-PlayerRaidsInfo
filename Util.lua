local ADDON, ns = ...

PlayerRaidsDB = PlayerRaidsDB or {}

ns.WHITE = "Interface\\Buttons\\WHITE8X8"

ns.HEX = {
    gold = "ffd100", white = "f2f2f2", grey = "9d9d9d", dim = "6b6f76",
    note = "c8b58a", none = "4a4d52", green = "1eff00",
}

function ns.Color(key, text)
    return "|cff" .. (ns.HEX[key] or key) .. text .. "|r"
end

local ASCII_LOWER = {}
for b = 65, 90 do ASCII_LOWER[string.char(b)] = string.char(b + 32) end

local CYR_LOWER = {}
for b = 144, 159 do CYR_LOWER["\208" .. string.char(b)] = "\208" .. string.char(b + 32) end
for b = 160, 175 do CYR_LOWER["\208" .. string.char(b)] = "\209" .. string.char(b - 32) end
CYR_LOWER["\208\129"] = "\209\145"

function ns.Lower(s)
    if not s then return "" end
    s = string.gsub(s, "[A-Z]", ASCII_LOWER)
    s = string.gsub(s, "\208[\129\144-\175]", CYR_LOWER)
    return s
end

function ns.FirstChar(s)
    return s and string.match(s, "^[%z\1-\127\194-\244][\128-\191]*") or ""
end

function ns.Plural(n, one, few, many)
    local m100, m10 = n % 100, n % 10
    if m100 >= 11 and m100 <= 14 then return many end
    if m10 == 1 then return one end
    if m10 >= 2 and m10 <= 4 then return few end
    return many
end

function ns.Compact(n)
    if not n then return "" end
    if n >= 1000 then return string.format("%.1fк", n / 1000) end
    return tostring(n)
end

local PARSE_COLORS = {
    { 100, "e5cc80" },
    { 99,  "e268a8" },
    { 95,  "ff8000" },
    { 75,  "a335ee" },
    { 50,  "0070dd" },
    { 25,  "1eff00" },
}

function ns.ParseHex(p)
    if not p then return "9d9d9d" end
    for _, c in ipairs(PARSE_COLORS) do
        if p >= c[1] then return c[2] end
    end
    return "9d9d9d"
end

function ns.ParseRGB(p)
    local hex = ns.ParseHex(p)
    return tonumber(strsub(hex, 1, 2), 16) / 255,
           tonumber(strsub(hex, 3, 4), 16) / 255,
           tonumber(strsub(hex, 5, 6), 16) / 255
end

function ns.ParseText(p)
    if not p then return ns.Color("none", "—") end
    return "|cff" .. ns.ParseHex(p) .. p .. "|r"
end

local SPEC_RU = {
    arms = "Оружие", fury = "Неистовство", protection = "Защита",
    holy = "Свет", retribution = "Воздаяние",
    beastmastery = "Повелитель зверей", marksmanship = "Стрельба", survival = "Выживание",
    assassination = "Ликвидация", combat = "Бой", subtlety = "Скрытность",
    discipline = "Послушание", shadow = "Тьма",
    blood = "Кровь", frost = "Лёд", unholy = "Нечестивость",
    elemental = "Стихии", enhancement = "Совершенствование", restoration = "Исцеление",
    arcane = "Тайная магия", fire = "Огонь",
    affliction = "Колдовство", demonology = "Демонология", destruction = "Разрушение",
    balance = "Баланс", feral = "Сила зверя", feralcombat = "Сила зверя", guardian = "Сила зверя",
}

function ns.SpecRu(spec)
    if not spec or spec == "" then return nil end
    local key = string.gsub(ns.Lower(spec), "[%s_%-]", "")
    return SPEC_RU[key] or spec
end

local SPEC_SPELL = {
    WARRIOR = { arms = 12294, fury = 23881, protection = 23922 },
    PALADIN = { holy = 20473, protection = 31935, retribution = 35395 },
    HUNTER = { beastmastery = 19574, marksmanship = 53209, survival = 53301 },
    ROGUE = { assassination = 1329, combat = 51690, subtlety = 51713 },
    PRIEST = { discipline = 47540, holy = 47788, shadow = 15473 },
    DEATHKNIGHT = { blood = 48266, frost = 48263, unholy = 48265 },
    SHAMAN = { elemental = 403, enhancement = 17364, restoration = 61295 },
    MAGE = { arcane = 30451, fire = 133, frost = 116 },
    WARLOCK = { affliction = 48181, demonology = 47241, destruction = 50796 },
    DRUID = { balance = 24858, feral = 768, feralcombat = 768, guardian = 9634, restoration = 33891 },
}

local function specNorm(s)
    s = string.gsub(ns.Lower(s or ""), "[%s_%-]", "")
    return (string.gsub(s, "\209\145", "\208\181"))
end

local SPEC_BY_RU = {}
for key, ru in pairs(SPEC_RU) do SPEC_BY_RU[specNorm(ru)] = SPEC_BY_RU[specNorm(ru)] or key end
SPEC_BY_RU[specNorm("Сила зверя")] = "feralcombat"

function ns.SpecIcon(classFile, spec)
    local spells = classFile and SPEC_SPELL[classFile]
    if not spells or not spec or spec == "" then return nil end
    local key = specNorm(spec)
    local id = spells[key] or spells[SPEC_BY_RU[key] or ""]
    if not id or type(GetSpellInfo) ~= "function" then return nil end
    local _, _, icon = GetSpellInfo(id)
    return icon
end

local CLASS_RU = {
    WARRIOR = "Воин", PALADIN = "Паладин", HUNTER = "Охотник", ROGUE = "Разбойник",
    PRIEST = "Жрец", DEATHKNIGHT = "Рыцарь смерти", SHAMAN = "Шаман", MAGE = "Маг",
    WARLOCK = "Чернокнижник", DRUID = "Друид",
}

function ns.ClassRu(classFile)
    return classFile and CLASS_RU[classFile] or nil
end

function ns.ClassColor(classFile)
    local pal = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local c = classFile and pal and pal[classFile]
    if not c then return 1, 1, 1 end
    return c.r, c.g, c.b
end

function ns.ClassHex(classFile)
    local r, g, b = ns.ClassColor(classFile)
    return string.format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

ns.MODES = { "ih", "iu", "in", "rh", "rn" }
ns.MODE_INDEX = { ih = 1, iu = 2, ["in"] = 3, rh = 4, rn = 5 }
ns.MODE_FULL = { ih = "ЦЛК 25 гер", iu = "ЦЛК 25 гер анбаф", ["in"] = "ЦЛК 25 об", rh = "РС 25 гер", rn = "РС 25 об" }
ns.MODE_SHORT = { ih = "ЦЛК г", iu = "ЦЛК г/а", ["in"] = "ЦЛК о", rh = "РС г", rn = "РС о" }
ns.MODE_COUNT = { ih = "ЦЛК гер", iu = "анбаф", ["in"] = "об", rh = "РС гер", rn = "РС об" }
ns.MODE_TAB = { ih = "ЦЛК 25 гер", iu = "ЦЛК 25 анбаф", ["in"] = "ЦЛК 25 об", rh = "РС 25 гер", rn = "РС 25 об" }
ns.MODE_CELL = { ih = "25 гер", iu = "гер анбаф", ["in"] = "25 об", rh = "25 гер", rn = "25 об" }
ns.ICC_BOSSES = { "surf", "prof", "lich" }
ns.RS_BOSSES = { "hal" }
ns.BOSS = { surf = "Саурфанг", prof = "Профессор", lich = "Лич", hal = "Халион" }

function ns.IsRS(mode)
    return mode == "rh" or mode == "rn"
end

function ns.DayMonth(d)
    if not d or d == "" then return "" end
    local y, m, dd = string.match(d, "^(%d%d)(%d%d)(%d%d)$")
    if not y then return d end
    return dd .. "." .. m
end

function ns.DayMonthYear(d)
    local y = d and string.match(d, "^(%d%d)%d%d%d%d$")
    local baked = PlayerRaidsMeta and PlayerRaidsMeta.baked
    local by = type(baked) == "string" and string.match(baked, "^%d%d(%d%d)")
    if y and by and y ~= by then return ns.DayMonth(d) .. "." .. y end
    return ns.DayMonth(d)
end

function ns.BakedText()
    local baked = PlayerRaidsMeta and PlayerRaidsMeta.baked
    if type(baked) ~= "string" then return "" end
    local y, m, d, hh, mm = string.match(baked, "^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+)")
    if not y then return baked end
    return d .. "." .. m .. " " .. hh .. ":" .. mm
end

ns.CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
ns.ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
ns.ROLE_COORD = { t = { 0, 19, 22, 41 }, h = { 20, 39, 1, 20 }, d = { 20, 39, 22, 41 } }
ns.ICC_ICON = "Interface\\Icons\\Achievement_Boss_Lichking"
ns.RS_ICON = "Interface\\Icons\\Ability_Mount_Drake_Twilight"
ns.BOSS_ICON = {
    surf = "Interface\\Icons\\achievement_boss_saurfang",
    prof = "Interface\\Icons\\achievement_boss_profputricide",
    lich = "Interface\\Icons\\Achievement_Boss_Lichking",
    hal = "Interface\\Icons\\Ability_Mount_Drake_Twilight",
}
ns.SKULL = {
    tex = "Interface\\Minimap\\UI-DungeonDifficulty-Button",
    coord = { 0, 0.25, 0.0703125, 0.4140625 },
    ratio = 64 / 44,
}
ns.HEROIC = { ih = true, iu = true, rh = true }
ns.MODE_CAPTION = { ih = "гер", iu = "анбаф", ["in"] = "об", rh = "гер", rn = "об" }

local HEALERS = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true }

function ns.CanHeal(classFile)
    return HEALERS[classFile] and true or false
end

local TANKS = { WARRIOR = true, PALADIN = true, DEATHKNIGHT = true, DRUID = true }
local ANY_ROLE = { d = true, h = true, t = true }
local CLASS_ROLES = {}
for classFile in pairs(CLASS_RU) do
    CLASS_ROLES[classFile] = { d = true, h = HEALERS[classFile] or false, t = TANKS[classFile] or false }
end

function ns.ClassRoles(classFile)
    return classFile and CLASS_ROLES[classFile] or ANY_ROLE
end

function ns.RoleIcon(role, size)
    local c = ns.ROLE_COORD[role]
    if not c then return "" end
    size = size or 13
    return string.format("|T%s:%d:%d:0:0:64:64:%d:%d:%d:%d|t", ns.ROLE_TEX, size, size, c[1], c[2], c[3], c[4])
end

function ns.ClassIcon(classFile, size)
    local c = _G.CLASS_ICON_TCOORDS and classFile and _G.CLASS_ICON_TCOORDS[classFile]
    if not c then return "" end
    size = size or 16
    return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", ns.CLASS_TEX, size, size,
        floor(c[1] * 256 + 0.5), floor(c[2] * 256 + 0.5), floor(c[3] * 256 + 0.5), floor(c[4] * 256 + 0.5))
end

function ns.SetClassTexture(tex, classFile)
    local c = _G.CLASS_ICON_TCOORDS and classFile and _G.CLASS_ICON_TCOORDS[classFile]
    if not c then return false end
    tex:SetTexture(ns.CLASS_TEX)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
    return true
end

function ns.BossHead(boss, size)
    local icon = ns.BOSS_ICON[boss]
    local name = ns.BOSS[boss] or boss
    if not icon then return name end
    size = size or 14
    return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s", icon, size, size, name)
end

function ns.WipesText(w)
    if not w then return ns.Color("none", "—") end
    if w == 0 then return ns.Color("grey", "0") end
    if w <= 3 then return ns.Color("white", w) end
    return "|cffff8000" .. w .. "|r"
end

function ns.CellMain(cell)
    if not cell then return ns.Color("none", "—") end
    local out = ns.RoleIcon(cell.role)
    if cell.value then
        out = out .. " " .. ns.Color("white", ns.Compact(cell.value))
    elseif cell.role == "t" then
        out = out .. " " .. ns.Color("grey", "танк")
    end
    if cell.parse then out = out .. "  |cff" .. ns.ParseHex(cell.parse) .. cell.parse .. "|r" end
    return out
end

ns.CellText = ns.CellMain

function ns.CellSub(cell)
    if not cell then return "" end
    local bits = {}
    if cell.gear then
        tinsert(bits, ns.Color("dim", "на гире ") .. "|cff" .. ns.ParseHex(cell.gear) .. cell.gear .. "|r")
    end
    if cell.ilvl then tinsert(bits, ns.Color("dim", cell.ilvl)) end
    return table.concat(bits, ns.Color("none", " / "))
end

ns.FONT_BODY = "Fonts\\ARIALN.TTF"
ns.FONT_HEAD = "Fonts\\FRIZQT__.TTF"

function ns.Text(parent, size, justify, kind)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local path = ns.FONT_BODY
    if kind == "head" then path = (GameFontNormal and GameFontNormal:GetFont()) or ns.FONT_HEAD end
    fs:SetFont(path, size or 13)
    fs:SetShadowColor(0, 0, 0, 0)
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH(justify or "LEFT")
    if kind == "head" then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(0.95, 0.95, 0.95) end
    return fs
end

function ns.Rect(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(ns.WHITE)
    t:SetVertexColor(r, g, b, a)
    return t
end

ns.TIP_BACKDROP = {
    bgFile = ns.WHITE,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function ns.StyleTip(f)
    f:SetBackdrop(ns.TIP_BACKDROP)
    f:SetBackdropColor(0.016, 0.024, 0.04, 0.93)
    f:SetBackdropBorderColor(0.54, 0.56, 0.6, 1)
end

function ns.StylePanel(f)
    f:SetBackdrop(ns.TIP_BACKDROP)
    f:SetBackdropColor(0.067, 0.059, 0.047, 0.97)
    f:SetBackdropBorderColor(0.43, 0.35, 0.2, 1)
    local g = f:CreateTexture(nil, "BACKGROUND")
    g:SetTexture(ns.WHITE)
    g:SetPoint("TOPLEFT", 4, -4)
    g:SetPoint("BOTTOMRIGHT", -4, 4)
    g:SetGradientAlpha("VERTICAL", 0.067, 0.059, 0.047, 0.97, 0.114, 0.098, 0.078, 0.97)
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Рейды игроков:|r " .. msg)
end

ns.OPT_DEFAULTS = { chat = true, world = true, frames = false, guild = true, altOpen = true, follow = true, updates = true }
ns.ARROW = " |cff999999>|r "

function ns.Opt(key)
    local opts = PlayerRaidsDB.opts
    local v = opts and opts[key]
    if v == nil then return ns.OPT_DEFAULTS[key] end
    return v
end

function ns.SetOpt(key, value)
    PlayerRaidsDB.opts = PlayerRaidsDB.opts or {}
    PlayerRaidsDB.opts[key] = value and true or false
end

PlayerRaidsNotes = PlayerRaidsNotes or {}
ns.NOTE_MAX = 120

function ns.Utf8Cut(s, n)
    local out, count = {}, 0
    for ch in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then break end
        out[count] = ch
    end
    return table.concat(out)
end

function ns.Utf8Len(s)
    local n = 0
    for _ in string.gmatch(s or "", "[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n
end

function ns.DayText(day)
    if not day then return "" end
    return date("%d.%m.%y", day * 86400 + 43200)
end

function ns.Note(id)
    local n = id and PlayerRaidsNotes and PlayerRaidsNotes[id]
    return n and n.text or nil
end

local noteListeners = {}

function ns.OnNotesChanged(fn)
    tinsert(noteListeners, fn)
end

function ns.SetNote(id, text)
    if not id then return end
    PlayerRaidsNotes = PlayerRaidsNotes or {}
    text = string.match(text or "", "^%s*(.-)%s*$") or ""
    text = string.gsub(text, "|", "/")
    if text == "" then
        PlayerRaidsNotes[id] = nil
    else
        PlayerRaidsNotes[id] = { text = ns.Utf8Cut(text, ns.NOTE_MAX), at = time() }
    end
    for _, fn in ipairs(noteListeners) do fn(id) end
end

function ns.NoteMark(id)
    if not ns.Note(id) then return "" end
    return " |cffff9933*|r"
end

function ns.DayMonthYearFull(d)
    local y, m, dd = string.match(d or "", "^(%d%d)(%d%d)(%d%d)$")
    if not y then return d or "" end
    return dd .. "." .. m .. "." .. y
end

ns.ICC_LFG = "Interface\\LFGFrame\\LFGIcon-IcecrownCitadel"
ns.RS_LFG = "Interface\\LFGFrame\\LFGIcon-RubySanctum"

ns.DATA_URL = "https://gitlab.com/dmitrii.nosach/ManacodePlayerRaidsInfo/-/raw/data/Data.zip"
ns.COPY_TEX = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
ns.ARROW_DOWN_TEX = "Interface\\Buttons\\Arrow-Down-Up"
ns.HERO_ICON = "Interface\\Icons\\Achievement_Boss_Lichking"

function ns.HasClass(classFile)
    local pal = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    return classFile and pal and pal[classFile] and true or false
end

local SPEC_ART = {
    WARRIOR = { arms = "WarriorArms", fury = "WarriorFury", protection = "WarriorProtection" },
    PALADIN = { holy = "PaladinHoly", protection = "PaladinProtection", retribution = "PaladinCombat" },
    HUNTER = { beastmastery = "HunterBeastMastery", marksmanship = "HunterMarksmanship", survival = "HunterSurvival" },
    ROGUE = { assassination = "RogueAssassination", combat = "RogueCombat", subtlety = "RogueSubtlety" },
    PRIEST = { discipline = "PriestDiscipline", holy = "PriestHoly", shadow = "PriestShadow" },
    DEATHKNIGHT = { blood = "DeathKnightBlood", frost = "DeathKnightFrost", unholy = "DeathKnightUnholy" },
    SHAMAN = { elemental = "ShamanElementalCombat", enhancement = "ShamanEnhancement", restoration = "ShamanRestoration" },
    MAGE = { arcane = "MageArcane", fire = "MageFire", frost = "MageFrost" },
    WARLOCK = { affliction = "WarlockCurses", demonology = "WarlockSummoning", destruction = "WarlockDestruction" },
    DRUID = { balance = "DruidBalance", feral = "DruidFeralCombat", feralcombat = "DruidFeralCombat",
        guardian = "DruidFeralCombat", restoration = "DruidRestoration" },
}

local ART_KNOWN = {}
for _, specs in pairs(SPEC_ART) do
    for _, file in pairs(specs) do ART_KNOWN[file] = true end
end

function ns.ArtPath(file)
    if not file or not ART_KNOWN[file] then return nil end
    return "Interface\\TalentFrame\\" .. file .. "-TopLeft"
end

function ns.SpecArt(classFile, spec)
    local specs = classFile and SPEC_ART[classFile]
    if not specs or not spec or spec == "" then return nil end
    local key = string.gsub(ns.Lower(spec), "[%s_%-]", "")
    return ns.ArtPath(specs[key])
end

function ns.PaintArt(tex, path, w, h, alpha)
    if not path then
        tex:Hide()
        return
    end
    tex:SetTexture(path)
    local frac = 0.3
    if w and w > 0 and h then frac = math.min(h / w, 1) end
    local top = 0.12
    if top + frac > 1 then top = 1 - frac end
    tex:SetTexCoord(0, 1, top, top + frac)
    local a = alpha or 0.5
    tex:SetGradientAlpha("HORIZONTAL", 0.9, 0.9, 0.9, 0, 0.9, 0.9, 0.9, a)
    tex:Show()
end

function ns.AmbientRGB(classFile)
    local r, g, b = ns.ClassColor(classFile)
    if r > 0.9 and g > 0.9 and b > 0.9 then return 0.7, 0.75, 0.84 end
    return r, g, b
end

function ns.PaintWash(tex, classFile, a1, a2, orient)
    if not ns.HasClass(classFile) then
        tex:Hide()
        return
    end
    local r, g, b = ns.AmbientRGB(classFile)
    tex:SetTexture(ns.WHITE)
    tex:SetGradientAlpha(orient or "HORIZONTAL", r, g, b, a1, r, g, b, a2)
    tex:Show()
end

function ns.MakeGlow(f, inset, depth)
    local g = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture(ns.WHITE)
        t:SetBlendMode("ADD")
        if side == "TOP" or side == "BOTTOM" then
            local dy = side == "TOP" and -inset or inset
            t:SetHeight(depth)
            t:SetPoint(side .. "LEFT", f, side .. "LEFT", inset, dy)
            t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", -inset, dy)
        else
            local dx = side == "LEFT" and inset or -inset
            t:SetWidth(depth)
            t:SetPoint("TOP" .. side, f, "TOP" .. side, dx, -inset)
            t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, dx, inset)
        end
        t:Hide()
        g[side] = t
    end
    f.glowTex = g
end

function ns.Ambient(f, classFile, base, amount, alpha)
    local g = f.glowTex
    if not ns.HasClass(classFile) then
        f:SetBackdropBorderColor(base[1], base[2], base[3], 1)
        if g then for _, t in pairs(g) do t:Hide() end end
        return
    end
    local r, gr, b = ns.AmbientRGB(classFile)
    local k = amount or 0.55
    f:SetBackdropBorderColor(base[1] * (1 - k) + r * k, base[2] * (1 - k) + gr * k, base[3] * (1 - k) + b * k, 1)
    if not g then return end
    local a = alpha or 0.2
    g.TOP:SetGradientAlpha("VERTICAL", r, gr, b, 0, r, gr, b, a)
    g.BOTTOM:SetGradientAlpha("VERTICAL", r, gr, b, a, r, gr, b, 0)
    g.LEFT:SetGradientAlpha("HORIZONTAL", r, gr, b, a, r, gr, b, 0)
    g.RIGHT:SetGradientAlpha("HORIZONTAL", r, gr, b, 0, r, gr, b, a)
    for _, t in pairs(g) do t:Show() end
end

local BTN_BACKDROP = {
    bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

ns.BTN = {
    bg = { 0.18, 0.16, 0.12, 0.95 }, border = { 0.62, 0.52, 0.32, 1 }, text = { 0.9, 0.9, 0.9 },
    bgHover = { 0.32, 0.26, 0.13, 0.97 }, borderHover = { 1, 0.84, 0.35, 1 }, textHover = { 1, 1, 1 },
    bgDown = { 0.05, 0.045, 0.035, 1 },
    bgOn = { 0.86, 0.68, 0.12, 1 }, bgOnHover = { 1, 0.82, 0.25, 1 }, borderOn = { 1, 0.9, 0.45, 1 },
    textOn = { 0.1, 0.07, 0.02 },
    bgOff = { 0.07, 0.065, 0.06, 0.85 }, borderOff = { 0.22, 0.22, 0.22, 1 }, textOff = { 0.36, 0.36, 0.36 },
    bgOnOff = { 0.38, 0.30, 0.08, 0.9 }, textOnOff = { 0.8, 0.72, 0.5 },
    textEmpty = { 0.62, 0.62, 0.64 },
}

function ns.PaintButton(b)
    local c = ns.BTN
    local bg, br, t
    if b.off then
        if b.on then bg, br, t = c.bgOnOff, c.borderOff, c.textOnOff
        else bg, br, t = c.bgOff, c.borderOff, c.textOff end
    elseif b.on then
        bg, br, t = (b.hovered and c.bgOnHover or c.bgOn), c.borderOn, c.textOn
    elseif b.pressed then
        bg, br, t = c.bgDown, c.borderHover, c.textHover
    elseif b.hovered then
        bg, br, t = c.bgHover, c.borderHover, c.textHover
    else
        bg, br, t = c.bg, c.border, (b.empty and c.textEmpty or c.text)
    end
    b:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    b:SetBackdropBorderColor(br[1], br[2], br[3], br[4])
    if b.text then b.text:SetTextColor(t[1], t[2], t[3]) end
    if b.icon then
        b.icon:SetVertexColor(t[1], t[2], t[3])
    end
end

function ns.SetButton(b, on, off, empty)
    b.on, b.off, b.empty = on and true or nil, off and true or nil, empty and true or nil
    ns.PaintButton(b)
end

function ns.MakeButton(parent, fontSize, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(h or 20)
    if w then b:SetWidth(w) end
    b:SetBackdrop(BTN_BACKDROP)
    b.text = ns.Text(b, fontSize or 13, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:SetScript("OnEnter", function(self)
        self.hovered = true
        ns.PaintButton(self)
        if self.tip then self.tip(self) end
    end)
    b:SetScript("OnLeave", function(self)
        self.hovered, self.pressed = nil, nil
        self.text:SetPoint("CENTER", self, "CENTER", self.textX or 0, 0)
        ns.PaintButton(self)
        if self.tip then GameTooltip:Hide() end
    end)
    b:SetScript("OnMouseDown", function(self)
        if self.off then return end
        self.pressed = true
        self.text:SetPoint("CENTER", self, "CENTER", (self.textX or 0) + 1, -1)
        ns.PaintButton(self)
    end)
    b:SetScript("OnMouseUp", function(self)
        self.pressed = nil
        self.text:SetPoint("CENTER", self, "CENTER", self.textX or 0, 0)
        ns.PaintButton(self)
    end)
    b:SetScript("OnClick", function(self, button)
        if self.off then return end
        if self.onClick then self.onClick(self, button) end
    end)
    ns.PaintButton(b)
    return b
end

function ns.FitButton(b, text, pad)
    b.text:SetText(text)
    b:SetWidth(math.floor((b.text:GetStringWidth() or 40) + (pad or 16)))
end

function ns.Tip(owner, anchor, title, ...)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 0.82, 0)
    for i = 1, select("#", ...) do
        local l = select(i, ...)
        if l then GameTooltip:AddLine(l, 0.9, 0.9, 0.9, 1) end
    end
    GameTooltip:Show()
end

function ns.TipTable(owner, anchor, title, rows, foot)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 0.82, 0)
    for _, r in ipairs(rows or {}) do
        if type(r) == "table" then
            GameTooltip:AddDoubleLine(r[1], tostring(r[2]), 0.8, 0.8, 0.8, 1, 1, 1)
        else
            GameTooltip:AddLine(r, 0.9, 0.9, 0.9, 1)
        end
    end
    if foot then GameTooltip:AddLine(foot, 0.5, 0.52, 0.55, 1) end
    GameTooltip:Show()
end

function ns.FitText(fs, text, maxW)
    fs:SetText(text)
    local w = fs:GetStringWidth() or 0
    if w <= maxW then return w end
    local n = ns.Utf8Len(text)
    while n > 1 do
        n = n - 1
        fs:SetText(ns.Utf8Cut(text, n) .. "…")
        w = fs:GetStringWidth() or 0
        if w <= maxW then return w end
    end
    return w
end

local copy

local function buildCopy()
    copy = CreateFrame("Frame", "PlayerRaidsCopy", UIParent)
    copy:SetFrameStrata("FULLSCREEN_DIALOG")
    copy:SetHeight(56)
    copy:SetWidth(230)
    copy:EnableMouse(true)
    ns.StyleTip(copy)
    copy:SetBackdropBorderColor(1, 0.82, 0, 1)
    copy:Hide()
    local eb = CreateFrame("EditBox", "PlayerRaidsCopyBox", copy, "InputBoxTemplate")
    eb:SetHeight(20)
    eb:SetPoint("TOPLEFT", copy, "TOPLEFT", 16, -8)
    eb:SetPoint("TOPRIGHT", copy, "TOPRIGHT", -10, -8)
    eb:SetAutoFocus(false)
    eb:SetFont(ns.FONT_BODY, 13)
    eb:SetScript("OnEscapePressed", function() copy:Hide() end)
    eb:SetScript("OnEnterPressed", function() copy:Hide() end)
    eb:SetScript("OnEditFocusLost", function() copy:Hide() end)
    eb:SetScript("OnTextChanged", function(self)
        if copy.value and self:GetText() ~= copy.value then
            self:SetText(copy.value)
            self:HighlightText()
        end
    end)
    copy:SetScript("OnHide", function()
        copy.value = nil
        eb:ClearFocus()
    end)
    copy.box = eb
    copy.hint = ns.Text(copy, 12)
    copy.hint:SetTextColor(0.62, 0.62, 0.62)
    copy.hint:SetPoint("BOTTOMLEFT", copy, "BOTTOMLEFT", 11, 9)
    copy.hint:SetText("Ctrl+C — скопировать, Esc — закрыть")
end

function ns.ShowCopy(anchor, text, width)
    if not copy then buildCopy() end
    if copy:IsShown() and copy.value == text and copy.anchor == anchor then
        copy:Hide()
        return
    end
    copy.anchor = anchor
    copy:SetWidth(width or 230)
    copy:ClearAllPoints()
    copy:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -8, -3)
    copy:Show()
    copy.value = text
    copy.box:SetText(text)
    copy.box:SetFocus()
    copy.box:HighlightText()
end

function ns.HideCopy()
    if copy then copy:Hide() end
end

local blur = CreateFrame("Frame")
blur:Hide()
blur:SetScript("OnUpdate", function(self)
    local box = self.box
    if not box then
        self:Hide()
        return
    end
    if not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then return end
    if GetMouseFocus() == box then return end
    self.box = nil
    self:Hide()
    box:ClearFocus()
end)

function ns.BlurOnClick(box)
    box:HookScript("OnEditFocusGained", function(self)
        blur.box = self
        blur:Show()
    end)
    box:HookScript("OnEditFocusLost", function(self)
        if blur.box == self then
            blur.box = nil
            blur:Hide()
        end
    end)
end

function ns.SyncSeasons()
    PlayerRaidsDB.opts = PlayerRaidsDB.opts or {}
    local o = PlayerRaidsDB.opts
    local list = {}
    local meta = ns.Meta and ns.Meta() or {}
    for _, sn in ipairs(meta.seasons or {}) do
        sn = tonumber(sn)
        if sn then tinsert(list, sn) end
    end
    if o.seasonsFrom ~= nil and (type(o.seasons) == "table" or #list > 0) then
        local from = tonumber(o.seasonsFrom) or 0
        if type(o.seasons) ~= "table" then
            o.seasons = {}
            for _, sn in ipairs(list) do
                if sn >= from then o.seasons[sn] = true end
            end
        end
        o.seasonsFrom = nil
    end
    if type(o.seasons) ~= "table" then
        if #list == 0 then return end
        o.seasons = {}
        for _, sn in ipairs(list) do o.seasons[sn] = true end
    end
    local cur = ns.CurrentSeason and ns.CurrentSeason()
    if cur then o.seasons[cur] = true end
end

function ns.SeasonWanted(sn)
    if sn == (ns.CurrentSeason and ns.CurrentSeason()) then return true end
    local o = PlayerRaidsDB.opts
    if not o or type(o.seasons) ~= "table" then return true end
    return o.seasons[sn] and true or false
end

function ns.SetSeasonWanted(sn, on)
    ns.SyncSeasons()
    local o = PlayerRaidsDB.opts
    o.seasons = o.seasons or {}
    if sn == (ns.CurrentSeason and ns.CurrentSeason()) then on = true end
    o.seasons[sn] = on and true or nil
end

local syncer = CreateFrame("Frame")
syncer:RegisterEvent("PLAYER_LOGIN")
syncer:SetScript("OnEvent", function() ns.SyncSeasons() end)
