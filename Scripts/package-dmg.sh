#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="动动枪赛博体温计"
INFO_PLIST="$ROOT_DIR/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$ROOT_DIR/build/dmg-root"
DMG_PATH="$DIST_DIR/DDQs-Cyber-Thermometer-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/DDQs-Cyber-Thermometer-$VERSION.app.zip"

mkdir -p "$DIST_DIR"

APP_PATH="$("$ROOT_DIR/Scripts/build-app.sh" | tail -n 1)"
if [ ! -d "$APP_PATH" ]; then
  echo "Build did not produce an app bundle: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGE_DIR" "$DMG_PATH" "$DMG_PATH.sha256" "$ZIP_PATH" "$ZIP_PATH.sha256"
mkdir -p "$STAGE_DIR"

cp -R "$APP_PATH" "$STAGE_DIR/$PRODUCT_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

cat > "$STAGE_DIR/安装说明.txt" <<EOF
DDQ's Cyber Thermometer
动动枪赛博体温计

安装：
1. 把“$PRODUCT_NAME.app”拖到 Applications 文件夹。
2. 打开后它会出现在 macOS 顶栏，不会显示 Dock 图标。
3. 顶栏迷你柱显示内存压力、内存和 CPU，右侧显示核心温度、下载和上传速率。
4. 鼠标移到顶栏小组件上可查看完整数值。
5. 点击菜单可打开快捷网页、管理快捷入口、调整顶栏显示项、勾选开机启动，查看网络流量、风扇转速、检查更新、复制诊断信息、刷新或退出。
6. v0.4.0 起，App 内检查更新会优先使用 .app.zip 自动替换安装。

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

(
  cd "$(dirname "$APP_PATH")"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$(basename "$APP_PATH")" "$ZIP_PATH"
)
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "$DMG_PATH"
echo "$DMG_PATH.sha256"
echo "$ZIP_PATH"
echo "$ZIP_PATH.sha256"
