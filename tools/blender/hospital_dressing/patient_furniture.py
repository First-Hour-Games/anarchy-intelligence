"""Patient furniture and wall safety equipment for the hospital interior (see README.md)."""

from math import cos, radians, sin


def turn(kit, count: int, axis: str, degrees: float, pivot: tuple = (0.0, 0.0, 0.0)) -> None:
    """Rotate the kit's last `count` vertices about a local axis through pivot (same sense as Kit.build)."""
    c, s = cos(radians(degrees)), sin(radians(degrees))
    i, j = {"x": (1, 2), "y": (2, 0), "z": (0, 1)}[axis]
    for n in range(len(kit.verts) - count, len(kit.verts)):
        v = list(kit.verts[n])
        a, b = v[i] - pivot[i], v[j] - pivot[j]
        v[i], v[j] = pivot[i] + a * c - b * s, pivot[j] + a * s + b * c
        kit.verts[n] = tuple(v)


def label(B, name: str, words: str, x: float, z: float, yaw: float, y: float, local: tuple, size: float,
          mat: str = "SignWhite"):
    """Flat lettering: kit_text without extrusion costs a quarter of the triangles."""
    text = B.kit_text(name, words, x, z, yaw, y, local, size=size, mat=mat)
    text.data.extrude = 0.0
    return text


def hospital_bed(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, head_angle: float = 30.0,
                 stripped: bool = False, rails_up: bool = True):
    kit = B.Kit(name)
    for lx in (-0.36, 0.36):
        for lz in (-0.86, 0.86):
            kit.cylinder((lx, 0.06, lz), 0.06, 0.035, "Rubber", axis="x", segments=10)         # casters
            kit.box((lx - 0.03, 0.08, lz - 0.025), (lx + 0.03, 0.15, lz + 0.025), "Chrome")    # caster forks
        kit.box((lx - 0.03, 0.15, -0.92), (lx + 0.03, 0.21, 0.92), "FilingGrey")              # base frame
    for lz in (-0.86, 0.86):
        kit.box((-0.39, 0.15, lz - 0.04), (0.39, 0.21, lz + 0.04), "FilingGrey")
    for lz in (-0.5, 0.5):
        kit.box((-0.22, 0.21, lz - 0.06), (0.22, 0.37, lz + 0.06), "FilingGrey")              # hi-lo lift housings
    kit.box((-0.17, 0.24, -0.3), (0.17, 0.34, 0.25), "PlasticBeige")                           # motor box
    for lx in (-0.46, 0.42):
        kit.box((lx, 0.37, -1.03), (lx + 0.04, 0.44, 1.03), "FilingGrey")                     # upper frame
    for lx in (-0.485, 0.485):
        for lz in (-1.035, 1.035):
            kit.cylinder((lx, 0.4, lz), 0.04, 0.06, "PlasticGrey", segments=10)              # corner bumpers
        kit.cylinder((lx * 1.04, 0.47, -0.975), 0.016, 0.1, "Chrome", segments=8)             # IV pole sockets
    for lz, top in ((-1.045, 1.03), (1.045, 0.9)):
        for lx in (-0.49, 0.45):
            kit.box((lx, 0.37, lz - 0.02), (lx + 0.04, top, lz + 0.02), "Chrome")              # board frame posts
        kit.box((-0.49, top - 0.04, lz - 0.02), (0.49, top, lz + 0.02), "Chrome")              # board frame top rail
        kit.box((-0.45, 0.47, lz - 0.01), (0.45, top - 0.04, lz + 0.01), "Laminate")           # beige board panel
    kit.box((0.2, 0.84, 1.025), (0.22, 0.92, 1.07), "Chrome")                                  # pendant hook
    kit.box((0.16, 0.64, 1.055), (0.26, 0.84, 1.075), "PlasticGrey")                           # control pendant
    for by in (0.7, 0.75, 0.8):
        kit.box((0.18, by, 1.075), (0.24, by + 0.025, 1.078), "PlasticWhite")                  # pendant buttons
    kit.box((0.205, 0.45, 1.06), (0.215, 0.64, 1.07), "Rubber")                                # pendant cord
    bottom = 0.58 if rails_up else 0.22
    for side in (-1.0, 1.0):
        xa, xb = sorted((side * 0.47, side * 0.495))
        for z0, z1 in ((-0.93, -0.4), (-0.27, 0.55)):                                         # split side rails
            for ry in (0.0, 0.15, 0.305):
                kit.box((xa, bottom + ry, z0), (xb, bottom + ry + 0.03, z1), "Chrome")
            for rz in (z0, z1 - 0.03):
                kit.box((xa, bottom, rz), (xb, bottom + 0.335, rz + 0.03), "Chrome")
            if rails_up:
                for rz in (z0 + 0.12, z1 - 0.15):
                    kit.box((xa, 0.4, rz), (xb, bottom, rz + 0.03), "Chrome")                 # rail mount arms
    kit.box((-0.44, 0.43, -0.3), (0.44, 0.45, 1.0), "ShelfSteel")                             # seat and foot deck
    kit.box((-0.45, 0.45, -0.3), (0.45, 0.6, 1.0), "MattressBlue")                            # vinyl mattress
    if not stripped:
        kit.box((-0.455, 0.52, -0.3), (0.455, 0.605, 1.005), "Linen")                         # sheet
        kit.box((-0.36, 0.605, 0.66), (0.36, 0.665, 0.97), "Blanket")                         # folded blanket
    obj = kit.build(x, z, yaw, y=y)
    back = B.Kit(name + "Backrest")
    back.box((-0.44, -0.02, -0.68), (0.44, 0.0, 0.0), "ShelfSteel")                           # head deck
    back.box((-0.45, 0.0, -0.68), (0.45, 0.15, 0.0), "MattressBlue")
    if not stripped:
        back.box((-0.455, 0.07, -0.685), (0.455, 0.155, 0.0), "Linen")
        back.box((-0.32, 0.155, -0.6), (0.32, 0.235, -0.24), "Paper")                        # pillow
        back.box((-0.28, 0.235, -0.56), (0.28, 0.26, -0.28), "Paper")
    hx, hz = B.local_point(x, z, yaw, 0.0, -0.3)
    back.build(hx, hz, yaw, y=y + 0.45, pitch=max(0.0, min(head_angle, 45.0)))
    return obj


