"""First-person clips for the alt route's double-barrelled shotgun, on the arms of
models/player/fpsWhite_holding_idle.glb.

The gun hangs from the right hand the way the pipe does: the right fist closes round the stock's wrist
exactly where it closes round the pipe, with the wrist's line through the fist where the pipe's was,
so the fingers keep their grip. How far the gun is turned round that line is chosen once, as the most
natural right arm in the ready pose.

The left hand cradles the fore-end from below, the palm up under it, and its fingers curl round it until
their skin touches it and no further (gun_distance is a rough model of the gun's surface to test the
hand's mesh against); it stays on the fore-end when the barrels swing down to open. To reload it drops
off the fore-end and goes to the pocket, comes back with two shells pinched by their rims between the
thumb and fingers, lines them up behind the open chambers and pushes them in, lets go and comes back
along the side of the barrels to the fore-end. The open gun is tipped up toward the eye so the chambers
are in plain view past the action.

A clip's keys say where the gun is in the player's view: the right fist (screen x and y from -1 to 1
across the 4:3 picture, and depth in metres from the eye), which way the barrels point (yaw and pitch),
how far the gun is canted, how far the barrels are broken open, and where the left hand is (one of
the left_anchors). The arms are solved to it with the same two-bone arms as the pipe swings
(swings.Arms). The upper body stands bladed, turned STANCE_TURN to the right round the spine, which
brings the left shoulder forward enough for the left hand to reach the fore-end, the way a real
shooter stands.

Every clip starts and ends on the READY key, which shotgun_idle breathes around.
"""

import math
from dataclasses import dataclass

from mathutils import Matrix, Quaternion, Vector

import shotgun_layout as layout
import swings
from swings import FPS, UP, aim_direction, camera_axes, catmull, ease_in, ease_out, on_screen, smooth, swivels

STANCE_TURN = 35.0           # degrees the upper body is turned to the right while holding the gun
SWIVEL_RANGE = 40.0
# How far out of the chambers the shells still are when the left hand lets go of them (they slide the rest
# of the way on their own, the fingers staying clear of the breech), and how far behind them they are
# lined up before going in.
SHELL_LET_GO = 0.03
SHELL_LINE_UP = layout.SHELL_LENGTH + 0.03
# Where the left hand goes to fetch the shells, in camera axes from the eye: down by the left hip, out of
# view, far enough from the shoulder that the arm is not folded double.
POCKET = (-0.22, -0.72, 0.16)
# On the way up from the pocket the hand passes this far below and left of the line-up, in camera axes, so
# it rises into it from below; after letting go of the shells it backs off RELEASE metres along the barrels.
LIFT = (-0.05, -0.04, -0.02)
RELEASE = 0.04
# Round the fore-end, in the barrels' frame: the hand first drops this far straight down off it, and on the
# way back from the breech its wrist passes here, beside the barrels on the side it let go of the shells.
OFF_FORE_END = Vector((0.0, 0.0, -0.06))
BESIDE_BARRELS = Vector((0.13, 0.08, -0.04))
# Anchors the hand only passes through: its wrist stays as it is at rest on the forearm there.
PASSING = ("pocket",)
# Anchors on the line the shells go in along: the hand runs straight between them, pushing them in and
# backing off.
ALONG_BARRELS = ("line_up", "insert", "release")
# The pinch the left hand carries the shells in, to start from: the index and the other fingers curled
# these shares of the pipe grip, the thumb's bones turned these degrees across the palm. The shells sit
# by their rims between the three tips, pointing out of the pinch along the fingers tipped PINCH_TILT
# degrees toward the palm; then the fingers and the thumb close until they touch them.
PINCH_CURL = {"Index01.L": 0.85, "Fingers01.L": 0.9}
PINCH_THUMB = (10.0, 5.0, 0.0)
PINCH_TILT = 20.0
# Letting go: the pinch opened to this share; leaving the fore-end and coming back to it, the cradle opened to
# this share.
PINCH_OPEN = 0.4
CRADLE_LOOSE = 0.6
# In choosing how the shells turn in the pinch, how much the hand going into the gun while it pushes them in
# (per metre of skin inside, summed) and the shells being out of sight (per share hidden) count against the
# arm's comfort. A brush with the action on the way in matters less than the eye seeing the shells go in.
SHELLS_INSIDE_GUN = 1500.0
SHELLS_IN_SIGHT = 600.0
# Which finger pose the left hand has at each of its anchors; at the others it holds the shells.
FINGER_POSE = {"fore_end": "cradle", "off": "loose", "beside": "loose", "release": "open"}


@dataclass
class GunKey:
    time: float
    grip: tuple = None          # the right fist on the stock: screen x, y and depth; None: as READY
    aim: tuple = None           # the barrels' yaw and pitch in degrees; None: as READY
    cant: float = None          # degrees the gun is turned round the barrels, its top to the right
    open: float = 0.0           # 0 closed, 1 broken open by layout.BREAK_ANGLE
    left: str = "fore_end"      # where the left hand is: one of ShotgunRig.left_anchors
    elbow: tuple = None         # right elbow hint in camera axes (right, up, forward); None: as READY
    left_elbow: tuple = None
    turn: float = None          # degrees the upper body is turned to the right; None: as READY
    ease: object = smooth       # timing of the stretch that arrives at this key


