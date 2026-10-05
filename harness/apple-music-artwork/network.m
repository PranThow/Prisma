#import "Shared/AnimatedArtwork/AppleMusicArtwork.h"
#import <objc/runtime.h>
#include <assert.h>

static NSUInteger requests, searches, scripts;
static BOOL rejectOnce, rateLimited, malformed, failOnce;
static NSString *guestToken;
static NSURLSessionConfiguration *lastConfiguration;
static NSString *base64JSON(NSDictionary *object) {
    NSString *text = [[NSJSONSerialization dataWithJSONObject:object options:0 error:nil] base64EncodedStringWithOptions:0];
    return [[[text stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
        stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@"=" withString:@""];
}
@interface AppleArtworkProtocol : NSURLProtocol
@end
@implementation AppleArtworkProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return YES; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    requests++;
    assert(!lastConfiguration.HTTPCookieStorage && !lastConfiguration.URLCredentialStorage && !lastConfiguration.URLCache);
    assert(!lastConfiguration.allowsConstrainedNetworkAccess);
    NSURL *url = self.request.URL;
    NSString *auth = [self.request valueForHTTPHeaderField:@"Authorization"];
    assert(![self.request valueForHTTPHeaderField:@"Music-User-Token"]);
    assert(![self.request valueForHTTPHeaderField:@"Cookie"]);
    NSInteger status = 200;
    NSData *data = nil;
    if ([url.path hasSuffix:@"/new"]) {
        assert(!auth);
        data = [@"<script src=\"/assets/index~fixture.js\"></script>" dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([url.path hasSuffix:@".js"]) {
        scripts++;
        assert(!auth);
        guestToken = [NSString stringWithFormat:@"%@.%@.fixture",base64JSON(@{@"alg":@"ES256"}),
            base64JSON(@{@"iss":@"AMPWebPlay",@"exp":@(NSDate.date.timeIntervalSince1970+3600),@"fixture":@(scripts)})];
        data = [guestToken dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([url.path hasSuffix:@"/search"]) {
        searches++;
        assert([url.host isEqual:@"amp-api.music.apple.com"]);
        assert([auth isEqual:[@"Bearer " stringByAppendingString:guestToken]]);
        assert([[self.request valueForHTTPHeaderField:@"Origin"] isEqual:@"https://music.apple.com"]);
        if (failOnce) {
            failOnce = NO;
            [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil]];
            return;
        }
        if (rejectOnce) { status = 401; rejectOnce = NO; }
        else if (rateLimited) status = 429;
        NSString *term = nil;
        for (NSURLQueryItem *item in [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES].queryItems)
            if ([item.name isEqual:@"term"]) term = item.value;
        NSArray *rows = [term containsString:@"Missing"] ? @[] : @[@{
            @"attributes":@{@"artistName":@"Artist",@"name":@"Album",@"editorialVideo":@{
                @"motionDetailTall":@{@"video":@"https://mvod.itunes.apple.com/master.m3u8"}}}}];
        data = [NSJSONSerialization dataWithJSONObject:@{@"results":@{@"albums":@{@"data":rows}}} options:0 error:nil];
        if (malformed) data = [@"invalid JSON" dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([url.host isEqual:@"mvod.itunes.apple.com"]) {
        assert(!auth);
        NSString *playlist = [url.path hasSuffix:@"master.m3u8"] ?
            @"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"avc1.64001f\",RESOLUTION=600x800\nmedia.m3u8\n" :
            @"#EXTM3U\n#EXTINF:4,\nclip.mp4\n#EXT-X-ENDLIST\n";
        data = [playlist dataUsingEncoding:NSUTF8StringEncoding];
    } else assert(!"Unexpected request; harness must never reach the network");
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:status HTTPVersion:@"HTTP/1.1"
        headerFields:rateLimited ? @{@"Retry-After":@"65"} : @{}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@interface NSURLSessionConfiguration (AppleHarness)
+ (instancetype)appleArtworkConfiguration;
@end
@implementation NSURLSessionConfiguration (AppleHarness)
+ (instancetype)appleArtworkConfiguration {
    NSURLSessionConfiguration *configuration = [self appleArtworkConfiguration];
    configuration.protocolClasses = @[AppleArtworkProtocol.class];
    lastConfiguration = configuration;
    return configuration;
}
@end
static NSURL *resolve(SGAppleMusicArtworkResolver *resolver, NSString *album, NSError **failure) {
    __block BOOL done = NO;
    __block NSURL *clip = nil;
    __block NSError *error = nil;
    [resolver resolveArtist:@"Artist" album:album aspectRatio:.75 completion:^(NSURL *url, NSError *why) {
        clip = url; error = why; done = YES;
    }];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!done && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    assert(done);
    *failure = error;
    return clip;
}
void SGAppleArtworkNetworkChecks(void) {
    [NSUserDefaults.standardUserDefaults setVolatileDomain:@{SGKeyAppleMusicDeveloperToken:@""} forName:NSArgumentDomain];
    Method original = class_getClassMethod(NSURLSessionConfiguration.class,@selector(ephemeralSessionConfiguration));
    Method fake = class_getClassMethod(NSURLSessionConfiguration.class,@selector(appleArtworkConfiguration));
    method_exchangeImplementations(original,fake);
    SGAppleMusicArtworkResolver *resolver = [SGAppleMusicArtworkResolver new];
    NSError *error = nil;
    assert(resolve(resolver,@"Album",&error) && !error);
    assert(requests == 5 && searches == 1);
    assert(resolve(resolver,@"Album",&error) && requests == 5); // Successful cache hit.
    assert(!resolve(resolver,@"Missing",&error) && !error);
    NSUInteger afterMiss = requests;
    assert(!resolve(resolver,@"Missing",&error) && !error && requests == afterMiss);
    rejectOnce = YES;
    SGAppleMusicArtworkResolver *fresh = [SGAppleMusicArtworkResolver new];
    NSUInteger before = scripts;
    assert(resolve(fresh,@"Album",&error) && !error && scripts == before+2); // Guest refresh after 401.
    malformed = YES;
    SGAppleMusicArtworkResolver *broken = [SGAppleMusicArtworkResolver new];
    assert(!resolve(broken,@"Album",&error) && error);
    NSUInteger afterError = searches;
    malformed = NO;
    assert(resolve(broken,@"Album",&error) && !error && searches == afterError+1); // Failure was not a cached miss.
    failOnce = YES;
    SGAppleMusicArtworkResolver *retrying = [SGAppleMusicArtworkResolver new];
    NSUInteger beforeRetry = searches;
    assert(resolve(retrying,@"Album",&error) && !error && searches == beforeRetry+2);
    rateLimited = YES;
    SGAppleMusicArtworkResolver *limited = [SGAppleMusicArtworkResolver new];
    assert(!resolve(limited,@"Album",&error) && error.code == 429);
    NSUInteger afterLimit = requests;
    assert(!resolve(limited,@"Album",&error) && error && requests == afterLimit); // Retry-After cooldown.
    __block BOOL stale = NO;
    SGAppleMusicArtworkResolver *cancelled = [SGAppleMusicArtworkResolver new];
    [cancelled resolveArtist:@"Artist" album:@"Album" aspectRatio:.75 completion:^(NSURL *url, NSError *why) { stale = YES; }];
    [cancelled cancel];
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    assert(!stale);
    method_exchangeImplementations(original,fake);
    [NSUserDefaults.standardUserDefaults removeVolatileDomainForName:NSArgumentDomain];
    NSLog(@"Apple artwork isolated authorization, refresh, cache, rate limit and cancellation checks passed");
}
