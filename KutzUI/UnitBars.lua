---------------------------------------------------------------------------
-- KutzUI / UnitBars         (part of module "frames")
--
-- Our own health and power bars for the PLAYER and TARGET frames, in place of Blizzard's:
--
--     (portrait)  [ Name, wrapping onto a second line if it is long      98% ]
--                 [                                                    1234  ]
--                 [ power bar ................................ 56 | 80%      ]
--
-- Why: Blizzard's frame art is one fixed-size picture, so its bar can't be made taller or wider,
-- and a long name is squeezed into a 12-pixel label and cut off. Ours is as wide and as tall as
-- you set (the same for both frames), the name sits INSIDE the health bar and wraps:
--   Target = the whole name       Player = your first name only
--
-- Blizzard's frames are not replaced and nothing of theirs is hooked or moved: the portrait, level,
-- PvP / leader / raid-target icons, buffs and class bars all stay. We only make the pieces we
-- replace (the frame picture, the name, the two bars) invisible - alpha only - and put our bars,
-- anchored to the portrait, where they were. Layout.lua asks BarsExtra() how far our bars stick out
-- past Blizzard's frame, so Player / Target / the cast bars keep their spacing.
--
-- Our bars are secure unit buttons (SecureUnitButtonTemplate, like the Target-of-target frame):
-- left click targets, right click opens the menu, and they show / hide with the unit by themselves,
-- also in combat. Switch: "KutzUI bars" on the Unit frames page (DB.ownBars, on by default).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("frames", function()

local issecret = issecretvalue or function() return false end

local FLAT       = "Interface\\Buttons\\WHITE8X8"
local POWER_H    = 10          -- the power bar's thickness
local GAP        = 2           -- between the health and the power bar
local NUMBERS_W  = 46          -- room for the health number / percent at the right end of the health bar
local NAME_SIZE, NUM_SIZE, POWER_SIZE = 12, 10, 10

local DEFAULT_W, DEFAULT_H = 240, 44       -- Blizzard's bar is 124 x 15-20
local BUFF_GAP   = 1                       -- space between the target's buff icons (Blizzard's is 3)
local BORDER_OUT = 4                       -- how far the border stands outside the bars
local MIN_W, MAX_W = 100, 400
local MIN_H, MAX_H = 20, 70

