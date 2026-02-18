#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
VER="${1:-}"

[[ -z "$VER" ]] && { echo "usage: package.sh <version>"; exit 1; }

rm -rf "$DIST" && mkdir -p "$DIST"
TARBALL="git-tangle_${VER}.tar.gz"
WINZIP="git-tangle_${VER}_windows_x64.zip"
WIN_STAGE="$DIST/windows-package"

tar -czf "$DIST/$TARBALL"   --exclude-vcs --exclude='.github' --exclude='dist'   -C "$ROOT" .

( cd "$DIST" && shasum -a 256 "$TARBALL" > "$TARBALL.sha256" )

rm -rf "$WIN_STAGE"
mkdir -p "$WIN_STAGE/bin" "$WIN_STAGE/libexec/tangle"
cp "$ROOT/bin/git-tangle" "$WIN_STAGE/bin/git-tangle"
cp "$ROOT/bin/git-tangle.cmd" "$WIN_STAGE/git-tangle.cmd"
cp "$ROOT/libexec/tangle/"*.sh "$WIN_STAGE/libexec/tangle/"
cp "$ROOT/LICENSE" "$WIN_STAGE/LICENSE"
cp "$ROOT/README.md" "$WIN_STAGE/README.md"

if command -v zip >/dev/null 2>&1; then
  ( cd "$WIN_STAGE" && zip -qr "$DIST/$WINZIP" . )
elif command -v powershell.exe >/dev/null 2>&1; then
  if command -v cygpath >/dev/null 2>&1; then
    WIN_STAGE_WIN="$(cygpath -w "$WIN_STAGE")"
    WINZIP_WIN="$(cygpath -w "$DIST/$WINZIP")"
  else
    WIN_STAGE_WIN="$WIN_STAGE"
    WINZIP_WIN="$DIST/$WINZIP"
  fi
  powershell.exe -NoProfile -Command "\$ErrorActionPreference='Stop'; if (Test-Path -LiteralPath '$WINZIP_WIN') { Remove-Item -LiteralPath '$WINZIP_WIN' -Force }; Compress-Archive -Path '$WIN_STAGE_WIN\\*' -DestinationPath '$WINZIP_WIN' -CompressionLevel Optimal"
else
  echo "[tangle] ERROR: zip not found and powershell.exe is unavailable; cannot build Windows ZIP." >&2
  exit 1
fi

( cd "$DIST" && shasum -a 256 "$WINZIP" > "$WINZIP.sha256" )

echo "Built $DIST/$TARBALL and $DIST/$WINZIP"