@dataclass
class GunClip:
    name: str
    duration: float
    keys: list
    loop: bool = False
    shot: float = None          # when the gun goes off, for the game's muzzle flash and pellets
    eject: float = None         # when the spent shells kick out of the opened breech
    grab: float = None          # when the left hand has the new shells
    transfer: float = None      # when it lets go of them, nearly in the chambers: the gun is loaded
    seated: float = None        # when they have slid fully in

    @property
    def frames(self):
        return round(self.duration * FPS)

    @property
    def sounds(self) -> dict:
        """When each of the gun's action sounds lands in this clip, in seconds: the barrels unlocking as
        they start to drop, the spent shells kicking out, the new ones seating and the barrels snapping
        shut. Empty for a clip that does not open the gun."""
        opened = [index for index, key in enumerate(self.keys) if key.open > 0.0]
        if not opened:
            return {}
        sounds = {"break_open": self.keys[opened[0] - 1].time, "snap_shut": self.keys[opened[-1] + 1].time}
        if self.eject is not None:
            sounds["shells_out"] = self.eject
        if self.seated is not None:
            sounds["shells_in"] = self.seated
        return sounds


READY = GunKey(0.0, grip=(0.66, -0.98, 0.38), aim=(-13.0, 7.0), cant=-10.0, elbow=(0.6, -0.8, -0.1),
               left_elbow=(0.1, -1.0, 0.0), turn=STANCE_TURN)


def moved(time: float, ease=smooth, grip=(0.0, 0.0, 0.0), aim=(0.0, 0.0), cant: float = 0.0, open: float = 0.0,
          left: str = "fore_end", turn: float = 0.0, left_elbow: tuple = None) -> GunKey:
    """The ready pose at `time`, moved by these amounts: the grip in screen units and metres of depth,
    the aim, cant and the body's turn in degrees. Clips are written this way so that moving READY
    moves them all. `left_elbow` replaces the ready pose's left elbow hint."""
    return GunKey(time, grip=tuple(a + b for a, b in zip(READY.grip, grip)),
                  aim=(READY.aim[0] + aim[0], READY.aim[1] + aim[1]), cant=READY.cant + cant, open=open, left=left,
                  elbow=READY.elbow, left_elbow=left_elbow or READY.left_elbow, turn=READY.turn + turn, ease=ease)


# The broken-open pose: the thumb has pushed the top lever and the barrels have dropped; the action is
# tipped up and over to the left, so the eye looks down past it into both chambers.
OPEN = dict(grip=(-0.16, 0.03, 0.06), aim=(-27.0, 45.0), cant=-40.0, open=1.0)
# Loading: the same, turned a little further toward the left hand.
LOADING = {**OPEN, "grip": (-0.17, 0.04, 0.05), "aim": (-28.0, 47.0), "cant": -42.0}
# Reaching down for the pocket, the elbow goes out to the left and back.
TO_POCKET = (-0.7, -0.2, -0.6)

CLIPS = [
    # Breathing while held ready: the gun rises and settles a few millimetres and drifts a little.
    GunClip("shotgun_idle", 4.0, [
        moved(0.0),
        moved(1.0, grip=(0.0, 0.02, 0.0), aim=(0.3, 0.4), cant=0.5),
        moved(2.0, grip=(0.005, 0.01, -0.005), aim=(-0.2, 0.1), cant=-0.5),
        moved(3.0, grip=(-0.002, -0.01, 0.0), aim=(-0.1, -0.3)),
        moved(4.0),
    ], loop=True),
    # One barrel goes off: the gun kicks back into the shoulder and the muzzles jump high, then it comes
    # back down to ready.
    GunClip("shotgun_fire", 0.5, [
        moved(0.0),
        moved(0.05, grip=(0.035, 0.10, -0.07), aim=(1.5, 12.0), cant=4.0, turn=4.0, ease=ease_out),
        moved(0.18, grip=(0.012, 0.04, -0.03), aim=(0.5, 4.0), cant=1.5, turn=1.0, ease=ease_out),
        moved(0.32, grip=(0.0, -0.01, 0.0), aim=(0.0, -0.8), ease=smooth),
        moved(0.5),
    ], shot=0.0),
    # Reloading: break it open and the spent shells kick out; the left hand fetches two shells from the
    # pocket, lines them up behind the chambers and pushes them in; it lets go, goes back to the fore-end
    # and snaps the gun shut.
    GunClip("shotgun_reload", 2.3, [
        moved(0.0),
        moved(0.12, grip=(0.0, 0.03, -0.03), aim=(-2.0, 4.0), cant=-8.0),
        moved(0.34, ease=ease_out, **OPEN),
        moved(0.46, **OPEN),
        moved(0.54, left="off", **OPEN),
        moved(0.66, left="pocket", left_elbow=TO_POCKET, **OPEN),
        moved(0.78, left="pocket", left_elbow=TO_POCKET, **OPEN),
        moved(1.00, left="lift", **LOADING),
        moved(1.14, left="line_up", **LOADING),
        moved(1.30, left="insert", ease=ease_in, **LOADING),
        moved(1.40, left="release", **LOADING),
        moved(1.50, left="beside", **OPEN),
        moved(1.60, **OPEN),
        moved(1.74, grip=(0.0, 0.02, -0.02), aim=(-1.0, 4.0), cant=-6.0, ease=ease_in),
        moved(1.92, ease=ease_out),
        moved(2.3),
    ], eject=0.36, grab=0.78, transfer=1.30, seated=1.40),
]


