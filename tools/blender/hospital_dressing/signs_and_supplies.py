"""Signs, ceiling fixtures and small supplies for the hospital interior (see README.md)."""

from math import cos, radians, sin

PALETTE = {"SuppliesGreenBar": ((0.70, 0.84, 0.68), 0.0, 0.9)}   # pale bands of fanfold printout paper


def part(B, kit, x: float, z: float, yaw: float, y: float, lx: float, ly: float, lz: float,
         pitch: float = 0.0, roll: float = 0.0, turn: float = 0.0):
    """Places a second kit with its origin at the prop-local point (lx, ly, lz)."""
    px, pz = B.local_point(x, z, yaw, lx, lz)
    return kit.build(px, pz, yaw + turn, y=y + ly, pitch=pitch, roll=roll)


def flat_text(B, name: str, words: str, x: float, z: float, yaw: float, y: float, local: tuple, size: float,
              mat: str = "SignWhite", res: int = 3):
    """kit_text as one flat face: about a quarter of the extruded glyph triangles."""
    obj = B.kit_text(name, words, x, z, yaw, y, local, size=size, mat=mat)
    obj.data.extrude = 0.0
    obj.data.resolution_u = res
    return obj


def fit(words: str, width: float, big: float, small: float = 0.036) -> tuple:
    """Words and text size so the widest line spans at most `width`; wraps once rather than go below `small`."""
    def size(text: str) -> float:
        return min(big, width / (0.64 * max(len(line) for line in text.split("\n"))))
    if size(words) < small and " " in words:
        cut = min((i for i, c in enumerate(words) if c == " "), key=lambda i: abs(i - len(words) / 2.0))
        words = words[:cut] + "\n" + words[cut + 1:]
    return words, size(words)


def room_plaque(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.45, number: str = "104",
                label: str = "WARD B"):
    kit = B.Kit(name)
    kit.box((-0.13, 0.0, -0.006), (0.13, 0.18, -0.002), "SignBlue")              # backing plate
    kit.box((-0.122, 0.008, -0.002), (0.122, 0.172, 0.002), "SignBlue")          # raised face
    if label:
        kit.box((-0.1, 0.071, 0.002), (0.1, 0.075, 0.004), "SignWhite")         # divider rule
    obj = kit.build(x, z, yaw, y=y)
    words, size = fit(number, 0.2, 0.085)
    flat_text(B, name + "Number", words, x, z, yaw, y, (0.0, 0.118 if label else 0.088, 0.005), size)
    if label:
        words, size = fit(label, 0.21, 0.04, small=0.03)
        flat_text(B, name + "Label", words, x, z, yaw, y, (0.0, 0.038, 0.005), size)
    return obj


def poster(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.25, title: str = "WASH YOUR HANDS",
           lines: tuple = ("",), band: str = "SignBlue", curl: bool = False):
    kit = B.Kit(name)
    kit.box((-0.14, 0.096 if curl else 0.016, -0.003), (0.14, 0.412, -0.002), "Paper")   # sheet
    if curl:
        kit.box((-0.14, 0.016, -0.003), (0.04, 0.096, -0.002), "Paper")
        flap = B.Kit(name + "Curl").box((0.0, -0.08, 0.0), (0.1, 0.0, 0.001), "Paper")
        part(B, flap, x, z, yaw, y, 0.04, 0.096, -0.003, pitch=-14.0)            # lifted corner
    kit.box((-0.125, 0.29, -0.002), (0.125, 0.39, 0.0), band)                      # header band
    kit.box((-0.11, 0.1, -0.002), (0.11, 0.105, 0.0), band)                         # footer rule
    kit.box((-0.11, 0.072, -0.002), (-0.01, 0.077, 0.0), "PlasticGrey")
    for i, line in enumerate(lines[:3]):
        ly = 0.2 + (min(len(lines), 3) - 1 - 2 * i) * 0.0275
        if line:
            words, size = fit(line, 0.24, 0.036, small=0.0)
            flat_text(B, f"{name}Line{i}", words, x, z, yaw, y, (0.0, ly, 0.0), size, mat="Rubber")
        else:
            for j, half in enumerate((0.11, 0.1, 0.11, 0.06)):
                kit.box((-0.11, ly + 0.014 - j * 0.012, -0.002), (half, ly + 0.019 - j * 0.012, 0.0), "PlasticGrey")  # small print
    obj = kit.build(x, z, yaw, y=y)
    words, size = fit(title, 0.23, 0.05)
    flat_text(B, name + "Title", words, x, z, yaw, y, (0.0, 0.34, 0.002), size)
    for i, (cx, cy, r) in enumerate(((-0.132, 0.404, 45.0), (0.132, 0.404, -45.0), (-0.132, 0.024, -45.0), (0.132, 0.024, 45.0))):
        if not (curl and i == 3):
            tape = B.Kit(f"{name}Tape{i}").box((-0.024, -0.009, 0.0), (0.024, 0.009, 0.002), "PlasticBeige")
            part(B, tape, x, z, yaw, y, cx, cy, -0.002, roll=r)                    # masking tape
    return obj


