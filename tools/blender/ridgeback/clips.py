"""The Ridgeback's clips, authored on the creator's control rig (see rig.py for axes and units).

A pose is a dict of a few dozen numbers (POSE_KEYS): where the hips are and how the trunk, neck and
head bend, then where each hand reaches, which way the elbows and knees point, and where each foot
stands. apply() turns a pose into the rig's controls; the rig's IK fills in the limbs.

A hand is placed from its shoulder in the body's level frame (forward along the chest's heading,
straight up, and out to that hand's own side), or, as `reach` goes to 1, at an absolute point
`grip` on the floor's axes, which is how the four-legged clips plant their hands. `plant` turns a
hand flat onto the ground; otherwise the hand carries on from the forearm, curled toward the palm
by `claw`. Feet are placed on the floor's axes and keep their pitch to the floor, whatever the shin
is doing.

Loops are functions of the cycle's phase u (0 to 1), built from whole-cycle waves so the last frame
meets the first. One-shots are key poses on a timeline, eased into each other, with per-channel
delays for overlap and a tremor for the moments the creature holds still. A free hand then follows
its pose through a damped spring, so the arms drag behind the body and overshoot where they stop.

The AI's timings set the one-shot lengths (scenes/monsters/corrupted_friend/corrupted_friend.gd):
windup 0.7 s, recovery after a strike 1.2 s, and the Ridgeback's activation_seconds for the
chase-start scream.
"""

import math
from dataclasses import dataclass
from typing import Callable, Optional

from mathutils import Quaternion, Vector

from rig import SIDES, UP, Rig, aim, capped, limited, rotation

FPS = 24
TAU = math.tau
REST_FOOT = {"l": (0.096, 0.068, 0.085), "r": (-0.096, 0.068, 0.085)}
ANKLE = 0.085
WRIST_FLOOR = 0.08          # a flat hand's wrist sits this high off the ground
SPLAY = 10.0                # planted fingers turn this far out from the forearm's line
# How far each trunk bone may turn from its parent, in degrees, and each wrist and ankle may twist
# about its length and swing (tools/blender/ridgeback/anatomy.py checks the same ranges).
TRUNK_LIMITS = {"spine_01": 35.0, "spine_02": 35.0, "chest": 35.0, "neck": 55.0, "head": 50.0}
WRIST = (35.0, 75.0)
ANKLE_RANGE = (20.0, 65.0)
SHOULDER_TWIST = 65.0       # furthest an elbow turns from where it folds with no twist at the shoulder
HIP_TWIST = 30.0            # and a knee at the hip
REACH = 0.95                # a hand or foot never goes further than this share of its limb's length
TIP_FLOOR = {"hand": 0.09, "toe": 0.06}   # fingertips and toes stop this far above the floor

STAND = {
    "hip": (0.0, 0.0, 0.0),            # torso head, from its rest (0, 0.099, 1.009)
    "trunk": (0.0, 0.0, 0.0),          # whole body at the hips: bend, turn, tilt
    "pelvis": (0.0, 0.0, 0.0),
    "spine1": (0.0, 0.0, 0.0),
    "spine2": (0.0, 0.0, 0.0),
    "chest": (0.0, 0.0, 0.0),
    "neck": (0.0, 0.0, 0.0),
    "head": (0.0, 0.0, 0.0),
    "trophy": (0.0, 0.0, 0.0),
    "clav_l": (0.0, 0.0),              # protract (shoulder forward), raise
    "clav_r": (0.0, 0.0),
    "hand_l": (0.06, -0.6, 0.14),      # wrist from the shoulder: forward, up, out
    "hand_r": (0.06, -0.6, 0.14),
    "grip_l": (0.4, -0.75, WRIST_FLOOR),   # wrist on the floor's axes, used as reach goes to 1
    "grip_r": (-0.4, -0.75, WRIST_FLOOR),
    "reach_l": 0.0,
    "reach_r": 0.0,
    "plant_l": 0.0,                    # 1: hand flat on the ground
    "plant_r": 0.0,
    "elbow_l": 15.0,                   # degrees the elbow turns out from its natural bend
    "elbow_r": 15.0,
    "claw_l": 12.0,                    # wrist curl toward the palm, from the forearm's line
    "claw_r": 12.0,
    "foot_l": REST_FOOT["l"],          # ankle target, on the floor
    "foot_r": REST_FOOT["r"],
    "sole_l": (0.0, 0.0),              # foot pitch to the floor (toe down), turn
    "sole_r": (0.0, 0.0),
    "toe_l": 0.0,                      # toe bend from the foot (curl down)
    "toe_r": 0.0,
    "knee_l": 0.0,                     # degrees the knee turns out from its natural bend
    "knee_r": 0.0,
}
POSE_KEYS = tuple(STAND)
TRUNK = (("hips", "pelvis"), ("spine_01", "spine1"), ("spine_02", "spine2"), ("chest", "chest"),
         ("neck", "neck"), ("head", "head"), ("trophy", "trophy"))


@dataclass
class Clip:
    name: str
    frames: int
    loop: bool
    pose: Callable[[float], dict]   # loops: phase 0..1; one-shots: frame number
    spring: Optional[tuple] = None  # free hands' follow-through: (frequency in Hz, damping ratio)


# --- Posing ----------------------------------------------------------------------------------------

def pose_trunk(rig: Rig, pose: dict) -> Vector:
    """Poses the hips, spine, neck, head and shoulders, and returns the chest's level heading."""
    rig.clear()
    rig.place("torso", rig.rest_head("torso") + Vector(pose["hip"]), rotation(*pose["trunk"]))
    for bone, key in TRUNK:
        turned = rotation(*pose[key])
        rig.turn(bone, capped(turned, TRUNK_LIMITS[bone]) if bone in TRUNK_LIMITS else turned)
    for side, sign in SIDES.items():
        protract, rise = pose["clav_" + side]
        rig.turn("clavicle_" + side, rotation(turn=-sign * protract, tilt=-sign * rise))
    rig.evaluate()
    # The chest's forward and up together: steady from upright to tipped past vertical on all fours,
    # where the forward axis alone points at the floor.
    chest_forward, chest_up, _ = rig.body_axes("chest")
    facing = chest_forward + chest_up
    heading = Vector((facing.x, facing.y, 0.0))
    return heading.normalized() if heading.length > 0.05 else Vector((0.0, -1.0, 0.0))


def hand_targets(rig: Rig, pose: dict, heading: Vector) -> dict:
    """Where each wrist goes: from its shoulder, or at its grip as reach goes to 1. Kept off the floor."""
    targets = {}
    for side, sign in SIDES.items():
        shoulder = rig.head("upperarm_" + side)
        target = shoulder + level(pose["hand_" + side], heading, UP.cross(heading) * sign)
        reach = pose["reach_" + side]
        if reach > 0.0:
            target = target.lerp(Vector(pose["grip_" + side]), reach)
        target.z = max(target.z, WRIST_FLOOR)
        targets[side] = target
    return targets


def apply(rig: Rig, pose: dict) -> float:
    """Poses the rig; returns how far the furthest hand or foot was pulled in to keep its limb bent."""
    heading = pose_trunk(rig, pose)
    hands = hand_targets(rig, pose, heading)
    chest_forward, chest_up, _ = rig.body_axes("chest")
    hips_forward = rig.body_axes("hips")[0]
    shortfall = 0.0
    for side, sign in SIDES.items():
        # Elbows fold down and back from the chest, knees forward from the hips, wherever the limb
        # reaches; a pose only turns them out by a few degrees, which the shoulder and hip can take.
        shoulder = rig.head("upperarm_" + side)
        hand = within(shoulder, hands[side], REACH * rig.length("upperarm_" + side, "forearm_" + side))
        shortfall = max(shortfall, (hand - hands[side]).length)
        hand.z = max(hand.z, WRIST_FLOOR)
        rig.place("hand_ik_" + side, hand)
        elbow = pole(rig, "clavicle_" + side, ("upperarm_" + side, "hand_" + side, "forearm_" + side, "pole_elbow_" + side),
                     shoulder, hand, -chest_up - chest_forward * 0.5, pose["elbow_" + side] * sign, SHOULDER_TWIST)
        rig.place("pole_elbow_" + side, elbow)
        hip = rig.head("thigh_" + side)
        wanted = Vector(pose["foot_" + side])
        foot = within(hip, wanted, REACH * rig.length("thigh_" + side, "calf_" + side))
        shortfall = max(shortfall, (foot - wanted).length)
        rig.place("foot_ik_" + side, foot)
        knee = pole(rig, "hips", ("thigh_" + side, "foot_" + side, "calf_" + side, "pole_knee_" + side),
                    hip, foot, hips_forward, -pose["knee_" + side] * sign, HIP_TWIST)
        rig.place("pole_knee_" + side, knee)
        rig.turn("toe_" + side, rotation(bend=pose["toe_" + side]))
    rig.evaluate()
    # The hands and feet copy their targets' rotation relative to the forearm and shin, so these go
    # on once the IK has placed those, kept inside what a wrist and an ankle can do.
    for side, sign in SIDES.items():
        pitch, turn = pose["sole_" + side]
        flat = rotation(bend=pitch, turn=turn) @ rig.rest_turn("foot_" + side)
        ankle = rig.local_turn("foot_" + side, "calf_" + side, flat)
        rig.bones["foot_ik_" + side].rotation_quaternion = limited(ankle, *ANKLE_RANGE)
        wrist = Quaternion((1.0, 0.0, 0.0), math.radians(-pose["claw_" + side]))
        plant = pose["plant_" + side]
        if plant > 0.0:
            ground = rig.local_turn("hand_" + side, "forearm_" + side, flat_hand(rig, side, sign, heading))
            wrist = wrist.slerp(ground, min(plant, 1.0))
        rig.bones["hand_ik_" + side].rotation_quaternion = limited(wrist, *WRIST)
    # A hand or foot the wrist or ankle cannot lay flat rests on its tips instead of going through
    # the floor.
    rig.evaluate()
    lifted = False
    for side in SIDES:
        for tip, target, floor in (("hand_" + side, "hand_ik_" + side, TIP_FLOOR["hand"]),
                                   ("toe_" + side, "foot_ik_" + side, TIP_FLOOR["toe"])):
            low = rig.bones[tip].tail.z
            if low < floor:
                rig.raise_by(target, floor - low)
                lifted = True
    if lifted:
        rig.evaluate()
    return shortfall


