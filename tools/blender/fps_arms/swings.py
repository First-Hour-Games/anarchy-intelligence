"""Two-handed pipe swings for the first-person arms (models/player/fpsWhite_holding_idle.glb).

A swing is a few keys in the player's screen space: where the right wrist is (x and y from -1 to 1
across the game's 4:3 picture, and depth in metres from the eye), where the pipe's top end points,
how far the wrist rolls round the pipe, which way the elbows point, and how firmly the left hand holds
the pipe (`grip`, 0 for its resting pose, 1 on the pipe). Between keys the wrist and the pipe tip follow
smooth curves, and each stretch has its own timing: slow into the wind-up, accelerating into the hit,
decelerating through the follow-through, easing back to the idle pose.

Each arm is solved from its shoulder, which never moves: the elbow is a hinge, folding in the plane the
elbow hint gives, with the upper arm and forearm turned so the hinge keeps the axis it has in the idle
pose. A hand turns round the forearm mostly by the forearm rolling, and the wrist only bends within
range. The right hand points the pipe where the key says. The left hand takes the mirror image of the
right hand's grip, across the plane through the pipe and the right wrist, GRIP_GAP further down the
pipe: both forearms come at the pipe from the same side with the palms on opposite sides, the way a
bat is held. Its fingers curl into the right hand's grip, mirrored. The right fingers keep their idle
grip, so the hands look as they always have.

Every swing starts and ends exactly on Holding_Idle's first frame, which the game blends into and out
of; `impact` is when the pipe passes through the hit. tools/blender/build_pipe_swings.py builds the
swings into models/player/pipe_swings.tres for the game, which plays swing_downswing; preview.py
renders them for review.

Axes are Blender's after importing the glTF: the eye is at EYE looking along -Y, screen right is -X,
screen up is +Z (see the camera in pipe_weapon.tscn: the arms sit 25 cm below and 10 cm in front of
the eye, turned to face it).
"""

import math
from dataclasses import dataclass, field

from mathutils import Matrix, Quaternion, Vector

FPS = 40
EYE = Vector((0.0, 0.1, 0.25))
FOV_Y = 74.0
TAN_Y = math.tan(math.radians(FOV_Y / 2.0))
TAN_X = TAN_Y * 4.0 / 3.0
RIGHT = Vector((-1.0, 0.0, 0.0))
UP = Vector((0.0, 0.0, 1.0))
FORWARD = Vector((0.0, -1.0, 0.0))
REACH = 0.97                     # a wrist never goes further than this share of its arm's length
# A hand turns round the forearm's length mostly by the forearm rolling (pronation), up to
# FOREARM_ROLL degrees from the idle pose; the wrist itself bends at most WRIST_BEND and twists at
# most WRIST_TWIST from its idle angle. A turn that would need more is eased back to what the arm can do.
FOREARM_ROLL = 80.0
WRIST_BEND = 55.0
WRIST_TWIST = 20.0
# A hand holding the pipe keeps its angle exactly, so the twist between upper arm and hand is shared
# evenly between the elbow (the forearm bone) and the wrist, measured against the model's rest pose,
# which is what the skin is bound to, with the elbow's share at most HELD_FOREARM_ROLL. With one forearm
# bone, all of it at the elbow twists the skin there thin. (The idle pose already twists the left
# forearm 33 degrees from rest; it barely shows because that arm sits low.)
HELD_FOREARM_ROLL = 45.0
ELBOW_FOLD = 125.0               # past this an elbow pinches; the hold search avoids it
GRIP_GAP = 0.13                  # from the right wrist down the pipe to the left wrist, in metres
SPINE_BACK = 0.15                # the spine, which the upper body turns round, behind the shoulders' middle
HIPS_DOWN = 0.45                 # the hips, which the upper body leans from, below the spine's top
FOREARM_CLEARANCE = 0.09         # the forearms' centre lines stay at least this far apart
SIDES = ("R", "L")
FINGERS = ("Fingers01", "Fingers02", "Fingers03", "Index01", "Index02", "Index03", "Thumb01", "Thumb02", "Thumb03")
IDLE_ACTION = "Holding_Idle"
FLIP = Matrix.Diagonal((-1.0, 1.0, 1.0))


def on_screen(x, y, depth):
    """A point at screen position (x, y), -1 to 1 across the 4:3 picture, `depth` metres ahead."""
    return EYE + FORWARD * depth + RIGHT * (x * depth * TAN_X) + UP * (y * depth * TAN_Y)


def to_screen(point):
    offset = point - EYE
    depth = offset.dot(FORWARD)
    return (offset.dot(RIGHT) / (depth * TAN_X), offset.dot(UP) / (depth * TAN_Y), depth)


def camera_axes(right, up, forward):
    return RIGHT * right + UP * up + FORWARD * forward


# --- Timing -----------------------------------------------------------------------------------------

