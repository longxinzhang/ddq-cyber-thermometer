#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="动动枪的电脑体温计"
INFO_PLIST="$ROOT_DIR/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$ROOT_DIR/build/dmg-root"
DMG_PATH="$DIST_DIR/$PRODUCT_NAME-$VERSION.dmg"

mkdir -p "$DIST_DIR"

APP_PATH="$("$ROOT_DIR/Scripts/build-app.sh" | tail -n 1)"
if [ ! -d "$APP_PATH" ]; then
  echo "Build did not produce an app bundle: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGE_DIR" "$DMG_PATH" "$DMG_PATH.sha256"
mkdir -p "$STAGE_DIR"

cp -R "$APP_PATH" "$STAGE_DIR/$PRODUCT_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

cat > "$STAGE_DIR/安装说明.txt" <<EOF
动动枪的电脑体温计

安装：
1. 把“$PRODUCT_NAME.app”拖到 Applications 文件夹。
2. 打开后它会出现在 macOS 顶栏，不会显示 Dock 图标。
3. 顶栏左侧双柱表示内存和 CPU，右侧数字是核心温度。
4. 鼠标移到顶栏小组件上可查看完整数值，点击可刷新或退出。

如果 macOS 提示无法验证开发者：
这是未使用 Apple Developer ID 公证的个人分发包。可在“系统设置 > 隐私与安全性”里允许打开，或右键 App 选择“打开”。
EOF

hdiutil create \
  -volname "$PRODUCT_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "$DMG_PATH"
echo "$DMG_PATH.sha256"
