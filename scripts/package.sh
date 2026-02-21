#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
VER="${1:-}"
SHIM_C="$ROOT/scripts/windows/git-tangle-shim.c"

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
cp "$ROOT/libexec/tangle/"*.sh "$WIN_STAGE/libexec/tangle/"
cp "$ROOT/LICENSE" "$WIN_STAGE/LICENSE"
cp "$ROOT/README.md" "$WIN_STAGE/README.md"
cp "$ROOT/bin/git-tangle.cmd" "$WIN_STAGE/git-tangle.cmd"

normalize_version() {
  local raw="${1%%-*}"
  local major=0 minor=0 patch=0
  IFS='.' read -r major minor patch _ <<<"$raw"
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"
  echo "$major $minor $patch"
}

write_windows_version_rc() {
  local rc_path="$1"
  local major minor patch
  read -r major minor patch <<<"$(normalize_version "$VER")"
  cat > "$rc_path" <<EOF
1 VERSIONINFO
FILEVERSION ${major},${minor},${patch},0
PRODUCTVERSION ${major},${minor},${patch},0
FILEFLAGSMASK 0x3fL
#ifdef _DEBUG
FILEFLAGS 0x1L
#else
FILEFLAGS 0x0L
#endif
FILEOS 0x40004L
FILETYPE 0x1L
FILESUBTYPE 0x0L
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904E4"
    BEGIN
      VALUE "CompanyName", "taygunsavas\0"
      VALUE "FileDescription", "Git Tangle Windows launcher\0"
      VALUE "FileVersion", "${major}.${minor}.${patch}.0\0"
      VALUE "InternalName", "git-tangle.exe\0"
      VALUE "LegalCopyright", "MIT\0"
      VALUE "OriginalFilename", "git-tangle.exe\0"
      VALUE "ProductName", "Git Tangle\0"
      VALUE "ProductVersion", "${major}.${minor}.${patch}\0"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation", 0x0409, 1200
  END
END
EOF
}

build_windows_exe_shim() {
  local out="$1"
  local cc=""
  local rc_compiler=""
  local rc_path="$DIST/git-tangle-version.rc"
  local rc_obj="$DIST/git-tangle-version.res"

  if [[ -f "$SHIM_C" ]] && command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1 && command -v x86_64-w64-mingw32-windres >/dev/null 2>&1; then
    cc="x86_64-w64-mingw32-gcc"
    rc_compiler="x86_64-w64-mingw32-windres"
  elif [[ -f "$SHIM_C" ]] && command -v gcc >/dev/null 2>&1 && command -v windres >/dev/null 2>&1 && [[ "${OS:-}" == "Windows_NT" ]]; then
    cc="gcc"
    rc_compiler="windres"
  else
    return 1
  fi

  write_windows_version_rc "$rc_path"
  "$rc_compiler" "$rc_path" -O coff -o "$rc_obj"
  "$cc" -Os -municode -o "$out" "$SHIM_C" "$rc_obj" -lversion
}

if ! build_windows_exe_shim "$WIN_STAGE/git-tangle.exe"; then
  if [[ "${REQUIRE_WINDOWS_SHIM_EXE:-false}" == "true" ]]; then
    echo "[tangle] ERROR: Could not build required git-tangle.exe shim." >&2
    exit 1
  fi
  echo "[tangle] WARNING: Could not build git-tangle.exe shim; packaged git-tangle.cmd only." >&2
fi

require_file() {
  local path="$1"
  [[ -f "$path" ]] || {
    echo "[tangle] ERROR: missing required packaged file: $path" >&2
    exit 1
  }
}

require_file "$WIN_STAGE/bin/git-tangle"
require_file "$WIN_STAGE/libexec/tangle/utils.sh"
if [[ "${REQUIRE_WINDOWS_SHIM_EXE:-false}" == "true" ]]; then
  require_file "$WIN_STAGE/git-tangle.exe"
fi

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
