#import <Foundation/Foundation.h>
#import "App/About/SGVersion.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSArray *ordered = @[@"0.23.0-alpha", @"0.23.0-alpha.1", @"0.23.0-beta.2", @"0.23.0-beta.10", @"0.23.0-rc.1", @"0.23.0", @"0.24.0-beta.1"];
        for (NSUInteger i = 1; i < ordered.count; i++) {
            assert(SGVersionCompare(ordered[i-1], ordered[i]) == NSOrderedAscending);
            assert(SGVersionCompare(ordered[i], ordered[i-1]) == NSOrderedDescending);
        }
        assert(SGVersionCompare(@"0.23", @"0.23.0+build.9") == NSOrderedSame);
        assert(SGVersionCompare(@"0.23.0-beta-with-hyphen.2", @"0.23.0-beta-with-hyphen.10") == NSOrderedAscending);
        assert(!SGVersionParts(@"garbage") && !SGVersionParts(@"0.23.0-beta..1"));
        assert(!SGVersionAllowed(@"0.24.0-beta.1", NO, @"0.23.0"));
        assert(!SGVersionAllowed(@"0.24.0", YES, @"0.23.0"));
        assert(SGVersionAllowed(@"0.24.0-beta.1", YES, @"0.23.0-beta.1"));
        assert(SGVersionAllowed(@"0.23.0", NO, @"0.23.0-beta.1"));
        assert(!SGVersionAllowed(@"garbage", NO, @"0.23.0-beta.1"));
        puts("release version and channel checks passed");
    }
}
