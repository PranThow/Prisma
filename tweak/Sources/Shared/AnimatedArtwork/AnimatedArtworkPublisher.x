#import <MediaPlayer/MediaPlayer.h>
#import "AnimatedArtwork.h"
#import "ArtworkVideo.h"
#import "SpotifyCanvas.h"
#import "AppleMusicArtwork.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"

@interface SGArtworkPublisher : NSObject <SGPlayerStateObserver>
@property (nonatomic, strong) SGArtworkVideoPreparer *preparer;
@property (nonatomic, strong) SGAppleMusicArtworkResolver *apple;
@property (nonatomic, copy) NSArray *inputs;
@property (nonatomic, copy) NSString *trackURI;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSURL *canvasSource;
@property (nonatomic) NSUInteger providerIndex;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, strong) id artwork;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, copy) NSDictionary *info;
@property (nonatomic) CFAbsoluteTime reportedAt;
@property (nonatomic) BOOL republishing;
@property (nonatomic) BOOL exhausted;
@property (nonatomic) BOOL retryableFailure;
@property (nonatomic) NSUInteger retries;
@property (nonatomic) CFAbsoluteTime retryAt;
@end

static SGArtworkPublisher *sg_publisher;

@implementation SGArtworkPublisher
- (BOOL)enabled {
    return SGAnimatedArtworkEnabled() && SGAnimatedArtworkOrder().count > 0;
}
- (void)republish {
    // Lyrics owns the original artist and its playback clock. Its resend traverses our hook in
    // either order, without either hook mistaking the other's decorated info for Spotify's.
    if (SGRefreshLockScreenLyrics()) return;
    @synchronized (self) {
        if (!self.info) return;
        NSMutableDictionary *info = [self.info mutableCopy];
        if (info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) {
            double elapsed = [info[MPNowPlayingInfoPropertyElapsedPlaybackTime] doubleValue];
            elapsed += [info[MPNowPlayingInfoPropertyPlaybackRate] doubleValue] *
                (CFAbsoluteTimeGetCurrent() - self.reportedAt);
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(elapsed);
        }
        self.republishing = YES;
        MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = info;
        self.republishing = NO;
    }
}
- (void)playerStateDidChange:(SPTPlayerState *)state { [self update]; }
- (void)changed:(NSNotification *)notification {
    if (NSThread.isMainThread) [self update];
    else dispatch_async(dispatch_get_main_queue(), ^{ [self update]; });
}
- (void)playerTrackMetadataDidChange:(SPTPlayerState *)state { [self update]; }
- (void)update {
    if (@available(iOS 26.0, *)) {
        NSArray *keys = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys;
        NSString *key = SGAnimatedArtworkPreferredKey(keys, MPNowPlayingInfoProperty3x4AnimatedArtwork,
                                                     MPNowPlayingInfoProperty1x1AnimatedArtwork);
        SPTPlayerTrack *track = SGPlayerState().track;
        NSString *uri = SGURIString(track.URI);
        NSString *title = track.trackTitle;
        NSString *artist = track.artistName;
        id album = track.metadata[@"album_title"];
        if (![album isKindOfClass:NSString.class]) album = @"";
        SGCanvasResult *canvas = SGCanvasCurrentResult();
        NSURL *source = [canvas.trackURI isEqual:uri] ? canvas.videoURL : nil;
        NSArray *order = [self enabled] && key ? SGAnimatedArtworkOrder() : @[];
        // Canvas can arrive after fallback starts; only restart if its priority can improve the result.
        id token = [NSUserDefaults.standardUserDefaults objectForKey:SGKeyAppleMusicDeveloperToken];
        NSArray *inputs = @[uri ?: @"",title ?: @"",artist ?: @"",album,
                            key ?: @"",order,token ?: @""];
        NSUInteger generation;
        @synchronized (self) {
            BOOL sameInputs = [inputs isEqual:self.inputs];
            BOOL sameCanvas = source == self.canvasSource || [source isEqual:self.canvasSource];
            self.canvasSource = source;
            if (sameInputs) {
                NSUInteger spotify = [order indexOfObject:@"spotify"];
                BOOL improvedCanvas = !sameCanvas && spotify != NSNotFound && spotify <= self.providerIndex;
                if (!improvedCanvas && !(self.exhausted && self.retryableFailure && self.retries < 2 &&
                    CFAbsoluteTimeGetCurrent() >= self.retryAt)) return;
                if (improvedCanvas) self.retries = 0;
                else self.retries++;
            } else {
                self.retries = 0;
            }
            self.exhausted = NO;
            self.retryableFailure = NO;
            self.inputs = inputs;
            generation = ++self.generation;
            self.trackURI = uri; self.title = title; self.key = key;
            self.artwork = nil;
            self.providerIndex = 0;
        }
        [self.apple cancel];
        [self.preparer cancel];
        [self republish];
        if (!uri.length || !key || !order.count) return;
        double ratio = [key isEqual:MPNowPlayingInfoProperty3x4AnimatedArtwork] ? 0.75 : 1.0;
        [self tryProviders:order index:0 artist:artist album:album ratio:ratio generation:generation refreshed:NO];
    }
}
- (void)tryProviders:(NSArray *)order index:(NSUInteger)index
              artist:(NSString *)artist album:(NSString *)album ratio:(double)ratio generation:(NSUInteger)generation
              refreshed:(BOOL)refreshed {
    if (generation != self.generation || ![self enabled]) return;
    self.providerIndex = index;
    if (index >= order.count) {
        self.exhausted = YES;
        if (self.retryableFailure && self.retries < 2) {
            NSTimeInterval delay = MAX(self.retries ? 30 : 5, self.apple.retryDelay);
            self.retryAt = CFAbsoluteTimeGetCurrent() + delay;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    if (generation == self.generation) [self update];
                });
        }
        return;
    }
    void (^resolved)(NSURL *, NSError *) = ^(NSURL *source, NSError *error) {
        if (generation != self.generation || ![self enabled]) return;
        if (error) NSLog(@"[spotifyglass] apple artwork: %@",error.localizedDescription);
        if (error || !source) {
            if (error) self.retryableFailure = YES;
            [self tryProviders:order index:index+1 artist:artist album:album ratio:ratio generation:generation refreshed:NO];
            return;
        }
        [self prepareSource:source ratio:ratio generation:generation failed:^{
            self.retryableFailure = YES;
            BOOL apple = [order[index] isEqual:@"appleMusic"];
            if (apple) [self.apple invalidateClip:source];
            [self tryProviders:order index:apple && !refreshed ? index : index+1
                artist:artist album:album ratio:ratio generation:generation refreshed:apple && !refreshed];
        }];
    };
    if ([order[index] isEqual:@"spotify"]) resolved(self.canvasSource,nil);
    else [self.apple resolveArtist:artist album:album aspectRatio:ratio completion:resolved];
}
- (void)prepareSource:(NSURL *)source ratio:(double)ratio generation:(NSUInteger)generation failed:(void (^)(void))failed {
    if (@available(iOS 26.0, *)) {
        NSString *uri = self.trackURI, *key = self.key;
        [self.preparer prepareURL:source aspectRatio:ratio completion:^(SGPreparedArtworkVideo *video, NSError *error) {
            if (generation != self.generation || ![self enabled]) return;
            UIImage *preview = video.fileURL.isFileURL ? [UIImage imageWithData:video.previewJPEG] : nil;
            if (error || !preview) { failed(); return; }
            @synchronized (self) {
                if (generation != self.generation || ![self enabled] ||
                    ![uri isEqual:SGURIString(SGPlayerState().track.URI)]) return;
                // A -> B -> A gets a fresh ID: the old A object's handlers have been invalidated.
                NSString *identity = [NSString stringWithFormat:@"%@|%@|%@|%lu", uri,
                    source.absoluteString, key, (unsigned long)generation];
                self.artwork = [[MPMediaItemAnimatedArtwork alloc] initWithArtworkID:identity
                    previewImageRequestHandler:^(CGSize size, void (^completion)(UIImage *)) {
                        @synchronized (self) {
                            completion(generation == self.generation && [self enabled] ? preview : nil);
                        }
                    } videoAssetFileURLRequestHandler:^(CGSize size, void (^completion)(NSURL *)) {
                        @synchronized (self) {
                            // Capturing video retains its cache lease for the system's requests.
                            completion(generation == self.generation && [self enabled] ? video.fileURL : nil);
                        }
                    }];
            }
            [self republish];
        }];
    }
}
- (NSDictionary *)decorate:(NSDictionary *)info {
    @synchronized (self) {
        if (!(NSThread.isMainThread && (self.republishing || SGLockScreenLyricsIsRepublishing()))) {
            self.info = info;
            self.reportedAt = CFAbsoluteTimeGetCurrent();
        }
        if (!info) return nil;
        if (@available(iOS 26.0, *)) {
            // Now-playing and player-state notifications can arrive in either order.
            NSString *identifier = info[MPNowPlayingInfoPropertyExternalContentIdentifier];
            // Titles (even with artist/album) are not unique. Withhold ambiguous metadata.
            BOOL matches = self.trackURI.length && [identifier isEqual:self.trackURI] &&
                [self.title isEqual:info[MPMediaItemPropertyTitle]];
            return SGAnimatedArtworkInfo(info, MPNowPlayingInfoProperty3x4AnimatedArtwork,
                MPNowPlayingInfoProperty1x1AnimatedArtwork, self.key,
                matches && [self enabled] ? self.artwork : nil);
        }
        return info;
    }
}
@end

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    %orig([sg_publisher decorate:info]);
}
%end

%ctor {
    if (@available(iOS 26.0, *)) {
        sg_publisher = [SGArtworkPublisher new];
        sg_publisher.preparer = [SGArtworkVideoPreparer new];
        sg_publisher.apple = [SGAppleMusicArtworkResolver new];
        %init;
        dispatch_async(dispatch_get_main_queue(), ^{
            SGAddPlayerStateObserver(sg_publisher);
            [NSNotificationCenter.defaultCenter addObserver:sg_publisher selector:@selector(changed:)
                name:SGCanvasResultDidChange object:nil];
            [NSNotificationCenter.defaultCenter addObserver:sg_publisher selector:@selector(changed:)
                name:NSUserDefaultsDidChangeNotification object:nil];
            [sg_publisher update];
        });
    }
}
