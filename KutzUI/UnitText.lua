---------------------------------------------------------------------------
-- KutzUI / UnitText
--
-- Adds text ONTO Blizzard's own Player and Target frames (nothing replaced):
--
--   health bar:  [ current number ............................ percent ]
--   power bar :  mana          -> [        12.3K  |  98%         ]  (centered)
--                rage/energy/… -> [            100               ]  (centered)
--
-- The helpers are also exported on `ns` so the custom Target-of-Target frame
-- (Layout.lua) shows exactly the same text. (Module: "frames")
--
-- Midnight-era note: in combat, health/power can be "secret values". They can
-- be shown, but not compared or used in math. We only do math when readable and
-- otherwise use UnitHealthPercent / UnitPowerPercent.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("frames", function()

local issecret = issecretvalue or function() return false end
local SCALE100 = CurveConstants and CurveConstants.ScaleTo100

local HEALTH_FONT_SIZE = 12
local POWER_FONT_SIZE  = 10
local TICK             = 0.1   -- seconds between text refreshes

---------------------------------------------------------------------------
-- Text helpers
---------------------------------------------------------------------------
local Present = ns.Present

-- The client's own AbbreviateNumbers(value, { config = ... }) does the work in
-- C, so a secret value passes straight through. WoW Forever's numbers are
-- small, so nothing under 10,000 is abbreviated: 9999 stays "9999", 12345
-- reads "12.3K". (Same approach the EllesmereUI reference addon uses.)
local abbrevOpts   -- nil = not built yet, false = unavailable

local function AbbrevOpts()
    if abbrevOpts == nil then
        abbrevOpts = false
        if CreateAbbreviateConfig and AbbreviateNumbers then
            local ok, cfg = pcall(CreateAbbreviateConfig, {
                { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 10000000, fractionDivisor = 100, abbreviationIsGlobal = false },
                { breakpoint = 1000000,    abbreviation = "M", significandDivisor = 10000,    fractionDivisor = 100, abbreviationIsGlobal = false },
                { breakpoint = 10000,      abbreviation = "K", significandDivisor = 100,      fractionDivisor = 10,  abbreviationIsGlobal = false },
                { breakpoint = 1,          abbreviation = "",  significandDivisor = 1,        fractionDivisor = 1,   abbreviationIsGlobal = false },
            })
            if ok and cfg then abbrevOpts = { config = cfg } end
        end
    end
    return abbrevOpts
end

local function Abbrev(v)
    local opts = AbbrevOpts()
    if opts then return AbbreviateNumbers(v, opts) end
    if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(v) end
    return v
end

local function FmtNum(fs, cur)         fs:SetFormattedText("%s", Abbrev(cur)) end
local function FmtRawNum(fs, cur)      fs:SetFormattedText("%s", cur) end
local function FmtPct(fs, pct)         fs:SetFormattedText("%.0f%%", pct) end
local function FmtBoth(fs, cur, pct)   fs:SetFormattedText("%s  |  %.0f%%", Abbrev(cur), pct) end
local function FmtRawBoth(fs, cur, pct) fs:SetFormattedText("%s  |  %.0f%%", cur, pct) end

local function SetNumber(fs, cur)
    if pcall(FmtNum, fs, cur) then return end
    if pcall(FmtRawNum, fs, cur) then return end
    fs:SetText("")
end

local function SetPercent(fs, pct)
    if not Present(pct) or not pcall(FmtPct, fs, pct) then fs:SetText("") end
end

-- "number  |  percent" in one string; degrades gracefully if a formatter
-- refuses a secret value.
local function SetNumberAndPercent(fs, cur, pct)
    if Present(pct) then
        if pcall(FmtBoth, fs, cur, pct) then return end
        if pcall(FmtRawBoth, fs, cur, pct) then return end
    end
    SetNumber(fs, cur)
end

-- Percent (0-100) or nil.
local function Percent(cur, max, apiFn, ...)
    if not issecret(cur) and not issecret(max) then
        if max and max > 0 then return cur / max * 100 end
        return nil
    end
    if apiFn and SCALE100 then
        local ok, v = pcall(apiFn, ...)
        if ok then return v end
    end
    return nil
end

function ns.UnitColor(unit)
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = class and not issecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]    -- a hidden class can't be a table key
        if c then return c.r, c.g, c.b end
    end
    local reaction = UnitReaction(unit, "player")
    local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then return c.r, c.g, c.b end
    return 0.2, 0.8, 0.2
