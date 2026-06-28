#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"

APP_NAME="CodeReviewTool"
VERSION="2.0.0"
VOLUME_NAME="代码对比工具"

APP="$DIST/$APP_NAME.app"
DMG="$DIST/CodeReviewTool-$VERSION.dmg"

# Clean previous build artifacts
rm -rf "$APP" "$DMG"
mkdir -p "$DIST"

TMP="$DIST/.build"
rm -rf "$TMP"
mkdir -p "$TMP"

echo "▶ Compiling Swift (arm64 + x86_64 → universal binary)..."
swiftc -O -target arm64-apple-macos11 \
    -framework Cocoa -framework WebKit \
    -o "$TMP/$APP_NAME-arm64" \
    "$BUILD/main.swift"

swiftc -O -target x86_64-apple-macos11 \
    -framework Cocoa -framework WebKit \
    -o "$TMP/$APP_NAME-x86_64" \
    "$BUILD/main.swift"

lipo -create \
    "$TMP/$APP_NAME-arm64" \
    "$TMP/$APP_NAME-x86_64" \
    -output "$TMP/$APP_NAME"

echo "▶ Generating app icon..."
swiftc -O "$BUILD/make_icon.swift" -framework Cocoa -o "$TMP/make_icon"
"$TMP/make_icon" "$TMP/icon_1024.png"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16   "$TMP/icon_1024.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32   "$TMP/icon_1024.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32   "$TMP/icon_1024.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64   "$TMP/icon_1024.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$TMP/icon_1024.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$TMP/icon_1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$TMP/icon_1024.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$TMP/icon_1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$TMP/icon_1024.png" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$TMP/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil --convert icns --output "$TMP/AppIcon.icns" "$ICONSET"

echo "▶ Assembling .app bundle..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$TMP/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"
cp "$BUILD/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/index.html" "$APP/Contents/Resources/index.html"
cp "$TMP/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "▶ Ad-hoc code signing..."
codesign --force --deep --sign - --options runtime "$APP" 2>/dev/null \
    || codesign --force --deep --sign - "$APP"

echo "▶ Packing .dmg..."
STAGE="$TMP/dmg-staging"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/使用说明.txt" <<'EOF'
代码 / 提示词对比工具
====================

1. 安装
   将「CodeReviewTool.app」拖入「Applications」文件夹即可。

2. 首次启动
   因为应用未经苹果商店签名，macOS 会提示
   「无法打开，因为无法验证开发者」。请按以下任一方式打开：

   方式一（推荐 · 一次性）
     在「访达 → 应用程序」中，右键 CodeReviewTool.app → 「打开」
     → 弹窗中再点「打开」。之后直接双击就能运行。

   方式二（终端 · 一劳永逸）
     打开「终端」执行：
     xattr -dr com.apple.quarantine /Applications/CodeReviewTool.app

3. 隐私
   所有对比内容仅保存于本应用的本地存储中，
   不会上传任何服务器，也不会被其他应用读取。
EOF

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null

# Clean up intermediates, keep .app and .dmg as deliverables
rm -rf "$TMP"

echo ""
echo "✅ 构建完成"
echo "   App: $APP"
echo "   DMG: $DMG ($(du -h "$DMG" | cut -f1))"
