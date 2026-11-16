---------------------------------------------------------------------------
-- KutzUI / JunkHint        (module "junkhint")
--
-- When every bag slot is taken, the 5 stacks that would fetch the least from a vendor get a red
-- border so you know what to delete first. Nothing is highlighted while there is a free slot.
-- Items with no vendor price (quest items and the like) are never picked.
--
-- Same approach as ItemLevel: our own frame on top of each item button, filled in by a slow check
-- (a few times a second) that only runs while a bag is open. Nothing of Blizzard's is hooked.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("junkhint", function()

local DEFAULTS = {
    jhCount = 5,          -- how many stacks to mark
}

function ns.JHOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

function ns.SetJHOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
end

function ns.ResetJHSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
end

local issecret = issecretvalue or function() return false end

local marks = setmetatable({}, { __mode = "k" })       -- item button -> { holder =, shown = }
ns.JHMarks = marks

local function Build(button)
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints(button)
    holder:SetFrameLevel(button:GetFrameLevel() + 9)
    holder:EnableMouse(false)
    local function Edge(p1, p2, w, h)
        local t = holder:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 0.15, 0.15, 0.95)
        t:SetPoint(p1, holder, p1, 0, 0)
        t:SetPoint(p2, holder, p2, 0, 0)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
    end
    Edge("TOPLEFT", "TOPRIGHT", nil, 2)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    Edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
    local entry = { holder = holder, shown = false }
    marks[button] = entry
    return entry
end

local function SetMark(button, on)
    local entry = marks[button]
    if not on then
        if entry and entry.shown then entry.holder:Hide(); entry.shown = false end
        return
    end
    entry = entry or Build(button)
    if not entry.shown then entry.holder:Show(); entry.shown = true end
end

-- every bag we look at: backpack, the four bag slots and the reagent bag
local function BagIds()
    local last = (_G.NUM_BAG_SLOTS or 4) + (_G.NUM_REAGENTBAG_SLOTS or 1)
    local ids = {}
    for bag = 0, last do ids[#ids + 1] = bag end
    return ids
end

-- true when no bag has a free slot
local function BagsFull()
    if not (_G.C_Container and C_Container.GetContainerNumFreeSlots) then return false end
    for _, bag in ipairs(BagIds()) do
        local free = C_Container.GetContainerNumFreeSlots(bag)
        if type(free) == "number" and not issecret(free) and free > 0 then return false end
    end
    return true
end

-- what the whole stack in bag/slot sells for, or nil when it can't be sold / isn't known yet
local function StackValue(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if type(info) ~= "table" then return nil end
    local link, count, noValue = info.hyperlink, info.stackCount, info.hasNoValue
    if issecret(link) or issecret(count) or issecret(noValue) then return nil end
    if type(link) ~= "string" or noValue then return nil end
    local price
    if _G.C_Item and C_Item.GetItemInfo then
        price = select(11, C_Item.GetItemInfo(link))
    elseif _G.GetItemInfo then
        price = select(11, GetItemInfo(link))
    end
    if type(price) ~= "number" or issecret(price) or price <= 0 then return nil end
    return price * (type(count) == "number" and count or 1)
end

-- set of "bag:slot" keys of the cheapest stacks (empty while there is a free slot)
local function Cheapest()
    local picked = {}
    if not BagsFull() then return picked end
    local list = {}
    for _, bag in ipairs(BagIds()) do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local value = StackValue(bag, slot)
            if value then list[#list + 1] = { key = bag .. ":" .. slot, value = value } end
        end
    end
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value < b.value end
        return a.key < b.key
    end)
    for i = 1, math.min(ns.JHOption("jhCount"), #list) do picked[list[i].key] = true end
    return picked
end

local bagButtons = {}                                  -- buttons we have marked (to clear them later)

local function Tick()
    local frames = {}
    if _G.ContainerFrameCombinedBags then frames[#frames + 1] = _G.ContainerFrameCombinedBags end
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then frames[#frames + 1] = f end
    end
    local anyOpen = false
    for _, frame in ipairs(frames) do
        if frame:IsShown() then anyOpen = true end
    end
    local picked = anyOpen and Cheapest() or {}
    local seen = {}
    for _, frame in ipairs(frames) do
        if frame:IsShown() and frame.EnumerateValidItems then
            for _, button in frame:EnumerateValidItems() do
                local bag = button.GetBagID and button:GetBagID()
                local on = (bag ~= nil and picked[bag .. ":" .. button:GetID()]) and true or false
                if on then seen[button] = true; bagButtons[button] = true end
                SetMark(button, on)
            end
        end
    end
    for button in pairs(bagButtons) do
        if not seen[button] then
            SetMark(button, false)
            bagButtons[button] = nil
        end
    end
end
ns.JHTick = Tick

local acc = 0
local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.4 then return end
    acc = 0
    local ok, err = pcall(Tick)
    if not ok and not ns.junkHintErrored then
        ns.junkHintErrored = true
        ns.Print("junk hint error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    local n = 0
    for _, e in pairs(marks) do if e.shown then n = n + 1 end end
    ns.Print(string.format("junk hint: bags full=%s, marking %d (limit %s)", tostring(BagsFull()), n, tostring(ns.JHOption("jhCount"))))
end)

end)
