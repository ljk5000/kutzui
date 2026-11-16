---------------------------------------------------------------------------
-- KutzUI / Common
--
-- Helpers every part of the addon can rely on, whatever modules are switched on:
-- the chosen font (and how text we create / Blizzard's labels get it), the cast bar
-- texture list, and `Present`. Nothing here touches Blizzard's UI by itself.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local issecret = issecretvalue or function() return false end

---------------------------------------------------------------------------
-- Fonts. All monospace with a slashed zero. The files live in
-- Media\Fonts and are bundled under the SIL Open Font License (see the
-- *-OFL.txt files next to them). The choice is KutzUIDB.font; "default" keeps
-- Blizzard's own font. Pick one in the /kutz menu.
---------------------------------------------------------------------------
local FONT_DIR = "Interface\\AddOns\\KutzUI\\Media\\Fonts\\"
ns.FONTS = {
    { key = "inconsolata",  name = "Inconsolata",        path = FONT_DIR .. "Inconsolata-Regular.ttf" },
    { key = "robotomono",   name = "Roboto Mono",        path = FONT_DIR .. "RobotoMono-Regular.ttf" },
    { key = "anonymouspro", name = "Anonymous Pro",      path = FONT_DIR .. "AnonymousPro-Regular.ttf" },
    { key = "default",      name = "Default (Blizzard)", path = nil },
}
ns.DEFAULT_FONT_KEY = "inconsolata"

function ns.CurrentFontKey()
    return (KutzUIDB and KutzUIDB.font) or ns.DEFAULT_FONT_KEY
end

-- path for the chosen font, or nil for "default"
function ns.FontPathFor(key)
    for _, f in ipairs(ns.FONTS) do
        if f.key == key then return f.path end
    end
    return ns.FONTS[1].path
end

-- A font file the game can't see (e.g. added since the game started, before a
-- full restart) makes SetFont return false, which would leave the text
-- blank - so always fall back to Blizzard's font.
local function SafeSetFont(fs, path, size, flags)
    if path and fs:SetFont(path, size, flags) then return true end
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
    return false
end

-- Text we create: remember size/flags so a font change can restyle it.
local styled = setmetatable({}, { __mode = "k" })   -- fontstring -> { size, flags }

function ns.StyleText(fs, size, flags)
    flags = flags or "OUTLINE"
    styled[fs] = { size, flags }
    SafeSetFont(fs, ns.FontPathFor(ns.CurrentFontKey()), size, flags)
end

function ns.ApplyFont()
    local path = ns.FontPathFor(ns.CurrentFontKey())
    for fs, s in pairs(styled) do SafeSetFont(fs, path, s[1], s[2]) end
    -- Blizzard's own labels we restyle (names, keybinds) pick the change up
    -- themselves: their pollers call ns.ForceFont every tick. The game-wide font
    -- (UIFont.lua) is told to redo its pass too.
    if ns.RefreshUIFont then ns.RefreshUIFont() end
end

-- Text Blizzard owns (name labels, keybinds): keep our chosen font on it.
-- `rec` is a table the caller keeps per FontString; it remembers Blizzard's
-- original font so "Default" can put it back.
local function Norm(p) return p and (p:lower():gsub("/", "\\")) or nil end

-- How much bigger than Blizzard's own size the Player/Target name labels are.
-- Default +2 ("slightly bigger"); the menu slider sets KutzUIDB.nameBonus.
function ns.NameBonus()
    local b = KutzUIDB and KutzUIDB.nameBonus
    if b == nil then return 2 end
    return b
end

