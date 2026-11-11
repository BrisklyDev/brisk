#!/bin/sh
# Copies the kasma crate (engine + FFI) into this plugin.
# Usage: kasma_engine/scripts/sync_from_kasma.sh [path/to/kasma]  (default: ~/Personal/kasma)
set -e
SRC="${1:-$HOME/Personal/kasma}"
DEST="$(cd "$(dirname "$0")/.." && pwd)/rust"
rm -rf "$DEST/src"
cp -r "$SRC/src" "$DEST/src"
cp "$SRC/Cargo.toml" "$SRC/Cargo.lock" "$DEST/"
echo "Synced kasma from $SRC into $DEST"
