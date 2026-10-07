#import <MediaPlayer/MediaPlayer.h>
#import "Core/SGPrefs.h"
#import "AnimatedArtwork.h"
#import "AnimatedArtworkSettings.h"

NSArray<SGModRow *> *SGAnimatedArtworkRows(void) {
    BOOL supported = NO;
    if (@available(iOS 26.0, *)) {
        supported = SGAnimatedArtworkPreferredKey(MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys,
            MPNowPlayingInfoProperty3x4AnimatedArtwork, MPNowPlayingInfoProperty1x1AnimatedArtwork) != nil;
    }
    if (!supported) {
        SGModRow *row = SGStatRow(@"Animated artwork unavailable", ^NSString *{ return @"Unavailable"; });
        row.subtitle = @"Animated lock-screen artwork needs iOS 26 and a device that supports it. The system may also disable it in Low Power Mode or when Auto-Play Animated Images is off in Accessibility > Motion.";
        return @[row];
    }
    // The standard switch reads SGFlag, so repair malformed imported values before it reads them.
    if ([NSUserDefaults.standardUserDefaults objectForKey:SGKeyAnimatedArtwork]) {
        SGSetEnabled(SGKeyAnimatedArtwork, SGAnimatedArtworkEnabled());
    }
    SGModRow *providers = SGPageRow(@"Artwork providers", ^UIViewController *{
        return SGAnimatedArtworkProvidersPage();
    });
    providers.value = ^NSString *{
        NSArray *order = SGAnimatedArtworkOrder();
        if (!order.count) return @"None enabled";
        return [order.firstObject isEqualToString:@"spotify"] ? @"Spotify first" : @"Apple Music first";
    };
    return @[
        SGOptionRow(@"Animated artwork", @"Animated artwork on the lock screen.", SGKeyAnimatedArtwork),
        providers,
    ];
}
