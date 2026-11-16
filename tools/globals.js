const fs = require("fs"); const luaparse = require("luaparse");
const dir = process.argv[2];
const all = new Set(); let bad = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith(".lua"))) {
  let ast;
  try { ast = luaparse.parse(fs.readFileSync(dir + "/" + f, "utf8"), { luaVersion: "5.1", scope: true }); }
  catch (e) { bad++; console.log("SYNTAX FAIL " + f + ": " + e.message); continue; }
  const globals = new Set();
  (function walk(n) {
    if (!n || typeof n !== "object") return;
    if (Array.isArray(n)) return n.forEach(walk);
    if (n.type === "Identifier" && n.isLocal === false) globals.add(n.name);
    for (const k of Object.keys(n)) if (k !== "loc" && k !== "range" && k !== "globals") walk(n[k]);
  })(ast.body);
  globals.forEach(g => all.add(g));
  console.log("OK   " + f);
}
const known = new Set(("_G ipairs pairs pcall select type unpack tostring tonumber string math table wipe strsplit strlower strtrim " +
 "GetAddOnMemoryUsage UpdateAddOnMemoryUsage collectgarbage setmetatable IsInRaid GetLocale GetCVar SetCVar ReloadUI C_AddOns GetRealmName LoadAddOn error LibStub GetCVarBool GetFramerate GetNetStats GetCursorPosition GetGuildInfo UnitFactionGroup UnitLevel UnitRace UnitIsAFK UnitIsDND UnitIsConnected UnitIsGhost GetBindingKey SetOverrideBindingClick ClearOverrideBindings ColorPickerFrame CreateFrame UIParent GameTooltip hooksecurefunc InCombatLockdown C_Timer GetTime UnitExists UnitName UnitClass UnitReaction UnitIsPlayer " +
 "C_BattleNet C_FriendList C_SummonInfo C_MerchantFrame GetCoinTextureString CanMerchantRepair GetRepairAllCost CanGuildBankRepair GetGuildBankWithdrawMoney RepairAllItems GetMoney GetNumLootItems LootSlot LootSlotHasItem IsGuildMember CancelDuel AcceptGroup StaticPopup_Hide Screenshot C_NamePlate GetInventoryItemLink C_Container CreateColor C_Map next UnitGUID UnitIsUnit TooltipUtil TooltipDataProcessor GetItemQualityColor C_Item GetCVarDefault UnitXP UnitXPMax GetXPExhaustion StatusTrackingBarManager StatusTrackingBarInfo UnitHealth UnitHealthMax UnitPower UnitPowerMax UnitPowerType UnitIsConnected UnitIsDeadOrGhost UnitHealthPercent UnitPowerPercent UnitAffectingCombat PlayerFrame_UpdateStatus UnitCanAttack GetUnitName UnitGroupRolesAssigned GetBuildInfo geterrorhandler seterrorhandler BuyMerchantItem GetMerchantItemInfo GetMerchantItemMaxStack MerchantFrame " +
 "UnitCastingInfo UnitChannelInfo UnitCastingDuration UnitChannelDuration issecretvalue CurveConstants RAID_CLASS_COLORS FACTION_BAR_COLORS " +
 "PowerBarColor STANDARD_TEXT_FONT RegisterUnitWatch UnregisterUnitWatch C_DamageMeter C_Spell C_DeathRecap UnitIsDead date time GameTooltip_SetDefaultAnchor SlashCmdList Enum CreateAbbreviateConfig AbbreviateNumbers " +
 "AbbreviateLargeNumbers KutzUIDB SLASH_KUTZUI1 print SetPortraitTexture KEY_BUTTON1 KEY_MOUSEWHEELUP KEY_MOUSEWHEELDOWN " +
 // Extra client APIs and saved-file names, so the typo check does not flag them.
 "KutzInventoryDB SLASH_KUTZINVENTORY1 C_AuctionHouse C_Bank C_ClassTalents C_CurrencyInfo C_GossipInfo C_Reputation C_SkillInfo C_SpecializationInfo C_SpellBook C_TradeSkillUI C_Traits " +
 "GetAchievementInfo GetArmorPenetration GetAverageItemLevel GetAvoidance GetBlockChance GetCategoryInfo GetCategoryNumAchievements GetCombatRating GetCombatRatingBonus GetCritChance GetCurrentGuildBankTab GetDodgeChance GetExpertise " +
 "GetGuildBankItemInfo GetGuildBankItemLink GetGuildBankMoney GetGuildBankTabInfo GetHaste GetHitModifier GetInstanceInfo GetInventoryItemDurability GetInventoryItemQuality GetInventorySlotInfo GetItemInfo GetItemStats GetLifesteal GetMasteryEffect GetMeleeHaste " +
 "GetMerchantItemID GetMerchantNumItems GetNumSkillLines GetNumTrainerServices GetPVPLifetimeStats GetPVPSessionStats GetPVPYesterdayStats GetParryChance GetPersonalRatedInfo GetProfessionInfo GetProfessions GetRangedCritChance GetRangedHaste GetRangedHitModifier GetRealZoneText GetShieldBlock GetSkillLineInfo " +
 "GetSpecialization GetSpecializationInfo GetSpeed GetSpellBonusDamage GetSpellBonusHealing GetSpellCritChance GetSpellHitModifier GetSpellInfo GetSpellPenetration GetStatistic GetStatisticsCategoryList GetSubZoneText GetTalentTabInfo GetTotalAchievementPoints " +
 "GetTrainerServiceCost GetTrainerServiceInfo GetTrainerServiceLevelReq GetTrainerServiceSkillReq GetTrainerServiceTypeFilter GetUnitSpeed GetUnspentTalentPoints GetVersatilityBonus GetZoneText IsTradeskillTrainer " +
 "SetTrainerServiceTypeFilter UnitArmor UnitAttackPower UnitAttackSpeed UnitDamage UnitDefenseSkill UnitHonor UnitHonorLevel UnitHonorMax UnitRangedAttackPower UnitRangedDamage UnitResistance UnitSex UnitSpellHaste UnitStat").split(" "));
const odd = [...all].filter(g => !known.has(g)).sort();
console.log("\nglobals used that are NOT in the expected WoW/Lua list (check for typos):\n  " + (odd.join(", ") || "(none)"));
process.exit(bad ? 1 : 0);
