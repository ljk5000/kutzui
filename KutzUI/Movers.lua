---------------------------------------------------------------------------
-- KutzUI / Movers
--
-- 1. Bags: press B, drag the bag by any empty part of it (title area, edges),
--    close it, press B again -> it opens where you left it. Remembered across
--    logins.
--
-- 2. Tooltips: up to three locations you drag into place, and for each kind of
--    thing you point at (a player, an NPC, a bag item, an action button, a
--    party or raid member ...) a choice of Blizzard's spot, the cursor or a
--    location. The tooltip grows toward the middle of the screen so it never
--    runs off-screen. See the section below.
--
-- No hooks on Blizzard bag frames: a hook runs inside Blizzard's own call and
-- taints it. Positions are kept by a small per-frame poller instead.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("movers", function()

local issecret = issecretvalue or function() return false end
local DB

-- Which Blizzard bag frames can be dragged. "CombinedBags" is the single
-- all-in-one bag; ContainerFrame1 is the backpack in separate-bag mode.
local BAG_FRAMES = { "ContainerFrameCombinedBags", "ContainerFrame1" }

local MOVER_W, MOVER_H = 220, 70

---------------------------------------------------------------------------
-- Bags
---------------------------------------------------------------------------
local function AtSavedPosition(frame, p)
    if frame:GetNumPoints() ~= 1 then return false end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    return point == "BOTTOMLEFT" and rel == UIParent and relPoint == "BOTTOMLEFT"
        and x and y and math.abs(x - p.x) < 0.5 and math.abs(y - p.y) < 0.5
end

local function ApplyBag(frame)
    local p = DB and DB.bags[frame:GetName()]
    if not p then return end
    if InCombatLockdown() and frame:IsProtected() then return end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
end

local function SetupBag(frame)
    if frame.kutzSetup then return end
    frame.kutzSetup = true

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local function start()
        frame.kutzDragging = true
        frame:StartMoving()
    end
    local function stop()
        frame:StopMovingOrSizing()
        frame.kutzDragging = false
        local x, y = frame:GetLeft(), frame:GetBottom()
        if x and y then
            DB.bags[frame:GetName()] = { x = x, y = y }
            ApplyBag(frame)
        end
    end

    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnDragStart", start)
    frame:HookScript("OnDragStop", stop)

    -- the title strip often swallows the mouse, so let it start the drag too
    local tc = frame.TitleContainer
    if tc and tc.RegisterForDrag then
        tc:EnableMouse(true)
        tc:RegisterForDrag("LeftButton")
        tc:HookScript("OnDragStart", start)
        tc:HookScript("OnDragStop", stop)
    end
end

-- Blizzard anchors a bag when it opens (and again on some layout changes).
-- Instead of hooking Blizzard's anchoring code, check every frame that a shown
-- bag is where you left it, and put it back if not. Runs before the frame is
-- drawn, so you don't see it jump.
local bagWatch = CreateFrame("Frame")
bagWatch:SetScript("OnUpdate", function()
    if not DB then return end
    for _, name in ipairs(BAG_FRAMES) do
        local f = _G[name]
        local p = DB.bags[name]
        if f and p and f.kutzSetup and not f.kutzDragging and f:IsShown() and not AtSavedPosition(f, p) then
            ApplyBag(f)
        end
    end
end)

local function SetupBags()
    for _, name in ipairs(BAG_FRAMES) do
        local f = _G[name]
        if f then SetupBag(f) end
    end
end

---------------------------------------------------------------------------
-- Tooltip placement: WHERE a tooltip goes depends on WHAT you are pointing at.
--
--   * up to three LOCATIONS you make by dragging blue boxes (menu: Tooltip placement);
--   * for each kind of thing you can point at, one of: Blizzard's usual spot, on the cursor, or one of
--     the locations.
--
-- What the tooltip belongs to is worked out from the frame it is attached to (its "owner"): an action
-- button, a bag slot, a party or raid frame, a buff, or - for the world - the mouse-over unit. The
-- tooltip's CONTENT is never touched, only where it sits. A slow-and-cheap per-frame check keeps it
-- there while it is shown (Blizzard re-attaches some tooltips to their button a few frames after they
-- appear). The one hook is the same sanctioned post-hook as before, on the call Blizzard makes when it
-- builds a default tooltip, so those never flash in the wrong place.
---------------------------------------------------------------------------
ns.TT_SCENARIOS = {
    { key = "player",    name = "A player in the world" },
    { key = "npc",       name = "An NPC or creature in the world" },
    { key = "object",    name = "An object in the world" },
    { key = "item",      name = "Items (bags, bank, character, vendor, loot)" },
    { key = "actionbar", name = "Action bar buttons" },
    { key = "party",     name = "Party members" },
    { key = "raid",      name = "Raid members" },
    { key = "myframes",  name = "Your own frames (player, target, focus, pet)" },
    { key = "aura",      name = "Buffs and debuffs" },
    { key = "other",     name = "Everything else" },
}

local LOCATIONS = 3
ns.TT_PLACES = {
    { key = "default", name = "Blizzard's usual spot" },
    { key = "cursor",  name = "On the cursor" },
    { key = "loc1",    name = "Location 1" },
    { key = "loc2",    name = "Location 2" },
    { key = "loc3",    name = "Location 3" },
}

local mover = {}                 -- the draggable boxes, by location number
local idle = 0

-- where each location sits until you drag it: bottom right, top left, top middle
local function DefaultLocation(i)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if i == 1 then return sw - MOVER_W - 60, 160 end
    if i == 2 then return 60, sh - MOVER_H - 160 end
    return sw / 2 - MOVER_W / 2, sh - MOVER_H - 100
end

local function LocationPos(i)
    local p = DB and DB.ttLoc and DB.ttLoc[i]
    if p and p.x and p.y then return p.x, p.y end
    return DefaultLocation(i)
end

-- corner of the tooltip + where on screen it goes: the tooltip's corner is attached to the matching
-- corner of the box, so it grows toward the middle of the screen
function ns.TTAnchorFor(i)
    local px, py = LocationPos(i)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local onLeft = (px + MOVER_W / 2) < sw / 2
    local onTop  = (py + MOVER_H / 2) > sh / 2
    local point = (onTop and "TOP" or "BOTTOM") .. (onLeft and "LEFT" or "RIGHT")
    local x = onLeft and px or (px + MOVER_W)
    local y = onTop  and (py + MOVER_H) or py
    return point, x, y
end

function ns.TTWhere(scenario)
    local w = DB and DB.ttWhere and DB.ttWhere[scenario]
    return w or "default"
end

function ns.SetTTWhere(scenario, where)
    if not DB then return end
    DB.ttWhere = DB.ttWhere or {}
    DB.ttWhere[scenario] = (where ~= "default") and where or nil
end

local function OwnerUsable(owner)
    if type(owner) ~= "table" then return false end
    if owner.IsForbidden and owner:IsForbidden() then return false end
    return true
end

-- Put the tooltip in place - but only write when it isn't already there. (Blizzard can re-anchor a
-- tooltip a few frames after it appears without clearing points first, which would stretch it between
-- two corners; and the anchor it reports can be a SECRET value, which must never be compared.)
-- x, y are in screen pixels; the tooltip's own size setting is divided out.
local function EnforceAt(tt, point, x, y)
    local s = tt:GetScale() or 1
    local ex, ey = x / s, y / s
    local ok, pt, rel, relPt, ox, oy = pcall(tt.GetPoint, tt, 1)
    if ok and not (issecret(pt) or issecret(rel) or issecret(relPt) or issecret(ox) or issecret(oy))
        and tt:GetNumPoints() == 1 and pt == point and rel == UIParent and relPt == "BOTTOMLEFT"
        and ox and oy and math.abs(ox - ex) < 0.5 and math.abs(oy - ey) < 0.5 then
        return
    end
    tt:ClearAllPoints()
    tt:SetPoint(point, UIParent, "BOTTOMLEFT", ex, ey)
