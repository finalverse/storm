#!/bin/bash
set -e

# Paths
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUST_TARGET_DIR="$PROJECT_ROOT/.build-rust"
LIBS_DIR="$PROJECT_ROOT/libs"
mkdir -p "$LIBS_DIR"

# Targets
MACOS_TARGET="aarch64-apple-darwin"
IOS_TARGET="aarch64-apple-ios"
IOS_SIM_X86="x86_64-apple-ios"
IOS_SIM_ARM="aarch64-apple-ios-sim"

#
# Move into RustCore where Cargo.toml lives
cd "$PROJECT_ROOT/RustCore"

# Build all targets
echo "🔨 Building for macOS..."
cargo build --release --target "$MACOS_TARGET"

echo "🔨 Building for iOS..."
cargo build --release --target "$IOS_TARGET"

echo "🔨 Building for iOS Simulator (x86_64)..."
cargo build --release --target "$IOS_SIM_X86"

echo "🔨 Building for iOS Simulator (arm64)..."
cargo build --release --target "$IOS_SIM_ARM"

# Copy macOS lib
cp "$RUST_TARGET_DIR/$MACOS_TARGET/release/libstorm.a" "$LIBS_DIR/libstorm-macos.a"
echo "✅ Copied macOS libstorm.a → libs/libstorm-macos.a"

# Copy iOS lib
cp "$RUST_TARGET_DIR/$IOS_TARGET/release/libstorm.a" "$LIBS_DIR/libstorm-ios.a"
echo "✅ Copied iOS libstorm.a → libs/libstorm-ios.a"

# Combine simulator libs
lipo -create \
    "$RUST_TARGET_DIR/$IOS_SIM_X86/release/libstorm.a" \
    "$RUST_TARGET_DIR/$IOS_SIM_ARM/release/libstorm.a" \
    -output "$LIBS_DIR/libstorm-ios-sim.a"
echo "✅ Combined simulator libstorm.a → libs/libstorm-ios-sim.a"

echo "🎉 All Rust static libraries are built and copied successfully!"