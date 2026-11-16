-- Read-only profession batch estimate. No hooks on Blizzard's crafting functions.
local ADDON_NAME, ns = ...
ns.Module("craftingtime", function()
local batch, label, owner
local runner = CreateFrame("Frame")
runner:Hide()
local durations = {}
local function Number(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) == "number" and v >= 0 and v < math.huge then return v end
end
local function Call(object, method)
    if object and type(object[method]) == "function" then
        local ok, value = pcall(object[method], object)
        if ok then return value end
    end
end
local function Page()
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    if page and Call(page, "IsShown") then return page end
end
local function Selected(page)
    local info = Call(page.SchematicForm, "GetRecipeInfo")
    return info and Number(info.recipeID)
end
local function Duration(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    local ms = info and Number(info.castTime)
    if ms and ms > 0 then return ms / 1000 end
    return durations[id]
end
local function Counts(page)
    local maximum = Number(Call(page, "GetCraftableCount")) or 0
    local requested = Number(Call(page.CreateMultipleInputBox, "GetValue")) or 1
    return math.min(math.max(1, math.floor(requested)), maximum), math.floor(maximum)
end
local function Time(seconds)
    if not seconds then return "time unavailable" end
    local s = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
local function Update()
    local page = Page()
    if not page then if label then label:Hide() end; return end
    if owner ~= page then
        if label then label:Hide() end
        owner = page
        runner:SetParent(page)
        -- An extra strip below the window leaves the recipe and native cast bar clear.
        label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", page, "BOTTOMLEFT", 10, -5)
        label:SetPoint("TOPRIGHT", page, "BOTTOMRIGHT", -10, -5)
        label:SetHeight(24)
    end
    label:Show()
    if batch and batch.stopped and GetTime() - batch.stopped > 1 then batch = nil end
    if batch then
        local remaining = batch.left * batch.duration
        if batch.ends then remaining = (batch.left - 1) * batch.duration + math.max(0, batch.ends - GetTime()) end
        label:SetText(string.format("%d / %d crafts remaining - %s left", batch.left, batch.total, Time(remaining)))
    else
        local id = Selected(page)
        if not id then label:SetText(""); return end
        local count, maximum = Counts(page)
        local duration = Duration(id)
        label:SetText(string.format("Create: %d crafts - %s   |   Create All: %d crafts - %s",
            count, Time(duration and count * duration), maximum, Time(duration and maximum * duration)))
    end
end
local events = CreateFrame("Frame")
events:RegisterEvent("TRADE_SKILL_CRAFT_BEGIN")
events:RegisterEvent("TRADE_SKILL_CLOSE")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("ADDON_LOADED")
events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
events:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "TRADE_SKILL_CLOSE" then batch = nil; runner:Hide()
    elseif event == "TRADE_SKILL_SHOW" then runner:Show()
    elseif event == "ADDON_LOADED" then
        if Page() then runner:Show() end
    elseif event == "TRADE_SKILL_CRAFT_BEGIN" then
        local page = Page()
        local id = Number(unit)
        if page and id and not batch then
            local count, maximum = Counts(page)
            if Call(page.CreateAllButton, "IsMouseOver") then count = maximum end
            if count > 0 then
                batch = { id = id, total = count, left = count, duration = Duration(id) or 0 }
            end
        end
    elseif unit == "player" and batch then
        local id = Number(spellID)
        if id == batch.id then
            if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
                batch.stopped = nil
                local _, _, _, startMS, endMS = UnitCastingInfo("player")
                startMS, endMS = Number(startMS), Number(endMS)
                if startMS and endMS and endMS > startMS then
                    batch.duration = (endMS - startMS) / 1000
                    durations[id] = batch.duration
                    batch.ends = endMS / 1000
                end
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                batch.left = batch.left - 1
                batch.ends = nil
                batch.stopped = GetTime()
                if batch.left <= 0 then batch = nil end
            elseif event == "UNIT_SPELLCAST_STOP" then
                batch.stopped = GetTime()
            elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
                batch = nil
            end
        end
    end
    Update()
end)
-- Discovery only while the profession window is open; no Blizzard scripts modified.
local elapsed = 0
runner:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.1 then return end
    elapsed = 0
    Update()
end)
end)
