---------------------------------------------------------------------------
-- KutzUI / MapCoords        (part of module "minimap")
--
-- Coordinates along the bottom of the WORLD MAP: where you are and where the mouse is on the map,
-- like  Player 45.2, 63.1     Cursor 51.0, 70.3   (menu: Minimap page).
--
-- (The minimap's own "coordinates under the map" are Blizzard's: the switch for them on the
-- Minimap page just turns Blizzard's setting on. This file only adds the world map line.)
--
-- Nothing of Blizzard's is hooked: our own small frame is a child of the world map, so it shows
-- and hides with it, and reads the position through the map APIs. Inside dungeons and raids the
-- game hides your position from addons; the line then shows "--".
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("minimap", function()

local issecret = issecretvalue or function() return false end

function ns.MapCoordsOn()
    local v = KutzUIDB and KutzUIDB.mmMapCoords
    if v == nil then return true end
    return v
end

function ns.SetMapCoords(on)
    if KutzUIDB then KutzUIDB.mmMapCoords = on and true or false end
end

local frame

local function Num(v)
    if type(v) == "number" and not issecret(v) then return v end
    return nil
end

local function PlayerXY(map)
    if not (_G.C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local mapId = Num(map.GetMapID and map:GetMapID())
    if not mapId then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapId, "player")
    if not pos or not pos.GetXY then return nil end
    local x, y = pos:GetXY()
    x, y = Num(x), Num(y)
    if x and y then return x * 100, y * 100 end
    return nil
end

local function CursorXY(map)
    local container = map.ScrollContainer
    if not (container and container.GetNormalizedCursorPosition) then return nil end
    local x, y = container:GetNormalizedCursorPosition()
    x, y = Num(x), Num(y)
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x * 100, y * 100 end
    return nil
end

local function Format(px, py, cx, cy)
    local p = px and string.format("%.1f, %.1f", px, py) or "--"
    local c = cx and string.format("%.1f, %.1f", cx, cy) or "--"
    return "Player " .. p .. "      Cursor " .. c
end
ns.MapCoordsFormat = Format

local sinceUpdate, lastText = 0, nil
local function Update(self, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < 0.05 then return end
    sinceUpdate = 0
    local map = _G.WorldMapFrame
    if not map then return end
    local px, py = PlayerXY(map)
    local cx, cy = CursorXY(map)
    local text = Format(px, py, cx, cy)
    if text ~= lastText then
        lastText = text
        self.text:SetText(text)
    end
end

local function Build()
    local map = _G.WorldMapFrame
    if frame or not (map and map.ScrollContainer) then return end
    frame = CreateFrame("Frame", "KutzMapCoords", map)
    frame:SetSize(330, 18)
    frame:SetPoint("BOTTOM", map.ScrollContainer, "BOTTOM", 0, 6)
    frame:SetFrameLevel(map:GetFrameLevel() + 50)
    frame:EnableMouse(false)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.45)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetAllPoints()
    frame.text:SetJustifyH("CENTER")
    frame.text:SetTextColor(0.92, 0.94, 1)
    ns.StyleText(frame.text, 12)
    frame:SetScript("OnUpdate", Update)
    ns.mapCoordsFrame = frame
end

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    local ok, err = pcall(function()
        Build()
        if frame then frame:SetShown(ns.MapCoordsOn()) end
    end)
    if not ok and not ns.mapCoordsErrored then
        ns.mapCoordsErrored = true
        ns.Print("map coordinates error (please report): " .. tostring(err))
    end
end)

end)
