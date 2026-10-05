// The line being sung in place of the artist in the system's now playing: lock screen, Dynamic Island,
// Control Center, CarPlay. There is a Live Activity for it too (Shared/LiveActivity). The
// lines and the clock come from Karaoke.
#import <Foundation/Foundation.h>

#define SGKeyLockScreenLyrics @"spotifyglass.lockScreenLyrics"

// Main queue: refresh through the lyrics hook's original metadata and clock, if active.
BOOL SGRefreshLockScreenLyrics(void);
BOOL SGLockScreenLyricsIsRepublishing(void);
