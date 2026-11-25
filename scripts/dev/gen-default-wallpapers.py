#!/usr/bin/env python3
"""Генерирует три стандартных обоя Northling Midnight (1920x1080).
Зависимость: Pillow. Запуск: python3 gen-default-wallpapers.py <папка-вывода>
Это воспроизводимый источник дефолтных обоев — оригинальные, без чужих картинок."""
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 1920, 1080
BASE   = (14, 10, 36)     # #0E0A24
INDIGO = (28, 17, 85)     # #1C1155
VIOLET = (52, 38, 118)    # #342676
LAV    = (167, 139, 250)  # #A78BFA
SKY    = (130, 191, 255)  # #82BFFF
PINK   = (210, 132, 229)  # #D284E5

def vgrad(top, bottom):
    im = Image.new("RGB", (W, H)); px = im.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W): px[x, y] = c
    return im

def glow(im, cx, cy, rx, ry, color, alpha, blur):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    im.paste(layer, (0, 0), layer)

def stars(im, rnd, n, maxr=2.2):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.uniform(0.6, maxr)
        a = rnd.randrange(60, 200); c = rnd.choice([(229, 231, 245), SKY, LAV])
        d.ellipse((x - r, y - r, x + r, y + r), fill=c + (a,))
    im.paste(layer, (0, 0), layer)

def sparkle(im, x, y, s, color, alpha=230):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    pts = []
    for i in range(8):
        a = math.pi / 4 * i; r = s if i % 2 == 0 else s * 0.18
        pts.append((x + r * math.cos(a - math.pi / 2), y + r * math.sin(a - math.pi / 2)))
    d.polygon(pts, fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    im.paste(layer, (0, 0), layer)

def bubble(im, x, y, r, color):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.ellipse((x - r, y - r, x + r, y + r), fill=color + (28,), outline=(229, 231, 245, 90), width=2)
    d.ellipse((x - r * .55, y - r * .6, x - r * .15, y - r * .3), fill=(255, 255, 255, 70))
    layer = layer.filter(ImageFilter.GaussianBlur(0.8))
    im.paste(layer, (0, 0), layer)

def dotgrid(im, step=14, alpha=16):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    for y in range(0, H, step):
        for x in range(0, W, step):
            d.ellipse((x, y, x + 1.6, y + 1.6), fill=(229, 231, 245, alpha))
    im.paste(layer, (0, 0), layer)

def vignette(im, strength=150):
    layer = Image.new("L", (W, H), 0); d = ImageDraw.Draw(layer)
    d.ellipse((-W * .25, -H * .35, W * 1.25, H * 1.35), fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new("RGB", (W, H), (6, 4, 18))
    mask = layer.point(lambda v: 255 - v)
    mask = mask.point(lambda v: int(v * strength / 255))
    im.paste(dark, (0, 0), mask)

def wall_glow(out):
    rnd = random.Random(11); im = vgrad(BASE, INDIGO)
    glow(im, 360, 900, 700, 420, LAV, 120, 190)
    glow(im, 1620, 160, 620, 340, SKY, 95, 190)
    glow(im, 1100, 1000, 520, 220, PINK, 60, 170)
    stars(im, rnd, 220); dotgrid(im)
    for (x, y, s, c) in [(300, 220, 26, SKY), (1510, 700, 20, PINK), (1740, 330, 30, LAV), (820, 140, 16, (229, 231, 245))]:
        sparkle(im, x, y, s, c)
    vignette(im); im.save(out, optimize=True)

def wall_bubbles(out):
    rnd = random.Random(23); im = vgrad(BASE, VIOLET)
    glow(im, 960, 1180, 1100, 420, LAV, 110, 200)
    glow(im, 200, 200, 520, 320, SKY, 70, 190)
    dotgrid(im, 14, 14)
    for _ in range(16):
        r = rnd.randrange(22, 110)
        bubble(im, rnd.randrange(60, W - 60), rnd.randrange(60, H - 60), r, rnd.choice([LAV, SKY, PINK]))
    stars(im, rnd, 90, 1.8)
    sparkle(im, 1650, 220, 28, PINK); sparkle(im, 260, 820, 24, SKY)
    vignette(im); im.save(out, optimize=True)

def wall_aurora(out):
    rnd = random.Random(37); base = vgrad(BASE, INDIGO)
    band = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(band)
    for i, (col, a) in enumerate([(LAV, 120), (SKY, 90), (PINK, 80)]):
        off = i * 150
        d.polygon([(-200, 820 - off), (700, 420 - off), (1500, 560 - off), (2200, 160 - off),
                   (2200, 330 - off), (1500, 760 - off), (700, 640 - off), (-200, 1020 - off)], fill=col + (a,))
    band = band.filter(ImageFilter.GaussianBlur(95))
    base.paste(band, (0, 0), band)
    stars(base, rnd, 260, 2.0); dotgrid(base, 16, 10)
    sparkle(base, 1450, 190, 24, SKY); sparkle(base, 420, 260, 20, LAV)
    vignette(base, 170); base.save(out, optimize=True)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    wall_glow(f"{out}/01-midnight-glow.png")
    wall_bubbles(f"{out}/02-midnight-bubbles.png")
    wall_aurora(f"{out}/03-midnight-aurora.png")
