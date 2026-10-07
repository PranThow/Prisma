// Numeric release components and SemVer prerelease precedence; build metadata has no precedence.
#import <Foundation/Foundation.h>

static inline NSArray<NSString *> *SGVersionParts(NSString *version) {
    if (![version isKindOfClass:NSString.class]) return nil;
    static NSRegularExpression *syntax;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        syntax = [NSRegularExpression regularExpressionWithPattern:
            @"^[0-9]+(?:\\.[0-9]+){0,2}(?:-[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$"
            options:0 error:NULL];
    });
    NSTextCheckingResult *match = [syntax firstMatchInString:version options:0 range:NSMakeRange(0, version.length)];
    if (!match || !NSEqualRanges(match.range, NSMakeRange(0, version.length))) return nil;
    return [[version componentsSeparatedByString:@"+"].firstObject componentsSeparatedByString:@"-"];
}

static inline BOOL SGVersionNumeric(NSString *part) {
    return part.length && [part rangeOfCharacterFromSet:
        [NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet].location == NSNotFound;
}

static inline NSComparisonResult SGVersionNumberCompare(NSString *a, NSString *b) {
    while (a.length > 1 && [a hasPrefix:@"0"]) a = [a substringFromIndex:1];
    while (b.length > 1 && [b hasPrefix:@"0"]) b = [b substringFromIndex:1];
    if (a.length != b.length) return a.length > b.length ? NSOrderedDescending : NSOrderedAscending;
    return [a compare:b options:NSLiteralSearch];
}

static inline BOOL SGVersionPrerelease(NSString *version) {
    return SGVersionParts(version).count > 1;
}

static inline NSComparisonResult SGVersionCompare(NSString *a, NSString *b) {
    NSArray *left = SGVersionParts(a), *right = SGVersionParts(b);
    if (!left || !right) return NSOrderedSame;
    NSArray *lc = [left[0] componentsSeparatedByString:@"."], *rc = [right[0] componentsSeparatedByString:@"."];
    for (NSUInteger i = 0; i < MAX(lc.count, rc.count); i++) {
        NSComparisonResult result = SGVersionNumberCompare(i < lc.count ? lc[i] : @"0", i < rc.count ? rc[i] : @"0");
        if (result != NSOrderedSame) return result;
    }
    if (left.count == 1 || right.count == 1) {
        if (left.count == right.count) return NSOrderedSame;
        return left.count == 1 ? NSOrderedDescending : NSOrderedAscending;
    }
    // A prerelease identifier may itself contain a hyphen.
    NSString *lp = [[left subarrayWithRange:NSMakeRange(1, left.count - 1)] componentsJoinedByString:@"-"];
    NSString *rp = [[right subarrayWithRange:NSMakeRange(1, right.count - 1)] componentsJoinedByString:@"-"];
    NSArray *li = [lp componentsSeparatedByString:@"."], *ri = [rp componentsSeparatedByString:@"."];
    for (NSUInteger i = 0; i < MIN(li.count, ri.count); i++) {
        BOOL ln = SGVersionNumeric(li[i]), rn = SGVersionNumeric(ri[i]);
        NSComparisonResult result = ln && rn ? SGVersionNumberCompare(li[i], ri[i]) :
            ln != rn ? (ln ? NSOrderedAscending : NSOrderedDescending) : [li[i] compare:ri[i] options:NSLiteralSearch];
        if (result != NSOrderedSame) return result;
    }
    return li.count == ri.count ? NSOrderedSame : li.count > ri.count ? NSOrderedDescending : NSOrderedAscending;
}

static inline BOOL SGVersionAllowed(NSString *version, BOOL flaggedPrerelease, NSString *build) {
    return SGVersionParts(version) && (SGVersionPrerelease(build) || (!flaggedPrerelease && !SGVersionPrerelease(version)));
}
