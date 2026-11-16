---------------------------------------------------------------------------
-- KutzUI / Monitor              (module "monitor")
--
-- Watches EVERY addon that is running, not just this one, and tells you what is worth fixing.
-- Open the report with  /kutz mon   (menu: Modules page switches the whole thing on or off).
--
--   Lua errors     every error, whichever addon it came from, counted per distinct message
--                  (the addon is found from the file path in the message or the stack). Blizzard's own
--                  error window still shows exactly as before; this only listens.
--   Blocked        "an addon tried a protected action" (taint) events: ADDON_ACTION_BLOCKED / FORBIDDEN.
--   Frame time     how long each frame took, as a histogram, and every hitch of 100 ms or more
--                  (with whether you were in combat and, if CPU profiling is on, the busiest addon).
--   Memory         per addon right now, and how fast each one is growing (a leak shows as steady
--                  growth), from the log Core.lua already keeps.
--   CPU            per addon, in ms of work per second. The game only measures this while its script
--                  profiling switch is on:  /kutz mon cpu on  then /reload  (it slows the game a little,
--                  so switch it off again when you are done:  /kutz mon cpu off).
--
-- The report starts with a ranked "refactor candidates" list, then one row per addon, then the details.
-- Everything is kept in KutzUIDB.monitor, so the saved file after logging out holds the last session
-- plus short summaries of the five before it. The same moment writes KutzUIDB.monitor.findings,
-- a short ranked copy (errors, blocked actions, memory growth) of plain strings and numbers.
-- Opening this report writes that copy too.
--
--   /kutz mon              open the report window      /kutz mon print   the top of it in chat
--   /kutz mon reset        start counting again        /kutz mon alert on|off   a chat line for a NEW error
--   /kutz mon cpu on|off   the game's CPU profiling (needs /reload)
--
-- Cost: nothing runs per error except a counter; one tiny function per frame (the frame-time counter);
-- a 10 second tick that does real work only while CPU profiling is on.
---------------------------------------------------------------------------
local ns = _G.KutzUI

