// Planner and run controller in a small fake WoW client; no live game or new dependencies.
const fs = require('fs');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const source = fs.readFileSync(require('path').join(__dirname, '../KutzUI/SubCraft.lua'), 'utf8');
const code = `
local source = [====[${source}]====]
local realPrint = print
local function Recipe(id, name, output, made, ...)
 return {id=id,name=name,outputItemID=output,quantityMin=made,reagents={...}}
end
local function R(item, quantity) return {itemID=item,quantity=quantity} end
local boots = Recipe(101,"Hillman's Leather Boots",201,1,R(202,1),R(205,2),R(206,1))
local hide = Recipe(102,"Cured Medium Hide",202,1,R(203,1),R(204,1))
local names={[201]="Hillman's Leather Boots",[202]="Cured Medium Hide",[203]="Medium Hide",
 [204]="Salt",[205]="Medium Leather",[206]="Fine Thread"}
local function Stock(n, cured)
 return {[202]=cured or 0,[203]=n,[204]=n,[205]=n*2,[206]=n}
end
local function New(options)
 local o=options or {}
 local g={frames={},messages={},calls={},stock=o.stock or Stock(1),selected=101,quantity=o.quantity or 1,
  recipes=o.recipes or {boots,hide},shown=true,profession=77,reads=0,clicking=false,stops=0,
  linked=o.linked or false,refuse=o.refuse,casting=nil,countCalls=0}
 function print(v) table.insert(g.messages,v) end
 local secret={}
 g.secret=secret
 function issecretvalue(v) return v==secret end
 function CreateFrame(kind, name, parent, template)
  local f={kind=kind,parent=parent,template=template,shown=true,enabled=true,events={},points={}}
  function f:Hide() self.shown=false end
  function f:Show() self.shown=true end
  function f:SetScript(k,v) self[k]=v end
  function f:RegisterEvent(k) self.events[k]=true end
  f.RegisterUnitEvent=f.RegisterEvent
  function f:SetPoint(...) table.insert(self.points,{...}) end
  function f:SetSize(w,h) self.width=w;self.height=h end
  function f:SetHeight(h) self.height=h end
  function f:SetWidth(w) self.width=w end
  function f:SetJustifyH() end
  function f:SetFontObject(font) self.font=font end
  function f:SetText(v)
   self.text=v
   if self.OnTextChanged then self.OnTextChanged(self,false) end
  end
  function f:GetText() return self.text or '' end
  function f:SetAutoFocus() end
  function f:SetNumeric() end
  function f:SetMaxLetters() end
  function f:ClearFocus() if self.OnEditFocusLost then self.OnEditFocusLost(self) end end
  function f:GetTextWidth() return #(self.text or '')*6 end
  function f:Enable() self.enabled=true end
  function f:Disable() self.enabled=false end
  function f:CreateFontString()
   local font=CreateFrame('FontString',nil,self)
   if not g.label then g.label=font else g.capacity=font end
   return font
  end
  table.insert(g.frames,f)
  if kind=='Button' then g.button=f;g.strip=parent end
  if kind=='EditBox' then g.amount=f end
  return f
 end
 local function ReadCount(id) g.countCalls=g.countCalls+1;return g.stock[id] or 0 end
 ItemUtil={GetCraftingReagentCount=function(id,only)
  assert(only==g.onlyCharacter,'transaction inventory flag');return ReadCount(id)
 end}
 C_Item={GetItemCount=function(id,bank,uses,reagent)
  assert(bank==true and uses==false and reagent==true);return ReadCount(id)
 end,GetItemNameByID=function(id) return names[id] end}
 GetItemCount=ReadCount
 GetItemInfo=function(id) return names[id] end
 UnitCastingInfo=function(unit) assert(unit=='player');return g.casting end
 local byID={}
 for _, recipe in ipairs(g.recipes) do byID[recipe.id]=recipe end
 g.byID=byID
 C_TradeSkillUI={
  IsTradeSkillReady=function() return not g.notReady end,
  IsTradeSkillLinked=function() return g.linked end,
  IsTradeSkillGuild=function() return g.guild or false end,
  IsNPCCrafting=function() return g.npc or false end,
  GetBaseProfessionInfo=function() return {professionID=g.profession} end,
  GetAllRecipeIDs=function()
   g.reads=g.reads+1;local ids={};for _,r in ipairs(g.recipes) do table.insert(ids,r.id) end;return ids
  end,
  GetRecipeInfo=function(id) local r=byID[id];return r and {name=r.name,learned=r.learned~=false} end,
  GetRecipeSchematic=function(id,recraft)
   assert(recraft==false);local r=byID[id];local slots={}
   for _,v in ipairs(r.reagents) do table.insert(slots,{reagentType=1,quantityRequired=v.quantity,reagents={{itemID=v.itemID}}}) end
   table.insert(slots,{reagentType=2,quantityRequired=99,reagents={{itemID=99999}}})
   table.insert(slots,{reagentType=3,quantityRequired=99,reagents={{itemID=99998}}})
   return {outputItemID=r.outputItemID,quantityMin=r.quantityMin,quantityMax=r.quantityMin+1,reagentSlotSchematics=slots}
  end,
  CraftRecipe=function(id,count)
   table.insert(g.calls,{id=id,count=count,click=g.clicking})
   if not g.clicking and g.throwAuto then error('hardware event required') end
   if not g.clicking and g.blockAuto then g:Event(g.blockAuto,'KutzUI','CraftRecipe');return end
   if not g.clicking and g.refuse then return end
   g:Event('TRADE_SKILL_CRAFT_BEGIN',id)
   g:Event('UNIT_SPELLCAST_START','player','start',id)
  end,
  StopRecipeRepeat=function() assert(g.clicking);g.stops=g.stops+1 end,
 }
 local transaction={ShouldUseCharacterInventoryOnly=function() return g.onlyCharacter end}
 local page={IsShown=function() return g.shown end,
  SchematicForm={GetRecipeInfo=function() return {recipeID=g.selected} end,GetTransaction=function() return transaction end},
  CreateMultipleInputBox={GetValue=function() return g.quantity end}}
 ProfessionsFrame={CraftingPage=page}
 local ns={Module=function(key,body) assert(key=='subcraft');if not o.off then body() end end}
 assert(load(source))('KutzUI',ns)
 g.plan=ns.SubCraftPlan
 g.maximum=ns.SubCraftMaximum
 function g:Event(event,...)
  for _,f in ipairs(self.frames) do if f.events[event] then f.OnEvent(f,event,...) end end
 end
 function g:Tick(dt)
  for _,f in ipairs(self.frames) do if f.OnUpdate and f.shown then f.OnUpdate(f,dt or .2) end end
 end
 function g:Click()
  assert(self.button and self.button.shown and self.button.enabled,'button unavailable')
  self.clicking=true;self.button.OnClick(self.button);self.clicking=false
 end
 function g:Success(id)
  local r=self.byID[id]
  for _,v in ipairs(r.reagents) do self.stock[v.itemID]=(self.stock[v.itemID] or 0)-v.quantity end
  if r.outputItemID then self.stock[r.outputItemID]=(self.stock[r.outputItemID] or 0)+r.quantityMin end
  self:Event('UNIT_SPELLCAST_SUCCEEDED','player','success',id)
 end
 function g:Stopped()
  local count=0;for _,v in ipairs(self.messages) do if v=='KutzUI: sub-assembly run stopped' then count=count+1 end end;return count
 end
 g:Event('TRADE_SKILL_SHOW')
 return g
end
local g=New()
local p,m=g.plan(101,1,{boots,hide},Stock(1))
assert(#p==2 and #m==0 and p[1].recipeID==102 and p[1].crafts==1 and p[2].recipeID==101)
assert(g.label.text=='Needs: 1 Cured Medium Hide (you can make it)')
assert(g.button.text=='Make 1 (parts first)')
assert(g.strip.points[1][5]==-31 and g.strip.height==24)
local held=Stock(1,1)
p,m=g.plan(101,1,{boots,hide},held)
assert(#p==1 and #m==0 and held[202]==1,'held stock must not be mutated')
g=New({stock=held});assert(not g.strip.shown,'already in bags: strip hidden')
g=New({stock=Stock(3,1),quantity=3})
p,m=g.plan(101,3,{boots,hide},g.stock)
assert(#p==2 and p[1].crafts==2 and p[2].crafts==3 and #m==0)
g=New({stock=Stock(10,3),quantity=10})
p,m=g.plan(101,10,{boots,hide},g.stock)
assert(#p==2 and p[1].recipeID==102 and p[1].crafts==7 and p[2].recipeID==101 and p[2].crafts==10 and #m==0)
g:Click();assert(g.calls[1].id==102 and g.calls[1].count==7)
for i=1,3 do g:Success(102) end
assert(g.label.text=='Step 1 of 2: Cured Medium Hide 3 / 7')
for i=4,7 do g:Success(102) end
g.casting='finishing';g:Tick(.4);assert(#g.calls==1,'wait for cast to clear')
g.casting=nil;g:Tick(.2)
assert(#g.calls==2 and g.calls[2].id==101 and g.calls[2].count==10 and not g.calls[2].click)
for i=1,10 do g:Success(101) end
g:Tick(.4);assert(g:Stopped()==0 and not g.label.text:find('Step '),'automatic whole-run completion returns to normal plan')

local parent=Recipe(301,'Parent',401,1,R(402,3),R(403,1))
local part=Recipe(302,'Part',402,2,R(404,1))
local other=Recipe(303,'Other',403,1,R(402,1))
p,m=g.plan(301,1,{parent,part,other},{[404]=2})
assert(#p==3 and #m==0 and p[1].recipeID==302 and p[1].crafts==2 and p[2].recipeID==303,'ceil and surplus reuse')
local deep=Recipe(304,'Deep',404,1,R(405,2))
p,m=g.plan(301,1,{parent,part,other,deep},{[405]=4})
assert(#p==4 and #m==0 and p[1].recipeID==304 and p[1].crafts==2 and p[2].recipeID==302,'two levels deep')
part=Recipe(302,'Part',402,1,R(404,1))
parent=Recipe(301,'Parent',401,1,R(403,1),R(402,1))
p,m=g.plan(301,1,{parent,part,other},{[404]=2})
assert(#p==3 and #m==0 and p[1].recipeID==302 and p[1].crafts==2 and p[2].recipeID==303,'shared part merged before first use')
-- A later contribution to an already merged part brings its own dependencies forward too.
parent=Recipe(301,'Parent',401,1,R(403,1),R(402,2))
p,m=g.plan(301,1,{parent,part,other,deep},{[404]=1,[405]=4})
assert(#m==0 and p[1].recipeID==304 and p[2].recipeID==302 and p[2].crafts==3 and p[3].recipeID==303)
local sharedRaw=Recipe(305,'Shared raw',406,1,R(402,1),R(404,1))
p,m=g.plan(305,1,{sharedRaw,part},{[404]=1})
assert(#m==1 and m[1].itemID==404 and m[1].short==1,'two steps cannot spend the same raw stack')
g=New({stock={[205]=2,[206]=1}})
p,m=g.plan(101,1,{boots,hide},g.stock)
assert(#m==2 and m[1].itemID==203 and m[1].short==1 and m[2].itemID==204 and m[2].short==1)
assert(g.strip.shown and not g.button.shown and g.label.font=='GameFontRed')
assert(g.label.text=='Missing: 1 Medium Hide, 1 Salt')
local cycleA=Recipe(501,'A',601,1,R(602,1))
local cycleB=Recipe(502,'B',602,1,R(601,1))
p,m=g.plan(501,1,{cycleA,cycleB},{})
assert(#m==1 and m[1].itemID==601 and m[1].short==1,'cycle bounded')
local mergeA=Recipe(511,'Merge A',611,2,R(612,1))
local mergeB=Recipe(512,'Merge B',612,2,R(611,1))
local mergeTarget=Recipe(513,'Merge target',613,1,R(611,1),R(612,1),R(611,2))
p,m=g.plan(513,1,{mergeA,mergeB,mergeTarget},{[612]=1})
assert(#m>0,'a cycle exposed by merged steps cannot be ready')
local chain={}
for i=1,11 do table.insert(chain,Recipe(700+i,'Depth '..i,800+i,1,R(801+i,1))) end
p,m=g.plan(701,1,chain,{[812]=1})
assert(#p==9 and #m==1 and m[1].itemID==810,'depth over 8 bounded')
local alternate=Recipe(103,'Alternative',202,1,R(207,1))
p,m=g.plan(101,1,{boots,hide,alternate},{[207]=1,[205]=2,[206]=1})
assert(#m==0 and p[1].recipeID==103,'prefer fully held alternative')
p,m=g.plan(101,1,{boots,alternate,hide},{[205]=2,[206]=1})
assert(p[1].recipeID==102,'otherwise choose lowest ID')
local enchant=Recipe(104,'Enchant',nil,1,R(203,1))
p,m=g.plan(101,1,{boots,enchant},Stock(1))
assert(#p==1 and m[1].itemID==202,'enchants are never producers')
for _,flag in ipairs({'linked','guild','npc','notReady'}) do
 g=New({linked=true});g.linked=false;g[flag]=true;g:Tick();assert(not g.strip or not g.strip.shown)
end
g=New();local reads=g.reads;local counts=g.countCalls
for i=1,10 do g:Tick() end
assert(g.reads==reads and g.countCalls==counts,'no recipe rebuild or inventory scan while idle')
g.quantity=2;g.stock=Stock(2);g:Event('BAG_UPDATE_DELAYED');g:Tick()
assert(g.button.text=='Make 2 (parts first)' and g.reads==reads)
g:Event('BAG_UPDATE_DELAYED');assert(g.reads==reads)
g:Event('TRADE_SKILL_LIST_UPDATE');assert(g.reads==reads+1)
g:Click();assert(g.calls[1].id==102 and g.calls[1].count==2 and g.button.text=='Stop')
g:Event('UNIT_SPELLCAST_SUCCEEDED','player','unrelated',999)
assert(g.label.text=='Step 1 of 2: Cured Medium Hide 0 / 2')
g:Success(102);g:Success(102);g:Tick(.2);assert(#g.calls==1,'delay before next step')
g:Tick(.2);assert(g.calls[2].id==101 and g.calls[2].count==2)
g:Success(101);g:Success(101);g:Tick(.4);assert(g:Stopped()==0)

-- Automatic refusal: no begin/start in 1.5 seconds, one attempt, manual next, remembered next run.
g=New({refuse=true});g:Click();g:Success(102);g:Tick(.4)
assert(#g.calls==2);g:Tick(1.6)
assert(g.button.text=="Next: Hillman's Leather Boots x1 (step 2 of 2)" and g.button.enabled)
g:Tick(3);assert(#g.calls==2,'no retry loop')
g:Click();assert(g.calls[3].id==101 and g.calls[3].count==1 and g.calls[3].click)
g:Success(101);g:Tick(.4)
g.stock=Stock(1);g:Event('BAG_UPDATE_DELAYED');g:Click();g:Success(102);g:Tick(.4)
assert(#g.calls==4 and g.button.text:find('Next:'),'later run skips automatic attempt and wait')
g:Click();assert(#g.calls==5);g:Success(101);g:Tick(.4)
g=New({refuse=true});g:Click();g:Success(102);g:Tick(.4);g:Tick(1.6)
assert(g.button.text:find('Next:'))
g:Event('UNIT_SPELLCAST_START','player','late',101)
assert(g.button.text=='Stop','late automatic start removes manual retry')
g:Success(101);g:Tick(.4);assert(g:Stopped()==0)
for _,mode in ipairs({'throwAuto','blockAuto','forbidAuto'}) do
 g=New();if mode=='throwAuto' then g.throwAuto=true else g.blockAuto=mode=='blockAuto' and 'ADDON_ACTION_BLOCKED' or 'ADDON_ACTION_FORBIDDEN' end
 g:Click();g:Success(102);g:Tick(.4)
 assert(g.button.text:find('Next:') and g.button.enabled and #g.messages==1,'refused automatic call falls back immediately')
end
-- Manual failure, interruption, close, selection and profession change all stop once.
for _,event in ipairs({'UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_FAILED'}) do
 g=New();g:Click();g:Event(event,'player','one',102);g:Event(event,'player','one',102)
 assert(g:Stopped()==1 and g.button.text=='Make 1 (parts first)')
end
g=New();g:Click();g.shown=false;g:Event('TRADE_SKILL_CLOSE');g:Event('TRADE_SKILL_CLOSE')
assert(g:Stopped()==1 and not g.strip.shown)
g=New();g:Click();g.shown=false;g:Tick();assert(g:Stopped()==1)
g=New();g:Click();g.selected=102;g:Tick();assert(g:Stopped()==1)
g=New();g:Click();g.profession=78;g:Tick();assert(g:Stopped()==1)
g=New();g:Click();g:Success(102);g.stock[205]=0;g:Tick(.4)
assert(g:Stopped()==1 and #g.calls==1,'materials vanished between steps')
-- Finishing a craft can briefly clear profession readiness/selection while the UI refreshes.
g=New();g:Click();g:Success(102)
g.notReady=true;g.selected=nil;g:Event('BAG_UPDATE_DELAYED');g:Tick(.4)
assert(g:Stopped()==0 and g.strip.shown and #g.calls==1,'temporary profession refresh preserves the pending parent')
g.notReady=false;g.selected=101;g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==2 and g.calls[2].id==101,'parent starts after profession data returns')
g=New();g:Click();g:Success(102);g.notReady=true;g.selected=0;g.profession=0;g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==1,'zero IDs during a refresh are unavailable data')
g.notReady=false;g.selected=101;g.profession=77;g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==2)
g=New();g:Click();g.notReady=true;g.casting='long part cast';g:Tick(6)
assert(g:Stopped()==0,'data refresh does not time out an active craft')
g:Success(102);g.casting=nil;g.notReady=false;g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==2)
g=New();g:Click();g:Success(102);g:Event('TRADE_SKILL_SHOW');g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==2,'same-profession show refresh does not cancel')
g=New();g:Click();g:Success(102);g:Event('TRADE_SKILL_DATA_SOURCE_CHANGING');g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==1,'data source refresh pauses advancement')
g:Event('TRADE_SKILL_DATA_SOURCE_CHANGED');g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==2,'same-profession data source refresh resumes')
g=New();g:Click();g:Event('TRADE_SKILL_DATA_SOURCE_CHANGING');g.profession=78
g:Event('TRADE_SKILL_DATA_SOURCE_CHANGED');assert(g:Stopped()==1,'an actual profession change still cancels')
g=New();g:Click();g.notReady=true;g.linked=true;g:Tick(.4)
assert(g:Stopped()==1,'foreign profession views cancel even during data refresh')
g=New();g:Click();g:Success(102);g.stock[202]=0;g:Tick(.4)
assert(g:Stopped()==0 and #g.calls==1,'allow the completed part to arrive in item counts')
g.stock[202]=1;g:Event('BAG_UPDATE_DELAYED');g:Tick(.2)
assert(g:Stopped()==0 and #g.calls==2 and g.calls[2].id==101,'delayed item count starts parent exactly once')
g:Tick(.4);assert(#g.calls==2)
g=New();g:Click();g:Success(102);g.stock[202]=0;g:Tick(.4);g:Tick(2)
assert(g:Stopped()==1 and #g.calls==1,'never start a parent whose parts did not arrive')
g=New();g:Click();g.notReady=true;g:Tick(6)
assert(g:Stopped()==1,'unavailable profession data has a bounded wait')
g=New();C_TradeSkillUI.CraftRecipe=nil;g:Click()
assert(#g.calls==0 and g.messages[1]:find('CraftRecipe unavailable or failed') and g:Stopped()==1)
g=New();C_TradeSkillUI.CraftRecipe=function() error('blocked') end;g:Click()
assert(g.messages[1]:find('CraftRecipe unavailable or failed'))
g=New({stock=Stock(3),quantity=3});g:Click();g:Click()
assert(g.stops==1 and not g.button.enabled,'Stop is a hardware click and stops the repeat queue')
g:Success(102);g:Tick(2);assert(#g.calls==1 and g:Stopped()==1,'Stop prevents remaining steps after current craft')
g=New();g:Click();g:Success(102);g:Click();g:Tick(2);assert(#g.calls==1 and g:Stopped()==1,'Stop during delay')
g=New({refuse=true});g:Click();g:Success(102);g:Tick(.4);g:Click();g:Tick(2)
assert(g:Stopped()==1 and #g.calls==2 and not g.button.text:find('Next:'),'Stop while automatic start is pending')
-- Count helper, transaction flag, secret/error fallback and quantity guards.
g=New();g.onlyCharacter=true;g:Event('BAG_UPDATE_DELAYED')
ItemUtil.GetCraftingReagentCount=function() error('helper unavailable') end
g:Event('BAG_UPDATE_DELAYED');assert(g.strip.shown)
C_Item.GetItemCount=function() return g.secret end
g:Event('BAG_UPDATE_DELAYED');assert(g.strip.shown,'fallback to legacy item count')
g.quantity=g.secret;g:Tick();assert(g.button.text=='Make 1 (parts first)')
-- Capacity includes both held parts and all craftable parts, limited by shared raw stock.
g=New({stock=Stock(10,3)})
assert(g.maximum(101,{boots,hide},g.stock)==10)
assert(g.capacity.text=='Max crafts: 10  Qty:' and g.strip.shown and g.button.text=='Make 1')
assert(g.maximum(101,{boots,hide},Stock(1,1))==1)
assert(g.maximum(101,{boots,hide},{[203]=7,[204]=7,[205]=20,[206]=10,[202]=3})==10)
assert(g.maximum(101,{boots,hide},{[203]=7,[204]=2,[205]=20,[206]=10,[202]=3})==5,'Salt limits the total')
assert(g.maximum(305,{sharedRaw,part},{[404]=5})==2,'shared raw stack counted once')
assert(g.maximum(301,{parent,part,other,deep},{[405]=18})==3,'two-level capacity')
local batchParent=Recipe(901,'Batch parent',1001,1,R(1002,3),R(1003,1))
local batchPart=Recipe(902,'Batch part',1002,2,R(1003,1))
assert(g.maximum(901,{batchParent,batchPart},{[1003]=10})==4,'multi-output rounding and shared raw capacity')
assert(g.maximum(501,{cycleA,cycleB},{})==0)
assert(g.maximum(999,{boots,hide},Stock(10))==0)
assert(g.maximum(101,{boots,hide},{})==0)
assert(g.maximum(301,{Recipe(301,'Free',401,1)},{})==2147483647,'free recipes cannot make the search loop forever')
-- Native count is zero/capped: our field can still request the full ten-parent batch.
g.quantity=0;g:Tick()
local beforeCounts=g.countCalls
g.amount:SetText('10');assert(g.amount.text=='10' and g.button.text=='Make 10 (parts first)')
assert(g.countCalls==beforeCounts,'typing reuses the cached stock and capacity')
g.quantity=1;g:Tick();assert(g.amount.text=='10','native quantity cannot overwrite an explicit choice')
g:Click();assert(g.calls[1].id==102 and g.calls[1].count==7 and not g.amount.shown)
for i=1,7 do g:Success(102) end
g:Tick(.4);assert(g.calls[2].id==101 and g.calls[2].count==10)
for i=1,10 do g:Success(101) end
g:Tick(.4);assert(g:Stopped()==0)
-- A smaller choice, over-limit/empty entry, changing bags, and resetting on selection.
g=New({stock=Stock(10,3)});g.amount:SetText('6');g:Click()
assert(g.calls[1].id==102 and g.calls[1].count==3)
for i=1,3 do g:Success(102) end
g:Tick(.4);assert(g.calls[2].id==101 and g.calls[2].count==6)
g=New({stock=Stock(10,3)});g.amount:SetText('99')
assert(g.amount.text=='10' and g.button.text=='Make 10 (parts first)','quantity clamped to maximum')
g.amount:SetText('');g.amount:ClearFocus();assert(g.amount.text=='10','empty entry restored')
g.stock[204]=2;g:Event('BAG_UPDATE_DELAYED')
assert(g.capacity.text=='Max crafts: 5  Qty:' and g.amount.text=='5')
g.stock[204]=10;g:Event('BAG_UPDATE_DELAYED');assert(g.amount.text=='5','clamping does not restore a stale larger request')
g.selected=102;g:Tick();assert(not g.strip.shown,'selection clears custom quantity')
g.selected=101;g:Tick();assert(g.amount.text=='1')
g=New({off=true});assert(#g.frames==0 and not g.plan,'disabled module creates no frames')
realPrint('OK subcraft plans, maximum craftable counts, independent quantities, merged batches, shortages, automatic runs, refusal fallback, Stop and cancellation')
`;
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
if (lauxlib.luaL_dostring(L, to_luastring(code)) !== 0) {
  console.error(to_jsstring(lua.lua_tostring(L, -1))); process.exit(1);
}
