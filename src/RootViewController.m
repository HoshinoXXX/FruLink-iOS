//
//  RootViewController.m
//  FruLink (iOS 越獄移植版)
//  對應 Android 原版 MainActivity（com.tendouaris.frulink）
//
#import "RootViewController.h"
#import "FruLinkUpdateManager.h"

// ===== 原版常量（來自反編譯 classes.dex）=====
#define FRU_HOME_URL    @"https://kei.tendouaris.com/upload/frulink/index.html?v=4"
#define FRU_BG_LOADING  0xFF6893D9U   // 原版 onPageStarted / WebView 初始背景色
#define FRU_BG_FINISHED 0xFFF7FAFFU   // 原版 onPageFinished 背景色

// 原版 onReceivedError 的離線提示頁（dex 字符串 #17，完全一致）
static NSString * const FRUOfflineHTML =
@"<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'></head>"
@"<body style='margin:0;display:flex;align-items:center;justify-content:center;height:100vh;background:#EAF3FF;font-family:sans-serif;color:#4A5468;text-align:center'>"
@"<div><div style='font-size:44px;font-weight:700;color:#5599FF'>FruLink</div>"
@"<p style='margin-top:14px;font-size:15px'>网络好像断开了……<br>检查一下网络，再重新打开吧。</p></div></body></html>";

// 原版 showKb() 對應：聚焦頁面第一個可輸入控件
static NSString * const FRUFocusInputJS =
@"(function(){var els=document.querySelectorAll('input,textarea,select,[contenteditable=true]');"
@"for(var i=0;i<els.length;i++){var e=els[i];"
@"if(e.type&&String(e.type).toLowerCase()==='hidden')continue;"
@"if(e.offsetWidth>0){e.focus();return true;}}return false;})();";

static UIColor *FRUColor(uint32_t rgb)
{
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

@implementation RootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = FRUColor(FRU_BG_LOADING);

    // ===== 全屏 / 屏幕拉伸適配（iPhone & iPad 通用）=====
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    self.edgesForExtendedLayout = UIRectEdgeAll;          // iOS 7+：內容延伸到狀態欄
    self.extendedLayoutIncludesOpaqueBars = YES;
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = YES;                 // iOS 5–6：全屏佈局
    }
#pragma clang diagnostic pop

    [self setupWebView];

    // 對應原版 onCreate 尾部：啟動 1.5 秒後自動檢查更新（manual=NO）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[FruLinkUpdateManager sharedManager] checkUpdateManual:NO presentingIn:self];
    });
}

- (void)dealloc
{
    self.webView.delegate = nil;
    [self.webView stopLoading];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    self.wkWebView.navigationDelegate = nil;
    [self.wkWebView stopLoading];
#endif
}

#pragma mark - WebView 搭建

- (void)setupWebView
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if (NSClassFromString(@"WKWebView")) {
        // ---- iOS 8+：WKWebView（在文檔開始時注入 JS 橋，與 Android
        //      addJavascriptInterface 的時機一致，兼容性最好）----
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        WKUserContentController *ucc = [[WKUserContentController alloc] init];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:[self bridgeScript]
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                    forMainFrameOnly:NO];
        [ucc addUserScript:script];
        config.userContentController = ucc;

        WKWebView *wk = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
        wk.navigationDelegate = self;
        // 關鍵：隨屏幕旋轉 / iPad 分屏自動拉伸鋪滿
        wk.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        wk.backgroundColor = FRUColor(FRU_BG_LOADING);
        self.wkWebView = wk;
        self.usingWKWebView = YES;
        [self.view addSubview:wk];
        [wk loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:FRU_HOME_URL]]];
        return;
    }
#endif
    // ---- iOS 5–7：UIWebView（iOS 2 起可用，天然滿足 iOS 5 兼容）----
    UIWebView *wv = [[UIWebView alloc] initWithFrame:self.view.bounds];
    wv.delegate = self;
    wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    wv.backgroundColor = FRUColor(FRU_BG_LOADING);
    // 對應原版 setUseWideViewPort + setLoadWithOverviewMode（按屏幕寬度縮放 = 拉伸效果）
    wv.scalesPageToFit = YES;
    wv.dataDetectorTypes = UIDataDetectorTypeNone;
    self.webView = wv;
    self.usingWKWebView = NO;
    [self.view addSubview:wv];
    [wv loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:FRU_HOME_URL]]];
}