def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def ease_in(x):
    x = min(max(x, 0.0), 1.0)
    return x * x


def ease_out(x):
    x = min(max(x, 0.0), 1.0)
    return 1.0 - (1.0 - x) * (1.0 - x)


def linear(x):
    """For keys a fast move passes straight through without slowing."""
    return min(max(x, 0.0), 1.0)


@dataclass
class Key:
    time: float
    wrist: tuple = None              # right wrist: screen x, y and depth; None: the idle pose's
    tip: tuple = None                # where the pipe's top end points, the same way
    aim: tuple = None                # or the pipe's direction round the player: (yaw, pitch) in degrees,
                                     # yaw 0 straight ahead, +90 to the right; pitch up from level
    roll: float = 0.0                # degrees the right wrist turns round the pipe, from the idle grip
    elbow: tuple = None              # right elbow hint in camera axes (right, up, forward); None: idle
    left_elbow: tuple = None         # the same for the left elbow
    grip: float = 0.0                # 0: left hand resting, 1: left hand on the pipe
    turn: float = 0.0                # degrees the upper body has turned to the right round the spine; the
                                     # wrist, aim and elbows above are as if it faced straight ahead
    lean: float = 0.0                # degrees the upper body leans forward from the hips
    ease: object = smooth            # timing of the stretch that arrives at this key


@dataclass
class Swing:
    name: str
    title: str
    duration: float
    impact: float
    keys: list = field(default_factory=list)
    swivel_range: float = 60.0       # how far either elbow may turn from where the keys put it, degrees
    grip_slide: float = 24.0         # how far the left hand may move round the pipe per frame; 0 holds it
    wrist_limit: float = None        # furthest the right wrist bends past its idle grip, degrees; the pipe
                                     # gives a little instead. None: the pipe goes exactly where the keys say
    plane_tilt: float = 0.0          # the body turns round an axis leaning this far to the left, so the swing
                                     # runs from high on the right to low on the left
    grip_drop: float = 0.0           # metres both hands slide down the pipe while it is held in two hands
    grip_gap: float = 0.13           # from the right wrist down the pipe to the left wrist, metres
    slides: list = None              # authoring result: how far the pipe has slid up through the hands, per frame
    round_pipe: tuple = None         # authoring state: the left hand's last side of the pipe and swivel
    fixed_round: float = None        # authoring state: the one side of the pipe the left hand keeps
    trace: list = None               # authoring state: the right arm and left hint per frame, first pass
    right_hold: tuple = None         # authoring state: the right hand's last turn round the pipe and swivel
    pipe_error: float = 0.0          # authoring result: furthest the pipe fell short of its keys, degrees
    eye_gap: float = math.inf        # authoring result: closest the pipe comes to the eye, metres

    @property
    def frames(self):
        return round(self.duration * FPS)


def catmull(points, s):
    """A point on a Catmull-Rom curve through `points` (Vectors), s from 0 to len(points) - 1."""
    count = len(points)
    index = min(int(s), count - 2)
    t = s - index
    p0 = points[max(index - 1, 0)]
    p1, p2 = points[index], points[index + 1]
    p3 = points[min(index + 2, count - 1)]
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
                  + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


# --- The rig ----------------------------------------------------------------------------------------

@dataclass
class Side:
    """One arm's idle pose: the reference its swings are solved from."""
    shoulder: Vector
    upper: float
    lower: float
    hinge_upper: Vector
    hinge_lower: Vector
    hint: Vector
    wrist: Vector
    hand: Quaternion
    forearm: Quaternion


