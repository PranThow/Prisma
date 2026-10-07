#!/usr/bin/env python3
"""Render Prisma's eclipse mark as opaque, unmasked alternate icons (stdlib only)."""
import math
from pathlib import Path
import struct
import zlib

PALETTES = {"PrismaViolet": (122, 106, 255), "PrismaEmerald": (55, 215, 161), "PrismaPearl": (190, 208, 235)}


def png(size, tint):
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            u, v = (x + .5) / size, (y + .5) / size
            radius = math.hypot(u - .5, v - .76)
            arc = math.exp(-((radius - .385) / .005) ** 2)
            glow = math.exp(-((radius - .385) / .065) ** 2)
            upper = max(0, min(1, (.77 - v) * 7))
            outer = max(0, min(1, (radius - .377) * 90))
            rows.extend(round(min(255, 5 + c * (.09 + .32 * glow * upper) * outer +
                                  245 * arc * upper)) for c in tint)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "docs" / "app-icons"
    target.mkdir(exist_ok=True)
    for name, tint in PALETTES.items():
        for suffix, size in (("@2x", 120), ("@3x", 180), ("-ipad@2x", 152), ("-ipad-pro@2x", 167)):
            (target / f"{name}{suffix}.png").write_bytes(png(size, tint))
