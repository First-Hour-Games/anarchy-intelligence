"""Clinical wall equipment for bedsides and exam rooms (see README.md)."""

from math import atan2, degrees, hypot


def label(B, name: str, words: str, x: float, z: float, yaw: float, y: float, local: tuple, size: float,
          mat: str = "Rubber", res: int = 2):
    """kit_text left flat (no extrusion): about a quarter of the triangles of the 2 mm extruded label."""
    obj = B.kit_text(name, words, x, z, yaw, y, local, size=size, mat=mat)
    obj.data.extrude = 0.0
    obj.data.resolution_u = res
    return obj


def bar(B, name: str, x: float, z: float, yaw: float, y: float, a: tuple, b: tuple, y0: float, y1: float,
        half: float, mat: str):
    """Horizontal bar from local (x, z) point a to b, as a second kit turned to follow it."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    px, pz = B.local_point(x, z, yaw, a[0], a[1])
    kit = B.Kit(name).box((-half, y0, 0.0), (half, y1, hypot(dx, dz)), mat)
    return kit.build(px, pz, yaw + degrees(atan2(dx, dz)), y=y)


def strand(B, name: str, x: float, z: float, yaw: float, y: float, a: tuple, b: tuple, lz: float, radius: float,
           mat: str):
    """Cable from local (x, y) point a to b in the plane z = lz, as a second kit rolled to follow it."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    px, pz = B.local_point(x, z, yaw, a[0], lz)
    kit = B.Kit(name).cylinder((0.0, hypot(dx, dy) / 2.0, 0.0), radius, hypot(dx, dy), mat, segments=6)
    return kit.build(px, pz, yaw, y=y + a[1], roll=degrees(atan2(-dx, dy)))


