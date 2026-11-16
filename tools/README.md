# Offline checks for KutzUI (no game needed)

These run the addons' Lua in a small Lua interpreter with a fake game, so mistakes show up before you
`/reload` in WoW. One-time setup, in this folder (`package.json` pins the versions, `npm ci` uses the
lockfile):

    npm ci

Then:

    node check_all.js ../KutzUI     # everything below, for KutzUI, KutzUI_Options and KutzUI_Monitor
    node check.js     ../KutzUI     # syntax of every .lua file
    node globals.js   ../KutzUI     # any global name that isn't a normal Lua/WoW one (catches typos)
    node limits.js    ../KutzUI     # the Lua 5.1 limits (60 upvalues / 200 locals) that make WoW refuse a file
    node harness.js   ../KutzUI     # loads the addon into a FAKE game, fires login, opens /kutz, clicks every control
    node harness.js   ../KutzUI chat,fonts     # the same with those modules switched off (or "all")

`check_all.js` also runs the crafting countdown, sub-assembly crafting, and chat-window checks, the
profile upgrade fixture (`fixtures/kutzui-0.43.0-profile.txt`), the fake game without the Monitor
addon, and the fake game once per module switched off. Module keys come from `ns.MODULES` in
`KutzUI/Core.lua`, so a new module is covered on its own. GitHub Actions runs this on every push
and pull request (`.github/workflows/checks.yml`, Node 22).

The fake game (`harness_driver.lua`) is deliberately simple: it can't tell you a real WoW function name
is misspelled or how something LOOKS, only that the addon's own logic runs.

## Secret-value lint (optional)

`check_all.js` can also run [taintlint](https://github.com/bettogamer/taintlint) (MIT), which checks the
addons against the WoW Forever 1.60.1 API database for arithmetic, comparisons or table keys on values
the game may hide. Clone it into its own folder, give it a copy of `luaparse`, and point `TAINTLINT_DIR`
at it (Node 22+). Without `TAINTLINT_DIR` the step is skipped.

## Textures

`python -I make_textures.py ../KutzUI/Media/Textures` regenerates the cast bar textures and masks.

## Release zips

    node check_release_zip.js <zip> kutzui [version] [--licensed]   # a zip, as if extracted alone into an empty AddOns folder
    PACKAGER=<BigWigs packager release.sh> bash build_addon_zips.sh <out dir> [vX.Y.Z]

`kutzui` is this repository's download. The `inventory` argument checks a separate inventory addon
that is not in this repository.

Run `build_addon_zips.sh` from the repository root of a normal clone (not a git worktree); it needs `jq`
and `zip`. CI (`.github/workflows/release-addons.yml`) builds and checks the zip on every push to
`main` and on pull requests, and publishes it when a `vX.Y.Z` tag is pushed. On a public repository
that publish also attaches a build-provenance attestation. See the README for how to verify one.
Tags are not created by CI. Use `node tag_release.js` (it prints the tag; `--apply` creates it and
does not push).
