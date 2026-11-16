---------------------------------------------------------------------------
-- KutzUI / ItemLevel        (module "itemlevel")
--
-- The item level written on the item itself:
--   * on every slot of the character sheet (head, neck, ... weapons)
--   * on weapons and armour in your bags
-- in a small number at the top of the icon, coloured by the item's quality (or plain white).
-- Each part has its own switch (menu: Tooltip and bags page).
--
-- Nothing of Blizzard's is hooked or changed: the numbers are our own text, in a small
-- frame we put on top of each item button, filled in by a slow check (a few times a second)
-- that only runs while the character sheet or a bag is open.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("itemlevel", function()

local DEFAULTS = {
    ilChar  = true,       -- on the character sheet
    ilBags  = true,       -- on weapons and armour in the bags
    ilColor = true,       -- coloured by quality (off: white)
}

function ns.ILOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

function ns.SetILOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
end

function ns.ResetILSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
end

local issecret = issecretvalue or function() return false end

local SLOT_NAMES = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
                     "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand" }

local labels = setmetatable({}, { __mode = "k" })      -- item button -> { holder =, text =, link =, shown = }

ns.ILLabels = labels                                -- for the offline tests

local function Build(button)
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints(button)
    holder:SetFrameLevel(button:GetFrameLevel() + 8)
    holder:EnableMouse(false)
    local text = holder:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", holder, "TOP", 0, -2)
    ns.StyleText(text, 12)
    local entry = { holder = holder, text = text }
    labels[button] = entry
    return entry
end

-- the number and its colour for an item link, or nil
local function LevelOf(link)
    if type(link) ~= "string" or issecret(link) or not (_G.C_Item and C_Item.GetDetailedItemLevelInfo) then return nil end
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if type(level) ~= "number" or issecret(level) or level < 2 then return nil end
    local r, g, b = 1, 1, 1
    if ns.ILOption("ilColor") and C_Item.GetItemQualityByID and _G.GetItemQualityColor then
        local quality = C_Item.GetItemQualityByID(link)
        if type(quality) == "number" and not issecret(quality) then
            r, g, b = GetItemQualityColor(quality)
        end
    end
    return level, r or 1, g or 1, b or 1
end

-- put the number for `link` on `button` (link nil: clear it)
local function Show(button, link)
    local entry = labels[button]
    if not link then
        if entry and entry.shown then entry.holder:Hide(); entry.shown = false end
        return
    end
    entry = entry or Build(button)
    local color = ns.ILOption("ilColor")
    if entry.link ~= link or entry.color ~= color then
        entry.link, entry.color = link, color
        local level, r, g, b = LevelOf(link)
        if level then
            entry.text:SetText(level)
            entry.text:SetTextColor(r, g, b)
            entry.has = true
        else
            entry.has = false
        end
    end
    if entry.has then
        if not entry.shown then entry.holder:Show(); entry.shown = true end
    elseif entry.shown then
        entry.holder:Hide(); entry.shown = false
    end
end

---------------------------------------------------------------------------
-- Character sheet
---------------------------------------------------------------------------
local function DoCharacter(on)
    local sheet = _G.CharacterFrame
    local active = on and sheet and sheet:IsShown()
    for _, name in ipairs(SLOT_NAMES) do
        local button = _G["Character" .. name .. "Slot"]
        if button then
            if active and button:IsVisible() then
                Show(button, GetInventoryItemLink("player", button:GetID()))
            else
                Show(button, nil)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Bags
---------------------------------------------------------------------------
local bagButtons = {}                                  -- buttons we have written on (to clear them later)

local function GearLink(button)
    if not (_G.C_Container and C_Container.GetContainerItemInfo and button.GetBagID) then return nil end
    local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
    local link = info and info.hyperlink
    if type(link) ~= "string" or issecret(link) then return nil end
    if _G.C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
        if classID ~= 2 and classID ~= 4 then return nil end          -- weapons and armour only
    end
    return link
end

local function DoBags(on)
    local frames = {}
    if _G.ContainerFrameCombinedBags then frames[#frames + 1] = _G.ContainerFrameCombinedBags end
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then frames[#frames + 1] = f end
    end
    local seen = {}
    if on then
        for _, frame in ipairs(frames) do
            if frame:IsShown() and frame.EnumerateValidItems then
                for _, button in frame:EnumerateValidItems() do
                    seen[button] = true
                    bagButtons[button] = true
                    Show(button, GearLink(button))
                end
            end
        end
    end
    for button in pairs(bagButtons) do
        if not seen[button] then
            Show(button, nil)
            bagButtons[button] = nil
        end
    end
end

local function Tick()
    DoCharacter(ns.ILOption("ilChar"))
    DoBags(ns.ILOption("ilBags"))
end
ns.ILTick = Tick

local acc = 0
local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.3 then return end
    acc = 0
    local ok, err = pcall(Tick)
    if not ok and not ns.itemLevelErrored then
        ns.itemLevelErrored = true
        ns.Print("item level error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    local n = 0
    for _ in pairs(labels) do n = n + 1 end
    ns.Print(string.format("item level: character=%s bags=%s colour=%s | %d item buttons have a number frame", tostring(ns.ILOption("ilChar")),
        tostring(ns.ILOption("ilBags")), tostring(ns.ILOption("ilColor")), n))
end)

end)
