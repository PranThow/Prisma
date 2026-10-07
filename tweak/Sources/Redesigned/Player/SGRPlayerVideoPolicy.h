#import <Foundation/Foundation.h>
static inline NSArray<NSString *> *SGRPlayerNormalizeVideoOrder(id stored) {
    if (![stored isKindOfClass:NSArray.class]) return @[@"spotify", @"apple"];
    NSMutableArray *order = [NSMutableArray new];
    for (id key in stored)
        if ([@[@"spotify", @"apple"] containsObject:key] && ![order containsObject:key]) [order addObject:key];
    return order;
}
static inline BOOL SGRPlayerCanvasCanImprove(NSArray *order, NSString *currentProvider) {
    NSUInteger spotify = [order indexOfObject:@"spotify"];
    NSUInteger current = currentProvider ? [order indexOfObject:currentProvider] : NSNotFound;
    return spotify != NSNotFound && (current == NSNotFound || spotify < current);
}
