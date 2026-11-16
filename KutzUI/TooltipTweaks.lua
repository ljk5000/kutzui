---------------------------------------------------------------------------
-- KutzUI / TooltipTweaks        (module "tooltip")
--
-- Small, separate switches for the mouse-over tooltip (menu: Tooltip and bags page):
--   * hide the health bar under a unit's tooltip (off to start with: the bar shows)
--   * tooltip size (a slider)
--   * how long the tooltip takes to fade away after you move off a unit or object (a slider)
--   * unit tooltips (players, NPCs) colour-coded with symbols: class colours, a faction emblem, the
--     guild in <angle brackets>, "Lvl" instead of "Level", a status (Away / Busy / Offline / Ghost,
--     and the Dead line), and on NPCs the kingdom line ("Stormwind", "Orgrimmar" ...) in its side's
--     colour with the faction emblem - separate switches
--
-- (An item's level is already part of Blizzard's own item tooltip, so nothing is added there. The extras -
-- IDs, "Targeting:", item-quality borders - are in TooltipExtras.lua.)
--
-- Nothing is hooked: alpha / scale only, re-applied by a slow poller. Where the tooltip
-- appears is the "Bag and tooltip" module (Movers.lua).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("tooltip", function()

local DEFAULTS = {
    ttHideHealthBar = false,    -- hide the health bar under unit tooltips (off: Blizzard's bar shows)
    ttScale         = 100,      -- percent
    ttFadeMs        = 150,      -- fade-out time in milliseconds after leaving a unit / object (1000 = Blizzard's own)
    ttColorUnits    = true,     -- class-coloured names, faction colours, <guild>, level difficulty colours
    ttSymbols       = true,     -- the class icon and faction emblem
    ttLvl           = true,     -- "Lvl 7" instead of "Level 7"
    ttStatus        = true,     -- Away / Busy / Offline / Ghost beside a player's name, and a coloured Dead line
    ttIds           = false,    -- item / spell / NPC / currency IDs (TooltipExtras.lua)
    ttTarget        = true,     -- "Targeting: Name" under a unit tooltip (TooltipExtras.lua)
    ttRarity        = true,     -- item tooltips get a border in the item's quality colour (TooltipExtras.lua)
    ttCompare       = true,     -- gear comparison: green "EQUIPPED" / orange "NOT EQUIPPED" bars and borders (TooltipCompare.lua)
}

ns.TT_SCALE_MIN, ns.TT_SCALE_MAX = 60, 150
ns.TT_FADE_MAX = 1000                 -- at this value the tooltip's own fade is left alone

function ns.TTOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

function ns.SetTTOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
end

function ns.ResetTTSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
end

---------------------------------------------------------------------------
-- Unit tooltips: colour-coded, with symbols.
--
-- Blizzard builds the tooltip, then calls the functions addons registered with
-- TooltipDataProcessor.AddTooltipPostCall (Blizzard routes those through an isolated path, so addon
-- code can't taint its own). Ours only rewrites the TEXT of lines, using facts read from the unit
-- itself (class, race, faction, guild, level). If any of those is hidden by the game ("secret"), that
-- part is left exactly as Blizzard wrote it.
--
--   name line   [faction emblem] [class icon] Name in the class colour   (players)
--   guild line  <Guild Name> in green                                    (players)
--   (Blizzard's own separate "Paladin" and "Alliance" lines under it are dropped, so nothing is said twice)
--   level line  Lvl 7  Human  Paladin                                    (players; the number is coloured by
--                                                                         how hard they are for you, the class in
--                                                                         its colour; the race is in the faction's
--                                                                         colour when symbols are off)
--               Lvl 10  Humanoid (Elite)                             (NPCs: only "Lvl" + the number's colour)
---------------------------------------------------------------------------
local FACTION_HEX = { Alliance = "5b8cff", Horde = "e34747" }           -- blue for the Alliance, red for the Horde
local FACTION_ICON = {
    Alliance = "|TInterface\\TargetingFrame\\UI-PVP-Alliance:16:16:0:0:64:64:0:39:0:41|t",
    Horde    = "|TInterface\\TargetingFrame\\UI-PVP-Horde:16:16:0:0:64:64:0:39:0:41|t",
}
local GUILD_HEX, PVP_HEX = "6ee08a", "ff8a3d"

-- status: the friends-list icons (Blizzard's own files) and a colour for each
local STATUS_ICON = {
    away    = _G.FRIENDS_TEXTURE_AFK     or "Interface\\FriendsFrame\\StatusIcon-Away",
    busy    = _G.FRIENDS_TEXTURE_DND     or "Interface\\FriendsFrame\\StatusIcon-DnD",
    offline = _G.FRIENDS_TEXTURE_OFFLINE or "Interface\\FriendsFrame\\StatusIcon-Offline",
}
local STATUS_HEX = { away = "ffd24d", busy = "ff5555", offline = "8a8f99", ghost = "9aa0aa" }
local SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14:14|t "     -- the raid skull, beside "Dead"
local DEAD_HEX = "d04545"

-- The line under an NPC's level that names its kingdom or group ("Stormwind"). Known names get their side's
-- colour (blue Alliance / red Horde) and emblem; neutral groups get gold and no emblem. A name not in these
-- lists is only treated as a kingdom when it sits right under the level line of an NPC that belongs to a side.
local KINGDOM_SIDE = {
    ["Stormwind"] = "Alliance", ["Ironforge"] = "Alliance", ["Darnassus"] = "Alliance", ["Exodar"] = "Alliance",
    ["Gilneas"] = "Alliance", ["Gnomeregan Exiles"] = "Alliance", ["Kul Tiras"] = "Alliance", ["Wildhammer Clan"] = "Alliance",
    ["Orgrimmar"] = "Horde", ["Thunder Bluff"] = "Horde", ["Undercity"] = "Horde", ["Silvermoon City"] = "Horde",
    ["Darkspear Trolls"] = "Horde", ["Bilgewater Cartel"] = "Horde", ["Zandalar"] = "Horde", ["Frostwolf Clan"] = "Horde",
    ["Booty Bay"] = "Neutral", ["Gadgetzan"] = "Neutral", ["Ratchet"] = "Neutral", ["Everlook"] = "Neutral",
    ["Steamwheedle Cartel"] = "Neutral", ["Argent Dawn"] = "Neutral", ["Cenarion Circle"] = "Neutral", ["Darkmoon Faire"] = "Neutral",
}
local NEUTRAL_HEX = "d8b84a"

local function KingdomSide(plain, npcSide, justUnderLevel)
    local known = KINGDOM_SIDE[plain]
    if known then return known end
    if justUnderLevel and npcSide and FACTION_HEX[npcSide]
        and #plain <= 32 and not plain:find("[%d:<>]") and plain:sub(1, 1) ~= "-" then
        return npcSide
    end
    return nil
end
local issecret = issecretvalue or function() return false end

local function Hex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Clean(v)                          -- a value we may use: not hidden by the game
    if v == nil or issecret(v) then return nil end
    return v
end

local function ClassHex(classFile)
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local c = classFile and colors and colors[classFile]
    if c then return Hex(c.r, c.g, c.b) end
end

local function LevelHex(level)                   -- grey / green / yellow / orange / red, as Blizzard colours quest levels
    if level and level < 0 then return "ff3333" end
    local fn = _G.GetQuestDifficultyColor
    local c = fn and level and fn(level)
    if c then return Hex(c.r, c.g, c.b) end
    return "ffffff"
end

local function Escape(s) return (s:gsub("%p", "%%%0")) end

local function Strip(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    return s
end

-- "[icon] Away" / "Busy" / "Offline" / "Ghost" for a player, or nil. One at a time, most important first.
local function StatusMarkup(unit, symbols)
    local connected = Clean(UnitIsConnected(unit))
    local state
    if connected == false then state = "offline"
    elseif Clean(UnitIsDND(unit)) then state = "busy"
    elseif Clean(UnitIsAFK(unit)) then state = "away"
    elseif Clean(UnitIsGhost(unit)) then state = "ghost" end
    if not state then return nil end
    local words = {
        away = _G.SOCIAL_UI_PRESENCE_TYPE_LABEL_AWAY or "Away",
        busy = _G.SOCIAL_UI_PRESENCE_TYPE_LABEL_BUSY or "Busy",
        offline = _G.PLAYER_OFFLINE or "Offline",
        ghost = _G.GHOST or "Ghost",
    }
    local icon = (symbols and STATUS_ICON[state]) and ("|T" .. STATUS_ICON[state] .. ":14:14|t ") or ""
    return icon .. "|cff" .. STATUS_HEX[state] .. words[state] .. "|r"
end

local function StyleUnitTooltip(tooltip)
    local _, unit = _G.TooltipUtil.GetDisplayedUnit(tooltip)
    if type(unit) ~= "string" or issecret(unit) or not UnitExists(unit) then return end
    local color, symbols, short = ns.TTOption("ttColorUnits"), ns.TTOption("ttSymbols"), ns.TTOption("ttLvl")
    local status = ns.TTOption("ttStatus")
    if not (color or short or status) then return end

    local isPlayer = Clean(UnitIsPlayer(unit))
    local levelWord = _G.LEVEL or "Level"
    local pvpWord = _G.PVP

    -- what we know about a player
    local className, classFile, raceName, faction, factionName, guild, classHex
    if isPlayer then
        className, classFile = Clean((UnitClass(unit))), Clean(select(2, UnitClass(unit)))
        raceName = Clean((UnitRace(unit)))
        faction, factionName = UnitFactionGroup(unit)
        faction, factionName = Clean(faction), Clean(factionName)
        guild = Clean((GetGuildInfo(unit)))
        classHex = ClassHex(classFile)
    end
    local statusMarkup = (isPlayer and status) and StatusMarkup(unit, symbols) or nil
    local deadWord = _G.DEAD or "Dead"

    local name = tooltip:GetName()
    local lines = tooltip:NumLines()
    local npcSide = (not isPlayer) and Clean((UnitFactionGroup(unit))) or nil
    local changed, levelDone, guildDone, levelLine = false, false, false, nil
    for i = 1, lines do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if type(text) == "string" and not issecret(text) and text ~= "" then
            local plain = Strip(text)
            if i == 1 then
                if isPlayer then
                    local base, suffix = plain, ""
                    if statusMarkup then                -- Blizzard's own "<Away>" / "<Busy>" is replaced by ours
                        base = plain:gsub("%s*<[^<>]*>%s*$", "")
                        suffix = "  " .. statusMarkup
                    end
                    if color and classHex then
                        local emblem = (symbols and faction and FACTION_ICON[faction]) and (FACTION_ICON[faction] .. " ") or ""
                        local classIcon = (symbols and classFile) and ("|A:classicon-" .. classFile:lower() .. ":14:14|a ") or ""
                        fs:SetText(emblem .. classIcon .. "|cff" .. classHex .. base .. "|r" .. suffix)
                        changed = true
                    elseif statusMarkup then
                        fs:SetText(base .. suffix)
                        changed = true
                    end
                end
            elseif isPlayer and color and guild and not guildDone and plain:find(guild, 1, true) then
                fs:SetText("|cff" .. GUILD_HEX .. "<" .. guild .. ">|r")
                guildDone, changed = true, true
            elseif not levelDone and plain:find(levelWord, 1, true) then
                levelDone, levelLine = true, i
                local level = Clean(UnitLevel(unit))
                local shown = short and "Lvl" or levelWord
                if isPlayer and color and classHex and level then
                    local number = (level > 0) and tostring(level) or "??"
                    local parts = { "|cff" .. LevelHex(level) .. shown .. " " .. number .. "|r" }
                    if raceName then
                        -- the faction is on the name line (emblem); without symbols it would be lost, so the
                        -- race then carries the faction's colour
                        local raceHex = (not symbols and faction) and FACTION_HEX[faction] or nil
                        parts[#parts + 1] = raceHex and ("|cff" .. raceHex .. raceName .. "|r") or raceName
                    end
                    if className then parts[#parts + 1] = "|cff" .. classHex .. className .. "|r" end   -- the class, after the race
                    fs:SetText(table.concat(parts, "  "))
                    changed = true
                else
                    local num, rest = plain:match("^" .. Escape(levelWord) .. "%s+([%d%?%-]+)%s*(.*)$")
                    if num then
                        local head = shown .. " " .. num
                        if color then head = "|cff" .. LevelHex(tonumber(num) or -1) .. head .. "|r" end
                        fs:SetText(head .. (rest ~= "" and ("  " .. rest) or ""))
                        changed = true
                    elseif short then
                        fs:SetText((plain:gsub(Escape(levelWord), "Lvl", 1)))
                        changed = true
                    end
                end
            elseif color and pvpWord and plain == pvpWord then
                fs:SetText("|cff" .. PVP_HEX .. plain .. "|r")
                changed = true
            elseif status and plain == deadWord then       -- the "Dead" line (players and creatures)
                fs:SetText((symbols and SKULL or "") .. "|cff" .. DEAD_HEX .. plain .. "|r")
                changed = true
            elseif color and not isPlayer and plain ~= pvpWord then
                local side = KingdomSide(plain, npcSide, levelLine ~= nil and i == levelLine + 1)
                if side then                                 -- the kingdom line of an NPC
                    local hex = FACTION_HEX[side] or NEUTRAL_HEX
                    local emblem = (symbols and FACTION_ICON[side]) and (FACTION_ICON[side] .. " ") or ""
                    fs:SetText(emblem .. "|cff" .. hex .. plain .. "|r")
                    changed = true
                end
            end
        end
    end
    if changed then tooltip:Show() end           -- let the tooltip size itself to the new text
end

ns.TTStyleUnit = StyleUnitTooltip

-- Blizzard puts a player's class and faction on lines of their own under the level line ("Paladin",
-- "Alliance"). The name line now carries both (class colour + icon, faction emblem), so those two lines
-- are dropped: a LINE pre-call, which Blizzard runs before it adds each line and which stops the line
-- from being added when it returns true. Only for players, only while the colour switch is on, and only
-- when the class / faction is readable (so something we can't show is never removed).
local function IsRepeatedLine(tooltip, lineData)
    if tooltip ~= _G.GameTooltip or not ns.TTOption("ttColorUnits") then return false end
    if type(lineData) ~= "table" then return false end
    local lineTypes = _G.Enum.TooltipDataLineType
    if lineTypes and lineData.type == lineTypes.UnitName then return false end
    local text = lineData.leftText
    if type(text) ~= "string" or issecret(text) then return false end
    if not tooltip:IsTooltipType(_G.Enum.TooltipDataType.Unit) then return false end
    local _, unit = _G.TooltipUtil.GetDisplayedUnit(tooltip)
    if type(unit) ~= "string" or issecret(unit) or not UnitExists(unit) then return false end
    if not Clean(UnitIsPlayer(unit)) then return false end

    local plain = Strip(text)
    local className, classFile = UnitClass(unit)
    className, classFile = Clean(className), Clean(classFile)
    if className and classFile and ClassHex(classFile) and plain == className then return true end
    local faction, factionName = UnitFactionGroup(unit)
    faction, factionName = Clean(faction), Clean(factionName)
    if faction and FACTION_HEX[faction] and (plain == factionName or plain == faction) then return true end
    return false
end

if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddLinePreCall and _G.TooltipDataProcessor.AllTypes
    and _G.Enum and _G.Enum.TooltipDataType and _G.TooltipUtil and _G.TooltipUtil.GetDisplayedUnit then
    _G.TooltipDataProcessor.AddLinePreCall(_G.TooltipDataProcessor.AllTypes, function(tooltip, lineData)
        local ok, drop = pcall(IsRepeatedLine, tooltip, lineData)
        return ok and drop or false
    end)
end

if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall and _G.Enum and _G.Enum.TooltipDataType
    and _G.TooltipUtil and _G.TooltipUtil.GetDisplayedUnit then
    _G.TooltipDataProcessor.AddTooltipPostCall(_G.Enum.TooltipDataType.Unit, function(tooltip)
        if tooltip ~= _G.GameTooltip or tooltip:IsForbidden() then return end
        local ok, err = pcall(StyleUnitTooltip, tooltip)
        if not ok and not ns.unitTipErrored then
            ns.unitTipErrored = true
            ns.Print("unit tooltip error (please report): " .. tostring(err))
        end
    end)
end

local TIPS = { "GameTooltip", "ItemRefTooltip" }
local baseScale, appliedScale = {}, {}          -- tooltip -> Blizzard's own scale / the scale we set

local function Tick()
    local bar = (_G.GameTooltip and _G.GameTooltip.StatusBar) or _G.GameTooltipStatusBar
    ns.SetFrameHidden(bar, ns.TTOption("ttHideHealthBar"), 1)

    local pct = ns.TTOption("ttScale")
    for _, name in ipairs(TIPS) do
        local tip = _G[name]
        if tip and tip.GetScale then
            local cur = tip:GetScale()
            if appliedScale[tip] == nil or math.abs(cur - appliedScale[tip]) > 0.001 then baseScale[tip] = cur end
            local target = baseScale[tip] * pct / 100
            if math.abs(cur - target) > 0.001 then tip:SetScale(target) end
            appliedScale[tip] = tip:GetScale()
        end
    end
end

---------------------------------------------------------------------------
-- A shorter fade-out. When you move off a unit or object in the world, Blizzard calls the tooltip's own
-- FadeOut(), a fixed fade inside the game that an addon can't shorten. What we CAN do is notice that the fade
-- has started (the tooltip is shown but its alpha is below full) and finish it sooner: our own quick ramp
-- down, then Hide(). Per frame, but it returns at the first check unless a fade is under way.
---------------------------------------------------------------------------
local fadeStart
local fader = CreateFrame("Frame")
fader:SetScript("OnUpdate", function()
    local tt = _G.GameTooltip
    if not tt or tt:IsForbidden() or not tt:IsShown() then fadeStart = nil; return end
    local ms = ns.TTOption("ttFadeMs")
    if ms >= ns.TT_FADE_MAX then fadeStart = nil; return end
    local alpha = tt:GetAlpha()
    if alpha >= 0.999 then fadeStart = nil; return end          -- not fading
    local now = GetTime()
    fadeStart = fadeStart or now
    local t = (ms > 0) and ((now - fadeStart) / (ms / 1000)) or 1
    if t >= 1 then
        tt:Hide()
        tt:SetAlpha(1)                                           -- ready for the next tooltip
        fadeStart = nil
    else
        tt:SetAlpha(math.min(alpha, 1 - t))
    end
end)

local acc = 0
local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    acc = 0
    local ok, err = pcall(Tick)
    if not ok and not ns.tooltipErrored then
        ns.tooltipErrored = true
        ns.Print("tooltip tweak error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    local tip = _G.GameTooltip
    ns.Print(string.format("tooltip: GameTooltip=%s statusBar=%s hideHealthBar=%s size=%s%%",
        tostring(tip ~= nil), tostring(tip and (tip.StatusBar ~= nil) or _G.GameTooltipStatusBar ~= nil),
        tostring(ns.TTOption("ttHideHealthBar")), tostring(ns.TTOption("ttScale"))))
end)

end)