def bed_headwall(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.95, bed: str = "1",
                 light_on: bool = False):
    kit = B.Kit(name)
    kit.box((-0.8, 0.35, -0.08), (0.8, 0.71, 0.0), "PlasticBeige")                         # powder-coated panel
    kit.box((-0.7, 0.67, -0.08), (0.7, 0.72, 0.012), "Appliance")                            # reading-light housing
    kit.box((-0.66, 0.66, -0.03), (0.66, 0.69, 0.016), "LampGlow" if light_on else "PanelDead")  # reading-light lens
    # Gas outlets: O2, O2, air, vacuum (the right vacuum outlet sits behind the suction regulator).
    for ox, ring, face in ((-0.64, "OxygenGreen", None), (-0.5, "OxygenGreen", "Chrome"),
                           (-0.36, "AirYellow", "Chrome"), (0.4, "Rubber", "PlasticWhite")):
        kit.cylinder((ox, 0.53, 0.006), 0.03, 0.012, ring, axis="z", segments=8)            # outlet ring
        if face:
            kit.box((ox - 0.016, 0.514, 0.012), (ox + 0.016, 0.546, 0.02), face)              # valve face
    for px, mat in ((-0.15, "PlasticGrey"), (0.03, "MedicalRed")):                            # normal / emergency power
        kit.box((px - 0.07, 0.47, 0.0), (px + 0.07, 0.59, 0.005), "PlasticWhite")           # two-gang plate
        for sx in (px - 0.035, px + 0.035):
            kit.box((sx - 0.02, 0.495, 0.005), (sx + 0.02, 0.565, 0.011), mat)               # duplex receptacle
    kit.box((0.215, 0.49, 0.0), (0.265, 0.57, 0.006), "PlasticWhite")                      # nurse-call jack plate
    kit.cylinder((0.24, 0.32, 0.014), 0.0075, 0.36, "PlasticGrey", segments=6)             # coiled pendant cord
    kit.box((0.222, 0.06, 0.0), (0.258, 0.15, 0.024), "PlasticBeige")                      # call pendant
    kit.box((0.232, 0.118, 0.024), (0.248, 0.134, 0.03), "MedicalRed")                     # call button
    kit.box((-0.665, 0.48, 0.012), (-0.615, 0.55, 0.06), "Chrome")                         # O2 flowmeter body
    kit.cylinder((-0.64, 0.6, 0.04), 0.016, 0.1, "DoorGlass", segments=6)                   # flow tube
    kit.box((-0.663, 0.65, 0.02), (-0.617, 0.672, 0.06), "Chrome")                          # flowmeter head
    kit.cylinder((-0.64, 0.684, 0.04), 0.013, 0.024, "OxygenGreen", segments=6)             # flow knob
    kit.cylinder((-0.64, 0.465, 0.044), 0.022, 0.03, "PlasticWhite", segments=6)           # humidifier cap
    kit.cylinder((-0.64, 0.375, 0.044), 0.036, 0.15, "DoorGlass", segments=8)              # humidifier bottle
    kit.box((0.52, 0.46, 0.012), (0.58, 0.56, 0.048), "Chrome")                            # suction regulator
    kit.cylinder((0.55, 0.53, 0.054), 0.027, 0.012, "PlasticWhite", segments=8)            # vacuum gauge
    kit.box((0.548, 0.53, 0.06), (0.552, 0.552, 0.063), "Rubber")                          # gauge needle
    kit.box((0.566, 0.24, 0.026), (0.574, 0.46, 0.034), "PlasticWhite")                    # suction tubing
    kit.box((0.45, 0.2, -0.08), (0.65, 0.23, -0.068), "Chrome")                            # short wall rail
    kit.box((0.535, 0.17, -0.068), (0.565, 0.23, -0.036), "Chrome")                        # canister bracket
    kit.cylinder((0.55, 0.18, 0.02), 0.06, 0.02, "Chrome", segments=8)                     # bracket ring
    kit.cylinder((0.55, 0.11, 0.02), 0.055, 0.22, "DoorGlass", segments=8)                 # suction canister
    kit.cylinder((0.55, 0.232, 0.02), 0.058, 0.024, "PlasticWhite", segments=8)            # canister lid
    if bed:
        kit.box((0.69, 0.56, 0.0), (0.79, 0.62, 0.004), "SignBlue")                         # bed placard
        label(B, name + "Bed", "BED " + str(bed), x, z, yaw, y, (0.74, 0.588, 0.006), 0.037, "SignWhite")
    return kit.build(x, z, yaw, y=y)


