# Lucide subset

`manifest.json` pins the upstream [Lucide](https://github.com/lucide-icons/lucide) commit, icon names,
renderer and atlas layout. SVGs in `icons/` are unmodified files from that commit. The full upstream
licence, including Feather's MIT notice, ships in `KutzUI/Media/Icons/Lucide-LICENSE.txt`.

Only the generated atlas and shared Lua helper are needed in game. To regenerate them:

```powershell
npm install --prefix "$env:TEMP/kutzui-icon-renderer" --no-save --package-lock=false @resvg/resvg-js@2.6.2
node tools/make_lucide_icons.js "$env:TEMP/kutzui-icon-renderer"
```

The build-only renderer is not added to the addon's dependencies or `tools/package.json`.
The atlas is a 32-bit, straight-alpha TGA with power-of-two dimensions and white strokes, so each
caller can tint its icon. Cells are 64 pixels for clean rendering at small UI sizes.
