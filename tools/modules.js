// The module keys live in KutzUI/Core.lua (ns.MODULES). The offline checks read them from there
// so a new module is switched off in a test run without anyone editing this list.
"use strict";
const fs = require("fs");

function moduleKeysFromCore(corePath) {
    const src = fs.readFileSync(corePath, "utf8");
    const start = src.indexOf("ns.MODULES");
    if (start < 0) throw new Error("ns.MODULES not found in " + corePath);
    const brace = src.indexOf("{", start);
    if (brace < 0) throw new Error("ns.MODULES has no table in " + corePath);
    let depth = 0, end = -1;
    for (let i = brace; i < src.length; i++) {
        const c = src[i];
        if (c === "{") depth++;
        else if (c === "}") {
            depth--;
            if (depth === 0) { end = i; break; }
        }
    }
    if (end < 0) throw new Error("ns.MODULES table did not end in " + corePath);
    const body = src.slice(brace, end + 1);
    const keys = [];
    const re = /key\s*=\s*"([^"]+)"/g;
    let m;
    while ((m = re.exec(body))) keys.push(m[1]);
    if (!keys.length) throw new Error("ns.MODULES has no keys in " + corePath);
    return keys;
}

module.exports = { moduleKeysFromCore };
