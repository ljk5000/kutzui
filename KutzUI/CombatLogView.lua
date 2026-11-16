---------------------------------------------------------------------------
-- KutzUI / CombatLogView
--
-- Makes Blizzard's combat log read the way the menu's Combat log page says.
--
-- WHAT IS POSSIBLE ON THIS CLIENT (learned in game):
--   * every combat line's text is an opaque token like |Ky49|k - an addon cannot read or
--     re-write the words;
--   * writing to Blizzard's combat log settings and calling C_CombatLog.ApplyFilterSettings /
--     RefilterEntries is BLOCKED for addons ("KutzUI has been blocked from an action only
--     available to the Blizzard UI"), so colors are left to Blizzard's own Chat Settings;
--   * lines that came through chat (crafting, experience, loot) carry a chat-type number
--     and CAN be removed from the window, and line spacing can be set. That is all this does.
--
-- Nothing here replaces or hooks a Blizzard function.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("combatlog", function()

local issecret = issecretvalue or function() return false end

local stats = { passes = 0, hidden = 0 }
local dirty, installed, needRemove, lastForce = true, false, false, 0
local lastSpacing

---------------------------------------------------------------------------
-- Keep non-combat lines out of the window (they carry a chat-type number)
---------------------------------------------------------------------------
local HIDE = "|rkutz-hidden"

local function OnlyCombat()
    local saved = _G.Blizzard_CombatLog_Filters
    local selected = saved and saved.filters and saved.filters[saved.currentFilter]
    return ns.CLOption("clogOnlyCombat") and not (selected and selected.kutzAll)
end

-- The supported chat filter runs before AddMessage. It only suppresses messages
-- destined for the combat window; General and other chat windows keep theirs.
local function BeforeDisplay(frame)
    return frame == _G.ChatFrame2 and OnlyCombat() or false
end
local function InstallChatFilters()
    local util = _G.ChatFrameUtil
    local add = util and util.AddMessageEventFilter or _G.ChatFrame_AddMessageEventFilter
    if not add then return end
    for _, suffix in ipairs({ "LOOT", "MONEY", "CURRENCY", "OPENING", "TRADESKILLS", "SKILL",
        "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SYSTEM" }) do
        add("CHAT_MSG_" .. suffix, BeforeDisplay)
    end
end

local function Pred(msg, r, g, b, chatType)
    if chatType == nil or issecret(chatType) or issecret(msg) then return false end
    if type(msg) ~= "string" or msg:sub(1, #HIDE) == HIDE then return false end
    return OnlyCombat()
end

local function Xform(msg, r, g, b, chatType, ...)
    needRemove = true
    stats.hidden = stats.hidden + 1
    return HIDE, r, g, b, chatType, ...
end

local function RemovePred(msg)
    if issecret(msg) or type(msg) ~= "string" then return false end
    return msg:sub(1, #HIDE) == HIDE
end

---------------------------------------------------------------------------
-- Tick
---------------------------------------------------------------------------
local function Tick(now)
    local cl = _G.ChatFrame2
    if not cl or not cl.TransformMessages then return end

    if not installed and cl.AddOnDisplayRefreshedCallback then
        installed = pcall(cl.AddOnDisplayRefreshedCallback, cl, function() dirty = true end)
    end
    if not installed and now - lastForce > 1 then dirty = true end

    local spacing = (KutzUIDB and KutzUIDB.clogSpacing) or 0
    if spacing ~= lastSpacing and cl.SetSpacing then
        lastSpacing = spacing
        pcall(cl.SetSpacing, cl, spacing)
    end

    if not dirty then return end
    dirty = false
    lastForce = now
    stats.passes = stats.passes + 1
    pcall(cl.TransformMessages, cl, Pred, Xform)
    if needRemove then
        needRemove = false
        if cl.RemoveMessagesByPredicate then pcall(cl.RemoveMessagesByPredicate, cl, RemovePred) end
    end
end

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InstallChatFilters()
        local getMeta = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
        ns.Print("v" .. tostring(getMeta and getMeta(ADDON_NAME, "Version") or "?") .. " loaded - /kutz opens the settings")
        self:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc < 0.25 then return end
            acc = 0
            local ok, err = pcall(Tick, GetTime())
            if not ok and not ns.combatViewErrored then
                ns.combatViewErrored = true
                ns.Print("combat log error (please report): " .. tostring(err))
            end
        end)
    end
end)

-- the menu calls this after any combat log setting changes
function ns.RefreshCombatView()
    lastSpacing = nil
    dirty = true
end

function ns.DebugCombatView()
    local cl = _G.ChatFrame2
    ns.Print(string.format("combat log: passes=%d non-combat lines removed=%d | window refresh notice=%s | ChatFrame2=%s TransformMessages=%s edit box alpha=%s",
        stats.passes, stats.hidden, tostring(installed), tostring(cl ~= nil), tostring(cl and cl.TransformMessages ~= nil),
        _G.ChatFrame2EditBox and string.format("%.1f", _G.ChatFrame2EditBox:GetAlpha()) or "?"))
end

ns.RegisterDebug(ns.DebugCombatView)

end)