def _basis(first: Vector, second: Vector) -> Matrix:
    """A right-handed 3x3 basis with `first` as its first column and `second`, made perpendicular, as
    its second."""
    first = first.normalized()
    second = (second - first * second.dot(first)).normalized()
    return Matrix((first, second, first.cross(second))).transposed()


def hinge(open_amount: float) -> Matrix:
    """The barrels' part swung down on the hinge pin, in the gun's frame."""
    angle = math.radians(layout.BREAK_ANGLE * open_amount)
    return Matrix.Translation(layout.HINGE) @ Matrix.Rotation(-angle, 4, "X") @ Matrix.Translation(-layout.HINGE)


def chambers(gun: Matrix, open_amount: float, out: float) -> Matrix:
    """The pair of shells in the world, `out` metres short of seated in the chambers: their middle
    between the rims, +Y into the chambers, +X across to the right barrel."""
    return gun @ hinge(open_amount) @ Matrix.Translation(layout.BREECH + Vector((0.0, -out, 0.0)))


# --- Contact: how far a point is from the gun's surface --------------------------------------------

def _box_distance(point: Vector, low, high) -> float:
    centre = (Vector(low) + Vector(high)) / 2.0
    half = (Vector(high) - Vector(low)) / 2.0
    q = Vector([abs(point[i] - centre[i]) - half[i] for i in range(3)])
    outside = Vector([max(c, 0.0) for c in q]).length
    return outside + min(max(q.x, q.y, q.z), 0.0)


def _along_y_distance(point: Vector, x: float, z: float, half_width: float, half_height: float, start: float,
                      end: float) -> float:
    """A rod along Y with an elliptical cross-section; the distance is exact for round ones."""
    radial = (math.hypot((point.x - x) / half_width, (point.z - z) / half_height) - 1.0) * min(half_width, half_height)
    axial = max(start - point.y, point.y - end)
    return math.hypot(max(radial, 0.0), max(axial, 0.0)) + min(max(radial, axial), 0.0)


def shells_distance(point: Vector) -> float:
    """How far a point in the pair of shells' frame (as chambers() gives it) is outside both shells."""
    return min(_along_y_distance(point, side * layout.BARREL_X, 0.0, layout.SHELL_RADIUS, layout.SHELL_RADIUS, 0.0,
                                 layout.SHELL_LENGTH) for side in (-1.0, 1.0))


def gun_distance(point: Vector, open_amount: float = 0.0) -> float:
    """Roughly how far a point in the gun's frame is outside the gun: the action, the stock's wrist, both
    barrels and the fore-end (those last two swung open by `open_amount`). Negative inside."""
    low, high = layout.ACTION
    distances = [_box_distance(point, low, high), _along_y_distance(point, 0.0, 0.0, *layout.WRIST, -0.10, 0.035)]
    swung = hinge(open_amount).inverted() @ point
    start, end, radius = layout.BARREL
    for side in (-1.0, 1.0):
        distances.append(_along_y_distance(swung, side * layout.BARREL_X, layout.BORE_Z, radius, radius, start, end))
    near, far, centre, half_width, half_height = layout.FORE_END
    distances.append(_along_y_distance(swung, 0.0, centre, half_width, half_height, near, far))
    return min(distances)


# The left hand's own frame (from the rig): its fingers point along +Y, curl toward -X, the palm's side,
# and spread along Z, the index finger toward -Z and the thumb on that side.
LEFT_PALM = Vector((-1.0, 0.0, 0.0))
LEFT_FINGERS = Vector((0.0, 1.0, 0.0))
# The middle of the palm, which rests on the fore-end.
PALM_MIDDLE = Vector((-0.03, 0.09, -0.01))
# The left finger chains, base to tip; the middle, ring and little fingers are rigged as one.
FINGER_CHAINS = (
    ("Index01.L", "Index02.L", "Index03.L"),
    ("Fingers01.L", "Fingers02.L", "Fingers03.L"),
    ("Thumb01.L", "Thumb02.L", "Thumb03.L"),
)
CURL_STEPS = [step / 20.0 for step in range(-12, 27)]  # from a little past straight (0) past the pipe grip (1) to 1.3
# How close the skin comes to what it rests on, in metres.
SKIN_GAP = 0.002


