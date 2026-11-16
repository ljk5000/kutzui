---------------------------------------------------------------------------
-- KutzUI / ActionBars        (module "actionbars")
--
-- Switches for the main action bar's extras (menu: Action bars page):
--
--   * hide the page number and its up / down arrows at the bar's left end
--   * hide the gryphon / wyvern end caps
--   * XP numbers and percent shown on the experience bar all the time
--   * LOCK paging: the arrows do nothing and the paging keys (Next / Previous action
--     bar, "Action bar page 1-6") are neutralised, so the bar can't be switched by accident.
--     Bars the GAME switches by itself (stance, vehicle, possess) still change - those are
--     not paging.
--
-- Nothing of Blizzard's is hooked or replaced:
--   * hiding is alpha only, re-applied by a slow poller (Blizzard re-lays things out now
--     and then);
--   * locking uses override bindings owned by this addon (same method the chat module uses
--     for Enter), which can't be changed during combat - they are applied out of combat and
--     simply stay in force once set.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("actionbars", function()

local DEFAULTS = {
    abHideArrows  = true,    -- hide the page number + arrows
    abHideEndCaps = false,   -- hide the gryphons (left as Blizzard has it until you ask)
    abLockPaging  = true,    -- arrows and paging keys do nothing
    abXpText      = true,    -- XP numbers + percent always on the experience bar
    abXpSize      = 11,      -- their font size
    abXpRested    = true,    -- add the rested XP: "+12,000 rested"
}

function ns.ABOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

local dirty = true

function ns.SetABOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
    dirty = true
end

function ns.ResetABSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
    KutzUIDB.abScale, KutzUIDB.abBarScale = nil, nil
    dirty = true
end

---------------------------------------------------------------------------
-- Size: one slider for every bar, plus an optional size for a single bar.
-- The bar frame itself is scaled (the same SetScale the unit frame sizes use), out of
-- combat only - protected buttons can't be resized in a fight, so a change made in combat
-- waits for combat to end. If Blizzard (Edit Mode) sets a scale of its own, that becomes
-- the new starting point and ours is applied on top of it.
---------------------------------------------------------------------------
ns.AB_BARS = {
    { key = "MainActionBar",      name = "Bar 1 (main bar)" },
    { key = "MultiBarBottomLeft", name = "Bar 2 (bottom left)" },
    { key = "MultiBarBottomRight", name = "Bar 3 (bottom right)" },
    { key = "MultiBarRight",      name = "Bar 4 (right)" },
    { key = "MultiBarLeft",       name = "Bar 5 (far right)" },
    { key = "MultiBar5",          name = "Bar 6" },
    { key = "MultiBar6",          name = "Bar 7" },
    { key = "MultiBar7",          name = "Bar 8" },
    { key = "StanceBar",          name = "Stance bar" },
    { key = "PetActionBar",       name = "Pet bar" },
}
ns.AB_SCALE_MIN, ns.AB_SCALE_MAX = 50, 200

function ns.ABScaleAll()
    return (KutzUIDB and KutzUIDB.abScale) or 100
end

-- the size for one bar: its own setting, or the "all bars" one
function ns.ABScaleFor(key)
    local own = KutzUIDB and KutzUIDB.abBarScale and KutzUIDB.abBarScale[key]
    return own or ns.ABScaleAll()
end

function ns.SetABScaleAll(pct)
    if KutzUIDB then KutzUIDB.abScale = (pct ~= 100) and pct or nil end
    dirty = true
end

function ns.SetABScaleBar(key, pct)
    if not KutzUIDB then return end
    KutzUIDB.abBarScale = KutzUIDB.abBarScale or {}
    KutzUIDB.abBarScale[key] = (pct ~= ns.ABScaleAll()) and pct or nil
    dirty = true
end

local baseScale, appliedScale = {}, {}     -- frame -> Blizzard's own scale / the scale we last set

local function ApplyScale()
    for _, bar in ipairs(ns.AB_BARS) do
        local f = _G[bar.key]
        if f and f.GetScale then
            local cur = f:GetScale()
            if appliedScale[f] == nil or math.abs(cur - appliedScale[f]) > 0.001 then
                baseScale[f] = cur                            -- something else set a scale: start from that
            end
            local target = baseScale[f] * ns.ABScaleFor(bar.key) / 100
            if math.abs(cur - target) > 0.001 then
                f:SetScale(target)
            end
            appliedScale[f] = f:GetScale()
        end
    end
end

---------------------------------------------------------------------------
-- Hiding (alpha only)
---------------------------------------------------------------------------
local function SetAlphaIf(frame, alpha)
    if frame and frame.GetAlpha and frame:GetAlpha() ~= alpha then frame:SetAlpha(alpha) end
end

local function ApplyLook()
    local bar = _G.MainActionBar
    if not bar then return end
    local hide, lock = ns.ABOption("abHideArrows"), ns.ABOption("abLockPaging")

    local pn = bar.ActionBarPageNumber
    if pn then
        SetAlphaIf(pn, hide and 0 or 1)
        for _, b in ipairs({ pn.UpButton, pn.DownButton }) do
            if b then
                -- hidden or locked: nothing to click. (Disabled buttons show Blizzard's greyed-out arrow.)
                local clickable = not (hide or lock)
                if b.IsMouseEnabled and b:IsMouseEnabled() ~= clickable then b:EnableMouse(clickable) end
                if b.IsEnabled and b:IsEnabled() ~= clickable then b:SetEnabled(clickable) end
            end
        end
    end
    SetAlphaIf(bar.EndCaps, ns.ABOption("abHideEndCaps") and 0 or 1)
end

---------------------------------------------------------------------------
-- XP numbers on the experience bar, always visible: "12,345 / 56,000  (22.1%)  +12,000 rested"
-- (the rested part, in blue, only while you have rested XP and only if its switch is on).
-- Blizzard only shows its own "12345 / 56000" while the mouse is over the bar (or all the time
-- through its "xpBarText" setting, but then without the percent). Ours is a text line of our own
-- that sits on the bar, so nothing of Blizzard's is hooked or rewritten; the only thing done to
-- Blizzard's own bar text is that its alpha is set to 0 while ours is up, so the two never overlap
-- when you hover (the tooltip with the rested XP still appears as usual).
---------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
local xpFrame = CreateFrame("Frame", "KutzXpBarText", UIParent)
xpFrame:SetSize(420, 14)
xpFrame:SetFrameStrata("MEDIUM")           -- same strata as the bar's own overlay (its tick marks), so we draw above them
xpFrame:EnableMouse(false)
xpFrame.text = xpFrame:CreateFontString(nil, "OVERLAY")
xpFrame.text:SetAllPoints(xpFrame)
xpFrame.text:SetJustifyH("CENTER")
xpFrame.text:SetTextColor(1, 1, 1)
xpFrame.size, xpFrame.bar, xpFrame.shownText = 0, nil, nil
local dimmedText                                       -- Blizzard's bar text we have set to alpha 0

local function Commas(n)
    local s, k = tostring(math.floor(n)), nil
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

local function FindXpBar()
    local mgr, info = _G.StatusTrackingBarManager, _G.StatusTrackingBarInfo
    local want = info and info.BarsEnum and info.BarsEnum.Experience
    if not (mgr and want and mgr.barContainers) then return nil end
    for _, container in ipairs(mgr.barContainers) do
        local bar = container.bars and container.bars[want]
        if bar and bar:IsShown() then return bar end
    end
end

local function UpdateXpText()
    local bar = ns.ABOption("abXpText") and FindXpBar() or nil
    local cur, max
    if bar then
        cur, max = UnitXP("player"), UnitXPMax("player")
        if type(cur) ~= "number" or type(max) ~= "number" or issecret(cur) or issecret(max) or max <= 0 then bar = nil end
    end

    local blizzText = bar and bar.OverlayFrame and bar.OverlayFrame.Text or nil
    if dimmedText and dimmedText ~= blizzText then SetAlphaIf(dimmedText, 1); dimmedText = nil end
    if not bar then
        if xpFrame:IsShown() then xpFrame:Hide() end
        xpFrame.bar = nil
        return
    end

    if xpFrame.bar ~= bar then
        xpFrame.bar = bar
        xpFrame:ClearAllPoints()
        xpFrame:SetPoint("CENTER", bar, "CENTER", 0, -1)
        xpFrame:SetFrameLevel(bar:GetFrameLevel() + 30)
    end
    local size = ns.ABOption("abXpSize")
    if xpFrame.size ~= size then
        xpFrame.size = size
        ns.StyleText(xpFrame.text, size)
    end
    if blizzText then SetAlphaIf(blizzText, 0); dimmedText = blizzText end

    local text = string.format("%s / %s  (%.1f%%)", Commas(cur), Commas(max), cur / max * 100)
    if ns.ABOption("abXpRested") and GetXPExhaustion then
        local rested = GetXPExhaustion()               -- nil when you have no rested XP
        if type(rested) == "number" and not issecret(rested) and rested > 0 then
            text = text .. "  |cff5aa0ff+" .. Commas(rested) .. " rested|r"
        end
    end
    if xpFrame.shownText ~= text then
        xpFrame.shownText = text
        xpFrame.text:SetText(text)
    end
    if not xpFrame:IsShown() then xpFrame:Show() end
end

---------------------------------------------------------------------------
-- Locking the paging keys
---------------------------------------------------------------------------
local owner = CreateFrame("Frame", "KutzActionBarLockOwner", UIParent)
local noop = CreateFrame("Button", "KutzNoopButton", UIParent)    -- a button that does nothing when clicked

local COMMANDS = { "NEXTACTIONPAGE", "PREVIOUSACTIONPAGE",
    "ACTIONPAGE1", "ACTIONPAGE2", "ACTIONPAGE3", "ACTIONPAGE4", "ACTIONPAGE5", "ACTIONPAGE6" }
local lockedKeys = 0

local function ApplyLock()
    ClearOverrideBindings(owner)
    lockedKeys = 0
    if not ns.ABOption("abLockPaging") then return end
    for _, command in ipairs(COMMANDS) do
        local k1, k2 = GetBindingKey(command)
        for _, key in ipairs({ k1 or false, k2 or false }) do
            if key then
                SetOverrideBindingClick(owner, true, key, "KutzNoopButton")
                lockedKeys = lockedKeys + 1
            end
        end
    end
end

---------------------------------------------------------------------------
-- Driving it
---------------------------------------------------------------------------
local lockDirty = true
local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function() lockDirty = true; dirty = true end)
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    pcall(ApplyLook)                                   -- cheap: only writes when something differs
    pcall(UpdateXpText)
    if (lockDirty or dirty) and not InCombatLockdown() then
        lockDirty, dirty = false, false
        pcall(ApplyLock)
    end
    if not InCombatLockdown() then pcall(ApplyScale) end
end)

ns.RegisterDebug(function()
    local bar = _G.MainActionBar
    local pn = bar and bar.ActionBarPageNumber
    ns.Print(string.format("action bars: MainActionBar=%s pageNumber=%s up=%s down=%s endCaps=%s | hideArrows=%s hideEndCaps=%s lockPaging=%s (%d key(s) neutralised)",
        tostring(bar ~= nil), tostring(pn ~= nil), tostring(pn and pn.UpButton ~= nil), tostring(pn and pn.DownButton ~= nil),
        tostring(bar and bar.EndCaps ~= nil), tostring(ns.ABOption("abHideArrows")), tostring(ns.ABOption("abHideEndCaps")),
        tostring(ns.ABOption("abLockPaging")), lockedKeys))
end)

end)
