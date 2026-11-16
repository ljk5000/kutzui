#!/usr/bin/env node
// Creates the vX.Y.Z git tag for the version in KutzUI/KutzUI.toc. Pushing the tag runs
// .github/workflows/release-addons.yml, which builds, checks and publishes the zip.
//
//   node tools/tag_release.js           # say what tag HEAD's toc version would be
//   node tools/tag_release.js --apply   # create that lightweight tag on HEAD
//
// It does not push. After --apply:  git push origin vX.Y.Z
// Tags are not made by CI. A docs-only commit is not a release; tag the commit that
// shipped the ## Version line, the same way v0.12.1 onward were tagged.
"use strict";
const { execFileSync } = require("child_process");
const path = require("path");

const root = path.join(__dirname, "..");
const apply = process.argv.includes("--apply");
const tocPath = "KutzUI/KutzUI.toc";
const prefix = "v";

function git(args) {
    return execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}

let toc;
try {
    toc = git(["show", "HEAD:" + tocPath]);
} catch (e) {
    console.error("Could not read " + tocPath + " at HEAD.");
    process.exit(1);
}
const m = toc.match(/^## Version:\s*(\S+)/m);
if (!m) {
    console.error(tocPath + " at HEAD has no ## Version line.");
    process.exit(1);
}
const version = m[1];
const tag = prefix + version;
if (!/^\d+\.\d+\.\d+$/.test(version)) {
    console.error("Version " + JSON.stringify(version) + " is not MAJOR.MINOR.PATCH. No tag created.");
    process.exit(1);
}

let existing = "";
try { existing = git(["rev-parse", tag]); } catch (e) { existing = ""; }
const head = git(["rev-parse", "HEAD"]);

if (existing) {
    if (existing === head) {
        console.log(tag + " already points at HEAD. Push it with:  git push origin " + tag);
        process.exit(0);
    }
    console.error(tag + " already exists and points at " + existing.slice(0, 12) + ", not HEAD (" + head.slice(0, 12) + ").");
    console.error("Bump ## Version in " + tocPath + " before tagging a new release.");
    process.exit(1);
}

const dirty = git(["status", "--porcelain"]);
if (dirty) {
    console.error("The work tree is not clean. Commit the version bump, then tag HEAD.");
    process.exit(1);
}

if (!apply) {
    console.log("HEAD " + head.slice(0, 12) + " would be tagged " + tag + ".");
    console.log("Create it with:  node tools/tag_release.js --apply");
    console.log("Then push it with:  git push origin " + tag);
    process.exit(0);
}

git(["tag", tag, "HEAD"]);
console.log("Tagged HEAD as " + tag + ".");
console.log("Push it with:  git push origin " + tag);