class ShotgunRig:
    left_anchors = ("fore_end", "off", "pocket", "lift", "line_up", "insert", "release", "beside")

    def __init__(self, arms: swings.Arms):
        self.arms = arms
        hand = arms.world @ arms.bones["Hand.R"].matrix
        fingers = [(arms.world @ arms.bones[name].matrix).translation for name in ("Index01.R", "Fingers01.R")]
        fist = hand.inverted() @ (sum(fingers, Vector()) / len(fingers))
        # Where the pipe runs through the fist, in the right hand's own frame: the stock's wrist goes there.
        self.axis = arms.pipe_axis.normalized()
        self.grip = arms.pipe_middle + self.axis * (fist - arms.pipe_middle).dot(self.axis)
        self.reference = (Vector((0.0, 1.0, 0.0)) - self.axis * self.axis.y).normalized()
        self.right_roll = 0.0
        self.left_hold = Matrix.Identity(4)
        self.shells_roll = 0.0
        self.skin = self._left_skin()
        self.pinch_fingers, self.pinch_hold, self.pinch_skin = self._pinch()
        self.shells_hold = self.pinch_hold
        self._choose_holds()
        self.pinch_fingers = self._close_pinch()
        self.cradle_fingers = self._curl_fingers_onto_gun()
        self.finger_poses = {
            "cradle": self.cradle_fingers,
            "pinch": self.pinch_fingers,
            "open": {name: Quaternion().slerp(turn, PINCH_OPEN) for name, turn in self.pinch_fingers.items()},
            "loose": {name: Quaternion().slerp(turn, CRADLE_LOOSE) for name, turn in self.cradle_fingers.items()},
        }
        self.previous = None

    # --- How the hands sit on the gun -----------------------------------------------------------

    def mount(self, roll: float = None) -> Matrix:
        """The gun in the right hand's frame: its wrist on the pipe's line through the fist."""
        roll = self.right_roll if roll is None else roll
        perpendicular = Quaternion(self.axis, math.radians(roll)) @ self.reference
        hand_axes = _basis(self.axis, perpendicular)
        gun_axes = _basis(layout.GRIP_AXIS, Vector((0.0, 0.0, 1.0)))
        return Matrix.Translation(self.grip) @ (hand_axes @ gun_axes.transposed()).to_4x4()

    @staticmethod
    def cradle(yaw: float, tilt: float, along: float, across: float) -> Matrix:
        """The left hand in the barrels' frame, cradling the fore-end from below: the palm up under it,
        tipped `tilt` degrees round the fingers, the fingers pointing `yaw` degrees forward of straight
        across to the right, the middle of the palm `along` the fore-end and `across` it."""
        fingers = Vector((math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), 0.0))
        palm_up = Quaternion(fingers, math.radians(tilt)) @ Vector((0.0, 0.0, 1.0))
        rotation = _basis(fingers, palm_up) @ _basis(LEFT_FINGERS, LEFT_PALM).transposed()
        _near, _far, centre, _half_width, half_height = layout.FORE_END
        contact = Vector((across, along, centre - half_height - 0.003))
        return Matrix.Translation(contact - rotation @ PALM_MIDDLE) @ rotation.to_4x4()

    def shells_in_hand(self) -> Matrix:
        """The pair of shells in the left hand's frame: pinched by the rims, pointing out of the pinch,
        turned shells_roll degrees round their own length and fitted to the fingertips."""
        return self.shells_hold

    def _left_skin(self) -> dict:
        """The left hand's skin: the arms mesh's vertices that move mostly with the left hand or one of its
        finger bones, each in that bone's own frame, as they are in the idle pose. Carried on their bones,
        they are where the skin is in any pose, closely enough to keep it out of the gun and the shells."""
        import bpy

        arms = self.arms
        for bone in arms.bones:
            bone.matrix_basis = arms.idle_basis[bone.name]
        bpy.context.view_layer.update()
        mesh_object = next(obj for obj in arms.object.children if obj.type == "MESH" and obj.name.startswith("FPS_Arms"))
        groups = [group.name for group in mesh_object.vertex_groups]
        to_bone = {name: (arms.world @ arms.bones[name].matrix).inverted()
                   for name in ("Hand.L",) + sum(FINGER_CHAINS, ())}
        evaluated = mesh_object.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        skin = {name: [] for name in to_bone}
        for vertex in mesh_object.data.vertices:
            if vertex.groups:
                name = groups[max(vertex.groups, key=lambda group: group.weight).group]
                if name in skin:
                    skin[name].append(to_bone[name] @ (evaluated.matrix_world @ mesh.vertices[vertex.index].co))
        evaluated.to_mesh_clear()
        return skin

    def _skin_at(self, names) -> list:
        """The skin on these left-hand bones where the current pose puts it, in the world."""
        points = []
        for name in names:
            bone = self.arms.world @ self.arms.bones[name].matrix
            points += [bone @ point for point in self.skin[name]]
        return points

    def _pinch(self):
        """The pinch to start from (PINCH_CURL, PINCH_THUMB), where the pair of shells sits in it, in the
        left hand's frame (the rims between the tips of the index, the other fingers and the thumb, side
        by side from the index to the others), and the whole hand's skin in that pose, in its frame."""
        import bpy

        arms = self.arms
        for bone in arms.bones:
            bone.matrix_basis = arms.idle_basis[bone.name]
        turns = {}
        for chain in FINGER_CHAINS[:2]:
            for name in chain:
                axis, angle = arms.left_fingers[name].to_axis_angle()
                turns[name] = Quaternion(axis, angle * PINCH_CURL[chain[0]])
        for name, angle in zip(FINGER_CHAINS[2], PINCH_THUMB):
            turns[name] = Quaternion(Vector((1.0, 0.0, 0.0)), math.radians(angle))
        for name, turn in turns.items():
            arms.bones[name].rotation_quaternion = turn
        bpy.context.view_layer.update()
        to_hand = (arms.world @ arms.bones["Hand.L"].matrix).inverted()
        tips = [to_hand @ (arms.world @ arms.bones[chain[-1]].tail) for chain in FINGER_CHAINS]
        tilt = math.radians(PINCH_TILT)
        along = LEFT_FINGERS * math.cos(tilt) + LEFT_PALM * math.sin(tilt)
        across = tips[1] - tips[0]
        across = (across - along * across.dot(along)).normalized()
        rims = sum(tips, Vector()) / len(tips) - along * 0.004
        hold = Matrix.Translation(rims) @ Matrix((across, along, across.cross(along))).transposed().to_4x4()
        skin = {name: [to_hand @ point for point in self._skin_at([name])] for name in self.skin}
        return turns, hold, skin

    def _fitted_pinch(self, roll: float) -> Matrix:
        """The shells in the starting pinch turned `roll` degrees round their own length, slid to where the
        skin of its fingertips (the index, the other fingers and the thumb) rests on them and none goes
        into them: first on a coarse grid, then a fine one round the best."""
        turned = self.pinch_hold @ Matrix.Rotation(math.radians(roll), 4, "Y")
        tips = {chain[-1] for chain in FINGER_CHAINS}
        skin = [(name in tips, points[::2]) for name, points in self.pinch_skin.items()]

        def cost(offset):
            to_pair = (Matrix.Translation(offset) @ turned).inverted()
            total = 0.0
            for tip, points in skin:
                gaps = [shells_distance(to_pair @ point) for point in points]
                total += 10.0 * sum(min(gap, 0.0) ** 2 for gap in gaps)
                if tip:
                    total += (min(gaps) - SKIN_GAP) ** 2
            return total

        coarse = [step * 0.006 for step in range(-4, 5)]
        fine = [step * 0.002 for step in range(-2, 3)]
        best = min((Vector((x, y, z)) for x in coarse for y in coarse for z in coarse), key=cost)
        best = min((best + Vector((x, y, z)) for x in fine for y in fine for z in fine), key=cost)
        return Matrix.Translation(best) @ turned

    def _close_pinch(self) -> dict:
        """The pinch's fingers and thumb closed onto the shells as they are held: each chain curls evenly
        from straight toward and past the starting pinch until its skin would touch them."""
        import bpy

        arms = self.arms
        for bone in arms.bones:
            bone.matrix_basis = arms.idle_basis[bone.name]
        bpy.context.view_layer.update()
        to_pair = (arms.world @ arms.bones["Hand.L"].matrix @ self.shells_in_hand()).inverted()
        turns = {}
        for chain in FINGER_CHAINS:
            start = {name: self.pinch_fingers[name].to_axis_angle() for name in chain}
            settled = 0.0
            for step in range(41):
                share = step / 20.0
                for name in chain:
                    axis, angle = start[name]
                    arms.bones[name].rotation_quaternion = Quaternion(axis, angle * share)
                bpy.context.view_layer.update()
                if min(shells_distance(to_pair @ point) for point in self._skin_at(chain)) < SKIN_GAP:
                    break
                settled = share
            for name in chain:
                axis, angle = start[name]
                turns[name] = Quaternion(axis, angle * settled)
                arms.bones[name].rotation_quaternion = turns[name]
            bpy.context.view_layer.update()
        print("SHOTGUN PINCH " + " ".join("%s %.0f" % (name, math.degrees(turn.angle)) for name, turn in turns.items()))
        return turns

    def _penetration(self, hand: Matrix, gun: Matrix, open_amount: float, skin: dict = None) -> float:
        """How deep the left hand's skin is inside the gun, summed, in metres: by default the palm and the
        back of the hand, or else all of `skin` (bone name to points in the hand's frame)."""
        to_gun = gun.inverted() @ hand
        points = self.skin["Hand.L"] if skin is None else sum(skin.values(), [])
        return sum(max(0.0, SKIN_GAP - gun_distance(to_gun @ point, open_amount)) for point in points)

    @staticmethod
    def _hidden(hand: Matrix, pair: Matrix, skin: dict) -> float:
        """The share of points along the pair of shells that the left hand's skin (bone name to points in
        the hand's frame) hides from the eye: those whose line of sight passes within a finger's
        thickness of the skin on the way."""
        points = [hand @ point for point in sum(skin.values(), [])]
        targets = [pair @ Vector((side * layout.BARREL_X, along, 0.0))
                   for side in (-1.0, 1.0) for along in (0.012, 0.03, 0.048, 0.064)]
        hidden = 0
        for target in targets:
            sight = target - swings.EYE
            length = sight.length
            sight /= length
            for point in points:
                ahead = (point - swings.EYE).dot(sight)
                if 0.0 < ahead < length - 0.012 and ((point - swings.EYE) - sight * ahead).length < 0.012:
                    hidden += 1
                    break
        return hidden / len(targets)

    def _clear_of_fore_end(self, hold: Matrix) -> Matrix:
        """A cradle (the left hand in the closed gun's frame) lowered, straight down from the barrels, until
        the palm's skin is clear of the gun."""
        for _attempt in range(4):
            deepest = max(SKIN_GAP - gun_distance(hold @ point) for point in self.skin["Hand.L"])
            if deepest <= 0.0005:
                break
            hold = Matrix.Translation((0.0, 0.0, -deepest)) @ hold
        return hold

    def _choose_holds(self) -> None:
        """The right hand's turn round the stock, the left hand's cradle under the fore-end and how it
        holds the shells, each leaving its arm most natural without going into the gun."""
        gun, body = gun_matrix(READY), body_matrix(self.arms, READY.turn)
        to_body = body.inverted()
        hint = to_body.to_3x3() @ camera_axes(*READY.elbow).normalized()
        best = None
        for roll in range(-180, 180, 5):
            hand = to_body @ gun @ self.mount(roll).inverted()
            cost = min(self.arms.strain("R", hand.translation, hand.to_quaternion(), hint, swivel, True)[0]
                       for swivel in swivels(SWIVEL_RANGE))
            if best is None or cost < best[0]:
                best = (cost, roll)
        self.right_roll = best[1]
        left_hint = to_body.to_3x3() @ camera_axes(*READY.left_elbow).normalized()
        best = None
        for yaw in range(0, 76, 15):
            for tilt in range(-30, 31, 15):
                for along in (0.24, 0.28, 0.32):
                    for across in (-0.012, 0.0, 0.012):
                        hold = self._clear_of_fore_end(self.cradle(yaw, tilt, along, across))
                        hand = to_body @ gun @ hold
                        cost = min(self.arms.strain("L", hand.translation, hand.to_quaternion(), left_hint, swivel, True)[0]
                                   for swivel in swivels(SWIVEL_RANGE))
                        cost += 4000.0 * self._penetration(gun @ hold, gun, 0.0)
                        if best is None or cost < best[0]:
                            best = (cost, (yaw, tilt, along, across))
        self.left_hold = self._clear_of_fore_end(self.cradle(*best[1]))
        # The shells' turn in the pinch: the arm most natural at the push into the chambers, the hand's
        # skin out of the gun all the way from lining them up to backing off after letting go, and the
        # shells in sight of the eye, not behind the hand, while they go in.
        loading = moved(0.0, **LOADING)
        gun, body = gun_matrix(loading), body_matrix(self.arms, loading.turn)
        to_body = body.inverted()
        skin = {name: points[::2] for name, points in self.pinch_skin.items()}
        best_shells = None
        for roll in range(0, 360, 15):
            hold = self._fitted_pinch(roll)
            hand = chambers(gun, 1.0, SHELL_LET_GO) @ hold.inverted()
            local = to_body @ hand
            strain = min(self.arms.strain("L", local.translation, local.to_quaternion(), left_hint, swivel, True)[0]
                         for swivel in swivels(SWIVEL_RANGE))
            pairs = [chambers(gun, 1.0, out) for out in
                     (SHELL_LINE_UP, (SHELL_LINE_UP + SHELL_LET_GO) / 2.0, SHELL_LET_GO, SHELL_LET_GO + RELEASE)]
            inside = sum(self._penetration(pair @ hold.inverted(), gun, 1.0, skin) for pair in pairs)
            hidden = sum(self._hidden(pair @ hold.inverted(), pair, skin) for pair in pairs[:2]) / 2.0
            cost = strain + SHELLS_INSIDE_GUN * inside + SHELLS_IN_SIGHT * hidden
            if best_shells is None or cost < best_shells[0]:
                best_shells = (cost, roll, hold)
        _cost, self.shells_roll, self.shells_hold = best_shells
        print("SHOTGUN HOLD right roll %d; left cradle yaw %d tilt %d along %.2f across %.3f; shells roll %d"
              % (self.right_roll, *best[1], self.shells_roll))

    def _curl_fingers_onto_gun(self) -> dict:
        """The left fingers for the cradle: each joint, base to tip, curls from straight toward and past
        the pipe grip until the skin it moves would touch the gun."""
        import bpy

        arms = self.arms
        gun = gun_matrix(READY)
        hand = gun @ self.left_hold
        to_gun = gun.inverted()
        for bone in arms.bones:
            bone.matrix_basis = arms.idle_basis[bone.name]
        bpy.context.view_layer.update()
        arms.bones["Hand.L"].matrix = arms.world.inverted() @ hand
        bpy.context.view_layer.update()
        turns = {}
        for chain in FINGER_CHAINS:
            for name in chain:
                arms.bones[name].rotation_quaternion = Quaternion()
            bpy.context.view_layer.update()
            for joint, name in enumerate(chain):
                bone = arms.bones[name]
                axis, angle = arms.left_fingers[name].to_axis_angle()
                settled = Quaternion(axis, angle * CURL_STEPS[0])
                for curl in CURL_STEPS:
                    bone.rotation_quaternion = Quaternion(axis, angle * curl)
                    bpy.context.view_layer.update()
                    if min(gun_distance(to_gun @ point) for point in self._skin_at(chain[joint:])) < SKIN_GAP:
                        break
                    settled = Quaternion(axis, angle * curl)
                bone.rotation_quaternion = settled
                bpy.context.view_layer.update()
                turns[name] = settled
        return turns

    # --- Poses ----------------------------------------------------------------------------------

    def left_anchor(self, name: str, gun: Matrix, open_amount: float) -> Matrix:
        """Where the left hand is in the world for one of left_anchors, with the gun where it is now."""
        if name == "fore_end":
            return gun @ hinge(open_amount) @ self.left_hold
        if name == "off":
            return gun @ hinge(open_amount) @ Matrix.Translation(OFF_FORE_END) @ self.left_hold
        if name == "beside":
            # On the side of the barrels where the hand let go of the shells (the release, in their frame).
            release = (Matrix.Translation(layout.BREECH - Vector((0.0, SHELL_LET_GO + RELEASE, 0.0)))
                       @ self.shells_in_hand().inverted())
            side = 1.0 if release.translation.x >= 0.0 else -1.0
            hold = self.left_hold.copy()
            hold.translation = Vector((side * BESIDE_BARRELS.x, BESIDE_BARRELS.y, BESIDE_BARRELS.z))
            return gun @ hinge(open_amount) @ hold
        if name == "pocket":
            return Matrix.Translation(swings.EYE + camera_axes(*POCKET))
        out = SHELL_LET_GO if name in ("insert", "release") else SHELL_LINE_UP
        pair = chambers(gun, open_amount, out)
        hand = pair @ self.shells_in_hand().inverted()
        if name == "lift":
            hand = Matrix.Translation(camera_axes(*LIFT)) @ hand
        elif name == "release":
            hand = Matrix.Translation(pair.to_3x3() @ Vector((0.0, -RELEASE, 0.0))) @ hand
        return hand

    def pose_at(self, clip: GunClip, time: float):
        """World matrices for the arms, the left fingers, the gun and how far its barrels are open, at
        `time`."""
        key, index, w, s = sample(clip, time)
        gun = gun_matrix(key)
        body = body_matrix(self.arms, key.turn)
        to_body = body.inverted()
        hints = {"R": to_body.to_3x3() @ camera_axes(*key.elbow).normalized(),
                 "L": to_body.to_3x3() @ camera_axes(*key.left_elbow).normalized()}
        # The left hand runs on a smooth path through where each key puts it, the gun being where it is
        # now, and turns from one key's hold to the next. Where a key only passes through, the hand's
        # turn there is its wrist at rest on the forearm, so it never twists on the way.
        anchors = [to_body @ self.left_anchor(other.left, gun, key.open) for other in clip.keys]
        ends = (clip.keys[index].left, clip.keys[index + 1].left)
        if ends[0] == ends[1]:
            place = anchors[index].translation          # staying where it is, on the gun or in the pocket
        elif all(end in ALONG_BARRELS for end in ends):
            place = anchors[index].translation.lerp(anchors[index + 1].translation, w)
        else:
            place = catmull([anchor.translation for anchor in anchors], s)
        swivel = self.previous["L"] if self.previous else 0.0
        lower = self.arms.reach("L", place, hints["L"], swivel)[3]
        data = self.arms.sides["L"]
        at_rest = lower @ (data.forearm.inverted() @ data.hand)
        turns = [at_rest if clip.keys[k].left in PASSING else anchors[k].to_quaternion() for k in (index, index + 1)]
        left = Matrix.Translation(place) @ turns[0].slerp(turns[1], w).to_matrix().to_4x4()
        hands = {"R": to_body @ gun @ self.mount().inverted(), "L": left}
        swivel = {}
        for side in swings.SIDES:
            centre = self.previous[side] if self.previous else 0.0
            options = swivels(SWIVEL_RANGE) if self.previous is None else \
                [centre + step for step in range(-9, 10, 3) if abs(centre + step) <= SWIVEL_RANGE]
            swivel[side] = min(options, key=lambda value: self.arms.strain(
                side, hands[side].translation, hands[side].to_quaternion(), hints[side], value, True)[0]
                + 0.5 * abs(value - centre))
        self.previous = swivel
        matrices = {}
        for side in swings.SIDES:
            matrices.update(self.arms.arm(side, hands[side].translation, hands[side].to_quaternion(), hints[side],
                                          holding=True, swivel=swivel[side]))
        matrices = {name: body @ matrix for name, matrix in matrices.items()}
        matrices["_ROOT_"] = body @ self.arms.root_idle
        # Cradling fingers on the fore-end, a pinch round the shells while it has them, opening as it lets go.
        poses = [self.finger_poses[FINGER_POSE.get(clip.keys[k].left, "pinch")] for k in (index, index + 1)]
        fingers = {name: poses[0][name].slerp(poses[1][name], w) for name in poses[0]}
        return matrices, fingers, gun, key.open


