"""What furnishes the alt route's hospital: equipment in every room by its kind, and the things Godot spawns
(hiding spots, bottles, documents). Plain Python, read by tools/blender/build_alt_hospital.py.

Each placement is a dict:
  prop: a key from tools/blender/hospital_dressing (built with that module's builder);
  kit:  one of build_hospital_interior.py's furniture functions (gurney, shelter_cot, office_desk, ...);
with name, level, x, z (building-local, as in plan.py), yaw (Godot convention: +90 turns the front, local +Z,
toward +x), and optionally y (height above the level's floor), opts (keyword arguments) and tilt ([pitch, roll]
in degrees: knocked over). Others:
  text:    painted or sprayed words on a wall (words, size, mat);
  sign:    a blue plate of lines of text, on a wall or hanging (double-sided) from the ceiling;
  papers:  sheets of paper scattered round a point;
  fixture: a light fitting where Godot puts a light: a lit ceiling panel, or a red emergency lamp;
  bodybag: a body bag on a gurney.
Decals (blood, stains) are markers Godot projects: kind, level, position, facing (floor or a wall's normal),
size and yaw.
"""

import math

import plan

WALL_GAP = 0.1    # pieces stand this far off a wall face


class Room:
    def __init__(self, r: dict) -> None:
        self.__dict__.update(r)
        self.front = self.z1 > plan.CORRIDOR[1]          # in the front band (corridor at its z0 side)
        self.end = abs(self.x0) > 13.0 or abs(self.x1) > 13.0
        # Faces of the walls round it (partitions are 0.15 thick; the exterior faces are exact).
        self.fx0 = self.x0 + (0.0 if self.x0 <= plan.IX0 + 1e-6 else plan.PT / 2)
        self.fx1 = self.x1 - (0.0 if self.x1 >= plan.IX1 - 1e-6 else plan.PT / 2)
        self.fz0 = self.z0 + (0.0 if self.z0 <= plan.IZ0 + 1e-6 else plan.PT / 2)
        self.fz1 = self.z1 - (0.0 if self.z1 >= plan.IZ1 - 1e-6 else plan.PT / 2)
        # The wall it opens from (the corridor's, or for an end room the one onto the middle bay) and the
        # wall opposite it, with the direction into the room from the outside wall.
        if self.end:
            self.outer_z = self.fz1 if self.front else self.fz0
        else:
            self.outer_z = self.fz1 if self.front else self.fz0
        self.corr_z = self.fz0 if self.front else self.fz1
        self.inward = -1.0 if self.front else 1.0
        # Yaw for a piece against the outside wall facing into the room, and one facing the outside wall.
        self.yaw_in = 180.0 if self.front else 0.0
        self.yaw_out = 0.0 if self.front else 180.0
        self.cx = (self.x0 + self.x1) / 2.0
        self.cz = (self.z0 + self.z1) / 2.0
        self.width = self.fx1 - self.fx0
        self.depth = self.fz1 - self.fz0
        self.door_xs = [d for d in self.doors if not isinstance(d, tuple)]
        self.side_doors = [d for d in self.doors if isinstance(d, tuple)]

    def at_outer(self, depth: float) -> float:
        """z of a point `depth` in from the outside wall."""
        return self.outer_z + self.inward * depth

    def at_corridor(self, depth: float) -> float:
        return self.corr_z - self.inward * depth

    def clear_of_doors(self, x: float, z: float, half_w: float, half_d: float) -> bool:
        """Whether a footprint keeps 1.4 m in front of every doorway clear."""
        for dx in self.door_xs:
            zone = (dx - 1.1, dx + 1.1, *sorted((self.corr_z, self.at_corridor(1.5))))
            if _overlap((x - half_w, x + half_w, z - half_d, z + half_d), zone):
                return False
        for axis, center, at in self.side_doors:
            inside = 1.0 if abs(at - self.fx0) < abs(at - self.fx1) else -1.0
            face = self.fx0 if inside > 0 else self.fx1
            zone = (*sorted((face, face + inside * 1.5)), center - 1.0, center + 1.0)
            if _overlap((x - half_w, x + half_w, z - half_d, z + half_d), zone):
                return False
        return True


def _overlap(a: tuple, b: tuple) -> bool:
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]


