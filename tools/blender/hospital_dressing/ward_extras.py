"""Ward fittings for walls broken up by windows (see README.md)."""


def headwall_column(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 0.85, bed: str = "1",
                    light_on: bool = False):
    """Vertical bed-head services column for the pier beside a bed: gas outlets with an oxygen
    flowmeter and humidifier, suction regulator and canister, sockets, a reading light and the
    nurse-call pendant hanging on its cord (the cord's end is the base)."""
    kit = B.Kit(name)
    kit.box((-0.16, 0.25, -0.0875), (0.16, 1.25, -0.0225), "PlasticBeige")               # trunking
    kit.box((-0.15, 1.17, -0.0225), (0.15, 1.23, 0.0225), "PlasticWhite")                # reading light
    kit.box((-0.13, 1.175, 0.0225), (0.13, 1.215, 0.0285), "LampGlow" if light_on else "PanelDead")
    for gx, ring in ((-0.08, "OxygenGreen"), (0.0, "AirYellow"), (0.08, "PlasticWhite")):
        kit.cylinder((gx, 1.02, -0.0175), 0.028, 0.012, ring, axis="z", segments=8)       # gas outlets
        kit.cylinder((gx, 1.02, -0.0095), 0.012, 0.008, "Rubber", axis="z", segments=8)
    for sy in (0.30, 0.41):
        kit.box((-0.13, sy, -0.0225), (-0.03, sy + 0.08, -0.0125), "PlasticWhite")        # sockets
        kit.box((-0.105, sy + 0.025, -0.0125), (-0.055, sy + 0.035, -0.0095), "Rubber")
    kit.box((0.03, 0.36, -0.0225), (0.12, 0.44, -0.0095), "PlasticWhite")                # nurse-call jack
    kit.box((0.06, 0.385, -0.0095), (0.09, 0.415, -0.0035), "MedicalRed")
    # Oxygen flowmeter on the left outlet, humidifier bottle below it.
    kit.box((-0.09, 0.96, -0.0095), (-0.07, 1.0, 0.0225), "Chrome")
    kit.cylinder((-0.08, 0.89, 0.0325), 0.014, 0.13, "DoorGlass", segments=8)
    kit.cylinder((-0.08, 0.97, 0.0325), 0.018, 0.03, "OxygenGreen", segments=8)
    kit.cylinder((-0.08, 0.76, 0.0325), 0.035, 0.12, "DoorGlass", segments=8)
    kit.cylinder((-0.08, 0.83, 0.0325), 0.037, 0.02, "PlasticWhite", segments=8)
    # Suction regulator on the right outlet and its canister on a bracket.
    kit.cylinder((0.08, 0.93, 0.0125), 0.03, 0.025, "Chrome", axis="z", segments=8)
    kit.cylinder((0.08, 0.93, 0.0255), 0.024, 0.004, "PlasticWhite", axis="z", segments=8)
    kit.box((0.04, 0.57, -0.0225), (0.14, 0.59, 0.0425), "Chrome")
    kit.cylinder((0.09, 0.67, 0.0425), 0.045, 0.16, "DoorGlass", segments=8)
    kit.cylinder((0.09, 0.76, 0.0425), 0.047, 0.02, "PlasticBeige", segments=8)
    # Nurse-call pendant hanging from the jack on its cord.
    kit.box((0.072, 0.30, -0.0055), (0.078, 0.36, 0.0005), "PlasticGrey")
    kit.box((0.055, 0.0, -0.0175), (0.095, 0.30, 0.0125), "PlasticBeige")
    kit.box((0.065, 0.2, 0.0125), (0.085, 0.24, 0.0165), "MedicalRed")
    obj = kit.build(x, z, yaw, y=y)
    B.kit_text(name + "Bed", f"BED {bed}", x, z, yaw, y, (0.0, 1.1, -0.0195), size=0.035, mat="SignBlue")
    return obj


PROPS = {
    "headwall_column": {
        "build": headwall_column,
        "size": (0.32, 1.25, 0.175),
        "mount": "wall",
        "y": 0.85,
        "collide": False,
        "variants": [{}, {"bed": "3", "light_on": True}],
        "desc": "Vertical bed-head services column for a window pier beside a ward bed",
    },
}
