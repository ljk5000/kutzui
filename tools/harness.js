// Runs the whole addon inside a Lua VM against a fake WoW API, then drives it.
// Usage: node harness.js <addon dir>
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const { moduleKeysFromCore } = require("./modules");

const dir = process.argv[2];
const toc = fs.readFileSync(path.join(dir, "KutzUI.toc"), "utf8").split(/\r?\n/).filter(l => /\.lua$/.test(l.trim())).map(l => l.trim());
let filesLua = "local FILES = {\n";
for (const f of toc) filesLua += `  { name = ${JSON.stringify(f)}, src = [=====[${fs.readFileSync(path.join(dir, f), "utf8")}]=====] },\n`;
filesLua += "}\n";
// the settings window is its own load-on-demand addon next to the main one
const optDir = path.join(dir, "..", "KutzUI_Options");
filesLua += "local OPTION_FILES = {\n";
if (fs.existsSync(path.join(optDir, "KutzUI_Options.toc"))) {
    const optToc = fs.readFileSync(path.join(optDir, "KutzUI_Options.toc"), "utf8").split(/\r?\n/).filter(l => /\.lua$/.test(l.trim())).map(l => l.trim());
    for (const f of optToc) filesLua += `  { name = ${JSON.stringify("KutzUI_Options/" + f)}, src = [=====[${fs.readFileSync(path.join(optDir, f), "utf8")}]=====] },\n`;
}
filesLua += "}\n";

filesLua += "local MONITOR_FILES = {\n";
if (!process.argv.includes("--without-monitor")) {
    const child = path.join(dir, "..", "KutzUI_Monitor");
    for (const f of fs.readFileSync(path.join(child, "KutzUI_Monitor.toc"), "utf8").split(/\r?\n/).map(s => s.trim()).filter(s => s.endsWith(".lua"))) {
        filesLua += `  { name = ${JSON.stringify("KutzUI_Monitor/" + f)}, src = [=====[${fs.readFileSync(path.join(child, f), "utf8")}]=====] },\n`;
    }
}
filesLua += "}\n";

// optional 3rd argument: modules to switch off for this run, e.g.  node harness.js ..\KutzUI chat,fonts   (or "all")
// "all" is every key in ns.MODULES (Core.lua), so a new module is covered without editing this file.
const ALL = moduleKeysFromCore(path.join(dir, "Core.lua"));
let off = (process.argv[3] || "").split(",").filter(Boolean);
if (off.includes("all")) off = ALL;
const pre = off.length ? "DISABLE_MODULES = {" + off.map(k => `${k} = false`).join(", ") + "}" + String.fromCharCode(10) : "";
const driver = (process.argv.includes("--upgrade") ? "UPGRADE_FIXTURE = " + JSON.stringify(fs.readFileSync(path.join(__dirname, "fixtures", "kutzui-0.43.0-profile.txt"), "utf8").trim()) + "\n" : "") + pre + fs.readFileSync(path.join(__dirname, "harness_driver.lua"), "utf8");
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const status = lauxlib.luaL_dostring(L, to_luastring(filesLua + driver));
if (status !== 0) { console.log("HARNESS ERROR:", to_jsstring(lua.lua_tostring(L, -1))); process.exit(1); }