-- Where Blizzard's own pieces live (their layout differs a little between client versions, so each
-- entry is a path from _G; ones that don't exist are skipped). "replace" = what we make invisible.
local UNITS = {
    player = {
        label = "Player", frame = "PlayerFrame", side = "right", firstNameOnly = true,
        portrait = { "PlayerFrame", "PlayerFrameContainer", "PlayerPortrait" },
        fallbackCx = 52,           -- portrait's centre from the frame's left, at 100% (Blizzard's layout)
        replace = {
            { "PlayerFrame", "PlayerFrameContainer" },          -- all of Blizzard's frame art, portrait and combat glow
            { "PlayerFrame", "PlayerFrameContainer", "FrameTexture" },
            { "PlayerFrame", "PlayerFrameContainer", "VehicleFrameTexture" },
            { "PlayerFrame", "PlayerFrameContainer", "AlternatePowerFrameTexture" },
            { "PlayerFrame", "PlayerFrameContainer", "FrameFlash" },
            { "PlayerFrame", "PlayerFrameContainer", "PlayerPortrait" },
            { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "StatusTexture" },
            { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "HealthBarsContainer" },
            { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "ManaBarArea" },
            { "PlayerName" },
        },
    },
    target = {
        label = "Target", frame = "TargetFrame", side = "left", firstNameOnly = false,
        portrait = { "TargetFrame", "TargetFrameContainer", "Portrait" },
        fallbackCx = 180,          -- portrait's centre from the frame's left, at 100%
        replace = {
            { "TargetFrame", "TargetFrameContainer" },
            { "TargetFrame", "TargetFrameContainer", "FrameTexture" },
            { "TargetFrame", "TargetFrameContainer", "Flash" },
            { "TargetFrame", "TargetFrameContainer", "Portrait" },
            { "TargetFrame", "TargetFrameContainer", "BossPortraitFrameTexture" },
            { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "ReputationColor" },
            { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "Name" },
            { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer" },
            { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "ManaBar" },
        },
    },
}
local ORDER = { "player", "target" }

local PlaceBuffs, RestoreBuffs   -- defined further down
local bars = {}                -- unit -> our frame
local pending = false          -- a change waits for the end of combat

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function On() return not (KutzUIDB and KutzUIDB.ownBars == false) end
local function BarW() local v = KutzUIDB and KutzUIDB.barW or DEFAULT_W; return math.max(MIN_W, math.min(MAX_W, v)) end
local function BarH() local v = KutzUIDB and KutzUIDB.barH or DEFAULT_H; return math.max(MIN_H, math.min(MAX_H, v)) end
-- 3D model or flat picture, per frame: KutzUIDB.pic3d = { player = true, target = false }
-- (the old single switch, portrait3d, still counts for both until one is set)
local function Use3D(unit)
    local db = KutzUIDB
    if not db then return false end
    if db.pic3d then return db.pic3d[unit] == true end
    return db.portrait3d == true
end
local function TotalH() return BarH() + GAP + POWER_H + 2 end       -- the whole frame's height = the square portrait's side

local function Dig(root, ...)
    for i = 1, select("#", ...) do
        if type(root) ~= "table" then return nil end
        root = root[select(i, ...)]
    end
    return root
end

local function Find(path)
    local o = Dig(_G, unpack(path))
    if type(o) == "table" and o.SetAlpha and o.GetAlpha then return o end
end

---------------------------------------------------------------------------
-- How far our frames stick out past Blizzard's frame (screen pixels), for Layout.lua.
-- Our square portrait is centred on Blizzard's round one; the bars run on from it toward the middle of
-- the screen (Player: to the right, Target: to the left).
---------------------------------------------------------------------------
function ns.BarsExtra(unit)
    local cfg = UNITS[unit]
    if not (cfg and On() and bars[unit]) then return 0 end
    local frame = _G[cfg.frame]
    if not frame then return 0 end
    local s = frame:GetScale() or 1
    local width = frame:GetWidth() or 232
    local cx                                     -- the portrait's centre, from the frame's left, in the frame's own units
    local portrait = Find(cfg.portrait)
    local fl = frame:GetLeft()
    if portrait and fl then
        local pc = portrait:GetCenter()
        if pc then cx = pc - fl end
    end
    if not (cx and cx > 0 and cx < width) then cx = cfg.fallbackCx end      -- not laid out yet: Blizzard's own numbers
    local w, half = BarW(), TotalH() / 2
    if cfg.side == "right" then
        return math.max(0, cx * s + half + w - width * s)
    end
    return math.max(0, w + half - cx * s)
end

function ns.BarsActive() return On() and next(bars) ~= nil end

---------------------------------------------------------------------------
-- Making Blizzard's own pieces invisible (alpha only) / giving them back
---------------------------------------------------------------------------
local touched = {}             -- object -> true, the ones we made invisible

-- Blizzard's combat / status glow (the red flashing ring and line) has its alpha rewritten by the
-- game's own OnUpdate on EVERY frame, so checking it four times a second leaves it flickering. Those
-- pieces go on a list that is checked every frame (ours runs after Blizzard's, so ours has the last word).
local FAST = { StatusTexture = true, FrameFlash = true, Flash = true }
local fastList = {}

local function SetReplaced(cfg, hide)
    local gaveBack = false
    for _, path in ipairs(cfg.replace) do
        local o = Find(path)
        if o then
            if hide then
                if o:GetAlpha() ~= 0 then o:SetAlpha(0) end
                touched[o] = true
                if FAST[path[#path]] then fastList[o] = true end
            elseif touched[o] then
                o:SetAlpha(1)
                touched[o] = nil
                if fastList[o] then gaveBack = true end
                fastList[o] = nil
            end
        end
    end
    -- the flash pieces were also Hide()-n each frame: ask Blizzard to show whichever ones apply right now
    if gaveBack and cfg.frame == "PlayerFrame" and PlayerFrame_UpdateStatus and not InCombatLockdown() then
        pcall(PlayerFrame_UpdateStatus)
    end
end

-- The resting glow (yellow ring + line) and the combat glow (red) are one texture, StatusTexture, whose
-- alpha Blizzard's own OnUpdate rewrites every frame while it is shown. Setting its alpha to 0 is not
-- enough (which of the two scripts runs last is not ours to decide), so it is also hidden: Blizzard's
-- flash code only runs for a shown texture, and only shows it again on a status event.
local flasher = CreateFrame("Frame")
flasher:SetScript("OnUpdate", function()
    for o in pairs(fastList) do
        if o:GetAlpha() ~= 0 then o:SetAlpha(0) end
        if o:IsShown() then o:Hide() end
    end
end)

---------------------------------------------------------------------------
-- Our frame for one unit
---------------------------------------------------------------------------
local function Create(unit)
    local cfg = UNITS[unit]
    local f = CreateFrame("Button", "Kutz" .. cfg.label .. "Bars", UIParent, "SecureUnitButtonTemplate")
    f.unit, f.cfg = unit, cfg
    f:SetFrameStrata("BACKGROUND")        -- under everything of Blizzard's: its level badge and icons sit on our portrait's corner
    f:SetClampedToScreen(false)

    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")          -- left click: target it
    f:SetAttribute("*type2", "togglemenu")      -- right click: its menu
    f:RegisterForClicks("AnyUp")
    f:EnableMouse(true)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.75)

    -- a border in Blizzard's own style (its tooltip / dialog border, tinted gold like the unit frames')
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetPoint("TOPLEFT", f, "TOPLEFT", -BORDER_OUT, BORDER_OUT)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", BORDER_OUT, -BORDER_OUT)
    border:SetFrameLevel(f:GetFrameLevel() + 8)
    border:EnableMouse(false)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        border:SetBackdropBorderColor(0.95, 0.78, 0.30, 1)
    end
    f.border = border

    -- the square portrait: a flat picture (SetPortraitTexture) or a 3D model, one at a time
    local box = CreateFrame("Frame", nil, f)
    box:SetFrameLevel(f:GetFrameLevel() + 1)
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    box.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
    box.pic = box:CreateTexture(nil, "ARTWORK")
    box.pic:SetAllPoints()
    -- the game's 2D portrait is a round picture with black outside the circle, which showed in the bottom
    -- right corner: a little zoom, and the picture shifted down and to the right (the window into the
    -- texture starts nearer its top-left), so that corner is cut off without cropping the face much
    box.pic:SetTexCoord(0.05, 0.87, 0.05, 0.87)
    box.model = CreateFrame("PlayerModel", nil, box)
    box.model:SetAllPoints()
    box.model:Hide()
    f.box = box
    f.divider = f:CreateTexture(nil, "OVERLAY")                  -- the line between portrait and bars
    f.divider:SetColorTexture(0.95, 0.78, 0.30, 1)
    f.divider:SetWidth(1)
    f.dirty = true
    f:SetScript("OnShow", function(self) self.dirty = true end)

    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetStatusBarTexture(FLAT)
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(1)

    f.power = CreateFrame("StatusBar", nil, f)
    f.power:SetStatusBarTexture(FLAT)
    f.power:SetMinMaxValues(0, 1)
    f.power:SetValue(0)
    f.power.bg = f.power:CreateTexture(nil, "BACKGROUND")
    f.power.bg:SetAllPoints()
    f.power.bg:SetColorTexture(0, 0, 0, 0.5)

    -- the text sits in frames of its own, above the bars
    local hold = CreateFrame("Frame", nil, f.health)
    hold:SetAllPoints()
    hold:SetFrameLevel(f.health:GetFrameLevel() + 5)
    f.name = hold:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.name, NAME_SIZE)
    f.name:SetJustifyH("LEFT")
    f.name:SetJustifyV("MIDDLE")
    f.name:SetWordWrap(true)
    f.numbers = hold:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.numbers, NUM_SIZE)
    f.numbers:SetJustifyH("RIGHT")
    f.numbers:SetJustifyV("MIDDLE")

    local phold = CreateFrame("Frame", nil, f.power)
    phold:SetAllPoints()
    phold:SetFrameLevel(f.power:GetFrameLevel() + 5)
    f.powerText = phold:CreateFontString(nil, "OVERLAY")
    ns.StyleText(f.powerText, POWER_SIZE)
    f.powerText:SetJustifyH("CENTER")
    f.powerText:SetPoint("CENTER", phold, "CENTER", 0, 0)

    f:SetScript("OnEnter", function(self)
        if UnitExists(self.unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(self.unit)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    bars[unit] = f
    return f
end

-- Where the bars go. oUF-style: our own frame hangs off UIParent at absolute coordinates, never off a
-- Blizzard piece (the client refuses some anchors to Blizzard's protected frames, and its refusal is what
-- left the player bar missing). The spot is measured from Blizzard's portrait on screen; if that can't be
-- read (not laid out yet, or hidden values) it is worked out from Blizzard's frame and its usual layout.
local function Num(v) return type(v) == "number" and not issecret(v) and v or nil end

local function Measure(cfg)
    local ui = Num(UIParent:GetEffectiveScale()) or 1
    local portrait = Find(cfg.portrait)
    if portrait then
        local k = (Num(portrait:GetEffectiveScale()) or ui) / ui
        local cx, cy = portrait:GetCenter()
        cx, cy = Num(cx), Num(cy)
        if cx and cy and cx > 0 and cy > 0 then return cx * k, cy * k, "portrait" end
    end
    local frame = _G[cfg.frame]
    if frame then
        local k = (Num(frame:GetEffectiveScale()) or ui) / ui
        local fl, ft = Num(frame:GetLeft()), Num(frame:GetTop())
        if fl and ft and fl >= 0 and ft > 0 then
            return (fl + cfg.fallbackCx) * k, (ft - 51) * k, "frame"
        end
    end
end

function ns.BarsPlace(f)
    local x, y, how = Measure(f.cfg)
    if not x then return false end
    local half = TotalH() / 2
    local key = string.format("%.1f:%.1f:%d", x, y, half)
    if f.placeKey == key then return true end
    local ok = pcall(function()
        f:ClearAllPoints()
        if f.cfg.side == "right" then
            f:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x - half, y)         -- our portrait centred where Blizzard's is
        else
            f:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", x + half, y)
        end
    end)
    if ok then f.placeKey, f.placedBy, f.placeX, f.placeY = key, how, x, y end
    return ok
end

-- size and inner arrangement (protected frame: out of combat only)
local function Arrange(f)
    local w, h = BarW(), BarH()
    local size = NAME_SIZE + ((ns.NameBonus and ns.NameBonus()) or 0)
    if f.nameSize ~= size then
        f.nameSize = size
        ns.StyleText(f.name, size)
    end
    local H = h + GAP + POWER_H + 2
    local right = f.cfg.side == "right"
    local near, far = right and "LEFT" or "RIGHT", right and "RIGHT" or "LEFT"
    local lx, rx = right and (H + 1) or 1, right and 1 or (H + 1)          -- the bars' insets: the portrait takes H at its end
    f:SetSize(w + H, H)

    f.box:ClearAllPoints()
    f.box:SetSize(H - 2, H - 2)
    -- the 2D picture sits 3 pixels lower than the window set in Create (whatever the portrait's size)
    local span = 0.82
    local top = math.max(0, 0.05 - 3 / (H - 2) * span)
    f.box.pic:SetTexCoord(0.05, 0.05 + span, top, top + span)
    f.box:SetPoint("TOP" .. near, f, "TOP" .. near, right and 1 or -1, -1)
    f.divider:ClearAllPoints()
    f.divider:SetPoint("TOP" .. near, f, "TOP" .. near, right and H or -H, -1)
    f.divider:SetPoint("BOTTOM" .. near, f, "BOTTOM" .. near, right and H or -H, 1)
    local want3d = Use3D(f.unit)
    f.box.pic:SetShown(not want3d)
    f.box.model:SetShown(want3d)
    f.dirty = true

    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -1)
    f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", -rx, -1)
    f.health:SetHeight(h)

    f.power:ClearAllPoints()
    f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -GAP)
    f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -GAP)
    f.power:SetHeight(POWER_H)

    -- the name takes everything the numbers don't, and wraps: as many lines as fit the bar
    f.numbers:ClearAllPoints()
    f.numbers:SetPoint("RIGHT", f.health, "RIGHT", -4, 0)
    f.numbers:SetWidth(NUMBERS_W)
    f.name:ClearAllPoints()
    f.name:SetPoint("LEFT", f.health, "LEFT", 4, 0)
    f.name:SetWidth(math.max(20, w - 2 - 8 - NUMBERS_W - 2))
    f.name:SetHeight(h - 2)
    f.name:SetMaxLines(math.max(1, math.floor((h - 4) / (size + 2))))

    f.placeKey = nil
    ns.BarsPlace(f)
