---------------------------------------------------------------------------
-- KutzUI / settings pages
-- Action bars, minimap, damage meter, FPS readout, window positions, tooltip placement, tooltip and bags, convenience.
--
-- Part of KutzUI_Options. These files load only when you open /kutz, and only
-- after Menu.lua, which publishes the widget toolkit on KutzUI._opt.
-- Nothing in here runs until that window is opened.
---------------------------------------------------------------------------
local ns = _G.KutzUI
local M = ns._opt
if not M then error("KutzUI settings pages loaded before Menu.lua") end

local function BuildActionBarsPage()
    local p = M.NewPage("Action bars", "Tidy the main action bar: the page arrows at its left end, the end caps, and the keys that switch its page.")
    M.pages.actionbars = p

    p:Columns(2)
    p:Col(1)
    p:Section("Page arrows and art")
    if ns.Enabled("actionbars") then
        p:Check("Hide the page arrows",
            function() return ns.ABOption("abHideArrows") end,
            function(v) ns.SetABOption("abHideArrows", v and true or false) end,
            "Hides the little page number with the up and down arrows at the left end of your main action bar.")
        p:Check("Hide the end caps (gryphons)",
            function() return ns.ABOption("abHideEndCaps") end,
            function(v) ns.SetABOption("abHideEndCaps", v and true or false) end,
            "Hides the gryphon / wyvern art at both ends of the main action bar.")
        p:Check("Lock the action bar page",
            function() return ns.ABOption("abLockPaging") end,
            function(v) ns.SetABOption("abLockPaging", v and true or false) end,
            "The arrows stop working and the keys for Next / Previous action bar and Action bar page 1-6 do nothing, so the bar can't be switched by accident.")
        p:Note("Locking applies to paging you do yourself. Bars the game swaps in on its own (a vehicle, taking control of something, some stances) still change; those are not paging. To rebind the paging keys, turn the lock off first.", 4)
    else
        p:Note("The action bar extras module is switched off (UI features tab), so nothing here is changed.", 3)
        p:Buttons({ { text = "Open the UI features tab", w = 190, click = function() M.ShowTab("modules") end } })
    end

    if ns.Enabled("actionbars") then
        p:Section("Experience bar")
        p:Check("Always show the XP numbers",
            function() return ns.ABOption("abXpText") end,
            function(v) ns.SetABOption("abXpText", v and true or false) end,
            "Writes your XP on the experience bar all the time, like 12,345 / 56,000  (22.1%): the XP you have this level, what the level takes, and how far through it you are. Blizzard only shows its numbers while the mouse is over the bar.")
        p:Check("Show rested XP",
            function() return ns.ABOption("abXpRested") end,
            function(v) ns.SetABOption("abXpRested", v and true or false) end,
            "Adds your rested XP in blue after the percent, like +12,000 rested, while you have some.")
        p:Slider("XP text size", 8, 18,
            function() return ns.ABOption("abXpSize") end,
            function(v) ns.SetABOption("abXpSize", v) end,
            { wheel = 1, fmt = function(v) return v .. " pt" end,
              tip = "Size of the XP numbers on the experience bar." })
        p:Section("Size")
        p:Slider("All action bars", ns.AB_SCALE_MIN, ns.AB_SCALE_MAX,
            function() return ns.ABScaleAll() end,
            function(v) ns.SetABScaleAll(v) end,
            { wheel = 5, fmt = function(v) return v .. "%" end,
              tip = "Makes every action bar bigger or smaller. A bar keeps its place by its anchor, so you may want to nudge bars in Edit Mode afterwards. Changes in combat apply when combat ends." })
        local bars = {}
        for _, bar in ipairs(ns.AB_BARS) do
            if _G[bar.key] then bars[#bars + 1] = bar end
        end
        if #bars > 0 then
            local chosen = bars[1].key
            p:Cycler("One bar on its own", bars,
                function() return chosen end,
                function(k) chosen = k end,
                { tip = "Pick a bar, then use the slider below to give just that bar its own size." })
            p:Slider("That bar's size", ns.AB_SCALE_MIN, ns.AB_SCALE_MAX,
                function() return ns.ABScaleFor(chosen) end,
                function(v) ns.SetABScaleBar(chosen, v) end,
                { wheel = 5, fmt = function(v) return v .. "%" end,
                  tip = "Size of the bar chosen above. Set it back to the 'All action bars' value to follow that again." })
        end
    end

    p:Col(2)
    p:Section("Key labels")
    if ns.Enabled("keybinds") then
        p:Check("Short mouse button names (M4, M5)",
            function() return M.DB.shortKeys ~= false end,
            function(v) M.DB.shortKeys = v and true or false end,
            "\"Mouse Button 4\" becomes \"M4\" (and mouse wheel becomes MwU / MwD) so the label fits. Turning it off needs a /reload to take effect.")
    else
        p:Note("The short key names module is switched off (UI features tab).", 2)
    end
    p:Section("Cooldowns")
    p:Check("Show numbers on cooldowns",
        function() return GetCVarBool("countdownForCooldowns") and true or false end,
        function(v) pcall(SetCVar, "countdownForCooldowns", v and "1" or "0") end,
        "The seconds left on a spell's cooldown, written over the action button. This is Blizzard's own setting (Options > Gameplay > Show Numbers for Cooldowns), so the two always agree.")
    p:Buttons({ { text = "Reset action bar options", w = 210, click = function()
        if ns.ResetABSettings then ns.ResetABSettings() end
    end, tip = "Arrows hidden and locked, end caps as Blizzard has them." } })
end

local function BuildConveniencePage()
    local p = M.NewPage("Convenience", "Small chores the game can do for you. Every one has its own switch.")
    M.pages.convenience = p
    if M.Off(p, "convenience", "The convenience module") then return end

    local function C(label, key, tip)
        p:Check(label, function() return ns.CVOption(key) end, function(v) ns.SetCVOption(key, v and true or false) end, tip)
    end
    p:Columns(2)
    p:Col(1)
    p:Section("At a vendor")
    C("Sell grey junk items", "cvSellJunk", "When you open a vendor, sells every grey item in your bags, the same as Blizzard's Sell All Junk button. You can buy anything back from the vendor's Buyback tab.")
    C("Repair all gear", "cvRepair", "When you open a vendor who repairs, repairs everything you wear and carry, if you have the gold.")
    C("Type the amount when buying", "cvBuyBox", "Shift-click an item at a vendor and type how many you want, even more than one stack. Enter buys, Escape closes. It shows the total cost, buys one stack at a time, and never more than you can afford. Items paid with tokens or other items still use Blizzard's popup.")
    C("Pay repairs from the guild bank", "cvRepairGuild", "Uses your guild's bank gold for the repair when your guild rank allows it enough; otherwise pays from your own gold.")
    p:Section("Looting")
    C("Fast loot", "cvFastLoot", "While auto-loot is on, takes every item at once the moment the corpse or chest opens, instead of one slot at a time. It follows Blizzard's own auto-loot setting and its Shift key, so a loot window still opens when you hold the key.")
    p:Note("Auto-loot itself is Blizzard's setting. You can switch it on or off on the Game settings page.", 2)

    p:Col(2)
    p:Section("Requests")
    C("Decline duels", "cvDeclineDuels", "Says no to every duel request for you, so the popup never gets in the way.")
    C("Accept summons", "cvAcceptSummon", "Accepts a warlock or meeting-stone summon after a moment. Not while you are in combat.")
    C("Accept invites from friends and guild", "cvAcceptInvite", "Joins the group when someone on your friends list, Battle.net friends or guild invites you. Anyone else still gets Blizzard's normal Accept / Decline popup.")
    p:Section("Screenshots")
    C("Screenshot when I earn an achievement", "cvShotAchieve", "Takes a screenshot a second after the achievement toast appears. They land in your World of Warcraft Screenshots folder.")
    C("Screenshot when I level up", "cvShotLevel", "Takes a screenshot a moment after you gain a level.")
    p:Section("Low health")
    p:Check("Blink 3 times at low health", function() return ns.CVOption("cvLowHealth") end,
        function(v) ns.SetCVOption("cvLowHealth", v and true or false); if ns.LowHealthApply then ns.LowHealthApply() end end,
        "Instead of Blizzard's red pulse over the whole screen for as long as your health is under 35%, the screen edge blinks red 3 times, faintly, each time your health drops under 35%. Off = Blizzard's pulse comes back.")
    p:Buttons({ { text = "Reset convenience options", w = 210, click = function() ns.ResetCVSettings(); if ns.LowHealthApply then ns.LowHealthApply() end end,
        tip = "Back to the starting choices: junk, repair, fast loot, declining duels and the achievement screenshot on; the rest off." } })
end

local function BuildTooltipPlacePage()
    local p = M.NewPage("Tooltip placement", "Choose where the mouse-over tooltip appears depending on what you point at: right on the cursor, in a spot you pick, or where Blizzard puts it.")
    M.pages.tooltipplace = p
    if M.Off(p, "movers", "The bag and tooltip module") then return end

    p:Columns(2)
    p:Col(1)
    p:Section("Your locations")
    p:Buttons({
        { text = "Show / hide locations", w = 170, click = function() ns.ToggleTooltipMover() end,
          tip = "Shows three coloured boxes, Location 1, 2 and 3. Drag each where you want tooltips to appear, then right-click a box (or press this button again) to save." },
        { text = "Reset", w = 80, click = function() ns.ResetTooltip() end,
          tip = "Puts the three locations back where they started and sends every tooltip back to Blizzard's usual spot." },
    })
    p:Note("A tooltip grows toward the middle of the screen from its box, so it never runs off the edge. Each tooltip uses the location you pick on the right.", 4)
    p:Note("On the cursor: the tooltip follows the mouse, on the side that has room.", 2)
    p:Note("Blizzard's usual spot: the tooltip stays where the game puts it (beside a button, or at the default place for the world).", 3)
    p:Note("How it decides: a unit in the world is a player or an NPC; a thing in the world is an object; a bag, bank, character, vendor or loot slot is an item; the rest are named by the frame you are over. Anything it can't name is 'Everything else'.", 6)

    p:Col(2)
    p:Section("Where each tooltip goes")
    for _, scenario in ipairs(ns.TT_SCENARIOS) do
        local key = scenario.key
        p:Cycler(scenario.name, ns.TT_PLACES,
            function() return ns.TTWhere(key) end,
            function(k) ns.SetTTWhere(key, k) end,
            { tip = "Where the tooltip goes when you point at: " .. scenario.name .. "." })
    end
end

local function BuildFpsPage()
    local p = M.NewPage("FPS readout", "One tiny line of text with your frame rate and latency, like  144 fps  38 ms . No background, not clickable, in your font.")
    M.pages.fps = p
    if M.Off(p, "fpsreadout", "The FPS and latency readout module") then return end

    p:Columns(2)
    p:Col(1)
    p:Section("Show it")
    p:Check("Show the FPS and latency readout",
        function() return ns.FpsOption("fpsShow") end,
        function(v) ns.SetFpsOption("fpsShow", v and true or false) end,
        "Your frame rate and your world latency (the delay that matters while you play), updated twice a second.")
    p:Cycler("Where", ns.FPS_PLACES,
        function() return ns.FpsOption("fpsPlace") end,
        function(k) ns.SetFpsOption("fpsPlace", k) end,
        { tip = "The top-left corner, the top centre, or the top right just left of the minimap (the very top-right corner is taken by the clock and the minimap's zone bar)." })

    p:Col(2)
    p:Section("Fine tuning")
    p:Slider("Move right (pixels)", -600, 600,
        function() return ns.FpsOption("fpsX") end,
        function(v) ns.SetFpsOption("fpsX", v) end,
        { wheel = 1, tip = "Nudges the readout sideways from its spot. Negative moves it left." })
    p:Slider("Move up (pixels)", -600, 600,
        function() return ns.FpsOption("fpsY") end,
        function(v) ns.SetFpsOption("fpsY", v) end,
        { wheel = 1, tip = "Nudges the readout up (+) or down (-) from its spot." })
    p:Slider("Text size", 8, 24,
        function() return ns.FpsOption("fpsSize") end,
        function(v) ns.SetFpsOption("fpsSize", v) end,
        { wheel = 1, tip = "Size of the text." })
    p:Slider("Opacity", 20, 100,
        function() return ns.FpsOption("fpsAlpha") end,
        function(v) ns.SetFpsOption("fpsAlpha", v) end,
        { wheel = 5, fmt = function(v) return v .. "%" end, tip = "How solid the text is. Lower = more see-through." })
    p:Buttons({ { text = "Reset FPS readout", w = 170, click = function() ns.ResetFpsSettings() end,
        tip = "Back to the top-left corner, normal size." } })
end

local function BuildDamageMeterPage()
    local p = M.NewPage("Damage meter", "Blizzard's own damage meter, kept apart from your combat log: a scoreboard of damage, healing and more, in your font. Switch between it and the log whenever you like.")
    M.pages.damagemeter = p
    if M.Off(p, "damagemeter", "The damage meter module") then return end

    p:Columns(2)
    p:Col(1)
    p:Section("Turn it on")
    p:Check("Show Blizzard's damage meter",
        function() return ns.DMEnabled() end,
        function(v) ns.SetDMEnabled(v) end,
        "The same setting as Blizzard's Options > Gameplay > Damage Meter. Its text uses your chosen font automatically.")
    local status = M.Text(p.frame, 11, "LEFT", M.GREY)
    status:SetPoint("TOPLEFT", p:X(), p:Y())
    status:SetWidth(p.colW)
    status:SetWordWrap(true)
    p:Advance(48)
    p.refreshers[#p.refreshers + 1] = function()
        local ok, reason = ns.DMAvailable()
        local r = ns.dmLoadResult
        if not ok then
            status:SetText("Not available right now: " .. ((type(reason) == "string" and reason ~= "") and reason or "the game did not say why") .. ".")
            status:SetTextColor(1, 0.5, 0.2)
        elseif ns.DMEnabled() and not ns.DMCodeLoaded() then
            status:SetText("The meter is on, but Blizzard's damage meter code is not loaded"
                .. (r and not r.ok and (": " .. tostring(r.reason or "the game did not say why")) or " yet (try /reload)") .. ".")
            status:SetTextColor(1, 0.5, 0.2)
        else
            status:SetText("The game says the damage meter is available here.")
            status:SetTextColor(M.GREY[1], M.GREY[2], M.GREY[3])
        end
    end

    p:Section("What to show")
    p:Cycler("On screen", ns.DM_MODES,
        function() return ns.DMMode() end,
        function(k) if k == "meter" and not (ns.DMEnabled() and ns.DMAvailable()) then return end ns.SetDMMode(k) end,
        { tip = "Both windows, only your combat log, or only the damage meter. 'Damage meter only' needs the meter to be on and available, so you can never lose both." })
    p:Check("Show a small Log / Meter switch button",
        function() return ns.DMButtonEnabled() end,
        function(v) M.DB.dmButton = v and true or false end,
        "A small button in the top-right corner of the combat log window (while the mouse is over it) that flips between the log and the meter. Also: /kutz meter.")

    p:Col(2)
    p:Section("Size, position and look")
    p:Note("These are Blizzard's own, in Edit Mode (press Esc, then Edit Mode, then click the Damage Meter): its position and size, bar height, text size, transparency, background, class colours, spec icons, and when it shows (always, only in combat, only in a group, hidden). You can open up to three windows, each on damage, healing, damage taken, interrupts, and more.", 8)
    p:Note("To use the meter in the combat log's place, drag it there in Edit Mode, then pick 'Damage meter only' here (or click the Log / Meter button) to flip between them.", 4)
    p:Note("Your font is applied to it by the Fonts page (the game-wide font), so turn that on if the meter doesn't look monospaced.", 3)
end

local function BuildMinimapPage()
    local p = M.NewPage("Minimap", "Choose which buttons stay around the minimap. The map, its frame border and the zone name bar are kept.")
    M.pages.minimap = p
    if M.Off(p, "minimap", "The minimap module") then return end

    p:Columns(2)
    p:Col(1)
    p:Section("Quick looks")
    p:Buttons({
        { text = "Clean (map only)", w = 150, click = function() ns.ResetMinimap() end,
          tip = "Hides the calendar, tracking, zoom, landing page, addon list and coordinates; keeps mail, crafting orders, the group finder eye and difficulty; clock in the screen corner." },
        { text = "Show everything", w = 150, click = function() ns.ShowEverythingOnMinimap() end,
          tip = "Every button visible and the clock where Blizzard puts it." },
    })

    p:Section("Clock")
    p:Cycler("Where the clock goes", ns.MM_CLOCK_MODES,
        function() return ns.MMClockMode() end,
        function(k) ns.SetMMClockMode(k) end,
        { tip = "The screen corner is as far top-right as it goes. 'Where Blizzard puts it' undoes any move." })

    p:Section("Coordinates")
    p:Check("Coordinates on the world map",
        function() return ns.MapCoordsOn() end,
        function(v) ns.SetMapCoords(v) end,
        "A line along the bottom of the world map showing where you are and where the mouse is on the map, like Player 45.2, 63.1  Cursor 51.0, 70.3. Inside dungeons and raids the game hides your position, so it shows --.")
    p:Check("One decimal place on the minimap coordinates",
        function() return GetCVarBool("coordsByTenths") and true or false end,
        function(v) pcall(SetCVar, "coordsByTenths", v and "1" or "0") end,
        "Shows 45.2, 63.1 instead of 45, 63 under the minimap. This is Blizzard's own setting. Turn the coordinates on under 'Blizzard's buttons' below.")

    p:Section("Blizzard's buttons")
    for _, b in ipairs(ns.MM_BUTTONS) do
        local key = b.key
        p:Check(b.label .. (b.alert and "  (alert)" or ""),
            function() return ns.MMShown(key) end,
            function(v) ns.SetMMShown(key, v) end,
            b.tip)
    end

    p:Col(2)
    p:Section("Buttons from other addons")
    local found = ns.MMAddonButtons()
    if #found == 0 then
        p:Note("No addon buttons were found on the minimap. Buttons that other addons add later show up here after a reload.", 3)
    else
        for _, b in ipairs(found) do
            local name = b.name
            p:Check(name,
                function() return ns.MMAddonShown(name) end,
                function(v) ns.SetMMAddonShown(name, v) end,
                "Show or hide the minimap button that the " .. name .. " addon adds.")
        end
        p:Buttons({
            { text = "Hide all", w = 110, click = function() ns.SetAllMMAddonShown(false) end },
            { text = "Show all", w = 110, click = function() ns.SetAllMMAddonShown(true) end },
        })
    end
    p:Note("Marked (alert): these tell you something, like new mail or a queue pop, so they stay visible by default. Hidden buttons still work in the background; you just don't see them.", 4)
    p:Buttons({ { text = "Reset minimap options", w = 190, click = function() ns.ResetMinimap() end,
        tip = "Back to the clean look." } })
end

local function WindowControls(p, key, what)
    local function Cur(i) return function() return (select(i, ns.WindowRect(key))) end end
    local function Set(field) return function(v) ns.SetWindowField(key, field, v) end end
    p:Numbers({
        { label = "X  (from left of screen)", get = Cur(1), set = Set("x"),
          tip = "Where the bottom-left corner of the " .. what .. " sits, counted in pixels from the LEFT side of the screen." },
        { label = "Y  (from bottom of screen)", get = Cur(2), set = Set("y"),
          tip = "Where the bottom-left corner of the " .. what .. " sits, counted in pixels from the BOTTOM of the screen." },
        { label = "Width", get = Cur(3), set = Set("w"), tip = "Width of the " .. what .. " in pixels." },
        { label = "Height", get = Cur(4), set = Set("h"), tip = "Height of the " .. what .. " in pixels." },
    })
end

local function BuildWindowsPage()
    local p = M.NewPage("Windows", "Type where each window goes. X and Y are the window's bottom-left corner, counted in pixels from the bottom-left of the screen. Press Enter (or click away) to apply, Tab for the next box.")
    M.pages.windows = p
    if M.Off(p, "windows", "The window positions module") then return end

    p:Columns(2)
    p:Col(1)
    p:Section("Chat window")
    WindowControls(p, "chat", "chat window")
    p:Buttons({ { text = "Give control back", w = 170, click = function() ns.ReleaseWindow("chat") end,
        tip = "Stop holding the chat window at these numbers. It stays where it is now, and you can drag it again." } })

    p:Col(2)
    p:Section("Combat log window")
    WindowControls(p, "clog", "combat log")
    p:Buttons({ { text = "Give control back", w = 170, click = function() ns.ReleaseWindow("clog") end,
        tip = "Stop holding the combat log at these numbers." } })

    p:Below()
    p:Note("The boxes show where each window is right now. Once you change a number, the window is held at these numbers (also after a reload) until you press \"Give control back\". The combat log's filter buttons follow it along the bottom of the screen, so its bottom edge can't go lower than the buttons. If the combat log is docked inside your main chat, drag its tab out into its own window first.", 4)
end

local function BuildMorePage()
    local p = M.NewPage("Tooltips and bags", "Tooltip appearance, item hints, bag position and the alignment grid.")
    M.pages.more = p

    p:Columns(2)
    p:Col(1)
    if ns.Enabled("movers") then
        p:Section("Where tooltips appear")
        p:Note("Where a tooltip goes depending on what you point at (a player, an NPC, a bag item, an action button, a party member ...) now has its own page: Tooltip placement.", 4)
        p:Buttons({ { text = "Open Tooltip placement", w = 190, click = function() M.ShowTab("tooltipplace") end } })
    else
        p:Section("Tooltip and bags")
        p:Note("The bag and tooltip module is switched off (UI features tab).", 2)
    end

    if ns.Enabled("tooltip") then
        p:Section("Tooltip tweaks")
        p:Check("Hide the health bar on tooltips",
            function() return ns.TTOption("ttHideHealthBar") end,
            function(v) ns.SetTTOption("ttHideHealthBar", v and true or false) end,
            "Hides the little health bar under a unit's tooltip.")
        p:Check("Colour-code players and units",
            function() return ns.TTOption("ttColorUnits") end,
            function(v) ns.SetTTOption("ttColorUnits", v and true or false) end,
            "Player names in their class colour, the guild in <angle brackets>, the Alliance in blue and the Horde in red (also on an NPC's kingdom line, like Stormwind or Orgrimmar), and the level coloured by how hard the unit is for you. The level line reads Lvl 7  Human  Paladin, and the faction is shown by the emblem in front of the name, so Blizzard's separate class and faction lines under the level are left out.")
        p:Check("Show symbols",
            function() return ns.TTOption("ttSymbols") end,
            function(v) ns.SetTTOption("ttSymbols", v and true or false) end,
            "A faction emblem and the class icon in front of a player's name, and an emblem beside an NPC's kingdom.")
        p:Check("Show status (Away, Busy, Offline, Dead)",
            function() return ns.TTOption("ttStatus") end,
            function(v) ns.SetTTOption("ttStatus", v and true or false) end,
            "Shows a player who is Away (yellow), Busy (red), Offline (grey) or a Ghost beside their name, with the same little status icons as your friends list, and colours the Dead line.")
        p:Check("Write \"Lvl\" instead of \"Level\"",
            function() return ns.TTOption("ttLvl") end,
            function(v) ns.SetTTOption("ttLvl", v and true or false) end,
            "Shortens the level line on the tooltip of players and NPCs.")
        p:Slider("Fade-out time", 0, ns.TT_FADE_MAX,
            function() return ns.TTOption("ttFadeMs") end,
            function(v) ns.SetTTOption("ttFadeMs", v) end,
            { wheel = 50, fmt = function(v) return v >= ns.TT_FADE_MAX and "Blizzard's own" or (v == 0 and "instant" or (v .. " ms")) end,
              tip = "How long a world tooltip takes to fade away after you move the mouse off a unit or object. 0 = it disappears at once; all the way right = Blizzard's own, longer fade." })
        p:Slider("Tooltip size", ns.TT_SCALE_MIN, ns.TT_SCALE_MAX,
            function() return ns.TTOption("ttScale") end,
            function(v) ns.SetTTOption("ttScale", v) end,
            { wheel = 5, fmt = function(v) return v .. "%" end, tip = "Makes tooltips bigger or smaller." })
        p:Buttons({ { text = "Reset tooltip tweaks", w = 170, click = function() ns.ResetTTSettings() end,
            tip = "Health bar hidden, normal size." } })
    else
        p:Section("Tooltip tweaks")
        p:Note("The tooltip tweaks module is switched off (UI features tab).", 2)
    end

    p:Col(2)
    if ns.Enabled("tooltip") then
        p:Section("Tooltip extras")
        p:Check("Show who the unit is targeting",
            function() return ns.TTOption("ttTarget") end,
            function(v) ns.SetTTOption("ttTarget", v and true or false) end,
            "Adds \"Targeting: Name\" under a unit's tooltip, in the class colour for players and \"Targeting: YOU\" in red when it is you.")
        p:Check("Colour item tooltip borders by quality",
            function() return ns.TTOption("ttRarity") end,
            function(v) ns.SetTTOption("ttRarity", v and true or false) end,
            "Gives the tooltip of a green, blue, purple or better item a border in that quality's colour. Grey and white items keep the plain border.")
        p:Check("Label equipped / not equipped on gear comparisons",
            function() return ns.TTOption("ttCompare") end,
            function(v) ns.SetTTOption("ttCompare", v and true or false) end,
            "When you hover gear and the game shows what you are wearing beside it, the worn item gets a green border and a green EQUIPPED bar, and the item you are hovering gets an orange border and an orange NOT EQUIPPED bar. While a comparison is showing, these colours replace the quality border.")
        p:Check("Show IDs (item, spell, NPC)",
            function() return ns.TTOption("ttIds") end,
            function(v) ns.SetTTOption("ttIds", v and true or false) end,
            "Adds the game's ID number under item, spell, aura, currency and NPC tooltips. Useful for macros, bug reports and looking things up on a database site.")
    end
    if ns.Enabled("itemlevel") then
        p:Section("Item level numbers")
        p:Check("On the character sheet",
            function() return ns.ILOption("ilChar") end,
            function(v) ns.SetILOption("ilChar", v and true or false) end,
            "Writes each piece's item level at the top of its icon on the character sheet.")
        p:Check("On weapons and armour in bags",
            function() return ns.ILOption("ilBags") end,
            function(v) ns.SetILOption("ilBags", v and true or false) end,
            "Writes the item level at the top of the icon of every weapon and piece of armour in your bags, so you can see what is an upgrade at a glance.")
        p:Check("Colour the numbers by quality",
            function() return ns.ILOption("ilColor") end,
            function(v) ns.SetILOption("ilColor", v and true or false) end,
            "Green, blue, purple ... like the item's name. Off: plain white.")
    end
    if ns.Enabled("junkhint") then
        p:Section("Full-bag junk hint")
        p:Slider("Stacks to mark", 1, 10,
            function() return ns.JHOption("jhCount") end,
            function(v) ns.SetJHOption("jhCount", math.floor(v + 0.5)) end,
            { tip = "How many of the cheapest stacks get a red border while every bag slot is taken. Items with no vendor price are never picked." })
    end
    if ns.Enabled("movers") then
        p:Section("Bags")
        p:Buttons({ { text = "Reset bag position", w = 170, click = function() ns.ResetBags() end,
            tip = "Puts your bag back where Blizzard opens it." } })
        p:Note("Press B and drag the bag by an empty part of it. It opens where you left it, even after you log out.", 3)
    end
    p:Section("Alignment grid")
    p:Buttons({ { text = "Toggle grid", w = 130, click = function() ns.ToggleGrid() end,
        tip = "Shows a faint grid over the whole screen to help you line things up. The red lines are the middle of the screen." } })
    p:Note("Also available as /kutz grid.", 1)
end

M.builders.actionbars = BuildActionBarsPage
M.builders.convenience = BuildConveniencePage
M.builders.tooltipplace = BuildTooltipPlacePage
M.builders.fps = BuildFpsPage
M.builders.damagemeter = BuildDamageMeterPage
M.builders.minimap = BuildMinimapPage
M.builders.windows = BuildWindowsPage
M.builders.more = BuildMorePage
