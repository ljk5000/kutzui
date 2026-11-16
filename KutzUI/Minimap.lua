---------------------------------------------------------------------------
-- KutzUI / Minimap        (module "minimap")
--
-- Tidies the minimap: every button around it can be shown or hidden on its own, and the
-- clock can sit in the top-right corner of the screen. The map itself, its frame
-- border and the zone name bar are kept.
--
-- Nothing of Blizzard's is hooked or replaced:
--   * hiding a button = alpha 0 + mouse off (its own code keeps running, so e.g. the
--     mail icon still "works", you just don't see it); showing it again puts back
--     exactly what Blizzard had;
--   * a slow poller (every 0.5 s) re-applies this, because Blizzard shows, hides and
--     re-anchors some of these now and then, and some only exist after another
--     Blizzard addon or one of yours has loaded;
--   * the only thing MOVED is the clock (an unprotected button).
--
-- Buttons other addons add to the minimap (the round LibDBIcon ones, named
-- LibDBIcon10_<addon>) are found by name and can be switched one by one too.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("minimap", function()

-- each entry: key, label, tip, default (is it SHOWN by default), frames() -> list of frames (nil entries skipped)
-- "alert" ones tell you something (new mail, a queue popped, which difficulty you're in) so they stay visible by default
local function Cluster() return _G.MinimapCluster end
local function Mini() return _G.Minimap or (Cluster() and Cluster().MinimapContainer and Cluster().MinimapContainer.Minimap) end

ns.MM_BUTTONS = {
    { key = "zone",       label = "Zone name bar",              default = true,
      tip = "The bar with the zone name at the top of the minimap.",
      frames = function() return { Cluster() and Cluster().ZoneTextButton } end },
    { key = "calendar",   label = "Calendar",                   default = false,
      tip = "The calendar button.",
      frames = function() return { _G.GameTimeFrame } end },
    { key = "tracking",   label = "Tracking (magnifying glass)", default = false,
      tip = "The button that picks what the minimap tracks (herbs, ore, ...).",
      frames = function() return { Cluster() and Cluster().Tracking } end },
    { key = "mail",       label = "New mail",                   default = true, alert = true,
      tip = "The envelope that shows when you have mail. Kept visible by default so you don't miss mail.",
      frames = function() local c = Cluster(); return { c and c.IndicatorFrame and c.IndicatorFrame.MailFrame } end },
    { key = "crafting",   label = "Crafting orders",            default = true, alert = true,
      tip = "The icon that shows when you have crafting orders waiting.",
      frames = function() local c = Cluster(); return { c and c.IndicatorFrame and c.IndicatorFrame.CraftingOrderFrame } end },
    { key = "queue",      label = "Group finder eye",           default = true, alert = true,
      tip = "The eye that shows while you are queued for a dungeon or group. Kept visible by default.",
      frames = function() return { _G.QueueStatusButton } end },
    { key = "difficulty", label = "Instance difficulty",        default = true, alert = true,
      tip = "The little icon showing the difficulty of the dungeon or raid you are in.",
      frames = function() return { Cluster() and Cluster().InstanceDifficulty } end },
    { key = "zoom",       label = "Zoom + / - buttons",         default = false,
      tip = "The plus and minus buttons that appear when you hover the map. The mouse wheel still zooms.",
      frames = function() local m = Mini(); return { m and m.ZoomIn, m and m.ZoomOut } end },
    { key = "landing",    label = "Expansion / landing page",   default = false,
      tip = "The button that opens the expansion landing page (missions, renown, ...).",
      frames = function() return { _G.ExpansionLandingPageMinimapButton } end },
    { key = "compartment", label = "Addon list button",         default = false,
      tip = "Blizzard's button that opens a list of addon buttons.",
      frames = function() return { _G.AddonCompartmentFrame } end },
    { key = "coords",     label = "Coordinates under the map",  default = false,
      tip = "Your map coordinates below the minimap.",
      frames = function() local c = Cluster(); return { c and c.MinimapContainer and c.MinimapContainer.PlayerCoords } end },
}

local BY_KEY = {}
for _, b in ipairs(ns.MM_BUTTONS) do BY_KEY[b.key] = b end

function ns.MMShown(key)
    local db = KutzUIDB
    local v = db and db.mmShow and db.mmShow[key]
    if v == nil then return BY_KEY[key] and BY_KEY[key].default end
    return v
end

local dirty = true

function ns.SetMMShown(key, show)
    if not KutzUIDB then return end
    KutzUIDB.mmShow = KutzUIDB.mmShow or {}
    KutzUIDB.mmShow[key] = show and true or false
    dirty = true
end

-- the buttons other addons put on the minimap, found by name; { {name=, frame=}, ... }
function ns.MMAddonButtons()
    local list = {}
    local m = Mini()
    if not (m and m.GetChildren) then return list end
    for _, child in ipairs({ m:GetChildren() }) do
        local name = child.GetName and child:GetName()
        local addon = name and name:match("^LibDBIcon10_(.+)$")
        if addon then list[#list + 1] = { name = addon, frame = child } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function ns.MMAddonShown(name)
    local db = KutzUIDB
    return (db and db.mmAddon and db.mmAddon[name]) == true       -- hidden unless you switch it on
end

function ns.SetMMAddonShown(name, show)
    if not KutzUIDB then return end
    KutzUIDB.mmAddon = KutzUIDB.mmAddon or {}
    KutzUIDB.mmAddon[name] = show and true or false
    dirty = true
end

function ns.SetAllMMAddonShown(show)
    for _, b in ipairs(ns.MMAddonButtons()) do ns.SetMMAddonShown(b.name, show) end
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------
ns.MM_CLOCK_MODES = {
    { key = "corner",  name = "Top-right corner of the screen" },
    { key = "bar",     name = "Right end of the zone name bar" },
    { key = "default", name = "Where Blizzard puts it" },
    { key = "hidden",  name = "Hidden" },
}

function ns.MMClockMode()
    return (KutzUIDB and KutzUIDB.mmClock) or "corner"
end

function ns.SetMMClockMode(key)
    if KutzUIDB then KutzUIDB.mmClock = key end
    dirty = true
end

---------------------------------------------------------------------------
-- Applying it
---------------------------------------------------------------------------
local function Apply(frame, show) ns.SetFrameHidden(frame, not show) end

local clockHome                                       -- where Blizzard had the clock

local function PlaceClock(mode)
    local clock = _G.TimeManagerClockButton
    if not clock then return end
    Apply(clock, mode ~= "hidden")
    if mode == "hidden" then return end

    local point, rel, relPoint, x, y = clock:GetPoint(1)
    if not clockHome and point then clockHome = { point, rel, relPoint, x, y, clock:GetNumPoints() } end

    local wantPoint, wantRel, wantRelPoint, wx, wy
    if mode == "corner" then
        wantPoint, wantRel, wantRelPoint, wx, wy = "TOPRIGHT", UIParent, "TOPRIGHT", -2, -2
    elseif mode == "bar" then
        local zone = Cluster() and Cluster().ZoneTextButton
        if not zone then return end
        wantPoint, wantRel, wantRelPoint, wx, wy = "TOPRIGHT", zone, "TOPRIGHT", 0, 0
    else                                                -- "default": put it back
        if not clockHome then return end
        wantPoint, wantRel, wantRelPoint, wx, wy = clockHome[1], clockHome[2], clockHome[3], clockHome[4], clockHome[5]
    end
    if clock:GetNumPoints() == 1 and point == wantPoint and rel == wantRel and relPoint == wantRelPoint
        and x and y and math.abs(x - wx) < 0.5 and math.abs(y - wy) < 0.5 then return end
    clock:ClearAllPoints()
    clock:SetPoint(wantPoint, wantRel, wantRelPoint, wx, wy)
end

local function Tick()
    for _, b in ipairs(ns.MM_BUTTONS) do
        local show = ns.MMShown(b.key)
        local list = b.frames()
        for i = 1, 2 do                                 -- at most two frames per entry (zoom + / -)
            if list[i] then Apply(list[i], show) end
        end
    end
    for _, b in ipairs(ns.MMAddonButtons()) do Apply(b.frame, ns.MMAddonShown(b.name)) end
    PlaceClock(ns.MMClockMode())
    -- the coordinates under the map are Blizzard's own text; it only fills them in while this game setting is on
    if ns.MMShown("coords") and GetCVar("minimapShowPlayerCoords") ~= "1" then pcall(SetCVar, "minimapShowPlayerCoords", "1") end
end

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function() dirty = true end)
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 and not dirty then return end
    acc = 0
    dirty = false
    local ok, err = pcall(Tick)
    if not ok and not ns.minimapErrored then
        ns.minimapErrored = true
        ns.Print("minimap error (please report): " .. tostring(err))
    end
end)

function ns.ResetMinimap()
    if not KutzUIDB then return end
    KutzUIDB.mmShow, KutzUIDB.mmAddon, KutzUIDB.mmClock, KutzUIDB.mmMapCoords = nil, nil, nil, nil
    dirty = true
end

-- everything back the way Blizzard has it
function ns.ShowEverythingOnMinimap()
    if not KutzUIDB then return end
    KutzUIDB.mmShow = {}
    for _, b in ipairs(ns.MM_BUTTONS) do KutzUIDB.mmShow[b.key] = true end
    ns.SetAllMMAddonShown(true)
    KutzUIDB.mmClock = "default"
    dirty = true
end

ns.RegisterDebug(function()
    local parts = {}
    for _, b in ipairs(ns.MM_BUTTONS) do
        local found = 0
        for _, f in ipairs(b.frames()) do if f then found = found + 1 end end
        parts[#parts + 1] = string.format("%s=%s%s", b.key, ns.MMShown(b.key) and "shown" or "hidden", found == 0 and "(not found)" or "")
    end
    ns.Print("minimap: " .. table.concat(parts, " ") .. " | clock=" .. ns.MMClockMode()
        .. " (button " .. tostring(_G.TimeManagerClockButton ~= nil) .. ") | addon buttons found: " .. #ns.MMAddonButtons())
end)

end)