end

---------------------------------------------------------------------------
-- Turning the bars on / off and re-arranging them (never in combat)
---------------------------------------------------------------------------
local function Apply()
    if InCombatLockdown() then pending = true; return end
    pending = false
    local on = On()
    for _, unit in ipairs(ORDER) do
        local cfg = UNITS[unit]
        local f = bars[unit]
        if on and not f and Find(cfg.portrait) then f = Create(unit) end
        if f then
            if on then
                Arrange(f)
                if not f.watching then RegisterUnitWatch(f); f.watching = true end
            else
                if f.watching then UnregisterUnitWatch(f); f.watching = false end
                f:Hide()
                RestoreBuffs()
            end
        end
        SetReplaced(cfg, on and f ~= nil)
    end
end
ns.BarsApply = Apply

---------------------------------------------------------------------------
-- Updating what they show
---------------------------------------------------------------------------
local function PowerColor(unit)
    local ok, pType, pToken = pcall(UnitPowerType, unit)
    if not ok then return 0.2, 0.4, 0.9 end
    local tbl = _G.PowerBarColor
    local c = tbl and ((not issecret(pToken) and pToken and tbl[pToken]) or (not issecret(pType) and pType and tbl[pType]))
    if c then return c.r, c.g, c.b end
    return 0.2, 0.4, 0.9
