#import <MediaPlayer/MediaPlayer.h>
#import "AnimatedArtwork.h"
#import "ArtworkVideo.h"
#import "SpotifyCanvas.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"

@interface SGArtworkPublisher : NSObject <SGPlayerStateObserver>
@property (nonatomic, strong) SGArtworkVideoPreparer *preparer;
@property (nonatomic, copy) NSString *trackURI;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSURL *source;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, strong) id artwork;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, copy) NSDictionary *info;
@property (nonatomic) CFAbsoluteTime reportedAt;
@property (nonatomic) BOOL republishing;
@end

static SGArtworkPublisher *sg_publisher;

@implementation SGArtworkPublisher
- (BOOL)enabled {
    return SGAnimatedArtworkEnabled() && [SGAnimatedArtworkOrder() containsObject:@"spotify"];
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
        NSString *uri = SGURIString(SGPlayerState().track.URI);
        NSString *title = SGPlayerState().track.trackTitle;
        SGCanvasResult *canvas = SGCanvasCurrentResult();
        NSURL *source = [self enabled] && key && [canvas.trackURI isEqual:uri] ? canvas.videoURL : nil;
        NSUInteger generation;
        @synchronized (self) {
            // nil == nil must also count as unchanged, to avoid repeated clears on pause/resume.
            if ((uri == self.trackURI || [uri isEqual:self.trackURI]) &&
                (source == self.source || [source isEqual:self.source]) &&
                (key == self.key || [key isEqual:self.key]) &&
                (title == self.title || [title isEqual:self.title])) return;
            generation = ++self.generation;
            self.trackURI = uri;
            self.title = title;
            self.source = source;
            self.key = key;
            self.artwork = nil;
        }
        [self.preparer cancel];
        [self republish];
        if (!source) return;
        double ratio = [key isEqual:MPNowPlayingInfoProperty3x4AnimatedArtwork] ? 0.75 : 1.0;
        [self.preparer prepareURL:source aspectRatio:ratio completion:^(SGPreparedArtworkVideo *video, NSError *error) {
            @synchronized (self) {
                if (generation != self.generation || ![self enabled] ||
                    ![uri isEqual:SGURIString(SGPlayerState().track.URI)] || !video.fileURL.isFileURL) return;
                UIImage *preview = [UIImage imageWithData:video.previewJPEG];
                if (!preview) return;
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
            BOOL matches = [self.title isEqual:info[MPMediaItemPropertyTitle]] &&
                (!identifier || [identifier isEqual:self.trackURI]);
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
