// The player's settings that do not depend on the look: the lock screen widget's flags.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "PlayerSettings.h"
#import "SpeedPitch.h"
#import "Shared/AnimatedArtwork/AnimatedArtworkSettings.h"

SGModRow *SGPitchFollowsSpeedRow(void) {
    SGModRow *row = SGSwitchRow(@"Pitch follows speed", @"Changing speed also raises or lowers pitch", SGKeyPitchFollowsSpeed);
    row.changed = ^(BOOL on) { SGSetPlayerPitchFollowsSpeed(on); };
    return row;
}

UIViewController *SGLockScreenWidgetPage(void) {
    NSMutableArray<SGModRow *> *artwork = [SGAnimatedArtworkRows() mutableCopy];
    [artwork addObject:SGFlagRow(@"Companion content", @"ios-feature-lockscreen.companion_content_enabled")];
    return [[SGModPage alloc] initWithTitle:@"Lock screen widget" intro:@"Artwork changes apply immediately. Other changes apply after you restart Spotify." sections:@[
        SGSection(@"Controls", @[
            SGFlagRow(@"Like and dislike buttons", @"ios-feature-lockscreen.like_dislike_enabled"),
            SGFlagRow(@"Skip button on podcasts", @"ios-feature-lockscreen.skip_button_on_podcasts"),
            SGFlagRow(@"Chapter skip controls", @"ios-feature-lockscreen.enable_chapter_skip_controls"),
            SGFlagRow(@"Burst skip", @"ios-feature-lockscreen.burst_skip_enabled"),
        ]),
        SGSection(@"Artwork", artwork),
    ] footer:nil];
}
