---------------------------------------------------------------------------
-- KutzUI / Profiles                 (always on - a character's profile is applied at startup)
--
-- A profile is a named snapshot of ALL your settings (module switches included).
--   * the ACTIVE profile follows your changes: it is refreshed from the live settings when
--     you log out, reload, switch profile or save, so switching characters never loses work;
--   * "Save as" copies the current settings into a new profile and makes it active;
--   * "Load" replaces every setting with the profile's (then reload the UI to apply it);
--   * a profile can be assigned to a character: it is loaded when that character logs in.
--     By default EVERY character gets a profile of its own, named after it ("Name-Realm"), the
--     first time it logs in: a copy of the settings as they are at that moment, so each character
--     keeps its own settings from then on. Unassigning it in the menu ("Char" again) stores
--     `false`, which means "this character just uses whatever profile is active" and stops a new
--     one being made for it;
--   * export turns the current settings into one line of text, import turns such a line back
--     into a profile. The text is NOT code: the importer is a strict parser that never runs
--     anything, and it rejects text that is too big, too deep, damaged (checksum) or has
--     odd value types.
--
-- Where the profiles live: KutzUIDB.profiles (name -> settings), KutzUIDB.activeProfile,
-- KutzUIDB.charProfile (character -> profile name). Those three are not part of a profile.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local OUTSIDE = { profiles = true, charProfile = true, activeProfile = true,
    clogRoutingBackup = true,
    clogBlizzBackup = true,         -- (a copy of Blizzard's own combat log settings: account-wide, not per profile)
    memLog = true,                  -- (notes of every addon's memory: not a setting)
    monitor = true }                -- (the addon monitor's errors / hitches / CPU notes: not a setting)
local MAX_NAME = 32
local MAX_TEXT = 300000          -- characters accepted by the importer
local MAX_DEPTH = 8
local MAX_VALUES = 20000

local function DeepCopy(v, depth)
    if type(v) ~= "table" then return v end
    depth = (depth or 0) + 1
    if depth > 12 then return nil end
    local t = {}
    for k, x in pairs(v) do t[k] = DeepCopy(x, depth) end
    return t
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------
function ns.ProfileSnapshot()
    local out = {}
    for k, v in pairs(KutzUIDB or {}) do
        if not OUTSIDE[k] then out[k] = DeepCopy(v) end
    end
    return out
end

local function Store()
    KutzUIDB.profiles = KutzUIDB.profiles or {}
    return KutzUIDB.profiles
end

function ns.ProfileNames()
    local list = {}
    for name in pairs((KutzUIDB and KutzUIDB.profiles) or {}) do list[#list + 1] = name end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

function ns.ProfileActive()
    return KutzUIDB and KutzUIDB.activeProfile
end

function ns.CleanProfileName(name)
    name = (tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if name == "" then return nil, "Type a name first." end
    if #name > MAX_NAME then return nil, "Use at most " .. MAX_NAME .. " characters." end
    return name
end

-- the active profile follows the live settings
function ns.ProfileSync()
    local active = KutzUIDB and KutzUIDB.activeProfile
    if active and KutzUIDB.profiles and KutzUIDB.profiles[active] then
        KutzUIDB.profiles[active] = ns.ProfileSnapshot()
    end
end

-- copy the current settings into a profile called `name` (new, or overwrite) and make it active
function ns.ProfileSave(name)
    local clean, err = ns.CleanProfileName(name)
    if not clean then return false, err end
    ns.ProfileSync()
    Store()[clean] = ns.ProfileSnapshot()
    KutzUIDB.activeProfile = clean
    return true, clean
end

-- put a ready-made settings table into a profile (import); does not touch the live settings
function ns.ProfileCreate(name, settings)
    local clean, err = ns.CleanProfileName(name)
    if not clean then return false, err end
    local copy = {}
    for k, v in pairs(settings) do
        if not OUTSIDE[k] then copy[k] = DeepCopy(v) end
    end
    Store()[clean] = copy
    return true, clean
end

-- replace every setting with the profile's. The caller then reloads the UI.
function ns.ProfileLoad(name)
    local p = KutzUIDB and KutzUIDB.profiles and KutzUIDB.profiles[name]
    if not p then return false, "No such profile." end
    ns.ProfileSync()
    for k in pairs(KutzUIDB) do
        if not OUTSIDE[k] then KutzUIDB[k] = nil end
    end
    for k, v in pairs(p) do KutzUIDB[k] = DeepCopy(v) end
    KutzUIDB.activeProfile = name
    return true
end

function ns.ProfileDelete(name)
    local s = KutzUIDB and KutzUIDB.profiles
    if not (s and s[name]) then return false end
    s[name] = nil
    if KutzUIDB.activeProfile == name then KutzUIDB.activeProfile = nil end
    for char, p in pairs(KutzUIDB.charProfile or {}) do
        if p == name then KutzUIDB.charProfile[char] = nil end
    end
    return true
end

---------------------------------------------------------------------------
-- Per character
---------------------------------------------------------------------------
function ns.CharacterKey()
    return (UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "?")
end

function ns.ProfileAssigned()
    return KutzUIDB and KutzUIDB.charProfile and KutzUIDB.charProfile[ns.CharacterKey()]
end

-- name, or nil to stop assigning one to this character
function ns.ProfileAssign(name)
    KutzUIDB.charProfile = KutzUIDB.charProfile or {}
    KutzUIDB.charProfile[ns.CharacterKey()] = name
end

-- the character's name and realm, or nil while the game doesn't know them yet
local function KnownCharacter()
    local name = UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if type(name) ~= "string" or name == "" or name == _G.UNKNOWNOBJECT then return nil end
    if type(realm) ~= "string" or realm == "" then return nil end
    return true
end

-- give this character a profile of its own if it has none yet (and hasn't opted out).
-- Returns the new profile's name when one was made.
function ns.ProfileEnsureCharacter()
    if not KutzUIDB or not KnownCharacter() then return nil end
    local key = ns.CharacterKey()
    KutzUIDB.charProfile = KutzUIDB.charProfile or {}
    if KutzUIDB.charProfile[key] ~= nil then return nil end          -- has one, or chose none (false)
    local name = key:sub(1, MAX_NAME)
    local made
    if not Store()[name] then
        ns.ProfileSync()                                              -- keep the previous character's work
        Store()[name] = ns.ProfileSnapshot()
        made = name
    end
    KutzUIDB.charProfile[key] = name
    return made
end

-- Core calls this at startup, before any module starts, so a switch needs no reload
function ns.ProfileApplyForCharacter()
    ns.ProfileEnsureCharacter()
    local want = ns.ProfileAssigned()
    if want and want ~= KutzUIDB.activeProfile and KutzUIDB.profiles and KutzUIDB.profiles[want] then
        ns.ProfileLoad(want)
    end
end

local logout = CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:RegisterEvent("PLAYER_LOGIN")
logout:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- in case the character's name wasn't known yet at startup: make its profile now. It is a
        -- copy of the settings already in use, so it only has to become the active one (no reload).
        local ok, made = pcall(ns.ProfileEnsureCharacter)
        if ok and made then KutzUIDB.activeProfile = made end
        return
    end
    pcall(ns.ProfileSync)
end)

---------------------------------------------------------------------------
-- Export / import: "KUTZ1:<checksum>:<base64 of a plain description of the settings>"
-- The description is a tiny typed format: n<number>;  T  F  s<length>:<characters>  {key value ...}
---------------------------------------------------------------------------
local function Ser(v, out, depth)
    local t = type(v)
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then error("a number that can't be saved") end
        out[#out + 1] = "n" .. string.format("%.17g", v) .. ";"
    elseif t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "table" then
        if depth > MAX_DEPTH then error("settings nested too deep") end
        local keys = {}
        for k in pairs(v) do
            if type(k) ~= "string" and type(k) ~= "number" then error("a key that can't be saved") end
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta ~= tb then return ta < tb end
            return a < b
        end)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do
            Ser(k, out, depth + 1)
            Ser(v[k], out, depth + 1)
        end
        out[#out + 1] = "}"
    else
        error("a " .. t .. " can't be saved")
    end
end

local function Parse(s)
    local pos, n, count = 1, #s, 0
    local function value(depth)
        count = count + 1
        if count > MAX_VALUES then error("too many values") end
        local c = s:sub(pos, pos)
        if c == "n" then
            local e = s:find(";", pos, true)
            if not e then error("damaged number") end
            local num = tonumber(s:sub(pos + 1, e - 1))
            if not num or num ~= num or num == math.huge or num == -math.huge then error("bad number") end
            pos = e + 1
            return num
        elseif c == "T" then pos = pos + 1; return true
        elseif c == "F" then pos = pos + 1; return false
        elseif c == "s" then
            local colon = s:find(":", pos, true)
            if not colon then error("damaged text") end
            local len = tonumber(s:sub(pos + 1, colon - 1))
            if not len or len < 0 or len ~= math.floor(len) or colon + len > n then error("bad text length") end
            local str = s:sub(colon + 1, colon + len)
            pos = colon + len + 1
            return str
        elseif c == "{" then
            if depth > MAX_DEPTH then error("nested too deep") end
            pos = pos + 1
            local t = {}
            while s:sub(pos, pos) ~= "}" do
                if pos > n then error("unfinished table") end
                local k = value(depth + 1)
                if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
                t[k] = value(depth + 1)
            end
            pos = pos + 1
            return t
        end
        error("unexpected '" .. c .. "'")
    end
    local v = value(0)
    if pos ~= n + 1 then error("extra data at the end") end
    return v
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64VALUE
local function Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function Base64Decode(text)
    if not B64VALUE then
        B64VALUE = {}
        for i = 1, #B64 do B64VALUE[B64:sub(i, i)] = i - 1 end
    end
    local out, buffer, bits = {}, 0, 0
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == "=" then break end
        local v = B64VALUE[ch]
        if not v then error("not a Kutz UI export (odd character)") end
        buffer = buffer * 64 + v
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local byte = math.floor(buffer / 2 ^ bits)
            buffer = buffer - byte * 2 ^ bits
            out[#out + 1] = string.char(byte)
        end
    end
    return table.concat(out)
end

local function Checksum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%04x%04x", b, a)
end

-- one line of text for the current settings
function ns.ProfileExport()
    local out = {}
    Ser(ns.ProfileSnapshot(), out, 0)
    local payload = table.concat(out)
    return "KUTZ1:" .. Checksum(payload) .. ":" .. Base64Encode(payload)
end

-- text -> settings table, or nil + a reason
function ns.ProfileParse(text)
    if type(text) ~= "string" then return nil, "Nothing to import." end
    text = text:gsub("%s+", "")
    if text == "" then return nil, "Paste an export first." end
    if #text > MAX_TEXT then return nil, "That text is too long to be a Kutz UI export." end
    local sum, body = text:match("^KUTZ1:(%x%x%x%x%x%x%x%x):(.*)$")
    if not sum then return nil, "That is not a Kutz UI export (it should start with KUTZ1:)." end
    local ok, payload = pcall(Base64Decode, body)
    if not ok then return nil, "That is not a Kutz UI export." end
    if Checksum(payload) ~= sum then return nil, "The text is damaged or cut off (checksum doesn't match)." end
    local ok2, settings = pcall(Parse, payload)
    if not ok2 or type(settings) ~= "table" then return nil, "The export could not be read: " .. tostring(settings) end
    for k in pairs(OUTSIDE) do settings[k] = nil end
    return settings
end

ns.RegisterDebug(function()
    local names = ns.ProfileNames()
    ns.Print(string.format("profiles: %d saved, active=%s, this character (%s) uses=%s",
        #names, tostring(ns.ProfileActive()), ns.CharacterKey(), tostring(ns.ProfileAssigned())))
end)
