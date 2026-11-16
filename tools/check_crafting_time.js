const fs = require('fs');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const source = fs.readFileSync(require('path').join(__dirname, '../KutzUI/CraftingTime.lua'), 'utf8');
const code = `
local now, ms, hover, text = 0, 3000, false, ""
local frames={}
function GetTime() return now end
C_Spell={GetSpellInfo=function() return {castTime=ms} end}
function UnitCastingInfo() return "Craft",nil,nil,now*1000,now*1000+ms end
function CreateFrame()
 local f={Hide=function() end,Show=function() end,SetParent=function() end,
 RegisterEvent=function() end,RegisterUnitEvent=function() end}
 function f:SetScript(k,v) self[k]=v end
 frames[#frames+1]=f; return f
end
local label={Hide=function() end,Show=function() end,SetPoint=function() end,SetHeight=function() end}
function label:SetText(v) text=v end
ProfessionsFrame={CraftingPage={IsShown=function() return true end,
 SchematicForm={GetRecipeInfo=function() return {recipeID=10} end},
 CreateMultipleInputBox={GetValue=function() return 100 end},
 CreateAllButton={IsMouseOver=function() return hover end},
 GetCraftableCount=function() return 150 end,CreateFontString=function() return label end}}
assert(load([====[${source}]====]))('KutzUI',{Module=function(_,fn) fn() end})
local function event(name,...) frames[2].OnEvent(frames[2],name,...) end
event('TRADE_SKILL_SHOW'); assert(text:find('100 crafts %- 5:00'),text)
assert(text:find('150 crafts %- 7:30'),text)
event('TRADE_SKILL_CRAFT_BEGIN',10)
event('UNIT_SPELLCAST_START','player','one',10)
now=1; frames[1].OnUpdate(frames[1],.1)
assert(text:find('100 / 100 crafts remaining %- 4:59'),text)
now=3; event('UNIT_SPELLCAST_SUCCEEDED','player','one',10)
assert(text:find('99 / 100 crafts remaining %- 4:57'),text)
event('UNIT_SPELLCAST_START','player','two',10)
event('UNIT_SPELLCAST_INTERRUPTED','player','two',10)
assert(text:find('Create:'),text)
ms=1500; hover=true
event('TRADE_SKILL_CRAFT_BEGIN',10)
event('UNIT_SPELLCAST_START','player','three',10)
assert(text:find('150 / 150 crafts remaining %- 3:45'),text)
event('UNIT_SPELLCAST_SUCCEEDED','player','other',999)
assert(text:find('150 / 150'),text)
for i=1,150 do event('UNIT_SPELLCAST_SUCCEEDED','player',tostring(i),10) end
assert(text:find('Create:'),text)
event('TRADE_SKILL_CRAFT_BEGIN',10)
event('UNIT_SPELLCAST_STOP','player','stop',10)
now=now+2; frames[1].OnUpdate(frames[1],.1)
assert(text:find('Create:'),text)
print('OK crafting estimates, actual duration, countdown, completion, cancellation and Create All')
`;
const L=lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(code))!==0){console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exit(1);}
