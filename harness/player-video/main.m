#import "Redesigned/Player/SGRPlayerVideoPolicy.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    assert([SGRPlayerNormalizeVideoOrder(nil) isEqual:@[@"spotify", @"apple"]]);
    assert([SGRPlayerNormalizeVideoOrder(@42) isEqual:@[@"spotify", @"apple"]]);
    assert([SGRPlayerNormalizeVideoOrder(@[]) isEqual:@[]]);
    assert([SGRPlayerNormalizeVideoOrder(@[@"apple", @"bad", @"spotify", @"apple", NSNull.null]) isEqual:@[@"apple", @"spotify"]]);
    assert(SGRPlayerCanvasCanImprove(@[@"spotify", @"apple"], @"apple"));
    assert(SGRPlayerCanvasCanImprove(@[@"spotify", @"apple"], nil));
    assert(!SGRPlayerCanvasCanImprove(@[@"apple", @"spotify"], @"apple"));
    assert(!SGRPlayerCanvasCanImprove(@[@"spotify", @"apple"], @"spotify"));
    assert(!SGRPlayerCanvasCanImprove(@[@"apple"], nil));
    assert(!SGRPlayerCanvasCanImprove(@[], nil));
    puts("Player video: independent order, empty/malformed preferences and late Canvas priority passed");
} return 0; }
