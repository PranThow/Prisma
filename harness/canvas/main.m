// macOS: sh harness/canvas/check.sh. Uses the production parsers, no network or credentials.
#import "Shared/AnimatedArtwork/SpotifyCanvas.h"
#import "Shared/Lyrics/Protobuf.h"
#include <assert.h>

static NSData *entry(NSString *uri, NSString *url, uint64_t type) {
    return SGPBSerialize(@[SGPBString(2, url), SGPBVarint(4, type), SGPBString(5, uri)]);
}

int main(void) {
    @autoreleasepool {
        NSString *uri = @"spotify:track:0123456789ABCDEFGHIJKL";
        NSString *other = @"spotify:track:abcdefghijklmnopqrstuv";
        NSString *video = @"https://canvaz.scdn.co/upload/video/test.cnvs.mp4?token=public";
        assert(!SGCanvasFromMetadata(nil, uri));
        assert(!SGCanvasFromMetadata(@[], uri));
        assert(!SGCanvasFromMetadata(@{}, uri));
        assert(!SGCanvasFromMetadata(@{@"canvas_url": @42}, uri));
        assert(!SGCanvasFromMetadata(@{@"canvas_url": video, @"canvas_type": @[]}, uri));
        for (id type in @[@1, @2, @3, @"VIDEO", @"video_looping", @"VIDEO_LOOPING_RANDOM"]) {
            SGCanvasResult *canvas = SGCanvasFromMetadata(@{@"canvas_url": video, @"canvas_type": type}, uri);
            assert([canvas.trackURI isEqual:uri]);
            assert([canvas.videoURL.absoluteString isEqual:video]);
        }
        assert(SGCanvasFromMetadata(@{@"canvas_url": video}, uri));
        for (id type in @[@0, @4, @"IMAGE", @"GIF", @"garbage"])
            assert(!SGCanvasFromMetadata(@{@"canvas_url": video, @"canvas_type": type}, uri));
        for (NSString *url in @[@"http://canvaz.scdn.co/a.mp4", @"https://canvaz.scdn.co/a.jpg",
                @"https://scdn.co.evil.test/a.mp4", @"https://evilscdn.co/a.mp4",
                @"https://user:pass@canvaz.scdn.co/a.mp4", @"https://canvaz.scdn.co:444/a.mp4", @"bad"])
            assert(!SGCanvasFromMetadata(@{@"canvas_url": url}, uri));
        for (NSString *badURI in @[@"", @"spotify:episode:0123456789ABCDEFGHIJKL",
                @"spotify:track:short", @"spotify:track:0123456789ABCDEFGHIJK/"]) {
            assert(!SGCanvasRequestBody(badURI));
            assert(!SGCanvasFromMetadata(@{@"canvas_url": video}, badURI));
        }
        assert(!SGCanvasRequestBody(nil));
        SGPBField *entity = SGPBFirst(SGPBParse(SGCanvasRequestBody(uri)), 1);
        assert([SGPBText(SGPBFirst(SGPBParse(entity.payload), 1)) isEqual:uri]);
        for (uint64_t type = 0; type <= 5; type++) {
            NSData *reply = SGPBSerialize(@[SGPBBytes(1, entry(uri, video, type))]);
            assert((SGCanvasFromProtobuf(reply, uri) != nil) == (type >= 1 && type <= 3));
        }
        NSData *mixed = SGPBSerialize(@[SGPBBytes(1, entry(other, video, 2)),
            SGPBBytes(1, entry(uri, @"https://canvaz.scdn.co/cover.jpg", 2)),
            SGPBBytes(1, entry(uri, video, 3)), SGPBVarint(2, 3600), SGPBString(99, @"future")]);
        assert([SGCanvasFromProtobuf(mixed, uri).videoURL.absoluteString isEqual:video]);
        assert(!SGCanvasFromProtobuf(SGPBSerialize(@[SGPBBytes(1, entry(other, video, 2))]), uri));
        assert(!SGCanvasFromProtobuf(SGPBSerialize(@[SGPBBytes(1, SGPBSerialize(@[
            SGPBString(2, video), SGPBString(4, @"2"), SGPBString(5, uri)]))]), uri));
        assert(!SGCanvasFromProtobuf(nil, uri));
        assert(!SGCanvasFromProtobuf([NSData data], uri));
        assert(!SGCanvasFromProtobuf([NSMutableData dataWithLength:1024 * 1024 + 1], uri));
        const uint8_t truncated[] = {0x0a, 0x05, 0x12};
        NSData *broken = [NSData dataWithBytes:truncated length:sizeof(truncated)];
        assert(!SGCanvasFromProtobuf(broken, uri));
        // Reject a malformed entry even after finding a valid one.
        assert(!SGCanvasFromProtobuf(SGPBSerialize(@[SGPBBytes(1, entry(uri, video, 2)),
                                                    SGPBBytes(1, broken)]), uri));
        const uint8_t overflow[] = {0x08, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x02};
        assert(!SGPBParse([NSData dataWithBytes:overflow length:sizeof(overflow)]));
        assert(!SGPBParse(SGPBSerialize(@[SGPBVarint(0x20000000, 1)])));
        assert(SGPBFirst(SGPBParse(SGPBSerialize(@[SGPBVarint(1, UINT64_MAX)])), 1).varint == UINT64_MAX);
        puts("Canvas metadata and protobuf: passed");
    }
}
