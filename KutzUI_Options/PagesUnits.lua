---------------------------------------------------------------------------
-- KutzUI / settings pages
-- Unit frames, cast bars, party frames and nameplates.
--
-- Part of KutzUI_Options. These files load only when you open /kutz, and only
-- after Menu.lua, which publishes the widget toolkit on KutzUI._opt.
-- Nothing in here runs until that window is opened.
---------------------------------------------------------------------------
local ns = _G.KutzUI
local M = ns._opt
if not M then error("KutzUI settings pages loaded before Menu.lua") end

local function BuildPartyPage()
    local p = M.NewPage("Party frames", "Beside each of Blizzard's party frames: what that member is targeting, and what that target is targeting. Each is a plain health bar with the name, like your Target-of-target. Click one to target it; right-click for its menu.")
    M.pages.party = p

    p:Columns(2)
    p:Col(1)
    if ns.PartyBarsApply then
        p:Section("Wider party frames")
        p:Check("Wider party frames",
            function() return not (M.DB.partyBars == false) end,
            function(v) M.DB.partyBars = (not v) and false or nil; ns.PartyBarsApply() end,
            "KutzUI's own bars on Blizzard's party frames: 15 letters wide, with the name on two lines and the health and power numbers always shown. Blizzard's portrait, icons, buffs and debuffs stay.")
    end
    p:Col(2)
    if ns.PartyBarsApply then p:Note("These go on the classic party frames. With Edit Mode's raid-style party frames on, the frame size and health text are Blizzard's own Edit Mode settings.", 3) end
    p:Col(1)
    if M.Off(p, "partytargets", "The party targets module") then return end

    p:Section("What shows")
    p:Check("Party members' targets",
        function() return ns.PTOption("ptTarget") end,
        function(v) ns.SetPTOption("ptTarget", v and true or false) end,
        "A bar to the right of each party frame showing what that member has targeted: its health and name.")
    p:Check("Their targets' targets",
        function() return ns.PTOption("ptToT") end,
        function(v) ns.SetPTOption("ptToT", v and true or false) end,
        "A second bar further right: what the member's target is itself targeting. Handy to see who a monster is hitting.")

    p:Section("Size and spacing")
    p:Slider("Bar width", 60, 200,
        function() return ns.PTOption("ptWidth") end,
        function(v) ns.SetPTOption("ptWidth", v) end,
        { wheel = 5, fmt = function(v) return v .. " px" end, tip = "How wide each of the bars is. Longer names fit in wider bars." })
    p:Slider("Space between bars", 0, 40,
        function() return ns.PTOption("ptGap") end,
        function(v) ns.SetPTOption("ptGap", v) end,
        { wheel = 1, fmt = function(v) return v .. " px" end, tip = "The gap between the party frame and the first bar, and between the two bars." })

    p:Col(2)
    p:Section("Colour")
    p:Cycler("Bar colour", {
            { key = "unit",   name = "Class colour (creatures: friendly / hostile)" },
            { key = "custom", name = "My colours (below)" },
        },
        function() return ns.PTOption("ptColorMode") end,
        function(k) ns.SetPTOption("ptColorMode", k) end,
        { tip = "Class colour: players show in their class colour; creatures in green, yellow or red for friendly, neutral or hostile. My colours: each kind of bar is always the colour you pick below." })
    p:Swatches({
            { key = "ptColorTarget", label = "Their target" },
            { key = "ptColorToT",    label = "Target's target" },
        },
        function(key) return ns.PTOption(key) end,
        function(key, hex) ns.SetPTOption(key, hex); ns.SetPTOption("ptColorMode", "custom") end,
        2)
    p:Note("Left-click a bar to target that unit, right-click for its menu. Picking a colour switches the bars to your colours. The game lets addons move clickable frames only outside combat, so a change to the switches, width or spacing made during a fight is applied when it ends. The bars only show while you are in a party, with the classic or the raid-style party frames.", 3)
    p:Buttons({ { text = "Reset", w = 90, click = function() ns.ResetPTSettings() end,
        tip = "Both bars on, class colours, normal width and spacing." } })
end

