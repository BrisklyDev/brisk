#!/bin/sh
# Builds libkasma.a for the architectures Xcode is building for and merges them with lipo.
set -e
export PATH="$HOME/.cargo/bin:$PATH"
RUST_DIR="$PODS_TARGET_SRCROOT/../rust"
OUT_DIR="$BUILT_PRODUCTS_DIR/kasma_rust"
TARGET_DIR="$OUT_DIR/target"
mkdir -p "$OUT_DIR"
LIBS=""
for ARCH in ${ARCHS:-$(uname -m)}; do
  case "$ARCH" in
    arm64) TRIPLE=aarch64-apple-darwin ;;
    x86_64) TRIPLE=x86_64-apple-darwin ;;
    *) echo "Unsupported arch $ARCH"; exit 1 ;;
  esac
  rustup target add "$TRIPLE" >/dev/null 2>&1 || true
  cargo build --release --lib --manifest-path "$RUST_DIR/Cargo.toml" --target-dir "$TARGET_DIR" --target "$TRIPLE"
  LIBS="$LIBS $TARGET_DIR/$TRIPLE/release/libkasma.a"
done
lipo -create $LIBS -output "$OUT_DIR/libkasma.a"
