// Compile the real publisher without Logos, with controllable provider and MediaPlayer callbacks.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dispatch/dispatch.h>
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Shared/AnimatedArtwork/ArtworkVideo.h"
#import "Shared/AnimatedArtwork/AppleMusicArtwork.h"
#import "Shared/AnimatedArtwork/SpotifyCanvas.h"
#include <assert.h>

static NSString *const MPNowPlayingInfoProperty3x4AnimatedArtwork = @"tall";
static NSString *const MPNowPlayingInfoProperty1x1AnimatedArtwork = @"square";
static NSString *const MPNowPlayingInfoPropertyElapsedPlaybackTime = @"elapsed";
static NSString *const MPNowPlayingInfoPropertyPlaybackRate = @"rate";
static NSString *const MPNowPlayingInfoPropertyExternalContentIdentifier = @"uri";
static NSString *const MPMediaItemPropertyTitle = @"title";
static NSArray *supported;
@interface MPNowPlayingInfoCenter : NSObject
@property (nonatomic, copy) NSDictionary *nowPlayingInfo;
+ (instancetype)defaultCenter;
+ (NSArray *)supportedAnimatedArtworkKeys;
@end
@implementation MPNowPlayingInfoCenter
+ (instancetype)defaultCenter { static id center; if (!center) center = [self new]; return center; }
+ (NSArray *)supportedAnimatedArtworkKeys { return supported; }
@end

@interface UIImage : NSObject
+ (instancetype)imageWithData:(NSData *)data;
@end
@implementation UIImage
+ (instancetype)imageWithData:(NSData *)data { return data.length ? [self new] : nil; }
@end
@interface MPMediaItemAnimatedArtwork : NSObject
@property (nonatomic, copy) void (^preview)(CGSize, void (^)(UIImage *));
@property (nonatomic, copy) void (^video)(CGSize, void (^)(NSURL *));
- (instancetype)initWithArtworkID:(NSString *)identity
    previewImageRequestHandler:(void (^)(CGSize, void (^)(UIImage *)))preview
    videoAssetFileURLRequestHandler:(void (^)(CGSize, void (^)(NSURL *)))video;
@end
@implementation MPMediaItemAnimatedArtwork
- (instancetype)initWithArtworkID:(NSString *)identity
    previewImageRequestHandler:(void (^)(CGSize, void (^)(UIImage *)))preview
    videoAssetFileURLRequestHandler:(void (^)(CGSize, void (^)(NSURL *)))video {
    if ((self = [super init])) { self.preview = preview; self.video = video; } return self;
}
@end

@interface SPTPlayerTrack : NSObject
@property (nonatomic, copy) NSString *URI, *trackTitle, *artistName;
@property (nonatomic, copy) NSDictionary *metadata;
@end
@implementation SPTPlayerTrack @end
@interface SPTPlayerState : NSObject
@property (nonatomic, strong) SPTPlayerTrack *track;
@end
@implementation SPTPlayerState @end
@protocol SGPlayerStateObserver <NSObject>
- (void)playerStateDidChange:(SPTPlayerState *)state;
@end
static SPTPlayerState *state;
static SGCanvasResult *canvas;
static SPTPlayerState *SGPlayerState(void) { return state; }
static NSString *SGURIString(id uri) { return uri; }
SGCanvasResult *SGCanvasCurrentResult(void) { return canvas; }
static BOOL SGRefreshLockScreenLyrics(void) { return NO; }
static BOOL SGLockScreenLyricsIsRepublishing(void) { return NO; }

// Keep canceled callbacks so tests can deliberately deliver them after replacement.
@interface SGAppleMusicArtworkResolver ()
@property (nonatomic, strong) NSMutableArray *callbacks;
@property (nonatomic) NSUInteger cancellations;
@property (nonatomic, strong) NSURL *invalidated;
@property (nonatomic) NSTimeInterval cooldown;
@end
@implementation SGAppleMusicArtworkResolver
- (instancetype)init { if ((self = [super init])) self.callbacks = [NSMutableArray new]; return self; }
- (void)cancel { self.cancellations++; }
- (void)invalidateClip:(NSURL *)clip { self.invalidated = clip; }
- (NSTimeInterval)retryDelay { return self.cooldown; }
- (void)resolveArtist:(NSString *)artist album:(NSString *)album aspectRatio:(double)ratio
    completion:(void (^)(NSURL *, NSError *))completion { [self.callbacks addObject:[completion copy]]; }
