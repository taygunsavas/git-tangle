#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
VER="${1:-}"

[[ -z "$VER" ]] && { echo "usage: package.sh <version>"; exit 1; }

rm -rf "$DIST" && mkdir -p "$DIST"
TARBALL="git-tangle_${VER}.tar.gz"

tar -czf "$DIST/$TARBALL"   --exclude-vcs --exclude='.github' --exclude='dist'   -C "$ROOT" .

( cd "$DIST" && shasum -a 256 "$TARBALL" > "$TARBALL.sha256" )
echo "Built $DIST/$TARBALL"