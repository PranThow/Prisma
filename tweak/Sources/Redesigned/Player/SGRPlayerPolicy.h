// Small numeric decisions shared with the standalone regression check.
#include <math.h>
#include <stdbool.h>
static inline double SGRPlayerTapFraction(double x, double width, bool rtl) {
    if (!isfinite(x) || !isfinite(width) || width <= 0) return NAN;
    double fraction = fmin(1, fmax(0, x / width));
    return rtl ? 1 - fraction : fraction;
}
static inline bool SGRPlayerShouldImmerse(bool eligible, double now, double lastTouch) {
    return eligible && isfinite(now) && isfinite(lastTouch) && now - lastTouch >= 4;
}
static inline double SGRPlayerDisplayedCoverScale(bool holdingTransition, double transitionScale, double currentScale) {
    return holdingTransition ? transitionScale : currentScale;
}
