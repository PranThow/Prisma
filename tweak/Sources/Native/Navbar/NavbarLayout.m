// The saved composition of the bar, as NSUserDefaults property lists.
#import "Navbar.h"

NSString *const SGNavbarID = @"id";
NSString *const SGNavbarTitle = @"title";
NSString *const SGNavbarURI = @"uri";
NSString *const SGNavbarIcon = @"icon";
NSString *const SGNavbarHidden = @"hidden";

static NSString *const kNavbarLayout = @"spotifyglass.navbar.layout";
static NSString *const kNavbarStock = @"spotifyglass.navbar.stock";

static NSArray *sg_layoutCache, *sg_stockCache;

// Only property list types go in, so a corrupt read cannot be anything but an array of dictionaries.
static NSArray *listOfKind(NSString *key, Class kind) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    for (id item in list) if (![item isKindOfClass:kind]) return @[];
    return list ?: @[];
}

NSArray<NSDictionary *> *SGNavbarLayout(void) {
    if (!sg_layoutCache) sg_layoutCache = [listOfKind(kNavbarLayout, NSDictionary.class) copy];
    return sg_layoutCache;
}

void SGSetNavbarLayout(NSArray<NSDictionary *> *layout) {
    sg_layoutCache = [layout ?: @[] copy];
    [NSUserDefaults.standardUserDefaults setObject:sg_layoutCache forKey:kNavbarLayout];
}

NSArray<NSString *> *SGNavbarStock(void) {
    if (!sg_stockCache) sg_stockCache = [listOfKind(kNavbarStock, NSString.class) copy];
    return sg_stockCache;
}

void SGSetNavbarStock(NSArray<NSString *> *stock) {
    sg_stockCache = [stock ?: @[] copy];
    [NSUserDefaults.standardUserDefaults setObject:sg_stockCache forKey:kNavbarStock];
}