class Arms:
    def __init__(self, armature):
        import bpy

        self.object = armature
        self.bones = armature.pose.bones
        self.world = armature.matrix_world.copy()
        ad = armature.animation_data
        for track in list(ad.nla_tracks):
            ad.nla_tracks.remove(track)
        self.use(bpy.data.actions[IDLE_ACTION])
        bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()
        self.idle_basis = {bone.name: bone.matrix_basis.copy() for bone in self.bones}
        self.idle_upper = {"UpperArm." + side: self.bones["UpperArm." + side].matrix.copy() for side in SIDES}
        self.idle_upper_world = {side: (self.world @ self.idle_upper["UpperArm." + side]).to_quaternion()
                                 for side in SIDES}
        self.rest = {bone.name: bone.matrix_local.to_quaternion() for bone in armature.data.bones}
        self.root_idle = self.world @ self.bones["_ROOT_"].matrix
        self.sides = {side: self._side(side) for side in SIDES}
        self.spine = (self.sides["R"].shoulder + self.sides["L"].shoulder) / 2.0 - FORWARD * SPINE_BACK
        self.hips = self.spine - UP * HIPS_DOWN
        # The left fingers' grip: the right hand's idle finger pose, mirrored.
        self.left_fingers = {}
        for finger in FINGERS:
            turn = self.idle_basis[finger + ".R"].to_quaternion()
            self.left_fingers[finger + ".L"] = Quaternion((turn.w, turn.x, -turn.y, -turn.z))
        # The pipe's length axis (toward its top end) and a point on it, in the right hand's frame.
        pipe = bpy.data.objects["MetalPipe_Hand_R"]
        hand = self.world @ self.bones["Hand.R"].matrix
        points = [hand.inverted() @ (pipe.matrix_world @ vertex.co) for vertex in pipe.data.vertices]
        middle = sum(points, Vector()) / len(points)
        spread = Matrix(((0, 0, 0), (0, 0, 0), (0, 0, 0)))
        for point in points:
            offset = point - middle
            for i in range(3):
                for j in range(3):
                    spread[i][j] += offset[i] * offset[j]
        axis = principal_axis(spread)
        if (hand.to_3x3() @ axis).z < 0.0:
            axis = -axis
        self.pipe_axis, self.pipe_middle = axis, middle
        along = [(point - middle).dot(axis) for point in points]
        self.pipe_ends = (min(along), max(along))      # bottom and top end, along the axis from the middle
        self.idle_pipe = (hand.to_3x3() @ axis).normalized()
        self.idle_tip = self.sides["R"].wrist + self.idle_pipe * 0.4

    def _side(self, side):
        world = {name: self.world @ self.bones[name + "." + side].matrix for name in ("UpperArm", "LowerArm", "Hand")}
        shoulder = world["UpperArm"].translation.copy()
        elbow = world["LowerArm"].translation.copy()
        wrist = world["Hand"].translation.copy()
        hinge = (elbow - shoulder).cross(wrist - elbow).normalized()
        line = (wrist - shoulder).normalized()
        hint = ((elbow - shoulder) - line * (elbow - shoulder).dot(line)).normalized()
        return Side(shoulder, (elbow - shoulder).length, (wrist - elbow).length,
                    world["UpperArm"].to_3x3().inverted() @ hinge, world["LowerArm"].to_3x3().inverted() @ hinge,
                    hint, wrist, world["Hand"].to_quaternion(), world["LowerArm"].to_quaternion())

    def use(self, action):
        ad = self.object.animation_data
        ad.action = action
        if len(action.slots):
            ad.action_slot = action.slots[0]

    def reach(self, side, wrist, hint, swivel=0.0):
        """The elbow, the wrist actually reached and the upper arm's and forearm's world rotations for a
        wrist position and an elbow hint (None: the idle one), the elbow turned `swivel` degrees round
        the line from shoulder to wrist."""
        data = self.sides[side]
        to_wrist = wrist - data.shoulder
        distance = min(max(to_wrist.length, abs(data.upper - data.lower) + 0.02), (data.upper + data.lower) * REACH)
        line = to_wrist.normalized()
        reached = data.shoulder + line * distance
        along = (data.upper ** 2 - data.lower ** 2 + distance ** 2) / (2.0 * distance)
        out = math.sqrt(max(data.upper ** 2 - along ** 2, 0.0))
        hint = hint if hint is not None else data.hint
        offside = hint - line * hint.dot(line)
        offside = offside.normalized() if offside.length > 1e-4 else data.hint
        offside = Quaternion(line, math.radians(swivel)) @ offside
        elbow = data.shoulder + line * along + offside * out
        upper_axis = (elbow - data.shoulder).normalized()
        lower_axis = (reached - elbow).normalized()
        hinge = upper_axis.cross(lower_axis).normalized()
        upper = frame_turn(Vector((0, 1, 0)), data.hinge_upper, upper_axis, hinge)
        lower = frame_turn(Vector((0, 1, 0)), data.hinge_lower, lower_axis, hinge)
        return elbow, reached, upper, lower

    def arm(self, side, wrist, hand, hint, holding=False, swivel=0.0, amount=1.0, bend_limit=None):
        """World matrices of one arm's upper arm, forearm and hand for a wrist position, a wanted hand
        rotation, an elbow hint and swivel. A hand `holding` something keeps its rotation exactly,
        sharing the roll between elbow and wrist (`amount` of that sharing, 0 at the idle pose)."""
        data = self.sides[side]
        elbow, wrist, upper, lower = self.reach(side, wrist, hint, swivel)
        if holding:
            lower = lower @ Quaternion((0.0, 1.0, 0.0), math.radians(amount * self.held_roll(side, upper, lower, hand)))
        if bend_limit is not None:
            # Ease the wrist's bend (not its twist) back to the limit; the hand, and what it holds, follow.
            idle_on_forearm = data.forearm.inverted() @ data.hand
            change = lower.inverted() @ hand @ idle_on_forearm.inverted()
            twist = Quaternion((change.w, 0.0, change.y, 0.0))
            twist = twist.normalized() if twist.magnitude > 1e-6 else Quaternion()
            bend = change @ twist.inverted()
            if bend.angle > math.radians(bend_limit):
                bend = Quaternion().slerp(bend, math.radians(bend_limit) / bend.angle)
                hand = lower @ bend @ twist @ idle_on_forearm
        return {
            "UpperArm." + side: Matrix.Translation(data.shoulder) @ upper.to_matrix().to_4x4(),
            "LowerArm." + side: Matrix.Translation(elbow) @ lower.to_matrix().to_4x4(),
            "Hand." + side: Matrix.Translation(wrist) @ hand.to_matrix().to_4x4(),
        }

    def rest_twist(self, child, parent, parent_turn, child_turn):
        """Degrees a bone is twisted round its length against its parent, compared with the rest pose."""
        basis = self.rest[child].inverted() @ self.rest[parent] @ parent_turn.inverted() @ child_turn
        twist = Quaternion((basis.w, 0.0, basis.y, 0.0))
        return signed_angle(twist.normalized()) if twist.magnitude > 1e-6 else 0.0

    def held_roll(self, side, upper, forearm, hand):
        """How far to roll the forearm so the elbow and the wrist share the arm's twist evenly, the
        elbow's share kept within HELD_FOREARM_ROLL of the rest pose."""
        elbow = self.rest_twist("LowerArm." + side, "UpperArm." + side, upper, forearm)
        wrist = self.rest_twist("Hand." + side, "LowerArm." + side, forearm, hand)
        target = max(-HELD_FOREARM_ROLL, min(HELD_FOREARM_ROLL, (elbow + wrist) / 2.0))
        return target - elbow

    def strain(self, side, wrist, hand, hint, swivel, holding=True):
        """How unnatural a hold looks: the wrist's bend, the twist left at the elbow and at the wrist,
        the elbow's fold, the upper arm's twist from idle, and any reach the arm falls short of.
        Returns (cost, wrist bend)."""
        data = self.sides[side]
        elbow, reached, upper, lower = self.reach(side, wrist, hint, swivel)
        rolled = lower @ Quaternion((0.0, 1.0, 0.0), math.radians(self.held_roll(side, upper, lower, hand)))
        elbow_twist = abs(self.rest_twist("LowerArm." + side, "UpperArm." + side, upper, rolled))
        wrist_twist = abs(self.rest_twist("Hand." + side, "LowerArm." + side, rolled, hand))
        change = rolled.inverted() @ hand @ (data.forearm.inverted() @ data.hand).inverted()
        twist = Quaternion((change.w, 0.0, change.y, 0.0))
        twist = twist.normalized() if twist.magnitude > 1e-6 else Quaternion()
        bend = math.degrees((change @ twist.inverted()).angle)
        fold = math.degrees((elbow - data.shoulder).angle(reached - elbow))
        cost = bend + 0.6 * elbow_twist + 0.6 * wrist_twist + 3.0 * max(0.0, bend - WRIST_BEND)
        cost += 0.5 * max(0.0, self.upper_twist(side, upper) - 35.0) + 3.0 * max(0.0, fold - ELBOW_FOLD)
        cost += 400.0 * (reached - wrist).length + 0.08 * abs(swivel)
        return cost, bend

    def upper_twist(self, side, upper):
        """Degrees the upper arm has turned round its own length from the idle pose."""
        turn = self.idle_upper_world[side].rotation_difference(upper)
        axis = upper @ Vector((0.0, 1.0, 0.0))
        twist = abs(math.degrees(2.0 * math.atan2(Vector(turn[1:]).dot(axis), turn.w)))
        return min(twist, 360.0 - twist)

    def hold_right(self, wrist, pipe, roll, hint, previous, swivel_range=60.0):
        """How the right hand holds the pipe pointing along `pipe`: the turn round the pipe (from the
        key's `roll`) and the elbow swivel that look most natural, close to the last frame's."""
        if previous is None:
            options = [(r, w) for r in range(-40, 41, 8) for w in swivels(swivel_range)]
        else:
            options = [(previous[0] + r, previous[1] + w) for r in range(-8, 9, 2) for w in range(-12, 13, 3)
                       if abs(previous[1] + w) <= swivel_range]
        best = None
        for extra, swivel in options:
            hand = Quaternion(pipe, math.radians(roll + extra)) @ self.idle_pipe.rotation_difference(pipe) @ self.sides["R"].hand
            cost = self.strain("R", wrist, hand, hint, swivel, True)[0] + 0.15 * abs(extra)
            if previous is not None:
                cost += 0.6 * (abs(extra - previous[0]) + abs(swivel - previous[1]))
            if best is None or cost < best[0]:
                best = (cost, (extra, swivel))
        return best[1]

    def left_on_pipe(self, right_hand, round_pipe=0.0, gap=GRIP_GAP):
        """Where the left hand grips the pipe, from the right hand's world matrix: the mirror of the
        right hand across the plane through the pipe and the right wrist, GRIP_GAP down the pipe, then
        turned `round_pipe` degrees round it (a hand grips a pipe from any side)."""
        axis = (right_hand.to_3x3() @ self.pipe_axis).normalized()
        middle = right_hand @ self.pipe_middle
        wrist = right_hand.translation
        on_line = middle + axis * (wrist - middle).dot(axis)
        normal = axis.cross(wrist - on_line)
        normal = normal.normalized() if normal.length > 1e-5 else axis.orthogonal().normalized()
        mirror = Matrix.Identity(3) - 2.0 * Matrix(((normal.x * normal.x, normal.x * normal.y, normal.x * normal.z),
                                                   (normal.y * normal.x, normal.y * normal.y, normal.y * normal.z),
                                                   (normal.z * normal.x, normal.z * normal.y, normal.z * normal.z)))
        turn = (mirror @ right_hand.to_3x3() @ FLIP).to_quaternion()
        around = Quaternion(axis, math.radians(round_pipe))
        return on_line + around @ (wrist - on_line) - axis * gap, around @ turn

    def left_grip(self, right, left_hint, previous, swivel_range=60.0, slide=24.0, fixed=None, gap=GRIP_GAP):
        """The side of the pipe the left hand takes and its elbow swivel: the most natural hold that
        keeps the left forearm clear of the right one, close to the last frame's so it never jumps."""
        right_elbow = right["LowerArm.R"].translation
        right_wrist = right["Hand.R"].translation
        if fixed is not None:
            centre = previous[1] if previous is not None else 0.0
            options = [(fixed, w) for w in swivels(swivel_range) if previous is None or abs(w - centre) <= 12]
        elif previous is None:
            options = [(r, w) for r in range(-180, 180, 10) for w in swivels(swivel_range)]
        else:
            turns = range(-int(slide), int(slide) + 1, 3) if slide > 0 else (0,)
            options = [(previous[0] + r, previous[1] + w) for r in turns for w in range(-12, 13, 3)
                       if abs(previous[1] + w) <= swivel_range]
        best = None
        for round_pipe, swivel in options:
            wrist, turn = self.left_on_pipe(right["Hand.R"], round_pipe, gap)
            cost = self.strain("L", wrist, turn, left_hint, swivel, True)[0]
            elbow, reached, upper, lower = self.reach("L", wrist, left_hint, swivel)
            cost += 600.0 * max(0.0, FOREARM_CLEARANCE - segment_gap(elbow, reached, right_elbow, right_wrist))
            if previous is not None:
                cost += 0.5 * abs(round_pipe - previous[0]) + 0.6 * abs(swivel - previous[1])
            if best is None or cost < best[0]:
                best = (cost, (round_pipe, swivel))
        return best[1]

    def best_fixed_grip(self, trace, swivel_range, gap=GRIP_GAP):
        """The side of the pipe that keeps the left arm most natural over a whole swing: for each side,
        the sum over the two-handed frames of the best hold's strain."""
        best = None
        for round_pipe in range(-180, 180, 10):
            total = 0.0
            for right, left_hint, grip in trace:
                if grip < 0.5:
                    continue
                wrist, turn = self.left_on_pipe(right["Hand.R"], round_pipe, gap)
                total += min(self.strain("L", wrist, turn, left_hint, swivel, True)[0]
                             for swivel in swivels(swivel_range))
            if best is None or total < best[0]:
                best = (total, round_pipe)
        return best[1]

    def pose(self, matrices, finger_turns):
        """Idle pose everywhere, the left fingers as given, then the solved arms."""
        import bpy

        for bone in self.bones:
            bone.matrix_basis = self.idle_basis[bone.name]
        for name, turn in finger_turns.items():
            self.bones[name].rotation_quaternion = turn
        bpy.context.view_layer.update()
        inverse = self.world.inverted()
        if "_ROOT_" in matrices:
            self.bones["_ROOT_"].matrix = inverse @ matrices["_ROOT_"]
            bpy.context.view_layer.update()
        for side in SIDES:
            for part in ("UpperArm", "LowerArm", "Hand"):
                name = part + "." + side
                if name in matrices:
                    self.bones[name].matrix = inverse @ matrices[name]
                    bpy.context.view_layer.update()


