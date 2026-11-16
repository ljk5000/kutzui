#!/usr/bin/env node
// Checks a release zip the way a player would use it: extracted alone into an empty AddOns folder.
//
//   node tools/check_release_zip.js <zip> <kutzui|inventory> [expected version]
//
// - the zip holds exactly the addon folders of that download, nothing else (no tools, exports, tests)
// - every folder has <folder>.toc for this client, and every file the .toc lists is in the zip
// - every ## Dependencies is satisfied inside the same zip (## OptionalDeps may be missing)
// - all .toc versions of the download agree (and match the tag, when given)
// - every .lua file parses as Lua
// - kutzui: the full fake-game run (tools/harness.js) on the EXTRACTED folders
// - inventory: the extracted addon loads and logs in with no KutzUI present, and creates its saved table
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const luaparse = require("luaparse");

const UNITS = {
  kutzui: ["KutzUI", "KutzUI_Monitor", "KutzUI_Options"],
  inventory: ["KutzInventory"],
};
const INTERFACE = "16001";
const ALLOWED_EXTRA = /^(CHANGELOG\.md|LICENSE\.txt)$/;   // the packager's changelog, our licence copy
const FORBIDDEN = /(^|\/)(tools|export|node_modules|companion|schema|docs|References|WTF)(\/|$)|\.test\.js$|\.pkgmeta|inventory\.json|\.lnk$/i;

const licensed = process.argv.includes("--licensed");      // each addon folder must carry LICENSE.txt
const [zip, unit, wantVersion] = process.argv.slice(2).filter((a) => !a.startsWith("--"));
if (!zip || !UNITS[unit]) {
  console.error("usage: node tools/check_release_zip.js <zip> <kutzui|inventory> [version] [--licensed]");
  process.exit(2);
}
const problems = [];
const bad = (m) => problems.push(m);

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "kutz-zip-"));
const unz = spawnSync("unzip", ["-q", path.resolve(zip), "-d", dir], { encoding: "utf8" });
if (unz.status !== 0) { console.error("FAIL could not unzip: " + unz.stderr); process.exit(1); }

const files = [];
(function walk(d, rel) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const r = rel ? rel + "/" + e.name : e.name;
    if (e.isDirectory()) walk(path.join(d, e.name), r); else files.push(r);
  }
})(dir, "");

const top = [...new Set(files.map((f) => f.split("/")[0]))].sort();
const want = [...UNITS[unit]].sort();
if (JSON.stringify(top) !== JSON.stringify(want)) bad(`top-level folders are [${top}], expected [${want}]`);
for (const f of files) if (FORBIDDEN.test(f)) bad("should not ship: " + f);

const versions = {};
for (const addon of want) {
  const tocPath = path.join(dir, addon, addon + ".toc");
  if (!fs.existsSync(tocPath)) { bad(`${addon}/${addon}.toc is missing`); continue; }
  const toc = fs.readFileSync(tocPath, "utf8").split(/\r?\n/);
  const meta = {};
  for (const l of toc) { const m = /^##\s*([^:]+):\s*(.*)$/.exec(l); if (m) meta[m[1].trim()] = m[2].trim(); }
  if (meta.Interface !== INTERFACE) bad(`${addon}: ## Interface is ${meta.Interface}, expected ${INTERFACE}`);
  if (!meta.Version) bad(`${addon}: no ## Version`); else versions[addon] = meta.Version;
  if (licensed && !fs.existsSync(path.join(dir, addon, "LICENSE.txt"))) bad(`${addon}/LICENSE.txt is missing (the MIT licence must ship with the code)`);
  for (const dep of (meta.Dependencies || meta.RequiredDeps || "").split(",").map((s) => s.trim()).filter(Boolean)) {
    if (!want.includes(dep)) bad(`${addon} needs ${dep}, which is not in this zip`);
  }
  const listed = toc.map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));
  for (const f of listed) {
    if (!fs.existsSync(path.join(dir, addon, f.replace(/\\/g, "/")))) bad(`${addon}.toc lists ${f}, not in the zip`);
  }
  for (const f of files.filter((x) => x.startsWith(addon + "/") && !x.includes("/", addon.length + 1))) {
    const name = f.slice(addon.length + 1);
    if (name.endsWith(".lua") && !listed.includes(name)) bad(`${f} is shipped but not loaded by the .toc`);
    if (!/\.(lua|toc|xml)$/.test(name) && !ALLOWED_EXTRA.test(name)) bad(`unexpected file ${f}`);
  }
}
const vs = [...new Set(Object.values(versions))];
if (vs.length > 1) bad("the .toc versions differ: " + JSON.stringify(versions));
if (wantVersion && vs[0] !== wantVersion) bad(`.toc version ${vs[0]} does not match the tag's ${wantVersion}`);

