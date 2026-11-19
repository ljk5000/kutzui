---------------------------------------------------------------------------
-- KutzUI / settings pages
-- Profiles and the Modules page.
--
-- Part of KutzUI_Options. These files load only when you open /kutz, and only
-- after Menu.lua, which publishes the widget toolkit on KutzUI._opt.
-- Nothing in here runs until that window is opened.
---------------------------------------------------------------------------
local ns = _G.KutzUI
local M = ns._opt
if not M then error("KutzUI settings pages loaded before Menu.lua") end

local function BuildModulesPage()
    local p = M.NewPage("UI features", "Switch whole parts of Kutz UI on or off. A part that is off creates nothing and leaves Blizzard's own look untouched.")
    M.pages.modules = p

    p:Columns(2)
    p:Col(1)
    p:Section("Interface features")
    for _, m in ipairs(ns.MODULES) do
        local key = m.key
        p:Check(m.name,
            function() return ns.Enabled(key) end,
            function(v) ns.SetModuleEnabled(key, v) end,
            m.desc)
    end

    p:Col(2)
    p:Note("Addon Monitor also requires KutzUI_Monitor enabled in AddOns. Inventory is a separate addon, not a UI feature switch.", 4)
    p:Section("Apply")
    local note = M.Text(p.frame, 12, "LEFT", { 1, 0.5, 0.2 })
    note:SetPoint("TOPLEFT", p:X(), p:Y())
    note:SetWidth(p.colW)
    note:SetWordWrap(true)
    p:Advance(34)
    p.refreshers[#p.refreshers + 1] = function()
        local changed = false
        for _, m in ipairs(ns.MODULES) do
            if ns.startedOn and ns.startedOn[m.key] ~= ns.Enabled(m.key) then changed = true end
        end
        note:SetText(changed and "Changes are saved. Press Reload UI to apply them." or "Nothing changed since the game started.")
    end
    p:Buttons({ { text = "Reload UI", w = 130, click = function() ReloadUI() end,
        tip = "Reloads the interface so the switches above take effect (same as typing /reload)." } })

    if not ns.moduleMemory.monitor then
        p:Note("Addon Monitor is not running. Enable KutzUI_Monitor in AddOns and its feature switch, then reload.", 3)
    end
    p:Section("Memory")
    local mem = M.Text(p.frame, 11, "LEFT", M.GREY)
    mem:SetPoint("TOPLEFT", p:X(), p:Y())
    mem:SetWidth(p.colW)
    mem:SetWordWrap(true)
    p:Advance(90)
    p.refreshers[#p.refreshers + 1] = function()
        UpdateAddOnMemoryUsage()
        local lines = { string.format("Kutz UI right now: %.0f KB, plus %.0f KB for this settings window (it only loads while you use it).",
            GetAddOnMemoryUsage(M.ADDON_NAME), GetAddOnMemoryUsage("KutzUI_Options")) }
        local parts = {}
        for label, kb in pairs(ns.moduleMemory or {}) do parts[#parts + 1] = string.format("%s %.0f KB", label, kb) end
        table.sort(parts)
        if #parts > 0 then lines[#lines + 1] = "Set up at start (approximate): " .. table.concat(parts, ", ") .. "." end
        lines[#lines + 1] = "Type /kutz mem for the number after cleaning up garbage."
        mem:SetText(table.concat(lines, "\n"))
    end
end

local function BuildProfilesPage()
    local p = M.NewPage("Profiles", "Save your settings under a name, switch between setups, give a character its own, and copy your settings as text to back them up or share them.")
    M.pages.profiles = p

    local status
    local function Say(msg, bad)
        status:SetText(msg)
        if bad then status:SetTextColor(1, 0.4, 0.35) else status:SetTextColor(M.GOLD[1], M.GOLD[2], M.GOLD[3]) end
    end

    p:Columns(2)
    p:Col(1)
    p:Section("Your profiles")
    local info = M.Text(p.frame, 11, "LEFT", M.GREY)
    info:SetPoint("TOPLEFT", p:X(), p:Y())
    info:SetWidth(p.colW)
    info:SetWordWrap(true)
    p:Advance(44)
    p.refreshers[#p.refreshers + 1] = function()
        info:SetText("Active profile: " .. (ns.ProfileActive() or "none yet") .. "   -   this character uses: "
            .. (ns.ProfileAssigned() or "whatever is active") .. ".\nEach character gets its own profile when it first logs in; the active profile follows your changes automatically.")
    end

    local nameBox, nameHolder = M.MakeEditBox(p.frame, p.colW - 100)
    nameHolder:SetPoint("TOPLEFT", p:X(), p:Y())
    local saveBtn = M.Btn(p.frame, "Save as", 90, 24, function()
        local ok, res = ns.ProfileSave(nameBox:GetText())
        if ok then
            nameBox:SetText("")
            Say("Saved as '" .. res .. "' and made active.")
            p:Refresh()
        else
            Say(res, true)
        end
    end)
    saveBtn:SetPoint("TOPLEFT", p:X() + p.colW - 90, p:Y())
    M.Tip(saveBtn, "Copies your current settings into a profile with the name typed on the left (a new one, or overwrites that name).")
    p:Advance(32)

    status = M.Text(p.frame, 11, "LEFT", M.GOLD)
    status:SetPoint("TOPLEFT", p:X(), p:Y())
    status:SetWidth(p.colW)
    status:SetWordWrap(true)
    p:Advance(30)

    local rows, first = {}, 0                     -- first: how many profiles are scrolled past
    local listBox = CreateFrame("Frame", nil, p.frame)
    listBox:SetSize(p.colW, 8 * 28)
    listBox:SetPoint("TOPLEFT", p:X(), p:Y())
    listBox:EnableMouseWheel(true)
    listBox:SetScript("OnMouseWheel", function(_, delta)
        local most = math.max(0, #ns.ProfileNames() - 8)
        first = math.max(0, math.min(most, first - delta))
        p:Refresh()
    end)
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, listBox)
        row.name = false                          -- the profile this row shows (none yet)
        row:SetSize(p.colW, 26)
        row:SetPoint("TOPLEFT", listBox, "TOPLEFT", 0, -(i - 1) * 28)
        local bg = M.Fill(row, "BACKGROUND", 0.085, 0.09, 0.12, 1)
        bg:SetAllPoints()
        row.text = M.Text(row, 12, "LEFT")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetWidth(p.colW - 170)
        row.text:SetWordWrap(false)
        row.load = M.Btn(row, "Load", 44, 20, function()
            if not row.name then return end
            ns.ProfileLoad(row.name)
            Say("Loaded '" .. row.name .. "'. Press Reload UI (right) to apply it.")
            p:Refresh()
        end)
        row.load:SetPoint("RIGHT", row, "RIGHT", -92, 0)
        M.Tip(row.load, "Replaces your settings with this profile. Reload the UI afterwards.")
        row.char = M.Btn(row, "Char", 44, 20, function()
            if not row.name then return end
            if ns.ProfileAssigned() == row.name then
                ns.ProfileAssign(false)                 -- false: don't make a new one for it either
                Say("This character now uses whichever profile is active.")
            else
                ns.ProfileAssign(row.name)
                Say("'" .. row.name .. "' will be loaded whenever this character logs in.")
            end
            p:Refresh()
        end)
        row.char:SetPoint("RIGHT", row, "RIGHT", -46, 0)
        M.Tip(row.char, "Use this profile on this character: it is loaded when the character logs in. Click again to stop; the character then uses whichever profile is active.")
        row.del = M.Btn(row, "Del", 40, 20, function()
            if not row.name then return end
            if row.sure then
                ns.ProfileDelete(row.name)
                row.sure = nil
                Say("Deleted.")
                p:Refresh()
            else
                row.sure = true
                row.del.text:SetText("Sure?")
                C_Timer.After(3, function() row.sure = nil; row.del.text:SetText("Del") end)
            end
        end)
        row.del:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        M.Tip(row.del, "Deletes this profile (click twice).")
        rows[i] = row
    end
    p:Advance(8 * 28)
    local more = M.Text(p.frame, 11, "LEFT", M.GREY)
    more:SetPoint("TOPLEFT", p:X(), p:Y())
    more:SetWidth(p.colW)
    p:Advance(18)
    p.refreshers[#p.refreshers + 1] = function()
        local names = ns.ProfileNames()
        first = math.max(0, math.min(first, #names - 8))
        if #names > 8 then
            more:SetText(string.format("Showing %d-%d of %d profiles. Scroll the list with the mouse wheel.", first + 1, first + 8, #names))
        else
            more:SetText("")
        end
        for i, row in ipairs(rows) do
            local name = names[first + i]
            row.name = name or false
            row:SetShown(name ~= nil)
            if name then
                local tags = {}
                if name == ns.ProfileActive() then tags[#tags + 1] = "active" end
                if name == ns.ProfileAssigned() then tags[#tags + 1] = "this character" end
                row.text:SetText(name .. (#tags > 0 and ("  (" .. table.concat(tags, ", ") .. ")") or ""))
            end
        end
    end

    p:Col(2)
    p:Section("Copy your settings as text")
    p:Note("Creates one line of text for your current settings. Click in the box, press Ctrl+A then Ctrl+C, and keep it somewhere safe (or send it to a friend).", 3)
    local exportBox, exportHolder = M.MakeEditBox(p.frame, p.colW)
    exportHolder:SetPoint("TOPLEFT", p:X(), p:Y())
    p:Advance(30)
    p:Buttons({ { text = "Create export text", w = 170, click = function()
        local ok, text = pcall(ns.ProfileExport)
        if ok then
            exportBox:SetText(text)
            exportBox:HighlightText()
            exportBox:SetFocus()
            Say("Ready. Press Ctrl+C to copy it.")
        else
            Say("Could not create the text: " .. tostring(text), true)
        end
    end, tip = "Fills the box above with your current settings." } })

    p:Section("Bring settings in")
    p:Note("Paste an export here (click in the box, then Ctrl+V). It becomes a new profile; your current settings are not touched until you load it.", 3)
    local importBox, importHolder = M.MakeEditBox(p.frame, p.colW)
    importHolder:SetPoint("TOPLEFT", p:X(), p:Y())
    p:Advance(30)
    local importName, importNameHolder = M.MakeEditBox(p.frame, p.colW - 154)
    importNameHolder:SetPoint("TOPLEFT", p:X(), p:Y())
    importName:SetText("Imported")
    local importBtn = M.Btn(p.frame, "Import as profile", 148, 24, function()
        local settings, err = ns.ProfileParse(importBox:GetText())
        if not settings then Say(err, true); return end
        local ok, res = ns.ProfileCreate(importName:GetText(), settings)
        if ok then
            importBox:SetText("")
            Say("Imported as '" .. res .. "'. Load it from the list on the left.")
            p:Refresh()
        else
            Say(res, true)
        end
    end)
    importBtn:SetPoint("TOPLEFT", p:X() + p.colW - 148, p:Y())
    M.Tip(importBtn, "Reads the pasted text and saves it as a new profile with the name on the left.")
    p:Advance(36)

    p:Section("Apply")
    p:Note("Loading a profile changes your saved settings; many things only take effect after a reload.", 3)
    p:Buttons({ { text = "Reload UI", w = 130, click = function() ReloadUI() end,
        tip = "Reloads the interface (same as typing /reload)." } })
end

M.builders.modules = BuildModulesPage
M.builders.profiles = BuildProfilesPage

M.builders.package = function()
    local p = M.NewPage("KutzUI package", "Choose addons in the game AddOns menu. Configure interface features here; connect inventory uploads in the desktop companion.")
    M.pages.package = p
    p:Columns(2)
    p:Section("In the game")
    p:Note("KutzUI: interface features and profiles. KutzUI - Settings opens only with /kutz and requires KutzUI.", 4)
    p:Note("KutzUI - Inventory: independent recording with /kinv. Works with KutzUI disabled. Reload or log out to save inventory for export.", 4)
    p:Note("KutzUI - Addon Monitor: optional diagnostics, requires KutzUI. Disable separately in AddOns. Existing settings stay in KutzUIDB.", 4)
    p:Buttons({ { text = "UI features", w = 130, click = function() M.ShowTab("modules") end },
        { text = "Profiles", w = 100, click = function() M.ShowTab("profiles") end } })
    p:Col(2)
    p:Section("On your desktop")
    p:Note("Open KutzUI Companion, select your game folder, and connect a cr0m key. Start watches game saves; Pause stops watching. Keys never belong in addon settings.", 5)
    p:Note("Uploads follow /reload or logout. The companion keeps the latest snapshot through connection failures. Windows sign-in startup is optional and never enabled by installing the addon.", 5)
    p:Section("Upgrading")
    p:Note("Replace addon folders and keep WTF untouched. Restart the game after installing new addons. KutzUIDB and KutzInventoryDB names are unchanged.", 4)
end
