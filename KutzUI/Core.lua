---------------------------------------------------------------------------
-- KutzUI / Core
--
-- The module system and the /kutz command. Always loaded; everything else is either
-- shared helpers (Common.lua, Grid.lua, Menu.lua) or a MODULE you can switch off.
--
-- A module's file is wrapped like this:
--
--     local ADDON_NAME, ns = ...
--     ns.Module("chat", function()
--         ... the whole file ...
--     end)
--
-- The function is only RUN (after the saved settings have loaded) when the module is
-- switched on, so a switched-off module creates no frames, no pollers, no event
-- registrations and touches nothing of Blizzard's. Switches are on the menu's Modules
-- page and take effect after a reload (that is also what leaves Blizzard's own look
-- exactly as it was when a module is off).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- The settings window is a separate load-on-demand addon (KutzUI_Options); it reaches this
-- addon's table through this one global.
_G.KutzUI = ns

-- display order; `desc` is shown on the Modules page
ns.MODULES = {
    { key = "craftingtime", name = "Crafting time",
      desc = "Profession batch time estimates and a remaining craft count and countdown." },
    { key = "subcraft", name = "Sub-assembly crafting",
      desc = "Makes the missing parts of a recipe first, then the item, from one button under the profession window." },
    { key = "frames",   name = "Unit frames",
      desc = "Health/power text, Player and Target placement and size, Target-of-Target, name options." },
    { key = "castbars", name = "Cast bars",
      desc = "The two cast bars (icon, spell name, time) and their textures." },
    { key = "fonts",    name = "Game-wide font",
      desc = "Changes the font of Blizzard's own windows: quest tracker, character sheet, spellbook, tooltips, error text." },
    { key = "chat",     name = "Chat",
      desc = "Short colored prefixes, Enter opens the main chat, chat window look, time stamps." },
    { key = "combatlog", name = "Combat log",
      desc = "Transparent borderless look, filter buttons at the screen bottom, hidden text box, only-combat lines, Blizzard presets or KutzUI's own log." },
    { key = "windows",  name = "Window positions",
      desc = "Typed X / Y / width / height for the chat and combat log windows." },
    { key = "movers",   name = "Bag and tooltip",
      desc = "A bag you can drag (it remembers where) and a tooltip you can place." },
    { key = "keybinds", name = "Short key names",
      desc = "M4 / M5 instead of the spelled-out mouse button names on action bars." },
    { key = "actionbars", name = "Action bar extras",
      desc = "Hide the page arrows and end caps, lock the bar's page, and set the size of the action bars." },
    { key = "minimap",  name = "Minimap",
      desc = "Show or hide each button around the minimap, and put the clock in the top-right corner." },
    { key = "tooltip",  name = "Tooltip tweaks",
      desc = "Hide the health bar under tooltips and set the tooltip size." },
    { key = "damagemeter", name = "Damage meter",
      desc = "Turn on Blizzard's damage meter (in your font) and switch between it and the combat log." },
    { key = "fpsreadout", name = "FPS and latency readout",
      desc = "One tiny line of text in a corner with your frame rate and latency." },
    { key = "partytargets", name = "Party targets",
      desc = "Beside each party frame, a small bar for what that member is targeting, and one for what that target is targeting." },
    { key = "nameplates", name = "Nameplates",
      desc = "Health percent in Blizzard's nameplates and a gold outline on your target's plate." },
    { key = "itemlevel", name = "Item level numbers",
      desc = "The item level written on the character sheet slots and on weapons and armour in your bags." },
    { key = "junkhint", name = "Full-bag junk hint",
      desc = "When every bag slot is taken, puts a red border on the 5 stacks that sell for the least, so you know what to delete first." },
    { key = "convenience", name = "Convenience",
      desc = "Sell junk and repair at vendors, fast loot, decline duels, accept summons, screenshots of achievements." },
    { key = "monitor", name = "Addon monitor",
      desc = "Watches every loaded addon for Lua errors, blocked (tainted) actions, memory growth, CPU use and frame hitches. /kutz mon opens the report." },
}

