"""Generate the aged 1920s wallpapers for Carrie's house as tileable 1024 px PNGs.

Run inside Blender (it supplies numpy and the image I/O):
    blender --background --python tools/blender/carrie_house/wallpapers.py

Each image holds two pattern repeats each way and covers WALLPAPER_SIZE metres of wall. The
patterns are drawn here; the ageing (mottling, streaks and the paper normal map) comes from Poly
Haven's CC0 decrepit_wallpaper, which tiles at the same size. Output goes to
assets/local_licensed/carrie_house_textures/generated/, which build_carrie_house.py reads.
"""

from pathlib import Path

import bpy
import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[3]
TEXTURE_DIR = PROJECT_ROOT / "assets" / "local_licensed" / "carrie_house_textures"
GRIME = TEXTURE_DIR / "decrepit_wallpaper" / "decrepit_wallpaper_diff_1k.jpg"
OUT_DIR = TEXTURE_DIR / "generated"
SIZE = 1024
WALLPAPER_SIZE = 1.06       # metres per image: two 0.53 m (21 inch) pattern repeats
REPEATS = 2
AA = 1.5 / (SIZE / REPEATS)  # edge softness, in pattern-repeat units


def coords():
    """u right and v up across one pattern repeat, as [rows, cols] arrays; row 0 is the bottom,
    as in Blender's pixel order."""
    t = (np.arange(SIZE) + 0.5) / SIZE * REPEATS % 1.0
    return np.meshgrid(t, t)          # u varies along columns, v along rows


def fill(mask, colour, base):
    """Paint colour over base where mask (0..1) is set."""
    return base * (1.0 - mask[..., None]) + np.asarray(colour)[None, None, :] * mask[..., None]


def inside(distance):
    """Soft coverage from a signed distance (negative inside)."""
    return np.clip(0.5 - distance / AA, 0.0, 1.0)


def wrapped(d):
    return (d + 0.5) % 1.0 - 0.5


def blob(u, v, cx, cy, radius, petals=0, depth=0.0, turn=0.0):
    """Coverage of a disc, or a flower with petals lobes, centred at (cx, cy) in repeat units."""
    du, dv = wrapped(u - cx), wrapped(v - cy)
    r = np.hypot(du, dv)
    if petals:
        angle = np.arctan2(dv, du) + turn
        radius = radius * (1.0 - depth + depth * np.abs(np.cos(petals * angle / 2.0)))
    return inside(r - radius)


def ellipse(u, v, cx, cy, rx, ry, turn):
    du, dv = wrapped(u - cx), wrapped(v - cy)
    c, s = np.cos(turn), np.sin(turn)
    x, y = du * c + dv * s, -du * s + dv * c
    return inside((np.hypot(x / rx, y / ry) - 1.0) * min(rx, ry))


def stripe(u, v):
    """Parents' room: cream and faded sage stripes with dark pinstripes."""
    p = u * 5.0 % 1.0
    paper = np.empty(u.shape + (3,))
    paper[:] = (0.86, 0.82, 0.70)
    paper = fill(inside(np.abs(p - 0.775) - 0.21), (0.63, 0.67, 0.56), paper)
    for edge in (0.57, 0.98):
        paper = fill(inside(np.abs(wrapped(p - edge)) - 0.006), (0.44, 0.49, 0.41), paper)
    paper = fill(inside(np.abs(p - 0.28) - 0.004), (0.74, 0.70, 0.58), paper)
    return paper


def ogee(u, v):
    """Living room: an olive-gold ogee lattice in dark green with oxblood rosettes."""
    paper = np.empty(u.shape + (3,))
    paper[:] = (0.66, 0.60, 0.42)
    amplitude = 0.18
    slope = np.hypot(1.0, amplitude * 2.0 * np.pi * np.cos(2.0 * np.pi * v))
    for offset in (0.0, 0.5):
        for sign in (1.0, -1.0):
            curve = offset + sign * amplitude * np.sin(2.0 * np.pi * v)
            paper = fill(inside(np.abs(wrapped(u - curve)) / slope - 0.01), (0.30, 0.36, 0.26), paper)
    for cx, cy in ((0.25, 0.0), (0.75, 0.0), (0.25, 0.5), (0.75, 0.5)):
        paper = fill(blob(u, v, cx, cy, 0.085, petals=4, depth=0.45), (0.45, 0.20, 0.17), paper)
        paper = fill(blob(u, v, cx, cy, 0.03), (0.72, 0.62, 0.38), paper)
        paper = fill(blob(u, v, cx, cy, 0.012), (0.45, 0.20, 0.17), paper)
    for cx, cy in ((0.5, 0.25), (0.5, 0.75), (0.0, 0.25), (0.0, 0.75)):
        paper = fill(blob(u, v, cx, cy, 0.022, petals=4, depth=0.8, turn=np.pi / 4.0), (0.30, 0.36, 0.26), paper)
    return paper


def floral(u, v):
    """Carrie's room: dusty pink flowers and blue forget-me-nots on cream, half-drop."""
    paper = np.empty(u.shape + (3,))
    paper[:] = (0.88, 0.84, 0.74)
    rng = np.random.default_rng(7)
    for i in range(4):
        for j in range(4):
            cx, cy = (i + 0.5) / 4.0, (j + (0.5 if i % 2 else 0.0)) / 4.0
            turn = rng.uniform(0.0, 2.0 * np.pi)
            if (i + j) % 2 == 0:
                for side in (-1.0, 1.0):
                    leaf = turn + side * 0.7 - np.pi / 2.0
                    lx, ly = cx + 0.055 * np.cos(leaf), cy + 0.055 * np.sin(leaf)
                    paper = fill(ellipse(u, v, lx, ly, 0.028, 0.011, leaf), (0.50, 0.60, 0.42), paper)
                paper = fill(blob(u, v, cx, cy, 0.045, petals=5, depth=0.55, turn=turn), (0.80, 0.52, 0.55), paper)
                paper = fill(blob(u, v, cx, cy, 0.011), (0.86, 0.72, 0.36), paper)
            else:
                paper = fill(blob(u, v, cx, cy, 0.026, petals=5, depth=0.5, turn=turn), (0.55, 0.65, 0.80), paper)
                paper = fill(blob(u, v, cx, cy, 0.007), (0.92, 0.88, 0.70), paper)
    return paper


