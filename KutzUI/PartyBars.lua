---------------------------------------------------------------------------
-- KutzUI / PartyBars         (part of module "frames")
--
-- Wider bars for Blizzard's classic party frames (PartyFrame.MemberFrame1-4):
--
--   (portrait) [ Name-Realm, wrapping    (role) ]
--              [ after 15 characters           ]
--              [ health bar:  12.3K                           98%   ]
--              [ power bar:          4567  |  80%                   ]
--
-- Blizzard's party frame has a 57-pixel name label and 70-pixel bars, so names are cut short and
-- the numbers only show when you point at them. Ours are 15 characters wide (the name wraps onto a second line) and the
-- health and power numbers are always shown (power = mana, rage, energy, focus ... whatever the
-- member uses; mana also gets its percent).
--
-- Nothing of Blizzard's is hooked or moved. Their portrait, its ring, level, leader / PvP / ready
-- check icons, buffs, debuffs and the pet frame all stay. Only the pieces we replace (the name, the
-- two bars with their text, the role icon) are made invisible - alpha only - and our bar is a
-- child of Blizzard's member frame, so it shows, hides and moves with it, in combat too.
-- It is a secure unit button: left click targets, right click opens the menu.
--
-- The raid-style party frames (Edit Mode: "Use raid-style party frames") are Blizzard's compact
-- frames; their size and health text are Edit Mode / Raid frame settings, so these bars don't apply.
-- Switch: "Wider party frames" on the Party frames page (DB.partyBars, on by default).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("frames", function()

local issecret = issecretvalue or function() return false end

local FLAT = "Interface\\Buttons\\WHITE8X8"
local SLOTS = 4
local NAME_SIZE, NUM_SIZE, POWER_SIZE = 10, 10, 9
local WRAP_AT = 15                                               -- the name wraps onto a second line after this many characters
local NAME_H, HEALTH_H, POWER_H = 22, 11, 7                      -- two name lines
local FRAME_H = 1 + NAME_H + 1 + HEALTH_H + 1 + POWER_H + 1      -- 44: as tall as Blizzard's frame, above its buff row
local LEFT_X, TOP_Y = 46, 0                                      -- just right of the portrait (Blizzard's name starts at 46)
local BORDER_OUT = 3

-- Blizzard's pieces we make invisible (keys inside each member frame)
local REPLACE = {
    { "Name" },
    { "HealthBarContainer" },
    { "ManaBar" },
    { "PartyMemberOverlay", "RoleIcon" },
}

local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

local bars = {}            -- [i] = our frame
local byMember = {}        -- Blizzard member frame -> our frame
local pending = false

local function On() return not (KutzUIDB and KutzUIDB.partyBars == false) end

local function Member(i)
    local party = _G.PartyFrame
    local m = party and party["MemberFrame" .. i]
    if type(m) == "table" and m.GetObjectType then return m end
end

local function Piece(member, path)
    local o = member
    for _, k in ipairs(path) do
        if type(o) ~= "table" then return nil end
        o = o[k]
    end
    if type(o) == "table" and o.SetAlpha and o.GetAlpha then return o end
end

local function SetReplaced(member, hide)
    for _, path in ipairs(REPLACE) do
        local o = Piece(member, path)
        if o then
            local want = hide and 0 or 1
            if o:GetAlpha() ~= want then o:SetAlpha(want) end
        end
    end
end

---------------------------------------------------------------------------
-- Our bar for one party slot (out of combat only: it is a protected frame)
---------------------------------------------------------------------------
local function Create(i, member)
    local unit = "party" .. i
    local f = CreateFrame("Button", "KutzPartyBars" .. i, member, "SecureUnitButtonTemplate")
    f.unit, f.member = unit, member
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f:EnableMouse(true)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.85)

    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetPoint("TOPLEFT", f, "TOPLEFT", -BORDER_OUT, BORDER_OUT)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", BORDER_OUT, -BORDER_OUT)
    border:EnableMouse(false)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
        border:SetBackdropBorderColor(0.95, 0.78, 0.30, 1)
    end
    f.border = border

    -- the text and bars sit above the border
    local inner = CreateFrame("Frame", nil, f)
    inner:SetAllPoints()
    inner:SetFrameLevel(border:GetFrameLevel() + 1)

    f.name = inner:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.name, NAME_SIZE)
    f.name:SetJustifyH("LEFT")
    f.name:SetJustifyV("MIDDLE")
    f.name:SetWordWrap(true)
    if f.name.SetNonSpaceWrap then f.name:SetNonSpaceWrap(true) end      -- "Name-Realm" has no space to break at
    if f.name.SetMaxLines then f.name:SetMaxLines(2) end
    f.role = inner:CreateTexture(nil, "OVERLAY")
    f.role:SetSize(12, 12)
    f.role:Hide()

    f.health = CreateFrame("StatusBar", nil, inner)
    f.health:SetStatusBarTexture(FLAT)
    f.health:SetMinMaxValues(0, 1); f.health:SetValue(1)
    f.health.bg = f.health:CreateTexture(nil, "BACKGROUND")
    f.health.bg:SetAllPoints()
    f.health.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    f.power = CreateFrame("StatusBar", nil, inner)
    f.power:SetStatusBarTexture(FLAT)
    f.power:SetMinMaxValues(0, 1); f.power:SetValue(0)
    f.power.bg = f.power:CreateTexture(nil, "BACKGROUND")
    f.power.bg:SetAllPoints()
    f.power.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    local hold = CreateFrame("Frame", nil, f.health)
    hold:SetAllPoints()
    hold:SetFrameLevel(f.health:GetFrameLevel() + 5)
    f.hpLeft = hold:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.hpLeft, NUM_SIZE)
    f.hpLeft:SetPoint("LEFT", hold, "LEFT", 4, 0)
    f.hpRight = hold:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.hpRight, NUM_SIZE)
    f.hpRight:SetPoint("RIGHT", hold, "RIGHT", -4, 0)
    f.hpText = { left = f.hpLeft, right = f.hpRight }

    local phold = CreateFrame("Frame", nil, f.power)
    phold:SetAllPoints()
    phold:SetFrameLevel(f.power:GetFrameLevel() + 5)
    f.powerText = phold:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.powerText, POWER_SIZE)
    f.powerText:SetPoint("CENTER", phold, "CENTER", 0, 0)
    f.pwText = { center = f.powerText }

    f:SetScript("OnEnter", function(self)
        if UnitExists(self.unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(self.unit)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    bars[i], byMember[member] = f, f
    return f
end

-- how wide WRAP_AT characters are in the font in use (measured, so any font choice works)
local function NameWidth(f)
    local before = f.name:GetText()
    f.name:SetText(string.rep("a", WRAP_AT))
    local w = f.name.GetUnboundedStringWidth and f.name:GetUnboundedStringWidth() or f.name:GetStringWidth()
    f.name:SetText(before or "")
    if type(w) ~= "number" or issecret(w) or w <= 0 then w = WRAP_AT * NAME_SIZE * 0.55 end
    return math.ceil(w) + 2
end

-- the frame is exactly as wide as the 15-character name plus the role icon at its right end
local function Arrange(f)
    local nameW = NameWidth(f)
    local w = 4 + nameW + 2 + 12 + 2
    if f.w == w then return end
    f.w = w
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", f.member, "TOPLEFT", LEFT_X, TOP_Y)
    f:SetSize(w, FRAME_H)

    f.role:ClearAllPoints()
    f.role:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -1)
    f.name:ClearAllPoints()
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -1)
    f.name:SetSize(nameW, NAME_H)

    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(1 + NAME_H + 1))
    f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -(1 + NAME_H + 1))
    f.health:SetHeight(HEALTH_H)
    f.power:ClearAllPoints()
    f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -1)
    f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -1)
    f.power:SetHeight(POWER_H)
