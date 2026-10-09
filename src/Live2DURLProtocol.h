//
//  Live2DURLProtocol.h
//  FruLink (iOS 越獄移植版)
//  對應 Android 原版 WebViewClient.shouldInterceptRequest：
//  把 /upload/frulink/live2d/ 路徑的資源改由 app bundle 內的 live2d/ 目錄提供
//  （目錄爲空時自動回退爲網絡加載，行爲與原版 assets 爲空時一致）
//
#import <Foundation/Foundation.h>

@interface Live2DURLProtocol : NSURLProtocol

@end
