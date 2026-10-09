#!/bin/bash
# ============================================================
#  FruLink 免簽 IPA 組裝腳本（配合已編譯好的二進制）
#
#  用法：
#    ./finalize-ipa.sh                      # 用 build/FruLink.app/FruLink
#    ./finalize-ipa.sh /path/to/FruLink     # 指定二進制路徑
#
#  功能：放入二進制 → ldid 假簽名 → 打包為
#        FruLink_1.5.12_jailbreak.ipa
# ============================================================
set -euo pipefail

BIN="${1:-build/FruLink.app/FruLink}"
if [ ! -f "$BIN" ]; then
    echo "!! 找不到二進制：$BIN"
    echo "   先用 build-ipa.sh 編譯，或把編譯好的 FruLink 二進制路徑作爲參數傳入"
    exit 1
fi

OUT="FruLink_1.5.12_jailbreak.ipa"
rm -rf .final Payload "$OUT"
mkdir -p .final/FruLink.app

cp Resources/Info.plist .final/FruLink.app/
printf 'APPL????' > .final/FruLink.app/PkgInfo
cp Resources/*.png .final/FruLink.app/ 2>/dev/null || true
cp "$BIN" .final/FruLink.app/FruLink
chmod 755 .final/FruLink.app/FruLink

if command -v ldid >/dev/null 2>&1; then
    ldid -S .final/FruLink.app/FruLink
    echo ">> 已假簽名（ldid -S）"
else
    echo "!! 未找到 ldid（brew install ldid），二進制未假簽名"
fi

mkdir Payload
cp -R .final/FruLink.app Payload/
zip -qry "$OUT" Payload
rm -rf Payload .final
echo ">> 完成：$(pwd)/$OUT"
