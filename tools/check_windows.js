const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const root = path.resolve(__dirname, '..');
const windows = fs.readFileSync(path.join(root, 'KutzUI/Windows.lua'), 'utf8');
const code = `
local ns = {} local combat = false local sw, sh = 1000, 700
UIParent = { GetWidth = function() return sw end, GetHeight = function() return sh end }
InCombatLockdown = function() return combat end
CreateFrame = function() return {SetScript = function() end} end
ns.Module = function(_, fn) fn() end
local frame = {x=0,y=0,w=400,h=200,writes=0}
function frame:GetLeft() return self.x end
function frame:GetBottom() return self.y end
function frame:GetWidth() return self.w end
function frame:GetHeight() return self.h end
function frame:SetSize(w,h) self.w=w; self.h=h; self.writes=self.writes+1 end
function frame:ClearAllPoints() end
function frame:SetPoint(_,_,_,x,y) self.x=x; self.y=y end
ChatFrame1 = frame; ChatFrame2 = frame
KutzUIDB = {winRect={chat={x=950,y=650,w=400,h=200},clog={x=-50,y=-20,w=400,h=200}}}
assert(load([====[${windows}]====]))('KutzUI', ns)
ns.ApplyWindow('chat'); assert(frame.x==600 and frame.y==500)
assert(KutzUIDB.winRect.chat.x==950)
local writes=frame.writes; ns.ApplyWindow('chat'); assert(frame.writes==writes)
sw=1500; sh=1000; ns.ApplyWindow('chat'); assert(frame.x==950 and frame.y==650)
combat=true; sw=300; sh=150; ns.ApplyWindow('chat'); assert(frame.x==950)
combat=false; ns.ApplyWindow('chat'); assert(frame.x==0 and frame.y==0 and frame.w==300 and frame.h==150)
ns.ApplyWindow('clog'); assert(frame.x==0 and frame.y==24 and frame.h==126)
print('OK window bounds, resize restoration and combat deferral')
`;
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
if (lauxlib.luaL_dostring(L, to_luastring(code)) !== 0) {
    console.error(to_jsstring(lua.lua_tostring(L, -1))); process.exit(1);
}
