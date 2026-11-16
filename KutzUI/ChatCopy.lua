---------------------------------------------------------------------------
-- KutzUI / ChatCopy        (part of the "chat" module)
--
-- A "copy chat" window: the lines of a chat window as plain text you can select and copy
-- (Ctrl+A, Ctrl+C), opened by
--   * a small "copy" button in the top-right corner of a chat window (shown while the mouse is
--     over it; switch it off on the Chat page), or
--   * /kutz copy   (the chat tab you are looking at).
--
-- HOW THE LINES ARE READ: a chat window's stored lines belong to Blizzard's secure code, so an
-- addon can't read them directly. What it CAN do is hand the window a predicate through
-- TransformMessages (Blizzard's own sanctioned call). Ours changes nothing - it only records each
-- line it is shown and answers "no change", so nothing is re-drawn. Only done when you ask.
--
-- ORDER: the window keeps its lines in a ring (the list starts in the MIDDLE once it has filled
-- up). Every chat line carries a rising line number, so the single place where the numbers drop
-- is where the list really starts, and the list is turned around that point. Lines we can't read
-- (they are "secret" in some situations) are counted and reported, not guessed.
--
-- Also here: how many lines a chat window remembers (Blizzard's default is 128).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("chat", function()

local issecret = issecretvalue or function() return false end
local NUM = _G.NUM_CHAT_WINDOWS or 10

---------------------------------------------------------------------------
-- Plain text and ordering (no game calls: tested outside the game)
---------------------------------------------------------------------------
function ns.ChatPlainText(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|cn[%w_]+:", "")
    s = s:gsub("|r", "")
    s = s:gsub("|H.-|h", "")
    s = s:gsub("|h", "")
    s = s:gsub("|T.-|t", "")
    s = s:gsub("|A.-|a", "")
    s = s:gsub("|K.-|k", "?")                 -- a sealed (Battle.net) name we can't read
    s = s:gsub("||", "|")
    s = s:gsub("\194\160", " ")
    return s
end

-- entries: { { text=, id= (line number or nil) }, ... } in the order the ring is stored.
-- Returns them oldest first, and whether the order could not be worked out.
function ns.ChatCopyOrder(entries)
    local cut, descents, prev
    for i, e in ipairs(entries) do
        if e.id then
            if prev and e.id < prev then
                descents = (descents or 0) + 1
                cut = cut or i
            end
            prev = e.id
        end
    end
    if descents == 1 then
        local out = {}
        for i = cut, #entries do out[#out + 1] = entries[i] end
        for i = 1, cut - 1 do out[#out + 1] = entries[i] end
        return out, false
    end
    return entries, descents ~= nil
end

---------------------------------------------------------------------------
-- Reading a window
---------------------------------------------------------------------------
-- returns plain text (oldest line first), number of lines, number of unreadable lines, order uncertain?
function ns.ChatCopyCapture(cf)
    if not cf or not cf.TransformMessages then return "", 0, 0, false end
    local entries, hidden = {}, 0
    -- the entry arrives as (message, r, g, b, infoID, accessID, typeID, event, eventArgs, formatter, ...)
    local function record(message, r, g, b, infoID, accessID, typeID, event, eventArgs)
        if issecret(message) or type(message) ~= "string" then
            hidden = hidden + 1
            return false
        end
        local id
        if type(eventArgs) == "table" then
            local ok, v = pcall(function() return eventArgs[11] end)
            if ok and type(v) == "number" and not issecret(v) then id = v end
        end
        entries[#entries + 1] = { text = message, id = id }
        return false                            -- "no change": nothing is rewritten or redrawn
    end
    local ok = pcall(cf.TransformMessages, cf, record, function(...) return ... end)
    if not ok then return "", 0, 0, false end
    local ordered, uncertain = ns.ChatCopyOrder(entries)
    local lines = {}
    for i, e in ipairs(ordered) do lines[i] = ns.ChatPlainText(e.text) end
    return table.concat(lines, "\n"), #lines, hidden, uncertain
end

---------------------------------------------------------------------------
-- The window (built the first time it is needed)
---------------------------------------------------------------------------
local frame

local function Build()
    frame = CreateFrame("Frame", "KutzCopyChatFrame", UIParent)
    frame.box, frame.edit, frame.plain = false, false, false     -- filled in below
    frame:SetSize(660, 440)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local edge = frame:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0.17, 0.18, 0.24, 1)
    edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetColorTexture(0.045, 0.05, 0.07, 0.97)
    bg:SetAllPoints()

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    ns.StyleText(frame.title, 14)
    frame.title:SetTextColor(1, 0.82, 0)
    frame.title:SetPoint("TOPLEFT", 14, -12)

    frame.hint = frame:CreateFontString(nil, "OVERLAY")
    ns.StyleText(frame.hint, 11)
    frame.hint:SetTextColor(0.62, 0.65, 0.72)
    frame.hint:SetPoint("TOPLEFT", 14, -34)
    frame.hint:SetWidth(630)
    frame.hint:SetJustifyH("LEFT")

    local function Button(label, w, x, onClick)
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(w, 24)
        b:SetPoint("BOTTOMRIGHT", x, 12)
        local e = b:CreateTexture(nil, "BACKGROUND"); e:SetColorTexture(0.17, 0.18, 0.24, 1); e:SetAllPoints()
        local f = b:CreateTexture(nil, "BACKGROUND", nil, 1); f:SetColorTexture(0.11, 0.12, 0.16, 1)
        f:SetPoint("TOPLEFT", 1, -1); f:SetPoint("BOTTOMRIGHT", -1, 1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetColorTexture(1, 0.82, 0, 0.12); hl:SetAllPoints()
        local t = b:CreateFontString(nil, "OVERLAY")
        ns.StyleText(t, 12)
        t:SetPoint("CENTER")
        t:SetText(label)
        b:SetScript("OnClick", onClick)
        return b
    end
    Button("Close", 90, -14, function() frame:Hide() end)
    Button("Select all", 100, -112, function()
        if frame.edit then frame.edit:SetFocus(); frame.edit:HighlightText() end
    end)

    -- the text: Blizzard's scrolling edit box when this client has it, else a plain box with the last lines
    local ok, box = pcall(CreateFrame, "Frame", nil, frame, "ScrollingEditBoxTemplate")
    local scrollingEdit = ok and box and type(box.GetEditBox) == "function" and box:GetEditBox() or nil
    if scrollingEdit then
        box:SetPoint("TOPLEFT", 14, -58)
        box:SetPoint("BOTTOMRIGHT", -34, 46)
        frame.box = box
        frame.edit = scrollingEdit
        local okBar, bar = pcall(CreateFrame, "EventFrame", nil, frame, "MinimalScrollBar")
        if okBar and bar and _G.ScrollUtil and box.ScrollBox then
            bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
            bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 8, 0)
            pcall(_G.ScrollUtil.RegisterScrollBoxWithScrollBar, box.ScrollBox, bar)
        end
    else
        local eb = CreateFrame("EditBox", nil, frame)
        eb:SetMultiLine(true)
        eb:SetPoint("TOPLEFT", 14, -58)
        eb:SetPoint("BOTTOMRIGHT", -14, 46)
        frame.edit = eb
        frame.plain = true
    end
    local eb = frame.edit
    eb:SetAutoFocus(false)
    ns.StyleText(eb, 12, "")
    eb:SetTextColor(0.9, 0.92, 0.96)
    eb:SetScript("OnEscapePressed", function() frame:Hide() end)

    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "KutzCopyChatFrame") end
    frame:Hide()
end

local function Name(cf)
    local tab = cf and _G[cf:GetName() .. "Tab"]
    local label = tab and tab.GetText and tab:GetText()
    return (type(label) == "string" and label ~= "") and label or (cf and cf:GetName()) or "chat"
end

function ns.ChatCopyOpen(cf)
    if not frame then Build() end
    if not cf then
        local sel
        if _G.FCFDock_GetSelectedWindow and _G.GENERAL_CHAT_DOCK then
            local ok, w = pcall(_G.FCFDock_GetSelectedWindow, _G.GENERAL_CHAT_DOCK)
            if ok then sel = w end
        end
        cf = sel or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
    end
    if not cf then ns.Print("No chat window found to copy."); return 0, 0 end
    local text, lines, hidden, uncertain = ns.ChatCopyCapture(cf)
    if frame.plain then                             -- no scrolling box: keep the newest lines that fit
        local keep = {}
        for line in text:gmatch("[^\n]+") do keep[#keep + 1] = line end
        local first = math.max(1, #keep - 29)
        text = table.concat(keep, "\n", first)
    end
    local note = lines .. " line" .. (lines == 1 and "" or "s") .. " from \"" .. Name(cf) .. "\""
    if hidden > 0 then note = note .. "  -  " .. hidden .. " could not be read (the game hides some chat in certain situations)" end
    if uncertain then note = note .. "  -  the order of some lines may be off" end
    frame.title:SetText("Copy chat")
    frame.hint:SetText(note .. ".   Click in the text, press Ctrl+A then Ctrl+C.")
    if frame.box and frame.box.SetText then frame.box:SetText(text) else frame.edit:SetText(text) end
    frame:Show()
    frame.edit:SetFocus()
    frame.edit:HighlightText()
    return lines, hidden
end

ns.RegisterSlash("copy", function() ns.ChatCopyOpen() end)

---------------------------------------------------------------------------
-- The little button on each chat window (not the combat log) and the history length
---------------------------------------------------------------------------
function ns.ChatCopyButtonEnabled()
    local v = KutzUIDB and KutzUIDB.chatCopyButton
    if v == nil then return true end
    return v
end

local buttons = {}
local function MakeButton(cf)
    local b = CreateFrame("Button", nil, cf)
    b:SetSize(38, 16)
    b:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -2, -2)
    b:SetFrameStrata("HIGH")
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetColorTexture(0, 0, 0, 0.55); bg:SetAllPoints()
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetColorTexture(1, 0.82, 0, 0.18); hl:SetAllPoints()
    local t = b:CreateFontString(nil, "OVERLAY")
    ns.StyleText(t, 10)
    t:SetPoint("CENTER")
    t:SetText("copy")
    b:SetScript("OnClick", function() ns.ChatCopyOpen(cf) end)
    b:SetAlpha(0)
    b:EnableMouse(false)
    b.shown = false
    return b
end

local applied = {}                                    -- chat window -> history length we set
local acc = 0
local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    local enabled = ns.ChatCopyButtonEnabled()
    local want = KutzUIDB and KutzUIDB.chatHistoryLines
    for i = 1, NUM do
        local cf = _G["ChatFrame" .. i]
        if cf and i ~= 2 then                          -- ChatFrame2 is the combat log
            if enabled and cf:IsShown() then
                local b = buttons[cf]
                if not b then b = MakeButton(cf); buttons[cf] = b end
                local over = cf:IsMouseOver() or b:IsMouseOver()
                if over ~= b.shown then
                    b.shown = over
                    b:SetAlpha(over and 0.9 or 0)
                    b:EnableMouse(over)
                end
            elseif buttons[cf] and buttons[cf].shown then
                buttons[cf].shown = false
                buttons[cf]:SetAlpha(0)
                buttons[cf]:EnableMouse(false)
            end
            if want and applied[cf] ~= want and cf.SetMaxLines then
                if pcall(cf.SetMaxLines, cf, want) then applied[cf] = want end
            end
        end
    end
end)

ns.RegisterDebug(function()
    ns.Print(string.format("chat copy: button=%s, window=%s, history lines=%s",
        tostring(ns.ChatCopyButtonEnabled()), tostring(frame and (frame.plain and "plain box" or "scrolling box") or "not built yet"),
        tostring(KutzUIDB and KutzUIDB.chatHistoryLines or "Blizzard's default (128)")))
end)

end)