#pragma mark - JS 橋（對應原版 window.FruLinkApp）

- (NSString *)bridgeScript
{
    NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (ver.length == 0) ver = @"1.5.12";
    NSString *q = [ver stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    q = [q stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    q = [q stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    // 與原版 JsBridge 四個 @JavascriptInterface 方法一一對應：
    //   checkUpdate() / exitApp() / getVersionName() / kb()
    return [NSString stringWithFormat:
            @"(function(){"
             "if(window.FruLinkApp)return;"
             "var __v='%@';"
             "window.FruLinkApp={"
             "checkUpdate:function(){window.location.href='frulink://checkUpdate';},"
             "exitApp:function(){window.location.href='frulink://exitApp';},"
             "getVersionName:function(){return __v;},"
             "kb:function(){window.location.href='frulink://kb';}"
             "};"
             "})();", q];
}

// 攔截 frulink:// 協議，返回 YES 表示已處理（對應 Android JsBridge 調用轉發）
- (BOOL)handleBridgeURL:(NSURL *)url
{
    if (![[url scheme] isEqualToString:@"frulink"]) return NO;
    NSString *cmd = [url host];
    if ([cmd isEqualToString:@"checkUpdate"]) {
        [[FruLinkUpdateManager sharedManager] checkUpdateManual:YES presentingIn:self];
    } else if ([cmd isEqualToString:@"exitApp"]) {
        // 越獄版：直接退出（對應原版 backExit → finishAndRemoveTask）
        exit(0);
    } else if ([cmd isEqualToString:@"kb"]) {
        [self focusFirstInput];
    }
    return YES;
}

- (void)focusFirstInput
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if (self.usingWKWebView) {
        [self.wkWebView evaluateJavaScript:FRUFocusInputJS completionHandler:nil];
        return;
    }
#endif
    [self.webView stringByEvaluatingJavaScriptFromString:FRUFocusInputJS];
}

#pragma mark - 背景色（對應原版 setSurfaceBgs）

- (void)setSurfaceBackground:(uint32_t)rgb
{
    UIColor *c = FRUColor(rgb);
    self.view.backgroundColor = c;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if (self.usingWKWebView) {
        self.wkWebView.backgroundColor = c;
        return;
    }
#endif
    self.webView.backgroundColor = c;
}

#pragma mark - UIWebViewDelegate（iOS 5–7 路徑）

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
    if ([self handleBridgeURL:request.URL]) return NO;
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self setSurfaceBackground:FRU_BG_LOADING];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self setSurfaceBackground:FRU_BG_FINISHED];
    [webView stringByEvaluatingJavaScriptFromString:[self bridgeScript]];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (error.code == NSURLErrorCancelled) return;
    NSString *failing = [error.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey];
    if (failing && [failing hasPrefix:@"http"] &&
        [failing rangeOfString:@"frulink/index.html"].location != NSNotFound) {
        // 對應原版 onReceivedError：主頁加載失敗時顯示離線提示頁
        [webView loadHTMLString:FRUOfflineHTML baseURL:nil];
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#pragma mark - WKNavigationDelegate（iOS 8+ 路徑）

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([self handleBridgeURL:navigationAction.request.URL]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [self setSurfaceBackground:FRU_BG_LOADING];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self setSurfaceBackground:FRU_BG_FINISHED];
    [webView evaluateJavaScript:[self bridgeScript] completionHandler:nil];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
       withError:(NSError *)error
{
    if (error.code == NSURLErrorCancelled) return;
    NSString *failing = [error.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey];
    if (failing && [failing hasPrefix:@"http"] &&
        [failing rangeOfString:@"frulink/index.html"].location != NSNotFound) {
        [webView loadHTMLString:FRUOfflineHTML baseURL:nil];
    }
}
#endif

#pragma mark - 旋轉與拉伸（對應原版 configChanges=orientation|screenSize|keyboardHidden）

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;   // iOS 5
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
- (BOOL)shouldAutorotate
{
    return YES;   // iOS 6+
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;   // iPhone/iPad 全方向
}
#endif

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    // 旋轉 / 分屏時重新鋪滿（配合 autoresizingMask 實現無縫拉伸）
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if (self.usingWKWebView) {
        self.wkWebView.frame = self.view.bounds;
    } else
#endif
    if (self.webView) {
        self.webView.frame = self.view.bounds;
    }
}

@end
