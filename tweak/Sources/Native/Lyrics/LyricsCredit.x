#import "Core/SGCore.h"
#import "Shared/LyricsSources/LyricsSources.h"
#import "Shared/Player/PlayerState.h"

// These are the same locally established views used by LyricsPage.x and LyricsCard.x.
@interface SGLyricsCreditView : UITextView <SGPlayerStateObserver>
@property (nonatomic, strong) id creditObserver;
@end
@implementation SGLyricsCreditView
- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)container {
    if (!(self = [super initWithFrame:frame textContainer:container])) return nil;
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.layer.cornerRadius = 8;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.editable = NO; self.selectable = YES; self.scrollEnabled = NO;
    self.textContainerInset = UIEdgeInsetsMake(4, 6, 4, 6);
    self.linkTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor, NSUnderlineStyleAttributeName: @1};
    __weak SGLyricsCreditView *weakSelf = self;
    self.creditObserver = [NSNotificationCenter.defaultCenter addObserverForName:SGLyricsCreditDidChange object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { [weakSelf refresh]; }];
    SGAddPlayerStateObserver(self);
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self.creditObserver]; }
- (void)playerStateDidChange:(SPTPlayerState *)state { [self refresh]; }
- (void)refresh {
    NSAttributedString *credit = SGLyricsAttributionFor(SGKaraokePlayingTrack());
    self.hidden = !credit.length;
    if (!credit.length) { self.attributedText = nil; return; }
    NSMutableAttributedString *styled = [credit mutableCopy];
    [styled addAttributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2], NSForegroundColorAttributeName: UIColor.whiteColor} range:NSMakeRange(0, styled.length)];
    self.attributedText = styled;
    [self.superview setNeedsLayout];
}
@end
static char kCredit;
static void placeCredit(UIView *view, BOOL fullScreen) {
    SGLyricsCreditView *credit = objc_getAssociatedObject(view, &kCredit);
    if (!credit) {
        credit = [[SGLyricsCreditView alloc] initWithFrame:CGRectZero textContainer:nil];
        objc_setAssociatedObject(view, &kCredit, credit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [view addSubview:credit];
        [credit refresh];
    }
    if (credit.superview != view) [view addSubview:credit];
    CGFloat width = MAX(0, view.bounds.size.width - 32);
    CGFloat height = [credit sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
    CGFloat bottom = fullScreen ? MAX(view.safeAreaInsets.bottom, 16) + 48 : 12;
    credit.frame = CGRectMake(16, MAX(0, view.bounds.size.height - bottom - height), width, height);
    [view bringSubviewToFront:credit];
}
%hook _TtC32Lyrics_FullscreenElementPageImpl14FullscreenView
- (void)layoutSubviews { %orig; placeCredit((UIView *)self, YES); }
%end
%hook _TtC22Lyrics_CardElementImpl8CardView
- (void)layoutSubviews { %orig; placeCredit((UIView *)self, NO); }
%end
%ctor {
    if (!SGNativeUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC32Lyrics_FullscreenElementPageImpl14FullscreenView", @"_TtC22Lyrics_CardElementImpl8CardView"]);
}
