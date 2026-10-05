#import <Foundation/Foundation.h>

// Optional caller-owned Apple developer JWT. No signing key or Music User Token is needed here.
#define SGKeyAppleMusicDeveloperToken @"spotifyglass.appleMusicDeveloperToken"

// Main queue API; replacement/cancellation suppresses stale completions.
@interface SGAppleMusicArtworkResolver : NSObject
- (void)resolveArtist:(NSString *)artist album:(NSString *)album aspectRatio:(double)ratio
           completion:(void (^)(NSURL *clip, NSError *error))completion;
- (void)cancel;
@end

// Foundation-only functions exercised by harness/apple-music-artwork.
NSString *SGAppleArtworkNormalize(id name);
NSArray<NSDictionary *> *SGAppleArtworkMatches(id albums, NSString *artist, NSString *album);
NSURL *SGAppleArtworkMotionURL(id attributes, double ratio);
BOOL SGAppleArtworkURLValid(NSURL *url);
// Master -> one supported variant; media -> one complete MP4 resource. Never returns a segment.
NSURL *SGAppleArtworkPlaylistURL(NSString *playlist, NSURL *base, double ratio,
                                BOOL *isMaster, NSError **error);