end

local function RefreshPortrait(f)
    local u = f.unit
    if not UnitExists(u) then return end
    f.dirty = false
    if Use3D(u) then
        pcall(function()
            f.box.model:SetUnit(u)
            f.box.model:SetPortraitZoom(1)
        end)
    else
        pcall(SetPortraitTexture, f.box.pic, u)
    end
end

local function Update(f)
    local u = f.unit
    if not UnitExists(u) then return end
    if f.dirty then RefreshPortrait(f) end

    f.health:SetStatusBarColor(ns.UnitColor(u))
    f.health:SetMinMaxValues(0, UnitHealthMax(u))
    f.health:SetValue(UnitHealth(u))
    ns.UpdateHealthStack(u, f.numbers)

    local name = UnitName(u)
    if f.cfg.firstNameOnly and type(name) == "string" and not issecret(name) then
        name = name:match("%S+") or name
    end
    f.name:SetText(name or "")             -- the target's name is handed straight over: it may be hidden

    local pType = UnitPowerType(u)
    local max = UnitPowerMax(u, pType)
    if not issecret(max) and max == 0 then
        f.power:SetAlpha(0); f.powerText:SetText("")      -- nothing to show (a creature without power)
    else
        f.power:SetAlpha(1)
        f.power:SetStatusBarColor(PowerColor(u))
        f.power:SetMinMaxValues(0, max)
        f.power:SetValue(UnitPower(u, pType))
        ns.UpdatePowerText(u, { center = f.powerText })
    end
