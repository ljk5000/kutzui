---------------------------------------------------------------------------
-- KutzUI / Names
--
-- Menu options to hide first and/or last names on the unit frames
-- (Player, Target, Target-of-Target).
--
--   "Arthas Menethil"      hide first -> "Menethil"      hide last -> "Arthas"
--   "Lord Marrowgar Jr"    hide first -> "Marrowgar Jr"  hide last -> "Lord Marrowgar"
--   single-word names ("Thrall") are never changed.
--   hide both -> whatever is left in the middle (nothing for 2-word names).
--
-- Settings: KutzUIDB.hideFirst / KutzUIDB.hideLast (set from the /kutz menu).
--
-- The same poller also keeps your chosen font on Blizzard's level numbers
-- (the number in the circle on the player and target frames).
--
-- Blizzard's labels are NOT hooked. Hooking a Blizzard function or
-- FontString runs our code inside Blizzard's own call and taints it. Instead a
-- small poller (outside Blizzard's code) notices when Blizzard wrote a new
-- name and rewrites it.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("frames", function()

local issecret = issecretvalue or function() return false end

function ns.FormatName(name)
    local db = KutzUIDB
    if not db or type(name) ~= "string" or issecret(name) then return name end
    local hideFirst, hideLast = db.hideFirst, db.hideLast
    if not (hideFirst or hideLast) then return name end

    local words = {}
    for w in name:gmatch("%S+") do words[#words + 1] = w end
    if #words < 2 then return name end

    local first = hideFirst and 2 or 1
    local last  = hideLast and (#words - 1) or #words
    if first > last then return "" end
    return table.concat(words, " ", first, last)
end

---------------------------------------------------------------------------
-- Blizzard's own labels. Where they live differs between client versions, so
-- several places are tried.
---------------------------------------------------------------------------
local NAME_SOURCES = {
    player = {
        { "PlayerFrame", "name" },
        { "PlayerName" },
        { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "Name" },
    },
    target = {
        { "TargetFrame", "name" },
        { "TargetFrameTextureFrameName" },
        { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "Name" },
    },
}

local LEVEL_SOURCES = {
    player = {
        { "PlayerLevelText" },
        { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "LevelText" },
    },
    target = {
        { "TargetFrame", "TargetFrameContent", "TargetFrameContentMain", "LevelText" },
        { "TargetFrameTextureFrameLevelText" },
    },
}

local function Dig(root, ...)
    for i = 1, select("#", ...) do
        if type(root) ~= "table" then return nil end
        root = root[select(i, ...)]
    end
    return root
end

local function FindLabel(paths)
    for _, p in ipairs(paths) do
        local o = Dig(_G, unpack(p))
        if type(o) == "table" and o.GetObjectType and o:GetObjectType() == "FontString" then
            return o
        end
    end
end

-- unit -> { fs = FontString, orig = what Blizzard last wrote, applied = what we show }
local labels = {}
-- unit -> { fs = FontString }   (font only)
local levels = {}

-- Called by the menu whenever an option changes: redo every label from the
-- text Blizzard last gave it.
function ns.RefreshNames()
    for _, st in pairs(labels) do
        if st.orig ~= nil then
            local new = ns.FormatName(st.orig)
            st.applied = new
            st.fs:SetText(new)
        end
    end
end

local function Tick()
    for _, st in pairs(labels) do
        -- keep the chosen font, plus a little extra size, on Blizzard's name label
        ns.ForceFont(st.fs, st, ns.NameBonus())
        local cur = st.fs:GetText()
        if type(cur) == "string" and not issecret(cur) and cur ~= st.applied then
            -- Blizzard wrote a new name since we last looked
            st.orig = cur
            local new = ns.FormatName(cur)
            st.applied = new
            if new ~= cur then st.fs:SetText(new) end
        end
    end
    for _, st in pairs(levels) do
        ns.ForceFont(st.fs, st, 0)      -- same size as Blizzard's, our font
    end
end

local acc, tries = 0, 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    self:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.05 then return end
        acc = 0

        -- labels can appear a moment after login: keep looking for a while
        if tries < 300 then
            tries = tries + 1
            for unit, paths in pairs(NAME_SOURCES) do
                if not labels[unit] then
                    local fs = FindLabel(paths)
                    if fs then labels[unit] = { fs = fs } end
                end
            end
            for unit, paths in pairs(LEVEL_SOURCES) do
                if not levels[unit] then
                    local fs = FindLabel(paths)
                    if fs then levels[unit] = { fs = fs } end
                end
            end
        end
        Tick()
    end)
end)

function ns.DebugNames()
    for unit, paths in pairs(NAME_SOURCES) do
        local st = labels[unit]
        local fs = st and st.fs or FindLabel(paths)
        ns.Print(string.format("%-6s name label: %s   tracking=%s", unit,
            fs and (fs:GetName() or "found (unnamed)") or "NOT FOUND", tostring(st ~= nil)))
    end
    for unit, paths in pairs(LEVEL_SOURCES) do
        local st = levels[unit]
        local fs = st and st.fs or FindLabel(paths)
        ns.Print(string.format("%-6s level text: %s   tracking=%s", unit,
            fs and (fs:GetName() or "found (unnamed)") or "NOT FOUND", tostring(st ~= nil)))
    end
end

ns.RegisterDebug(ns.DebugNames)

end)