end

-- next to the cursor, on the side with room
local function FollowCursor(tt)
    local cx, cy = GetCursorPosition()
    if not cx or not cy then return end
    local us = UIParent:GetEffectiveScale() or 1
    cx, cy = cx / us, cy / us
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local right, top = cx > sw * 0.6, cy > sh * 0.6
    local point = (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
    EnforceAt(tt, point, cx + (right and -18 or 18), cy + (top and -18 or 18))
end

local function ApplyWhere(tt, where)
    if where == "cursor" then
        FollowCursor(tt)
    elseif where == "loc1" or where == "loc2" or where == "loc3" then
        local point, x, y = ns.TTAnchorFor(tonumber(where:sub(4)))
        EnforceAt(tt, point, x, y)
    end                                         -- "default": Blizzard's spot, left alone
end

---------------------------------------------------------------------------
-- What is the tooltip about?
---------------------------------------------------------------------------
local function NameOf(frame)
    if not frame.GetName then return nil end
    local ok, n = pcall(frame.GetName, frame)
    return (ok and type(n) == "string") and n or nil
end

local function UnitOf(frame)
    local u = frame.unit
    if type(u) ~= "string" and frame.GetAttribute then
        local ok, a = pcall(frame.GetAttribute, frame, "unit")
        u = ok and a or nil
    end
    return type(u) == "string" and u or nil
end

local function ParentOf(frame)
    if not frame.GetParent then return nil end
    local ok, p = pcall(frame.GetParent, frame)
    return ok and p or nil
end

local ACTION_NAMES = { "^ActionButton%d+$", "^MultiBar%w*Button%d+$", "^StanceButton%d+$", "^PetActionButton%d+$",
    "^OverrideActionBarButton%d+$", "^PossessButton%d+$", "^ExtraActionButton%d+$", "^ZoneAbilityFrame" }
local ITEM_NAMES = { "^ContainerFrame", "^BankFrame", "^ReagentBank", "^AccountBank", "^Character%a*Slot$", "^Inspect%a*Slot$",
    "^MerchantItem", "^LootButton", "^PaperDoll", "^BuybackItem", "^TradeRecipientItem", "^TradePlayerItem", "^MailItem",
    "^SendMailAttachment", "^OpenMailAttachment", "^GuildBank" }
local AURA_NAMES = { "^BuffButton", "^DebuffButton", "^TempEnchant", "^Aura" }

local function NameMatches(name, patterns)
    if not name then return false end
    for _, p in ipairs(patterns) do
        if name:find(p) then return true end
    end
    return false
end

-- the kind of unit a unit token names, for frames: party / raid / myframes, or nil
local function FrameUnitKind(u)
    if u:find("^party") then return "party" end
    if u:find("^raid") then return "raid" end
    if u == "player" or u == "pet" or u == "vehicle" or u:find("^target") or u:find("^focus") or u:find("^boss") or u:find("^arena") then
        return "myframes"
    end
    return nil
end

local function WorldUnitKind(unit)
    if not UnitExists(unit) then return nil end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if ok and not issecret(isPlayer) and isPlayer then return "player" end
    return "npc"
end

-- owner = the frame the tooltip is attached to (UIParent for the world's default tooltips)
function ns.TTClassify(owner)
    if type(owner) ~= "table" then return "other" end
    local name = NameOf(owner)

    if type(owner.auraInstanceID) == "number" or NameMatches(name, AURA_NAMES) then return "aura" end
    if NameMatches(name, ACTION_NAMES) or (owner.action ~= nil and type(owner.action) == "number") then return "actionbar" end
    if NameMatches(name, ITEM_NAMES) or type(owner.GetBagID) == "function" or type(owner.GetSlotAndBagID) == "function" then return "item" end

    -- unit frames: the frame itself, or a frame a few levels up (a name text, a portrait ...)
    local frame, depth = owner, 0
    while frame and depth < 4 do
        local u = UnitOf(frame)
        if u then
            local kind = FrameUnitKind(u)
            if kind then return kind end
            if u:find("^nameplate") then return WorldUnitKind(u) or "other" end
        end
        local fname = NameOf(frame)
        if fname and (fname:find("^PartyMemberFrame") or fname:find("^CompactPartyFrame")) then return "party" end
        if fname and fname:find("^CompactRaidFrame") then return "raid" end
        frame = ParentOf(frame)
        depth = depth + 1
    end

    if owner == UIParent then                   -- the world: a default-anchored tooltip
        return WorldUnitKind("mouseover") or "object"
    end
    return "other"
end

---------------------------------------------------------------------------
-- The blue boxes you drag
---------------------------------------------------------------------------
local COLORS = { { 0.10, 0.30, 0.80 }, { 0.65, 0.30, 0.10 }, { 0.15, 0.55, 0.30 } }

local function PositionMover(i)
    local x, y = LocationPos(i)
    mover[i]:ClearAllPoints()
    mover[i]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function HideMovers()
    for i = 1, LOCATIONS do if mover[i] then mover[i]:Hide() end end
end

local function CreateMover(i)
    local m = CreateFrame("Frame", "KutzTooltipMover" .. i, UIParent)
    m:SetSize(MOVER_W, MOVER_H)
    m:SetFrameStrata("DIALOG")
    m:SetClampedToScreen(true)
    m:SetMovable(true)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")

    local bg = m:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local c = COLORS[i]
    bg:SetColorTexture(c[1], c[2], c[3], 0.85)

    local text = m:CreateFontString(nil, "OVERLAY")
    ns.StyleText(text, 12)
    text:SetPoint("CENTER")
    text:SetText("Tooltip location " .. i .. "\nDrag me. Right-click when done.")

    m:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            HideMovers()
            ns.Print("Tooltip locations saved.")
        end
    end)
    m:SetScript("OnDragStart", function(self) self:StartMoving() end)
    m:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetLeft(), self:GetBottom()
        if x and y then
            DB.ttLoc = DB.ttLoc or {}
            DB.ttLoc[i] = { x = x, y = y }
        end
    end)
    m:Hide()
    mover[i] = m
