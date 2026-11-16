---------------------------------------------------------------------------
-- KutzUI / CombatLog
--
-- Restyles the combat log window (ChatFrame2) IN PLACE. It does not move it.
--   * faint background, no border
--   * more transparent text
--   * "Combat Log" tab hidden (filter-button strip kept)
--   * can't be dragged or resized (tab hidden + resize grip disabled)
--
-- IMPORTANT - what this file deliberately does NOT do (learned from the
-- EllesmereUI reference addon, which measured the damage on this client):
--   * no hooksecurefunc on any FCF_* function: the hook wrapper runs inside
--     Blizzard's call and taints it;
--   * no FCF_SetLocked: it writes chatFrame.isLocked, and a tainted write there
--     later breaks the chat tab menu and whisper windows;
--   * no SetParent of Blizzard chat pieces.
-- Instead a poller (outside Blizzard's code) re-applies the style about once
-- a second while you are out of combat.
--
-- The tab hiding and resize lock only apply when the combat log is its own
-- (undocked) window. If it is docked inside your main chat, hiding its tab
-- would make the log unreachable, so only the look is changed.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("combatlog", function()

-- Opacity (0 = invisible, 1 = solid) - set on the menu's Combat log page
local function TextAlpha() return (KutzUIDB and KutzUIDB.clogTextAlpha) or 0.65 end   -- how see-through the text is
local function BgAlpha()   return (KutzUIDB and KutzUIDB.clogBgAlpha)   or 0.20 end   -- how dark the background is (final, on screen)
function ns.CombatLogTextAlpha() return TextAlpha() end      -- (the damage meter swap restores this)
local HIDE_TAB    = true
local LOCK_RESIZE = true

local showTab = false        -- session-only, toggled with /kutz tab
local warnedDocked = false

local function StripRegions(frame)
    if not frame or not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if r and r.IsObjectType and r:IsObjectType("Texture") and not r.kutzOwned then
            r:SetTexture("")
            pcall(r.SetAtlas, r, "")
            r:SetAlpha(0)
        end
    end
end

-- The filter buttons ("My actions", "What happened to me?", "Party"): Blizzard puts them
-- above the log. We seat them flush with the BOTTOM OF THE SCREEN, spanning the log's width,
-- and keep the log itself just above them. (The bar is a protected frame: out of combat only.)
local BAR_H = 24
local BG_PAD = 4          -- how far the log's own dark background sticks out past its text on every side

local function PlaceQuickBar(qb, cl)
    local l, r = cl:GetLeft(), cl:GetRight()
    if not l or not r then return end
    local _, rel = qb:GetPoint(1)
    if rel == UIParent and qb.kutzL == l and qb.kutzR == r then return end       -- already placed
    qb.kutzL, qb.kutzR = l, r
    -- exactly as wide as the log's background, so the two line up on both sides
    qb:ClearAllPoints()
    qb:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - BG_PAD, 0)
    qb:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r + BG_PAD, 0)
end

-- Blizzard puts the first button 3px in and pads every button by 13px (6.5px each side), so the
-- first word starts ~9px inside the bar. Pull the first button back so "My actions" starts exactly
-- where the log's text starts. (Blizzard re-anchors it now and then; out of combat we put it back.)
local TEXT_INSET = -6.5 + BG_PAD      -- the bar now starts BG_PAD further left, so the first word still lines up with the log text

local function AlignButtons(qb)
    local b = _G.CombatLogQuickButtonFrameButton1
    if not b then return end
    local point, rel, relPoint, x = b:GetPoint(1)
    if point == "LEFT" and rel == qb and x ~= TEXT_INSET then
        b:SetPoint("LEFT", qb, relPoint or "LEFT", TEXT_INSET, 0)
    end
end

-- the log must not run underneath the bar: lift it if its bottom edge is lower than the bar's top
local function KeepAboveBar(cl)
    local bottom = cl:GetBottom()
    if not bottom or bottom >= BAR_H - 0.5 or cl:GetNumPoints() ~= 1 then return end
    local point, rel, relPoint, x, y = cl:GetPoint(1)
    cl:SetPoint(point, rel, relPoint, x, y + (BAR_H - bottom))
end

-- Things on the combat log that should not be there. Not protected, so also done in combat.
local function Hush(cl)
    -- the text box: nothing can be typed into the (filtered) combat log. Enter opens the
    -- main chat instead (Chat.lua).
    local eb = _G.ChatFrame2EditBox
    if eb then
        if eb:GetAlpha() ~= 0 then eb:SetAlpha(0) end
        if eb:IsMouseEnabled() then eb:EnableMouse(false) end
    end
    -- the little buttons that open filter menus / minimize the window
    local more = _G.CombatLogQuickButtonFrame_CustomAdditionalFilterButton
    if more then
        if more:GetAlpha() ~= 0 then more:SetAlpha(0) end
        if more:IsMouseEnabled() then more:EnableMouse(false) end
    end
    -- the faint rounded frame that holds the minimize button, at the log's left end
    local bf = cl.buttonFrame or _G.ChatFrame2ButtonFrame
    if bf and bf:GetAlpha() ~= 0 then bf:SetAlpha(0) end
    local mini = _G.ChatFrame2ButtonFrameMinimizeButton
    if mini then
        if mini:GetAlpha() ~= 0 then mini:SetAlpha(0) end
        if mini:IsMouseEnabled() then mini:EnableMouse(false) end
    end
    -- the mouse wheel scrolls Blizzard's own window; make sure nothing is blocking it
    local c = cl.FontStringContainer
    if c and c:GetAlpha() ~= 1 then c:SetAlpha(1) end
    if cl.SetScrollAllowed and not cl.kutzScroll then
        cl.kutzScroll = pcall(cl.SetScrollAllowed, cl, true)
    end
    if cl.EnableMouseWheel and not cl:IsMouseWheelEnabled() then cl:EnableMouseWheel(true) end
