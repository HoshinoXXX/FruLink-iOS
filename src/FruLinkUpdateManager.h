//
//  FruLinkUpdateManager.h
//  FruLink (iOS 越獄移植版)
//  對應 Android 原版 MainActivity 的 checkUpdate / showUpdateDialog /
//  downloadAndInstall / installApk 邏輯（version.json 接口不變）
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FruLinkUpdateManager : NSObject <UIAlertViewDelegate, NSURLConnectionDataDelegate>

+ (instancetype)sharedManager;

// manual=YES：網頁 FruLinkApp.checkUpdate() 觸發（帶 toast 提示）
// manual=NO ：啟動 1.5 秒後自動檢查
- (void)checkUpdateManual:(BOOL)manual presentingIn:(UIViewController *)presenter;

@end
