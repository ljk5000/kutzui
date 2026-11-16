const fs = require("fs"); const luaparse = require("luaparse");
const dir = process.argv[2]; let bad = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith(".lua"))) {
  try { luaparse.parse(fs.readFileSync(dir + "/" + f, "utf8"), { luaVersion: "5.1" }); console.log("OK   " + f); }
  catch (e) { bad++; console.log("FAIL " + f + ": " + e.message); }
}
process.exit(bad ? 1 : 0);