end

local function ToggleMover()
    if mover[1] and mover[1]:IsShown() then
        HideMovers()
        ns.Print("Tooltip locations saved.")
        return
    end
    for i = 1, LOCATIONS do
        if not mover[i] then CreateMover(i) end
        PositionMover(i)
        mover[i]:Show()
    end
    ns.Print("Drag each box where you want it, then right-click one (or press the button again). Then pick, for each kind of tooltip, which location it uses.")
end

-- used by the menu's buttons and /kutz move
ns.ToggleTooltipMover = ToggleMover

function ns.ResetTooltip()
    DB.ttLoc, DB.ttWhere = nil, nil
    DB.tooltip, DB.tooltipCursor = nil, nil
    for i = 1, LOCATIONS do if mover[i] then PositionMover(i) end end
    ns.Print("Tooltips back to Blizzard's default spot; the three locations are back where they started.")
end

-- Older versions had one box and one "follow the cursor" switch, for the tooltips Blizzard places
-- itself (the world). Turn that into the new settings once, so nothing jumps.
function ns.TTMigrate()
    if not DB then return end
    if DB.tooltip and not DB.ttLoc then DB.ttLoc = { [1] = DB.tooltip } end
    if not DB.ttWhere and (DB.tooltipCursor or DB.tooltip) then
        local where = DB.tooltipCursor and "cursor" or "loc1"
        DB.ttWhere = { player = where, npc = where, object = where, other = where }
    end
    DB.tooltip, DB.tooltipCursor = nil, nil
