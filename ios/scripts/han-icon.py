#!/usr/bin/env python3
"""L'icône de Reindoo Hán Việt, tirée de celle de reindoo.

Le renne passe à l'encre, et un sceau rouge porte 漢 en bas à droite. Le
caractère est tracé ici, trait par trait : aucune police, aucun fichier
d'ailleurs. Rien que la bibliothèque standard, pour tourner partout.

    python3 ios/scripts/han-icon.py

Lit  ios/App/Assets.xcassets/AppIcon.appiconset/icon.png
Écrit ios/Han/Assets.xcassets/AppIcon.appiconset/icon.png
"""
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "App/Assets.xcassets/AppIcon.appiconset/icon.png"
TARGET = ROOT / "Han/Assets.xcassets/AppIcon.appiconset/icon.png"

INK = (34, 40, 49)
SEAL = (215, 38, 61)
PAPER = (255, 250, 240)

# Le sceau : un carré aux bords un peu mangés, comme un tampon.
SEAL_X, SEAL_Y, SEAL_SIZE = 668, 668, 272
STROKE = 0.075  # épaisseur d'un trait, en fraction du sceau

# 漢, dans un carré unité (y vers le bas) : 氵 à gauche, puis 廿, 口 et 夫,
# dont les deux traits horizontaux le distinguent de 漠.
STROKES = [
    ((0.10, 0.13), (0.19, 0.21)),
    ((0.07, 0.38), (0.16, 0.45)),
    ((0.07, 0.86), (0.20, 0.58)),
    ((0.32, 0.16), (0.94, 0.16)),
    ((0.47, 0.05), (0.47, 0.31)),
    ((0.79, 0.05), (0.79, 0.31)),
    ((0.47, 0.31), (0.79, 0.31)),
    ((0.42, 0.39), (0.84, 0.39)),
    ((0.42, 0.39), (0.42, 0.54)),
    ((0.84, 0.39), (0.84, 0.54)),
    ((0.42, 0.54), (0.84, 0.54)),
    ((0.42, 0.66), (0.84, 0.66)),
    ((0.34, 0.78), (0.93, 0.78)),
    ((0.63, 0.54), (0.63, 0.80)),
    ((0.63, 0.80), (0.33, 0.96)),
    ((0.65, 0.81), (0.95, 0.96)),
]


def read_png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat = 8, b""
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert (depth, colour, interlace) == (8, 2, 0), "attendu : RVB 8 bits, non entrelacé"
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * 3
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            a = line[x - 3] if x >= 3 else 0
            b = previous[x]
            c = previous[x - 3] if x >= 3 else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        previous = line
    return width, height, rows


def write_png(path, width, height, rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def noise(x, y):
    """Un grain fixe, de 0 à 1 : la même icône à chaque exécution."""
    h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 0xFFFF


def segment_distance(px, py, a, b):
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def mix(base, colour, alpha):
    return [round(b + (c - b) * alpha) for b, c in zip(base, colour)]


def main():
    width, height, rows = read_png(SOURCE)

    # Le renne à l'encre : sa couverture se lit sur le vert, que le rouge
    # d'origine n'a presque pas et le fond blanc a tout entier.
    for row in rows:
        for x in range(width):
            r, g, b = row[3 * x:3 * x + 3]
            coverage = max(0.0, min(1.0, (255 - g) / (255 - 51)))
            if coverage > 0 and r > g:
                row[3 * x:3 * x + 3] = bytes(mix((255, 255, 255), INK, coverage))

    size = SEAL_SIZE
    margin, stroke = 0.12, STROKE
    for y in range(SEAL_Y - 4, SEAL_Y + size + 4):
        for x in range(SEAL_X - 4, SEAL_X + size + 4):
            u, v = (x - SEAL_X) / size, (y - SEAL_Y) / size
            # Le bord : une distance au carré arrondi, rongée par le grain.
            edge = max(abs(u - 0.5), abs(v - 0.5)) - 0.5
            rough = 0.012 * noise(x // 3, y // 3)
            alpha = max(0.0, min(1.0, (-(edge + rough)) * size / 1.5))
            if alpha <= 0:
                continue
            pixel = list(rows[y][3 * x:3 * x + 3])
            pixel = mix(pixel, SEAL, alpha * (0.88 + 0.12 * noise(x, y)))
            # Le caractère, dans le sceau, à la couleur du papier.
            cu, cv = (u - margin) / (1 - 2 * margin), (v - margin) / (1 - 2 * margin)
            d = min(segment_distance(cu, cv, a, b) for a, b in STROKES)
            ink = max(0.0, min(1.0, (stroke / 2 - d) * size / 1.2))
            if ink > 0:
                pixel = mix(pixel, PAPER, ink * (0.8 + 0.2 * noise(x * 7, y * 5)))
            rows[y][3 * x:3 * x + 3] = bytes(pixel)

    write_png(TARGET, width, height, rows)
    print(f"écrit {TARGET.relative_to(ROOT.parent)}")


if __name__ == "__main__":
    main()