def wall_vitals_monitor(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.5, on: bool = False):
    wall, elbow, head = (-0.12, -0.195), (0.1, -0.07), (0.0, 0.041)                       # arm pivots (local x, z)
    kit = B.Kit(name)
    kit.box((-0.16, 0.05, -0.225), (-0.08, 0.3, -0.21), "ShelfSteel")                      # wall channel
    kit.cylinder((wall[0], 0.115, wall[1]), 0.022, 0.05, "PlasticGrey", segments=8)        # wall pivot
    kit.cylinder((elbow[0], 0.135, elbow[1]), 0.022, 0.08, "PlasticGrey", segments=8)      # elbow
    kit.cylinder((head[0], 0.17, head[1]), 0.02, 0.07, "PlasticGrey", segments=8)          # tilt head
    kit.box((-0.226, 0.22, 0.03), (-0.21, 0.26, 0.05), "Rubber")                           # patient cable plug
    kit.cylinder((-0.218, 0.16, 0.04), 0.006, 0.12, "Rubber", segments=6)                  # patient cable
    obj = kit.build(x, z, yaw, y=y)
    loop = ((-0.218, 0.1), (-0.18, 0.008), (-0.11, 0.008), (-0.02, 0.14))                  # sagging cable loop
    for i in range(3):
        strand(B, name + f"Cable{i}", x, z, yaw, y, loop[i], loop[i + 1], 0.04, 0.006, "Rubber")
    bar(B, name + "Arm1", x, z, yaw, y, wall, elbow, 0.1, 0.135, 0.018, "PlasticGrey")
    bar(B, name + "Arm2", x, z, yaw, y, elbow, head, 0.135, 0.17, 0.018, "PlasticGrey")
    mon = B.Kit(name + "Monitor")                                                           # origin on the tilt axis
    mon.box((-0.06, -0.02, -0.08), (0.06, 0.0, 0.08), "ShelfSteel")                        # tilt plate
    mon.box((-0.21, 0.0, 0.0), (0.21, 0.3, 0.13), "PlasticGrey")                           # bezel housing
    mon.box((-0.16, 0.03, -0.12), (0.16, 0.27, 0.0), "PlasticGrey")                        # CRT back
    mon.box((-0.19, 0.05, 0.13), (0.11, 0.27, 0.134), "ScreenDark")                        # 0.30 x 0.22 screen
    mon.box((0.13, 0.05, 0.13), (0.19, 0.27, 0.133), "Rubber")                             # key panel
    for ky in (0.17, 0.205, 0.24):
        mon.box((0.14, ky, 0.133), (0.18, ky + 0.02, 0.138), "PlasticWhite")              # keys
    mon.cylinder((0.16, 0.1, 0.14), 0.018, 0.014, "PlasticWhite", axis="z", segments=8)   # trim knob
    if on:                                                                                  # ECG, pleth, heart rate
        rects = [(-0.18, 0.198, 0.04, 0.202), (-0.18, 0.118, 0.04, 0.122)]
        for bx in (-0.12, -0.01):
            rects += [(bx - 0.03, 0.198, bx - 0.018, 0.206), (bx, 0.198, bx + 0.004, 0.25),
                      (bx + 0.004, 0.186, bx + 0.008, 0.202), (bx + 0.03, 0.198, bx + 0.05, 0.211)]
        for bx in (-0.16, -0.08, 0.0):
            rects += [(bx, 0.118, bx + 0.004, 0.142), (bx + 0.004, 0.138, bx + 0.02, 0.142),
                      (bx + 0.02, 0.124, bx + 0.024, 0.142)]
        rects += [(0.055, 0.238, 0.073, 0.242), (0.069, 0.21, 0.073, 0.242), (0.08, 0.238, 0.098, 0.242),
                  (0.094, 0.226, 0.098, 0.242), (0.08, 0.224, 0.098, 0.228), (0.08, 0.21, 0.084, 0.226),
                  (0.08, 0.21, 0.098, 0.214)]
        for x0, y0, x1, y1 in rects:
            mon.box((x0, y0, 0.134), (x1, y1, 0.137), "ScreenGreen")
    px, pz = B.local_point(x, z, yaw, head[0], head[1])
    mon.build(px, pz, yaw, y=y + 0.204, pitch=10.0)
    return obj