for (const f of files.filter((x) => x.endsWith(".lua"))) {
  try { luaparse.parse(fs.readFileSync(path.join(dir, f), "utf8"), { luaVersion: "5.1" }); }
  catch (e) { bad(`${f} does not parse: ${e.message}`); }
}

if (!problems.length && unit === "kutzui") {
  const run = spawnSync(process.execPath, [path.join(__dirname, "harness.js"), path.join(dir, "KutzUI")], { encoding: "utf8", maxBuffer: 64 << 20 });
  const out = (run.stdout || "") + (run.stderr || "");
  if (run.status !== 0 || !/RESULT: no errors/.test(out)) bad("fake-game run on the extracted zip failed:\n" + out.split("\n").slice(-15).join("\n"));
}
if (!problems.length && unit === "inventory") {
  const err = loadInventoryAlone(path.join(dir, "KutzInventory"));
  if (err) bad("KutzInventory does not load on its own: " + err);
}

if (problems.length) {
  console.error(`FAIL ${path.basename(zip)} (${problems.length} problem(s))`);
  for (const p of problems) console.error("  " + p);
  process.exit(1);
}
console.log(`OK   ${path.basename(zip)}: ${want.join(", ")} ${vs[0]}, ${files.length} files, loads from an empty AddOns folder`);

// A small fake game: any unknown global is a harmless stub. KutzUI is NOT present. Fires the
// addon's own load and login events and checks it created KutzInventoryDB without an error.
function loadInventoryAlone(addonDir) {
  const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
  const toc = fs.readFileSync(path.join(addonDir, "KutzInventory.toc"), "utf8").split(/\r?\n/).map((l) => l.trim()).filter((l) => l.endsWith(".lua"));
  const sources = toc.map((f) => `{ ${JSON.stringify(f)}, [=====[${fs.readFileSync(path.join(addonDir, f), "utf8")}]=====] }`).join(",\n");
  const code = `
local stub
stub = setmetatable({}, { __index = function() return stub end, __call = function() return nil end })
local frames = {}
function CreateFrame()
  local f = { scripts = {} }
  setmetatable(f, { __index = function(_, k) return function() end end })
  f.SetScript = function(self, name, fn) self.scripts[name] = fn end
  f.RegisterEvent = function() return true end
  frames[#frames + 1] = f
  return f
end
C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
GetTime = function() return 1000 end
UnitName = function(u) if u == "player" then return "Tester" end end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 10 end
UnitClass = function() return "Warrior", "WARRIOR", 1 end
UnitRace = function() return "Human", "Human", 1 end
UnitFactionGroup = function() return "Alliance", "Alliance" end
UnitGUID = function() return "Player-1-00000001" end
GetMoney = function() return 0 end
time = function() return 1700000000 end
SlashCmdList = {}
local SAVED = { KutzInventoryDB = true, KutzUIDB = true }   -- saved variables: nil on a first run, as in the game
local env = setmetatable({}, { __index = function(_, k) local v = rawget(_G, k); if v == nil and not SAVED[k] then return stub end; return v end,
                               __newindex = function(_, k, v) rawset(_G, k, v) end })
local ns = {}
for _, file in ipairs({ ${sources} }) do
  local chunk, err = load(file[2], "@" .. file[1], "t", env)
  if not chunk then error(file[1] .. ": " .. err) end
  chunk("KutzInventory", ns)
end
for _, f in ipairs(frames) do
  local on = f.scripts.OnEvent
  if on then on(f, "ADDON_LOADED", "KutzInventory"); on(f, "PLAYER_LOGIN") end
end
if type(rawget(_G, "KutzInventoryDB")) ~= "table" then error("KutzInventoryDB was not created") end
if rawget(_G, "KutzUIDB") ~= nil then error("it created KutzUIDB") end
local e = KutzInventoryDB.lastError
if e then local t = {} if type(e) == "table" then for k, v in pairs(e) do t[#t+1] = tostring(k) .. "=" .. tostring(v) end else t[1] = tostring(e) end error("addon error: " .. table.concat(t, " ")) end
`;
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  if (lauxlib.luaL_dostring(L, to_luastring(code)) !== 0) return to_jsstring(lua.lua_tostring(L, -1));
  return null;
}
