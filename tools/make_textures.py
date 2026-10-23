#!/usr/bin/env python3
"""Procedural foliage/ground textures (alpha cards) for the PS2/PS3 jungle look."""
import numpy as np, random, math
from PIL import Image, ImageDraw, ImageFilter
OUT = "assets/textures/"; R = random.Random(4)
def pnoise(n, scale, seed):  # periodic (tileable) noise via FFT filtering
    rng = np.random.default_rng(seed); w = rng.standard_normal((n, n))
    f = np.fft.fft2(w); fx = np.fft.fftfreq(n)[:, None]; fy = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(fx**2 + fy**2) + 1e-6; f *= np.exp(-(k * scale) ** 2) / k**0.5
    a = np.real(np.fft.ifft2(f)); return (a - a.min()) / (a.max() - a.min())
def col(c, j=0.08): return tuple(int(max(0, min(255, v * 255 * (1 + R.uniform(-j, j))))) for v in c)
def save(img, name): img.save(OUT + name); print(name, img.size)

# 1) grass card
S = 512; im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
for i in range(140):
    x = R.uniform(10, S - 10); h = R.uniform(0.45, 0.98) * S; w = R.uniform(5, 11); lean = R.uniform(-0.25, 0.25) * h
    c = R.choice([(0.25, 0.38, 0.1), (0.33, 0.45, 0.14), (0.42, 0.48, 0.18), (0.2, 0.3, 0.08), (0.5, 0.5, 0.22)])
    pts = []
    for t in np.linspace(0, 1, 8):
        cx = x + lean * t * t; cy = S - t * h; ww = w * (1 - t) ** 0.8
        pts.append((cx - ww / 2, cy))
    for t in np.linspace(1, 0, 8):
        cx = x + lean * t * t; cy = S - t * h; ww = w * (1 - t) ** 0.8
        pts.append((cx + ww / 2, cy))
    d.polygon(pts, fill=col(c) + (255,))
save(im, "grass_card.png")

# 2) leaf cluster (tree canopy cards)
def leaf(d, cx, cy, L, W, ang, c, vein=True):
    pts = []
    for t in np.linspace(0, 1, 12):
        r = W * math.sin(math.pi * t) * (1 - 0.3 * t)
        pts.append((t * L, r))
    pts += [(t * L, -r) for (t, r) in [(p[0] / L, p[1]) for p in reversed(pts)]]
    ca, sa = math.cos(ang), math.sin(ang)
    P = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    d.polygon(P, fill=c + (255,))
    if vein: d.line([(cx, cy), (cx + L * ca, cy + L * sa)], fill=tuple(int(v * 0.75) for v in c) + (255,), width=1)
S = 512; im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
for i in range(1100):
    a = R.uniform(0, math.tau); r = (R.random() ** 0.6) * S * 0.46
    cx = S / 2 + math.cos(a) * r; cy = S / 2 + math.sin(a) * r * 0.8
    shade = 0.6 + 0.5 * (1 - r / (S * 0.46)) * R.uniform(0.7, 1.0)
    base = R.choice([(0.16, 0.32, 0.08), (0.22, 0.38, 0.1), (0.12, 0.26, 0.07), (0.3, 0.42, 0.12)])
    leaf(d, cx, cy, R.uniform(22, 40), R.uniform(7, 12), R.uniform(0, math.tau), col(tuple(v * shade for v in base)))
save(im, "leaf_cluster.png")

# 3) taro / elephant-ear leaf
S = 512; im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
pts = []
for t in np.linspace(0, math.tau, 80):
    r = 0.42 * S * (1 - 0.35 * math.sin(t) ** 8) * (0.9 + 0.1 * math.cos(2 * t))
    pts.append((S / 2 + r * math.sin(t) * 0.82, S * 0.08 + r * (1 - math.cos(t)) * 1.05))
d.polygon(pts, fill=(52, 98, 40, 255))
im2 = Image.new("RGBA", (S, S)); dd = ImageDraw.Draw(im2)
for k in range(-7, 8):
    dd.line([(S / 2, S * 0.2), (S / 2 + k * 30, S * 0.85 - abs(k) * 20)], fill=(110, 150, 70, 255), width=3)
dd.line([(S / 2, S * 0.08), (S / 2, S * 0.92)], fill=(130, 165, 80, 255), width=5)
mask = im.getchannel("A"); im.paste(im2, (0, 0), Image.composite(im2.getchannel("A"), Image.new("L", (S, S), 0), mask))
n = (pnoise(S, 12, 3) * 60 - 30).astype(np.int16); a = np.asarray(im).astype(np.int16); a[..., :3] = np.clip(a[..., :3] + n[..., None], 0, 255)
save(Image.fromarray(a.astype(np.uint8), "RGBA"), "taro_leaf.png")

# 4) fern frond / palm frond (pinnate)
def pinnate(W, H, leaflets, lw, c, name):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for i in range(leaflets):
        t = i / leaflets; y = H * (0.04 + 0.94 * t); L = W * 0.48 * math.sin(math.pi * (0.15 + 0.85 * t)) ** 0.7
        for s in (-1, 1):
            leaf(d, W / 2, y, L, lw * (1 - 0.5 * t) + 2, math.pi / 2 + s * (math.pi / 2 - 0.5), col(c), False)
    d.line([(W / 2, 0), (W / 2, H)], fill=(70, 80, 30, 255), width=4)
    save(im, name)
pinnate(256, 512, 34, 7, (0.24, 0.42, 0.12), "fern_frond.png")
pinnate(256, 1024, 60, 6, (0.3, 0.44, 0.14), "palm_frond.png")

# 5) ground: forest floor (grass + leaf litter), laterite, bark
S = 512
g = pnoise(S, 30, 1); h = pnoise(S, 6, 2); l = pnoise(S, 90, 5)
grass = np.stack([0.17 + 0.12 * h, 0.25 + 0.15 * h, 0.07 + 0.05 * h], -1)
litter = np.stack([0.32 + 0.12 * h, 0.24 + 0.08 * h, 0.12 + 0.05 * h], -1)
m = np.clip((g - 0.45) * 4, 0, 1)[..., None]
img = grass * (1 - m) + litter * m; img *= (0.75 + 0.4 * l)[..., None]
save(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)), "ground_forest.png")
soil = np.stack([0.5 + 0.14 * h, 0.22 + 0.08 * h, 0.11 + 0.05 * h], -1) * (0.7 + 0.45 * pnoise(S, 40, 9))[..., None]
pebble = (pnoise(S, 2.5, 11) > 0.72)[..., None] * 0.12
save(Image.fromarray((np.clip(soil + pebble, 0, 1) * 255).astype(np.uint8)), "ground_laterite.png")
S = 256; bx = pnoise(S, 3, 21); streak = np.tile(pnoise(S, 6, 22).mean(axis=0, keepdims=True), (S, 1))
bark = np.stack([0.33, 0.27, 0.2], -1)[None, None] * (0.55 + 0.5 * (0.6 * streak + 0.4 * bx))[..., None]
save(Image.fromarray((np.clip(bark, 0, 1) * 255).astype(np.uint8)), "bark.png")