ns.Module("monitor", function()

local Report                                -- defined below; the logout handler calls it

local issecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not issecret(v) end

local HITCH            = 0.100      -- seconds: a frame this long or longer is listed as a hitch
local MAX_ERRORS       = 60         -- distinct error messages kept (the counts stay exact beyond that)
local MAX_HITCHES      = 40
local MAX_HISTORY      = 5
local TICK             = 10         -- seconds between CPU samples
local CPU_HEAVY_AVG    = 3          -- ms of work per second, averaged: worth a look
local CPU_HEAVY_PEAK   = 30         -- ms per second over one 10 s window
local LEAK_KB_PER_HOUR = 500
local BIG_ADDON_KB     = 50 * 1024

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local function Fresh()
    return {
        t0 = time(), tEnd = time(),
        errTotal = 0, errOverflow = 0, errors = {}, errByAddon = {},
        taintTotal = 0, taint = {},
        frames = 0, frameSum = 0, hist = { 0, 0, 0, 0, 0, 0, 0 },
        hitchN = 0, hitchCombat = 0, worst = 0, hitches = {},
        cpu = {}, cpuT0 = nil,
    }
end

local function Top(map, n)                          -- { {name, value}, ... } biggest first
    local list = {}
    for k, v in pairs(map) do list[#list + 1] = { k, v } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    while #list > n do table.remove(list) end
    return list
end

local function Summarize(c)
    local errs = {}
    for _, e in ipairs(Top(c.errByAddon or {}, 3)) do errs[#errs + 1] = e[1] .. " x" .. e[2] end
    local cpuAvg = {}
    local span = (c.cpuLastT and c.cpuT0) and (c.cpuLastT - c.cpuT0) or 0
    if span > 0 then
        for name, r in pairs(c.cpu or {}) do cpuAvg[name] = (r.total - (r.base or r.total)) / span end
    end
    local cpu = {}
    for _, e in ipairs(Top(cpuAvg, 3)) do cpu[#cpu + 1] = string.format("%s %.1f ms/s", e[1], e[2]) end
    return {
        t0 = c.t0, minutes = math.floor(((c.tEnd or c.t0) - c.t0) / 60),
        errors = c.errTotal or 0, errAddons = table.concat(errs, ", "),
        blocked = c.taintTotal or 0,
        hitches = c.hitchN or 0, worstMs = math.floor((c.worst or 0) * 1000 + 0.5),
        fps = (c.frameSum or 0) > 0 and math.floor(c.frames / c.frameSum + 0.5) or 0,
        cpuTop = table.concat(cpu, ", "),
    }
end

KutzUIDB.monitor = type(KutzUIDB.monitor) == "table" and KutzUIDB.monitor or {}
local store = KutzUIDB.monitor
store.history = type(store.history) == "table" and store.history or {}
if type(store.cur) == "table" and store.cur.t0 then          -- the session before this one
    local ok, s = pcall(Summarize, store.cur)
    if ok then
        table.insert(store.history, s)
        while #store.history > MAX_HISTORY do table.remove(store.history, 1) end
    end
end
local cur = Fresh()
store.cur = cur

---------------------------------------------------------------------------
-- Errors
---------------------------------------------------------------------------
local ADDON_PATH = "[Ii]nterface[\\/][Aa]dd[Oo]ns[\\/]([^\\/]+)[\\/]"
local lastAlert = 0

local function Classify(msg, stack)
    -- the addon named in the message; if the message points into Blizzard's code, the first real addon in the stack
    local first = msg:match(ADDON_PATH)
    if first and not first:find("^Blizzard_") then return first, false end
    for name in (stack or ""):gmatch(ADDON_PATH) do
        if not name:find("^Blizzard_") then return name, true end    -- true: "through Blizzard code"
    end
    if first then return first, false end
    if msg:find("[Ff]rame[Xx][Mm][Ll]") or msg:find("SharedXML") then return "Blizzard UI", false end
    return "(unknown)", false
end

local function Normalize(msg)
    msg = msg:gsub("0x%x+", "0x?")                  -- addresses differ between otherwise identical errors
    if #msg > 300 then msg = msg:sub(1, 300) end
    return msg
end

local function Record(msg)
    local c = cur
    c.errTotal = c.errTotal + 1
    local text = (type(msg) == "string" and not issecret(msg)) and msg or "(message hidden by the game)"
    local stack = ""
    if _G.debugstack then
        local ok, s = pcall(_G.debugstack, 2, 14, 0)
        if ok and type(s) == "string" then
            -- leave out our own frames so the monitor never blames itself
            s = s:gsub("[^\n]*Monitor%.lua[^\n]*\n?", "")
            stack = s
        end
    end
    local addon, via = Classify(text, stack)
    c.errByAddon[addon] = (c.errByAddon[addon] or 0) + 1

    local sig = addon .. "|" .. Normalize(text)
    local rec = c.errors[sig]
    if not rec then
        local n = 0
        for _ in pairs(c.errors) do n = n + 1 end
        if n >= MAX_ERRORS then c.errOverflow = c.errOverflow + 1 return end
        rec = { addon = addon, via = via, msg = text:sub(1, 400), stack = stack:sub(1, 800),
                count = 0, first = time() }
        c.errors[sig] = rec
        if KutzUIDB.monAlert ~= false and GetTime() - lastAlert > 10 then
            lastAlert = GetTime()
            print("|cffff6666KutzUI monitor:|r new error in |cffffd24d" .. addon .. "|r: "
                .. text:sub(1, 90):gsub("|", "||") .. "   (/kutz mon)")
        end
    end
    rec.count = rec.count + 1
    rec.last = time()
    rec.combat = InCombatLockdown() and true or false
end

local original
local inHandler = false
local function Handler(msg)
    if inHandler then return end                    -- another handler chained back to us: do not loop
    inHandler = true
    pcall(Record, msg)
    local ret
    if original then
        local ok, r = pcall(original, msg)          -- Blizzard's / BugSack's own handling goes on as before
        if ok then ret = r end
    end
    inHandler = false
    return ret
end

local function InstallHandler()
    if not (_G.geterrorhandler and _G.seterrorhandler) then return end
    local now = geterrorhandler()
    if now == Handler then return end
    original = now
    seterrorhandler(Handler)
end
InstallHandler()

---------------------------------------------------------------------------
-- Blocked / tainted actions
---------------------------------------------------------------------------
local function RecordTaint(event, addon, fn)
    addon = Plain(addon) and tostring(addon) or "?"
    fn = Plain(fn) and tostring(fn) or "?"
    local kind = event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked"
    local key = kind .. "|" .. addon .. "|" .. fn
    local rec = cur.taint[key]
    if not rec then
        local n = 0
        for _ in pairs(cur.taint) do n = n + 1 end
        if n >= MAX_ERRORS then return end
        rec = { addon = addon, fn = fn, kind = kind, count = 0, first = time() }
        cur.taint[key] = rec
    end
    rec.count = rec.count + 1
    rec.last = time()
    cur.taintTotal = cur.taintTotal + 1
end

---------------------------------------------------------------------------
-- Which addons exist and are loaded
---------------------------------------------------------------------------
local function Call(fn, ...) if fn then return fn(...) end end
local function NumAddOns() return Call((C_AddOns and C_AddOns.GetNumAddOns) or _G.GetNumAddOns) or 0 end
local function AddOnName(i)
    local n = Call((C_AddOns and C_AddOns.GetAddOnInfo) or _G.GetAddOnInfo, i)
    if type(n) == "table" then n = n.name end
    return type(n) == "string" and n or nil
end
local function IsLoaded(i) return Call((C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded, i) and true or false end

local function LoadedNames()
    local list = {}
    for i = 1, NumAddOns() do
        local n = AddOnName(i)
        if n and IsLoaded(i) then list[#list + 1] = n end
    end
    return list
end

---------------------------------------------------------------------------
-- CPU (only while the game's script profiling is on)
---------------------------------------------------------------------------
local function ProfilingOn() return _G.GetCVar and GetCVar("scriptProfile") == "1" end
local cpuPrev, lastTop = {}, nil

local function SampleCPU()
    if not ProfilingOn() then return end
    local upd = (C_AddOns and C_AddOns.UpdateAddOnCPUUsage) or _G.UpdateAddOnCPUUsage
    local get = (C_AddOns and C_AddOns.GetAddOnCPUUsage) or _G.GetAddOnCPUUsage
    if not (upd and get) then return end
    upd()
    local now = GetTime()
    local dt = cur.cpuLastT and (now - cur.cpuLastT) or nil
    cur.cpuT0 = cur.cpuT0 or now
    cur.cpuLastT = now
    local topName, topRate = nil, 0
    for _, name in ipairs(LoadedNames()) do
        local ok, total = pcall(get, name)
        if ok and type(total) == "number" then
            local rec = cur.cpu[name]
            if not rec then rec = { base = total, total = total, peak = 0, last = 0 }; cur.cpu[name] = rec end
            local prev = cpuPrev[name]
            cpuPrev[name] = total
            rec.total = total
            if prev and dt and dt > 0 and total >= prev then
                local rate = (total - prev) / dt
                rec.last = rate
                if rate > rec.peak then rec.peak = rate end
                if rate > topRate then topName, topRate = name, rate end
            end
        end
    end
    lastTop = (topRate >= 0.5) and topName or nil
end

---------------------------------------------------------------------------
-- Frame time
---------------------------------------------------------------------------
local skip = 3                                      -- frames to ignore after a loading screen
local frameWatcher = CreateFrame("Frame")
frameWatcher:SetScript("OnUpdate", function(_, e)
    if skip > 0 then skip = skip - 1 return end
    if e > 5 then return end                        -- the game was paused / minimised, not slow
    local c = cur
    c.frames = c.frames + 1
    c.frameSum = c.frameSum + e
    local h = c.hist
    if     e < 0.0084 then h[1] = h[1] + 1
    elseif e < 0.0167 then h[2] = h[2] + 1
    elseif e < 0.0334 then h[3] = h[3] + 1
    elseif e < 0.0500 then h[4] = h[4] + 1
    elseif e < HITCH  then h[5] = h[5] + 1
    elseif e < 0.250  then h[6] = h[6] + 1
    else                   h[7] = h[7] + 1 end
    if e >= HITCH then
        local combat = InCombatLockdown() and true or false
        c.hitchN = c.hitchN + 1
        if combat then c.hitchCombat = c.hitchCombat + 1 end
        if e > c.worst then c.worst = e end
        local list = c.hitches
        list[#list + 1] = { t = time(), ms = math.floor(e * 1000 + 0.5), combat = combat, suspect = lastTop }
        if #list > MAX_HITCHES then table.remove(list, 1) end
    end
end)

---------------------------------------------------------------------------
-- Events and the 10 second tick
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("LOADING_SCREEN_DISABLED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        pcall(RecordTaint, event, a1, a2)
    elseif event == "PLAYER_LOGOUT" then
        cur.tEnd = time()
        local ok, err = pcall(Report)         -- ranked findings into KutzUIDB.monitor.findings, for the export
        if not ok then print("|cff33ff99KutzUI:|r monitor snapshot was not saved: " .. tostring(err)) end
    else
        skip = 3
        InstallHandler()                            -- an addon that loaded later may have replaced the handler
    end
end)

local function Tick()
    cur.tEnd = time()
    if ProfilingOn() then pcall(SampleCPU) end
    InstallHandler()
    C_Timer.After(TICK, Tick)
end
C_Timer.After(TICK, Tick)
C_Timer.After(20, function() if not InCombatLockdown() and ns.MemSnapshot then pcall(ns.MemSnapshot, "monitor") end end)

---------------------------------------------------------------------------
-- The report
---------------------------------------------------------------------------
local function Clock(t) return t and date("%H:%M:%S", t) or "?" end
local function Dur(sec)
    sec = math.max(0, math.floor(sec))
    if sec >= 3600 then return string.format("%dh %02dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60)) end
    return string.format("%dm %02ds", math.floor(sec / 60), sec % 60)
end
local function KB(kb)
    if not kb then return "-" end
    if kb >= 1024 then return string.format("%.1f MB", kb / 1024) end
    return string.format("%.0f KB", kb)
end
local function OneLine(s) return (tostring(s):gsub("[\r\n]+", " ")) end

-- KB per hour each addon is growing by (least squares over this session's memory notes), or nil if too little data
local function Growth()
    local log, pts = KutzUIDB.memLog, {}
    if type(log) ~= "table" then return nil end
    for _, s in ipairs(log) do if (s.t or 0) >= cur.t0 and type(s.a) == "table" then pts[#pts + 1] = s end end
    if #pts < 2 then return nil end
    local span = pts[#pts].t - pts[1].t
    if span < 600 then return nil end
    local t0, out = pts[1].t, {}
    for name in pairs(pts[#pts].a) do
        local n, sx, sy, sxx, sxy = 0, 0, 0, 0, 0
        for _, s in ipairs(pts) do
            local y = s.a[name]
            if y then
                local x = (s.t - t0) / 3600
                n, sx, sy, sxx, sxy = n + 1, sx + x, sy + y, sxx + x * x, sxy + x * y
            end
        end
        local den = n * sxx - sx * sx
        if n >= 2 and den > 0 then out[name] = (n * sxy - sx * sy) / den end
    end
    return out, span
end

function Report()
    local lines = {}
    local function L(s) lines[#lines + 1] = s or "" end

    -- gather everything once
    local mem = {}
    if ns.AddonMemory then
        local ok, list = pcall(ns.AddonMemory)
        if ok and type(list) == "table" then for _, e in ipairs(list) do mem[e.name] = e.kb end end
    end
    local growth, growSpan = Growth()
    local profiling = ProfilingOn()
    local cpuSpan = (cur.cpuLastT and cur.cpuT0) and (cur.cpuLastT - cur.cpuT0) or 0
    local rows, loaded = {}, LoadedNames()
    local function Row(name)
        local r = rows[name]
        if not r then r = { name = name, err = 0, taint = 0 }; rows[name] = r end
        return r
    end
    for _, n in ipairs(loaded) do Row(n) end
    for name, n in pairs(cur.errByAddon) do Row(name).err = n end
    for _, t in pairs(cur.taint) do Row(t.addon).taint = Row(t.addon).taint + t.count end
    for name, kb in pairs(mem) do Row(name).kb = kb end
    if growth then for name, g in pairs(growth) do Row(name).grow = g end end
    if profiling and cpuSpan > 0 then
        for name, c in pairs(cur.cpu) do
            local r = Row(name)
            r.cpuAvg, r.cpuPeak = (c.total - c.base) / cpuSpan, c.peak
        end
    end

    -- refactor candidates
    local cand = {}
    local function Add(score, tag, text, addon) cand[#cand + 1] = { score = score, tag = tag, text = text, addon = addon } end
    for _, r in pairs(rows) do
        if r.err > 0 then
            local worst
            for _, e in pairs(cur.errors) do
                if e.addon == r.name and (not worst or e.count > worst.count) then worst = e end
            end
            Add(1000 + math.min(r.err, 900), "ERRORS",
                string.format("%s: %d error%s%s", r.name, r.err, r.err == 1 and "" or "s",
                    worst and ("  - most often: " .. OneLine(worst.msg):sub(1, 110)) or ""), r.name)
        end
        if r.taint > 0 then
            Add(800 + math.min(r.taint, 100), "BLOCKED", string.format("%s: %d blocked / forbidden action%s (taint)", r.name, r.taint, r.taint == 1 and "" or "s"), r.name)
        end
        if r.cpuAvg and (r.cpuAvg >= CPU_HEAVY_AVG or (r.cpuPeak or 0) >= CPU_HEAVY_PEAK) then
            Add(600 + r.cpuAvg, "CPU", string.format("%s: %.1f ms/s on average, %.1f ms/s at its worst 10 s", r.name, r.cpuAvg, r.cpuPeak or 0), r.name)
        end
        if r.grow and r.grow >= LEAK_KB_PER_HOUR then
            Add(500 + math.min(r.grow / 100, 99), "MEMORY GROWTH", string.format("%s: growing about %s per hour (now %s) - possible leak", r.name, KB(r.grow), KB(r.kb)), r.name)
        end
        if r.kb and r.kb >= BIG_ADDON_KB then
            Add(300 + r.kb / 10240, "BIG", string.format("%s: %s of memory", r.name, KB(r.kb)), r.name)
        end
    end
    if cur.hitchN >= 5 then
        local by = {}
        for _, h in ipairs(cur.hitches) do if h.suspect then by[h.suspect] = (by[h.suspect] or 0) + 1 end end
        local top = Top(by, 1)[1]
        Add(400 + math.min(cur.hitchN, 99), "HITCHES", string.format("%d frames of %d ms or more (worst %d ms), %d in combat%s",
            cur.hitchN, HITCH * 1000, math.floor(cur.worst * 1000 + 0.5), cur.hitchCombat,
            top and (", busiest addon at those moments: " .. top[1]) or (profiling and "" or "  (turn CPU profiling on to see who)")),
            top and top[1] or nil)
    end
    for label, err in pairs(ns.moduleErrors or {}) do
        Add(1500, "KUTZUI MODULE FAILED", label .. ": " .. OneLine(err):sub(1, 140), label)
    end
    table.sort(cand, function(a, b) return a.score > b.score end)

    -- header
    local version = select(1, GetBuildInfo and GetBuildInfo() or "?")
    L("KUTZUI MONITOR - every loaded addon")
    L(string.format("Session started %s, %s so far.   Game %s.   %d addons loaded.", Clock(cur.t0), Dur(time() - cur.t0), tostring(version), #loaded))
    L("CPU profiling: " .. (profiling and "ON" or "OFF   (to measure CPU: /kutz mon cpu on, then /reload)"))
    L()

    L("== REFACTOR CANDIDATES (worst first) ==")
    if #cand == 0 then L("  nothing found yet - no errors, no blocked actions, nothing heavy.") end
    for i, c in ipairs(cand) do
        if i > 15 then L("  ... and " .. (#cand - 15) .. " more") break end
        L(string.format("%2d. [%s] %s", i, c.tag, c.text))
    end
    L()

    -- one row per addon
    L("== ALL ADDONS ==   (sorted: errors, then blocked, then CPU, then memory)")
    L(string.format("%-30s %6s %7s %10s %12s %9s %9s", "Addon", "Errors", "Blocked", "Memory", "Growth/hour", "CPU avg", "CPU peak"))
    local list = {}
    for _, r in pairs(rows) do list[#list + 1] = r end
    table.sort(list, function(a, b)
        if a.err ~= b.err then return a.err > b.err end
        if a.taint ~= b.taint then return a.taint > b.taint end
        if (a.cpuAvg or 0) ~= (b.cpuAvg or 0) then return (a.cpuAvg or 0) > (b.cpuAvg or 0) end
        return (a.kb or 0) > (b.kb or 0)
    end)
    for _, r in ipairs(list) do
        L(string.format("%-30s %6d %7d %10s %12s %9s %9s", r.name:sub(1, 30), r.err, r.taint, KB(r.kb),
            r.grow and (KB(r.grow)) or "-",
            r.cpuAvg and string.format("%.2f", r.cpuAvg) or "-", r.cpuPeak and string.format("%.1f", r.cpuPeak) or "-"))
    end
    if not growth then L("  (memory growth needs about 10 minutes of notes; one is taken every 5 minutes)") end
    if profiling then L("  CPU is in ms of work per second; 1 ms/s is about 0.1% of one core. Averaged over " .. Dur(cpuSpan) .. ".") end
    L()

    -- errors in detail
    L("== LUA ERRORS ==   " .. cur.errTotal .. " in total" .. (cur.errOverflow > 0 and (", " .. cur.errOverflow .. " more not listed (too many different ones)") or ""))
    local errs = {}
    for _, e in pairs(cur.errors) do errs[#errs + 1] = e end
    table.sort(errs, function(a, b) return a.count > b.count end)
    if #errs == 0 then L("  none") end
    for _, e in ipairs(errs) do
        L(string.format("  %dx  [%s]%s  first %s, last %s%s", e.count, e.addon, e.via and " (through Blizzard code)" or "", Clock(e.first), Clock(e.last), e.combat and ", in combat" or ""))
        L("      " .. OneLine(e.msg))
        if e.stack and e.stack ~= "" then
            local n = 0
            for line in e.stack:gmatch("[^\n]+") do
                n = n + 1
                if n > 5 then L("      ...") break end
                L("      at " .. line)
            end
        end
    end
    L()

    -- taint
    L("== BLOCKED / FORBIDDEN ACTIONS (taint) ==   " .. cur.taintTotal .. " in total")
    local ts = {}
    for _, t in pairs(cur.taint) do ts[#ts + 1] = t end
    table.sort(ts, function(a, b) return a.count > b.count end)
    if #ts == 0 then L("  none") end
    for _, t in ipairs(ts) do L(string.format("  %dx  [%s] %s  %s", t.count, t.addon, t.kind, t.fn)) end
    L()

    -- frame time
    L("== FRAME TIME ==")
    if cur.frameSum > 0 then
        local names = { "under 8 ms", "8-17 ms", "17-33 ms", "33-50 ms", "50-100 ms", "100-250 ms", "250 ms+" }
        L(string.format("  %d frames, %d fps on average.", cur.frames, math.floor(cur.frames / cur.frameSum + 0.5)))
        for i = 1, 7 do
            L(string.format("  %-11s %5.1f%%  (%d)", names[i], 100 * cur.hist[i] / cur.frames, cur.hist[i]))
        end
        L(string.format("  hitches (%d ms or more): %d, %d of them in combat, worst %d ms", HITCH * 1000, cur.hitchN, cur.hitchCombat, math.floor(cur.worst * 1000 + 0.5)))
        for i = math.max(1, #cur.hitches - 11), #cur.hitches do
            local h = cur.hitches[i]
            L(string.format("    %s  %4d ms  %s%s", Clock(h.t), h.ms, h.combat and "combat" or "      ", h.suspect and ("  busiest addon: " .. h.suspect) or ""))
        end
    else
        L("  no frames counted yet")
    end
    L()

    -- KutzUI itself
    L("== KUTZUI MODULES ==   (memory allocated while each started, approximate)")
    local km = {}
    for label, kb in pairs(ns.moduleMemory or {}) do km[#km + 1] = { label, kb } end
    table.sort(km, function(a, b) return a[2] > b[2] end)
    for _, e in ipairs(km) do L(string.format("  %-22s %s", e[1], KB(e[2]))) end
    L()

    -- earlier sessions
    L("== EARLIER SESSIONS ==")
    if #store.history == 0 then L("  none saved yet") end
    for i = #store.history, 1, -1 do
        local s = store.history[i]
        L(string.format("  %s  %d min  %d fps  errors %d%s  blocked %d  hitches %d (worst %d ms)%s",
            date("%Y-%m-%d %H:%M", s.t0 or 0), s.minutes or 0, s.fps or 0, s.errors or 0,
            (s.errAddons and s.errAddons ~= "") and (" (" .. s.errAddons .. ")") or "",
            s.blocked or 0, s.hitches or 0, s.worstMs or 0,
            (s.cpuTop and s.cpuTop ~= "") and ("  CPU: " .. s.cpuTop) or ""))
    end

    -- Ranked copy kept in the saved file. Plain strings and numbers only, so a hidden
    -- value can never land there.
    local findings = {}
    for i, c in ipairs(cand) do
        if i > 15 then break end
        findings[i] = { rank = i, tag = c.tag, score = c.score, addon = c.addon, text = c.text }
    end
    local errList = {}
    for _, e in ipairs(errs) do
        errList[#errList + 1] = {
            addon = e.addon, count = e.count, message = OneLine(e.msg),
            throughBlizzard = e.via and true or false,
            first = e.first, last = e.last, inCombat = e.combat and true or false,
            stack = (e.stack and e.stack ~= "") and OneLine(e.stack):sub(1, 400) or nil,
        }
    end
    local blockedList = {}
    for _, t in ipairs(ts) do
        blockedList[#blockedList + 1] = { addon = t.addon, kind = t.kind, fn = t.fn, count = t.count }
    end
    local growthList = {}
    for _, r in pairs(rows) do
        if type(r.grow) == "number" then
            growthList[#growthList + 1] = {
                addon = r.name, kbPerHour = math.floor(r.grow + 0.5),
                kb = type(r.kb) == "number" and math.floor(r.kb + 0.5) or nil,
            }
        end
    end
    table.sort(growthList, function(a, b) return a.kbPerHour > b.kbPerHour end)
    while #growthList > 15 do table.remove(growthList) end
    local hist = {}
    for i, s in ipairs(store.history) do
        hist[i] = {
            started = s.t0, minutes = s.minutes or 0, fps = s.fps or 0, errors = s.errors or 0,
            errorAddons = s.errAddons or "", blocked = s.blocked or 0, hitches = s.hitches or 0,
            worstMs = s.worstMs or 0, cpuTop = s.cpuTop or "",
        }
    end
    local game = version
    if type(game) ~= "string" or game == "?" or not Plain(game) then game = nil end
    store.findings = {
        updated = time(), game = game,
        session = {
            started = cur.t0, ended = cur.tEnd or time(),
            minutes = math.floor(((cur.tEnd or cur.t0) - (cur.t0 or 0)) / 60),
            fps = (cur.frameSum or 0) > 0 and math.floor(cur.frames / cur.frameSum + 0.5) or 0,
            errors = cur.errTotal or 0, errorsOmitted = cur.errOverflow or 0,
            blocked = cur.taintTotal or 0, hitches = cur.hitchN or 0,
            hitchesInCombat = cur.hitchCombat or 0,
            worstMs = math.floor((cur.worst or 0) * 1000 + 0.5),
            addonsLoaded = #loaded, cpuProfiling = profiling and true or false,
        },
        findings = findings, errors = errList, blocked = blockedList,
        memoryGrowth = growthList, history = hist,
    }
    return table.concat(lines, "\n"), cand
end

---------------------------------------------------------------------------
-- The window (same build as the chat copy window)
---------------------------------------------------------------------------
local frame

local function Build()
    frame = CreateFrame("Frame", "KutzMonitorFrame", UIParent)
    frame.edit, frame.plain = false, false
    frame:SetSize(900, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local edge = frame:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0.17, 0.18, 0.24, 1)
    edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetColorTexture(0.045, 0.05, 0.07, 0.97)
    bg:SetAllPoints()

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    ns.StyleText(frame.title, 14)
    frame.title:SetTextColor(1, 0.82, 0)
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.title:SetText("Addon monitor")

    frame.hint = frame:CreateFontString(nil, "OVERLAY")
    ns.StyleText(frame.hint, 11)
    frame.hint:SetTextColor(0.62, 0.65, 0.72)
    frame.hint:SetPoint("TOPLEFT", 14, -34)
    frame.hint:SetWidth(870)
    frame.hint:SetJustifyH("LEFT")
    frame.hint:SetText("Click in the text, press Ctrl+A then Ctrl+C to copy it. Refresh updates the numbers.")

    local function Button(label, w, x, onClick)
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(w, 24)
        b:SetPoint("BOTTOMRIGHT", x, 12)
        local e = b:CreateTexture(nil, "BACKGROUND"); e:SetColorTexture(0.17, 0.18, 0.24, 1); e:SetAllPoints()
        local f = b:CreateTexture(nil, "BACKGROUND", nil, 1); f:SetColorTexture(0.11, 0.12, 0.16, 1)
        f:SetPoint("TOPLEFT", 1, -1); f:SetPoint("BOTTOMRIGHT", -1, 1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetColorTexture(1, 0.82, 0, 0.12); hl:SetAllPoints()
        local t = b:CreateFontString(nil, "OVERLAY")
        ns.StyleText(t, 12)
        t:SetPoint("CENTER")
        t:SetText(label)
        b:SetScript("OnClick", onClick)
        return b
    end
    Button("Close", 90, -14, function() frame:Hide() end)
    Button("Select all", 100, -112, function()
        if frame.edit then frame.edit:SetFocus(); frame.edit:HighlightText() end
    end)
    Button("Refresh", 90, -220, function() ns.MonitorOpen() end)
    Button("Reset counts", 120, -318, function()
        cur = Fresh(); store.cur = cur; cpuPrev = {}
        ns.MonitorOpen()
    end)

    local ok, box = pcall(CreateFrame, "Frame", nil, frame, "ScrollingEditBoxTemplate")
    local scrollingEdit = ok and box and type(box.GetEditBox) == "function" and box:GetEditBox() or nil
    if scrollingEdit then
        box:SetPoint("TOPLEFT", 14, -58)
        box:SetPoint("BOTTOMRIGHT", -34, 46)
        frame.box = box
        frame.edit = scrollingEdit
        local okBar, bar = pcall(CreateFrame, "EventFrame", nil, frame, "MinimalScrollBar")
        if okBar and bar and _G.ScrollUtil and box.ScrollBox then
            bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
            bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 8, 0)
            pcall(_G.ScrollUtil.RegisterScrollBoxWithScrollBar, box.ScrollBox, bar)
        end
    else
        local eb = CreateFrame("EditBox", nil, frame)
        eb:SetMultiLine(true)
        eb:SetPoint("TOPLEFT", 14, -58)
        eb:SetPoint("BOTTOMRIGHT", -14, 46)
        frame.edit = eb
        frame.plain = true
    end
    local eb = frame.edit
    eb:SetAutoFocus(false)
    ns.StyleText(eb, 12, "")
    eb:SetTextColor(0.9, 0.92, 0.96)
    eb:SetScript("OnEscapePressed", function() frame:Hide() end)

    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "KutzMonitorFrame") end
    frame:Hide()
end

function ns.MonitorOpen()
    if not frame then Build() end
    local text = Report()
    if frame.plain then                              -- no scrolling box: only the top of the report fits
        local keep, n = {}, 0
        for line in text:gmatch("[^\n]+") do
            n = n + 1
            if n > 32 then break end
            keep[#keep + 1] = line
        end
        text = table.concat(keep, "\n")
    end
    if frame.box and frame.box.SetText then frame.box:SetText(text) else frame.edit:SetText(text) end
    frame:Show()
end

---------------------------------------------------------------------------
-- /kutz mon
---------------------------------------------------------------------------
ns.RegisterSlash("mon", function(arg)
    local cmd, rest = strsplit(" ", strtrim(arg or ""), 2)
    cmd = cmd or ""
    if cmd == "" or cmd == "open" or cmd == "report" then
        ns.MonitorOpen()
    elseif cmd == "print" then
        local _, cand = Report()
        if #cand == 0 then ns.Print("monitor: nothing to fix yet (no errors, nothing blocked, nothing heavy).") end
        for i = 1, math.min(#cand, 6) do ns.Print(string.format("monitor %d. [%s] %s", i, cand[i].tag, cand[i].text)) end
        ns.Print("monitor: /kutz mon for the full report")
    elseif cmd == "reset" then
        cur = Fresh(); store.cur = cur; cpuPrev = {}
        ns.Print("monitor: counts reset.")
    elseif cmd == "alert" then
        local on = rest ~= "off"
        if on then KutzUIDB.monAlert = nil else KutzUIDB.monAlert = false end
        ns.Print("monitor: a chat line for each new error is " .. (on and "ON" or "OFF") .. ".")
    elseif cmd == "cpu" then
        if rest == "on" then
            SetCVar("scriptProfile", "1")
            ns.Print("monitor: CPU profiling will be ON after /reload. It slows the game a little - switch it off with /kutz mon cpu off when you are done.")
        elseif rest == "off" then
            SetCVar("scriptProfile", "0")
            ns.Print("monitor: CPU profiling will be OFF after /reload.")
        else
            ns.Print("monitor: CPU profiling is " .. (ProfilingOn() and "ON" or "OFF") .. ".  /kutz mon cpu on | off  (then /reload)")
        end
    else
        ns.Print("/kutz mon  |  print  |  reset  |  alert on|off  |  cpu on|off")
    end
end)

end)
