---------------------------------------------------------------------------
-- KutzUI / TooltipExtras        (part of module "tooltip")
--
-- Three extra tooltip touches, each with its own switch (menu: Tooltip and bags page):
--
--   * IDs            "Item ID  19019" under item tooltips, "Spell ID" under spells and auras,
--                    "NPC ID" under creatures, "Currency ID" under currencies.  (off to start with:
--                    it's information for the curious, not something to look at all day)
--   * Targeting      "Targeting: Name" under a unit's tooltip, in the class colour for players,
--                    "Targeting: YOU" in red when it's you.
--   * Rarity border  an item's tooltip gets a border in the item's quality colour (green, blue,
--                    purple ...), so a glance tells you what it is.
--
-- Same method as the unit tooltip colouring (TooltipTweaks.lua): functions registered with
-- TooltipDataProcessor.AddTooltipPostCall, which Blizzard runs after it has built the tooltip. They
-- only ADD a line or tint the border; anything the game hides from addons ("secret") is skipped.
-- The border is put back to normal as soon as the tooltip closes or turns into something that
-- isn't an item.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("tooltip", function()

local issecret = issecretvalue or function() return false end
local ID_HEX = "8a8fa3"

local function Clean(v)
    if v == nil or issecret(v) then return nil end
    return v
end

local function Hex(r, g, b)
    return string.format("%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end

-- only the mouse-over tooltip and the one a chat link opens
local function Ours(tooltip)
    return tooltip ~= nil and (tooltip == _G.GameTooltip or tooltip == _G.ItemRefTooltip)
end

---------------------------------------------------------------------------
-- The border: tinted for an item, plain white (= Blizzard's own untinted look) otherwise
---------------------------------------------------------------------------
local tinted = {}                                     -- tooltip -> true while we have coloured its border

local function SetBorder(tooltip, r, g, b)
    local slice = tooltip.NineSlice
    if slice and slice.SetBorderColor then slice:SetBorderColor(r, g, b, 1) end
end

local function ClearBorder(tooltip)
    if tinted[tooltip] then
        tinted[tooltip] = nil
        SetBorder(tooltip, 1, 1, 1)
    end
end

local function TintForItem(tooltip, itemId)
    if not ns.TTOption("ttRarity") then ClearBorder(tooltip); return end
    local quality = _G.C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemId)
    quality = Clean(quality)
    -- poor and common items keep the plain border: only the interesting qualities are tinted
    if type(quality) ~= "number" or quality < 2 or not _G.GetItemQualityColor then ClearBorder(tooltip); return end
    local r, g, b = GetItemQualityColor(quality)
    if r then
        SetBorder(tooltip, r, g, b)
        tinted[tooltip] = true
    end
end

---------------------------------------------------------------------------
-- Lines
---------------------------------------------------------------------------
local function AddId(tooltip, label, id)
    if not ns.TTOption("ttIds") then return end
    id = Clean(id)
    if type(id) ~= "number" then return end
    tooltip:AddLine("|cff" .. ID_HEX .. label .. "  " .. math.floor(id) .. "|r")
end

local function NpcIdFromGuid(guid)
    guid = Clean(guid)
    if type(guid) ~= "string" then return nil end
    local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(npc) end
    return nil
end

local function AddTargeting(tooltip, unit)
    if not ns.TTOption("ttTarget") then return end
    local target = unit .. "target"
    if not UnitExists(target) then return end
    if Clean(UnitIsUnit(target, "player")) then
        tooltip:AddLine("|cffd0d4dcTargeting:|r |cffff4d4dYOU|r")
        return
    end
    local name = Clean(UnitName(target))
    if type(name) ~= "string" then return end
    local hex = "d0d4dc"
    if Clean(UnitIsPlayer(target)) then
        local _, classFile = UnitClass(target)
        classFile = Clean(classFile)
        local c = classFile and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if c then hex = Hex(c.r, c.g, c.b) end
    end
    tooltip:AddLine("|cffd0d4dcTargeting:|r |cff" .. hex .. name .. "|r")
end

---------------------------------------------------------------------------
-- The post-calls
---------------------------------------------------------------------------
local function OnItem(tooltip, data)
    if not Ours(tooltip) or type(data) ~= "table" then return end
    local id = Clean(data.id)
    if type(id) ~= "number" then ClearBorder(tooltip); return end
    TintForItem(tooltip, id)
    AddId(tooltip, "Item ID", id)
end

local function OnSpell(tooltip, data)
    if not Ours(tooltip) or type(data) ~= "table" then return end
    ClearBorder(tooltip)
    AddId(tooltip, "Spell ID", data.id)
end

local function OnCurrency(tooltip, data)
    if not Ours(tooltip) or type(data) ~= "table" then return end
    ClearBorder(tooltip)
    AddId(tooltip, "Currency ID", data.id)
end

local function OnUnit(tooltip, data)
    if tooltip ~= _G.GameTooltip then return end
    ClearBorder(tooltip)
    local _, unit = TooltipUtil.GetDisplayedUnit(tooltip)
    unit = Clean(unit)
    if type(unit) ~= "string" or not UnitExists(unit) then return end
    AddTargeting(tooltip, unit)
    if ns.TTOption("ttIds") then
        local guid = (type(data) == "table" and Clean(data.guid)) or Clean(UnitGUID(unit))
        local npc = NpcIdFromGuid(guid)
        if npc then AddId(tooltip, "NPC ID", npc) end
    end
end

ns.TTExtras = { OnItem = OnItem, OnSpell = OnSpell, OnUnit = OnUnit, OnCurrency = OnCurrency, NpcIdFromGuid = NpcIdFromGuid,
                TintForItem = TintForItem, ClearBorder = ClearBorder }     -- the last two: TooltipCompare.lua puts the quality border back

local function Register(typeName, fn)
    local types = _G.Enum and _G.Enum.TooltipDataType
    local value = types and types[typeName]
    if value == nil then return end
    _G.TooltipDataProcessor.AddTooltipPostCall(value, function(tooltip, data)
        local ok, err = pcall(fn, tooltip, data)
        if not ok and not ns.ttExtrasErrored then
            ns.ttExtrasErrored = true
            ns.Print("tooltip extras error (please report): " .. tostring(err))
        end
    end)
end

if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall and _G.TooltipUtil and _G.TooltipUtil.GetDisplayedUnit then
    Register("Item", OnItem)
    Register("Spell", OnSpell)
    Register("UnitAura", OnSpell)
    Register("Currency", OnCurrency)
    Register("Unit", OnUnit)
end

-- put the border back once the tooltip has closed (a slow check; it does nothing unless we tinted)
local acc = 0
local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    acc = 0
    if next(tinted) == nil then return end
    for tooltip in pairs(tinted) do
        if not tooltip:IsShown() or not ns.TTOption("ttRarity") then pcall(ClearBorder, tooltip) end
    end
end)

end)
