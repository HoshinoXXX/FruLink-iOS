//
//  Live2DURLProtocol.m
//  FruLink (iOS 越獄移植版)
//
#import "Live2DURLProtocol.h"

static NSString * const kLive2DPrefix = @"/upload/frulink/live2d/";

@implementation Live2DURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSString *path = request.URL.path;
    if (![path hasPrefix:kLive2DPrefix]) return NO;
    NSString *rel = [path substringFromIndex:kLive2DPrefix.length];
    if (rel.length == 0 || [rel rangeOfString:@".."].location != NSNotFound) return NO;
    NSString *file = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:
                      [@"live2d" stringByAppendingPathComponent:rel]];
    return [[NSFileManager defaultManager] fileExistsAtPath:file];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSString *rel = [self.request.URL.path substringFromIndex:kLive2DPrefix.length];
    NSString *file = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:
                      [@"live2d" stringByAppendingPathComponent:rel]];
    NSData *data = [NSData dataWithContentsOfFile:file];
    if (!data) {
        NSError *err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotOpenFile userInfo:nil];
        [self.client URLProtocol:self didFailWithError:err];
        return;
    }

    // 與原版一致的 MIME 映射
    NSString *ext = [[rel pathExtension] lowercaseString];
    NSString *mime = @"application/octet-stream";
    if ([ext isEqualToString:@"js"])           mime = @"application/javascript";
    else if ([ext isEqualToString:@"png"])     mime = @"image/png";
    else if ([ext isEqualToString:@"webp"])    mime = @"image/webp";
    else if ([ext isEqualToString:@"ogg"])     mime = @"audio/ogg";
    else if ([ext isEqualToString:@"json"] ||
             [ext isEqualToString:@"atlas"])   mime = @"text/plain";

    NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                          statusCode:200
                                                         HTTPVersion:@"HTTP/1.1"
                                                        headerFields:@{
        @"Content-Type" : mime,
        @"Access-Control-Allow-Origin" : @"*",
        @"Content-Length" : [NSString stringWithFormat:@"%lu", (unsigned long)data.length],
    }];
    [self.client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
}

@end
