---------------------------------------------------------------------------
-- KutzUI / Convenience        (module "convenience")
--
-- Small chores the game can do for you. Every one has its own switch (menu: Convenience page).
--
--   At a vendor:   sell the grey junk items, repair all gear (optionally from the guild bank)
--   Looting:       "fast loot": when auto-loot is on, take every slot at once instead of one by one
--   Requests:      decline duels; accept summons; accept group invites from friends / guild members
--   Screenshots:   one when you earn an achievement, one when you level up
--   Vendor:        shift-click an item to type how many to buy, any amount (BuyAmount.lua)
--   Low health:    3 faint red blinks instead of Blizzard's full-screen pulse (LowHealthBlink.lua)
--
-- All of it is done with the same game functions Blizzard's own buttons call (the
-- "Sell all junk" button, the repair button, the popups' Accept / Decline). Nothing of
-- Blizzard's is replaced or hooked; each chore is an event handler of its own.
--
-- Safe defaults: junk selling, repairing, fast loot, declining duels and the achievement
-- screenshot are on; summons / invites / level-up screenshots are off until you ask.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("convenience", function()

local DEFAULTS = {
    cvSellJunk     = true,    -- sell grey items when a vendor opens
    cvRepair       = true,    -- repair everything when a vendor opens
    cvRepairGuild  = false,   -- ... paying from the guild bank when it allows it
    cvFastLoot     = true,    -- take all slots at once while auto-loot is on
    cvDeclineDuels = true,
    cvAcceptSummon = false,
    cvAcceptInvite = false,   -- invites from friends / Battle.net friends / guild members
    cvShotAchieve  = true,    -- screenshot when an achievement is earned
    cvShotLevel    = false,   -- screenshot when you level up
    cvBuyBox       = true,    -- shift-click at a vendor: a box to type any amount (BuyAmount.lua)
    cvLowHealth    = true,    -- 3 faint red blinks instead of Blizzard's constant low-health pulse (LowHealthBlink.lua)
}

function ns.CVOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

function ns.SetCVOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
end

function ns.ResetCVSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
end

local function Safe(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local stats = { sold = 0, repaired = 0, looted = 0, duels = 0, summons = 0, invites = 0, shots = 0 }

---------------------------------------------------------------------------
-- Vendor
---------------------------------------------------------------------------
local function Coins(copper)
    if _G.GetCoinTextureString then return _G.GetCoinTextureString(copper) end
    return tostring(copper) .. " copper"
end

local function SellJunk()
    local api = _G.C_MerchantFrame
    if not (api and api.GetNumJunkItems and api.SellAllJunkItems) then return end
    local n = api.GetNumJunkItems()
    if type(n) ~= "number" or n <= 0 then return end
    api.SellAllJunkItems()
    stats.sold = stats.sold + n
    ns.Print("sold " .. n .. " grey item" .. (n == 1 and "" or "s") .. ".")
end

local function Repair()
    if not (_G.CanMerchantRepair and CanMerchantRepair()) then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or type(cost) ~= "number" or cost <= 0 then return end

    if ns.CVOption("cvRepairGuild") and _G.CanGuildBankRepair and CanGuildBankRepair() then
        local allowance = _G.GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
        if allowance == -1 or allowance >= cost then          -- -1: no limit
            RepairAllItems(true)
            stats.repaired = stats.repaired + 1
            ns.Print("repaired for " .. Coins(cost) .. " (guild bank).")
            return
        end
    end
    if GetMoney() >= cost then
        RepairAllItems()
        stats.repaired = stats.repaired + 1
        ns.Print("repaired for " .. Coins(cost) .. ".")
    else
        ns.Print("not enough gold to repair (" .. Coins(cost) .. ").")
    end
end

---------------------------------------------------------------------------
-- Fast loot: LOOT_READY says whether auto-loot is on for this loot. If so, take the slots
-- ourselves right away, last slot first so the list doesn't shift under us.
---------------------------------------------------------------------------
local lastLoot = 0
local function FastLoot(autoLoot)
    if not autoLoot or not (_G.GetNumLootItems and _G.LootSlot) then return end
    local now = GetTime()
    if now - lastLoot < 0.3 then return end                    -- the event can fire twice for one corpse
    lastLoot = now
    for slot = GetNumLootItems(), 1, -1 do
        if not _G.LootSlotHasItem or LootSlotHasItem(slot) then
            LootSlot(slot)
            stats.looted = stats.looted + 1
        end
    end
end

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------
local function KnownPlayer(guid)
    if type(guid) ~= "string" then return false end
    if _G.C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then return true end
    if _G.C_BattleNet and C_BattleNet.GetAccountInfoByGUID and C_BattleNet.GetAccountInfoByGUID(guid) then return true end
    if _G.IsGuildMember and IsGuildMember(guid) then return true end
    return false
end

local function Hide(which) if _G.StaticPopup_Hide then StaticPopup_Hide(which) end end

local handlers = {}

handlers.MERCHANT_SHOW = function()
    if ns.CVOption("cvSellJunk") then Safe(SellJunk) end
    if ns.CVOption("cvRepair") then Safe(Repair) end
end

handlers.LOOT_READY = function(autoLoot)
    if ns.CVOption("cvFastLoot") then Safe(FastLoot, autoLoot) end
end

handlers.DUEL_REQUESTED = function(challenger)
    if not ns.CVOption("cvDeclineDuels") then return end
    -- one tick later: Blizzard's own handler shows the popup first, then we answer it
    C_Timer.After(0, function()
        if _G.CancelDuel then CancelDuel() end
        Hide("DUEL_REQUESTED")
        stats.duels = stats.duels + 1
        ns.Print("declined a duel" .. (type(challenger) == "string" and (" from " .. challenger) or "") .. ".")
    end)
end

handlers.CONFIRM_SUMMON = function()
    if not ns.CVOption("cvAcceptSummon") or InCombatLockdown() then return end
    C_Timer.After(0.2, function()
        if InCombatLockdown() then return end
        if _G.C_SummonInfo and C_SummonInfo.ConfirmSummon then
            C_SummonInfo.ConfirmSummon()
            Hide("CONFIRM_SUMMON"); Hide("CONFIRM_SUMMON_SCENARIO"); Hide("CONFIRM_SUMMON_STARTING_AREA")
            stats.summons = stats.summons + 1
            ns.Print("accepted a summon.")
        end
    end)
end

handlers.PARTY_INVITE_REQUEST = function(name, _, _, _, _, _, guid)
    if not ns.CVOption("cvAcceptInvite") then return end
    if not Safe(KnownPlayer, guid) then return end
    C_Timer.After(0, function()
        if _G.AcceptGroup then
            AcceptGroup()
            Hide("PARTY_INVITE")
            stats.invites = stats.invites + 1
            ns.Print("accepted a group invite" .. (type(name) == "string" and (" from " .. name) or "") .. ".")
        end
    end)
end

local function Shoot(delay)
    C_Timer.After(delay, function()
        if _G.Screenshot then Screenshot(); stats.shots = stats.shots + 1 end
    end)
end

handlers.ACHIEVEMENT_EARNED = function()
    if ns.CVOption("cvShotAchieve") then Shoot(1.0) end      -- give the toast time to appear
end

handlers.PLAYER_LEVEL_UP = function()
    if ns.CVOption("cvShotLevel") then Shoot(1.5) end
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(handlers[event], ...)
    if not ok and not ns.cvErrored then
        ns.cvErrored = true
        ns.Print("convenience error (please report): " .. tostring(err))
    end
end)
ns.cvHandlers = handlers                     -- for the offline tests

ns.RegisterDebug(function()
    ns.Print(string.format("convenience: sold %d junk, %d repairs, %d loot slots, %d duels declined, %d summons, %d invites, %d screenshots | junk=%s repair=%s fastLoot=%s duels=%s",
        stats.sold, stats.repaired, stats.looted, stats.duels, stats.summons, stats.invites, stats.shots,
        tostring(ns.CVOption("cvSellJunk")), tostring(ns.CVOption("cvRepair")),
        tostring(ns.CVOption("cvFastLoot")), tostring(ns.CVOption("cvDeclineDuels"))))
end)

end)
