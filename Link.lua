local ADDON, ns = ...

local PREFIX = "MPRI"
local PROTO = "1"
local BODY_MAX = 200
local CHANNEL_GAP = 60
local REPLY_GAP = 60
local DATA_AHEAD = 12 * 3600
local HEARD_MAX = 300

local sentAt = {}
local repliedAt = {}
local heardCount = 0
local toldVersion, toldData
local groupWas = 0

local function parseVersion(v)
    if type(v) ~= "string" or #v > 12 then return nil end
    local a, b = string.match(v, "^b(%d%d?%d?)%.(%d%d?%d?)$")
    if not a then
        a = string.match(v, "^b(%d%d?%d?)$")
        b = "0"
    end
    if not a then return nil end
    return tonumber(a), tonumber(b)
end

local function newerVersion(a, b)
    local a1, a2 = parseVersion(a)
    local b1, b2 = parseVersion(b)
    if not a1 or not b1 then return false end
    if a1 ~= b1 then return a1 > b1 end
    return a2 > b2
end

ns.NewerVersion = newerVersion

local function myVersion()
    local v = GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")
    if parseVersion(v) then return v end
    return "b0"
end

local BAKED = "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$"

local function bakedTime(s)
    if type(s) ~= "string" or #s > 24 then return nil end
    local y, mo, d, h, mi, se = string.match(s, BAKED)
    if not y then return nil end
    y, mo, d, h, mi, se = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(se)
    if y < 2020 or y > 2100 or mo < 1 or mo > 12 or d < 1 or d > 31 or h > 23 or mi > 59 or se > 59 then return nil end
    local ok, t = pcall(time, { year = y, month = mo, day = d, hour = h, min = mi, sec = se })
    if not ok then return nil end
    return t
end

ns.BakedTime = bakedTime

local function bakedShort(s)
    local y, mo, d, h, mi = string.match(s or "", "^%d%d(%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)")
    if not y then return "?" end
    return d .. "." .. mo .. " " .. h .. ":" .. mi
end

local function myBaked()
    if not ns.DataOK() then return "", "0" end
    local meta = ns.Meta()
    if not bakedTime(meta.baked) then return "", "0" end
    return meta.baked, meta.complete == false and "0" or "1"
end

local function body(tag)
    local baked, complete = myBaked()
    return tag .. "\t" .. PROTO .. "\t" .. myVersion() .. "\t" .. baked .. "\t" .. complete
end

local function send(tag, chan, target)
    if not SendAddonMessage then return end
    local msg = body(tag)
    if #msg > BODY_MAX then return end
    pcall(SendAddonMessage, PREFIX, msg, chan, target)
end

local function shout(chan)
    local now = GetTime()
    if sentAt[chan] and now - sentAt[chan] < CHANNEL_GAP then return end
    sentAt[chan] = now
    send("HI", chan)
end

local function groupChannel()
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid > 0 then return raid, "RAID" end
    local party = GetNumPartyMembers and GetNumPartyMembers() or 0
    if party > 0 then return party, "PARTY" end
    return 0, nil
end

local function validSender(name)
    if type(name) ~= "string" or name == "" or #name > 48 then return nil end
    if string.find(name, "[%s%c|]") then return nil end
    local short = string.match(name, "^([^%-]+)") or name
    if short == UnitName("player") then return nil end
    return short
end

local function heard(from, ver, baked, complete)
    if not ns.Opt("updates") then return end
    if not toldVersion and newerVersion(ver, myVersion()) then
        toldVersion = true
        ns.Print("у " .. from .. " версия " .. ver .. ", у вас " .. myVersion())
    end
    local theirs = bakedTime(baked)
    if not toldData and theirs then
        local mine, mineT = myBaked()
        mineT = bakedTime(mine)
        if not mineT or theirs - mineT > DATA_AHEAD then
            toldData = true
            local where = mineT and ("у вас от " .. bakedShort(mine)) or "у вас выгрузки нет"
            ns.Print("у " .. from .. " выгрузка от " .. bakedShort(baked) .. ", " .. where
                .. " — запустите ОбновитьДанные.exe и /reload")
        end
    end
end

local function receive(prefix, message, channel, sender)
    if prefix ~= PREFIX then return end
    if type(message) ~= "string" or #message > BODY_MAX then return end
    if string.find(message, "|", 1, true) then return end
    if string.find((string.gsub(message, "\t", "")), "%c") then return end
    local from = validSender(sender)
    if not from then return end

    local tag, proto, ver, baked, complete, extra = strsplit("\t", message)
    if extra ~= nil then return end
    if tag ~= "HI" and tag ~= "HERE" then return end
    if proto ~= PROTO then return end
    if not parseVersion(ver) then return end
    if baked == nil or complete == nil then return end
    if baked ~= "" and not bakedTime(baked) then return end
    if complete ~= "0" and complete ~= "1" then return end

    heard(from, ver, baked, complete)

    if tag == "HI" then
        local now = GetTime()
        local key = string.lower(from)
        if repliedAt[key] and now - repliedAt[key] < REPLY_GAP then return end
        if not repliedAt[key] then
            heardCount = heardCount + 1
            if heardCount > HEARD_MAX then
                repliedAt, heardCount = {}, 1
            end
        end
        repliedAt[key] = now
        send("HERE", "WHISPER", from)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
    if event == "CHAT_MSG_ADDON" then
        receive(a1, a2, a3, a4)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if IsInGuild and IsInGuild() then shout("GUILD") end
        groupWas = 0
    end
    local n, chan = groupChannel()
    if n > groupWas and chan then shout(chan) end
    groupWas = n
end)

ns.LinkReceive = receive
ns.LinkVersion = myVersion
