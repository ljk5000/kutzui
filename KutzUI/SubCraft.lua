-- Parts first, parent last. Only our own frames/scripts; no Blizzard hooks or writes.
local ADDON_NAME, ns = ...
ns.Module("subcraft", function()
-- Pure planner. Recipes: {id, name, outputItemID, quantityMin, reagents={{itemID, quantity}}}.
-- Stock and recipes are never mutated. Projected output is reserved just like held stock.
local function Plan(targetID, count, recipes, held)
    local byID, producers, stock, lots = {}, {}, {}, {}
    local nodes, order, active, missing, shortages = {}, {}, {}, {}, {}
    for id, quantity in pairs(held) do stock[id] = quantity end
    for _, recipe in ipairs(recipes) do
        byID[recipe.id] = recipe
        local item = recipe.outputItemID
        if item and recipe.quantityMin > 0 then
            producers[item] = producers[item] or {}
            table.insert(producers[item], recipe)
        end
    end
    for _, list in pairs(producers) do table.sort(list, function(a, b) return a.id < b.id end) end
    local function Missing(item, short)
        if not shortages[item] then
            shortages[item] = { itemID = item, short = 0 }
            table.insert(missing, shortages[item])
        end
        shortages[item].short = shortages[item].short + short
    end
    local function Depends(node, id)
        if not node.seen[id] then node.seen[id] = true; table.insert(node.deps, id) end
    end
    local function InHand(recipe, crafts)
        local needed = {}
        for _, reagent in ipairs(recipe.reagents) do
            local item = reagent.itemID
            needed[item] = (needed[item] or 0) + reagent.quantity * crafts
        end
        for item, quantity in pairs(needed) do if (stock[item] or 0) < quantity then return false end end
        return true
    end
    local Resolve
    local function Reserve(item, quantity, consumer, depth)
        local take = math.min(stock[item] or 0, quantity)
        stock[item] = (stock[item] or 0) - take
        quantity = quantity - take
        -- Track the producers of surplus too, so merging never moves a user before its parts.
        for _, lot in ipairs(lots[item] or {}) do
            local used = math.min(lot.left, quantity)
            if used > 0 then Depends(consumer, lot.id); lot.left = lot.left - used; quantity = quantity - used end
        end
        if quantity <= 0 then return end
        local candidates, chosen = producers[item] or {}
        for _, recipe in ipairs(candidates) do
            if InHand(recipe, math.ceil(quantity / recipe.quantityMin)) then chosen = recipe; break end
        end
        chosen = chosen or candidates[1]
        if not chosen or active[chosen.id] or depth > 8 then Missing(item, quantity); return end
        local crafts = math.ceil(quantity / chosen.quantityMin)
        Depends(consumer, chosen.id)
        Resolve(chosen, crafts, depth)
        lots[item] = lots[item] or {}
        table.insert(lots[item], { id = chosen.id, left = crafts * chosen.quantityMin - quantity })
    end
    Resolve = function(recipe, crafts, depth)
        local node = nodes[recipe.id]
        if not node then
            node = { recipeID = recipe.id, name = recipe.name, crafts = 0, deps = {}, seen = {} }
            nodes[recipe.id] = node
        end
        node.crafts = node.crafts + crafts
        active[recipe.id] = true
        for _, reagent in ipairs(recipe.reagents) do
            Reserve(reagent.itemID, reagent.quantity * crafts, node, depth + 1)
        end
        active[recipe.id] = nil
    end
    local target = byID[targetID]
    if not target then return {}, {} end
    Resolve(target, count, 0)
    local visited, visiting = {}, {}
    local function Emit(id)
        if visiting[id] then
            -- Merging can expose a cycle even when held stock broke the initial recursion.
            local recipe = byID[id]
            Missing(recipe.outputItemID, nodes[id].crafts * recipe.quantityMin)
            return
        end
        if visited[id] then return end
        visiting[id] = true
        local node = nodes[id]
        for _, dependency in ipairs(node.deps) do Emit(dependency) end
        visiting[id] = nil; visited[id] = true
        table.insert(order, { recipeID = id, name = node.name, crafts = node.crafts })
    end
    Emit(targetID)
    return order, missing
end
ns.SubCraftPlan = Plan

-- Search complete parent batches with the same reservations/rounding as the actual plan.
-- Bound even reagent-free recipes; normal inventory limits are far below this integer ceiling.
local MAX_CRAFTS = 2147483647.0
local function Maximum(targetID, recipes, held)
    local function Ready(count)
        local steps, short = Plan(targetID, count, recipes, held)
        return #steps > 0 and #short == 0
    end
    if not Ready(1) then return 0 end
    local low, high = 1.0, 2.0
    while Ready(high) do
        low = high
        if high == MAX_CRAFTS then return high end
        high = math.min(MAX_CRAFTS, high * 2)
    end
    while high - low > 1 do
        local mid = low + math.floor((high - low) / 2)
        if Ready(mid) then low = mid else high = mid end
    end
    return low
end
ns.SubCraftMaximum = Maximum

local function Value(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function Number(v)
    v = Value(v)
    if type(v) == "number" and v >= 0 and v < math.huge then return v end
end
local function Invoke(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return Value(result) end
end
local function Call(object, method, ...)
    if object then return Invoke(object[method], object, ...) end
end
local function API(method, ...)
    return Invoke(C_TradeSkillUI and C_TradeSkillUI[method], ...)
end
local function Page()
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    if page and Call(page, "IsShown") then return page end
end
local function OwnProfession()
    local linked, guild, npc = API("IsTradeSkillLinked"), API("IsTradeSkillGuild"), API("IsNPCCrafting")
    local foreign = linked == true or guild == true or npc == true
    return API("IsTradeSkillReady") == true and linked == false and guild == false and npc == false, foreign
end
local function Profession()
    local info = API("GetBaseProfessionInfo")
    local id = info and Number(info.professionID)
    if id and id > 0 then return id end
end
local function Selected(page)
    local info = Call(page.SchematicForm, "GetRecipeInfo")
    local id = info and Number(info.recipeID)
    if id and id > 0 then return id end
end
local function Quantity(page)
    return math.max(1, math.floor(Number(Call(page.CreateMultipleInputBox, "GetValue")) or 1))
end
local function ReadRecipes()
    local recipes, byID = {}, {}
    for _, rawID in ipairs(API("GetAllRecipeIDs") or {}) do
        local id = Number(rawID)
        local info = id and API("GetRecipeInfo", id)
        local schematic = info and Value(info.learned) == true and API("GetRecipeSchematic", id, false)
        if schematic then
            local recipe = { id = id, name = Value(info.name) or tostring(id),
                outputItemID = Number(schematic.outputItemID), quantityMin = Number(schematic.quantityMin) or 1,
                reagents = {} }
            local valid = true
            for _, slot in ipairs(Value(schematic.reagentSlotSchematics) or {}) do
                if Number(slot.reagentType) == 1 then
                    local first = slot.reagents and slot.reagents[1]
                    local item, quantity = first and Number(first.itemID), Number(slot.quantityRequired)
                    if not item or not quantity then valid = false; break end
                    table.insert(recipe.reagents, { itemID = item, quantity = quantity })
                end
            end
            if valid then table.insert(recipes, recipe); byID[id] = recipe end
        end
    end
    return { recipes = recipes, byID = byID }
end
local function Held(page, item)
    local transaction = Call(page.SchematicForm, "GetTransaction")
    local onlyCharacter = Call(transaction, "ShouldUseCharacterInventoryOnly")
    -- Same helper and transaction flag as the schematic and GetCraftableCount on Forever.
    local count = Number(Invoke(_G.ItemUtil and _G.ItemUtil.GetCraftingReagentCount, item, onlyCharacter))
    if count then return count end
    count = Number(Invoke(C_Item and C_Item.GetItemCount, item, true, false, true))
    return count or Number(Invoke(_G.GetItemCount, item)) or 0
end
local function Inventory(page, recipes)
    local held = {}
    for _, recipe in ipairs(recipes) do
        for _, reagent in ipairs(recipe.reagents) do
            if held[reagent.itemID] == nil then held[reagent.itemID] = Held(page, reagent.itemID) end
        end
    end
    return held
end
local function ItemName(id)
    return Invoke(C_Item and C_Item.GetItemNameByID, id) or Invoke(GetItemInfo, id) or ("item " .. id)
end

local cache, profession, selected, quantity, plan, missing = {}, nil, nil, nil, {}, {}
local dirty, opened, run, autoRefused, refreshing = true, false, nil, false, false
local stockDirty, requested, maximum, useful = true, nil, 0, false
local held, strip, label, button, owner, amount, capacity, settingAmount
local Update
local runner = CreateFrame("Frame")
runner:Hide()
local function Message(text) print("KutzUI: " .. text) end
local function Cancel()
    if run then run = nil; dirty = true; stockDirty = true; Message("sub-assembly run stopped") end
end
local function ReadAmount()
    local value = Number(tonumber(Call(amount, "GetText")))
    if value then return math.max(1, math.min(math.max(1, maximum), math.floor(value))) end
end
local function ChangeAmount()
    if settingAmount or run then return end
    local value = ReadAmount()
    if value then requested = value; dirty = true; Update() end
end
local function EnsureStrip(page)
    if owner == page then return end
    if strip then strip:Hide() end
    owner = page
    strip = CreateFrame("Frame", nil, page)
    strip:SetPoint("TOPLEFT", page, "BOTTOMLEFT", 10, -31)
    strip:SetPoint("TOPRIGHT", page, "BOTTOMRIGHT", -10, -31)
    strip:SetHeight(24)
    label = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", strip, "LEFT", 0, 0)
    label:SetJustifyH("LEFT")
    button = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
    button:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
    button:SetSize(220, 24)
    amount = CreateFrame("EditBox", nil, strip, "InputBoxTemplate")
    amount:SetSize(50, 22)
    amount:SetPoint("RIGHT", button, "LEFT", -12, 0)
    amount:SetAutoFocus(false)
    amount:SetNumeric(true)
    amount:SetMaxLetters(10)
    amount:SetJustifyH("CENTER")
    amount:SetScript("OnTextChanged", ChangeAmount)
    amount:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    amount:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    amount:SetScript("OnEditFocusLost", function() ChangeAmount(); Update() end)
    capacity = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    capacity:SetPoint("RIGHT", amount, "LEFT", -10, 0)
    capacity:SetWidth(150)
    capacity:SetJustifyH("RIGHT")
end
local function ButtonText(text)
    button:SetText(text)
    button:SetWidth(math.max(180, (Number(Call(button, "GetTextWidth")) or 200) + 24))
end
local function Paint()
    if not strip then return end
    label:SetFontObject("GameFontHighlight")
    if run then
        amount:Hide(); capacity:Hide()
        label:SetPoint("RIGHT", button, "LEFT", -8, 0)
        strip:Show(); button:Show(); button:Enable()
        local step = run.steps[run.index]
        local status = run.paused and " (updating profession data)" or run.waitingMaterials and " (waiting for crafted materials)" or ""
        label:SetText(string.format("Step %d of %d: %s %d / %d", run.index, #run.steps, step.name, run.done, step.crafts) .. status)
        if run.phase == "click" then
            ButtonText(string.format("Next: %s x%d (step %d of %d)", step.name, step.crafts, run.index, #run.steps))
        elseif run.stopping then ButtonText("Stopping after current cast"); button:Disable()
        else ButtonText("Stop") end
    elseif useful or #plan > 1 then
        strip:Show()
        amount:Show(); capacity:Show()
        label:SetPoint("RIGHT", capacity, "LEFT", -8, 0)
        capacity:SetText(string.format("Max crafts: %d  Qty:", maximum))
        if maximum > 0 then amount:Enable() else amount:Disable() end
        if tonumber(Call(amount, "GetText")) ~= quantity then
            settingAmount = true; amount:SetText(string.format("%d", quantity)); settingAmount = false
        end
        if #missing > 0 then
            local names = {}
            for _, item in ipairs(missing) do table.insert(names, item.short .. " " .. ItemName(item.itemID)) end
            label:SetFontObject("GameFontRed")
            label:SetText("Missing: " .. table.concat(names, ", ")); button:Hide()
        else
            local names = {}
            for i = 1, #plan - 1 do
                local step = plan[i]
                local recipe = cache[profession].byID[step.recipeID]
                table.insert(names, (step.crafts * recipe.quantityMin) .. " " .. step.name)
            end
            label:SetText(#names > 0 and ("Needs: " .. table.concat(names, ", ") .. " (you can make it)") or "Materials ready")
            ButtonText(string.format(#plan > 1 and "Make %d (parts first)" or "Make %d", quantity))
            button:Show(); button:Enable()
        end
    else strip:Hide() end
end
local function Covered(page, step, pendingItem)
    local recipe = run.catalog.byID[step.recipeID]
    local needs = {}
    for _, reagent in ipairs(recipe.reagents) do
        needs[reagent.itemID] = (needs[reagent.itemID] or 0) + reagent.quantity * step.crafts
    end
    local waiting = false
    for item, amount in pairs(needs) do
        if Held(page, item) < amount then
            if item ~= pendingItem then return false, false end
            waiting = true
        end
    end
    return not waiting, waiting
end
local function Fallback()
    if not run or run.phase == "click" then return end
    autoRefused = true
    run.phase = "click"; run.automatic = false
    Message("automatic crafting refused; click Next to continue")
end
local function Start(page, automatic)
    local step = run.steps[run.index]
    if not Covered(page, step) then Cancel(); return end
    local fn = C_TradeSkillUI and C_TradeSkillUI.CraftRecipe
    run.phase = "casting"; run.automatic = automatic; run.wait = 0; run.began = false; run.attempted = true
    local ok, result = false, nil
    if type(fn) == "function" then ok, result = pcall(fn, step.recipeID, step.crafts) end
    if not ok or Value(result) == false then
        if automatic then Fallback()
        else Message("cannot start crafting (CraftRecipe unavailable or failed)"); Cancel() end
    end
end
local function Click()
    local previous = run
    if not run and amount then requested = ReadAmount() or quantity; dirty = true end
    Update()
    if previous and run ~= previous then return end
    local page = Page()
    if not page then return end
    if run then
        if run.phase == "click" then Start(page, false)
        elseif run.phase == "delay" then Cancel()
        else
            run.stopping = true
            -- Only from this hardware click: stop repeats without interrupting the current cast.
            local fn = C_TradeSkillUI and C_TradeSkillUI.StopRecipeRepeat
            local ok, result = false, nil
            if type(fn) == "function" then ok, result = pcall(fn) end
            if not ok or Value(result) == false then
                Message("cannot stop the current batch; stop it in the profession window")
            end
        end
    elseif #plan > 0 and (useful or #plan > 1) and #missing == 0 then
        run = { steps = plan, catalog = cache[profession], index = 1, done = 0,
            target = selected, profession = profession, phase = "click" }
        Start(page, false)
    end
    Paint()
end
Update = function()
    local page = opened and Page()
    local own, foreign
    if page then own, foreign = OwnProfession() end
    local current = page and Profession()
    local id = page and Selected(page)
    if run then
        if not page or foreign or (own and current and current ~= run.profession)
            or (own and not refreshing and id and id ~= run.target) then Cancel()
        else
            -- A refreshed schematic may temporarily have no selected recipe or ready data.
            run.paused = refreshing or not own or not current or not id
            Paint()
            return
        end
    end
    if not own or not current or refreshing then
        plan, missing, useful = {}, {}, false
        if strip then strip:Hide() end
        return
    end
    if profession ~= current or selected ~= id then
        requested = nil; stockDirty = true; dirty = true
    end
    profession, selected = current, id
    if not cache[current] then cache[current] = ReadRecipes(); stockDirty = true; dirty = true end
    if not cache[current].byID[id] then
        plan, missing, useful = {}, {}, false
        if strip then strip:Hide() end
        return
    end
    if stockDirty and not run then
        held = Inventory(page, cache[current].recipes)
        maximum = Maximum(id, cache[current].recipes, held)
        local full = Plan(id, math.max(1, maximum), cache[current].recipes, held)
        useful = #full > 1
        stockDirty = false; dirty = true
    end
    if requested and not run then requested = math.min(math.max(1, maximum), requested) end
    local count = math.min(math.max(1, maximum), requested or Quantity(page))
    if not run and quantity ~= count then quantity = count; dirty = true end
    if dirty and not run then
        plan, missing = Plan(id, count, cache[current].recipes, held)
        dirty = false
    end
    EnsureStrip(page)
    button:SetScript("OnClick", Click)
    Paint()
end
local events = CreateFrame("Frame")
for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGING", "TRADE_SKILL_DATA_SOURCE_CHANGED", "BAG_UPDATE_DELAYED",
    "TRADE_SKILL_CRAFT_BEGIN", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "ADDON_LOADED" }) do
    events:RegisterEvent(event)
end
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do events:RegisterUnitEvent(event, "player") end
events:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "TRADE_SKILL_CLOSE" then
        Cancel(); opened = false; refreshing = false; runner:Hide(); if strip then strip:Hide() end
        return
    elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGING" then
        refreshing = true
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        refreshing = false; opened = true; cache = {}; stockDirty = true; dirty = true; runner:Show()
    elseif event == "ADDON_LOADED" then
        if Page() then opened = true; runner:Show() end
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        if opened and Page() then cache = {}; stockDirty = true; dirty = true end
    elseif event == "BAG_UPDATE_DELAYED" then stockDirty = true; dirty = true
    elseif run then
        local step = run.steps[run.index]
        if (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and Value(unit) == ADDON_NAME then
            if run.automatic then Fallback() else Message("crafting blocked by the game"); Cancel() end
        elseif event == "TRADE_SKILL_CRAFT_BEGIN" and Number(unit) == step.recipeID then
            if run.attempted then run.began = true; if run.phase == "click" then run.phase = "casting" end end
        elseif Value(unit) == "player" and Number(spellID) == step.recipeID and run.attempted then
            -- A late start after the refusal deadline must not leave a second clickable start.
            if event == "UNIT_SPELLCAST_START" and run.phase == "click" then run.phase = "casting" end
            if run.phase ~= "casting" then return end
            if event == "UNIT_SPELLCAST_START" then run.began = true
            elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then Cancel()
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                run.began = true
                run.done = run.done + 1
                if run.stopping then Cancel()
                elseif run.done >= step.crafts then run.phase = "delay"; run.wait = 0 end
            end
        end
    end
    Update()
end)
local elapsed = 0
runner:SetScript("OnUpdate", function(_, dt)
    dt = Number(dt) or 0
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    local delta = elapsed; elapsed = 0
    Update()
    if run and run.paused then
        local casting = Invoke(UnitCastingInfo, "player")
        run.pausedFor = casting and 0 or ((run.pausedFor or 0) + delta)
        if run.pausedFor >= 5 then Message("profession data did not become ready"); Cancel() end
        Update()
        return
    end
    if run then
        run.pausedFor = 0
        run.wait = (run.wait or 0) + delta
        if run.phase == "casting" and not run.began and run.wait >= 1.5 then
            if run.stopping then Cancel()
            elseif run.automatic then Fallback()
            else Message("crafting did not start"); Cancel() end
        elseif run.phase == "delay" and run.wait >= 0.3 then
            -- A successful final craft can fire before the cast has actually left the unit.
            local ok, casting = pcall(UnitCastingInfo, "player")
            local accessible = not issecretvalue or not issecretvalue(casting)
            if ok and accessible and casting == nil then
                if run.index == #run.steps then run = nil; stockDirty = true; dirty = true
                else
                    local completed = run.catalog.byID[run.steps[run.index].recipeID]
                    local covered, waiting = Covered(Page(), run.steps[run.index + 1], completed.outputItemID)
                    if covered then
                        run.index = run.index + 1; run.done = 0; run.attempted = false; run.waitingMaterials = false
                        if autoRefused then run.phase = "click" else Start(Page(), true) end
                    elseif waiting and run.wait < 2 then run.waitingMaterials = true
                    else Message("materials for the next step are missing"); Cancel() end
                end
            end
        end
    end
    Update()
end)
end)