def smoke_detector(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 2.90):
    kit = B.Kit(name)
    kit.cylinder((0.0, 0.047, 0.0), 0.065, 0.006, "PlasticWhite", segments=14)     # mounting base
    kit.cylinder((0.0, 0.033, 0.0), 0.06, 0.022, "PlasticWhite", segments=14)      # body
    kit.cylinder((0.0, 0.018, 0.0), 0.054, 0.008, "PlasticGrey", segments=12)      # vent slots
    kit.cylinder((0.0, 0.01, 0.0), 0.058, 0.008, "PlasticWhite", segments=14)      # cover
    kit.cylinder((0.0, 0.003, 0.0), 0.038, 0.006, "PlasticWhite", segments=12)     # sensor dome
    kit.cylinder((0.047, 0.005, 0.0), 0.0045, 0.004, "AlarmRed", segments=6)       # LED
    kit.box((-0.054, 0.004, -0.007), (-0.042, 0.006, 0.007), "PlasticGrey")       # test button
    return kit.build(x, z, yaw, y=y)


def sprinkler_head(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 2.88):
    kit = B.Kit(name)
    kit.cylinder((0.0, 0.067, 0.0), 0.035, 0.006, "Chrome", segments=16)           # escutcheon
    kit.cylinder((0.0, 0.058, 0.0), 0.022, 0.012, "Chrome", segments=12)           # escutcheon cup
    kit.cylinder((0.0, 0.047, 0.0), 0.01, 0.012, "Chrome", segments=8)             # threaded body
    for side in (-1.0, 1.0):
        kit.box((side * 0.013 - 0.002, 0.012, -0.003), (side * 0.013 + 0.002, 0.044, 0.003), "Chrome")  # frame arms
    kit.box((-0.015, 0.008, -0.003), (0.015, 0.013, 0.003), "Chrome")              # frame boss
    kit.cylinder((0.0, 0.026, 0.0), 0.0035, 0.026, "MedicalRed", segments=6)       # glass bulb
    kit.cylinder((0.0, 0.0055, 0.0), 0.003, 0.006, "Chrome", segments=6)           # deflector stem
    kit.cylinder((0.0, 0.0015, 0.0), 0.018, 0.003, "Chrome", segments=12)          # deflector
    return kit.build(x, z, yaw, y=y)


def ceiling_speaker(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 2.92):
    kit = B.Kit(name)
    for lo, hi in (((-0.15, -0.15), (0.15, -0.13)), ((-0.15, 0.13), (0.15, 0.15)),
                   ((-0.15, -0.13), (-0.13, 0.13)), ((0.13, -0.13), (0.15, 0.13))):
        kit.box((lo[0], 0.0, lo[1]), (hi[0], 0.03, hi[1]), "PlasticWhite")        # trim frame
    kit.box((-0.13, 0.008, -0.13), (0.13, 0.03, 0.13), "PlasticWhite")            # recessed grille plate
    for i in range(-4, 5):
        sz = i * 0.021
        half = (0.1 ** 2 - sz ** 2) ** 0.5
        kit.box((-half, 0.006, sz - 0.004), (half, 0.008, sz + 0.004), "Rubber")   # slots over the cone
    return kit.build(x, z, yaw, y=y)