local KEYS = {}
for _, m in ipairs(ns.MODULES) do KEYS[m.key] = m end

-- is this module switched on? (before the settings load: yes)
function ns.Enabled(key)
    local db = KutzUIDB
    return not (db and db.modules and db.modules[key] == false)
end

function ns.SetModuleEnabled(key, on)
    if not KutzUIDB or not KEYS[key] then return end
    KutzUIDB.modules = KutzUIDB.modules or {}
    if on then KutzUIDB.modules[key] = nil else KutzUIDB.modules[key] = false end
end

local queue = {}                 -- files waiting for the settings to load
ns.moduleMemory = {}             -- label -> KB allocated while its code first ran
ns.moduleErrors = {}

local function Label(keys) return table.concat(keys, "+") end

ns.startedOn = {}                -- key -> was it on when the game started (the Modules page compares)

-- Child addons register after KutzUI's ADDON_LOADED has already run.
local function StartModule(m)
    local on = false
    for _, k in ipairs(m.keys) do if ns.Enabled(k) then on = true end end
    local label = Label(m.keys)
    if on then
        local before = collectgarbage("count")
        local ok, err = pcall(m.body)
        ns.moduleMemory[label] = (ns.moduleMemory[label] or 0) + (collectgarbage("count") - before)
        if not ok then
            ns.moduleErrors[label] = tostring(err)
            print("|cff33ff99KutzUI:|r module '" .. label .. "' failed to start (please report): " .. tostring(err))
        end
    else
        ns.moduleMemory[label] = nil
    end
end

function ns.Module(keys, body)
    local m = { keys = type(keys) == "table" and keys or { keys }, body = body }
    if ns.modulesReady then StartModule(m) else queue[#queue + 1] = m end
end

local function RunModules()
    for _, m in ipairs(ns.MODULES) do ns.startedOn[m.key] = ns.Enabled(m.key) end
    for _, m in ipairs(queue) do StartModule(m) end
    queue = {}
    ns.modulesReady = true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    KutzUIDB = KutzUIDB or {}
    if ns.ProfileApplyForCharacter then pcall(ns.ProfileApplyForCharacter) end    -- this character's own profile, before anything reads a setting
    RunModules()
end)

---------------------------------------------------------------------------
-- Printing, /kutz and the debug / memory reports
---------------------------------------------------------------------------
function ns.Print(msg)
    print("|cff33ff99KutzUI:|r " .. tostring(msg))
end

local slash = {}                 -- command -> function(arg)
local debuggers = {}             -- functions run by /kutz debug