def overbed_table(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    for lz in (-0.2, 0.2):
        kit.box((-0.425, 0.05, lz - 0.02), (0.41, 0.08, lz + 0.02), "PlasticBeige")           # C-base legs
        for lx in (-0.39, 0.37):
            kit.cylinder((lx, 0.025, lz), 0.025, 0.02, "Rubber", axis="z", segments=8)       # casters
            kit.box((lx - 0.012, 0.035, lz - 0.015), (lx + 0.012, 0.05, lz + 0.015), "Chrome")
    kit.box((-0.425, 0.05, -0.2), (-0.325, 0.09, 0.2), "PlasticBeige")                          # cross bar
    kit.box((-0.41, 0.09, -0.035), (-0.34, 0.6, 0.035), "PlasticBeige")                        # column
    kit.box((-0.4, 0.6, -0.025), (-0.35, 0.84, 0.025), "Chrome")                               # telescoping post
    kit.box((-0.41, 0.84, -0.06), (0.1, 0.865, 0.06), "ShelfSteel")                            # top support arm
    kit.box((-0.4, 0.865, -0.19), (0.4, 0.89, 0.19), "Laminate")                               # laminate top
    for lz in (-0.19, 0.175):
        kit.box((-0.4, 0.89, lz), (0.4, 0.9, lz + 0.015), "PlasticBeige")                      # spill lips
    kit.cylinder((0.22, 0.955, -0.04), 0.055, 0.13, "VinylMauve", segments=12)                 # water pitcher
    kit.cylinder((0.22, 1.03, -0.04), 0.05, 0.02, "PlasticWhite", segments=12)                 # pitcher lid
    kit.box((0.27, 0.92, -0.05), (0.3, 0.94, -0.03), "VinylMauve")                             # pitcher handle
    kit.box((0.27, 0.98, -0.05), (0.3, 1.0, -0.03), "VinylMauve")
    kit.box((0.285, 0.92, -0.05), (0.3, 1.0, -0.03), "VinylMauve")
    kit.box((0.15, 0.99, -0.05), (0.17, 1.01, -0.03), "VinylMauve")                            # spout
    kit.cylinder((0.06, 0.93, 0.08), 0.032, 0.08, "VinylMauve", segments=10)                   # matching cup
    kit.cylinder((0.06, 0.975, 0.08), 0.037, 0.012, "VinylMauve", segments=10)                 # cup rim
    kit.box((0.056, 0.95, 0.076), (0.064, 1.02, 0.084), "PlasticWhite")                        # bendy straw
    kit.box((0.056, 1.012, 0.076), (0.095, 1.02, 0.084), "PlasticWhite")
    turn(kit, 16, "z", -12.0, (0.06, 0.95, 0.08))
    kit.box((-0.3, 0.89, -0.13), (-0.06, 0.98, -0.01), "CartBlue")                             # tissue box
    kit.box((-0.2, 0.98, -0.09), (-0.16, 1.01, -0.05), "Paper")                                # tissue
    return kit.build(x, z, yaw, y=y)


def visitor_chair(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, color: str = "VinylTeal"):
    kit = B.Kit(name)
    for side in (-1.0, 1.0):
        xa, xb = sorted((side * 0.25, side * 0.29))
        kit.box((xa, 0.0, 0.21), (xb, 0.62, 0.25), "Wood")                                    # front legs and arm posts
        kit.box((xa, 0.0, -0.25), (xb, 0.42, -0.21), "Wood")                                  # back legs
        kit.box((xa, 0.13, -0.21), (xb, 0.16, 0.21), "Wood")                                  # side stretchers
        kit.box((side * 0.27 - 0.03, 0.62, -0.27), (side * 0.27 + 0.03, 0.655, 0.31), "Wood")  # arms
        kit.box((xa, 0.4, -0.25), (xb, 0.95, -0.21), "Wood")                                  # raked back uprights
        turn(kit, 8, "x", -10.0, (0.0, 0.42, -0.21))
    kit.box((-0.25, 0.34, -0.22), (0.25, 0.4, 0.24), "Wood")                                  # seat frame
    kit.box((-0.245, 0.4, -0.2), (0.245, 0.47, 0.27), color)                                   # vinyl seat
    kit.box((-0.25, 0.4, -0.25), (0.25, 0.95, -0.21), "Wood")                                 # back panel
    kit.box((-0.245, 0.47, -0.21), (0.245, 0.92, -0.15), color)                                # vinyl back
    turn(kit, 16, "x", -10.0, (0.0, 0.42, -0.21))
    return kit.build(x, z, yaw, y=y)


def exam_table(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    kit.box((-0.7, 0.0, -0.27), (0.78, 0.08, 0.22), "Baseboard")                              # toe kick
    kit.box((-0.72, 0.08, -0.3), (0.8, 0.7, 0.26), "PlasticBeige")                            # cabinet base
    kit.box((-0.42, 0.7, -0.33), (0.92, 0.72, 0.33), "PlasticBeige")                          # top frame
    kit.box((-0.42, 0.72, -0.34), (0.92, 0.78, 0.34), "Vinyl")                                # seat pad
    kit.box((-0.42, 0.78, -0.25), (0.92, 0.783, 0.25), "Paper")                               # paper sheet
    fronts = [(-0.7, -0.22, 0.12, 0.29), (-0.7, -0.22, 0.31, 0.48), (-0.7, -0.22, 0.5, 0.67),
              (-0.2, 0.36, 0.12, 0.39), (-0.2, 0.36, 0.41, 0.67), (0.38, 0.78, 0.31, 0.48), (0.38, 0.78, 0.5, 0.67)]
    for x0, x1, y0, y1 in fronts:
        kit.box((x0, y0, 0.26), (x1, y1, 0.275), "Laminate")                                  # drawer fronts
        mid = (x0 + x1) / 2.0
        kit.box((mid - 0.06, y1 - 0.05, 0.275), (mid + 0.06, y1 - 0.035, 0.29), "Chrome")     # pulls
    kit.box((0.38, 0.1, 0.25), (0.78, 0.29, 0.262), "Rubber")                                 # step slot
    kit.box((0.4, 0.12, 0.08), (0.76, 0.25, 0.36), "ShelfSteel")                              # pull-out step
    kit.box((0.41, 0.25, 0.09), (0.75, 0.262, 0.355), "Rubber")                               # rubber tread
    kit.box((0.4, 0.235, 0.355), (0.76, 0.265, 0.375), "Chrome")                              # step nosing
    obj = kit.build(x, z, yaw, y=y)
    back = B.Kit(name + "Backrest")
    back.box((-0.47, -0.02, -0.33), (0.0, 0.0, 0.33), "PlasticBeige")                        # backrest frame
    back.box((-0.47, 0.0, -0.34), (0.0, 0.06, 0.34), "Vinyl")                                 # backrest pad
    back.box((-0.47, 0.06, -0.25), (0.0, 0.063, 0.25), "Paper")                               # paper over the backrest
    back.cylinder((-0.5, -0.035, 0.0), 0.045, 0.52, "Paper", axis="z", segments=12)           # paper roll
    for lz in (-0.275, 0.265):
        back.box((-0.52, -0.045, lz), (-0.45, -0.025, lz + 0.01), "Chrome")                  # roll holder arms
    px, pz = B.local_point(x, z, yaw, -0.42, 0.0)
    back.build(px, pz, yaw, y=y + 0.72, roll=-35.0)
    return obj


def physician_scale(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    cx = -0.11                                                                                 # column line; beam reaches +X
    for lx in (cx - 0.15, cx + 0.13):
        for lz in (-0.12, 0.21):
            kit.box((lx, 0.0, lz), (lx + 0.02, 0.02, lz + 0.02), "Rubber")                    # feet
    kit.box((cx - 0.17, 0.02, -0.14), (cx + 0.17, 0.1, 0.25), "Appliance")                     # platform
    kit.box((cx - 0.15, 0.1, -0.11), (cx + 0.15, 0.112, 0.23), "Rubber")                      # rubber mat
    kit.box((cx - 0.06, 0.1, -0.21), (cx + 0.06, 0.18, -0.13), "Appliance")                    # column foot
    kit.box((cx - 0.035, 0.18, -0.2), (cx + 0.035, 1.3, -0.14), "Appliance")                   # column
    kit.box((cx - 0.055, 1.3, -0.21), (cx + 0.055, 1.42, -0.13), "Appliance")                  # beam head
    kit.box((cx - 0.17, 1.325, -0.13), (cx + 0.37, 1.35, -0.115), "Chrome")                   # main beam
    kit.box((cx - 0.17, 1.37, -0.13), (cx + 0.37, 1.39, -0.115), "Chrome")                    # fine beam
    kit.box((cx + 0.37, 1.31, -0.135), (cx + 0.39, 1.41, -0.11), "Chrome")                    # beam tip
    kit.box((cx - 0.17, 1.315, -0.135), (cx - 0.14, 1.4, -0.11), "Chrome")                    # counterweight end
    kit.box((cx + 0.07, 1.315, -0.138), (cx + 0.12, 1.36, -0.105), "Brass")                   # main poise
    kit.box((cx + 0.2, 1.365, -0.136), (cx + 0.225, 1.4, -0.107), "Chrome")                   # fine poise
    kit.box((cx - 0.01, 0.9, -0.24), (cx + 0.01, 1.53, -0.22), "Chrome")                      # height rod
    kit.box((cx - 0.015, 1.51, -0.245), (cx + 0.015, 1.55, -0.215), "Chrome")                 # hinge block
    kit.box((cx - 0.01, 1.535, -0.215), (cx + 0.01, 1.55, -0.04), "Chrome")                   # head piece, swung out
    return kit.build(x, z, yaw, y=y)


def wheeled_stool(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    for k in range(5):
        kit.box((-0.02, 0.08, 0.03), (0.02, 0.11, 0.23), "Chrome")                              # star base leg
        kit.box((-0.012, 0.05, 0.215), (0.012, 0.08, 0.245), "Chrome")                         # caster stem
        kit.cylinder((0.0, 0.03, 0.23), 0.03, 0.045, "Rubber", axis="x", segments=8)           # twin-wheel caster
        turn(kit, 32, "y", 180.0 + 72.0 * k)
    kit.cylinder((0.0, 0.095, 0.0), 0.045, 0.06, "Chrome", segments=10)                        # hub
    kit.cylinder((0.0, 0.24, 0.0), 0.03, 0.24, "Rubber", segments=10)                          # gas column sleeve
    kit.cylinder((0.0, 0.42, 0.0), 0.02, 0.12, "Chrome", segments=10)                          # gas column
    kit.cylinder((0.0, 0.485, 0.0), 0.17, 0.03, "PlasticGrey", segments=16)                    # seat pan
    kit.cylinder((0.0, 0.54, 0.0), 0.2, 0.08, "Rubber", segments=20)                           # black vinyl seat
    kit.box((0.12, 0.465, -0.01), (0.22, 0.475, 0.01), "Chrome")                               # height lever
    return kit.build(x, z, yaw, y=y)


def step_stool(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    for lx in (-0.205, 0.205):
        for lz, top in ((-0.17, 0.385), (-0.015, 0.385), (0.17, 0.185)):
            kit.cylinder((lx, top / 2.0, lz), 0.012, top, "Chrome", segments=8)               # chrome tube legs
            kit.cylinder((lx, 0.01, lz), 0.016, 0.02, "Rubber", segments=8)                   # rubber feet
        kit.cylinder((lx, 0.09, 0.0), 0.01, 0.34, "Chrome", axis="z", segments=8)             # side brace
    kit.box((-0.2, 0.385, -0.19), (0.2, 0.405, -0.005), "Chrome")                             # top step
    kit.box((-0.19, 0.405, -0.18), (0.19, 0.42, -0.015), "Rubber")                            # top tread
    kit.box((-0.2, 0.185, 0.005), (0.2, 0.205, 0.19), "Chrome")                               # lower step
    kit.box((-0.19, 0.205, 0.015), (0.19, 0.22, 0.18), "Rubber")                              # lower tread
    return kit.build(x, z, yaw, y=y)


def med_dispensing_cabinet(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12,
                           forced: bool = False):
    kit = B.Kit(name)
    kit.box((-0.4, 0.0, -0.3), (0.4, 0.08, 0.17), "Baseboard")                                # plinth
    kit.box((-0.425, 0.08, -0.325), (0.425, 1.75, 0.215), "FilingGrey")                       # steel tower
    kit.box((-0.3, 1.44, 0.215), (0.3, 1.7, 0.235), "PlasticBeige")                           # display bezel
    kit.box((-0.12, 1.5, 0.235), (0.12, 1.65, 0.24), "ScreenDark")                            # small screen
    kit.box((-0.2, 1.33, 0.215), (0.2, 1.37, 0.285), "PlasticBeige")                          # keypad shelf
    for row in range(3):
        for col in range(4):
            kx, kz = -0.09 + col * 0.05, 0.23 + row * 0.018
            kit.box((kx - 0.018, 1.37, kz), (kx + 0.018, 1.378, kz + 0.013), "PlasticWhite")  # keys
    heights = (0.17, 0.17, 0.13, 0.13, 0.1, 0.1, 0.1, 0.1)
    # Forced drawers: (column, row) -> (pulled out, bend axis, degrees); a bent front swings out on one edge.
    pried = {(0, 5): (0.03, "y", -11.0), (2, 4): (0.03, "y", 12.0), (1, 2): (0.04, "x", 22.0),
             (1, 6): (0.04, "y", -7.0)} if forced else {}
    for col, (x0, x1) in enumerate(((-0.41, -0.145), (-0.135, 0.135), (0.145, 0.41))):
        y0 = 0.13
        for row, h in enumerate(heights):
            out, axis, bend = pried.get((col, row), (0.0, "y", 0.0))
            f = 0.215 + out
            if out:
                kit.box((x0 + 0.01, y0 + 0.01, f - 0.25), (x1 - 0.01, y0 + h - 0.02, f), "ShelfSteel")   # drawer bin
                kit.box((x0 + 0.02, y0 + h - 0.02, f - 0.24), (x1 - 0.02, y0 + h - 0.018, f - 0.01), "Rubber")
            kit.box((x0, y0, f), (x1, y0 + h, f + 0.02), "PlasticGrey")                         # drawer front
            kit.box((x0 + 0.03, y0 + h - 0.03, f + 0.02), (x1 - 0.03, y0 + h - 0.015, f + 0.04), "Chrome")  # pull
            kit.box((x1 - 0.03, y0 + 0.02, f + 0.02), (x1 - 0.015, y0 + 0.035, f + 0.024), "Brass")       # lock
            if bend:
                turn(kit, 24, axis, bend, (x1 if bend > 0 else x0, y0, f))
            y0 += h + 0.016
    return kit.build(x, z, yaw, y=y)


def sterile_wall_cabinet(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.45):
    kit = B.Kit(name)
    kit.box((-0.46, 0.0, -0.18), (0.46, 0.9, -0.165), "Chrome")                               # stainless back
    for lx in (-0.46, 0.44):
        kit.box((lx, 0.0, -0.18), (lx + 0.02, 0.9, 0.14), "Chrome")                          # sides
    for ly in (0.0, 0.88):
        kit.box((-0.46, ly, -0.18), (0.46, ly + 0.02, 0.14), "Chrome")                       # top and bottom
    for ly in (0.3, 0.6):
        kit.box((-0.44, ly - 0.008, -0.165), (0.44, ly, 0.12), "Chrome")                     # shelves
    for x0 in (-0.46, 0.0):
        x1 = x0 + 0.46
        for a, b in ((x0, x0 + 0.035), (x1 - 0.035, x1)):
            kit.box((a, 0.0, 0.14), (b, 0.9, 0.16), "Chrome")                                 # door stiles
        for a, b in ((0.0, 0.035), (0.865, 0.9)):
            kit.box((x0 + 0.035, a, 0.14), (x1 - 0.035, b, 0.16), "Chrome")                  # door rails
        kit.box((x0 + 0.035, 0.035, 0.145), (x1 - 0.035, 0.865, 0.155), "DoorGlass")          # glass
    for lx in (-0.05, 0.035):
        kit.box((lx, 0.38, 0.16), (lx + 0.015, 0.52, 0.18), "Chrome")                         # handles
    for ly in (0.02, 0.3, 0.6):                                                               # sterile packs, gauze, rolls
        kit.box((-0.42, ly, -0.15), (-0.22, ly + 0.15, 0.09), "PlasticWhite")
        kit.box((-0.41, ly + 0.15, -0.14), (-0.23, ly + 0.25, 0.06), "Cardboard" if ly < 0.5 else "PlasticWhite")
    for i, (mat, lz) in enumerate((("GloveBlue", 0.0), ("GloveBlue", 0.05), ("OxygenGreen", 0.1), ("GloveBlue", 0.15))):
        kit.box((-0.18 + i * 0.005, 0.3 + i * 0.05, -0.15 + lz * 0.1), (0.1 - i * 0.005, 0.35 + i * 0.05, 0.1), mat)
    kit.box((0.14, 0.3, -0.13), (0.42, 0.38, 0.1), "PlasticWhite")                           # pouch bin
    for i in range(5):
        kit.box((0.16 + i * 0.05, 0.38, -0.11), (0.18 + i * 0.05, 0.45 + (i % 2) * 0.03, 0.08), "Paper")  # peel pouches
    for i, (rx, ry) in enumerate(((0.06, 0.06), (0.16, 0.06), (0.26, 0.06), (0.11, 0.135), (0.21, 0.135))):
        kit.cylinder((rx, ry, -0.03 + (i % 2) * 0.04), 0.04, 0.09, "Linen", axis="z", segments=10)  # bandage rolls
    kit.box((-0.18, 0.6, -0.15), (0.12, 0.7, 0.1), "GloveBlue")
    kit.box((0.16, 0.6, -0.15), (0.42, 0.78, 0.08), "Cardboard")
    return kit.build(x, z, yaw, y=y)


def fire_extinguisher_cabinet(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.8,
                              empty: bool = False):
    kit = B.Kit(name)
    kit.box((-0.16, 0.0, -0.085), (0.16, 0.8, -0.077), "SignWhite")                          # white back panel
    for lx in (-0.16, 0.145):
        kit.box((lx, 0.0, -0.085), (lx + 0.015, 0.8, 0.055), "CartRed")                     # red steel sides
    for ly in (0.0, 0.785):
        kit.box((-0.16, ly, -0.085), (0.16, ly + 0.015, 0.055), "CartRed")                  # top and bottom
    kit.box((-0.16, 0.655, 0.055), (0.16, 0.8, 0.075), "CartRed")                             # lettering band
    for lx in (-0.16, 0.13):
        kit.box((lx, 0.0, 0.055), (lx + 0.03, 0.655, 0.075), "CartRed")                       # door stiles
    for ly in (0.0, 0.625):
        kit.box((-0.13, ly, 0.055), (0.13, ly + 0.03, 0.075), "CartRed")                      # door rails
    kit.box((-0.13, 0.03, 0.06), (0.13, 0.625, 0.07), "DoorGlass")                            # glass
    kit.box((0.135, 0.28, 0.075), (0.15, 0.38, 0.085), "Chrome")                              # door pull
    kit.box((-0.035, 0.5, -0.077), (0.035, 0.53, -0.06), "Chrome")                            # hanger bracket
    if not empty:
        kit.cylinder((0.0, 0.26, -0.012), 0.06, 0.42, "MedicalRed", segments=12)             # extinguisher
        kit.cylinder((0.0, 0.48, -0.012), 0.04, 0.02, "MedicalRed", segments=12)             # shoulder
        kit.cylinder((0.0, 0.505, -0.012), 0.016, 0.04, "Chrome", segments=8)                # valve
        kit.box((-0.02, 0.525, -0.022), (0.08, 0.535, -0.002), "Chrome")                      # lever
        kit.box((-0.02, 0.51, -0.022), (0.075, 0.518, -0.002), "Chrome")                      # carry handle
        kit.cylinder((0.0, 0.5, 0.01), 0.012, 0.012, "PlasticWhite", axis="z", segments=8)   # gauge
        kit.box((-0.073, 0.2, -0.02), (-0.058, 0.5, -0.005), "Rubber")                        # black hose
        kit.box((-0.058, 0.49, -0.02), (-0.012, 0.505, -0.005), "Rubber")
        kit.box((-0.078, 0.15, -0.022), (-0.053, 0.2, -0.003), "Rubber")                      # nozzle
        kit.box((-0.04, 0.22, 0.042), (0.04, 0.36, 0.051), "PlasticWhite")                    # instruction label
    label(B, name + "Label", "FIRE\nEXTINGUISHER", x, z, yaw, y, (0.0, 0.727, 0.078), 0.038)
    return kit.build(x, z, yaw, y=y)


def aed_cabinet(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.05, empty: bool = False):
    kit = B.Kit(name)
    kit.box((-0.21, 0.0, -0.09), (0.21, 0.5, -0.08), "PlasticWhite")                         # back
    for lx in (-0.21, 0.195):
        kit.box((lx, 0.0, -0.09), (lx + 0.015, 0.5, 0.06), "PlasticWhite")                   # sides
    for ly in (0.0, 0.485):
        kit.box((-0.21, ly, -0.09), (0.21, ly + 0.015, 0.06), "PlasticWhite")                # top and bottom
    kit.box((-0.21, 0.37, 0.06), (0.21, 0.5, 0.08), "PlasticWhite")                          # sign band
    for lx in (-0.21, 0.18):
        kit.box((lx, 0.0, 0.06), (lx + 0.03, 0.37, 0.08), "PlasticWhite")                    # door stiles
    for ly in (0.0, 0.34):
        kit.box((-0.18, ly, 0.06), (0.18, ly + 0.03, 0.08), "PlasticWhite")                  # door rails
    kit.box((-0.18, 0.03, 0.065), (0.18, 0.34, 0.075), "DoorGlass")                           # glass
    kit.box((0.185, 0.14, 0.08), (0.2, 0.23, 0.09), "Chrome")                                 # door pull
    if not empty:
        kit.box((-0.14, 0.03, -0.07), (0.14, 0.25, 0.03), "SafetyYellow")                     # defibrillator case
        kit.box((-0.06, 0.25, -0.035), (0.06, 0.28, -0.015), "Rubber")                        # carry handle
        kit.box((-0.1, 0.1, 0.03), (0.03, 0.19, 0.033), "PlasticGrey")                        # pads panel
        kit.cylinder((0.08, 0.145, 0.034), 0.017, 0.008, "SignGreen", axis="z", segments=10)  # power button
    label(B, name + "Label", "AED", x, z, yaw, y, (0.0, 0.435, 0.083), 0.075, mat="SignGreen")
    return kit.build(x, z, yaw, y=y)


def fire_alarm_pull(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.15):
    kit = B.Kit(name)
    kit.box((-0.05, 0.0, -0.03), (0.05, 0.16, -0.022), "MedicalRed")                         # back plate
    kit.box((-0.045, 0.006, -0.022), (0.045, 0.154, 0.01), "MedicalRed")                     # body
    kit.box((-0.032, 0.035, 0.01), (0.032, 0.095, 0.013), "Rubber")                          # handle recess
    kit.box((-0.028, 0.06, 0.013), (0.028, 0.082, 0.028), "MedicalRed")                      # pull handle
    kit.box((-0.02, 0.068, 0.028), (0.02, 0.074, 0.03), "SignWhite")                          # handle stripe
    label(B, name + "Label", "FIRE", x, z, yaw, y, (0.0, 0.124, 0.013), 0.032)
    return kit.build(x, z, yaw, y=y)


def wall_clock(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 2.05, time: tuple = (10, 10)):
    kit = B.Kit(name)
    centre = (0.0, 0.16, 0.0)
    kit.cylinder((0.0, 0.16, -0.007), 0.16, 0.036, "Rubber", axis="z", segments=24)          # dark rim
    kit.cylinder((0.0, 0.16, 0.0125), 0.145, 0.003, "SignWhite", axis="z", segments=24)      # white face
    for k in range(12):
        w, r = (0.006, 0.105) if k % 3 == 0 else (0.003, 0.118)
        kit.box((-w, 0.16 + r, 0.014), (w, 0.295, 0.016), "Rubber")                           # tick marks
        turn(kit, 8, "z", -30.0 * k, centre)
    hour, minute = time
    for degrees, length, w, lz, mat in (((hour % 12 + minute / 60.0) * 30.0, 0.075, 0.006, 0.016, "Rubber"),
                                        (minute * 6.0, 0.115, 0.004, 0.018, "Rubber"),
                                        (222.0, 0.125, 0.0015, 0.02, "MedicalRed")):
        kit.box((-w, 0.16 - 0.025, lz), (w, 0.16 + length, lz + 0.002), mat)                 # hands
        turn(kit, 8, "z", -degrees, centre)
    kit.cylinder((0.0, 0.16, 0.019), 0.007, 0.01, "MedicalRed", axis="z", segments=8)        # centre cap
    return kit.build(x, z, yaw, y=y)


PROPS = {
    "hospital_bed": {
        "build": hospital_bed, "size": (1.05, 1.05, 2.15), "mount": "floor", "collide": True,
        "variants": [{}, {"head_angle": 0.0, "stripped": True, "rails_up": False}, {"head_angle": 45.0, "rails_up": False}],
        "desc": "1990s electric hospital bed, head end at -Z, raised backrest, split rails",
    },
    "overbed_table": {
        "build": overbed_table, "size": (0.85, 1.04, 0.45), "mount": "floor", "collide": True,
        "variants": [{}], "desc": "C-base overbed table with water pitcher, cup and tissue box",
    },
    "visitor_chair": {
        "build": visitor_chair, "size": (0.62, 0.95, 0.65), "mount": "floor", "collide": True,
        "variants": [{}, {"color": "VinylMauve"}], "desc": "Wooden-arm visitor armchair with vinyl seat and back",
    },
    "exam_table": {
        "build": exam_table, "size": (1.85, 1.045, 0.72), "mount": "floor", "collide": True,
        "variants": [{}], "desc": "Drawer-base examination table, raised backrest, paper roll, pull-out step",
    },
    "physician_scale": {
        "build": physician_scale, "size": (0.55, 1.55, 0.5), "mount": "floor", "collide": True,
        "variants": [{}], "desc": "Mechanical doctor's beam scale with height rod",
    },
    "wheeled_stool": {
        "build": wheeled_stool, "size": (0.5, 0.58, 0.5), "mount": "floor", "collide": True,
        "variants": [{}], "desc": "Rolling physician stool, five casters, black vinyl seat",
    },
    "step_stool": {
        "build": step_stool, "size": (0.45, 0.42, 0.38), "mount": "floor", "collide": True,
        "variants": [{}], "desc": "Two-step chrome step stool with rubber treads, ascending toward -Z",
    },
    "med_dispensing_cabinet": {
        "build": med_dispensing_cabinet, "size": (0.85, 1.75, 0.65), "mount": "floor", "collide": True,
        "variants": [{}, {"forced": True}], "desc": "Early-90s automated medication dispensing cabinet",
    },
    "sterile_wall_cabinet": {
        "build": sterile_wall_cabinet, "size": (0.92, 0.9, 0.36), "mount": "wall", "y": 1.45, "collide": True,
        "variants": [{}], "desc": "Stainless glass-door wall cabinet with sterile supplies",
    },
    "fire_extinguisher_cabinet": {
        "build": fire_extinguisher_cabinet, "size": (0.32, 0.8, 0.17), "mount": "wall", "y": 0.8, "collide": False,
        "variants": [{}, {"empty": True}], "desc": "Surface-mounted red fire extinguisher cabinet",
    },
    "aed_cabinet": {
        "build": aed_cabinet, "size": (0.42, 0.5, 0.18), "mount": "wall", "y": 1.05, "collide": False,
        "variants": [{}, {"empty": True}], "desc": "White AED wall cabinet with yellow defibrillator",
    },
    "fire_alarm_pull": {
        "build": fire_alarm_pull, "size": (0.1, 0.16, 0.06), "mount": "wall", "y": 1.15, "collide": False,
        "variants": [{}], "desc": "Red fire alarm pull station",
    },
    "wall_clock": {
        "build": wall_clock, "size": (0.32, 0.32, 0.05), "mount": "wall", "y": 2.05, "collide": False,
        "variants": [{}, {"time": (3, 40)}], "desc": "Round school-style wall clock",
    },
}
