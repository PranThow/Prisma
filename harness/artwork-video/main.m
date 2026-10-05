// Compile the implementation so this small harness can exercise download limits and leases too.
#import "Shared/AnimatedArtwork/ArtworkVideo.m"
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#include <assert.h>

static NSData *clip;
static NSUInteger requests;
static NSURL *testRoot;
static NSURLSessionConfiguration *lastConfiguration;
@interface NSFileManager (Harness)
- (NSArray<NSURL *> *)clipURLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domains;
@end
@implementation NSFileManager (Harness)
- (NSArray<NSURL *> *)clipURLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domains {
    return directory == NSCachesDirectory ? @[testRoot] : [self clipURLsForDirectory:directory inDomains:domains];
}
@end
@interface ClipProtocol : NSURLProtocol
@end
@implementation ClipProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqual:@"artwork.invalid"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    requests++;
    NSString *path = self.request.URL.path;
    if ([path containsString:@"network-error"]) {
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil]];
        return;
    }
    NSData *body = [path containsString:@"bad-media"] ? [@"not a video" dataUsingEncoding:NSUTF8StringEncoding] : clip;
    NSInteger status = [path containsString:@"404"] ? 404 : 200;
    NSString *length = [path containsString:@"large"] ? @"999999999" : @(body.length).stringValue;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:status
        HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Length":length}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:body];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@interface NSURLSessionConfiguration (Harness)
+ (instancetype)clipConfiguration;
@end
@implementation NSURLSessionConfiguration (Harness)
+ (instancetype)clipConfiguration {
    NSURLSessionConfiguration *config = [self clipConfiguration]; // Original after swizzle.
    config.protocolClasses = @[ClipProtocol.class];
    lastConfiguration = config;
    return config;
}
@end

