# ============================================================
#  FruLink iOS 越獄移植版 — Theos 構建腳本
#  用法（macOS/Linux + Theos）：
#     make            # 構建 FruLink.app（輸出在 .theos/obj/）
#     make package    # 打包 .deb
#     make install    # 安裝到已連接的越獄設備
#  免簽 IPA 請使用 build-ipa.sh
# ============================================================
export TARGET = iphone:clang:5.0:5.0
ARCHS = armv7 arm64
INSTALL_TARGET_PROCESSES = FruLink

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = FruLink

FruLink_FILES = src/main.m \
                src/AppDelegate.m \
                src/RootViewController.m \
                src/FruLinkUpdateManager.m \
                src/Live2DURLProtocol.m

FruLink_FRAMEWORKS = UIKit Foundation WebKit CFNetwork
FruLink_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 FruLink || true"