end

local function Style()
    local cl = _G.ChatFrame2
    if not cl then return end
    local textAlpha, bgAlpha = TextAlpha(), BgAlpha()

    -- Blizzard's background + border: empty every texture on the frame and on
    -- its Background. (Emptied, not just faded: Blizzard's hover fade then has
    -- nothing to draw.)
    StripRegions(cl)
    if cl.Background then
        cl.Background:SetAlpha(0)
        StripRegions(cl.Background)
    end

    -- our own faint, borderless background
    if not cl.kutzBG then
        local t = cl:CreateTexture(nil, "BACKGROUND", nil, -8)
        t.kutzOwned = true
        t:SetPoint("TOPLEFT", -BG_PAD, BG_PAD)
        t:SetPoint("BOTTOMRIGHT", BG_PAD, -BG_PAD)
        cl.kutzBG = t
    end
    -- the frame's alpha (below) scales this too, so compensate
    cl.kutzBG:SetColorTexture(0, 0, 0, math.min(1, bgAlpha / math.max(textAlpha, 0.05)))

    -- text transparency (0 while the damage meter or KutzUI's own log has taken its place)
    local replaced = (ns.CombatLogSwapped and ns.CombatLogSwapped()) or (ns.KutzLogActive and ns.KutzLogActive())
    cl:SetAlpha(replaced and 0 or textAlpha)

    -- filter buttons: flush with the bottom of the screen
    local quickBar = _G.CombatLogQuickButtonFrame_Custom
    if quickBar and not InCombatLockdown() then
        if not cl.isDocked then KeepAboveBar(cl) end
        PlaceQuickBar(quickBar, cl)
        AlignButtons(quickBar)
    end
    Hush(cl)

    local tab = _G.ChatFrame2Tab
    local resize = _G.ChatFrame2ResizeButton

    if cl.isDocked then
        if not warnedDocked then
            warnedDocked = true
            ns.Print("Combat log is docked inside your main chat, so I only changed its look. "
                .. "Drag its tab out into its own window if you want it tab-less and locked.")
        end
    else
        -- tab
        if tab then
            if HIDE_TAB and not showTab then
                ns.hideCombatLogTab = true
                if not tab.kutzHooked then
                    tab.kutzHooked = true
                    -- Blizzard's hover fade re-Shows the tab; hide it again
                    tab:HookScript("OnShow", function(self)
                        if ns.hideCombatLogTab then self:Hide() end
                    end)
                end
                if tab:IsShown() then tab:Hide() end

                -- Blizzard parents the filter-button strip to the tab; keep it
                -- visible by seating it on the chat frame instead (same as the
                -- reference addon). Out of combat only: it is a protected frame.
                local qb = _G.CombatLogQuickButtonFrame_Custom
                if qb and not InCombatLockdown() and qb:GetParent() ~= cl then
                    qb:SetParent(cl)
                end
            elseif ns.hideCombatLogTab then
                ns.hideCombatLogTab = false
                tab:Show()
            end
        end

        -- resize grip: invisible and dead (the tab is gone, so no dragging either)
        if resize then
            if LOCK_RESIZE and not showTab then
                resize:SetAlpha(0)
                resize:EnableMouse(false)
            else
                resize:EnableMouse(true)
                resize:SetAlpha(1)
            end
        end
    end
end

-- the menu calls this when you change opacity / button position, so it shows at once
function ns.RestyleCombatLog()
    if not InCombatLockdown() then pcall(Style) end
end

-- Fast poller: Blizzard re-shows the text box whenever chat is opened or faded.
local fastAcc = 0
local fast = CreateFrame("Frame")
fast:SetScript("OnUpdate", function(_, elapsed)
    fastAcc = fastAcc + elapsed
    if fastAcc < 0.25 then return end
    fastAcc = 0
    local cl = _G.ChatFrame2
    if cl then pcall(Hush, cl) end
end)

-- Poller: about once a second, out of combat.
local acc = 0
local follower = CreateFrame("Frame")
follower:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = 0
    if InCombatLockdown() then return end
    local ok, err = pcall(Style)
    if not ok and not ns.combatLogErrored then
        ns.combatLogErrored = true
        ns.Print("combat log style error (please report): " .. tostring(err))
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
ns.RegisterSlash("tab", function()
    showTab = not showTab
    Style()
    ns.Print("Combat log tab " .. (showTab and "shown (right-click it for settings)" or "hidden") .. ".")
end)
ns.RegisterSlash("log", function()
    Style()
    ns.Print("Combat log restyled.")
end)
ns.RegisterDebug(function()
    local cl = _G.ChatFrame2
    ns.Print("ChatFrame2=" .. tostring(cl ~= nil)
        .. " docked=" .. tostring(cl and cl.isDocked and true or false)
        .. " Background=" .. tostring(cl and cl.Background ~= nil)
        .. " tab=" .. tostring(_G.ChatFrame2Tab ~= nil)
        .. " quickButtons=" .. tostring(_G.CombatLogQuickButtonFrame_Custom ~= nil)
        .. " resizeButton=" .. tostring(_G.ChatFrame2ResizeButton ~= nil))
end)

end)
