#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$PROJECT_ROOT/rust"
OUTPUT_LIB="$SCRIPT_DIR/libflutter_pcd_view.a"
DEVICE_LIB="$SCRIPT_DIR/libflutter_pcd_view_device.a"
SIM_LIB="$SCRIPT_DIR/libflutter_pcd_view_sim.a"

# 优先使用包内预编译的 Rust 静态库，调用方无需安装 Rust。
# 仅当预编译产物缺失（即在仓库内开发）时才回退到 cargo 构建。
use_prebuilt() {
  if [ -z "$PLATFORM_NAME" ]; then
    # prepare_command 等无平台上下文场景：默认输出模拟器库
    if [ -f "$SIM_LIB" ]; then
      cp "$SIM_LIB" "$OUTPUT_LIB"
      echo "[flutter_pcd_view] Using prebuilt simulator library: $SIM_LIB"
      return 0
    fi
    return 1
  fi

  if [ "$PLATFORM_NAME" = "iphoneos" ]; then
    if [ -f "$DEVICE_LIB" ]; then
      cp "$DEVICE_LIB" "$OUTPUT_LIB"
      echo "[flutter_pcd_view] Using prebuilt device library: $DEVICE_LIB"
      return 0
    fi
  else
    if [ -f "$SIM_LIB" ]; then
      cp "$SIM_LIB" "$OUTPUT_LIB"
      echo "[flutter_pcd_view] Using prebuilt simulator library: $SIM_LIB"
      return 0
    fi
  fi
  return 1
}

if use_prebuilt; then
  lipo -info "$OUTPUT_LIB" || true
  exit 0
fi

echo "[flutter_pcd_view] Prebuilt library not found, falling back to cargo build (requires Rust toolchain)"

ensure_target() {
  TARGET="$1"
  if ! rustup target list --installed | grep -q "^${TARGET}$"; then
    echo "[flutter_pcd_view] Installing missing Rust target: $TARGET"
    rustup target add "$TARGET"
  fi
}

build_target() {
  TARGET="$1"
  ensure_target "$TARGET"
  echo "[flutter_pcd_view] Building Rust static library for $TARGET"
  cargo build --manifest-path "$RUST_DIR/Cargo.toml" --target "$TARGET" --release
  TARGET_LIB="$RUST_DIR/target/$TARGET/release/libflutter_pcd_view.a"
  if [ ! -f "$TARGET_LIB" ]; then
    echo "[flutter_pcd_view] Expected Rust library not found: $TARGET_LIB"
    exit 1
  fi
}

build_default_library() {
  build_target aarch64-apple-ios-sim
  build_target x86_64-apple-ios
  lipo -create \
    "$RUST_DIR/target/aarch64-apple-ios-sim/release/libflutter_pcd_view.a" \
    "$RUST_DIR/target/x86_64-apple-ios/release/libflutter_pcd_view.a" \
    -output "$OUTPUT_LIB"
}

if [ -z "$PLATFORM_NAME" ] || [ -z "$ARCHS" ]; then
  echo "[flutter_pcd_view] PLATFORM_NAME/ARCHS is not set, generating default simulator library"
  build_default_library
  echo "[flutter_pcd_view] Output Rust library: $OUTPUT_LIB"
  lipo -info "$OUTPUT_LIB" || true
  exit 0
fi

TARGETS=""
for ARCH in $ARCHS; do
  case "$PLATFORM_NAME:$ARCH" in
    iphoneos:arm64)
      TARGETS="$TARGETS aarch64-apple-ios"
      ;;
    iphonesimulator:arm64)
      TARGETS="$TARGETS aarch64-apple-ios-sim"
      ;;
    iphonesimulator:x86_64)
      TARGETS="$TARGETS x86_64-apple-ios"
      ;;
    *)
      echo "[flutter_pcd_view] Unsupported iOS Rust target for PLATFORM_NAME=$PLATFORM_NAME ARCH=$ARCH"
      exit 1
      ;;
  esac
done

TARGETS=$(printf '%s\n' $TARGETS | awk '!seen[$0]++')

for TARGET in $TARGETS; do
  build_target "$TARGET"
done

if [ "$PLATFORM_NAME" = "iphoneos" ]; then
  cp "$RUST_DIR/target/aarch64-apple-ios/release/libflutter_pcd_view.a" "$OUTPUT_LIB"
else
  lipo -create \
    "$RUST_DIR/target/aarch64-apple-ios-sim/release/libflutter_pcd_view.a" \
    "$RUST_DIR/target/x86_64-apple-ios/release/libflutter_pcd_view.a" \
    -output "$OUTPUT_LIB"
fi

echo "[flutter_pcd_view] Output Rust library: $OUTPUT_LIB"
lipo -info "$OUTPUT_LIB" || true