end

---------------------------------------------------------------------------
-- The target's buffs / debuffs: Blizzard's aura container (the game itself lays the icons out), moved
-- under our target frame: top right corner, growing to the left. Only its public calls are used
-- (SetPoint, SetFlowLayoutAnchorPoint / GrowthDirection); each one is guarded, and the reason for a
-- refusal is kept for /kutz debug. Blizzard puts it back under ITS frame now and then: we re-place it.
---------------------------------------------------------------------------
local buffs = { moved = false, err = nil }

local function AuraContainer()
    local c = Dig(_G, "TargetFrame", "TargetFrameContent", "TargetFrameContentContextual", "Auras")
    if type(c) == "table" and c.SetPoint then return c end
end

function PlaceBuffs()
    local f, c = bars.target, AuraContainer()
    if not (f and c and On()) then return end
    local ok, err = pcall(function()
        if not buffs.set then
            local dir = _G.AnchorUtil and _G.AnchorUtil.FlowDirection
            if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("TOPRIGHT") end
            if c.SetFlowLayoutGrowthDirection and dir then c:SetFlowLayoutGrowthDirection(dir.Left, dir.Down) end
            buffs.set = true
        end
        if c.SetFlowLayoutSpacing then c:SetFlowLayoutSpacing(BUFF_GAP, BUFF_GAP) end     -- Blizzard's own gap is 3
        local _, rel = c:GetPoint(1)
        if rel ~= f then
            c:ClearAllPoints()
            c:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -(BORDER_OUT + 2))
        end
        buffs.moved = true
    end)
    buffs.err = (not ok) and tostring(err) or nil
