#import "SGRFlow.h"
#import <CoreImage/CoreImage.h>
#import <math.h>
#import "SGRFluidRender.h"

double SGRFluidValue(NSString *key, double fallback, double minimum, double maximum) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    double number = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : fallback;
    return isfinite(number) ? MIN(maximum, MAX(minimum, number)) : fallback;
}
@implementation SGRFlowLayer {
    CIImage *_cover;
    dispatch_source_t _timer;
    dispatch_queue_t _renderer;
    CIContext *_context;
    CFTimeInterval _phase, _last;
    NSUInteger _generation;
    BOOL _pending;
    double _speed, _warp, _blur, _saturation, _brightness;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.contentsGravity = kCAGravityResizeAspectFill;
    self.masksToBounds = YES;
    _renderer = dispatch_queue_create("Prisma.cover-renderer", DISPATCH_QUEUE_SERIAL);
    _context = [CIContext contextWithOptions:@{kCIContextCacheIntermediates:@NO}];
    [self refreshSettings];
    return self;
}
- (void)dealloc { if (_timer) dispatch_source_cancel(_timer); }
- (void)refreshSettings {
    _speed = SGRFluidValue(SGRKeyFluidSpeed, 1, 0, 3);
    _warp = SGRFluidValue(SGRKeyFluidWarp, 1.2, 0, 4);
    _blur = SGRFluidValue(SGRKeyFluidBlur, 12, 0, 30);
    _saturation = SGRFluidValue(SGRKeyFluidSaturation, 1.2, 0, 2);
    _brightness = SGRFluidValue(SGRKeyFluidBrightness, -.18, -.5, .2);
    ++_generation;
    [self render];
}
- (void)setArtwork:(UIImage *)artwork {
    if (!artwork.CGImage) return;
    // Bound raster work independently of screen scale; this surface is intentionally blurred.
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1;
    UIImage *small = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(160, 160) format:format]
        imageWithActions:^(UIGraphicsImageRendererContext *context) { [artwork drawInRect:CGRectMake(0, 0, 160, 160)]; }];
    _cover = [CIImage imageWithCGImage:small.CGImage];
    ++_generation;
    [self render];
}
- (void)setMoving:(BOOL)moving {
    if (_moving == moving) return;
    _moving = moving;
    if (_timer) { dispatch_source_cancel(_timer); _timer = nil; }
    _last = CACurrentMediaTime();
    if (!moving) return;
    __weak SGRFlowLayer *weakSelf = self;
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 20, NSEC_PER_SEC / 200);
    dispatch_source_set_event_handler(_timer, ^{
        SGRFlowLayer *owner = weakSelf;
        if (!owner) return;
        CFTimeInterval now = CACurrentMediaTime();
        owner->_phase += MIN(.1, now - owner->_last) * owner->_speed;
        owner->_last = now;
        if (owner->_speed == 0) return;
        [owner render];
    });
    dispatch_resume(_timer);
}
- (void)render {
    if (_pending || !_cover) return;
    _pending = YES;
    NSUInteger generation = _generation;
    double phase = _phase, warp = _warp, blur = _blur, saturation = _saturation, brightness = _brightness;
    CIImage *cover = _cover;
    CIContext *context = _context;
    __weak SGRFlowLayer *weakSelf = self;
    dispatch_async(_renderer, ^{
        @autoreleasepool {
            CIImage *image = SGRFluidFrame(cover, phase, warp, blur, saturation, brightness);
            CGImageRef bitmap = [context createCGImage:image fromRect:CGRectMake(0, 0, 160, 160)];
            dispatch_async(dispatch_get_main_queue(), ^{
                SGRFlowLayer *owner = weakSelf;
                if (owner) {
                    owner->_pending = NO;
                    if (generation == owner->_generation && bitmap) {
                        [CATransaction begin]; [CATransaction setDisableActions:YES];
                        owner.contents = (__bridge id)bitmap;
                        [CATransaction commit];
                    } else if (generation != owner->_generation) [owner render];
                }
                if (bitmap) CGImageRelease(bitmap);
            });
        }
    });
}
@end