class Dresser:
    def __init__(self) -> None:
        self.placements: list = []
        self.hiding: list = []
        self.bottles: list = []
        self.documents: dict = {}
        self.decals: list = []
        self.count = 0

    def _name(self, room: Room, label: str) -> str:
        self.count += 1
        safe = "".join(ch for ch in room.name.title() if ch.isalnum())
        return f"L{room.level}_{safe}_{label}{self.count}"

    def prop(self, room: Room, key: str, x: float, z: float, yaw: float, y=None, **opts) -> None:
        self.placements.append(dict(prop=key, name=self._name(room, key.title().replace("_", "")), level=room.level,
                                    x=round(x, 3), z=round(z, 3), yaw=yaw, y=y, opts=opts))

    def kit(self, room: Room, fn: str, x: float, z: float, yaw: float, tilt=None, **opts) -> None:
        self.placements.append(dict(kit=fn, name=self._name(room, fn.title().replace("_", "")), level=room.level,
                                    x=round(x, 3), z=round(z, 3), yaw=yaw, opts=opts, tilt=tilt))

    # ---- placements that are not furniture -----------------------------------------------------------
    def text(self, level: int, words: str, x: float, y: float, z: float, yaw: float, size: float = 0.18,
             mat: str = "SprayPaint") -> None:
        self.count += 1
        self.placements.append(dict(text=words, name=f"L{level}_Words{self.count}", level=level, x=x, y=y, z=z,
                                    yaw=yaw, size=size, mat=mat))

    def sign(self, level: int, lines: list, x: float, y: float, z: float, yaw: float, width: float,
             hanging: bool = False, back: list = None) -> None:
        self.count += 1
        self.placements.append(dict(sign=lines, back=back, name=f"L{level}_Sign{self.count}", level=level, x=x, y=y,
                                    z=z, yaw=yaw, width=width, hanging=hanging))

    def papers(self, level: int, x: float, z: float, radius: float, count: int = 14) -> None:
        self.count += 1
        self.placements.append(dict(papers=count, name=f"L{level}_Papers{self.count}", level=level, x=x, z=z,
                                    radius=radius, seed=self.count))

    def fixture(self, level: int, kind: str, x: float, z: float) -> None:
        self.count += 1
        self.placements.append(dict(fixture=kind, name=f"L{level}_Fixture{self.count}", level=level, x=x, z=z))

    def bodybag(self, level: int, x: float, z: float, yaw: float) -> None:
        self.count += 1
        self.placements.append(dict(bodybag=True, name=f"L{level}_BodyBag{self.count}", level=level, x=x, z=z, yaw=yaw))

    def decal(self, level: int, kind: str, x: float, y: float, z: float, size: tuple, yaw: float = 0.0,
              facing=None) -> None:
        """A decal: on the floor (facing None) or on a wall (facing is the wall's outward normal [x, z])."""
        self.decals.append(dict(kind=kind, level=level, position=[round(x, 3), round(plan.floor_y(level) + y, 3), round(z, 3)],
                                facing="floor" if facing is None else [facing[0], 0.0, facing[1]],
                                size=[size[0], size[1]], yaw=yaw))

    def trail(self, level: int, points: list, width: float = 0.5) -> None:
        """A smear of blood dragged along a path of floor points."""
        import math as _m
        for (x0, z0), (x1, z1) in zip(points, points[1:]):
            length = _m.hypot(x1 - x0, z1 - z0)
            yaw = _m.degrees(_m.atan2(x1 - x0, z1 - z0))
            self.decal(level, "blood_smear", (x0 + x1) / 2.0, 0.0, (z0 + z1) / 2.0, (width, length), yaw)

    def hide(self, room: Room, kind: str, x: float, z: float, yaw: float) -> None:
        self.hiding.append(dict(name=self._name(room, kind.title()), kind=kind, level=room.level,
                                position=[round(x, 3), plan.floor_y(room.level), round(z, 3)], yaw=yaw))

    def bottle(self, room: Room, x: float, z: float, height: float) -> None:
        self.bottles.append(dict(name=self._name(room, "Bottle"), level=room.level,
                                 position=[round(x, 3), round(plan.floor_y(room.level) + height, 3), round(z, 3)]))

    def document(self, room: Room, key: str, x: float, z: float, height: float) -> None:
        self.documents[key] = [round(x, 3), round(plan.floor_y(room.level) + height, 3), round(z, 3)]

    # ---- shared dressing for every room -------------------------------------------------------------
    def basics(self, room: Room) -> None:
        # A plaque beside the first door, on the corridor side, and the ceiling's light fittings.
        if room.door_xs and not room.end:
            dx = room.door_xs[0]
            px = dx + 1.25 if dx + 1.25 < room.x1 - 0.3 else dx - 1.25
            plaque_z = plan.CORRIDOR[1] - plan.PT / 2 if room.front else plan.CORRIDOR[0] + plan.PT / 2
            yaw = 0.0 if room.front else 180.0
            self.prop(room, "room_plaque", px, plaque_z + (-0.006 if room.front else 0.006), yaw + 180.0,
                      number=f"{plan.LEVEL_NAMES[room.level]}{abs(int(room.cx)):02d}", label=room.name.upper()[:18])
        columns = 2 if room.width > 5.0 else 1
        rows = 2 if room.depth > 5.0 else 1
        for i in range(columns):
            for j in range(rows):
                x = room.fx0 + room.width * (i + 0.5) / columns
                z = room.fz0 + room.depth * (j + 0.5) / rows
                self.kit(room, "ceiling_panel", x, z, 90.0 if room.width > room.depth else 0.0, lit=False)
        self.prop(room, "smoke_detector", room.cx + 0.4, room.cz + 0.3, 0.0)

    # ---- room kinds ------------------------------------------------------------------------------------
    def ward(self, room: Room, beds_hide: int = 1) -> None:
        """Four beds, two against each side wall, heads to the wall, curtains between them."""
        spots = []
        for side, face, yaw in ((0, room.fx0, 90.0), (1, room.fx1, -90.0)):
            for k, depth in enumerate((1.75, 4.15)):
                z = room.at_outer(depth)
                x = face + (1.0 if side == 0 else -1.0) * (WALL_GAP + 1.075)
                spots.append((x, z, yaw, side, k))
        for index, (x, z, yaw, side, k) in enumerate(spots):
            if not room.clear_of_doors(x, z, 1.1, 0.55):
                continue
            if index < beds_hide:
                # A ward bed you can hide under: its length along its local x, head (headboard) at +x, you
                # come out at its local +z.
                hide_yaw = 0.0 if side == 1 else 180.0
                if not room.front:
                    hide_yaw = 180.0 - hide_yaw
                self.hide(room, "bed", x, z, hide_yaw)
                continue
            self.prop(room, "hospital_bed", x, z, yaw, head_angle=20.0 + 15.0 * ((index * 7) % 3), stripped=index % 3 == 2)
            ox = x + (0.75 if side == 0 else -0.75)
            self.prop(room, "overbed_table", ox, z + room.inward * 0.9, yaw)
            self.prop(room, "bed_headwall", face + (0.08 if side == 0 else -0.08), z, yaw, bed=str(index + 1))
        # Curtain tracks between the bed spaces, pulled half across.
        for side, face in ((0, room.fx0), (1, room.fx1)):
            x = face + (1.0 if side == 0 else -1.0) * 1.3
            self.kit(room, "privacy_curtain", x, room.at_outer(2.95), 90.0, length=2.4, drawn=0.55)
        self.prop(room, "visitor_chair", room.cx, room.at_outer(0.6), room.yaw_in)
        self.prop(room, "wall_clock", room.cx, room.outer_z + room.inward * 0.03, room.yaw_in)
        self.prop(room, "sanitizer_dispenser", (room.door_xs[0] + 1.1) if room.door_xs else room.cx,
                  room.corr_z - room.inward * 0.06, room.yaw_out)
        self.bottle(room, room.cx + 0.2, room.at_outer(0.6), 0.47)

    def lobby(self, room: Room) -> None:
        # The counter faces the entrance (its visitor side, local +Z, toward the doors).
        self.kit(room, "reception_counter", 2.6, -4.9, 0.0, length=3.6)
        self.document(room, "register", 2.3, -4.5, 1.12)
        self.prop(room, "crt_terminal", 3.4, -5.25, 180.0, y=0.76)
        self.prop(room, "desk_phone", 1.6, -5.2, 180.0, y=0.76)
        for k, x in enumerate((-4.6, -2.3)):
            self.kit(room, "waiting_chairs", x, -2.2, 180.0, seats=4)
            self.kit(room, "waiting_chairs", x, -3.6, 0.0, seats=4)
        self.kit(room, "vending_machine", -6.2, -5.6, 90.0, lit=True)
        self.kit(room, "wheelchair", 5.6, -1.4, 160.0)
        self.kit(room, "notice_board", -6.725, -1.2, 90.0)
        self.prop(room, "wall_clock", 2.6, -0.3 - 0.03, 180.0)
        self.bottle(room, 3.9, -4.5, 1.12)

    def shelter(self, room: Room) -> None:
        for k, x in enumerate((7.9, 9.5, 11.1, 12.7)):
            self.kit(room, "shelter_cot", x, -1.4, 90.0, made=k % 2 == 0)
        for k, x in enumerate((7.9, 11.1)):
            self.kit(room, "shelter_cot", x, -4.0, 90.0, made=True)
        self.kit(room, "iv_stand", 12.9, -4.6, 0.0)
        self.hide(room, "bed", 12.3, -5.9, 180.0)
        self.bottle(room, 9.5, -4.0, 0.47)

    def er(self, room: Room) -> None:
        for k, x in enumerate((-12.4, -10.2, -8.0)):
            self.kit(room, "gurney", x, -2.0, 90.0)
            self.kit(room, "privacy_curtain", x + 1.1, -2.2, 90.0, length=3.0, drawn=0.6 if k != 1 else 0.25)
            self.prop(room, "mobile_vitals", x - 0.6, -0.8, 180.0, on=k == 1)
        self.prop(room, "crash_cart", -12.9, -5.2, 90.0, drawers_open=(1,))
        self.prop(room, "infusion_pump_pole", -9.0, -3.6, 0.0, bags=2)
        self.prop(room, "waste_bin", -7.4, -1.0, 180.0, kind="biohazard")
        self.bottle(room, -12.9, -5.2, 1.0)

    def radiology(self, room: Room) -> None:
        self.prop(room, "exam_table", room.cx, room.at_outer(2.6), 90.0)
        self.prop(room, "xray_viewbox", room.cx, room.outer_z + room.inward * 0.052, room.yaw_in, lit=False, films=2)
        self.prop(room, "wheeled_stool", room.cx + 1.4, room.at_outer(2.0), 0.0)
        self.prop(room, "mobile_vitals", room.fx0 + 0.5, room.at_outer(1.2), 90.0)
        self.kit(room, "shelving_unit", room.fx1 - 0.3, room.at_outer(2.5), -90.0, width=1.2)

    def pharmacy(self, room: Room) -> None:
        for k, z in enumerate((room.at_outer(1.0), room.at_outer(2.5), room.at_outer(4.0))):
            self.kit(room, "shelving_unit", room.fx0 + 0.3, z, 90.0, width=1.2)
        self.prop(room, "med_dispensing_cabinet", room.fx1 - 0.4, room.at_outer(1.2), -90.0, forced=True)
        self.prop(room, "fluid_cartons", room.fx1 - 0.6, room.at_outer(3.2), -90.0, y=0.0)
        self.bottle(room, room.fx0 + 0.3, room.at_outer(2.5), 0.98)

    def staff(self, room: Room) -> None:
        for k in range(3):
            self.hide(room, "locker", room.fx0 + 0.36, room.at_outer(1.2 + k * 0.7), 90.0)
        self.kit(room, "office_desk", room.fx1 - 0.5, room.at_outer(2.0), -90.0, width=1.4, depth=0.8)
        self.prop(room, "visitor_chair", room.fx1 - 1.3, room.at_outer(2.0), 90.0, color="VinylMauve")
        self.prop(room, "wall_clock", room.cx, room.outer_z + room.inward * 0.03, room.yaw_in)
        self.bottle(room, room.fx1 - 0.5, room.at_outer(2.3), 0.76)

    def records(self, room: Room) -> None:
        for k in range(4):
            self.kit(room, "filing_cabinet", room.fx0 + 0.6 + k * 0.5, room.outer_z + room.inward * 0.35, room.yaw_in,
                     open_drawer=2 if k == 1 else -1)
        self.kit(room, "office_desk", room.cx + 1.2, room.at_outer(2.6), room.yaw_out, width=1.6, depth=0.8)
        self.prop(room, "crt_terminal", room.cx + 1.5, room.at_outer(2.6), room.yaw_out, y=0.76)
        self.kit(room, "shelving_unit", room.fx1 - 0.3, room.at_outer(4.6), -90.0, width=1.4)
        if room.level == 0:
            self.document(room, "evacuation", room.cx + 0.8, room.at_outer(2.6), 0.765)
        self.bottle(room, room.cx + 0.4, room.at_outer(2.6), 0.76)

    def storage(self, room: Room) -> None:
        for k in range(3):
            self.kit(room, "shelving_unit", room.fx0 + 0.3, room.at_outer(1.0 + k * 1.5), 90.0, width=1.2)
        self.hide(room, "closet", room.fx1 - 0.4, room.at_outer(1.4), -90.0)
        self.prop(room, "o2_cylinder_rack", room.cx, room.outer_z + room.inward * 0.2, room.yaw_in)
        self.bottle(room, room.fx0 + 0.3, room.at_outer(2.5), 0.55)
        if room.level == 0:
            # The stores log, on the middle unit's fourth shelf (its top is 1.44 m up).
            self.document(room, "supply", room.fx0 + 0.3, room.at_outer(2.5), 1.445)

    def linen(self, room: Room) -> None:
        self.prop(room, "linen_cart", room.cx, room.at_outer(1.0), room.yaw_in)
        self.hide(room, "closet", room.fx1 - 0.4, room.at_outer(3.2), -90.0)
        self.kit(room, "shelving_unit", room.fx0 + 0.3, room.at_outer(1.5), 90.0, width=1.4)
        self.prop(room, "soiled_linen_hamper", room.fx0 + 0.6, room.at_outer(3.6), 90.0)

    def plant(self, room: Room) -> None:
        self.prop(room, "o2_cylinder_rack", room.cx, room.outer_z + room.inward * 0.2, room.yaw_in)
        self.kit(room, "shelving_unit", room.fx1 - 0.3, room.at_outer(2.0), -90.0, width=1.2)

    def security(self, room: Room) -> None:
        self.kit(room, "office_desk", room.cx, room.at_outer(1.2), room.yaw_out, width=2.0, depth=0.8)
        for k, dx in enumerate((-0.6, 0.4)):
            self.prop(room, "crt_terminal", room.cx + dx, room.at_outer(1.2), room.yaw_out, y=0.76, on=k == 0)
        self.hide(room, "locker", room.fx1 - 0.36, room.at_outer(3.6), -90.0)
        self.hide(room, "locker", room.fx1 - 0.36, room.at_outer(4.3), -90.0)

    def ambulance(self, room: Room) -> None:
        self.kit(room, "gurney", room.cx, room.at_outer(1.6), 0.0)
        self.kit(room, "wheelchair", room.fx0 + 0.6, room.at_outer(3.5), 60.0)
        self.prop(room, "o2_cylinder_cart", room.fx0 + 0.4, room.at_outer(0.6), 90.0)

    def children(self, room: Room) -> None:
        self.ward(room, beds_hide=1)
        self.prop(room, "poster", room.cx - 1.0, room.outer_z + room.inward * 0.003, room.yaw_in, y=1.3,
                  title="DRAW YOUR FAMILY", lines=("", ""), band="SignGreen")

    def nurse(self, room: Room) -> None:
        passes = [d for d in room.doors if isinstance(d, tuple) and d[0] == "pass"]
        px = passes[0][1] if passes else room.cx
        # Its visitor side faces the corridor, through the opening.
        self.kit(room, "reception_counter", px, room.at_corridor(0.55), room.yaw_in, length=2.0, depth=0.7)
        self.prop(room, "med_cart", room.fx0 + 0.6, room.at_outer(1.0), 90.0, locked=False)
        self.prop(room, "chart_rack", room.fx1 - 0.5, room.at_outer(1.0), -90.0)
        self.prop(room, "crt_terminal", px + 0.5, room.at_corridor(0.75), room.yaw_out, y=0.76, on=True)
        self.prop(room, "desk_phone", px - 0.5, room.at_corridor(0.75), room.yaw_out, y=0.76)
        self.prop(room, "wheeled_stool", px, room.at_corridor(1.5), 0.0)
        self.bottle(room, px, room.at_corridor(0.55) - room.inward * 0.37, 1.12)

    def void(self, room: Room) -> None:
        for x in (-4.0, 0.0, 4.0):
            self.kit(room, "ceiling_panel", x, -3.8, 90.0, lit=x == 0.0)

    def dayroom(self, room: Room) -> None:
        for k in range(3):
            self.prop(room, "visitor_chair", room.fx0 + 0.7 + k * 1.1, room.at_outer(1.0), room.yaw_out,
                      color="VinylTeal" if k % 2 else "VinylMauve")
        self.kit(room, "office_desk", room.cx, room.at_outer(3.0), room.yaw_in, width=1.2, depth=0.8)
        self.kit(room, "wheelchair", room.fx1 - 0.6, room.at_outer(4.6), -60.0)

    def isolation(self, room: Room) -> None:
        self.prop(room, "hospital_bed", room.cx, room.at_outer(2.0), room.yaw_in, head_angle=40.0)
        self.prop(room, "isolation_cart", room.fx1 - 0.5, room.at_outer(4.2), -90.0)
        self.prop(room, "wall_vitals_monitor", room.cx + 0.9, room.outer_z + room.inward * 0.23, room.yaw_in, y=1.5)

    def sluice(self, room: Room) -> None:
        self.prop(room, "soiled_linen_hamper", room.fx1 - 0.5, room.at_outer(1.0), -90.0, bag="yellow")
        self.prop(room, "kick_bucket", room.cx, room.at_outer(1.4), 0.0)
        self.prop(room, "waste_bin", room.fx1 - 0.5, room.at_outer(2.2), -90.0, kind="biohazard")
        self.hide(room, "closet", room.fx0 + 0.4, room.at_outer(1.6), 90.0)

    def theatre(self, room: Room) -> None:
        self.prop(room, "exam_table", room.cx, room.at_outer(3.2), 90.0)
        for dx in (-0.7, 0.7):
            self.prop(room, "exam_lamp", room.cx + dx, room.at_outer(2.0 + abs(dx)), 0.0, on=room.name.endswith("1"))
        self.prop(room, "instrument_tray", room.cx + 1.4, room.at_outer(4.2), 0.0, y=0.9)
        self.kit(room, "office_desk", room.cx + 1.4, room.at_outer(4.2), room.yaw_in, width=1.0, depth=0.6)
        self.prop(room, "crash_cart", room.fx0 + 0.5, room.at_outer(1.0), 90.0)
        self.prop(room, "o2_cylinder_cart", room.fx1 - 0.4, room.at_outer(0.8), -90.0)
        self.prop(room, "mobile_vitals", room.cx - 1.6, room.at_outer(3.4), 90.0, on=room.name.endswith("1"))
        self.prop(room, "waste_bin", room.fx1 - 0.5, room.at_outer(2.0), -90.0, kind="biohazard")
        self.prop(room, "sterile_wall_cabinet", room.cx - 1.2, room.outer_z + room.inward * 0.18, room.yaw_in, y=1.45)

    def scrub(self, room: Room) -> None:
        for k in range(2):
            self.prop(room, "paper_towel_dispenser", room.cx - 1.0 + k * 2.0, room.outer_z + room.inward * 0.06, room.yaw_in, y=1.15)
        self.kit(room, "shelving_unit", room.fx1 - 0.3, room.at_outer(1.4), -90.0, width=1.2)
        self.prop(room, "scrubs_stack", room.fx1 - 0.3, room.at_outer(1.4), -90.0, y=0.98)
        self.hide(room, "locker", room.fx0 + 0.36, room.at_outer(1.0), 90.0)
        self.bottle(room, room.fx1 - 0.3, room.at_outer(1.8), 0.98)

    def recovery(self, room: Room) -> None:
        self.ward(room, beds_hide=1)
        self.prop(room, "wall_vitals_monitor", room.cx, room.outer_z + room.inward * 0.23, room.yaw_in, y=1.5, on=True)

    def sterile(self, room: Room) -> None:
        for k in range(3):
            self.kit(room, "shelving_unit", room.fx0 + 0.3, room.at_outer(1.0 + k * 1.6), 90.0, width=1.4)
        self.prop(room, "linen_cart", room.fx1 - 0.7, room.at_outer(1.2), -90.0)
        self.prop(room, "supply_bin_row", room.fx0 + 0.3, room.at_outer(2.6), 90.0, y=1.41)

    def anaesthetics(self, room: Room) -> None:
        self.prop(room, "med_cart", room.fx0 + 0.6, room.at_outer(1.0), 90.0, locked=True)
        self.prop(room, "o2_cylinder_rack", room.cx, room.outer_z + room.inward * 0.2, room.yaw_in)
        self.prop(room, "infusion_pump_pole", room.fx1 - 0.5, room.at_outer(2.0), 0.0)
        self.hide(room, "closet", room.fx1 - 0.4, room.at_outer(4.2), -90.0)

    def waiting(self, room: Room) -> None:
        self.kit(room, "waiting_chairs", room.cx, room.outer_z + room.inward * 0.6, room.yaw_in, seats=4)
        self.kit(room, "waiting_chairs", room.fx0 + 0.6, room.at_outer(3.2), 90.0, seats=3)
        self.prop(room, "fire_extinguisher_cabinet", room.fx1 - 0.085, room.at_outer(2.0), -90.0, y=0.8)

    def changing(self, room: Room) -> None:
        for k in range(4):
            if k in (1, 2):
                self.hide(room, "locker", room.fx1 - 0.36, room.at_outer(1.0 + k * 0.7), -90.0)
        self.prop(room, "soiled_linen_hamper", room.fx0 + 0.5, room.at_outer(1.0), 90.0)
        self.prop(room, "scrubs_stack", room.cx, room.at_outer(4.6), 0.0, y=0.0)

    def icu(self, room: Room) -> None:
        if room.width > 8.0:
            self.icu_unit(room)
            return
        for k, x in enumerate((room.fx0 + 1.4, room.fx1 - 1.4)):
            if k == 0:
                self.prop(room, "hospital_bed", x, room.at_outer(1.6), room.yaw_in, head_angle=35.0)
            else:
                self.hide(room, "bed", x, room.at_outer(1.6), 90.0 if room.front else -90.0)
            self.prop(room, "wall_vitals_monitor", x + 0.9, room.outer_z + room.inward * 0.23, room.yaw_in, y=1.5, on=k == 0)
            self.prop(room, "infusion_pump_pole", x - 0.9, room.at_outer(1.2), 0.0, bags=2, pump_on=k == 0)
        self.prop(room, "crash_cart", room.cx, room.at_outer(4.0), room.yaw_out)

    def icu_unit(self, room: Room) -> None:
        """The open unit: a bay between each pair of glass screens, a bed in each, its head to the facade, and a
        desk in the aisle where the nurses watched them all."""
        edges = [room.fx0] + list(plan.ICU_SCREENS[1]) + [room.fx1]
        for k, (a, b) in enumerate(zip(edges, edges[1:])):
            x = (a + b) / 2.0
            if k == 3:
                self.hide(room, "bed", x, room.at_outer(1.35), -90.0)
            else:
                self.prop(room, "hospital_bed", x, room.at_outer(1.25), room.yaw_in, head_angle=25.0 + 7 * k,
                          stripped=k == 1)
            self.prop(room, "wall_vitals_monitor", x + 0.85, room.outer_z + room.inward * 0.23, room.yaw_in, y=1.5, on=k % 2 == 0)
            self.prop(room, "infusion_pump_pole", x - 0.85, room.at_outer(1.0), 0.0, bags=1 + k % 2, pump_on=k == 0)
        self.kit(room, "reception_counter", (room.fx0 + room.fx1) / 2.0 + 1.4, room.at_outer(4.6), 0.0, length=2.6, depth=0.7)
        self.prop(room, "crt_terminal", (room.fx0 + room.fx1) / 2.0 + 1.0, room.at_outer(4.95), 180.0, y=0.76, on=True)
        self.prop(room, "crash_cart", room.fx0 + 0.6, room.at_outer(4.2), 90.0, drawers_open=(0, 2))
        self.prop(room, "mobile_vitals", room.fx1 - 0.6, room.at_outer(4.4), -90.0, on=True)
        self.bottle(room, (room.fx0 + room.fx1) / 2.0 + 2.2, room.at_outer(4.6) - room.inward * 0.37, 1.12)

    def office(self, room: Room) -> None:
        self.kit(room, "office_desk", room.cx, room.at_outer(1.6), room.yaw_out, width=1.8, depth=0.9)
        self.prop(room, "crt_terminal", room.cx - 0.3, room.at_outer(1.6), room.yaw_out, y=0.76)
        self.prop(room, "visitor_chair", room.cx - 0.5, room.at_outer(3.0), room.yaw_in, color="VinylMauve")
        self.prop(room, "visitor_chair", room.cx + 0.5, room.at_outer(3.0), room.yaw_in, color="VinylMauve")
        for k in range(2):
            self.kit(room, "filing_cabinet", room.fx1 - 0.35, room.at_outer(1.0 + k * 0.5), -90.0)
        self.prop(room, "binder_shelf", room.fx0 + 0.15, room.at_outer(2.4), 90.0, y=1.55)
        self.bottle(room, room.cx + 0.6, room.at_outer(1.6), 0.76)

    def radio(self, room: Room) -> None:
        self.kit(room, "office_desk", room.cx + 0.8, room.outer_z + room.inward * 0.5, room.yaw_out, width=2.2, depth=0.8)
        self.prop(room, "crt_terminal", room.cx + 0.3, room.outer_z + room.inward * 0.5, room.yaw_out, y=0.76, on=True)
        self.prop(room, "dot_matrix_printer", room.cx + 1.4, room.outer_z + room.inward * 0.5, room.yaw_out, y=0.76)
        self.kit(room, "notice_board", room.fx0 + 0.0, room.at_outer(2.6), 90.0)
        self.document(room, "flight", room.cx + 0.9, room.outer_z + room.inward * 0.45, 0.765)
        self.hide(room, "locker", room.fx1 - 0.36, room.at_outer(4.2), -90.0)

    def oncall(self, room: Room) -> None:
        for k in range(3):
            self.kit(room, "shelter_cot", room.fx0 + 1.2, room.at_outer(1.0 + k * 1.3), 0.0, made=k != 1)
        self.hide(room, "locker", room.fx1 - 0.36, room.at_outer(1.2), -90.0)
        self.hide(room, "locker", room.fx1 - 0.36, room.at_outer(1.9), -90.0)

    def conference(self, room: Room) -> None:
        self.kit(room, "office_desk", room.cx, room.at_outer(2.6), 90.0, width=2.4, depth=1.0)
        for side in (-1.0, 1.0):
            for k in range(2):
                self.prop(room, "visitor_chair", room.cx + side * 1.0, room.at_outer(2.0 + k * 1.2), -90.0 * side)
        self.kit(room, "notice_board", room.cx, room.outer_z + room.inward * 0.0, room.yaw_in)


