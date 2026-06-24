#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INTERNAL_NAME="MacHealthGuardian"
PRODUCT_NAME="动动枪赛博体温计"
APP_DIR="$ROOT_DIR/build/$PRODUCT_NAME.app"
INFO_PLIST="$ROOT_DIR/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"
ICON_FILE="$ROOT_DIR/build/AppIcon.icns"
ICON_SOURCE="$ROOT_DIR/icon.png"

cd "$ROOT_DIR"

CAN_UNIVERSAL=0
if [ -x "/Library/Developer/SharedFrameworks/XCBuild.framework/Versions/A/Support/xcbuild" ]; then
  CAN_UNIVERSAL=1
fi

BUILD_MODE="${BUILD_UNIVERSAL:-auto}"
if [ "$BUILD_MODE" = "1" ] || { [ "$BUILD_MODE" = "auto" ] && [ "$CAN_UNIVERSAL" = "1" ]; }; then
  echo "Building universal release..."
  if ! swift build -c release --arch arm64 --arch x86_64; then
    if [ "$BUILD_MODE" = "1" ]; then
      exit 1
    fi
    echo "Universal build unavailable; falling back to current architecture."
    swift build -c release
  fi
else
  echo "Building release..."
  swift build -c release
fi

EXECUTABLE="$ROOT_DIR/.build/release/$INTERNAL_NAME"
if [ -x "$ROOT_DIR/.build/apple/Products/Release/$INTERNAL_NAME" ]; then
  EXECUTABLE="$ROOT_DIR/.build/apple/Products/Release/$INTERNAL_NAME"
fi

if [ ! -x "$EXECUTABLE" ]; then
  echo "Missing executable: $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR" "$ICONSET_DIR" "$ICON_FILE"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift "$ROOT_DIR/Scripts/generate-icon.swift" "$ICON_SOURCE" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

cp "$INFO_PLIST" "$APP_DIR/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$INTERNAL_NAME"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"
chmod +x "$APP_DIR/Contents/MacOS/$INTERNAL_NAME"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1
fi

echo "Built $PRODUCT_NAME $VERSION"
if command -v lipo >/dev/null 2>&1; then
  lipo -archs "$APP_DIR/Contents/MacOS/$INTERNAL_NAME" 2>/dev/null | sed 's/^/Architectures: /' || true
fi
echo "$APP_DIR"
