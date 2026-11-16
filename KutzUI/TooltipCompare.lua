---------------------------------------------------------------------------
-- KutzUI / TooltipCompare       (part of module "tooltip")
--
-- When you hover a piece of gear, Blizzard shows what you are wearing next to it. Both tooltips look
-- alike, and the only hint is a tiny "Equipped" tab on one of them. This makes it obvious:
--
--   * the tooltip of what you are WEARING   green border + a green "EQUIPPED" bar
--   * the tooltip of what you are HOVERING  orange border + an orange "NOT EQUIPPED" bar
--
-- (menu: Tooltip and bags page, "Label equipped / not equipped on gear comparisons")
--
-- Nothing is read from the item data and no tooltip line is touched: the bar is a small frame of our own
-- under the tooltip, and the border is tinted the same way TooltipExtras.lua tints the quality border.
-- A slow-ish check (20x a second, and only while a comparison is on screen) decides which tooltip gets
-- which look, so it does not matter in which order Blizzard builds and shows them.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("tooltip", function()

local issecret = issecretvalue or function() return false end

local EQUIPPED     = { r = 0.20, g = 0.85, b = 0.40, text = "EQUIPPED" }
local NOT_EQUIPPED = { r = 1.00, g = 0.55, b = 0.10, text = "NOT EQUIPPED" }

-- the tooltip you hover, and the comparison tooltips Blizzard attaches to it
local GROUPS = {
    { main = "GameTooltip",    shop = { "ShoppingTooltip1", "ShoppingTooltip2" } },
    { main = "ItemRefTooltip", shop = { "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" } },
}

local BAR_HEIGHT = 22
local styled  = {}                -- tooltip -> the look we gave it (EQUIPPED / NOT_EQUIPPED)
local banners = {}                -- tooltip -> our label bar

local function Usable(tooltip)
    return tooltip ~= nil and tooltip.IsShown ~= nil and not (tooltip.IsForbidden and tooltip:IsForbidden())
end

-- Blizzard's own little "Equipped" tab above a comparison tooltip (its CompareHeader). Our bar says the same
-- thing more clearly, so the tab is made invisible while ours is up (alpha only: it is never hooked or hidden).
local function HideBlizzardTab(tooltip, hide)
    local header = tooltip.CompareHeader
    if type(header) == "table" and header.SetAlpha then header:SetAlpha(hide and 0 or 1) end
end

local function SetBorder(tooltip, r, g, b)
    local slice = tooltip.NineSlice
    if slice and slice.SetBorderColor then slice:SetBorderColor(r, g, b, 1) end
end

---------------------------------------------------------------------------
-- The label bar
---------------------------------------------------------------------------
local function Place(bar, tooltip)
    -- under the tooltip; above it instead when the tooltip is so low the bar would run off the screen
    local bottom = tooltip:GetBottom()
    local above = bottom ~= nil and bottom < (BAR_HEIGHT + 4)
    if bar.above == above then return end
    bar.above = above
    bar:ClearAllPoints()
    if above then
        bar:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, -1)
        bar:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", 0, -1)
    else
        bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, 1)
        bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", 0, 1)
    end
end

local function Banner(tooltip)
    local bar = banners[tooltip]
    if bar then return bar end
    bar = CreateFrame("Frame", nil, tooltip)          -- a child, so it hides with the tooltip by itself
    bar:SetHeight(BAR_HEIGHT)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.text:SetPoint("CENTER", 0, 0)
    bar.text:SetTextColor(0.04, 0.04, 0.04, 1)        -- dark text on the bright bar
    banners[tooltip] = bar
    return bar
end

---------------------------------------------------------------------------
-- Give a tooltip a look / take it away again
---------------------------------------------------------------------------
local function Style(tooltip, look)
    HideBlizzardTab(tooltip, true)
    SetBorder(tooltip, look.r, look.g, look.b)        -- every time: the quality border may have been put back meanwhile
    local bar = Banner(tooltip)
    Place(bar, tooltip)
    if styled[tooltip] ~= look then
        bar.bg:SetColorTexture(look.r, look.g, look.b, 0.95)
        bar.text:SetText(look.text)
        styled[tooltip] = look
    end
    bar:Show()