def diagnostic_set(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.2):
    kit = B.Kit(name)
    kit.box((-0.31, 0.05, -0.07), (0.31, 0.34, -0.06), "PlasticWhite")                     # backplate
    kit.box((-0.295, 0.13, -0.06), (-0.005, 0.23, 0.0), "Appliance")                         # instrument transformer
    for hx in (-0.215, -0.085):
        kit.cylinder((hx, 0.18, 0.018), 0.0145, 0.11, "Rubber", segments=8)                 # instrument handle
        kit.box((hx - 0.022, 0.17, 0.0), (hx + 0.022, 0.195, 0.036), "PlasticGrey")         # handle cradle
    kit.cylinder((-0.215, 0.26, 0.018), 0.016, 0.05, "Chrome", segments=8)                 # otoscope head
    kit.cylinder((-0.215, 0.28, 0.04), 0.007, 0.03, "Rubber", axis="z", segments=6)        # ear speculum
    kit.box((-0.101, 0.235, 0.008), (-0.069, 0.295, 0.028), "Chrome")                      # ophthalmoscope head
    kit.cylinder((-0.085, 0.27, 0.031), 0.011, 0.006, "Rubber", axis="z", segments=6)      # lens wheel
    kit.box((-0.097, 0.295, 0.012), (-0.073, 0.31, 0.026), "Rubber")                       # brow rest
    kit.cylinder((0.035, 0.2, -0.035), 0.022, 0.14, "DoorGlass", segments=8)               # specula dispenser
    kit.cylinder((0.035, 0.278, -0.035), 0.024, 0.016, "PlasticWhite", segments=6)
    kit.cylinder((0.035, 0.122, -0.035), 0.024, 0.016, "PlasticWhite", segments=6)
    kit.cylinder((0.185, 0.255, -0.0475), 0.065, 0.025, "Chrome", axis="z", segments=12)   # aneroid dial bezel
    kit.cylinder((0.185, 0.255, -0.0335), 0.058, 0.003, "PlasticWhite", axis="z", segments=12)  # dial face
    kit.cylinder((0.185, 0.255, -0.0305), 0.05, 0.003, "Rubber", axis="z", segments=12)    # mmHg scale ring
    kit.cylinder((0.185, 0.255, -0.0275), 0.043, 0.003, "PlasticWhite", axis="z", segments=12)
    kit.cylinder((0.185, 0.13, -0.04), 0.006, 0.12, "Rubber", segments=6)                 # cuff hose
    kit.box((0.09, 0.0, -0.06), (0.28, 0.006, 0.06), "Chrome")                             # cuff basket floor
    for wy in (0.04, 0.082):
        kit.box((0.09, wy, 0.054), (0.28, wy + 0.006, 0.06), "Chrome")                     # front wires
    for bx in (0.09, 0.274):
        kit.box((bx, 0.082, -0.06), (bx + 0.006, 0.088, 0.06), "Chrome")                   # side rims
        kit.box((bx, 0.0, 0.054), (bx + 0.006, 0.088, 0.06), "Chrome")                     # corner posts
    kit.cylinder((0.185, 0.04, -0.005), 0.034, 0.17, "PlasticGrey", axis="x", segments=8)  # rolled cuff
    kit.box((0.14, 0.03, 0.06), (0.2, 0.092, 0.065), "PlasticGrey")                        # cuff tail over the rim
    obj = kit.build(x, z, yaw, y=y)
    strand(B, name + "Needle", x, z, yaw, y, (0.185, 0.255), (0.153, 0.223), -0.0245, 0.002, "Rubber")  # needle at zero
    for i, (hx, low) in enumerate(((-0.215, 0.006), (-0.085, 0.035))):                      # coiled cords looping down
        strand(B, name + f"Cord{i}a", x, z, yaw, y, (hx, 0.13), (hx + 0.022, low), 0.006, 0.0075, "Rubber")
        strand(B, name + f"Cord{i}b", x, z, yaw, y, (hx + 0.022, low), (hx + 0.045, 0.13), 0.006, 0.0075, "Rubber")
    return obj


