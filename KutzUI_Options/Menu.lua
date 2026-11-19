---------------------------------------------------------------------------
-- KutzUI / Menu            (open it with  /kutz )
--
--   +-----------+---------------------------------------------------------+
--   | Unit      |  Page title                                             |
--   |  frames   |  one line saying what this page is for                  |
--   | Cast bars |  [live preview where there is something to look at]     |
--   | Fonts     |  Section ------------------   Section ------------------|
--   | Combat log|  controls                     controls                  |
--   | Chat      |                                                         |
--   | More      |                                                         |
--   +-----------+---------------------------------------------------------+
--   | [Toggle grid]      (status)                              [Close]    |
--   +---------------------------------------------------------------------+
--
-- * One page per thing you want to change; sections group the controls.
-- * Hover any control for a short explanation.
-- * Every change applies immediately; pages show what is set right now.
-- * Pages are laid out by a tiny "flow" toolkit (Page:Section / Slider / Check ...),
--   so adding or moving a control means adding or moving one line.
---------------------------------------------------------------------------
-- This file is the shell of the "KutzUI_Options" addon: the look, the widget toolkit and the
-- window. The pages live in Pages*.lua next to it. The whole addon loads when you first open
-- /kutz. It shares the main addon's table through the global KutzUI (each addon is given a
-- private table of its own, so the main addon publishes its one).
local ADDON_NAME = "KutzUI"
local ns = _G.KutzUI

local DB
local L                                  -- ns.L: the layout module's interface

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------
local W, H          = 820, 850
local SIDEBAR_W     = 165
local HEADER_H      = 46
local FOOTER_H      = 46
local PAD, GAP      = 22, 24
local CONTENT_W     = W - SIDEBAR_W
local BAR           = "Interface\\Buttons\\WHITE8X8"

local GOLD   = { 1.00, 0.82, 0.00 }
local GREY   = { 0.62, 0.65, 0.72 }
local WHITE  = { 1.00, 1.00, 1.00 }
local EDGE   = { 0.17, 0.18, 0.24 }       -- thin borders and divider lines
local DIM    = { 0.45, 0.47, 0.52 }       -- text of things that are switched off
local NAV    = { 0.86, 0.88, 0.93 }

-- Icons reinforce familiar actions; the wording stays on ordinary buttons.
local ACTION_ICONS = {
    ["Close"] = "x", ["Toggle grid"] = "grid-2x2", ["Reload UI"] = "rotate-cw",
    ["Save as"] = "save", ["Create export text"] = "upload", ["Import as profile"] = "download",
    ["<"] = "chevron-left", [">"] = "chevron-right", ["-"] = "minus", ["+"] = "plus",
}