@end
@interface SGArtworkVideoPreparer ()
@property (nonatomic, strong) NSMutableArray *callbacks, *urls;
@property (nonatomic) NSUInteger cancellations;
@property (nonatomic) double ratio;
@end
@implementation SGArtworkVideoPreparer
- (instancetype)init {
    if ((self = [super init])) { self.callbacks = [NSMutableArray new]; self.urls = [NSMutableArray new]; }
    return self;
}
- (void)cancel { self.cancellations++; }
- (void)prepareURL:(NSURL *)url aspectRatio:(double)ratio
    completion:(void (^)(SGPreparedArtworkVideo *, NSError *))completion {
    self.ratio = ratio; [self.urls addObject:url]; [self.callbacks addObject:[completion copy]];
}
@end
@interface SGPreparedArtworkVideo ()
@property (nonatomic, readwrite) NSURL *fileURL;
@property (nonatomic, readwrite) NSData *previewJPEG;
@end
@implementation SGPreparedArtworkVideo @end

#include "publisher.inc"

static NSURL *clip(NSString *name) {
    return [NSURL URLWithString:[@"https://example.test/" stringByAppendingString:name]];
}
static void preferences(NSArray *order, BOOL enabled) {
    [NSUserDefaults.standardUserDefaults setVolatileDomain:
        @{SGKeyAnimatedArtworkProviders:order, SGKeyAnimatedArtwork:@(enabled)} forName:NSArgumentDomain];
}
static void track(NSString *name) {
    state = [SPTPlayerState new]; state.track = [SPTPlayerTrack new];
    state.track.URI = [@"spotify:track:" stringByAppendingString:
        [name stringByPaddingToLength:22 withString:@"0" startingAtIndex:0]];
    state.track.trackTitle = @"Same title"; state.track.artistName = @"Artist";
    state.track.metadata = @{@"album_title":@"Album"}; canvas = nil;
}
static void canvasClip(NSString *name) { canvas = SGCanvasFromMetadata(@{@"canvas.url":
    [@"https://canvaz.scdn.co/" stringByAppendingFormat:@"%@.mp4", name]}, state.track.URI); assert(canvas); }
static SGArtworkPublisher *publisher(NSArray *order) {
    preferences(order, YES); supported = @[@"tall", @"square"]; track(@"A");
    SGArtworkPublisher *p = [SGArtworkPublisher new];
    p.apple = [SGAppleMusicArtworkResolver new]; p.preparer = [SGArtworkVideoPreparer new]; return p;
}
static void apple(SGArtworkPublisher *p, NSUInteger index, NSURL *url, NSError *error) {
    void (^done)(NSURL *, NSError *) = p.apple.callbacks[index]; done(url, error);
}
static void prepared(SGArtworkPublisher *p, NSUInteger index, NSInteger kind) {
    SGPreparedArtworkVideo *video = nil;
    if (kind) {
        video = [SGPreparedArtworkVideo new];
        video.fileURL = kind == 2 ? clip(@"remote") : [NSURL fileURLWithPath:@"/tmp/clip.mp4"];
        video.previewJPEG = kind == 3 ? [NSData data] : [@"JPEG" dataUsingEncoding:NSUTF8StringEncoding];
    }
    void (^done)(SGPreparedArtworkVideo *, NSError *) = p.preparer.callbacks[index]; done(video, nil);
}