end

---------------------------------------------------------------------------
-- Text overlay: a child frame of the bar (so it hides/shows with the bar),
-- raised above it, holding left / right / center FontStrings.
---------------------------------------------------------------------------
function ns.MakeOverlay(bar, size)
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar)
    holder:SetFrameLevel(bar:GetFrameLevel() + 10)

    local function fs(justify, point, x)
        local f = holder:CreateFontString(nil, "OVERLAY")
        ns.StyleText(f, size)
        f:SetJustifyH(justify)
        f:SetPoint(point, holder, point, x, 0)
        return f
    end
    return { holder = holder, left = fs("LEFT", "LEFT", 4), right = fs("RIGHT", "RIGHT", -4), center = fs("CENTER", "CENTER", 0) }
end

---------------------------------------------------------------------------
-- Updating text for a unit
---------------------------------------------------------------------------
function ns.UpdateHealthText(unit, o)
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    if UnitIsConnected(unit) == false then
        o.left:SetText("Offline"); o.right:SetText("")
    elseif UnitIsDeadOrGhost(unit) then
        o.left:SetText("Dead"); o.right:SetText("")
    else
        SetNumber(o.left, cur)
        SetPercent(o.right, Percent(cur, max, UnitHealthPercent, unit, false, SCALE100))
    end
end

-- Health percent only (used by the Target-of-Target frame)
function ns.UpdateHealthPercent(unit, fs)
    if UnitIsConnected(unit) == false then
        fs:SetText("Off")
    elseif UnitIsDeadOrGhost(unit) then
        fs:SetText("Dead")
    else
        local cur, max = UnitHealth(unit), UnitHealthMax(unit)
        SetPercent(fs, Percent(cur, max, UnitHealthPercent, unit, false, SCALE100))
    end
end

-- Health number over percent ("1234" above "98%"), for the tall health bar of KutzUI's own Player / Target bars
local function FmtStack(fs, cur, pct)    fs:SetFormattedText("%s\n%.0f%%", Abbrev(cur), pct) end
local function FmtRawStack(fs, cur, pct) fs:SetFormattedText("%s\n%.0f%%", cur, pct) end

function ns.UpdateHealthStack(unit, fs)
    if UnitIsConnected(unit) == false then
        fs:SetText("Offline")
    elseif UnitIsDeadOrGhost(unit) then
        fs:SetText("Dead")
    else
        local cur, max = UnitHealth(unit), UnitHealthMax(unit)
        local pct = Percent(cur, max, UnitHealthPercent, unit, false, SCALE100)
        if Present(pct) then
            if pcall(FmtStack, fs, cur, pct) then return end
            if pcall(FmtRawStack, fs, cur, pct) then return end
        end
        SetNumber(fs, cur)
    end
end

function ns.UpdatePowerText(unit, o)
    local pType, pToken = UnitPowerType(unit)
    local cur, max = UnitPower(unit, pType), UnitPowerMax(unit, pType)
    if not issecret(max) and max == 0 then
        o.center:SetText("")   -- no power resource
    elseif pToken == "MANA" then
        SetNumberAndPercent(o.center, cur, Percent(cur, max, UnitPowerPercent, unit, pType, false, SCALE100))
    else
        SetNumber(o.center, cur)   -- rage, energy, focus, ...: number only
    end
end

---------------------------------------------------------------------------
-- Finding Blizzard's bars. The exact layout differs between client versions,
-- so each bar lists several places to look; the first StatusBar found wins.
---------------------------------------------------------------------------
local function Dig(root, ...)
    for i = 1, select("#", ...) do
        if type(root) ~= "table" then return nil end
        root = root[select(i, ...)]
    end
    return root