local function BuildNameplatesPage()
    local p = M.NewPage("Nameplates", "Blizzard's own nameplates, with a health percent in the bar and an outline on your target. Everything else here is the game's own nameplate settings.")
    M.pages.nameplates = p
    if M.Off(p, "nameplates", "The nameplates module") then return end
    local miss = { 0 }

    p:Columns(2)
    p:Col(1)
    p:Section("On the plate")
    p:Check("Health percent in the bar",
        function() return ns.NPOption("npHealthText") end,
        function(v) ns.SetNPOption("npHealthText", v and true or false) end,
        "Writes the health left, like 64%, in the middle of every nameplate's health bar.")
    p:Slider("Percent text size", 7, 16,
        function() return ns.NPOption("npTextSize") end,
        function(v) ns.SetNPOption("npTextSize", v) end,
        { wheel = 1, fmt = function(v) return v .. " pt" end, tip = "Size of the health percent on the plates." })
    p:Check("Show the whole name",
        function() return ns.NPOption("npFullName") end,
        function(v) ns.SetNPOption("npFullName", v and true or false); if ns.NPTick then ns.NPTick() end end,
        "Blizzard cuts a long plate name short with ... to fit the health bar. With this on the whole name is written instead, running past the ends of the bar if it has to.")
    p:Check("Outline the target's plate",
        function() return ns.NPOption("npTargetGlow") end,
        function(v) ns.SetNPOption("npTargetGlow", v and true or false) end,
        "A thin gold outline around the nameplate of whatever you have targeted, so you can find it in a crowd.")

    p:Col(2)
    p:Section("Colours and size (the game's own)")
    M.GS.Bool(p, miss, "Class colours on enemy players", "nameplateShowClassColor", "Enemy players' plates are coloured by their class.")
    M.GS.Bool(p, miss, "Class colours on friendly players", "nameplateShowFriendlyClassColor", "Friendly players' plates are coloured by their class.")
    M.GS.Slider(p, miss, "Size of the selected plate", "nameplateSelectedScale", 100, 200, 100, "%", "How much bigger the plate of your target is. 100% means no change.", 5)
    M.GS.Slider(p, miss, "Size of far-away plates", "nameplateMinScale", 40, 100, 100, "%", "How small plates get when they are far away. 100% means they stay full size.", 5)
    M.GS.Slider(p, miss, "Opacity of far-away plates", "nameplateMinAlpha", 10, 100, 100, "%", "How see-through plates get when they are far away. 100% means they stay solid.", 5)
    M.GS.MissingNote(p, miss)
    p:Note("Which nameplates show at all, how far away, and whether they overlap or stack are on the Game settings page.", 3)
    p:Buttons({
        { text = "Open Game settings", w = 170, click = function() M.ShowTab("gamesettings") end },
        { text = "Reset", w = 90, click = function() ns.ResetNPSettings() end, tip = "Percent text on, target outline on." },
    })
end

