#import "SpotifyCanvas.h"
#import "Shared/Lyrics/Protobuf.h"

@interface SGCanvasResult ()
@property (nonatomic, copy, readwrite) NSString *trackURI;
@property (nonatomic, copy, readwrite) NSURL *videoURL;
@end
@implementation SGCanvasResult
@end

static BOOL trackURIValid(NSString *uri) {
    if (![uri isKindOfClass:NSString.class] || ![uri hasPrefix:@"spotify:track:"] || uri.length != 36) return NO;
    NSString *identifier = [uri substringFromIndex:14];
    return [identifier rangeOfCharacterFromSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"] invertedSet]].location == NSNotFound;
}

static SGCanvasResult *result(id address, NSString *uri) {
    if (!trackURIValid(uri) || ![address isKindOfClass:NSString.class]) return nil;
    NSURL *url = [NSURL URLWithString:address];
    NSString *host = url.host.lowercaseString;
    // Canvas videos live on Spotify's CDN. Require a video path, never a cover image or arbitrary URL.
    if (![url.scheme.lowercaseString isEqual:@"https"] || url.user || url.password ||
        (url.port && url.port.integerValue != 443) ||
        !([host isEqual:@"scdn.co"] || [host hasSuffix:@".scdn.co"]) ||
        ![url.path.pathExtension.lowercaseString isEqual:@"mp4"]) return nil;
    SGCanvasResult *canvas = [SGCanvasResult new];
    canvas.trackURI = uri;
    canvas.videoURL = url;
    return canvas;
}

SGCanvasResult *SGCanvasFromMetadata(id metadata, NSString *trackURI) {
    if (![metadata isKindOfClass:NSDictionary.class]) return nil;
    id type = metadata[@"canvas.type"];
    if (type && !([type isKindOfClass:NSString.class] || [type isKindOfClass:NSNumber.class])) return nil;
    if (type && ![@[@"1", @"2", @"3", @"VIDEO", @"VIDEO_LOOPING", @"VIDEO_LOOPING_RANDOM"]
                  containsObject:[[type description] uppercaseString]]) return nil;
    return result(metadata[@"canvas.url"], trackURI);
}

NSData *SGCanvasRequestBody(NSString *trackURI) {
    if (!trackURIValid(trackURI)) return nil;
    // EntityCanvazRequest: repeated Entity field 1, Entity.entity_uri field 1.
    return SGPBSerialize(@[SGPBBytes(1, SGPBSerialize(@[SGPBString(1, trackURI)]))]);
}

SGCanvasResult *SGCanvasFromProtobuf(NSData *body, NSString *trackURI) {
    if (!trackURIValid(trackURI) || !body.length || body.length > 1024 * 1024) return nil;
    NSArray<SGPBField *> *fields = SGPBParse(body);
    SGCanvasResult *found = nil;
    // EntityCanvazResponse.canvases field 1; url 2, type 4, entity_uri 5.
    // Schema: https://github.com/Delitefully/spotify-canvas-downloader/blob/master/protos/canvas.proto
    for (SGPBField *field in fields) {
        if (field.number != 1) continue;
        if (field.wire != 2) return nil;
        NSArray<SGPBField *> *canvas = SGPBParse(field.payload);
        if (!canvas) return nil;
        SGPBField *type = SGPBFirst(canvas, 4);
        if (!type || type.wire != 0 || type.varint < 1 || type.varint > 3) continue;
        if (![SGPBText(SGPBFirst(canvas, 5)) isEqual:trackURI]) continue;
        SGCanvasResult *candidate = result(SGPBText(SGPBFirst(canvas, 2)), trackURI);
        if (!found) found = candidate;
    }
    return found;
}
