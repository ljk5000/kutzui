---------------------------------------------------------------------------
-- KutzUI / BuyAmount          (part of module "convenience")
--
-- Shift-click an item at a vendor and Blizzard opens a small "how many?" popup with arrows; you can
-- only type into it blind, and it stops at one stack. This puts a real box in its place:
--
--   [ Buy how many?                      ]
--   [ Coarse Thread                      ]
--   [ [ 100      ]   max 2000            ]
--   [ Total: 1g 0s 0c                    ]
--   [      ( Buy )   ( Cancel )          ]
--
-- Type any number (more than a stack is fine), Enter buys, Escape closes. The amount is rounded down
-- to what the vendor sells per purchase (items sold in bundles of 5 buy 5 at a time), to what you can
-- afford, and to what the vendor has left. It is bought one stack at a time with the same game call
-- Blizzard's popup makes (BuyMerchantItem), a quarter second apart, and stops if the vendor window
-- closes or the game reports an error (bags full, ...).
--
-- Items that cost something other than gold (badges, tokens, other items) are left to Blizzard's own
-- popup, which asks you to confirm those. Nothing of Blizzard's is hooked: a light watcher sees the
-- popup open for a vendor item, closes it, and opens ours in the same spot.
-- Switch: "Type the amount when buying" on the Convenience page (cvBuyBox, on by default).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("convenience", function()

local BUY_GAP = 0.25          -- seconds between purchases
local MAX_TYPED = 99999

local function On() return ns.CVOption("cvBuyBox") and true or false end

local function Coins(copper)
    if GetCoinTextureString then
        local ok, s = pcall(GetCoinTextureString, copper)
        if ok and s then return s end
    end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function ItemInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(info) == "table" then return info end
    end
    if GetMerchantItemInfo then
        local name, _, price, stackCount, numAvailable, _, _, extendedCost = GetMerchantItemInfo(index)
        if name then
            return { name = name, price = price, stackCount = stackCount, numAvailable = numAvailable, hasExtendedCost = extendedCost }
        end
    end
end

---------------------------------------------------------------------------
-- What can be bought: per purchase (bundle), most at once, most in total
---------------------------------------------------------------------------
local function Limits(index)
    local info = ItemInfo(index)
    if not info then return nil end
    local bundle = math.max(1, info.stackCount or 1)
    local perItem = (info.price or 0) / bundle
    local most = MAX_TYPED
    if perItem > 0 then most = math.floor(GetMoney() / perItem) end
    if info.numAvailable and info.numAvailable >= 0 then most = math.min(most, info.numAvailable * bundle) end
    most = most - most % bundle
    local chunk = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(index)) or bundle
    chunk = math.max(bundle, chunk - chunk % bundle)
    return { name = info.name, bundle = bundle, perItem = perItem, most = most, chunk = chunk, extended = info.hasExtendedCost }
end

---------------------------------------------------------------------------
-- Buying, one stack at a time
---------------------------------------------------------------------------
local queue = { index = nil, left = 0, chunk = 1, bought = 0, name = nil }
local buyer = CreateFrame("Frame")
buyer:Hide()

local function StopBuying(why)
    if queue.index and queue.bought > 0 then
        ns.Print(string.format("bought %d x %s%s", queue.bought, queue.name or "item", why and (" (" .. why .. ")") or ""))
    elseif why then
        ns.Print("buying stopped: " .. why)
    end
    queue.index, queue.left, queue.bought = nil, 0, 0
    buyer:Hide()
end

local wait = 0
buyer:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = BUY_GAP
    if not (queue.index and MerchantFrame and MerchantFrame:IsShown()) then StopBuying(queue.left > 0 and "vendor closed" or nil); return end
    if queue.left <= 0 then StopBuying(); return end
    local n = math.min(queue.chunk, queue.left)
    local ok = pcall(BuyMerchantItem, queue.index, n)
    if not ok then StopBuying("the game refused"); return end
    queue.left, queue.bought = queue.left - n, queue.bought + n
end)

buyer:RegisterEvent("UI_ERROR_MESSAGE")
buyer:RegisterEvent("MERCHANT_CLOSED")
buyer:SetScript("OnEvent", function(_, event, _, msg)
    if not queue.index then return end
    if event == "MERCHANT_CLOSED" then StopBuying(queue.left > 0 and "vendor closed" or nil)
    else StopBuying(type(msg) == "string" and msg or "error") end
end)

local function Buy(index, amount)
    local lim = Limits(index)
    if not lim then return end
    amount = math.min(amount, lim.most)
    amount = amount - amount % lim.bundle
    if amount <= 0 then ns.Print("nothing bought: you can't afford any, or the vendor has none left."); return end
    queue.index, queue.left, queue.chunk, queue.bought, queue.name = index, amount, lim.chunk, 0, lim.name
    wait = 0
    buyer:Show()
end

