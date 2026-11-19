-- A hover-only sound switch in the bottom-left corner. Only our button is touched.
local ADDON_NAME, ns = ...
ns.Module("mutebutton", function()
local CVAR = "Sound_EnableAllSound"
local button = CreateFrame("Button", "KutzMuteButton", UIParent)
button:SetSize(32, 32)
button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 8, 8)
button:SetHitRectInsets(-8, -8, -8, -8)
button:SetFrameStrata("HIGH")
button:EnableMouse(true)
local edge = button:CreateTexture(nil, "BACKGROUND")
edge:SetColorTexture(0.25, 0.28, 0.34, 0.9); edge:SetAllPoints()
local background = button:CreateTexture(nil, "BORDER")
background:SetColorTexture(0.045, 0.05, 0.07, 0.96)
background:SetPoint("TOPLEFT", 1, -1); background:SetPoint("BOTTOMRIGHT", -1, 1)
local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetColorTexture(1, 0.82, 0, 0.12); highlight:SetAllPoints()
local icon = ns.CreateIcon(button, "volume-2", 20)
icon:SetPoint("CENTER")
-- Keep the small hit area active so entering it can reveal the otherwise invisible button.
button:SetAlpha(0)

local function SoundOn()
    local ok, value = pcall(GetCVar, CVAR)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil end
    if value == "1" then return true end
    if value == "0" then return false end
end
local hovered, soundOn = false, nil
local function Tooltip()
    GameTooltip:SetOwner(button, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText(soundOn == nil and "Game sound unavailable" or soundOn and "Game sound on" or "Game sound muted")
    if soundOn ~= nil then
        GameTooltip:AddLine(soundOn and "Click to mute WoW sound." or "Click to unmute WoW sound.", 0.75, 0.77, 0.82)
    end
    GameTooltip:Show()
end
local function Update()
    soundOn = SoundOn()
    ns.SetIcon(icon, soundOn == false and "volume-x" or "volume-2")
    if soundOn == nil then icon:SetVertexColor(0.45, 0.47, 0.52)
    elseif soundOn then icon:SetVertexColor(0.86, 0.88, 0.93)
    else icon:SetVertexColor(1, 0.82, 0) end
    if hovered then Tooltip() end
end
button:SetScript("OnEnter", function(self) hovered = true; Update(); self:SetAlpha(1) end)
local function Leave(self) hovered = false; self:SetAlpha(0); GameTooltip:Hide() end
button:SetScript("OnLeave", Leave)
button:SetScript("OnHide", Leave)
button:SetScript("OnClick", function()
    local on = SoundOn()
    if on == nil then ns.Print("game sound setting is unavailable"); return end
    local ok = pcall(SetCVar, CVAR, on and "0" or "1")
    if not ok or SoundOn() ~= not on then ns.Print("could not change the game sound setting") end
    Update()
end)
button:RegisterEvent("CVAR_UPDATE")
button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_ENTERING_WORLD" then Update()
    elseif not (issecretvalue and issecretvalue(name)) and type(name) == "string"
        and string.lower(name) == string.lower(CVAR) then Update() end
end)
Update()
end)
