#import <AVFoundation/AVFoundation.h>
#import "Shared/AnimatedArtwork/AppleMusicArtwork.h"
#import "Shared/AnimatedArtwork/ArtworkVideo.h"
#import "Album.h"

@interface SGRAlbumMotion : UIView
- (void)showArtist:(NSString *)artist album:(NSString *)album;
@end
@implementation SGRAlbumMotion {
    SGAppleMusicArtworkResolver *_resolver;
    SGArtworkVideoPreparer *_preparer;
    SGPreparedArtworkVideo *_lease;
    AVQueuePlayer *_player;
    AVPlayerLooper *_looper;
    AVPlayerLayer *_video;
    NSString *_artist, *_album;
    NSUInteger _generation;
    BOOL _requested;
    NSUInteger _attempts;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    self.clipsToBounds = YES;
    _resolver = [SGAppleMusicArtworkResolver new];
    _preparer = [SGArtworkVideoPreparer new];
    _video = [AVPlayerLayer layer];
    _video.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:_video];
    for (NSNotificationName name in @[UIApplicationDidBecomeActiveNotification, UIApplicationWillResignActiveNotification, NSProcessInfoPowerStateDidChangeNotification, UIAccessibilityReduceMotionStatusDidChangeNotification]) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateMotion) name:name object:nil];
    }
    return self;
}
- (void)dealloc {
    [_resolver cancel]; [_preparer cancel]; [_player pause];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)layoutSubviews { [super layoutSubviews]; _video.frame = self.bounds; }
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) {
        _generation++; [_resolver cancel]; [_preparer cancel]; _requested = NO;
        [_player pause];
    }
    [self updateMotion];
}
- (void)showArtist:(NSString *)artist album:(NSString *)album {
    if (![_artist isEqualToString:artist] || ![_album isEqualToString:album]) {
        _generation++; [_resolver cancel]; [_preparer cancel]; [_player pause];
        _video.player = nil; _player = nil; _looper = nil; _lease = nil;
        _artist = [artist copy]; _album = [album copy]; _requested = NO; _attempts = 0;
    }
    [self updateMotion];
}
- (BOOL)canAnimate {
    static BOOL enabled;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ enabled = SGHidden(SGRKeyAlbumMotion); });
    return enabled && self.window && UIApplication.sharedApplication.applicationState == UIApplicationStateActive && !NSProcessInfo.processInfo.lowPowerModeEnabled && !UIAccessibilityIsReduceMotionEnabled();
}
- (void)retry:(NSUInteger)generation {
    if (_attempts >= 3) return;
    __weak typeof(self) weakSelf = self;
    NSTimeInterval delay = MAX(2, [_resolver retryDelay]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SGRAlbumMotion *owner = weakSelf;
        if (!owner || owner->_generation != generation) return;
        owner->_requested = NO;
        [owner updateMotion];
    });
}
- (void)updateMotion {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self updateMotion]; }); return; }
    if (![self canAnimate]) { [_player pause]; self.hidden = YES; return; }
    self.hidden = !_lease;
    if (_player) { [_player play]; return; }
    if (_requested || _attempts >= 3 || !_artist.length || !_album.length) return;
    _requested = YES; _attempts++;
    NSUInteger generation = _generation;
    __weak typeof(self) weakSelf = self;
    [_resolver resolveArtist:_artist album:_album aspectRatio:1 completion:^(NSURL *clip, NSError *error) {
        SGRAlbumMotion *owner = weakSelf;
        if (!owner || owner->_generation != generation) return;
        if (!clip) { [owner retry:generation]; return; }
        [owner->_preparer prepareURL:clip aspectRatio:1 completion:^(SGPreparedArtworkVideo *video, NSError *failure) {
            SGRAlbumMotion *live = weakSelf;
            if (!live || live->_generation != generation) return;
            if (!video) { [live->_resolver invalidateClip:clip]; [live retry:generation]; return; }
            live->_lease = video;
            AVPlayerItem *item = [AVPlayerItem playerItemWithURL:video.fileURL];
            live->_player = [AVQueuePlayer queuePlayerWithItems:@[]];
            live->_player.muted = YES;
            live->_looper = [AVPlayerLooper playerLooperWithPlayer:live->_player templateItem:item];
            live->_video.player = live->_player;
            [live updateMotion];
        }];
    }];
}
@end
