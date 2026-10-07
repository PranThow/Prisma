// The Now playing page of the redesign, under Player (App/Pages.m puts it there): the bar and the
// player behind it.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlayingBar.h"
#import "Redesigned/Player/Player.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Redesigned/Kit/SGRFlow.h"

@interface SGRBackgroundSettings : SGModPage <SGPlayerStateObserver>
@end
@implementation SGRBackgroundSettings {
    SGRArtworkField *_preview;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _preview = [[SGRArtworkField alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 180)];
    _preview.flows = YES;
    _preview.showsBackdrop = YES;
    _preview.motionHeld = SGPlayerState().isPaused;
    [_preview setArtwork:SGRNowPlayingArtwork(NULL, NULL) identity:nil animated:NO];
    self.tableView.tableHeaderView = _preview;
    SGAddPlayerStateObserver(self);
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(artworkChanged:) name:SGRNowPlayingArtworkDidChangeNotification object:nil];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)playerStateDidChange:(SPTPlayerState *)state { _preview.motionHeld = state.isPaused; }
- (void)artworkChanged:(NSNotification *)note { [_preview setArtwork:SGRNowPlayingArtwork(NULL, NULL) identity:nil animated:YES]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 180);
    if (!CGRectEqualToRect(_preview.frame, frame)) { _preview.frame = frame; self.tableView.tableHeaderView = _preview; }
}
@end

static SGModRow *fluidSlider(NSString *name, NSString *key, double fallback, double minimum, double maximum, double step) {
    return SGSliderRow(name, nil, minimum, maximum, step,
        ^double { return SGRFluidValue(key, fallback, minimum, maximum); },
        ^(double value) { [NSUserDefaults.standardUserDefaults setDouble:value forKey:key]; },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%.2f", value]; });
}

UIViewController *SGRPlayerBackgroundSettingsPage(void) {
    SGModRow *providers = SGChoiceRow(@"Video providers", nil, @"spotifyglass.redesign.player.videoOrderChoice",
        @[@"Canvas, then Apple Music", @"Apple Music, then Canvas", @"Canvas only", @"Apple Music only", @"None"], 0);
    providers.chosen = ^(NSInteger index) {
        NSArray *orders = @[@[@"spotify", @"apple"], @[@"apple", @"spotify"], @[@"spotify"], @[@"apple"], @[]];
        [NSUserDefaults.standardUserDefaults setObject:orders[MAX(0, MIN(4, index))] forKey:SGRKeyPlayerVideoProviders];
    };
    providers.value = ^NSString * { NSArray *order = SGRPlayerVideoOrder(); return order.count ? [order componentsJoinedByString:@", "] : @"None"; };
    return [[SGRBackgroundSettings alloc] initWithTitle:@"Player background" intro:@"Preview uses the current cover. Changes apply immediately; playback pause holds the background still." sections:@[
        SGSection(nil, @[SGSwitchRow(@"Fluid cover", nil, SGRKeyPlayerFluid),
            SGOptionRow(@"Video background", @"Fluid cover is the fallback when no clip is available.", SGRKeyPlayerVideo), providers]),
        SGSection(@"Fluid cover", @[
            fluidSlider(@"Speed", SGRKeyFluidSpeed, 1, 0, 3, .05),
            fluidSlider(@"Warp", SGRKeyFluidWarp, 1.2, 0, 4, .05),
            fluidSlider(@"Blur", SGRKeyFluidBlur, 12, 0, 30, 1),
            fluidSlider(@"Saturation", SGRKeyFluidSaturation, 1.2, 0, 2, .05),
            fluidSlider(@"Brightness", SGRKeyFluidBrightness, -.18, -.5, .2, .01),
            SGActionRow(@"Reset fluid controls", nil, ^{
                for (NSString *key in @[SGRKeyFluidSpeed, SGRKeyFluidWarp, SGRKeyFluidBlur, SGRKeyFluidSaturation, SGRKeyFluidBrightness])
                    [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
            }),
        ]),
    ] footer:@"Video uses its own provider order. Reduce Motion, Low Power Mode and disabled video autoplay keep the static cover; Low Data Mode blocks new downloads."];
}

UIViewController *SGRNowPlayingBarSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGHideRow(@"Hide the device button", nil, SGRHideBarConnect),
        ]),
        SGSection(nil, @[
            SGPageRow(@"Player background", ^{ return SGRPlayerBackgroundSettingsPage(); }),
        ]),
    ] footer:nil];
}
