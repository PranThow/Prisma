// Core Image distorts the actual cover; a paused owner retains the last rendered frame.
#import <UIKit/UIKit.h>
#define SGRKeyFluidSpeed @"spotifyglass.redesign.player.fluid.speed"
#define SGRKeyFluidWarp @"spotifyglass.redesign.player.fluid.warp"
#define SGRKeyFluidBlur @"spotifyglass.redesign.player.fluid.blur"
#define SGRKeyFluidSaturation @"spotifyglass.redesign.player.fluid.saturation"
#define SGRKeyFluidBrightness @"spotifyglass.redesign.player.fluid.brightness"
double SGRFluidValue(NSString *key, double fallback, double minimum, double maximum);
@interface SGRFlowLayer : CALayer
- (void)setArtwork:(UIImage *)artwork;
- (void)refreshSettings;
@property (nonatomic) BOOL moving;
@end