def level(offset, heading, out) -> Vector:
    forward, upward, outward = offset
    return heading * forward + UP * upward + out * outward


def within(start: Vector, target, length: float) -> Vector:
    """The target, no further from where the limb starts than `length`, so the limb never locks straight."""
    offset = Vector(target) - start
    return start + offset.normalized() * length if offset.length > length else Vector(target)


def pole(rig: Rig, parent: str, bones: tuple, start: Vector, end: Vector, hint: Vector, bias: float,
         twist_limit: float, distance: float = 0.6) -> Vector:
    """Where an elbow or knee pole goes, out from the middle of the limb.

    The joint folds toward `hint`, the way it naturally folds, turned out by `bias` degrees, unless
    that would roll the upper bone (upper arm or thigh) further about its own length than
    `twist_limit`. Directions are tried every 5 degrees round the limb, nearest the natural one
    first: for each, where the elbow or knee would land, then how far the upper bone has rolled,
    measured as the joint's hinge against the rest hinge carried along by the bone's swing."""
    upper_bone, end_bone, lower_bone, rest_pole = bones
    upper_length, lower_length = rig.length(upper_bone), rig.length(lower_bone)
    carried = rig.turned_from_rest(parent)
    upper_rest = carried @ (rig.rest_head(lower_bone) - rig.rest_head(upper_bone)).normalized()
    rest_fold = rig.rest_head(rest_pole) - rig.rest_head(lower_bone)
    rest_fold = carried @ (rest_fold - upper_rest * rest_fold.dot(upper_rest)).normalized()
    hinge_rest = rest_fold.cross(upper_rest).normalized()
    axis = end - start
    reach = min(max(axis.length, 1e-3), (upper_length + lower_length) * 0.999)
    axis.normalize()
    along = (upper_length ** 2 - lower_length ** 2 + reach ** 2) / (2.0 * reach)
    out = math.sqrt(max(upper_length ** 2 - along ** 2, 0.0))
    natural = hint - axis * hint.dot(axis)
    natural = natural.normalized() if natural.length > 1e-4 else axis.orthogonal().normalized()
    natural = Quaternion(axis, math.radians(bias)) @ natural
    best = (math.inf, natural)
    for step in sorted(range(-36, 37), key=abs):
        fold = Quaternion(axis, math.radians(5.0 * step)) @ natural
        joint = start + axis * along + fold * out
        upper = (joint - start).normalized()
        hinge = upper.cross((end - joint).normalized())
        if hinge.length < 1e-4:
            return (start + end) * 0.5 + fold * distance
        hinge.normalize()
        expected = upper_rest.rotation_difference(upper) @ hinge_rest
        twist = abs(math.degrees(math.atan2(upper.dot(expected.cross(hinge)), expected.dot(hinge))))
        if twist <= twist_limit:
            return (start + end) * 0.5 + fold * distance
        if twist < best[0]:
            best = (twist, fold)
    return (start + end) * 0.5 + best[1] * distance


def flat_hand(rig: Rig, side: str, sign: float, heading: Vector) -> Quaternion:
    """A hand pressed to the ground, palm down, carrying on from the forearm's line across the floor
    and turned a little out."""
    forearm = rig.bones["hand_" + side].head - rig.bones["forearm_" + side].head
    line = Vector((forearm.x, forearm.y, 0.0))
    line = line.normalized() if line.length > 0.05 else heading.copy()
    out = UP.cross(line) * sign
    angle = math.radians(SPLAY)
    pointing = (line * math.cos(angle) + out * math.sin(angle) - UP * 0.12).normalized()
    return aim(pointing, UP, Vector((sign, 0.0, 0.0)), UP) @ rig.rest_turn("hand_" + side)


def follow(rig: Rig, poses: list, spring: tuple, loop: bool) -> None:
    """Runs each free hand through a damped spring toward where its pose puts it, in the rig's space,
    so a hand drags behind the body and overshoots when the arm stops. Planted hands stay exact.
    Loops run three cycles and keep the last, so the follow-through is the same at the seam."""
    frequency, damping = spring
    omega = TAU * frequency
    steps = 8
    dt = 1.0 / FPS / steps
    designed = []
    for pose in poses:
        heading = pose_trunk(rig, pose)
        designed.append(hand_targets(rig, pose, heading))
    count = len(poses) - 1 if loop else len(poses)
    for side in SIDES:
        position = designed[0][side].copy()
        velocity = Vector()
        followed = []
        for _ in range(3 if loop else 1):
            followed = []
            for index in range(count):
                start = designed[index - 1][side] if index > 0 else designed[count - 1 if loop else 0][side]
                end = designed[index][side]
                for step in range(steps):
                    target = start.lerp(end, (step + 1) / steps)
                    velocity += ((target - position) * omega * omega - velocity * (2.0 * damping * omega)) * dt
                    position += velocity * dt
                followed.append(position.copy())
        if loop:
            followed.append(followed[0].copy())
        for pose, there, exact in zip(poses, followed, (frame[side] for frame in designed)):
            there.z = max(there.z, WRIST_FLOOR)
            loose = 1.0 - min(max(pose["plant_" + side], 0.0), 1.0)
            pose["grip_" + side] = tuple(exact.lerp(there, loose))
            pose["reach_" + side] = 1.0


# --- Timing ----------------------------------------------------------------------------------------

