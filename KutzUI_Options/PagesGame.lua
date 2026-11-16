---------------------------------------------------------------------------
-- KutzUI / settings pages
-- Game settings and sound / advanced.
--
-- Part of KutzUI_Options. These files load only when you open /kutz, and only
-- after Menu.lua, which publishes the widget toolkit on KutzUI._opt.
-- Nothing in here runs until that window is opened.
---------------------------------------------------------------------------
local ns = _G.KutzUI
local M = ns._opt
if not M then error("KutzUI settings pages loaded before Menu.lua") end

---------------------------------------------------------------------------
-- Game settings: the game's own settings (CVars) that Blizzard hides, buries or never exposed.
-- Each row is read from and written to the game directly, so it always agrees with the game
-- (and with the game's own options window). A setting that this version of the game doesn't
-- have is simply left out. "Any game setting" at the end handles everything else.
---------------------------------------------------------------------------
local GS = {}

function GS.Exists(name)
    local ok, v = pcall(GetCVar, name)
    return ok and v ~= nil
end

function GS.Num(name)
    local ok, v = pcall(GetCVar, name)
    return ok and tonumber(v) or 0
end

function GS.Set(name, value)
    local ok = pcall(SetCVar, name, tostring(value))
    if not ok and ns.Print then ns.Print("the game would not change '" .. name .. "' right now (some settings are locked in combat).") end
end

-- adds one row, or counts it as missing
function GS.Bool(p, miss, label, cvar, tip)
    if not GS.Exists(cvar) then miss[1] = miss[1] + 1; return end
    p:Check(label, function() return GS.Num(cvar) ~= 0 end, function(v) GS.Set(cvar, v and 1 or 0) end,
        tip .. "  (game setting: " .. cvar .. ")")
end

-- a number setting shown as `scale` times the real value (rounded)
function GS.Slider(p, miss, label, cvar, lo, hi, scale, unit, tip, wheel)
    if not GS.Exists(cvar) then miss[1] = miss[1] + 1; return end
    p:Slider(label, lo, hi,
        function() return math.floor(GS.Num(cvar) * scale + 0.5) end,
        function(v) GS.Set(cvar, v / scale) end,
        { wheel = wheel or 5, fmt = function(v) return v .. unit end, tip = tip .. "  (game setting: " .. cvar .. ")" })
end

function GS.Choice(p, miss, label, cvar, items, tip)
    if not GS.Exists(cvar) then miss[1] = miss[1] + 1; return end
    p:Cycler(label, items,
        function() return tostring(math.floor(GS.Num(cvar))) end,
        function(k) GS.Set(cvar, k) end,
        { tip = tip .. "  (game setting: " .. cvar .. ")" })
end

function GS.MissingNote(p, miss)
    if miss[1] > 0 then
        p:Note(miss[1] .. " setting" .. (miss[1] == 1 and " isn't" or "s aren't") .. " in this version of the game, so " .. (miss[1] == 1 and "it is" or "they are") .. " left out.", 2)
    end
end

local function BuildGameSettingsPage()
    local p = M.NewPage("Game settings", "Settings the game hides or buries, in one place. They are the game's own settings, so the game's options window always agrees with what you see here.")
    M.pages.gamesettings = p
    local miss = { 0 }
    local B, S, C = GS.Bool, GS.Slider, GS.Choice

    p:Columns(2)
    p:Col(1)
    p:Section("Combat and casting")
    B(p, miss, "Cast on key press, not release", "ActionButtonUseKeyDown", "Spells and abilities fire the moment you press the key instead of when you let go. Feels noticeably quicker.")
    B(p, miss, "Auto self-cast", "autoSelfCast", "A helpful spell goes on you when you have no friendly target, instead of waiting for you to pick one.")
    S(p, miss, "Spell alert opacity", "spellActivationOverlayOpacity", 0, 100, 100, "%", "How strong the glowing spell alerts around your character are. 0 hides them.")
    B(p, miss, "Damage numbers on targets", "floatingCombatTextCombatDamage", "The floating numbers over a target when you hit it.")
    B(p, miss, "Floating numbers on yourself", "enableFloatingCombatText", "The floating numbers for damage and healing you take.")
    p:Section("Camera and mouse")
    S(p, miss, "Camera zoom distance", "cameraDistanceMaxZoomFactor", 100, 260, 100, "%", "How far you can zoom the camera out. 100% is the normal limit; 260% is the farthest the game allows.", 10)
    B(p, miss, "Reduce camera motion", "CameraReduceUnexpectedMovement", "Stops the camera from jumping around by itself, for example when you land or zone in.")
    B(p, miss, "Left-click to interact", "interactOnLeftClick", "A plain left click talks to people and opens things in the world.")
    B(p, miss, "Dismount when clicking in flight", "autoDismountFlying", "Lets the game dismount you when you use something that needs you on foot, even while flying.")
    p:Section("Looting")
    B(p, miss, "Auto-loot", "autoLootDefault", "Takes everything from a corpse or chest automatically. Hold Shift (Blizzard's auto-loot key) to open the loot window instead.")
    B(p, miss, "Open the loot window at the mouse", "lootUnderMouse", "The loot window appears under the cursor instead of in a fixed spot.")

    p:Col(2)
    p:Section("Interface")
    B(p, miss, "Show Lua errors", "scriptErrors", "Pops up a window when an addon has an error. Handy while you test, noisy otherwise.")
    B(p, miss, "Show tutorial pop-ups", "showTutorials", "The little tutorial and tip pop-ups.")
    B(p, miss, "Mouse wheel scrolls chat", "chatMouseScroll", "Scroll the chat window with the mouse wheel.")
    B(p, miss, "No delay when hovering chat", "removeChatDelay", "The chat tabs and buttons react at once instead of after a short wait.")
    B(p, miss, "Always compare item tooltips", "alwaysCompareItems", "Hovering an item always shows what you are wearing next to it, without holding Shift.")
    B(p, miss, "Show free slots on the backpack", "displayFreeBagSlots", "The number of empty bag slots on the backpack button.")
    B(p, miss, "Fade the world map when moving", "mapFade", "The world map turns see-through while you are walking.")
    p:Section("Nameplates (the game's own)")
    B(p, miss, "Show enemy nameplates", "nameplateShowEnemies", "Health bars over enemies' heads.")
    B(p, miss, "Show friendly nameplates", "nameplateShowFriends", "Health bars over friendly players and NPCs.")
    B(p, miss, "Always show nameplates", "nameplateShowAll", "Nameplates for everything in range, not only for enemies you are fighting.")
    S(p, miss, "Nameplate distance", "nameplateMaxDistance", 20, 100, 1, " yd", "How far away a nameplate is still drawn.", 5)
    C(p, miss, "When nameplates meet", "nameplateMotion", { { key = "0", name = "Overlap" }, { key = "1", name = "Stack apart" } },
        "Overlapping plates sit on top of each other; stacked plates are pushed apart so you can read them all.")
    GS.MissingNote(p, miss)
end

local function BuildSoundAdvancedPage()
    local p = M.NewPage("Sound and advanced", "Sound switches, the frame rate cap, the screen's UI scale, and a box to read or change any other game setting by name.")
    M.pages.gamesettings2 = p
    local miss = { 0 }
    local B, S = GS.Bool, GS.Slider

    p:Columns(2)
    p:Col(1)
    p:Section("Sound")
    B(p, miss, "Voice lines for errors", "Sound_EnableErrorSpeech", "The spoken \"I can't do that yet\" lines. The red error text stays either way.")
    B(p, miss, "Music", "Sound_EnableMusic", "Background music.")
    B(p, miss, "Ambience", "Sound_EnableAmbience", "Wind, water, crowds and other background sound.")
    B(p, miss, "Dialog", "Sound_EnableDialog", "Spoken dialog from NPCs.")
    B(p, miss, "Sound effects", "Sound_EnableSFX", "Spell, combat and interface sounds.")
    B(p, miss, "Sound while the game is in the background", "Sound_EnableSoundWhenGameIsInBG", "Keeps playing sound when you switch to another window.")
    p:Section("Screen")
    if GS.Exists("UIScale") then
        p:Slider("UI scale", 64, 100,
            function() return math.floor(GS.Num("UIScale") * 100 + 0.5) end,
            function(v) GS.Set("useUiScale", 1); GS.Set("UIScale", v / 100) end,
            { wheel = 2, fmt = function(v) return v .. "%" end,
              tip = "Makes the whole interface bigger or smaller. This is the game's own UI scale (Options > Graphics); everything on screen is resized, so you may want to check where things sit afterwards." })
    else
        miss[1] = miss[1] + 1
    end
    S(p, miss, "Frame rate cap", "MaxFPS", 0, 300, 1, " fps", "The most frames per second the game draws. 0 means no cap.", 10)
    S(p, miss, "Frame rate cap in the background", "maxFPSBk", 0, 200, 1, " fps", "The frame rate cap while the game window is in the background.", 10)
    GS.MissingNote(p, miss)

    p:Col(2)
    p:Section("Any game setting")
    local f, x, y, w = p.frame, p:X(), p:Y(), p.colW
    local nameLabel = M.Text(f, 11, "LEFT", M.GREY); nameLabel:SetPoint("TOPLEFT", x, y); nameLabel:SetText("Setting name (for example nameplateMaxDistance)")
    local nameBox, nameHolder = M.MakeEditBox(f, w); nameHolder:SetPoint("TOPLEFT", x, y - 16)
    local valueLabel = M.Text(f, 11, "LEFT", M.GREY); valueLabel:SetPoint("TOPLEFT", x, y - 52); valueLabel:SetText("New value")
    local valueBox, valueHolder = M.MakeEditBox(f, w); valueHolder:SetPoint("TOPLEFT", x, y - 68)
    local result = M.Text(f, 11, "LEFT", M.WHITE); result:SetPoint("TOPLEFT", x, y - 134); result:SetWidth(w); result:SetWordWrap(true)
    result:SetText("Type a name and press Look up to see what it is set to.")

    local function Describe(name)
        if name == "" then result:SetText("Type a setting name first."); return false end
        if not GS.Exists(name) then result:SetText("The game has no setting called '" .. name .. "'."); return false end
        local default = _G.GetCVarDefault and select(2, pcall(GetCVarDefault, name)) or "?"
        result:SetText(name .. " is " .. tostring(GetCVar(name)) .. "   (the game's own default: " .. tostring(default) .. ")")
        return true
    end
    local look = M.Btn(f, "Look up", 90, 24, function()
        local name = strtrim(nameBox:GetText())
        if Describe(name) then valueBox:SetText(tostring(GetCVar(name))) end
    end)
    look:SetPoint("TOPLEFT", x, y - 100)
    M.Tip(look, "Shows the setting's current value and the game's default for it, and fills the value box.")
    local apply = M.Btn(f, "Set", 70, 24, function()
        local name = strtrim(nameBox:GetText())
        if Describe(name) then GS.Set(name, valueBox:GetText()); Describe(name) end
    end)
    apply:SetPoint("TOPLEFT", x + 98, y - 100)
    M.Tip(apply, "Writes the value you typed. Some settings need a /reload or are locked while you are in combat.")
    local reset = M.Btn(f, "Back to default", 130, 24, function()
        local name = strtrim(nameBox:GetText())
        if Describe(name) and _G.GetCVarDefault then GS.Set(name, GetCVarDefault(name)); Describe(name) end
    end)
    reset:SetPoint("TOPLEFT", x + 176, y - 100)
    M.Tip(reset, "Puts the setting back to the game's own default value.")
    p:Advance(176)
    p:Note("These are the game's own settings, so a wrong value can make things look odd. \"Back to default\" always undoes it.", 3)
end

M.GS = GS
M.builders.gamesettings = BuildGameSettingsPage
M.builders.gamesettings2 = BuildSoundAdvancedPage
