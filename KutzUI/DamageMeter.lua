---------------------------------------------------------------------------
-- KutzUI / DamageMeter        (module "damagemeter")
--
-- Blizzard's own damage meter (a window of damage / healing / ... per player) next to your combat
-- log, and a way to go between them. Nothing about the meter is re-drawn here:
--   * its text already uses your font (the game-wide font module restyles NumberFontNormal and
--     GameFontNormalMed1, the font objects it is built from);
--   * its size, bar height, transparency, text size, class colours and "when to show" are Blizzard's
--     own Edit Mode settings (Esc > Edit Mode > Damage Meter), and so is where it sits;
--   * what this adds is the on switch (the game option damageMeterEnabled), and the SWAP:
--
--        what to show:   both  |  combat log only  |  damage meter only
--
--     with a small "Meter" / "Log" button in the corner of the combat log window (while the mouse is
--     over it) and  /kutz meter [log|meter|both].
--
-- Hiding is alpha + mouse only, re-applied by a slow poller (no hooks). The combat log is only ever
-- hidden while the meter is really on and available, so you can't end up with neither.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("damagemeter", function()

local CVAR = "damageMeterEnabled"

ns.DM_MODES = {
    { key = "both",  name = "Both: combat log and damage meter" },
    { key = "log",   name = "Combat log only" },
    { key = "meter", name = "Damage meter only" },
}

function ns.DMMode()
    return (KutzUIDB and KutzUIDB.dmMode) or "both"
end

function ns.SetDMMode(mode)
    if KutzUIDB then KutzUIDB.dmMode = (mode ~= "both") and mode or nil end
end

function ns.DMEnabled()
    return GetCVarBool and GetCVarBool(CVAR) and true or false
end

-- Blizzard's meter is its own addon (Blizzard_DamageMeter). On some clients it is not loaded until
-- something asks for it, so when the meter is switched on and its frame doesn't exist, ask once.
-- ns.dmLoadResult keeps what the game answered, so the menu and /kutz debug can say why if it fails.
ns.dmLoadResult = nil

function ns.DMCodeLoaded()
    return type(_G.DamageMeter) == "table"
end

function ns.DMLoadCode()
    local api = _G.C_AddOns
    if not (api and api.LoadAddOn) then
        ns.dmLoadResult = { ok = false, reason = "this game version cannot load addons on request" }
        return false
    end
    local ok, loaded, reason = pcall(api.LoadAddOn, "Blizzard_DamageMeter")
    ns.dmLoadResult = { ok = ok and loaded and true or false, reason = (ok and reason) or (not ok and tostring(loaded)) or nil }
    return ns.dmLoadResult.ok
end

function ns.SetDMEnabled(on)
    SetCVar(CVAR, on and "1" or "0")
    if on and not ns.DMCodeLoaded() then ns.DMLoadCode() end
end

-- true, or false + the game's reason (for example "not available in this game mode")
function ns.DMAvailable()
    if not (_G.C_DamageMeter and _G.C_DamageMeter.IsDamageMeterAvailable) then return false, "this game version has no damage meter" end
    local ok, available, reason = pcall(_G.C_DamageMeter.IsDamageMeterAvailable)
    if not ok then return false, "could not ask the game" end
    return available and true or false, reason
end

function ns.DMButtonEnabled()
    local v = KutzUIDB and KutzUIDB.dmButton
    if v == nil then return true end
    return v
end

-- The combat log is hidden only while the meter can actually be seen.
function ns.CombatLogSwapped()
    return ns.DMMode() == "meter" and ns.DMEnabled() and (ns.DMAvailable())
end

local function MeterHidden()
    return ns.DMMode() == "log"
end

---------------------------------------------------------------------------
-- Applying it
---------------------------------------------------------------------------
local function ApplyMeter()
    local meter = _G.DamageMeter
    if type(meter) ~= "table" then return end
    local hide = MeterHidden()
    ns.SetFrameHidden(meter, hide)
    if meter.GetWindowDataList then
        local ok, list = pcall(meter.GetWindowDataList, meter)
        if ok and type(list) == "table" then
            for _, data in pairs(list) do
                if type(data) == "table" then ns.SetFrameHidden(data.sessionWindow, hide) end
            end
        end
    end
end

local hiddenLog = false                      -- have WE hidden the combat log?