def swivels(limit):
    """Elbow swivels to try, every 10 degrees within the limit, and the limit itself."""
    values = set(range(-int(limit), int(limit) + 1, 10)) | {-int(limit), int(limit)}
    return sorted(values)


def aim_direction(yaw, pitch):
    """A direction round the player: yaw degrees to the right of straight ahead, pitch degrees up."""
    yaw, pitch = math.radians(yaw), math.radians(pitch)
    return (FORWARD * math.cos(yaw) + RIGHT * math.sin(yaw)) * math.cos(pitch) + UP * math.sin(pitch)


def aim_angles(direction):
    """(yaw, pitch) in degrees of a direction."""
    direction = direction.normalized()
    return (math.degrees(math.atan2(direction.dot(RIGHT), direction.dot(FORWARD))),
            math.degrees(math.asin(max(-1.0, min(1.0, direction.dot(UP))))))


def segment_gap(a0, a1, b0, b1):
    """The closest distance between segments a0-a1 and b0-b1, sampled along the first."""
    best = math.inf
    span = b1 - b0
    for i in range(9):
        point = a0.lerp(a1, i / 8.0)
        t = min(max((point - b0).dot(span) / max(span.length_squared, 1e-9), 0.0), 1.0)
        best = min(best, (point - (b0 + span * t)).length)
    return best


