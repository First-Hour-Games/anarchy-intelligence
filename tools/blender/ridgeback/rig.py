"""Posing helpers for The Ridgeback's control rig: the creator's PSX_Rig in THE_RIDGEBACK.blend.

Everything is in the rig's armature space, in Blender axes: the creature faces -Y, its left is +X,
up is +Z, and the floor is z = 0. Angles are degrees about the body's own axes: bend tips a bone
forward (and a forward-pointing foot's toe down), turn swings it toward the creature's left, and tilt
leans it toward its left. A bone's rotation is applied at its head, on top of its parent's, so equal
bends down a chain add up the way a spine curls.

The arms and legs between the shoulders, hips, hands and feet are solved by the rig's own IK: a clip
poses the body by rotation, then places the hand and foot targets and the elbow and knee poles.
"""

import math

import bpy
from mathutils import Matrix, Quaternion, Vector

# Controls parented to the rig's root: placed by position and keyed by location and rotation.
PLACED = ("torso", "foot_ik_l", "foot_ik_r", "hand_ik_l", "hand_ik_r", "pole_knee_l", "pole_knee_r",
          "pole_elbow_l", "pole_elbow_r")
# Bones posed by rotation alone.
TURNED = ("hips", "spine_01", "spine_02", "chest", "neck", "head", "clavicle_l", "clavicle_r",
          "toe_l", "toe_r", "trophy")
FORWARD = Vector((0.0, -1.0, 0.0))
UP = Vector((0.0, 0.0, 1.0))
LEFT = Vector((1.0, 0.0, 0.0))
SIDES = {"l": 1.0, "r": -1.0}


def rotation(bend=0.0, turn=0.0, tilt=0.0):
    """A rotation in body axes: turn about +Z, then bend about +X, then tilt about +Y."""
    return (Quaternion((0.0, 0.0, 1.0), math.radians(turn))
            @ Quaternion((1.0, 0.0, 0.0), math.radians(bend))
            @ Quaternion((0.0, 1.0, 0.0), math.radians(tilt)))


def split(turned):
    """A bone's rotation as its twist about its own length (local Y) and the swing that follows."""
    turned = turned.normalized()
    twist = Quaternion((turned.w, 0.0, turned.y, 0.0))
    if twist.magnitude < 1e-6:
        return Quaternion(), turned
    twist.normalize()
    return twist, turned @ twist.inverted()


def capped(turned, limit):
    """The same rotation, turned no further than `limit` degrees."""
    if turned.w < 0.0:
        turned = -turned
    axis, angle = turned.to_axis_angle()
    return Quaternion(axis, min(angle, math.radians(limit)))


def limited(turned, twist_limit, swing_limit):
    """A joint's rotation kept inside its twist and swing ranges."""
    twist, swing = split(turned)
    return capped(swing, swing_limit) @ capped(twist, twist_limit)


def aim(direction, up, rest_direction, rest_up):
    """The rotation that turns a rest frame (its direction and up) onto a new one."""
    def frame(pointing, upward):
        pointing = Vector(pointing).normalized()
        side = pointing.cross(Vector(upward)).normalized()
        return Matrix((pointing, side, side.cross(pointing))).transposed()
    return (frame(direction, up) @ frame(rest_direction, rest_up).inverted()).to_quaternion()


class Rig:
    def __init__(self, armature):
        self.object = armature
        self.bones = armature.pose.bones
        self.rest = {bone.name: bone.matrix_local.copy() for bone in armature.data.bones}

    def rest_head(self, name):
        return self.rest[name].translation.copy()

    def clear(self):
        for bone in self.bones:
            bone.location = (0.0, 0.0, 0.0)
            bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
            bone.scale = (1.0, 1.0, 1.0)

    def turn(self, name, turned):
        """Rotates a bone at its head by a body-axes rotation, on top of its parent."""
        rest = self.rest[name].to_quaternion()
        self.bones[name].rotation_quaternion = rest.inverted() @ turned @ rest

    def place(self, name, position, turned=None):
        """Puts a root-parented control at an armature-space position, turned from its rest."""
        rest = self.rest[name]
        resting = rest.to_quaternion()
        self.bones[name].location = resting.inverted() @ (Vector(position) - rest.translation)
        self.bones[name].rotation_quaternion = resting.inverted() @ (turned or Quaternion()) @ resting

    def evaluate(self):
        bpy.context.view_layer.update()

    def head(self, name):
        """Where a bone's head is now, in armature space. Call evaluate first."""
        return self.bones[name].head.copy()

    def body_axes(self, name):
        """A bone's forward, up and left after posing, as the body axes it carries. Call evaluate first."""
        turned = self.bones[name].matrix.to_quaternion() @ self.rest[name].to_quaternion().inverted()
        return turned @ FORWARD, turned @ UP, turned @ LEFT

    def rest_turn(self, name):
        return self.rest[name].to_quaternion()

    def length(self, *names):
        return sum(self.object.data.bones[name].length for name in names)

    def turned_from_rest(self, name):
        """How far a bone has turned from its rest, in armature space. Call evaluate first."""
        return self.bones[name].matrix.to_quaternion() @ self.rest_turn(name).inverted()

    def raise_by(self, name, height):
        """Lifts a root-parented control straight up, keeping its rotation."""
        self.bones[name].location += self.rest_turn(name).inverted() @ Vector((0.0, 0.0, height))

    def local_turn(self, name, parent, world):
        """The rotation a bone needs, relative to its posed parent, to face `world` in armature space.
        The hands and feet copy their IK targets' rotation in local space, so this is what the target
        gets. Call evaluate first, so the parent is posed."""
        parent_now = self.bones[parent].matrix.to_quaternion()
        return (self.rest_turn(name).inverted() @ self.rest_turn(parent) @ parent_now.inverted() @ world)

    def key(self, frame):
        for name in PLACED:
            self.bones[name].keyframe_insert("location", frame=frame, group=name)
            self.bones[name].keyframe_insert("rotation_quaternion", frame=frame, group=name)
        for name in TURNED:
            self.bones[name].keyframe_insert("rotation_quaternion", frame=frame, group=name)