end

local function Find(paths)
    for _, p in ipairs(paths) do
        local o = Dig(_G, unpack(p))
        if type(o) == "table" and o.GetObjectType and o:GetObjectType() == "StatusBar" then
            return o
        end
    end
end

local SOURCES = {
    {
        unit = "player",
        health = {
            { "PlayerFrame", "healthbar" },
            { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "HealthBarsContainer", "HealthBar" },
            { "PlayerFrameHealthBar" },
        },
        power = {
            { "PlayerFrame", "manabar" },
            { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "ManaBarArea", "ManaBar" },
            { "PlayerFrameManaBar" },
        },
    },
    {
        unit = "target",
        health = {
            { "TargetFrame", "healthbar" },
            { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar" },
            { "TargetFrameHealthBar" },
        },
        power = {
            { "TargetFrame", "manabar" },
            { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "ManaBar" },
            { "TargetFrameManaBar" },
        },
    },
}

-- Blizzard draws its own numbers on these bars ("136 / 136", "0 / 800") whenever
-- you hover them or open the character sheet, on top of ours. Make its copy
-- invisible instead (alpha only: we don't hook or hide anything of Blizzard's).
local function Mute(fs)
    if fs and fs.GetAlpha and fs:GetAlpha() ~= 0 then fs:SetAlpha(0) end
end

local function MuteBlizzardText(bar)
    Mute(bar.TextString); Mute(bar.LeftText); Mute(bar.RightText)
    Mute(bar.ManaBarText); Mute(bar.HealthBarText)
    local parent = bar:GetParent()
    if parent then
        Mute(parent.TextString); Mute(parent.LeftText); Mute(parent.RightText)
        Mute(parent.ManaBarText); Mute(parent.HealthBarText)
    end
end

local function Step(src)
    local unit = src.unit
    -- KutzUI's own bars (UnitBars.lua) draw this text themselves; Blizzard's bars are invisible then
    if ns.BarsActive and ns.BarsActive() then return end

    if not src.hBar then src.hBar = Find(src.health) end
    if not src.pBar then src.pBar = Find(src.power) end
    if src.hBar then MuteBlizzardText(src.hBar) end
    if src.pBar then MuteBlizzardText(src.pBar) end

    -- create overlays out of combat only (parents can be protected frames)
    if not InCombatLockdown() then
        if src.hBar and not src.hText then src.hText = ns.MakeOverlay(src.hBar, HEALTH_FONT_SIZE) end
        if src.pBar and not src.pText then src.pText = ns.MakeOverlay(src.pBar, POWER_FONT_SIZE) end
    end

    if not UnitExists(unit) then return end
    if src.hText and src.hBar:IsVisible() then ns.UpdateHealthText(unit, src.hText) end
    if src.pText and src.pBar:IsVisible() then ns.UpdatePowerText(unit, src.pText) end
end

local acc = 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < TICK then return end
    acc = 0
    for _, src in ipairs(SOURCES) do
        -- an error in one frame must not spam you or stop the others
        local ok, err = pcall(Step, src)
        if not ok and not src.errored then
            src.errored = true
            ns.Print(src.unit .. " text error (please report): " .. tostring(err))
        end
    end
end)

function ns.DebugUnits()
    for _, src in ipairs(SOURCES) do
        local h, p = Find(src.health), Find(src.power)
        ns.Print(string.format("%-8s health bar: %s   power bar: %s",
            src.unit, h and (h:GetName() or "found (unnamed)") or "NOT FOUND",
            p and (p:GetName() or "found (unnamed)") or "NOT FOUND"))
    end
    ns.Print("UnitHealthPercent=" .. tostring(UnitHealthPercent ~= nil)
        .. " UnitPowerPercent=" .. tostring(UnitPowerPercent ~= nil)
        .. " ScaleTo100=" .. tostring(SCALE100 ~= nil))
end

ns.RegisterDebug(ns.DebugUnits)

end)
