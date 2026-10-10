"""Source-backed parser/serialization assertions; runs the actual Objective-C functions on macOS.
Windows can prepare/check the source extraction; it cannot execute Apple's frameworks.
"""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'tweak/Sources'
OUT = Path(__file__).resolve().parent / 'build'
OUT.mkdir(exist_ok=True)
(OUT / 'UIKit').mkdir(exist_ok=True)
(OUT / 'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\n', encoding='utf-8')
provider = (SRC / 'Shared/LyricsSources/SpicyLyrics.m').read_text(encoding='utf-8')
parser = provider[provider.index('static BOOL token'):provider.index('@interface SGSpicyRequest')]
sources = (SRC / 'Shared/LyricsSources/LyricsSources.m').read_text(encoding='utf-8')
lock_screen = (SRC / 'Shared/LockScreenLyrics/LockScreenLyrics.x').read_text(encoding='utf-8')
live_activity = (SRC / 'Shared/LiveActivity/LiveActivity.x').read_text(encoding='utf-8')
assert 'if (!token(key, @"sl_pk_", 512)' in provider
assert 'if (status == 401 || status == 403)' in provider
assert 'response.expectedContentLength > 2 * 1024 * 1024' in provider
assert 'self.body.length + data.length > 2 * 1024 * 1024' in provider
assert 'willPerformHTTPRedirection' in provider and 'handler(nil)' in provider
assert 'if (![key isEqualToString:[NSUserDefaults.standardUserDefaults stringForKey:kKey]])' in provider
assert 'status == 429 || status >= 500' in provider
assert 'MIN(10 * pow(2, sg_losses - 1), 600)' in provider
assert 'response.allHeaderFields[@"Retry-After"]' in provider
assert 'configuration.URLCache = nil' in provider
assert 'if (sg_kept.count >= kKeptTracks)' in sources
assert '-[sg_keptAt[trackID] timeIntervalSinceNow] >= 86400' in sources
lines = sources[sources.index('static const NSInteger kBreakMs'):sources.index('#pragma mark - which sources')]
hook = (SRC / 'Shared/LyricsSources/LyricsHook.x').read_text(encoding='utf-8')
page = hook[hook.index('static NSData *defaultColours'):hook.index('static NSString *timingName')]
assert 'previous = MAX(previous, start)' in page
assert 'SGKeyExternalLyricsReplacement' in sources
assert 'return !SGFlag(SGKeyExternalLyricsReplacement, NO) && SGLyricsOrder().count > 0;' in sources
assert 'dispatch_once(&once, ^{ on = SGLyricsEnabled(); });' in sources
assert 'SGLyricsProviderFor(key) && ![order containsObject:key]' in sources
assert 'walk.order = SGLyricsOrder();' in sources
assert 'SGLyricsProviderFor(walk.order[walk.index++])' in sources
assert 'merged.attribution = fresh.attribution;' in sources
assert 'sg_attribution[trackID] = lyrics.attribution;' in sources
assert 'return sg_attribution[trackID] ?: SGKaraokeLinesForTrack(trackID).firstObject.sourceAttribution;' in sources
assert 'if (SGLyricsAttributionFor(trackID)) return nil;' in lock_screen
assert 'if (SGLyricsAttributionFor(trackID)) { *next = @""; return @"♪"; }' in live_activity
assert 'if (!SGLyricsEnabled()) return;' in hook
karaoke = (SRC / 'Shared/Lyrics/KaraokeSource.x').read_text(encoding='utf-8')
assert 'SGAddPlayerStateObserver(sg_stateObserver)' in karaoke
assert 'UIApplicationDidBecomeActiveNotification' in karaoke
assert 'SGSpotifyAuthorizationDidChange' in karaoke
clutter_source = (SRC / 'Shared/Privacy/Clutter.m').read_text(encoding='utf-8')
clutter = clutter_source[clutter_source.index('static NSString *const socialProofFlags'):].replace('__attribute__((constructor)) ', '')
prefix = '''#import <Foundation/Foundation.h>
#import <assert.h>
#import <math.h>
#import "Shared/LyricsSources/LyricsSources.h"
#import "Shared/Lyrics/Protobuf.h"
#import "Shared/Privacy/Privacy.h"
#import "Core/SGFlagForce.h"
static BOOL hideVideos, hideSocial;
static SGFlagForcer launchForcer, lockedForcer;
BOOL SGHidden(NSString *key) { return [key isEqual:SGKeyHideSearchVideos] ? hideVideos : hideSocial; }
void SGRegisterFlagForcer(BOOL priority, SGFlagForcer launch, SGFlagForcer locked) { launchForcer = [launch copy]; lockedForcer = [locked copy]; }
NSString *const NSLinkAttributeName = @"NSLink";
@implementation SGLyricsResult
@end
static NSString *const kUnnamedProvider = @"Prisma";
'''
# NSLinkAttributeName is declared by UIKit normally, but this pure parser check uses Foundation only.
tests = '''
int main(void) { @autoreleasepool {
    NSString *videoFlag = @"ios-feature-search.video_carousel_section_enabled";
    NSString *socialFlag = @"ios-feature-search.social_proof_playlist_enabled";
    hideVideos = YES; hideSocial = NO; registerForcer();
    assert([launchForcer(videoFlag) isEqual:@NO] && !launchForcer(socialFlag));
    hideVideos = NO; hideSocial = YES;
    assert([launchForcer(videoFlag) isEqual:@NO] && !launchForcer(socialFlag));
    assert(!lockedForcer(videoFlag) && [lockedForcer(socialFlag) isEqual:@NO]);
    NSString *track = @"1234567890123456789012";
    NSMutableDictionary *lead = [@{@"StartTime": @1, @"EndTime": @2, @"Syllables": @[
        @{@"Text": @"Hel", @"StartTime": @1, @"EndTime": @1.5, @"IsPartOfWord": @YES},
        @{@"Text": @"lo", @"StartTime": @1.5, @"EndTime": @2, @"IsPartOfWord": @NO}
    ]} mutableCopy];
    NSMutableDictionary *body = [@{@"id": track, @"Type": @"Syllable", @"source": @"spicy_lyrics",
        @"Content": @[@{@"Type": @"Vocal", @"Lead": lead}],
        @"UploadAttribution": @{@"Uploader": @{@"username": @"artist", @"url": @"https://spicylyrics.org/uid/123"}}} mutableCopy];
    NSDictionary *root = @{@"Body": body};
    SGLyricsResult *result = SGSpicyLyricsParse(root, track);
    assert(result.synced && result.wordTimed && result.karaokeLines.count == 1);
    assert([SGKaraokeLineText(result.karaokeLines.firstObject) isEqual:@"Hello"]);
    assert(result.karaokeLines.firstObject.start == 1000 && result.karaokeLines.firstObject.end == 2000);
    assert([result.attribution.string containsString:@"Uploader: artist"]);
    assert(!SGSpicyLyricsParse(root, @"2234567890123456789012"));
    lead[@"EndTime"] = @0.5; assert(!SGSpicyLyricsParse(root, track)); lead[@"EndTime"] = @2;
    body[@"UploadAttribution"] = @{}; assert(!SGSpicyLyricsParse(root, track));
    body[@"source"] = @"apple_music"; result = SGSpicyLyricsParse(root, track);
    assert([result.attribution.string isEqual:@"Apple Music"]);
    body[@"Type"] = @"Unknown"; assert(!SGSpicyLyricsParse(root, track));
    SGLyricsResult *page = [SGLyricsResult new]; page.synced = YES;
    page.starts = @[@1000, @1000, @900, @1200, @-5]; page.texts = @[@"a", @"b", @"c", @"d", @"e"];
    NSArray *fields = SGPBParse(SGPBFirst(SGPBParse(pageBody(page, nil)), 1).payload);
    NSArray *expected = @[@1000, @1000, @1000, @1200, @1200]; NSUInteger index = 0;
    for (SGPBField *field in fields) if (field.number == 2) {
        assert(SGPBFirst(SGPBParse(field.payload), 1).varint == [expected[index++] unsignedLongLongValue]);
    }
    assert(index == 5); puts("Spicy payload validation, attribution, timing and nondecreasing serialization passed");
} }
'''
main = OUT / 'main.m'
main.write_text(prefix + lines + parser + page + clutter + tests, encoding='utf-8')
if sys.platform != 'darwin':
    print('Spicy request lifecycle, source extraction and compatibility guards passed; Objective-C runtime checks require macOS.')
    sys.exit(0)
executable = OUT / 'check'
subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-I', str(OUT), '-I', str(SRC),
    '-framework', 'Foundation', str(main), str(SRC / 'Shared/Lyrics/KaraokeTiming.m'),
    str(SRC / 'Shared/Lyrics/Protobuf.m'), '-o', str(executable)], check=True)
subprocess.run([str(executable)], check=True)