def shells_at(clip: GunClip, time: float):
    """Whether the left hand shows the new shells, and how far out of the chambers the shells in them are
    (None while the chambers are empty), at `time`."""
    in_hand = clip.grab is not None and clip.grab <= time < clip.transfer
    if clip.eject is None or time < clip.eject:
        return in_hand, 0.0
    kick = (time - clip.eject) / 0.08
    if kick < 1.0:
        return in_hand, 0.06 * ease_out(kick)
    if time < clip.transfer:
        return in_hand, None
    return in_hand, SHELL_LET_GO * (1.0 - smooth((time - clip.transfer) / (clip.seated - clip.transfer)))


def sample(clip: GunClip, time: float):
    """The clip's pose at `time` (positions and aim on smooth curves through the keys, the rest eased),
    with the stretch it is in, how far along it, and the curve parameter."""
    keys = clip.keys
    times = [key.time for key in keys]
    index = 0
    while index < len(times) - 2 and time > times[index + 1]:
        index += 1
    local = (time - times[index]) / max(times[index + 1] - times[index], 1e-6)
    s = index + keys[index + 1].ease(local)
    w = s - index

    def blend(name):
        a, b = getattr(keys[index], name), getattr(keys[index + 1], name)
        return a + (b - a) * w

    grip = catmull([Vector(key.grip) for key in keys], s)
    aim = catmull([Vector((*key.aim, 0.0)) for key in keys], s)
    elbow = catmull([Vector(key.elbow) for key in keys], s)
    left_elbow = catmull([Vector(key.left_elbow) for key in keys], s)
    key = GunKey(time, grip=tuple(grip), aim=(aim.x, aim.y), cant=blend("cant"), open=blend("open"),
                 elbow=tuple(elbow), left_elbow=tuple(left_elbow), turn=blend("turn"))
    return key, index, w, s


