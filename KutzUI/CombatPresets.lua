---------------------------------------------------------------------------
-- KutzUI / CombatPresets        (part of the "combatlog" module)
--
-- Which combat log you see (menu: Combat log page):
--   own   - Blizzard's log, exactly as you set it up yourself (the start)
--   stock - Blizzard's log with Blizzard's own out-of-the-box settings
--   best  - Blizzard's log with the settings that read best (see BEST below)
--   kutz  - KutzUI's own log window (KutzLog.lua) in the combat log's place
--
-- How a Blizzard preset is put in, and why this way:
--   The game BLOCKS addons from applying combat log settings while it runs
--   (C_CombatLog.ApplyFilterSettings - tried in v0.11.0). What Blizzard does on its own is read
--   its saved settings (Blizzard_CombatLog_Filters) when the interface loads. So the preset is
--   written into that saved table and the interface is reloaded AT ONCE: the game saves the
--   table, then loads it fresh and applies it itself. Nothing of Blizzard's runs in between, and
--   no restricted function is ever called by this addon.
--   Only the look of the lines is changed (the settings + colours of each filter); which events
--   each filter shows, the filter names and buttons stay as they are.
--   The first time, a copy of your own settings is kept (KutzUIDB.clogBlizzBackup), so "own"
--   always gives them back.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("combatlog", function()

local VIEWS = { own = true, stock = true, best = true, kutz = true }

function ns.CLView()
    local v = KutzUIDB and KutzUIDB.clogView
    if VIEWS[v] then return v end
    return "own"
end

local function Copy(v, depth)
    depth = depth or 0
    if type(v) ~= "table" or depth > 6 then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = Copy(x, depth + 1) end
    return out
end
ns.CLCopy = Copy

-- Change saved routing only as the UI exits. Blizzard applies it securely on the
-- next load; calling ApplyFilterSettings from addon code is blocked on Forever.
function ns.CLPrepareDefaultTabs()
    local saved = _G.Blizzard_CombatLog_Filters
    local mine = _G.COMBATLOG_FILTER_MINE
    if not (saved and type(saved.filters) == "table" and type(mine) == "number") then return end
    local actions = saved.filters[1]
    if not (actions and type(actions.filters) == "table") then return end
    if not KutzUIDB.clogRoutingBackup then KutzUIDB.clogRoutingBackup = Copy(saved) end
    -- Every rule is an alternative match. An incoming-action rule here would
    -- make the My Actions label misleading, even when the first rule is correct.
    for _, rule in ipairs(actions.filters) do
        rule.sourceFlags = { [mine] = true }
        rule.destFlags = nil
    end
    local all
    for _, filter in ipairs(saved.filters) do
        if filter.kutzAll or filter.name == "All" then all = filter; break end
    end
    if not all then
        all = { name = "All", quickButtonName = "All", tooltip = "All nearby combat actions.",
            settings = Copy(actions.settings), colors = Copy(actions.colors) }
        saved.filters[#saved.filters + 1] = all
    end
    local generate = _G.Blizzard_CombatLog_GenerateFullEventList
    local events = generate and generate() or {}
    if not generate then
        for _, filter in ipairs(saved.filters) do
            for _, rule in ipairs(filter.filters or {}) do
                for event, enabled in pairs(rule.eventList or {}) do if enabled then events[event] = true end end
            end
        end
    end
    all.kutzAll, all.hasQuickButton, all.onQuickBar = true, true, true
    all.quickButtonDisplay = { solo = true, party = true, raid = true }
    all.filters = { { eventList = events, sourceFlags = { [_G.COMBATLOG_FILTER_EVERYTHING or -1] = true } } }
end
local routing = CreateFrame("Frame")
routing:RegisterEvent("PLAYER_LOGOUT")
routing:SetScript("OnEvent", function() ns.CLPrepareDefaultTabs() end)

-- the settings that read best: short text, timestamps, names coloured by who they are (with a
-- colour of your own for you), the whole line in the colour of whoever did it, spell names and
-- numbers in the colour of their school, raid marker icons, no brackets.
local BEST = {
    timestamp = true, fullText = false,
    unitColoring = true, sourceColoring = true, destColoring = true,
    lineColoring = true, lineColorPriority = 1, lineHighlighting = true,
    abilityColoring = true, abilitySchoolColoring = true, abilityActorColoring = false, abilityHighlighting = false,
    amountColoring = true, amountSchoolColoring = true, amountActorColoring = false, amountHighlighting = false,
    schoolNameColoring = true, schoolNameActorColoring = false, schoolNameHighlighting = false,
    actionColoring = false, missColoring = true, noMeleeSwingColoring = false,
    braces = false, unitIcons = true,
}

-- colours by who: you stand out from everyone else in brightness as well as hue (colour-blind safe)
local BEST_UNIT_COLORS = {
    COMBATLOG_FILTER_MINE            = { 1.00, 0.84, 0.30 },   -- you: bright gold
    COMBATLOG_FILTER_MY_PET          = { 0.60, 0.85, 0.40 },   -- your pet: light green
    COMBATLOG_FILTER_FRIENDLY_UNITS  = { 0.34, 0.64, 1.00 },   -- friends: blue
    COMBATLOG_FILTER_HOSTILE_UNITS   = { 0.85, 0.22, 0.18 },   -- enemies: dark red
    COMBATLOG_FILTER_HOSTILE_PLAYERS = { 0.85, 0.22, 0.18 },
    COMBATLOG_FILTER_NEUTRAL_UNITS   = { 0.90, 0.55, 0.20 },   -- neutral: orange
    COMBATLOG_FILTER_UNKNOWN_UNITS   = { 0.70, 0.70, 0.70 },
}

local function Filters()
    local f = _G.Blizzard_CombatLog_Filters
    if type(f) == "table" and type(f.filters) == "table" and #f.filters > 0 then return f.filters end
    return nil
end

function ns.CLBlizzardReady() return Filters() ~= nil end

local function Backup(filters)
    if KutzUIDB.clogBlizzBackup then return end
    local b = {}
    for i, flt in ipairs(filters) do
        b[i] = { settings = Copy(flt.settings), colors = Copy(flt.colors) }
    end
    KutzUIDB.clogBlizzBackup = b
end

local function ApplyBest(flt)
    flt.settings = type(flt.settings) == "table" and flt.settings or {}
    for k, v in pairs(BEST) do flt.settings[k] = v end
    flt.colors = type(flt.colors) == "table" and flt.colors or Copy(_G.COMBATLOG_DEFAULT_COLORS) or {}
    flt.colors.unitColoring = type(flt.colors.unitColoring) == "table" and flt.colors.unitColoring or {}
    for name, c in pairs(BEST_UNIT_COLORS) do
        local mask = _G[name]
        if type(mask) == "number" then
            flt.colors.unitColoring[mask] = { a = 1, r = c[1], g = c[2], b = c[3] }
        end
    end
end

local function ApplyStock(flt)
    local s, c = _G.COMBATLOG_DEFAULT_SETTINGS, _G.COMBATLOG_DEFAULT_COLORS
    if type(s) == "table" then flt.settings = Copy(s) end
    if type(c) == "table" then flt.colors = Copy(c) end
end

local function ApplyOwn(flt, i)
    local b = KutzUIDB.clogBlizzBackup and KutzUIDB.clogBlizzBackup[i]
    if not b then return end
    if type(b.settings) == "table" then flt.settings = Copy(b.settings) end
    if type(b.colors) == "table" then flt.colors = Copy(b.colors) end
end

-- does Blizzard's log currently look the way `view` says? (nil = can't tell)
function ns.CLPresetActive(view)
    local filters = Filters()
    if not filters then return nil end
    local s = filters[1].settings
    if type(s) ~= "table" then return nil end
    if view == "best" then
        for k, v in pairs(BEST) do if s[k] ~= v then return false end end
        return true
    elseif view == "stock" then
        local d = _G.COMBATLOG_DEFAULT_SETTINGS
        if type(d) ~= "table" then return nil end
        for k, v in pairs(d) do if s[k] ~= v then return false end end
        return true
    elseif view == "own" then
        local b = KutzUIDB and KutzUIDB.clogBlizzBackup
        if not b then return true end                  -- never changed
        local bs = b[1] and b[1].settings
        if type(bs) ~= "table" then return nil end
        for k, v in pairs(bs) do if s[k] ~= v then return false end end
        return true
    end
    return true                                        -- kutz: Blizzard's settings don't matter
end

-- would picking `view` need the interface to reload?
function ns.CLViewNeedsReload(view)
    if view == "kutz" then return false end
    return ns.CLPresetActive(view) == false
end

-- put Blizzard's log in the look `view` asks for, then reload so the game applies it itself
function ns.CLApplyView(view, noReload)
    if not VIEWS[view] or not KutzUIDB then return false, "unknown choice" end
    KutzUIDB.clogView = view
    if view == "kutz" or not ns.CLViewNeedsReload(view) then return true end
    if InCombatLockdown() then return false, "not in combat" end
    local filters = Filters()
    if not filters then return false, "Blizzard's combat log is not loaded yet" end
    Backup(filters)
    for i, flt in ipairs(filters) do
        if type(flt) == "table" then
            if view == "best" then ApplyBest(flt)
            elseif view == "stock" then ApplyStock(flt)
            else ApplyOwn(flt, i) end
        end
    end
    if not noReload then
        local reload = (_G.C_UI and _G.C_UI.Reload) or _G.ReloadUI
        if reload then reload() end
    end
    return true
end

function ns.CLViewStatus()
    local view = ns.CLView()
    if view == "kutz" then
        return "Showing KutzUI's own log. Blizzard's log is hidden behind it (its settings are untouched)."
    end
    if not ns.CLBlizzardReady() then return "Blizzard's combat log has not loaded yet." end
    local on = ns.CLPresetActive(view)
    if on == false then
        return "|cffffd24aNot applied yet.|r Press Apply: the interface reloads once and Blizzard's log then uses these settings."
    end
    return "Blizzard's log is using these settings."
end

ns.RegisterDebug(function()
    ns.Print(string.format("combat log view: %s | Blizzard settings loaded=%s | matches=%s | backup kept=%s",
        ns.CLView(), tostring(ns.CLBlizzardReady()), tostring(ns.CLPresetActive(ns.CLView())),
        tostring(KutzUIDB and KutzUIDB.clogBlizzBackup ~= nil)))
end)

end)
