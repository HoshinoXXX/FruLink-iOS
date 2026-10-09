#!/bin/bash
# ============================================================
#  FruLink iOS 越獄版 — 老設備（32 位）構建腳本
#
#  適用：iPhone 3GS/4/4S/5/5c、iPad 1/2/3/4/mini1、iPod touch 3/4/5
#        （iOS 5.0 – 10.3.3 的 armv7/armv7s 設備）
#
#  環境要求：macOS + 舊版 Xcode 6.x/7.x（最後支持 32 位 armv7 的時代，
#            自帶 iOS 8 SDK 或 iOS 6/7 SDK）+ ldid
#
#  用法：./build-legacy-armv7.sh [SDK名]
#  輸出：FruLink_1.5.12_jailbreak_legacy32.ipa
# ============================================================
set -euo pipefail

SDK_NAME="${1:-iphoneos}"
SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"
OUT="build/FruLink.app"
IPA="FruLink_1.5.12_jailbreak_legacy32.ipa"

rm -rf build Payload FruLink_*_legacy32.ipa
mkdir -p "$OUT"

# 若舊 SDK 不支持 armv7s（iOS 6 以前），可去掉 -arch armv7s
ARCH_FLAGS="-arch armv7 -arch armv7s"

echo ">> 編譯 ($SDK_NAME / armv7+armv7s / min-ios=5.0)"
clang $ARCH_FLAGS \
      -mios-version-min=5.0 \
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

echo ">> 假簽名"
ldid -S "$OUT/FruLink"

echo ">> 打包 IPA"
mkdir Payload
cp -R "$OUT" Payload/
zip -qry "$IPA" Payload
rm -rf Payload

echo ">> 完成：$(pwd)/$IPA"