CORRIDOR_N = plan.CORRIDOR[1] - plan.PT / 2      # the corridor's faces
CORRIDOR_S = plan.CORRIDOR[0] + plan.PT / 2
# Hanging signs across each corridor: (x, lines read walking toward +x, lines read walking toward -x).
HANGING = {
    0: [(-9.5, ["LOBBY", "WAY OUT"], ["STAIR A", "CLOSED"]), (9.5, ["STAIR B", "UPPER FLOORS"], ["LOBBY", "WAY OUT"])],
    1: [(-9.5, ["WARDS 2D  2E", "STAIR B"], ["STAIR A", "UP TO 3"]), (9.5, ["STAIR B", "DOWN ONLY"], ["WARDS 2A", "CHILDREN"])],
    2: [(-9.5, ["RECOVERY", "STAIR B"], ["STAIR A", "DOWN ONLY"]), (9.5, ["STAIR B", "UP TO 4"], ["THEATRES"])],
    3: [(-9.5, ["OFFICES", "STAIR B"], ["STAIR A", "ROOF ACCESS"]), (9.5, ["STAIR B", "DOWN"], ["INTENSIVE CARE", "ROOF: STAIR A"])],
}
DIRECTORY = ["CICELY GENERAL HOSPITAL", "4  INTENSIVE CARE  OFFICES", "3  THEATRES  RECOVERY", "2  WARDS  CHILDREN",
             "G  ADMISSIONS  EMERGENCY"]