end

-- the hovered tooltip's own quality border (green / blue / purple ...) is brought back, as TooltipExtras does
local function RestoreItemBorder(tooltip)
    SetBorder(tooltip, 1, 1, 1)
    local ex = ns.TTExtras
    if not (ex and ex.TintForItem and _G.TooltipUtil and TooltipUtil.GetDisplayedItem) then return end
    local _, link, id = TooltipUtil.GetDisplayedItem(tooltip)
    if issecret(link) or issecret(id) then return end
    if type(id) ~= "number" and type(link) == "string" and _G.C_Item and C_Item.GetItemInfoInstant then
        id = C_Item.GetItemInfoInstant(link)
    end
    if type(id) == "number" then ex.TintForItem(tooltip, id) end
end

local function Unstyle(tooltip, isMain)
    styled[tooltip] = nil
    HideBlizzardTab(tooltip, false)
    local bar = banners[tooltip]
    if bar then bar:Hide() end
    if isMain then RestoreItemBorder(tooltip) else SetBorder(tooltip, 1, 1, 1) end
end

local function UnstyleAll()
    for _, g in ipairs(GROUPS) do
        local main = _G[g.main]
        if styled[main] and Usable(main) then Unstyle(main, true) end
        for _, name in ipairs(g.shop) do
            local s = _G[name]
            if styled[s] and Usable(s) then Unstyle(s, false) end
        end
    end
end

---------------------------------------------------------------------------
-- Which tooltip is which
---------------------------------------------------------------------------
local function Refresh(g)
    local main = _G[g.main]
    if not Usable(main) then return end

    local shops = {}
    for _, name in ipairs(g.shop) do
        local s = _G[name]
        if Usable(s) and s:IsShown() then shops[#shops + 1] = s end
    end

    if main:IsShown() and #shops > 0 then
        Style(main, NOT_EQUIPPED)                     -- you are hovering this one ...
        for _, s in ipairs(shops) do Style(s, EQUIPPED) end   -- ... and these are what you are wearing
    else
        if styled[main] then Unstyle(main, true) end
        for _, name in ipairs(g.shop) do
            local s = _G[name]
            if styled[s] and Usable(s) then Unstyle(s, false) end
        end
    end
end

local acc = 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.05 then return end
    acc = 0
    if not ns.TTOption("ttCompare") then
        if next(styled) ~= nil then pcall(UnstyleAll) end
        return
    end
    -- nothing to do (and nothing to pay) while no tooltip is up
    local anyUp = false
    for _, g in ipairs(GROUPS) do
        local main = _G[g.main]
        if main and (main:IsShown() or styled[main]) then anyUp = true break end
    end
    if not anyUp then return end
    for _, g in ipairs(GROUPS) do
        local ok, err = pcall(Refresh, g)
        if not ok and not ns.ttCompareErrored then
            ns.ttCompareErrored = true
            ns.Print("comparison labels error (please report): " .. tostring(err))
        end
    end
end)

-- Also right when Blizzard (re)builds an item tooltip, so the colours do not flash back for a moment
-- (TooltipExtras puts the quality border on the hovered tooltip at this point).
local function OnItem(tooltip)
    if not ns.TTOption("ttCompare") or not Usable(tooltip) then return end
    for _, g in ipairs(GROUPS) do
        for _, name in ipairs(g.shop) do
            if tooltip == _G[name] then Style(tooltip, EQUIPPED) return end
        end
        if tooltip == _G[g.main] then
            for _, name in ipairs(g.shop) do
                local s = _G[name]
                if Usable(s) and s:IsShown() then Style(tooltip, NOT_EQUIPPED) return end
            end
        end
    end
end

if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall and _G.Enum and _G.Enum.TooltipDataType then
    local item = _G.Enum.TooltipDataType.Item
    if item ~= nil then
        _G.TooltipDataProcessor.AddTooltipPostCall(item, function(tooltip)
            local ok, err = pcall(OnItem, tooltip)
            if not ok and not ns.ttCompareErrored then
                ns.ttCompareErrored = true
                ns.Print("comparison labels error (please report): " .. tostring(err))
            end
        end)
    end
end

end)
