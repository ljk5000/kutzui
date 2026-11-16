---------------------------------------------------------------------------
-- KutzUI / Nameplates        (module "nameplates")
--
-- Blizzard's own nameplates, kept as they are, with two small additions of our own (each with its
-- own switch, menu: Nameplates page):
--
--   * the health PERCENT written in the middle of every plate's health bar
--   * a gold outline around the plate of your TARGET, so you can find it in a crowd
--   * the unit's WHOLE name: Blizzard squeezes the name into the width of the health bar and ends it in
--     "..." when it doesn't fit, so we hide that (alpha 0; never hooked or moved) and write the same
--     name in the same place with no width limit
--
-- Everything else on that page (class colours on player plates, how much bigger the selected plate
-- is, how small / faint far-away plates get) is the game's OWN nameplate settings, which the page
-- just reads and writes, so the game's options window always agrees with it. The plate font is
-- already covered by the game-wide font module.
--
-- Blizzard's plates are never hooked or edited: our text and outline are small frames of our own
-- placed on top of each plate's health bar, refreshed a few times a second and the moment a plate
-- appears. The game hides health, and whether a plate is your target, from addon code in some places
-- (dungeons, raids); those values are only ever handed straight to the game's own widget calls
-- (SetFormattedText, SetAlphaFromBoolean) and never looked at, so a hidden value just works.
-- Plates the game marks as off-limits to addons (forbidden) are skipped.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("nameplates", function()

local DEFAULTS = {
    npHealthText = true,      -- the percent in the bar
    npTextSize   = 10,
    npTargetGlow = true,      -- the gold outline on your target's plate
    npFullName   = true,      -- the whole name, not cut short with "..."
}

function ns.NPOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

function ns.SetNPOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
end

function ns.ResetNPSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
end

local Present = ns.Present
local issecret = issecretvalue or function() return false end
local SCALE100 = CurveConstants and CurveConstants.ScaleTo100
local GLOW = { 1.00, 0.82, 0.00, 0.95 }

local extras = setmetatable({}, { __mode = "k" })       -- a plate's health bar -> our text and outline for it
ns.NPExtras = extras

local function Build(bar)
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar)
    holder:SetFrameLevel(bar:GetFrameLevel() + 10)
    holder:EnableMouse(false)
    local text = holder:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", holder, "CENTER", 0, 0)
    ns.StyleText(text, ns.NPOption("npTextSize"))

    local glow = CreateFrame("Frame", nil, bar)
    glow:SetAllPoints(bar)
    glow:SetFrameLevel(bar:GetFrameLevel() + 9)
    glow:EnableMouse(false)
    local function Edge(p1, r1, x1, y1, p2, r2, x2, y2, w, h)
        local t = glow:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(GLOW[1], GLOW[2], GLOW[3], GLOW[4])
        t:SetPoint(p1, glow, r1, x1, y1)
        t:SetPoint(p2, glow, r2, x2, y2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
    end
    Edge("BOTTOMLEFT", "TOPLEFT", -2, 0,  "BOTTOMRIGHT", "TOPRIGHT", 2, 0,  nil, 2)      -- top
    Edge("TOPLEFT", "BOTTOMLEFT", -2, 0,  "TOPRIGHT", "BOTTOMRIGHT", 2, 0,  nil, 2)      -- bottom
    Edge("TOPRIGHT", "TOPLEFT", 0, 2,  "BOTTOMRIGHT", "BOTTOMLEFT", 0, -2,  2, nil)      -- left
    Edge("TOPLEFT", "TOPRIGHT", 0, 2,  "BOTTOMLEFT", "BOTTOMRIGHT", 0, -2,  2, nil)      -- right

    -- the whole-name text lives in a frame of its own so it doesn't vanish with the percent text
    local nameHolder = CreateFrame("Frame", nil, bar)
    nameHolder:SetAllPoints(bar)
    nameHolder:SetFrameLevel(bar:GetFrameLevel() + 11)
    nameHolder:EnableMouse(false)
    local name = nameHolder:CreateFontString(nil, "OVERLAY")
    name:SetWordWrap(false)
    name:SetFontObject("GameFontNormal")      -- until we copy the plate's own font on the first update

    local entry = { holder = holder, text = text, glow = glow, size = ns.NPOption("npTextSize"),
                    nameHolder = nameHolder, name = name }
    extras[bar] = entry
    return entry
end

local function FmtPct(fs, pct) fs:SetFormattedText("%.0f%%", pct) end

-- Write the unit's name over Blizzard's (hidden) one with no width limit, same place, font and colour.
local function ShowFullName(e, uf)
    local theirs = uf.name
    if type(theirs) ~= "table" then e.nameHolder:Hide(); return end
    if not theirs:IsShown() then              -- the game decided this plate shows no name
        e.nameHolder:Hide()
        return
    end
    local mine = e.name

    local ok, font, size, flags = pcall(theirs.GetFont, theirs)
    if ok and font and not issecret(font) and not issecret(size) and (e.font ~= font or e.fsize ~= size or e.fflags ~= flags) then
        pcall(mine.SetFont, mine, font, size, flags)       -- its return value isn't reliable on this client
        e.font, e.fsize, e.fflags = font, size, flags
    end

    local okJ, just = pcall(theirs.GetJustifyH, theirs)
    just = (okJ and (just == "RIGHT" or just == "CENTER")) and just or "LEFT"
    if e.just ~= just then                    -- grow outward from the same edge Blizzard's name is aligned to
        e.just = just
        mine:ClearAllPoints()
        mine:SetPoint(just, theirs, just, 0, 0)
        mine:SetJustifyH(just)
    end

    local okT, text = pcall(theirs.GetText, theirs)
    if okT and Present(text) then mine:SetText(text) end
    local okC, r, g, b = pcall(theirs.GetTextColor, theirs)
    if okC then pcall(mine.SetTextColor, mine, r, g, b) end

    theirs:SetAlpha(0)
    e.hidTheirs = true
    e.nameHolder:Show()
end

local function RestoreName(e, uf)
    e.nameHolder:Hide()
    if e.hidTheirs and type(uf.name) == "table" then uf.name:SetAlpha(1); e.hidTheirs = false end
end

local function UpdatePlate(plate)
    local uf = plate and plate.UnitFrame
    if not uf or (uf.IsForbidden and uf:IsForbidden()) then return end
    local container = uf.HealthBarsContainer
    local bar = container and container.healthBar
    if not bar then return end
    local unit = plate.namePlateUnitToken or uf.unit
    if type(unit) ~= "string" then return end

    local e = extras[bar] or Build(bar)

    if ns.NPOption("npHealthText") then
        local size = ns.NPOption("npTextSize")
        if e.size ~= size then e.size = size; ns.StyleText(e.text, size) end
        local ok, pct = pcall(UnitHealthPercent, unit, false, SCALE100)
        if ok and Present(pct) and pcall(FmtPct, e.text, pct) then
            e.holder:Show()
        else
            e.holder:Hide()
        end
    else
        e.holder:Hide()
    end

    if ns.NPOption("npFullName") then ShowFullName(e, uf) else RestoreName(e, uf) end

    if ns.NPOption("npTargetGlow") then
        e.glow:Show()
        if not pcall(function() e.glow:SetAlphaFromBoolean(UnitIsUnit(unit, "target"), 1, 0) end) then e.glow:SetAlpha(0) end
    else
        e.glow:Hide()
    end
end

local function Tick()
    if not (_G.C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        pcall(UpdatePlate, plate)
    end
end
ns.NPTick = Tick

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" and type(unit) == "string" and _G.C_NamePlate then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then pcall(UpdatePlate, plate) end
    else
        acc = 1                                             -- target changed: refresh on the next frame
    end
end)
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.15 then return end
    acc = 0
    local ok, err = pcall(Tick)
    if not ok and not ns.nameplatesErrored then
        ns.nameplatesErrored = true
        ns.Print("nameplates error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    local n = 0
    if _G.C_NamePlate and C_NamePlate.GetNamePlates then n = #(C_NamePlate.GetNamePlates() or {}) end
    ns.Print(string.format("nameplates: %d visible | healthText=%s targetGlow=%s fullName=%s size=%s",
        n, tostring(ns.NPOption("npHealthText")), tostring(ns.NPOption("npTargetGlow")), tostring(ns.NPOption("npFullName")), tostring(ns.NPOption("npTextSize"))))
end)

end)