-- sizeBonus (optional): points added to Blizzard's original size for this label.
-- followSize (optional): only swap the font FILE and leave whatever size Blizzard
-- currently uses alone (chat windows: you change their size in Blizzard's own menu).
-- forceSize (optional): use exactly this size (the combat log's font size setting).
function ns.ForceFont(fs, rec, sizeBonus, followSize, forceSize)
    local path, size, flags = fs:GetFont()
    if not path then return end
    if not rec.origPath then
        -- Blizzard's ORIGINAL font for this label. If the game-wide font module has
        -- already restyled the font object the label uses, ask it for the original.
        local fontObject = fs.GetFontObject and fs:GetFontObject()
        local o = fontObject and ns.UIFontOriginal and ns.UIFontOriginal(fontObject)
        if o then
            rec.origPath, rec.origSize, rec.origFlags = o.path, o.size, o.flags
        else
            rec.origPath, rec.origSize, rec.origFlags = path, size, flags
        end
    end

    local wantPath = ns.FontPathFor(ns.CurrentFontKey()) or rec.origPath

    if forceSize then
        if Norm(path) ~= Norm(wantPath) or math.abs((size or 0) - forceSize) > 0.01 then
            fs:SetFont(wantPath, forceSize, rec.origFlags or flags)
        end
        return
    end

    if followSize then
        if Norm(path) ~= Norm(wantPath) then fs:SetFont(wantPath, size, flags) end
        return
    end

    local wantSize = (rec.origSize or size) + (sizeBonus or 0)
    local wantFlags = rec.origFlags or flags

    if Norm(path) ~= Norm(wantPath) or math.abs((size or 0) - wantSize) > 0.01 then
        fs:SetFont(wantPath, wantSize, wantFlags)
    end
end

---------------------------------------------------------------------------
-- Cast bar textures. "Kutz ..." ones are my own grayscale .tga files (the bar
-- color tints them); "Blizzard ..." ones ship with the game.
-- New files need a full game restart before the game can see them.
---------------------------------------------------------------------------
local TEX_DIR = "Interface\\AddOns\\KutzUI\\Media\\Textures\\"
ns.TEXTURES = {
    { key = "kutz_gradient", name = "Kutz Gradient",     path = TEX_DIR .. "kutz_gradient.tga" },
    { key = "kutz_glass",    name = "Kutz Glass",        path = TEX_DIR .. "kutz_glass.tga" },
    { key = "kutz_stripes",  name = "Kutz Stripes",      path = TEX_DIR .. "kutz_stripes.tga" },
    { key = "kutz_soft",     name = "Kutz Soft",         path = TEX_DIR .. "kutz_soft.tga" },
    { key = "kutz_edged",    name = "Kutz Flat, edged",  path = TEX_DIR .. "kutz_edged.tga" },
    { key = "kutz_glaze", name = "Kutz Glaze", path = TEX_DIR .. "kutz_glaze.tga" },
    { key = "kutz_chrome", name = "Kutz Chrome", path = TEX_DIR .. "kutz_chrome.tga" },
    { key = "kutz_brushed", name = "Kutz Brushed metal", path = TEX_DIR .. "kutz_brushed.tga" },
    { key = "kutz_carbon", name = "Kutz Carbon", path = TEX_DIR .. "kutz_carbon.tga" },
    { key = "kutz_segments", name = "Kutz Segments", path = TEX_DIR .. "kutz_segments.tga" },
    { key = "kutz_dots", name = "Kutz Dots", path = TEX_DIR .. "kutz_dots.tga" },
    { key = "kutz_grain", name = "Kutz Grain", path = TEX_DIR .. "kutz_grain.tga" },
    { key = "kutz_wave", name = "Kutz Wave", path = TEX_DIR .. "kutz_wave.tga" },
    { key = "blizz_smooth",  name = "Blizzard Smooth",   path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "blizz_skills",  name = "Blizzard Glossy",   path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { key = "blizz_raid",    name = "Blizzard Raid",     path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "blizz_target",  name = "Blizzard Target frame", path = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill" },
    { key = "blizz_profession", name = "Blizzard Profession", path = "Interface\\Spellbook\\Professions-Progress-Fill" },
    { key = "blizz_archaeology", name = "Blizzard Archaeology", path = "Interface\\Archeology\\Arch-Progress-Fill" },
    { key = "flat",          name = "Flat",              path = "Interface\\Buttons\\WHITE8X8" },
}
ns.DEFAULT_CAST_TEXTURE = { player = "blizz_skills", target = "blizz_smooth" }   -- what they were before you could choose

function ns.CastTextureKey(unit)
    local db = KutzUIDB
    local k = db and db[unit == "player" and "castTexPlayer" or "castTexTarget"]
    return k or ns.DEFAULT_CAST_TEXTURE[unit]
end

-- Our list, plus the bar textures of any other addon that registers them with LibSharedMedia
-- (if you have such an addon; nothing is required or bundled).
function ns.TextureList()
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if not LSM then return ns.TEXTURES end
    local list = {}
    for _, t in ipairs(ns.TEXTURES) do list[#list + 1] = t end
    local ok, names = pcall(LSM.List, LSM, "statusbar")
    if ok and type(names) == "table" then
        for _, name in ipairs(names) do
            local path = LSM:Fetch("statusbar", name, true)
            if path then list[#list + 1] = { key = "lsm:" .. name, name = name .. "  (SharedMedia)", path = path } end
        end
    end
    return list
end

function ns.CastTexturePath(unit)
    local key = ns.CastTextureKey(unit)
    for _, t in ipairs(ns.TextureList()) do
        if t.key == key then return t.path end
    end
    return ns.TEXTURES[#ns.TEXTURES].path
end

---------------------------------------------------------------------------
-- Is a value there at all? (true for a secret value too - it can be shown, not read)
---------------------------------------------------------------------------
local function Present(v) return issecret(v) or v ~= nil end
ns.Present = Present

---------------------------------------------------------------------------
-- Hiding a Blizzard frame without touching its code: alpha 0 + mouse off, and when it is shown
-- again, exactly what Blizzard had (or restoreAlpha). Blizzard keeps Show()ing / Hide()ing it
-- as it likes; only the look and clicks are ours. Re-call it from a poller to keep it applied.
---------------------------------------------------------------------------
local hiddenRecs = setmetatable({}, { __mode = "k" })     -- frame -> { alpha, mouse } as Blizzard had it

function ns.SetFrameHidden(frame, hide, restoreAlpha)
    if type(frame) ~= "table" or not frame.SetAlpha then return end
    local rec = hiddenRecs[frame]
    if hide then
        if not rec then
            rec = { alpha = frame:GetAlpha(), mouse = frame.IsMouseEnabled and frame:IsMouseEnabled() }
            hiddenRecs[frame] = rec
        end
        if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
        if frame.IsMouseEnabled and frame:IsMouseEnabled() then frame:EnableMouse(false) end
    elseif rec then
        frame:SetAlpha(restoreAlpha or ((rec.alpha and rec.alpha > 0) and rec.alpha or 1))
        if rec.mouse and frame.EnableMouse then frame:EnableMouse(true) end
        hiddenRecs[frame] = nil
    end
end
