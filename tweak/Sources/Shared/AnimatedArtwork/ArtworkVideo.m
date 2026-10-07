#import "ArtworkVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#import <math.h>

static const NSUInteger SGVideoDownloadLimit = 32 * 1024 * 1024;
static const NSUInteger SGVideoFileLimit = 64 * 1024 * 1024;
static const NSUInteger SGVideoCacheLimit = 128 * 1024 * 1024;

static NSError *videoError(NSString *message) {
    return [NSError errorWithDomain:@"Prisma.ArtworkVideo" code:1
                           userInfo:@{NSLocalizedDescriptionKey:message}];
}
BOOL SGArtworkVideoURLValid(NSURL *url) {
    return [url isKindOfClass:NSURL.class] && [url.scheme.lowercaseString isEqual:@"https"] &&
        url.host.length && !url.user && !url.password && !url.fragment &&
        (!url.port || url.port.integerValue == 443);
}
BOOL SGArtworkVideoFilenameValid(NSString *name) {
    if (![name isKindOfClass:NSString.class] || name.length != 68 || ![name hasSuffix:@".mp4"]) return NO;
    return [[name substringToIndex:64] rangeOfCharacterFromSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location == NSNotFound;
}
BOOL SGArtworkVideoGeometry(CGSize natural, CGAffineTransform orientation, double ratio,
                            CGSize *renderSize, CGAffineTransform *transform, BOOL *crop) {
    CGRect bounds = CGRectApplyAffineTransform((CGRect){CGPointZero,natural}, orientation);
    double w = bounds.size.width, h = bounds.size.height;
    double determinant = orientation.a * orientation.d - orientation.b * orientation.c;
    if (!isfinite(ratio) || ratio < 0.1 || ratio > 10 || !isfinite(w) || !isfinite(h) ||
        !isfinite(bounds.origin.x) || !isfinite(bounds.origin.y) || natural.width <= 0 ||
        natural.height <= 0 || !isfinite(determinant) || fabs(determinant) < 1e-8 ||
        w < 2 || h < 2 || w > 8192 || h > 8192) return NO;
    // One pixel of aspect error is unavoidable for integral encoded dimensions.
    BOOL needsCrop = fabs(w - h * ratio) > MAX(1.0, ratio);
    CGSize size = CGSizeMake(w, h);
    if (needsCrop) {
        size.width = floor(MIN(w, h * ratio) / 2) * 2;
        size.height = floor(MIN(h, w / ratio) / 2) * 2;
    }
    if (size.width < 2 || size.height < 2) return NO;
    CGAffineTransform t = CGAffineTransformConcat(orientation, CGAffineTransformMakeTranslation(
        -bounds.origin.x - (w - size.width) / 2, -bounds.origin.y - (h - size.height) / 2));
    if (renderSize) *renderSize = size;
    if (transform) *transform = t;
    if (crop) *crop = needsCrop;
    return YES;
}
static NSString *cacheName(NSString *identity) {
    NSData *data = [identity dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *name = [NSMutableString new];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [name appendFormat:@"%02x", digest[i]];
    return [name stringByAppendingString:@".mp4"];
}
static NSURL *cacheDirectory(void) {
    return [[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject
        URLByAppendingPathComponent:@"spotifyglass-artwork-video-v1" isDirectory:YES];
}
static NSMutableDictionary<NSString *, NSNumber *> *leases(void) {
    static NSMutableDictionary *counts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ counts = [NSMutableDictionary new]; });
    return counts;
}
static unsigned long long fileSize(NSURL *url) {
    return [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil].fileSize;
}
// All cache writes and eviction run on one queue. Leases may be released on any thread.
static dispatch_queue_t preparationQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("Prisma.artwork-video", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
static BOOL makeRoom(NSUInteger reserve, NSSet<NSString *> *protected) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSURL *> *files = [fm contentsOfDirectoryAtURL:cacheDirectory()
        includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:0 error:nil];
    files = [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *ad, *bd;
        [a getResourceValue:&ad forKey:NSURLContentModificationDateKey error:nil];
        [b getResourceValue:&bd forKey:NSURLContentModificationDateKey error:nil];
        return [(ad ?: NSDate.distantPast) compare:(bd ?: NSDate.distantPast)];
    }];
    unsigned long long total = 0;
    for (NSURL *file in files) total += fileSize(file);
    @synchronized (leases()) {
        for (NSURL *file in files) {
            if (total + reserve <= SGVideoCacheLimit) break;
            NSString *name = file.lastPathComponent;
            if (!SGArtworkVideoFilenameValid(name) || [protected containsObject:name] || [leases()[name] unsignedIntegerValue]) continue;
            unsigned long long bytes = fileSize(file);
            if ([fm removeItemAtURL:file error:nil]) total -= bytes;
        }
    }
    return total + reserve <= SGVideoCacheLimit;
}
@interface SGPreparedArtworkVideo ()
@property (nonatomic, readwrite) NSURL *fileURL;
@property (nonatomic, readwrite) NSData *previewJPEG;
@end
@implementation SGPreparedArtworkVideo
- (void)dealloc {
    @synchronized (leases()) {
        NSString *name = _fileURL.lastPathComponent;
        NSUInteger count = [leases()[name] unsignedIntegerValue];
        if (count > 1) leases()[name] = @(count - 1);
        else if (name) [leases() removeObjectForKey:name];
    }
}
@end

