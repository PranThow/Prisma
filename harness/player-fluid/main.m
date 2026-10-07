#import "Redesigned/Kit/SGRFluidRender.h"
#include <assert.h>
static NSData *pixels(CIContext *context, CIImage *image) {
    assert(CGRectEqualToRect(image.extent, CGRectMake(0, 0, 160, 160)));
    NSMutableData *data = [NSMutableData dataWithLength:160 * 160 * 4];
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    [context render:image toBitmap:data.mutableBytes rowBytes:160 * 4 bounds:image.extent format:kCIFormatRGBA8 colorSpace:color];
    CGColorSpaceRelease(color);
    return data;
}
int main(void) { @autoreleasepool {
    CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@YES}];
    CIImage *cover = [[CIFilter filterWithName:@"CICheckerboardGenerator" withInputParameters:@{
        @"inputColor0":[CIColor colorWithRed:1 green:.2 blue:.1],
        @"inputColor1":[CIColor colorWithRed:.1 green:.2 blue:1], @"inputWidth":@20}].outputImage
        imageByCroppingToRect:CGRectMake(0, 0, 160, 160)];
    NSData *still = pixels(context, SGRFluidFrame(cover, 0, 1.2, 12, 1.2, -.18));
    assert([still isEqual:pixels(context, SGRFluidFrame(cover, 0, 1.2, 12, 1.2, -.18))]);
    assert(![still isEqual:pixels(context, SGRFluidFrame(cover, 5, 1.2, 12, 1.2, -.18))]);
    assert(![still isEqual:pixels(context, SGRFluidFrame(cover, 0, 1.2, 0, 1.2, -.18))]);
    assert(![still isEqual:pixels(context, SGRFluidFrame(cover, 0, 1.2, 12, 0, -.18))]);
    assert(![still isEqual:pixels(context, SGRFluidFrame(cover, 0, 1.2, 12, 1.2, -.4))]);
    puts("Fluid: actual-cover warp, pause determinism, blur, saturation and brightness passed");
} return 0; }
