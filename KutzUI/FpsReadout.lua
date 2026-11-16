---------------------------------------------------------------------------
-- KutzUI / FpsReadout        (module "fpsreadout")
--
-- One tiny line of text with your frame rate and latency, e.g.  144 fps   38 ms   (menu: FPS readout).
-- No background, no buttons, not clickable; your chosen font. The latency shown is the "world"
-- one, the delay that matters while you play.
--
-- Where: by default in the top-LEFT corner of the screen. Or top-centre, or at the top right just
-- left of the minimap (the top-right corner itself holds the clock and the minimap's zone bar, so
-- the text can't sit there; it follows the minimap if you move it in Edit Mode). X / Y offsets (in
-- pixels) move it anywhere else.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("fpsreadout", function()

local DEFAULTS = {
    fpsShow  = true,
    fpsPlace = "topleft",
    fpsX     = 0,
    fpsY     = 0,
    fpsSize  = 11,
    fpsAlpha = 70,          -- percent
}

ns.FPS_PLACES = {
    { key = "topleft", name = "Top left corner" },
    { key = "top",     name = "Top centre" },
    { key = "minimap", name = "Top right, left of the minimap" },
}

function ns.FpsOption(name)
    local v = KutzUIDB and KutzUIDB[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

local dirty = true

function ns.SetFpsOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
    dirty = true
end

function ns.ResetFpsSettings()
    if not KutzUIDB then return end
    for name in pairs(DEFAULTS) do KutzUIDB[name] = nil end
    dirty = true
end

local frame = CreateFrame("Frame", "KutzFpsReadout", UIParent)
frame:SetSize(150, 14)
frame:SetFrameStrata("MEDIUM")
frame:EnableMouse(false)
frame.text = frame:CreateFontString(nil, "OVERLAY")
frame.text:SetAllPoints(frame)
frame.size, frame.placeKey = 0, ""

local function Place()
    local place, x, y = ns.FpsOption("fpsPlace"), ns.FpsOption("fpsX"), ns.FpsOption("fpsY")
    local cluster = (place == "minimap") and _G.MinimapCluster or nil
    local key = place .. "|" .. x .. "|" .. y .. "|" .. tostring(cluster)
    if frame.placeKey == key then return end
    frame.placeKey = key
    frame:ClearAllPoints()
    if place == "topleft" then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 6 + x, -6 + y)
        frame.text:SetJustifyH("LEFT")
    elseif place == "top" then
        frame:SetPoint("TOP", UIParent, "TOP", x, -6 + y)
        frame.text:SetJustifyH("CENTER")
    else
        if cluster then
            frame:SetPoint("TOPRIGHT", cluster, "TOPLEFT", -4 + x, -8 + y)
        else
            frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -264 + x, -8 + y)
        end
        frame.text:SetJustifyH("RIGHT")
    end
end

local function Update()
    local show = ns.FpsOption("fpsShow")
    frame:SetShown(show)
    if not show then return end
    if dirty then
        dirty = false
        Place()
        local size = ns.FpsOption("fpsSize")
        if frame.size ~= size then
            frame.size = size
            ns.StyleText(frame.text, size)
        end
        frame:SetAlpha(ns.FpsOption("fpsAlpha") / 100)
        frame.text:SetTextColor(0.85, 0.87, 0.92)
    end
    Place()                                   -- cheap; also notices the minimap appearing late
    local fps = GetFramerate and GetFramerate() or 0
    local _, _, home, world = GetNetStats()
    local ms = (world and world > 0) and world or home or 0
    frame.text:SetText(string.format("%d fps  %d ms", math.floor(fps + 0.5), math.floor(ms + 0.5)))
end

local acc = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 and not dirty then return end
    acc = 0
    local ok, err = pcall(Update)
    if not ok and not ns.fpsErrored then
        ns.fpsErrored = true
        ns.Print("fps readout error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    local fps = GetFramerate and GetFramerate() or 0
    local bi, bo, home, world = GetNetStats()
    ns.Print(string.format("fps readout: shown=%s place=%s | game says %.0f fps, latency home %s ms / world %s ms",
        tostring(ns.FpsOption("fpsShow")), ns.FpsOption("fpsPlace"), fps, tostring(home), tostring(world)))
end)

end)