def gun_matrix(key: GunKey) -> Matrix:
    """The gun in the world: its grip where the key says, the barrels along the aim, canted."""
    forward = aim_direction(*key.aim)
    up = (UP - forward * UP.dot(forward)).normalized()
    up = Quaternion(forward, math.radians(key.cant)) @ up
    right = forward.cross(up)
    return Matrix.Translation(on_screen(*key.grip)) @ Matrix((right, forward, up)).transposed().to_4x4()


def body_matrix(arms: swings.Arms, turn: float) -> Matrix:
    """The upper body turned `turn` degrees to the right round the spine."""
    return Matrix.Translation(arms.spine) @ Matrix.Rotation(math.radians(-turn), 4, UP) @ Matrix.Translation(-arms.spine)


def author(rig: ShotgunRig, clip: GunClip):
    """Keys a clip into its own action, every bone, frame 0 to clip.frames at FPS. Per frame, how far
    the barrels are open goes into the action as "open" (0 closed to 1 broken open), whether the left
    hand shows the new shells as "hand_shells", and how far out of the chambers the shells in them are
    as "chamber_shells" (-1 while the chambers are empty); when its action sounds land as "sounds"."""
    import bpy

    arms = rig.arms
    action = bpy.data.actions.new(clip.name)
    action.use_fake_user = True
    arms.use(action)
    rig.previous = None
    opening, hand_shells, chamber_shells = [], [], []
    for frame in range(clip.frames + 1):
        time = frame / FPS
        matrices, fingers, _gun, open_amount = rig.pose_at(clip, time)
        arms.pose(matrices, fingers)
        in_hand, out = shells_at(clip, time)
        opening.append(open_amount)
        hand_shells.append(1.0 if in_hand else 0.0)
        chamber_shells.append(-1.0 if out is None else out)
        for bone in arms.bones:
            bone.keyframe_insert("location", frame=frame, group=bone.name)
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
            bone.keyframe_insert("scale", frame=frame, group=bone.name)
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, clip.frames
    action["open"] = opening
    action["hand_shells"] = hand_shells
    action["chamber_shells"] = chamber_shells
    action["loop"] = clip.loop
    if clip.shot is not None:
        action["shot"] = clip.shot
    if clip.transfer is not None:
        action["loaded"] = clip.transfer
    if clip.sounds:
        action["sounds"] = clip.sounds
    return action
