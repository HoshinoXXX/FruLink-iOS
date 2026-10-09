//
//  AppDelegate.m
//  FruLink (iOS 越獄移植版)
//
#import "AppDelegate.h"
#import "RootViewController.h"
#import "Live2DURLProtocol.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // 註冊 Live2D 資源本地覆蓋協議（對應 Android 版 WebViewClient.shouldInterceptRequest，
    // 從 app bundle 的 live2d/ 目錄提供緩存資源；目錄不存在時自動回退爲網絡加載）
    [NSURLProtocol registerClass:[Live2DURLProtocol class]];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[RootViewController alloc] init];
    [self.window makeKeyAndVisible];

    return YES;
}

@end
