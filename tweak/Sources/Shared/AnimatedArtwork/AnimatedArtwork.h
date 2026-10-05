// Shared lock-screen artwork preferences. Provider identifiers are persisted, never display names.
#import <Foundation/Foundation.h>

#define SGKeyAnimatedArtwork @"spotifyglass.animatedArtwork"
#define SGKeyAnimatedArtworkProviders @"spotifyglass.animatedArtworkProviders"

NSArray<NSString *> *SGAnimatedArtworkAllProviders(void);
NSArray<NSString *> *SGAnimatedArtworkOrder(void);
void SGAnimatedArtworkSetOrder(id keys);
BOOL SGAnimatedArtworkEnabled(void);
