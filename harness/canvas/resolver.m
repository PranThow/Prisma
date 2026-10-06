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
static NSDictionary *headers;
static NSDictionary *SGSpotifyHeadersForURL(NSURL *url) {
    assert(headers); return headers;
}
@interface PendingTask : NSObject
@property (nonatomic) BOOL cancelled;
- (void)cancel;
- (void)resume;
@end
@implementation PendingTask
- (void)cancel { self.cancelled = YES; }
- (void)resume {}
@end
@interface CanvasSession : NSObject
@property (nonatomic, copy) void (^done)(NSData *, NSURLResponse *, NSError *);
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic) NSUInteger requests;
@end
@implementation CanvasSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    self.request = request; self.done = completion; self.requests++;
    return (id)[PendingTask new];
}
@end
#include "resolver.inc"

static void respond(CanvasSession *session, NSInteger status, NSError *error) {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:session.request.URL
        statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/x-protobuf"}];
    session.done([NSData data],response,error);
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
}

int main(void) { @autoreleasepool {
    state = [SPTPlayerState new]; state.track = [SPTPlayerTrack new];
    state.track.URI = @"spotify:track:0123456789012345678901";
    NSDictionary *metadata = @{@"canvas.url":@"https://canvaz.scdn.co/fixture.mp4"};
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
    // Same credentials recover after transient errors, with at most two retries.
    headers = @{@"authorization":@"fixture"};
    state.track.metadata = @{}; [resolver publish:nil];
    CanvasSession *session = [CanvasSession new]; resolver.session = (id)session;
    [resolver resolve:state]; assert(session.requests == 1);
    respond(session,500,nil);
    assert(resolver.retryAt > CFAbsoluteTimeGetCurrent());
    [resolver resolve:state]; assert(session.requests == 1);
    resolver.retryAt = 1; [resolver resolve:state]; assert(session.requests == 2);
    respond(session,0,[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]);
    resolver.retryAt = 1; [resolver resolve:state]; assert(session.requests == 3);
    respond(session,503,nil); [resolver resolve:state]; assert(session.requests == 3 && !resolver.retryAt);
    // Changed credentials still retry, but a valid empty response is a confirmed miss.
    headers = @{@"authorization":@"new fixture"}; [resolver resolve:state];
    assert(session.requests == 4); respond(session,200,nil);
    [resolver resolve:state]; assert(session.requests == 4 && !resolver.retryAt);
    // Late dotted metadata cancels service work and wins over its queued completion.
    headers = @{@"authorization":@"third fixture"}; [resolver resolve:state];
    state.track.metadata = metadata; [resolver resolve:state];
    respond(session,500,nil);
    assert(SGCanvasCurrentResult().videoURL && !resolver.task);
    [NSUserDefaults.standardUserDefaults removeVolatileDomainForName:NSArgumentDomain];
    puts("Canvas resolver: disablement, cancellation, unsupported keys and re-enable passed");
} return 0; }
