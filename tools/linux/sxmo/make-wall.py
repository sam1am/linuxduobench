#!/usr/bin/env python3
"""Make duo-wall.png: 1350x1800, near-black gradient, a neon horizon and a fading perspective grid. Pure Python."""
import math, struct, sys, zlib

W, H = 1350, 1800
HOR = int(H * 0.66)                      # horizon line
top, bot = (7, 7, 13), (16, 8, 30)
CYAN, MAG = (0, 240, 255), (255, 42, 109)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


rows = []
vx = W / 2
# horizontal grid lines: evenly spaced in depth (1/z), as rows below the horizon
hrows = []
for k in range(0, 80):                     # equal spacing on the ground: screen offset ~ 1/distance
    y = HOR + (H - HOR) * 0.9 / (1.0 + 0.45 * k)
    if y > HOR + 3:
        hrows.append(y)


def line(px, width):
    """intensity of a neon line at pixel distance px: hard core + soft halo"""
    return max(0.0, 1 - px / width) + 0.35 * math.exp(-px / (width * 2.5))


for y in range(H):
    base = mix(top, bot, (y / H) ** 1.6)
    row = bytearray()
    d = y - HOR
    hd = min((abs(y - r) for r in hrows), default=99) if d > 2 else 99
    for x in range(W):
        c = list(base)
        g = math.exp(-abs(d) / (3.0 if d >= 0 else 26.0))            # horizon glow
        c = [c[i] + (CYAN[i] - c[i]) * min(1, g * (0.85 if abs(d) < 2 else 0.35)) for i in range(3)]
        if d > 2:
            depth = d / (H - HOR)
            fade = 0.10 + 0.60 * depth
            sp = d * 1.15                                          # vertical line spacing on this row, px
            fu = ((x - vx) / sp + 0.5) % 1.0
            vpx = min(fu, 1 - fu) * sp
            a = min(1.0, max(line(hd, 1.2), line(vpx, 1.0 + depth * 0.8))) * fade
            c = [c[i] + (MAG[i] - c[i]) * a for i in range(3)]
        row += bytes(max(0, min(255, int(v))) for v in c)
    rows.append(bytes(row))


def png(path):
    raw = b"".join(b"\0" + r for r in rows)
    def chunk(t, data):
        return struct.pack(">I", len(data)) + t + data + struct.pack(">I", zlib.crc32(t + data) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) +
                chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


png(sys.argv[1])
