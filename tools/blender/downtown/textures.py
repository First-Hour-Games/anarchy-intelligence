"""Paint the downtown's generated textures into models/buildings/downtown/textures/.

Run inside Blender (it supplies numpy and the image I/O):
    blender --background --python tools/blender/downtown/textures.py

- rooms.png: 4 x 4 rooms seen through a window, one 256 px back wall each. The window shader
  (shaders/window_interior.gdshader) draws the side walls from the edge columns, and the floor and
  ceiling from the bottom and top rows, so each room is one picture. See ROOMS.
- overlays.png: 4 x 4 things hung or stuck behind the glass (curtains, blinds, boards, whitewash),
  with alpha. See OVERLAYS.
- palette.png: flat colours in 16 px cells for every painted part (frames, trim, metal, enamel) and,
  through the Glow material, every lit one. See PALETTE.
- fabric.png: eight bands of awning stripes, plus a barber pole. See FABRICS.
- limestone.png: ashlar blocks over ambientCG's CC0 Concrete012, LIMESTONE_TILE metres a repeat.
- brick_painted.png and brick_buff.png: Poly Haven's CC0 brick_wall_02 (the brick of Carrie's
  house) painted cream with the paint worn off in patches, and recoloured as buff brick.
"""

from pathlib import Path

import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = PROJECT_ROOT / "models" / "buildings" / "downtown" / "textures"
CONCRETE = PROJECT_ROOT / "assets" / "local_licensed" / "materials" / "concrete012" / "Concrete012_Color.jpg"
BRICK = PROJECT_ROOT / "assets" / "local_licensed" / "carrie_house_textures" / "brick_wall_02" / "brick_wall_02_diff_1k.jpg"
CELL = 256                  # px per room or overlay
GRID = 4                    # rooms and overlays per row and column
PALETTE_CELL = 16
PALETTE_GRID = 16
LIMESTONE_TILE = (2.0, 1.8)     # metres across and up per repeat
FABRIC_PERIOD = 0.9             # metres per pair of stripes on an awning
FABRIC_REPEATS = 8              # stripe pairs across the image

# Room index -> what the room is. The builder picks rooms by these names; lit rooms glow.
ROOMS = ["living", "bedroom", "kitchen", "empty", "office", "hotel_room", "hall", "storage",
         "living_green", "bedroom_blue", "lit_living", "lit_kitchen", "shop", "service", "vacant_shop", "lobby"]
LIT_ROOMS = {"lit_living", "lit_kitchen"}
OVERLAYS = ["clear", "curtains", "curtains_open", "nets", "blinds", "blinds_half", "shade", "boarded",
            "cracked", "grime", "whitewash", "newspaper", "notice", "curtains_red", "blinds_broken", "dust"]

