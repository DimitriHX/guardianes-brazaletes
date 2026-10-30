"""Genera el arte del orbe de vida del HUD (assets/ui/health_orb/).

Tres capas de 56x56 px que PlayerHealthBar apila:
- orb_back.png: interior vacío del vidrio (se ve al perder vida).
- orb_fill.png: líquido rojo; el TextureProgressBar lo recorta de abajo arriba.
- orb_frame.png: anillo dorado, brillo del vidrio y gema rosa del brazalete.
Uso: python tools/make_health_orb.py
"""
import math
from pathlib import Path
from PIL import Image

SIZE = 56
C = (SIZE - 1) / 2.0
R_INNER = 20.5   # radio del vidrio
R_RING = 24.5    # radio exterior del anillo
OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "health_orb"


def dist(x, y):
    return math.hypot(x - C, y - C)


def light(x, y):
    """-1 (abajo-derecha, sombra) .. 1 (arriba-izquierda, luz)."""
    d = dist(x, y) or 1.0
    return ((C - x) + (C - y)) / (2 ** 0.5 * d)


def make_back():
    img = Image.new("RGBA", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            if dist(x, y) <= R_INNER:
                img.putpixel((x, y), (46, 22, 38, 255) if light(x, y) > -0.2 else (32, 14, 28, 255))
    return img


def make_fill():
    img = Image.new("RGBA", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            d = dist(x, y)
            if d > R_INNER:
                continue
            l = light(x, y) * (d / R_INNER)
            if l > 0.45:
                col = (236, 64, 72)
            elif l > 0.05:
                col = (204, 34, 52)
            elif l > -0.45:
                col = (160, 20, 44)
            else:
                col = (112, 12, 36)
            # Borde oscuro dentro del vidrio para dar volumen.
            if d > R_INNER - 1.2:
                col = tuple(int(c * 0.7) for c in col)
            img.putpixel((x, y), col + (255,))
    # Burbujas pequeñas.
    for bx, by in ((34, 36), (22, 40), (30, 43)):
        img.putpixel((bx, by), (250, 120, 120, 255))
    return img


def make_frame():
    img = Image.new("RGBA", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            d = dist(x, y)
            l = light(x, y)
            col = None
            if R_INNER < d <= R_INNER + 1.0:
                col = (40, 20, 24)                      # contorno interior
            elif R_INNER + 1.0 < d <= R_RING - 1.0:
                if l > 0.55:
                    col = (255, 226, 140)               # oro con luz
                elif l > -0.25:
                    col = (226, 168, 76)                # oro
                else:
                    col = (156, 98, 48)                 # oro en sombra
            elif R_RING - 1.0 < d <= R_RING + 0.4:
                col = (30, 14, 20)                      # contorno exterior
            if col:
                img.putpixel((x, y), col + (255,))
    # Brillo del vidrio: arco arriba a la izquierda y un destello.
    for y in range(SIZE):
        for x in range(SIZE):
            d = dist(x, y)
            ang = math.degrees(math.atan2(y - C, x - C))
            if R_INNER - 4.5 <= d <= R_INNER - 2.5 and -165 <= ang <= -110:
                img.putpixel((x, y), (255, 255, 255, 150))
    for px, py in ((19, 17), (18, 18), (19, 18), (20, 18), (19, 19)):
        img.putpixel((px, py), (255, 255, 255, 230))
    # Gema rosa del brazalete en la parte de abajo del anillo.
    gem = {
        (0, -2): (120, 30, 70), (-1, -1): (120, 30, 70), (0, -1): (255, 170, 210), (1, -1): (120, 30, 70),
        (-2, 0): (120, 30, 70), (-1, 0): (250, 110, 170), (0, 0): (236, 80, 150), (1, 0): (200, 50, 120), (2, 0): (120, 30, 70),
        (-1, 1): (120, 30, 70), (0, 1): (190, 50, 115), (1, 1): (120, 30, 70),
        (0, 2): (120, 30, 70),
    }
    gx, gy = int(round(C)), int(round(C + R_RING - 1))
    for (dx, dy), col in gem.items():
        if 0 <= gy + dy < SIZE:
            img.putpixel((gx + dx, gy + dy), col + (255,))
    return img


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    make_back().save(OUT / "orb_back.png")
    make_fill().save(OUT / "orb_fill.png")
    make_frame().save(OUT / "orb_frame.png")
    print("ok", OUT)