end

function RestoreBuffs()
    local c = AuraContainer()
    if not (c and buffs.set) then return end
    buffs.set, buffs.moved = false, false
    pcall(function()
        local dir = _G.AnchorUtil and _G.AnchorUtil.FlowDirection
        if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("TOPLEFT") end
        if c.SetFlowLayoutGrowthDirection and dir then c:SetFlowLayoutGrowthDirection(dir.Right, dir.Down) end
        if c.SetFlowLayoutSpacing then c:SetFlowLayoutSpacing(3, 3) end
        -- Blizzard puts it back under its own frame the next time it lays the auras out (or after /reload)
    end)
end

---------------------------------------------------------------------------
-- The target's debuffs: a second, small aura container of our own (Blizzard's "custom aura container",
-- which addons may create) above the frame, growing left to right. Blizzard's container only splits
-- buffs and debuffs into rows, not into two places, so its own debuff group is switched off while ours
-- works (a filter that matches nothing: harmful AND cancelable) and switched back when ours is off.
---------------------------------------------------------------------------
local DEBUFF_SIZE = 22
local debuffs = { c = nil, err = nil, failed = false, hid = false, shown = nil, key = nil, lineW = nil }

local function DebuffsWanted() return On() and not (KutzUIDB and KutzUIDB.debuffsTop == false) end

