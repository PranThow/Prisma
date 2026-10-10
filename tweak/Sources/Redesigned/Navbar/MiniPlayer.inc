#import "Redesigned/Kit/SGRKit.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/PlayerState.h"

static BOOL integratedPlayerEnabled(void) {
    static BOOL enabled;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ enabled = SGHidden(SGRKeyIntegratedPlayer); });
    return enabled;
}
@interface SGRMiniPlayer : UIControl <SGPlayerStateObserver, UIGestureRecognizerDelegate>
@property (nonatomic) BOOL minimized;
@property (nonatomic, weak) SGRSystemTabBar *bar;
@end
@implementation SGRMiniPlayer {
    UIImageView *_cover;
    UILabel *_title, *_artist;
    UIButton *_play, *_first, *_last;
    UIVisualEffectView *_glass;
    char _glassKey;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _glass = SGGlassFor(self, &_glassKey);
    _glass.userInteractionEnabled = NO;
    _cover = [UIImageView new];
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.clipsToBounds = YES;
    _cover.layer.cornerRadius = 8;
    _title = [UILabel new]; _artist = [UILabel new];
    _title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _artist.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _title.textColor = UIColor.whiteColor; _artist.textColor = UIColor.lightGrayColor;
    _play = [UIButton buttonWithType:UIButtonTypeSystem];
    _first = [UIButton buttonWithType:UIButtonTypeSystem];
    _last = [UIButton buttonWithType:UIButtonTypeSystem];
    _play.tintColor = _first.tintColor = _last.tintColor = UIColor.whiteColor;
    [_play addTarget:self action:@selector(togglePlayback) forControlEvents:UIControlEventTouchUpInside];
    [_first addTarget:self action:@selector(firstTab) forControlEvents:UIControlEventTouchUpInside];
    [_last addTarget:self action:@selector(lastTab) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *view in @[_cover, _title, _artist, _play, _first, _last]) [self addSubview:view];
    [self addTarget:self action:@selector(openPlayer) forControlEvents:UIControlEventTouchUpInside];
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityCustomActions = @[
        [[UIAccessibilityCustomAction alloc] initWithName:@"Previous track" target:self selector:@selector(skipPrevious:)],
        [[UIAccessibilityCustomAction alloc] initWithName:@"Next track" target:self selector:@selector(skipNext:)],
    ];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    pan.delegate = self;
    [self addGestureRecognizer:pan];
    SGAddPlayerStateObserver(self);
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(artworkChanged) name:SGRNowPlayingArtworkDidChangeNotification object:nil];
    [self playerStateDidChange:SGPlayerState()];
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)artworkChanged {
    NSString *uri = nil;
    UIImage *cover = SGRNowPlayingArtwork(&uri, NULL);
    _cover.image = [uri isEqualToString:SGURIString(SGPlayerState().track.URI)] ? cover : nil;
}
- (void)playerStateDidChange:(SPTPlayerState *)state {
    self.hidden = !state.track;
    _title.text = state.track.trackTitle;
    _artist.text = state.track.artistName;
    [_play setImage:[UIImage systemImageNamed:state.isPaused ? @"play.fill" : @"pause.fill"] forState:UIControlStateNormal];
    _play.accessibilityLabel = state.isPaused ? @"Play" : @"Pause";
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", _title.text ?: @"", _artist.text ?: @""];
    self.accessibilityHint = @"Opens the player. Swipe left or right to skip tracks.";
    [self artworkChanged];
}
- (void)playerTrackMetadataDidChange:(SPTPlayerState *)state { [self playerStateDidChange:state]; }
- (void)togglePlayback {
    id<SPTPlayer> player = SGKaraokePlayer();
    if (SGPlayerState().isPaused) [player resume:nil]; else [player pause:nil];
}
- (void)openPlayer {
    // The existing card identifier identifies the player-open target. Its ancestors can own the tap.
    UIView *card = SGRFindByIdentifier(sgr_nowPlayingRoot, @"SPTNowPlayingBar", NULL);
    for (UIView *view = card; view; view = view.superview) {
        if (fireTapRecognizers(view)) return;
        if (view == sgr_nowPlayingRoot) break;
    }
    [card accessibilityActivate];
}
- (BOOL)accessibilityActivate { [self openPlayer]; return YES; }
- (BOOL)skipPrevious:(UIAccessibilityCustomAction *)action {
    [(id<SPTPlayer>)SGKaraokePlayer() skipToPreviousTrackWithOptions:nil];
    return YES;
}
- (BOOL)skipNext:(UIAccessibilityCustomAction *)action {
    [(id<SPTPlayer>)SGKaraokePlayer() skipToNextTrackWithOptions:nil];
    return YES;
}
- (void)firstTab { if (self.bar.sources.count) { SGRNavbarSelectItem(self.bar.sources.firstObject); forwardTap(self.bar.sources.firstObject); } }
- (void)lastTab { if (self.bar.sources.count) { SGRNavbarSelectItem(self.bar.sources.lastObject); forwardTap(self.bar.sources.lastObject); } }
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (![gesture isKindOfClass:UIPanGestureRecognizer.class]) return YES;
    CGPoint velocity = [(UIPanGestureRecognizer *)gesture velocityInView:self];
    return fabs(velocity.x) > fabs(velocity.y);
}
- (void)panned:(UIPanGestureRecognizer *)pan {
    CGPoint delta = [pan translationInView:self];
    if (pan.state == UIGestureRecognizerStateChanged && !UIAccessibilityIsReduceMotionEnabled()) {
        CGFloat x = MAX(-48, MIN(48, delta.x));
        _cover.transform = _title.transform = _artist.transform = CGAffineTransformMakeTranslation(x, 0);
    }
    if (pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled) return;
    if (pan.state == UIGestureRecognizerStateEnded && (fabs(delta.x) > 44 || fabs([pan velocityInView:self].x) > 500)) {
        id<SPTPlayer> player = SGKaraokePlayer();
        if (delta.x < 0) [player skipToNextTrackWithOptions:nil]; else [player skipToPreviousTrackWithOptions:nil];
    }
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_cover.transform = self->_title.transform = self->_artist.transform = CGAffineTransformIdentity;
    } completion:nil];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width, side = self.minimized ? 48 : 0;
    _glass.frame = self.bounds;
    SGShapeGlass(_glass, 24, NO);
    _first.hidden = _last.hidden = !self.minimized;
    _first.frame = CGRectMake(0, 0, side, 56);
    _last.frame = CGRectMake(width - side, 0, side, 56);
    if (self.bar.items.count) {
        [_first setImage:self.bar.items.firstObject.image forState:UIControlStateNormal];
        [_last setImage:self.bar.items.lastObject.image forState:UIControlStateNormal];
        _first.accessibilityLabel = self.bar.items.firstObject.title ?: @"First tab";
        _last.accessibilityLabel = self.bar.items.lastObject.title ?: @"Last tab";
    }
    _cover.frame = CGRectMake(side + 10, 10, 36, 36);
    _play.frame = CGRectMake(width - side - 48, 6, 44, 44);
    CGFloat textWidth = MAX(0, width - 2 * side - 110);
    _title.frame = CGRectMake(side + 56, 9, textWidth, 21);
    _artist.frame = CGRectMake(side + 56, 30, textWidth, 17);
}
@end
