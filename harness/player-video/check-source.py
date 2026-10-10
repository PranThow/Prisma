#!/usr/bin/env python3
"""Source contracts for the player-video fallback path (runs without Apple SDKs)."""
from pathlib import Path

source = (Path(__file__).parents[2] / "tweak/Sources/Redesigned/Player/PlayerVideo.x").read_text()
required = (
    "SGCanvasSetConsumerActive(self, eligible && [order containsObject:@\"spotify\"]);",
    "if (!url) { owner->_pending = NO; [owner next]; return; }",
    "current->_lease = video;",
    "[AVPlayerLooper playerLooperWithPlayer:current->_player templateItem:item]",
    "BOOL shown = active && _surface.readyForDisplay;",
    "if (!video) {",
    "[current next]; return;",
    "if (object == self->_player && self->_player.currentItem.status == AVPlayerItemStatusFailed) [self clipFailed];",
    "[self releasePlayer];",
    "SGRPlayerSetVideoActive(NO); self.alpha = 0;",
    "generation != current->_generation",
)
missing = [contract for contract in required if contract not in source]
assert not missing, "missing player-video contract(s): " + "; ".join(missing)
assert source.index("BOOL shown = active && _surface.readyForDisplay;") < source.index("SGRPlayerSetVideoActive(shown);"), \
    "video must not replace the fluid fallback before the surface is ready"
print("Player video source: ordered fallback, leased looping playback, readiness and stale/failure fallback passed")
