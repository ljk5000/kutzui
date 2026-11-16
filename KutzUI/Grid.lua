---------------------------------------------------------------------------
-- KutzUI / Grid
--
-- A faint alignment grid over the whole screen, for lining frames up.
-- Toggle it with the "Toggle grid" button in the /kutz menu or "/kutz grid".
--
--   * thin white lines every GRID px (units of the game's UI scale)
--   * every 4th line a bit brighter
--   * the screen's centre lines in red - handy for mirroring Player/Target
--
-- It sits behind all of the game's windows, never takes mouse clicks, and is
-- off every time you log in.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local GRID = 32

local grid
local lines = {}

local function Line(parent, vertical, offset, r, g, b, a)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(r, g, b, a)
    if vertical then
        t:SetWidth(1)
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", offset, 0)
        t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", offset, 0)
    else
        t:SetHeight(1)
        t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, offset)
        t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, offset)
    end
    lines[#lines + 1] = t
end

local function Build()
    for i = #lines, 1, -1 do lines[i]:Hide(); lines[i] = nil end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local cx, cy = w / 2, h / 2

    -- centre lines
    Line(grid, true,  cx, 1, 0.25, 0.25, 0.7)
    Line(grid, false, cy, 1, 0.25, 0.25, 0.7)

    -- outwards from the centre so the centre is always on a line
    local k = 1
    while cx + k * GRID < w or cy + k * GRID < h do
        local strong = (k % 4 == 0)
        local a = strong and 0.28 or 0.12
        if cx + k * GRID < w then
            Line(grid, true, cx + k * GRID, 1, 1, 1, a)
            Line(grid, true, cx - k * GRID, 1, 1, 1, a)
        end
        if cy + k * GRID < h then
            Line(grid, false, cy + k * GRID, 1, 1, 1, a)
            Line(grid, false, cy - k * GRID, 1, 1, 1, a)
        end
        k = k + 1
    end
end

local function Create()
    grid = CreateFrame("Frame", "KutzGrid", UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid:EnableMouse(false)
    grid:Hide()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
    ev:RegisterEvent("UI_SCALE_CHANGED")
    ev:SetScript("OnEvent", function()
        if grid:IsShown() then Build() end    -- screen size changed: redraw
    end)
end

function ns.ToggleGrid()
    if not grid then Create() end
    if grid:IsShown() then
        grid:Hide()
        ns.Print("Grid off.")
    else
        Build()
        grid:Show()
        ns.Print("Grid on (red = screen centre). Toggle it again to hide it.")
    end
end

function ns.GridShown()
    return grid and grid:IsShown() or false
end

-- "/kutz grid"
ns.RegisterSlash("grid", function() ns.ToggleGrid() end)
