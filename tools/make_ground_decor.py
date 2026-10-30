"""Genera la hoja de decoración del suelo (assets/tiles/ground_decor.png).

Una fila por estación (verde, otoño, invierno) con 10 piezas de 32x32 px:
 0-2  matas de pasto (pequeña, alta, ancha)
 3-4  flores / variantes de la estación
 5-6  piedras (pequeña y grande) con musgo, hojas o nieve encima
 7    seta o montículo de nieve
 8-9  piedrecitas y raíz incrustadas en la tierra (bajo la superficie)
Cada fila ocupa 64 px de alto y la pieza va en los 32 de arriba: así el shader
`grass_sway` distingue los vértices de arriba (se mecen) de los de abajo.
Uso: python tools/make_ground_decor.py
"""
import random
from pathlib import Path
from PIL import Image

TILE = 32
SLOT_H = 64
# Las piezas pequeñas se dibujan en coordenadas de 16 px y se centran.
OX = (TILE - 16) // 2
COLUMNS = 10
OUT = Path(__file__).resolve().parent.parent / "assets" / "tiles" / "ground_decor.png"

STONE = [(48, 46, 56), (100, 98, 112), (148, 146, 160)]

SEASONS = [
    {   # GREEN
        "grass": [(30, 66, 34), (60, 126, 50), (118, 188, 78)],
        "flower_a": [(250, 214, 80), (255, 248, 210)],
        "flower_b": [(236, 120, 180), (255, 214, 236)],
        "cap": [(52, 112, 48), (92, 160, 64)],
        "mushroom": [(196, 44, 48), (240, 236, 220), (226, 214, 190)],
    },
    {   # AUTUMN
        "grass": [(86, 54, 22), (164, 112, 42), (222, 176, 78)],
        "flower_a": [(232, 120, 40), (196, 66, 30)],
        "flower_b": [(196, 150, 70), (236, 200, 120)],
        "cap": [(196, 80, 34), (236, 140, 50)],
        "mushroom": [(140, 80, 44), (226, 200, 160), (210, 186, 150)],
    },
    {   # WINTER
        "grass": [(66, 86, 118), (138, 166, 200), (222, 236, 252)],
        "flower_a": [(150, 210, 250), (240, 250, 255)],
        "flower_b": [(150, 210, 250), (240, 250, 255)],
        "cap": [(214, 228, 244), (250, 252, 255)],
        "mushroom": [(214, 228, 244), (250, 252, 255), (180, 200, 226)],
    },
]


def blank():
    return Image.new("RGBA", (TILE, TILE))


def put(img, x, y, col):
    if 0 <= x < TILE and 0 <= y < TILE:
        img.putpixel((x, y), col + (255,) if len(col) == 3 else col)


def put16(img, x, y, col):
    put(img, x + OX, y, col)