def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def ease_in(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * x


def ease_out(x):
    x = 1.0 - min(max(x, 0.0), 1.0)
    return 1.0 - x * x * x


def snap(x):
    """Most of the move in the first few frames: for jerks and twitches."""
    x = min(max(x, 0.0), 1.0)
    return 1.0 - (1.0 - x) ** 5


def overshoot(x):
    x = min(max(x, 0.0), 1.0) - 1.0
    return 1.0 + 2.7 * x * x * x + 1.7 * x * x


def wave(u, cycles=1, at=0.0):
    """cos over the loop, peaking at phase `at`."""
    return math.cos(TAU * (cycles * (u - at)))


def loop_noise(u, seed, harmonics=(3, 5, 8)):
    """Loopable wobble in about -1..1, from a few whole-cycle sines."""
    total = 0.0
    for index, count in enumerate(harmonics):
        phase = math.sin(seed * 12.9898 + index * 78.233) * 43758.5453 % 1.0
        total += math.sin(TAU * (count * u + phase)) / (index + 1)
    return total / 1.6


def noise(t, seed, rate=6.0):
    """Wobble in about -1..1 for one-shots, t in seconds."""
    total = 0.0
    for index, factor in enumerate((1.0, 2.3, 4.1)):
        phase = math.sin(seed * 12.9898 + index * 78.233) * 43758.5453 % 1.0
        total += math.sin(TAU * (rate * factor * t + phase)) / (index + 1)
    return total / 1.6


def mix(a, b, w):
    if isinstance(a, tuple):
        return tuple(x + (y - x) * w for x, y in zip(a, b))
    return a + (b - a) * w


def add(a, b):
    if isinstance(a, tuple):
        return tuple(x + y for x, y in zip(a, b))
    return a + b


def scaled(a, k):
    if isinstance(a, tuple):
        return tuple(x * k for x in a)
    return a * k


def pose_of(base, **changes):
    pose = dict(base)
    pose.update(changes)
    return pose


def timeline(keys, frame, delays=None):
    """A pose on a list of (frame, pose, ease) keys; each key's ease shapes the move into it.
    delays holds channels that trail the rest by a few frames, for overlap."""
    result = {}
    for channel in POSE_KEYS:
        t = frame - (delays or {}).get(channel, 0.0)
        if t <= keys[0][0]:
            result[channel] = keys[0][1][channel]
            continue
        for (start, before, _), (end, after, ease) in zip(keys, keys[1:]):
            if t <= end:
                w = ease((t - start) / max(end - start, 1e-6))
                result[channel] = mix(before[channel], after[channel], w)
                break
        else:
            result[channel] = keys[-1][1][channel]
    return result


def path(points, s):
    """A smooth curve through (s, value-tuple) points: cubic Hermite with Catmull-Rom tangents."""
    for index in range(len(points) - 1):
        s0, p0 = points[index]
        s1, p1 = points[index + 1]
        if s <= s1 or index == len(points) - 2:
            before = points[max(index - 1, 0)]
            after = points[min(index + 2, len(points) - 1)]
            t = min(max((s - s0) / (s1 - s0), 0.0), 1.0)
            span = s1 - s0
            m0 = [(b - a) / max(s1 - before[0], 1e-6) * span for a, b in zip(before[1], p1)]
            m1 = [(b - a) / max(after[0] - s0, 1e-6) * span for a, b in zip(p0, after[1])]
            h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
            h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
            return tuple(h00 * a + h10 * c + h01 * b + h11 * d for a, b, c, d in zip(p0, p1, m0, m1))
    return points[-1][1]


# --- Sprint: the chase --------------------------------------------------------------------------

SPRINT_FRAMES = 13
SPRINT_DUTY = 0.30
SPRINT_TOUCH = -0.36       # foot lands this far ahead of the hips' rest line
SPRINT_LIFT = 0.52         # and leaves the ground this far behind
# Ground speed the cycle matches, in the model's own metres per second.
SPRINT_SPEED = (SPRINT_LIFT - SPRINT_TOUCH) / (SPRINT_DUTY * SPRINT_FRAMES / FPS)
SPRINT_SWING = [            # (fraction of the swing, (y, ankle height, foot pitch))
    (0.0, (SPRINT_LIFT, ANKLE + 0.12, 45.0)),
    (0.1, (0.54, 0.34, 58.0)),
    (0.25, (0.5, 0.5, 78.0)),
    (0.55, (-0.06, 0.62, 18.0)),
    (0.82, (-0.44, 0.3, -14.0)),
    (1.0, (SPRINT_TOUCH, ANKLE, -8.0)),
]


def sprint_leg(side, u):
    """Where one foot is: planted and sweeping back under the hips, then kicked up and driven
    forward with a high knee, reaching past the landing spot before it pulls back down."""
    sign = SIDES[side]
    phase = (u - (0.0 if side == "r" else 0.5)) % 1.0
    x = 0.13 * sign
    if phase < SPRINT_DUTY:
        s = phase / SPRINT_DUTY
        y = SPRINT_TOUCH + (SPRINT_LIFT - SPRINT_TOUCH) * s
        heel = 0.12 * smooth((s - 0.55) / 0.45)
        pitch = -8.0 + 53.0 * smooth((s - 0.35) / 0.65)
        foot = (x, y, ANKLE + heel)
        toe = -0.9 * max(pitch, 0.0)
    else:
        s = (phase - SPRINT_DUTY) / (1.0 - SPRINT_DUTY)
        y, z, pitch = path(SPRINT_SWING, s)
        foot = (x * (1.0 - 0.25 * math.sin(math.pi * s)), y, z)
        toe = 10.0 * math.sin(math.pi * s)
    return foot, (pitch, 0.0), toe


def claw_loop(a, reach=1.0):
    """One arm's clawing loop from the shoulder: reach out ahead, rake down, swing back past the hip,
    then come up high and wide with the elbow lifted, ready to reach again."""
    theta = TAU * a
    forward = 0.175 + reach * (0.4 * math.cos(theta) + 0.15 * math.sin(theta))
    upward = -0.2 + reach * (0.3 * math.cos(theta) - 0.25 * math.sin(theta))
    out = 0.21 - 0.13 * math.cos(theta) - 0.07 * math.sin(theta)
    return (forward, upward, out)


def sprint(u):
    """Flat-out and hunched, the head held level and locked ahead while the hips and shoulders twist
    against each other and both arms claw at the air in big uneven loops."""
    pose = dict(STAND)
    bob = -0.045 * wave(u, 2, 0.15)
    pose["hip"] = (0.0, 0.02 * wave(u, 2, 0.35), -0.11 + bob)
    pose["trunk"] = (30.0 + 4.0 * wave(u, 2, 0.3), 0.0, -4.0 * wave(u, 1, 0.15))
    twist = math.cos(TAU * u)
    pose["pelvis"] = (0.0, 14.0 * twist, 0.0)
    pose["spine1"] = (6.0 + 3.0 * wave(u, 2, 0.15), -10.0 * twist, 0.0)
    pose["spine2"] = (7.0, -11.0 * twist, 0.0)
    pose["chest"] = (5.0 + 3.0 * wave(u, 2, 0.15), -11.0 * twist, 0.0)
    lean = pose["trunk"][0] + pose["spine1"][0] + pose["spine2"][0] + pose["chest"][0]
    look = lean - 6.0
    pose["neck"] = (-0.55 * look, 0.6 * 18.0 * twist, 0.0)
    pose["head"] = (-0.45 * look + 2.5 * loop_noise(u, 3, (5, 9)), 0.4 * 18.0 * twist,
                    12.0 + 3.0 * loop_noise(u, 7, (4, 11)))
    pose["trophy"] = (12.0 * wave(u, 2, 0.28), 0.0, 6.0 * wave(u, 1, 0.2))
    left_arm = u % 1.0
    right_arm = (u + 0.53) % 1.0
    pose["hand_l"] = claw_loop(left_arm)
    pose["hand_r"] = claw_loop(right_arm, 1.12)
    pose["elbow_l"] = 28.0
    pose["elbow_r"] = 31.0
    pose["claw_l"] = 25.0 + 20.0 * smooth(math.sin(TAU * left_arm))
    pose["claw_r"] = 30.0 + 22.0 * smooth(math.sin(TAU * right_arm))
    pose["clav_l"] = (18.0 * math.cos(TAU * left_arm), 4.0 + 10.0 * max(math.cos(TAU * left_arm), 0.0))
    pose["clav_r"] = (20.0 * math.cos(TAU * right_arm), 5.0 + 12.0 * max(math.cos(TAU * right_arm), 0.0))
    for side in SIDES:
        foot, sole, toe = sprint_leg(side, u)
        pose["foot_" + side] = foot
        pose["sole_" + side] = sole
        pose["toe_" + side] = toe
        pose["knee_" + side] = 11.0
    return pose


def gaze(pose, down=6.0, turn=0.0, tilt=0.0):
    """Neck and head take back whatever the trunk and spine bend, so the head looks `down` degrees
    below level, and turn it on top."""
    lean = sum(pose[key][0] for key in ("trunk", "spine1", "spine2", "chest"))
    head = pose["head"]
    pose["neck"] = (-0.55 * (lean - down), 0.6 * turn, 0.3 * tilt)
    pose["head"] = (-0.45 * (lean - down) + head[0], 0.4 * turn + head[1], 0.7 * tilt + head[2])
    return pose


def bump(u, at, rise, hold, fall):
    """0, then up to 1 in `rise`, held for `hold`, back down in `fall` (all in loop phase)."""
    if u < at:
        return 0.0
    if u < at + rise:
        return snap((u - at) / rise)
    if u < at + rise + hold:
        return 1.0
    return 1.0 - smooth((u - at - rise - hold) / fall)


def tremble(pose, t, amount, seed=1):
    """A shudder through the trunk, head and claws, for moments the creature holds still."""
    pose = dict(pose)
    for index, key in enumerate(("chest", "neck", "head")):
        pose[key] = add(pose[key], (amount * noise(t, seed + index, 9.0), amount * noise(t, seed + 7 + index, 8.0),
                                    amount * noise(t, seed + 13 + index, 10.0)))
    for index, side in enumerate(SIDES):
        pose["claw_" + side] += 3.0 * amount * noise(t, seed + 20 + index, 11.0)
        pose["hand_" + side] = add(pose["hand_" + side], tuple(0.012 * amount * noise(t, seed + 30 + 3 * index + k, 9.0)
                                                          for k in range(3)))
    return pose


# --- Idle and watch --------------------------------------------------------------------------------

HUNCH = pose_of(
    STAND, hip=(0.0, 0.02, -0.05), trunk=(10.0, 0.0, 0.0), spine1=(5.0, 0.0, 0.0), spine2=(6.0, 0.0, 0.0),
    chest=(6.0, 0.0, 0.0), head=(0.0, 0.0, 8.0), clav_l=(6.0, 3.0), clav_r=(8.0, 5.0),
    hand_l=(0.14, -0.58, 0.16), hand_r=(0.1, -0.6, 0.12), elbow_l=19.0, elbow_r=20.0,
    claw_l=18.0, claw_r=22.0, foot_l=(0.15, 0.04, ANKLE), foot_r=(-0.14, 0.13, ANKLE),
    sole_l=(0.0, 9.0), sole_r=(0.0, -12.0), knee_l=12.0, knee_r=13.0)


def idle(u):
    """Hunched and breathing raggedly, weight rolling side to side, the head drifting round until it
    jerks sideways, holds, and eases back; the right hand twitches open once."""
    pose = dict(HUNCH)
    breath = wave(u, 2, 0.1)
    sway = math.sin(TAU * u)
    twitch = bump(u, 0.6, 0.02, 0.1, 0.12)
    flex = bump(u, 0.28, 0.015, 0.04, 0.08)
    pose["hip"] = (0.035 * sway, 0.02, -0.05 + 0.01 * breath)
    pose["trunk"] = (10.0 + 1.5 * breath, 4.0 * math.sin(TAU * (u - 0.1)), 2.5 * sway)
    pose["chest"] = (6.0 - 3.0 * breath, 0.0, -1.5 * sway)
    pose["clav_l"] = (6.0, 3.0 + 4.0 * breath)
    pose["clav_r"] = (8.0, 5.0 + 4.0 * wave(u, 2, 0.14))
    pose["hand_l"] = (0.14 + 0.03 * wave(u, 1, 0.25), -0.58, 0.16 + 0.015 * sway)
    pose["hand_r"] = (0.1 + 0.03 * wave(u, 1, 0.3) + 0.12 * flex, -0.6 + 0.1 * flex, 0.12)
    pose["claw_l"] = 18.0 + 6.0 * loop_noise(u, 2)
    pose["claw_r"] = 22.0 - 45.0 * flex
    pose["head"] = (4.0 * loop_noise(u, 4, (2, 3)), 0.0, 8.0 + 26.0 * twitch)
    pose["trophy"] = (4.0 * breath, 0.0, -3.0 * sway)
    return gaze(pose, down=10.0, turn=18.0 * math.sin(TAU * u) - 30.0 * twitch)


CROUCH = pose_of(
    STAND, hip=(0.0, 0.05, -0.13), trunk=(22.0, 0.0, 0.0), spine1=(6.0, 0.0, 0.0), spine2=(6.0, 0.0, 0.0),
    chest=(4.0, 0.0, 0.0), clav_l=(10.0, 12.0), clav_r=(12.0, 14.0),
    hand_l=(0.32, -0.35, 0.3), hand_r=(0.3, -0.32, 0.32), elbow_l=31.0, elbow_r=32.0,
    claw_l=25.0, claw_r=25.0, foot_l=(0.22, -0.02, ANKLE), foot_r=(-0.21, 0.1, ANKLE),
    sole_l=(0.0, 14.0), sole_r=(0.0, -16.0), knee_l=30.0, knee_r=30.0)


def watch(u):
    """Crouched with its arms out and its shoulders up, staring: the head is cocked, snaps over to
    the other side, holds there, then snaps back. The claws flex as it breathes."""
    pose = dict(CROUCH)
    breath = wave(u, 3, 0.05)
    flip = bump(u, 0.42, 0.03, 0.36, 0.04)
    pose["hip"] = (0.01 * math.sin(TAU * u), 0.05, -0.13 + 0.008 * breath)
    pose["chest"] = (4.0 - 2.5 * breath, 0.0, 0.0)
    pose["clav_l"] = (10.0, 12.0 + 3.0 * breath)
    pose["clav_r"] = (12.0, 14.0 + 3.0 * breath)
    pose["claw_l"] = 25.0 + 15.0 * wave(u, 2, 0.1)
    pose["claw_r"] = 25.0 + 15.0 * wave(u, 2, 0.35)
    pose["head"] = (2.0 * loop_noise(u, 9, (5, 7)), 0.0, 22.0 - 46.0 * flip + 2.0 * loop_noise(u, 11, (6, 9)))
    pose["trophy"] = (3.0 * breath, 0.0, 0.0)
    return gaze(pose, down=2.0, turn=4.0 * loop_noise(u, 5, (2, 3)))


# --- Stalk: the walk -------------------------------------------------------------------------------

STALK_FRAMES = 34
STALK_DUTY = 0.6
STALK_TOUCH = -0.44
STALK_LIFT = 0.5
STALK_SPEED = (STALK_LIFT - STALK_TOUCH) / (STALK_DUTY * STALK_FRAMES / FPS)
STALK_SWING = [
    (0.0, (STALK_LIFT, ANKLE + 0.08, 35.0)),
    (0.35, (0.2, 0.42, 55.0)),
    (0.7, (-0.38, 0.4, 5.0)),
    (0.88, (-0.5, 0.18, -10.0)),
    (1.0, (STALK_TOUCH, ANKLE, -4.0)),
]


def stalk_leg(side, u):
    """A long creeping step: the knee lifts high, the foot hangs out ahead, then sets down."""
    sign = SIDES[side]
    phase = (u - (0.0 if side == "r" else 0.5)) % 1.0
    x = 0.14 * sign
    if phase < STALK_DUTY:
        s = phase / STALK_DUTY
        y = STALK_TOUCH + (STALK_LIFT - STALK_TOUCH) * s
        heel = 0.08 * smooth((s - 0.7) / 0.3)
        pitch = -4.0 + 39.0 * smooth((s - 0.6) / 0.4)
        return (x, y, ANKLE + heel), (pitch, 6.0 * sign), -0.9 * max(pitch, 0.0)
    s = (phase - STALK_DUTY) / (1.0 - STALK_DUTY)
    y, z, pitch = path(STALK_SWING, s)
    return (x * (1.0 + 0.3 * math.sin(math.pi * s)), y, z), (pitch, 6.0 * sign), 15.0 * math.sin(math.pi * s)


def stalk(u):
    """Bent low and creeping on long legs, the head level and scanning, the long arms hanging and
    swinging loosely a beat behind the body."""
    pose = dict(STAND)
    twist = math.cos(TAU * u)
    pose["hip"] = (0.03 * math.sin(TAU * (u - 0.3)), 0.03, -0.09 - 0.03 * wave(u, 2, 0.32))
    pose["trunk"] = (26.0 + 2.0 * wave(u, 2, 0.4), 0.0, -4.0 * math.sin(TAU * (u - 0.3)))
    pose["pelvis"] = (0.0, 8.0 * twist, 0.0)
    pose["spine1"] = (5.0, -5.0 * twist, 0.0)
    pose["spine2"] = (6.0, -5.0 * twist, 0.0)
    pose["chest"] = (5.0, -5.0 * twist, 0.0)
    pose["clav_l"] = (8.0, 2.0)
    pose["clav_r"] = (10.0, 4.0)
    lag_l = math.cos(TAU * (u - 0.12))
    lag_r = math.cos(TAU * (u + 0.5 - 0.15))
    pose["hand_l"] = (0.14 + 0.16 * lag_l, -0.6 + 0.05 * max(lag_l, 0.0), 0.2 + 0.03 * lag_l)
    pose["hand_r"] = (0.12 + 0.18 * lag_r, -0.6 + 0.06 * max(lag_r, 0.0), 0.18 + 0.03 * lag_r)
    pose["elbow_l"] = 21.0
    pose["elbow_r"] = 22.0
    pose["claw_l"] = 15.0 + 10.0 * lag_l
    pose["claw_r"] = 18.0 + 10.0 * lag_r
    pose["trophy"] = (8.0 * wave(u, 2, 0.45), 0.0, 5.0 * math.sin(TAU * (u - 0.4)))
    for side in SIDES:
        foot, sole, toe = stalk_leg(side, u)
        pose["foot_" + side] = foot
        pose["sole_" + side] = sole
        pose["toe_" + side] = toe
        pose["knee_" + side] = 15.0
    pose["head"] = (0.0, 0.0, 6.0 * math.sin(TAU * (u - 0.2)))
    return gaze(pose, down=4.0, turn=6.0 * twist + 14.0 * math.sin(TAU * u))


# --- One-shots ---------------------------------------------------------------------------------------

DELAYS = {"head": 1.0, "neck": 0.5, "hand_l": 1.5, "hand_r": 2.0, "claw_l": 2.0, "claw_r": 2.5,
          "elbow_l": 1.5, "elbow_r": 2.0, "trophy": 3.0}
SCREAM_FRAMES = round(0.9 * FPS)
REAR = gaze(pose_of(
    HUNCH, hip=(0.0, 0.08, 0.03), trunk=(-12.0, 0.0, 0.0), spine1=(-6.0, 0.0, 0.0), spine2=(-8.0, 0.0, 0.0),
    chest=(-10.0, 0.0, 0.0), head=(-16.0, 0.0, 0.0), clav_l=(-15.0, 18.0), clav_r=(-15.0, 20.0),
    hand_l=(-0.05, 0.42, 0.55), hand_r=(-0.08, 0.45, 0.55), elbow_l=34.0, elbow_r=35.0,
    claw_l=-20.0, claw_r=-25.0, foot_l=(0.2, 0.0, ANKLE), foot_r=(-0.22, 0.28, ANKLE), sole_l=(0.0, 12.0),
    sole_r=(0.0, -15.0), knee_l=21.0, knee_r=21.0), down=-28.0)
SHRIEK = gaze(pose_of(
    REAR, trunk=(-4.0, 0.0, 0.0), chest=(4.0, 0.0, 0.0), spine2=(-2.0, 0.0, 0.0), head=(8.0, 0.0, 6.0),
    hand_l=(0.15, 0.3, 0.6), hand_r=(0.12, 0.34, 0.6), claw_l=32.0, claw_r=36.0, clav_l=(0.0, 22.0),
    clav_r=(0.0, 24.0)), down=-6.0)
LAUNCH = gaze(pose_of(
    STAND, hip=(0.0, -0.04, -0.14), trunk=(34.0, 0.0, 0.0), spine1=(6.0, 0.0, 0.0), spine2=(7.0, 0.0, 0.0),
    chest=(6.0, 0.0, 0.0), clav_l=(-12.0, 6.0), clav_r=(-12.0, 8.0), hand_l=(-0.28, -0.48, 0.3),
    hand_r=(-0.3, -0.45, 0.32), elbow_l=27.0, elbow_r=28.0, claw_l=35.0, claw_r=35.0,
    foot_l=(0.14, -0.3, ANKLE), foot_r=(-0.14, 0.42, ANKLE + 0.1), sole_l=(-4.0, 0.0), sole_r=(40.0, 0.0),
    toe_r=-35.0, knee_l=12.0, knee_r=12.0), down=6.0)


def scream(frame):
    """Rears up tall with its arms flung wide and its head thrown back, shrieks forward with
    everything shaking, then drops and launches into the sprint's first stride."""
    keys = [(0, HUNCH, smooth), (3, REAR, snap), (8, REAR, smooth), (10, SHRIEK, snap), (15, SHRIEK, smooth),
            (19, LAUNCH, ease_in), (SCREAM_FRAMES, sprint(0.0), smooth)]
    pose = timeline(keys, frame, DELAYS)
    if 3 <= frame <= 17:
        pose = tremble(pose, frame / FPS, 5.0 if frame >= 10 else 2.5)
    return pose


WINDUP_FRAMES = round(0.7 * FPS)
COIL = gaze(pose_of(
    STAND, hip=(0.0, 0.06, -0.04), trunk=(8.0, 0.0, 0.0), pelvis=(0.0, -15.0, 0.0), spine1=(2.0, 9.0, 0.0),
    spine2=(2.0, 10.0, 0.0), chest=(2.0, 9.0, -4.0), clav_l=(14.0, 6.0), clav_r=(-18.0, 22.0),
    hand_l=(0.5, 0.05, 0.15), hand_r=(-0.15, 0.55, 0.25), elbow_l=23.0, elbow_r=32.0,
    claw_l=30.0, claw_r=-5.0, foot_l=(0.15, -0.25, ANKLE), foot_r=(-0.15, 0.38, ANKLE + 0.06),
    sole_l=(0.0, 8.0), sole_r=(25.0, -10.0), toe_r=-22.0, knee_l=15.0, knee_r=15.0),
    down=-4.0, turn=-20.0)
COILED = gaze(pose_of(
    COIL, trunk=(4.0, 0.0, 0.0), chest=(2.0, 15.0, -6.0), hand_r=(-0.25, 0.5, 0.3), claw_r=-15.0,
    hand_l=(0.55, 0.0, 0.2)), down=-4.0, turn=-30.0)


def windup(frame):
    """Rises out of the run and coils: the right arm cocked high behind its head, the left reaching
    to fix the distance, the head locked on its target while the chest winds away."""
    keys = [(0, sprint(0.0), smooth), (6, COIL, ease_out), (12, COILED, smooth), (WINDUP_FRAMES, COILED, smooth)]
    pose = timeline(keys, frame, DELAYS)
    if frame >= 8:
        pose = tremble(pose, frame / FPS, 3.0, seed=4)
    return pose


STRIKE_FRAMES = round(1.2 * FPS)
SLASH = gaze(pose_of(
    COILED, hip=(0.0, -0.12, -0.14), trunk=(42.0, 0.0, 0.0), pelvis=(0.0, 10.0, 0.0), spine1=(6.0, -12.0, 0.0),
    spine2=(6.0, -14.0, 0.0), chest=(4.0, -14.0, 6.0), clav_l=(-10.0, 4.0), clav_r=(25.0, 4.0),
    hand_r=(0.45, -0.55, -0.15), hand_l=(-0.2, -0.35, 0.3), elbow_r=28.0, elbow_l=26.0,
    claw_r=50.0, claw_l=30.0, foot_r=(-0.15, -0.45, ANKLE), sole_r=(-6.0, -10.0), toe_r=0.0,
    foot_l=(0.15, 0.25, ANKLE + 0.04), sole_l=(20.0, 10.0), toe_l=-15.0), down=14.0)
FOLLOW = gaze(pose_of(
    SLASH, trunk=(46.0, 0.0, 0.0), chest=(6.0, -19.0, 6.0), hand_r=(0.35, -0.65, -0.25), claw_r=55.0), down=16.0)


def strike(frame):
    """The cocked arm whips down and across in three frames as the body lunges after it, follows
    through low, hangs there heaving, then gathers itself back into the run."""
    keys = [(0, COILED, smooth), (3, SLASH, ease_in), (6, FOLLOW, ease_out), (13, FOLLOW, smooth),
            (24, sprint(0.0), smooth), (STRIKE_FRAMES, sprint(0.0), smooth)]
    pose = timeline(keys, frame, {"head": 0.5, "hand_l": 1.0, "trophy": 3.0, "claw_r": 1.0})
    if 6 <= frame <= 16:
        pose = tremble(pose, frame / FPS, 3.0, seed=6)
    return pose


FLINCH_FRAMES = 12
RECOIL = gaze(pose_of(
    CROUCH, hip=(0.0, 0.14, -0.08), trunk=(4.0, 0.0, -6.0), chest=(-12.0, 8.0, 0.0), spine2=(-4.0, 0.0, 0.0),
    hand_l=(0.25, 0.12, 0.25), hand_r=(0.18, 0.2, 0.2), elbow_l=21.0, elbow_r=19.0,
    claw_l=-15.0, claw_r=-20.0, head=(0.0, 0.0, -20.0)), down=-25.0, turn=25.0)


def flinch(frame):
    """Hit: the head snaps back and away, the arms jerk up, then it sinks back into a crouch."""
    keys = [(0, CROUCH, smooth), (2, RECOIL, snap), (5, RECOIL, smooth), (FLINCH_FRAMES, gaze(dict(CROUCH)), smooth)]
    return tremble(timeline(keys, frame, DELAYS), frame / FPS, 4.0 * (1.0 - frame / FLINCH_FRAMES), seed=8)


DEATH_FRAMES = round(1.6 * FPS)
JOLT = gaze(pose_of(
    HUNCH, hip=(0.0, 0.08, -0.02), trunk=(-6.0, 0.0, 4.0), chest=(-14.0, -10.0, 0.0), head=(0.0, 0.0, 15.0),
    hand_l=(0.1, 0.0, 0.5), hand_r=(0.0, 0.1, 0.45), elbow_l=26.0, elbow_r=27.0,
    claw_l=-25.0, claw_r=-30.0), down=-35.0, turn=-15.0)
BUCKLE = gaze(pose_of(
    STAND, hip=(0.0, 0.02, -0.42), trunk=(28.0, 0.0, -6.0), spine1=(6.0, 0.0, 0.0), spine2=(8.0, 0.0, 0.0),
    chest=(8.0, 0.0, -4.0), head=(22.0, 0.0, -18.0), hand_l=(0.1, -0.5, 0.25), hand_r=(0.22, -0.4, 0.15),
    elbow_l=19.0, elbow_r=19.0, claw_l=40.0, claw_r=35.0,
    foot_l=(0.18, 0.05, ANKLE), foot_r=(-0.16, 0.12, ANKLE), knee_l=21.0, knee_r=21.0),
    down=40.0)
KNEEL = gaze(pose_of(
    BUCKLE, hip=(0.0, 0.0, -0.40), trunk=(42.0, 0.0, -10.0), head=(30.0, 0.0, -20.0),
    hand_l=(0.25, -0.45, 0.2), hand_r=(0.35, -0.3, 0.05), foot_l=(0.16, 0.5, 0.16), foot_r=(-0.15, 0.52, 0.16),
    sole_l=(-72.0, 0.0), sole_r=(-75.0, 0.0), knee_l=6.0, knee_r=6.0), down=55.0)
PRONE = pose_of(
    STAND, hip=(0.0, 0.1, -0.74), trunk=(84.0, 0.0, -14.0), spine1=(2.0, 0.0, 0.0), spine2=(2.0, 0.0, 0.0),
    chest=(0.0, 0.0, -6.0), neck=(-10.0, 0.0, 0.0), head=(-22.0, 35.0, 0.0), clav_l=(10.0, -6.0), clav_r=(-10.0, 10.0),
    hand_l=(0.55, -0.12, 0.28), hand_r=(0.3, -0.12, 0.4), elbow_l=29.0, elbow_r=29.0,
    claw_l=30.0, claw_r=45.0, foot_l=(0.2, 0.8, 0.36), foot_r=(-0.12, 0.78, 0.33), sole_l=(-85.0, 10.0),
    sole_r=(-80.0, -5.0), knee_l=0.0, knee_r=0.0)


# Tipping forward over its knees, the feet lifting off the floor before the body lands.
TOPPLE = gaze(pose_of(
    KNEEL, hip=(0.0, -0.05, -0.42), trunk=(64.0, 0.0, -12.0), foot_l=(0.18, 0.62, 0.3), foot_r=(-0.14, 0.62, 0.28),
    hand_l=(0.45, -0.3, 0.25), hand_r=(0.2, -0.2, 0.2)), down=50.0)


def death(frame):
    """Jolts upright, the knees go, it drops onto them, pitches forward onto its face with the arms
    sprawled, the right hand twitches once, and it stays down: the last frame is the corpse."""
    twitch = bump(frame / DEATH_FRAMES, 0.8, 0.02, 0.03, 0.08)
    still = pose_of(PRONE, claw_r=PRONE["claw_r"] - 40.0 * twitch,
                    hand_r=add(PRONE["hand_r"], (0.0, 0.03 * twitch, 0.0)))
    keys = [(0, HUNCH, smooth), (4, JOLT, snap), (10, BUCKLE, ease_in), (16, KNEEL, ease_out),
            (21, TOPPLE, smooth), (25, PRONE, ease_in), (DEATH_FRAMES, PRONE, smooth)]
    pose = timeline(keys, frame, DELAYS)
    if frame > 25:
        pose["claw_r"] = still["claw_r"]
        pose["hand_r"] = still["hand_r"]
    if frame <= 10:
        pose = tremble(pose, frame / FPS, 4.0, seed=12)
    return pose


# --- On all fours -------------------------------------------------------------------------------------

def hang(pose, swing=(0.0, 0.0, 0.0)):
    """The trophy on its chest hangs straight down, whatever the trunk is doing, and swings."""
    lean = sum(pose[key][0] for key in ("trunk", "spine1", "spine2", "chest"))
    pose["trophy"] = (-lean + swing[0], swing[1], swing[2])
    return pose


# A bear crawl: the hips 0.4 m lower than standing, the trunk tipped 74 degrees and the spine curling
# down to the chest, so the back humps into a ridge and the shoulders come down about level with the
# hips, low enough for the hands to reach the floor (about 0.4 m round the point under each shoulder)
# while the legs fold only part way. The shoulders sit near y -0.47, the hips near y 0.12. The head
# lifts as far as the neck allows, to about level.
FOURS_HIP = (0.0, 0.05, -0.40)
QUAD = hang(gaze(pose_of(
    STAND, hip=FOURS_HIP, trunk=(74.0, 0.0, 0.0), spine1=(6.0, 0.0, 0.0), spine2=(12.0, 0.0, 0.0),
    chest=(22.0, 0.0, 0.0), clav_l=(14.0, 16.0), clav_r=(14.0, 16.0),
    grip_l=(0.34, -0.72, WRIST_FLOOR), grip_r=(-0.34, -0.7, WRIST_FLOOR), reach_l=1.0, reach_r=1.0,
    plant_l=1.0, plant_r=1.0, elbow_l=30.0, elbow_r=30.0, claw_l=15.0, claw_r=15.0,
    foot_l=(0.2, 0.42, 0.14), foot_r=(-0.2, 0.45, 0.14), sole_l=(35.0, 15.0), sole_r=(35.0, -15.0),
    toe_l=-35.0, toe_r=-35.0, knee_l=20.0, knee_r=20.0), down=0.0))


def quad_leg(phase, duty, touch, lift, height, stance=0.14):
    """A hind foot on its toes: planted and sweeping back, pushing up off the toes, then kicked up,
    tucked forward under the belly and set down. Returns y, ankle height, foot pitch, toe bend."""
    if phase < duty:
        s = phase / duty
        push = smooth((s - 0.6) / 0.4)
        return touch + (lift - touch) * s, stance + 0.08 * push, 35.0 + 25.0 * push, -35.0 + 5.0 * push
    s = (phase - duty) / (1.0 - duty)
    y, z, pitch = path([(0.0, (lift, stance + 0.08, 60.0)), (0.2, (lift - 0.1, stance + 0.6 * height, 80.0)),
                        (0.55, (mix(lift, touch, 0.6), stance + height, 40.0)),
                        (0.85, (touch - 0.02, stance + 0.4 * height, 25.0)), (1.0, (touch, stance, 35.0))], s)
    return y, z, pitch, -30.0 - 5.0 * smooth((s - 0.7) / 0.3)


def quad_hand(phase, duty, touch, lift, height):
    """A hand: pressed flat and dragged back under the shoulder, then lifted high with the elbow
    out, swung forward with the claws tucked, spread, and slapped down. Returns y, wrist height,
    plant and claw."""
    if phase < duty:
        s = phase / duty
        return touch + (lift - touch) * s, WRIST_FLOOR, 1.0, 15.0
    s = (phase - duty) / (1.0 - duty)
    y, z = path([(0.0, (lift, WRIST_FLOOR)), (0.25, (lift - 0.1, WRIST_FLOOR + 0.6 * height)),
                 (0.6, (mix(lift, touch, 0.7), WRIST_FLOOR + height)),
                 (0.88, (touch - 0.05, WRIST_FLOOR + 0.35 * height)), (1.0, (touch, WRIST_FLOOR))], s)
    plant = 1.0 - smooth((z - WRIST_FLOOR) / 0.12)
    claw = 15.0 + 35.0 * math.sin(math.pi * min(s / 0.7, 1.0)) - 40.0 * smooth((s - 0.7) / 0.25)
    return y, z, plant, claw


def limbs(pose, u, order, hind, fore, spread=0.34, lift_shoulders=10.0):
    """Places all four limbs for a phase: hind (duty, touch, lift, height) and fore likewise."""
    for side, sign in SIDES.items():
        y, z, pitch, toe = quad_leg((u - order["foot_" + side]) % 1.0, *hind)
        pose["foot_" + side] = (0.2 * sign, y, z)
        pose["sole_" + side] = (pitch, 15.0 * sign)
        pose["toe_" + side] = toe
        pose["knee_" + side] = 20.0
        y, z, plant, claw = quad_hand((u - order["grip_" + side]) % 1.0, *fore)
        swinging = 1.0 - plant
        pose["grip_" + side] = ((spread + 0.08 * swinging) * sign, y, z)
        pose["plant_" + side] = plant
        pose["claw_" + side] = claw
        pose["clav_" + side] = (14.0 + lift_shoulders * swinging, 16.0 + 0.8 * lift_shoulders * swinging)
    return pose


def lurk(u):
    """Down on all fours with its back humped, staring up at you: the ribs heave, the head is cocked,
    snaps over to the other side and back, and one hand lifts and taps the ground."""
    pose = dict(QUAD)
    breath = wave(u, 3, 0.05)
    flip = bump(u, 0.42, 0.03, 0.36, 0.04)
    tap = bump(u, 0.62, 0.05, 0.05, 0.07)
    sway = math.sin(TAU * u)
    pose["hip"] = (0.03 * sway, 0.05, -0.40 + 0.012 * breath)
    pose["trunk"] = (74.0, 0.0, 2.0 * sway)
    pose["spine2"] = (12.0 + 2.0 * breath, 0.0, 0.0)
    pose["chest"] = (22.0 - 3.0 * breath, 0.0, -2.0 * sway)
    pose["clav_l"] = (14.0, 16.0 + 4.0 * breath)
    pose["clav_r"] = (14.0, 16.0 + 4.0 * breath)
    pose["grip_r"] = (-0.34, -0.7 - 0.05 * tap, WRIST_FLOOR + 0.12 * tap)
    pose["plant_r"] = 1.0 - tap
    pose["claw_r"] = 15.0 - 45.0 * tap
    pose["head"] = (2.0 * loop_noise(u, 9, (5, 7)), 0.0, 20.0 - 42.0 * flip + 2.0 * loop_noise(u, 11, (6, 9)))
    gaze(pose, down=3.0 * breath, turn=5.0 * loop_noise(u, 5, (2, 3)))
    return hang(pose, (0.0, 0.0, 6.0 * sway))


PROWL_FRAMES = 24
PROWL_DUTY = 0.62
PROWL_HIND = (PROWL_DUTY, 0.16, 0.76, 0.14)
PROWL_FORE = (PROWL_DUTY, -0.77, -0.17, 0.26)
PROWL_SPEED = (PROWL_HIND[2] - PROWL_HIND[1]) / (PROWL_DUTY * PROWL_FRAMES / FPS)
PROWL_ORDER = {"foot_l": 0.0, "grip_l": 0.25, "foot_r": 0.5, "grip_r": 0.75}


def prowl(u):
    """Creeping on all fours one limb at a time, the hands lifted high and set down with care, the
    spine snaking side to side like a lizard's, and the head craned up and steady."""
    pose = limbs(dict(QUAD), u, PROWL_ORDER, PROWL_HIND, PROWL_FORE, lift_shoulders=8.0)
    pose["hip"] = (0.02 * math.sin(TAU * u), 0.05, -0.40 + 0.02 * wave(u, 2, 0.1))
    pose["pelvis"] = (0.0, 9.0 * math.sin(TAU * u), 0.0)
    pose["spine1"] = (6.0, -4.0 * math.sin(TAU * (u - 0.1)), 0.0)
    pose["spine2"] = (12.0 + 2.0 * wave(u, 2, 0.3), -5.0 * math.sin(TAU * (u - 0.2)), 0.0)
    pose["chest"] = (22.0, -6.0 * math.sin(TAU * (u - 0.3)), 0.0)
    pose["head"] = (1.5 * loop_noise(u, 21, (3, 5)), 0.0, 10.0 + 3.0 * math.sin(TAU * u))
    gaze(pose, down=0.0, turn=4.0 * math.sin(TAU * u))
    return hang(pose, (6.0 * wave(u, 2, 0.2), 0.0, 5.0 * math.sin(TAU * (u - 0.3))))


GALLOP_FRAMES = 9
GALLOP_HIND = (0.40, 0.15, 0.80, 0.16)
GALLOP_FORE = (0.37, -0.77, -0.17, 0.3)
# Ground speed the cycle matches, in the model's own metres per second (hind and fore agree).
GALLOP_SPEED = (GALLOP_HIND[2] - GALLOP_HIND[1]) / (GALLOP_HIND[0] * GALLOP_FRAMES / FPS)
GALLOP_ORDER = {"foot_l": 0.0, "foot_r": 0.08, "grip_l": 0.5, "grip_r": 0.62}


def gallop(u):
    """The chase on all fours: a bounding gallop, the back bunching and stretching under its ridge,
    the hind feet driving almost together and the hands slapping down one after the other with the
    elbows out like a spider's, while the head stays craned up, steady, and locked on you."""
    pose = limbs(dict(QUAD), u, GALLOP_ORDER, GALLOP_HIND, GALLOP_FORE)
    flex = wave(u, 1, 0.95)
    pose["hip"] = (0.0, 0.05 - 0.04 * flex, -0.40 + 0.04 * wave(u, 2, 0.42))
    pose["trunk"] = (74.0 - 3.0 * flex, 0.0, 2.0 * math.sin(TAU * u))
    pose["pelvis"] = (0.0, 6.0 * math.sin(TAU * (u - 0.05)), 0.0)
    pose["spine1"] = (6.0 + 5.0 * flex, 0.0, 0.0)
    pose["spine2"] = (12.0 + 5.0 * flex, 0.0, 0.0)
    pose["chest"] = (22.0 + 3.0 * flex, -5.0 * math.sin(TAU * (u - 0.55)), 0.0)
    pose["head"] = (2.0 * loop_noise(u, 3, (5, 9)), 0.0, 8.0 + 2.0 * loop_noise(u, 7, (4, 11)))
    gaze(pose, down=0.0)
    return hang(pose, (14.0 * math.sin(TAU * (u - 0.2)), 0.0, 0.0))


DROP_FRAMES = 22
FOLD = gaze(pose_of(
    HUNCH, hip=(0.0, 0.0, -0.3), trunk=(48.0, 0.0, 0.0), spine1=(8.0, 0.0, 0.0), spine2=(8.0, 0.0, 0.0),
    chest=(6.0, 0.0, 0.0), hand_l=(0.32, -0.62, 0.3), hand_r=(0.3, -0.6, 0.28), claw_l=-20.0, claw_r=-20.0,
    foot_l=(0.2, 0.2, ANKLE), foot_r=(-0.2, 0.22, ANKLE), knee_l=24.0, knee_r=24.0),
    down=30.0)
SLAM = hang(gaze(pose_of(QUAD, hip=(0.0, 0.05, -0.45), spine2=(16.0, 0.0, 0.0), clav_l=(16.0, 6.0),
                         clav_r=(16.0, 6.0)), down=45.0))
BOUNCE = hang(gaze(pose_of(SLAM, hip=(0.0, 0.05, -0.38)), down=42.0))
ARCH = hang(gaze(pose_of(QUAD, spine1=(12.0, 0.0, 0.0), spine2=(20.0, 0.0, 0.0), clav_l=(16.0, 24.0),
                         clav_r=(16.0, 24.0)), down=40.0))
STARE = hang(gaze(pose_of(QUAD, head=(0.0, 0.0, 18.0)), down=-5.0))


def drop(frame):
    """Down onto all fours: the knees go, it pitches forward and slaps its hands onto the ground,
    bounces, humps its back up into the ridge with its head hanging, then slowly lifts its head to
    stare at you and cocks it with a jerk."""
    keys = [(0, HUNCH, smooth), (5, FOLD, ease_in), (8, SLAM, ease_in), (10, BOUNCE, ease_out),
            (14, ARCH, smooth), (19, STARE, smooth), (DROP_FRAMES, STARE, smooth)]
    pose = timeline(keys, frame, {"head": 2.0, "neck": 1.0, "trophy": 3.0})
    jerk = bump(frame / DROP_FRAMES, 0.78, 0.03, 0.06, 0.1)
    pose["head"] = add(pose["head"], (0.0, 0.0, 14.0 * jerk))
    return pose


RISE_FRAMES = 17
PUSH = gaze(pose_of(FOLD, hip=(0.0, 0.02, -0.25), trunk=(40.0, 0.0, 0.0), hand_l=(0.2, -0.55, 0.25),
                    hand_r=(0.18, -0.55, 0.25)), down=20.0)


def rise(frame):
    """Back up onto its legs: it shoves off its hands, the spine unrolls from the hips up, and the
    head comes up last."""
    keys = [(0, STARE, smooth), (5, PUSH, ease_out), (12, HUNCH, smooth), (RISE_FRAMES, HUNCH, smooth)]
    return timeline(keys, frame, {"head": 2.0, "neck": 1.0, "hand_l": 1.0, "hand_r": 1.5, "trophy": 3.0})


GATHERED = hang(gaze(pose_of(
    QUAD, hip=(0.0, 0.02, -0.33), trunk=(80.0, 0.0, 0.0), spine1=(4.0, 0.0, 0.0), spine2=(10.0, 0.0, 0.0),
    chest=(26.0, 0.0, 0.0), clav_l=(20.0, 24.0), clav_r=(20.0, 24.0), grip_l=(0.36, -0.74, WRIST_FLOOR),
    grip_r=(-0.36, -0.72, WRIST_FLOOR), elbow_l=35.0, elbow_r=35.0,
    foot_l=(0.2, 0.22, 0.16), foot_r=(-0.2, 0.24, 0.16), sole_l=(45.0, 15.0), sole_r=(45.0, -15.0),
    knee_l=22.0, knee_r=22.0), down=10.0))


def crouch(frame):
    """Before it pounces: the hind feet creep up under it, the haunches rise and wiggle side to side,
    the chest sinks between the raised elbows, and the head stays low, staring up at you."""
    keys = [(0, gallop(0.0), smooth), (7, GATHERED, ease_out), (WINDUP_FRAMES, GATHERED, smooth)]
    pose = timeline(keys, frame, {"head": 1.0, "neck": 0.5})
    t = frame / FPS
    wiggle = smooth((frame - 6) / 3.0) * math.sin(TAU * 3.2 * t)
    pose["hip"] = add(pose["hip"], (0.035 * wiggle, 0.0, 0.0))
    pose["pelvis"] = add(pose["pelvis"], (0.0, 10.0 * wiggle, 0.0))
    if frame >= 9:
        pose = tremble(pose, t, 2.0, seed=14)
    return hang(pose)


LEAP = gaze(pose_of(
    QUAD, hip=(0.0, -0.3, -0.28), trunk=(45.0, 0.0, 0.0), spine1=(4.0, 0.0, 0.0), spine2=(4.0, 0.0, 0.0),
    chest=(6.0, 0.0, 0.0), clav_l=(-6.0, 22.0), clav_r=(-6.0, 22.0), hand_l=(0.62, 0.22, 0.16),
    hand_r=(0.6, 0.26, 0.14), reach_l=0.0, reach_r=0.0, plant_l=0.0, plant_r=0.0, claw_l=-25.0, claw_r=-30.0,
    elbow_l=23.0, elbow_r=23.0, foot_l=(0.2, 0.55, 0.22), foot_r=(-0.2, 0.58, 0.2),
    sole_l=(70.0, 10.0), sole_r=(70.0, -10.0), toe_l=-30.0, toe_r=-30.0), down=0.0)
STRETCH = gaze(pose_of(
    LEAP, hip=(0.0, -0.45, -0.3), trunk=(50.0, 0.0, 0.0), hand_l=(0.62, 0.1, 0.12), hand_r=(0.6, 0.14, 0.1),
    foot_l=(0.18, 0.7, 0.4), foot_r=(-0.18, 0.72, 0.38), sole_l=(65.0, 10.0), sole_r=(65.0, -10.0)), down=4.0)
LANDED = gaze(pose_of(
    QUAD, hip=(0.0, -0.3, -0.42), trunk=(76.0, 0.0, 0.0), grip_l=(0.36, -1.0, WRIST_FLOOR),
    grip_r=(-0.36, -0.98, WRIST_FLOOR), claw_l=10.0, claw_r=10.0, foot_l=(0.2, 0.3, 0.2),
    foot_r=(-0.2, 0.32, 0.2)), down=10.0)
CRASHED = gaze(pose_of(
    LANDED, hip=(0.0, -0.25, -0.46), chest=(28.0, 0.0, 0.0), foot_l=(0.2, 0.28, 0.14), foot_r=(-0.2, 0.3, 0.14),
    sole_l=(35.0, 15.0), sole_r=(35.0, -15.0)), down=20.0)


def pounce(frame):
    """The strike on all fours: it launches at you claws first and stretches out flat in the air,
    slams down onto its hands well ahead, crashes low and heaves, then gathers back into the gallop."""
    keys = [(0, GATHERED, smooth), (3, LEAP, ease_in), (6, STRETCH, ease_out), (9, LANDED, ease_in),
            (12, CRASHED, ease_out), (17, CRASHED, smooth), (STRIKE_FRAMES, gallop(0.0), smooth)]
    pose = timeline(keys, frame, {"head": 0.5})
    if 12 <= frame <= 20:
        pose = tremble(pose, frame / FPS, 3.0, seed=16)
    return hang(pose)


FOURS_SCREAM_FRAMES = 38


def fours_scream(frame):
    """It sees you: rears up tall with its arms flung wide and its head thrown back, shrieks forward
    shaking, then drops onto all fours, slaps the ground, humps its back, lifts its head to stare at
    you, and launches into the gallop."""
    keys = [(0, HUNCH, smooth), (3, REAR, snap), (8, REAR, smooth), (10, SHRIEK, snap), (15, SHRIEK, smooth),
            (20, FOLD, ease_in), (23, SLAM, ease_in), (25, BOUNCE, ease_out), (29, ARCH, smooth),
            (34, STARE, smooth), (FOURS_SCREAM_FRAMES, gallop(0.0), smooth)]
    pose = timeline(keys, frame, DELAYS)
    if 3 <= frame <= 17:
        pose = tremble(pose, frame / FPS, 5.0 if frame >= 10 else 2.5)
    return pose


RECOIL_FOURS = hang(gaze(pose_of(
    QUAD, hip=(0.0, 0.12, -0.34), trunk=(66.0, 0.0, -6.0), chest=(14.0, 8.0, 0.0), clav_l=(4.0, 28.0),
    clav_r=(4.0, 28.0), grip_l=(0.36, -0.62, WRIST_FLOOR + 0.1), grip_r=(-0.36, -0.6, WRIST_FLOOR + 0.06),
    plant_l=0.3, plant_r=0.5, claw_l=-20.0, claw_r=-15.0, head=(0.0, 0.0, -18.0)), down=-20.0, turn=20.0))


def fours_flinch(frame):
    """Hit on all fours: it rears back off its hands, the head snapping up and away and the claws
    splayed, then drops back onto them."""
    keys = [(0, QUAD, smooth), (2, RECOIL_FOURS, snap), (5, RECOIL_FOURS, smooth), (FLINCH_FRAMES, QUAD, smooth)]
    pose = timeline(keys, frame, DELAYS)
    return hang(tremble(pose, frame / FPS, 4.0 * (1.0 - frame / FLINCH_FRAMES), seed=18))


FOURS_DEATH_FRAMES = round(1.6 * FPS)
SEIZE = hang(gaze(pose_of(
    QUAD, hip=(0.0, 0.1, -0.3), trunk=(60.0, 0.0, 8.0), chest=(10.0, -10.0, 6.0), clav_l=(0.0, 30.0),
    clav_r=(0.0, 26.0), grip_l=(0.4, -0.6, WRIST_FLOOR + 0.12), plant_l=0.2, claw_l=-30.0, claw_r=-25.0),
    down=-35.0, turn=-20.0))
GIVE = hang(gaze(pose_of(
    QUAD, hip=(0.0, 0.05, -0.45), trunk=(80.0, 0.0, -10.0), chest=(28.0, 0.0, -8.0),
    grip_l=(0.46, -0.66, WRIST_FLOOR), grip_r=(-0.44, -0.7, WRIST_FLOOR), elbow_l=40.0, elbow_r=40.0,
    foot_l=(0.22, 0.52, 0.18), foot_r=(-0.2, 0.57, 0.18)), down=30.0))


# Sinking over its knees, the feet lifting off the floor before the body lands.
SLUMP = gaze(pose_of(
    GIVE, hip=(0.0, 0.05, -0.56), trunk=(82.0, 0.0, -12.0), foot_l=(0.2, 0.66, 0.32), foot_r=(-0.16, 0.66, 0.3),
    trophy=(0.0, 0.0, 0.0)), down=40.0)


def fours_death(frame):
    """Killed on all fours: it jerks up off its hands with its head thrown back, the elbows give, the
    chest drops, it slumps flat with the arms sprawled, a hand twitches once, and it stays down."""
    twitch = bump(frame / FOURS_DEATH_FRAMES, 0.8, 0.02, 0.03, 0.08)
    keys = [(0, QUAD, smooth), (3, SEIZE, snap), (9, GIVE, ease_in), (13, SLUMP, smooth), (17, PRONE, ease_in),
            (FOURS_DEATH_FRAMES, PRONE, smooth)]
    # The pendant swings flat against the chest as it lands, with no lag that would sink it into the floor.
    pose = timeline(keys, frame, {key: delay for key, delay in DELAYS.items() if key != "trophy"})
    if frame > 17:
        pose["claw_r"] = PRONE["claw_r"] - 40.0 * twitch
    if frame <= 9:
        pose = tremble(pose, frame / FPS, 4.0, seed=20)
    return pose


# Clip names follow the enemy contract (lowercase; see the godot-3d-enemy-pipeline skill). The
# gameplay states map onto them in scenes/monsters/the_ridgeback/ridgeback_visual.gd. The fours_
# clips are the four-legged set; fours_drop and fours_rise carry it between standing and all fours.
CLIPS = [
    Clip("idle", 96, True, idle, (2.0, 0.3)),
    Clip("watch", 72, True, watch, (2.4, 0.35)),
    Clip("walk", STALK_FRAMES, True, stalk, (2.2, 0.32)),
    Clip("run", SPRINT_FRAMES, True, sprint, (5.0, 0.45)),
    Clip("scream", SCREAM_FRAMES, False, scream, (3.2, 0.32)),
    Clip("windup", WINDUP_FRAMES, False, windup, (3.5, 0.4)),
    Clip("attack", STRIKE_FRAMES, False, strike, (4.5, 0.38)),
    Clip("hit", FLINCH_FRAMES, False, flinch, (3.5, 0.3)),
    Clip("death", DEATH_FRAMES, False, death, (3.0, 0.45)),
    Clip("fours_scream", FOURS_SCREAM_FRAMES, False, fours_scream, (3.2, 0.32)),
    Clip("fours_drop", DROP_FRAMES, False, drop, (3.5, 0.4)),
    Clip("fours_lurk", 72, True, lurk, (3.0, 0.4)),
    Clip("fours_prowl", PROWL_FRAMES, True, prowl, (4.0, 0.5)),
    Clip("fours_gallop", GALLOP_FRAMES, True, gallop, (7.0, 0.6)),
    Clip("fours_crouch", WINDUP_FRAMES, False, crouch, (3.5, 0.45)),
    Clip("fours_pounce", STRIKE_FRAMES, False, pounce, (5.0, 0.4)),
    Clip("fours_rise", RISE_FRAMES, False, rise, (3.0, 0.4)),
    Clip("fours_hit", FLINCH_FRAMES, False, fours_flinch, (3.5, 0.3)),
    Clip("fours_death", FOURS_DEATH_FRAMES, False, fours_death, (3.0, 0.45)),
]


def author(rig: Rig, clip: Clip):
    """Keys one clip into a new action on the rig, frame 0 to clip.frames."""
    import bpy

    poses = [clip.pose((frame % clip.frames) / clip.frames if clip.loop else float(frame))
             for frame in range(clip.frames + 1)]
    if clip.spring:
        follow(rig, poses, clip.spring, clip.loop)
    action = bpy.data.actions.new(clip.name)
    action.use_fake_user = True
    rig.object.animation_data_create()
    rig.object.animation_data.action = action
    shortfall = 0.0
    for frame, pose in enumerate(poses):
        shortfall = max(shortfall, apply(rig, pose))
        rig.key(frame)
    action["shortfall"] = shortfall
    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = clip.frames
    action.use_cyclic = clip.loop
    return action
