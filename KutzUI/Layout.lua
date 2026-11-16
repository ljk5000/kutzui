---------------------------------------------------------------------------
-- KutzUI / Layout
--
--   [ Player ]                                   [ Target ] name  45%
--   (centre of                                   (centre of  ^ ToT
--    left half)       [icon Spell name  1.5 ]     right half)
--                     [icon Spell name  1.5 ]   <- cast bars: their own height
--
-- * Player and Target are Blizzard's own frames, moved so they mirror each
--   other on the two halves of the screen. Each has its own size slider.
-- * Target-of-Target is drawn by us (Blizzard hides its own ToT when you
--   target yourself): just a health bar - no background, no power bar - with
--   the name on the left and health % on the right. It shows whenever the
--   target has a target, including when that target is you.
-- * Two cast bars (player on top, target below). Each shows the spell ICON,
--   the spell NAME and the time. Their height, width and textures are separate
--   from the frames'.
-- * "/kutz" opens the menu.
--
-- Blizzard's player/target frames are protected: they can't be moved or
-- resized during combat, so a change made in combat is applied the moment
-- combat ends.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module({ "frames", "castbars" }, function()

local DEFAULT_Y    = -200     -- frames' height: pixels above (+) / below (-) screen centre
local TOT_W, TOT_H = 150, 20
local CAST_HEIGHT  = 24
local CAST_SPACING = 4        -- vertical gap between the two cast bars
local CAST_MIN_W, CAST_MAX_W = 60, 800
local CAST_MIN_H, CAST_MAX_H = 14, 60
local SCALE_MIN, SCALE_MAX   = 50, 200      -- frame size, percent

local CAST_COLORS = {
    player = { 1.00, 0.75, 0.10 },
    target = { 0.90, 0.25, 0.25 },
}
local PREVIEW_SPELL = { player = "Fireball", target = "Greater Heal" }   -- shown while the menu is open

local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local QUESTION    = "Interface\\Icons\\INV_Misc_QuestionMark"

local issecret = issecretvalue or function() return false end
local Present  = ns.Present

local DB
local tot
local castBars = {}               -- unit -> cast bar
local pendingLayout = false
local scheduled = false

-- Blizzard frames we replace (its ToT and cast bars). We never reparent or hook
-- them - both run our code inside Blizzard's own calls and taint them. Their
-- events are unregistered and the watchdog below hides them whenever Blizzard
-- shows one again (it re-drives them on target changes). They are protected, so
-- this only happens out of combat; in a fight one can briefly show alongside ours.
local suppressed = {}

local function Suppress(frame)
    if not frame or suppressed[frame] then return end
    suppressed[frame] = true
    frame:UnregisterAllEvents()
    if not InCombatLockdown() then frame:Hide() end
end

local function MakeText(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns.StyleText(fs, size)       -- uses the font chosen in the menu
    fs:SetJustifyH(justify)
    return fs
end

---------------------------------------------------------------------------
-- Target-of-Target frame (ours): health bar only, no background
---------------------------------------------------------------------------
-- the bar's colour: by default the unit's own colour (class colour for players, the green / yellow /
-- red of friendly / neutral / hostile for creatures); or one fixed colour picked in the menu
local TOT_COLOR_DEFAULT = "4fa35a"
local function ToTColorHex() return (DB and DB.totColor) or TOT_COLOR_DEFAULT end
local function ToTColor(u)
    if DB and DB.totColorMode == "custom" then
        local h = ToTColorHex()
        return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
    end
    return ns.UnitColor(u)
end

local function UpdateToT(f)
    local u = f.unit
    if not UnitExists(u) then return end

    f.health:SetStatusBarColor(ToTColor(u))
    f.health:SetMinMaxValues(0, UnitHealthMax(u))
    f.health:SetValue(UnitHealth(u))

    f.text.left:SetText(ns.FormatName(UnitName(u) or ""))     -- name, left
    ns.UpdateHealthPercent(u, f.text.right)                    -- health %, right
end

local function CreateToT()
    local f = CreateFrame("Button", "KutzToTFrame", UIParent, "SecureUnitButtonTemplate")
    f.unit = "targettarget"
    f:SetSize(TOT_W, TOT_H)
    f:SetClampedToScreen(true)

    f:SetAttribute("unit", f.unit)
    f:SetAttribute("*type1", "target")       -- left click: target it
    f:SetAttribute("*type2", "togglemenu")   -- right click: its menu
    f:RegisterForClicks("AnyUp")
    f:EnableMouse(true)

    -- no background texture on purpose: only the filled part of the bar shows
    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetStatusBarTexture(BAR_TEXTURE)
    f.health:SetAllPoints()

    f.text = ns.MakeOverlay(f.health, 12)
    f.text.left:SetWidth(TOT_W - 54)    -- leave room for the percent on the right
    f.text.left:SetWordWrap(false)

    f:SetScript("OnEnter", function(self)
        if UnitExists(self.unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(self.unit)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ToT doesn't reliably fire unit events, so poll it
    local acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        if acc >= 0.1 then
            acc = 0
            local ok, err = pcall(UpdateToT, self)
            if not ok and not self.errored then
                self.errored = true
                ns.Print("ToT frame error (please report): " .. tostring(err))
            end
        end
    end)
    f:SetScript("OnShow", UpdateToT)

    RegisterUnitWatch(f)   -- shown exactly when "targettarget" exists
    return f
end

---------------------------------------------------------------------------
-- Cast bars:  [icon] [ Spell name ....... 1.5 ....... ]
---------------------------------------------------------------------------
-- What the time on a cast bar says: the time left ("1.2", the default), the time left and the whole
-- cast ("1.2 / 2.5"), or nothing. (DB.castTimeMode: nil / "total" / "off")
local function TimeMode() return DB and DB.castTimeMode end

-- Where the time sits: "left" (default: outside the bar, to the left of it, so the spell name gets the
-- whole bar and is never cut short), "middle" (centred in the bar) or "right" (right end, inside).
-- DB.castTimeRight is the old "always on the right" switch; it still counts.
local function TimePos()
    local p = DB and DB.castTimePos
    if p == "middle" or p == "right" then return p end
    if DB and DB.castTimeRight then return "right" end
    return "left"
end

local function CastOnUpdate(self)
    local mode = TimeMode()
    if self.mode == "manual" then
        local now = GetTime()
        if now >= self.endS then self:Hide(); return end
        self.bar:SetValue(self.channel and (self.endS - now) or (now - self.startS))
        if mode == "off" then
            self.time:SetText("")
        elseif mode == "total" then
            self.time:SetFormattedText("%.1f / %.1f", self.endS - now, self.endS - self.startS)
        else
            self.time:SetFormattedText("%.1f", self.endS - now)
        end
    elseif self.mode == "timer" then
        -- Secret cast times: the StatusBar animates itself (SetTimerDuration);
        -- we only refresh the number.
        if mode == "off" then
            self.time:SetText("")
        elseif not pcall(function()
            if mode == "total" then
                self.time:SetFormattedText("%.1f / %.1f", self.duration:GetRemainingDuration(), self.duration:GetTotalDuration())
            else
                self.time:SetFormattedText("%.1f", self.duration:GetRemainingDuration())
            end
        end) then
            self.time:SetText("")
        end
    end
end

local function CastH() return (DB and DB.castHeight) or CAST_HEIGHT end

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- The colour of one cast bar: the unit's class colour if you asked for that (and it is a player),
-- else the colour you picked, else the built-in one.
local function CastRGB(unit)
    local isPlayerBar = (unit == "player")
    if DB then
        if DB[isPlayerBar and "castClassPlayer" or "castClassTarget"] then
            local ok, r, g, b = pcall(function()
                if UnitExists(unit) and UnitIsPlayer(unit) then
                    local _, class = UnitClass(unit)
                    local c = class and not issecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                    if c then return c.r, c.g, c.b end
                end
            end)
            if ok and r then return r, g, b end
        end
        local hex = DB[isPlayerBar and "castColorPlayer" or "castColorTarget"]
        if hex then return HexToRGB(hex) end
    end
    local d = CAST_COLORS[unit]
    return d[1], d[2], d[3]
end

-- Rounded corners: one mask over the whole bar (background, fill and icon follow it). The masks
-- are pictures of a rounded rectangle, so the one whose width/height ratio is closest to the
-- bar's is used; the corner radius is then close to what its name says whatever size you pick.
local MASK_DIR = "Interface\\AddOns\\KutzUI\\Media\\Textures\\"
local MASK_ASPECTS = { 4, 8, 16, 32 }

local function MaskPath(shape, w, h)
    local ratio = w / math.max(h, 1)
    local best, bestDiff = 8, math.huge
    for _, a in ipairs(MASK_ASPECTS) do
        local diff = math.abs(math.log(ratio / a))
        if diff < bestDiff then best, bestDiff = a, diff end
    end
    return MASK_DIR .. "kutz_mask_" .. shape .. "_" .. best .. ".tga"
end

local function ApplyShape(b)
    local shape = (DB and DB.castShape) or "square"
    if shape ~= "round" and shape ~= "pill" then
        if b.maskOn then
            b.bg:RemoveMaskTexture(b.mask)
            b.icon:RemoveMaskTexture(b.mask)
            if b.maskedFill then b.maskedFill:RemoveMaskTexture(b.mask) end
            b.maskOn, b.maskedFill = false, false
            if b.safeMasked then b.safe:RemoveMaskTexture(b.mask); b.safeMasked = false end
        end
        return
    end
    if not b.mask then
        b.mask = b:CreateMaskTexture()
        b.mask:SetAllPoints(b)
    end
    local path = MaskPath(shape, b:GetWidth(), b:GetHeight())
    if b.maskPath ~= path then
        b.maskPath = path
        b.mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    if not b.maskOn then
        b.bg:AddMaskTexture(b.mask)
        b.icon:AddMaskTexture(b.mask)
        b.maskOn = true
    end
    local fill = b.bar:GetStatusBarTexture()
    if fill and b.maskedFill ~= fill then          -- the bar's fill texture is its own object
        if b.maskedFill then b.maskedFill:RemoveMaskTexture(b.mask) end
        fill:AddMaskTexture(b.mask)
        b.maskedFill = fill
    end
    if b.safe and not b.safeMasked then
        b.safe:AddMaskTexture(b.mask)
        b.safeMasked = true
    end
end

-- The countdown: yellow, and as bold as this game's fonts get (they have no bold variant, so a thick outline)
local TIME_COLOR = { 1.00, 0.82, 0.00 }
local TIME_FLAGS = "THICKOUTLINE"

local function CreateCastBar(unit, label)
    local b = CreateFrame("Frame", "Kutz" .. label .. "CastBar", UIParent)
    b.unit, b.label = unit, label
    b:SetSize(232, CAST_HEIGHT)   -- real width is set in ApplyLayout
    b:SetFrameStrata("MEDIUM")

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0, 0, 0, 0.7)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(CAST_HEIGHT - 2, CAST_HEIGHT - 2)
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)       -- trim the icon's own border

    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetStatusBarTexture(ns.CastTexturePath(unit))
    b.bar:SetStatusBarColor(CastRGB(unit))
    b.bar:SetMinMaxValues(0, 1)
    b.bar:SetValue(0)

    local overlay = CreateFrame("Frame", nil, b)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(b.bar:GetFrameLevel() + 5)

    -- the latency "safe zone" (your own bar) and the "can't be interrupted" badge (the target's bar)
    b.safe = b.bar:CreateTexture(nil, "OVERLAY")
    b.safe:SetColorTexture(0.95, 0.15, 0.15, 0.6)
    b.safe:Hide()
    b.shield = overlay:CreateTexture(nil, "OVERLAY")
    if not pcall(b.shield.SetAtlas, b.shield, "ui-castingbar-shield") then
        b.shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Arena-Shield")
    end
    b.shield:Hide()

    b.spell = MakeText(overlay, 12, "LEFT")
    b.spell:SetWordWrap(false)
    b.time = MakeText(overlay, 12, "CENTER")
    b.time:SetTextColor(TIME_COLOR[1], TIME_COLOR[2], TIME_COLOR[3])
    ns.StyleText(b.time, 12, TIME_FLAGS)
    b.fontSize, b.maskOn, b.reverse = 12, false, false
    b.mask, b.maskedFill, b.maskPath = false, false, false      -- made when a rounded shape is first wanted

    b:SetScript("OnUpdate", CastOnUpdate)
    b:Hide()
    castBars[unit] = b
    return b
end

-- Fit icon, bar, spell name and time inside the bar's current width.
-- The spell name gets every pixel the time doesn't need, so it can show what is
-- being cast; with the time in the middle the name has the left half.
local function LayoutCast(b)
    local h = CastH()
    if math.abs(b:GetHeight() - h) > 0.01 then b:SetHeight(h) end
    b.icon:SetSize(h - 2, h - 2)
    local fontSize = math.max(9, math.floor(h * 0.5 + 0.5))            -- 24 high -> 12 point, as before
    if b.fontSize ~= fontSize then
        b.fontSize = fontSize
        ns.StyleText(b.spell, fontSize)
        ns.StyleText(b.time, fontSize, TIME_FLAGS)
    end
    local reverse = (DB and DB.castReverse) and true or false
    if b.reverse ~= reverse then
        b.reverse = reverse
        b.bar:SetReverseFill(reverse)                                   -- fill from the right instead of the left
    end
    ApplyShape(b)

    local showIcon  = not (DB and DB.castIcon == false)
    -- "middle" moves its time to the right for a cast whose name is too long to fit beside it (see FitCastName)
    local pos = TimePos()
    local timeRight = (pos == "right") or (pos == "middle" and b.autoRight)

    b.icon:SetShown(showIcon)
    b.bar:ClearAllPoints()
    if showIcon then
        b.bar:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 1, 0)
    else
        b.bar:SetPoint("TOPLEFT", 1, -1)
    end
    b.bar:SetPoint("BOTTOMRIGHT", -1, 1)

    local barW = b:GetWidth() - 2 - (showIcon and (h - 1) or 0)

    b.spell:ClearAllPoints()
    b.spell:SetPoint("LEFT", b.bar, "LEFT", 5, 0)
    b.time:ClearAllPoints()
    local nameW
    local timeW = (TimeMode() == "total") and 70 or 36            -- "1.2 / 2.5" needs more room than "1.2"
    if pos == "left" then
        -- outside the bar, left of the icon (and of the shield badge when there is no icon)
        b.time:SetPoint("RIGHT", b, "LEFT", showIcon and -4 or -18, 0)
        b.time:SetJustifyH("RIGHT")
        nameW = 0                                                   -- no width limit: the whole name, no "..."
    elseif timeRight then
        b.time:SetPoint("RIGHT", b.bar, "RIGHT", -5, 0)
        b.time:SetJustifyH("RIGHT")
        nameW = barW - 5 - timeW
    else
        b.time:SetPoint("CENTER", b.bar, "CENTER", 0, 0)
        b.time:SetJustifyH("CENTER")
        nameW = barW / 2 - 5 - timeW / 2
    end

    b.shield:ClearAllPoints()
    b.shield:SetSize(math.max(12, math.floor(h * 0.55)), math.max(14, math.floor(h * 0.65)))
    if showIcon then
        b.shield:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 4, -3)       -- a badge on the icon's corner
    else
        b.shield:SetPoint("RIGHT", b, "LEFT", -2, 0)
    end
    if pos == "left" then
        b.spell:SetWidth(0)                                         -- 0 = as wide as the text; may run past the bar's end
        b.spell:Show()
    else
        nameW = math.floor(nameW)
        b.spell:SetWidth(math.max(nameW, 1))
        b.spell:SetShown(nameW >= 30)
    end
