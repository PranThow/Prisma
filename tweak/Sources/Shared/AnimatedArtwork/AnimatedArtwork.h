// Shared lock-screen artwork preferences. Provider identifiers are persisted, never display names.
#import <Foundation/Foundation.h>

#define SGKeyAnimatedArtwork @"spotifyglass.animatedArtwork"
#define SGKeyAnimatedArtworkProviders @"spotifyglass.animatedArtworkProviders"

NSArray<NSString *> *SGAnimatedArtworkAllProviders(void);
NSArray<NSString *> *SGAnimatedArtworkOrder(void);
void SGAnimatedArtworkSetOrder(id keys);
BOOL SGAnimatedArtworkEnabled(void);
NSString *SGAnimatedArtworkPreferredKey(NSArray *supported, NSString *tall, NSString *square);
NSDictionary *SGAnimatedArtworkInfo(NSDictionary *info, NSString *tall, NSString *square,
                                   NSString *key, id artwork);