# Flat colours (sRGB) by name; the cell order is the order here.
PALETTE = {
    "FrameDark": (0.10, 0.11, 0.11), "FrameGreen": (0.11, 0.20, 0.15), "FrameRed": (0.30, 0.09, 0.08),
    "FrameCream": (0.80, 0.76, 0.64), "FrameBlack": (0.04, 0.04, 0.045), "Stone": (0.66, 0.63, 0.56),
    "StoneDark": (0.48, 0.46, 0.41), "Cornice": (0.30, 0.28, 0.25), "CorniceGreen": (0.18, 0.24, 0.20),
    "Tar": (0.11, 0.11, 0.115), "RoofEdge": (0.34, 0.33, 0.31), "SignBlack": (0.06, 0.07, 0.08),
    "SignGreen": (0.07, 0.19, 0.13), "SignMaroon": (0.24, 0.07, 0.07), "SignNavy": (0.07, 0.10, 0.19),
    "SignCream": (0.84, 0.79, 0.65), "DoorWood": (0.24, 0.14, 0.08), "DoorGreen": (0.10, 0.19, 0.14),
    "Iron": (0.08, 0.08, 0.09), "Steel": (0.42, 0.44, 0.46), "Chrome": (0.70, 0.72, 0.74),
    "Enamel": (0.84, 0.81, 0.72), "EnamelRed": (0.58, 0.11, 0.09), "TankWood": (0.32, 0.23, 0.16),
    "TankBand": (0.11, 0.10, 0.09), "Concrete": (0.53, 0.52, 0.49), "Kerb": (0.60, 0.59, 0.56),
    "LineWhite": (0.84, 0.83, 0.79), "LineYellow": (0.78, 0.62, 0.18), "Plywood": (0.52, 0.42, 0.30),
    "GhostPanel": (0.47, 0.37, 0.30), "Buff": (0.62, 0.53, 0.38), "SignalYellow": (0.72, 0.56, 0.10),
    "Rubber": (0.05, 0.05, 0.05), "Grate": (0.13, 0.13, 0.12), "Soil": (0.16, 0.12, 0.09),
    "Bark": (0.20, 0.17, 0.14), "Meter": (0.25, 0.29, 0.27), "NewsBlue": (0.12, 0.22, 0.42),
    "NewsRed": (0.50, 0.10, 0.08), "NewsYellow": (0.70, 0.58, 0.14), "Canvas": (0.40, 0.37, 0.31),
    "Brass": (0.52, 0.40, 0.18), "Mirror": (0.55, 0.60, 0.62),
    # Lit colours, used through the Glow material.
    "NeonPink": (1.0, 0.36, 0.62), "NeonRed": (1.0, 0.24, 0.18), "NeonTeal": (0.30, 0.95, 0.85),
    "NeonBlue": (0.35, 0.55, 1.0), "BulbWarm": (1.0, 0.82, 0.45), "LampWarm": (1.0, 0.74, 0.42),
    "PoliceBlue": (0.40, 0.62, 1.0), "MarqueeBoard": (0.95, 0.90, 0.74), "ClockFace": (0.92, 0.88, 0.74),
    "PosterA": (0.62, 0.30, 0.34), "PosterB": (0.30, 0.42, 0.58), "LensAmber": (1.0, 0.62, 0.10),
    "LensRed": (1.0, 0.12, 0.08), "LensDark": (0.10, 0.08, 0.05), "StarGold": (1.0, 0.82, 0.35),
    "SignLight": (0.98, 0.95, 0.85),
}
# Awning fabric bands, top to bottom: (stripe colour, ground colour). The last band is the barber pole.
FABRICS = {
    "AwningGreen": ((0.16, 0.33, 0.22), (0.80, 0.77, 0.66)), "AwningBlue": ((0.15, 0.27, 0.45), (0.82, 0.82, 0.78)),
    "AwningRed": ((0.52, 0.12, 0.10), (0.84, 0.80, 0.70)), "AwningOchre": ((0.62, 0.44, 0.14), (0.40, 0.25, 0.12)),
    "AwningNavy": ((0.10, 0.13, 0.27), (0.78, 0.74, 0.62)), "AwningTeal": ((0.12, 0.40, 0.40), (0.84, 0.82, 0.76)),
    "AwningPlain": ((0.20, 0.27, 0.22), (0.20, 0.27, 0.22)), "BarberPole": ((0.62, 0.08, 0.08), (0.88, 0.86, 0.82)),
}


def palette_uv(name: str) -> tuple:
    """UV (Blender's, v up) of the middle of a palette colour's cell."""
    index = list(PALETTE).index(name)
    col, row = index % PALETTE_GRID, index // PALETTE_GRID
    return (col + 0.5) / PALETTE_GRID, 1.0 - (row + 0.5) / PALETTE_GRID


def fabric_v(name: str) -> tuple:
    """(v bottom, v top) of a fabric band, Blender's v up, a little inside the band."""
    index = list(FABRICS).index(name)
    band = 1.0 / len(FABRICS)
    top = 1.0 - index * band
    return top - band + band * 0.2, top - band * 0.2


# --- Painting helpers (arrays are [row, col, channel], row 0 at the top) ---------------------------

def canvas(height: int, width: int, colour, alpha: bool = False):
    channels = 4 if alpha else 3
    image = np.empty((height, width, channels), dtype=np.float32)
    image[...] = (*colour, 0.0) if alpha else colour
    return image