end

-- Called whenever the spell name changes. The time stays in the middle of the bar
-- unless the name is wider than the room to its left; then the time moves to the
-- right for this cast, which gives the name the whole bar. (A name we can't
-- measure - secret text - just keeps whatever layout is set.)
local function FitCastName(b)
    b.autoRight = false
    if TimePos() == "middle" then
        local showIcon = not (DB and DB.castIcon == false)
        local barW = b:GetWidth() - 2 - (showIcon and (CastH() - 1) or 0)
        local centeredSlot = barW / 2 - 5 - ((TimeMode() == "total") and 35 or 18)
        local ok, w = pcall(b.spell.GetUnboundedStringWidth, b.spell)
        if ok and w ~= nil and not issecret(w) and type(w) == "number" and w > centeredSlot then
            b.autoRight = true
        end
    end
    LayoutCast(b)
end

local function SetCastIcon(b, texture)
    if not b.icon:IsShown() then return end
    local ok = Present(texture) and pcall(b.icon.SetTexture, b.icon, texture)
    if not ok then b.icon:SetTexture(QUESTION) end
end

-- The "can't be interrupted" mark on the TARGET's bar: a small shield on the icon and a grey bar. The game
-- may hide whether a cast can be interrupted ("secret"), and addon code may not test a hidden value, so it is
-- never tested here: it goes straight to widget calls the game provides for exactly this
-- (SetAlphaFromBoolean / SetVertexColorFromBoolean), which accept a hidden true/false.
local greyBar
local function MarkInterruptible(b, notInterruptible)
    local want = b.unit ~= "player" and not (DB and DB.castShield == false)
    if not want or not b.shield.SetAlphaFromBoolean then
        b.shield:Hide()
        return
    end
    local flag = notInterruptible
    if flag == nil then flag = false end                  -- the game says nothing: it can be interrupted
    b.shield:Show()
    b.shield:SetAlphaFromBoolean(flag, 1, 0)
    local fill = b.bar:GetStatusBarTexture()
    if fill and fill.SetVertexColorFromBoolean and _G.CreateColor then
        greyBar = greyBar or _G.CreateColor(0.55, 0.57, 0.62, 1)
        local r, g, bl = CastRGB(b.unit)
        fill:SetVertexColorFromBoolean(flag, greyBar, _G.CreateColor(r, g, bl, 1))
    end
