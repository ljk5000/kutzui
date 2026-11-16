---------------------------------------------------------------------------
-- KutzUI / KutzLogFeed        (part of the "combatlog" module)
--
-- Collects the lines for KutzUI's own log (KutzLog.lua draws them).
--
-- The game does not let addons read the real combat log on this client (the log is restricted,
-- and listening to its event is refused - checked in game). These are the events an addon CAN
-- see, and what each gives:
--   UNIT_COMBAT (you, your target, your pet): hit / heal / miss, dodge, parry, block, absorb,
--     resist, immune ..., crit / crushing / glancing, the school. The amount may be hidden by the
--     game; then it is handed straight to the text, which can show it. It does NOT say who did it.
--   UNIT_SPELLCAST_SUCCEEDED (you, your pet): which spell was cast (with its icon), when readable.
--   your target dying, you dying.
--
-- One line = { t = time, dir = "out"|"in"|"pet"|"heal"|"info", who = name (may be hidden),
--   r,g,b = colour of the name, icon = texture, amount = number (may be hidden), what = words }
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("combatlog", function()

local issecret = issecretvalue or function() return false end
local MAX = 500

local feed = { first = 1, last = 0 }                -- ring of lines
ns.KLFeed = feed
local listeners = {}
function ns.KLOnLine(fn) listeners[#listeners + 1] = fn end

function ns.KLCount() return feed.last - feed.first + 1 end
function ns.KLLine(n)                                -- n = 1 is the newest
    local i = feed.last - n + 1
    if i < feed.first then return nil end
    return feed[i]
end
function ns.KLClear()
    for i = feed.first, feed.last do feed[i] = nil end
    feed.first, feed.last = 1, 0
    for _, fn in ipairs(listeners) do pcall(fn) end
end

local function Add(line)
    line.t = line.t or time()
    feed.last = feed.last + 1
    feed[feed.last] = line
    while feed.last - feed.first + 1 > MAX do
        feed[feed.first] = nil
        feed.first = feed.first + 1
    end
    for _, fn in ipairs(listeners) do pcall(fn, line) end
end
ns.KLAdd = Add

---------------------------------------------------------------------------
-- Words
---------------------------------------------------------------------------
local SCHOOLS = { [1] = "Physical", [2] = "Holy", [4] = "Fire", [8] = "Nature", [16] = "Frost", [32] = "Shadow", [64] = "Arcane" }
local SCHOOL_RGB = {
    [1] = { 1.00, 1.00, 0.55 }, [2] = { 1.00, 0.90, 0.50 }, [4] = { 1.00, 0.50, 0.00 }, [8] = { 0.30, 1.00, 0.30 },
    [16] = { 0.50, 1.00, 1.00 }, [32] = { 0.60, 0.60, 1.00 }, [64] = { 1.00, 0.50, 1.00 },
}
local function SchoolName(mask)
    if type(mask) ~= "number" or issecret(mask) then return nil end
    if SCHOOLS[mask] then return SCHOOLS[mask] end
    local getter = _G.C_Spell and _G.C_Spell.GetSchoolString
    local ok, s = pcall(getter or error, mask)
    if ok and type(s) == "string" and not issecret(s) then return s end
    return nil
end
function ns.KLSchoolRGB(mask)
    local c = type(mask) == "number" and not issecret(mask) and SCHOOL_RGB[mask]
    if c then return c[1], c[2], c[3] end
    return 1, 1, 1
end

local FLAG_WORDS = { CRITICAL = "crit", CRUSHING = "crushing", GLANCING = "glancing",
    BLOCK_REDUCED = "partly blocked", ABSORB = "absorbed", BLOCK = "blocked", RESIST = "resisted" }
local AVOID = { MISS = "miss", DODGE = "dodge", PARRY = "parry", BLOCK = "block", RESIST = "resist",
    ABSORB = "absorb", IMMUNE = "immune", EVADE = "evade", DEFLECT = "deflect", REFLECT = "reflect",
    INTERRUPT = "interrupt" }

local function Plain(v) return v ~= nil and not issecret(v) end

local function UnitRGB(unit)
    local isPlayer = UnitIsPlayer(unit)
    if Plain(isPlayer) and isPlayer then
        local _, class = UnitClass(unit)
        local c = Plain(class) and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    end
    local reaction = UnitReaction(unit, "player")
    if type(reaction) == "number" and Plain(reaction) then
        local c = _G.FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
        if c then return c.r, c.g, c.b end
    end
    return 0.8, 0.8, 0.8
end

local function Who(unit)
    if unit == "player" then return "You", UnitRGB("player") end
    local name = UnitName(unit)
    if name == nil then return "?", 0.8, 0.8, 0.8 end
    return name, UnitRGB(unit)                       -- may be hidden: the text shows it
end

---------------------------------------------------------------------------
-- UNIT_COMBAT
---------------------------------------------------------------------------
local WATCH = { player = "in", target = "out", pet = "pet" }

local function OnUnitCombat(unit, action, flag, amount, school)
    local dir = WATCH[unit]
    if not dir or not Plain(action) then return end
    if unit ~= "player" then                        -- the same unit seen twice: keep one line
        local same = UnitIsUnit(unit, "player")
        if Plain(same) and same then return end
    end
    if unit == "target" then
        local same = UnitIsUnit("target", "pet")
        if Plain(same) and same then return end
    end
    local who, r, g, b = Who(unit)
    local line = { dir = dir, who = who, r = r, g = g, b = b, school = school }
    local parts = {}
    if action == "WOUND" then
        line.amount = amount
        local s = SchoolName(school)
        if s then parts[#parts + 1] = s end
        if Plain(flag) and FLAG_WORDS[flag] then parts[#parts + 1] = FLAG_WORDS[flag] end
        line.kind = "hit"
    elseif action == "HEAL" then
        line.amount, line.dir, line.kind = amount, "heal", "heal"
        parts[#parts + 1] = "healed"
        if Plain(flag) and flag == "CRITICAL" then parts[#parts + 1] = "crit" end
    elseif action == "ENERGIZE" then
        line.amount, line.kind = amount, "energize"
        parts[#parts + 1] = "power"
        line.dir = "info"
    elseif AVOID[action] then
        line.kind = "avoid"
        parts[#parts + 1] = AVOID[action]
        if action == "BLOCK" or action == "RESIST" or action == "ABSORB" then line.amount = amount end
    else
        line.kind = "other"
        parts[#parts + 1] = string.lower(action)
    end
    line.what = table.concat(parts, " ")
    Add(line)
end

---------------------------------------------------------------------------
-- Casts
---------------------------------------------------------------------------
local function OnCast(unit, spellID)
    if unit ~= "player" and unit ~= "pet" then return end
    local line = { dir = (unit == "player") and "out" or "pet", kind = "cast" }
    if Plain(spellID) and type(spellID) == "number" then
        local name = _G.C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        if not Plain(name) then return end               -- nothing readable to say
        line.who = name
        line.icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        line.spellID = spellID
    else
        return                                            -- a hidden spell: no line rather than "?"
    end
    line.r, line.g, line.b = 1, 1, 1
    line.what = (unit == "player") and "cast" or "pet cast"
    Add(line)
end

---------------------------------------------------------------------------
-- Deaths
---------------------------------------------------------------------------
local targetDead = false

local function CheckTarget(fresh)
    if not UnitExists("target") then targetDead = false; return end
    local dead = UnitIsDead("target")
    if not Plain(dead) then return end
    if fresh then targetDead = dead and true or false; return end
    if dead and not targetDead then
        local who, r, g, b = Who("target")
        Add({ dir = "out", kind = "death", who = who, r = r, g = g, b = b, what = "dies" })
    end
    targetDead = dead and true or false
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local registered = {}
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_COMBAT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_HEALTH", "PLAYER_TARGET_CHANGED", "PLAYER_DEAD" }) do
    local ok, res = pcall(ev.RegisterEvent, ev, e)
    registered[e] = ok and res ~= false
end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
    if not ns.KLCollecting() then return end
    if event == "UNIT_COMBAT" then
        OnUnitCombat(a1, a2, a3, a4, a5)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnCast(a1, a3)
    elseif event == "UNIT_HEALTH" then
        if a1 == "target" then CheckTarget(false) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        CheckTarget(true)
    elseif event == "PLAYER_DEAD" then
        local _, r, g, b = Who("player")
        Add({ dir = "in", kind = "death", who = "You", r = r, g = g, b = b, what = "die" })
    end
end)
local function Handler(event, ...)                     -- (for the offline tests)
    local f = ev:GetScript("OnEvent")
    if f then f(ev, event, ...) end
end
ns.KLHandle = Handler

-- only collect while KutzUI's log is the one shown (no cost otherwise)
function ns.KLCollecting()
    return ns.CLView and ns.CLView() == "kutz"
end

ns.RegisterDebug(function()
    local parts = {}
    for e, ok in pairs(registered) do parts[#parts + 1] = e .. "=" .. tostring(ok) end
    table.sort(parts)
    ns.Print("kutz log feed: " .. ns.KLCount() .. " lines | listening: " .. table.concat(parts, " "))
end)

end)