local function InitDebuffButton(b)
    b:SetSize(DEBUFF_SIZE, DEBUFF_SIZE)
    local edge = b:CreateTexture(nil, "BACKGROUND")                  -- the red frame around each debuff
    edge:SetAllPoints()
    edge:SetColorTexture(0.75, 0.12, 0.12, 1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetIcon(icon)
    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    cd:SetDrawEdge(false)
    b:SetDurationCooldown(cd)
    local over = CreateFrame("Frame", nil, b)                        -- above the cooldown sweep
    over:SetAllPoints()
    over:SetFrameLevel(cd:GetFrameLevel() + 2)
    local count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetApplicationCount(count, {})
end

-- Blizzard shows other players' debuffs on a hostile creature only if they matter; we keep it simple:
-- on a creature, only yours; on a player or a friend, all of them.
local function DebuffFilters()
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsPlayer("target") then
        return { isFromPlayerOrPlayerPet = true }
    end
    return {}
end

local function RestoreDebuffs()
    local bc = AuraContainer()
    if debuffs.c and debuffs.shown ~= false then
        pcall(function() debuffs.c:SetEnabled(false); debuffs.c:Hide() end)
        debuffs.shown = false
    end
    if bc and debuffs.hid then
        debuffs.hid = false
        local d = _G.TargetFrameAuraContainerDefaults
        pcall(function() bc:SetDebuffFilterString(d and d.DebuffFilterString or "HARMFUL|INCLUDE_NAME_PLATE_ONLY") end)
    end
end

local function PlaceDebuffs()
    local f, bc = bars.target, AuraContainer()
    if not (f and bc and DebuffsWanted()) then RestoreDebuffs(); return end
    if debuffs.failed then return end
    local ok, err = pcall(function()
        if not debuffs.c then
            local c = CreateFrame("AuraContainer", "KutzTargetDebuffs", UIParent, "CustomAuraContainerTemplate")
            local dir = _G.AnchorUtil and _G.AnchorUtil.FlowDirection
            c:SetUnit("target")
            c:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
            if dir then c:SetFlowLayoutGrowthDirection(dir.Right, dir.Up) end
            c:AddAuraGroup("debuffs", "HARMFUL|INCLUDE_NAME_PLATE_ONLY", {
                maxFrameCount = 16,
                initializeFrame = InitDebuffButton,
                layout = { elementSpacing = BUFF_GAP, lineSpacing = BUFF_GAP },
            })
            c:SetEnabled(true)
            debuffs.c, debuffs.shown = c, true
        end
        local c = debuffs.c
        if debuffs.shown ~= true then c:Show(); c:SetEnabled(true); debuffs.shown = true end
        local _, rel = c:GetPoint(1)
        if rel ~= f then
            c:ClearAllPoints()
            c:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, BORDER_OUT + 2)
        end
        local w = math.floor((f:GetWidth() or 0) / (DEBUFF_SIZE + BUFF_GAP)) * (DEBUFF_SIZE + BUFF_GAP)
        if w >= DEBUFF_SIZE and debuffs.lineW ~= w then
            debuffs.lineW = w
            c:SetFlowLayoutMaximumLineSize(w)
        end
        local key = tostring(UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsPlayer("target"))
        if debuffs.key ~= key then
            debuffs.key = key
            c:SetAuraGroupCandidateFilters("debuffs", DebuffFilters())
        end
        if not debuffs.hid then                      -- ours works: now Blizzard's own debuff group can go
            bc:SetDebuffFilterString("HARMFUL|CANCELABLE")
            debuffs.hid = true
        end
    end)
    if not ok then
        debuffs.failed, debuffs.err = true, tostring(err)     -- one try; /kutz debug says why
        RestoreDebuffs()
    end
end

local acc, hideAcc = 0, 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    acc, hideAcc = acc + elapsed, hideAcc + elapsed

    -- Blizzard re-shows / re-fades its pieces now and then: keep them invisible (alpha is allowed in combat)
    if hideAcc >= 0.25 then
        hideAcc = 0
        local on = On()
        for _, unit in ipairs(ORDER) do
            if on and bars[unit] then SetReplaced(UNITS[unit], true) end
        end
        if on then PlaceBuffs() else RestoreBuffs() end
        PlaceDebuffs()                                       -- (puts Blizzard's debuffs back when off)
        if not InCombatLockdown() and on then
            for _, unit in ipairs(ORDER) do                     -- follow Blizzard's frame if Layout moved it
                if bars[unit] then ns.BarsPlace(bars[unit]) end
            end
        end
        if not InCombatLockdown() then
            -- first frame creation can wait for Blizzard's frames to exist; a change made in combat waits too
            local need = pending
            if on then
                for _, unit in ipairs(ORDER) do
                    local b = bars[unit]
                    if not b and Find(UNITS[unit].portrait) then need = true end
                    if b and not b.placeKey then need = true end                  -- not placed yet: try again
                end
            end
            if need then pcall(Apply) end
        end
    end

    if acc < 0.1 then return end
    acc = 0
    for _, unit in ipairs(ORDER) do
        local f = bars[unit]
        if f and f:IsVisible() then
            local ok, err = pcall(Update, f)
            if not ok and not f.errored then
                f.errored = true
                ns.Print(unit .. " bars error (please report): " .. tostring(err))
            end
        end
    end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UNIT_PORTRAIT_UPDATE")
ev:RegisterEvent("UNIT_MODEL_CHANGED")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then pcall(Apply) end
    elseif event == "PLAYER_TARGET_CHANGED" and debuffs.c then
        debuffs.key = nil                                          -- friend / creature may have changed: filters re-chosen
        for _, u in ipairs(ORDER) do if bars[u] then bars[u].dirty = true end end
        pcall(function() debuffs.c:UpdateAllAuras() end)
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        for _, u in ipairs(ORDER) do if bars[u] and unit == u then bars[u].dirty = true end end
    else                                                           -- target changed / entered the world
        for _, u in ipairs(ORDER) do if bars[u] then bars[u].dirty = true end end
    end
end)

