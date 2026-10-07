#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Album.h"
UIViewController *SGRAlbumSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Albums" intro:SGRestartNote sections:@[
        SGSection(nil, @[SGOptionRow(@"Animated artwork", @"Apple Music motion artwork for the album you are browsing.", SGRKeyAlbumMotion)]),
    ] footer:@"Reduce Motion and Low Power Mode show the static cover. Browsed albums keep their own artwork state."];
}