def corridors(d: Dresser) -> None:
    for level in range(plan.LEVELS):
        y = plan.floor_y(level)
        # Unlit fittings along the ceiling, and the fittings of the storey's lights.
        lights = [(lx, lz) for _, ll, lx, lz, *_ in plan.LIGHTS if ll == level]
        for k in range(8):
            x = -12.25 + k * 3.5
            if all(abs(x - lx) > 1.2 or abs(-8.7 - lz) > 1.5 for lx, lz in lights):
                d.placements.append(dict(kit="ceiling_panel", name=f"L{level}_CorridorPanel{k}", level=level, x=x,
                                         z=-8.7, yaw=90.0, opts=dict(lit=False), tilt=None))
        for name, ll, lx, lz, colour, *_ in plan.LIGHTS:
            # No fitting where the lobby rises into the atrium: there is no ceiling to hang it from.
            if ll == level and not (level == 0 and -6.8 < lx < 6.8 and lz > plan.CORRIDOR[1]):
                d.fixture(level, "emergency" if colour == plan.EMERGENCY else "panel", lx, lz)
        # The signs over the corridor, and the directory on each stair landing.
        for x, toward_b, toward_a in HANGING[level]:
            d.sign(level, toward_b, x, 2.45, -8.7, -90.0, 1.5, hanging=True, back=toward_a)
        for core in ("A", "B"):
            c = plan.core_x(core)
            lx = (c["inner"] + c["landing_end"]) / 2.0
            d.sign(level, DIRECTORY, lx, 1.35, plan.CORE_Z[0] + plan.CORE_WALL / 2 + 0.012, 0.0, 1.5)
        del y
    # G: a gurney left by radiology with a stain under it, a wheelchair tipped over, records spilled, the trail
    # from emergency, and the way round the chained stair.
    gs = Room(dict(level=0, kind="corridor", name="Corridor", x0=-13.6, x1=13.6, z0=-10.1, z1=-7.3, doors=[]))
    d.kit(gs, "gurney", -7.4, CORRIDOR_S + 0.42, 4.0)
    d.decal(0, "blood_pool", -7.2, 0.0, CORRIDOR_S + 0.6, (1.3, 1.0), 20.0)
    d.kit(gs, "wheelchair", 8.2, CORRIDOR_N - 0.5, 200.0, tilt=[0.0, 82.0])
    d.papers(0, 9.6, -9.2, 0.9)
    d.papers(0, -2.4, -8.6, 0.7, 8)
    d.trail(0, [(-11.4, CORRIDOR_N - 0.3), (-10.6, -8.4), (-9.4, -9.2), (-7.9, -9.6)])
    d.text(0, "STAIR A IS CHAINED", -12.0, 1.75, CORRIDOR_S + 0.02, 0.0, 0.16)
    d.text(0, "USE STAIR B  ->", -12.0, 1.45, CORRIDOR_S + 0.02, 0.0, 0.2)
    d.decal(0, "handprint", -12.6, 1.2, CORRIDOR_S + 0.01, (0.35, 0.35), 0.0, facing=(0.0, 1.0))
    # 2: an empty wheelchair parked facing out over the atrium, a gurney, a pole knocked down, a chair thrown by
    # the nurse station, blood at the door of ward 2A, and the way round the buried stair.
    g1 = Room(dict(level=1, kind="corridor", name="Corridor", x0=-13.6, x1=13.6, z0=-10.1, z1=-7.3, doors=[]))
    d.kit(g1, "wheelchair", -1.6, CORRIDOR_N - 0.55, 180.0)
    d.kit(g1, "gurney", 11.4, CORRIDOR_S + 0.42, -3.0)
    d.kit(g1, "iv_stand", -10.8, -8.5, 30.0, tilt=[0.0, 84.0])
    d.prop(g1, "visitor_chair", -2.2, -8.1, 60.0)
    d.papers(1, -4.3, -8.9, 0.8)
    d.decal(1, "blood_pool", -8.6, 0.0, CORRIDOR_N - 0.7, (1.1, 0.9), 40.0)
    d.trail(1, [(-8.6, CORRIDOR_N - 0.6), (-8.4, -6.4), (-8.9, -5.0)])
    d.text(1, "STAIRS GONE", 12.2, 1.75, CORRIDOR_S + 0.02, 0.0, 0.2)
    d.text(1, "<-  USE STAIR A", 12.2, 1.45, CORRIDOR_S + 0.02, 0.0, 0.18)
    d.text(1, "SHE WAS SINGING", 4.7, 1.9, plan.IZ0 + 0.02, 0.0, 0.16)
    d.decal(1, "blood_spatter", 12.6, 1.0, CORRIDOR_S + 0.01, (0.9, 0.7), 0.0, facing=(0.0, 1.0))
    # 3: a body bag on a gurney outside recovery, a crash cart left in the corridor, instruments on the floor, the
    # trail out of theatre 1 toward the suite doors, and the way round the barricade.
    g2 = Room(dict(level=2, kind="corridor", name="Corridor", x0=-13.6, x1=13.6, z0=-10.1, z1=-7.3, doors=[]))
    d.bodybag(2, 11.6, CORRIDOR_N - 0.42, 2.0)
    d.prop(g2, "crash_cart", 3.0, CORRIDOR_S + 0.35, 0.0, drawers_open=(1,))
    d.kit(g2, "iv_stand", -5.8, -8.0, 120.0, tilt=[0.0, 80.0])
    d.papers(2, 2.0, -8.6, 0.6, 6)
    d.trail(2, [(-8.6, CORRIDOR_N - 0.3), (-7.2, -8.6), (-3.0, -9.2), (2.0, -9.0), (6.5, -8.7)], 0.45)
    d.decal(2, "blood_pool", -8.6, 0.0, CORRIDOR_N - 0.5, (1.0, 0.8), 10.0)
    d.text(2, "STAIR B  ->", -12.2, 1.6, CORRIDOR_S + 0.02, 0.0, 0.22)
    d.text(2, "NOBODY CAME OUT", 6.9, 2.95, -8.7, -90.0, 0.13)
    # 4: a bed wheeled out into the corridor, papers from the offices, a fallen tile, and the way to the roof.
    g3 = Room(dict(level=3, kind="corridor", name="Corridor", x0=-13.6, x1=13.6, z0=-10.1, z1=-7.3, doors=[]))
    d.prop(g3, "hospital_bed", 11.4, CORRIDOR_S + 0.6, -90.0, head_angle=10.0, stripped=True)
    d.papers(3, 3.2, -8.7, 1.0)
    d.papers(3, -4.6, -9.3, 0.6, 8)
    d.text(3, "ROOF", 12.2, 1.8, CORRIDOR_S + 0.02, 0.0, 0.26)
    d.text(3, "<-  STAIR A", 12.2, 1.45, CORRIDOR_S + 0.02, 0.0, 0.2)
    d.text(3, "DON'T LET IT FOLLOW YOU UP", -12.2, 1.85, CORRIDOR_S + 0.02, 0.0, 0.12)
    d.decal(3, "water_stain", -9.8, 2.0, CORRIDOR_N - 0.01, (1.6, 1.4), 0.0, facing=(0.0, -1.0))
    d.decal(3, "water_stain", 6.0, 2.1, CORRIDOR_S + 0.01, (1.4, 1.2), 0.0, facing=(0.0, 1.0))
    for level in range(plan.LEVELS):
        for x in (-6.0, 1.0, 9.0):
            d.decal(level, "grime", x + level * 0.7, 0.45, CORRIDOR_S + 0.01, (2.4, 0.9), 0.0, facing=(0.0, 1.0))
            d.decal(level, "grime", x - 2.0 - level * 0.5, 0.45, CORRIDOR_N - 0.01, (2.0, 0.9), 0.0, facing=(0.0, -1.0))


def build() -> Dresser:
    dresser = Dresser()
    for r in plan.ROOMS:
        room = Room(dict(level=r[0], kind=r[1], name=r[2], x0=r[3], x1=r[4], z0=r[5], z1=r[6], doors=r[7]))
        method = getattr(dresser, room.kind, None)
        if method is None:
            raise ValueError(f"no dressing for room kind {room.kind!r}")
        method(room)
        if room.kind not in ("lobby", "void"):
            dresser.basics(room)
    corridors(dresser)
    return dresser


if __name__ == "__main__":
    d = build()
    print(f"{len(d.placements)} placements, {len(d.hiding)} hiding spots, {len(d.bottles)} bottles, "
          f"documents {sorted(d.documents)}")
    del math
