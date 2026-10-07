// The saved composition of the redesign's bar, as NSUserDefaults property lists, apart from the native look's.
#import "Navbar.h"
#import "Shared/Navigation/Links.h"

NSString *const SGRNavbarID = @"id";
NSString *const SGRNavbarTitle = @"title";
NSString *const SGRNavbarURI = @"uri";
NSString *const SGRNavbarIcon = @"icon";
NSString *const SGRNavbarHidden = @"hidden";

static NSString *const kNavbarLayout = @"spotifyglass.redesign.navbar.layout";
static NSString *const kNavbarStock = @"spotifyglass.redesign.navbar.stock";

static NSArray *sg_layoutCache, *sg_stockCache;

// Only property list types go in, so a corrupt read cannot be anything but an array of dictionaries.
static NSArray *listOfKind(NSString *key, Class kind) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    for (id item in list) if (![item isKindOfClass:kind]) return @[];
    return list ?: @[];
}

NSArray<NSDictionary *> *SGRNavbarLayout(void) {
    if (!sg_layoutCache) sg_layoutCache = [listOfKind(kNavbarLayout, NSDictionary.class) copy];
    return sg_layoutCache;
}

void SGRSetNavbarLayout(NSArray<NSDictionary *> *layout) {
    sg_layoutCache = [layout ?: @[] copy];
    [NSUserDefaults.standardUserDefaults setObject:sg_layoutCache forKey:kNavbarLayout];
}

NSArray<NSString *> *SGRNavbarStock(void) {
    if (!sg_stockCache) sg_stockCache = [listOfKind(kNavbarStock, NSString.class) copy];
    return sg_stockCache;
}

void SGRSetNavbarStock(NSArray<NSString *> *stock) {
    sg_stockCache = [stock ?: @[] copy];
    [NSUserDefaults.standardUserDefaults setObject:sg_stockCache forKey:kNavbarStock];
}

NSURL *SGRNavbarTabURL(NSString *uri) {
    NSURL *url = SGSpotifyURIFromText(uri);
    if ([url.absoluteString isEqualToString:@"spotify:collection:playlists"]) return [NSURL URLWithString:@"spotify:playlists"];
    return url;
}
