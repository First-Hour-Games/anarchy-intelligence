"""Mobile hospital equipment for the hospital interior: carts, oxygen cylinders, poles and bins (see README.md)."""

PALETTE = {"MobileTubeGreen": ((0.45, 0.78, 0.55), 0.0, 0.35)}   # translucent oxygen tubing


def caster(kit, cx: float, cz: float, r: float = 0.05, top: float = 0.14) -> None:
    kit.cylinder((cx, r, cz), r, 0.03, "Rubber", axis="x", segments=10)                 # wheel
    kit.box((cx - 0.021, r, cz - 0.016), (cx + 0.021, top, cz + 0.016), "Chrome")       # swivel fork


def star_base(B, name: str, x: float, z: float, yaw: float, y: float, reach: float, pz: float = 0.0) -> None:
    """Five-leg caster base around a pole at local (0, pz); one leg points to the front."""
    px, pw = B.local_point(x, z, yaw, 0.0, pz)
    for i in range(5):
        leg = B.Kit(f"{name}Leg{i}")
        leg.box((-0.017, 0.06, 0.0), (0.017, 0.085, reach - 0.03), "Chrome")             # leg
        caster(leg, 0.0, reach - 0.03, r=0.03, top=0.06)
        leg.build(px, pw, yaw + 72.0 * i, y=y)


def ring(B, kit, name: str, x: float, z: float, yaw: float, y: float, c: tuple, a: float, t: float, mat: str,
         flat: bool = False, edges: str = "tbrl", diagonals: str = "tbrl") -> None:
    """Octagonal tube loop of apothem a around kit-local c, upright facing +Z (or flat); diagonals are a 45-degree kit."""
    s, h = a * 0.4142 + t / 2.0, t / 2.0
    runs = {"t": ((-s, a - h), (s, a + h)), "b": ((-s, -a - h), (s, -a + h)),
            "r": ((a - h, -s), (a + h, s)), "l": ((-a - h, -s), (-a + h, s))}

    def put(target, edge: str, ox: float, oy: float, oz: float) -> None:
        (u0, v0), (u1, v1) = runs[edge]
        if flat:
            target.box((ox + u0, oy - h, oz + v0), (ox + u1, oy + h, oz + v1), mat)
        else:
            target.box((ox + u0, oy + v0, oz - h), (ox + u1, oy + v1, oz + h), mat)

    for edge in edges:
        put(kit, edge, *c)
    diagonal = B.Kit(name)
    for edge in diagonals:
        put(diagonal, edge, 0.0, 0.0, 0.0)
    px, pz = B.local_point(x, z, yaw, c[0], c[2])
    diagonal.build(px, pz, yaw + (45.0 if flat else 0.0), y=y + c[1], roll=0.0 if flat else 45.0)


def gas_cylinder(kit, cx: float, base: float, cz: float, r: float, h: float, cap: float = 0.0) -> float:
    """Oxygen cylinder standing at `base`: metal body, green shoulder and dome, then a brass valve or a
    green valve cap `cap` tall. Returns the top."""
    kit.cylinder((cx, base + (h - 0.08) / 2.0, cz), r, h - 0.08, "FilingGrey", segments=12)  # body
    kit.cylinder((cx, base + h - 0.04, cz), r, 0.08, "OxygenGreen", segments=12)            # green shoulder
    kit.cylinder((cx, base + h + 0.012, cz), r * 0.7, 0.024, "OxygenGreen", segments=8)     # dome
    if cap:
        kit.cylinder((cx, base + h + 0.024 + cap / 2.0, cz), r * 0.55, cap, "OxygenGreen", segments=8)  # valve cap
        return base + h + 0.024 + cap
    kit.cylinder((cx, base + h + 0.05, cz), 0.014, 0.052, "Brass", segments=6)              # valve post
    return base + h + 0.076