def crt_terminal(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, on: bool = False):
    kit = B.Kit(name)
    kit.box((-0.12, 0.0, -0.2), (0.12, 0.025, 0.0), "PlasticBeige")                # swivel base
    kit.box((-0.08, 0.025, -0.17), (0.08, 0.05, -0.03), "PlasticBeige")
    kit.box((-0.18, 0.05, -0.05), (0.18, 0.42, 0.03), "PlasticBeige")              # front housing
    kit.box((-0.165, 0.065, -0.14), (0.165, 0.405, -0.05), "PlasticBeige")         # tapered tube housing
    kit.box((-0.14, 0.09, -0.22), (0.14, 0.37, -0.14), "PlasticBeige")
    kit.box((-0.1, 0.13, -0.29), (0.1, 0.32, -0.22), "PlasticBeige")
    kit.box((-0.18, 0.36, 0.03), (0.18, 0.42, 0.05), "PlasticBeige")               # bezel
    kit.box((-0.18, 0.05, 0.03), (0.18, 0.14, 0.05), "PlasticBeige")
    kit.box((-0.18, 0.14, 0.03), (-0.145, 0.36, 0.05), "PlasticBeige")
    kit.box((0.145, 0.14, 0.03), (0.18, 0.36, 0.05), "PlasticBeige")
    kit.box((-0.145, 0.14, 0.03), (0.145, 0.36, 0.037), "ScreenDark")             # screen
    kit.box((0.11, 0.08, 0.05), (0.14, 0.095, 0.056), "PlasticGrey")              # power switch
    kit.box((0.088, 0.084, 0.05), (0.096, 0.091, 0.053), "ScreenGreen" if on else "Rubber")  # power LED
    if on:
        for i, length in enumerate((0.2, 0.13, 0.22, 0.08, 0.17, 0.11)):
            kit.box((-0.125, 0.33 - i * 0.026, 0.037), (-0.125 + length, 0.339 - i * 0.026, 0.039), "ScreenGreen")  # text
        kit.box((-0.125, 0.174, 0.037), (-0.113, 0.186, 0.039), "ScreenGreen")    # cursor
    kit.box((-0.21, 0.0, 0.1), (0.13, 0.02, 0.27), "PlasticBeige")                 # keyboard
    kit.box((-0.21, 0.02, 0.1), (0.13, 0.03, 0.13), "PlasticBeige")
    for gx0, gx1 in ((-0.2, -0.1), (-0.09, 0.03), (0.06, 0.12)):
        kit.box((gx0, 0.03, 0.108), (gx1, 0.035, 0.124), "PlasticGrey")          # function keys
    for row in range(5):
        rz, top = 0.142 + row * 0.024, 0.032 - row * 0.002
        kit.box((-0.2, 0.02, rz), (0.05, top, rz + 0.02), "PlasticGrey")          # key rows
        kit.box((0.06, 0.02, rz), (0.12, top, rz + 0.02), "PlasticGrey")          # keypad rows
    kit.box((0.15, 0.0, 0.13), (0.205, 0.026, 0.23), "PlasticBeige")              # mouse
    for bx in (0.153, 0.179):
        kit.box((bx, 0.026, 0.132), (bx + 0.023, 0.029, 0.165), "PlasticGrey")    # mouse buttons
    kit.box((0.174, 0.0, -0.06), (0.18, 0.005, 0.13), "PlasticGrey")             # mouse cable
    kit.box((0.12, 0.0, -0.066), (0.18, 0.005, -0.06), "PlasticGrey")
    return kit.build(x, z, yaw, y=y)


