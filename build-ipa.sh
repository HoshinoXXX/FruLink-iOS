#!/bin/bash
# ============================================================
#  FruLink iOS 越獄版（免 Apple 簽名）一鍵構建 + 打包 IPA
#
#  環境要求：macOS + Xcode（含命令行工具）+ ldid（假簽名工具）
#            ldid 安裝：brew install ldid   或使用 Theos 自帶的
#
#  用法：
#     ./build-ipa.sh                          # 默認：arm64 / iOS 12+（現代越獄設備）
#     ./build-ipa.sh iphoneos arm64 12.0      # 同上（顯式指定）
#     ./build-ipa.sh iphoneos arm64 8.0       # 舊一點的 arm64 設備
#
#  輸出：FruLink_1.5.12_jailbreak.ipa
#  安裝：越獄設備裝好 AppSync Unified 後，用 Filza / 愛思助手 /
#        sideloadly（假簽名） 等方式直接安裝，無需 Apple 開發者賬號。
#
#  說明：iOS 5 時代的 32 位老設備（iPhone 3GS/4/4S/5、iPad 1/2/3 等）
#        請用 build-legacy-armv7.sh（需要舊版 Xcode 6/7 + 舊 SDK）。
# ============================================================
set -euo pipefail

SDK_NAME="${1:-iphoneos}"
ARCH="${2:-arm64}"
MINOS="${3:-12.0}"

SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"
OUT="build/FruLink.app"
IPA="FruLink_1.5.12_jailbreak.ipa"

rm -rf build Payload FruLink_*.ipa
mkdir -p "$OUT"

echo ">> 編譯 ($SDK_NAME / $ARCH / min-ios=$MINOS)"
clang -arch "$ARCH" \
      -mios-version-min="$MINOS" \
      -isysroot "$SDK_PATH" \
      -fobjc-arc \
      -Wno-deprecated-declarations \
      -framework UIKit \
      -framework Foundation \
      -framework WebKit \
      -framework CFNetwork \
      src/*.m -o "$OUT/FruLink"

echo ">> 複製 Info.plist / 圖標 / 啟動圖"
cp Resources/Info.plist "$OUT/Info.plist"
printf 'APPL????' > "$OUT/PkgInfo"
cp Resources/*.png "$OUT/" 2>/dev/null || true

echo ">> 假簽名（ldid -S：越獄版免 Apple 證書；設備需 AppSync）"
if command -v ldid >/dev/null 2>&1; then
    ldid -S "$OUT/FruLink"
else
    echo "!! 未找到 ldid，二進制未假簽名（brew install ldid 後重跑）"
fi

echo ">> 打包 IPA"
mkdir Payload
cp -R "$OUT" Payload/
zip -qry "$IPA" Payload
rm -rf Payload

echo ">> 完成：$(pwd)/$IPA"
