#!/usr/bin/env bash
# Refresh the vendored SRD 5.2.1 pack from grimoire, its source of truth.
# Usage: tools/sync_srd_pack.sh [path/to/grimoire]
set -euo pipefail
src="${1:-$(dirname "$0")/../../grimoire}/content-packs/srd-5.2"
dst="$(dirname "$0")/../addons/srd/data/srd-5.2"
[ -d "$src" ] || { echo "no pack at $src" >&2; exit 1; }
rm -rf "$dst"
cp -r "$src" "$dst"
echo "synced $(find "$dst" -name '*.json' | wc -l) files from $src"
