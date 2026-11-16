-- (appended after:  local FILES = { {name=, src=}, ... } )
-- A stand-in for the game's API, just faithful enough to run the addon's own logic.

local problems, notes = {}, {}
local chatAdmissionFilters = {}
ChatFrameUtil = { AddMessageEventFilter = function(event, callback) chatAdmissionFilters[event] = callback end }
local function problem(msg) problems[#problems + 1] = msg end

---------------------------------------------------------------------------
-- fake widgets
---------------------------------------------------------------------------
local all = {}                         -- every widget ever created
local Methods = {}
-- optional FIELDS on Blizzard's frames: absent unless a test sets them (a method would be a function)
local OPTIONAL_FIELDS = {
    Background = true, ScrollBar = true, spellbar = true, totFrame = true, healthbar = true, manabar = true,
    TextString = true, LeftText = true, RightText = true, ManaBarText = true, HealthBarText = true,
    header = true, TitleContainer = true, HotKey = true, isDocked = true, isLocked = true,
    historyBuffer = true, FontStringContainer = true, UnpackageEntry = true, TransformMessages = true,
    safeMasked = true, kutzBG = true, kutzOwned = true, kutzHooked = true, kutzSetup = true, kutzDragging = true,
    HealthBar = true, ManaBar = true, Name = true, Portrait = true,
    GetBagID = true, GetSlotAndBagID = true, auraInstanceID = true, action = true, unit = true,
}
local Widget = { __index = function(t, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and (k:sub(1, 1) == "_" or OPTIONAL_FIELDS[k]) then return nil end
    return function() end              -- any other widget method: do nothing
end }

local function new(kind, name)
    local o = setmetatable({ _kind = kind, _name = name, _scripts = {}, _hooks = {}, _events = {}, _shown = true,
        _value = 0, _min = 0, _max = 1, _text = "", _alpha = 1, _scale = 1, _w = 100, _h = 20, _kids = {}, _points = 0 }, Widget)
    all[#all + 1] = o
    if name then _G[name] = o end
    return o
end

function Methods.SetScript(s, e, f) s._scripts[e] = f end
function Methods.GetScript(s, e) return s._scripts[e] end
function Methods.HookScript(s, e, f) s._hooks[e] = f end
function Methods.RegisterEvent(s, e) s._events[e] = true end
function Methods.RegisterUnitEvent(s, e) s._events[e] = true end
function Methods.UnregisterEvent(s, e) s._events[e] = nil end
function Methods.UnregisterAllEvents(s) s._events = {} end
function Methods.Show(s) s._shown = true; if s._scripts.OnShow then s._scripts.OnShow(s) end end
function Methods.Hide(s) s._shown = false; if s._scripts.OnHide then s._scripts.OnHide(s) end end
function Methods.SetShown(s, b) if b then s:Show() else s:Hide() end end
function Methods.IsShown(s) return s._shown end
function Methods.IsVisible(s) return s._shown end
function Methods.SetAttribute(s, k, v) s._attr = s._attr or {}; s._attr[k] = v end
function Methods.GetAttribute(s, k) return s._attr and s._attr[k] end
function Methods.CreateTexture(s) return new("Texture") end
function Methods.CreateMaskTexture(s) return new("Texture") end
function Methods.GetStatusBarTexture(s) s._sbtex = s._sbtex or new("Texture"); return s._sbtex end
function Methods.AddMaskTexture(s, m) s._masks = (s._masks or 0) + 1 end
function Methods.RemoveMaskTexture(s, m) s._masks = (s._masks or 0) - 1 end
function Methods.SetReverseFill(s, v) s._reverse = v end
function Methods.SetTexture(s, path) s._tex = path end
function Methods.SetStatusBarTexture(s, path) s._sbpath = path end
function Methods.SetStatusBarColor(s, r, g, b) s._color = { r, g, b } end
function Methods.SetTextColor(s, r, g, b) s._tcolor = { r, g, b } end
function Methods.CreateFontString(s) return new("FontString") end
function Methods.GetName(s) return s._name end
function Methods.GetParent(s) return UIParent end
function Methods.SetText(s, t) s._text = t end
function Methods.GetText(s) return s._text end
function Methods.SetFormattedText(s, f, ...) s._text = string.format(f, ...) end
function Methods.SetFont(s, p, sz, fl) s._font = { p, sz, fl } end   -- returns nothing, like the real client does
function Methods.GetFont(s) local f = s._font or { "Fonts\\FRIZQT__.TTF", 12, "" }; return f[1], f[2], f[3] end
function Methods.SetSize(s, w, h) s._w, s._h = w, h end
function Methods.SetWidth(s, w) s._w = w end
function Methods.SetHeight(s, h) s._h = h end
function Methods.GetWidth(s) return s._w end
function Methods.GetHeight(s) return s._h end
function Methods.SetAlpha(s, a) s._alpha = a end
function Methods.GetAlpha(s) return s._alpha end
function Methods.SetScale(s, v) s._scale = v end
function Methods.GetScale(s) return s._scale end
function Methods.SetPoint(s, point, rel, relPoint, x, y)
    s._pl = s._pl or {}
    for _, e in ipairs(s._pl) do if e[1] == point then e[2], e[3], e[4], e[5] = rel, relPoint, x, y; return end end
    s._points = s._points + 1
    s._pl[#s._pl + 1] = { point, rel, relPoint, x, y }
end
function Methods.ClearAllPoints(s) s._points = 0; s._pl = nil end
function Methods.GetNumPoints(s) return s._points end
function Methods.GetPoint(s, i) local e = s._pl and s._pl[i or 1]; if e then return e[1], e[2], e[3], e[4], e[5] end end
function Methods.GetFontString(s) s._fs = s._fs or new("FontString"); return s._fs end
function Methods.GetThumbTexture(s) s._thumb = s._thumb or new("Texture"); return s._thumb end
function Methods.GetStringWidth(s) return 10 end
function Methods.GetUnboundedStringWidth(s) return 10 end
function Methods.GetFrameLevel(s) return 5 end
function Methods.GetFrameStrata(s) return "MEDIUM" end
function Methods.GetObjectType(s) return s._kind end
function Methods.IsObjectType(s, t) return s._kind == t end
function Methods.GetRegions(s) return end
function Methods.GetLeft(s) return 0 end
function Methods.GetBottom(s) return 0 end
function Methods.GetRight(s) return 300 end
function Methods.EnableMouse(s, b) s._mouse = b end
function Methods.IsMouseEnabled(s) return s._mouse ~= false end
function Methods.EnableMouseWheel(s, b) s._wheel = b end
function Methods.IsMouseWheelEnabled(s) return s._wheel == true end
function Methods.IsForbidden(s) return false end
function Methods.IsProtected(s) return false end
function Methods.GetFontObject(s) return nil end
function Methods.GetColorRGB(s) return 0.5, 0.25, 0.75 end
-- sliders: SetValue fires OnValueChanged when the value really changes (like the game)
function Methods.SetMinMaxValues(s, lo, hi)
    s._min, s._max = lo, hi
    if type(s._value) ~= "number" or type(lo) ~= "number" or type(hi) ~= "number" then return end   -- (a hidden value: the real bar copes)
    local v = math.max(lo, math.min(hi, s._value))
    if v ~= s._value then s:SetValue(v) end
end
function Methods.GetMinMaxValues(s) return s._min, s._max end
function Methods.SetValue(s, v)
    if s._value == v then return end
    s._value = v
    if s._scripts.OnValueChanged then s._scripts.OnValueChanged(s, v, false) end
end
function Methods.GetValue(s) return s._value end
function Methods.Click(s) if s._scripts.OnClick then s._scripts.OnClick(s, "LeftButton", true) end end
-- scrolling message frames (ours and Blizzard's chat frames)
function Methods.AddMessage(s, text, r, g, b) s._lines = s._lines or {}; s._lines[#s._lines + 1] = text end
function Methods.Clear(s) s._lines = {} end
function Methods.GetNumMessages(s) return s._lines and #s._lines or 0 end

UIParent = new("Frame", "UIParent"); UIParent._w, UIParent._h = 2000, 1300
function UnitClass() return "Warrior", "WARRIOR" end
GameTooltip = new("Frame", "GameTooltip")
ColorPickerFrame = new("Frame", "ColorPickerFrame")
function ColorPickerFrame.SetupColorPickerAndShow(self, info) ColorPickerFrame._info = info end
function CreateFrame(kind, name, parent, template) return new(kind, name) end

---------------------------------------------------------------------------
-- fake game functions
---------------------------------------------------------------------------
SlashCmdList = {}
UISpecialFrames = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function GetLocale() return "enUS" end
function InCombatLockdown() return false end
local clock = 1000
function GetTime() return clock end
UnitAffectingCombat = UnitAffectingCombat or function() return false end
time = time or function() return 1700000000 + math.floor(clock) end   -- the game has the Lua time() function; this fake did not
function IsShiftKeyDown() return false end
function GetBindingKey() return "ENTER" end
function ClearOverrideBindings() end
function SetOverrideBindingClick() end
collectgarbage = function() return 0 end   -- the test interpreter has no collector
GetAddOnMemoryUsage = function() return 512 end
UpdateAddOnMemoryUsage = function() end
function ReloadUI() end
DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local ORIGINAL_DAMAGE_FONT = DAMAGE_TEXT_FONT
local optionsLoaded = false
LOAD_REQUESTS = {}
C_AddOns = {
    GetAddOnMetadata = function() return "test" end,
    LoadAddOn = function(name)                        -- the settings window is its own addon
        if name ~= "KutzUI_Options" or #OPTION_FILES == 0 then LOAD_REQUESTS[name] = true; return false, "MISSING" end
        if not optionsLoaded then
            optionsLoaded = true
            for _, f in ipairs(OPTION_FILES) do
                local fn, err = load(f.src, "@" .. f.name)
                if not fn then problem("LOAD " .. f.name .. ": " .. tostring(err)) else
                    local ok, e = pcall(fn, "KutzUI_Options", {})
                    if not ok then problem("RUN " .. f.name .. ": " .. tostring(e)) end
                end
            end
        end
        return true
    end,
}
local cvars = { showTimestamps = "none" }
function GetCVar(name) return cvars[name] or "classic" end
function SetCVar(name, value) cvars[name] = value end
function GetCVarBool(name) return cvars[name] == "1" end
function issecretvalue(v) return type(v) == "table" and v._secret == true end
function RegisterUnitWatch() end
function UnregisterUnitWatch() end
function UnregisterUnitWatch() end
function hooksecurefunc() end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strsplit(sep, str, n) local a, b = str:match("^(.-)" .. sep .. "(.*)$"); if a then return a, b end return str end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strlower = string.lower
unpack = unpack or table.unpack
Enum = {}
local timers = {}
C_Timer = { After = function(t, f) timers[#timers + 1] = f end }
function UnitExists() return false end
function UnitIsPlayer() return true end
function GetFramerate() return 143.6 end
function GetNetStats() return 0, 0, 25, 40 end
local cursorX, cursorY = 500, 400
function GetCursorPosition() return cursorX, cursorY end
function UnitName() return "Tester" end
function GetBuildInfo() return "1.60.1", "70790", "Nov 4 2026", 16001 end
C_CombatLog = { IsCombatLogRestricted = function() return false end }

---------------------------------------------------------------------------
-- load the addon files in TOC order
---------------------------------------------------------------------------
local ns = {}
for _, f in ipairs(FILES) do
    local fn, err = load(f.src, "@" .. f.name)
    if not fn then problem("LOAD " .. f.name .. ": " .. tostring(err)) else
        local ok, e = pcall(fn, "KutzUI", ns)
        if not ok then problem("RUN " .. f.name .. ": " .. tostring(e)) end
    end
end

local function safely(label, fn, ...)
    local ok, e = pcall(fn, ...)
    if not ok then problem(label .. ": " .. tostring(e)) end
    return ok
end

---------------------------------------------------------------------------
-- 1. login: fire PLAYER_LOGIN on every frame that asked for it
---------------------------------------------------------------------------
-- make the "player" and "target" bars exist as the menu / layout expect
-- a fake minimap with the pieces the addon looks for
Minimap = new("Frame", "Minimap")
Minimap.ZoomIn = new("Button"); Minimap.ZoomOut = new("Button")
local addonIcon = new("Button", "LibDBIcon10_FakeAddon")
Minimap.GetChildren = function() return addonIcon end
MinimapCluster = new("Frame", "MinimapCluster")
MinimapCluster.ZoneTextButton = new("Button")
MinimapCluster.Tracking = new("Frame")
MinimapCluster.IndicatorFrame = new("Frame")
MinimapCluster.IndicatorFrame.MailFrame = new("Frame")
MinimapCluster.IndicatorFrame.CraftingOrderFrame = new("Frame")
MinimapCluster.MinimapContainer = new("Frame")
MinimapCluster.MinimapContainer.PlayerCoords = new("Frame")
MinimapCluster.MinimapContainer.Minimap = Minimap
MinimapCluster.InstanceDifficulty = false     -- only exists inside instances
GameTimeFrame = new("Button", "GameTimeFrame")
QueueStatusButton = new("Button", "QueueStatusButton")
ExpansionLandingPageMinimapButton = new("Button", "ExpansionLandingPageMinimapButton")
AddonCompartmentFrame = new("Button", "AddonCompartmentFrame")
TimeManagerClockButton = new("Button", "TimeManagerClockButton")
TimeManagerClockButton:SetPoint("TOPRIGHT", MinimapCluster.ZoneTextButton, "TOPRIGHT", -4, 0)
-- the unit tooltip's lines and the hook the game offers addons
Enum = Enum or {}
Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Currency = 5, UnitAura = 7 }
POSTCALLS = {}
Enum.TooltipDataLineType = { UnitName = 2, UnitLevel = 47, UnitType = 48 }
LINEPRECALLS = {}
TooltipDataProcessor = { AllTypes = "ALL",
    AddTooltipPostCall = function(kind, fn) POSTCALLS[#POSTCALLS + 1] = { kind = kind, fn = fn } end,
    AddLinePreCall = function(kind, fn) LINEPRECALLS[#LINEPRECALLS + 1] = { kind = kind, fn = fn } end }
TooltipUtil = { GetDisplayedUnit = function() return "Someone", "mouseover", "Player-1-ABC" end }
LEVEL, PVP = "Level", "PvP"
TIP_LINES = 0
for i = 1, 8 do new("FontString", "GameTooltipTextLeft" .. i) end
GameTooltip.NumLines = function() return TIP_LINES end
GameTooltip.IsTooltipType = function() return true end
-- Blizzard's damage meter: one frame holding up to three session windows
DamageMeter = new("Frame", "DamageMeter")
local dmWindow = new("Frame")
DamageMeter.GetWindowDataList = function() return { { sessionWindow = dmWindow } } end
local dmAvailable, dmReason = true, nil
C_DamageMeter = { IsDamageMeterAvailable = function() return dmAvailable, dmReason end }
MainActionBar = new("Frame", "MainActionBar")
MainActionBar._scale = 1
-- chat buttons and the tooltip's health bar
ChatFrameMenuButton = new("Button", "ChatFrameMenuButton")
ChatFrameChannelButton = new("Button", "ChatFrameChannelButton")
QuickJoinToastButton = new("Button", "QuickJoinToastButton")
GameTooltip.StatusBar = new("StatusBar", "GameTooltipStatusBar")
GameTooltip._scale = 1
ItemRefTooltip = new("Frame", "ItemRefTooltip")
ItemRefTooltip._scale = 1
MultiBarBottomLeft = new("Frame", "MultiBarBottomLeft")
MultiBarBottomLeft._scale = 1
XP, XPMAX = 1234, 56789
function UnitXP() return XP end
function UnitXPMax() return XPMAX end
RESTED = nil
function GetXPExhaustion() return RESTED end
StatusTrackingBarInfo = { BarsEnum = { Reputation = 1, Experience = 4 } }
XPBAR = new("Frame", "FakeXpBar"); XPBAR.OverlayFrame = new("Frame"); XPBAR.OverlayFrame.Text = new("FontString")
REPBAR = new("Frame", "FakeRepBar"); REPBAR._shown = false
StatusTrackingBarManager = { barContainers = { { bars = { [1] = REPBAR, [4] = XPBAR } } } }
MAPCUR, MAPPLAYER = { 0.5, 0.5 }, true
WorldMapFrame = new("Frame", "WorldMapFrame")
WorldMapFrame.GetMapID = function() return 947 end
WorldMapFrame.ScrollContainer = new("Frame", "FakeMapScroll")
WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition = function() return MAPCUR[1], MAPCUR[2] end
C_Map = { GetBestMapForUnit = function() return 947 end,
    GetPlayerMapPosition = function() if not MAPPLAYER then return nil end return { GetXY = function() return 0.12, 0.34 end } end }
MainActionBar.EndCaps = new("Frame")
MainActionBar.ActionBarPageNumber = new("Frame")
MainActionBar.ActionBarPageNumber.UpButton = new("Button", "FakePageUp")
MainActionBar.ActionBarPageNumber.DownButton = new("Button", "FakePageDown")
PlayerFrame = new("Frame", "PlayerFrame"); PlayerFrame._w = 232; PlayerFrame._h = 100
TargetFrame = new("Frame", "TargetFrame"); TargetFrame._w = 232; TargetFrame._h = 100
KutzUIDB = nil
if UPGRADE_FIXTURE then
    -- Exported by the unmodified 0.43.0 harness: a complete previous-version profile.
    local legacy, err = ns.ProfileParse(UPGRADE_FIXTURE)
    if not legacy then error("invalid legacy profile fixture: " .. tostring(err)) end
    legacy.spread = 321
    KutzUIDB = { profiles = { Legacy = legacy }, activeProfile = "Legacy",
        monitor = { alert = false, upgradeMarker = "kept", history = {} } }
end
local DISABLED = DISABLE_MODULES or {}          -- set by harness.js: modules to switch off for this run
local anyDisabled = next(DISABLED) ~= nil
local function DisabledCopy()
    local copy = {}
    for key, value in pairs(DISABLED) do copy[key] = value end
    return copy
end
if anyDisabled then KutzUIDB = { modules = DisabledCopy() } end
-- Core's loader runs every enabled module when its own ADDON_LOADED arrives
local loaders = {}
for _, w in ipairs(all) do if w._events.ADDON_LOADED and w._scripts.OnEvent then loaders[#loaders + 1] = w end end
for _, w in ipairs(loaders) do safely("ADDON_LOADED", w._scripts.OnEvent, w, "ADDON_LOADED", "KutzUI") end
-- A dependent addon loads after the parent's settings and module queue.
for _, f in ipairs(MONITOR_FILES) do
    local fn, err = load(f.src, "@" .. f.name)
    if not fn then problem(tostring(err)) else safely(f.name, fn, "KutzUI_Monitor", {}) end
end
if #MONITOR_FILES == 0 and ns.moduleMemory.monitor then problem("disabled monitor addon started") end
if #MONITOR_FILES > 0 and ns.Enabled("monitor") and not ns.moduleMemory.monitor then
    problem("dependent monitor addon did not start after parent ADDON_LOADED")
end
if UPGRADE_FIXTURE then
    if not KutzUIDB.profiles.Legacy or KutzUIDB.profiles.Legacy.spread ~= 321 then problem("upgrade lost existing profile") end
    if not KutzUIDB.monitor or KutzUIDB.monitor.upgradeMarker ~= "kept" or KutzUIDB.monitor.alert ~= false then
        problem("monitor extraction lost existing SavedVariables")
    end
end
-- Feature switches must persist false (Lua's false-or-nil idiom loses it).
ns.SetModuleEnabled("chat", false)
if ns.Enabled("chat") then problem("feature switch failed to persist disabled state") end
ns.SetModuleEnabled("chat", DISABLED.chat ~= false)
local login = {}
for _, w in ipairs(all) do if w._events.PLAYER_LOGIN and w._scripts.OnEvent then login[#login + 1] = w end end
for _, w in ipairs(login) do safely("PLAYER_LOGIN", w._scripts.OnEvent, w, "PLAYER_LOGIN") end
for label, err in pairs(ns.moduleErrors or {}) do problem("module " .. label .. " failed to start: " .. err) end
if not anyDisabled then
    -- with everything on, the pieces must really exist (so the "off creates nothing" checks mean something)
    for _, g in ipairs({ "KutzToTFrame", "KutzPlayerCastBar", "KutzTargetCastBar", "KutzNoopButton" }) do
        if _G[g] == nil then problem("module on but " .. g .. " was not created") end
    end
    for _, m in ipairs(ns.MODULES) do
        if not ns.Enabled(m.key) then problem("module " .. m.key .. " should default to on") end
    end
    if not tostring(DAMAGE_TEXT_FONT):find("Inconsolata", 1, true) then problem("the floating combat numbers font was not set to the chosen font (" .. tostring(DAMAGE_TEXT_FONT) .. ")") end
end
notes[#notes + 1] = ("login handled by %d frames; KutzUIDB = %s"):format(#login, tostring(KutzUIDB ~= nil))

---------------------------------------------------------------------------
-- 2. open the menu and build every page
---------------------------------------------------------------------------
local widgetsBefore = #all
if ns.ToggleLayoutPanel then problem("the settings window was loaded before /kutz (it should be load-on-demand)") end
safely("/kutz", SlashCmdList.KUTZUI, "")
if not ns.ToggleLayoutPanel then problem("/kutz did not load the settings addon") end
notes[#notes + 1] = ("menu opened: %d widgets created; window shown = %s"):format(#all - widgetsBefore, tostring(KutzLayoutPanel and KutzLayoutPanel._shown))

---------------------------------------------------------------------------
-- 3. click every button, drag every slider to both ends and the middle
---------------------------------------------------------------------------
local clicked, slid = 0, 0
local i = widgetsBefore + 1
while i <= #all do                       -- pages are built when their tab is clicked, so the list grows
    local w = all[i]
    if w._kind == "Slider" and w._scripts.OnValueChanged then
        for _, v in ipairs({ w._min, w._max, math.floor((w._min + w._max) / 2) }) do
            safely("slider " .. tostring(w._value), function() w._scripts.OnValueChanged(w, v, true) end)
            slid = slid + 1
        end
    end
    if w._kind == "Button" and w._scripts.OnClick then
        safely("click", w._scripts.OnClick, w, "LeftButton", true)
        clicked = clicked + 1
    end
    i = i + 1
end
-- typing into a slider's number box: a value past the end is clamped, text that is not a number changes nothing
do
    local tried, bad = 0, 0
    for j = widgetsBefore + 1, #all do
        local w = all[j]
        local box = w._kind == "Slider" and w.valueText
        if box and box._scripts and box._scripts.OnEnterPressed and box._scripts.OnTextChanged and w.GetValue then
            local lo, hi = w:GetMinMaxValues()
            local function type_(text)
                box:SetText(text)
                box._scripts.OnTextChanged(box, true)
                box._scripts.OnEnterPressed(box)
            end
            safely("type a number", type_, "999999")
            if w:GetValue() ~= hi then bad = bad + 1 end
            local before = w:GetValue()
            safely("type junk", type_, "abc")
            if w:GetValue() ~= before then bad = bad + 1 end
            tried = tried + 1
            if tried >= 6 then break end
        end
    end
    if tried == 0 then problem("slider number boxes: none found to test") end
    if bad > 0 then problem("slider number boxes: typing a number or junk gave the wrong value in " .. bad .. " case(s)") end
    notes[#notes + 1] = ("typed into %d slider number boxes"):format(tried)
    if ns.L and ns.L.ResetFrames then safely("reset frames", ns.L.ResetFrames) end     -- typing moved things: the Reset button puts the frames back
    if ns.L and ns.L.Apply then safely("re-apply", ns.L.Apply) end
end
KutzUIDB.modules = anyDisabled and DisabledCopy() or nil     -- the clicks above flipped the module switches
-- the color picker the swatches opened: choose a color then cancel
if ColorPickerFrame._info then
    safely("color picker change", ColorPickerFrame._info.swatchFunc)
    safely("color picker cancel", ColorPickerFrame._info.cancelFunc)
end
notes[#notes + 1] = ("clicked %d buttons, moved %d slider positions"):format(clicked, slid)
local subPages
for _, r in ipairs(ns.MenuLayoutReport and ns.MenuLayoutReport() or {}) do
    if r.visible ~= r.current then problem(("menu: page '%s' is %s but %s the page you are on"):format(r.key, r.visible and "shown" or "hidden", r.current and "it is" or "it is not")) end
    if r.subs > 0 and r.visible and r.panesShown ~= 1 then problem(("menu: page '%s' shows %d of its sub-tab panes (should be 1)"):format(r.key, r.panesShown)) end
    if r.subs > 0 then subPages = (subPages or 0) + 1 end
    if r.used > r.room - 4 then problem(("menu: page '%s' is too tall: its controls reach %d px down (columns: %s) but the window has %d"):format(r.key, r.used, table.concat(r.cols, "/"), r.room)) end
end
for _, name in ipairs({ "ActionButtonUseKeyDown", "autoLootDefault", "Sound_EnableErrorSpeech", "nameplateMaxDistance", "UIScale", "MaxFPS" }) do
    if cvars[name] == nil then problem("game settings: clicking the page never wrote " .. name) end
end

-- the window's own show / hide scripts
safely("window OnShow", KutzLayoutPanel._scripts.OnShow, KutzLayoutPanel)
safely("window OnHide", KutzLayoutPanel._scripts.OnHide, KutzLayoutPanel)

---------------------------------------------------------------------------
-- report
---------------------------------------------------------------------------
local function report()
    print("---- notes ----")
    for _, n in ipairs(notes) do print("  " .. n) end
    print(#problems == 0 and "\nRESULT: no errors, no failed checks." or ("\nRESULT: " .. #problems .. " PROBLEM(S):"))
    for _, p in ipairs(problems) do print("  * " .. p) end
end

if anyDisabled then
    -- Switched-off modules must create nothing, and everything left must still work
    local names = {}
    for k in pairs(DISABLED) do names[#names + 1] = k end
    table.sort(names)
    notes[#notes + 1] = "modules switched off in this run: " .. table.concat(names, ", ")
    local function made(global) return _G[global] ~= nil end
    local expectNone = {
        frames    = { "KutzToTFrame" },
        castbars  = { "KutzPlayerCastBar", "KutzTargetCastBar" },
        actionbars = { "KutzNoopButton", "KutzActionBarLockOwner" },
        convenience = { "KutzLowHealthBlink", "KutzBuyAmountFrame", "KutzBuyAmountEdit" },
    }
    for key in pairs(DISABLED) do
        for _, g in ipairs(expectNone[key] or {}) do
            if made(g) then problem("module '" .. key .. "' is off but created " .. g) end
        end
        if ns.moduleMemory[key] then problem("module '" .. key .. "' is off but was started") end
    end
    if DISABLED.fonts and DAMAGE_TEXT_FONT ~= ORIGINAL_DAMAGE_FONT then problem("the fonts module is off but the floating combat numbers font was changed") end
    safely("/kutz debug", SlashCmdList.KUTZUI, "debug")
    safely("/kutz mem", SlashCmdList.KUTZUI, "mem")
    safely("/kutz grid", SlashCmdList.KUTZUI, "grid")
    safely("/kutz grid", SlashCmdList.KUTZUI, "grid")
    notes[#notes + 1] = ("%d widgets alive"):format(#all)
    report()
    return
end

---------------------------------------------------------------------------
-- 4. the combat log window: a fake secure window that behaves like Blizzard's
--    (the addon only gets TransformMessages / RemoveMessagesByPredicate / a change callback)
---------------------------------------------------------------------------
local function Buffer()
    local b = { entries = {} }                       -- entries[1] = NEWEST (like Blizzard's buffer)
    function b:GetNumElements() return #self.entries end
    function b:GetEntryAtIndex(i) return self.entries[i] end
    function b:PushFront(text, chat) table.insert(self.entries, 1, { text = text, chat = chat }) end
    function b:PushBack(text, chat) self.entries[#self.entries + 1] = { text = text, chat = chat } end
    function b:Wipe() self.entries = {} end
    return b
end
local pollers = {}
for _, w in ipairs(login) do if w._scripts.OnUpdate then pollers[#pollers + 1] = w end end
local function tick(seconds)
    for _, w in ipairs(pollers) do if w._scripts.OnUpdate then safely("OnUpdate", w._scripts.OnUpdate, w, seconds or 0.2) end end
end
local function tickAll(seconds)
    for _, w in ipairs(all) do if w._scripts.OnUpdate then safely("OnUpdate (all)", w._scripts.OnUpdate, w, seconds or 0.3) end end
end
local function containsText(lines, needle) for _, l in ipairs(lines) do if type(l) == "string" and l:find(needle, 1, true) then return true end end return false end

-- Blizzard-like class colors and a visible target
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
local realExists, realName = UnitExists, UnitName
function UnitExists(u) return u == "player" or u == "target" end
function UnitName(u) if u == "target" then return "Defias Thug" end return "Tester" end
function UnitClass(u) if u == "target" then return "Mage", "MAGE" end return "Warrior", "WARRIOR" end
for _, w in ipairs(login) do
    if w._events.GROUP_ROSTER_UPDATE and w._scripts.OnEvent then safely("roster update", w._scripts.OnEvent, w, "GROUP_ROSTER_UPDATE") end
end

ChatFrame2 = new("ScrollingMessageFrame", "ChatFrame2")
ChatFrame2.FontStringContainer = new("Frame")
local hb = Buffer()
local callbacks, refreshes = {}, 0
local function display() refreshes = refreshes + 1; for _, f in ipairs(callbacks) do f(ChatFrame2) end end
ChatFrame2.AddOnDisplayRefreshedCallback = function(self, f) callbacks[#callbacks + 1] = f end
ChatFrame2.TransformMessages = function(self, pred, xform)
    local changed = false
    for _, e in ipairs(hb.entries) do
        if pred(e.text, 1, 1, 1, e.chat) then e.text = xform(e.text, 1, 1, 1, e.chat); changed = true end
    end
    if changed then display() end                      -- Blizzard: MarkDisplayDirty only if something changed
end
ChatFrame2.RemoveMessagesByPredicate = function(self, pred)
    local keep = {}
    for _, e in ipairs(hb.entries) do if not pred(e.text, 1, 1, 1, e.chat) then keep[#keep + 1] = e end end
    hb.entries = keep
    display()                                          -- Blizzard: RemoveIf always reports a change
end
local function texts() local t = {}; for i = #hb.entries, 1, -1 do t[#t + 1] = hb.entries[i].text end return t end

hb:PushBack("Pope Patrick creates Linen Bandage.", 7)                                  -- not combat (chat system line)
hb:PushFront("|Ky4|k")                                                                   -- combat lines are sealed tokens
hb:PushFront("|Ky47|k")
hb:PushFront("|Ky48|k")
local secretLine = setmetatable({ _secret = true }, { __tostring = function() return "secret" end })
hb:PushFront(secretLine)

-- Blizzard's own combat log settings (what the addon now edits)
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET, COMBATLOG_FILTER_FRIENDLY_UNITS = 1, 2, 3
COMBATLOG_FILTER_HOSTILE_UNITS, COMBATLOG_FILTER_HOSTILE_PLAYERS, COMBATLOG_FILTER_NEUTRAL_UNITS = 4, 5, 6
COMBATLOG_DEFAULT_SETTINGS = { amountColoring = false, amountHighlighting = true, abilityColoring = false,
    abilityActorColoring = false, abilityHighlighting = true, unitColoring = false, timestamp = false,
    schoolNameColoring = false, schoolNameHighlighting = true, showHistory = true }
local function MakeFilter()
    local st = {}
    for k, v in pairs(COMBATLOG_DEFAULT_SETTINGS) do st[k] = v end
    local grey = function() return { a = 1, r = 0.7, g = 0.7, b = 0.7 } end
    return { settings = st, colors = { unitColoring = { [1] = grey(), [2] = grey(), [3] = grey(), [4] = grey(), [5] = grey(), [6] = grey() },
        defaults = { damage = { a = 1, r = 1, g = 1, b = 0 }, spell = { a = 1, r = 1, g = 1, b = 1 } } } }
end
Blizzard_CombatLog_Filters = { filters = { MakeFilter(), MakeFilter() }, currentFilter = 1 }
Blizzard_CombatLog_CurrentSettings = Blizzard_CombatLog_Filters.filters[1]
local applyCalls, refilterCalls = 0, 0
C_CombatLog = { ApplyFilterSettings = function() applyCalls = applyCalls + 1 end, RefilterEntries = function() refilterCalls = refilterCalls + 1 end }
display()
tick(); tick(); tick()
local lines = texts()
notes[#notes + 1] = ("combat log: %d lines left (crafting line removed); Blizzard settings untouched"):format(#lines)
if containsText(lines, "creates Linen Bandage") then problem("'only real combat' failed: a crafting line is still in the window") end
for _, token in ipairs({ "|Ky4|k", "|Ky47|k", "|Ky48|k" }) do
    local seen = false
    for _, l in ipairs(lines) do if l == token then seen = true end end
    if not seen then problem("a sealed combat line was altered or lost: " .. token) end
end
local stillSecret = false
for _, l in ipairs(lines) do if l == secretLine then stillSecret = true end end
if not stillSecret then problem("a secret line was touched or lost") end

-- Blizzard's own combat log settings must be left alone (writing them / calling ApplyFilterSettings is blocked for addons)
local fs = Blizzard_CombatLog_Filters.filters[1]
if fs.settings.amountColoring ~= false or fs.settings.abilityActorColoring ~= false or fs.colors.defaults.damage.b ~= 0 then
    problem("the addon changed Blizzard's combat log settings")
end
if applyCalls ~= 0 or refilterCalls ~= 0 then problem("the addon called C_CombatLog.ApplyFilterSettings / RefilterEntries (blocked for addons)") end

-- nothing new: no endless refresh
local before = refreshes
tick(); tick(); tick(); tick()
if refreshes ~= before then problem("the combat log kept refreshing with nothing new (" .. (refreshes - before) .. " extra refreshes)") end

-- a new crafting line later is removed once
hb:PushFront("You create Rough Sharpening Stone.", 7)
display(); tick(); tick()
if containsText(texts(), "Rough Sharpening") then problem("a later crafting line stayed in the window") end
KutzUIDB.clogOnlyCombat = false
hb:PushFront("You create Another Thing.", 7)
display(); tick(); tick()
if not containsText(texts(), "Another Thing") then problem("with 'only real combat' off, a chat line was still removed") end
KutzUIDB.clogOnlyCombat = nil
KutzUIDB.clogHide = nil

UnitExists, UnitName = realExists, realName

---------------------------------------------------------------------------
-- 5. chat tags and fonts run without errors
---------------------------------------------------------------------------
ChatFrame1 = new("ScrollingMessageFrame", "ChatFrame1")
ChatFrame1.historyBuffer = Buffer()
ChatFrame1.TransformMessages = function(self, pred, xform)
    for _, e in ipairs(self.historyBuffer.entries) do if pred(e.text) then e.text = xform(e.text) end end
end
ChatFrame1.UnpackageEntry = function(self, e) return e.text, 1, 1, 1 end
CHAT_SAY_GET, CHAT_YELL_GET, CHAT_WHISPER_GET = "%s says: ", "%s yells: ", "%s whispers: "
ChatFrame1.historyBuffer:PushFront("|Hchannel:PARTY|h[Party]|h |Hplayer:Bob:3:PARTY|h[Bob]|h: pull")
ChatFrame1.historyBuffer:PushFront("|Hplayer:Example:6:SAY|h[Example]|h says: hello")
tick()
local chatTick = 0
for _, w in ipairs(all) do
    if w._scripts.OnUpdate and not w._name and not w._events.PLAYER_LOGIN then safely("chat/other poller", w._scripts.OnUpdate, w, 0.3); chatTick = chatTick + 1 end
end
local tagged = ChatFrame1.historyBuffer.entries[1].text .. " | " .. ChatFrame1.historyBuffer.entries[2].text
notes[#notes + 1] = "chat lines after the tag poller: " .. (tagged:gsub("|", "¦"))
if not (tagged:find("[P]", 1, true) and tagged:find("[S]", 1, true)) then problem("chat tags were not applied by the poller") end

---------------------------------------------------------------------------
-- 6. the game-wide font: apply, size offset, restore, and labels Blizzard owns
---------------------------------------------------------------------------
local function fontObj(name, size) local o = new("Font", name); o._font = { "Fonts\\FRIZQT__.TTF", size, "OUTLINE" }; return o end
local gfn, obj = fontObj("GameFontNormal", 12), fontObj("ObjectiveFont", 13)
local function fontOf(o) local p, s, f = o:GetFont(); return p, s, f end
local function isOurs(path) return path and path:find("Inconsolata", 1, true) ~= nil end

KutzUIDB.font, KutzUIDB.fontEverywhere, KutzUIDB.uiFontOffset = nil, nil, nil   -- defaults: Inconsolata, everywhere
ns.RefreshUIFont(); tick(0.6)
local p, s, f = fontOf(gfn)
local p2, s2 = fontOf(obj)
notes[#notes + 1] = ("game font applied: GameFontNormal -> %s @%s flags=%s ; ObjectiveFont (quest tracker) -> %s @%s"):format(tostring(p):match("[^\\]+$"), s, f, tostring(p2):match("[^\\]+$"), s2)
if not isOurs(p) or not isOurs(p2) then problem("game font was not applied to the font objects") end
if s ~= 12 or s2 ~= 13 or f ~= "OUTLINE" then problem("game font changed a size/flag it should have kept") end

KutzUIDB.uiFontOffset = 2; ns.RefreshUIFont(); tick(0.6)
if select(2, fontOf(gfn)) ~= 14 then problem("size offset +2 not applied from Blizzard's original size") end
KutzUIDB.uiFontOffset = 2; ns.RefreshUIFont(); tick(0.6)                  -- again: must NOT stack to +4
if select(2, fontOf(gfn)) ~= 14 then problem("size offset stacked on itself") end

-- a label Blizzard owns, built on that font object (name labels, key labels ...)
local label = new("FontString"); label.GetFontObject = function() return gfn end
label._font = { "Fonts\\FRIZQT__.TTF", 12, "OUTLINE" }
local rec = {}
ns.ForceFont(label, rec, 2)
if not (rec.origPath and rec.origPath:find("FRIZQT", 1, true) and rec.origSize == 12) then
    problem("a label's original font was recorded wrongly after the game font was applied: " .. tostring(rec.origPath) .. " @" .. tostring(rec.origSize))
end

KutzUIDB.font, KutzUIDB.uiFontOffset = "default", nil; ns.RefreshUIFont(); tick(0.6); ns.ForceFont(label, rec, 2)
local rp, rs = fontOf(gfn)
local lp, ls = fontOf(label)
notes[#notes + 1] = ("choosing Default restores: GameFontNormal -> %s @%s ; owned label -> %s @%s (original 12, +2 name bonus)"):format(tostring(rp):match("[^\\]+$"), rs, tostring(lp):match("[^\\]+$"), ls)
if not (rp:find("FRIZQT", 1, true) and rs == 12) then problem("Default (Blizzard) did not restore the font object") end
if not (lp:find("FRIZQT", 1, true) and ls == 14) then problem("Default (Blizzard) did not restore an owned label's font (size should be its original + bonus)") end

KutzUIDB.font, KutzUIDB.fontEverywhere = "robotomono", false; ns.RefreshUIFont(); tick(0.6)
if isOurs(fontOf(gfn)) or select(1, fontOf(gfn)):find("RobotoMono", 1, true) then problem("'use everywhere' off still changed Blizzard's font") end
KutzUIDB.fontEverywhere = nil; ns.RefreshUIFont(); tick(0.6)
if not select(1, fontOf(gfn)):find("RobotoMono", 1, true) then problem("Roboto Mono was not applied game-wide when chosen") end

---------------------------------------------------------------------------
-- 7. the combat log: filter bar flush with the screen bottom, text box and extra button hidden
---------------------------------------------------------------------------
local qb = new("Frame", "CombatLogQuickButtonFrame_Custom")
ChatFrame2EditBox = new("EditBox", "ChatFrame2EditBox")
CombatLogQuickButtonFrame_CustomAdditionalFilterButton = new("Button", "CombatLogQuickButtonFrame_CustomAdditionalFilterButton")
CombatLogQuickButtonFrameButton1 = new("Button", "CombatLogQuickButtonFrameButton1")
CombatLogQuickButtonFrameButton1:SetPoint("LEFT", qb, "LEFT", 3, 0)
ChatFrame2.buttonFrame = new("Frame", "ChatFrame2ButtonFrame"); ChatFrame2.buttonFrame._alpha = 0.2
ns.RestyleCombatLog(); tickAll(0.3)
do
    local _, _, _, bx = CombatLogQuickButtonFrameButton1:GetPoint(1)
    if bx ~= -2.5 then problem("the first filter button is not pulled back to the log's text edge (x=" .. tostring(bx) .. ")") end
    if ChatFrame2.buttonFrame._alpha ~= 0 then problem("the combat log's side button frame is still visible") end
end
if qb._points ~= 2 then problem("filter buttons were not anchored (points=" .. qb._points .. ")") end
if ChatFrame2EditBox._alpha ~= 0 or ChatFrame2EditBox._mouse ~= false then problem("the combat log text box is still visible / clickable") end
ChatFrame2EditBox._alpha = 1; tickAll(0.3)                                  -- Blizzard re-shows it: must be hidden again
if ChatFrame2EditBox._alpha ~= 0 then problem("the combat log text box came back and stayed visible") end
if CombatLogQuickButtonFrame_CustomAdditionalFilterButton._alpha ~= 0 then problem("the extra filter button is still visible") end
if not ChatFrame2._wheel then problem("mouse wheel scrolling is not enabled on the combat log") end
notes[#notes + 1] = ("filter bar anchored with %d points; text box alpha=%s; extra button alpha=%s; wheel=%s")
    :format(qb._points, tostring(ChatFrame2EditBox._alpha), tostring(CombatLogQuickButtonFrame_CustomAdditionalFilterButton._alpha), tostring(ChatFrame2._wheel))

-- the game-wide font also reaches the red error text at the top of the screen
UIErrorsFrame = new("MessageFrame", "UIErrorsFrame")
local ef = fontObj("ErrorFont", 16)
KutzUIDB.font, KutzUIDB.fontEverywhere = "inconsolata", nil; ns.RefreshUIFont(); tick(0.6)
local ep = UIErrorsFrame:GetFont()
if not (ep and ep:find("Inconsolata", 1, true)) then problem("the error text (UIErrorsFrame) did not get the chosen font: " .. tostring(ep)) end

-- chat window look sliders run without errors
KutzUIDB.chatSpacing, KutzUIDB.chatTextAlpha, KutzUIDB.chatBgAlpha, KutzUIDB.chatFontSize = 3, 0.5, 0.4, 16
ChatFrame1.FontStringContainer = new("Frame")
ns.RefreshChatLook(); tickAll(0.3)
if ChatFrame1.FontStringContainer._alpha ~= 0.5 then problem("chat text opacity was not applied") end
KutzUIDB.chatSpacing, KutzUIDB.chatTextAlpha, KutzUIDB.chatBgAlpha, KutzUIDB.chatFontSize = nil, nil, nil, nil

-- Player/Target: anchored by their inner bottom corners, an equal distance either side of the centre
do
    KutzUIDB.spread, KutzUIDB.spreadIsGap, KutzUIDB.groupY = 300, true, -383
    ns.L.Apply()
    local pp, _, _, px, py = PlayerFrame:GetPoint(1)
    local tp, _, _, tx, ty = TargetFrame:GetPoint(1)
    if pp ~= "BOTTOMRIGHT" or tp ~= "BOTTOMLEFT" then problem("Player/Target are not anchored by their bottom-right / bottom-left corners (" .. tostring(pp) .. "/" .. tostring(tp) .. ")") end
    local s = PlayerFrame:GetScale() or 1
    local ts = TargetFrame:GetScale() or 1
    if not px or not tx or math.abs(px * s + 150) > 0.5 or math.abs(tx * ts - 150) > 0.5 then
        problem("Player and Target are not an equal distance from the centre (" .. tostring(px) .. " / " .. tostring(tx) .. ")")
    end
    if py and math.abs(py * s + 50 - (-383)) > 0.5 then problem("the frames' height on screen changed (" .. tostring(py) .. ")") end
    -- an old-style saved spread (distance to the frame centres) is converted once, not left as a huge gap
    KutzUIDB.spread, KutzUIDB.spreadIsGap = 500, nil
    ns.L.Apply()
    local lo, hi = ns.L.SpreadBounds()
    local g = ns.L.GetSpread()
    if g < lo or g > hi then problem("the converted gap is out of range: " .. tostring(g)) end
    notes[#notes + 1] = ("player/target gap: saved gap 300 -> corners at %s / %s; old centre distance 500 -> gap %s"):format(tostring(px), tostring(tx), tostring(g))
    KutzUIDB.spread, KutzUIDB.spreadIsGap = nil, true
end

-- Target-of-target: pixels from the Target frame
do
    KutzUIDB.totOffsetX, KutzUIDB.totOffsetY = nil, nil
    ns.L.Apply()
    local p0, r0, rp0, x0, y0 = KutzToTFrame:GetPoint(1)
    if p0 ~= "LEFT" or r0 ~= TargetFrame or rp0 ~= "RIGHT" or math.abs(x0 - 2) > 0.01 or y0 ~= 0 then problem("Target-of-target is not 2 px right of Target by default (" .. tostring(x0) .. ")") end
    KutzUIDB.totOffsetX, KutzUIDB.totOffsetY = 20, -5
    ns.L.Apply()
    local p1, r1, rp1, x1, y1 = KutzToTFrame:GetPoint(1)
    if math.abs(x1 - 20) > 0.01 or math.abs(y1 + 5) > 0.01 then problem("Target-of-target offset was not applied (" .. tostring(x1) .. ", " .. tostring(y1) .. ")") end
    KutzToTFrame._scale = 2                              -- offsets are in the frame's own units: 20 px on screen = 10 here
    ns.L.Apply()
    local _, _, _, x2 = KutzToTFrame:GetPoint(1)
    if math.abs(x2 - 10) > 0.01 then problem("Target-of-target offset is not in screen pixels when the frame is scaled (" .. tostring(x2) .. ")") end
    KutzToTFrame._scale = 1
    KutzUIDB.totOffsetX, KutzUIDB.totOffsetY = nil, nil
    ns.L.Apply()
end

-- Target-of-target: a left click targets it, a right click opens its menu
do
    local f = KutzToTFrame
    if f:GetAttribute("unit") ~= "targettarget" or f:GetAttribute("*type1") ~= "target" or f:GetAttribute("*type2") ~= "togglemenu" then
        problem("Target-of-target: not set up to be clicked (unit / left click / right click)")
    end
end

-- Target-of-target colour: the unit's own colour by default, or one picked colour
do
    local keepExists, keepPlayer, keepClass = UnitExists, UnitIsPlayer, UnitClass
    UnitExists = function() return true end
    UnitIsPlayer = function() return true end
    UnitClass = function() return "Mage", "MAGE" end
    KutzUIDB.totColorMode, KutzUIDB.totColor = nil, nil
    ns.L.RefreshToT()
    local c = KutzToTFrame.health._color
    local m = RAID_CLASS_COLORS and RAID_CLASS_COLORS.MAGE
    if not (c and m and math.abs(c[1] - m.r) < 0.01 and math.abs(c[3] - m.b) < 0.01) then problem("Target-of-target bar is not in the class colour by default") end
    KutzUIDB.totColorMode, KutzUIDB.totColor = "custom", "ff0000"
    ns.L.RefreshToT()
    c = KutzToTFrame.health._color
    if not (c and c[1] == 1 and c[2] == 0 and c[3] == 0) then problem("Target-of-target bar did not take the picked colour") end
    ns.L.ResetFrames()
    if KutzUIDB.totColorMode or KutzUIDB.totColor then problem("Reset frames did not clear the Target-of-target colour") end
    UnitExists, UnitIsPlayer, UnitClass = keepExists, keepPlayer, keepClass
end

-- cast bars: thickness, shape (rounded masks), colours, direction, distance from the unit frames
do
    local L = ns.L
    local bar, tbar = KutzPlayerCastBar, KutzTargetCastBar
    L.ResetCastBars(); KutzUIDB.spread = nil

    KutzUIDB.castHeight = 40; L.Apply()
    if bar:GetHeight() ~= 40 then problem("cast bars: the thickness was not applied (" .. tostring(bar:GetHeight()) .. ")") end
    KutzUIDB.castHeight = nil; L.Apply()
    if bar:GetHeight() ~= 24 then problem("cast bars: the thickness did not return to normal") end

    KutzUIDB.castShape = "pill"; L.ApplyCastTextures()
    local fill = bar.bar:GetStatusBarTexture()
    if not (bar.maskOn and bar.mask and tostring(bar.mask._tex):find("kutz_mask_pill_", 1, true)) then problem("cast bars: the pill shape did not use a pill mask (" .. tostring(bar.mask and bar.mask._tex) .. ")") end
    if bar.bg._masks ~= 1 or bar.icon._masks ~= 1 or fill._masks ~= 1 then problem("cast bars: the mask was not put on the background, icon and fill") end
    KutzUIDB.castWidth = 700; L.Apply()
    if not tostring(bar.mask._tex):find("_32.tga", 1, true) then problem("cast bars: a very wide bar did not pick the widest mask (" .. tostring(bar.mask._tex) .. ")") end
    KutzUIDB.castWidth = 234; KutzUIDB.castShape = "round"; L.ApplyCastTextures()
    if not tostring(bar.mask._tex):find("kutz_mask_round_", 1, true) then problem("cast bars: the rounded shape did not switch masks") end
    if bar.bg._masks ~= 1 or fill._masks ~= 1 then problem("cast bars: switching shape stacked masks (" .. tostring(bar.bg._masks) .. ")") end
    KutzUIDB.castShape = nil; L.ApplyCastTextures()
    if bar.maskOn or bar.bg._masks ~= 0 or bar.icon._masks ~= 0 or fill._masks ~= 0 then problem("cast bars: square corners did not remove the mask") end

    KutzUIDB.castColorPlayer = "00ff00"; L.ApplyCastTextures()
    local c = bar.bar._color
    if not c or math.abs(c[1]) > 0.01 or math.abs(c[2] - 1) > 0.01 or math.abs(c[3]) > 0.01 then problem("cast bars: a picked colour was not used") end
    local keepExists = UnitExists
    UnitExists = function(u) return u == "player" or u == "target" end       -- a target that is a mage
    KutzUIDB.castClassTarget = true; L.ApplyCastTextures()
    UnitExists = keepExists
    local tc = tbar.bar._color
    if not tc or math.abs(tc[1] - 0.25) > 0.01 or math.abs(tc[2] - 0.78) > 0.01 then problem("cast bars: the target's class colour was not used (got " .. (tc and (tc[1] .. "," .. tc[2] .. "," .. tc[3]) or "nil") .. ")") end
    KutzUIDB.castClassTarget = nil; L.ApplyCastTextures()
    KutzUIDB.castReverse = true; L.Apply()
    if bar.bar._reverse ~= true then problem("cast bars: fill from the right was not applied") end
    KutzUIDB.castReverse = nil; L.Apply()
    if bar.bar._reverse ~= false then problem("cast bars: fill direction did not return to normal") end

    -- Player / Target distance: follows the cast bars, or a distance you set
    KutzUIDB.castWidth, KutzUIDB.castMargin = 300, 10
    KutzUIDB.castHug, KutzUIDB.spread = true, 999
    L.Apply()
    if L.GetSpread() ~= 320 then problem("cast bars: 'same distance' gap is not width + 2 x margin (" .. tostring(L.GetSpread()) .. ")") end
    local _, _, _, px = PlayerFrame:GetPoint(1)
    if not px or math.abs(px * PlayerFrame:GetScale() + 160) > 0.5 then problem("cast bars: Player is not half the gap left of the centre (" .. tostring(px) .. ")") end
    KutzUIDB.castWidth = 400; L.Apply()
    if L.GetSpread() ~= 420 then problem("cast bars: the frames did not follow a wider cast bar (" .. tostring(L.GetSpread()) .. ")") end
    KutzUIDB.castHug = nil; KutzUIDB.spread = 500; L.Apply()
    if L.GetSpread() ~= 500 then problem("cast bars: a distance you set was not used when 'same distance' is off") end
    L.ResetCastBars(); KutzUIDB.spread = nil
    L.Apply()
end

-- unit tooltips: class colours, faction colours, <guild>, Lvl, symbols
do
    local hook = POSTCALLS[1]
    if not hook or hook.kind ~= Enum.TooltipDataType.Unit then problem("unit tooltips: the post call was not registered for unit tooltips") else
        local style = hook.fn
        local function setLines(t) TIP_LINES = #t; for i, v in ipairs(t) do _G["GameTooltipTextLeft" .. i]._text = v end end
        local function line(i) return tostring(_G["GameTooltipTextLeft" .. i]._text) end
        local function has(i, piece) return line(i):find(piece, 1, true) ~= nil end
        local keep = { UnitExists, UnitIsPlayer, UnitClass, UnitRace, UnitLevel, UnitFactionGroup, GetGuildInfo, GetQuestDifficultyColor }
        local secret = setmetatable({ _secret = true }, { __tostring = function() return "secret" end })
        local keepStatus = { UnitIsAFK, UnitIsDND, UnitIsConnected, UnitIsGhost }
        local afk, dnd, connected, ghost = false, false, true, false
        UnitIsAFK = function() return afk end
        UnitIsDND = function() return dnd end
        UnitIsConnected = function() return connected end
        UnitIsGhost = function() return ghost end
        UnitExists = function() return true end
        UnitIsPlayer = function() return true end
        UnitClass = function() return "Warrior", "WARRIOR" end
        UnitRace = function() return "Human" end
        UnitLevel = function() return 7 end
        UnitFactionGroup = function() return "Alliance", "Alliance" end
        GetGuildInfo = function() return "Example Guild", "Officer", 1 end
        GetQuestDifficultyColor = function() return { r = 1, g = 0.82, b = 0 } end
        for _, k in ipairs({ "ttColorUnits", "ttSymbols", "ttLvl", "ttStatus" }) do KutzUIDB[k] = nil end
        local fresh = { "Example Player", "<Example Guild>", "Level 7 Human Warrior (Player)", "PvP" }

        setLines(fresh); style(GameTooltip)
        if not (has(1, "c79c6e") and has(1, "Example Player") and has(1, "UI-PVP-Alliance")) then problem("unit tooltips: the name line is not class-coloured with the Alliance emblem (" .. line(1) .. ")") end
        if not (has(2, "<Example Guild>") and has(2, "6ee08a")) then problem("unit tooltips: the guild is not in green angle brackets (" .. line(2) .. ")") end
        if has(3, "Level") or not has(3, "Lvl 7") then problem("unit tooltips: 'Level' was not changed to 'Lvl' (" .. line(3) .. ")") end
        if not has(3, "Human") then problem("unit tooltips: the race is missing from the level line (" .. line(3) .. ")") end
        if not (has(3, "Warrior") and has(3, "c79c6e")) then problem("unit tooltips: the class is not on the level line in its colour (" .. line(3) .. ")") end
        if (line(3):find("Human", 1, true) or 0) > (line(3):find("Warrior", 1, true) or 0) then problem("unit tooltips: the class does not come after the race (" .. line(3) .. ")") end
        if has(3, "Alliance") or has(3, "classicon") then problem("unit tooltips: the faction or the class icon is repeated on the level line (" .. line(3) .. ")") end
        if not (has(1, "classicon-warrior") and has(1, "UI-PVP-Alliance")) then problem("unit tooltips: the class icon and faction emblem are not both on the name line (" .. line(1) .. ")") end
        if has(3, "5b8cff") then problem("unit tooltips: the race was coloured by faction although the emblem already shows it (" .. line(3) .. ")") end
        if not has(3, "ffd100") then problem("unit tooltips: the level number is not coloured by difficulty (" .. line(3) .. ")") end
        if has(3, "(Player)") then problem("unit tooltips: '(Player)' was left on the level line") end
        if not has(4, "ff8a3d") then problem("unit tooltips: the PvP line is not coloured") end

        -- status: Away / Busy / Offline / Ghost beside the name, Blizzard's own <Away> replaced
        afk = true
        setLines({ "Example Player <Away>", "<Example Guild>", "Level 7 Human Warrior (Player)" }); style(GameTooltip)
        if not (has(1, "Away") and has(1, "StatusIcon-Away") and has(1, "ffd24d")) or has(1, "<Away>") then problem("unit tooltips: Away is not shown as a yellow status with its icon (" .. line(1) .. ")") end
        if not has(1, "Example Player") then problem("unit tooltips: the name was lost when adding the status") end
        afk, dnd = false, true
        setLines({ "Example Player", "<Example Guild>", "Level 7 Human Warrior (Player)" }); style(GameTooltip)
        if not (has(1, "Busy") and has(1, "StatusIcon-DnD") and has(1, "ff5555")) then problem("unit tooltips: Busy is not shown as a red status (" .. line(1) .. ")") end
        dnd, connected = false, false
        setLines({ "Example Player", "<Example Guild>", "Level 7 Human Warrior (Player)" }); style(GameTooltip)
        if not (has(1, "Offline") and has(1, "StatusIcon-Offline") and has(1, "8a8f99")) then problem("unit tooltips: Offline is not shown as a grey status (" .. line(1) .. ")") end
        connected, ghost = true, true
        setLines({ "Example Player", "<Example Guild>", "Level 7 Human Warrior (Player)" }); style(GameTooltip)
        if not (has(1, "Ghost") and has(1, "9aa0aa")) then problem("unit tooltips: Ghost is not shown (" .. line(1) .. ")") end
        ghost = false
        setLines(fresh); style(GameTooltip)
        if has(1, "Away") or has(1, "Busy") or has(1, "Offline") or has(1, "Ghost") then problem("unit tooltips: a status is shown for a player who has none (" .. line(1) .. ")") end
        setLines({ "Example Player", "<Example Guild>", "Level 7 Human Warrior (Player)", "Dead" }); style(GameTooltip)
        if not (has(4, "d04545") and has(4, "UI-RaidTargetingIcon_8")) then problem("unit tooltips: the Dead line is not coloured with a skull (" .. line(4) .. ")") end
        afk = true
        KutzUIDB.ttStatus = false
        setLines({ "Example Player <Away>", "<Example Guild>", "Level 7 Human Warrior (Player)", "Dead" }); style(GameTooltip)
        if has(1, "StatusIcon") or not has(1, "<Away>") or has(4, "d04545") then problem("unit tooltips: status still changed the tooltip with its switch off (" .. line(1) .. ")") end
        KutzUIDB.ttStatus = nil
        afk = false

        UnitFactionGroup = function() return "Horde", "Horde" end
        setLines(fresh); style(GameTooltip)
        if not (has(1, "UI-PVP-Horde") and not has(3, "Horde")) then problem("unit tooltips: the Horde emblem is not on the name line, or the word is repeated (" .. line(3) .. ")") end

        KutzUIDB.ttSymbols = false
        setLines(fresh); style(GameTooltip)
        if has(1, "UI-PVP") or has(1, "classicon") or has(3, "classicon") then problem("unit tooltips: symbols still show with 'Show symbols' off") end
        if not has(1, "c79c6e") then problem("unit tooltips: colours were lost with symbols off") end
        if not (has(3, "e34747") and has(3, "Human") and has(3, "Warrior") and not has(3, "Horde")) then problem("unit tooltips: with symbols off the race should carry the faction colour and the class should still follow (" .. line(3) .. ")") end
        KutzUIDB.ttSymbols = nil

        KutzUIDB.ttLvl = false
        setLines(fresh); style(GameTooltip)
        if not has(3, "Level 7") or has(3, "Lvl") then problem("unit tooltips: 'Level' was changed although that switch is off (" .. line(3) .. ")") end
        KutzUIDB.ttLvl = nil

        KutzUIDB.ttColorUnits = false
        setLines(fresh); style(GameTooltip)
        if line(1) ~= "Example Player" or line(2) ~= "<Example Guild>" or line(4) ~= "PvP" then problem("unit tooltips: lines were coloured with the colour switch off") end
        if not has(3, "Lvl 7") or has(3, "|c") then problem("unit tooltips: with colours off the level line should only say Lvl (" .. line(3) .. ")") end
        KutzUIDB.ttColorUnits = nil

        UnitClass = function() return secret, secret end                -- the game hides the class
        setLines(fresh); style(GameTooltip)
        if line(1) ~= "Example Player" then problem("unit tooltips: a name was recoloured although the class is hidden (" .. line(1) .. ")") end
        UnitClass = function() return "Warrior", "WARRIOR" end

        UnitIsPlayer = function() return false end                      -- an NPC
        UnitLevel = function() return 10 end
        setLines({ "Brog Hamfist", "General Supplies", "Level 10", "Stormwind", "PvP" }); style(GameTooltip)
        if line(1) ~= "Brog Hamfist" or line(2) ~= "General Supplies" or not has(4, "Stormwind") then problem("unit tooltips: an NPC's name / title lines were changed, or the kingdom was lost") end
        if not (has(3, "Lvl 10") and has(3, "ffd100")) then problem("unit tooltips: an NPC's level line was not 'Lvl 10' in a difficulty colour (" .. line(3) .. ")") end
        -- Blizzard's own separate class and faction lines under the level line are dropped before they are added
        local pre = LINEPRECALLS[1] and LINEPRECALLS[1].fn
        if not (LINEPRECALLS[1] and LINEPRECALLS[1].kind == "ALL") then problem("unit tooltips: the line pre-call was not registered for every line type") end
        UnitIsPlayer = function() return true end
        UnitClass = function() return "Paladin", "PALADIN" end
        UnitFactionGroup = function() return "Alliance", "Alliance" end
        local function dropped(text, lineType) return pre(GameTooltip, { type = lineType or 5, leftText = text }) end
        if not dropped("Paladin") then problem("unit tooltips: the separate class line was not dropped") end
        if not dropped("Alliance") then problem("unit tooltips: the separate faction line was not dropped") end
        if not dropped("|cffff0000Paladin|r") then problem("unit tooltips: a coloured class line was not dropped") end
        if dropped("Human") or dropped("<Citadel>") or dropped("Lvl 7") then problem("unit tooltips: a line that is not the class or faction was dropped") end
        if dropped("Paladin", Enum.TooltipDataLineType.UnitName) then problem("unit tooltips: a player's NAME line was dropped") end
        UnitFactionGroup = function() return "Horde", "Horde" end
        if not dropped("Horde") or dropped("Alliance") then problem("unit tooltips: the faction line is matched against the wrong faction") end
        UnitFactionGroup = function() return "Alliance", "Alliance" end
        KutzUIDB.ttColorUnits = false
        if dropped("Paladin") or dropped("Alliance") then problem("unit tooltips: lines were dropped with the colour switch off (they would be said nowhere)") end
        KutzUIDB.ttColorUnits = nil
        UnitClass = function() return secret, secret end
        if dropped("Paladin") then problem("unit tooltips: the class line was dropped although the class is hidden") end
        UnitClass = function() return "Paladin", "PALADIN" end
        if pre(GameTooltip, { type = 5, leftText = secret }) then problem("unit tooltips: a hidden line was dropped") end
        UnitIsPlayer = function() return false end
        if dropped("Paladin") or dropped("Alliance") then problem("unit tooltips: an NPC's line was dropped") end
        UnitIsPlayer = function() return true end
        UnitClass = function() return "Warrior", "WARRIOR" end

        -- an NPC's kingdom line
        UnitIsPlayer = function() return false end
        UnitFactionGroup = function() return "Alliance", "Alliance" end
        setLines({ "Brog Hamfist", "General Supplies", "Level 10", "Stormwind", "PvP" }); style(GameTooltip)
        if not (has(4, "5b8cff") and has(4, "Stormwind") and has(4, "UI-PVP-Alliance")) then problem("unit tooltips: the Stormwind line is not blue with the Alliance emblem (" .. line(4) .. ")") end
        UnitFactionGroup = function() return "Horde", "Horde" end
        setLines({ "Grunt", "Level 10", "Orgrimmar", "PvP" }); style(GameTooltip)
        if not (has(3, "e34747") and has(3, "UI-PVP-Horde")) then problem("unit tooltips: the Orgrimmar line is not red with the Horde emblem (" .. line(3) .. ")") end
        UnitFactionGroup = function() return nil end
        setLines({ "Trader", "Level 10", "Booty Bay", "PvP" }); style(GameTooltip)
        if not (has(3, "d8b84a") and not has(3, "UI-PVP")) then problem("unit tooltips: a neutral group is not gold without an emblem (" .. line(3) .. ")") end
        UnitFactionGroup = function() return "Alliance", "Alliance" end
        setLines({ "Guard", "Level 10", "Westfall Brigade", "PvP" }); style(GameTooltip)
        if not (has(3, "5b8cff") and has(3, "Westfall Brigade")) then problem("unit tooltips: an unlisted group right under the level was not coloured by its side (" .. line(3) .. ")") end
        setLines({ "Guard", "Level 10", "Quest: 3 wolves", "Westfall Brigade" }); style(GameTooltip)
        if line(3) ~= "Quest: 3 wolves" or line(4) ~= "Westfall Brigade" then problem("unit tooltips: a line that is not right under the level was treated as a kingdom") end
        UnitFactionGroup = function() return nil end
        setLines({ "Critter", "Level 1", "Tameable" }); style(GameTooltip)
        if line(3) ~= "Tameable" then problem("unit tooltips: an unaligned NPC's extra line was recoloured (" .. line(3) .. ")") end
        UnitFactionGroup = function() return "Alliance", "Alliance" end
        KutzUIDB.ttSymbols = false
        setLines({ "Brog Hamfist", "General Supplies", "Level 10", "Stormwind", "PvP" }); style(GameTooltip)
        if has(4, "UI-PVP") or not has(4, "5b8cff") then problem("unit tooltips: the kingdom emblem shows with symbols off (" .. line(4) .. ")") end
        KutzUIDB.ttSymbols = nil
        KutzUIDB.ttColorUnits = false
        setLines({ "Brog Hamfist", "General Supplies", "Level 10", "Stormwind", "PvP" }); style(GameTooltip)
        if line(4) ~= "Stormwind" then problem("unit tooltips: the kingdom was coloured with the colour switch off") end
        KutzUIDB.ttColorUnits = nil
        UnitFactionGroup = function() return "Horde", "Horde" end

        setLines({ "Boss", "Level ?? Elite" }); style(GameTooltip)
        if not (has(2, "Lvl ??") and has(2, "ff3333") and has(2, "Elite")) then problem("unit tooltips: a ?? level was not shown in red (" .. line(2) .. ")") end

        UnitExists, UnitIsPlayer, UnitClass, UnitRace, UnitLevel, UnitFactionGroup, GetGuildInfo, GetQuestDifficultyColor =
            keep[1], keep[2], keep[3], keep[4], keep[5], keep[6], keep[7], keep[8]
        UnitIsAFK, UnitIsDND, UnitIsConnected, UnitIsGhost = keepStatus[1], keepStatus[2], keepStatus[3], keepStatus[4]
        TIP_LINES = 0
    end
end

-- tooltip placement: what is the tooltip about, and where does it go
do
    local function fake(name, fields)
        local o = new("Button")
        o.GetName = function() return name end
        for k, v in pairs(fields or {}) do o[k] = v end
        return o
    end
    local keepExists, keepIsPlayer = UnitExists, UnitIsPlayer
    UnitExists = function(u) return u == "mouseover" end
    UnitIsPlayer = function(u) return true end
    if ns.TTClassify(UIParent) ~= "player" then problem("tooltip placement: a player under the mouse was not recognised") end
    UnitIsPlayer = function(u) return false end
    if ns.TTClassify(UIParent) ~= "npc" then problem("tooltip placement: an NPC under the mouse was not recognised") end
    UnitExists = function(u) return false end
    if ns.TTClassify(UIParent) ~= "object" then problem("tooltip placement: a world object was not recognised") end
    UnitExists, UnitIsPlayer = keepExists, keepIsPlayer

    local expect = {
        { fake("ActionButton1"), "actionbar" }, { fake("MultiBarBottomLeftButton3"), "actionbar" }, { fake("StanceButton2"), "actionbar" },
        { fake("ContainerFrame1Item4"), "item" }, { fake(nil, { GetBagID = function() return 1 end }), "item" }, { fake("CharacterHeadSlot"), "item" },
        { fake("CompactPartyFrameMember2", { unit = "party2" }), "party" }, { fake("PartyMemberFrame1"), "party" },
        { fake("CompactRaidFrame7", { unit = "raid7" }), "raid" },
        { fake("PlayerFrame", { unit = "player" }), "myframes" }, { fake("TargetFrame", { unit = "target" }), "myframes" },
        { fake("BuffButton3"), "aura" }, { fake(nil, { auraInstanceID = 12 }), "aura" },
        { fake("SomethingElseEntirely"), "other" },
    }
    for _, e in ipairs(expect) do
        local got = ns.TTClassify(e[1])
        if got ~= e[2] then problem("tooltip placement: " .. tostring(e[1]:GetName()) .. " was '" .. got .. "', expected '" .. e[2] .. "'") end
    end
    -- a unit frame found a level up (a name text inside a party frame)
    local child = fake("PartyNameText", {}); child.GetParent = function() return expect[7][1] end
    if ns.TTClassify(child) ~= "party" then problem("tooltip placement: a part of a party frame was not recognised as a party member") end

    -- placing
    local tt = GameTooltip
    local owner = fake("ActionButton1")
    tt.GetOwner = function() return owner end
    tt._shown = true
    tt._scale = 1
    ns.ResetTooltip()
    tt:ClearAllPoints(); tt:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 5, 5)
    tickAll(0.2)
    local _, rel0 = tt:GetPoint(1)
    if rel0 ~= owner then problem("tooltip placement: 'Blizzard's usual spot' still moved the tooltip") end

    ns.SetTTWhere("actionbar", "loc2"); tickAll(0.2)
    local wantPoint, wantX, wantY = ns.TTAnchorFor(2)
    local gp, grel, grp, gx, gy = tt:GetPoint(1)
    if gp ~= wantPoint or grel ~= UIParent or grp ~= "BOTTOMLEFT" or math.abs(gx - wantX) > 0.01 or math.abs(gy - wantY) > 0.01 then
        problem("tooltip placement: an action button tooltip did not go to location 2 (" .. tostring(gp) .. " " .. tostring(gx) .. "," .. tostring(gy) .. ")")
    end
    tt._scale = 2; tickAll(0.2)
    local _, _, _, gx2 = tt:GetPoint(1)
    if math.abs(gx2 - wantX / 2) > 0.01 then problem("tooltip placement: the tooltip's own size was not allowed for (" .. tostring(gx2) .. ")") end
    tt._scale = 1

    ns.SetTTWhere("actionbar", "cursor"); cursorX, cursorY = 500, 400; tickAll(0.2)
    local cp, _, _, cx, cy = tt:GetPoint(1)
    if cp ~= "BOTTOMLEFT" or math.abs(cx - 518) > 0.01 or math.abs(cy - 418) > 0.01 then problem("tooltip placement: not on the cursor (" .. tostring(cp) .. " " .. tostring(cx) .. "," .. tostring(cy) .. ")") end
    cursorX, cursorY = 1900, 1200; tickAll(0.2)                                    -- top right of a 2000 x 1300 screen
    local cp2, _, _, cx2, cy2 = tt:GetPoint(1)
    if cp2 ~= "TOPRIGHT" or math.abs(cx2 - 1882) > 0.01 or math.abs(cy2 - 1182) > 0.01 then problem("tooltip placement: the cursor tooltip did not switch sides near the edge (" .. tostring(cp2) .. ")") end

    -- another kind of thing is not affected
    local itemOwner = fake("ContainerFrame1Item2")
    tt.GetOwner = function() return itemOwner end
    tt:ClearAllPoints(); tt:SetPoint("BOTTOMLEFT", itemOwner, "TOPRIGHT", 5, 5)
    tickAll(0.2)
    local _, rel5 = tt:GetPoint(1)
    if rel5 ~= itemOwner then problem("tooltip placement: a rule for action buttons moved an item tooltip") end

    -- the settings from older versions become the new ones, once
    local keepLoc, keepWhere = KutzUIDB.ttLoc, KutzUIDB.ttWhere
    KutzUIDB.ttLoc, KutzUIDB.ttWhere = nil, nil
    KutzUIDB.tooltip, KutzUIDB.tooltipCursor = { x = 100, y = 200 }, nil
    ns.TTMigrate()
    if not (KutzUIDB.ttLoc and KutzUIDB.ttLoc[1] and KutzUIDB.ttLoc[1].x == 100) or KutzUIDB.ttWhere.player ~= "loc1" or KutzUIDB.ttWhere.object ~= "loc1" or KutzUIDB.ttWhere.item then
        problem("tooltip placement: the old tooltip box was not carried over")
    end
    if KutzUIDB.tooltip ~= nil then problem("tooltip placement: the old setting was left behind") end
    KutzUIDB.ttLoc, KutzUIDB.ttWhere = nil, nil
    KutzUIDB.tooltipCursor = true
    ns.TTMigrate()
    if KutzUIDB.ttWhere.npc ~= "cursor" then problem("tooltip placement: the old 'follow the cursor' was not carried over") end
    KutzUIDB.ttLoc, KutzUIDB.ttWhere = keepLoc, keepWhere

    tt.GetOwner = nil
    ns.ResetTooltip()
end

-- fps and latency readout
do
    for _, k in ipairs({ "fpsShow", "fpsPlace", "fpsX", "fpsY", "fpsSize", "fpsAlpha" }) do KutzUIDB[k] = nil end
    tickAll(0.6)
    local f = KutzFpsReadout
    if not f then problem("fps readout: the readout frame was not created")
    else
        if f.text._text ~= "144 fps  40 ms" then problem("fps readout: wrong text (" .. tostring(f.text._text) .. ")") end
        local p, rel, rp, x, y = f:GetPoint(1)
        if p ~= "TOPLEFT" or rel ~= UIParent or x ~= 6 or y ~= -6 then problem("fps readout: not in the top-left corner by default (" .. tostring(p) .. ")") end
        KutzUIDB.fpsX, KutzUIDB.fpsY = 20, -10; ns.SetFpsOption("fpsX", 20); tickAll(0.6)
        local _, _, _, x2, y2 = f:GetPoint(1)
        if x2 ~= 26 or y2 ~= -16 then problem("fps readout: offsets were not applied (" .. tostring(x2) .. ", " .. tostring(y2) .. ")") end
        KutzUIDB.fpsX, KutzUIDB.fpsY = nil, nil
        ns.SetFpsOption("fpsPlace", "minimap"); tickAll(0.6)
        local p3, rel3 = f:GetPoint(1)
        if p3 ~= "TOPRIGHT" or rel3 ~= MinimapCluster then problem("fps readout: 'left of the minimap' is not anchored to the minimap") end
        ns.SetFpsOption("fpsPlace", "top"); tickAll(0.6)
        local p4 = f:GetPoint(1)
        if p4 ~= "TOP" then problem("fps readout: 'top centre' did not move it") end
        ns.SetFpsOption("fpsPlace", "topleft"); ns.SetFpsOption("fpsAlpha", 40); tickAll(0.6)
        if math.abs(f._alpha - 0.4) > 0.001 then problem("fps readout: opacity was not applied") end
        ns.SetFpsOption("fpsShow", false); tickAll(0.6)
        if f._shown then problem("fps readout: it is still shown after switching it off") end
        ns.ResetFpsSettings(); tickAll(0.6)
        if not f._shown then problem("fps readout: reset did not show it again") end
    end
end

-- damage meter: on switch, swap between combat log and meter, never losing both
do
    local function settle() tickAll(0.3); tickAll(0.3) end
    local function quick() return _G.CombatLogQuickButtonFrameButton1 end
    SetCVar("damageMeterEnabled", "0"); dmAvailable = true
    KutzUIDB.dmButton, KutzUIDB.dmMode = nil, nil                  -- (the menu click-through above left them anywhere)
    -- the meter's code is not loaded: switching it on asks the game to load it, and the answer is kept
    local keepMeter = DamageMeter
    _G.DamageMeter = nil
    ns.dmLoadResult = nil
    ns.SetDMEnabled(true)
    if not LOAD_REQUESTS["Blizzard_DamageMeter"] then problem("damage meter: switching it on did not ask the game to load Blizzard's meter") end
    if not (ns.dmLoadResult and ns.dmLoadResult.ok == false and ns.dmLoadResult.reason == "MISSING") then problem("damage meter: the game's answer to the load request was not kept") end
    _G.DamageMeter = keepMeter
    SetCVar("damageMeterEnabled", "0")
    ns.SetDMMode("both"); settle()
    if DamageMeter._alpha ~= 1 or dmWindow._alpha ~= 1 then problem("damage meter: hidden although both should show") end
    if ChatFrame2._alpha == 0 then problem("damage meter: the combat log is hidden although both should show") end

    ns.SetDMMode("log"); settle()
    if DamageMeter._alpha ~= 0 or dmWindow._alpha ~= 0 then problem("damage meter: not hidden in 'combat log only'") end
    if ChatFrame2._alpha == 0 then problem("damage meter: the combat log was hidden in 'combat log only'") end

    ns.SetDMMode("meter"); settle()                                    -- the meter is OFF: the log must stay
    if ChatFrame2._alpha == 0 then problem("damage meter: the combat log was hidden although the meter is off (you would see nothing)") end

    ns.SetDMEnabled(true); settle()
    if ChatFrame2._alpha ~= 0 or ChatFrame2._mouse ~= false then problem("damage meter: 'meter only' did not hide the combat log") end
    if quick()._alpha ~= 0 then problem("damage meter: the log's filter buttons are still visible in 'meter only'") end
    if DamageMeter._alpha == 0 or dmWindow._alpha == 0 then problem("damage meter: the meter is hidden in 'meter only'") end

    dmAvailable, dmReason = false, "not here"; settle()                -- the game says no: bring the log back
    if ChatFrame2._alpha == 0 then problem("damage meter: the log stayed hidden although the meter is unavailable") end
    dmAvailable, dmReason = true, nil; settle()
    if ChatFrame2._alpha ~= 0 then problem("damage meter: 'meter only' did not come back when the meter became available") end

    ns.SetDMMode("both"); settle()
    if ChatFrame2._alpha == 0 or ChatFrame2._mouse == false then problem("damage meter: the combat log was not given back") end
    if quick()._alpha == 0 then problem("damage meter: the filter buttons were not given back") end

    -- the button and the slash command
    SlashCmdList.KUTZUI("meter meter")
    if ns.DMMode() ~= "meter" then problem("damage meter: /kutz meter meter did not switch to the meter") end
    SlashCmdList.KUTZUI("meter")
    if ns.DMMode() ~= "log" then problem("damage meter: /kutz meter did not toggle back to the log") end
    SlashCmdList.KUTZUI("meter both")
    if ns.DMMode() ~= "both" then problem("damage meter: /kutz meter both did not show both") end
    settle()
    local sw = KutzMeterSwapButton
    if not sw then problem("damage meter: the Log / Meter button was not created")
    else
        sw._scripts.OnClick(sw)
        if ns.DMMode() ~= "meter" then problem("damage meter: clicking the button did not switch to the meter") end
        sw._scripts.OnClick(sw)
        if ns.DMMode() ~= "log" then problem("damage meter: clicking the button again did not switch back") end
    end
    SetCVar("damageMeterEnabled", "0")                                 -- the meter is off again: a click must not hide the log
    ns.SetDMMode("both")
    sw = KutzMeterSwapButton
    if sw then sw._scripts.OnClick(sw) end
    if ns.DMMode() == "meter" then problem("damage meter: the button switched to a meter that is off") end
    ns.SetDMMode("both"); settle()
end

-- copy chat: plain text, ordering of a ring that has wrapped, unreadable lines, and the window
do
    local plain = ns.ChatPlainText("|cffff0000red|r |Hplayer:Bob:1|h[Bob]|h |TInterface\\Icon:0|t |Kq1|k pipe||done")
    if not (plain:find("red [Bob]", 1, true) and plain:find("?", 1, true) and plain:find("pipe|done", 1, true)) or plain:find("|c", 1, true) or plain:find("|H", 1, true) then
        problem("copy chat: formatting codes were not turned into plain text (" .. plain .. ")")
    end

    local ordered, uncertain = ns.ChatCopyOrder({ { text = "a", id = 1 }, { text = "b", id = 2 }, { text = "c" } })
    if uncertain or ordered[1].text ~= "a" or ordered[3].text ~= "c" then problem("copy chat: lines already in order were changed") end
    ordered, uncertain = ns.ChatCopyOrder({ { text = "9", id = 9 }, { text = "10", id = 10 }, { text = "n", id = nil },
        { text = "5", id = 5 }, { text = "6", id = 6 }, { text = "7", id = 7 } })
    local names = {}
    for _, e in ipairs(ordered) do names[#names + 1] = e.text end
    if uncertain or table.concat(names, ",") ~= "5,6,7,9,10,n" then problem("copy chat: a wrapped ring was not turned around the right place (" .. table.concat(names, ",") .. ")") end
    local _, bad = ns.ChatCopyOrder({ { text = "x", id = 5 }, { text = "y", id = 3 }, { text = "z", id = 8 }, { text = "w", id = 1 } })
    if not bad then problem("copy chat: a list with two order breaks was not flagged as uncertain") end

    local ring = { { "line 9", 9 }, { "line 10", 10 }, { "line 11", 11 }, { "line 5", 5 }, { "line 6", 6 }, { "line 7", 7 }, { "line 8", 8 } }
    local fake = new("ScrollingMessageFrame", "ChatFrame9")
    local secretLine = setmetatable({ _secret = true }, { __tostring = function() return "secret" end })
    local transformCalled = false
    fake.TransformMessages = function(self, pred, xform)
        for _, e in ipairs(ring) do pred(e[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_SAY", { [11] = e[2] }) end
        pred(secretLine, 1, 1, 1)
        pred(42, 1, 1, 1)
    end
    local text, lines, hidden, unsure = ns.ChatCopyCapture(fake)
    if text ~= "line 5\nline 6\nline 7\nline 8\nline 9\nline 10\nline 11" or lines ~= 7 then problem("copy chat: wrong text or order (" .. text:gsub("\n", "|") .. ")") end
    if hidden ~= 2 then problem("copy chat: unreadable lines were not counted (" .. tostring(hidden) .. ")") end

    ns.ChatCopyOpen(fake)
    local win = KutzCopyChatFrame
    if not win or not win._shown then problem("copy chat: the window did not open")
    elseif not tostring(win.edit._text):find("line 11", 1, true) then problem("copy chat: the window does not show the chat text") end
    SlashCmdList.KUTZUI("copy")                                   -- the slash command opens it too
    win:Hide()

    ChatFrame1.SetMaxLines = function(self, n) self._maxlines = n end
    ChatFrame2.SetMaxLines = function(self, n) self._maxlines = n end
    KutzUIDB.chatHistoryLines = 300
    tickAll(0.3); tickAll(0.3)
    if ChatFrame1._maxlines ~= 300 then problem("copy chat: the chat history length was not applied") end
    if ChatFrame2._maxlines ~= nil then problem("copy chat: the combat log's history length was changed") end
    KutzUIDB.chatHistoryLines = nil
end

-- chat tweaks: buttons, scroll bar and tabs
do
    ChatFrame1.ScrollBar = new("Frame"); ChatFrame1.buttonFrame = new("Frame")
    ChatFrame1Tab = new("Button", "ChatFrame1Tab")
    local function settle() tickAll(0.3); tickAll(0.3) end
    KutzUIDB.chatHideButtons, KutzUIDB.chatHideScrollbar, KutzUIDB.chatFadeTabs = nil, nil, nil
    settle()
    if ChatFrameMenuButton._alpha ~= 0 or QuickJoinToastButton._alpha ~= 0 or ChatFrameChannelButton._alpha ~= 0 then problem("chat tweaks: the chat buttons are not hidden by default") end
    if ChatFrame1.buttonFrame._alpha ~= 0 then problem("chat tweaks: the button frame is not hidden by default") end
    if ChatFrame1.ScrollBar._alpha ~= 0 then problem("chat tweaks: the scroll bar is not hidden by default") end
    if ChatFrame1Tab._alpha ~= 0 then problem("chat tweaks: the tab is not faded away when the mouse is elsewhere") end
    ChatFrame1.IsMouseOver = function() return true end
    settle()
    if ChatFrame1Tab._alpha ~= 1 then problem("chat tweaks: the tab did not come back when the mouse is over the chat") end
    ChatFrame1.IsMouseOver = nil
    settle()
    if ChatFrame1Tab._alpha ~= 0 then problem("chat tweaks: the tab did not fade away again") end
    KutzUIDB.chatHideButtons, KutzUIDB.chatHideScrollbar, KutzUIDB.chatFadeTabs = false, false, false
    settle()
    if ChatFrameMenuButton._alpha == 0 or ChatFrame1.ScrollBar._alpha == 0 or ChatFrame1Tab._alpha == 0 then problem("chat tweaks: switching them off did not bring everything back") end
    KutzUIDB.chatHideButtons, KutzUIDB.chatHideScrollbar, KutzUIDB.chatFadeTabs = nil, nil, nil
    settle()
end

-- tooltip fade-out: shortened after the game starts its own fade
do
    local tt = GameTooltip
    tt._shown, tt._alpha = true, 1
    ns.SetTTOption("ttFadeMs", 200)
    tickAll(0.016)
    if tt._alpha ~= 1 or not tt._shown then problem("tooltip fade: a normal tooltip was touched") end
    tt._alpha = 0.9                                      -- the game's own fade has begun
    clock = clock + 1
    tickAll(0.016)                                       -- we notice it
    clock = clock + 0.05
    tickAll(0.016)
    local first = tt._alpha
    if first >= 0.9 or not tt._shown then problem("tooltip fade: our quicker fade did not take over (" .. tostring(first) .. ")") end
    tt._alpha = 0.8                                      -- the game keeps fading it ...
    clock = clock + 0.1
    tickAll(0.016)
    if not tt._shown or tt._alpha >= 0.8 then problem("tooltip fade: no progress half way (" .. tostring(tt._alpha) .. ")") end
    tt._alpha = 0.7
    clock = clock + 0.2                                  -- ... but ours is over after 200 ms
    tickAll(0.016)
    if tt._shown then problem("tooltip fade: the tooltip was still shown after our fade time") end
    if tt._alpha ~= 1 then problem("tooltip fade: the alpha was not reset for the next tooltip (" .. tostring(tt._alpha) .. ")") end

    tt._shown, tt._alpha = true, 0.5
    ns.SetTTOption("ttFadeMs", 0); clock = clock + 5
    tickAll(0.016)
    if tt._shown then problem("tooltip fade: 0 ms did not hide it at once") end

    tt._shown, tt._alpha = true, 0.5
    ns.SetTTOption("ttFadeMs", ns.TT_FADE_MAX); clock = clock + 5
    tickAll(0.016); clock = clock + 5; tickAll(0.016)
    if not tt._shown or tt._alpha ~= 0.5 then problem("tooltip fade: 'Blizzard's own' still changed the fade") end
    tt._shown, tt._alpha = false, 1
    ns.ResetTTSettings()
end

-- tooltip tweaks: health bar and size
do
    local function settle() tickAll(0.3); tickAll(0.3) end
    ns.ResetTTSettings(); settle()
    if GameTooltip.StatusBar._alpha == 0 then problem("tooltip tweaks: the health bar is hidden by default") end
    ns.SetTTOption("ttHideHealthBar", true); settle()
    if GameTooltip.StatusBar._alpha ~= 0 then problem("tooltip tweaks: the health bar did not hide") end
    ns.SetTTOption("ttHideHealthBar", false); settle()
    if GameTooltip.StatusBar._alpha ~= 1 then problem("tooltip tweaks: the health bar did not come back") end
    ns.SetTTOption("ttScale", 150); settle()
    if math.abs(GameTooltip._scale - 1.5) > 0.001 or math.abs(ItemRefTooltip._scale - 1.5) > 0.001 then problem("tooltip tweaks: the size was not applied") end
    ns.ResetTTSettings(); settle()
    if math.abs(GameTooltip._scale - 1) > 0.001 then problem("tooltip tweaks: reset did not restore the size") end
end

-- profiles: save / load / follow changes / per character / export and import
do
    local db = KutzUIDB
    local keep = { spread = db.spread, font = db.font, profiles = db.profiles, active = db.activeProfile, char = db.charProfile }
    db.profiles, db.activeProfile, db.charProfile = nil, nil, nil
    db.spread, db.font = 123, "robotomono"
    local ok, name = ns.ProfileSave("  Tank  ")
    if not ok or name ~= "Tank" then problem("profiles: saving did not clean the name") end
    if ns.ProfileActive() ~= "Tank" then problem("profiles: a saved profile did not become active") end
    ns.ProfileSave("Heal")                      -- a copy of the current settings, now the active profile
    db.spread = 456                             -- a change made while Heal is active
    ns.ProfileLoad("Tank")
    if KutzUIDB.spread ~= 123 then problem("profiles: loading did not restore the saved value (" .. tostring(KutzUIDB.spread) .. ")") end
    KutzUIDB.spread = 777                       -- a change while Tank is active ...
    ns.ProfileLoad("Heal"); ns.ProfileLoad("Tank")
    if KutzUIDB.spread ~= 777 then problem("profiles: the active profile did not follow changes made while it was active") end
    local snap = ns.ProfileSnapshot()
    if snap.profiles or snap.charProfile or snap.activeProfile then problem("profiles: a profile contains the profile list itself") end

    ns.ProfileAssign("Heal"); ns.ProfileApplyForCharacter()
    if ns.ProfileActive() ~= "Heal" or KutzUIDB.spread ~= 456 then problem("profiles: the character's own profile was not applied at startup") end

    if ns.ProfileSave("   ") then problem("profiles: an empty name was accepted") end
    if ns.ProfileSave(string.rep("x", 40)) then problem("profiles: a 40-character name was accepted") end

    -- export / import
    local text = ns.ProfileExport()
    if text:sub(1, 6) ~= "KUTZ1:" or text:find("[|\n]") then problem("profiles: the export text has the wrong shape") end
    local settings, err = ns.ProfileParse(text)
    if not settings then problem("profiles: the export could not be imported again: " .. tostring(err))
    elseif settings.spread ~= KutzUIDB.spread or settings.font ~= KutzUIDB.font then problem("profiles: the imported values differ from the exported ones") end
    local wrapped = text:sub(1, 30) .. "\n  " .. text:sub(31, 80) .. "\r\n" .. text:sub(81)
    if not ns.ProfileParse(wrapped) then problem("profiles: an export that was wrapped onto several lines was rejected") end
    if ns.ProfileParse(text:sub(1, #text - 8)) then problem("profiles: a cut-off export was accepted") end
    if ns.ProfileParse(text:sub(1, #text - 3) .. "AAA") then problem("profiles: a damaged export was accepted") end
    if ns.ProfileParse("hello") or ns.ProfileParse("") or ns.ProfileParse(nil) then problem("profiles: nonsense was accepted as an export") end
    if ns.ProfileParse("KUTZ1:00000000:" .. string.rep("A", 40)) then problem("profiles: an export with a wrong checksum was accepted") end
    if ns.ProfileParse(string.rep("A", 400000)) then problem("profiles: a huge text was accepted") end

    -- settings that cannot be written down must not produce an export
    KutzUIDB.deepTest = {}
    local cur = KutzUIDB.deepTest
    for i = 1, 12 do cur.x = {}; cur = cur.x end
    if pcall(ns.ProfileExport) then problem("profiles: settings nested too deep were exported") end
    KutzUIDB.deepTest = nil
    KutzUIDB.fnTest = function() end
    if pcall(ns.ProfileExport) then problem("profiles: a function was exported") end
    KutzUIDB.fnTest = nil

    local imported = ns.ProfileCreate("Imported", settings)
    if not imported or not KutzUIDB.profiles["Imported"] then problem("profiles: importing did not create a profile") end
    ns.ProfileDelete("Heal")
    if ns.ProfileAssigned() ~= nil or ns.ProfileActive() == "Heal" then problem("profiles: deleting a profile left it assigned / active") end

    -- every character gets a profile of its own on its first login, a copy of the settings in use
    local keepRealm = GetRealmName
    GetRealmName = function() return "Forever" end
    db.charProfile = nil
    KutzUIDB.spread = 321
    ns.ProfileApplyForCharacter()
    local own = "Tester-Forever"
    if ns.ProfileAssigned() ~= own or ns.ProfileActive() ~= own then problem("profiles: a new character did not get (and use) a profile of its own: " .. tostring(ns.ProfileAssigned())) end
    if not (KutzUIDB.profiles[own] and KutzUIDB.profiles[own].spread == 321) or KutzUIDB.spread ~= 321 then problem("profiles: the new character's profile is not a copy of the settings in use") end
    KutzUIDB.spread = 654; ns.ProfileSync()
    if KutzUIDB.profiles[own].spread ~= 654 then problem("profiles: the character's own profile does not follow its changes") end
    -- another character logging in afterwards starts from those settings, and the first keeps its own
    local keepName = UnitName
    UnitName = function() return "Alt" end
    ns.ProfileApplyForCharacter()
    if ns.ProfileActive() ~= "Alt-Forever" then problem("profiles: a second character did not get its own profile") end
    KutzUIDB.spread = 999; ns.ProfileSync()
    UnitName = keepName
    ns.ProfileApplyForCharacter()
    if ns.ProfileActive() ~= own or KutzUIDB.spread ~= 654 then problem("profiles: going back to the first character did not bring its own settings back (" .. tostring(KutzUIDB.spread) .. ")") end
    -- opting out ("Char" clicked off) stores false, and no new profile is made for it
    ns.ProfileAssign(false); KutzUIDB.profiles[own] = nil
    ns.ProfileApplyForCharacter()
    if ns.ProfileAssigned() ~= false or KutzUIDB.profiles[own] then problem("profiles: a character that chose no profile got a new one anyway") end
    -- a name the game doesn't know yet: nothing is made
    db.charProfile = nil
    UnitName = function() return nil end
    if ns.ProfileEnsureCharacter() or (db.charProfile and next(db.charProfile)) then problem("profiles: a profile was made for an unknown character") end
    UnitName, GetRealmName = keepName, keepRealm

    db.profiles, db.activeProfile, db.charProfile = keep.profiles, keep.active, keep.char
    db.spread, db.font = keep.spread, keep.font
end

-- minimap: buttons hide / show on their own, the clock moves, other addons' buttons are found
do
    local function settle() tick(0.6); tick(0.6) end
    if KutzUIDB then KutzUIDB.mmShow, KutzUIDB.mmAddon, KutzUIDB.mmClock = nil, nil, nil end
    ns.ResetMinimap(); settle()
    if GameTimeFrame._alpha ~= 0 then problem("minimap: the calendar is not hidden by default") end
    if MinimapCluster.Tracking._alpha ~= 0 then problem("minimap: tracking is not hidden by default") end
    if Minimap.ZoomIn._alpha ~= 0 or Minimap.ZoomOut._alpha ~= 0 then problem("minimap: the zoom buttons are not hidden by default") end
    if MinimapCluster.IndicatorFrame.MailFrame._alpha == 0 then problem("minimap: the mail icon (an alert) was hidden by default") end
    if QueueStatusButton._alpha == 0 then problem("minimap: the group finder eye (an alert) was hidden by default") end
    if MinimapCluster.ZoneTextButton._alpha == 0 then problem("minimap: the zone name bar was hidden by default") end
    if addonIcon._alpha ~= 0 then problem("minimap: another addon's button is not hidden by default") end
    local p1, r1 = TimeManagerClockButton:GetPoint(1)
    if p1 ~= "TOPRIGHT" or r1 ~= UIParent then problem("minimap: the clock is not in the screen corner by default") end
    if #ns.MMAddonButtons() ~= 1 then problem("minimap: the addon button was not found") end

    ns.SetMMShown("calendar", true); settle()
    if GameTimeFrame._alpha == 0 then problem("minimap: the calendar did not come back") end
    ns.SetMMShown("mail", false); settle()
    if MinimapCluster.IndicatorFrame.MailFrame._alpha ~= 0 then problem("minimap: the mail icon was not hidden on request") end
    ns.SetMMAddonShown("FakeAddon", true); settle()
    if addonIcon._alpha == 0 then problem("minimap: the addon button did not come back") end

    ns.SetMMClockMode("bar"); settle()
    local p2, r2 = TimeManagerClockButton:GetPoint(1)
    if r2 ~= MinimapCluster.ZoneTextButton then problem("minimap: the clock did not move to the zone bar") end
    ns.SetMMClockMode("default"); settle()
    local p3, r3, _, x3 = TimeManagerClockButton:GetPoint(1)
    if r3 ~= MinimapCluster.ZoneTextButton or x3 ~= -4 then problem("minimap: the clock did not go back to Blizzard's spot") end
    ns.SetMMClockMode("hidden"); settle()
    if TimeManagerClockButton._alpha ~= 0 then problem("minimap: the clock was not hidden") end
    ns.SetMMClockMode("corner"); settle()
    if TimeManagerClockButton._alpha == 0 then problem("minimap: the clock did not come back") end

    ns.ShowEverythingOnMinimap(); settle()
    if GameTimeFrame._alpha == 0 or Minimap.ZoomIn._alpha == 0 then problem("minimap: 'show everything' left something hidden") end
    ns.ResetMinimap(); settle()
    if GameTimeFrame._alpha ~= 0 then problem("minimap: reset did not return to the clean look") end
    if KutzUIDB then KutzUIDB.mmShow, KutzUIDB.mmAddon, KutzUIDB.mmClock = nil, nil, nil end
end

-- party targets: clickable bars for each member's target, and for that target's target
do
    if not ns.PTTick then problem("party targets: not loaded") else
        ns.ResetPTSettings()
        local member = new("Button", "FakePartyMember1"); member.unit = "party1"; member._shown = true
        local mine = new("Button", "FakeCompactPlayer"); mine.unit = "player"; mine._shown = true
        local second = new("Button", "FakeCompactParty2"); second.unit = "party2"; second._shown = true
        local keepParty, keepCompact = _G.PartyFrame, _G.CompactPartyFrame
        PartyFrame = { MemberFrame1 = member }
        CompactPartyFrame = { memberUnitFrames = { mine, second } }
        local keep = { UnitExists, UnitName, UnitIsPlayer, UnitClass, UnitReaction, UnitHealth, UnitHealthMax, InCombatLockdown }
        local hidden = setmetatable({ _secret = true }, { __tostring = function() return "secret" end })
        local exists = { party1target = true, party1targettarget = true }
        local names = { party1target = "Hogger", party1targettarget = "Jaina" }
        local combat = false
        UnitExists = function(u) return exists[u] == true end
        UnitName = function(u) return names[u] end
        UnitIsPlayer = function(u) return u == "party1targettarget" end
        UnitClass = function() return "Mage", "MAGE" end
        UnitReaction = function() return 2 end
        UnitHealth = function() return 40 end
        UnitHealthMax = function() return 100 end
        InCombatLockdown = function() return combat end
        local keepFBC = FACTION_BAR_COLORS
        FACTION_BAR_COLORS = FACTION_BAR_COLORS or { [2] = { r = 1, g = 0, b = 0 } }
        local hostile = FACTION_BAR_COLORS[2]

        ns.PTTick()
        local s1, s2 = ns.PTSlots[1], ns.PTSlots[2]
        if not (s1 and s2) then problem("party targets: no bars were made for the party slots") else
            local t, tt = s1.target, s1.tot
            if t:GetAttribute("unit") ~= "party1target" or tt:GetAttribute("unit") ~= "party1targettarget" then problem("party targets: the bars are not set to the right units") end
            if t:GetAttribute("*type1") ~= "target" or t:GetAttribute("*type2") ~= "togglemenu" then problem("party targets: a left click does not target / a right click does not open the menu") end
            if not t.watched or not tt.watched then problem("party targets: the bars were not handed to the game's unit watch") end
            local _, rel, rp = t:GetPoint(1)
            if rel ~= member or rp ~= "RIGHT" then problem("party targets: the target bar is not to the right of the party frame") end
            local _, rel2 = tt:GetPoint(1)
            if rel2 ~= t then problem("party targets: the target's-target bar is not to the right of the target bar") end
            local _, rel3 = s2.target:GetPoint(1)
            if rel3 ~= second then problem("party targets: party2's bar is not beside its raid-style frame") end
            if t.text._text ~= "Hogger" or tt.text._text ~= "Jaina" then problem("party targets: wrong names (" .. tostring(t.text._text) .. ", " .. tostring(tt.text._text) .. ")") end
            local m = RAID_CLASS_COLORS.MAGE
            local c = tt.health._color
            if not (c and math.abs(c[1] - m.r) < 0.01) then problem("party targets: a player is not in their class colour") end
            c = t.health._color
            if not (c and math.abs(c[1] - hostile.r) < 0.01 and math.abs(c[2] - hostile.g) < 0.01) then problem("party targets: a hostile creature is not in the hostile colour") end

            ns.SetPTOption("ptColorMode", "custom"); ns.SetPTOption("ptColorTarget", "00ff00"); ns.PTTick()
            c = t.health._color
            if not (c and c[1] == 0 and c[2] == 1 and c[3] == 0) then problem("party targets: the picked colour was not used") end
            ns.SetPTOption("ptColorMode", nil)

            names.party1target = hidden; ns.PTTick()
            if t.text._text ~= hidden then problem("party targets: a hidden name was not handed straight to the text") end
            names.party1target = "Hogger"

            -- in combat nothing protected is touched; the change lands when the fight ends
            combat = true
            ns.SetPTOption("ptToT", false); ns.SetPTOption("ptWidth", 150); ns.PTTick()
            if not tt.watched or t.width == 150 then problem("party targets: a protected bar was changed in combat") end
            names.party1target = "Ragnaros"; ns.PTTick()
            if t.text._text ~= "Ragnaros" then problem("party targets: the name did not update in combat") end
            combat = false; ns.PTTick()
            if tt.watched or tt._shown then problem("party targets: switching the target's-target bar off did not apply after combat") end
            if t.width ~= 150 then problem("party targets: the width did not apply after combat") end
            ns.SetPTOption("ptTarget", false); ns.PTTick()
            if t.watched then problem("party targets: the target bar stayed on with its switch off") end
            ns.ResetPTSettings(); ns.PTTick()
            member._shown = false; ns.PTTick()
            if t.watched or tt.watched then problem("party targets: bars stayed on after the party frame went away") end
            member._shown = true; ns.PTTick()
            ns.ResetPTSettings()
        end
        UnitExists, UnitName, UnitIsPlayer, UnitClass, UnitReaction, UnitHealth, UnitHealthMax, InCombatLockdown =
            keep[1], keep[2], keep[3], keep[4], keep[5], keep[6], keep[7], keep[8]
        FACTION_BAR_COLORS = keepFBC
        PartyFrame, CompactPartyFrame = keepParty, keepCompact
        ns.PTTick()
    end
end

-- which combat log: Blizzard presets (written, then one reload) and KutzUI's own log window
do
    if not (ns.CLApplyView and ns.KLHandle and ns.KLPlace) then problem("combat log choice: not loaded") else
        date = date or function() return "12:00:00" end
        time = time or function() return 0 end
        local keepIsUnit = UnitIsUnit
        UnitIsUnit = UnitIsUnit or function(x, y) return x == y end
        local keep = { Blizzard_CombatLog_Filters, COMBATLOG_DEFAULT_SETTINGS, COMBATLOG_DEFAULT_COLORS, COMBATLOG_FILTER_MINE,
            ReloadUI, C_UI, InCombatLockdown, C_DamageMeter, Enum }
        COMBATLOG_FILTER_MINE = 1
        COMBATLOG_DEFAULT_SETTINGS = { timestamp = false, braces = false, unitColoring = false }
        COMBATLOG_DEFAULT_COLORS = { unitColoring = {}, schoolColoring = {} }
        Blizzard_CombatLog_Filters = { filters = { { settings = { timestamp = true, braces = true, mine = "kept" },
            colors = { unitColoring = {} }, eventList = { X = true }, name = "My actions" } } }
        local reloads = 0
        ReloadUI = function() reloads = reloads + 1 end
        C_UI = nil
        local combat = false
        InCombatLockdown = function() return combat end
        KutzUIDB.clogView, KutzUIDB.clogBlizzBackup = nil, nil
        local flt = Blizzard_CombatLog_Filters.filters[1]

        if ns.CLView() ~= "own" then problem("combat log choice: does not start on your own Blizzard settings") end
        if ns.CLViewNeedsReload("best") ~= true then problem("combat log choice: 'best' was not seen as different") end
        ns.CLApplyView("best")
        if reloads ~= 1 or flt.settings.braces ~= false or flt.settings.timestamp ~= true or flt.settings.unitIcons ~= true then
            problem("combat log choice: best settings were not written, or the interface did not reload") end
        if not flt.colors.unitColoring[1] then problem("combat log choice: your own colour was not set in the best settings") end
        if flt.eventList.X ~= true or flt.name ~= "My actions" then problem("combat log choice: the filter's events or name were touched") end
        if ns.CLPresetActive("best") ~= true then problem("combat log choice: best settings not seen as applied") end
        ns.CLApplyView("stock")
        if reloads ~= 2 or flt.settings.unitColoring ~= false then problem("combat log choice: out-of-the-box settings were not written") end
        ns.CLApplyView("own")
        if reloads ~= 3 or flt.settings.braces ~= true or flt.settings.mine ~= "kept" then problem("combat log choice: your own settings did not come back") end
        ns.CLApplyView("own")
        if reloads ~= 3 then problem("combat log choice: reloaded although nothing changed") end
        combat = true
        if ns.CLApplyView("best") or reloads ~= 3 then problem("combat log choice: settings were written in combat") end
        combat = false
        if ns.ProfileSnapshot and ns.ProfileSnapshot().clogBlizzBackup then problem("combat log choice: the copy of Blizzard's settings went into the profile") end

        -- KutzUI's own log
        ns.CLApplyView("kutz")
        if reloads ~= 3 then problem("kutz log: picking it reloaded the interface") end
        local hidden = setmetatable({ _secret = true }, { __tostring = function() return "secret" end })
        ns.KLClear()
        ns.KLHandle("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 5, 1)
        ns.KLHandle("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
        ns.KLHandle("UNIT_COMBAT", "player", "WOUND", "", hidden, 4)
        ns.KLHandle("UNIT_COMBAT", "player", "HEAL", "CRITICAL", 30, 2)
        local l = ns.KLLine(4)
        if not l or l.dir ~= "in" or l.amount ~= 5 or l.what ~= "Physical crit" then problem("kutz log: a crit on you was not logged right (" .. tostring(l and l.what) .. ")") end
        l = ns.KLLine(3)
        if not l or l.dir ~= "out" or l.what ~= "dodge" then problem("kutz log: your target's dodge was not logged right") end
        l = ns.KLLine(2)
        if not l or l.amount ~= hidden or l.what ~= "Fire" then problem("kutz log: a hidden amount was not kept for the text") end
        l = ns.KLLine(1)
        if not l or l.dir ~= "heal" or l.what ~= "healed crit" then problem("kutz log: a heal was not logged right") end

        ChatFrame2 = ChatFrame2 or new("ScrollingMessageFrame", "ChatFrame2")
        ChatFrame2:Show(); ChatFrame2._h, ChatFrame2._w = 200, 400
        ns.KLPlace()
        local win = _G.KutzLogFrame
        if not (win and win._shown) then problem("kutz log: the window did not show in the combat log's place") else
            win._h, win._w = 200, 400
            ns.KLSetTab("log"); ns.KLRedraw()
            local rows = ns.KLRows
            local n = ns.KLState.rowCount or 0
            local bottom = rows[n]
            if not bottom or bottom.amount._text ~= "30" or bottom.time._text ~= "12:00:00+" then
                problem("kutz log: the newest line is not at the bottom (" .. tostring(bottom and bottom.time._text) .. ")") end
            if rows[n - 1].amount._text ~= hidden then problem("kutz log: a hidden amount was not handed straight to the text") end
            ns.RestyleCombatLog()
            if ChatFrame2._alpha ~= 0 then problem("kutz log: Blizzard's log was not hidden behind it") end

            -- meters from Blizzard's damage meter data
            Enum = Enum or {}
            Enum.DamageMeterType = Enum.DamageMeterType or { DamageDone = 0, HealingDone = 2, DamageTaken = 7, Deaths = 9 }
            Enum.DamageMeterSessionType = Enum.DamageMeterSessionType or { Overall = 0, Current = 1 }
            local asked
            C_DamageMeter = {
                IsDamageMeterAvailable = function() return true, "" end,
                GetCombatSessionFromType = function(st, mt) return { maxAmount = 100, combatSources = {
                    { name = "Example", classFilename = "ROGUE", totalAmount = 80, amountPerSecond = 8, isLocalPlayer = true, sourceGUID = "g1" },
                    { name = hidden, classFilename = "MAGE", totalAmount = hidden, amountPerSecond = hidden, sourceGUID = hidden } } } end,
                GetCombatSessionSourceFromType = function(st, mt, guid) asked = guid
                    return { maxAmount = 50, combatSpells = { { spellID = 1752, totalAmount = 50, amountPerSecond = 5 } } } end,
            }
            ns.KLSetTab("damage")
            if rows[1].who._text ~= "Example" or rows[1].amount._text ~= "80" then problem("kutz log: the damage bars are wrong") end
            if rows[2].who._text ~= hidden or rows[2].bar._value ~= hidden then problem("kutz log: hidden meter values were not handed straight to the bar / text") end
            if rows[2].click then problem("kutz log: a bar whose owner is hidden offered a breakdown") end
            rows[1].click()
            if asked ~= "g1" or not ns.KLState.detail or rows[1].amount._text ~= "50" then problem("kutz log: clicking a bar did not show its spells") end
            ns.KLBack()
            if ns.KLState.detail then problem("kutz log: back did not leave the spell list") end
            ns.KLSetTab("log")
        end

        KutzUIDB.clogView, KutzUIDB.clogBlizzBackup, KutzUIDB.klTab = nil, nil, nil
        ns.KLPlace()
        if win and win._shown then problem("kutz log: the window stayed after switching back to Blizzard's log") end
        Blizzard_CombatLog_Filters, COMBATLOG_DEFAULT_SETTINGS, COMBATLOG_DEFAULT_COLORS, COMBATLOG_FILTER_MINE,
            ReloadUI, C_UI, InCombatLockdown, C_DamageMeter, Enum =
            keep[1], keep[2], keep[3], keep[4], keep[5], keep[6], keep[7], keep[8], keep[9]
        UnitIsUnit = keepIsUnit
        ns.RestyleCombatLog()
    end
end

-- nameplates: health percent and the target outline
do
    if not ns.NPTick then problem("nameplates: not loaded") else
        ns.ResetNPSettings()
        local bar = new("StatusBar", "FakeNPBar")
        local plate = new("Frame", "FakePlate"); plate.namePlateUnitToken = "nameplate1"
        plate.UnitFrame = new("Button", "FakePlateUF")
        plate.UnitFrame.HealthBarsContainer = new("Frame", "FakePlateHB")
        plate.UnitFrame.HealthBarsContainer.healthBar = bar
        plate.UnitFrame.name = new("FontString", "FakePlateName"); plate.UnitFrame.name._text = "Frostmane Troll Whelp"
        C_NamePlate = { GetNamePlates = function() return { plate } end, GetNamePlateForUnit = function() return plate end }
        local keepPct, keepIs = UnitHealthPercent, UnitIsUnit
        local pct, isTarget = 64, true
        UnitHealthPercent = function() return pct end
        UnitIsUnit = function() return isTarget end
        local hidden = setmetatable({ _secret = true }, { __tostring = function() return "secret" end })
        local boolArgs
        local function tick()
            ns.NPTick()
            local e = ns.NPExtras[bar]
            if e and not e.hooked then e.glow.SetAlphaFromBoolean = function(_, v, a, b) boolArgs = { v, a, b } end; e.hooked = true; ns.NPTick() end
            return e
        end
        local e = tick()
        if not e then problem("nameplates: nothing was added to the plate") else
            if e.text._text ~= "64%" or not e.holder._shown then problem("nameplates: wrong health text (" .. tostring(e.text._text) .. ")") end
            if not (boolArgs and boolArgs[1] == true and boolArgs[2] == 1 and boolArgs[3] == 0) then problem("nameplates: the outline was not driven by the target test") end
            isTarget = hidden; tick()
            if not (boolArgs and boolArgs[1] == hidden) then problem("nameplates: a hidden target flag was not handed straight to the widget") end
            isTarget = false; tick()
            if not (boolArgs and boolArgs[1] == false) then problem("nameplates: a non-target should switch the outline off") end
            pct = 5; tick()
            if e.text._text ~= "5%" then problem("nameplates: the percent did not follow the health (" .. tostring(e.text._text) .. ")") end
            pct = hidden; tick()
            if e.text._text ~= "secret" and e.text._text ~= nil and e.holder._shown and false then problem("nameplates: odd") end
            pct = 64
            ns.SetNPOption("npHealthText", false); tick()
            if e.holder._shown then problem("nameplates: health text shown with its switch off") end
            ns.SetNPOption("npHealthText", nil)
            ns.SetNPOption("npTargetGlow", false); tick()
            if e.glow._shown then problem("nameplates: outline shown with its switch off") end
            ns.SetNPOption("npTargetGlow", nil)
            -- the whole name: ours shows the full text, Blizzard's is made invisible; off gives it back
            if e.name._text ~= "Frostmane Troll Whelp" or not e.nameHolder._shown then problem("nameplates: the whole name was not written (" .. tostring(e.name._text) .. ")") end
            if plate.UnitFrame.name._alpha ~= 0 then problem("nameplates: Blizzard's name was not hidden") end
            if e.name._w and e.name._w ~= 0 and e.name._w ~= 100 then problem("nameplates: the name has a width limit") end
            plate.UnitFrame.name._shown = false; tick()
            if e.nameHolder._shown then problem("nameplates: our name shown while the game hides the name") end
            plate.UnitFrame.name._shown = true
            ns.SetNPOption("npFullName", false); tick()
            if e.nameHolder._shown or plate.UnitFrame.name._alpha ~= 1 then problem("nameplates: the whole-name switch off did not restore Blizzard's name") end
            ns.SetNPOption("npFullName", nil); tick()
            plate.UnitFrame.IsForbidden = function() return true end
            local before = e.text._text
            pct = 33; tick()
            if e.text._text ~= before then problem("nameplates: a forbidden plate was touched") end
            plate.UnitFrame.IsForbidden = nil
            ns.SetNPOption("npTextSize", 14); pct = 64; tick()
            if e.size ~= 14 then problem("nameplates: the text size was not applied") end
        end
        UnitHealthPercent, UnitIsUnit = keepPct, keepIs
        ns.ResetNPSettings()
    end
end

-- KutzUI's own Player / Target bars: name, numbers, size, and the room they take beside Blizzard's frame
do
    if not (ns.BarsApply and ns.UB and ns.BarsExtra) then problem("unit bars: not loaded") else
        local keep = { UnitExists = UnitExists, UnitName = UnitName, UnitHealth = UnitHealth, UnitHealthMax = UnitHealthMax,
            UnitPowerType = UnitPowerType, UnitPowerMax = UnitPowerMax, UnitPower = UnitPower,
            UnitIsConnected = UnitIsConnected, UnitIsDeadOrGhost = UnitIsDeadOrGhost, UnitIsPlayer = UnitIsPlayer,
            UnitReaction = UnitReaction }
        UnitExists = function(u) return u == "player" or u == "target" end
        UnitName = function(u) if u == "target" then return "Frostmane Troll Whelp" end return "Example Player" end
        UnitHealth = function() return 80 end
        UnitHealthMax = function() return 100 end
        UnitPowerType = function() return 0, "MANA" end
        UnitPowerMax = function() return 50 end
        UnitPower = function() return 25 end
        UnitIsConnected = function() return true end
        UnitIsDeadOrGhost = function() return false end
        UnitIsPlayer = function() return false end
        UnitReaction = function() return 4 end
        KutzUIDB.ownBars, KutzUIDB.barW, KutzUIDB.barH = nil, nil, nil

        PlayerFrame.PlayerFrameContainer = { PlayerPortrait = new("Texture", "FakePlayerPortrait"), FrameTexture = new("Texture", "FakePlayerArt") }
        TargetFrame.TargetFrameContainer = { Portrait = new("Texture", "FakeTargetPortrait"), FrameTexture = new("Texture", "FakeTargetArt") }
        ns.BarsApply()
        local pb, tb = _G.KutzPlayerBars, _G.KutzTargetBars
        if not (pb and tb) then problem("unit bars: the bars were not made") else
            ns.UB.Tick()
            if pb.name._text ~= "Example" then problem("unit bars: the Player bar should show the first name only (" .. tostring(pb.name._text) .. ")") end
            if tb.name._text ~= "Frostmane Troll Whelp" then problem("unit bars: the Target bar should show the whole name (" .. tostring(tb.name._text) .. ")") end
            if not tostring(tb.numbers._text):find("80%%") then problem("unit bars: no health percent (" .. tostring(tb.numbers._text) .. ")") end
            if pb.health._max ~= 100 or pb.health._value ~= 80 then problem("unit bars: health bar not filled") end
            local fullW = ns.UB.DEFAULT_W + ns.UB.DEFAULT_H + 14      -- the bars plus the square portrait joined to them
            if pb:GetWidth() ~= fullW or tb:GetWidth() ~= fullW then problem("unit bars: Player and Target are not the same width") end
            if pb:GetHeight() ~= tb:GetHeight() then problem("unit bars: Player and Target are not the same height") end
            if FakePlayerArt._alpha ~= 0 or FakeTargetArt._alpha ~= 0 then problem("unit bars: Blizzard's frame picture was not made invisible") end
            local ep, et = ns.BarsExtra("player"), ns.BarsExtra("target")
            if ep ~= 89 or et ~= 89 then problem("unit bars: wrong room taken beside the frames (" .. tostring(ep) .. ", " .. tostring(et) .. ")") end
            -- the frames make room: Player sits that much further left of the gap's half
            ns.L.Apply()
            local px = select(4, PlayerFrame:GetPoint(1))
            local gap = ns.L.GetSpread()
            if not px or math.abs(px * PlayerFrame:GetScale() + gap / 2 + ep) > 0.5 then problem("unit bars: Player not moved out to make room (" .. tostring(px) .. ")") end
            KutzUIDB.barW = 124; if ns.BarsExtra("player") ~= 0 then problem("unit bars: a narrow bar should need no extra room") end
            KutzUIDB.barW = 200; if ns.BarsExtra("target") ~= 49 then problem("unit bars: a 200 wide bar should stick out 49 (" .. tostring(ns.BarsExtra("target")) .. ")") end
            KutzUIDB.barW = nil
            -- off: Blizzard's pieces come back and our bars go
            KutzUIDB.ownBars = false; ns.BarsApply()
            if FakePlayerArt._alpha ~= 1 or pb._shown then problem("unit bars: switching off did not give Blizzard's frame back") end
        end
        for k, v in pairs(keep) do _G[k] = v end
        KutzUIDB.ownBars = false; ns.BarsApply(); ns.L.Apply()    -- the rest of the checks run without them
    end
end

-- item level numbers
do
    if not ns.ILTick then problem("item level: not loaded") else
        ns.ResetILSettings()
        local function button(name, id) local b = new("Button", name); b._id = id; b.GetID = function(self) return self._id end; return b end
        CharacterFrame = new("Frame", "CharacterFrame"); CharacterFrame._shown = true
        local head = button("CharacterHeadSlot", 1); CharacterHeadSlot = head
        local ring = button("CharacterFinger0Slot", 11); CharacterFinger0Slot = ring
        local links = { [1] = "|cffa335ee|Hitem:100|h[Helm]|h|r", [11] = "|cff0070dd|Hitem:200|h[Ring]|h|r" }
        function GetInventoryItemLink(unit, id) return links[id] end
        local levels = { ["|cffa335ee|Hitem:100|h[Helm]|h|r"] = 639, ["|cff0070dd|Hitem:200|h[Ring]|h|r"] = 1 }
        C_Item = { GetDetailedItemLevelInfo = function(link) return levels[link] end,
                   GetItemQualityByID = function(link) return link:find("a335ee", 1, true) and 4 or 3 end,
                   GetItemInfoInstant = function(link) return 1, "Armor", "Plate", "INVTYPE_HEAD", 1, link:find("Bag", 1, true) and 1 or 4 end }
        GetItemQualityColor = function(q) if q == 4 then return 0.64, 0.21, 0.93 end return 0, 0.44, 0.87 end
        ns.ILTick()
        local function entry(b) return ns.ILLabels[b] end
        local he = entry(head) or { text = {}, shown = false }
        if not (he and he.shown) then problem("item level: no number on the helm") end
        if he and he.text._text ~= 639 and he.text._text ~= "639" then problem("item level: wrong number on the helm (" .. tostring(he.text._text) .. ")") end
        if he and not (he.text._tcolor and math.abs(he.text._tcolor[1] - 0.64) < 0.01) then problem("item level: the number is not in the quality colour") end
        local re_ = entry(ring)
        if re_ and re_.shown then problem("item level: a level-1 item got a number") end
        ns.SetILOption("ilChar", false); ns.ILTick()
        if he.shown then problem("item level: still shown on the character sheet with its switch off") end
        ns.SetILOption("ilChar", nil)
        CharacterFrame._shown = false; ns.ILTick()
        if he.shown then problem("item level: still shown with the character sheet closed") end
        CharacterFrame._shown = true; ns.ILTick()
        if not he.shown then problem("item level: not back with the sheet open") end
        ns.SetILOption("ilColor", false); ns.ILTick()
        if not (he.text._tcolor and he.text._tcolor[1] == 1 and he.text._tcolor[2] == 1) then problem("item level: numbers not white with colouring off") end
        ns.SetILOption("ilColor", nil)

        -- bags
        local bag = new("Frame", "ContainerFrame1"); ContainerFrame1 = bag
        local b1, b2 = button("Bag1Item1", 1), button("Bag1Item2", 2)
        b1.GetBagID = function() return 0 end; b2.GetBagID = function() return 0 end
        bag.EnumerateValidItems = function() local list = { b1, b2 }; local i = 0; return function() i = i + 1; if list[i] then return i, list[i] end end end
        C_Container = { GetContainerItemInfo = function(bagId, slot) if slot == 1 then return { hyperlink = links[1] } end return { hyperlink = "|Hitem:5|h[Bag]|h" } end }
        bag._shown = true
        ns.ILTick()
        local e1, e2 = entry(b1) or { shown = false, text = {} }, entry(b2)
        if not (e1 and e1.shown) then problem("item level: no number on armour in the bag") end
        if e2 and e2.shown then problem("item level: a bag (not gear) got a number") end
        ns.SetILOption("ilBags", false); ns.ILTick()
        if e1.shown then problem("item level: bag numbers stayed with their switch off") end
        ns.SetILOption("ilBags", nil); ns.ILTick()
        if not e1.shown then problem("item level: bag numbers did not come back") end
        bag._shown = false; ns.ILTick()
        if e1.shown then problem("item level: bag numbers stayed with the bag closed") end
        ns.ResetILSettings()
        CharacterFrame._shown = false; ns.ILTick()
    end
end

-- cast bar extras: time shown, latency safe zone, "can't be interrupted" mark
do
    local L = ns.L
    local bar, tbar = KutzPlayerCastBar, KutzTargetCastBar
    L.ResetCastBars()
    local ev
    for _, w in ipairs(all) do if w._events and w._events["UNIT_SPELLCAST_START"] then ev = w end end
    if not ev then problem("cast extras: could not find the cast event frame") else
        local keepExists, keepInfo, keepChan = UnitExists, UnitCastingInfo, UnitChannelInfo
        CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
        UnitExists = function(u) return u == "player" or u == "target" end
        local notInt = false
        UnitCastingInfo = function(u) return "Fireball", "Fireball", 134400, (clock - 1) * 1000, (clock + 1.5) * 1000, false, "cast-1", notInt, 133 end
        UnitChannelInfo = function() return nil end
        tbar.shield.SetAlphaFromBoolean = function(self, v, a, b) self._boolArgs = { v, a, b } end
        local fill = tbar.bar:GetStatusBarTexture()
        fill.SetVertexColorFromBoolean = function(self, v, c1, c2) self._colorArgs = { v, c1, c2 } end
        local function cast(frame, unit)
            ev._scripts.OnEvent(ev, "UNIT_SPELLCAST_START", unit)
            frame._scripts.OnUpdate(frame, 0.016)
        end

        -- time: left (default), left / whole, none
        cast(bar, "player")
        if bar.time._text ~= "1.5" then problem("cast extras: default time should be the time left, got '" .. tostring(bar.time._text) .. "'") end
        KutzUIDB.castTimeMode = "total"; L.Apply(); cast(bar, "player")
        if bar.time._text ~= "1.5 / 2.5" then problem("cast extras: 'time left / whole cast' wrong: '" .. tostring(bar.time._text) .. "'") end
        KutzUIDB.castTimeMode = "off"; L.Apply(); cast(bar, "player")
        if bar.time._text ~= "" then problem("cast extras: 'no time' still wrote a time: '" .. tostring(bar.time._text) .. "'") end
        KutzUIDB.castTimeMode = nil; L.Apply()

        -- safe zone: only on your own bar, as wide as the latency, and switchable
        cast(bar, "player")
        if not bar.safe._shown then problem("cast extras: no latency safe zone on the player's bar") end
        if math.abs(bar.safe._w - math.max(1, bar.bar:GetWidth() * 0.04 / 2.5)) > 0.5 then problem("cast extras: safe zone width is wrong (" .. tostring(bar.safe._w) .. ")") end
        cast(tbar, "target")
        if tbar.safe._shown then problem("cast extras: the target's bar got a safe zone") end
        KutzUIDB.castSafe = false; cast(bar, "player")
        if bar.safe._shown then problem("cast extras: safe zone shown with its switch off") end
        KutzUIDB.castSafe = nil

        -- the interrupt mark goes only on the target's bar and is driven by the (possibly hidden) flag itself
        notInt = true; cast(tbar, "target")
        if not tbar.shield._shown or not tbar.shield._boolArgs or tbar.shield._boolArgs[1] ~= true or tbar.shield._boolArgs[2] ~= 1 or tbar.shield._boolArgs[3] ~= 0 then problem("cast extras: the shield was not driven by the uninterruptible flag") end
        if not fill._colorArgs or fill._colorArgs[1] ~= true then problem("cast extras: the bar tint was not driven by the uninterruptible flag") end
        local hiddenFlag = setmetatable({ _secret = true }, { __tostring = function() return "secret" end })
        notInt = hiddenFlag; cast(tbar, "target")
        if tbar.shield._boolArgs[1] ~= hiddenFlag then problem("cast extras: a hidden flag was not passed straight to the widget") end
        notInt = nil; cast(tbar, "target")
        if tbar.shield._boolArgs[1] ~= false then problem("cast extras: a missing flag should mean 'can be interrupted'") end
        notInt = true
        cast(bar, "player")
        if bar.shield._shown then problem("cast extras: the player's bar got the shield") end
        KutzUIDB.castShield = false; cast(tbar, "target")
        if tbar.shield._shown then problem("cast extras: shield shown with its switch off") end
        KutzUIDB.castShield = nil

        -- the menu's preview shows both on the right bars
        notInt = false
        UnitExists = function() return false end
        L.SetCastPreview(true)
        if not (bar.safe._shown and tbar.shield._shown) then problem("cast extras: the preview does not show the safe zone and the shield") end
        L.SetCastPreview(false)
        if bar.safe._shown or tbar.shield._shown then problem("cast extras: preview marks stayed after the preview ended") end

        -- the shape mask covers the safe zone too
        UnitExists = function(u) return u == "player" or u == "target" end
        KutzUIDB.castShape = "pill"; L.ApplyCastTextures(); cast(bar, "player")
        if bar.safe._masks ~= 1 then problem("cast extras: the pill mask did not cover the safe zone (" .. tostring(bar.safe._masks) .. ")") end
        KutzUIDB.castShape = nil; L.ApplyCastTextures()
        if bar.safe._masks ~= 0 then problem("cast extras: the mask stayed on the safe zone with square corners") end

        UnitExists, UnitCastingInfo, UnitChannelInfo = keepExists, keepInfo, keepChan
        ev._scripts.OnEvent(ev, "UNIT_SPELLCAST_STOP", "player"); ev._scripts.OnEvent(ev, "UNIT_SPELLCAST_STOP", "target")
        L.ResetCastBars()
    end
end

-- world map coordinates
do
    local c = _G.KutzMapCoords
    if ns.SetMapCoords then ns.SetMapCoords(nil) end
    if not c then
        problem("map coordinates: the frame was not built")
    else
        if ns.MapCoordsFormat(45.25, 63.1, nil, nil) ~= "Player 45.2, 63.1      Cursor --" and ns.MapCoordsFormat(45.25, 63.1, nil, nil) ~= "Player 45.3, 63.1      Cursor --" then problem("map coordinates: wrong format (" .. ns.MapCoordsFormat(45.25, 63.1, nil, nil) .. ")") end
        if ns.MapCoordsFormat(nil, nil, 10, 20) ~= "Player --      Cursor 10.0, 20.0" then problem("map coordinates: wrong format without a player position") end
        MAPCUR = { 0.5, 0.25 }
        tickAll(0.2)
        if not c.text._text:find("Cursor 50.0, 25.0", 1, true) then problem("map coordinates: cursor not shown (" .. tostring(c.text._text) .. ")") end
        if not c.text._text:find("Player 12.0, 34.0", 1, true) then problem("map coordinates: player not shown (" .. tostring(c.text._text) .. ")") end
        MAPCUR = { 1.5, 0.5 }; tickAll(0.2)
        if not c.text._text:find("Cursor --", 1, true) then problem("map coordinates: a cursor off the map was shown") end
        MAPPLAYER = false; tickAll(0.2)
        if not c.text._text:find("Player --", 1, true) then problem("map coordinates: hidden position was shown") end
        MAPPLAYER = true
        ns.SetMapCoords(false); tickAll(0.6)
        if c._shown then problem("map coordinates: still shown with the switch off") end
        ns.SetMapCoords(true); tickAll(0.6)
        if not c._shown then problem("map coordinates: not back with the switch on") end
        ns.SetMapCoords(nil)
    end
end

-- tooltip extras: IDs, "Targeting:", item-quality borders
do
    local x = ns.TTExtras
    ns.ResetTTSettings()
    if not x then problem("tooltip extras: not loaded") else
        local hidden = setmetatable({ _secret = true }, { __tostring = function() return 'secret' end })
        local added, border = {}, nil
        GameTooltip.AddLine = function(_, text) added[#added + 1] = text end
        GameTooltip.NineSlice = new("Frame")
        GameTooltip.NineSlice.SetBorderColor = function(_, r, g, b) border = { r, g, b } end
        C_Item = { GetItemQualityByID = function(id) return id == 19019 and 5 or (id == 1 and 1 or 3) end }
        GetItemQualityColor = function(q) if q == 5 then return 1, 0.5, 0 end return 0, 0.4, 0.9 end
        local function reset() added = {}; border = nil end

        -- registered for the right kinds
        local kinds = {}
        for _, c in ipairs(POSTCALLS) do kinds[c.kind] = (kinds[c.kind] or 0) + 1 end
        for _, k in ipairs({ Enum.TooltipDataType.Item, Enum.TooltipDataType.Spell, Enum.TooltipDataType.UnitAura, Enum.TooltipDataType.Currency }) do
            if not kinds[k] then problem("tooltip extras: no post call for kind " .. tostring(k)) end
        end

        -- item: border by quality, id only when asked for
        x.OnItem(GameTooltip, { id = 19019 })
        if not border or border[1] ~= 1 or border[2] ~= 0.5 then problem("tooltip extras: the legendary border was not tinted") end
        if #added ~= 0 then problem("tooltip extras: an ID was added with the switch off") end
        reset(); x.OnItem(GameTooltip, { id = 1 })
        if not border or border[1] ~= 1 or border[3] ~= 1 then problem("tooltip extras: a common item did not get the plain border back") end
        reset(); ns.SetTTOption("ttRarity", false); x.OnItem(GameTooltip, { id = 19019 })
        if border and border[2] ~= 1 then problem("tooltip extras: tinted with its switch off") end
        ns.SetTTOption("ttRarity", nil)
        reset(); ns.SetTTOption("ttIds", true)
        x.OnItem(GameTooltip, { id = 19019 })
        if not (added[1] and added[1]:find("Item ID  19019", 1, true)) then problem("tooltip extras: item ID line missing") end
        reset(); x.OnSpell(GameTooltip, { id = 133 })
        if not (added[1] and added[1]:find("Spell ID  133", 1, true)) then problem("tooltip extras: spell ID line missing") end
        reset(); x.OnSpell(GameTooltip, { id = hidden })
        if #added ~= 0 then problem("tooltip extras: an unreadable ID was written") end
        if x.NpcIdFromGuid("Creature-0-3-0-0-1234-00001") ~= 1234 then problem("tooltip extras: NPC id not read from a Creature GUID") end
        if x.NpcIdFromGuid("Player-1-ABC") ~= nil then problem("tooltip extras: a player GUID gave an NPC id") end
        ns.SetTTOption("ttIds", nil)

        -- the border is put back when the tooltip is shown and isn't an item any more
        reset(); x.OnItem(GameTooltip, { id = 19019 }); reset(); x.OnSpell(GameTooltip, { id = 133 })
        if not border or border[1] ~= 1 or border[2] ~= 1 then problem("tooltip extras: border not reset on a spell tooltip") end
        -- ... and when the tooltip closes (the slow check)
        reset(); x.OnItem(GameTooltip, { id = 19019 }); GameTooltip._shown = false; border = nil
        tickAll(0.3)
        if not border or border[2] ~= 1 then problem("tooltip extras: border not reset after the tooltip closed") end
        GameTooltip._shown = true

        -- targeting line
        local oldExists, oldIsUnit, oldName, oldClass, oldPlayer = UnitExists, UnitIsUnit, UnitName, UnitClass, UnitIsPlayer
        UnitExists = function(u) return u == "mouseover" or u == "mouseovertarget" end
        UnitIsUnit = function() return false end
        UnitName = function(u) return u == "mouseovertarget" and "Thrall" or "Someone" end
        UnitIsPlayer = function() return true end
        UnitClass = function() return "Warrior", "WARRIOR" end
        reset(); x.OnUnit(GameTooltip, {})
        if not (added[1] and added[1]:find("Targeting:", 1, true) and added[1]:find("Thrall", 1, true) and added[1]:find("c79c6e", 1, true)) then problem("tooltip extras: targeting line wrong (" .. tostring(added[1]) .. ")") end
        UnitIsUnit = function() return true end
        reset(); x.OnUnit(GameTooltip, {})
        if not (added[1] and added[1]:find("YOU", 1, true)) then problem("tooltip extras: 'targeting you' missing") end
        UnitIsUnit = function() return false end
        UnitName = function() return hidden end
        reset(); x.OnUnit(GameTooltip, {})
        if #added ~= 0 then problem("tooltip extras: wrote a hidden name") end
        UnitName = function(u) return "Thrall" end
        ns.SetTTOption("ttTarget", false); reset(); x.OnUnit(GameTooltip, {})
        if #added ~= 0 then problem("tooltip extras: targeting shown with its switch off") end
        ns.SetTTOption("ttTarget", nil)
        UnitExists, UnitIsUnit, UnitName, UnitClass, UnitIsPlayer = oldExists, oldIsUnit, oldName, oldClass, oldPlayer
    end
end

-- convenience chores
do
    local h = ns.cvHandlers
    if ns.ResetCVSettings then ns.ResetCVSettings() end
    local function runTimers() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
    if not h then problem("convenience: no handlers") else
        -- vendor
        local sold, repairedGuild, repaired = 0, 0, 0
        local junk, money, cost, guildAllow, canGuild = 3, 10000, 500, -1, true
        C_MerchantFrame = { GetNumJunkItems = function() return junk end, SellAllJunkItems = function() sold = sold + 1; junk = 0 end }
        function CanMerchantRepair() return true end
        function GetRepairAllCost() return cost, cost > 0 end
        function CanGuildBankRepair() return canGuild end
        function GetGuildBankWithdrawMoney() return guildAllow end
        function GetMoney() return money end
        function RepairAllItems(guild) if guild then repairedGuild = repairedGuild + 1 else repaired = repaired + 1 end end
        function GetCoinTextureString(c) return c .. "c" end
        h.MERCHANT_SHOW()
        if sold ~= 1 then problem("convenience: junk was not sold") end
        if repaired ~= 1 or repairedGuild ~= 0 then problem("convenience: repair did not use own gold by default") end
        junk = 0; h.MERCHANT_SHOW()
        if sold ~= 1 then problem("convenience: sold with no junk") end
        ns.SetCVOption("cvRepairGuild", true); h.MERCHANT_SHOW()
        if repairedGuild ~= 1 then problem("convenience: guild repair not used when allowed") end
        guildAllow = 100; h.MERCHANT_SHOW()
        if repaired ~= 3 or repairedGuild ~= 1 then problem("convenience: should fall back to own gold when the guild allowance is too small (" .. repaired .. "," .. repairedGuild .. ")") end
        money = 10; ns.SetCVOption("cvRepairGuild", false); h.MERCHANT_SHOW()
        if repaired ~= 3 then problem("convenience: repaired without enough gold") end
        ns.SetCVOption("cvSellJunk", false); ns.SetCVOption("cvRepair", false); junk = 3; money = 10000
        h.MERCHANT_SHOW()
        if sold ~= 1 or repaired ~= 3 then problem("convenience: vendor chores ran with their switches off") end
        ns.ResetCVSettings()

        -- fast loot
        local slots = {}
        function GetNumLootItems() return 3 end
        function LootSlotHasItem(i) return i ~= 2 end
        function LootSlot(i) slots[#slots + 1] = i end
        clock = clock + 5
        h.LOOT_READY(true)
        if table.concat(slots, ",") ~= "3,1" then problem("convenience: fast loot took the wrong slots (" .. table.concat(slots, ",") .. ")") end
        h.LOOT_READY(true)
        if #slots ~= 2 then problem("convenience: fast loot ran twice for one corpse") end
        clock = clock + 5; slots = {}
        h.LOOT_READY(false)
        if #slots ~= 0 then problem("convenience: fast loot ran with auto-loot off") end
        ns.SetCVOption("cvFastLoot", false); clock = clock + 5; h.LOOT_READY(true)
        if #slots ~= 0 then problem("convenience: fast loot ran with its switch off") end
        ns.ResetCVSettings()

        -- duels, summons, invites
        local cancelled, hidden, confirmed, accepted = 0, {}, 0, 0
        function CancelDuel() cancelled = cancelled + 1 end
        function StaticPopup_Hide(w) hidden[#hidden + 1] = w end
        C_SummonInfo = { ConfirmSummon = function() confirmed = confirmed + 1 end }
        function AcceptGroup() accepted = accepted + 1 end
        h.DUEL_REQUESTED("Bob"); runTimers()
        if cancelled ~= 1 or not containsText(hidden, "DUEL_REQUESTED") then problem("convenience: duel was not declined") end
        ns.SetCVOption("cvDeclineDuels", false); h.DUEL_REQUESTED("Bob"); runTimers()
        if cancelled ~= 1 then problem("convenience: duel declined with the switch off") end
        h.CONFIRM_SUMMON(); runTimers()
        if confirmed ~= 0 then problem("convenience: summon accepted by default") end
        ns.SetCVOption("cvAcceptSummon", true); h.CONFIRM_SUMMON(); runTimers()
        if confirmed ~= 1 then problem("convenience: summon not accepted") end
        h.PARTY_INVITE_REQUEST("Al", false, false, true, true, true, "Player-1"); runTimers()
        if accepted ~= 0 then problem("convenience: invite accepted by default") end
        ns.SetCVOption("cvAcceptInvite", true)
        C_FriendList = { IsFriend = function(g) return g == "Player-friend" end }
        h.PARTY_INVITE_REQUEST("Al", false, false, true, true, true, "Player-stranger"); runTimers()
        if accepted ~= 0 then problem("convenience: a stranger's invite was accepted") end
        h.PARTY_INVITE_REQUEST("Al", false, false, true, true, true, "Player-friend"); runTimers()
        if accepted ~= 1 then problem("convenience: a friend's invite was not accepted") end
        ns.ResetCVSettings()

        -- screenshots
        local shots = 0
        function Screenshot() shots = shots + 1 end
        h.ACHIEVEMENT_EARNED(1); runTimers()
        if shots ~= 1 then problem("convenience: no achievement screenshot") end
        h.PLAYER_LEVEL_UP(2); runTimers()
        if shots ~= 1 then problem("convenience: level-up screenshot taken by default") end
        ns.SetCVOption("cvShotLevel", true); h.PLAYER_LEVEL_UP(2); runTimers()
        if shots ~= 2 then problem("convenience: no level-up screenshot") end
        ns.SetCVOption("cvShotAchieve", false); h.ACHIEVEMENT_EARNED(1); runTimers()
        if shots ~= 2 then problem("convenience: achievement screenshot with its switch off") end
        ns.ResetCVSettings()
    end
end

-- XP numbers on the experience bar
do
    local text = _G.KutzXpBarText
    if not text then problem("xp text: the frame does not exist") else
        XP, XPMAX = 1234, 56789
        tickAll(0.6)
        local shown = text.text._text
        if not text._shown or shown ~= "1,234 / 56,789  (2.2%)" then problem("xp text: wrong text '" .. tostring(shown) .. "'") end
        if XPBAR.OverlayFrame.Text._alpha ~= 0 then problem("xp text: Blizzard's own bar text was not set to alpha 0") end
        RESTED = 12000; tickAll(0.6)
        if not text.text._text:find("+12,000 rested", 1, true) then problem("xp text: the rested XP is missing (" .. tostring(text.text._text) .. ")") end
        ns.SetABOption("abXpRested", false); tickAll(0.6)
        if text.text._text:find("rested", 1, true) then problem("xp text: rested XP shown with its switch off") end
        KutzUIDB.abXpRested = nil; RESTED = nil; tickAll(0.6)
        if text.text._text:find("rested", 1, true) then problem("xp text: 'rested' shown with no rested XP") end
        XP = 28394; tickAll(0.6)
        if text.text._text ~= "28,394 / 56,789  (50.0%)" then problem("xp text: did not follow the XP (" .. tostring(text.text._text) .. ")") end
        XPBAR._shown = false; tickAll(0.6)
        if text._shown then problem("xp text: still shown with no XP bar") end
        if XPBAR.OverlayFrame.Text._alpha ~= 1 then problem("xp text: Blizzard's text was not given back") end
        XPBAR._shown = true; XPMAX = 0; tickAll(0.6)
        if text._shown then problem("xp text: shown with a zero level size") end
        XPMAX = 56789; tickAll(0.6)
        if not text._shown then problem("xp text: not back after the bar returned") end
        ns.SetABOption("abXpText", false); tickAll(0.6)
        if text._shown or XPBAR.OverlayFrame.Text._alpha ~= 1 then problem("xp text: switching it off did not restore Blizzard's bar text") end
        KutzUIDB.abXpText = nil; XP, XPMAX = 1234, 56789; tickAll(0.6)
    end
end

-- action bar size: all bars, one bar, and Blizzard changing a scale of its own
do
    local function settle() tick(0.6); tick(0.6) end
    ns.ResetABSettings(); settle()
    if MainActionBar._scale ~= 1 then problem("action bar size: touched at 100%") end
    ns.SetABScaleAll(150); settle()
    if math.abs(MainActionBar._scale - 1.5) > 0.001 or math.abs(MultiBarBottomLeft._scale - 1.5) > 0.001 then problem("action bar size: 'all bars' was not applied") end
    ns.SetABScaleBar("MainActionBar", 80); settle()
    if math.abs(MainActionBar._scale - 0.8) > 0.001 then problem("action bar size: one bar's own size was not applied") end
    if math.abs(MultiBarBottomLeft._scale - 1.5) > 0.001 then problem("action bar size: another bar changed with it") end
    MultiBarBottomLeft._scale = 2; settle()           -- Blizzard / Edit Mode sets a scale of its own
    if math.abs(MultiBarBottomLeft._scale - 3.0) > 0.001 then problem("action bar size: not applied on top of Blizzard's own scale (" .. tostring(MultiBarBottomLeft._scale) .. ")") end
    ns.ResetABSettings(); settle()
    if math.abs(MainActionBar._scale - 1) > 0.001 then problem("action bar size: reset did not restore the size") end
    if math.abs(MultiBarBottomLeft._scale - 2) > 0.001 then problem("action bar size: reset did not restore Blizzard's own scale") end
    MultiBarBottomLeft._scale = 1; settle()
end

-- action bar extras: page arrows hidden and locked, end caps optional
do
    local pn = MainActionBar.ActionBarPageNumber
    local function settle() tick(0.6); tick(0.6) end
    KutzUIDB.abHideArrows, KutzUIDB.abLockPaging, KutzUIDB.abHideEndCaps = nil, nil, nil
    ns.SetABOption("abHideArrows", true); settle()
    if pn._alpha ~= 0 then problem("the page arrows are not hidden by default") end
    if pn.UpButton._mouse ~= false or pn.DownButton._mouse ~= false then problem("the hidden page arrows can still be clicked") end
    if MainActionBar.EndCaps._alpha == 0 then problem("the end caps were hidden without being asked") end
    ns.SetABOption("abHideArrows", false); ns.SetABOption("abLockPaging", true); settle()
    if pn._alpha ~= 1 then problem("the page arrows did not come back") end
    if pn.UpButton._mouse ~= false then problem("locked page arrows can still be clicked") end
    ns.SetABOption("abLockPaging", false); settle()
    if pn.UpButton._mouse == false then problem("unlocked page arrows are not clickable again") end
    ns.SetABOption("abHideEndCaps", true); settle()
    if MainActionBar.EndCaps._alpha ~= 0 then problem("the end caps were not hidden") end
    KutzUIDB.abHideArrows, KutzUIDB.abLockPaging, KutzUIDB.abHideEndCaps = nil, nil, nil
    settle()
end

-- exact window position / size (Windows page)
ChatFrame2.isDocked = false
ns.SetWindowField("chat", "w", 700); ns.SetWindowField("chat", "h", 250)
if ChatFrame1:GetWidth() ~= 700 or ChatFrame1:GetHeight() ~= 250 then problem("chat window size was not applied") end
ns.SetWindowField("clog", "y", 5)
if not (KutzUIDB.winRect and KutzUIDB.winRect.clog and KutzUIDB.winRect.clog.y == 24) then problem("combat log bottom edge was allowed below its filter bar") end
ChatFrame1._w = 300; tickAll(0.6)
if ChatFrame1:GetWidth() ~= 700 then problem("a held chat window did not snap back to its numbers") end
ChatFrame2.isDocked = true; ChatFrame2._w = 111; tickAll(0.6)
if ChatFrame2:GetWidth() ~= 111 then problem("a docked combat log was resized") end
ns.ReleaseWindow("chat"); ns.ReleaseWindow("clog"); ChatFrame2.isDocked = false
ChatFrame1._w = 300; tickAll(0.6)
if ChatFrame1:GetWidth() ~= 300 then problem("a released chat window was still held") end
KutzUIDB.winRect = nil

-- chat time stamps use the game's own option: whatever the menu clicks left must be a valid value
do
    local v = GetCVar("showTimestamps")
    if not (v == "none" or v:match("^%%[HI]:%%M[:%%S]* ?%%p? $") or v:match("^%%[HI]:%%M:?%%S? ?%%p? $")) then
        problem("chat time stamp option got an odd value: " .. tostring(v))
    end
    notes[#notes + 1] = "chat time stamp option after the menu clicks: " .. tostring(v)
end
KutzUIDB.winRect = nil

-- memory report command
collectgarbage = function() return 0 end   -- the test interpreter has no collector
GetAddOnMemoryUsage = function() return 512 end
UpdateAddOnMemoryUsage = function() end
local okMem, errMem = pcall(SlashCmdList.KUTZUI, "mem")
if not okMem then problem("/kutz mem failed: " .. tostring(errMem)) end
-- every addon's memory, biggest first, and the note kept in the saved file
do
    local fakeAddons = { { "KutzUI", 2100 }, { "Questie", 90000 }, { "Spoken", 5000 }, { "NotLoaded", 1 } }
    C_AddOns.GetNumAddOns = function() return #fakeAddons end
    C_AddOns.GetAddOnInfo = function(i) return fakeAddons[i][1] end
    C_AddOns.IsAddOnLoaded = function(i) return fakeAddons[i][1] ~= "NotLoaded" end
    GetAddOnMemoryUsage = function(i)
        if type(i) == "number" then return fakeAddons[i][2] end
        return 512
    end
    KutzUIDB.memLog = nil
    local okM, errM = pcall(SlashCmdList.KUTZUI, "mem")
    if not okM then problem("/kutz mem (all addons) failed: " .. tostring(errM)) end
    local log = KutzUIDB.memLog
    local snap = type(log) == "table" and log[#log]
    if not snap then problem("/kutz mem kept no memory note")
    else
        if snap.a.Questie ~= 90000 or snap.a.KutzUI ~= 2100 then problem("memory note has the wrong numbers") end
        if snap.a.NotLoaded then problem("memory note lists an addon that is not loaded") end
        if snap.total ~= 97100 then problem("memory note total is " .. tostring(snap.total)) end
    end
    local list = ns.AddonMemory()
    if not (list[1] and list[1].name == "Questie" and list[3].name == "KutzUI") then problem("addon memory list is not biggest first") end
    for i = 1, 60 do ns.MemSnapshot("auto") end
    if #KutzUIDB.memLog ~= 48 then problem("memory notes are not capped at 48: " .. #KutzUIDB.memLog) end
    if ns.ProfileExport then
        local okE, text = pcall(ns.ProfileExport)
        if okE and type(text) == "string" and text:find("memLog", 1, true) then problem("memory notes leak into profile export") end
    end
    KutzUIDB.memLog = nil
    C_AddOns.GetNumAddOns, C_AddOns.GetAddOnInfo, C_AddOns.IsAddOnLoaded = nil, nil, nil
    GetAddOnMemoryUsage = function() return 512 end
end

if ns.CLPrepareDefaultTabs then
    local saved = Blizzard_CombatLog_Filters
    local originalBackup = KutzUIDB.clogRoutingBackup
    Blizzard_CombatLog_Filters = { currentFilter = 1, filters = {
        { settings = {}, colors = {}, filters = {
            { eventList = { SPELL_CAST_START = true }, sourceFlags = { [3] = true } },
            { eventList = { SPELL_HEAL = true }, destFlags = { [1] = true } },
        } }, { name = "Party", filters = {} },
    } }
    ns.CLPrepareDefaultTabs()
    local tabs = Blizzard_CombatLog_Filters.filters
    for _, rule in ipairs(tabs[1].filters) do
        if not rule.sourceFlags[COMBATLOG_FILTER_MINE] or rule.sourceFlags[3] or rule.destFlags then
            problem("My Actions still admits another actor")
        end
    end
    if tabs[2].name ~= "Party" or not tabs[3].kutzAll or tabs[3].name ~= "All" then problem("default All tab missing or Party changed") end
    if not tabs[3].filters[1].eventList.SPELL_CAST_START then problem("All lost cast events") end
    ns.CLPrepareDefaultTabs()
    if #tabs ~= 3 then problem("All duplicated on reload") end
    local admission = chatAdmissionFilters.CHAT_MSG_LOOT
    if not admission or not admission(ChatFrame2) or admission(ChatFrame1) then problem("chat filter failed before display or hid General chat") end
    Blizzard_CombatLog_Filters.currentFilter = 3
    if admission and admission(ChatFrame2) then problem("All still suppresses chat messages") end
    Blizzard_CombatLog_Filters = saved
    KutzUIDB.clogRoutingBackup = originalBackup
end
notes[#notes + 1] = ("%d widgets alive, %d pending timers"):format(#all, #timers)

report()
