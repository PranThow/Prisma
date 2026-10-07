#import "AppleMusicArtwork.h"
#import <math.h>
#import <VideoToolbox/VideoToolbox.h>

BOOL SGAppleArtworkHEVCSupported(void) { return VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC); }

static NSError *artworkError(NSString *message) {
    return [NSError errorWithDomain:@"Prisma.AppleMusicArtwork" code:1
                           userInfo:@{NSLocalizedDescriptionKey:message}];
}
NSString *SGAppleArtworkNormalize(id name) {
    if (![name isKindOfClass:NSString.class]) return @"";
    NSString *folded = [name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch
                                               locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]].lowercaseString;
    folded = [[folded stringByReplacingOccurrencesOfString:@"&" withString:@" and "]
        stringByReplacingOccurrencesOfString:@"’" withString:@"'"];
    folded = [folded stringByReplacingOccurrencesOfString:@"'" withString:@""];
    NSArray *words = [folded componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet];
    return [[words filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@" "];
}
static NSString *albumBase(NSString *name) {
    // Strip only known edition suffixes. Live, remixes, re-recordings and arbitrary subtitles stay.
    NSRegularExpression *suffix = [NSRegularExpression regularExpressionWithPattern:
        @"(?i)\\s*(?:[\\(\\[](?:deluxe(?: edition| version)?|expanded(?: edition)?|(?:\\d{4} )?remaster(?:ed)?(?: \\d{4})?(?: edition)?)[\\)\\]]| - (?:single|ep|deluxe(?: edition)?))$"
        options:0 error:nil];
    NSString *base = [suffix stringByReplacingMatchesInString:name ?: @"" options:0
        range:NSMakeRange(0,name.length) withTemplate:@""];
    return SGAppleArtworkNormalize(base);
}
static NSArray *artistCredits(NSString *name) {
    if (![name isKindOfClass:NSString.class]) return @[];
    NSRegularExpression *separator = [NSRegularExpression regularExpressionWithPattern:
        @"(?i)\\s+(?:feat\\.?|ft\\.?|featuring|with|and)\\s+|\\s*[&,]\\s*" options:0 error:nil];
    NSString *split = [separator stringByReplacingMatchesInString:name options:0 range:NSMakeRange(0, name.length) withTemplate:@"\n"];
    NSMutableArray *credits = [NSMutableArray new];
    for (NSString *part in [split componentsSeparatedByString:@"\n"]) {
        NSString *credit = SGAppleArtworkNormalize(part);
        if (!credit.length || [credits containsObject:credit]) return @[];
        [credits addObject:credit];
    }
    return [credits sortedArrayUsingSelector:@selector(compare:)];
}
BOOL SGAppleArtworkArtistsMatch(NSString *left, NSString *right) {
    NSString *a = SGAppleArtworkNormalize(left), *b = SGAppleArtworkNormalize(right);
    if (!a.length || !b.length) return NO;
    if ([a isEqual:b]) return YES;
    // Require every explicitly credited artist on both sides, never a lead-artist substring.
    NSArray *credits = artistCredits(left), *other = artistCredits(right);
    return credits.count > 1 && [credits isEqual:other];
}
NSArray<NSDictionary *> *SGAppleArtworkMatches(id albums, NSString *artist, NSString *album) {
    NSString *who = SGAppleArtworkNormalize(artist), *title = SGAppleArtworkNormalize(album);
    if (!who.length || !title.length) return @[];
    NSMutableArray *exact = [NSMutableArray new], *editions = [NSMutableArray new];
    for (id row in [albums isKindOfClass:NSArray.class] ? albums : @[]) {
        if (![row isKindOfClass:NSDictionary.class]) continue;
        id a = row[@"attributes"];
        if (![a isKindOfClass:NSDictionary.class] || ![a[@"name"] isKindOfClass:NSString.class] ||
            !SGAppleArtworkArtistsMatch(a[@"artistName"], artist)) continue;
        if ([SGAppleArtworkNormalize(a[@"name"]) isEqual:title]) [exact addObject:row];
        else if ([albumBase(a[@"name"]) isEqual:albumBase(album)]) [editions addObject:row];
    }
    // Never substitute another edition when the exact edition exists but has no motion artwork.
    return exact.count ? exact : editions;
}
BOOL SGAppleArtworkURLValid(NSURL *url) {
    NSString *host = url.host.lowercaseString;
    return [url.scheme.lowercaseString isEqual:@"https"] && !url.user && !url.password && !url.fragment &&
        (!url.port || url.port.integerValue == 443) &&
        ([host hasSuffix:@".itunes.apple.com"] || [host hasSuffix:@".mzstatic.com"]);
}
NSURL *SGAppleArtworkMotionURL(id attributes, double ratio) {
    if (![attributes isKindOfClass:NSDictionary.class] || !isfinite(ratio) || ratio <= 0) return nil;
    id videos = attributes[@"editorialVideo"];
    if (![videos isKindOfClass:NSDictionary.class]) return nil;
    NSArray *keys = fabs(ratio - .75) < fabs(ratio - 1) ?
        @[@"motionDetailTall",@"motionTallVideo3x4",@"motionDetailSquare",@"motionSquareVideo1x1"] :
        @[@"motionDetailSquare",@"motionSquareVideo1x1",@"motionDetailTall",@"motionTallVideo3x4"];
    for (NSString *key in keys) {
        id v = videos[key];
        id text = [v isKindOfClass:NSDictionary.class] ? v[@"video"] : nil;
        if (![text isKindOfClass:NSString.class]) continue;
        NSURL *url = [NSURL URLWithString:text];
        if (SGAppleArtworkURLValid(url)) return url;
    }
    return nil;
}
static NSDictionary *hlsAttributes(NSString *text) {
    if (!text.length || [text hasSuffix:@","]) return nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        @"([A-Z0-9_-]+)=(\"[^\"]*\"|[^,]+)(?:,|$)" options:0 error:nil];
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    NSUInteger end = 0;
    for (NSTextCheckingResult *match in [re matchesInString:text options:0 range:NSMakeRange(0,text.length)]) {
        if (match.range.location != end) return nil;
        NSString *key = [text substringWithRange:[match rangeAtIndex:1]];
        NSString *value = [text substringWithRange:[match rangeAtIndex:2]];
        if (attributes[key]) return nil;
        if ([value hasPrefix:@"\""]) {
            if (value.length < 2 || ![value hasSuffix:@"\""]) return nil;
            value = [value substringWithRange:NSMakeRange(1,value.length-2)];
        }
        if ([value containsString:@"\""]) return nil;
        attributes[key] = value;
        end = NSMaxRange(match.range);
    }
    return end == text.length ? attributes : nil;
}
static BOOL decimal(NSString *text, unsigned long long *value) {
    if (!text.length || [text rangeOfCharacterFromSet:
        [NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet].location != NSNotFound) return NO;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    return [scanner scanUnsignedLongLong:value] && scanner.isAtEnd && *value <= 32 * 1024 * 1024;
}
static BOOL byteRange(NSString *text, unsigned long long expected, unsigned long long *end) {
    NSArray *parts = [text componentsSeparatedByString:@"@"];
    unsigned long long length = 0, start = expected;
    if (parts.count > 2 || !decimal(parts.firstObject,&length) || !length ||
        (parts.count == 2 && !decimal(parts[1],&start)) || start != expected ||
        start + length > 32 * 1024 * 1024) return NO;
    *end = start + length;
    return YES;
}
NSURL *SGAppleArtworkPlaylistURL(NSString *playlist, NSURL *base, double ratio, BOOL *isMaster, NSError **error) {
    if (isMaster) *isMaster = NO;
    if (error) *error = nil;
    NSURL *(^fail)(NSString *) = ^NSURL *(NSString *why) { if (error) *error = artworkError(why); return nil; };
    if (![playlist isKindOfClass:NSString.class] || playlist.length > 256 * 1024 ||
        !SGAppleArtworkURLValid(base) || !isfinite(ratio) || ratio <= 0) return fail(@"Invalid artwork playlist");
    NSMutableArray<NSString *> *lines = [NSMutableArray new];
    for (NSString *line in [playlist componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (trimmed.length) [lines addObject:trimmed];
    }
    if (![lines.firstObject isEqual:@"#EXTM3U"]) return fail(@"Missing HLS header");
    BOOL master = [playlist containsString:@"#EXT-X-STREAM-INF:"];
    if (isMaster) *isMaster = master;
    NSURL *best = nil, *resource = nil;
    NSDictionary *variant = nil;
    NSString *range = nil;
    BOOL mapped = NO, ended = NO, pending = NO;
    NSUInteger segments = 0;
    unsigned long long offset = 0, bestPixels = 0;
    double duration = 0, bestShape = HUGE_VAL;
    for (NSString *line in [lines subarrayWithRange:NSMakeRange(1,lines.count-1)]) {
        if (ended) return fail(@"Content after HLS end marker");
        if ([line hasPrefix:@"#EXT-X-KEY:"] || [line hasPrefix:@"#EXT-X-SESSION-KEY:"] ||
            [line hasPrefix:@"#EXT-X-DISCONTINUITY"] || [line hasPrefix:@"#EXT-X-PART"] ||
            [line hasPrefix:@"#EXT-X-PRELOAD"] || [line hasPrefix:@"#EXT-X-SKIP"] ||
            [line hasPrefix:@"#EXT-X-GAP"] || [line hasPrefix:@"#EXT-X-I-FRAME"] ||
            [line hasPrefix:@"#EXT-X-DEFINE"] || [line hasPrefix:@"#EXT-X-START"] ||
            [line hasPrefix:@"#EXT-X-MEDIA:"]) return fail(@"Unsupported encrypted, discontinuous, variable or alternate-media HLS");
        if ([line hasPrefix:@"#EXT-X-STREAM-INF:"]) {
            if (!master || variant) return fail(@"Malformed HLS master");
            variant = hlsAttributes([line substringFromIndex:18]);
            if (!variant) return fail(@"Malformed variant attributes");
        } else if ([line hasPrefix:@"#EXT-X-MAP:"]) {
            if (master || mapped || segments || pending) return fail(@"Unsupported HLS initialization map");
            NSDictionary *a = hlsAttributes([line substringFromIndex:11]);
            if (!a[@"URI"] || !byteRange(a[@"BYTERANGE"],0,&offset)) return fail(@"Initialization map needs a contiguous byte range from zero");
            resource = [NSURL URLWithString:a[@"URI"] relativeToURL:base].absoluteURL;
            mapped = YES;
        } else if ([line hasPrefix:@"#EXTINF:"]) {
            if (master || pending) return fail(@"Malformed HLS segment duration");
            NSString *text = [[[line substringFromIndex:8] componentsSeparatedByString:@","] firstObject];
            double seconds = 0;
            NSScanner *scanner = [NSScanner scannerWithString:text]; scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            if (![scanner scanDouble:&seconds] || !scanner.isAtEnd || !isfinite(seconds) || seconds <= 0 || duration + seconds > 60)
                return fail(@"Artwork duration is invalid or exceeds 60 seconds");
            duration += seconds; pending = YES;
        } else if ([line hasPrefix:@"#EXT-X-BYTERANGE:"]) {
            if (master || !pending || range) return fail(@"Malformed HLS byte range");
            range = [line substringFromIndex:17];
        } else if ([line isEqual:@"#EXT-X-ENDLIST"]) {
            if (master || pending) return fail(@"Malformed HLS end marker");
            ended = YES;
        } else if ([line hasPrefix:@"#EXT-X-PLAYLIST-TYPE:"]) {
            if (master || ![line isEqual:@"#EXT-X-PLAYLIST-TYPE:VOD"]) return fail(@"Only VOD artwork playlists are supported");
        } else if (![line hasPrefix:@"#"]) {
            NSURL *url = [NSURL URLWithString:line relativeToURL:base].absoluteURL;
            if (!SGAppleArtworkURLValid(url)) return fail(@"Artwork URL leaves Apple's HTTPS CDN");
            if (master) {
                if (!variant) return fail(@"Variant URI without stream attributes");
                NSArray *size = [variant[@"RESOLUTION"] componentsSeparatedByString:@"x"];
                unsigned long long w = 0, h = 0;
                NSString *codec = variant[@"CODECS"];
                BOOL avc = [codec hasPrefix:@"avc1."];
                NSRegularExpression *hevc = [NSRegularExpression regularExpressionWithPattern:
                    @"^(?:hvc1|hev1)\\.[12]\\.[0-9A-Fa-f]+\\.L[0-9]+(?:\\.[0-9A-Fa-f]+)*$" options:0 error:nil];
                BOOL supportedCodec = avc || (SGAppleArtworkHEVCSupported() && [codec isKindOfClass:NSString.class] &&
                    [hevc numberOfMatchesInString:codec options:0 range:NSMakeRange(0, codec.length)] == 1);
                BOOL supported = size.count == 2 && decimal(size[0],&w) && decimal(size[1],&h) && w && h &&
                    w <= 1920 && h <= 1920 && supportedCodec && ![codec containsString:@","] &&
                    (!variant[@"VIDEO-RANGE"] || [variant[@"VIDEO-RANGE"] isEqual:@"SDR"]) &&
                    !variant[@"AUDIO"] && !variant[@"VIDEO"] && !variant[@"SUBTITLES"];
                double shape = supported ? fabs(log(((double)w/h)/ratio)) : HUGE_VAL;
                if (supported && (shape < bestShape - .001 || (fabs(shape-bestShape) <= .001 && w*h > bestPixels))) {
                    best = url; bestShape = shape; bestPixels = w*h;
                }
                variant = nil;
            } else {
                if (!pending || ![url.pathExtension.lowercaseString isEqual:@"mp4"]) return fail(@"Only complete MP4 resources are supported");
                if (mapped) {
                    if (![resource isEqual:url] || !range || !byteRange(range,offset,&offset))
                        return fail(@"Only contiguous single-resource MP4 HLS is supported");
                } else if (segments || range) return fail(@"Segmented or unmapped byte-range HLS is unsupported");
                resource = url; segments++; pending = NO; range = nil;
            }
        } else if ([line hasPrefix:@"#EXT"] &&
            ![line hasPrefix:@"#EXT-X-VERSION:"] && ![line hasPrefix:@"#EXT-X-TARGETDURATION:"] &&
            ![line hasPrefix:@"#EXT-X-MEDIA-SEQUENCE:"] && ![line isEqual:@"#EXT-X-INDEPENDENT-SEGMENTS"]) {
            return fail(@"Unsupported HLS tag");
        }
    }
    if (master) return !variant && best ? best : fail(@"No supported SDR artwork variant");
    return ended && segments && !pending && SGAppleArtworkURLValid(resource) ? resource : fail(@"Live or incomplete artwork playlist");
}