---------------------------------------------------------------------------
-- The box
---------------------------------------------------------------------------
local box = CreateFrame("Frame", "KutzBuyAmountFrame", UIParent, "BackdropTemplate")
box:SetSize(220, 120)
box:SetFrameStrata("DIALOG")
box:SetClampedToScreen(true)
box:EnableMouse(true)
box:Hide()
if box.SetBackdrop then
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                      edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    box:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    box:SetBackdropBorderColor(0.95, 0.78, 0.30, 1)
end

box.title = box:CreateFontString(nil, "OVERLAY")
ns.StyleText(box.title, 12)
box.title:SetPoint("TOP", 0, -10)
box.title:SetText("Buy how many?")
box.title:SetTextColor(1, 0.82, 0)

box.item = box:CreateFontString(nil, "OVERLAY")
ns.StyleText(box.item, 11)
box.item:SetPoint("TOP", box.title, "BOTTOM", 0, -4)
box.item:SetWidth(200)
box.item:SetWordWrap(false)

local edit = CreateFrame("EditBox", "KutzBuyAmountEdit", box, "InputBoxTemplate")
edit:SetSize(80, 20)
edit:SetPoint("TOPLEFT", 22, -50)
edit:SetAutoFocus(false)
edit:SetNumeric(true)
edit:SetMaxLetters(5)
edit:SetJustifyH("CENTER")
box.edit = edit

box.max = box:CreateFontString(nil, "OVERLAY")
ns.StyleText(box.max, 10)
box.max:SetPoint("LEFT", edit, "RIGHT", 10, 0)
box.max:SetTextColor(0.75, 0.75, 0.75)

box.total = box:CreateFontString(nil, "OVERLAY")
ns.StyleText(box.total, 11)
box.total:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -6, -6)

local function Button(text, x)
    local b = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    b:SetSize(80, 22)
    b:SetPoint("BOTTOM", box, "BOTTOM", x, 10)
    b:SetText(text)
    return b
end
local buyBtn = Button("Buy", -44)
local cancelBtn = Button("Cancel", 44)

local function Typed()
    local n = tonumber(edit:GetText()) or 0
    return math.max(0, math.floor(n))
end

local function Refresh()
    local lim = box.index and Limits(box.index)
    if not lim then box:Hide(); return end
    local n = math.min(Typed(), lim.most)
    n = n - n % lim.bundle
    box.max:SetText(string.format("max %d", lim.most))
    if Typed() == 0 then
        box.total:SetText("Total: -")
    else
        local extra = (n ~= Typed()) and string.format("  (%d)", n) or ""
        box.total:SetText("Total: " .. Coins(math.floor(n * lim.perItem + 0.5)) .. extra)
    end
    buyBtn:SetEnabled(n > 0)
end

local function Close() edit:ClearFocus(); box:Hide() end
local function Confirm()
    local index, n = box.index, Typed()
    Close()
    if index and n > 0 then Buy(index, n) end
end

edit:SetScript("OnTextChanged", Refresh)
edit:SetScript("OnEnterPressed", Confirm)
edit:SetScript("OnEscapePressed", Close)
buyBtn:SetScript("OnClick", Confirm)
cancelBtn:SetScript("OnClick", Close)
box:SetScript("OnHide", function(self) self.index = nil; edit:ClearFocus() end)

local function Open(index, owner)
    local lim = Limits(index)
    if not lim then return end
    box.index = index
    box.item:SetText(lim.name or "")
    box:ClearAllPoints()
    box:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 0)
    box:Show()
    edit:SetText(tostring(lim.bundle))
    edit:SetFocus()
    edit:HighlightText()           -- typing replaces it
    Refresh()
end
ns.BuyAmountOpen = Open            -- for the offline tests

---------------------------------------------------------------------------
-- Watching for Blizzard's popup on a vendor item (a cheap check, only while a vendor is open)
---------------------------------------------------------------------------
local function MerchantOwner(owner)
    if type(owner) ~= "table" or not owner.GetName then return nil end
    local name = owner:GetName()
    if type(name) ~= "string" or not name:match("^MerchantItem%d+ItemButton$") then return nil end
    if MerchantFrame and MerchantFrame.selectedTab and MerchantFrame.selectedTab ~= 1 then return nil end
    local index = owner.GetID and owner:GetID()
    if type(index) == "number" and index > 0 then return index end
end

local watch = CreateFrame("Frame")
watch:Hide()
watch:SetScript("OnUpdate", function()
    local split = _G.StackSplitFrame
    if not (On() and split and split:IsShown()) then return end
    local owner = split.owner
    local index = MerchantOwner(owner)
    if not index then return end
    local lim = Limits(index)
    if not lim or lim.extended then return end              -- paid in tokens / items: Blizzard's popup confirms those
    split:Hide()
    Open(index, owner)
end)
watch:RegisterEvent("MERCHANT_SHOW")
watch:RegisterEvent("MERCHANT_CLOSED")
watch:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then self:Show() else self:Hide(); box:Hide() end
end)

ns.RegisterDebug(function()
    ns.Print(string.format("buy amount: on=%s, box %s, buying %s",
        tostring(On()), box:IsShown() and "open" or "closed", queue.index and (queue.left .. " more") or "nothing"))
end)

end)
