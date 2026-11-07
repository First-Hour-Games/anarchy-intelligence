"""Joint check for The Ridgeback's authored clips: how far every joint bends and twists, frame by
frame, against the ranges a body like this one can take without looking broken.

blender --background --factory-startup --disable-autoexec --python tools/blender/ridgeback/anatomy.py \
    -- [clip names...]

Authors the clips onto the creator's rig (the file is never saved), then for every frame reads each
bone's rotation from its parent, as the rig's IK and constraints left it, and splits it into the
twist about the bone's own length and the swing of that length. Reports the worst frame for every
joint that leaves its range, every hand or foot that could not reach its target, and the lowest
point of the mesh where it goes through the floor.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import clips  # noqa: E402
from rig import Rig  # noqa: E402

SOURCE = HERE.parents[2] / "models" / "source" / "the_ridgeback" / "vendor" / "THE_RIDGEBACK.blend"

# (bone, largest twist about its length, largest swing of its length), degrees, from its parent.
# Generous for a creature, but past these the skin of a single-bone joint folds or wrings.
LIMITS = {
    "upperarm": (80.0, 150.0),
    "forearm": (35.0, 150.0),   # one bone, no forearm twist: the elbow is a hinge
    "hand": (45.0, 80.0),
    "thigh": (55.0, 130.0),   # a hip rolls further than it turns actively, as legs do lying down
    "calf": (25.0, 150.0),      # the knee is a hinge
    "foot": (25.0, 70.0),
    "neck": (40.0, 60.0),
    "head": (45.0, 55.0),
    "spine_01": (25.0, 35.0),
    "spine_02": (25.0, 35.0),
    "chest": (25.0, 35.0),
}
REACH = 0.02                     # a hand or foot this far from its target is not where the clip put it


def twist_swing(rotation: Quaternion):
    """Twist about the local Y (the bone's length) and the swing of that length, in degrees."""
    rotation = rotation.normalized()
    twist = Quaternion((rotation.w, 0.0, rotation.y, 0.0))
    if twist.magnitude < 1e-6:
        return 180.0, math.degrees(rotation.angle)
    twist.normalize()
    swing = rotation @ twist.inverted()
    twist_angle = math.degrees(2.0 * math.atan2(twist.y, twist.w))
    twist_angle = (twist_angle + 180.0) % 360.0 - 180.0
    return twist_angle, math.degrees(swing.angle) if swing.angle <= math.pi else 360.0 - math.degrees(swing.angle)


def local_rotation(armature, name):
    bone = armature.pose.bones[name]
    parent = bone.parent
    rest = parent.bone.matrix_local.inverted() @ bone.bone.matrix_local
    posed = parent.matrix.inverted() @ bone.matrix
    return (rest.inverted() @ posed).to_quaternion()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
    armature = bpy.data.objects["PSX_Rig"]
    mesh = bpy.data.objects["ManThing_PSX"]
    rig = Rig(armature)
    for clip in (clip for clip in clips.CLIPS if not argv or clip.name in argv):
        check(armature, mesh, clip, clips.author(rig, clip))


def check(armature, mesh, clip, action):
    """Prints the clip's report and returns its problems: joints out of range or mesh through the
    floor. A limb pulled in to stay bent is reported but is not a problem. A legless clip, which only
    the crawler plays, is checked without its legs (clips.LEGS) and their skin."""
    scene = bpy.context.scene
    armature.animation_data.action = action
    armature.animation_data.action_slot = action.slots[0]
    worst = {}
    reach = {}
    floor = (0.0, 0, "")
    legless = getattr(clip, "legless", False)
    cut = {mesh.vertex_groups[name].index for name in clips.LEGS if name in mesh.vertex_groups} if legless else set()
    kept = [vertex.index for vertex in mesh.data.vertices
            if not vertex.groups or max(vertex.groups, key=lambda group: group.weight).group not in cut]
    for frame in range(clip.frames + (0 if clip.loop else 1)):
        scene.frame_set(frame)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        for side in ("l", "r"):
            for stem, (twist_limit, swing_limit) in LIMITS.items():
                name = stem + "_" + side if stem in ("upperarm", "forearm", "hand", "thigh", "calf", "foot") else stem
                if name in clips.LEGS and legless:
                    continue
                if name in worst and stem not in ("upperarm", "forearm", "hand", "thigh", "calf", "foot") and side == "r":
                    continue
                twist, swing = twist_swing(local_rotation(armature, name))
                over = max(abs(twist) - twist_limit, swing - swing_limit)
                if over > worst.get(name, (0.0,))[0]:
                    worst[name] = (over, frame, twist, swing)
            for limb, target in (("hand_" + side, "hand_ik_" + side), ("foot_" + side, "foot_ik_" + side)):
                if limb in clips.LEGS and legless:
                    continue
                miss = (armature.pose.bones[limb].head - armature.pose.bones[target].head).length
                if miss > reach.get(limb, (0.0,))[0]:
                    reach[limb] = (miss, frame)
        evaluated = mesh.evaluated_get(depsgraph)
        data = evaluated.to_mesh()
        index, lowest = min(((index, (evaluated.matrix_world @ data.vertices[index].co).z) for index in kept),
                            key=lambda item: item[1])
        evaluated.to_mesh_clear()
        if lowest < floor[0]:
            groups = mesh.data.vertices[index].groups
            part = max(groups, key=lambda group: group.weight).group if len(groups) else -1
            floor = (lowest, frame, mesh.vertex_groups[part].name if part >= 0 else "?")
    problems = ["%s twist %+.0f swing %.0f (frame %d, %.0f over)" % (name, twist, swing, frame, over)
                for name, (over, frame, twist, swing) in sorted(worst.items(), key=lambda item: -item[1][0])]
    misses = ["%s %.2f m short (frame %d)" % (limb, miss, frame)
              for limb, (miss, frame) in sorted(reach.items(), key=lambda item: -item[1][0]) if miss > REACH]
    print("CLIP %-13s joints: %s" % (clip.name, "; ".join(problems) or "all in range"))
    if misses:
        print("     %-13s reach:  %s" % ("", "; ".join(misses)))
    if action.get("shortfall", 0.0) > REACH:
        print("     %-13s pulled in: %.2f m to keep a limb bent" % ("", action["shortfall"]))
    if floor[0] < -0.01:
        print("     %-13s floor:  %.2f m below (frame %d, %s)" % ("", -floor[0], floor[1], floor[2]))
        problems.append("%.2f m through the floor at frame %d (%s)" % (-floor[0], floor[1], floor[2]))
    return problems


if __name__ == "__main__":
    main()
