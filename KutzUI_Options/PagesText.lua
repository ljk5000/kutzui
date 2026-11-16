---------------------------------------------------------------------------
-- KutzUI / settings pages
-- Fonts, combat log and chat.
--
-- Part of KutzUI_Options. These files load only when you open /kutz, and only
-- after Menu.lua, which publishes the widget toolkit on KutzUI._opt.
-- Nothing in here runs until that window is opened.
---------------------------------------------------------------------------
local ns = _G.KutzUI
local M = ns._opt
if not M then error("KutzUI settings pages loaded before Menu.lua") end

local function BuildFontsPage()
    local p = M.NewPage("Fonts", "One font for the whole game: your own text, the character sheet, spellbook, professions, quest log, tooltips and chat.")
    M.pages.fonts = p

    p:Section("Font")
    p:Cycler("Font", ns.FONTS,
        function() return ns.CurrentFontKey() end,
        function(k) M.DB.font = k; ns.ApplyFont() end,
        { previewBelow = true,
          tip = "All three are monospaced with a slashed zero. 'Default (Blizzard)' puts the game's own font back.",
          makePreview = function(parent, x, y, w)
              local fs = M.Text(parent, 15, "LEFT", M.WHITE)
              fs:SetPoint("TOPLEFT", x, y)
              fs:SetWidth(w)
              fs:SetWordWrap(false)
              fs:SetText("0123456789  O0  Il1  |  12.3K  98%  M4  [Example Player]")
              return function() ns.StyleText(fs, 15) end
          end })
    if ns.Enabled("fonts") then
        p:Check("Use this font everywhere in the game",
            function() return M.DB.fontEverywhere ~= false end,
            function(v) M.DB.fontEverywhere = v and true or false; ns.RefreshUIFont() end,
            "On: the font is used by every window Blizzard draws (character sheet, spellbook, professions, quest log, tooltips, menus). Off: only the text this addon draws and the chat.")
        p:Slider("Game text size (adjust all)", -3, 6,
            function() return M.DB.uiFontOffset or 0 end,
            function(v) M.DB.uiFontOffset = (v ~= 0) and v or nil; ns.RefreshUIFont() end,
            { wheel = 1, fmt = function(v) return (v > 0 and "+" or "") .. v end,
              tip = "Makes all of the game's text a little bigger or smaller. Handy if a wide font makes some windows feel cramped." })
        p:Check("Floating combat numbers use this font too",
            function() return M.DB.fontCombatNumbers ~= false end,
            function(v) M.DB.fontCombatNumbers = v and true or false end,
            "The damage and healing numbers that float up from enemies and from you. The game reads this once when it starts, so a change needs a full restart (log out and back in is not enough on its own; quit the game).")
        p:Note("Names, level numbers and the key labels on your action bars follow this font too. Some very wide fonts can cut off text in tight spots; the size adjustment above, or a different font, fixes that.", 3)
        p:Note("Your font files only have Latin letters, so on Korean, Chinese and Russian game clients the game-wide font is left alone.", 2)
    else
        p:Note("The game-wide font module is switched off (UI features tab), so only the text Kutz UI draws uses this font.", 2)
    end

end

local function CurrentCombatLogSize()
    local cf = _G.ChatFrame2
    local _, size = cf and cf:GetFont()
    return math.floor((size or 14) + 0.5)
end