end

-- The latency "safe zone" on YOUR bar: the last stretch of a cast, as long as your latency, where you can
-- already press the next spell and it will go off the moment this one ends. A red band at the end of the bar.
local function ShowSafeZone(b, totalSeconds, preview)
    if b.unit ~= "player" or (DB and DB.castSafe == false) then b.safe:Hide(); return end
    local barW = b.bar:GetWidth()
    local width
    if preview then
        width = barW * 0.14
    else
        local _, _, home, world = GetNetStats()
        local lag = ((world and world > 0) and world or home or 0) / 1000
        if lag <= 0 or not totalSeconds or totalSeconds <= 0 then b.safe:Hide(); return end
        width = barW * math.min(1, lag / totalSeconds)
    end
    b.safe:ClearAllPoints()
    b.safe:SetPoint(b.reverse and "TOPLEFT" or "TOPRIGHT", b.bar, b.reverse and "TOPLEFT" or "TOPRIGHT", 0, 0)
    b.safe:SetPoint(b.reverse and "BOTTOMLEFT" or "BOTTOMRIGHT", b.bar, b.reverse and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
    b.safe:SetWidth(math.max(1, width))
    b.safe:Show()
end

local function RefreshCast(b)
    local unit = b.unit
    b.bar:SetStatusBarColor(CastRGB(unit))             -- a class colour follows the target
    local active, channel, name, tex, startMS, endMS, notInt = false, false, nil, nil, nil, nil, nil

    if UnitExists(unit) then
        if UnitCastingInfo then
            local n, _, t, s, e, _, _, ni = UnitCastingInfo(unit)
            if Present(n) then active, name, tex, startMS, endMS, notInt = true, n, t, s, e, ni end
        end
        if not active and UnitChannelInfo then
            local n, _, t, s, e, _, ni = UnitChannelInfo(unit)
            if Present(n) then active, channel, name, tex, startMS, endMS, notInt = true, true, n, t, s, e, ni end
        end
    end

    if not active then
        b.mode = nil
        if b.preview then   -- menu open: show a made-up cast so you can see how it will look
            b.spell:SetText(PREVIEW_SPELL[unit] or b.label)
            FitCastName(b)
            SetCastIcon(b, QUESTION)
            b.bar:SetMinMaxValues(0, 1); b.bar:SetValue(0.5)
            local mode = TimeMode()
            b.time:SetText(mode == "off" and "" or (mode == "total" and "1.5 / 3.0" or "1.5"))
            ShowSafeZone(b, nil, true)
            MarkInterruptible(b, unit == "target")        -- the preview shows the mark on the target's bar
            b:Show()
        else
            b.safe:Hide(); b.shield:Hide()
            b:Hide()
        end
        return
    end

    b.channel = channel
    b.spell:SetText(name)
    FitCastName(b)
    SetCastIcon(b, tex)

    if not issecret(startMS) and not issecret(endMS) and startMS and endMS then
        -- readable times (always the case for your own casts)
        b.mode = "manual"
        b.startS, b.endS = startMS / 1000, endMS / 1000
        b.bar:SetMinMaxValues(0, b.endS - b.startS)
        if channel then b.safe:Hide() else ShowSafeZone(b, b.endS - b.startS) end
    elseif b.bar.SetTimerDuration and (channel and UnitChannelDuration or UnitCastingDuration) then
        local duration = channel and UnitChannelDuration(unit) or UnitCastingDuration(unit)
        local dir
        if Enum and Enum.StatusBarTimerDirection then
            dir = channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
        end
        if pcall(b.bar.SetTimerDuration, b.bar, duration, nil, dir) then
            b.mode, b.duration = "timer", duration
        else
            b.mode = nil
        end
    end

    if b.mode ~= "manual" then b.safe:Hide() end
    MarkInterruptible(b, notInt)

    if not b.mode then   -- no way to read the timing: just show a full bar
        b.bar:SetMinMaxValues(0, 1); b.bar:SetValue(1)
        b.time:SetText("")
    end
    b:Show()
end

local function ApplyCastTextures()
    for unit, b in pairs(castBars) do
        b.bar:SetStatusBarTexture(ns.CastTexturePath(unit))
        b.bar:SetStatusBarColor(CastRGB(unit))
        LayoutCast(b)
    end
end

---------------------------------------------------------------------------
-- Layout maths
---------------------------------------------------------------------------
local function FrameWidth(frame, default)
    return ((frame and frame:GetWidth()) or default) * ((frame and frame:GetScale()) or 1)
end

-- how far KutzUI's own bars (UnitBars.lua) stick out past Blizzard's frame toward the screen centre
local function BarsExtra(unit) return (ns.BarsExtra and ns.BarsExtra(unit)) or 0 end

local function PlayerWidth() return FrameWidth(_G.PlayerFrame, 232) + BarsExtra("player") end

-- cast bar width: your setting, or the player frame's width by default
local function GetCastWidth()
    local v = DB.castWidth or math.floor(PlayerWidth())
    return math.max(CAST_MIN_W, math.min(CAST_MAX_W, v))
end

-- the space between a cast bar's end and the frame beside it, when "same distance from the cast bars" is on
local function GetCastMargin() return (DB and DB.castMargin) or 8 end

-- Height of the cast bars (centre of the pair), set on its own from the frames.
local function GetCastY()
    return DB.castY or DB.groupY
end

-- Frame size: the percent you chose, or nil to leave Blizzard's size alone.
local function WantScale(key)
    local s = DB.scale and DB.scale[key]
    return s and (s / 100) or nil
end

local origScale = {}      -- frame -> the size Blizzard had given it before we touched it

local function ApplyScale(frame, key)
    local want = WantScale(key)
    if not frame or not want then return end
    if not origScale[frame] then origScale[frame] = frame:GetScale() end
    if math.abs(frame:GetScale() - want) > 0.001 then frame:SetScale(want) end
end

-- The gap (pixels) between Player's RIGHT edge and Target's LEFT edge, split evenly either
-- side of the screen centre - so the cast bars (centred on the screen) are the same
-- distance from both frames. Smallest: the two frames touching. Largest: keeps Target and
-- its Target-of-target frame fully on screen.
local function SpreadBounds()
    local pw = PlayerWidth()
    local tw = FrameWidth(_G.TargetFrame, 232) + BarsExtra("target")
    local totW = TOT_W * (WantScale("tot") or 1)
    local hi = math.floor(UIParent:GetWidth() - 2 * math.max(tw + totW, pw) - 4)
    if hi < 0 then hi = 0 end
    return 0, hi
end

-- Older versions saved the distance from the screen centre to the middle of each frame;
-- turn that into the gap once, so nothing jumps.
local function MigrateSpread()
    if DB.spreadIsGap then return end
    DB.spreadIsGap = true
    if DB.spread then
        local pw, tw = PlayerWidth(), FrameWidth(_G.TargetFrame, 232) + BarsExtra("target")
        DB.spread = math.max(0, math.floor(2 * DB.spread - (pw + tw) / 2))
    end
end

local function GetSpread()
    MigrateSpread()
    local lo, hi = SpreadBounds()
    local v
    if DB.castHug then
        v = GetCastWidth() + 2 * GetCastMargin()       -- the frames follow the cast bars, equally far from both ends
    else
        v = DB.spread or (GetCastWidth() + 16)         -- a distance you set (default: just outside the cast bars)
    end
    return math.max(lo, math.min(hi, v))
end

-- the menu (Menu.lua) shows "In combat - frames move when combat ends" while a change waits
local function UpdatePanelStatus()
    if ns.UpdateMenuStatus then ns.UpdateMenuStatus(pendingLayout) end
end

-- Where a frame's corner goes: Player by its BOTTOM-RIGHT corner, Target by its BOTTOM-LEFT,
-- each half the gap from the screen centre. y is the height of the frame's middle (as before),
-- so the vertical position doesn't change.
local function WantPoint(frame, isPlayer, gap, y)
    local s = frame:GetScale() or 1
    local h = frame:GetHeight() or 0
    -- our own bars stick out past Blizzard's frame toward the centre: make room for them
    local extra = BarsExtra(isPlayer and "player" or "target")
    local x = ((isPlayer and -gap or gap) / 2 + (isPlayer and -extra or extra)) / s
    return isPlayer and "BOTTOMRIGHT" or "BOTTOMLEFT", x, y / s - h / 2
end

local function Place(frame, isPlayer, gap, y)
    if not frame then return end
    local point, ox, oy = WantPoint(frame, isPlayer, gap, y)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, "CENTER", ox, oy)