def medallion(u, v):
    """Dining room: gold quatrefoils on deep red-brown, small dots between."""
    paper = np.empty(u.shape + (3,))
    paper[:] = (0.40, 0.22, 0.19)
    gold = (0.72, 0.60, 0.36)
    for i in range(3):
        for j in range(3):
            cx, cy = (i + 0.5) / 3.0, (j + 0.5) / 3.0
            for dx, dy in ((0.035, 0.0), (-0.035, 0.0), (0.0, 0.035), (0.0, -0.035)):
                paper = fill(blob(u, v, cx + dx, cy + dy, 0.032), gold, paper)
            paper = fill(blob(u, v, cx, cy, 0.022), (0.40, 0.22, 0.19), paper)
            paper = fill(blob(u, v, cx, cy, 0.009), gold, paper)
            paper = fill(blob(u, v, cx + 1.0 / 6.0, cy + 1.0 / 6.0, 0.008), gold, paper)
    return paper


def diamond(u, v):
    """Hall and landing: a fine grey-green diamond trellis with rust dots."""
    paper = np.empty(u.shape + (3,))
    paper[:] = (0.68, 0.70, 0.62)
    cells = 6.0
    for d in ((u + v) * cells, (u - v) * cells):
        paper = fill(inside(np.abs(wrapped(d)) / cells / np.sqrt(2.0) - 0.0035), (0.42, 0.45, 0.40), paper)
    for k in range(int(cells)):
        for m in range(int(cells)):
            paper = fill(blob(u, v, (k + 0.5) / cells, m / cells, 0.012), (0.55, 0.40, 0.32), paper)
    return paper


PATTERNS = {"stripe": stripe, "ogee": ogee, "floral": floral, "medallion": medallion, "diamond": diamond}
# How worn each paper is (0..1): Carrie's room is the worst.
WEAR = {"stripe": 0.6, "ogee": 0.75, "floral": 1.0, "medallion": 0.6, "diamond": 0.8}


def periodic_noise(cells: int, rng) -> np.ndarray:
    """Smooth value noise that tiles across the whole image."""
    grid = rng.random((cells, cells))
    t = np.arange(SIZE) * cells / SIZE
    i0 = np.floor(t).astype(int)
    i1 = (i0 + 1) % cells
    f = t - i0
    f = f * f * (3.0 - 2.0 * f)
    fu, fv = f[None, :], f[:, None]
    low = grid[i0][:, i0] * (1.0 - fu) + grid[i0][:, i1] * fu
    high = grid[i1][:, i0] * (1.0 - fu) + grid[i1][:, i1] * fu
    return low * (1.0 - fv) + high * fv


def load_rgb(path: Path) -> np.ndarray:
    image = bpy.data.images.load(str(path))
    pixels = np.empty(image.size[0] * image.size[1] * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    rgb = pixels.reshape(image.size[1], image.size[0], 4)[..., :3]
    bpy.data.images.remove(image)
    return rgb


def age(paper: np.ndarray, grime: np.ndarray, seed: int, wear: float) -> np.ndarray:
    """Yellowing, mottling and streaks from the grime map, and a few water stains."""
    lum = grime @ np.array([0.299, 0.587, 0.114])
    g = (lum - lum.mean()) / (lum.std() + 1e-6)
    paper = paper * np.clip(1.0 + 0.10 * g, 0.75, 1.15)[..., None]
    streak = np.clip(-g - 1.0, 0.0, 1.6) / 1.6
    paper = paper * (1.0 - 0.22 * wear * streak)[..., None]
    paper = paper * (1.0 - 0.35) + paper * np.array([0.95, 0.87, 0.70]) * 0.35
    rng = np.random.default_rng(seed)
    noise = periodic_noise(6, rng) * 0.6 + periodic_noise(13, rng) * 0.4
    blotch = np.clip((noise - 0.66) / 0.14, 0.0, 1.0) * 0.35 * wear
    ring = np.clip(1.0 - np.abs(noise - 0.69) / 0.02, 0.0, 1.0)
    paper = paper * (1.0 - blotch[..., None]) + paper * np.array([0.80, 0.68, 0.50]) * blotch[..., None]
    paper = paper * (1.0 - 0.15 * wear * ring)[..., None]
    grey = paper.mean(axis=2, keepdims=True)
    return np.clip(paper * 0.85 + grey * 0.15, 0.0, 1.0)


def save_rgb(rgb: np.ndarray, path: Path) -> None:
    image = bpy.data.images.new(path.stem, SIZE, SIZE, alpha=False)
    rgba = np.ones((SIZE, SIZE, 4), dtype=np.float32)
    rgba[..., :3] = rgb
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def generate() -> list:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    grime = load_rgb(GRIME)
    u, v = coords()
    written = []
    for seed, (name, pattern) in enumerate(PATTERNS.items()):
        path = OUT_DIR / f"wallpaper_{name}_1k.png"
        save_rgb(age(pattern(u, v), grime, seed, WEAR[name]), path)
        written.append(path.name)
    return written


if __name__ == "__main__":
    print("wallpapers:", generate())
