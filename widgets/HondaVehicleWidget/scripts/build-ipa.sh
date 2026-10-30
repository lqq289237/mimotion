#!/bin/bash
# 本地打包（macOS）→ 未签名 ipa，给 TrollStore / AltStore / Sideloadly 用
set -euo pipefail

cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null 2>&1 || { echo "先装 xcodegen: brew install xcodegen"; exit 1; }

xcodegen generate

xcodebuild \
  -project HondaVehicleWidget.xcodeproj \
  -scheme HondaWidgetApp \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM=""

APP=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name "*.app" | head -1)
[ -d "$APP" ] || { echo "构建失败：找不到 .app"; exit 1; }

rm -rf out && mkdir -p out/Payload
cp -R "$APP" out/Payload/
( cd out && zip -qry HondaWidgetApp.ipa Payload )

echo "✓ $(pwd)/out/HondaWidgetApp.ipa"
echo "  装法: TrollStore 直接装 / AltStore 拖进去 / 越狱机 ldid -S 后丢 /Applications"
