//
//  FruLinkUpdateManager.m
//  FruLink (iOS 越獄移植版)
//  所有提示文案與原版 Android dex 字符串完全一致
//
#import "FruLinkUpdateManager.h"

#define FRU_VERSION_URL @"https://kei.tendouaris.com/upload/frulink/version.json"

typedef NS_ENUM(NSInteger, FRUAlertTag) {
    FRUAlertUpdate = 1,
    FRUAlertDownloaded = 2,
};

@interface FruLinkUpdateManager ()
@property (nonatomic, assign) BOOL checking;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) NSString *pendingApkUrl;
@property (nonatomic, strong) NSMutableData *downloadData;
@property (nonatomic, assign) long long downloadTotal;
@property (nonatomic, assign) double lastProgressTime;
@property (nonatomic, strong) NSURLConnection *downloadConnection;
@property (nonatomic, strong) UIAlertView *progressAlertView;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
@property (nonatomic, strong) UIAlertController *progressController;
#endif
@end

@implementation FruLinkUpdateManager

+ (instancetype)sharedManager
{
    static FruLinkUpdateManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[FruLinkUpdateManager alloc] init]; });
    return shared;
}

// 對應原版 appVc()：本地 versionCode（Android 版爲 18，見 Info.plist CFBundleVersion）
- (NSInteger)currentVersionCode
{
    NSInteger vc = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
    return vc ?: 18;
}

// 對應原版 appVn()
- (NSString *)currentVersionName
{
    NSString *vn = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return (vn.length > 0) ? vn : @"?";
}

#pragma mark - Toast（對應原版 Toast）

- (void)showToast:(NSString *)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if (NSClassFromString(@"UIAlertController")) {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                                       message:text
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [self.presenter presentViewController:ac animated:YES completion:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [ac dismissViewControllerAnimated:YES completion:nil];
            });
            return;
        }
#endif
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:nil message:text
                                                    delegate:nil cancelButtonTitle:nil
                                           otherButtonTitles:nil];
        [av show];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [av dismissWithClickedButtonIndex:0 animated:YES];
        });
    });
}

#pragma mark - 檢查更新（對應原版 checkUpdate(manual) + MainActivity$5 線程）

- (void)checkUpdateManual:(BOOL)manual presentingIn:(UIViewController *)presenter
{
    self.presenter = presenter;
    if (self.checking) {
        if (manual) [self showToast:@"正在检查中，请稍等…"];
        return;
    }
    self.checking = YES;
    if (manual) [self showToast:@"正在检查更新…"];

    // 原版拼接 version.json?t=<毫秒時間戳>，8 秒超時
    NSString *urlString = [NSString stringWithFormat:@"%@?t=%lld", FRU_VERSION_URL,
                           (long long)([[NSDate date] timeIntervalSince1970] * 1000.0)];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:8.0];

    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        self.checking = NO;
        if (error || data.length == 0) {
            if (manual) [self showToast:@"检查更新失败，请稍后再试"];
            return;
        }
        NSError *jsonError = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![obj isKindOfClass:[NSDictionary class]]) {
            if (manual) [self showToast:@"检查更新失败，请稍后再试"];
            return;
        }
        NSDictionary *json = (NSDictionary *)obj;
        // 原版字段：versionCode(int) / versionName("?") / apk("") / notes("")
        id vcObj = [json objectForKey:@"versionCode"];
        NSInteger vc = 0;
        if ([vcObj isKindOfClass:[NSNumber class]])      vc = [(NSNumber *)vcObj integerValue];
        else if ([vcObj isKindOfClass:[NSString class]]) vc = [(NSString *)vcObj integerValue];
        id vnObj = [json objectForKey:@"versionName"];
        NSString *vn = [vnObj isKindOfClass:[NSString class]] ? vnObj : @"?";
        id apkObj = [json objectForKey:@"apk"];
        NSString *apk = [apkObj isKindOfClass:[NSString class]] ? apkObj : @"";
        id notesObj = [json objectForKey:@"notes"];
        NSString *notes = [notesObj isKindOfClass:[NSString class]] ? notesObj : @"";

        if (vc > [self currentVersionCode] && apk.length > 0) {
            [self showUpdateDialogWithMyVersion:[self currentVersionName]
                                     newVersion:vn
                                          notes:notes
                                        apkUrl:apk];
        } else if (manual) {
            [self showToast:[NSString stringWithFormat:@"已是最新版本 v%@", [self currentVersionName]]];
        }
    }];
}

#pragma mark - 更新對話框（對應原版 showUpdateDialog，文案一致）

- (void)showUpdateDialogWithMyVersion:(NSString *)myVn newVersion:(NSString *)vn
                                notes:(NSString *)notes apkUrl:(NSString *)apkUrl
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *effectiveNotes = (notes.length > 0) ? notes : @"常规更新";
        NSString *message = [NSString stringWithFormat:@"当前版本：v%@  →  新版本：v%@\n\n更新内容：\n%@",
                             myVn, vn, effectiveNotes];
        NSString *title = [NSString stringWithFormat:@"FruLink 有新版本 v%@ 啦", vn];
        self.pendingApkUrl = apkUrl;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if (NSClassFromString(@"UIAlertController")) {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"立即更新" style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                [self downloadAndInstall:self.pendingApkUrl];
            }]];
            [ac addAction:[UIAlertAction actionWithTitle:@"以后再说" style:UIAlertActionStyleCancel
                                                 handler:nil]];
            [self.presenter presentViewController:ac animated:YES completion:nil];
            return;
        }