local function Text(parent, size, justify, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns.StyleText(fs, size)
    fs:SetJustifyH(justify or "LEFT")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function Fill(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- flat button with a thin border and a hover highlight
local function Btn(parent, label, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.edge = Fill(b, "BACKGROUND", EDGE[1], EDGE[2], EDGE[3], 1)
    b.edge:SetAllPoints()
    b.bg = Fill(b, "BACKGROUND", 0.11, 0.12, 0.16, 1)
    b.bg:SetPoint("TOPLEFT", 1, -1)
    b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    b.hl = Fill(b, "HIGHLIGHT", GOLD[1], GOLD[2], GOLD[3], 0.12)
    b.hl:SetAllPoints()
    b.text = Text(b, 12, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    local name = ACTION_ICONS[label]
    if name then
        b.icon = ns.CreateIcon(b, name, 16)
        if label == "<" or label == ">" or label == "-" or label == "+" then
            b.text:Hide()
            b.icon:SetPoint("CENTER")
        else
            b.text:ClearAllPoints()
            b.text:SetPoint("CENTER", 11, 0)
            b.icon:SetPoint("RIGHT", b.text, "LEFT", -6, 0)
        end
    end
    b:SetScript("OnClick", onClick)
    return b
end

-- an on/off switch (a small track with a knob); returns a function  set(on)
local function MakeSwitch(parent)
    local track = Fill(parent, "BACKGROUND", 0.22, 0.23, 0.29, 1)
    track:SetSize(34, 16)
    track:SetPoint("LEFT")
    local knob = Fill(parent, "ARTWORK", 0.65, 0.67, 0.72, 1)
    knob:SetSize(12, 12)
    return function(on)
        if on then track:SetColorTexture(0.80, 0.64, 0.00, 1) else track:SetColorTexture(0.22, 0.23, 0.29, 1) end
        if on then knob:SetColorTexture(1.00, 0.97, 0.85, 1) else knob:SetColorTexture(0.65, 0.67, 0.72, 1) end
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", track, "LEFT", on and 20 or 2, 0)
    end, track
end

local function Tip(widget, text)
    if not text then return end
    widget:EnableMouse(true)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function RGBToHex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Blizzard's color picker; live updates while you drag, Cancel puts the old color back
local function PickColor(startHex, apply)
    local r, g, b = HexToRGB(startHex)
    local function onChange()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        apply(RGBToHex(nr, ng, nb))
    end
    local function onCancel() apply(startHex) end
    local ok
    if ColorPickerFrame.SetupColorPickerAndShow then
        ok = pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame,
            { r = r, g = g, b = b, hasOpacity = false, swatchFunc = onChange, cancelFunc = onCancel })
    else
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc, ColorPickerFrame.hasOpacity = onChange, onCancel, false
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
        ok = true
    end
    if not ok then ns.Print("Couldn't open the color picker on this client.") end
end

---------------------------------------------------------------------------
-- Sliders must be movable from code without firing their own callback
---------------------------------------------------------------------------
local silent = false

local function Clamp(slider, v)
    v = math.floor(v + 0.5)
    local lo, hi = slider:GetMinMaxValues()
    return math.max(lo, math.min(hi, v))
end

local function ShowSliderValue(slider, v)
    local vt = slider.valueText
    if not (vt.HasFocus and vt:HasFocus()) then      -- never overwrite what is being typed
        vt:SetText(slider.fmt and slider.fmt(v) or tostring(v))
    end
    if slider.fill then                      -- the gold part of the track shows how far along it is
        local lo, hi = slider:GetMinMaxValues()
        local frac = (hi > lo) and math.max(0, math.min(1, (v - lo) / (hi - lo))) or 0
        slider.fill:SetWidth(math.max(1, frac * slider.fullW))
    end
end

local function SetSlider(slider, v)
    if slider:GetValue() ~= v then
        silent = true
        slider:SetValue(v)
        silent = false
    end
    ShowSliderValue(slider, v)
end

---------------------------------------------------------------------------
-- The flow toolkit: a Page lays controls out top to bottom in 1 or 2 columns
---------------------------------------------------------------------------
local Page = {}
Page.__index = Page

local content                           -- the area right of the sidebar (set when the window is built)

local function NewPage(title, desc)
    local p = setmetatable({ refreshers = {} }, Page)
    p.frame = CreateFrame("Frame", nil, content)
    p.frame:SetAllPoints(content)
    p.frame:Hide()

    local t = Text(p.frame, 16, "LEFT", GOLD)
    t:SetPoint("TOPLEFT", PAD, -PAD)
    t:SetText(title)
    local d = Text(p.frame, 11, "LEFT", GREY)
    d:SetPoint("TOPLEFT", PAD, -PAD - 24)
    d:SetWidth(CONTENT_W - 2 * PAD)
    d:SetWordWrap(true)
    d:SetText(desc)

    p.fullW = CONTENT_W - 2 * PAD
    p.colW = p.fullW
    p.cols = 1
    p.ys = { -(PAD + 56) }
    p.cur = 1
    return p
end

function Page:Refresh()
    for i = 1, #self.refreshers do self.refreshers[i]() end
end

function Page:Lowest()
    local m = self.ys[1]
    for i = 2, #self.ys do if self.ys[i] < m then m = self.ys[i] end end
    return m
end

-- split the rest of the page into n columns (call before adding controls)
function Page:Columns(n)
    local y = self:Lowest()
    self.cols = n
    self.colW = math.floor((self.fullW - (n - 1) * GAP) / n)
    self.ys = {}
    for i = 1, n do self.ys[i] = y end
    self.cur = 1
end

function Page:Col(i) self.cur = i end

-- go back to one full-width column below everything added so far
function Page:Below()
    local y = self:Lowest() - 8
    self.cols, self.colW, self.ys, self.cur = 1, self.fullW, { y }, 1
end

function Page:X() return PAD + (self.cur - 1) * (self.colW + GAP) end
function Page:Y() return self.ys[self.cur] end
function Page:Advance(h) self.ys[self.cur] = self.ys[self.cur] - h end

function Page:Section(label)
    local x, y, w = self:X(), self:Y(), self.colW
    local mark = Fill(self.frame, "ARTWORK", GOLD[1], GOLD[2], GOLD[3], 1)
    mark:SetSize(3, 13)
    mark:SetPoint("TOPLEFT", x, y - 5)
    local fs = Text(self.frame, 12, "LEFT", GOLD)
    fs:SetPoint("TOPLEFT", x + 10, y - 4)
    fs:SetText(string.upper(label))
    local line = Fill(self.frame, "ARTWORK", EDGE[1], EDGE[2], EDGE[3], 1)
    line:SetPoint("TOPLEFT", x, y - 23)
    line:SetSize(w, 1)
    self:Advance(32)
end

function Page:Note(text, lines)
    local fs = Text(self.frame, 11, "LEFT", GREY)
    fs:SetPoint("TOPLEFT", self:X(), self:Y())
    fs:SetWidth(self.colW)
    fs:SetWordWrap(true)
    fs:SetText(text)
    self:Advance((lines or 2) * 14 + 8)
    return fs
end

-- Search reads these. indexingKey is the page being built; tabLabels is filled when the sidebar is.
local optionIndex = {}
local indexingKey
local tabLabels = {}

local function NoteOption(page, label, tip)
    if not indexingKey or type(label) ~= "string" or label == "" then return end
    if label:match("^[%+%<%>%-]+$") then return end
    optionIndex[#optionIndex + 1] = {
        label = label, tip = tip or "", page = indexingKey,
        pageName = tabLabels[indexingKey] or "",
        sub = page and page.buildingSub or nil,
    }
end

function Page:Check(label, get, set, tip)
    local x, y, w = self:X(), self:Y(), self.colW
    local b = CreateFrame("Button", nil, self.frame)
    b:SetSize(w, 24)
    b:SetPoint("TOPLEFT", x, y)
    b.hl = Fill(b, "HIGHLIGHT", 1, 1, 1, 0.04)
    b.hl:SetAllPoints()

    local setSwitch, track = MakeSwitch(b)

    local fs = Text(b, 12, "LEFT")
    fs:SetPoint("LEFT", track, "RIGHT", 10, 0)
    fs:SetWidth(w - 50)
    fs:SetWordWrap(false)
    fs:SetText(label)

    local page = self
    b:SetScript("OnClick", function() set(not get()); page:Refresh() end)
    Tip(b, tip)
    NoteOption(self, label, tip)
    self.refreshers[#self.refreshers + 1] = function() setSwitch(get() and true or false) end
    self:Advance(28)
    return b
end

-- several checkboxes in a grid (perRow per row); items = { {label=, get=, set=, tip=}, ... }
function Page:CheckGrid(items, perRow)
    perRow = perRow or 2
    local x, y, w = self:X(), self:Y(), self.colW
    local cell = math.floor(w / perRow)
    local page = self
    for i, item in ipairs(items) do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local b = CreateFrame("Button", nil, self.frame)
        b:SetSize(cell - 4, 24)
        b:SetPoint("TOPLEFT", x + col * cell, y - row * 28)
        b.hl = Fill(b, "HIGHLIGHT", 1, 1, 1, 0.04)
        b.hl:SetAllPoints()
        local setSwitch, track = MakeSwitch(b)
        local fs = Text(b, 12, "LEFT")
        fs:SetPoint("LEFT", track, "RIGHT", 10, 0)
        fs:SetWidth(cell - 54); fs:SetWordWrap(false)
        fs:SetText(item.label)
        b:SetScript("OnClick", function() item.set(not item.get()); page:Refresh() end)
        Tip(b, item.tip)
        NoteOption(self, item.label, item.tip)
        self.refreshers[#self.refreshers + 1] = function() setSwitch(item.get() and true or false) end
    end
    self:Advance(math.ceil(#items / perRow) * 28 + 2)
end

-- label, a value readout, [-] slider [+]
-- opts: step (default 1), wheel (mouse-wheel step, default 10), fmt(v)->text, bounds()->lo,hi, tip
function Page:Slider(label, lo, hi, get, set, opts)
    opts = opts or {}
    local x, y, w, f = self:X(), self:Y(), self.colW, self.frame
    local wheel = opts.wheel or 10

    local title = Text(f, 12, "LEFT")
    title:SetPoint("TOPLEFT", x, y)
    title:SetWidth(w - 70)
    title:SetWordWrap(false)
    title:SetText(label)
    NoteOption(self, label, opts.tip)
    -- the number is a box: click it, type a value, press Enter (Esc puts the old one back)
    local value = CreateFrame("EditBox", nil, f)
    value:SetSize(76, 18)
    value:SetPoint("TOPRIGHT", f, "TOPLEFT", x + w, y + 3)
    value:SetAutoFocus(false)
    value:SetJustifyH("RIGHT")
    value:SetMaxLetters(9)
    ns.StyleText(value, 12, "")
    value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local vbox = Fill(value, "BACKGROUND", 0.04, 0.04, 0.07, 1)
    vbox:SetPoint("TOPLEFT", -4, 1); vbox:SetPoint("BOTTOMRIGHT", 3, -1)
    vbox:Hide()
    local vline = Fill(value, "BORDER", 0.35, 0.36, 0.44, 1)       -- the underline says "type here"
    vline:SetPoint("BOTTOMLEFT", 0, -1); vline:SetPoint("BOTTOMRIGHT", 0, -1); vline:SetHeight(1)

    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(16)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", x + 28, y - 24)
    s:SetPoint("TOPRIGHT", f, "TOPLEFT", x + w - 28, y - 24)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s.valueText, s.fmt = value, opts.fmt

    local track = Fill(s, "BACKGROUND", 0.20, 0.21, 0.27, 1)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
    s.fullW = math.max(1, w - 56)            -- the slider runs from x + 28 to x + w - 28
    s.fill = Fill(s, "BORDER", GOLD[1], GOLD[2], GOLD[3], 0.85)
    s.fill:SetPoint("LEFT", track, "LEFT")
    s.fill:SetHeight(4)
    s.fill:SetWidth(1)
    s:SetThumbTexture(BAR)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(10, 20)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])

    local page = self
    local function onChange(v)
        v = Clamp(s, v)
        set(v)
        page:Refresh()
    end
    s:SetScript("OnValueChanged", function(_, v) if not silent then onChange(v) end end)
    local function ApplyTyped()
        if not value.typed then return end
        value.typed = false
        local n = tonumber((value:GetText() or ""):match("-?%d+%.?%d*"))
        if n then onChange(n) else page:Refresh() end
    end
    value:SetScript("OnEditFocusGained", function(self2)
        self2:SetText(tostring(s:GetValue())); self2:HighlightText(); vbox:Show(); self2.typed = false
    end)
    value:SetScript("OnTextChanged", function(self2, user) if user then self2.typed = true end end)
    value:SetScript("OnEnterPressed", function(self2) ApplyTyped(); self2:ClearFocus() end)
    value:SetScript("OnEscapePressed", function(self2) self2.typed = false; self2:ClearFocus() end)
    value:SetScript("OnEditFocusLost", function(self2) ApplyTyped(); vbox:Hide(); page:Refresh() end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self2, delta) onChange(self2:GetValue() + delta * wheel) end)

    local minus = Btn(f, "-", 22, 20, function() onChange(s:GetValue() - (opts.step or 1)) end)
    minus:SetPoint("TOPLEFT", x, y - 22)
    local plus = Btn(f, "+", 22, 20, function() onChange(s:GetValue() + (opts.step or 1)) end)
    plus:SetPoint("TOPLEFT", x + w - 22, y - 22)
    Tip(minus, "Decrease " .. label); Tip(plus, "Increase " .. label)

    Tip(s, opts.tip and (opts.tip .. "  (Click the number to type a value.)") or "Click the number to type a value.")
    self.refreshers[#self.refreshers + 1] = function()
        if opts.bounds then
            local a, b = opts.bounds()
            silent = true
            s:SetMinMaxValues(a, b)
            silent = false
        end
        SetSlider(s, get())
    end
    self:Advance(52)
    return s
end

-- boxes you type a number into (2 per row): items = { {label=, get=, set=, tip=}, ... }
-- Enter or clicking away applies it; Esc puts the old number back; Tab jumps to the next box.
function Page:Numbers(items)
    local x, y, w, f = self:X(), self:Y(), self.colW, self.frame
    local cell = math.floor(w / 2)
    local page = self
    local boxes = {}
    for i, item in ipairs(items) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local cx, cy = x + col * cell, y - row * 50

        local label = Text(f, 11, "LEFT", GREY)
        label:SetPoint("TOPLEFT", cx, cy)
        label:SetText(item.label)

        local holder = CreateFrame("Frame", nil, f)
        holder:SetSize(cell - 14, 24)
        holder:SetPoint("TOPLEFT", cx, cy - 16)
        local edge = Fill(holder, "BACKGROUND", 0.35, 0.35, 0.40, 1)
        edge:SetAllPoints()
        local inner = Fill(holder, "BORDER", 0.05, 0.05, 0.08, 1)
        inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)

        local eb = CreateFrame("EditBox", nil, holder)
        eb:SetPoint("TOPLEFT", 6, 0); eb:SetPoint("BOTTOMRIGHT", -6, 0)
        eb:SetAutoFocus(false)
        eb:SetNumeric(true)
        eb:SetMaxLetters(5)
        eb:SetJustifyH("CENTER")
        ns.StyleText(eb, 13, "")
        eb:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

        local function Show() eb:SetText(tostring(item.get())) end
        local function Apply()
            local v = tonumber(eb:GetText())
            if v then item.set(math.floor(v + 0.5)) end
            page:Refresh()
        end
        eb:SetScript("OnEnterPressed", function(self2) Apply(); self2:ClearFocus() end)
        eb:SetScript("OnEditFocusLost", function() Apply() end)
        eb:SetScript("OnEscapePressed", function(self2) Show(); self2:ClearFocus() end)
        eb:SetScript("OnTabPressed", function(self2)
            local nextBox = boxes[(i % #boxes) + 1]
            if nextBox then nextBox:SetFocus() end
        end)
        eb:SetScript("OnEditFocusGained", function(self2) self2:HighlightText() end)
        Tip(holder, item.tip)
        boxes[i] = eb
        self.refreshers[#self.refreshers + 1] = function() if not eb:HasFocus() then Show() end end
    end
    self:Advance(math.ceil(#items / 2) * 50 + 4)
end

-- a row of buttons: list = { {text=, w=, click=, tip=}, ... }
function Page:Buttons(list)
    local x, y = self:X(), self:Y()
    local page = self
    for _, spec in ipairs(list) do
        local width = spec.w or 120
        local b = Btn(self.frame, spec.text, width, 24, function() spec.click(); page:Refresh() end)
        b:SetPoint("TOPLEFT", x, y)
        Tip(b, spec.tip)
        NoteOption(page, spec.text, spec.tip)
        x = x + width + 8
    end
    self:Advance(34)
end

-- choose one of several items with [<] [>]; shows its name and (optionally) a preview
-- opts: tip, makePreview(parent, x, y, w) -> update(item) , previewBelow (preview gets its own line)
function Page:Cycler(label, items, getKey, setKey, opts)
    opts = opts or {}
    local x, y, w, f = self:X(), self:Y(), self.colW, self.frame

    local title = Text(f, 11, "LEFT", GREY)
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)
    NoteOption(self, label, opts.tip)
    local nameText = Text(f, 13, "LEFT", WHITE)
    nameText:SetPoint("TOPLEFT", x, y - 17)
    nameText:SetWidth(w - 130)
    nameText:SetWordWrap(false)

    local function Index()
        local key = getKey()
        for i, it in ipairs(items) do if it.key == key then return i end end
        return 1
    end
    local page = self
    local update
    local function Show()
        local item = items[Index()]
        nameText:SetText(item.name)
        if update then update(item) end
    end
    local function Step(delta)
        local i = Index() + delta
        if i < 1 then i = #items elseif i > #items then i = 1 end
        setKey(items[i].key)
        page:Refresh()
    end

    local prev = Btn(f, "<", 26, 22, function() Step(-1) end)
    prev:SetPoint("TOPLEFT", x + w - 56, y - 14)
    local nxt = Btn(f, ">", 26, 22, function() Step(1) end)
    nxt:SetPoint("TOPLEFT", x + w - 26, y - 14)
    Tip(prev, opts.tip or ("Previous " .. label)); Tip(nxt, opts.tip or ("Next " .. label))

    local height = 46
    if opts.makePreview then
        if opts.previewBelow then
            update = opts.makePreview(f, x, y - 42, w)
            height = 70
        else
            update = opts.makePreview(f, x + w - 56 - 8 - 100, y - 17, 100)
        end
    end
    self.refreshers[#self.refreshers + 1] = Show
    self:Advance(height)
end

-- a grid of color swatches; clicking one opens the color picker
-- defs = { {key=, label=} ... }   getHex(key) / setHex(key, hex)
function Page:Swatches(defs, getHex, setHex, perRow, afterChange)
    perRow = perRow or 3
    local x, y, w = self:X(), self:Y(), self.colW
    local cell = math.floor(w / perRow)
    local page = self
    for i, d in ipairs(defs) do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local b = CreateFrame("Button", nil, self.frame)
        b:SetSize(cell - 4, 22)
        b:SetPoint("TOPLEFT", x + col * cell, y - row * 26)
        local frame = Fill(b, "BACKGROUND", 0.45, 0.45, 0.50, 1)
        frame:SetSize(20, 20); frame:SetPoint("LEFT")
        local sw = Fill(b, "ARTWORK", 1, 1, 1, 1)
        sw:SetSize(18, 18); sw:SetPoint("CENTER", frame)
        local fs = Text(b, 11, "LEFT")
        fs:SetPoint("LEFT", frame, "RIGHT", 6, 0)
        fs:SetWidth(cell - 32); fs:SetWordWrap(false)
        fs:SetText(d.label)
        b:SetScript("OnClick", function()
            PickColor(getHex(d.key), function(hex)
                setHex(d.key, hex)
                if afterChange then afterChange() end
                page:Refresh()
            end)
        end)
        Tip(b, "Click to choose the color of: " .. d.label)
        self.refreshers[#self.refreshers + 1] = function() sw:SetColorTexture(HexToRGB(getHex(d.key))) end
    end
    self:Advance(math.ceil(#defs / perRow) * 26 + 4)
end

-- a dark box showing sample lines (full width; use after Page:Below() or on a 1-column page)
-- render(raw) -> text [, r, g, b]    sizeFn() -> font size     flags: "" (no outline)
function Page:Preview(lines, render, sizeFn)
    local x, y, w = self:X(), self:Y(), self.colW
    local lineH = 16
    local box = CreateFrame("Frame", nil, self.frame)
    box:SetSize(w, lineH * #lines + 14)
    box:SetPoint("TOPLEFT", x, y)
    local bg = Fill(box, "BACKGROUND", 0.02, 0.02, 0.03, 1)
    bg:SetAllPoints()
    local fss = {}
    for i = 1, #lines do
        local fs = box:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("TOPLEFT", 8, -7 - (i - 1) * lineH)
        fs:SetWidth(w - 16)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fss[i] = fs
    end
    self.refreshers[#self.refreshers + 1] = function()
        local size = sizeFn()
        for i, raw in ipairs(lines) do
            ns.StyleText(fss[i], size, "")
            local text, r, g, b = render(raw)
            fss[i]:SetTextColor(r or 1, g or 1, b or 1)
            fss[i]:SetText(text)
        end
    end
    self:Advance(lineH * #lines + 22)
end

-- Sub-tabs: split a long page into panes with a row of small tabs under the title.
-- p:SubTab("key", "Label") starts a pane; the controls added after it (until the next SubTab) are in it.
function Page:SubTab(key, label)
    self.buildingSub = key
    if not self.subs then
        self.main = self.frame
        self.subs = {}
        self.subX = 0
        self.lowestAll = 0
        self.subBar = CreateFrame("Frame", nil, self.main)
        self.subBar:SetPoint("TOPLEFT", PAD, -(PAD + 52))
        self.subBar:SetSize(self.fullW, 26)
        local base = Fill(self.subBar, "BORDER", EDGE[1], EDGE[2], EDGE[3], 1)
        base:SetPoint("BOTTOMLEFT"); base:SetPoint("BOTTOMRIGHT"); base:SetHeight(1)
    else
        self.lowestAll = math.min(self.lowestAll, self:Lowest())
    end
    local pane = CreateFrame("Frame", nil, self.main)
    pane:SetAllPoints(self.main)
    pane:Hide()
    self.frame = pane

    local width = math.max(76, 8 * #label + 28)
    local b = CreateFrame("Button", nil, self.subBar)
    b:SetSize(width, 26)
    b:SetPoint("BOTTOMLEFT", self.subX, 0)
    self.subX = self.subX + width + 4
    b.bg = Fill(b, "BACKGROUND", 0.08, 0.09, 0.12, 1)
    b.bg:SetAllPoints()
    b.hl = Fill(b, "HIGHLIGHT", 1, 1, 1, 0.06)
    b.hl:SetAllPoints()
    b.under = Fill(b, "ARTWORK", GOLD[1], GOLD[2], GOLD[3], 1)
    b.under:SetPoint("BOTTOMLEFT"); b.under:SetPoint("BOTTOMRIGHT"); b.under:SetHeight(2)
    b.text = Text(b, 12, "CENTER")
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(label)
    local page = self
    b:SetScript("OnClick", function() page:ShowSub(key) end)
    self.subs[#self.subs + 1] = { key = key, pane = pane, btn = b }
    if not self.activeSub then self.activeSub = key end
    self:ShowSub(self.activeSub, true)

    -- a fresh layout under the tab row
    self.cols, self.colW, self.ys, self.cur = 1, self.fullW, { -(PAD + 52 + 38) }, 1
end

function Page:ShowSub(key, quiet)
    self.activeSub = key
    for _, s in ipairs(self.subs) do
        local on = (s.key == key)
        s.pane:SetShown(on)
        s.btn.under:SetShown(on)
        if on then s.btn.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else s.btn.text:SetTextColor(GREY[1], GREY[2], GREY[3]) end
        s.btn.bg:SetColorTexture(on and 0.13 or 0.08, on and 0.14 or 0.09, on and 0.19 or 0.12, 1)
    end
    if not quiet then self:Refresh() end
end

---------------------------------------------------------------------------
-- Window, sidebar, footer
---------------------------------------------------------------------------
local window, footerStatus
local pages, tabButtons, tabKeys = {}, {}, {}
local builders = {}            -- page key -> function that builds it (each page is built the first time it is opened)
local currentTab

-- which module a page belongs to (its sidebar label dims when that module is switched off)
local TAB_MODULE = { frames = "frames", cast = "castbars", combat = "combatlog", chat = "chat",
    windows = "windows", actionbars = "actionbars", minimap = "minimap", damagemeter = "damagemeter", fps = "fpsreadout", tooltipplace = "movers", convenience = "convenience", nameplates = "nameplates", party = "partytargets" }
local TAB_ICONS = {
    package = "package", profiles = "user-round", modules = "sliders-horizontal",
    frames = "user-round", cast = "wand-sparkles", party = "users", nameplates = "panel-top",
    combat = "scroll-text", damagemeter = "chart-no-axes-combined", fonts = "type",
    chat = "messages-square", windows = "panels-top-left", actionbars = "grid-2x2",
    minimap = "compass", tooltipplace = "mouse-pointer-2", more = "backpack", fps = "gauge",
    convenience = "sparkles", gamesettings = "settings-2", gamesettings2 = "volume-2",
}

local function TabTextColor(key, on)
    local b = tabButtons[key]
    if not b then return end
    local mod = TAB_MODULE[key]
    local color = on and GOLD or (mod and not ns.Enabled(mod) and DIM) or NAV
    b.text:SetTextColor(color[1], color[2], color[3])
    if b.icon then b.icon:SetVertexColor(color[1], color[2], color[3]) end
end

local function BuildPage(key)
    if pages[key] or not builders[key] then return end
    indexingKey = key
    builders[key]()
    indexingKey = nil
    local name = tabLabels[key]
    if name then
        optionIndex[#optionIndex + 1] = { label = name, tip = "", page = key, pageName = name, isPage = true }
    end
end

local function ShowTab(key)
    currentTab = key
    BuildPage(key)
    for k, p in pairs(pages) do (p.main or p.frame):SetShown(k == key) end     -- (a page with sub-tabs keeps its whole-page frame in .main)
    for k, b in pairs(tabButtons) do
        local on = (k == key)
        b.selected:SetShown(on)
        b.bg:SetColorTexture(on and 0.12 or 0.07, on and 0.13 or 0.075, on and 0.18 or 0.10, 1)
        TabTextColor(k, on)
    end
    if pages[key] then pages[key]:Refresh() end
end

local function RefreshCurrent()
    if currentTab and pages[currentTab] then pages[currentTab]:Refresh() end
end

function ns.UpdateMenuStatus(pending)
    if footerStatus then
        footerStatus:SetText(pending and "In combat - the frames move when combat ends" or "")
    end
end

local sidebarY = -10
local sidebarHeaders = {}

-- a small caps heading that groups the tabs under it
local function AddHeader(label)
    local t = Text(window.sidebar, 10, "LEFT", DIM)
    t:SetPoint("TOPLEFT", 16, sidebarY - 8)
    t:SetText(string.upper(label))
    sidebarHeaders[#sidebarHeaders + 1] = t
    sidebarY = sidebarY - 24
end

local function AddTab(key, label)
    local b = CreateFrame("Button", nil, window.sidebar)
    b:SetSize(SIDEBAR_W, 28)
    b:SetPoint("TOPLEFT", 0, sidebarY)
    sidebarY = sidebarY - 29
    b.bg = Fill(b, "BACKGROUND", 0.07, 0.075, 0.10, 1)
    b.bg:SetAllPoints()
    b.hl = Fill(b, "HIGHLIGHT", 1, 1, 1, 0.06)
    b.hl:SetAllPoints()
    b.selected = Fill(b, "ARTWORK", GOLD[1], GOLD[2], GOLD[3], 1)
    b.selected:SetPoint("TOPLEFT"); b.selected:SetPoint("BOTTOMLEFT"); b.selected:SetWidth(3)
    b.selected:Hide()
    b.icon = ns.CreateIcon(b, TAB_ICONS[key], 16)
    b.icon:SetPoint("LEFT", b, "LEFT", 18, 0)
    b.text = Text(b, 13, "LEFT")
    b.text:SetPoint("LEFT", 42, 0)
    b.text:SetPoint("RIGHT", -10, 0)
    b.text:SetWordWrap(false)
    b.text:SetText(label)
    tabLabels[key] = label
    b:SetScript("OnClick", function() ShowTab(key) end)
    tabButtons[key] = b
    tabKeys[#tabKeys + 1] = key
    TabTextColor(key, false)
end

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------
-- A page whose module is switched off shows this instead of its controls.
-- Returns true when it did (the builder should stop there).
local function Off(p, key, what)
    if ns.Enabled(key) then return false end
    p:Note(what .. " is switched off, so there is nothing to set here. Turn it on in the UI features tab, then press Reload UI there.", 3)
    p:Buttons({ { text = "Open the UI features tab", w = 190, click = function() ShowTab("modules") end } })
    return true
end

-- a text box with the window's look
local function MakeEditBox(parent, w)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, 24)
    local edge = Fill(holder, "BACKGROUND", EDGE[1], EDGE[2], EDGE[3], 1)
    edge:SetAllPoints()
    local inner = Fill(holder, "BORDER", 0.05, 0.05, 0.08, 1)
    inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
    local eb = CreateFrame("EditBox", nil, holder)
    eb:SetPoint("TOPLEFT", 6, 0); eb:SetPoint("BOTTOMRIGHT", -6, 0)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(0)
    ns.StyleText(eb, 12, "")
    eb:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return eb, holder
end

---------------------------------------------------------------------------
-- Shared with the page files (Pages*.lua, loaded after this one).
-- DB and L are filled in when the window is first opened, before any page is built.
---------------------------------------------------------------------------
local M = {
    NewPage = NewPage, pages = pages, builders = builders, Off = Off, ShowTab = ShowTab,
    Text = Text, Fill = Fill, Btn = Btn, Tip = Tip,
    GOLD = GOLD, GREY = GREY, WHITE = WHITE, EDGE = EDGE,
    HexToRGB = HexToRGB, ADDON_NAME = ADDON_NAME, MakeEditBox = MakeEditBox,
}
ns._opt = M

---------------------------------------------------------------------------
-- Build the window (first time it is opened)
---------------------------------------------------------------------------
local SEARCH_ROWS = 12

local function Lower(s)
    return type(s) == "string" and s:lower() or ""
end

local function FindOptions(query)
    local q = Lower(strtrim(query or ""))
    if q == "" then return nil end
    for _, key in ipairs(tabKeys) do BuildPage(key) end
    local hits = {}
    for _, opt in ipairs(optionIndex) do
        local label = Lower(opt.label)
        local score
        if label == q then score = 0
        elseif #q <= #label and label:sub(1, #q) == q then score = 1
        elseif label:find(q, 1, true) then score = 2
        elseif opt.tip ~= "" and Lower(opt.tip):find(q, 1, true) then score = 4
        end
        if score then hits[#hits + 1] = { opt = opt, score = score } end
    end
    table.sort(hits, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.opt.isPage ~= b.opt.isPage then return not a.opt.isPage end
        return a.opt.label < b.opt.label
    end)
    return hits
end

local function InstallSidebarSearch(sidebar)
    local eb, holder = MakeEditBox(sidebar, SIDEBAR_W - 16)
    holder:SetPoint("TOPLEFT", 8, -8)
    local placeholder = Text(holder, 11, "LEFT", DIM)
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetText("Search")

    local resultHost = CreateFrame("Frame", nil, sidebar)
    resultHost:SetPoint("TOPLEFT", 0, -36)
    resultHost:SetPoint("BOTTOMRIGHT")
    resultHost:Hide()
    local empty = Text(resultHost, 11, "LEFT", GREY)
    empty:SetPoint("TOPLEFT", 12, -8)
    empty:SetWidth(SIDEBAR_W - 24)
    empty:SetWordWrap(true)
    empty:SetText("No matching setting")
    empty:Hide()

    local function OpenOption(opt)
        eb:SetText("")
        eb:ClearFocus()
        ShowTab(opt.page)
        local p = pages[opt.page]
        if opt.sub and p and p.ShowSub then p:ShowSub(opt.sub) end
    end

    local rows = {}
    for i = 1, SEARCH_ROWS do
        local b = CreateFrame("Button", nil, resultHost)
        b:SetSize(SIDEBAR_W, 40)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 40)
        b.hl = Fill(b, "HIGHLIGHT", 1, 1, 1, 0.06)
        b.hl:SetAllPoints()
        b.title = Text(b, 12, "LEFT", WHITE)
        b.title:SetPoint("TOPLEFT", 12, -4)
        b.title:SetPoint("RIGHT", -8, 0)
        b.title:SetWordWrap(false)
        b.where = Text(b, 10, "LEFT", GREY)
        b.where:SetPoint("BOTTOMLEFT", 12, 4)
        b.where:SetPoint("RIGHT", -8, 0)
        b.where:SetWordWrap(false)
        b:SetScript("OnClick", function(self) if self._opt then OpenOption(self._opt) end end)
        b:SetScript("OnEnter", function(self)
            if not (self._opt and self._opt.tip ~= "") then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self._opt.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        rows[i] = b
    end

    local function ApplySearch(text)
        local found = FindOptions(text)
        local searching = found ~= nil
        for _, h in ipairs(sidebarHeaders) do h:SetShown(not searching) end
        for _, b in pairs(tabButtons) do b:SetShown(not searching) end
        resultHost:SetShown(searching)
        if not searching then
            for _, b in ipairs(rows) do b._opt = nil; b:Hide() end
            return
        end
        local n = math.min(SEARCH_ROWS, #found)
        empty:SetShown(n == 0)
        for i = 1, SEARCH_ROWS do
            local b, hit = rows[i], found[i]
            if i <= n then
                b._opt = hit.opt
                b.title:SetText(hit.opt.label)
                b.where:SetText(hit.opt.isPage and "Open this screen" or (hit.opt.pageName or ""))
                b:Show()
            else
                b._opt = nil
                b:Hide()
            end
        end
    end

    eb:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        placeholder:SetShown(text == "")
        ApplySearch(text)
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    Tip(holder, "Find a setting by name. Click a result to open its screen.")
end

local function CreateWindow()
    L = ns.L
    DB = KutzUIDB
    M.L = L
    M.DB = DB

    window = CreateFrame("Frame", "KutzLayoutPanel", UIParent)
    window:SetSize(W, H)
    window:SetPoint("TOP", UIParent, "TOP", 0, -30)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    -- on a short screen, shrink the whole window to fit
    local fit = (UIParent:GetHeight() - 40) / H
    if fit < 1 then window:SetScale(math.max(0.5, fit)) end

    local border = Fill(window, "BACKGROUND", EDGE[1], EDGE[2], EDGE[3], 1)
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    local bg = Fill(window, "BACKGROUND", 0.045, 0.05, 0.07, 0.97)
    bg:SetAllPoints()

    -- header
    local title = Text(window, 15, "LEFT", GOLD)
    title:SetPoint("TOPLEFT", 18, -15)
    title:SetText("Kutz UI")
    local sub = Text(window, 11, "LEFT", GREY)
    sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
    sub:SetText("settings  -  drag the window by any empty spot")
    local getMeta = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local version = getMeta and getMeta(ADDON_NAME, "Version")
    if version then
        local ver = Text(window, 11, "RIGHT", DIM)
        ver:SetPoint("TOPRIGHT", -18, -18)
        ver:SetText("v" .. version)
    end
    local headerLine = Fill(window, "ARTWORK", 0.2, 0.22, 0.28, 1)
    headerLine:SetPoint("TOPLEFT", 0, -HEADER_H); headerLine:SetPoint("TOPRIGHT", 0, -HEADER_H); headerLine:SetHeight(1)

    -- sidebar
    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 0, -HEADER_H - 1)
    sidebar:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
    sidebar:SetWidth(SIDEBAR_W)
    local sbg = Fill(sidebar, "BACKGROUND", 0.07, 0.075, 0.10, 1)
    sbg:SetAllPoints()
    window.sidebar = sidebar

    -- page area
    content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", SIDEBAR_W, -HEADER_H - 1)
    content:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)

    -- footer
    local footerLine = Fill(window, "ARTWORK", 0.2, 0.22, 0.28, 1)
    footerLine:SetPoint("BOTTOMLEFT", 0, FOOTER_H); footerLine:SetPoint("BOTTOMRIGHT", 0, FOOTER_H); footerLine:SetHeight(1)
    local gridBtn = Btn(window, "Toggle grid", 120, 26, function() ns.ToggleGrid() end)
    gridBtn:SetPoint("BOTTOMLEFT", 16, 10)
    Tip(gridBtn, "Shows a faint alignment grid over the whole screen. The red lines are the middle of the screen.")
    local closeBtn = Btn(window, "Close", 100, 26, function() window:Hide() end)
    closeBtn:SetPoint("BOTTOMRIGHT", -16, 10)
    footerStatus = Text(window, 11, "CENTER", { 1, 0.5, 0.2 })
    footerStatus:SetPoint("BOTTOM", 0, 16)

    local needed = { "frames", "cast", "party", "nameplates", "fonts", "chat", "combat", "actionbars", "minimap", "damagemeter", "fps", "windows", "tooltipplace", "more", "convenience", "gamesettings", "gamesettings2", "profiles", "modules", "package" }
    for _, k in ipairs(needed) do
        if not builders[k] then error("KutzUI settings is missing the " .. k .. " page") end
    end

    InstallSidebarSearch(sidebar)
    sidebarY = -36

    AddHeader("Setup")
    AddTab("package", "KutzUI package")
    AddTab("profiles", "Profiles")
    AddTab("modules", "UI features")
    AddHeader("Units and combat")
    AddTab("frames", "Unit frames")
    AddTab("cast", "Cast bars")
    AddTab("party", "Party and targets")
    AddTab("nameplates", "Nameplates")
    AddTab("combat", "Combat log")
    AddTab("damagemeter", "Damage meter")
    AddHeader("Interface")
    AddTab("fonts", "Fonts")
    AddTab("chat", "Chat")
    AddTab("windows", "Window positions")
    AddTab("actionbars", "Action bars")
    AddTab("minimap", "Minimap")
    AddTab("tooltipplace", "Tooltip placement")
    AddTab("more", "Tooltips and bags")
    AddTab("fps", "FPS and latency")
    AddTab("convenience", "Convenience")
    AddHeader("Game")
    AddTab("gamesettings", "Game settings")
    AddTab("gamesettings2", "Sound / advanced")

    window:SetScript("OnShow", function()
        if L and L.SetCastPreview then L.SetCastPreview(true) end
        ns.UpdateMenuStatus(L and L.IsPending())
        RefreshCurrent()
    end)
    window:SetScript("OnHide", function()
        if L and L.SetCastPreview then L.SetCastPreview(false) end
        GameTooltip:Hide()
    end)

    -- Esc closes it
    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "KutzLayoutPanel") end

    ShowTab("package")
    window:Hide()
end

function ns.ToggleLayoutPanel()
    if not KutzUIDB then return end
    if not window then CreateWindow() end
    if window:IsShown() then window:Hide() else window:Show() end
end

-- how far down each built page's controls reach, against the room the window has (the offline tests use this
-- to catch a page that has grown past the bottom of the window)
function ns.MenuLayoutReport()
    local room = H - HEADER_H - 1 - FOOTER_H
    local out = {}
    for key, p in pairs(pages) do
        local cols = {}
        for i, y in ipairs(p.ys) do cols[i] = -y end
        local panes = 0
        for _, s in ipairs(p.subs or {}) do if s.pane:IsShown() then panes = panes + 1 end end
        out[#out + 1] = { key = key, used = -math.min(p:Lowest(), p.lowestAll or 0), room = room, cols = cols,
            visible = (p.main or p.frame):IsShown() and true or false, current = (key == currentTab),
            subs = p.subs and #p.subs or 0, panesShown = panes }
    end
    return out
end

-- the page you are on, for /kutz debug
function ns.DebugMenu()
    ns.Print("menu: built=" .. tostring(window ~= nil) .. "  page=" .. tostring(currentTab))
end
