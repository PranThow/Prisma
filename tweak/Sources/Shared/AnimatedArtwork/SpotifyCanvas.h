#import <Foundation/Foundation.h>

// No credentials travel with the result. A downloader uses a separate unauthenticated session.
@interface SGCanvasResult : NSObject
@property (nonatomic, copy, readonly) NSString *trackURI;
@property (nonatomic, copy, readonly) NSURL *videoURL;
@end

// Main queue only. Nil until resolved or when the track has no usable Canvas.
SGCanvasResult *SGCanvasCurrentResult(void);
// Posted on the main queue when a result arrives or is cleared on a track change.
extern NSString *const SGCanvasResultDidChange;

// Pure parsing entry points, also used by harness/canvas/check.sh.
SGCanvasResult *SGCanvasFromMetadata(id metadata, NSString *trackURI);
SGCanvasResult *SGCanvasFromProtobuf(NSData *body, NSString *trackURI);
NSData *SGCanvasRequestBody(NSString *trackURI);