def tuft(ramp, blades, max_h, width, seed):
    """Mata de pasto: hojas finas y separadas que salen de la base y se curvan
    hacia los lados; oscuras abajo y claras en la punta."""
    rng = random.Random(seed)
    img = blank()
    x0 = (TILE - width) // 2
    xs = rng.sample(range(width), min(blades, width))
    for x in xs:
        x += x0
        h = rng.randint(max(2, max_h // 2), max_h)
        # Las hojas de los lados se abren hacia fuera; las del centro, al azar.
        side = x - (x0 + width / 2)
        lean = -1 if side < -1 else 1 if side > 1 else rng.choice((-1, 1))
        for i in range(h):
            t = i / max(h - 1, 1)
            col = ramp[0] if t < 0.3 else ramp[1] if t < 0.75 else ramp[2]
            bend = int(lean * (i * i) / (h * 2.2))
            put(img, x + bend, TILE - 1 - i, col)
    # Base: una línea oscura irregular que asienta la mata en el suelo.
    for x in range(x0, x0 + width):
        if rng.random() < 0.7:
            put(img, x, TILE - 1, ramp[0])
    return img


def flower(ramp, petals, seed, heads=2):
    rng = random.Random(seed)
    img = tuft(ramp, 6, 8, 14, seed)
    for _ in range(heads):
        x = rng.randint(TILE // 2 - 4, TILE // 2 + 4)
        h = rng.randint(11, 16)
        for i in range(h):
            put(img, x, TILE - 1 - i, ramp[1])
        y = TILE - 1 - h
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            put(img, x + dx, y + dy, petals[0])
        put(img, x, y, petals[1])
    return img


def crystal(ramp):
    """Cristales de hielo (invierno)."""
    img = blank()
    for x, h in ((6, 6), (8, 9), (10, 5)):
        for i in range(h):
            col = ramp[0] if i < h * 0.3 else ramp[1]
            put16(img, x, TILE - 1 - i, col)
            if i < h - 2:
                put16(img, x + 1, TILE - 1 - i, ramp[0])
        put16(img, x, TILE - h, (255, 255, 255))
    return img


def leaf_pile(colors, seed):
    rng = random.Random(seed)
    img = blank()
    for _ in range(60):
        x = rng.randint(6, 25)
        y = TILE - 1 - rng.randint(0, max(0, 4 - abs(x - 16) // 3))
        put(img, x, y, rng.choice(colors))
    return img


def rock(w, h, cap):
    img = blank()
    x0 = (TILE - w) // 2
    cx, cy = x0 + (w - 1) / 2, TILE - h + (h - 1) / 2
    for y in range(TILE - h, TILE):
        for x in range(x0, x0 + w):
            nx, ny = (x - cx) / (w / 2), (y - cy) / (h / 2)
            if nx * nx + ny * ny > 1.05:
                continue
            light = -nx - ny
            col = STONE[2] if light > 0.6 else STONE[1] if light > -0.5 else STONE[0]
            put(img, x, y, col)
    # Tapa: musgo, hojas o nieve sobre la parte de arriba.
    for x in range(x0, x0 + w):
        for y in range(TILE - h, TILE):
            if img.getpixel((x, y))[3]:
                put(img, x, y, cap[1] if (x + y) % 3 else cap[0])
                if (x * 7) % 3 == 0:
                    put(img, x, y + 1, cap[0])
                break
    return img


def mushroom(cols):
    img = blank()
    cap, stem, dots = cols
    for y in range(TILE - 4, TILE):
        put16(img, 7, y, stem)
        put16(img, 8, y, dots)
    for y, (a, b) in zip(range(TILE - 8, TILE - 4), ((6, 9), (5, 10), (4, 11), (4, 11))):
        for x in range(a, b + 1):
            put16(img, x, y, cap)
    for x, y in ((6, TILE - 6), (9, TILE - 7), (10, TILE - 5)):
        put16(img, x, y, stem)
    return img


def snow_mound(cols):
    img = blank()
    for x in range(3, 13):
        h = 4 - abs(x - 7.5) // 1.6
        for i in range(int(h)):
            put16(img, x, TILE - 1 - i, cols[1] if i == int(h) - 1 else cols[0])
    return img


def pebbles():
    img = blank()
    for x, y, c in ((4, 6, 1), (5, 6, 2), (4, 7, 0), (5, 7, 1), (9, 9, 1), (10, 9, 0), (11, 4, 2), (11, 5, 1), (7, 12, 1)):
        put16(img, x, y, STONE[c])
    return img


def root(col):
    img = blank()
    for x, y in ((2, 3), (3, 3), (4, 4), (5, 4), (6, 5), (7, 5), (8, 6), (9, 6), (10, 6), (11, 7), (6, 6), (6, 7), (5, 8)):
        put16(img, x, y, col)
    return img


def season_row(si, pal):
    g = pal["grass"]
    pieces = [
        tuft(g, 6, 10, 10, 10 + si),
        tuft(g, 9, 19, 13, 20 + si),
        tuft(g, 13, 11, 24, 30 + si),
    ]
    if si == 0:
        pieces += [flower(g, pal["flower_a"], 40), flower(g, pal["flower_b"], 41, heads=1)]
    elif si == 1:
        pieces += [leaf_pile(pal["flower_a"] + [pal["flower_b"][0]], 42), tuft(g, 9, 21, 13, 43)]
    else:
        pieces += [tuft(g, 8, 14, 14, 44), crystal(pal["flower_a"])]
    pieces += [rock(10, 7, pal["cap"]), rock(17, 11, pal["cap"])]
    pieces.append(snow_mound(pal["mushroom"]) if si == 2 else mushroom(pal["mushroom"]))
    pieces += [pebbles(), root((70, 44, 30) if si < 2 else (60, 64, 80))]
    return pieces


if __name__ == "__main__":
    sheet = Image.new("RGBA", (TILE * COLUMNS, SLOT_H * len(SEASONS)))
    for si, pal in enumerate(SEASONS):
        for i, piece in enumerate(season_row(si, pal)):
            sheet.paste(piece, (i * TILE, si * SLOT_H))
    sheet.save(OUT)
    print("ok", OUT)