def crash_cart(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, drawers_open: tuple = ()):
    kit = B.Kit(name)
    x0, x1, back, face = -0.37, 0.27, -0.26, 0.21                                       # cabinet carcass
    for cx in (x0 + 0.07, x1 - 0.07):
        for cz in (back + 0.07, face - 0.07):
            caster(kit, cx, cz, r=0.0625, top=0.16)
    kit.box((x0, 0.16, back), (x1, 1.04, face), "CartRed")                               # cabinet
    kit.box((x0 - 0.015, 0.15, back - 0.015), (x1 + 0.015, 0.2, face + 0.03), "Rubber")  # base bumper
    top = 1.01
    for i, h in enumerate((0.1, 0.1, 0.15, 0.2, 0.25)):
        pull = 0.11 if i in drawers_open else 0.0
        f = face + pull
        kit.box((x0 + 0.02, top - h + 0.006, f), (x1 - 0.02, top - 0.006, f + 0.015), "CartRed")       # drawer front
        kit.box((x0 + 0.06, top - 0.036, f + 0.015), (x1 - 0.06, top - 0.02, f + 0.019), "Chrome")      # full-width pull
        if pull:
            for sx in (x0 + 0.03, x1 - 0.045):
                kit.box((sx, top - h + 0.015, face - 0.02), (sx + 0.015, top - 0.03, f), "PlasticGrey")  # drawer sides
            kit.box((x0 + 0.03, top - h + 0.015, face - 0.02), (x1 - 0.03, top - h + 0.025, f), "PlasticGrey")
            kit.box((x0 + 0.07, top - h + 0.025, face - 0.03), (x0 + 0.25, top - h + 0.065, f - 0.01), "PlasticWhite")  # supplies
        top -= h
    if 0 not in drawers_open:
        kit.box((x1 - 0.075, 0.94, face + 0.015), (x1 - 0.04, 1.0, face + 0.03), "PlasticGrey")       # breakaway lock
        kit.box((x1 - 0.066, 0.9, face + 0.03), (x1 - 0.049, 0.945, face + 0.034), "SafetyYellow")    # numbered seal
    kit.box((x0 - 0.035, 1.025, back - 0.03), (x1 + 0.035, 1.06, face + 0.07), "Rubber")    # bumper rim
    kit.box((x0 - 0.02, 1.04, back - 0.015), (x1 + 0.02, 1.075, face + 0.055), "PlasticGrey")  # worktop
    kit.box((x0 - 0.02, 1.075, back - 0.015), (x1 + 0.02, 1.1, back + 0.005), "PlasticGrey")   # raised back lip
    for sx in (x0 - 0.02, x1):
        kit.box((sx, 1.075, back - 0.015), (sx + 0.02, 1.1, face + 0.055), "PlasticGrey")      # side lips
    dx0, dx1, dz0, dz1 = -0.22, 0.1, -0.17, 0.15                                             # defibrillator/monitor
    kit.box((dx0, 1.075, dz0), (dx1, 1.31, dz1), "PlasticGrey")
    kit.box((dx0 + 0.02, 1.165, dz1), (dx0 + 0.185, 1.29, dz1 + 0.005), "ScreenDark")          # screen
    kit.cylinder((0.035, 1.235, dz1 + 0.01), 0.025, 0.02, "PlasticWhite", axis="z", segments=10)  # energy dial
    kit.box((-0.005, 1.12, dz1), (0.025, 1.15, dz1 + 0.006), "SafetyYellow")                   # charge button
    kit.box((0.045, 1.12, dz1), (0.075, 1.15, dz1 + 0.006), "MedicalRed")                      # shock button
    kit.box((dx0 + 0.03, 1.09, dz1), (dx0 + 0.15, 1.11, dz1 + 0.005), "Rubber")                # recorder slot
    for hx in (dx0 + 0.06, dx1 - 0.08):
        kit.box((hx, 1.31, -0.015), (hx + 0.02, 1.35, 0.015), "Rubber")                       # handle posts
    kit.box((dx0 + 0.06, 1.33, -0.015), (dx1 - 0.06, 1.35, 0.015), "Rubber")                   # carry handle
    kit.box((dx1, 1.085, dz0 + 0.01), (dx1 + 0.01, 1.25, dz1 - 0.01), "Rubber")                # paddle holder
    for pz in (-0.082, 0.072):
        kit.box((dx1 + 0.01, 1.1, pz - 0.068), (dx1 + 0.02, 1.112, pz + 0.068), "Chrome")      # electrode edge
        kit.box((dx1 + 0.01, 1.112, pz - 0.065), (dx1 + 0.035, 1.21, pz + 0.065), "PlasticGrey")  # paddle body
        for hz in (pz - 0.05, pz + 0.035):
            kit.box((dx1 + 0.014, 1.21, hz), (dx1 + 0.031, 1.255, hz + 0.015), "PlasticGrey")  # grip posts
        kit.box((dx1 + 0.012, 1.255, pz - 0.055), (dx1 + 0.033, 1.285, pz + 0.055), "Rubber")    # grip
        kit.box((dx1 + 0.015, 1.285, pz + 0.025), (dx1 + 0.03, 1.292, pz + 0.045), "SafetyYellow")  # discharge button
    kit.box((x0 + 0.07, 0.3, back - 0.03), (x1 - 0.07, 1.0, back - 0.012), "PlasticBeige")    # CPR backboard
    for bx in (x0 + 0.14, x1 - 0.14):
        kit.box((bx - 0.02, 0.96, back - 0.033), (bx + 0.02, 1.02, back), "Chrome")            # board clips
    cx, cz = x1 + 0.065, back + 0.17                                                         # side oxygen cylinder
    kit.cylinder((cx, 0.3, cz), 0.062, 0.04, "ShelfSteel", segments=12)                      # bracket cup
    kit.box((x1, 0.28, cz - 0.02), (x1 + 0.01, 0.32, cz + 0.02), "ShelfSteel")
    for sy in (0.55, 0.68):
        kit.box((x1, sy, cz - 0.066), (x1 + 0.13, sy + 0.025, cz - 0.06), "ShelfSteel")        # bracket strap
        kit.box((x1, sy, cz + 0.06), (x1 + 0.13, sy + 0.025, cz + 0.066), "ShelfSteel")
        kit.box((x1 + 0.124, sy, cz - 0.066), (x1 + 0.13, sy + 0.025, cz + 0.066), "ShelfSteel")
    valve = gas_cylinder(kit, cx, 0.3, cz, 0.055, 0.46)
    kit.cylinder((cx, valve + 0.01, cz + 0.02), 0.02, 0.05, "Chrome", axis="z", segments=8)   # regulator
    kit.cylinder((cx, valve + 0.01, cz + 0.05), 0.024, 0.012, "PlasticWhite", axis="z", segments=10)  # gauge
    return kit.build(x, z, yaw, y=y)