int main(void) {
    @autoreleasepool {
        SGArtworkPublisher *p = publisher(@[@"spotify", @"appleMusic"]);
        canvasClip(@"A"); [p update]; assert(p.apple.callbacks.count == 0);
        assert([p.preparer.urls.lastObject isEqual:canvas.videoURL]);
        NSUInteger generation = p.generation, cancels = p.preparer.cancellations;
        [p playerStateDidChange:state]; [p playerTrackMetadataDidChange:state];
        assert(p.generation == generation && p.preparer.cancellations == cancels);
        prepared(p, 0, 1); assert(p.artwork && p.apple.callbacks.count == 0);

        // Download/preparation failure and unusable output all continue in persisted order.
        for (NSInteger failure = 0; failure <= 3; failure++) {
            if (failure == 1) continue;
            p = publisher(@[@"spotify", @"appleMusic"]); canvasClip(@"A"); [p update];
            prepared(p, 0, failure); assert(p.apple.callbacks.count == 1);
            apple(p, 0, clip(@"apple"), nil); prepared(p, 1, 1); assert(p.artwork);
        }
        p = publisher(@[@"appleMusic", @"spotify"]); canvasClip(@"A"); [p update];
        assert(!p.preparer.urls.count);
        apple(p, 0, nil, [NSError errorWithDomain:@"lookup" code:1 userInfo:nil]);
        assert([p.preparer.urls.lastObject isEqual:canvas.videoURL]); prepared(p, 0, 1); assert(p.artwork);
        p = publisher(@[@"appleMusic", @"spotify"]); canvasClip(@"A"); [p update];
        apple(p, 0, clip(@"apple"), nil); prepared(p, 0, 0);
        assert([p.apple.invalidated isEqual:clip(@"apple")] && p.apple.callbacks.count == 2);
        apple(p, 1, clip(@"refreshed"), nil); prepared(p, 1, 0);
        assert([p.apple.invalidated isEqual:clip(@"refreshed")] && p.apple.callbacks.count == 2);
        assert([p.preparer.urls.lastObject isEqual:canvas.videoURL]); prepared(p, 2, 1); assert(p.artwork);
        p = publisher(@[@"appleMusic"]); [p update];
        apple(p, 0, clip(@"expired"), nil); prepared(p, 0, 0);
        apple(p, 1, clip(@"fresh"), nil); prepared(p, 1, 1);
        assert(p.artwork && p.apple.callbacks.count == 2);

        // Transient exhaustion retries twice after cooldown, without restarting pending/successful work.
        p = publisher(@[@"appleMusic"]); [p update];
        NSError *offline = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
        for (NSUInteger attempt = 0; attempt < 3; attempt++) {
            apple(p, attempt, nil, offline); assert(p.exhausted);
            [p update]; assert(p.apple.callbacks.count == attempt + 1);
            p.retryAt = 0; [p update];
            assert(p.apple.callbacks.count == MIN(attempt + 2, 3));
        }
        p = publisher(@[@"appleMusic"]); [p update]; apple(p, 0, nil, nil);
        p.retryAt = 0; [p update]; assert(p.apple.callbacks.count == 1); // Confirmed miss.
        p = publisher(@[@"appleMusic"]); [p update]; apple(p, 0, nil, offline);
        p.retryAt = 0; [p update]; apple(p, 1, clip(@"recovered"), nil); prepared(p, 0, 1);
        id recovered = p.artwork; [p update]; assert(p.artwork == recovered && p.apple.callbacks.count == 2);
        p = publisher(@[@"appleMusic"]); [p update]; p.apple.cooldown = 65;
        apple(p, 0, nil, offline);
        assert(p.retryAt - CFAbsoluteTimeGetCurrent() > 64);
        [p update]; assert(p.apple.callbacks.count == 1);

        // Lower-priority Canvas arriving during Apple lookup must remain available for fallback.
        p = publisher(@[@"appleMusic", @"spotify"]); [p update]; generation = p.generation;
        canvasClip(@"late"); [p update]; assert(p.generation == generation);
        apple(p, 0, nil, nil); assert([p.preparer.urls.lastObject isEqual:canvas.videoURL]);
        prepared(p, 0, 1); assert(p.artwork);
        preferences(@[], YES); [p update]; assert(!p.artwork);
        prepared(p, 0, 1); assert(!p.artwork);

        // Lower-priority metadata cannot displace a successful Apple result.
        p = publisher(@[@"appleMusic", @"spotify"]); [p update];
        apple(p, 0, clip(@"apple"), nil); prepared(p, 0, 1);
        id winner = p.artwork; generation = p.generation;
        canvasClip(@"late"); [p update]; assert(p.artwork == winner && p.generation == generation);

        // Higher-priority late Canvas replaces fallback and makes its queued callbacks harmless.
        p = publisher(@[@"spotify", @"appleMusic"]); [p update];
        apple(p, 0, clip(@"apple"), nil); canvasClip(@"late"); [p update];
        cancels = p.preparer.cancellations; prepared(p, 0, 0);
        assert(p.preparer.cancellations == cancels && p.preparer.urls.count == 2);
        prepared(p, 1, 1); winner = p.artwork; prepared(p, 0, 1); assert(p.artwork == winner);

        // Rapid A -> B -> A, including old lookup, preparation and system asset callbacks.
        p = publisher(@[@"appleMusic", @"spotify"]); [p update];
        track(@"B"); [p update]; apple(p, 1, clip(@"B"), nil);
        track(@"A"); [p update]; cancels = p.preparer.cancellations;
        apple(p, 0, clip(@"oldA"), nil); prepared(p, 0, 0);
        assert(!p.artwork && p.preparer.urls.count == 1 && p.preparer.cancellations == cancels);
        apple(p, 2, clip(@"newA"), nil); prepared(p, 1, 1); winner = p.artwork;
        prepared(p, 0, 1); assert(p.artwork == winner);
        MPMediaItemAnimatedArtwork *oldArtwork = p.artwork;
        track(@"B"); [p update];
        oldArtwork.video(CGSizeZero, ^(NSURL *url) { assert(!url); });
        oldArtwork.preview(CGSizeZero, ^(UIImage *image) { assert(!image); });

        // Reorder invalidates a pending request; empty/disabled/unsupported inputs do no work.
        p = publisher(@[@"appleMusic", @"spotify"]); canvasClip(@"A"); [p update];
        preferences(@[@"spotify", @"appleMusic"], YES); [p update];
        apple(p, 0, clip(@"obsolete"), nil); assert(p.preparer.urls.count == 1);
        prepared(p, 0, 1); assert(p.artwork);
        for (NSUInteger mode = 0; mode < 3; mode++) {
            p = publisher(@[@"appleMusic"]); [p update];
            if (mode == 0) preferences(@[], YES);
            if (mode == 1) preferences(@[@"appleMusic"], NO);
            if (mode == 2) supported = @[];
            [p update]; cancels = p.preparer.cancellations;
            apple(p, 0, clip(@"obsolete"), nil); [p update];
            assert(!p.artwork && !p.preparer.urls.count && p.preparer.cancellations == cancels);
        }
        p = publisher(@[]); [p update]; assert(!p.apple.callbacks.count && !p.preparer.urls.count);
        p = publisher(@[@"appleMusic"]); state.track = nil; [p update];
        assert(!p.apple.callbacks.count && !p.preparer.urls.count);
        // Shape changes cancel the old preparation and its callbacks cannot restart fallback.
        p = publisher(@[@"spotify", @"appleMusic"]); canvasClip(@"A"); [p update];
        assert(p.preparer.ratio == 0.75); supported = @[@"square"]; [p update];
        prepared(p, 0, 0); assert(!p.apple.callbacks.count && p.preparer.ratio == 1.0);
        prepared(p, 1, 1); assert(p.artwork);
        p = publisher(@[@"spotify"]); supported = @[@"square"]; canvasClip(@"A"); [p update];
        assert(p.preparer.ratio == 1.0); prepared(p, 0, 1); assert(p.artwork);
        // Readiness preserves all fields and advances only the elapsed-time anchor.
        NSDictionary *base = @{@"title":@"Same title", @"uri":state.track.URI,
            @"artist":@"Lyric line", @"album":@"Album", @"cover":@"Static cover", @"elapsed":@10, @"rate":@1};
        NSDictionary *shown = [p decorate:base];
        assert(shown[@"square"] == p.artwork && [shown[@"artist"] isEqual:@"Lyric line"]);
        p.reportedAt = CFAbsoluteTimeGetCurrent()-5; [p republish];
        NSDictionary *resent = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
        assert([resent[@"elapsed"] doubleValue] >= 15);
        for (NSString *field in @[@"title",@"uri",@"artist",@"album",@"cover",@"rate"])
            assert([resent[field] isEqual:base[field]]);
        NSMutableDictionary *paused = [base mutableCopy]; paused[@"rate"] = @0;
        [p decorate:paused]; p.reportedAt = CFAbsoluteTimeGetCurrent()-5; [p republish];
        assert([MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo[@"elapsed"] doubleValue] == 10);
        NSMutableDictionary *other = [base mutableCopy]; other[@"uri"] = @"spotify:track:other";
        assert(![p decorate:other][@"square"]);
        // Metadata arrives before player state for another track with the same title.
        [other removeObjectForKey:@"uri"];
        assert(![p decorate:other][@"square"]);
        track(@"B"); [p update];
        assert(![p decorate:base][@"square"]);
        // Disabled mode preserves Spotify objects but strips every still-live Prisma object.
        preferences(@[@"spotify"], NO); [p update];
        assert(![p decorate:shown][@"square"]);
        other[@"square"] = @"Spotify square"; other[@"tall"] = @"Spotify tall";
        assert([[p decorate:other] isEqual:other]);
        assert(![p decorate:nil]);
        puts("animated artwork publisher: passed");
    }
}
