#!/usr/bin/env bash
# Builds the addon downloads with the BigWigs packager and checks each one.
#
#   PACKAGER=/path/to/release.sh tools/build_addon_zips.sh <out dir> [git tag]
#
# No tag: builds the download as "<toc version>-dev.<commit>" (CI on every push).
# Tag vX.Y.Z: the KutzUI download (KutzUI + KutzUI_Options + KutzUI_Monitor).
# The tag's version must equal the .toc's ## Version, or nothing is built.
# Run from the repository root (a normal clone: the packager needs a .git folder, not a worktree).
set -euo pipefail

out=${1:?usage: build_addon_zips.sh <out dir> [tag]}
tag=${2:-}
: "${PACKAGER:?set PACKAGER to release.sh of the BigWigs packager}"
mkdir -p "$out"
out=$(cd "$out" && pwd)

case "$tag" in
  v*)           units="kutzui";    want="${tag#v}" ;;
  "")           units="kutzui"; want="" ;;
  *) echo "Not an addon release tag: $tag" >&2; exit 1 ;;
esac

for unit in $units; do
  case $unit in
    kutzui)    meta=.pkgmeta;           toc=KutzUI/KutzUI.toc;               addons="KutzUI KutzUI_Options KutzUI_Monitor" ;;
  esac
  version=$(sed -n 's/^## Version: *//p' "$toc" | tr -d '\r')
  if [ -n "$want" ] && [ "$version" != "$want" ]; then
    echo "Tag $tag says $want but $toc says $version. Fix the .toc or the tag." >&2
    exit 1
  fi
  label=$version
  [ -z "$want" ] && label="$version-dev.$(git rev-parse --short=7 HEAD)"

  rel=$(mktemp -d)
  # -d no upload, -l no localization, -e no externals. -n names the zip from the .toc version,
  # because the packager would otherwise use the newest tag of any prefix.
  bash "$PACKAGER" -d -l -e -m "$meta" -r "$rel" -n "{package-name}-$label:$label"
  zipfile=$(ls "$rel"/*.zip)

  # MIT: the licence travels inside every addon folder.
  for a in $addons; do cp LICENSE "$rel/$a/LICENSE.txt"; done
  (cd "$rel" && zip -q "$zipfile" $(for a in $addons; do echo "$a/LICENSE.txt"; done))

  node tools/check_release_zip.js "$zipfile" "$unit" "$version" --licensed
  cp "$zipfile" "$out/"
done
# "<hash>  <file>" lines, the format `sha256sum -c` reads (Git Bash would otherwise write "*" before names)
(cd "$out" && for z in *.zip; do printf '%s  %s\n' "$(sha256sum < "$z" | cut -d' ' -f1)" "$z"; done > SHA256SUMS.txt && cat SHA256SUMS.txt)