def signed_angle(twist):
    """A rotation about local Y as signed degrees, -180 to 180."""
    angle = math.degrees(2.0 * math.atan2(twist.y, twist.w))
    return (angle + 180.0) % 360.0 - 180.0


def principal_axis(spread):
    vector = Vector((0.3, 1.0, 0.2)).normalized()
    for _ in range(60):
        vector = (spread @ vector).normalized()
    return vector


def frame_turn(axis_local, hinge_local, axis_world, hinge_world):
    """The rotation taking a bone's local length axis and hinge axis onto world ones."""
    hinge_local = (hinge_local - axis_local * hinge_local.dot(axis_local)).normalized()
    hinge_world = (hinge_world - axis_world * hinge_world.dot(axis_world)).normalized()
    local = Matrix((axis_local, hinge_local, axis_local.cross(hinge_local))).transposed()
    world = Matrix((axis_world, hinge_world, axis_world.cross(hinge_world))).transposed()
    return (world @ local.inverted()).to_quaternion()


# --- Swings -----------------------------------------------------------------------------------------

SWINGS = [
    # A two-handed overhead chop. The left hand takes the pipe low and both hands slide down to its end;
    # the pipe goes up and back over the right shoulder with the hands up at the right of the view, the
    # body leaning back a little; then the body leans into the chop, which comes down across the middle
    # and finishes low on the left.
    Swing("swing_downswing", "Two-handed downswing", 0.75, 0.37, [
        Key(0.0),
        Key(0.12, wrist=(0.25, -0.70, 0.50), aim=(10.0, 62.0), elbow=(0.8, -0.6, 0.0),
            left_elbow=(-0.5, -0.9, 0.0), grip=1.0),
        # The lift: up and back over the right shoulder, the body leaning back and turning right.
        Key(0.27, wrist=(0.42, 0.02, 0.42), aim=(40.0, 72.0), elbow=(0.85, -0.3, 0.0),
            left_elbow=(0.0, -1.0, -0.3), grip=1.0, turn=5.0, lean=-5.0),
        # The chop: down across the middle, the body turning left and leaning in.
        Key(0.37, wrist=(0.0, -0.45, 0.60), aim=(-20.0, 0.0), elbow=(0.7, -0.6, 0.2),
            left_elbow=(-0.7, -0.6, 0.2), grip=1.0, turn=-10.0, lean=12.0, ease=ease_in),
        Key(0.46, wrist=(-0.05, -0.78, 0.62), aim=(-30.0, -22.0), elbow=(0.7, -0.7, 0.1),
            left_elbow=(-0.7, -0.7, 0.1), grip=1.0, turn=-20.0, lean=15.0, ease=ease_out),
        # Back up on the right; the left hand lets go.
        Key(0.60, wrist=(0.32, -0.90, 0.52), aim=(30.0, 50.0), elbow=(0.8, -0.6, 0.0), grip=0.0, turn=0.0, lean=4.0),
        Key(0.75),
    ], swivel_range=20.0, grip_slide=0.0, wrist_limit=40.0, grip_drop=0.22, grip_gap=0.10),
    # A two-handed bat swing on a plane leaning 20 degrees, from high on the right to low on the left. The
    # hands slide down to the end of the pipe; at the load they stay low at the right of the view and the
    # wrists cock the pipe back over the right shoulder; the body turns while the hands drive forward and
    # the pipe lags behind; the wrists release it through the hit at full speed; the arms extend and the
    # body keeps turning out to the left; and the pipe rises to finish.
    Swing("swing_bat", "Bat swing", 0.86, 0.39, [
        Key(0.0),
        Key(0.12, wrist=(0.28, -0.72, 0.50), aim=(10.0, 60.0), elbow=(0.8, -0.6, 0.0),
            left_elbow=(-0.5, -0.9, 0.0), grip=1.0),
        # Load: turned a little right, hands low at the right, the pipe cocked back over the shoulder.
        Key(0.28, wrist=(0.30, -0.80, 0.46), aim=(40.0, 55.0), elbow=(0.25, -1.0, 0.05),
            left_elbow=(-0.3, -1.0, -0.1), grip=1.0, turn=25.0),
        # Drive: the hands lead, the pipe lagging behind them.
        Key(0.34, wrist=(0.20, -0.78, 0.50), aim=(60.0, 35.0), elbow=(0.35, -0.95, 0.05),
            left_elbow=(-0.5, -0.85, 0.0), grip=1.0, turn=12.0, ease=ease_in),
        # Release: the wrists whip the pipe round through the hit, the arms out in front.
        Key(0.39, wrist=(0.05, -0.72, 0.60), aim=(-30.0, 8.0), elbow=(0.85, -0.45, 0.0),
            left_elbow=(-0.6, -0.8, 0.0), grip=1.0, turn=-5.0, lean=4.0, ease=linear),
        Key(0.45, wrist=(-0.05, -0.75, 0.60), aim=(-60.0, 0.0), elbow=(0.85, -0.45, 0.0),
            left_elbow=(-0.6, -0.8, 0.0), grip=1.0, turn=-35.0, lean=6.0, ease=linear),
        # Finish: still turning, the pipe rising.
        Key(0.55, wrist=(-0.05, -0.65, 0.48), aim=(-60.0, 40.0), elbow=(0.85, -0.45, 0.0),
            left_elbow=(-0.6, -0.8, 0.0), grip=1.0, turn=-55.0, ease=ease_out),
        Key(0.70, wrist=(0.15, -0.85, 0.50), aim=(15.0, 55.0), elbow=(0.7, -0.7, 0.0), grip=0.0, turn=-10.0),
        Key(0.86),
    ], swivel_range=20.0, grip_slide=0.0, wrist_limit=45.0, plane_tilt=20.0, grip_drop=0.22, grip_gap=0.10),
]


