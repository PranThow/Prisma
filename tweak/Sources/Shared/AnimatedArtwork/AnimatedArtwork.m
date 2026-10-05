#import "AnimatedArtwork.h"

NSString *SGAnimatedArtworkPreferredKey(NSArray *supported, NSString *tall, NSString *square) {
    return [supported containsObject:tall] ? tall : ([supported containsObject:square] ? square : nil);
}

NSDictionary *SGAnimatedArtworkInfo(NSDictionary *info, NSString *tall, NSString *square,
                                   NSString *key, id artwork) {
    if (!info) return nil;
    NSMutableDictionary *shown = [info mutableCopy];
    [shown removeObjectForKey:tall];
    [shown removeObjectForKey:square];
    if (key && artwork) shown[key] = artwork;
    return shown;
}

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
