---------------------------------------------------------------------------
-- KutzUI / UIFont
--
-- Puts your chosen font on the WHOLE game UI: the character sheet, spellbook,
-- professions, quest tracker and quest log, tooltips, menus, nameplates ...
--
-- HOW: every piece of Blizzard text takes its font from one of ~450 named font
-- objects (GameFontNormal, QuestFont, ObjectiveFont ...); I checked Blizzard's own
-- UI source for this client (build 1.60.1.70790): of the ~4,000 text elements in
-- it, none names a font file directly. Changing the named font objects therefore
-- restyles everything that uses them, immediately, including windows that open
-- later. The list is in UIFontList.lua (generated from that source).
--
-- Each font object's ORIGINAL file/size/flags is remembered, so choosing
-- "Default (Blizzard)" puts everything back, and a size adjustment is always
-- measured from Blizzard's own size (not stacked on top of itself).
--
-- Nothing is hooked; font objects are plain data on the C side, and this changes
-- no Lua table that Blizzard's code reads, so it can't taint anything.
--
-- Your font files only contain Latin letters, so on Korean / Chinese / Russian
-- game clients this module does nothing.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("fonts", function()

local LATIN = {
    enUS = true, enGB = true, deDE = true, frFR = true,
    esES = true, esMX = true, itIT = true, ptBR = true,
}

local originals = {}                 -- name -> { obj, path, size, flags, sig }
local byObject = setmetatable({}, { __mode = "k" })   -- fontObject -> originals entry
local missing = {}                   -- name -> true: not defined (yet) in this client
local dirty = true
local scans = 0

-- the font file to apply, or nil to leave / restore Blizzard's own
local function WantedPath()
    if not LATIN[GetLocale()] then return nil end
    local db = KutzUIDB
    if db and db.fontEverywhere == false then return nil end
    return ns.FontPathFor(ns.CurrentFontKey())
end

-- The numbers that float up from enemies / you (damage, healing) are drawn by the game itself with the
-- font named by the global DAMAGE_TEXT_FONT, read when the game starts. So it is set here, while this
-- module starts (before the world loads); a change on the menu needs a full restart to be seen.
local originalDamageFont = _G.DAMAGE_TEXT_FONT
local function ApplyCombatNumbersFont()
    local db = KutzUIDB
    local path
    if LATIN[GetLocale()] and not (db and db.fontCombatNumbers == false) then path = ns.FontPathFor(ns.CurrentFontKey()) end
    if path then
        _G.DAMAGE_TEXT_FONT = path
    elseif originalDamageFont then
        _G.DAMAGE_TEXT_FONT = originalDamageFont
    end
end
ApplyCombatNumbersFont()

local function SizeOffset()
    local db = KutzUIDB
    if db and db.fontEverywhere == false then return 0 end
    return (db and db.uiFontOffset) or 0
end

-- used by ns.ForceFont so "Default" can restore labels Blizzard owns
function ns.UIFontOriginal(fontObject)
    return byObject[fontObject]
end

local function Norm(p) return (tostring(p):gsub("/", "\\"):lower()) end

local function Remember(name)
    local obj = _G[name]
    if type(obj) ~= "table" or type(obj.GetFont) ~= "function" then return nil end
    local ok, path, size, flags = pcall(obj.GetFont, obj)
    if not ok or not path then return nil end
    local rec = { obj = obj, path = path, size = size or 12, flags = flags or "" }
    originals[name] = rec
    byObject[obj] = rec
    return rec
end

local function Apply()
    dirty = false
    local path = WantedPath()
    local offset = SizeOffset()
    local signature = (path or "-") .. "|" .. offset

    for _, name in ipairs(ns.UI_FONT_NAMES) do
        local rec = originals[name]
        if not rec and not missing[name] then
            rec = Remember(name)
            if not rec then missing[name] = true end      -- may appear later (load-on-demand windows)
        end
        if rec and rec.sig ~= signature then
            -- never touch a font we haven't been asked to change (keeps Blizzard's own
            -- objects completely untouched until you pick a font or a size)
            if rec.touched or path or offset ~= 0 then
                local size = math.max(6, rec.size + offset)
                local use = path or rec.path
                -- SetFont's return value is not reliable on this client (it can be nil even when
                -- it worked), so ask the object what font it ended up with.
                rec.failed = nil
                pcall(rec.obj.SetFont, rec.obj, use, size, rec.flags)
                local now = rec.obj:GetFont()
                if now and use and Norm(now) ~= Norm(use) then
                    pcall(rec.obj.SetFont, rec.obj, rec.path, size, rec.flags)   -- file not visible to the game yet: stay readable
                    if path then rec.failed = true end
                end
                rec.touched = true
            end
            rec.sig = signature
        end
    end

    -- The red messages at the top of the screen ("There is nothing to attack") live in
    -- UIErrorsFrame, which copied its font when it was created; hand it the new one directly.
    local ef, er = _G.UIErrorsFrame, originals.ErrorFont
    if ef and ef.SetFont and er and er.touched and er.obj.GetFont and ef.kutzFontSig ~= signature then
        local p, s, f = er.obj:GetFont()
        if p and pcall(ef.SetFont, ef, p, s or 16, f or "") then ef.kutzFontSig = signature end
    end
end

-- called by the menu / the font picker whenever a setting changes
function ns.RefreshUIFont()
    dirty = true
    scans = 0                    -- also look again for late-loading windows' fonts
    for name in pairs(missing) do missing[name] = nil end
end

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        dirty = true
        self:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc < 0.5 then return end
            acc = 0
            -- Load-on-demand Blizzard windows (professions, talents ...) can define fonts
            -- when they load; look for those for a while after login / after each change.
            if dirty or scans < 20 then
                scans = scans + 1
                local ok, err = pcall(Apply)
                if not ok and not ns.uiFontErrored then
                    ns.uiFontErrored = true
                    ns.Print("game font error (please report): " .. tostring(err))
                end
            end
        end)
    elseif event == "ADDON_LOADED" and type(arg1) == "string" and arg1:find("^Blizzard_") then
        scans = math.min(scans, 15)      -- a Blizzard window just loaded: check its fonts soon
        for name in pairs(missing) do missing[name] = nil end
        dirty = true
    end
end)

function ns.DebugUIFont()
    local total, changed, missingCount, failed = 0, 0, 0, 0
    for _, name in ipairs(ns.UI_FONT_NAMES) do
        total = total + 1
        local rec = originals[name]
        if rec then
            if rec.touched then changed = changed + 1 end
            if rec.failed then failed = failed + 1 end
        else
            missingCount = missingCount + 1
        end
    end
    if failed > 0 then ns.Print("game font: " .. failed .. " font objects refused the font file (it is not visible to the game yet - fully restart WoW once)") end
    local sample = _G.GameFontNormal and { _G.GameFontNormal:GetFont() } or {}
    local objective = _G.ObjectiveFont and { _G.ObjectiveFont:GetFont() } or {}
    ns.Print(string.format("game font: %d known font objects, %d restyled, %d not present in this client | everywhere=%s offset=%s locale=%s (latin=%s)",
        total, changed, missingCount, tostring(not (KutzUIDB and KutzUIDB.fontEverywhere == false)),
        tostring(SizeOffset()), GetLocale(), tostring(LATIN[GetLocale()] == true)))
    ns.Print("game font: GameFontNormal = " .. tostring(sample[1]) .. " @" .. tostring(sample[2])
        .. "   ObjectiveFont (quest tracker) = " .. tostring(objective[1]) .. " @" .. tostring(objective[2]))
end

ns.RegisterDebug(ns.DebugUIFont)

end)
