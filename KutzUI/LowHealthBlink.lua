---------------------------------------------------------------------------
-- KutzUI / LowHealthBlink     (part of module "convenience")
--
-- Blizzard's low-health warning pulses the whole screen red for as long as your health is under
-- 35%. This swaps it for three quick, faint blinks each time your health DROPS under 35%; it blinks
-- again only after your health has been back above 35%.
--
-- Blizzard's pulse is switched off with the game's own setting (the CVar doNotFlashLowHealthWarning,
-- "Flash screen at low health" in the game's options); its old value is remembered and put back
-- when this switch is turned off. Our blink uses Blizzard's own red screen-edge picture, on a frame
-- of ours. Switch: "Blink 3 times at low health" on the Convenience page (cvLowHealth, on by default).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("convenience", function()

local issecret = issecretvalue or function() return false end
local SCALE100 = CurveConstants and CurveConstants.ScaleTo100

local CVAR = "doNotFlashLowHealthWarning"
local LOW = 35              -- percent, the same line Blizzard uses
local BLINKS = 3
local BLINK_TIME = 0.5      -- seconds per blink (fade in + fade out)
local PEAK = 0.35           -- brightest point (Blizzard's pulse goes up to 1.0)

local function On() return ns.CVOption("cvLowHealth") and true or false end

---------------------------------------------------------------------------
-- Blizzard's pulse off while ours is on (and back the way it was when ours is turned off)
---------------------------------------------------------------------------
local function ApplyCVar()
    if not (KutzUIDB and GetCVar and SetCVar) then return end
    local now = GetCVar(CVAR)
    if now == nil then return end                         -- this client has no such setting
    if On() then
        if now ~= "1" then
            if KutzUIDB.lhBlizzWas == nil then KutzUIDB.lhBlizzWas = now end
            pcall(SetCVar, CVAR, "1")
        end
    elseif KutzUIDB.lhBlizzWas ~= nil then
        pcall(SetCVar, CVAR, KutzUIDB.lhBlizzWas)
        KutzUIDB.lhBlizzWas = nil
    end
end
ns.LowHealthApply = ApplyCVar

---------------------------------------------------------------------------
-- The blink
---------------------------------------------------------------------------
local flash = CreateFrame("Frame", "KutzLowHealthBlink", UIParent)
flash:SetAllPoints(UIParent)
flash:SetFrameStrata("FULLSCREEN_DIALOG")
flash:EnableMouse(false)
flash:Hide()
local tex = flash:CreateTexture(nil, "BACKGROUND")
tex:SetAllPoints()
tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
tex:SetBlendMode("ADD")

local t = 0
flash:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    if t >= BLINKS * BLINK_TIME then self:Hide(); return end
    local frac = (t % BLINK_TIME) / BLINK_TIME
    self:SetAlpha(PEAK * math.sin(math.pi * frac))
end)

local blinks = 0
local function Blink()
    t = 0
    flash:SetAlpha(0)
    flash:Show()
    blinks = blinks + 1
end
ns.LowHealthBlink = Blink                    -- for /kutz debug and the offline tests

---------------------------------------------------------------------------
-- Watching your health. A health value the game hides from addons is never compared: then
-- nothing happens until it can be read again.
---------------------------------------------------------------------------
local armed = true                           -- blink at the next drop under 35%

local function Percent()
    local cur, max = UnitHealth("player"), UnitHealthMax("player")
    if not issecret(cur) and not issecret(max) and type(cur) == "number" and type(max) == "number" then
        if max <= 0 then return nil end
        return cur / max * 100
    end
    if UnitHealthPercent and SCALE100 then
        local ok, p = pcall(UnitHealthPercent, "player", false, SCALE100)
        if ok and type(p) == "number" and not issecret(p) then return p end
    end
    return nil
end

local function Check()
    if not On() then return end
    if UnitIsDeadOrGhost("player") then armed = false; return end
    local p = Percent()
    if not p then return end
    if p > LOW then
        armed = true
    elseif armed then
        armed = false
        Blink()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CVAR_UPDATE")
ev:RegisterUnitEvent("UNIT_HEALTH", "player")
ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_ENTERING_WORLD" then ApplyCVar()
    elseif event == "CVAR_UPDATE" then
        -- the game's own checkbox was ticked again: keep ours in charge while our switch is on
        if name == CVAR and On() and GetCVar(CVAR) ~= "1" then KutzUIDB.lhBlizzWas = nil; ns.SetCVOption("cvLowHealth", false) end
        return
    end
    local ok, err = pcall(Check)
    if not ok and not ns.lhErrored then
        ns.lhErrored = true
        ns.Print("low health blink error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    ns.Print(string.format("low health: blink=%s, Blizzard pulse off=%s, armed=%s, blinked %d time(s)",
        tostring(On()), tostring(GetCVar and GetCVar(CVAR)), tostring(armed), blinks))
end)

end)