end

---------------------------------------------------------------------------
-- On / off and size (never in combat)
---------------------------------------------------------------------------
local function Apply()
    if InCombatLockdown() then pending = true; return end
    pending = false
    local on = On()
    for i = 1, SLOTS do
        local member = Member(i)
        if member then
            local f = bars[i]
            if on and not f then f = Create(i, member) end
            if f then
                if on then Arrange(f); f:Show() else f:Hide() end
            end
            SetReplaced(member, on and f ~= nil)
        end
    end
end
ns.PartyBarsApply = Apply

-- for PartyTargets: our bar on a Blizzard member frame, if it is showing
function ns.PartyBarOf(member)
    local f = member and byMember[member]
    if f and On() and f:IsShown() then return f end
end

---------------------------------------------------------------------------
-- What they show (all the time, in combat too)
---------------------------------------------------------------------------
local function PowerColor(unit)
    local ok, pType, pToken = pcall(UnitPowerType, unit)
    if not ok then return 0.2, 0.4, 0.9 end
    local tbl = _G.PowerBarColor
    local c = tbl and ((not issecret(pToken) and pToken and tbl[pToken]) or (not issecret(pType) and pType and tbl[pType]))
    if c then return c.r, c.g, c.b end
    return 0.2, 0.4, 0.9
