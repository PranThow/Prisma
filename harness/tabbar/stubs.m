// What the harness does not compile: the accent hook (SGRAccent.x), the repaint hook (SGRRepaint.x), the
// tab bar's composition (Navbar.x) and Mod Settings. Spotify's order of tabs stays as the mock has it.
#import <UIKit/UIKit.h>

UIColor *SGRAccentColor(void) { return nil; }
__weak UIView *sgr_nowPlayingRoot = nil;
__weak UIView *sgr_nowPlayingCard = nil;
__weak UIView *sgr_lyricsPageRoot = nil;
__weak UIView *sgr_playlistRoot = nil;
__weak UIView *sgr_albumRoot = nil;
__weak UIView *sgr_artistRoot = nil;

void SGRComposeTabBar(UIView *tabBar) {}
void SGRLogTabBarRow(UIView *tabBar) {}
void SGOpenModSettings(UIView *source) {}

#import "Shared/Player/PlayerState.h"
BOOL SGRNavbarCustomSelected(UIView *item) { return NO; }
void SGRNavbarSelectItem(UIView *item) {}
void SGAddPlayerStateObserver(id<SGPlayerStateObserver> observer) {}
SPTPlayerState *SGPlayerState(void) { return nil; }
NSString *SGURIString(id uri) { return [uri isKindOfClass:NSString.class] ? uri : nil; }
id SGKaraokePlayer(void) { return nil; }
NSNotificationName const SGRNowPlayingArtworkDidChangeNotification = @"harness.artwork";
UIImage *SGRNowPlayingArtwork(NSString **uri, NSString **identity) { if (uri) *uri = nil; return nil; }

NSURL *SGSpotifyURIFromText(NSString *text) { return [NSURL URLWithString:text]; }