end

local function ApplyLayout()
    if not DB then return end
    local y      = DB.groupY

    -- cast bars (module "castbars"): ours and unprotected, so they always move immediately
    if castBars.player then
        local cw, castY = GetCastWidth(), GetCastY()
        for _, b in pairs(castBars) do
            b:SetWidth(cw)
            LayoutCast(b)
        end
        castBars.player:ClearAllPoints()
        castBars.player:SetPoint("BOTTOM", UIParent, "CENTER", 0, castY + CAST_SPACING / 2)
        castBars.target:ClearAllPoints()
        castBars.target:SetPoint("TOP", UIParent, "CENTER", 0, castY - CAST_SPACING / 2)
    end

    if not tot then return end          -- module "frames" is off: leave Blizzard's frames alone

    -- Blizzard's player/target frames and our ToT are protected
    if InCombatLockdown() then
        pendingLayout = true
        UpdatePanelStatus()
        return
    end
    pendingLayout = false

    -- KutzUI's own Player / Target bars first: where the frames go depends on how wide they are
    if ns.BarsApply then ns.BarsApply() end

    -- sizes first: the spacing below depends on how wide the frames are
    ApplyScale(_G.PlayerFrame, "player")
    ApplyScale(_G.TargetFrame, "target")
    ApplyScale(tot, "tot")

    local gap = GetSpread()
    Place(_G.PlayerFrame, true,  gap, y)    -- bottom-right corner, half the gap left of the centre
    Place(_G.TargetFrame, false, gap, y)    -- bottom-left corner, half the gap right of the centre
    tot:ClearAllPoints()
    -- beside Target: offsets are measured in the Target-of-target frame's own units, so divide by its
    -- size to make them real screen pixels (fewer = closer to Target)
    local ts = tot:GetScale() or 1
    tot:SetPoint("LEFT", _G.TargetFrame, "RIGHT", (DB.totOffsetX or 2) / ts, (DB.totOffsetY or 0) / ts)
    UpdatePanelStatus()