def sharps_container(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.25, full: bool = False):
    kit = B.Kit(name)
    kit.box((-0.13, 0.0, -0.08), (0.13, 0.36, -0.072), "FilingGrey")                       # bracket plate
    kit.box((-0.14, 0.0, -0.072), (0.14, 0.025, 0.07), "FilingGrey")                         # bracket tray
    kit.box((-0.14, 0.025, 0.062), (0.14, 0.045, 0.07), "FilingGrey")                        # tray lip
    for sx in (-0.14, 0.13):
        kit.box((sx, 0.12, -0.072), (sx + 0.01, 0.2, 0.03), "FilingGrey")                   # side clips
    kit.box((-0.13, 0.025, -0.072), (0.13, 0.27, 0.06), "MedicalRed")                       # container body
    kit.box((-0.133, 0.27, -0.075), (0.133, 0.33, 0.063), "PlasticWhite")                  # lid
    kit.box((-0.1, 0.33, -0.05), (0.1, 0.35, 0.03), "PlasticWhite")                         # lid grip
    if full:
        kit.box((-0.092, 0.283, 0.063), (0.092, 0.32, 0.068), "PlasticWhite")              # mouth shut
        kit.box((-0.055, 0.21, 0.06), (0.055, 0.258, 0.064), "SafetyYellow")               # FULL tag
        label(B, name + "Full", "FULL", x, z, yaw, y, (0.0, 0.232, 0.066), 0.037)
    else:
        kit.box((-0.09, 0.285, 0.063), (0.09, 0.318, 0.066), "Rubber")                     # mouth opening
        kit.box((-0.12, 0.236, 0.06), (0.12, 0.24, 0.062), "SignWhite")                    # fill line
    label(B, name + "Label", "SHARPS", x, z, yaw, y, (0.0, 0.16, 0.062), 0.042, "SignWhite")
    return kit.build(x, z, yaw, y=y)


def glove_box_holder(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.2):
    kit = B.Kit(name)
    for wy in (0.05, 0.2):
        kit.box((-0.215, wy, -0.06), (0.215, wy + 0.006, -0.052), "Chrome")                # back wires
    kit.box((-0.215, 0.0, -0.06), (0.215, 0.008, 0.03), "Chrome")                          # wire shelf
    for wy in (0.03, 0.12):
        kit.box((-0.215, wy, 0.024), (0.215, wy + 0.006, 0.03), "Chrome")                  # front retaining wires
    for wx in (-0.215, -0.072, 0.066, 0.209):
        kit.box((wx, 0.0, 0.024), (wx + 0.006, 0.13, 0.03), "Chrome")                      # front posts
    for wx in (-0.215, 0.209):
        kit.box((wx, 0.124, -0.052), (wx + 0.006, 0.13, 0.024), "Chrome")                  # side wires
    for i, (bx, mat, size) in enumerate(((-0.137, "GloveBlue", "S"), (0.0, "GlovePurple", "M"), (0.137, "PlasticWhite", "L"))):
        kit.box((bx - 0.062, 0.008, -0.052), (bx + 0.062, 0.248, 0.02), mat)                # glove box on end
        kit.box((bx - 0.038, 0.19, 0.02), (bx + 0.038, 0.232, 0.023), "Rubber")            # dispenser opening
        kit.box((bx - 0.026, 0.2, 0.012), (bx + 0.02, 0.268, 0.034), mat)                   # glove cuff poking out
        kit.box((bx - 0.004 - 0.012 * (i - 1), 0.25, 0.016), (bx + 0.014 - 0.012 * (i - 1), 0.28, 0.03), mat)  # fingers
        label(B, name + "Size" + size, size, x, z, yaw, y, (bx, 0.08, 0.022), 0.05,
              "Rubber" if mat == "PlasticWhite" else "SignWhite")
    return kit.build(x, z, yaw, y=y)


def sanitizer_dispenser(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.0, kind: str = "sanitizer"):
    bar, fluid = ("GloveBlue", "GloveBlue") if kind == "sanitizer" else ("PlasticGrey", "Linen")
    kit = B.Kit(name)
    kit.box((-0.05, 0.0, -0.055), (0.05, 0.27, -0.047), "PlasticWhite")                    # wall plate
    kit.box((-0.06, 0.05, -0.047), (0.06, 0.28, 0.035), "PlasticWhite")                      # dispenser body
    kit.box((-0.05, 0.09, 0.035), (0.05, 0.18, 0.05), bar)                                    # push bar
    kit.box((-0.02, 0.2, 0.031), (0.02, 0.245, 0.037), "DoorGlass")                          # level window
    kit.box((-0.016, 0.204, 0.031), (0.016, 0.222, 0.039), fluid)                            # fluid level
    kit.box((-0.008, 0.038, -0.01), (0.008, 0.05, 0.012), "Rubber")                          # nozzle
    kit.box((-0.045, 0.0, -0.047), (0.045, 0.014, 0.045), "PlasticGrey")                     # drip tray
    kit.box((-0.035, 0.014, -0.03), (0.035, 0.016, 0.035), "Rubber")                         # tray grille
    return kit.build(x, z, yaw, y=y)


