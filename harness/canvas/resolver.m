// Exercise the real resolver's settings gate without Spotify or live network access.
#import <Foundation/Foundation.h>
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Shared/AnimatedArtwork/SpotifyCanvas.h"
#include <assert.h>

static NSString *const MPNowPlayingInfoProperty3x4AnimatedArtwork = @"tall";
static NSString *const MPNowPlayingInfoProperty1x1AnimatedArtwork = @"square";
static NSArray *supported;
@interface MPNowPlayingInfoCenter : NSObject
+ (NSArray *)supportedAnimatedArtworkKeys;
@end
@implementation MPNowPlayingInfoCenter
+ (NSArray *)supportedAnimatedArtworkKeys { return supported; }
@end
@interface SPTPlayerTrack : NSObject
@property (nonatomic, copy) NSString *URI;
@property (nonatomic, copy) NSDictionary *metadata;
@end
@implementation SPTPlayerTrack @end
@interface SPTPlayerState : NSObject
@property (nonatomic, strong) SPTPlayerTrack *track;
@end
@implementation SPTPlayerState @end
@protocol SGPlayerStateObserver <NSObject> @end
static SPTPlayerState *state;
static SPTPlayerState *SGPlayerState(void) { return state; }
static NSString *SGURIString(id uri) { return uri; }
static NSDictionary *SGSpotifyHeadersForURL(NSURL *url) {
    assert(!"Disabled resolver must not read Spotify authorization"); return nil;
}
@interface PendingTask : NSObject
@property (nonatomic) BOOL cancelled;
- (void)cancel;
@end
@implementation PendingTask
- (void)cancel { self.cancelled = YES; }
@end
#include "resolver.inc"

int main(void) { @autoreleasepool {
    state = [SPTPlayerState new]; state.track = [SPTPlayerTrack new];
    state.track.URI = @"spotify:track:0123456789012345678901";
    NSDictionary *metadata = @{@"canvas_url":@"https://canvaz.scdn.co/fixture.mp4"};
    SGCanvasResolver *resolver = [SGCanvasResolver new];
    for (NSUInteger mode = 0; mode < 4; mode++) {
        supported = mode == 2 ? @[] : mode == 3 ? @[@"unknown"] : @[@"tall"];
        NSArray *order = mode == 1 ? @[@"appleMusic"] : @[@"spotify"];
        [NSUserDefaults.standardUserDefaults setVolatileDomain:@{
            SGKeyAnimatedArtwork:@(mode != 0), SGKeyAnimatedArtworkProviders:order} forName:NSArgumentDomain];
        state.track.metadata = @{}; // Valid URI would otherwise reach authorization/service lookup.
        PendingTask *pending = [PendingTask new];
        resolver.task = (id)pending;
        resolver.trackURI = state.track.URI;
        resolver.attemptedHeaders = @{@"authorization":@"fixture"};
        [resolver publish:SGCanvasFromMetadata(metadata,state.track.URI)];
        NSUInteger generation = resolver.generation;
        [resolver preferencesChanged:nil];
        assert(pending.cancelled && !resolver.task && !resolver.attemptedHeaders);
        assert(resolver.generation > generation && !SGCanvasCurrentResult());
        // Re-enabling resolves current metadata without waiting for a track change.
        supported = @[@"square"];
        [NSUserDefaults.standardUserDefaults setVolatileDomain:@{
            SGKeyAnimatedArtwork:@YES, SGKeyAnimatedArtworkProviders:@[@"spotify"]} forName:NSArgumentDomain];
        state.track.metadata = metadata;
        [resolver preferencesChanged:nil];
        assert([SGCanvasCurrentResult().trackURI isEqual:state.track.URI]);
    }
    [NSUserDefaults.standardUserDefaults removeVolatileDomainForName:NSArgumentDomain];
    puts("Canvas resolver: disablement, cancellation, unsupported keys and re-enable passed");
} return 0; }