ns.UB = { MIN_W = MIN_W, MAX_W = MAX_W, MIN_H = MIN_H, MAX_H = MAX_H, DEFAULT_W = DEFAULT_W, DEFAULT_H = DEFAULT_H,
          Width = BarW, Height = BarH, On = On, Portrait3D = Use3D,
          Tick = function() for _, unit in ipairs(ORDER) do if bars[unit] then Update(bars[unit]) end end end }

-- Which of Blizzard's pieces are still visible and look like a combat glow (reddish, or named flash / glow / status)?
local function GlowSuspects(root, out, depth)
    if depth > 7 or #out >= 12 then return end
    for _, r in ipairs({ root:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r:IsShown() and (r:GetEffectiveAlpha() or 0) > 0.02 then
            local name = (r.GetDebugName and r:GetDebugName()) or tostring(r:GetName() or "?")
            local atlas = r.GetAtlas and r:GetAtlas() or ""
            local red, g, b = r:GetVertexColor()
            local reddish = type(red) == "number" and not issecret(red) and red > 0.6 and g < 0.5 and b < 0.5
            local named = (name .. " " .. tostring(atlas)):lower():find("flash") or (name .. " " .. tostring(atlas)):lower():find("glow")
                or (name .. " " .. tostring(atlas)):lower():find("status") or (name .. " " .. tostring(atlas)):lower():find("combat")
            if (reddish or named) and #out < 12 then out[#out + 1] = name .. (atlas ~= "" and ("  [" .. tostring(atlas) .. "]") or "") end
        end
    end
    for _, c in ipairs({ root:GetChildren() }) do
        if c ~= bars.player and c ~= bars.target then GlowSuspects(c, out, depth + 1) end
    end
end

ns.RegisterDebug(function()
    for _, unit in ipairs(ORDER) do
        local cfg, out = UNITS[unit], {}
        local frame = _G[cfg.frame]
        if frame then pcall(GlowSuspects, frame, out, 0) end
        ns.Print(unit .. " frame, pieces still visible that look like a combat glow: " .. (#out > 0 and table.concat(out, " | ") or "none"))
    end
    ns.Print(string.format("target buffs: container %s, moved under our frame=%s%s",
        AuraContainer() and "found" or "NOT FOUND", tostring(buffs.moved), buffs.err and ("  refused: " .. buffs.err) or ""))
    ns.Print(string.format("target debuffs (own row above the frame): wanted=%s  container=%s  Blizzard's own debuffs off=%s%s",
        tostring(DebuffsWanted()), debuffs.c and "made" or "not made", tostring(debuffs.hid),
        debuffs.err and ("  FAILED: " .. debuffs.err) or ""))
    for _, unit in ipairs(ORDER) do
        local f = bars[unit]
        local how = f and f.placedBy
        ns.Print(string.format("%-6s bars: %s  on=%s  %dx%d  sticks out %.0f px  Blizzard portrait %s  placed by %s at %s,%s",
            unit, f and f:GetName() or "not made", tostring(On()), BarW(), BarH(), ns.BarsExtra(unit),
            Find(UNITS[unit].portrait) and "found" or "NOT FOUND",
            how or "NOTHING", f and f.placeX and string.format("%.0f", f.placeX) or "-", f and f.placeY and string.format("%.0f", f.placeY) or "-"))
    end
end)

end)
