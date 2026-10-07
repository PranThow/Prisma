#import "Shared/AnimatedArtwork/AppleMusicArtwork.h"
#include <assert.h>
extern void SGAppleArtworkNetworkChecks(void);

static NSDictionary *album(NSString *artist, NSString *name) {
    return @{ @"attributes":@{ @"artistName":artist,@"name":name } };
}
static NSURL *parse(NSString *text, BOOL master, BOOL valid) {
    NSURL *base = [NSURL URLWithString:@"https://mvod.itunes.apple.com/art/master.m3u8"];
    BOOL isMaster = NO; NSError *error = nil;
    NSURL *url = SGAppleArtworkPlaylistURL(text,base,.75,&isMaster,&error);
    assert(isMaster == master);
    assert((url != nil) == valid);
    assert(valid ? !error : error != nil);
    return url;
}
int main(void) {
    @autoreleasepool {
        assert([SGAppleArtworkNormalize(@"  BEYONCÉ　& Jay–Z  ") isEqual:@"beyonce and jay z"]);
        assert([SGAppleArtworkNormalize(@"Don’t") isEqual:SGAppleArtworkNormalize(@"Don't")]);
        assert(!SGAppleArtworkNormalize(NSNull.null).length);
        assert(SGAppleArtworkArtistsMatch(@"Artist A feat. Artist B", @"Artist B & Artist A"));
        assert(SGAppleArtworkArtistsMatch(@"Beyoncé & Jay-Z", @"Jay-Z and BEYONCE"));
        assert(!SGAppleArtworkArtistsMatch(@"Artist A & Artist B", @"Artist A"));
        assert(!SGAppleArtworkArtistsMatch(@"Artist A & Artist B", @"Artist A & Artist C"));
        assert(!SGAppleArtworkArtistsMatch(@"Artist A & Artist A", @"Artist A & Artist B"));
        assert(!SGAppleArtworkArtistsMatch(@"Artist A Tribute", @"Artist A"));
        NSDictionary *standard = album(@"Beyoncé",@"Renaissance");
        NSDictionary *deluxe = album(@"Beyoncé",@"Renaissance (Deluxe Edition)");
        NSDictionary *live = album(@"Beyoncé",@"Renaissance (Live)");
        NSDictionary *other = album(@"Beyoncé Tribute",@"Renaissance");
        NSArray *rows = @[other,live,deluxe,standard];
        assert([SGAppleArtworkMatches(rows,@"BEYONCE",@"RENAISSANCE") isEqual:@[standard]]);
        assert([SGAppleArtworkMatches(rows,@"Beyoncé",@"Renaissance (Deluxe Edition)") isEqual:@[deluxe]]);
        assert([SGAppleArtworkMatches(@[live,deluxe],@"Beyonce",@"Renaissance") isEqual:@[deluxe]]);
        assert(!SGAppleArtworkMatches(@[live,other],@"Beyonce",@"Renaissance").count);
        assert(!SGAppleArtworkMatches(rows,@"",@"Renaissance").count);
        assert(!SGAppleArtworkMatches(@[album(@"Taylor Swift",@"1989 (Taylor's Version)")],@"Taylor Swift",@"1989").count);
        NSDictionary *single = album(@"Artist",@"Name - Single");
        assert([SGAppleArtworkMatches(@[single],@"Artist",@"Name") isEqual:@[single]]);
        assert(!SGAppleArtworkMatches(@[NSNull.null,@{ @"attributes":@42 }],@"Artist",@"Name").count);

        NSString *tall = @"https://mvod.itunes.apple.com/tall.m3u8";
        NSString *square = @"https://mvod.itunes.apple.com/square.m3u8";
        NSDictionary *motion = @{ @"editorialVideo":@{
            @"motionDetailTall":@{ @"video":tall }, @"motionDetailSquare":@{ @"video":square } } };
        assert([SGAppleArtworkMotionURL(motion,.75).absoluteString isEqual:tall]);
        assert([SGAppleArtworkMotionURL(motion,1).absoluteString isEqual:square]);
        assert([SGAppleArtworkMotionURL(@{ @"editorialVideo":@{ @"motionDetailSquare":@{ @"video":square } } },.75).absoluteString isEqual:square]);
        for (NSString *bad in @[@"http://mvod.itunes.apple.com/a",@"https://mvod.itunes.apple.com.evil.org/a",
                               @"https://user:pass@mvod.itunes.apple.com/a",@"https://mvod.itunes.apple.com:444/a",
                               @"https://mvod.itunes.apple.com/a#fragment"]) assert(!SGAppleArtworkURLValid([NSURL URLWithString:bad]));

        NSString *master = @"#EXTM3U\n#EXT-X-VERSION:7\n"
            "#EXT-X-STREAM-INF:BANDWIDTH=10,CODECS=\"hvc1.2\",RESOLUTION=900x1200\nhevc.m3u8\n"
            "#EXT-X-STREAM-INF:BANDWIDTH=20,CODECS=\"avc1.64001f\",RESOLUTION=960x960\nsquare.m3u8\n"
            "#EXT-X-STREAM-INF:BANDWIDTH=30,CODECS=\"avc1.64001f\",RESOLUTION=600x800,VIDEO-RANGE=SDR\ntall.m3u8\n"
            "#EXT-X-STREAM-INF:BANDWIDTH=40,CODECS=\"avc1.64001f\",RESOLUTION=900x1200\nbetter.m3u8\n";
        assert([parse(master,YES,YES).lastPathComponent isEqual:@"better.m3u8"]);
        BOOL squareMaster = NO;
        NSError *squareError = nil;
        NSURL *squareVariant = SGAppleArtworkPlaylistURL(master,[NSURL URLWithString:@"https://mvod.itunes.apple.com/art/master.m3u8"],1,&squareMaster,&squareError);
        assert(squareMaster && !squareError && [squareVariant.lastPathComponent isEqual:@"square.m3u8"]);
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"hvc1.2\",RESOLUTION=600x800\na.m3u8",YES,NO);
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"hvc1.2.4.L120.B0\",RESOLUTION=600x800,VIDEO-RANGE=SDR\na.m3u8",YES,SGAppleArtworkHEVCSupported());
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"hev1.1.6.L120.B0\",RESOLUTION=600x800\na.m3u8",YES,SGAppleArtworkHEVCSupported());
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"hvc1.2.4.L120.B0\",RESOLUTION=600x800,VIDEO-RANGE=PQ\na.m3u8",YES,NO);
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"avc1.64001f\",RESOLUTION=600x800,AUDIO=\"audio\"\na.m3u8",YES,NO);
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"avc1.64001f\",RESOLUTION=600x800",YES,NO);
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"avc1.64001f,RESOLUTION=600x800\na.m3u8",YES,NO);
        parse(@"#EXTM3U\n#EXT-X-STREAM-INF:CODECS=\"avc1.64001f\",RESOLUTION=600x800\nhttps://example.com/a.m3u8",YES,NO);
        NSString *media = @"#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXT-X-VERSION:7\n#EXT-X-PLAYLIST-TYPE:VOD\n"
            "#EXT-X-MAP:URI=\"clip.mp4\",BYTERANGE=\"877@0\"\n"
            "#EXTINF:5.43333,\n#EXT-X-BYTERANGE:1404025@877\nclip.mp4\n"
            "#EXTINF:2.73333,\n#EXT-X-BYTERANGE:758561@1404902\nclip.mp4\n#EXT-X-ENDLIST\n";
        assert([parse(media,NO,YES).absoluteString isEqual:@"https://mvod.itunes.apple.com/art/clip.mp4"]);
        parse([media stringByReplacingOccurrencesOfString:@"758561@1404902" withString:@"758561"],NO,YES);
        parse([media stringByReplacingOccurrencesOfString:@"758561@1404902" withString:@"758561@1404903"],NO,NO);
        parse([media stringByReplacingOccurrencesOfString:@"877@0" withString:@"877@1"],NO,NO);
        parse([media stringByReplacingOccurrencesOfString:@"#EXT-X-ENDLIST" withString:@""],NO,NO);
        parse([media stringByReplacingOccurrencesOfString:@"2.73333" withString:@"60"],NO,NO);
        parse([media stringByReplacingOccurrencesOfString:@"5.43333" withString:@"bad"],NO,NO);
        parse([media stringByReplacingOccurrencesOfString:@"1404025@877" withString:@"999999999@877"],NO,NO);
        for (NSString *tag in @[@"#EXT-X-KEY:METHOD=AES-128,URI=\"key\"",@"#EXT-X-DISCONTINUITY",
                               @"#EXT-X-PART:DURATION=1,URI=\"a.mp4\"",@"#EXT-X-MEDIA:TYPE=AUDIO",
                               @"#EXT-X-DEFINE:NAME=\"x\",VALUE=\"y\"",@"#EXT-X-UNKNOWN:1"]) {
            parse([media stringByReplacingOccurrencesOfString:@"#EXT-X-VERSION:7" withString:tag],NO,NO);
        }
        parse(@"#EXTM3U\n#EXTINF:4,\nclip.mp4\n#EXT-X-ENDLIST",NO,YES);
        parse(@"#EXTM3U\n#EXTINF:4,\na.mp4\n#EXTINF:4,\nb.mp4\n#EXT-X-ENDLIST",NO,NO);
        parse(@"#EXTM3U\n#EXTINF:4,\na.ts\n#EXT-X-ENDLIST",NO,NO);
        parse(@"#EXTM3U\n#EXTINF:4,\n#EXT-X-BYTERANGE:100@0\na.mp4\n#EXT-X-ENDLIST",NO,NO);
        parse(@"garbage",NO,NO);
        NSLog(@"Apple artwork matching and playlist checks passed");
        SGAppleArtworkNetworkChecks();
    }
    return 0;
}