static void makeClip(NSURL *url) {
    NSError *error = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:&error];
    assert(writer && !error);
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
        outputSettings:@{AVVideoCodecKey:AVVideoCodecTypeH264, AVVideoWidthKey:@160, AVVideoHeightKey:@96}];
    input.transform = CGAffineTransformMake(0,1,-1,0,96,0);
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
        assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:@{
            (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32ARGB),
            (id)kCVPixelBufferWidthKey:@160, (id)kCVPixelBufferHeightKey:@96}];
    [writer addInput:input]; assert([writer startWriting]); [writer startSessionAtSourceTime:kCMTimeZero];
    for (int frame = 0; frame < 10; frame++) {
        while (!input.readyForMoreMediaData) [NSThread sleepForTimeInterval:0.001];
        CVPixelBufferRef buffer = NULL;
        assert(CVPixelBufferPoolCreatePixelBuffer(NULL,adaptor.pixelBufferPool,&buffer) == kCVReturnSuccess);
        CVPixelBufferLockBaseAddress(buffer,0);
        memset(CVPixelBufferGetBaseAddress(buffer),127,CVPixelBufferGetBytesPerRow(buffer)*96);
        CVPixelBufferUnlockBaseAddress(buffer,0);
        assert([adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame,10)]);
        CVPixelBufferRelease(buffer);
    }
    [input markAsFinished];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{dispatch_semaphore_signal(done);}];
    dispatch_semaphore_wait(done,DISPATCH_TIME_FOREVER);
    assert(writer.status == AVAssetWriterStatusCompleted);
}
int main(void) { @autoreleasepool {
    CGSize size; CGAffineTransform t; BOOL crop;
    CGAffineTransform rotation = CGAffineTransformMake(0,1,-1,0,96,0);
    assert(SGArtworkVideoGeometry(CGSizeMake(160,96),rotation,0.6,&size,&t,&crop) && !crop);
    assert(size.width == 96 && size.height == 160);
    for (int angle = 0; angle < 4; angle++) {
        assert(SGArtworkVideoGeometry(CGSizeMake(160,96),CGAffineTransformMakeRotation(angle*M_PI_2),1,&size,&t,&crop));
        assert(crop && size.width == 96 && size.height == 96);
        CGRect box = CGRectApplyAffineTransform(CGRectMake(0,0,160,96),t);
        assert(fabs(CGRectGetMidX(box)-48) < 0.001 && fabs(CGRectGetMidY(box)-48) < 0.001);
    }
    assert(!SGArtworkVideoGeometry(CGSizeZero,rotation,1,NULL,NULL,NULL));
    assert(!SGArtworkVideoGeometry(CGSizeMake(160,96),rotation,NAN,NULL,NULL,NULL));
    assert(!SGArtworkVideoURLValid([NSURL URLWithString:@"file:///tmp/clip.mp4"]));
    assert(!SGArtworkVideoURLValid([NSURL URLWithString:@"https://user:pass@artwork.invalid/a"]));
    assert(!SGArtworkVideoURLValid([NSURL URLWithString:@"https://artwork.invalid:444/a"]));
    assert(!SGArtworkVideoFilenameValid(@"../clip.mp4"));
    assert(SGArtworkVideoFilenameValid(cacheName(@"clip")));
    method_exchangeImplementations(class_getClassMethod(NSURLSessionConfiguration.class,@selector(ephemeralSessionConfiguration)),
        class_getClassMethod(NSURLSessionConfiguration.class,@selector(clipConfiguration)));
    testRoot = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    method_exchangeImplementations(class_getInstanceMethod(NSFileManager.class,@selector(URLsForDirectory:inDomains:)),
        class_getInstanceMethod(NSFileManager.class,@selector(clipURLsForDirectory:inDomains:)));
    NSURL *fixture = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSUUID.UUID.UUIDString stringByAppendingString:@".mp4"]]];
    makeClip(fixture); clip = [NSData dataWithContentsOfURL:fixture];
    NSString *identity = NSUUID.UUID.UUIDString;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://artwork.invalid/%@",identity]];
    NSError *error = nil;
    SGPreparedArtworkVideo *original = prepare(url,0.6,[SGVideoWork new],&error);
    assert(original && !error && original.previewJPEG.length && requests == 1);
    assert([[NSData dataWithContentsOfURL:original.fileURL] isEqual:clip]); // No encoding for rotated matching shape.
    SGPreparedArtworkVideo *square = prepare(url,1,[SGVideoWork new],&error);
    assert(square && !error && requests == 1 && ![square.fileURL isEqual:original.fileURL]);
    AVAssetTrack *track = [[AVURLAsset URLAssetWithURL:square.fileURL options:nil] tracksWithMediaType:AVMediaTypeVideo].firstObject;
    assert(track.naturalSize.width == 96 && track.naturalSize.height == 96);
    assert(CGAffineTransformIsIdentity(track.preferredTransform));
    NSData *encoded = [NSData dataWithContentsOfURL:square.fileURL];
    @autoreleasepool {
        SGPreparedArtworkVideo *again = prepare(url,1,[SGVideoWork new],&error);
        assert(again && requests == 1 && [[NSData dataWithContentsOfURL:again.fileURL] isEqual:encoded]);
        assert([leases()[square.fileURL.lastPathComponent] unsignedIntegerValue] == 2);
    }
    assert([leases()[square.fileURL.lastPathComponent] unsignedIntegerValue] == 1);
    assert(!makeRoom(SGVideoCacheLimit,[NSSet set]));
    assert(fileSize(original.fileURL) && fileSize(square.fileURL));
    // Evict an unleased cache entry while preserving both leased files.
    NSURL *unleased = [cacheDirectory() URLByAppendingPathComponent:cacheName(@"unleased")];
    assert([[@"fixture" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:unleased atomically:YES]);
    NSUInteger leasedBytes = (NSUInteger)(fileSize(original.fileURL) + fileSize(square.fileURL));
    assert(makeRoom(SGVideoCacheLimit-leasedBytes,[NSSet set]));
    assert(!fileSize(unleased) && fileSize(original.fileURL) && fileSize(square.fileURL));
    for (NSString *failure in @[@"404",@"large",@"bad-media",@"network-error"]) {
        NSURL *bad = [NSURL URLWithString:[NSString stringWithFormat:@"https://artwork.invalid/%@/%@",identity,failure]];
        error = nil;
        assert(!prepare(bad,1,[SGVideoWork new],&error) && error);
        assert(!fileSize([cacheDirectory() URLByAppendingPathComponent:cacheName(bad.absoluteString)]));
    }
    // Replacement invalidates even a completion already queued for the main thread.
    SGArtworkVideoPreparer *preparer = [SGArtworkVideoPreparer new];
    __block BOOL stale = NO, completed = NO;
    [preparer prepareURL:url aspectRatio:1 completion:^(SGPreparedArtworkVideo *v,NSError *e) { stale = YES; }];
    dispatch_sync(preparationQueue(), ^{});
    [preparer prepareURL:url aspectRatio:0.6 completion:^(SGPreparedArtworkVideo *v,NSError *e) { assert(v && !e); completed = YES; }];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!completed && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    assert(completed && !stale);
    [preparer prepareURL:url aspectRatio:1 completion:^(SGPreparedArtworkVideo *v,NSError *e) { stale = YES; }];
    [preparer cancel]; dispatch_sync(preparationQueue(), ^{});
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    assert(!stale);
    assert(!lastConfiguration.allowsConstrainedNetworkAccess && !lastConfiguration.waitsForConnectivity);
    SGVideoWork *cancelled = [SGVideoWork new]; [cancelled cancel];
    error = nil; assert(!prepare(url,1,cancelled,&error));
    NSURL *sourceFile = original.fileURL, *squareFile = square.fileURL;
    original = nil; square = nil;
    [NSFileManager.defaultManager removeItemAtURL:sourceFile error:nil];
    [NSFileManager.defaultManager removeItemAtURL:squareFile error:nil];
    [NSFileManager.defaultManager removeItemAtURL:fixture error:nil];
    [NSFileManager.defaultManager removeItemAtURL:testRoot error:nil];
    puts("artwork video: rotation, crop, reuse, HTTP/media failures, leases and cancellation passed");
} return 0; }