def frame_pose(arms, swing, time):
    """The solved arm matrices and left finger rotations for a swing at `time` seconds."""
    right = arms.sides["R"]
    keys = swing.keys
    wrists = [on_screen(*key.wrist) if key.wrist else right.wrist for key in keys]
    tips = [on_screen(*key.tip) if key.tip else arms.idle_tip for key in keys]
    hints = [camera_axes(*key.elbow).normalized() if key.elbow else right.hint for key in keys]
    left_hints = [camera_axes(*key.left_elbow).normalized() if key.left_elbow else arms.sides["L"].hint for key in keys]
    times = [key.time for key in keys]
    index = 0
    while index < len(times) - 2 and time > times[index + 1]:
        index += 1
    local = (time - times[index]) / max(times[index + 1] - times[index], 1e-6)
    s = index + keys[index + 1].ease(local)
    w = s - index
    wrist = catmull(wrists, s)
    roll = keys[index].roll + (keys[index + 1].roll - keys[index].roll) * w
    if any(key.aim for key in keys):
        # Steer the pipe round the player by angle, so it sweeps a true arc; yaw is unwrapped so it
        # turns the way the keys go round.
        angles = []
        for key, key_wrist, key_tip in zip(keys, wrists, tips):
            yaw, pitch = key.aim if key.aim else aim_angles(key_tip - key_wrist if key.tip else arms.idle_pipe)
            if angles:
                while yaw - angles[-1].x > 180.0:
                    yaw -= 360.0
                while yaw - angles[-1].x < -180.0:
                    yaw += 360.0
            angles.append(Vector((yaw, pitch, 0.0)))
        angle = catmull(angles, s)
        pipe = aim_direction(angle.x, angle.y)
    else:
        pipe = (catmull(tips, s) - wrist).normalized()
    hint = catmull(hints, s)
    # The hold search fades in over the first stretch and out over the last, so the swing starts and
    # ends exactly on the idle pose the game blends from and back to.
    weight = smooth((time - times[0]) / (times[1] - times[0])) * smooth((times[-1] - time) / (times[-1] - times[-2]))
    swing.right_hold = arms.hold_right(wrist, pipe, roll, hint, swing.right_hold, swing.swivel_range)
    extra, swivel = (value * weight for value in swing.right_hold)
    turn = Quaternion(pipe, math.radians(roll + extra)) @ arms.idle_pipe.rotation_difference(pipe) @ right.hand
    limit = None if swing.wrist_limit is None else swing.wrist_limit + (1.0 - weight) * 180.0
    matrices = arms.arm("R", wrist, turn, hint, holding=True, swivel=swivel, amount=weight, bend_limit=limit)
    achieved = (matrices["Hand.R"].to_3x3() @ arms.pipe_axis).normalized()
    swing.pipe_error = max(swing.pipe_error, math.degrees(achieved.angle(pipe)))
    grip = keys[index].grip + (keys[index + 1].grip - keys[index].grip) * smooth(w)
    fingers = {}
    if grip > 0.0:
        left = arms.sides["L"]
        left_hint = catmull(left_hints, s)
        if swing.trace is not None:
            swing.trace.append(({name: matrix.copy() for name, matrix in matrices.items()}, left_hint, grip))
        swing.round_pipe = arms.left_grip(matrices, left_hint, swing.round_pipe, swing.swivel_range, swing.grip_slide,
                                          swing.fixed_round, swing.grip_gap)
        round_pipe, left_swivel = swing.round_pipe
        grip_wrist, grip_turn = arms.left_on_pipe(matrices["Hand.R"], round_pipe, swing.grip_gap)
        left_wrist = left.wrist.lerp(grip_wrist, grip)
        left_turn = left.hand.slerp(grip_turn, grip)
        matrices.update(arms.arm("L", left_wrist, left_turn, left_hint, holding=True, swivel=left_swivel * grip,
                                 amount=grip))
        # The fingers close round the pipe as the hand arrives.
        closing = smooth((grip - 0.4) / 0.6)
        for name, turn in arms.left_fingers.items():
            fingers[name] = arms.idle_basis[name].to_quaternion().slerp(turn, closing)
    # The upper body turns round the spine (its axis leaning left by plane_tilt) and leans from the hips,
    # carrying both arms and the pipe together.
    body_pose = catmull([Vector((key.turn, key.lean, 0.0)) for key in keys], s)
    tilt = math.radians(swing.plane_tilt)
    axis = UP * math.cos(tilt) - RIGHT * math.sin(tilt)
    body = Matrix.Translation(arms.spine) @ Matrix.Rotation(math.radians(-body_pose.x), 4, axis) @ Matrix.Translation(-arms.spine)
    lean_axis = UP.cross(FORWARD)
    body = (Matrix.Translation(arms.hips) @ Matrix.Rotation(math.radians(body_pose.y), 4, lean_axis)
            @ Matrix.Translation(-arms.hips) @ body)
    slide = swing.grip_drop * smooth(grip)
    if swing.slides is not None:
        swing.slides.append(slide)
    matrices = {name: body @ matrix for name, matrix in matrices.items()}
    matrices["_ROOT_"] = body @ arms.root_idle
    if "Hand.R" in matrices:
        # How close the pipe comes to the eye: the camera sits inside the player's head.
        hand = matrices["Hand.R"]
        axis = (hand.to_3x3() @ arms.pipe_axis).normalized()
        middle = hand @ arms.pipe_middle + axis * slide
        bottom, top = arms.pipe_ends
        swing.eye_gap = min(swing.eye_gap, segment_gap(EYE, EYE, middle + axis * bottom, middle + axis * top))
    return matrices, fingers