def med_cart(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, locked: bool = True):
    kit = B.Kit(name)
    x0, x1, back, face = -0.33, 0.33, -0.22, 0.245                                      # cabinet carcass
    for cx in (x0 + 0.07, x1 - 0.07):
        for cz in (back + 0.07, face - 0.07):
            caster(kit, cx, cz, r=0.05, top=0.13)
    kit.box((x0, 0.13, back), (x1, 0.985, face), "CartBlue")                              # cabinet
    kit.box((x0 - 0.01, 0.125, back - 0.01), (x1 + 0.01, 0.17, face + 0.02), "Rubber")    # base bumper
    kit.box((x0 - 0.015, 0.985, back - 0.015), (x1 + 0.015, 1.01, face + 0.025), "PlasticGrey")  # worktop
    kit.box((x0 - 0.015, 1.01, back - 0.015), (x1 + 0.015, 1.03, back + 0.005), "PlasticGrey")  # back lip
    for sx in (x0 - 0.015, x1 - 0.005):
        kit.box((sx, 1.01, back - 0.015), (sx + 0.02, 1.03, face + 0.025), "PlasticGrey")    # side lips
    for y0, y1 in ((0.18, 0.39), (0.395, 0.605)):
        kit.box((x0 + 0.02, y0 + 0.004, face), (x1 - 0.02, y1 - 0.004, face + 0.012), "CartBlue")   # deep drawer
        kit.box((x0 + 0.06, y1 - 0.036, face + 0.012), (x1 - 0.06, y1 - 0.02, face + 0.016), "Chrome")  # pull
    for col in range(5):                                                                 # 5 x 4 pill drawers
        c0 = x0 + 0.03 + col * 0.12
        for row in range(4):
            r0 = 0.615 + row * 0.0725
            pull = 0.065 if not locked and (col, row) == (3, 2) else 0.0
            f = face + pull
            kit.box((c0 + 0.004, r0 + 0.004, f), (c0 + 0.116, r0 + 0.0685, f + 0.012), "PlasticWhite")
            kit.box((c0 + 0.035, r0 + 0.045, f + 0.012), (c0 + 0.085, r0 + 0.057, f + 0.016), "Rubber")  # finger pull
            if pull:
                for sx in (c0 + 0.008, c0 + 0.106):
                    kit.box((sx, r0 + 0.01, face - 0.02), (sx + 0.006, r0 + 0.05, f), "PlasticWhite")  # cassette sides
                kit.box((c0 + 0.008, r0 + 0.008, face - 0.02), (c0 + 0.112, r0 + 0.014, f), "PlasticWhite")
                kit.box((c0 + 0.016, r0 + 0.014, face - 0.01), (c0 + 0.104, r0 + 0.03, f - 0.01), "Paper")  # unit doses
    kit.box((x1 - 0.15, 0.915, face), (x1 - 0.04, 0.975, face + 0.012), "PlasticGrey")      # keypad lock
    kit.box((x1 - 0.14, 0.922, face + 0.012), (x1 - 0.09, 0.968, face + 0.016), "Rubber")    # keys
    kit.box((x1 - 0.08, 0.945, face + 0.012), (x1 - 0.05, 0.965, face + 0.016), "ScreenDark")  # status window
    kit.box((x0 - 0.1, 0.6, -0.13), (x0 - 0.006, 0.84, 0.11), "PlasticGrey")                 # side waste bin
    kit.box((x0 - 0.104, 0.835, -0.134), (x0 - 0.002, 0.865, 0.114), "Rubber")               # bag lip
    kit.box((x1 + 0.006, 0.7, -0.09), (x1 + 0.085, 0.92, 0.07), "MedicalRed")                # sharps holder
    kit.box((x1 + 0.004, 0.92, -0.092), (x1 + 0.087, 0.945, 0.072), "PlasticGrey")           # sharps lid
    kit.box((x1, 0.685, -0.07), (x1 + 0.09, 0.7, 0.05), "Chrome")                            # sharps bracket
    for bx in (-0.26, 0.26):
        kit.box((bx - 0.012, 0.93, back - 0.064), (bx + 0.012, 0.955, back), "Chrome")       # handle arms
        kit.box((bx - 0.012, 0.93, back - 0.064), (bx + 0.012, 1.075, back - 0.036), "Chrome")
    kit.cylinder((0.0, 1.075, back - 0.05), 0.017, 0.6, "Chrome", axis="x", segments=8)     # push handle
    kit.box((-0.235, 1.01, -0.13), (-0.215, 1.06, 0.11), "BookRed")                          # binder spine
    kit.box((-0.22, 1.01, -0.13), (0.08, 1.018, 0.11), "BookRed")                            # binder covers
    kit.box((-0.22, 1.052, -0.13), (0.08, 1.06, 0.11), "BookRed")
    kit.box((-0.215, 1.018, -0.125), (0.075, 1.052, 0.105), "Paper")                         # pages
    return kit.build(x, z, yaw, y=y)