#endif
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:message
                                                    delegate:self
                                           cancelButtonTitle:@"以后再说"
                                           otherButtonTitles:@"立即更新", nil];
        av.tag = FRUAlertUpdate;
        [av show];
    });
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == FRUAlertUpdate && buttonIndex == 1) {
        [self downloadAndInstall:self.pendingApkUrl];
    }
}

#pragma mark - 下載（對應原版 downloadAndInstall + MainActivity$7 線程）

- (void)downloadAndInstall:(NSString *)apkUrl
{
    if (apkUrl.length == 0) return;
    self.pendingApkUrl = apkUrl;
    [self showProgress];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apkUrl]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:30.0];   // 原版 read 超時 30 秒
    self.downloadData = [NSMutableData data];
    self.downloadTotal = 0;
    self.lastProgressTime = 0;

    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
    [conn scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [conn start];
    self.downloadConnection = conn;
}

- (void)showProgress
{
    dispatch_async(dispatch_get_main_queue(), ^{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if (NSClassFromString(@"UIAlertController")) {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                                       message:@"正在下载新版本…"
                                                                preferredStyle:UIAlertControllerStyleAlert];
            self.progressController = ac;
            [self.presenter presentViewController:ac animated:YES completion:nil];
            return;
        }
#endif
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:nil message:@"正在下载新版本…"
                                                    delegate:nil cancelButtonTitle:nil
                                           otherButtonTitles:nil];
        self.progressAlertView = av;
        [av show];
    });
}

- (void)updateProgress:(NSString *)text
{
    if (self.progressAlertView) self.progressAlertView.message = text;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if (self.progressController) self.progressController.message = text;
#endif
}

- (void)dismissProgress
{
    if (self.progressAlertView) {
        [self.progressAlertView dismissWithClickedButtonIndex:0 animated:YES];
        self.progressAlertView = nil;
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if (self.progressController) {
        [self.progressController dismissViewControllerAnimated:YES completion:nil];
        self.progressController = nil;
    }
#endif
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.downloadTotal = [response expectedContentLength];
    if (self.downloadTotal < 0) self.downloadTotal = 0;
    [self.downloadData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.downloadData appendData:data];
    double now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastProgressTime >= 0.25) {   // 原版每 250ms 更新一次進度
        self.lastProgressTime = now;
        NSInteger pct = 0;
        if (self.downloadTotal > 0) {
            pct = (NSInteger)((double)self.downloadData.length * 100.0 / (double)self.downloadTotal);
        }
        [self updateProgress:[NSString stringWithFormat:@"正在下载新版本… %ld%%", (long)pct]];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self dismissProgress];
    [self finishDownload];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self dismissProgress];
    [self showToast:@"下载失败，请检查网络后重试"];
}

- (void)finishDownload
{
    NSData *data = self.downloadData;
    if (data.length <= 10000) {   // 原版 "file too small" 檢查
        [self showToast:@"下载失败，请检查网络后重试"];
        return;
    }
    // 對應原版 getCacheDir()/updates/frulink-update.apk
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *updatesDir = [cacheDir stringByAppendingPathComponent:@"updates"];
    [[NSFileManager defaultManager] createDirectoryAtPath:updatesDir
                              withIntermediateDirectories:YES
                                               attributes:nil error:NULL];

    NSString *ext = [self.pendingApkUrl pathExtension];
    if (ext.length == 0 || ext.length > 8) ext = @"bin";
    NSString *path = [updatesDir stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"frulink-update.%@", ext]];
    NSError *writeError = nil;
    [data writeToFile:path options:NSDataWritingAtomic error:&writeError];
    if (writeError) {
        [self showToast:@"下载失败，请检查网络后重试"];
        return;
    }
    [self attemptInstall:path extension:ext];
}

#pragma mark - 安裝（對應原版 installApk；iOS 越獄版處理 IPA）

- (void)attemptInstall:(NSString *)path extension:(NSString *)ext
{
    BOOL jailbroken = [[NSFileManager defaultManager] fileExistsAtPath:@"/bin/bash"];
    BOOL isIpa = ([ext caseInsensitiveCompare:@"ipa"] == NSOrderedSame);

    // 越獄設備 + IPA + 已安裝 appinst：自動安裝
    if (jailbroken && isIpa && [[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/appinst"]) {
        NSString *escaped = [path stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
        NSString *cmd = [NSString stringWithFormat:@"appinst '%@' >/dev/null 2>&1 &", escaped];
        system(cmd.UTF8String);
        [self showToast:@"已开始安装新版本…"];
        return;
    }

    NSString *message;
    if (isIpa) {
        message = [NSString stringWithFormat:@"新版本已下载：\n%@\n\n（越狱设备可用 Filza 打开安装；安装 appinst 后可自动安装）", path];
    } else {
        message = [NSString stringWithFormat:@"已下载更新包：\n%@\n\n（APK 无法在 iOS 安装，请让服务端在 version.json 的 apk 字段提供 IPA 链接）", path];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if (NSClassFromString(@"UIAlertController")) {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"下载完成"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
            [self.presenter presentViewController:ac animated:YES completion:nil];
            return;
        }
#endif
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"下载完成" message:message
                                                    delegate:nil cancelButtonTitle:@"好"
                                           otherButtonTitles:nil];
        av.tag = FRUAlertDownloaded;
        [av show];
    });
}

@end
