---------------------------------------------------------------------------
-- KutzUI / ChatTags
--
-- Short, color-coded chat prefixes (pure text in / text out - no game API, so it
-- can be tested outside the game):
--
--   [1. General - Elwynn Forest] [Duke]: hi      ->   [1] [Duke]: hi
--   [2. Trade - City] [Ann]: WTS                 ->   [2] [Ann]: WTS
--   [Party] [Bob]: pull                          ->   [P] [Bob]: pull
--   [Guild] [Gm]: hello                          ->   [G] [Gm]: hello
--   [Raid] / [Raid Leader] / [Instance] ...      ->   [R] / [RL] / [I]
--   [Example Player] says: hello                 ->   [Example Player][S]: hello
--   [Example Player] yells: hello                ->   [Example Player][Y]: hello
--   [Example Player] whispers: hello             ->   [Example Player][W]: hello
--
-- Each tag has its own color (menu -> Chat page). Names stay clickable: only the
-- text inside Blizzard's channel link is replaced, never the link itself.
--
-- Matching is on the channel LINK KEYWORD (|Hchannel:party|h[...]|h), which is the
-- same in every language, and on the game's own "says:" / "yells:" format strings,
-- so it follows your client's language. A line that doesn't match is left as is.
--
-- Why it rewrites finished lines and nothing else: overwriting Blizzard's
-- CHAT_*_GET format strings is known to taint the chat code on this client, and so
-- is replacing a chat frame's AddMessage. Chat.lua calls the chat frame's own
-- TransformMessages (an addon-facing method) on lines that already exist.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("chat", function()

local function DB() return KutzUIDB end

function ns.ChatOption(name)
    local db = DB()
    if db and db[name] ~= nil then return db[name] end
    return true            -- both shortening options default to on
end

-- color keys offered in the menu (defaults chosen so every kind of chat is distinct)
ns.CHAT_COLORS = {
    { key = "general", label = "General (1)",   default = "ffd966" },
    { key = "trade",   label = "Trade (2)",     default = "66d9ef" },
    { key = "channel", label = "Other channels", default = "c0c0c0" },
    { key = "party",   label = "Party",         default = "8ab4ff" },
    { key = "guild",   label = "Guild",         default = "40ff40" },
    { key = "officer", label = "Officer",       default = "7fdc7f" },
    { key = "raid",    label = "Raid",          default = "ff7f00" },
    { key = "instance", label = "Instance",     default = "ff9f40" },
    { key = "say",     label = "Say",           default = "ffffff" },
    { key = "yell",    label = "Yell",          default = "ff4040" },
    { key = "whisper", label = "Whisper",       default = "ff80ff" },
}

local COLOR_DEFAULT = {}
for _, c in ipairs(ns.CHAT_COLORS) do COLOR_DEFAULT[c.key] = c.default end

function ns.ChatColor(key)
    local db = DB()
    return (db and db.chatColors and db.chatColors[key]) or COLOR_DEFAULT[key] or "ffffff"
end

function ns.SetChatColor(key, hex)
    local db = DB()
    if not db then return end
    db.chatColors = db.chatColors or {}
    if hex == COLOR_DEFAULT[key] then hex = nil end
    db.chatColors[key] = hex
end

function ns.ResetChatTagSettings()
    local db = DB()
    if not db then return end
    db.chatShortChannels, db.chatShortSpeech, db.chatColors = nil, nil, nil
end

-- channel link keyword -> { letters, color key }
local KEYWORD = {
    PARTY                 = { "P",  "party" },
    PARTY_LEADER          = { "PL", "party" },
    PARTY_GUIDE           = { "PG", "party" },
    RAID                  = { "R",  "raid" },
    RAID_LEADER           = { "RL", "raid" },
    RAID_WARNING          = { "RW", "raid" },
    GUILD                 = { "G",  "guild" },
    OFFICER               = { "O",  "officer" },
    INSTANCE_CHAT         = { "I",  "instance" },
    INSTANCE_CHAT_LEADER  = { "IL", "instance" },
    BATTLEGROUND          = { "BG", "instance" },
    BATTLEGROUND_LEADER   = { "BGL", "instance" },
}

local function Tag(colorKey, letters)
    return "|cff" .. ns.ChatColor(colorKey) .. "[" .. letters .. "]|r"
end

-- one channel link:  |Hchannel:KEY|h[TEXT]|h   ->   |Hchannel:KEY|h<colored [TAG]>|h
local function ChannelReplacement(key, label)
    local upper = key:upper()
    local spec = KEYWORD[upper]
    if spec then
        local letters = spec[1]
        -- "Raid Leader" shares the RAID keyword; tell it apart by its label
        if (upper == "RAID" or upper == "PARTY" or upper == "INSTANCE_CHAT") and label:lower():find("leader", 1, true) then
            letters = (upper == "RAID" and "RL") or (upper == "PARTY" and "PL") or "IL"
        end
        return "|Hchannel:" .. key .. "|h" .. Tag(spec[2], letters) .. "|h"
    end
    local number = key:match("^channel:(%d+)$") or label:match("^(%d+)%.")
    if number then
        local colorKey = (number == "1" and "general") or (number == "2" and "trade") or "channel"
        return "|Hchannel:" .. key .. "|h" .. Tag(colorKey, number) .. "|h"
    end
    return nil                    -- unknown kind of channel (community ...): leave alone
end

-- " says: " / " yells: " / " whispers: " exactly as THIS client writes them
local SPEECH = {
    { global = "CHAT_SAY_GET",     letters = "S", color = "say" },
    { global = "CHAT_YELL_GET",    letters = "Y", color = "yell" },
    { global = "CHAT_WHISPER_GET", letters = "W", color = "whisper" },
}

local function SpeechSuffix(spec)
    local fmt = _G[spec.global]
    if type(fmt) ~= "string" then return nil end
    local suffix = fmt:gsub("^%%s", "")          -- "%s says: "  ->  " says: "
    if suffix == "" or suffix == fmt then return nil end
    return suffix
end

-- true if this line still has something to shorten (cheap: used on every line)
function ns.ChatLineNeedsWork(text)
    if type(text) ~= "string" then return false end
    if ns.ChatOption("chatShortChannels") and text:find("|Hchannel:[^|]+|h%[") then return true end
    if ns.ChatOption("chatShortSpeech") then
        for _, spec in ipairs(SPEECH) do
            local suffix = SpeechSuffix(spec)
            if suffix and text:find("]|h" .. suffix, 1, true) then return true end
        end
    end
    return false
end

-- returns the shortened line, or the same text if nothing applied
function ns.ShortenChatLine(text)
    if type(text) ~= "string" then return text end
    local out = text

    if ns.ChatOption("chatShortChannels") then
        out = out:gsub("|Hchannel:([^|]+)|h%[(.-)%]|h", ChannelReplacement)
    end

    if ns.ChatOption("chatShortSpeech") then
        for _, spec in ipairs(SPEECH) do
            local suffix = SpeechSuffix(spec)
            if suffix then
                -- the speaker's name link ends in "]|h", then comes " says: "
                local s, e = out:find("]|h" .. suffix, 1, true)
                if s and s < 300 then
                    out = out:sub(1, s + 2) .. Tag(spec.color, spec.letters) .. ": " .. out:sub(e + 1)
                end
            end
        end
    end
    return out
end

-- lines shown in the menu's preview (as Blizzard writes them)
ns.CHAT_SAMPLES = {
    "|Hchannel:channel:1|h[1. General - Elwynn Forest]|h |Hplayer:Duke:1:CHANNEL:1|h[Duke]|h: anyone up for Deadmines?",
    "|Hchannel:channel:2|h[2. Trade - Stormwind City]|h |Hplayer:Ann:2:CHANNEL:2|h[Ann]|h: WTS Linen Bandage x20",
    "|Hchannel:PARTY|h[Party]|h |Hplayer:Bob:3:PARTY|h[Bob]|h: pull when ready",
    "|Hchannel:GUILD|h[Guild]|h |Hplayer:Gm:4:GUILD|h[Gm]|h: welcome back!",
    "|Hchannel:RAID|h[Raid Leader]|h |Hplayer:Ray:5:RAID|h[Ray]|h: stack on me",
    "|Hplayer:Example Player:6:SAY|h[Example Player]|h says: hello there",
    "|Hplayer:Example Player:7:YELL|h[Example Player]|h yells: for the Alliance!",
    "|Hplayer:Mia:8:WHISPER|h[Mia]|h whispers: got a minute?",
}

end)
