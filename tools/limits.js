// Lua 5.1 (what WoW runs) refuses to LOAD a file when a function uses more than 60 variables from
// enclosing functions ("upvalues") or has more than 200 live local variables. The fake game uses a
// newer Lua that does not enforce either, so this checks them from the syntax tree.
// Usage: node limits.js <addon dir>
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const dir = process.argv[2];
const MAX_UPVALUES = 60, MAX_LOCALS = 200;
let bad = 0;

for (const file of fs.readdirSync(dir).filter(f => f.endsWith(".lua"))) {
    const ast = luaparse.parse(fs.readFileSync(path.join(dir, file), "utf8"), { luaVersion: "5.1", locations: true });
    const funcs = [];                    // every function: { line, upvalues:Set, maxLocals }
    const scopes = [];                   // stack of { vars: Map(name -> declId), fn }
    let declCounter = 0;

    const newFn = (line) => { const f = { line, upvalues: new Set(), live: 0, maxLocals: 0 }; funcs.push(f); return f; };
    const curFn = () => scopes[scopes.length - 1].fn;
    const push = (fn) => scopes.push({ vars: new Map(), fn });
    const pop = () => { const s = scopes.pop(); s.fn.live -= s.vars.size; };
    const declare = (name) => {
        const s = scopes[scopes.length - 1];
        if (!s.vars.has(name)) { s.fn.live++; s.fn.maxLocals = Math.max(s.fn.maxLocals, s.fn.live); }
        s.vars.set(name, ++declCounter);
    };
    const use = (name) => {
        for (let i = scopes.length - 1; i >= 0; i--) {
            if (scopes[i].vars.has(name)) {
                const id = scopes[i].vars.get(name);
                const owner = scopes[i].fn;
                // every function between the declaration and here carries it as an upvalue
                const seen = new Set();
                for (let j = scopes.length - 1; j > i; j--) {
                    const f = scopes[j].fn;
                    if (f !== owner && !seen.has(f)) { seen.add(f); f.upvalues.add(id); }
                }
                return;
            }
        }                                // not found: a global
    };

    function walk(n) {
        if (!n || typeof n !== "object") return;
        if (Array.isArray(n)) { n.forEach(walk); return; }
        switch (n.type) {
            case "Identifier": use(n.name); return;
            case "MemberExpression": walk(n.base); if (n.indexer === "[") walk(n.identifier); return;
            case "LocalStatement": walk(n.init); n.variables.forEach(v => declare(v.name)); return;
            case "FunctionDeclaration": {
                if (n.identifier) {
                    if (n.isLocal) declare(n.identifier.name); else walk(n.identifier);
                }
                const f = newFn(n.loc.start.line);
                push(f);
                n.parameters.forEach(p => { if (p.type === "Identifier") declare(p.name); });
                if (n.is_vararg) { /* ... costs nothing here */ }
                walk(n.body);
                pop();
                return;
            }
            case "ForNumericStatement":
                walk(n.start); walk(n.end); walk(n.step);
                push(curFn()); declare(n.variable.name); walk(n.body); pop(); return;
            case "ForGenericStatement":
                walk(n.iterators);
                push(curFn()); n.variables.forEach(v => declare(v.name)); walk(n.body); pop(); return;
            case "DoStatement": case "WhileStatement": case "RepeatStatement":
                if (n.condition && n.type === "WhileStatement") walk(n.condition);
                push(curFn()); walk(n.body); if (n.type === "RepeatStatement") walk(n.condition); pop(); return;
            case "IfClause": case "ElseifClause":
                walk(n.condition); push(curFn()); walk(n.body); pop(); return;
            case "ElseClause":
                push(curFn()); walk(n.body); pop(); return;
        }
        for (const k of Object.keys(n)) {
            if (k === "loc" || k === "range" || k === "type") continue;
            walk(n[k]);
        }
    }

    const main = newFn(0);
    push(main);
    walk(ast.body);
    pop();

    for (const f of funcs) {
        if (f.upvalues.size > MAX_UPVALUES || f.maxLocals > MAX_LOCALS) {
            bad++;
            console.log(`FAIL ${file}: function at line ${f.line} has ${f.upvalues.size} upvalues (max ${MAX_UPVALUES}) and ${f.maxLocals} live locals (max ${MAX_LOCALS})`);
        }
    }
    const worstUp = Math.max(...funcs.map(f => f.upvalues.size));
    const worstLoc = Math.max(...funcs.map(f => f.maxLocals));
    console.log(`OK   ${file.padEnd(18)} most upvalues in one function: ${String(worstUp).padStart(2)}   most live locals: ${String(worstLoc).padStart(3)}`);
}
console.log(bad ? `\n${bad} function(s) over the Lua 5.1 limits` : "\nNo function is over the Lua 5.1 limits.");
process.exit(bad ? 1 : 0);
