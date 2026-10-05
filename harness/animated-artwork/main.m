// macOS: sh harness/animated-artwork/check.sh
#import <Foundation/Foundation.h>
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        assert([SGAnimatedArtworkPreferredKey(@[@"square", @"tall"], @"tall", @"square") isEqual:@"tall"]);
        assert([SGAnimatedArtworkPreferredKey(@[@"square"], @"tall", @"square") isEqual:@"square"]);
        assert(!SGAnimatedArtworkPreferredKey(@[@"unknown"], @"tall", @"square"));
        NSDictionary *base = @{@"title": @"song", @"artist": @"lyric", @"elapsed": @42,
                               @"rate": @0.5, @"static": @"cover", @"tall": @"old", @"square": @"old"};
        NSDictionary *shown = SGAnimatedArtworkInfo(base, @"tall", @"square", @"square", @"new");
        assert(!shown[@"tall"] && [shown[@"square"] isEqual:@"new"]);
        for (NSString *key in @[@"title", @"artist", @"elapsed", @"rate", @"static"])
            assert([shown[key] isEqual:base[key]]);
        NSDictionary *cleared = SGAnimatedArtworkInfo(shown, @"tall", @"square", nil, nil);
        assert(!cleared[@"tall"] && !cleared[@"square"]);
        assert([base[@"tall"] isEqual:@"old"]); // Never mutate Spotify's dictionary.
        assert(!SGAnimatedArtworkInfo(nil, @"tall", @"square", @"tall", @"new"));
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        // Volatile arguments isolate the check from the user's persisted preferences.
        [store setVolatileDomain:@{} forName:NSArgumentDomain];
        assert([SGAnimatedArtworkOrder() isEqual:SGAnimatedArtworkAllProviders()]);
        assert(!SGAnimatedArtworkEnabled());
        for (id value in @[@"bad", @42, @{}, @YES]) {
            [store setVolatileDomain:@{SGKeyAnimatedArtworkProviders: value} forName:NSArgumentDomain];
            assert([SGAnimatedArtworkOrder() isEqual:SGAnimatedArtworkAllProviders()]);
        }
        [store setVolatileDomain:@{SGKeyAnimatedArtworkProviders: @[@"appleMusic", @"unknown", @42, @"appleMusic", @"spotify"]} forName:NSArgumentDomain];
        assert([SGAnimatedArtworkOrder() isEqual:(@[@"appleMusic", @"spotify"])]);
        [store setVolatileDomain:@{SGKeyAnimatedArtworkProviders: @[]} forName:NSArgumentDomain];
        assert(SGAnimatedArtworkOrder().count == 0);
        [store setVolatileDomain:@{SGKeyAnimatedArtworkProviders: @[@"unknown"]} forName:NSArgumentDomain];
        assert(SGAnimatedArtworkOrder().count == 0);
        for (id value in @[@"YES", @[], @{}, @2, @(-1), @0.5, @NO]) {
            [store setVolatileDomain:@{SGKeyAnimatedArtwork: value} forName:NSArgumentDomain];
            assert(!SGAnimatedArtworkEnabled());
        }
        [store setVolatileDomain:@{SGKeyAnimatedArtwork: @YES} forName:NSArgumentDomain];
        assert(SGAnimatedArtworkEnabled());
        // Exercise the real setter in this command-line harness's preferences domain.
        [store removeVolatileDomainForName:NSArgumentDomain];
        id previous = [store objectForKey:SGKeyAnimatedArtworkProviders];
        SGAnimatedArtworkSetOrder(@[@"spotify", @"unknown", @"spotify", @"appleMusic"]);
        assert([SGAnimatedArtworkOrder() isEqual:SGAnimatedArtworkAllProviders()]);
        SGAnimatedArtworkSetOrder(@[]);
        assert(SGAnimatedArtworkOrder().count == 0);
        SGAnimatedArtworkSetOrder(@"bad");
        assert([SGAnimatedArtworkOrder() isEqual:SGAnimatedArtworkAllProviders()]);
        if (previous) [store setObject:previous forKey:SGKeyAnimatedArtworkProviders];
        else [store removeObjectForKey:SGKeyAnimatedArtworkProviders];
        puts("animated artwork preferences: passed");
    }
}