local function BuildFramesPage()
    local p = M.NewPage("Unit frames", "Where your Player, Target and Target-of-target frames sit, how big they are, and how names show on them.")
    M.pages.frames = p
    if M.Off(p, "frames", "The unit frames module") then return end
    local half = math.floor(UIParent:GetHeight() / 2)

    p:SubTab("layout", "Position and size")
    p:Columns(2)
    p:Col(1)
    p:Section("Position")
    p:Slider("Height on the screen", -half, half,
        function() return M.DB.groupY end,
        function(v) M.DB.groupY = v; M.L.Apply() end,
        { tip = "Moves the Player, Target and Target-of-target frames up or down together. The cast bars have their own height on the Cast bars page." })
    p:Slider("Space between Player and Target", 0, 1000,
        function() return M.L.GetSpread() end,
        function(v) M.DB.castHug = nil; M.DB.spread = v; M.L.Apply() end,
        { bounds = M.L.SpreadBounds,
          tip = "The empty space between the Player frame and the Target frame, split evenly either side of the screen centre. Lower = closer together. Moving this turns off 'same distance from the cast bars' (Cast bars page), which would otherwise decide it." })
    p:Col(2)
    p:Section("Size")
    for _, spec in ipairs({
        { "player", "Player frame size" },
        { "target", "Target frame size" },
        { "tot",    "Target-of-target size" },
    }) do
        p:Slider(spec[2], M.L.SCALE_MIN, M.L.SCALE_MAX,
            function() return M.L.ScalePercent(spec[1]) end,
            function(v) M.DB.scale[spec[1]] = v; M.L.Apply() end,
            { wheel = 5, fmt = function(v) return v .. "%" end,
              tip = "Size as a percentage of the normal size. 100% = what Blizzard draws." })
    end
    p:Below()
    p:Buttons({ { text = "Reset frames", w = 130, click = function() M.L.ResetFrames() end,
        tip = "Back to the default height, spacing and sizes." } })

    p:SubTab("bars", "Player and Target")
    p:Columns(2)
    p:Col(1)
    p:Section("Health and power bars")
    p:Check("KutzUI's own health and power bars",
        function() return ns.UB.On() end,
        function(v) M.DB.ownBars = (not v) and false or nil; M.L.Apply() end,
        "Draws a wider, taller health bar (with the name inside it, wrapping onto a second line) and a power bar for the Player and Target frames, instead of Blizzard's small ones. The Target shows the whole name, the Player only your first name. Level, icons and buffs stay Blizzard's. Takes effect when you are out of combat.")
    p:Slider("Bar width", ns.UB.MIN_W, ns.UB.MAX_W,
        function() return ns.UB.Width() end,
        function(v) M.DB.barW = v; M.L.Apply() end,
        { wheel = 5, fmt = function(v) return v .. " px" end,
          tip = "How wide the health and power bars are. The same for the Player and the Target. The frames move apart to make room." })
    p:Slider("Bar height", ns.UB.MIN_H, ns.UB.MAX_H,
        function() return ns.UB.Height() end,
        function(v) M.DB.barH = v; M.L.Apply() end,
        { wheel = 1, fmt = function(v) return v .. " px" end,
          tip = "How tall the health bar is. About 28 or more fits a name on two lines." })
    p:Section("Portrait")
    for _, unit in ipairs({ "player", "target" }) do
        p:Check((unit == "player" and "Player" or "Target") .. ": 3D portrait (off = flat picture)",
            function() return ns.UB.Portrait3D(unit) end,
            function(v)
                local t = { player = ns.UB.Portrait3D("player"), target = ns.UB.Portrait3D("target") }
                t[unit] = v and true or false
                M.DB.pic3d = t; M.DB.portrait3d = nil
                M.L.Apply()
            end,
            "The square portrait joined to this frame's bars: a flat picture of the face (off), or the animated 3D model (on). Player and Target are set separately.")
    end
    p:Section("Target auras")
    p:Check("Target debuffs in their own row above the frame",
        function() return M.DB.debuffsTop ~= false end,
        function(v) M.DB.debuffsTop = (not v) and false or nil end,
        "The target's debuffs sit in a row above its frame, left to right; its buffs stay in the box under it. Off = both share the box under the frame (Blizzard's way).")
    p:Col(2)
    p:Section("Names")
    p:Check("Hide first names",
        function() return M.DB.hideFirst end,
        function(v) M.DB.hideFirst = v or nil; ns.RefreshNames() end,
        "\"Arthas Menethil\" shows as \"Menethil\". One-word names are never changed. With KutzUI's own Player / Target bars on, those two frames decide their own names (Player: first name only, Target: the whole name).")
    p:Check("Hide last names",
        function() return M.DB.hideLast end,
        function(v) M.DB.hideLast = v or nil; ns.RefreshNames() end,
        "\"Arthas Menethil\" shows as \"Arthas\". One-word names are never changed. With KutzUI's own Player / Target bars on, those two frames decide their own names (Player: first name only, Target: the whole name).")
    p:Slider("Name text size (added to normal)", 0, 8,
        function() return ns.NameBonus() end,
        function(v) M.DB.nameBonus = v end,
        { wheel = 1, fmt = function(v) return "+" .. v end,
          tip = "How much bigger than Blizzard's size the names on the Player and Target frames are." })

    p:SubTab("tot", "Target of target")
    p:Columns(2)
    p:Col(1)
    p:Section("Position")
    p:Slider("Distance from the Target frame", -30, 200,
        function() return M.DB.totOffsetX or 2 end,
        function(v) M.DB.totOffsetX = v; M.L.Apply() end,
        { wheel = 1, fmt = function(v) return v .. " px" end,
          tip = "How many pixels the Target-of-target frame sits to the right of the Target frame. Fewer pixels = closer together; 0 = touching; below 0 = overlapping." })
    p:Slider("Height offset", -100, 100,
        function() return M.DB.totOffsetY or 0 end,
        function(v) M.DB.totOffsetY = v; M.L.Apply() end,
        { wheel = 1, fmt = function(v) return v .. " px" end,
          tip = "Moves the Target-of-target frame up (+) or down (-) relative to the Target frame, in pixels." })
    p:Col(2)
    p:Section("Colour")
    p:Cycler("Bar colour", {
            { key = "unit",   name = "Class colour (creatures: friendly / hostile)" },
            { key = "custom", name = "One colour of my choice" },
        },
        function() return M.DB.totColorMode or "unit" end,
        function(k) M.DB.totColorMode = (k ~= "unit") and k or nil; M.L.RefreshToT() end,
        { tip = "Class colour: a player's bar is in their class colour; a creature's is green, yellow or red for friendly, neutral or hostile, like Blizzard's frames. One colour: the bar is always the colour below." })
    p:Swatches({ { key = "tot", label = "My colour" } },
        function() return M.L.ToTColorHex() end,
        function(_, hex) M.DB.totColor = hex; M.DB.totColorMode = "custom" end,
        2,
        function() M.L.RefreshToT() end)
    p:Below()
    p:Note("Tip: target yourself while you adjust, so Target and Target-of-target are on screen to look at.", 2)
