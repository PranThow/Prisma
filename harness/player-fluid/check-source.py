from pathlib import Path

source = (Path(__file__).parents[2] / "tweak/Sources/Redesigned/Kit/SGRFlow.m").read_text()
required = (
    'dispatch_queue_create("Prisma.cover-renderer", DISPATCH_QUEUE_SERIAL)',
    '++_generation;\n    [self render];',
    'if (generation == owner->_generation && bitmap)',
    'else if (generation != owner->_generation) [owner render];',
)
assert all(snippet in source for snippet in required)

field = (Path(__file__).parents[2] / "tweak/Sources/Redesigned/Player/PlayerField.x").read_text()
field_required = (
    'if (!uri || (cover == sg_lastCover && [uri isEqualToString:sg_lastCoverURI])) return;',
    'sg_field.motionHeld = state.isPaused || SGRPlayerVideoShowing();',
    'showArtwork(sg_field, YES);',
)
assert all(snippet in field for snippet in field_required)

artwork_field = (Path(__file__).parents[2] / "tweak/Sources/Redesigned/Kit/SGRField.m").read_text()
lifecycle_required = (
    'UIApplicationDidBecomeActiveNotification, UIApplicationWillResignActiveNotification',
    'NSProcessInfoPowerStateDidChangeNotification, UIAccessibilityReduceMotionStatusDidChangeNotification',
    'self.window && front && !SGRPlayerIsTransitioning() && !SGRReduceMotion()',
    '!NSProcessInfo.processInfo.lowPowerModeEnabled && !_motionHeld',
    '- (void)didMoveToWindow',
)
assert all(snippet in artwork_field for snippet in lifecycle_required)
print("Fluid source: serial renderer, stale-cover rejection and lifecycle gating passed")