end

-- Blizzard (Edit Mode, level-up, ...) may re-anchor the frames; put them
-- back, but not from inside Blizzard's own call stack.
local function ScheduleLayout()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0, function()
        scheduled = false
        ApplyLayout()
    end)
end

-- Watchdog (a poller - there are deliberately NO hooks on Blizzard's frames,
-- because a hook runs inside Blizzard's own call and taints it). Out of combat:
--   * every frame, hide any suppressed Blizzard frame that Blizzard re-showed;
--   * ten times a second, check Player/Target are where (and how big) they
--     should be (Edit Mode, a level-up, ... can change them) and put them back.
-- In combat nothing protected can be moved, so it all waits for combat to end.
local function FrameAt(frame, isPlayer, gap, y, key)
    if not frame then return true end
    local s = frame:GetScale() or 1
    local want = WantScale(key)
    if want and math.abs(s - want) > 0.005 then return false end
    if frame:GetNumPoints() ~= 1 then return false end
    local point, rel, relPoint, ox, oy = frame:GetPoint(1)
    local wp, wx, wy = WantPoint(frame, isPlayer, gap, y)
    return point == wp and rel == UIParent and relPoint == "CENTER"
        and ox and oy and math.abs(ox - wx) < 0.5 and math.abs(oy - wy) < 0.5
end

local watchAcc = 0
local watchdog = CreateFrame("Frame")
watchdog:SetScript("OnUpdate", function(_, elapsed)
    if not DB or InCombatLockdown() then return end
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then return end   -- don't fight Edit Mode

    for f in pairs(suppressed) do
        if f:IsShown() then f:Hide() end
    end
    if not tot then return end          -- module "frames" is off

    watchAcc = watchAcc + elapsed
    if watchAcc < 0.1 then return end
    watchAcc = 0
    local gap, y = GetSpread(), DB.groupY
    if not (FrameAt(_G.PlayerFrame, true, gap, y, "player") and FrameAt(_G.TargetFrame, false, gap, y, "target")) then
        ApplyLayout()
    end
end)

---------------------------------------------------------------------------
-- What the menu (Menu.lua) uses. It stores your choices in KutzUIDB and then
-- calls Apply(); everything else about the layout stays in this file.
---------------------------------------------------------------------------
local function FrameFor(key)
    if key == "player" then return _G.PlayerFrame end
    if key == "target" then return _G.TargetFrame end
    return tot
end

-- the size shown on a size slider: your setting, or Blizzard's current size
local function ScalePercent(key)
    if DB.scale[key] then return DB.scale[key] end
    local f = FrameFor(key)
    return math.floor(((f and f:GetScale()) or 1) * 100 + 0.5)
end

local function ResetFrames()
    DB.groupY, DB.spread = DEFAULT_Y, nil
    DB.totOffsetX, DB.totOffsetY = nil, nil
    DB.totColorMode, DB.totColor = nil, nil
    DB.ownBars, DB.barW, DB.barH = nil, nil, nil
    -- hand the frame sizes back to Blizzard (out of combat; otherwise at combat end)
    for _, key in ipairs({ "player", "target", "tot" }) do
        DB.scale[key] = nil
        local f = FrameFor(key)
        if f and origScale[f] and not InCombatLockdown() then f:SetScale(origScale[f]) end
    end
    ApplyLayout()
end

local function ResetCastBars()
    DB.castY, DB.castWidth = DEFAULT_Y, nil
    DB.castIcon, DB.castTimeRight, DB.castTimePos, DB.castTexPlayer, DB.castTexTarget = nil, nil, nil, nil, nil
    DB.castHeight, DB.castShape, DB.castReverse, DB.castHug, DB.castMargin = nil, nil, nil, nil, nil
    DB.castColorPlayer, DB.castColorTarget, DB.castClassPlayer, DB.castClassTarget = nil, nil, nil, nil
    DB.castTimeMode, DB.castSafe, DB.castShield = nil, nil, nil
    ApplyCastTextures()
    ApplyLayout()
end

ns.L = {
    DEFAULT_Y = DEFAULT_Y, SCALE_MIN = SCALE_MIN, SCALE_MAX = SCALE_MAX,
    CAST_MIN_W = CAST_MIN_W, CAST_MAX_W = CAST_MAX_W, CAST_MIN_H = CAST_MIN_H, CAST_MAX_H = CAST_MAX_H,
    GetCastHeight = CastH, GetCastMargin = GetCastMargin,
    CastColorHex = function(unit)             -- the colour as "rrggbb" for the menu's swatches (class colours aside)
        local own = DB and DB[unit == "player" and "castColorPlayer" or "castColorTarget"]
        if own then return own end
        local d = CAST_COLORS[unit]
        return string.format("%02x%02x%02x", math.floor(d[1] * 255 + 0.5), math.floor(d[2] * 255 + 0.5), math.floor(d[3] * 255 + 0.5))
    end,
    ToTColorHex = ToTColorHex,
    RefreshToT = function() local f = _G.KutzToTFrame; if f then pcall(UpdateToT, f) end end,
    Apply = ApplyLayout, ApplyCastTextures = ApplyCastTextures,
    GetCastY = GetCastY, GetCastWidth = GetCastWidth,
    GetSpread = GetSpread, SpreadBounds = SpreadBounds, ScalePercent = ScalePercent,
    ResetFrames = ResetFrames, ResetCastBars = ResetCastBars,
    IsPending = function() return pendingLayout end,
    -- while the menu is open the cast bars show made-up casts so you can see them
    SetCastPreview = function(on)
        for _, b in pairs(castBars) do b.preview = on; RefreshCast(b) end
    end,
}


---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        KutzUIDB = KutzUIDB or {}
        KutzUIDB.groupY = KutzUIDB.groupY or DEFAULT_Y
        -- Cast bars used to move with the frames. From now on they have their own
        -- height; start them exactly where they are today.
        KutzUIDB.castY = KutzUIDB.castY or KutzUIDB.groupY
        KutzUIDB.scale = KutzUIDB.scale or {}
        DB = KutzUIDB

        if ns.Enabled("frames") then
            tot = CreateToT()
            Suppress(_G.TargetFrame and _G.TargetFrame.totFrame or _G.TargetFrameToT)   -- Blizzard's own ToT
        end
        if ns.Enabled("castbars") then
            CreateCastBar("player", "Player")
            CreateCastBar("target", "Target")
            -- silence Blizzard's versions of what we replace (kept hidden by the watchdog)
            Suppress(_G.PlayerCastingBarFrame)
            Suppress(_G.TargetFrame and _G.TargetFrame.spellbar or _G.TargetFrameSpellBar)

            for _, e in ipairs({
                "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
                "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
                "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
                "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_EMPOWER_UPDATE",
                "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
            }) do
                -- pcall so an event this client doesn't know can't break the rest
                pcall(self.RegisterUnitEvent, self, e, "player", "target")
            end
        end
        for _, e in ipairs({
            "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_LEVEL_UP",
            "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED",
        }) do
            pcall(self.RegisterEvent, self, e)
        end
        self:UnregisterEvent("PLAYER_LOGIN")

        ApplyLayout()
        C_Timer.After(1, ApplyLayout)   -- Blizzard lays its frames out a moment after login
        C_Timer.After(3, ApplyLayout)

    elseif event:find("^UNIT_SPELLCAST_") then
        local b = castBars[arg1]
        if b then RefreshCast(b) end

    elseif event == "PLAYER_REGEN_ENABLED" then
        ScheduleLayout()   -- cheap: also catches anything Blizzard moved during the fight

    elseif event == "PLAYER_TARGET_CHANGED" then
        if castBars.target then RefreshCast(castBars.target) end

    elseif event == "PLAYER_LEVEL_UP" then
        -- Blizzard re-lays out the player frame around a level-up; re-apply
        -- now and again once things have settled.
        ScheduleLayout()
        C_Timer.After(1, ScheduleLayout)
        C_Timer.After(3, ScheduleLayout)

    elseif event == "PLAYER_ENTERING_WORLD" then
        for _, b in pairs(castBars) do RefreshCast(b) end
        ScheduleLayout()

    else   -- DISPLAY_SIZE_CHANGED, UI_SCALE_CHANGED, EDIT_MODE_LAYOUTS_UPDATED
        ScheduleLayout()
    end
end)

function ns.DebugLayout()
    local pf, tf = _G.PlayerFrame, _G.TargetFrame
    ns.Print(string.format("PlayerFrame=%s TargetFrame=%s TargetFrame.totFrame=%s TargetFrame.spellbar=%s PlayerCastingBarFrame=%s",
        tostring(pf ~= nil), tostring(tf ~= nil), tostring(tf and tf.totFrame ~= nil),
        tostring(tf and tf.spellbar ~= nil), tostring(_G.PlayerCastingBarFrame ~= nil)))
    if DB then
        local lo, hi = SpreadBounds()
        ns.Print(string.format("frames y=%s  cast y=%s  gap between Player and Target=%s (allowed %d..%d)  cast width=%s  sizes: player=%s%% target=%s%% tot=%s%%  pending=%s",
            tostring(DB.groupY), tostring(GetCastY()), tostring(GetSpread()), lo, hi, tostring(GetCastWidth()),
            tostring(ScalePercent("player")), tostring(ScalePercent("target")), tostring(ScalePercent("tot")),
            tostring(pendingLayout)))
    end
end

ns.RegisterDebug(ns.DebugLayout)

end)
