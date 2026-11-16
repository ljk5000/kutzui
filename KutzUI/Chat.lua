---------------------------------------------------------------------------
-- KutzUI / Chat
--
-- 1. FONT. Your chosen font is kept on every chat window (including the combat
--    log), its text box and its tab labels. Chat windows keep whatever SIZE you
--    set in Blizzard's own chat settings; only the font file is swapped.
--
-- 2. ENTER. Pressing Enter (or "/") always opens the text box on the main chat
--    window group - the one on the left of the screen - for whichever of its
--    tabs is selected, no matter which window you clicked last (e.g. the combat
--    log).
--
--    Blizzard's own binding calls ChatFrameUtil.OpenChat(nil) and lets the chat
--    code guess which window you meant. We bind your Enter key to a tiny button
--    that calls the same function but names the selected tab of the main
--    group (FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)).
--
--    The keys come from YOUR bindings (GetBindingKey("OPENCHAT")), so if you
--    rebind "Open chat" this follows. Turn it off in the menu any time.
--
-- Nothing here hooks Blizzard's chat code: fonts are kept by a poller, and the
-- Enter behavior is an override binding (it can't be changed during combat, so
-- it is re-applied when combat ends).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("chat", function()

---------------------------------------------------------------------------
-- 1. Fonts
---------------------------------------------------------------------------
local NUM = _G.NUM_CHAT_WINDOWS or 10
local recs = setmetatable({}, { __mode = "k" })    -- object -> { origPath, ... }

local function Rec(o)
    local r = recs[o]
    if not r then r = {}; recs[o] = r end
    return r
end

local function Force(o)
    if o and o.GetFont then ns.ForceFont(o, Rec(o), 0, true) end
end

local function FontTick()
    for i = 1, NUM do
        local cf = _G["ChatFrame" .. i]
        if cf then
            local isCombatLog = (_G.IsCombatLog and _G.IsCombatLog(cf)) or i == 2
            local db = KutzUIDB
            local size = db and (isCombatLog and db.clogFontSize or (not isCombatLog and db.chatFontSize)) or nil
            if size then
                ns.ForceFont(cf, Rec(cf), 0, false, size)           -- the size you chose on the Chat / Combat log page
            else
                Force(cf)                                           -- any other chat window: your font, Blizzard's size
            end
            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb then
                Force(eb)                                           -- the text box you type in
                Force(eb.header)                                    -- its "Say:" / "Whisper:" prefix
            end
            local tab = _G["ChatFrame" .. i .. "Tab"]
            Force(tab and tab.GetFontString and tab:GetFontString())  -- the tab label
        end
    end
end

---------------------------------------------------------------------------
-- 1b. Chat window look: text opacity, background opacity, line spacing
-- (the combat log has its own, see CombatLog.lua / CombatLogView.lua). Each is only
-- applied once you have moved its slider; until then Blizzard's own settings rule.
---------------------------------------------------------------------------
local look = setmetatable({}, { __mode = "k" })       -- chat frame -> { spacing =, alpha = }

local function LookTick()
    local db = KutzUIDB
    if not db then return end
    for i = 1, NUM do
        local cf = _G["ChatFrame" .. i]
        local isCombatLog = cf and ((_G.IsCombatLog and _G.IsCombatLog(cf)) or i == 2)
        if cf and not isCombatLog then
            local st = look[cf]
            if not st then st = {}; look[cf] = st end

            local spacing = db.chatSpacing or 0
            if st.spacing ~= spacing and cf.SetSpacing then
                if pcall(cf.SetSpacing, cf, spacing) then st.spacing = spacing end
            end

            local container = cf.FontStringContainer
            local wantText = db.chatTextAlpha
            if container and (wantText or st.alphaSet) then
                local a = wantText or 1
                if container:GetAlpha() ~= a then container:SetAlpha(a) end
                st.alphaSet = wantText ~= nil
            end

            local wantBg = db.chatBgAlpha
            if wantBg ~= nil or st.bg then
                if not st.bg then
                    local t = cf:CreateTexture(nil, "BACKGROUND", nil, -8)
                    t:SetPoint("TOPLEFT", -4, 4)
                    t:SetPoint("BOTTOMRIGHT", 4, -4)
                    st.bg = t
                end
                if wantBg ~= nil then
                    if st.bgAlpha ~= wantBg then st.bgAlpha = wantBg; st.bg:SetColorTexture(0, 0, 0, wantBg) end
                    st.bg:Show()
                    if cf.Background and cf.Background:GetAlpha() ~= 0 then cf.Background:SetAlpha(0) end   -- Blizzard's own box
                else
                    st.bg:Hide()
                    st.bgAlpha = nil
                    if cf.Background then cf.Background:SetAlpha(1) end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- 1b. Chat tweaks - each its own switch on the Chat page. Hiding = alpha + mouse only
-- (ns.SetFrameHidden); a slow poller keeps it applied.
---------------------------------------------------------------------------
local TWEAK_DEFAULTS = {
    chatHideButtons   = true,     -- the buttons beside the chat: menu, channels, voice, social
    chatHideScrollbar = true,     -- the scroll bar (the mouse wheel still scrolls)
    chatFadeTabs      = true,     -- tabs only show while the mouse is over the chat
}

function ns.ChatTweak(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return TWEAK_DEFAULTS[name] end
    return v
end

function ns.ResetChatTweaks()
    if not KutzUIDB then return end
    for name in pairs(TWEAK_DEFAULTS) do KutzUIDB[name] = nil end
end

local CHAT_BUTTONS = { "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton" }

local function TweakTick()
    local hideButtons, hideBar = ns.ChatTweak("chatHideButtons"), ns.ChatTweak("chatHideScrollbar")
    for _, name in ipairs(CHAT_BUTTONS) do ns.SetFrameHidden(_G[name], hideButtons) end
    for i = 1, NUM do
        local cf = _G["ChatFrame" .. i]
        if cf then
            ns.SetFrameHidden(cf.buttonFrame, hideButtons)          -- the little frame the buttons sit in
            ns.SetFrameHidden(cf.ScrollBar, hideBar)
        end
    end
end

-- Tabs: shown only while the mouse is over a chat window, its tabs, or you are typing.
local function MouseOverChat()
    local dock = _G.GeneralDockManager
    if dock and dock.IsMouseOver and dock:IsMouseOver() then return true end
    for i = 1, NUM do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.IsShown and cf:IsShown() then
            if cf:IsMouseOver() then return true end
            local tab = _G["ChatFrame" .. i .. "Tab"]
            if tab and tab.IsMouseOver and tab:IsMouseOver() then return true end
            local eb = cf.editBox or _G["ChatFrame" .. i .. "EditBox"]
            if type(eb) == "table" and eb.IsShown and eb:IsShown() and eb:HasFocus() then return true end
        end
    end
    return false
end

local fadeAcc = 0
local fader = CreateFrame("Frame")
fader:SetScript("OnUpdate", function(_, elapsed)
    fadeAcc = fadeAcc + elapsed
    if fadeAcc < 0.1 then return end
    fadeAcc = 0
    local fade = ns.ChatTweak("chatFadeTabs")
    local ok, over = pcall(MouseOverChat)
    over = fade and ok and over
    for i = 1, NUM do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then ns.SetFrameHidden(tab, fade and not over, 1) end
    end
end)

local function SlowTick() FontTick(); LookTick(); TweakTick() end

-- the menu calls this when a chat look slider moves
function ns.RefreshChatLook()
    for cf, st in pairs(look) do st.spacing = nil; st.bgAlpha = nil end
end

---------------------------------------------------------------------------
-- 2. Enter opens the main chat window group
---------------------------------------------------------------------------
local owner = CreateFrame("Frame")     -- owns the override bindings

local function OpenMainChat(text)
    local target
    if _G.FCFDock_GetSelectedWindow and _G.GENERAL_CHAT_DOCK then
        local ok, w = pcall(_G.FCFDock_GetSelectedWindow, _G.GENERAL_CHAT_DOCK)
        if ok and w then target = w end
    end
    target = target or _G.DEFAULT_CHAT_FRAME
    if _G.ChatFrameUtil and _G.ChatFrameUtil.OpenChat then
        _G.ChatFrameUtil.OpenChat(text, target)
    end
end

local function MakeOpener(name, text)
    local b = CreateFrame("Button", name, UIParent)
    b:RegisterForClicks("AnyDown")             -- react when the key goes down, like Blizzard's binding
    b:SetScript("OnClick", function() OpenMainChat(text) end)
    return b
end

MakeOpener("KutzChatOpenEnter", nil)           -- same text argument Blizzard's OPENCHAT passes (nil)
MakeOpener("KutzChatOpenSlash", "/")           -- ... and OPENCHATSLASH ("/")

local SPECS = {
    { binding = "OPENCHAT",      button = "KutzChatOpenEnter" },
    { binding = "OPENCHATSLASH", button = "KutzChatOpenSlash" },
}

local pending = false

local function ApplyBindings()
    if InCombatLockdown() then pending = true; return end
    pending = false
    ClearOverrideBindings(owner)
    if KutzUIDB and KutzUIDB.enterGeneral == false then return end
    for _, spec in ipairs(SPECS) do
        local k1, k2 = GetBindingKey(spec.binding)
        if k1 then SetOverrideBindingClick(owner, false, k1, spec.button, "LeftButton") end
        if k2 then SetOverrideBindingClick(owner, false, k2, spec.button, "LeftButton") end
    end
end
ns.RefreshChatBindings = ApplyBindings

---------------------------------------------------------------------------
-- 3. Short, color-coded tags ([1] [P] [G] [R] ... and [Name][S]:) - see ChatTags.lua
--
-- Blizzard's chat frames offer TransformMessages(predicate, transform) to addons;
-- Blizzard uses it itself. We call it on lines that already exist, only when a
-- window's contents changed, and skip any line we can't read ("secret" text).
-- The combat log is left alone here (it has its own rewriter, see CombatLogView.lua).
---------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
local tagState = setmetatable({}, { __mode = "k" })     -- chat frame -> { n =, newest = }

local function TagPredicate(message)
    if issecret(message) or type(message) ~= "string" then return false end
    return ns.ChatLineNeedsWork(message)
end

local function TagTransform(message, ...)
    return ns.ShortenChatLine(message), ...             -- everything after the text passes through untouched
end

local function TagTick()
    if not (ns.ChatOption("chatShortChannels") or ns.ChatOption("chatShortSpeech")) then return end
    for i = 1, NUM do
        local cf = _G["ChatFrame" .. i]
        local isCombatLog = cf and ((_G.IsCombatLog and _G.IsCombatLog(cf)) or i == 2)
        if cf and not isCombatLog and cf.historyBuffer and cf.TransformMessages then
            local hb = cf.historyBuffer
            local n = hb:GetNumElements()
            local newest = (n > 0) and hb:GetEntryAtIndex(1) or nil
            local st = tagState[cf]
            if not st then st = {}; tagState[cf] = st end
            if st.n ~= n or st.newest ~= newest then
                pcall(cf.TransformMessages, cf, TagPredicate, TagTransform)
                local n2 = hb:GetNumElements()
                st.n, st.newest = n2, (n2 > 0) and hb:GetEntryAtIndex(1) or nil
            end
        end
    end
end

-- called by the menu when an option changes: look at every window's lines again
function ns.RefreshChatTags()
    for cf in pairs(tagState) do tagState[cf] = nil end
end

---------------------------------------------------------------------------
-- Events + poller
---------------------------------------------------------------------------
local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        ApplyBindings()
        -- tags: checked 20 times a second so a new line is shortened before you read it
        local tagAcc = 0
        local tagFrame = CreateFrame("Frame")
        tagFrame:SetScript("OnUpdate", function(_, elapsed)
            tagAcc = tagAcc + elapsed
            if tagAcc < 0.05 then return end
            tagAcc = 0
            local ok, err = pcall(TagTick)
            if not ok and not ns.chatTagErrored then
                ns.chatTagErrored = true
                ns.Print("chat tag error (please report): " .. tostring(err))
            end
        end)

        self:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc < 0.25 then return end
            acc = 0
            local ok, err = pcall(SlowTick)
            if not ok and not ns.chatFontErrored then
                ns.chatFontErrored = true
                ns.Print("chat font error (please report): " .. tostring(err))
            end
        end)
    elseif event == "UPDATE_BINDINGS" then
        ApplyBindings()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then ApplyBindings() end
    end
end)

function ns.DebugChat()
    local sel = _G.FCFDock_GetSelectedWindow and _G.GENERAL_CHAT_DOCK and _G.FCFDock_GetSelectedWindow(_G.GENERAL_CHAT_DOCK)
    local k1, k2 = GetBindingKey("OPENCHAT")
    ns.Print(string.format("chat: selected main tab=%s  OPENCHAT keys=%s,%s  chatStyle=%s  enterOverride=%s  OpenChat=%s",
        sel and sel:GetName() or "?", tostring(k1), tostring(k2), tostring(GetCVar("chatStyle")),
        tostring(not (KutzUIDB and KutzUIDB.enterGeneral == false)),
        tostring(_G.ChatFrameUtil ~= nil and _G.ChatFrameUtil.OpenChat ~= nil)))
end

ns.RegisterDebug(ns.DebugChat)

end)