end

---------------------------------------------------------------------------
-- Keeping tooltips where they belong
---------------------------------------------------------------------------
local lastOwner, lastWhere = nil, "default"

-- Blizzard calls this whenever it builds a default-anchored tooltip (units, objects in the world).
if GameTooltip_SetDefaultAnchor then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
        if tt ~= GameTooltip or tt:IsForbidden() or not DB then return end
        if not OwnerUsable(parent) then return end   -- a forbidden owner (e.g. a nameplate aura button) can't be anchored to
        local where = ns.TTWhere(ns.TTClassify(parent))
        if where ~= "default" then ApplyWhere(tt, where) end
    end)
end

-- Every frame while a tooltip is shown: classify it (when its owner changes, and again every 0.1 s
-- for the world, where the mouse-over unit can change under the same owner) and keep it in place.
local tipWatch = CreateFrame("Frame")
tipWatch:SetScript("OnUpdate", function(_, elapsed)
    if not DB then return end
    local tt = GameTooltip
    if tt:IsForbidden() or not tt:IsShown() then lastOwner = nil; idle = 0; return end
    local ok, owner = pcall(tt.GetOwner, tt)
    if not ok or not OwnerUsable(owner) then return end
    idle = idle + elapsed
    if owner ~= lastOwner or idle > 0.1 then
        lastOwner, idle = owner, 0
        lastWhere = ns.TTWhere(ns.TTClassify(owner))
    end
    if lastWhere ~= "default" then ApplyWhere(tt, lastWhere) end
end)

---------------------------------------------------------------------------
-- Setup + slash commands (called from CombatLog.lua's /kutz handler)
---------------------------------------------------------------------------
KutzUIDB = KutzUIDB or {}
KutzUIDB.bags = KutzUIDB.bags or {}
DB = KutzUIDB       -- the module only starts once the saved settings have loaded
ns.TTMigrate()

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    SetupBags()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

ns.RegisterSlash("move", function(arg)
    if arg == "reset" then ns.ResetTooltip() else ToggleMover() end
end)
ns.ResetBags = function()
    wipe(DB.bags)
    ns.Print("Bag position reset. Close and reopen your bag (or /reload) to see it.")
end
ns.RegisterSlash("bags", function(arg)
    if arg == "reset" then
        ns.ResetBags()
    else
        ns.Print("Press B, then drag the bag by an empty part of it. '/kutz bags reset' puts it back.")
    end
end)

function ns.DebugMovers()
    for _, name in ipairs(BAG_FRAMES) do
        local f = _G[name]
        local saved = DB and DB.bags[name]
        ns.Print(string.format("%-28s exists=%s saved=%s", name, tostring(f ~= nil),
            saved and string.format("%.0f,%.0f", saved.x, saved.y) or "no"))
    end
    ns.Print("GameTooltip_SetDefaultAnchor=" .. tostring(GameTooltip_SetDefaultAnchor ~= nil)
        .. " GameTooltipDefaultContainer=" .. tostring(_G.GameTooltipDefaultContainer ~= nil)
        .. " tooltip rules: " .. (function()
            local parts = {}
            for _, sc in ipairs(ns.TT_SCENARIOS) do parts[#parts + 1] = sc.key .. "=" .. ns.TTWhere(sc.key) end
            return table.concat(parts, " ")
        end)()
        .. " | last tooltip: owner=" .. tostring(lastOwner and NameOf(lastOwner) or "-") .. " -> " .. lastWhere)
end

ns.RegisterDebug(ns.DebugMovers)

end)