def linen_cart(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    hw, hd = 0.565, 0.255                                                                # post centres
    for px in (-hw, hw):
        for pz in (-hd, hd):
            kit.cylinder((px, 0.8, pz), 0.014, 1.22, "Chrome", segments=8)                  # post
            caster(kit, px * 0.88, pz * 0.8, r=0.0625, top=0.19)
    for shelf, sy in enumerate((0.19, 0.62, 1.05)):
        kit.box((-hw - 0.015, sy, -hd - 0.015), (hw + 0.015, sy + 0.025, hd + 0.015), "ShelfSteel")  # shelf
        sx = -0.56
        for i in range(5):                                                               # folded linen stacks
            w = 0.18 if (i + 2 * shelf) % 4 == 1 else 0.22
            mat = "ScrubTeal" if w < 0.2 else "Linen"
            for k in range(3 + (i + shelf) % 3):
                o = 0.005 * ((i + k) % 2)
                ly = sy + 0.025 + k * 0.045
                kit.box((sx + o, ly, -0.2 + o), (sx + w - 0.005 + o, ly + 0.042, 0.2 - o), mat)
            sx += w + 0.016
    kit.box((-hw - 0.015, 1.39, -hd - 0.015), (hw + 0.015, 1.41, hd + 0.015), "Chrome")   # top frame
    kit.box((-0.6, 1.41, -0.3), (0.6, 1.45, 0.29), "MattressBlue")                         # vinyl cover top
    kit.box((-0.6, 0.22, -0.3), (0.6, 1.41, -0.285), "MattressBlue")                       # cover back
    kit.box((-0.6, 1.2, 0.275), (0.6, 1.41, 0.29), "MattressBlue")                         # front flap
    kit.cylinder((0.0, 1.2, 0.28), 0.03, 1.2, "MattressBlue", axis="x", segments=10)       # rolled-up flap
    for sx in (-0.4, 0.4):
        kit.box((sx - 0.02, 1.165, 0.29), (sx + 0.02, 1.41, 0.313), "SignBlue")            # roll straps
    return kit.build(x, z, yaw, y=y)


def isolation_cart(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    hw, back, face = 0.23, -0.19, 0.18
    for cx in (-0.17, 0.17):
        for cz in (-0.13, 0.13):
            caster(kit, cx, cz, r=0.035, top=0.075)
    kit.box((-hw, 0.075, back), (hw, 0.8, face), "PlasticGrey")                           # drawer cabinet
    for y0, y1 in ((0.1, 0.33), (0.335, 0.565), (0.57, 0.795)):
        kit.box((-hw + 0.015, y0 + 0.004, face), (hw - 0.015, y1 - 0.004, face + 0.012), "PlasticWhite")  # drawer
        kit.box((-0.09, y1 - 0.05, face + 0.012), (0.09, y1 - 0.03, face + 0.016), "Rubber")             # handle slot
    kit.box((-hw - 0.01, 0.8, face - 0.005), (hw + 0.01, 0.835, face + 0.01), "PlasticGrey")  # top tray rim
    kit.box((-hw - 0.01, 0.8, back - 0.01), (hw + 0.01, 0.835, back + 0.005), "PlasticGrey")
    for sx in (-hw - 0.01, hw - 0.005):
        kit.box((sx, 0.8, back - 0.01), (sx + 0.015, 0.835, face + 0.01), "PlasticGrey")
    kit.box((-0.21, 0.8, -0.04), (-0.01, 0.86, 0.165), "AirYellow")                          # folded gowns
    kit.box((-0.205, 0.86, -0.035), (-0.015, 0.905, 0.16), "AirYellow")
    kit.box((-0.16, 0.7, 0.19), (-0.1, 0.845, 0.198), "AirYellow")                           # sleeve over the rim
    kit.box((0.0, 0.8, 0.05), (0.21, 0.885, 0.17), "PlasticWhite")                           # glove box
    kit.box((0.07, 0.885, 0.09), (0.14, 0.905, 0.13), "GloveBlue")                           # gloves
    kit.box((0.02, 0.8, -0.14), (0.21, 0.92, 0.03), "Paper")                                 # mask box
    kit.box((0.017, 0.875, -0.143), (0.213, 0.9, 0.033), "SignBlue")                         # box band
    kit.box((0.08, 0.92, -0.075), (0.15, 0.935, -0.04), "Curtain")                           # mask
    for sx in (-0.2, 0.2):
        kit.box((sx - 0.006, 0.835, back - 0.004), (sx + 0.006, 0.95, back + 0.008), "Chrome")  # sign posts
    kit.box((-0.225, 0.945, back - 0.004), (0.225, 1.1, back + 0.009), "Chrome")              # sign holder
    kit.box((-0.215, 0.952, back + 0.009), (0.215, 1.093, back + 0.014), "SafetyYellow")      # sign
    obj = kit.build(x, z, yaw, y=y)
    B.kit_text(name + "Sign", "ISOLATION", x, z, yaw, y, (0.0, 1.022, back + 0.017), size=0.06, mat="Rubber")
    return obj


CHART_SPINES = ("BookBlue", "BookRed", "BookGreen", "AirYellow", "PlasticGrey", "BookBlue", "ScrubTeal", "BookRed")


def chart_rack(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    for cx in (-0.31, 0.31):
        for cz in (-0.18, 0.18):
            caster(kit, cx, cz, r=0.04, top=0.11)
    for sz in (-0.235, 0.21):
        kit.box((-0.375, 0.11, sz), (0.375, 0.14, sz + 0.025), "Chrome")                  # base rails
    for sx in (-0.375, 0.35):
        kit.box((sx, 0.11, -0.235), (sx + 0.025, 0.14, 0.235), "Chrome")
        for sz in (-0.235, 0.21):
            kit.box((sx, 0.14, sz), (sx + 0.025, 1.06, sz + 0.025), "Chrome")              # uprights
        for ry in (0.27, 0.65, 1.035):
            kit.box((sx, ry, -0.21), (sx + 0.025, ry + 0.025, 0.21), "Chrome")             # side rails
    kit.cylinder((0.0, 1.075, -0.2225), 0.016, 0.75, "Chrome", axis="x", segments=8)     # push handle
    for tier, ty in enumerate((0.3, 0.68)):                                              # tiers lean back 15 degrees
        rack = B.Kit(f"{name}Tier{tier}")
        rack.box((-0.345, 0.0, -0.15), (0.345, 0.012, 0.15), "ShelfSteel")                # slotted tray
        rack.box((-0.345, 0.0, -0.165), (0.345, 0.1, -0.15), "Chrome")                    # back stop
        rack.box((-0.345, 0.0, 0.15), (0.345, 0.035, 0.165), "Chrome")                     # front lip
        for k in range(9):
            dx = -0.34 + k * 0.085
            rack.box((dx - 0.002, 0.012, -0.15), (dx + 0.002, 0.12, 0.15), "Chrome")      # slot dividers
        for s in range(8):
            if s in ((2, 6), (1, 4))[tier]:
                continue
            sx = -0.34 + (s + 0.5) * 0.085
            rack.box((sx - 0.03, 0.012, -0.14), (sx + 0.03, 0.3, 0.13), CHART_SPINES[(s + 3 * tier) % 8])  # chart binder
            rack.box((sx - 0.018, 0.19, 0.13), (sx + 0.018, 0.25, 0.133), "Paper")         # spine label
        tx, tz = B.local_point(x, z, yaw, 0.0, 0.02)
        rack.build(tx, tz, yaw, y=y + ty, pitch=-15.0)
    return kit.build(x, z, yaw, y=y)


def o2_cylinder_cart(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    cz = -0.02                                                                           # cylinder axis
    for sx in (-0.15, 0.15):
        kit.cylinder((sx, 0.075, -0.1), 0.075, 0.03, "Rubber", axis="x", segments=12)     # wheel
        kit.cylinder((sx, 0.075, -0.1), 0.03, 0.036, "Chrome", axis="x", segments=8)      # hub
    kit.cylinder((0.0, 0.075, -0.1), 0.008, 0.3, "Chrome", axis="x", segments=6)          # axle
    for sx in (-0.075, 0.065):
        kit.box((sx, 0.06, -0.1), (sx + 0.01, 1.07, -0.075), "Rubber")                    # frame rails
        kit.box((sx, 0.0, -0.075), (sx + 0.01, 0.05, 0.175), "Rubber")                    # foot skids
    kit.box((-0.075, 0.0, 0.15), (0.075, 0.025, 0.175), "Rubber")                         # front foot
    kit.box((-0.075, 0.035, -0.1), (0.075, 0.05, 0.05), "Rubber")                         # cradle plate
    for sy in (0.2, 0.5):
        kit.box((-0.062, sy, cz + 0.056), (0.062, sy + 0.025, cz + 0.062), "Rubber")       # cylinder strap
        for sx in (-0.062, 0.056):
            kit.box((sx, sy, -0.08), (sx + 0.006, sy + 0.025, cz + 0.062), "Rubber")
    kit.cylinder((0.0, 1.08, -0.0875), 0.02, 0.22, "Rubber", axis="x", segments=8)        # handle grip
    top = gas_cylinder(kit, 0.0, 0.05, cz, 0.0555, 0.64)                                # E-size cylinder
    kit.cylinder((0.045, top - 0.03, cz), 0.022, 0.07, "Chrome", axis="x", segments=8)    # regulator
    kit.box((0.055, top - 0.01, cz - 0.005), (0.065, top + 0.01, cz + 0.005), "Chrome")   # gauge stem
    kit.cylinder((0.06, top + 0.035, cz + 0.01), 0.03, 0.02, "Chrome", axis="z", segments=10)  # gauge
    kit.cylinder((0.06, top + 0.035, cz + 0.022), 0.025, 0.006, "PlasticWhite", axis="z", segments=10)
    kit.cylinder((0.088, top - 0.03, cz), 0.018, 0.02, "OxygenGreen", axis="x", segments=8)  # flow knob
    kit.box((0.035, top - 0.06, cz + 0.02), (0.05, top - 0.045, cz + 0.078), "MobileTubeGreen")  # outlet tube
    ring(B, kit, name + "Coil", x, z, yaw, y, (0.0, top - 0.14, cz + 0.07), 0.085, 0.016, "MobileTubeGreen")
    return kit.build(x, z, yaw, y=y)


def o2_cylinder_rack(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    kit.box((-0.475, 0.0, -0.16), (0.475, 0.04, 0.14), "SafetyYellow")                   # base platform
    for sx in (-0.475, 0.435):
        for pz in (-0.16, 0.07):
            kit.box((sx, 0.04, pz), (sx + 0.04, 1.0, pz + 0.03), "SafetyYellow")          # end posts
        kit.box((sx, 0.96, -0.16), (sx + 0.04, 1.0, 0.1), "SafetyYellow")                 # end top rails
    for ry in (0.35, 0.9):
        kit.box((-0.435, ry, -0.16), (0.435, ry + 0.04, -0.12), "SafetyYellow")           # back rails
    for i in range(5):
        gas_cylinder(kit, -0.37 + i * 0.185, 0.04, -0.032, 0.088, 1.1, cap=0.136)        # M-size cylinders
    for i in range(17):                                                                  # restraining chain
        lx = -0.435 + i * 0.05
        if i % 2:
            kit.box((lx, 0.789, 0.081), (lx + 0.06, 0.811, 0.089), "Chrome")
        else:
            kit.box((lx, 0.796, 0.074), (lx + 0.06, 0.804, 0.096), "Chrome")
    for hx in (-0.1, 0.1):
        kit.box((hx - 0.004, 0.785, 0.082), (hx + 0.004, 0.81, 0.09), "Chrome")             # sign hooks
    kit.box((-0.15, 0.68, 0.087), (0.15, 0.785, 0.093), "SignWhite")                       # hanging plate
    obj = kit.build(x, z, yaw, y=y)
    B.kit_text(name + "Label", "OXYGEN", x, z, yaw, y, (0.0, 0.732, 0.096), size=0.07, mat="SignGreen")
    return obj


def mobile_vitals(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, on: bool = False):
    pz = -0.02                                                                           # pole, centring the base
    star_base(B, name, x, z, yaw, y, 0.28, pz)
    kit = B.Kit(name)
    kit.cylinder((0.0, 0.085, pz), 0.035, 0.06, "Chrome", segments=8)                     # hub
    kit.cylinder((0.0, 0.6, pz), 0.016, 1.0, "Chrome", segments=8)                        # pole
    kit.box((-0.04, 1.06, pz - 0.035), (0.04, 1.1, pz + 0.04), "PlasticGrey")             # head mount
    face = pz + 0.12
    kit.box((-0.14, 1.1, pz - 0.09), (0.14, 1.27, face), "PlasticBeige")                  # monitor head
    for dx in (-0.12, -0.04, 0.04):
        kit.box((dx, 1.19, face), (dx + 0.075, 1.25, face + 0.004), "ScreenGreen" if on else "ScreenDark")  # readouts
    for dx in (-0.12, -0.08, -0.04):
        kit.box((dx, 1.125, face), (dx + 0.03, 1.15, face + 0.006), "PlasticGrey")          # keys
    kit.cylinder((0.08, 1.14, face + 0.01), 0.013, 0.02, "Rubber", axis="z", segments=8)  # cuff hose port
    for hx in (-0.09, 0.07):
        kit.box((hx, 1.27, pz - 0.012), (hx + 0.02, 1.3, pz + 0.012), "PlasticGrey")        # handle posts
    kit.box((-0.09, 1.285, pz - 0.012), (0.09, 1.3, pz + 0.012), "PlasticGrey")            # carry handle
    kit.box((0.14, 1.12, pz - 0.03), (0.185, 1.25, pz + 0.05), "PlasticWhite")             # thermometer holder
    kit.box((0.152, 1.25, pz), (0.172, 1.29, pz + 0.025), "SignBlue")                      # probe handle
    b0, b1 = pz + 0.025, pz + 0.2                                                        # wire basket
    kit.box((-0.12, 0.84, b0), (0.12, 0.848, b1), "Chrome")
    for sx in (-0.12, 0.112):
        for sz in (b0, b1 - 0.008):
            kit.box((sx, 0.848, sz), (sx + 0.008, 0.93, sz + 0.008), "Chrome")              # corner wires
        kit.box((sx, 0.922, b0), (sx + 0.008, 0.93, b1), "Chrome")                         # rim
    for sz in (b0, b1 - 0.008):
        kit.box((-0.12, 0.922, sz), (0.12, 0.93, sz + 0.008), "Chrome")
    kit.box((-0.12, 0.88, b1 - 0.008), (0.12, 0.886, b1), "Chrome")                        # front wire
    kit.box((-0.02, 0.9, pz), (0.02, 0.93, b0 + 0.008), "Chrome")                          # basket bracket
    kit.box((-0.105, 0.848, b0 + 0.02), (0.03, 0.89, b1 - 0.02), "SignBlue")               # folded BP cuff
    kit.box((0.045, 0.848, b0 + 0.03), (0.1, 0.96, b0 + 0.11), "Paper")                    # probe covers
    kit.box((-0.006, 0.735, pz), (0.006, 0.755, pz + 0.05), "Chrome")                      # hose hook
    ring(B, kit, name + "Hose", x, z, yaw, y, (0.0, 0.65, pz + 0.038), 0.09, 0.014, "Rubber")  # coiled cuff hose
    return kit.build(x, z, yaw, y=y)


def infusion_pump_pole(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, bags: int = 1,
                       pump_on: bool = False):
    pz = -0.022                                                                          # pole, centring the base
    star_base(B, name, x, z, yaw, y, 0.31, pz)
    kit = B.Kit(name)
    kit.cylinder((0.0, 0.085, pz), 0.035, 0.06, "Chrome", segments=8)                     # hub
    kit.cylinder((0.0, 1.035, pz), 0.0125, 1.9, "Chrome", segments=8)                     # pole
    kit.cylinder((0.0, 1.5, pz), 0.02, 0.05, "Chrome", segments=8)                        # height lock
    kit.cylinder((0.03, 1.5, pz), 0.012, 0.03, "Rubber", axis="x", segments=6)
    kit.box((-0.14, 1.96, pz - 0.007), (0.14, 1.975, pz + 0.007), "Chrome")              # hook bar
    for s in (-1.0, 1.0):
        for xa, xb, y0, y1 in ((0.133, 0.147, 1.96, 2.05), (0.133, 0.17, 2.036, 2.05), (0.156, 0.17, 2.005, 2.05)):
            x0, x1 = sorted((s * xa, s * xb))
            kit.box((x0, y0, pz - 0.007), (x1, y1, pz + 0.007), "Chrome")                  # two-hook top
    for i in range(max(1, min(2, bags))):
        bx = 0.163 if i == 0 else -0.163
        kit.box((bx - 0.006, 1.95, pz - 0.004), (bx + 0.006, 2.012, pz + 0.004), "PlasticWhite")  # hanger tab
        kit.box((bx - 0.07, 1.68, pz - 0.018), (bx + 0.07, 1.95, pz + 0.018), "Curtain")    # saline bag
        kit.box((bx - 0.045, 1.76, pz + 0.018), (bx + 0.045, 1.88, pz + 0.021), "Paper")    # bag label
        kit.cylinder((bx, 1.66, pz), 0.008, 0.04, "PlasticWhite", segments=6)              # port
        kit.cylinder((bx, 1.61, pz), 0.013, 0.06, "PlasticWhite", segments=8)              # drip chamber
    kit.box((0.16, 0.986, pz - 0.003), (0.166, 1.58, pz + 0.003), "PlasticWhite")          # line down beside the pump
    kit.box((0.1, 0.986, pz - 0.003), (0.106, 1.2, pz + 0.003), "PlasticWhite")            # ... and back up
    kit.box((0.085, 1.197, pz - 0.003), (0.106, 1.203, pz + 0.07), "PlasticWhite")         # into the pump
    ring(B, kit, name + "Line", x, z, yaw, y, (0.133, 1.0, pz), 0.03, 0.006, "PlasticWhite", edges="b", diagonals="lb")
    if bags > 1:
        kit.box((-0.166, 1.4, pz - 0.003), (-0.16, 1.58, pz + 0.003), "PlasticWhite")      # secondary line
        kit.box((-0.166, 1.4, pz - 0.003), (-0.04, 1.406, pz + 0.003), "PlasticWhite")
        kit.box((-0.046, 1.3, pz - 0.003), (-0.04, 1.406, pz + 0.07), "PlasticWhite")
    kit.box((-0.03, 1.11, pz - 0.03), (0.03, 1.21, pz + 0.025), "Chrome")                  # pole clamp
    kit.cylinder((0.0, 1.16, pz - 0.045), 0.015, 0.03, "Rubber", axis="z", segments=8)    # clamp screw
    p0, p1 = pz + 0.025, pz + 0.165                                                     # infusion pump
    kit.box((-0.1, 1.02, p0), (0.09, 1.3, p1), "PlasticGrey")
    kit.box((-0.09, 1.04, p1), (0.015, 1.25, p1 + 0.006), "PlasticWhite")                 # tubing door
    kit.box((0.03, 1.21, p1), (0.08, 1.27, p1 + 0.004), "ScreenGreen" if pump_on else "ScreenDark")  # display
    kit.box((0.03, 1.06, p1), (0.08, 1.19, p1 + 0.004), "Rubber")                          # keypad
    kit.box((-0.07, 1.3, p0 + 0.05), (0.05, 1.318, p1 - 0.05), "PlasticGrey")             # carry grip
    return kit.build(x, z, yaw, y=y)


def kick_bucket(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    for cx, cz in ((0.13, 0.0), (-0.13, 0.0), (0.0, 0.13), (0.0, -0.13)):
        caster(kit, cx, cz, r=0.03, top=0.08)
    kit.cylinder((0.0, 0.1, 0.0), 0.21, 0.04, "Rubber", segments=16)                      # bumper ring
    kit.cylinder((0.0, 0.125, 0.0), 0.19, 0.01, "Chrome", segments=16)                    # base ring
    for lx, lz in ((0.172, 0.0), (-0.172, 0.0), (0.0, 0.172), (0.0, -0.172)):
        kit.box((lx - 0.006, 0.13, lz - 0.006), (lx + 0.006, 0.39, lz + 0.006), "Chrome")   # uprights
    kit.cylinder((0.0, 0.384, 0.0), 0.178, 0.012, "Chrome", segments=16)                  # top ring
    for r, y0, y1 in ((0.125, 0.14, 0.22), (0.14, 0.22, 0.3), (0.155, 0.3, 0.395)):
        kit.cylinder((0.0, (y0 + y1) / 2.0, 0.0), r, y1 - y0, "Chrome", segments=16)     # tapered bucket
    kit.cylinder((0.0, 0.4025, 0.0), 0.163, 0.015, "Chrome", segments=16)                 # rolled rim
    kit.cylinder((0.0, 0.405, 0.0), 0.15, 0.015, "ShelfSteel", segments=16)               # open interior
    return kit.build(x, z, yaw, y=y)


def rounded_box(kit, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, r: float, mat: str) -> None:
    """Box with its vertical edges rounded to radius r."""
    kit.box((x0 + r, y0, z0), (x1 - r, y1, z1), mat)
    kit.box((x0, y0, z0 + r), (x1, y1, z1 - r), mat)
    for cx in (x0 + r, x1 - r):
        for cz in (z0 + r, z1 - r):
            kit.cylinder((cx, (y0 + y1) / 2.0, cz), r, y1 - y0, mat, segments=8)


def waste_bin(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, kind: str = "general"):
    shell, bag = ("MedicalRed", "CartRed") if kind == "biohazard" else ("PlasticGrey", "Rubber")
    kit = B.Kit(name)
    hw, back, face = 0.175, -0.15, 0.14
    rounded_box(kit, -hw, hw, 0.0, 0.53, back, face, 0.035, shell)                         # body
    kit.box((-hw - 0.004, 0.5, back - 0.004), (hw + 0.004, 0.535, face + 0.004), bag)      # bag folded over the rim
    rounded_box(kit, -hw - 0.012, hw + 0.012, 0.535, 0.59, back - 0.012, face + 0.012, 0.04, shell)  # hinged lid
    kit.box((-hw + 0.03, 0.59, back + 0.03), (hw - 0.03, 0.615, face - 0.03), shell)       # lid crown
    kit.cylinder((0.0, 0.56, back - 0.016), 0.014, 0.3, shell, axis="x", segments=8)       # hinge barrel
    kit.box((-0.02, 0.03, face - 0.02), (0.02, 0.05, face + 0.01), "ShelfSteel")           # pedal arm
    kit.box((-0.075, 0.025, face + 0.01), (0.075, 0.05, face + 0.045), "ShelfSteel")       # foot pedal
    obj = kit.build(x, z, yaw, y=y)
    if kind == "biohazard":
        B.kit_text(name + "Label", "BIOHAZARD", x, z, yaw, y, (0.0, 0.41, face + 0.003), size=0.045)
    return obj


def soiled_linen_hamper(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, bag: str = "blue"):
    cloth = "AirYellow" if bag == "yellow" else "MattressBlue"
    kit = B.Kit(name)
    for cx in (-0.14, 0.14):
        for cz in (-0.14, 0.14):
            caster(kit, cx, cz, r=0.035, top=0.08)
    ring(B, kit, name + "Base", x, z, yaw, y, (0.0, 0.09, 0.0), 0.2, 0.02, "Chrome", flat=True)   # base ring
    for lx, lz in ((0.2, 0.0), (-0.2, 0.0), (0.0, 0.2), (0.0, -0.2)):
        kit.box((lx - 0.01, 0.08, lz - 0.01), (lx + 0.01, 0.82, lz + 0.01), "Chrome")         # legs
    kit.cylinder((0.0, 0.27, 0.0), 0.15, 0.06, cloth, segments=12)                           # bag bottom
    kit.cylinder((0.0, 0.565, 0.0), 0.19, 0.53, cloth, segments=12)                          # hanging bag
    kit.cylinder((0.0, 0.84, 0.0), 0.235, 0.07, cloth, segments=12)                          # cuff over the ring
    kit.cylinder((0.0, 0.8875, 0.0), 0.245, 0.025, "PlasticWhite", segments=16)              # lid
    kit.box((-0.05, 0.9, -0.012), (0.05, 0.92, 0.012), "PlasticWhite")                       # lid grip
    kit.box((-0.04, 0.86, -0.25), (0.04, 0.905, -0.225), "Chrome")                           # lid hinge
    kit.box((-0.006, 0.05, -0.236), (0.006, 0.87, -0.224), "Chrome")                         # pedal linkage
    kit.box((-0.006, 0.05, -0.236), (0.006, 0.062, 0.21), "Chrome")
    kit.box((-0.06, 0.035, 0.2), (0.06, 0.06, 0.25), "Rubber")                               # foot pedal
    return kit.build(x, z, yaw, y=y)


def exam_lamp(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, on: bool = False):
    from math import cos, radians, sin
    pz = -0.045                                                                          # pole, centring lamp and base
    star_base(B, name, x, z, yaw, y, 0.28, pz)
    kit = B.Kit(name)
    kit.cylinder((0.0, 0.085, pz), 0.035, 0.06, "Chrome", segments=8)                     # hub
    kit.cylinder((0.0, 0.6, pz), 0.014, 1.0, "Chrome", segments=8)                        # pole
    kit.cylinder((0.0, 0.98, pz), 0.02, 0.05, "Rubber", segments=8)                       # height collar
    kit.cylinder((0.0, 1.2, pz), 0.009, 0.2, "ShelfSteel", segments=6)                    # gooseneck, straight part
    ny, nz, step = 1.3, pz, 0.043
    for i in range(7):                                                                   # gooseneck curving forward
        angle = (i + 0.5) * 20.0
        seg = B.Kit(f"{name}Neck{i}")
        seg.cylinder((0.0, step / 2.0, 0.0), 0.009, step + 0.008, "ShelfSteel", segments=6)
        sx, sz = B.local_point(x, z, yaw, 0.0, nz)
        seg.build(sx, sz, yaw, y=y + ny, pitch=angle)
        ny += step * cos(radians(angle))
        nz += step * sin(radians(angle))
    head = B.Kit(name + "Head")                                                          # lamp head, down and forward
    head.cylinder((0.0, 0.01, 0.0), 0.016, 0.024, "Chrome", segments=8)                  # swivel
    head.cylinder((0.0, 0.06, 0.0), 0.055, 0.08, "PlasticBeige", segments=12)            # shade
    head.cylinder((0.0, 0.102, 0.0), 0.045, 0.006, "LampGlow" if on else "Chrome", segments=12)  # lens
    hx, hz = B.local_point(x, z, yaw, 0.0, nz)
    head.build(hx, hz, yaw, y=y + ny, pitch=140.0)
    return kit.build(x, z, yaw, y=y)


PROPS = {
    "crash_cart": {
        "build": crash_cart,
        "size": (0.80, 1.35, 0.62),
        "mount": "floor",
        "collide": True,
        "variants": [{}, {"drawers_open": [1, 3]}],
        "desc": "Red five-drawer crash cart with defibrillator, backboard and side oxygen cylinder",
    },
    "med_cart": {
        "build": med_cart,
        "size": (0.85, 1.10, 0.60),
        "mount": "floor",
        "collide": True,
        "variants": [{}, {"locked": False}],
        "desc": "Blue medication cart with pill drawers, keypad lock, waste bin, sharps holder and binder",
    },
    "linen_cart": {
        "build": linen_cart,
        "size": (1.20, 1.45, 0.62),
        "mount": "floor",
        "collide": True,
        "variants": [{}],
        "desc": "Covered stainless linen cart with folded linen and a rolled-up blue vinyl front flap",
    },
    "isolation_cart": {
        "build": isolation_cart,
        "size": (0.50, 1.10, 0.42),
        "mount": "floor",
        "collide": True,
        "variants": [{}],
        "desc": "Three-drawer isolation supply cart with yellow gowns, masks, gloves and an ISOLATION sign",
    },
    "chart_rack": {
        "build": chart_rack,
        "size": (0.75, 1.10, 0.48),
        "mount": "floor",
        "collide": True,
        "variants": [{}],
        "desc": "Rolling aluminium chart rack with two angled tiers of patient chart binders",
    },
    "o2_cylinder_cart": {
        "build": o2_cylinder_cart,
        "size": (0.34, 1.10, 0.36),
        "mount": "floor",
        "collide": True,
        "variants": [{}],
        "desc": "E-size oxygen cylinder on a two-wheel cart with regulator gauge and coiled tubing",
    },
    "o2_cylinder_rack": {
        "build": o2_cylinder_rack,
        "size": (0.95, 1.30, 0.32),
        "mount": "floor",
        "collide": True,
        "variants": [{}],
        "desc": "Floor rack of five large oxygen cylinders behind a chain with an OXYGEN plate",
    },
    "mobile_vitals": {
        "build": mobile_vitals,
        "size": (0.55, 1.30, 0.55),
        "mount": "floor",
        "collide": True,
        "variants": [{}, {"on": True}],
        "desc": "Vital-signs monitor on a five-caster rolling stand with basket and coiled cuff hose",
    },
    "infusion_pump_pole": {
        "build": infusion_pump_pole,
        "size": (0.60, 2.05, 0.60),
        "mount": "floor",
        "collide": True,
        "variants": [{}, {"bags": 2, "pump_on": True}],
        "desc": "IV pole with saline bags and a clamped infusion pump",
    },
    "kick_bucket": {
        "build": kick_bucket,
        "size": (0.42, 0.42, 0.42),
        "mount": "floor",
        "collide": True,
        "variants": [{}],
        "desc": "Stainless kick bucket in a ring frame on casters with a bumper ring",
    },
    "waste_bin": {
        "build": waste_bin,
        "size": (0.38, 0.62, 0.36),
        "mount": "floor",
        "collide": True,
        "variants": [{}, {"kind": "biohazard"}],
        "desc": "Step-on pedal waste bin, general or red biohazard",
    },
    "soiled_linen_hamper": {
        "build": soiled_linen_hamper,
        "size": (0.50, 0.95, 0.50),
        "mount": "floor",
        "collide": True,
        "variants": [{}, {"bag": "yellow"}],
        "desc": "Chrome ring hamper stand on casters with a fabric bag and foot-operated lid",
    },
    "exam_lamp": {
        "build": exam_lamp,
        "size": (0.55, 1.45, 0.55),
        "mount": "floor",
        "collide": True,
        "variants": [{}, {"on": True}],
        "desc": "Gooseneck examination lamp on a five-caster base",
    },
}