@interface SGVideoWork : NSObject <NSURLSessionDataDelegate>
@property (atomic) BOOL cancelled;
@property (atomic, strong) NSURLSessionDataTask *task;
@property (atomic, strong) AVAssetExportSession *exporter;
@property (atomic, strong) AVAssetImageGenerator *generator;
@property (nonatomic) dispatch_semaphore_t finished;
@property (nonatomic, strong) NSFileHandle *handle;
@property (nonatomic, strong) NSError *downloadError;
@property (nonatomic) NSUInteger received;
@property (nonatomic, strong) NSURL *remote;
- (void)cancel;
- (BOOL)download:(NSURL *)url to:(NSURL *)file error:(NSError **)error;
@end
@implementation SGVideoWork
- (void)cancel {
    @synchronized (self) {
        self.cancelled = YES;
        [self.task cancel]; [self.exporter cancelExport]; [self.generator cancelAllCGImageGeneration];
    }
}
- (BOOL)download:(NSURL *)url to:(NSURL *)file error:(NSError **)error {
    self.remote = url;
    self.finished = dispatch_semaphore_create(0);
    if (![NSFileManager.defaultManager createFileAtPath:file.path contents:nil attributes:nil]) {
        *error = videoError(@"Cannot create download file"); return NO;
    }
    self.handle = [NSFileHandle fileHandleForWritingToURL:file error:error];
    if (!self.handle) return NO;
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.allowsConstrainedNetworkAccess = NO;
    config.waitsForConnectivity = NO;
    config.timeoutIntervalForRequest = 20;
    config.timeoutIntervalForResource = 60;
    config.HTTPCookieStorage = nil; config.URLCredentialStorage = nil; config.URLCache = nil;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    @synchronized (self) {
        self.task = [session dataTaskWithURL:url];
        if (self.cancelled) [self.task cancel]; else [self.task resume];
    }
    dispatch_semaphore_wait(self.finished, DISPATCH_TIME_FOREVER);
    NSError *closeError = nil;
    if (![self.handle closeAndReturnError:&closeError] && !self.downloadError) self.downloadError = closeError;
    self.handle = nil;
    [session invalidateAndCancel]; self.task = nil;
    *error = self.downloadError;
    return !self.cancelled && !*error && self.received > 0;
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
    didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
    BOOL valid = http.statusCode == 200 && [http.URL isEqual:self.remote] &&
        response.expectedContentLength <= (int64_t)SGVideoDownloadLimit;
    if (!valid) self.downloadError = videoError(@"Invalid HTTP response or oversized video");
    completion(valid ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (self.cancelled || self.downloadError) return;
    if (data.length > SGVideoDownloadLimit - self.received) {
        self.downloadError = videoError(@"Video exceeds download limit"); [task cancel]; return;
    }
    NSError *error;
    if (![self.handle writeData:data error:&error]) { self.downloadError = error; [task cancel]; return; }
    self.received += data.length;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!self.downloadError) self.downloadError = error;
    if (!self.downloadError && !self.received) self.downloadError = videoError(@"Empty video response");
    dispatch_semaphore_signal(self.finished);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completion { completion(nil); }
@end

static NSData *preview(NSURL *file, SGVideoWork *work, NSError **error) {
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:[AVURLAsset URLAssetWithURL:file options:nil]];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(512, 512);
    @synchronized (work) { if (work.cancelled) return nil; work.generator = generator; }
    CGImageRef image = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:error];
    work.generator = nil;
    if (!image) return nil;
    NSMutableData *data = [NSMutableData new];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.jpeg"), 1, NULL);
    if (destination) CGImageDestinationAddImage(destination, image, NULL);
    BOOL success = destination && CGImageDestinationFinalize(destination);
    if (destination) CFRelease(destination);
    CGImageRelease(image);
    if (!success) { *error = videoError(@"Cannot encode video preview"); return nil; }
    return data;
}
static SGPreparedArtworkVideo *prepare(NSURL *url, double ratio, SGVideoWork *work, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *directory = cacheDirectory();
    if (![fm createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    NSNumber *symlink = nil;
    [directory getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:error];
    if (symlink.boolValue) { *error = videoError(@"Invalid cache directory"); return nil; }
    // A killed process can leave an unfinished file. The serial queue has no other writer.
    for (NSURL *file in [fm contentsOfDirectoryAtURL:directory includingPropertiesForKeys:nil options:0 error:nil]) {
        NSString *name = file.lastPathComponent;
        if ([name hasSuffix:@".part.mp4"] && name.length == 45 &&
            [[NSUUID alloc] initWithUUIDString:[name substringToIndex:36]]) [fm removeItemAtURL:file error:nil];
    }
    NSString *sourceName = cacheName(url.absoluteString);
    NSString *preparedName = cacheName([NSString stringWithFormat:@"%@|%.17g",url.absoluteString,ratio]);
    NSURL *source = [directory URLByAppendingPathComponent:sourceName];
    NSURL *output = [directory URLByAppendingPathComponent:preparedName];
    NSURL *temporary = [directory URLByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".part.mp4"]];
    NSSet *protected = [NSSet setWithObjects:sourceName,preparedName,nil];
    // Cache entries must be plain files, never links to paths outside our directory.
    for (NSURL *file in @[source,output]) {
        NSNumber *regular = nil, *link = nil;
        [file getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        [file getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
        if ((link.boolValue || (regular && !regular.boolValue))) { *error = videoError(@"Invalid cache entry"); return nil; }
    }
    NSURL *ready = fileSize(output) ? output : nil;
    if (!ready && !fileSize(source)) {
        if (!makeRoom(SGVideoDownloadLimit, protected)) { *error = videoError(@"Cache is in use"); return nil; }
        BOOL downloaded = [work download:url to:temporary error:error];
        if (!downloaded || work.cancelled || ![fm moveItemAtURL:temporary toURL:source error:error]) {
            [fm removeItemAtURL:temporary error:nil]; return nil;
        }
    }
    if (work.cancelled) return nil;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:ready ?: source options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    CGSize size; CGAffineTransform transform; BOOL crop;
    double duration = CMTimeGetSeconds(asset.duration);
    if (!track || !asset.playable || !isfinite(duration) || duration <= 0 || duration > 60 ||
        !SGArtworkVideoGeometry(track.naturalSize, track.preferredTransform, ratio, &size, &transform, &crop) || (ready && crop)) {
        *error = videoError(@"Unreadable video, invalid dimensions, or clip longer than 60 seconds");
        @synchronized (leases()) {
            NSURL *bad = ready ?: source;
            if (![leases()[bad.lastPathComponent] unsignedIntegerValue]) [fm removeItemAtURL:bad error:nil];
        }
        return nil;
    }
    if (!ready && !crop) ready = source; // The player and preview apply the stored orientation without encoding.
    if (!ready) {
        if (!makeRoom(SGVideoFileLimit, protected)) { *error = videoError(@"Cache is in use"); return nil; }
        AVMutableVideoComposition *composition = [AVMutableVideoComposition videoComposition];
        composition.renderSize = size;
        float fps = track.nominalFrameRate;
        composition.frameDuration = CMTimeMake(1, (int32_t)ceil(isfinite(fps) && fps > 0 ? MIN(fps,60) : 30));
        AVMutableVideoCompositionLayerInstruction *layer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:track];
        [layer setTransform:transform atTime:kCMTimeZero];
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero,asset.duration);
        instruction.layerInstructions = @[layer]; composition.instructions = @[instruction];
        AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
        if (!exporter || ![exporter.supportedFileTypes containsObject:AVFileTypeMPEG4]) { *error = videoError(@"Unsupported video export"); return nil; }
        exporter.outputURL = temporary; exporter.outputFileType = AVFileTypeMPEG4;
        exporter.videoComposition = composition; exporter.fileLengthLimit = SGVideoFileLimit;
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        @synchronized (work) {
            if (work.cancelled) return nil;
            work.exporter = exporter;
            [exporter exportAsynchronouslyWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
        }
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER); work.exporter = nil;
        if (work.cancelled || exporter.status != AVAssetExportSessionStatusCompleted ||
            !fileSize(temporary) || fileSize(temporary) > SGVideoFileLimit) {
            *error = exporter.error ?: videoError(@"Video export failed");
            [fm removeItemAtURL:temporary error:nil]; return nil;
        }
        if (![fm moveItemAtURL:temporary toURL:output error:error]) { [fm removeItemAtURL:temporary error:nil]; return nil; }
        ready = output;
    }
    NSData *jpeg = preview(ready,work,error);
    if (!jpeg || work.cancelled) return nil;
    [fm setAttributes:@{NSFileModificationDate:NSDate.date} ofItemAtPath:ready.path error:nil];
    SGPreparedArtworkVideo *result = [SGPreparedArtworkVideo new];
    @synchronized (leases()) {
        leases()[ready.lastPathComponent] = @([leases()[ready.lastPathComponent] unsignedIntegerValue] + 1);
        result.fileURL = ready;
    }
    result.previewJPEG = jpeg;
    return result;
}
@implementation SGArtworkVideoPreparer {
    SGVideoWork *_work;
}
- (void)cancel { [_work cancel]; _work = nil; }
- (void)dealloc { [_work cancel]; }
- (void)prepareURL:(NSURL *)url aspectRatio:(double)ratio completion:(void (^)(SGPreparedArtworkVideo *, NSError *))completion {
    NSAssert(NSThread.isMainThread, @"Artwork preparation starts on the main queue");
    [self cancel];
    SGVideoWork *work = [SGVideoWork new]; _work = work;
    __weak SGArtworkVideoPreparer *owner = self;
    dispatch_async(preparationQueue(), ^{
        @autoreleasepool {
            if (work.cancelled) return;
            NSError *error = nil;
            SGPreparedArtworkVideo *result = nil;
            if (!SGArtworkVideoURLValid(url) || !isfinite(ratio) || ratio < 0.1 || ratio > 10)
                error = videoError(@"Invalid HTTPS URL or aspect ratio");
            else result = prepare(url,ratio,work,&error);
            if (!result && !error) error = videoError(@"Video preparation failed");
            dispatch_async(dispatch_get_main_queue(), ^{
                SGArtworkVideoPreparer *strongOwner = owner;
                if (!strongOwner || strongOwner->_work != work || work.cancelled) return;
                strongOwner->_work = nil;
                completion(result,error);
            });
        }
    });
}
@end