def author(arms, swing):
    """Keys a swing into its own action: every bone, frame 0 to swing.frames, at FPS."""
    import bpy

    action = bpy.data.actions.new(swing.name)
    action.use_fake_user = True
    arms.use(action)
    swing.fixed_round = None
    if swing.grip_slide <= 0.0:
        # First pass: where the right hand goes, then the one left grip that suits it all.
        swing.round_pipe = swing.right_hold = None
        swing.slides = None
        swing.trace = []
        for frame in range(swing.frames + 1):
            frame_pose(arms, swing, frame / FPS)
        swing.fixed_round = arms.best_fixed_grip(swing.trace, swing.swivel_range, swing.grip_gap)
        swing.trace = None
    swing.round_pipe = swing.right_hold = None
    swing.pipe_error = 0.0
    swing.eye_gap = math.inf
    swing.slides = []
    for frame in range(swing.frames + 1):
        arms.pose(*frame_pose(arms, swing, frame / FPS))
        for bone in arms.bones:
            bone.keyframe_insert("location", frame=frame, group=bone.name)
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
            bone.keyframe_insert("scale", frame=frame, group=bone.name)
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, swing.frames
    action["pipe_error"] = swing.pipe_error
    action["eye_gap"] = swing.eye_gap
    action["slide"] = swing.slides
    swing.slides = None
    return action


def retime_original(arms, duration=0.55):
    """The team's Pipe_Swing, resampled onto this timeline the way the game used to play it (stretched
    to 0.55 s), for side-by-side review."""
    import bpy

    source = bpy.data.actions["Pipe_Swing"]
    start, end = source.frame_range
    frames = round(duration * FPS)
    action = bpy.data.actions.new("swing_original")
    action.use_fake_user = True
    poses = []
    arms.use(source)
    for frame in range(frames + 1):
        at = start + (end - start) * frame / frames
        bpy.context.scene.frame_set(int(at), subframe=at % 1.0)
        poses.append({bone.name: bone.matrix_basis.copy() for bone in arms.bones})
    arms.use(action)
    for frame, pose in enumerate(poses):
        for bone in arms.bones:
            bone.matrix_basis = pose[bone.name]
            bone.keyframe_insert("location", frame=frame, group=bone.name)
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
            bone.keyframe_insert("scale", frame=frame, group=bone.name)
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, frames
    return action
