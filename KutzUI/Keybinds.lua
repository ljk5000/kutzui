---------------------------------------------------------------------------
-- KutzUI / Keybinds
--
-- Short mouse-button names on the action bars:
--     "Mouse Button 4"  ->  "M4"          "Mouse Button 5" -> "M5"
--     "Middle Mouse Button" -> "M3"        "Mouse Wheel Up" -> "MwU"
--     "a-Mouse Button 4" -> "a-M4"  (modifier prefixes are left as Blizzard writes them)
--
-- Without this the text is wider than the button and gets cut off ("Mou...").
--
-- How it works: Blizzard's action buttons write the binding text themselves
-- (ActionBarActionButtonMixin:UpdateHotkeys -> HotKey:SetText(GetBindingText(key, 1))).
-- We do NOT hook that - a hook runs inside Blizzard's own call and taints it.
-- A small poller rewrites the text afterwards instead.
--
-- The same poller keeps the font you chose in the menu on these labels.
-- Turn the shortening off with the menu checkbox (then /reload).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("keybinds", function()

local issecret = issecretvalue or function() return false end

-- Standard button-name patterns. Frames that don't exist are just skipped.
local PREFIXES = {
    { "ActionButton", 12 },
    { "MultiBarBottomLeftButton", 12 },
    { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton", 12 },
    { "MultiBarLeftButton", 12 },
    { "MultiBar5Button", 12 },
    { "MultiBar6Button", 12 },
    { "MultiBar7Button", 12 },
    { "PetActionButton", 10 },
    { "StanceButton", 10 },
    { "ExtraActionButton", 1 },
}

-- built from the client's own localized strings, so it works in any language
local replacements
local function BuildReplacements()
    replacements = {}
    local function add(from, to)
        if type(from) == "string" and from ~= "" then
            replacements[#replacements + 1] = { from:gsub("%p", "%%%0"), to }   -- escape pattern characters
        end
    end
    for n = 31, 1, -1 do add(_G["KEY_BUTTON" .. n], "M" .. n) end   -- longest numbers first
    add(_G.KEY_MOUSEWHEELUP, "MwU")
    add(_G.KEY_MOUSEWHEELDOWN, "MwD")
end

local cache = {}       -- text -> shortened text (the same few strings come back every tick)
local function Shorten(text)
    local hit = cache[text]
    if hit then return hit end
    if not replacements then BuildReplacements() end
    local out = text
    for i = 1, #replacements do
        local r = replacements[i]
        out = out:gsub(r[1], r[2])
    end
    cache[text] = out
    return out
end
ns.ShortenKeyText = Shorten

local labels = {}      -- list of { fs = FontString }
local seen = {}        -- fs -> true
local scans = 0

local function Scan()
    for _, p in ipairs(PREFIXES) do
        for i = 1, p[2] do
            local name = p[1] .. i
            local b = _G[name]
            local fs = b and (b.HotKey or _G[name .. "HotKey"])
            if fs and not seen[fs] and fs.GetText then
                seen[fs] = true
                labels[#labels + 1] = { fs = fs }
            end
        end
    end
end

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    self:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.2 then return end
        acc = 0

        -- bars can finish loading a little after login: look again for a while
        if scans < 40 then
            scans = scans + 1
            Scan()
        end

        local short = not (KutzUIDB and KutzUIDB.shortKeys == false)
        for i = 1, #labels do
            local rec = labels[i]
            local fs = rec.fs
            ns.ForceFont(fs, rec)                       -- chosen font on Blizzard's label
            if short then
                local text = fs:GetText()
                if type(text) == "string" and text ~= "" and not issecret(text) and text ~= rec.done then
                    local new = Shorten(text)
                    if new ~= text then fs:SetText(new) end
                    rec.done = new                        -- unchanged text is not looked at again
                end
            end
        end
    end)
end)

function ns.DebugKeybinds()
    local sample
    for i = 1, #labels do
        local t = labels[i].fs:GetText()
        if type(t) == "string" and t ~= "" and not issecret(t) then sample = (sample and (sample .. " ") or "") .. t end
        if sample and #sample > 60 then break end
    end
    ns.Print(string.format("keybind labels tracked=%d  sample: %s", #labels, sample or "(none)"))
    ns.Print("KEY_BUTTON4=" .. tostring(_G.KEY_BUTTON4) .. "  KEY_BUTTON5=" .. tostring(_G.KEY_BUTTON5)
        .. "  KEY_MOUSEWHEELUP=" .. tostring(_G.KEY_MOUSEWHEELUP))
end

ns.RegisterDebug(ns.DebugKeybinds)

end)
