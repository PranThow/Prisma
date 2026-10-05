#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// Retain this result for as long as a player uses fileURL: it leases the cached file.
@interface SGPreparedArtworkVideo : NSObject
@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) NSData *previewJPEG;
@end

// Main queue API. Each prepare cancels the previous request on this instance.
// Cancellation (including replacement) suppresses completion, even if already queued.
@interface SGArtworkVideoPreparer : NSObject
- (void)prepareURL:(NSURL *)url aspectRatio:(double)ratio
        completion:(void (^)(SGPreparedArtworkVideo *video, NSError *error))completion;
- (void)cancel;
@end

// Geometry and boundary checks shared with the macOS harness.
BOOL SGArtworkVideoURLValid(NSURL *url);
BOOL SGArtworkVideoFilenameValid(NSString *name);
BOOL SGArtworkVideoGeometry(CGSize natural, CGAffineTransform orientation, double ratio,
                            CGSize *renderSize, CGAffineTransform *transform, BOOL *crop);