local function ApplyLog()
    local cl = _G.ChatFrame2
    if not cl then return end
    -- hidden while the meter OR KutzUI's own log (KutzLog.lua) is in its place
    local swapped = ns.CombatLogSwapped() or (ns.KutzLogActive and ns.KutzLogActive())
    if swapped then
        if cl:GetAlpha() ~= 0 then cl:SetAlpha(0) end
        if cl:IsMouseEnabled() then cl:EnableMouse(false) end
        hiddenLog = true
    elseif hiddenLog then                    -- give it back exactly as the combat log module styles it
        cl:SetAlpha((ns.CombatLogTextAlpha and ns.CombatLogTextAlpha()) or 1)
        cl:EnableMouse(true)
        hiddenLog = false
    end
    -- its filter buttons (children of a protected bar; out of combat only for the mouse)
    if not InCombatLockdown() then
        for i = 1, 6 do ns.SetFrameHidden(_G["CombatLogQuickButtonFrameButton" .. i], swapped) end
        ns.SetFrameHidden(_G.CombatLogQuickButtonFrame_CustomAdditionalFilterButton, swapped)
    end
end

local loadTried = false

local function Tick()
    if not loadTried and ns.DMEnabled() and not ns.DMCodeLoaded() then
        loadTried = true                         -- the game option was already on: make sure its code is there
        ns.DMLoadCode()
    end
    ApplyMeter()
    ApplyLog()
end

---------------------------------------------------------------------------
-- The little switch button in the corner of the combat log window
---------------------------------------------------------------------------
local button
local function MakeButton()
    button = CreateFrame("Button", "KutzMeterSwapButton", UIParent)
    button:SetSize(46, 16)
    button:SetFrameStrata("HIGH")
    local bg = button:CreateTexture(nil, "BACKGROUND"); bg:SetColorTexture(0, 0, 0, 0.55); bg:SetAllPoints()
    local hl = button:CreateTexture(nil, "HIGHLIGHT"); hl:SetColorTexture(1, 0.82, 0, 0.18); hl:SetAllPoints()
    button.text = button:CreateFontString(nil, "OVERLAY")
    ns.StyleText(button.text, 10)
    button.text:SetPoint("CENTER")
    button:SetScript("OnClick", function() ns.DMSwap() end)
    button:SetAlpha(0)
    button:EnableMouse(false)
    button.shown = false
    return button
end

-- one click: log <-> meter (from "both" it goes to the meter)
function ns.DMSwap(target)
    if not target then
        target = (ns.DMMode() == "meter") and "log" or "meter"
    end
    if target == "meter" and not (ns.DMEnabled() and ns.DMAvailable()) then
        ns.Print("The damage meter is not on. Turn it on in /kutz > Damage meter (or in Blizzard's options under Gameplay).")
        return
    end
    ns.SetDMMode(target)
    Tick()
end

ns.RegisterSlash("meter", function(arg)
    if arg == "log" or arg == "meter" or arg == "both" then
        if arg == "both" then ns.SetDMMode("both"); Tick() else ns.DMSwap(arg) end
    else
        ns.DMSwap()
    end
    ns.Print("showing: " .. ns.DMMode())
end)

local acc, fastAcc = 0, 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() Tick() end)
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    fastAcc = fastAcc + elapsed
    if acc >= 0.25 then
        acc = 0
        local ok, err = pcall(Tick)
        if not ok and not ns.damageMeterErrored then
            ns.damageMeterErrored = true
            ns.Print("damage meter swap error (please report): " .. tostring(err))
        end
    end
    if fastAcc < 0.1 then return end
    fastAcc = 0
    local cl = _G.ChatFrame2
    local want = ns.DMButtonEnabled() and cl and cl:IsShown() and ns.DMEnabled() and (ns.DMAvailable())
    if not want then
        if button and button.shown then button.shown = false; button:SetAlpha(0); button:EnableMouse(false) end
        return
    end
    if not button then
        MakeButton()
        button:SetPoint("TOPRIGHT", cl, "TOPRIGHT", -2, -2)
    end
    button.text:SetText(ns.DMMode() == "meter" and "Log" or "Meter")
    local over = cl:IsMouseOver() or button:IsMouseOver()
    if over ~= button.shown then
        button.shown = over
        button:SetAlpha(over and 0.9 or 0)
        button:EnableMouse(over)
    end
end)

ns.RegisterDebug(function()
    local meter = _G.DamageMeter
    local available, reason = ns.DMAvailable()
    local r = ns.dmLoadResult
    ns.Print(string.format("damage meter: frame=%s cvar=%s available=%s%s | showing=%s | combat log hidden by swap=%s | asked the game to load it: %s",
        tostring(type(meter) == "table"), tostring(ns.DMEnabled()), tostring(available),
        (type(reason) == "string" and reason ~= "") and (" (" .. reason .. ")") or "",
        ns.DMMode(), tostring(ns.CombatLogSwapped() and true or false),
        r and ((r.ok and "yes, loaded" or "no") .. (r.reason and (" (" .. tostring(r.reason) .. ")") or "")) or "not needed yet"))
end)

end)
