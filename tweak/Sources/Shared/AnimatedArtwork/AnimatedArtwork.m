#import "AnimatedArtwork.h"

NSArray<NSString *> *SGAnimatedArtworkAllProviders(void) {
    return @[@"spotify", @"appleMusic"];
}

static NSArray<NSString *> *validatedOrder(id keys) {
    if (![keys isKindOfClass:NSArray.class]) return SGAnimatedArtworkAllProviders();
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id key in keys) {
        if ([key isKindOfClass:NSString.class] && [SGAnimatedArtworkAllProviders() containsObject:key] &&
            ![order containsObject:key]) [order addObject:key];
    }
    return [order copy]; // An empty array deliberately disables every provider.
}

NSArray<NSString *> *SGAnimatedArtworkOrder(void) {
    return validatedOrder([NSUserDefaults.standardUserDefaults objectForKey:SGKeyAnimatedArtworkProviders]);
}

void SGAnimatedArtworkSetOrder(id keys) {
    [NSUserDefaults.standardUserDefaults setObject:validatedOrder(keys) forKey:SGKeyAnimatedArtworkProviders];
}

BOOL SGAnimatedArtworkEnabled(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:SGKeyAnimatedArtwork];
    return [value isKindOfClass:NSNumber.class] &&
        ([value isEqual:@YES] || [value isEqual:@NO]) && [value boolValue];
}