def box(image, x0, y0, x1, y1, colour, cover=1.0):
    """Fill pixels [y0:y1, x0:x1] (fractions of the image) with colour, mixed by cover."""
    h, w = image.shape[:2]
    r0, r1 = int(round(y0 * h)), int(round(y1 * h))
    c0, c1 = int(round(x0 * w)), int(round(x1 * w))
    if r1 <= r0 or c1 <= c0:
        return
    colour = np.asarray(colour, dtype=np.float32)
    region = image[r0:r1, c0:c1]
    if image.shape[2] == 4 and colour.shape[0] == 3:
        colour = np.append(colour, 1.0)
    region[...] = region * (1.0 - cover) + colour * cover


def noise(shape, seed: int, scale: int = 8):
    """Smooth value noise in 0..1, blocky at `scale` px then blurred by bilinear upsampling."""
    rng = np.random.default_rng(seed)
    h, w = shape
    coarse = rng.random((h // scale + 2, w // scale + 2)).astype(np.float32)
    ys = np.linspace(0, h / scale, h, endpoint=False)
    xs = np.linspace(0, w / scale, w, endpoint=False)
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    a = coarse[y0][:, x0]
    b = coarse[y0][:, x0 + 1]
    c = coarse[y0 + 1][:, x0]
    d = coarse[y0 + 1][:, x0 + 1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def mottle(image, seed: int, amount: float, scale: int = 16):
    n = noise(image.shape[:2], seed, scale)
    image[..., :3] *= (1.0 - amount + amount * 2.0 * n)[..., None]


def wallpaper(image, base, ink, kind: str, seed: int):
    """Wall pattern over the whole cell; furniture is painted on top afterwards."""
    h, w = image.shape[:2]
    image[..., :3] = base
    ys, xs = np.mgrid[0:h, 0:w]
    if kind == "stripe":
        mask = ((xs // 10) % 3 == 0)
        image[mask, :3] = image[mask, :3] * 0.6 + np.asarray(ink) * 0.4
    elif kind == "dots":
        mask = ((xs % 22 < 4) & (ys % 22 < 4)) | (((xs + 11) % 22 < 4) & ((ys + 11) % 22 < 4))
        image[mask, :3] = image[mask, :3] * 0.5 + np.asarray(ink) * 0.5
    elif kind == "tiles":
        mask = (xs % 18 < 1) | (ys % 18 < 1)
        image[mask, :3] = ink
    mottle(image, seed, 0.12)


def room_frame(image, floor, ceiling, skirting=(0.18, 0.14, 0.10)):
    """Ceiling along the top, floor along the bottom, a skirting board above the floor."""
    box(image, 0, 0, 1, 0.07, ceiling)
    box(image, 0, 0.82, 1, 1, floor)
    box(image, 0, 0.80, 1, 0.82, skirting)


def lamp_glow(image, cx, cy, radius, colour, strength):
    h, w = image.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.hypot(xs / w - cx, ys / h - cy) / radius
    glow = np.clip(1.0 - d, 0.0, 1.0) ** 2 * strength
    image[..., :3] = image[..., :3] + glow[..., None] * np.asarray(colour)


def paint_room(name: str, seed: int):
    image = canvas(CELL, CELL, (0.5, 0.5, 0.5))
    dark_wood = (0.20, 0.13, 0.08)
    if name in ("living", "lit_living"):
        wallpaper(image, (0.55, 0.47, 0.34), (0.35, 0.26, 0.18), "dots", seed)
        room_frame(image, (0.30, 0.20, 0.12), (0.62, 0.58, 0.50))
        box(image, 0.12, 0.60, 0.62, 0.82, (0.30, 0.22, 0.20))          # sofa
        box(image, 0.12, 0.54, 0.62, 0.62, (0.36, 0.27, 0.24))
        box(image, 0.30, 0.22, 0.48, 0.40, (0.22, 0.17, 0.12))          # picture
        box(image, 0.32, 0.24, 0.46, 0.38, (0.42, 0.46, 0.40))
        box(image, 0.74, 0.30, 0.90, 0.82, dark_wood)                   # cabinet
        box(image, 0.70, 0.36, 0.73, 0.82, (0.12, 0.09, 0.06))          # door edge
        if name == "lit_living":
            box(image, 0.66, 0.42, 0.70, 0.60, (0.25, 0.20, 0.12))      # lamp stand
            box(image, 0.62, 0.34, 0.74, 0.43, (0.95, 0.80, 0.52))      # shade
            image *= 1.35
            lamp_glow(image, 0.68, 0.40, 0.55, (0.55, 0.36, 0.14), 0.9)
    elif name in ("bedroom", "bedroom_blue"):
        base, ink = ((0.58, 0.55, 0.44), (0.42, 0.40, 0.30)) if name == "bedroom" else ((0.36, 0.42, 0.50), (0.26, 0.30, 0.38))
        wallpaper(image, base, ink, "stripe", seed)
        room_frame(image, (0.27, 0.18, 0.11), (0.66, 0.62, 0.55))
        box(image, 0.10, 0.62, 0.60, 0.82, (0.70, 0.66, 0.58))          # bed
        box(image, 0.10, 0.48, 0.16, 0.82, dark_wood)                   # headboard
        box(image, 0.70, 0.40, 0.88, 0.82, dark_wood)                   # dresser
        box(image, 0.72, 0.22, 0.86, 0.38, (0.45, 0.50, 0.52))          # mirror
    elif name in ("kitchen", "lit_kitchen"):
        wallpaper(image, (0.66, 0.68, 0.60), (0.48, 0.50, 0.44), "tiles", seed)
        room_frame(image, (0.30, 0.30, 0.28), (0.70, 0.70, 0.66))
        box(image, 0.05, 0.56, 0.70, 0.82, (0.62, 0.62, 0.56))          # counter
        box(image, 0.05, 0.53, 0.70, 0.57, (0.30, 0.28, 0.24))
        box(image, 0.08, 0.20, 0.50, 0.36, (0.60, 0.58, 0.50))          # wall cabinets
        box(image, 0.76, 0.28, 0.94, 0.82, (0.80, 0.80, 0.76))          # fridge
        if name == "lit_kitchen":
            image *= 1.3
            box(image, 0.30, 0.07, 0.60, 0.10, (1.0, 1.0, 0.92))        # tube light
            lamp_glow(image, 0.45, 0.10, 0.8, (0.30, 0.42, 0.34), 0.7)
    elif name == "empty":
        wallpaper(image, (0.50, 0.48, 0.42), (0.40, 0.38, 0.33), "plain", seed)
        mottle(image, seed + 1, 0.25, 32)
        room_frame(image, (0.28, 0.22, 0.16), (0.55, 0.53, 0.48))
        box(image, 0.60, 0.30, 0.80, 0.82, (0.10, 0.09, 0.08))          # open doorway
    elif name == "office":
        wallpaper(image, (0.52, 0.58, 0.50), (0.40, 0.45, 0.39), "plain", seed)
        room_frame(image, (0.25, 0.24, 0.22), (0.70, 0.70, 0.66))
        for i in range(3):                                              # filing cabinets
            box(image, 0.08 + i * 0.12, 0.42, 0.18 + i * 0.12, 0.82, (0.40, 0.42, 0.40))
            for j in range(3):
                box(image, 0.11 + i * 0.12, 0.47 + j * 0.12, 0.15 + i * 0.12, 0.49 + j * 0.12, (0.20, 0.20, 0.20))
        box(image, 0.52, 0.60, 0.92, 0.66, dark_wood)                   # desk
        box(image, 0.55, 0.66, 0.58, 0.82, dark_wood)
        box(image, 0.86, 0.66, 0.89, 0.82, dark_wood)
        box(image, 0.60, 0.20, 0.84, 0.40, (0.75, 0.74, 0.66))          # notice board
    elif name == "hotel_room":
        wallpaper(image, (0.48, 0.30, 0.26), (0.36, 0.22, 0.19), "dots", seed)
        room_frame(image, (0.22, 0.12, 0.12), (0.60, 0.55, 0.48))
        box(image, 0.25, 0.64, 0.80, 0.82, (0.68, 0.64, 0.56))          # bed
        box(image, 0.25, 0.50, 0.30, 0.82, dark_wood)
        box(image, 0.04, 0.34, 0.18, 0.82, dark_wood)                   # wardrobe
        box(image, 0.84, 0.55, 0.96, 0.64, dark_wood)                   # nightstand
    elif name == "hall":
        wallpaper(image, (0.56, 0.52, 0.44), (0.44, 0.40, 0.34), "plain", seed)
        room_frame(image, (0.24, 0.17, 0.11), (0.60, 0.57, 0.50))
        for i in range(6):                                              # stairs climbing to the right
            box(image, 0.45 + i * 0.08, 0.76 - i * 0.07, 1.0, 0.82 - i * 0.07, (0.30, 0.21, 0.14))
        box(image, 0.10, 0.32, 0.26, 0.82, (0.22, 0.15, 0.10))          # door
    elif name == "storage":
        wallpaper(image, (0.42, 0.40, 0.36), (0.32, 0.30, 0.27), "plain", seed)
        room_frame(image, (0.24, 0.22, 0.20), (0.45, 0.44, 0.40))
        rng = np.random.default_rng(seed)
        for _ in range(9):
            x = rng.uniform(0.0, 0.8)
            y = rng.uniform(0.40, 0.70)
            box(image, x, y, x + rng.uniform(0.12, 0.22), 0.82, (0.42 + rng.uniform(-0.06, 0.06), 0.32, 0.20))
    elif name == "living_green":
        wallpaper(image, (0.26, 0.34, 0.28), (0.18, 0.25, 0.20), "stripe", seed)
        room_frame(image, (0.26, 0.18, 0.12), (0.58, 0.56, 0.50))
        box(image, 0.05, 0.18, 0.40, 0.82, dark_wood)                   # bookshelf
        rng = np.random.default_rng(seed)
        for shelf in range(4):
            y = 0.24 + shelf * 0.14
            x = 0.07
            while x < 0.37:
                wide = rng.uniform(0.012, 0.03)
                box(image, x, y, x + wide, y + 0.10, (rng.uniform(0.2, 0.6), rng.uniform(0.15, 0.4), rng.uniform(0.1, 0.3)))
                x += wide + 0.004
        box(image, 0.55, 0.58, 0.90, 0.82, (0.38, 0.30, 0.22))          # armchair
    elif name in ("shop", "service", "vacant_shop"):
        wallpaper(image, (0.62, 0.60, 0.52), (0.50, 0.48, 0.42), "plain", seed)
        room_frame(image, (0.36, 0.34, 0.30), (0.72, 0.72, 0.68))
        rng = np.random.default_rng(seed)
        if name == "shop":
            for shelf in range(4):                                      # shelves of goods
                y = 0.26 + shelf * 0.13
                box(image, 0.05, y + 0.10, 0.95, y + 0.115, (0.30, 0.24, 0.18))
                x = 0.06
                while x < 0.93:
                    wide = rng.uniform(0.02, 0.05)
                    if rng.random() < 0.75:
                        box(image, x, y + rng.uniform(0.02, 0.05), x + wide, y + 0.10,
                            (rng.uniform(0.3, 0.8), rng.uniform(0.2, 0.7), rng.uniform(0.15, 0.6)))
                    x += wide + 0.008
            box(image, 0.20, 0.66, 0.80, 0.82, (0.40, 0.30, 0.20))      # counter
        elif name == "service":
            for i in range(4):                                          # machines or chairs along the wall
                box(image, 0.06 + i * 0.23, 0.50, 0.24 + i * 0.23, 0.82, (0.78, 0.78, 0.74))
                box(image, 0.10 + i * 0.23, 0.56, 0.20 + i * 0.23, 0.70, (0.16, 0.18, 0.20))
            box(image, 0.06, 0.18, 0.94, 0.30, (0.50, 0.55, 0.56))      # mirror or sign strip
        else:
            for _ in range(5):                                          # empty fixtures, papers
                x = rng.uniform(0.05, 0.8)
                box(image, x, 0.40, x + 0.10, 0.82, (0.40, 0.38, 0.34))
            for _ in range(30):
                x, y = rng.uniform(0.0, 0.95), rng.uniform(0.84, 0.98)
                box(image, x, y, x + 0.04, y + 0.015, (0.75, 0.73, 0.66))
            mottle(image, seed + 3, 0.2, 32)
    elif name == "lobby":
        wallpaper(image, (0.66, 0.62, 0.52), (0.54, 0.50, 0.42), "plain", seed)
        room_frame(image, (0.52, 0.48, 0.40), (0.76, 0.72, 0.62))
        ys, xs = np.mgrid[0:CELL, 0:CELL]
        checks = (((xs // 16) + (ys // 16)) % 2 == 0) & (ys > CELL * 0.82)
        image[checks, :3] *= 0.6                                        # chequered floor
        for x in (0.15, 0.45, 0.75):                                    # columns
            box(image, x, 0.07, x + 0.10, 0.82, (0.74, 0.70, 0.60))
            box(image, x - 0.01, 0.07, x + 0.11, 0.11, (0.62, 0.58, 0.50))
        box(image, 0.28, 0.62, 0.70, 0.82, (0.34, 0.24, 0.15))          # counter
    mottle(image, seed + 7, 0.08, 8)
    return np.clip(image, 0.0, 1.0)


def paint_overlay(name: str, seed: int):
    image = canvas(CELL, CELL, (0.0, 0.0, 0.0), alpha=True)
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:CELL, 0:CELL] / CELL
    if name in ("curtains", "curtains_open", "curtains_red"):
        colour = (0.62, 0.55, 0.42) if name != "curtains_red" else (0.40, 0.10, 0.10)
        folds = 0.82 + 0.18 * np.cos(xs * 2 * np.pi * 9)
        if name == "curtains_open":
            cover = (xs < 0.2) | (xs > 0.8)
        else:
            cover = np.abs(xs - 0.5) > 0.012
        image[..., :3] = np.asarray(colour) * folds[..., None]
        image[..., 3] = np.where(cover, 0.97, 0.0)
        box(image, 0, 0, 1, 0.04, (0.20, 0.15, 0.10))                  # rail
    elif name == "nets":
        image[..., :3] = (0.86, 0.85, 0.80)
        image[..., 3] = 0.55 + 0.1 * np.cos(xs * 2 * np.pi * 14)
    elif name in ("blinds", "blinds_half", "blinds_broken"):
        slats = (ys * 40 % 1.0) < 0.82
        image[..., :3] = (0.78, 0.76, 0.68) * (0.85 + 0.15 * (ys * 40 % 1.0))[..., None]
        reach = 1.0 if name != "blinds_half" else 0.5
        image[..., 3] = np.where(slats & (ys < reach), 0.98, 0.0)
        if name == "blinds_broken":
            image[(ys > 0.45) & (ys < 0.62) & (xs > 0.35), 3] = 0.0
        box(image, 0, reach - 0.03 if reach < 1 else 0.97, 1, reach if reach < 1 else 1.0, (0.55, 0.53, 0.47))
    elif name == "shade":
        image[..., :3] = (0.70, 0.64, 0.50)
        image[..., 3] = np.where(ys < 0.66, 0.96, 0.0)
        box(image, 0.47, 0.66, 0.53, 0.69, (0.30, 0.26, 0.20))         # pull
    elif name == "boarded":
        for i in range(5):
            tone = 0.42 + rng.uniform(-0.06, 0.06)
            box(image, 0, i * 0.2, 1, i * 0.2 + 0.195, (tone * 1.25, tone, tone * 0.72))
        mottle(image, seed, 0.25, 16)
        image[..., 3] = 1.0
        for i in range(5):
            for x in (0.06, 0.94):
                box(image, x - 0.01, i * 0.2 + 0.09, x + 0.01, i * 0.2 + 0.11, (0.12, 0.10, 0.08))
    elif name == "cracked":
        for _ in range(7):
            angle, x, y = rng.uniform(0, np.pi), rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8)
            t = np.linspace(-0.6, 0.6, 400)
            px = np.clip(((x + t * np.cos(angle)) * CELL).astype(int), 0, CELL - 1)
            py = np.clip(((y + t * np.sin(angle)) * CELL).astype(int), 0, CELL - 1)
            image[py, px, :3] = (0.85, 0.88, 0.88)
            image[py, px, 3] = 0.8
        hole = np.hypot(xs - 0.62, ys - 0.38) < 0.09
        image[hole, :3] = 0.0
        image[hole, 3] = 0.9
    elif name in ("grime", "dust"):
        n = noise((CELL, CELL), seed, 12)
        image[..., :3] = (0.30, 0.28, 0.22)
        image[..., 3] = np.clip(n * (0.55 if name == "grime" else 0.3) + ys * 0.25, 0.0, 0.8)
    elif name == "whitewash":
        n = noise((CELL, CELL), seed, 6)
        strokes = np.abs(np.sin((xs * 6 + ys * 2 + n * 0.6) * np.pi))
        image[..., :3] = (0.86, 0.85, 0.80)
        image[..., 3] = np.clip(0.55 + 0.35 * strokes - 0.25 * (ys < 0.12), 0.0, 0.93)
    elif name == "newspaper":
        for _ in range(6):
            x, y = rng.uniform(0.0, 0.7), rng.uniform(0.0, 0.7)
            box(image, x, y, x + 0.32, y + 0.30, (0.78, 0.74, 0.60))
            for line in range(8):
                box(image, x + 0.02, y + 0.04 + line * 0.03, x + 0.30, y + 0.05 + line * 0.03, (0.40, 0.38, 0.32))
    elif name == "notice":
        box(image, 0.25, 0.30, 0.75, 0.62, (0.92, 0.90, 0.84))
        box(image, 0.30, 0.34, 0.70, 0.40, (0.70, 0.12, 0.10))
        for line in range(5):
            box(image, 0.30, 0.44 + line * 0.035, 0.70, 0.455 + line * 0.035, (0.25, 0.25, 0.25))
    return np.clip(image, 0.0, 1.0)


def paint_palette():
    size = PALETTE_CELL * PALETTE_GRID
    image = canvas(size, size, (1.0, 0.0, 1.0))
    for index, colour in enumerate(PALETTE.values()):
        col, row = index % PALETTE_GRID, index // PALETTE_GRID
        image[row * PALETTE_CELL:(row + 1) * PALETTE_CELL, col * PALETTE_CELL:(col + 1) * PALETTE_CELL] = colour
    return image


def paint_fabric():
    width, band = 512, 64
    image = canvas(band * len(FABRICS), width, (0.5, 0.5, 0.5))
    period = width // FABRIC_REPEATS
    xs = np.arange(width)
    for index, (name, (stripe, ground)) in enumerate(FABRICS.items()):
        rows = slice(index * band, (index + 1) * band)
        if name == "BarberPole":
            ys = np.arange(band)[:, None]
            phase = ((xs[None, :] + ys * 2) % period) / period
            colour = np.where((phase < 0.33)[..., None], stripe, np.where((phase < 0.5)[..., None], (0.12, 0.18, 0.45), ground))
            image[rows] = colour
        else:
            on = ((xs % period) < period // 2)[None, :, None]
            image[rows] = np.where(on, stripe, ground)
    n = noise(image.shape[:2], 11, 16)
    image *= (0.85 + 0.25 * n)[..., None]
    return np.clip(image, 0.0, 1.0)


def paint_limestone(base):
    """Ashlar courses over a concrete photo: base is [rows, cols, 3], LIMESTONE_TILE metres."""
    stride = max(1, base.shape[0] // 1024)      # the photo is 4K; the game wants 1K
    base = base[::stride, ::stride]
    h, w = base.shape[:2]
    image = base * np.asarray((1.14, 1.08, 0.94), dtype=np.float32)
    image = image * 0.55 + image.mean(axis=2, keepdims=True) * 0.45 + 0.12
    courses = 4
    blocks = 2
    rng = np.random.default_rng(5)
    course_h = h // courses
    for c in range(courses):
        offset = (w // blocks // 2) if c % 2 else 0
        for b in range(blocks + 1):
            x0 = (b * (w // blocks) + offset) % w
            tone = 1.0 + rng.uniform(-0.05, 0.05)
            cols = (np.arange(w) - x0) % w < (w // blocks)
            image[c * course_h:(c + 1) * course_h, cols] *= tone
        image[c * course_h:c * course_h + 3] *= 0.62
        image[c * course_h + 3:c * course_h + 5] *= 1.08
        for b in range(blocks):
            x = (b * (w // blocks) + offset) % w
            image[c * course_h:(c + 1) * course_h, x:x + 3] *= 0.65
    return np.clip(image, 0.0, 1.0)


def paint_bricks(base):
    """(painted, buff) versions of the red brick photo. Mortar is where the photo is lightest."""
    grey = base.mean(axis=2, keepdims=True)
    lo, hi = np.percentile(grey, 5), np.percentile(grey, 95)
    shade = np.clip((grey - lo) / (hi - lo), 0.0, 1.0)
    mortar = np.clip((shade - 0.62) / 0.25, 0.0, 1.0)
    paint = np.asarray((0.80, 0.76, 0.64), dtype=np.float32) * (0.78 + 0.3 * shade)
    worn = noise(base.shape[:2], 31, 24)
    worn = np.clip((worn - 0.72) / 0.12, 0.0, 1.0)[..., None]      # patches where the brick shows through
    painted = paint * (1.0 - worn) + base * 1.1 * worn
    painted = painted * (1.0 - 0.25 * mortar) + np.asarray((0.62, 0.60, 0.54)) * 0.25 * mortar
    buff = grey * np.asarray((1.45, 1.22, 0.86), dtype=np.float32) + 0.05
    buff = buff * (1.0 - 0.4 * mortar) + np.asarray((0.66, 0.62, 0.55)) * 0.4 * mortar
    return np.clip(painted, 0.0, 1.0), np.clip(buff, 0.0, 1.0)


def save(name: str, image, alpha: bool = False):
    import bpy
    h, w = image.shape[:2]
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :image.shape[2]] = image
    if not alpha:
        rgba[..., 3] = 1.0
    target = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=alpha)
    if target.size[0] != w or target.size[1] != h:
        target.scale(w, h)
    target.pixels.foreach_set(np.flipud(rgba).ravel())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    target.filepath_raw = str(OUT_DIR / name)
    target.file_format = "PNG"
    target.save()
    print("wrote", OUT_DIR / name)


def load_rgb(path: Path):
    import bpy
    image = bpy.data.images.load(str(path), check_existing=True)
    w, h = image.size
    pixels = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return np.flipud(pixels.reshape(h, w, 4))[..., :3]


def generate():
    rooms = canvas(CELL * GRID, CELL * GRID, (0.0, 0.0, 0.0))
    overlays = canvas(CELL * GRID, CELL * GRID, (0.0, 0.0, 0.0), alpha=True)
    for index in range(GRID * GRID):
        row, col = divmod(index, GRID)
        rooms[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = paint_room(ROOMS[index], 100 + index)
        overlays[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = paint_overlay(OVERLAYS[index], 200 + index)
    save("rooms.png", rooms)
    save("overlays.png", overlays, alpha=True)
    save("palette.png", paint_palette())
    save("fabric.png", paint_fabric())
    save("limestone.png", paint_limestone(load_rgb(CONCRETE)))
    painted, buff = paint_bricks(load_rgb(BRICK))
    save("brick_painted.png", painted)
    save("brick_buff.png", buff)


if __name__ == "__main__":
    generate()
