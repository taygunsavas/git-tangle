#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"
LIBEXEC_DIR="$PREFIX/libexec/tangle"

echo "[tangle] Installing to $PREFIX ..."
mkdir -p "$BIN_DIR" "$LIBEXEC_DIR"
install -m 0755 "bin/git-tangle" "$BIN_DIR/git-tangle"
install -m 0755 libexec/tangle/*.sh "$LIBEXEC_DIR/"

echo "[tangle] Done. Ensure $BIN_DIR is in your PATH."