---------------------------------------------------------------------------
-- KutzUI / CombatFormat
--
-- The few combat log options this addon keeps. (Colors and text layout of the lines are
-- Blizzard's: on this client the words of each line are sealed from addons, and the
-- functions that change Blizzard's combat log settings are blocked for addons.)
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.Module("combatlog", function()

local OPTION_DEFAULTS = {
    clogOnlyCombat = true,    -- leave out crafting / experience / loot lines Blizzard also puts in this window
}

function ns.CLOption(name)
    local db = KutzUIDB
    if db and db[name] ~= nil then return db[name] end
    return OPTION_DEFAULTS[name]
end

function ns.SetCLOption(name, value)
    if KutzUIDB then KutzUIDB[name] = value end
end

function ns.ResetCLSettings()
    local db = KutzUIDB
    if not db then return end
    for name in pairs(OPTION_DEFAULTS) do db[name] = nil end
    db.clogFontSize, db.clogTextAlpha, db.clogBgAlpha, db.clogSpacing = nil, nil, nil, nil
end

end)