local function BuildCombatPage()
    local p = M.NewPage("Combat log", "How the combat log window looks: font, see-through text and background, spacing.")
    M.pages.combat = p
    if M.Off(p, "combatlog", "The combat log module") then return end

    p:Columns(2)
    p:Col(1)
    p:Section("Look")
    p:Slider("Font size", 8, 28,
        function() return M.DB.clogFontSize or CurrentCombatLogSize() end,
        function(v) M.DB.clogFontSize = v end,
        { wheel = 1, tip = "Size of the text in the combat log window." })
    p:Slider("Text opacity", 20, 100,
        function() return math.floor(((M.DB.clogTextAlpha or 0.65) * 100) + 0.5) end,
        function(v) M.DB.clogTextAlpha = v / 100; ns.RestyleCombatLog() end,
        { wheel = 5, fmt = function(v) return v .. "%" end, tip = "How solid the text is. Lower = more see-through." })
    p:Slider("Background opacity", 0, 80,
        function() return math.floor(((M.DB.clogBgAlpha or 0.20) * 100) + 0.5) end,
        function(v) M.DB.clogBgAlpha = v / 100; ns.RestyleCombatLog() end,
        { wheel = 5, fmt = function(v) return v .. "%" end, tip = "How dark the box behind the text is. 0% = no background at all." })
    p:Slider("Line spacing", 0, 10,
        function() return M.DB.clogSpacing or 0 end,
        function(v) M.DB.clogSpacing = (v ~= 0) and v or nil; ns.RefreshCombatView() end,
        { wheel = 1, tip = "Extra space between lines." })

    p:Col(2)
    p:Section("Which lines")
    p:Check("Only real combat in this window", function() return ns.CLOption("clogOnlyCombat") end,
        function(v) ns.SetCLOption("clogOnlyCombat", v and true or false); ns.RefreshCombatView() end,
        "Blizzard also routes crafting, experience and some loot messages into the combat log. With this on they are left out.")
    p:Note("The filter buttons (My actions, What happened to me?, Party) sit flush with the bottom of the screen.", 2)

    p:Below()
    p:Section("Which combat log")
    local viewPick = ns.CLView()
    p:Cycler("Show", {
            { key = "own",   name = "Blizzard's log, as I set it up myself" },
            { key = "stock", name = "Blizzard's log, out of the box" },
            { key = "best",  name = "Blizzard's log, best settings for me" },
            { key = "kutz",  name = "KutzUI log (Details!-style, with meters)" },
        },
        function() return viewPick end,
        function(k)
            viewPick = k
            if k == "kutz" or not ns.CLViewNeedsReload(k) then
                ns.CLApplyView(k); ns.RestyleCombatLog()
            end
        end,
        { tip = "Blizzard's choices change only how Blizzard's lines look (Apply reloads the interface once - the game only takes new combat log settings while it loads). Best settings: timestamps, short lines, everyone coloured by who they are with your own gold colour, whole lines in the colour of whoever did it, spell names and numbers in their school's colour, raid markers, no brackets. KutzUI log: our own window in the same place - a log of your casts and of hits on you, your target and your pet, plus damage / healing / taken / deaths bars from Blizzard's damage meter data." })
    local status = p:Note("", 2)
    p.refreshers[#p.refreshers + 1] = function()
        if viewPick ~= ns.CLView() and ns.CLViewNeedsReload(viewPick) then
            status:SetText("|cffffd24aNot applied yet.|r Press Apply: the interface reloads once and Blizzard's log then uses these settings.")
        else
            status:SetText(ns.CLViewStatus())
        end
    end
    p:Buttons({ { text = "Apply (reloads)", w = 150, click = function()
        if viewPick == ns.CLView() and not ns.CLViewNeedsReload(viewPick) then return end
        local ok, why = ns.CLApplyView(viewPick)
        if not ok then ns.Print("Combat log: " .. tostring(why) .. ".") end
    end, tip = "Puts the chosen settings into Blizzard's combat log and reloads the interface so the game applies them. Your own settings were copied the first time, so 'as I set it up myself' brings them back." } })
    p:Note("The game seals the words of Blizzard's lines from addons and won't let addons read the real combat log, so KutzUI's log is built from what addons can see: it can't say who hit you or with what, and the game may hide numbers in combat (they still show). Line colours of Blizzard's log: right-click the General chat tab > Settings > Combat.", 3)
    p:Buttons({ { text = "Reset combat log settings", w = 220, click = function()
        ns.ResetCLSettings(); ns.RestyleCombatLog(); ns.RefreshCombatView()
    end, tip = "Puts the look settings on this page back to normal." } })
end

local function CurrentChatSize()
    local cf = _G.ChatFrame1
    local _, size = cf and cf:GetFont()
    return math.floor((size or 14) + 0.5)
end

local function BuildChatPage()
    local p = M.NewPage("Chat", "Short, color-coded prefixes in your chat windows, and where the text box opens when you press Enter.")
    M.pages.chat = p
    if M.Off(p, "chat", "The chat module") then return end

    local baseColors = {
        { 1.00, 0.75, 0.75 }, { 1.00, 0.75, 0.75 }, { 0.67, 0.67, 1.00 }, { 0.25, 1.00, 0.25 },
        { 1.00, 0.28, 0.04 }, { 1.00, 1.00, 1.00 }, { 1.00, 0.25, 0.25 }, { 1.00, 0.50, 1.00 },
    }
    local order = {}
    for i, raw in ipairs(ns.CHAT_SAMPLES) do order[raw] = i end
    p:SubTab("messages", "Message format")
    p:Preview(ns.CHAT_SAMPLES, function(raw)
        local c = baseColors[order[raw]] or { 1, 1, 1 }
        return ns.ShortenChatLine(raw), c[1], c[2], c[3]
    end, function()
        local cf = _G.ChatFrame1
        local _, size = cf and cf:GetFont()
        return math.floor((size or 14) + 0.5)
    end)

    p:Columns(2)
    p:Col(1)
    if GetCVar("profanityFilter") ~= nil then
        p:Section("Language")
        p:Check("Show uncensored words",
            function() return GetCVar("profanityFilter") == "0" end,
            function(v) SetCVar("profanityFilter", v and "0" or "1") end,
            "Turns off WoW's mature language filter for new chat messages. Uncheck to filter words again. This changes the game's own setting immediately.")
    end
    p:Section("Short prefixes")
    p:Check("Short channel names: [1] [P] [G] [R]",
        function() return ns.ChatOption("chatShortChannels") end,
        function(v) M.DB.chatShortChannels = v and true or false; ns.RefreshChatTags() end,
        "[1. General - Elwynn Forest] becomes [1], [2. Trade - City] becomes [2], [Party] becomes [P], [Guild] [G], [Raid] [R], [Raid Leader] [RL], [Instance] [I] ... Each has its own color.")
    p:Check("Short speech tags: [Name][S]:",
        function() return ns.ChatOption("chatShortSpeech") end,
        function(v) M.DB.chatShortSpeech = v and true or false; ns.RefreshChatTags() end,
        "\"[Example Player] says:\" becomes \"[Example Player][S]:\", yells become [Y], whispers [W].")
    p:Section("Tag colors")
    p:Swatches(ns.CHAT_COLORS, ns.ChatColor, ns.SetChatColor, 3)
    p:Note("New colors show on new messages only.", 1)

    -- Blizzard's own chat time stamps (the game option "showTimestamps"; it is the single source of truth)
    p:Section("Time stamps")
    local function StampFormat() local v = GetCVar("showTimestamps"); return (v and v ~= "none" and v ~= "0") and v or nil end
    local function SetStamp(on, h24, secs)
        if not on then SetCVar("showTimestamps", "none"); return end
        SetCVar("showTimestamps", (h24 and "%H" or "%I") .. ":%M" .. (secs and ":%S" or "") .. (h24 and "" or " %p") .. " ")
    end
    local function Has(token) local f = StampFormat(); return f and f:find(token, 1, true) ~= nil end
    p:Check("Show the time on chat lines",
        function() return StampFormat() ~= nil end,
        function(v) SetStamp(v, Has("%H") or not StampFormat(), Has("%S")) end,
        "Puts the time in front of every new chat line (this is the game's own time stamp option).")
    p:Check("Include seconds",
        function() return Has("%S") end,
        function(v) SetStamp(true, Has("%H") or not StampFormat(), v) end,
        "12:34:56 instead of 12:34.")
    p:Check("24-hour clock",
        function() return Has("%H") end,
        function(v) SetStamp(true, v, Has("%S")) end,
        "On: 18:30. Off: 6:30 PM.")

    p:SubTab("window", "Window, typing and copy")
    p:Columns(2)
    p:Col(1)
    p:Section("Copy chat")
    p:Check("Show a copy button on chat windows",
        function() return ns.ChatCopyButtonEnabled() end,
        function(v) M.DB.chatCopyButton = v and true or false end,
        "A small 'copy' button appears in the top-right corner of a chat window while the mouse is over it. It opens the chat as text you can select and copy. Also: /kutz copy.")
    p:Slider("Chat history (lines)", 128, 1000,
        function() return M.DB.chatHistoryLines or 128 end,
        function(v) M.DB.chatHistoryLines = (v ~= 128) and v or nil end,
        { wheel = 10, tip = "How many lines each chat window remembers (and the copy window can show). Blizzard's normal is 128. Going back to 128 takes effect after a reload." })
    p:Buttons({ { text = "Open the copy window", w = 190, click = function() ns.ChatCopyOpen() end,
        tip = "Copy the chat tab you are looking at." } })

    p:Col(2)
    p:Section("Chat window look")
    p:Slider("Font size", 8, 28,
        function() return M.DB.chatFontSize or CurrentChatSize() end,
        function(v) M.DB.chatFontSize = v; ns.RefreshChatLook() end,
        { wheel = 1, tip = "Size of the text in your chat windows (not the combat log - that has its own on the Combat log page)." })
    p:Slider("Text opacity", 20, 100,
        function() return math.floor(((M.DB.chatTextAlpha or 1) * 100) + 0.5) end,
        function(v) M.DB.chatTextAlpha = v / 100; ns.RefreshChatLook() end,
        { wheel = 5, fmt = function(v) return v .. "%" end, tip = "How solid the chat text is. Lower = more see-through." })
    p:Slider("Background opacity", 0, 80,
        function() return math.floor(((M.DB.chatBgAlpha or 0.25) * 100) + 0.5) end,
        function(v) M.DB.chatBgAlpha = v / 100; ns.RefreshChatLook() end,
        { wheel = 5, fmt = function(v) return v .. "%" end, tip = "How dark the box behind the chat is. 0% = no background at all." })
    p:Slider("Line spacing", 0, 10,
        function() return M.DB.chatSpacing or 0 end,
        function(v) M.DB.chatSpacing = (v ~= 0) and v or nil; ns.RefreshChatLook() end,
        { wheel = 1, tip = "Extra space between chat lines." })
    p:Section("Typing")
    p:Check("Enter always opens the main chat",
        function() return M.DB.enterGeneral ~= false end,
        function(v) M.DB.enterGeneral = v and true or false; ns.RefreshChatBindings() end,
        "Pressing Enter (or /) opens the text box on the main chat window - the one at the left - for whichever of its tabs is selected, even if you last clicked the combat log.")
    p:Note("The text box always goes with the main chat window group, whichever tab of it is selected. It follows your own \"Open chat\" key binding.", 3)
    p:Section("Tweaks")
    local function Tweak(name) return function() return ns.ChatTweak(name) end end
    local function SetTweak(name) return function(v) M.DB[name] = v and true or false end end
    p:Check("Hide the chat buttons", Tweak("chatHideButtons"), SetTweak("chatHideButtons"),
        "Hides the buttons beside the chat: the chat menu, channels, voice and the social button. Right-click a chat tab for the same menu.")
    p:Check("Hide the scroll bar", Tweak("chatHideScrollbar"), SetTweak("chatHideScrollbar"),
        "Hides the scroll bar. The mouse wheel still scrolls the chat.")
    p:Check("Fade the tabs until the mouse is over the chat", Tweak("chatFadeTabs"), SetTweak("chatFadeTabs"),
        "The tabs (General, Trade ...) only show while the mouse is over a chat window, or while you are typing.")
    p:Buttons({ { text = "Reset chat settings", w = 170, click = function()
        ns.ResetChatTweaks()
        ns.ResetChatTagSettings(); ns.RefreshChatTags()
        M.DB.chatFontSize, M.DB.chatTextAlpha, M.DB.chatBgAlpha, M.DB.chatSpacing = nil, nil, nil, nil
        ns.RefreshChatLook()
        if M.pages.chat then M.pages.chat:Refresh() end
    end, tip = "Short prefixes, colors and the chat window look back to normal." } })
end

M.builders.fonts = BuildFontsPage
M.builders.combat = BuildCombatPage
M.builders.chat = BuildChatPage