def desk_phone(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    kit.box((-0.1, 0.0, -0.105), (0.12, 0.035, 0.105), "PlasticBeige")             # base
    kit.box((-0.03, 0.035, -0.105), (0.12, 0.068, -0.045), "PlasticBeige")         # raised rear housing
    kit.box((-0.1, 0.035, -0.105), (-0.03, 0.065, 0.105), "PlasticBeige")          # handset cradle
    kit.box((-0.091, 0.065, -0.1), (-0.041, 0.092, -0.05), "PlasticBeige")         # handset earpiece
    kit.box((-0.091, 0.065, 0.05), (-0.041, 0.092, 0.1), "PlasticBeige")           # handset mouthpiece
    kit.cylinder((-0.066, 0.095, 0.0), 0.016, 0.116, "PlasticBeige", axis="z", segments=8)   # handset grip
    for i in range(9):
        kit.cylinder((-0.11, 0.0075, 0.094 - i * 0.0125), 0.0075, 0.006, "PlasticBeige", axis="z", segments=5)  # coiled cord
    for i in range(4):
        kit.cylinder((-0.106, 0.022 + i * 0.012, 0.094), 0.007, 0.006, "PlasticBeige", axis="y", segments=5)
    kit.cylinder((-0.11, 0.0075, 0.04), 0.0035, 0.11, "PlasticBeige", axis="z", segments=5)
    kit.cylinder((-0.106, 0.045, 0.094), 0.0035, 0.05, "PlasticBeige", axis="y", segments=5)
    obj = kit.build(x, z, yaw, y=y)
    pad = B.Kit(name + "Keys")
    pad.box((-0.03, -0.012, -0.153), (0.117, 0.0, 0.0), "PlasticBeige")            # sloped key panel
    for r in range(4):
        for c in range(3):
            pad.box((c * 0.023, 0.0, -0.034 - r * 0.02), (c * 0.023 + 0.017, 0.006, -0.022 - r * 0.02), "PlasticGrey")  # dial keys
        if r < 3:
            pad.box((0.085, 0.0, -0.034 - r * 0.02), (0.11, 0.006, -0.022 - r * 0.02), "PlasticGrey")   # feature keys
    for c in range(6):
        pad.box((-0.022 + c * 0.023, 0.0, -0.145), (-0.007 + c * 0.023, 0.005, -0.135), "PlasticWhite")  # line buttons
    pad.box((-0.022, 0.0, -0.13), (0.11, 0.002, -0.118), "Paper")                 # line designation strip
    part(B, pad, x, z, yaw, y, 0.0, 0.035, 0.105, pitch=12.4)
    return obj


def dot_matrix_printer(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    kit.box((-0.235, 0.0, 0.08), (0.235, 0.075, 0.21), "PlasticBeige")             # front body
    kit.box((-0.235, 0.0, -0.07), (-0.2, 0.105, 0.08), "PlasticBeige")            # side housings
    kit.box((0.2, 0.0, -0.07), (0.235, 0.105, 0.08), "PlasticBeige")
    kit.box((-0.2, 0.0, -0.07), (0.2, 0.105, -0.04), "PlasticBeige")              # rear housing
    kit.box((-0.2, 0.0, -0.04), (0.2, 0.045, 0.08), "Rubber")                     # mechanism well
    kit.cylinder((0.0, 0.065, -0.015), 0.02, 0.398, "Rubber", axis="x", segments=10)   # platen
    kit.box((-0.07, 0.045, 0.01), (-0.03, 0.08, 0.05), "PlasticGrey")             # print head
    kit.box((-0.2, 0.093, -0.03), (0.2, 0.1, 0.08), "DoorGlass")                  # smoky lid
    kit.cylinder((0.245, 0.065, -0.015), 0.022, 0.02, "PlasticGrey", axis="x", segments=10)  # platen knob
    for i in range(3):
        kit.box((0.11 + i * 0.03, 0.075, 0.14), (0.132 + i * 0.03, 0.081, 0.16), "PlasticGrey")  # panel buttons
    kit.box((0.11, 0.075, 0.175), (0.19, 0.077, 0.185), "Rubber")                 # indicator strip
    for sx in (-0.19, 0.15):
        kit.box((sx, 0.105, -0.07), (sx + 0.04, 0.118, -0.045), "PlasticGrey")     # tractor covers
    kit.box((-0.19, 0.0, -0.21), (0.19, 0.055, -0.076), "Paper")                  # fanfold stack
    kit.box((-0.19, 0.055, -0.076), (0.19, 0.09, -0.073), "Paper")                # feed into the rear slot
    kit.box((-0.19, 0.09, -0.0375), (0.19, 0.17, -0.0365), "Paper")               # printout
    for band in (0.115, 0.145):
        kit.box((-0.19, band, -0.0365), (0.19, band + 0.014, -0.0345), "SuppliesGreenBar")
    obj = kit.build(x, z, yaw, y=y)
    ly, lz = 0.17, -0.037
    for i, angle in enumerate((30.0, 70.0, 115.0, 155.0)):
        sheet = B.Kit(f"{name}Sheet{i}").box((-0.19, 0.0, -0.0005), (0.19, 0.04, 0.0005), "Paper")
        part(B, sheet, x, z, yaw, y, 0.0, ly, lz, pitch=-angle)                  # printout curling over the top
        ly, lz = ly + 0.04 * cos(radians(angle)), lz - 0.04 * sin(radians(angle))
    return obj


def clipboard(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    kit.box((-0.115, 0.0, -0.165), (0.115, 0.004, 0.165), "Wood")                  # hardboard
    kit.box((-0.11, 0.004, -0.13), (0.104, 0.0055, 0.148), "Paper")                # forms
    kit.box((-0.106, 0.0055, -0.13), (0.11, 0.007, 0.152), "Paper")
    kit.box((-0.108, 0.007, -0.13), (0.106, 0.0085, 0.15), "Paper")
    kit.box((-0.09, 0.0085, -0.105), (0.03, 0.0105, -0.09), "Rubber")             # form heading
    for i in range(6):
        kit.box((-0.09, 0.0085, -0.07 + i * 0.03), (0.09 - (i % 3) * 0.03, 0.0105, -0.066 + i * 0.03), "PlasticGrey")  # form lines
    kit.box((-0.055, 0.004, -0.163), (0.055, 0.01, -0.13), "Chrome")              # clip plate
    kit.cylinder((0.0, 0.014, -0.146), 0.005, 0.1, "Chrome", axis="x", segments=8)
    kit.box((-0.05, 0.0085, -0.13), (0.05, 0.013, -0.118), "Chrome")              # clip jaw
    kit.box((-0.035, 0.016, -0.165), (0.035, 0.026, -0.152), "Chrome")            # clip lever
    return kit.build(x, z, yaw, y=y)


BINDERS = (("BookBlue", 0.055), ("BookRed", 0.045), ("Rubber", 0.065), ("BookGreen", 0.05),
           ("BookBlue", 0.06), ("PlasticGrey", 0.045), ("BookRed", 0.07), ("BookBlue", 0.05))


def binder(kit, x0: float, y0: float, w: float, h: float, mat: str) -> None:
    kit.box((x0, y0, -0.14), (x0 + w, y0 + h, 0.125), mat)                                     # binder
    kit.box((x0 + 0.008, y0 + h * 0.55, 0.125), (x0 + w - 0.008, y0 + h * 0.82, 0.127), "SignWhite")  # spine label


def binder_shelf(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.55):
    kit = B.Kit(name)
    kit.box((-0.46, 0.075, -0.15), (0.46, 0.095, 0.15), "Laminate")               # shelf board
    for i, bx in enumerate((-0.32, 0.32)):
        kit.box((bx - 0.014, 0.0, -0.15), (bx + 0.014, 0.075, -0.145), "ShelfSteel")   # bracket wall leg
        kit.box((bx - 0.004, 0.06, -0.145), (bx + 0.004, 0.075, 0.12), "ShelfSteel")   # bracket arm
        brace = B.Kit(f"{name}Brace{i}").box((-0.004, 0.0, -0.004), (0.004, 0.21, 0.004), "ShelfSteel")
        part(B, brace, x, z, yaw, y, bx, 0.008, -0.141, pitch=75.6)                     # diagonal strut
    bx = -0.445
    for i, (mat, w) in enumerate(BINDERS):
        binder(kit, bx, 0.095, w, 0.265 + (i % 3) * 0.008, mat)
        bx += w + 0.003
    kit.box((0.125, 0.095, -0.14), (0.41, 0.145, 0.125), "BookGreen")              # binder lying flat
    kit.box((0.16, 0.105, 0.125), (0.375, 0.135, 0.127), "SignWhite")
    obj = kit.build(x, z, yaw, y=y)
    lean = B.Kit(name + "Leaning")
    binder(lean, 0.0, 0.0, 0.05, 0.28, "BookRed")
    part(B, lean, x, z, yaw, y, bx - 0.003 + 0.273 * 0.1763, 0.095, 0.0, roll=10.0)   # binder leaning on the row
    return obj


def supply_bin_row(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12, stocked: bool = True):
    kit = B.Kit(name)
    for i, mat in enumerate(("CartBlue", "CartRed", "SafetyYellow", "CartBlue")):
        cx = -0.3825 + i * 0.255
        kit.box((cx - 0.1175, 0.0, -0.2), (cx + 0.1175, 0.008, 0.19), mat)               # floor
        kit.box((cx - 0.1175, 0.008, -0.2), (cx + 0.1175, 0.18, -0.194), mat)            # back wall
        kit.box((cx - 0.1175, 0.008, 0.184), (cx + 0.1175, 0.1, 0.19), mat)             # front lip
        for sx in (cx - 0.1175, cx + 0.1115):
            kit.box((sx, 0.008, -0.194), (sx + 0.006, 0.18, -0.06), mat)                 # rear side walls
            kit.box((sx, 0.008, -0.06), (sx + 0.006, 0.13, 0.184), mat)                  # scoop side walls
        kit.box((cx - 0.06, 0.035, 0.19), (cx + 0.06, 0.075, 0.192), "Paper")             # label slip
        if stocked and i % 2 == 0:
            kit.box((cx - 0.085, 0.008, -0.192), (cx + 0.085, 0.15, -0.176), "Paper")           # gauze packs on end
            for j in range(4):
                kit.box((cx - 0.095 + (j % 2) * 0.02, 0.008 + j * 0.018, -0.17 + j * 0.03),
                        (cx + 0.07 + (j % 2) * 0.02, 0.026 + j * 0.018, -0.03 + j * 0.03), "Paper")   # gauze packs
        elif stocked:
            for j, (rx, ry, rz) in enumerate(((-0.047, 0.048, 0.08), (0.047, 0.048, 0.07), (0.0, 0.048, -0.05))):
                kit.cylinder((cx + rx, ry, rz), 0.04, 0.088, "Linen", axis="x", segments=6)       # bandage rolls
    return kit.build(x, z, yaw, y=y)


def glove_box_stack(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    obj = None
    for i, (mat, dx, turn, size) in enumerate((("GlovePurple", -0.018, 2.0, "L"), ("GloveBlue", 0.016, -2.5, "M"),
                                               ("GloveBlue", -0.004, 1.0, "M"))):
        kit = B.Kit(name if i == 0 else f"{name}Box{i}")
        kit.box((-0.12, 0.0, -0.062), (0.12, 0.064, 0.062), mat)                        # dispenser box
        kit.box((-0.112, 0.01, 0.062), (-0.03, 0.054, 0.064), "SignWhite")             # size panel
        if i == 2:
            kit.box((-0.045, 0.064, -0.02), (0.045, 0.066, 0.02), "Rubber")             # torn-open slot
            for ex in (-0.045, 0.045):
                kit.cylinder((ex, 0.065, 0.0), 0.02, 0.002, "Rubber", segments=8)
        made = part(B, kit, x, z, yaw, y, dx, i * 0.0645, 0.0, turn=turn)
        obj = obj or made
        px, pz = B.local_point(x, z, yaw, dx, 0.0)
        flat_text(B, f"{name}Size{i}", size, px, pz, yaw + turn, y + i * 0.0645, (-0.071, 0.032, 0.066), 0.05, mat=mat)
    glove = B.Kit(name + "Glove")
    glove.box((-0.024, 0.0, -0.01), (0.024, 0.024, 0.01), "GloveBlue")              # crumpled palm
    for gx, length in ((-0.017, 0.022), (-0.005, 0.034), (0.008, 0.029), (0.019, 0.016)):
        glove.cylinder((gx, 0.024 + length / 2.0, 0.0), 0.0055, length, "GloveBlue", segments=6)   # fingers
    glove.cylinder((-0.032, 0.012, 0.002), 0.006, 0.02, "GloveBlue", axis="x", segments=6)       # thumb
    part(B, glove, x, z, yaw, y, -0.004, 0.193, 0.0, pitch=-12.0, roll=24.0)
    return obj


def fluid_cartons(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    kit.box((-0.3, 0.0, -0.19), (-0.015, 0.3, 0.19), "Cardboard")                   # sealed carton
    kit.box((-0.165, 0.3, -0.19), (-0.15, 0.302, 0.19), "PlasticBeige")             # packing tape
    kit.box((-0.165, 0.24, 0.19), (-0.15, 0.3, 0.192), "PlasticBeige")
    kit.box((-0.3, 0.03, 0.19), (-0.015, 0.05, 0.192), "SignBlue")                  # printed stripe
    kit.box((-0.005, 0.0, -0.19), (0.28, 0.008, 0.19), "Cardboard")                 # open carton
    kit.box((-0.005, 0.008, -0.19), (0.003, 0.3, 0.19), "Cardboard")
    kit.box((0.272, 0.008, -0.19), (0.28, 0.3, 0.19), "Cardboard")
    kit.box((0.003, 0.008, -0.19), (0.272, 0.3, -0.182), "Cardboard")
    kit.box((0.003, 0.008, 0.182), (0.272, 0.3, 0.19), "Cardboard")
    kit.box((0.003, 0.008, -0.182), (0.272, 0.22, 0.182), "PlasticWhite")           # lower layers of bags
    for bx in (0.072, 0.203):
        kit.box((bx - 0.05, 0.22, -0.15), (bx + 0.05, 0.255, 0.15), "PlasticWhite")   # saline bag
        for ex in (-0.05, 0.05):
            kit.cylinder((bx + ex, 0.2375, 0.0), 0.0175, 0.296, "PlasticWhite", axis="z", segments=6)  # soft edges
        for px in (-0.015, 0.015):
            kit.cylinder((bx + px, 0.2375, 0.165), 0.006, 0.03, "PlasticWhite", axis="z", segments=6)  # ports
    kit.box((-0.1475, 0.3, -0.19), (-0.005, 0.304, 0.19), "Cardboard")             # flap folded onto the sealed carton
    obj = kit.build(x, z, yaw, y=y)
    side = B.Kit(name + "FlapSide").box((0.0, -0.1425, -0.19), (0.006, 0.0, 0.19), "Cardboard")
    part(B, side, x, z, yaw, y, 0.28, 0.3, 0.0, roll=10.0)                          # flaps hanging open
    front = B.Kit(name + "FlapFront").box((-0.005, -0.13, 0.0), (0.28, 0.0, 0.006), "Cardboard")
    front.box((0.03, -0.06, 0.006), (0.25, -0.045, 0.008), "SignBlue")
    part(B, front, x, z, yaw, y, 0.0, 0.3, 0.19, pitch=-10.0)
    words, size = fit("0.9% SODIUM CHLORIDE", 0.25, 0.045)
    flat_text(B, name + "Print", words, x, z, yaw, y, (-0.1575, 0.17, 0.193), size, mat="SignBlue", res=2)
    return obj


def scrubs_stack(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    for i, (jx, jz) in enumerate(((0.004, -0.004), (-0.003, 0.003), (0.005, 0.0), (-0.002, 0.004))):
        y0, y1 = i * 0.033, i * 0.034
        kit.box((-0.195 + jx, y0, -0.165 + jz), (-0.015 + jx, y0 + 0.033, 0.15 + jz), "ScrubTeal")      # folded scrubs
        kit.cylinder((-0.105 + jx, y0 + 0.0165, 0.15 + jz), 0.0165, 0.176, "ScrubTeal", axis="x", segments=6)
        kit.box((0.015 - jz, y1, -0.16 + jx), (0.195 - jz, y1 + 0.034, 0.145 + jx), "Linen")              # folded towels
        kit.cylinder((0.105 - jz, y1 + 0.017, 0.145 + jx), 0.017, 0.176, "Linen", axis="x", segments=6)
        kit.cylinder((0.06 - jz, y1 + 0.017, 0.145 + jx), 0.019, 0.012, "SignBlue", axis="x", segments=6)  # woven stripe
    return kit.build(x, z, yaw, y=y)


def ring_instrument(B, name: str, jaw: float, width: float):
    kit = B.Kit(name)
    for sx in (-0.012, 0.012):
        kit.cylinder((sx, 0.0015, -0.062), 0.011, 0.003, "Chrome", segments=8)        # finger rings
        kit.cylinder((sx, 0.004, -0.062), 0.0065, 0.002, "ScrubTeal", segments=8)
        kit.box((sx * 0.4 - 0.002, 0.0, -0.052), (sx * 0.4 + 0.002, 0.003, -0.004), "Chrome")  # shanks
    kit.box((-0.005, 0.0, -0.006), (0.005, 0.004, 0.006), "Chrome")                   # box lock
    kit.box((-width / 2.0, 0.0, 0.006), (width / 2.0, 0.003, 0.006 + jaw), "Chrome")   # jaws
    return kit


def instrument_tray(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.12):
    kit = B.Kit(name)
    kit.box((-0.23, 0.0, -0.15), (0.23, 0.003, 0.15), "Chrome")                    # stainless tray
    kit.box((-0.23, 0.003, -0.15), (0.23, 0.02, -0.145), "Chrome")
    kit.box((-0.23, 0.003, 0.145), (0.23, 0.02, 0.15), "Chrome")
    kit.box((-0.23, 0.003, -0.145), (-0.225, 0.02, 0.145), "Chrome")
    kit.box((0.225, 0.003, -0.145), (0.23, 0.02, 0.145), "Chrome")
    kit.box((-0.222, 0.003, -0.142), (0.222, 0.008, 0.142), "ScrubTeal")           # folded towel
    for kx, kz, r in ((-0.125, -0.07, 0.048), (-0.125, 0.07, 0.048), (-0.14, 0.0, 0.05)):
        kit.cylinder((kx, 0.026, kz), r, 0.036, "Chrome", segments=10)              # kidney dish
        kit.cylinder((kx, 0.0455, kz), r - 0.008, 0.003, "ShelfSteel", segments=10)
    obj = kit.build(x, z, yaw, y=y)
    part(B, ring_instrument(B, name + "Forceps", 0.075, 0.005), x, z, yaw, y, 0.05, 0.008, -0.03, turn=10.0)
    part(B, ring_instrument(B, name + "Scissors", 0.06, 0.009), x, z, yaw, y, 0.16, 0.008, -0.04, turn=-6.0)
    for i, (gx, gz, turn) in enumerate(((-0.02, 0.07, 8.0), (-0.01, 0.06, -14.0))):
        gauze = B.Kit(f"{name}Gauze{i}").box((-0.05, 0.0, -0.05), (0.05, 0.004, 0.05), "Linen")
        part(B, gauze, x, z, yaw, y, gx, 0.008 + i * 0.004, gz, turn=turn)         # gauze squares
    return obj


PROPS = {
    "room_plaque": {
        "build": room_plaque, "size": (0.26, 0.18, 0.012), "mount": "wall", "y": 1.45, "collide": False,
        "variants": [{}, {"number": "112", "label": "X-RAY"}, {"number": "130", "label": ""}],
        "desc": "Blue room ID plaque beside a door: room number over a name line",
    },
    "poster": {
        "build": poster, "size": (0.30, 0.42, 0.006), "mount": "wall", "y": 1.25, "collide": False,
        "variants": [{}, {"title": "VISITING HOURS", "lines": ("2 PM - 8 PM",), "band": "SignGreen"},
                     {"title": "NO SMOKING", "lines": ("OXYGEN", "IN USE"), "band": "MedicalRed", "curl": True}],
        "desc": "Notice taped to the wall: coloured header band, heading and short lines",
    },
    "smoke_detector": {
        "build": smoke_detector, "size": (0.13, 0.05, 0.13), "mount": "ceiling", "collide": False,
        "variants": [{}], "desc": "Round white ceiling smoke detector with a red LED",
    },
    "sprinkler_head": {
        "build": sprinkler_head, "size": (0.07, 0.07, 0.07), "mount": "ceiling", "collide": False,
        "variants": [{}], "desc": "Pendant fire sprinkler with chrome escutcheon and red glass bulb",
    },
    "ceiling_speaker": {
        "build": ceiling_speaker, "size": (0.30, 0.03, 0.30), "mount": "ceiling", "collide": False,
        "variants": [{}], "desc": "Square white paging-speaker grille with slots",
    },
    "crt_terminal": {
        "build": crt_terminal, "size": (0.42, 0.42, 0.58), "mount": "surface", "collide": True,
        "variants": [{}, {"on": True}], "desc": "Beige early-90s CRT terminal with keyboard and mouse",
    },
    "desk_phone": {
        "build": desk_phone, "size": (0.24, 0.12, 0.22), "mount": "surface", "collide": False,
        "variants": [{}], "desc": "Beige multi-line desk phone with handset and coiled cord",
    },
    "dot_matrix_printer": {
        "build": dot_matrix_printer, "size": (0.50, 0.22, 0.42), "mount": "surface", "collide": True,
        "variants": [{}], "desc": "Dot-matrix printer with tractor-feed paper and a curling printout",
    },
    "clipboard": {
        "build": clipboard, "size": (0.24, 0.03, 0.33), "mount": "surface", "collide": False,
        "variants": [{}], "desc": "Brown clipboard with a metal clip and forms, lying flat",
    },
    "binder_shelf": {
        "build": binder_shelf, "size": (0.92, 0.36, 0.30), "mount": "wall", "y": 1.55, "collide": True,
        "variants": [{}], "desc": "Wall shelf on steel brackets with a row of patient binders",
    },
    "supply_bin_row": {
        "build": supply_bin_row, "size": (1.00, 0.18, 0.40), "mount": "surface", "collide": False,
        "variants": [{}, {"stocked": False}], "desc": "Four louvered stacking bins with gauze and bandage rolls",
    },
    "glove_box_stack": {
        "build": glove_box_stack, "size": (0.30, 0.25, 0.14), "mount": "surface", "collide": False,
        "variants": [{}], "desc": "Stack of three glove boxes, the top one open with a glove poking out",
    },
    "fluid_cartons": {
        "build": fluid_cartons, "size": (0.60, 0.32, 0.40), "mount": "surface", "collide": True,
        "variants": [{}], "desc": "Two cartons of IV saline, one open with bags showing",
    },
    "scrubs_stack": {
        "build": scrubs_stack, "size": (0.40, 0.14, 0.35), "mount": "surface", "collide": False,
        "variants": [{}], "desc": "Neat stacks of folded teal scrubs and white towels",
    },
    "instrument_tray": {
        "build": instrument_tray, "size": (0.46, 0.06, 0.30), "mount": "surface", "collide": False,
        "variants": [{}], "desc": "Stainless instrument tray with forceps, scissors, gauze and a kidney dish",
    },
}
