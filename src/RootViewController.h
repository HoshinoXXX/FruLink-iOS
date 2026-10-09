//
//  RootViewController.h
//  FruLink (iOS 越獄移植版)
//  對應 Android 原版 MainActivity（WebView 殼 + FruLinkApp JS 橋）
//
#import <UIKit/UIKit.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#import <WebKit/WebKit.h>
#endif

@interface RootViewController : UIViewController <UIWebViewDelegate>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
, WKNavigationDelegate
#endif

@property (nonatomic, strong) UIWebView *webView;        // iOS 5–7 路徑
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
@property (nonatomic, strong) WKWebView *wkWebView;      // iOS 8+ 路徑（編譯期可用時）
#endif
@property (nonatomic, assign) BOOL usingWKWebView;

@end
