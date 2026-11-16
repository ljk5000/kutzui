---------------------------------------------------------------------------
-- KutzUI / KutzLog        (part of the "combatlog" module)
--
-- KutzUI's own combat log window, in the place of Blizzard's (when the menu's Combat log page
-- says "KutzUI log"). Its look follows the Details! damage meter (only the idea - none of its
-- code): a strip of tabs on top, then thin bars, each with an icon, a name on the left and the
-- numbers on the right; click a bar to see what it is made of.
--
--   Log      - what happens to you, your target and your pet, newest at the bottom
--              (KutzLogFeed.lua collects it). Every line has the same order:
--                time+mark  [icon]  who  amount  what
--              The mark tells the direction by its SHAPE as well as its colour:
--                >  you / your target (gold)     <  done to you (red)
--                =  your pet (green)             +  a heal on you (light green)
--   Damage, Healing, Taken - from Blizzard's own damage meter data (C_DamageMeter): one bar per
--              person in class colour; click one for their spells.
--   Deaths   - who died; click one for the last hits before the death (Blizzard's death recap).
--   Now / All - this fight or all fights.
--
-- The game may hide numbers and names during combat. Those are handed straight to the bar and
-- the text, which can show them; this file never looks at them.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("combatlog", function()

local issecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not issecret(v) end
local TEX = "Interface\\Buttons\\WHITE8X8"
local HEADER = 20
local PAD = 4

local DIR = {
    out  = { ">", 1.00, 0.82, 0.30 },
    ["in"] = { "<", 1.00, 0.42, 0.42 },
    pet  = { "=", 0.60, 0.85, 0.40 },
    heal = { "+", 0.45, 1.00, 0.55 },
    info = { "-", 0.70, 0.70, 0.70 },
}
ns.KL_DIR = DIR

local TABS = {
    { key = "log",     text = "Log" },
    { key = "damage",  text = "Damage" },
    { key = "healing", text = "Healing" },
    { key = "taken",   text = "Taken" },
    { key = "deaths",  text = "Deaths" },
}

local function DB() return KutzUIDB or {} end
local function Tab() return DB().klTab or "log" end
local function SessionAll() return DB().klAll and true or false end
local function FontSize() return DB().clogFontSize or 12 end

local function Short(n)
    if not Plain(n) or type(n) ~= "number" then return n end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e4 then return string.format("%.1fk", n / 1e3) end
    return tostring(math.floor(n + 0.5))
end
ns.KLShort = Short

local function SpellName(id)
    local cs = _G.C_Spell
    local name = cs and cs.GetSpellName and cs.GetSpellName(id)
    return Plain(name) and name or nil
end
local function SpellIcon(id)
    local cs = _G.C_Spell
    return cs and cs.GetSpellTexture and cs.GetSpellTexture(id) or nil
end

local function SetAny(fs, v)                        -- text that may be hidden by the game
    if v == nil then fs:SetText(""); return end
    if not pcall(fs.SetText, fs, v) then fs:SetText("?") end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local win, rows, tabButtons = nil, {}, {}
ns.KLRows = rows
local state = { offset = 0, detail = nil, dirty = true }
ns.KLState = state

local function Active()
    if not ns.CLView or ns.CLView() ~= "kutz" then return false end
    if ns.CombatLogSwapped and ns.CombatLogSwapped() then return false end   -- the damage meter has the spot
    return true
end
ns.KutzLogActive = Active

local function Measure(text)
    local fs = win.measure
    ns.StyleText(fs, FontSize())
    fs:SetText(text)
    return math.ceil(fs:GetStringWidth() or (#text * FontSize() * 0.6))
end

local function MakeRow(i)
    local r = CreateFrame("Button", nil, win)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetAllPoints()
    r.bar:SetStatusBarTexture(TEX)
    r.bar:SetMinMaxValues(0, 1); r.bar:SetValue(0)
    r.icon = r.bar:CreateTexture(nil, "ARTWORK")
    r.time = r.bar:CreateFontString(nil, "OVERLAY")
    r.who = r.bar:CreateFontString(nil, "OVERLAY")
    r.amount = r.bar:CreateFontString(nil, "OVERLAY")
    r.what = r.bar:CreateFontString(nil, "OVERLAY")
    r.time:SetJustifyH("LEFT"); r.who:SetJustifyH("LEFT")
    r.amount:SetJustifyH("RIGHT"); r.what:SetJustifyH("LEFT")
    r.who:SetWordWrap(false); r.what:SetWordWrap(false)
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ns.KLBack() return end
        if self.click then self.click() end
    end)
    r:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
            GameTooltip:Show()
        elseif self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.click, r.spellID, r.tip = false, false, false
    rows[i] = r
    return r
end

-- lay the rows out for the current size and font
local function LayoutRows()
    local size = FontSize()
    local rh = size + 6
    local h = (win:GetHeight() or 0) - HEADER - PAD
    local w = win:GetWidth() or 0
    local n = math.max(1, math.floor(h / (rh + 1)))
    local timeW = Measure("00:00:00>") + 4
    local amountW = Measure("0000.0k") + 4
    local whatW = math.min(Measure("Physical crushing"), math.floor(w * 0.34))
    state.rowCount, state.rowH = n, rh
    for i = 1, math.max(n, #rows) do
        local r = rows[i] or MakeRow(i)
        if i <= n then
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -(HEADER + (i - 1) * (rh + 1)))
            r:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -(HEADER + (i - 1) * (rh + 1)))
            r:SetHeight(rh)
            for _, fs in ipairs({ r.time, r.who, r.amount, r.what }) do ns.StyleText(fs, size) end
            r.time:ClearAllPoints(); r.time:SetPoint("LEFT", r, "LEFT", 2, 0); r.time:SetWidth(timeW)
            r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", r, "LEFT", timeW + 2, 0); r.icon:SetSize(rh - 2, rh - 2)
            r.what:ClearAllPoints(); r.what:SetPoint("RIGHT", r, "RIGHT", -2, 0); r.what:SetWidth(whatW)
            r.amount:ClearAllPoints(); r.amount:SetPoint("RIGHT", r.what, "LEFT", -6, 0); r.amount:SetWidth(amountW)
            r.who:ClearAllPoints()
            r.who:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
            r.who:SetPoint("RIGHT", r.amount, "LEFT", -4, 0)
            r:Show()
        else
            r:Hide()
        end
    end
    state.size, state.w, state.h = size, w, win:GetHeight()
end

local function Clear(r)
    r.time:SetText(""); r.who:SetText(""); r.amount:SetText(""); r.what:SetText("")
    r.icon:SetTexture(nil); r.icon:Hide()
    r.bar:SetMinMaxValues(0, 1); r.bar:SetValue(0)
    r.bar:SetStatusBarColor(1, 1, 1, 0)
    r.click, r.spellID, r.tip = false, false, false
    r.time:SetTextColor(1, 1, 1); r.who:SetTextColor(1, 1, 1); r.amount:SetTextColor(1, 1, 1); r.what:SetTextColor(0.75, 0.75, 0.75)
end

local function Icon(r, tex, atlas)
    if atlas then
        if pcall(r.icon.SetAtlas, r.icon, atlas) then r.icon:Show() end
    elseif tex then
        r.icon:SetTexture(tex); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); r.icon:Show()
    end
end

local function Message(text)
    for i = 1, state.rowCount do Clear(rows[i]) end
    local r = rows[1]
    if r then r.who:SetText(text); r.who:SetTextColor(0.75, 0.75, 0.75) end
end

---------------------------------------------------------------------------
-- Log view
---------------------------------------------------------------------------
local function FillLogRow(r, line)
    local d = DIR[line.dir] or DIR.info
    r.time:SetText(date("%H:%M:%S", line.t) .. d[1])
    r.time:SetTextColor(d[2], d[3], d[4])
    r.bar:SetMinMaxValues(0, 1); r.bar:SetValue(1)
    r.bar:SetStatusBarColor(d[2], d[3], d[4], 0.10)
    if line.icon then Icon(r, line.icon) end
    SetAny(r.who, line.who)
    r.who:SetTextColor(line.r or 1, line.g or 1, line.b or 1)
    SetAny(r.amount, Short(line.amount))
    if line.kind == "heal" then r.amount:SetTextColor(0.45, 1, 0.55)
    else r.amount:SetTextColor(ns.KLSchoolRGB(line.school)) end
    r.what:SetText(line.what or "")
    r.spellID = line.spellID or false
end

local function DrawLog()
    local n = state.rowCount
    local count = ns.KLCount()
    state.offset = math.max(0, math.min(state.offset, count - n))
    if count == 0 then
        Message("Nothing yet. Fight something: your casts, hits on you, your target and your pet show here.")
        return
    end
    for k = 1, n do
        local r = rows[k]
        Clear(r)
        local line = ns.KLLine(state.offset + (n - k + 1))  -- newest at the bottom
        if line then FillLogRow(r, line) end
    end
end

---------------------------------------------------------------------------
-- Meter views (Blizzard's damage meter data)
---------------------------------------------------------------------------
local METER = { damage = "DamageDone", healing = "HealingDone", taken = "DamageTaken", deaths = "Deaths" }

local function MeterType(tab)
    local e = _G.Enum and Enum.DamageMeterType
    return e and e[METER[tab]]
end
local function SessionType()
    local e = _G.Enum and Enum.DamageMeterSessionType
    return e and (SessionAll() and e.Overall or e.Current)
end

local function MeterReady()
    local dm = _G.C_DamageMeter
    if not dm or not dm.GetCombatSessionFromType then return false, "This game has no damage meter data." end
    if dm.IsDamageMeterAvailable then
        local ok, avail, reason = pcall(dm.IsDamageMeterAvailable)
        if ok and Plain(avail) and not avail then
            return false, "Blizzard's damage meter is not available" .. (Plain(reason) and reason ~= "" and (": " .. reason) or ".")
        end
    end
    return true
end

local function ClassRGB(class)
    local c = Plain(class) and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.6, 0.6, 0.6
end

local function DrawMeter(tab)
    local ok, why = MeterReady()
    if not ok then Message(why) return end
    local good, session = pcall(C_DamageMeter.GetCombatSessionFromType, SessionType(), MeterType(tab))
    if not good or type(session) ~= "table" or type(session.combatSources) ~= "table" or #session.combatSources == 0 then
        Message(tab == "deaths" and "Nobody has died." or "No fight recorded yet.")
        return
    end
    local sources = session.combatSources
    local n = state.rowCount
    state.offset = math.max(0, math.min(state.offset, #sources - n))
    for k = 1, n do
        local r = rows[k]
        Clear(r)
        local i = state.offset + k
        local src = sources[i]
        if src then
            local cr, cg, cb = ClassRGB(src.classFilename)
            r.time:SetText(i .. ".")
            r.time:SetTextColor(0.75, 0.75, 0.75)
            if Plain(src.classFilename) and src.classFilename ~= "" then Icon(r, nil, "classicon-" .. string.lower(src.classFilename)) end
            SetAny(r.who, src.name)
            if src.isLocalPlayer then r.who:SetTextColor(1, 0.95, 0.6) end
            if tab == "deaths" then
                r.bar:SetMinMaxValues(0, 1); r.bar:SetValue(1)
                r.bar:SetStatusBarColor(cr, cg, cb, 0.35)
                local t = src.deathTimeSeconds
                if Plain(t) and type(t) == "number" then
                    r.what:SetText(string.format("at %d:%02d", math.floor(t / 60), math.floor(t % 60)))
                end
                local id = src.deathRecapID
                if Plain(id) and type(id) == "number" and id > 0 then
                    r.click = function() state.detail = { kind = "recap", id = id, name = src.name }; state.offset = 0; ns.KLRedraw() end
                    r.tip = "Click: the last hits before this death."
                end
            else
                r.bar:SetMinMaxValues(0, session.maxAmount or 1)
                r.bar:SetValue(src.totalAmount or 0)
                r.bar:SetStatusBarColor(cr, cg, cb, 0.55)
                SetAny(r.amount, Short(src.totalAmount))
                SetAny(r.what, Short(src.amountPerSecond))
                local guid, creature = src.sourceGUID, src.sourceCreatureID
                if (guid == nil or Plain(guid)) and (creature == nil or Plain(creature)) then
                    r.click = function()
                        state.detail = { kind = "spells", tab = tab, guid = guid, creature = creature, name = src.name }
                        state.offset = 0
                        ns.KLRedraw()
                    end
                    r.tip = "Click: this one's spells. Right-click: back."
                else
                    r.tip = "The game hides who this is during combat: click again after the fight to see the spells."
                end
            end
        end
    end
end

local function DrawSpells(d)
    local ok, why = MeterReady()
    if not ok then Message(why) return end
    local good, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType, SessionType(), MeterType(d.tab), d.guid, d.creature)
    if not good or type(src) ~= "table" or type(src.combatSpells) ~= "table" or #src.combatSpells == 0 then
        Message("No spells to show (right-click to go back).")
        return
    end
    local spells = src.combatSpells
    local n = state.rowCount
    state.offset = math.max(0, math.min(state.offset, #spells - n))
    for k = 1, n do
        local r = rows[k]
        Clear(r)
        local sp = spells[state.offset + k]
        if sp then
            r.time:SetText((state.offset + k) .. ".")
            r.time:SetTextColor(0.75, 0.75, 0.75)
            local id = sp.spellID
            if Plain(id) and type(id) == "number" then
                local name = SpellName(id)
                SetAny(r.who, name or ("spell " .. id))
                Icon(r, SpellIcon(id))
                r.spellID = id
            end
            r.bar:SetMinMaxValues(0, src.maxAmount or 1)
            r.bar:SetValue(sp.totalAmount or 0)
            r.bar:SetStatusBarColor(1, 0.82, 0.3, 0.40)
            SetAny(r.amount, Short(sp.totalAmount))
            SetAny(r.what, Short(sp.amountPerSecond))
            r.click = ns.KLBack
        end
    end
end

local function DrawRecap(d)
    local dr = _G.C_DeathRecap
    local good, events = false, nil
    if dr and dr.GetRecapEvents then good, events = pcall(dr.GetRecapEvents, d.id) end
    if not good or type(events) ~= "table" or #events == 0 then
        Message("This death recap is gone (right-click to go back).")
        return
    end
    local maxHP = dr.GetRecapMaxHealth and select(2, pcall(dr.GetRecapMaxHealth, d.id))
    local last = 0
    for _, e in ipairs(events) do
        if Plain(e.timestamp) and type(e.timestamp) == "number" and e.timestamp > last then last = e.timestamp end
    end
    local list = {}                                      -- Blizzard gives the killing blow first: oldest at the top here
    for i = #events, 1, -1 do list[#list + 1] = events[i] end
    local n = state.rowCount
    state.offset = math.max(0, math.min(state.offset, #list - n))
    for k = 1, n do
        local r = rows[k]
        Clear(r)
        local e = list[state.offset + k]
        if e then
            if Plain(e.timestamp) and type(e.timestamp) == "number" then
                r.time:SetText(string.format("-%.1fs", last - e.timestamp))
            end
            r.time:SetTextColor(1, 0.42, 0.42)
            local id = e.spellId
            local name = e.spellName
            if e.event == "SWING_DAMAGE" then name = _G.ACTION_SWING or "Melee"; id = nil end
            if Plain(id) and type(id) == "number" then
                Icon(r, SpellIcon(id))
                r.spellID = id
            end
            local caster = (not e.hideCaster) and e.sourceName or nil
            if Plain(name) and Plain(caster) and type(name) == "string" and type(caster) == "string" then
                r.who:SetText(name .. "  |cffaaaaaa" .. caster .. "|r")
            else
                SetAny(r.who, name)
            end
            local amt = e.amount
            if Plain(amt) and type(amt) == "number" then SetAny(r.amount, "-" .. Short(amt)) end
            r.amount:SetTextColor(ns.KLSchoolRGB(e.school))
            local extra = {}
            local function Add(field, word)
                local v = e[field]
                if Plain(v) and type(v) == "number" and v > 0 then extra[#extra + 1] = word .. " " .. Short(v) end
            end
            Add("overkill", "overkill"); Add("absorbed", "absorbed"); Add("resisted", "resisted"); Add("blocked", "blocked")
            if Plain(e.currentHP) and Plain(maxHP) and type(maxHP) == "number" and maxHP > 0 and type(e.currentHP) == "number" then
                table.insert(extra, 1, math.floor(e.currentHP / maxHP * 100) .. "% hp")
            end
            r.what:SetText(table.concat(extra, ", "))
            r.bar:SetMinMaxValues(0, 1); r.bar:SetValue(1)
            r.bar:SetStatusBarColor(1, 0.3, 0.3, (state.offset + k == #list) and 0.30 or 0.10)   -- the killing blow stands out
            r.click = ns.KLBack
        end
    end
end

---------------------------------------------------------------------------
-- Header
---------------------------------------------------------------------------
local function TabColor(b, on)
    if on then b.text:SetTextColor(1, 0.82, 0.3) else b.text:SetTextColor(0.7, 0.7, 0.7) end
end

local function UpdateHeader()
    for _, b in ipairs(tabButtons) do TabColor(b, b.key == Tab()) end
    local d = state.detail
    win.title:SetText("")
    if d then
        win.back:Show()
        local label = (d.kind == "recap") and "death of " or "spells of "
        if Plain(d.name) then win.title:SetText(label .. tostring(d.name)) else win.title:SetText(label .. "...") end
    else
        win.back:Hide()
    end
    win.session.text:SetText(SessionAll() and "All" or "Now")
    win.session:SetShown(Tab() ~= "log")
    win.clear:SetShown(Tab() == "log")
end

local function HeaderButton(text, w, onClick)
    local b = CreateFrame("Button", nil, win)
    b:SetSize(w, HEADER - 4)
    b.text = b:CreateFontString(nil, "OVERLAY")
    ns.StyleText(b.text, 11)
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetColorTexture(1, 0.82, 0, 0.15); hl:SetAllPoints()
    b:SetScript("OnClick", onClick)
    return b
end

function ns.KLSetTab(key)
    if KutzUIDB then KutzUIDB.klTab = key end
    state.detail, state.offset = nil, 0
    ns.KLRedraw()
end

function ns.KLBack()
    if state.detail then state.detail, state.offset = nil, 0; ns.KLRedraw() end
end

local function Build()
    win = CreateFrame("Frame", "KutzLogFrame", UIParent)
    win:Hide()
    win.anchor = false
    win:EnableMouse(true)
    win:EnableMouseWheel(true)
    win.measure = win:CreateFontString(nil, "OVERLAY"); win.measure:Hide()
    win.bg = win:CreateTexture(nil, "BACKGROUND"); win.bg:SetAllPoints()
    win.headBg = win:CreateTexture(nil, "BORDER")
    win.headBg:SetPoint("TOPLEFT"); win.headBg:SetPoint("TOPRIGHT"); win.headBg:SetHeight(HEADER - 2)
    win.headBg:SetColorTexture(0, 0, 0, 0.45)
    local x = PAD
    for _, t in ipairs(TABS) do
        local b = HeaderButton(t.text, 8 + #t.text * 7, function() ns.KLSetTab(t.key) end)
        b.key = t.key
        b:SetPoint("TOPLEFT", win, "TOPLEFT", x, -2)
        x = x + b:GetWidth() + 2
        tabButtons[#tabButtons + 1] = b
    end
    win.session = HeaderButton("Now", 34, function()
        if KutzUIDB then KutzUIDB.klAll = not SessionAll() or nil end
        state.detail, state.offset = nil, 0
        ns.KLRedraw()
    end)
    win.session:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -2)
    win.clear = HeaderButton("Clear", 40, function() ns.KLClear(); state.offset = 0; ns.KLRedraw() end)
    win.clear:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -2)
    win.back = HeaderButton("< Back", 50, ns.KLBack)
    win.back:SetPoint("TOPRIGHT", win.session, "TOPLEFT", -4, 0)
    win.title = win:CreateFontString(nil, "OVERLAY")
    ns.StyleText(win.title, 11)
    win.title:SetTextColor(0.85, 0.85, 0.85)
    win.title:SetPoint("BOTTOMLEFT", win, "TOPLEFT", PAD, 2)
    win:SetScript("OnMouseWheel", function(_, delta)
        if Tab() == "log" and not state.detail then
            state.offset = math.max(0, state.offset + delta * 3)      -- wheel up = older lines
        else
            state.offset = math.max(0, state.offset - delta * 3)      -- wheel down = further down the list
        end
        ns.KLRedraw()
    end)
    win:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then ns.KLBack() end end)
end

function ns.KLRedraw()
    if not win or not win:IsShown() then state.dirty = true; return end
    state.dirty = false
    if state.size ~= FontSize() or state.w ~= win:GetWidth() or state.h ~= win:GetHeight() then LayoutRows() end
    UpdateHeader()
    local tab, d = Tab(), state.detail
    if d and d.kind == "spells" then DrawSpells(d)
    elseif d and d.kind == "recap" then DrawRecap(d)
    elseif tab == "log" then DrawLog()
    else DrawMeter(tab) end
end

---------------------------------------------------------------------------
-- Placing it over Blizzard's log, and keeping it fresh
---------------------------------------------------------------------------
local function Place()
    local cl = _G.ChatFrame2
    local want = Active() and cl ~= nil and cl:IsShown()
    if not win then
        if not want then return end
        Build()
    end
    if want then
        if win.anchor ~= cl then
            win.anchor = cl
            win:ClearAllPoints()
            win:SetPoint("TOPLEFT", cl, "TOPLEFT", -PAD, PAD)
            win:SetPoint("BOTTOMRIGHT", cl, "BOTTOMRIGHT", PAD, -PAD)
            win:SetFrameStrata(cl:GetFrameStrata() or "MEDIUM")
            win:SetFrameLevel((cl:GetFrameLevel() or 1) + 20)
        end
        local bga = (KutzUIDB and KutzUIDB.clogBgAlpha) or 0.20
        win.bg:SetColorTexture(0, 0, 0, math.max(bga, 0.25))
        if not win:IsShown() then win:Show(); state.dirty = true end
    elseif win:IsShown() then
        win:Hide()
    end
    -- Blizzard's filter buttons belong to Blizzard's log: hidden while ours is shown. (The damage
    -- meter module does this itself when it runs; children of a protected bar: out of combat only.)
    if not ns.DMMode and not InCombatLockdown() then
        for i = 1, 6 do ns.SetFrameHidden(_G["CombatLogQuickButtonFrameButton" .. i], want) end
    end
end
ns.KLPlace = Place

ns.KLOnLine(function()
    if win and win:IsShown() and Tab() == "log" and not state.detail then
        if state.offset > 0 then state.offset = state.offset + 1 end   -- scrolled back: stay on the same lines
        state.dirty = true
    end
end)

local acc, meterAcc = 0, 0
local ticker = CreateFrame("Frame")
ticker:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
ticker:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
ticker:RegisterEvent("DAMAGE_METER_RESET")
ticker:SetScript("OnEvent", function() if Tab() ~= "log" or state.detail then state.dirty = true end end)
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc, meterAcc = acc + elapsed, meterAcc + elapsed
    if acc < 0.2 then return end
    acc = 0
    local ok, err = pcall(function()
        Place()
        if win and win:IsShown() then
            if meterAcc >= 1 and Tab() ~= "log" then meterAcc = 0; state.dirty = true end  -- numbers keep growing in a fight
            if state.dirty then ns.KLRedraw() end
        end
    end)
    if not ok and not ns.kutzLogErrored then
        ns.kutzLogErrored = true
        ns.Print("KutzUI log error (please report): " .. tostring(err))
    end
end)

ns.RegisterDebug(function()
    ns.Print(string.format("kutz log: active=%s shown=%s tab=%s detail=%s rows=%s",
        tostring(Active()), tostring(win and win:IsShown() or false), Tab(),
        tostring(state.detail and state.detail.kind), tostring(state.rowCount)))
end)

end)
