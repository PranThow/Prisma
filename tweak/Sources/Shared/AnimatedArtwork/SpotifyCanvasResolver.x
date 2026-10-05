#import "SpotifyCanvas.h"
#import "AnimatedArtwork.h"
#import <MediaPlayer/MediaPlayer.h>
#import "Shared/Player/PlayerState.h"
#import "Shared/Lyrics/SpotifyAuthorization.h"

NSString *const SGCanvasResultDidChange = @"SGCanvasResultDidChange";
static SGCanvasResult *sg_canvas;
SGCanvasResult *SGCanvasCurrentResult(void) { return sg_canvas; }

@interface SGCanvasResolver : NSObject <SGPlayerStateObserver, NSURLSessionTaskDelegate>
@property (nonatomic, copy) NSString *trackURI;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, copy) NSDictionary *attemptedHeaders;
@end

@implementation SGCanvasResolver
- (void)publish:(SGCanvasResult *)canvas {
    if (sg_canvas == canvas || ([sg_canvas.trackURI isEqual:canvas.trackURI] &&
                                 [sg_canvas.videoURL isEqual:canvas.videoURL])) return;
    sg_canvas = canvas;
    [NSNotificationCenter.defaultCenter postNotificationName:SGCanvasResultDidChange object:nil];
}
- (void)playerStateDidChange:(SPTPlayerState *)state { [self resolve:state]; }
- (void)playerTrackMetadataDidChange:(SPTPlayerState *)state { [self resolve:state]; }
- (void)authorizationChanged:(NSNotification *)notification { [self resolve:SGPlayerState()]; }
- (void)preferencesChanged:(NSNotification *)notification {
    if (NSThread.isMainThread) [self resolve:SGPlayerState()];
    else dispatch_async(dispatch_get_main_queue(), ^{ [self resolve:SGPlayerState()]; });
}
- (void)resolve:(SPTPlayerState *)state {
    BOOL supported = NO;
    if (@available(iOS 26.0, *)) {
        supported = SGAnimatedArtworkPreferredKey(MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys,
            MPNowPlayingInfoProperty3x4AnimatedArtwork, MPNowPlayingInfoProperty1x1AnimatedArtwork) != nil;
    }
    if (!supported || !SGAnimatedArtworkEnabled() || ![SGAnimatedArtworkOrder() containsObject:@"spotify"]) {
        self.generation++;
        [self.task cancel]; self.task = nil;
        self.trackURI = nil; self.attemptedHeaders = nil;
        [self publish:nil];
        return;
    }
    NSString *uri = SGURIString(state.track.URI);
    if (!(uri == self.trackURI || [uri isEqual:self.trackURI])) {
        self.generation++;
        [self.task cancel];
        self.task = nil;
        self.trackURI = uri;
        self.attemptedHeaders = nil;
        [self publish:nil];
    }
    SGCanvasResult *metadata = SGCanvasFromMetadata(state.track.metadata, uri);
    if (metadata) {
        // Invalidate even an already queued service completion: late metadata wins.
        self.generation++;
        [self.task cancel];
        self.task = nil;
        [self publish:metadata];
        return;
    }
    if (sg_canvas || self.task) return;
    NSData *body = SGCanvasRequestBody(uri);
    NSURL *url = [NSURL URLWithString:@"https://spclient.wg.spotify.com/canvaz-cache/v0/canvases"];
    NSDictionary *headers = SGSpotifyHeadersForURL(url);
    if (!body || !headers[@"authorization"] || [headers isEqual:self.attemptedHeaders]) return;
    self.attemptedHeaders = headers;
    if (!self.session) {
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.HTTPCookieStorage = nil;
        config.URLCredentialStorage = nil;
        config.URLCache = nil;
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = body;
    request.timeoutInterval = 15;
    request.allHTTPHeaderFields = headers;
    [request setValue:@"application/x-protobuf" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/x-protobuf" forHTTPHeaderField:@"Accept"];
    NSUInteger generation = self.generation;
    self.task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
        NSString *mime = http.MIMEType.lowercaseString;
        BOOL valid = !error && http.statusCode == 200 && [http.URL isEqual:url] && mime.length &&
            ([@[@"application/x-protobuf", @"application/protobuf", @"application/octet-stream"] containsObject:mime]);
        SGCanvasResult *canvas = valid ? SGCanvasFromProtobuf(data, uri) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            // Generation handles A -> B -> A as well as ordinary track changes.
            if (generation != self.generation || ![uri isEqual:self.trackURI] ||
                ![uri isEqual:SGURIString(SGPlayerState().track.URI)]) return;
            self.task = nil;
            [self publish:canvas];
            // Credentials may have refreshed while the request was in flight. The header comparison
            // prevents retries with the same credentials, including a missing-Canvas response.
            if (!canvas) [self resolve:SGPlayerState()];
        });
    }];
    [self.task resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completionHandler {
    // Do not forward Spotify authorization to a redirected destination, including the artwork CDN.
    completionHandler(nil);
}
@end

static SGCanvasResolver *sg_resolver;
%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        sg_resolver = [SGCanvasResolver new];
        SGAddPlayerStateObserver(sg_resolver);
        [NSNotificationCenter.defaultCenter addObserver:sg_resolver selector:@selector(authorizationChanged:)
            name:SGSpotifyAuthorizationDidChange object:nil];
        [NSNotificationCenter.defaultCenter addObserver:sg_resolver selector:@selector(preferencesChanged:)
            name:NSUserDefaultsDidChangeNotification object:nil];
        [sg_resolver resolve:SGPlayerState()];
    });
}
