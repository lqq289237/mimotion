#!/bin/sh
# 一键给 HondaWidgetApp 补 App Group entitlement 并重签
#
#   sh resign.sh                      自动找 /var/mobile 下最新的 ipa
#   sh resign.sh /path/to/xxx.ipa     指定 ipa
#
# 产出: /var/mobile/HondaWidgetApp-signed.ipa  → 用 TrollStore 装

set -e

IPA="$1"
if [ -z "$IPA" ]; then
  IPA=$(ls -t /var/mobile/*.ipa 2>/dev/null | head -1)
fi
if [ -z "$IPA" ] || [ ! -f "$IPA" ]; then
  echo "❌ 没找到 ipa。把它放到 /var/mobile/ 再跑，或传入路径：sh resign.sh /path/to.ipa"
  exit 1
fi

OUT="/var/mobile/HondaWidgetApp-signed.ipa"
WORK="/var/mobile/hw-sign"
LDID=$(command -v ldid || true)
[ -z "$LDID" ] && [ -x /var/jb/usr/bin/ldid ] && LDID=/var/jb/usr/bin/ldid
[ -z "$LDID" ] && { echo "❌ 缺 ldid，Sileo 里装 ldid"; exit 1; }

echo "ipa  : $IPA"
echo "ldid : $LDID"

rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

echo "[1/4] 解压"
unzip -q "$IPA" || { echo "❌ 解压失败（试试 Sileo 装 unzip）"; exit 1; }

APP="$WORK/Payload/HondaWidgetApp.app"
EXT="$APP/PlugIns/VehicleWidgetExtension.appex/VehicleWidgetExtension"
[ -d "$APP" ] || { echo "❌ ipa 结构异常"; exit 1; }

echo "[2/4] 写 entitlements"
cat > ent.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.yg.hondawidget</string>
	</array>
	<key>com.apple.security.exception.files.absolute-path.read-write</key>
	<array>
		<string>/var/mobile/</string>
	</array>
	<key>platform-application</key>
	<true/>
	<key>com.apple.private.security.no-container</key>
	<true/>
	<key>get-task-allow</key>
	<true/>
</dict>
</plist>
PLIST

echo "[3/4] 签名"
"$LDID" -Sent.plist "$APP/HondaWidgetApp"
[ -f "$EXT" ] && "$LDID" -Sent.plist "$EXT"

echo "[4/4] 打包"
rm -f "$OUT"
if command -v zip >/dev/null 2>&1; then
  zip -qry "$OUT" Payload
else
  echo "⚠️ 缺 zip 命令。用 Filza 手动把 $WORK/Payload 压缩成 zip，重命名 .ipa"
  exit 1
fi

ls -lh "$OUT"
echo ""
echo "✅ 完成：$OUT"
echo "   用 TrollStore 打开它安装，装完删掉桌面旧小组件再重新添加"
