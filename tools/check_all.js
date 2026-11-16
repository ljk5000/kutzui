// Runs every offline check: syntax, typo audit, the full fake-game run, and the fake-game run
// once per module switched off (plus all switched off). Module keys come from ns.MODULES.
// Usage: node check_all.js <addon dir>      (from tools/: npm ci   — see tools/package.json)
const { spawnSync } = require("child_process");
const path = require("path");
const { moduleKeysFromCore } = require("./modules");

const dir = process.argv[2];
if (!dir) { console.log("usage: node check_all.js <addon dir>"); process.exit(2); }

const root = path.resolve(dir, "..");
const MODULES = moduleKeysFromCore(path.join(path.resolve(dir), "Core.lua")).concat(["all"]);
const optDir = path.join(root, "KutzUI_Options");

function runOn(d, script, ...args) {
    const r = spawnSync(process.execPath, [path.join(__dirname, script), d, ...args], { encoding: "utf8" });
    return (r.stdout || "") + (r.stderr || "");
}
function run(script, ...args) { return runOn(dir, script, ...args); }

let failed = 0;
function report(label, ok, detail) {
    console.log((ok ? "PASS  " : "FAIL  ") + label);
    if (!ok) {
        failed++;
        // Preserve TAP/spec assertion details, stack traces, and child-process errors.
        // Node 22 TAP failures do not share the Lua harness output prefixes.
        if (detail && detail.trim()) console.log(detail.trim().split("\n").map(l => "      " + l).join("\n"));
    }
}

for (const [label, d] of [["KutzUI", dir], ["KutzUI_Options", optDir], ["KutzUI_Monitor", path.join(root, "KutzUI_Monitor")]]) {
    const c = runOn(d, "check.js");
    report(`${label}: syntax (Lua 5.1, what WoW runs)`, /^OK/m.test(c) && !/^FAIL/m.test(c), c);
    const lim = runOn(d, "limits.js");
    report(`${label}: under the Lua 5.1 load limits (60 upvalues / 200 locals)`, /No function is over/.test(lim), lim);
    const g = runOn(d, "globals.js");
    report(`${label}: no unexpected global names`, /\(none\)/.test(g), g);
}
// Secret-value lint (optional): taintlint, a separate MIT-licensed tool. Point TAINTLINT_DIR at a
// folder holding a clone of github.com/bettogamer/taintlint with luaparse installed (see tools/README.md).
// It reads the addon's ## Interface and checks against that client's API database (WoW Forever 1.60.1 here).
// Errors and warnings fail the check; "info" findings (data-flow guesses) are only listed.
if (process.env.TAINTLINT_DIR) {
    for (const [label, d] of [["KutzUI", dir], ["KutzUI_Options", optDir], ["KutzUI_Monitor", path.join(root, "KutzUI_Monitor")]]) {
        const r = spawnSync(process.execPath, [path.join(process.env.TAINTLINT_DIR, "src", "cli.ts"), path.resolve(d), "--min-severity", "warning"], { encoding: "utf8", cwd: process.env.TAINTLINT_DIR });
        const out = (r.stdout || "") + (r.stderr || "");
        const summary = (out.match(/taintlint \(db[^\n]*/) || [""])[0];
        const clean = r.status === 0 && /0 errors, 0 warnings/.test(out);
        report(`${label}: secret values (taintlint) ${summary.replace(/^taintlint /, "")}`, clean, out.split("\n").map(l => "  * " + l).join("\n"));
    }
} else {
    console.log("SKIP  secret values (taintlint): set TAINTLINT_DIR to run it (see tools/README.md)");
}
const crafting = run("check_crafting_time.js");
report("profession batch estimates and countdown", /OK crafting/.test(crafting), crafting);
const subcraft = run("check_sub_craft.js");
report("sub-assembly planning and crafting runs", /OK subcraft/.test(subcraft), subcraft);
const windows = spawnSync(process.execPath, [path.join(__dirname, "check_windows.js")], { encoding: "utf8" });
report("chat window bounds", windows.status === 0, windows.stdout + windows.stderr);
const full = run("harness.js");
report("fake game, every module on", /RESULT: no errors, no failed checks/.test(full), full);
const upgrade = run("harness.js", "", "--upgrade");
report("fake game, legacy profiles and monitor SavedVariables upgrade", /RESULT: no errors, no failed checks/.test(upgrade), upgrade);
const noMonitor = run("harness.js", "", "--without-monitor");
report("fake game, monitor addon not installed", /RESULT: no errors, no failed checks/.test(noMonitor), noMonitor);
for (const m of MODULES) {
    const out = run("harness.js", m);
    report(`fake game, ${m === "all" ? "ALL modules" : "module '" + m + "'"} switched off`, /RESULT: no errors, no failed checks/.test(out), out);
}
console.log(failed === 0 ? "\nALL CHECKS PASSED" : `\n${failed} CHECK(S) FAILED`);
process.exit(failed === 0 ? 0 : 1);
