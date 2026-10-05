// Captured from Spotify's existing URLSession delegates. Main queue only; never persisted.
#import <Foundation/Foundation.h>

extern NSString *const SGSpotifyAuthorizationDidChange;
BOOL SGSpotifyServiceURL(NSURL *url);
// Returns nil for any destination outside Spotify's HTTPS spclient service.
NSDictionary<NSString *, NSString *> *SGSpotifyHeadersForURL(NSURL *url);