function ns.RegisterSlash(cmd, fn) slash[cmd] = fn end
function ns.RegisterDebug(fn) debuggers[#debuggers + 1] = fn end

---------------------------------------------------------------------------
-- Memory of EVERY loaded addon (not just ours). Kept in KutzUIDB.memLog so it can be read from the
-- saved file after logging out: a note every 5 minutes out of combat, and one each /kutz mem.
---------------------------------------------------------------------------
local MEMLOG_MAX = 48
local MEMLOG_EVERY = 300

local function AddonCount()
    local f = (C_AddOns and C_AddOns.GetNumAddOns) or _G.GetNumAddOns
    return f and f() or 0
end
local function AddonName(i)
    local f = (C_AddOns and C_AddOns.GetAddOnInfo) or _G.GetAddOnInfo
    return f and f(i)
end
local function AddonLoaded(i)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if not f then return true end
    return f(i) and true or false
end

-- { { name = "Questie", kb = 81234 }, ... } biggest first. Updates the numbers first.
function ns.AddonMemory()
    UpdateAddOnMemoryUsage()
    local list = {}
    for i = 1, AddonCount() do
        local name = AddonName(i)
        if type(name) == "string" and AddonLoaded(i) then
            local ok, kb = pcall(GetAddOnMemoryUsage, i)
            if ok and type(kb) == "number" then list[#list + 1] = { name = name, kb = kb } end
        end
    end
    table.sort(list, function(a, b) return a.kb > b.kb end)
    return list
end

local function Size(kb)
    if kb >= 1024 then return string.format("%.1f MB", kb / 1024) end
    return string.format("%.0f KB", kb)
end
ns.MemSize = Size

function ns.MemSnapshot(why)
    local list = ns.AddonMemory()
    local snap = { t = time and time() or 0, why = why, total = 0, a = {} }
    for _, e in ipairs(list) do
        snap.a[e.name] = math.floor(e.kb + 0.5)
        snap.total = snap.total + snap.a[e.name]
    end
    local log = KutzUIDB.memLog
    if type(log) ~= "table" then log = {}; KutzUIDB.memLog = log end
    log[#log + 1] = snap
    while #log > MEMLOG_MAX do table.remove(log, 1) end
    return list, snap
end

local function MemTick()
    if not InCombatLockdown() then pcall(ns.MemSnapshot, "auto") end
    C_Timer.After(MEMLOG_EVERY, MemTick)
end
C_Timer.After(MEMLOG_EVERY, MemTick)

slash.mem = function()
    UpdateAddOnMemoryUsage()
    local before = GetAddOnMemoryUsage(ADDON_NAME)
    collectgarbage("collect")
    local list = ns.MemSnapshot("mem")
    local after = GetAddOnMemoryUsage(ADDON_NAME)
    local total, parts = 0, {}
    for _, e in ipairs(list) do
        total = total + e.kb
        parts[#parts + 1] = e.name .. " " .. Size(e.kb)
    end
    if #parts > 0 then
        ns.Print("all addons (" .. Size(total) .. " together, biggest first): " .. table.concat(parts, ", "))
    end
    ns.Print(string.format("KutzUI: %.0f KB in use right now, %.0f KB after cleaning up garbage (the second number is what the addon really keeps)", before, after))
    local parts = {}
    for _, m in ipairs(ns.MODULES) do
        local on = ns.Enabled(m.key)
        parts[#parts + 1] = m.name .. "=" .. (on and "on" or "OFF")
    end
    ns.Print("modules: " .. table.concat(parts, ", "))
    local mem = {}
    for label, kb in pairs(ns.moduleMemory) do mem[#mem + 1] = string.format("%s %.0f KB", label, kb) end
    table.sort(mem)
    if #mem > 0 then ns.Print("allocated while starting (approximate, includes some garbage): " .. table.concat(mem, ", ")) end
end

slash.debug = function()
    for _, fn in ipairs(debuggers) do
        local ok, err = pcall(fn)
        if not ok then ns.Print("debug error: " .. tostring(err)) end
    end
    ns.Print("font=" .. tostring(ns.CurrentFontKey()) .. "  path=" .. tostring(ns.FontPathFor(ns.CurrentFontKey())))
    for label, err in pairs(ns.moduleErrors) do ns.Print("module " .. label .. " failed: " .. err) end
end

-- Opens the settings window, loading the KutzUI_Options addon the first time.
function ns.OpenSettings()
    if not ns.ToggleLayoutPanel then
        local loadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        local loaded, reason
        if loadAddOn then loaded, reason = loadAddOn("KutzUI_Options") end
        if not ns.ToggleLayoutPanel then
            ns.Print("The settings window is its own addon (KutzUI_Options) and it could not be loaded ("
                .. tostring(reason or "not found") .. "). Its folder must sit next to KutzUI in Interface/AddOns; see the README.")
            return
        end
    end
    ns.ToggleLayoutPanel()
end

SLASH_KUTZUI1 = "/kutz"
SlashCmdList["KUTZUI"] = function(msg)
    local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
    if cmd == "" or cmd == "layout" or cmd == "menu" then
        ns.OpenSettings()
        return
    end
    local fn = slash[cmd]
    if fn then fn(arg); return end
    local list = {}
    for name in pairs(slash) do list[#list + 1] = name end
    table.sort(list)
    ns.Print("/kutz (menu) | " .. table.concat(list, " | "))
end
