#import <CoreImage/CoreImage.h>
#include <math.h>
// Shared by the renderer and its native Core Image regression, with a bounded output rectangle.
static inline CIImage *SGRFluidFrame(CIImage *cover, double phase, double warp, double blur, double saturation, double brightness) {
    CIImage *image = [cover imageByClampingToExtent];
    image = [image imageByApplyingFilter:@"CITwirlDistortion" withInputParameters:@{
        kCIInputCenterKey:[CIVector vectorWithX:80 + sin(phase * .17) * 35 Y:80 + cos(phase * .13) * 35],
        kCIInputRadiusKey:@180, kCIInputAngleKey:@(sin(phase * .2) * warp)}];
    image = [image imageByApplyingFilter:@"CIColorControls" withInputParameters:@{
        kCIInputSaturationKey:@(saturation), kCIInputBrightnessKey:@(brightness)}];
    return [[image imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{kCIInputRadiusKey:@(blur)}]
        imageByCroppingToRect:CGRectMake(0, 0, 160, 160)];
}
