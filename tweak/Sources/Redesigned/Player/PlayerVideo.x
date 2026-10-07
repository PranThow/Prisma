// Independent player consumer: shared resolvers carry no player UI state or lock-screen settings.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Shared/AnimatedArtwork/SpotifyCanvas.h"
#import "Shared/AnimatedArtwork/AppleMusicArtwork.h"
#import "Shared/AnimatedArtwork/ArtworkVideo.h"
#import "Player.h"
#import "SGRPlayerVideoPolicy.h"
#import <AVFoundation/AVFoundation.h>

NSArray<NSString *> *SGRPlayerVideoOrder(void) {
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:SGRKeyPlayerVideoProviders];
    return SGRPlayerNormalizeVideoOrder(stored);
}

@interface SGRPlayerVideo : UIView <SGPlayerStateObserver>
@end
@implementation SGRPlayerVideo {
    AVQueuePlayer *_player;
    AVPlayerLooper *_looper;
    AVPlayerLayer *_surface;
    SGPreparedArtworkVideo *_lease;
    SGArtworkVideoPreparer *_preparer;
    SGAppleMusicArtworkResolver *_apple;
    NSString *_identity, *_provider;
    NSArray *_order;
    NSUInteger _generation, _index;
    BOOL _pending, _refreshing, _watchingPlayer;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _preparer = [SGArtworkVideoPreparer new];
    _apple = [SGAppleMusicArtworkResolver new];
    _surface = [AVPlayerLayer layer];
    [_surface addObserver:self forKeyPath:@"readyForDisplay" options:0 context:NULL];
    _surface.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:_surface];
    // Darken the content surface to keep controls readable over any clip.
    UIView *shade = [[UIView alloc] initWithFrame:self.bounds];
    shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    shade.backgroundColor = [UIColor colorWithWhite:0 alpha:.35];
    [self addSubview:shade];
    self.alpha = 0;
    SGAddPlayerStateObserver(self);
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[NSUserDefaultsDidChangeNotification, UIApplicationDidBecomeActiveNotification,
        UIApplicationWillResignActiveNotification, NSProcessInfoPowerStateDidChangeNotification,
        UIAccessibilityReduceMotionStatusDidChangeNotification, UIAccessibilityVideoAutoplayStatusDidChangeNotification])
        [center addObserver:self selector:@selector(changed:) name:name object:nil];
    [center addObserver:self selector:@selector(canvasChanged:) name:SGCanvasResultDidChange object:nil];
    [center addObserver:self selector:@selector(failed:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    SGRObservePlayerTransition(self, ^(id owner) { [owner updatePlayback]; }, ^(id owner) { [owner updatePlayback]; });
    return self;
}
- (void)dealloc {
    [_surface removeObserver:self forKeyPath:@"readyForDisplay"];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_preparer cancel]; [_apple cancel]; [self releasePlayer];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    _surface.frame = self.bounds;
    [CATransaction commit];
}
- (void)didMoveToWindow { [super didMoveToWindow]; [self refresh]; }
- (void)changed:(NSNotification *)note { dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; }); }
- (void)playerStateDidChange:(SPTPlayerState *)state { [self refresh]; }
- (void)playerTrackMetadataDidChange:(SPTPlayerState *)state { [self refresh]; }
- (BOOL)eligible {
    return self.window && SGHidden(SGRKeyPlayerVideo) &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        !UIAccessibilityIsReduceMotionEnabled() && UIAccessibilityIsVideoAutoplayEnabled() &&
        !NSProcessInfo.processInfo.lowPowerModeEnabled;
}
- (void)clear {
    ++_generation; _pending = NO;
    [_preparer cancel]; [_apple cancel]; [self releasePlayer];
    _provider = nil;
    SGRPlayerSetVideoActive(NO);
    SGRPlayerField().motionHeld = SGPlayerState().isPaused;
    [UIView animateWithDuration:.2 animations:^{ self.alpha = 0; }];
}
- (void)releasePlayer {
    if (_watchingPlayer) [_player removeObserver:self forKeyPath:@"currentItem.status"];
    _watchingPlayer = NO;
    [_player pause]; [_looper disableLooping];
    _surface.player = nil; _looper = nil; _player = nil; _lease = nil;
}
- (void)refresh {
    if (_refreshing) return;
    _refreshing = YES;
    SPTPlayerState *state = SGPlayerState();
    NSString *uri = SGURIString(state.track.URI);
    NSArray *order = SGRPlayerVideoOrder();
    BOOL eligible = [self eligible] && uri.length && order.count;
    // Register before reading Canvas; synchronous resolver notifications are suppressed by identity.
    NSString *identity = eligible ? [@[uri, state.track.artistName ?: @"", state.track.metadata[@"album_title"] ?: @"", order] description] : nil;
    if (![_identity isEqual:identity]) {
        _identity = identity;
        [self clear]; _order = order; _index = 0;
        SGCanvasSetConsumerActive(self, eligible && [order containsObject:@"spotify"]);
        if (eligible) [self next];
    } else if (!eligible) SGCanvasSetConsumerActive(self, NO);
    [self updatePlayback];
    _refreshing = NO;
}
- (void)canvasChanged:(NSNotification *)note {
    if (_refreshing) return;
    SGCanvasResult *canvas = SGCanvasCurrentResult();
    if (![self eligible] || ![canvas.trackURI isEqual:SGURIString(SGPlayerState().track.URI)]) return;
    NSUInteger spotify = [_order indexOfObject:@"spotify"];
    // An exhausted chain has no current provider, even if its last attempted source was Canvas.
    NSString *current = (_lease || _pending) ? _provider : nil;
    if (!SGRPlayerCanvasCanImprove(_order, current)) return;
    // Late higher-priority Canvas can replace Apple, including an Apple lookup still pending.
    [self clear]; _index = spotify; [self next];
}
- (void)next {
    if (![self eligible] || _index >= _order.count) return;
    NSString *provider = _order[_index++];
    _provider = provider; _pending = YES;
    NSUInteger generation = _generation;
    __weak SGRPlayerVideo *weakSelf = self;
    void (^resolved)(NSURL *) = ^(NSURL *url) {
        SGRPlayerVideo *owner = weakSelf;
        if (!owner || generation != owner->_generation || ![owner eligible]) return;
        if (!url) { owner->_pending = NO; [owner next]; return; }
        [owner->_preparer prepareURL:url aspectRatio:.75 completion:^(SGPreparedArtworkVideo *video, NSError *error) {
            SGRPlayerVideo *current = weakSelf;
            if (!current || generation != current->_generation || ![current eligible]) return;
            current->_pending = NO;
            if (!video) {
                if ([provider isEqual:@"apple"]) [current->_apple invalidateClip:url];
                [current next]; return;
            }
            current->_lease = video;
            current->_player = [AVQueuePlayer queuePlayerWithItems:@[]];
            current->_player.muted = YES;
            AVPlayerItem *item = [AVPlayerItem playerItemWithURL:video.fileURL];
            current->_looper = [AVPlayerLooper playerLooperWithPlayer:current->_player templateItem:item];
            current->_surface.player = current->_player;
            current->_watchingPlayer = YES;
            [current->_player addObserver:current forKeyPath:@"currentItem.status" options:NSKeyValueObservingOptionNew context:NULL];
            [current updatePlayback];
        }];
    };
    if ([provider isEqual:@"spotify"]) {
        SGCanvasResult *canvas = SGCanvasCurrentResult();
        resolved([canvas.trackURI isEqual:SGURIString(SGPlayerState().track.URI)] ? canvas.videoURL : nil);
    } else {
        SPTPlayerTrack *track = SGPlayerState().track;
        [_apple resolveArtist:track.artistName album:track.metadata[@"album_title"] aspectRatio:.75
            completion:^(NSURL *url, NSError *error) { resolved(url); }];
    }
}
- (void)updatePlayback {
    BOOL active = _lease && [self eligible] && !SGRPlayerIsTransitioning();
    BOOL shown = active && _surface.readyForDisplay;
    SGRPlayerField().motionHeld = SGPlayerState().isPaused || shown;
    SGRPlayerSetVideoActive(shown);
    [UIView animateWithDuration:.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{ self.alpha = shown ? 1 : 0; } completion:nil];
    if (active && !SGPlayerState().isPaused) [_player play]; else [_player pause];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _surface && [keyPath isEqual:@"readyForDisplay"])
        dispatch_async(dispatch_get_main_queue(), ^{ [self updatePlayback]; });
    else if (object == _player && [keyPath isEqual:@"currentItem.status"])
        dispatch_async(dispatch_get_main_queue(), ^{
            if (object == self->_player && self->_player.currentItem.status == AVPlayerItemStatusFailed) [self clipFailed];
        });
    else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
- (void)failed:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_player.items containsObject:note.object]) [self clipFailed];
    });
}
- (void)clipFailed {
    [self releasePlayer];
    SGRPlayerSetVideoActive(NO); self.alpha = 0;
    SGRPlayerField().motionHeld = SGPlayerState().isPaused;
    [self next];
}
@end

static char kVideoKey;
%hook _TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *plane = ((UIViewController *)self).viewIfLoaded;
    if (!plane || plane.bounds.size.height < 200) return;
    SGRPlayerVideo *video = objc_getAssociatedObject(plane, &kVideoKey);
    if (!video) {
        video = [[SGRPlayerVideo alloc] initWithFrame:plane.bounds];
        video.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(plane, &kVideoKey, video, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Either Logos hook can run first; creating the shared field here fixes both orders.
    UIView *host = SGRPlayerFieldIn(plane);
    if (host.superview != plane) [plane addSubview:host];
    if (video.superview != host) [host addSubview:video];
    else [host bringSubviewToFront:video];
    video.frame = host.bounds;
}
%end
%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController"]);
}