end

local function SetName(f, unit)
    local name = GetUnitName and GetUnitName(unit, true) or UnitName(unit)     -- "Name-Realm" for another realm
    if issecret(name) then f.name:SetText(name)
    elseif type(name) == "string" then f.name:SetText(name)
    else f.name:SetText("") end
end

local function SetRole(f, unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    local atlas = type(role) == "string" and not issecret(role) and ROLE_ATLAS[role]
    if atlas and f.roleAtlas ~= atlas then
        f.roleAtlas = atlas
        if not pcall(f.role.SetAtlas, f.role, atlas) then f.roleAtlas = false end
    end
    f.role:SetShown(atlas and f.roleAtlas == atlas or false)
end

local function Update(f)
    local u = f.unit
    if not UnitExists(u) then return end
    SetName(f, u)
    SetRole(f, u)

    local connected = UnitIsConnected(u)
    if connected == false then f.health:SetStatusBarColor(0.5, 0.5, 0.5)
    else f.health:SetStatusBarColor(ns.UnitColor(u)) end
    f.health:SetMinMaxValues(0, UnitHealthMax(u))
    f.health:SetValue(UnitHealth(u))
    ns.UpdateHealthText(u, f.hpText)

    local pType = UnitPowerType(u)
    local max = UnitPowerMax(u, pType)
    if not issecret(max) and max == 0 then
        f.power:SetValue(0); f.powerText:SetText("")
    else
        f.power:SetStatusBarColor(PowerColor(u))
        f.power:SetMinMaxValues(0, max)
        f.power:SetValue(UnitPower(u, pType))
        ns.UpdatePowerText(u, f.pwText)
    end
end

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event ~= "GROUP_ROSTER_UPDATE" or pending or not bars[1] then Apply() end
    acc = 1
end)
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    if not On() then return end
    for i = 1, SLOTS do
        local f = bars[i]
        if f and f:IsVisible() then
            SetReplaced(f.member, true)            -- Blizzard sets some of these back now and then
            local ok, err = pcall(Update, f)
            if not ok and not ns.partyBarsErrored then
                ns.partyBarsErrored = true
                ns.Print("party bars error (please report): " .. tostring(err))
            end
        end
    end
end)

ns.RegisterDebug(function()
    local made, shown = 0, 0
    for i = 1, SLOTS do
        if bars[i] then made = made + 1; if bars[i]:IsVisible() then shown = shown + 1 end end
    end
    local compact = _G.CompactPartyFrame
    ns.Print(string.format("party bars: on=%s width=%s | %d made, %d showing%s", tostring(On()), tostring(bars[1] and bars[1].w), made, shown,
        (compact and compact.IsShown and compact:IsShown()) and " | raid-style party frames are in use (these bars only go on the classic ones)" or ""))
end)

end)