def paper_towel_dispenser(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.15):
    kit = B.Kit(name)
    kit.box((-0.15, 0.06, -0.06), (0.15, 0.38, 0.045), "PlasticWhite")                     # cover
    kit.box((-0.14, 0.03, -0.06), (0.14, 0.06, 0.03), "PlasticWhite")                        # tapered bottom
    kit.box((-0.135, 0.22, 0.043), (0.135, 0.29, 0.049), "DoorGlass")                        # smoky window band
    kit.box((-0.09, 0.08, 0.045), (0.09, 0.15, 0.06), "PlasticGrey")                         # push lever
    kit.box((-0.11, 0.025, 0.0), (0.11, 0.035, 0.034), "Rubber")                             # dispensing slot
    kit.box((-0.1, 0.0, 0.012), (0.1, 0.035, 0.016), "Paper")                                # towel tab
    kit.box((-0.01, 0.34, 0.045), (0.01, 0.356, 0.048), "Rubber")                            # key lock
    label(B, name + "Push", "PUSH", x, z, yaw, y, (0.0, 0.113, 0.062), 0.037, "SignWhite")
    return kit.build(x, z, yaw, y=y)


def xray_viewbox(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.25, lit: bool = False, films: int = 1):
    kit = B.Kit(name)
    kit.box((-0.475, 0.0, -0.05), (0.475, 0.52, 0.022), "PlasticWhite")                    # housing
    kit.box((-0.475, 0.0, 0.022), (0.475, 0.05, 0.05), "PlasticGrey")                      # switch ledge
    kit.box((0.4, 0.015, 0.05), (0.43, 0.035, 0.054), "Rubber")                            # rocker switch
    for index, px in enumerate((-0.24, 0.24)):
        kit.box((px - 0.215, 0.07, 0.022), (px + 0.215, 0.47, 0.026), "FilmLit" if lit else "PanelDead")
        for cx in (px - 0.1, px + 0.1):
            kit.box((cx - 0.02, 0.455, 0.026), (cx + 0.02, 0.49, 0.034), "Chrome")         # film clips
        if index >= films:
            continue
        kit.box((px - 0.18, 0.09, 0.026), (px + 0.18, 0.465, 0.028), "FilmDark")          # film
        bone = "PanelDead"
        if index == 0:                                                                     # hand
            kit.box((px - 0.07, 0.13, 0.0285), (px + 0.05, 0.27, 0.0305), bone)
            for finger, (fx, top) in enumerate(((-0.06, 0.39), (-0.025, 0.43), (0.01, 0.42), (0.045, 0.39))):
                kit.box((px + fx, 0.28, 0.0285), (px + fx + 0.02, top, 0.0305), bone)
            kit.box((px + 0.07, 0.2, 0.0285), (px + 0.09, 0.32, 0.0305), bone)             # thumb
        else:                                                                              # chest
            kit.box((px - 0.012, 0.11, 0.0285), (px + 0.012, 0.44, 0.0305), bone)         # spine
            for rib in range(6):
                ry = 0.4 - rib * 0.05
                width = 0.07 + rib * 0.012
                kit.box((px - 0.02 - width, ry, 0.0285), (px - 0.02, ry + 0.012, 0.0305), bone)
                kit.box((px + 0.02, ry, 0.0285), (px + 0.02 + width, ry + 0.012, 0.0305), bone)
    return kit.build(x, z, yaw, y=y)


