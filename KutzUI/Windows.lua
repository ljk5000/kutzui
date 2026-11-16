---------------------------------------------------------------------------
-- KutzUI / Windows
--
-- Exact position and size of the two chat windows, set from the menu's "Windows" page:
--   chat = the main chat window (ChatFrame1)      clog = the combat log (ChatFrame2)
--
-- Position is the window's BOTTOM-LEFT corner measured from the BOTTOM-LEFT of the screen.
-- Nothing is stored until you change a number; then a slow poller (outside Blizzard's code,
-- out of combat only) keeps the window there. "Give control back" forgets the numbers.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("windows", function()

local FRAMES = { chat = "ChatFrame1", clog = "ChatFrame2" }
local FIELDS = { x = 1, y = 2, w = 3, h = 4 }

ns.WINDOW_MIN = { chat = { y = 0, w = 150, h = 60 }, clog = { y = 24, w = 200, h = 60 } }  -- the log keeps clear of its filter bar

local function Round(n) return math.floor((n or 0) + 0.5) end

local function Saved(key)
    return KutzUIDB and KutzUIDB.winRect and KutzUIDB.winRect[key]
end

-- x, y, w, h as the window is right now
function ns.WindowRect(key)
    local cf = _G[FRAMES[key]]
    if not cf then return 0, 0, 400, 200 end
    return Round(cf:GetLeft()), Round(cf:GetBottom()), Round(cf:GetWidth()), Round(cf:GetHeight())
end

-- is this window free to be moved? (a docked combat log is just a tab of the main chat)
function ns.WindowMovable(key)
    local cf = _G[FRAMES[key]]
    if not cf then return false end
    return key == "chat" or not cf.isDocked
end

function ns.ApplyWindow(key)
    local rect = Saved(key)
    local cf = _G[FRAMES[key]]
    if not rect or not cf or InCombatLockdown() or not ns.WindowMovable(key) then return end
    -- Clamp the applied rectangle, preserving the preferred layout for larger displays.
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if sw <= 0 or sh <= 0 then return end
    local min = ns.WINDOW_MIN[key]
    local rw = math.min(math.max(rect.w, min.w), sw)
    local rh = math.min(math.max(rect.h, min.h), math.max(1, sh - min.y))
    local rx = math.max(0, math.min(rect.x, sw - rw))
    local ry = math.max(math.min(min.y, sh - rh), math.min(rect.y, sh - rh))
    local x, y, w, h = ns.WindowRect(key)
    if x == Round(rx) and y == Round(ry) and w == Round(rw) and h == Round(rh) then return end
    cf:SetSize(rw, rh)
    cf:ClearAllPoints()
    cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rx, ry)
    if key == "clog" and ns.RestyleCombatLog then ns.RestyleCombatLog() end
end

-- field = "x" | "y" | "w" | "h"
function ns.SetWindowField(key, field, value)
    if not FIELDS[field] or not FRAMES[key] or not KutzUIDB then return end
    KutzUIDB.winRect = KutzUIDB.winRect or {}
    local rect = KutzUIDB.winRect[key]
    if not rect then                                  -- first change: start from where the window is now
        local x, y, w, h = ns.WindowRect(key)
        rect = { x = x, y = y, w = w, h = h }
        KutzUIDB.winRect[key] = rect
    end
    local min = ns.WINDOW_MIN[key]
    if field == "y" then value = math.max(value, min.y)
    elseif field == "w" then value = math.max(value, min.w)
    elseif field == "h" then value = math.max(value, min.h) end
    local sw, sh = Round(UIParent:GetWidth()), Round(UIParent:GetHeight())
    value = math.min(value, (field == "x" or field == "w") and sw or sh)
    rect[field] = value
    ns.ApplyWindow(key)
end

function ns.WindowIsHeld(key) return Saved(key) ~= nil end

function ns.ReleaseWindow(key)
    if KutzUIDB and KutzUIDB.winRect then KutzUIDB.winRect[key] = nil end
end

local acc = 0
local poller = CreateFrame("Frame")
poller:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    if not (KutzUIDB and KutzUIDB.winRect) then return end
    pcall(ns.ApplyWindow, "chat")
    pcall(ns.ApplyWindow, "clog")
end)

end)
