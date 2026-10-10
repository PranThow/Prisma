from pathlib import Path

source = (Path(__file__).parents[2] / "tweak/Sources/Redesigned/Kit/SGRFlow.m").read_text()
required = (
    'dispatch_queue_create("Prisma.cover-renderer", DISPATCH_QUEUE_SERIAL)',
    '++_generation;\n    [self render];',
    'if (generation == owner->_generation && bitmap)',
    'else if (generation != owner->_generation) [owner render];',
)
assert all(snippet in source for snippet in required)
print("Fluid source: serial renderer and stale-cover rejection passed")