EYE_CHART_ROWS = (("E", 0.075), ("F P", 0.048), ("T O Z", 0.036), ("L P E D", 0.027), ("P E C F D", 0.021),
                  ("E D F C Z P", 0.016))


def eye_chart(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.1):
    kit = B.Kit(name)
    kit.box((-0.16, 0.0, -0.006), (0.16, 0.62, 0.004), "Paper")                            # board
    for x0, x1, y0, y1 in ((-0.16, 0.16, 0.0, 0.008), (-0.16, 0.16, 0.612, 0.62),
                           (-0.16, -0.152, 0.0, 0.62), (0.152, 0.16, 0.0, 0.62)):
        kit.box((x0, y0, 0.004), (x1, y1, 0.006), "Rubber")                                # frame
    kit.box((-0.12, 0.085, 0.004), (0.12, 0.09, 0.006), "MedicalRed")                      # red line
    kit.box((-0.12, 0.06, 0.004), (0.12, 0.065, 0.006), "SignGreen")                       # green line
    obj = kit.build(x, z, yaw, y=y)
    row_y = 0.56
    for index, (letters, size) in enumerate(EYE_CHART_ROWS):
        label(B, f"{name}Row{index}", letters, x, z, yaw, y, (0.0, row_y, 0.006), size, res=2)
        row_y -= size * 0.8 + 0.035
    return obj


PROPS = {
    "xray_viewbox": {
        "build": xray_viewbox, "size": (0.95, 0.52, 0.104), "mount": "wall", "y": 1.25, "collide": False,
        "variants": [{}, {"lit": True, "films": 2}],
        "desc": "Double-panel X-ray film viewer with clipped films (hand, chest)",
    },
    "eye_chart": {
        "build": eye_chart, "size": (0.32, 0.62, 0.012), "mount": "wall", "y": 1.1, "collide": False,
        "variants": [{}],
        "desc": "Snellen eye chart with red and green lines",
    },
    "bed_headwall": {
        "build": bed_headwall, "size": (1.6, 0.72, 0.16), "mount": "wall", "y": 0.95, "collide": False,
        "variants": [{}, {"bed": "2", "light_on": True}],
        "desc": "Horizontal patient headwall with gas outlets, flowmeter and suction",
    },
    "wall_vitals_monitor": {
        "build": wall_vitals_monitor, "size": (0.45, 0.5, 0.45), "mount": "wall", "y": 1.5, "collide": False,
        "variants": [{}, {"on": True}],
        "desc": "Patient monitor on an articulated wall arm",
    },
    "diagnostic_set": {
        "build": diagnostic_set, "size": (0.62, 0.34, 0.14), "mount": "wall", "y": 1.2, "collide": False,
        "variants": [{}],
        "desc": "Wall diagnostic set: otoscope, ophthalmoscope, aneroid dial and cuff basket",
    },
    "sharps_container": {
        "build": sharps_container, "size": (0.28, 0.36, 0.16), "mount": "wall", "y": 1.25, "collide": False,
        "variants": [{}, {"full": True}],
        "desc": "Red sharps container in a wall bracket",
    },
    "glove_box_holder": {
        "build": glove_box_holder, "size": (0.44, 0.28, 0.12), "mount": "wall", "y": 1.2, "collide": False,
        "variants": [{}],
        "desc": "Chrome wire rack with three glove boxes (S, M, L)",
    },
    "sanitizer_dispenser": {
        "build": sanitizer_dispenser, "size": (0.12, 0.28, 0.11), "mount": "wall", "y": 1.0, "collide": False,
        "variants": [{}, {"kind": "soap"}],
        "desc": "Wall hand-sanitizer or soap dispenser with drip tray",
    },
    "paper_towel_dispenser": {
        "build": paper_towel_dispenser, "size": (0.3, 0.38, 0.12), "mount": "wall", "y": 1.15, "collide": False,
        "variants": [{}],
        "desc": "White paper-towel dispenser with push lever",
    },
}