end

local function BuildCastPage()
    local p = M.NewPage("Cast bars", "The two bars that show what you and your target are casting: the spell's icon, its name and the time left. Size, shape, texture and colour are yours to set.")
    M.pages.cast = p
    if M.Off(p, "castbars", "The cast bars module") then return end
    local half = math.floor(UIParent:GetHeight() / 2)

    p:SubTab("pos", "Position and size")
    p:Columns(2)
    p:Col(1)
    p:Section("Position and size")
    p:Slider("Height on the screen", -half, half,
        function() return M.L.GetCastY() end,
        function(v) M.DB.castY = v; M.L.Apply() end,
        { tip = "Moves the cast bars on their own, separately from the unit frames. They are always centred left to right." })
    p:Slider("Width", M.L.CAST_MIN_W, M.L.CAST_MAX_W,
        function() return M.L.GetCastWidth() end,
        function(v) M.DB.castWidth = v; M.L.Apply() end,
        { wheel = 5, tip = "Wider bars leave more room for long spell names. With 'same distance from the cast bars' on, the unit frames move out as the bars grow." })
    p:Slider("Thickness", M.L.CAST_MIN_H, M.L.CAST_MAX_H,
        function() return M.L.GetCastHeight() end,
        function(v) M.DB.castHeight = v; M.L.Apply() end,
        { wheel = 1, tip = "How tall the bars are. The text and icon grow with it." })

    p:Col(2)
    p:Section("Distance from Player and Target")
    p:Check("Same distance from the cast bars",
        function() return M.DB.castHug and true or false end,
        function(v)
            if v then
                M.DB.castHug = true
            else
                local gap = M.L.GetSpread()           -- keep the frames where they are now, then let you set it yourself
                M.DB.castHug = nil
                M.DB.spread = gap
            end
            M.L.Apply()
        end,
        "On: Player and Target sit the same distance from the two ends of the cast bars, and follow them when you change the width. Off: you set the distance between Player and Target yourself (below), centred on the screen.")
    p:Slider("Space between bar and frame", 0, 150,
        function() return M.L.GetCastMargin() end,
        function(v) M.DB.castMargin = v; M.DB.castHug = true; M.L.Apply() end,
        { wheel = 1, tip = "The gap between each end of the cast bars and the frame beside it. Moving this turns 'same distance from the cast bars' on." })
    p:Slider("Space between Player and Target", 0, 1000,
        function() return M.L.GetSpread() end,
        function(v) M.DB.castHug = nil; M.DB.spread = v; M.L.Apply() end,
        { bounds = M.L.SpreadBounds, wheel = 5,
          tip = "The empty space between the Player frame and the Target frame, split evenly either side of the screen centre. Moving this turns 'same distance from the cast bars' off." })

    p:SubTab("shows", "What it shows")
    p:Columns(2)
    p:Col(1)
    p:Section("Text and icon")
    p:Check("Show the spell icon",
        function() return M.DB.castIcon ~= false end,
        function(v) M.DB.castIcon = v and true or false; M.L.Apply() end,
        "The little picture of the spell being cast, at the left end of the bar.")
    p:Cycler("Where the time goes", {
            { key = "left",   name = "Left of the bar (whole spell name)" },
            { key = "middle", name = "Middle of the bar" },
            { key = "right",  name = "Right end of the bar" },
        },
        function() return (M.DB.castTimePos == "middle" or M.DB.castTimePos == "right") and M.DB.castTimePos or (M.DB.castTimeRight and "right" or "left") end,
        function(k) M.DB.castTimeRight = nil; M.DB.castTimePos = (k ~= "left") and k or nil; M.L.Apply() end,
        { tip = "Left (the default) puts the countdown just outside the bar, left of the icon, so the spell name has the whole bar and is shown in full, however long it is. Middle and right keep the time inside the bar, so a long name is cut short with ... to make room." })
    p:Cycler("Time on the bar", {
            { key = "remaining", name = "Time left (counts down)" },
            { key = "total",     name = "Time left / whole cast" },
            { key = "off",       name = "No time" },
        },
        function() return M.DB.castTimeMode or "remaining" end,
        function(k) M.DB.castTimeMode = (k ~= "remaining") and k or nil; M.L.Apply() end,
        { tip = "What the number on the bar says: just the seconds left counting down (1.2), the seconds left and the length of the whole cast (1.2 / 2.5), or nothing at all." })
    p:Col(2)
    p:Section("Extras")
    p:Check("Latency safe zone on my bar",
        function() return M.DB.castSafe ~= false end,
        function(v) M.DB.castSafe = v and nil or false; M.L.Apply() end,
        "A red band at the end of YOUR cast bar as long as your latency. Once the bar reaches it you can already press your next spell and it goes off the instant this one ends, so there is no gap.")
    p:Check("Mark casts that can't be interrupted",
        function() return M.DB.castShield ~= false end,
        function(v) M.DB.castShield = v and nil or false; M.L.Apply() end,
        "On the TARGET's bar, a small shield on the icon and a grey bar when the spell can't be interrupted. Saves you wasting an interrupt.")
    p:Note("With the time on the left the whole spell name is always shown. With the time inside the bar, a name too long to fit beside it is cut short.", 3)

    p:SubTab("look", "Look")
    p:Columns(2)
    p:Col(1)
    p:Section("Shape and textures")
    p:Cycler("Shape", {
            { key = "square", name = "Square corners" },
            { key = "round",  name = "Rounded corners" },
            { key = "pill",   name = "Pill (fully round ends)" },
        },
        function() return M.DB.castShape or "square" end,
        function(k) M.DB.castShape = (k ~= "square") and k or nil; M.L.ApplyCastTextures() end,
        { tip = "The outline of the bars. Rounded shapes use picture files, so after an update that adds them the game needs a full restart (not just /reload) to see them." })

    local textures = ns.TextureList()
    local function TextureCycler(unit, label, key)
        p:Cycler(label, textures,
            function() return ns.CastTextureKey(unit) end,
            function(k) M.DB[key] = k; M.L.ApplyCastTextures() end,
            { tip = "Pick a texture for this bar. The 'Kutz' ones are mine; the 'Blizzard' ones come with the game; others appear if another addon adds textures via SharedMedia.",
              makePreview = function(parent, x, y, w)
                  local bar = CreateFrame("StatusBar", nil, parent)
                  bar:SetSize(w, 14)
                  bar:SetPoint("TOPLEFT", x, y)
                  bar:SetMinMaxValues(0, 1); bar:SetValue(0.65)
                  local bg = M.Fill(bar, "BACKGROUND", 0, 0, 0, 0.7); bg:SetAllPoints()
                  return function(item)
                      bar:SetStatusBarTexture(item.path)
                      local hex = M.L.CastColorHex(unit)
                      bar:SetStatusBarColor(M.HexToRGB(hex))
                  end
              end })
    end
    TextureCycler("player", "Your cast bar texture", "castTexPlayer")
    TextureCycler("target", "Target's cast bar texture", "castTexTarget")

    p:Col(2)
    p:Section("Colour")
    p:Swatches({
            { key = "player", label = "Your bar" },
            { key = "target", label = "Target's bar" },
        },
        function(unit) return M.L.CastColorHex(unit) end,
        function(unit, hex) M.DB[unit == "player" and "castColorPlayer" or "castColorTarget"] = hex end,
        2,
        function() M.L.ApplyCastTextures() end)
    p:Check("Your bar uses your class colour",
        function() return M.DB.castClassPlayer and true or false end,
        function(v) M.DB.castClassPlayer = v and true or nil; M.L.ApplyCastTextures() end,
        "Your own bar is always painted in your class colour; the colour above is used when this is off.")
    p:Check("Target's bar uses the target's class colour",
        function() return M.DB.castClassTarget and true or false end,
        function(v) M.DB.castClassTarget = v and true or nil; M.L.ApplyCastTextures() end,
        "When your target is a player, its bar uses that player's class colour. Creatures have no class, so they use the colour above.")
    p:Check("Fill from right to left",
        function() return M.DB.castReverse and true or false end,
        function(v) M.DB.castReverse = v and true or nil; M.L.Apply() end,
        "The bars normally fill from the left; this makes them fill from the right.")
    p:Below()
    p:Note("While this menu is open the bars show made-up casts so you can see where they are.", 2)
    p:Buttons({ { text = "Reset cast bars", w = 140, click = function() M.L.ResetCastBars() end,
        tip = "Back to the default height, width, thickness, shape, textures, colours and options." } })
end

M.builders.party = BuildPartyPage
M.builders.nameplates = BuildNameplatesPage
M.builders.frames = BuildFramesPage
M.builders.cast = BuildCastPage
