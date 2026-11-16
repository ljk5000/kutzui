---------------------------------------------------------------------------
-- KutzUI / PartyTargets        (module "partytargets")
--
-- Beside each of Blizzard's party frames, small bars like your own Target-of-target:
--
--   [ party member's frame ] [ what they target ] [ what THAT targets ]
--
-- Each bar is just a health bar with the name on it, and CLICKABLE like a unit frame: left
-- click targets that unit, right click opens its menu. Each of the two kinds has its own switch,
-- and they are coloured either by the unit (class colour for players; green / yellow / red for
-- friendly / neutral / hostile creatures) or in one colour you pick for each.
-- (menu: Party frames page)
--
-- Being clickable means the bars are protected ("secure") buttons, the same kind as Blizzard's
-- unit frames. The game decides when they show (a unit watch: shown exactly while that unit
-- exists, in combat too). Addons may only MOVE them or switch them on / off outside combat, so:
--   * the bars are placed beside the party frames, and switches / width / spacing are applied,
--     outside combat (a change made in combat is applied the moment the fight ends);
--   * health, name and colour are updated all the time, in combat too.
--
-- There is one bar pair per party slot (party1 .. party4). Each is placed next to the party frame
-- that shows that member: Blizzard's classic party frames (PartyFrame.MemberFrame1-4) or the
-- raid-style ones (CompactPartyFrame). The raid-style frames can re-sort during a fight; the bars
-- then follow at the end of the fight. Nothing of Blizzard's is hooked or changed.
--
-- Where the game hides a unit's health or name from addons, the hidden value is handed straight
-- to the bar / text (which can show it) and never looked at.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("partytargets", function()

local DEFAULTS = {
    ptTarget      = true,       -- a bar for what each party member is targeting
    ptToT         = true,       -- a bar for what that target is targeting
    ptColorMode   = "unit",     -- "unit" (class / friendly-hostile colour) or "custom"
    ptColorTarget = "c8a24a",   -- the picked colours ("rrggbb")
    ptColorToT    = "7f8fa6",
    ptWidth       = 110,        -- each bar's width in pixels
    ptGap         = 4,          -- pixels between the party frame and the first bar (and between the bars)
}

function ns.PTOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

function ns.SetPTOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
end

function ns.ResetPTSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
end

local issecret = issecretvalue or function() return false end
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local BAR_H = 16
local SLOTS = 4

local function Hex(h)
    if type(h) ~= "string" or not h:match("^%x%x%x%x%x%x$") then return 1, 1, 1 end
    return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

-- the unit's own colour; anything the game hides is skipped (a grey-green fallback)
local function UnitRGB(unit)
    local isPlayer = UnitIsPlayer(unit)
    if not issecret(isPlayer) and isPlayer then
        local _, class = UnitClass(unit)
        local c = type(class) == "string" and not issecret(class) and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    end
    local reaction = UnitReaction(unit, "player")
    if type(reaction) == "number" and not issecret(reaction) then
        local c = _G.FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
        if c then return c.r, c.g, c.b end
    end
    return 0.45, 0.62, 0.45
end

local function ColorFor(kind, unit)
    if ns.PTOption("ptColorMode") == "custom" then
        return Hex(ns.PTOption(kind == "target" and "ptColorTarget" or "ptColorToT"))
    end
    return UnitRGB(unit)
end

---------------------------------------------------------------------------
-- One bar: a secure unit button (click = target, right click = menu) with a health bar on it
---------------------------------------------------------------------------
local function MakeBar(name, unit, kind)
    local f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    f.unit, f.kind = unit, kind
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f:EnableMouse(true)
    f:SetSize(DEFAULTS.ptWidth, BAR_H)
    f:SetClampedToScreen(true)
    f:Hide()

    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetStatusBarTexture(BAR_TEXTURE)
    f.health:SetAllPoints()
    f.health:SetMinMaxValues(0, 1); f.health:SetValue(1)
    f.text = f.health:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("LEFT", f.health, "LEFT", 4, 0)
    f.text:SetPoint("RIGHT", f.health, "RIGHT", -4, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    ns.StyleText(f.text, 11)

    f:SetScript("OnEnter", function(self)
        if UnitExists(self.unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(self.unit)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.watched = false
    return f
end

local function SetName(fs, unit)
    local name = UnitName(unit)
    if issecret(name) then fs:SetText(name)                 -- the text can show it; we don't look
    elseif type(name) == "string" then fs:SetText(ns.FormatName(name))
    else fs:SetText("") end
end

local function FillBar(bar)
    local unit = bar.unit
    bar.health:SetStatusBarColor(ColorFor(bar.kind, unit))
    bar.health:SetMinMaxValues(0, UnitHealthMax(unit))
    bar.health:SetValue(UnitHealth(unit))
    SetName(bar.text, unit)
end

local slots = {}                                       -- [i] = { target = bar, tot = bar }
ns.PTSlots = slots

---------------------------------------------------------------------------
-- Placing (outside combat only)
---------------------------------------------------------------------------
-- the party frame on screen that shows `unit` (classic or raid-style), or nil
local function FrameFor(unit)
    local function Shows(frame)
        if not (frame and frame:IsVisible()) then return false end
        local u = frame.unit
        return type(u) == "string" and not issecret(u) and u == unit
    end
    local party = _G.PartyFrame
    if party then
        for i = 1, SLOTS do
            local f = party["MemberFrame" .. i]
            if Shows(f) then
                return (ns.PartyBarOf and ns.PartyBarOf(f)) or f     -- KutzUI's wider bars stick out further: go after them
            end
        end
    end
    local compact = _G.CompactPartyFrame
    if compact and compact.memberUnitFrames then
        for _, f in ipairs(compact.memberUnitFrames) do
            if Shows(f) then return f end
        end
    end
    return nil
end

local function Park(bar)                               -- off: not shown, not watched
    if bar.watched then UnregisterUnitWatch(bar); bar.watched = false end
    bar.anchor = nil
    bar:Hide()
end

local function Arm(bar, anchor, gap, width)             -- on: placed, and shown whenever its unit exists
    if bar.anchor ~= anchor or bar.gap ~= gap then
        bar.anchor, bar.gap = anchor, gap
        bar:ClearAllPoints()
        bar:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
    end
    if bar.width ~= width then bar.width = width; bar:SetSize(width, BAR_H) end
    if not bar.watched then RegisterUnitWatch(bar); bar.watched = true end
end

local function Layout()
    if InCombatLockdown() then return false end
    local wantTarget, wantToT = ns.PTOption("ptTarget"), ns.PTOption("ptToT")
    local gap, width = ns.PTOption("ptGap"), ns.PTOption("ptWidth")
    for i = 1, SLOTS do
        local unit = "party" .. i
        local s = slots[i]
        if not s then
            s = { target = MakeBar("KutzPartyTarget" .. i, unit .. "target", "target"),
                  tot    = MakeBar("KutzPartyToT" .. i, unit .. "targettarget", "tot") }
            slots[i] = s
        end
        local anchor = FrameFor(unit)
        if anchor and wantTarget then Arm(s.target, anchor, gap, width) else Park(s.target) end
        -- the second bar always sits in the second place when both are on (with no target there is
        -- no target's target either, so it never floats on its own)
        if anchor and wantToT then Arm(s.tot, wantTarget and s.target or anchor, gap, width) else Park(s.tot) end
    end
    return true
end
ns.PTLayout = Layout

---------------------------------------------------------------------------
-- Driving it
---------------------------------------------------------------------------
local function Tick()
    if not InCombatLockdown() then Layout() end
    for _, s in ipairs(slots) do
        for _, bar in ipairs({ s.target, s.tot }) do
            if bar.watched and UnitExists(bar.unit) then pcall(FillBar, bar) end
        end
    end
end
ns.PTTick = Tick

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("UNIT_TARGET")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function() acc = 1 end)        -- refresh on the next frame
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    local ok, err = pcall(Tick)
    if not ok and not ns.partyTargetsErrored then
        ns.partyTargetsErrored = true
        ns.Print("party targets error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    local placed = 0
    for _, s in ipairs(slots) do
        if s.target.watched then placed = placed + 1 end
        if s.tot.watched then placed = placed + 1 end
    end
    ns.Print(string.format("party targets: target=%s tot=%s colour=%s | %d bars placed beside party frames",
        tostring(ns.PTOption("ptTarget")), tostring(ns.PTOption("ptToT")), tostring(ns.PTOption("ptColorMode")), placed))
end)

end)
