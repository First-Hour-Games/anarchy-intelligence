"""Where the parts of the double-barrelled shotgun are, shared by tools/blender/build_shotgun.py (the model)
and the first-person clips that hold it.

Blender axes in the gun's own space: the barrels point along +Y, up is +Z, the right side is +X. The
origin is the middle of the stock's wrist, where the right hand's fist closes round it, so the gun
hangs from the right hand the way the pipe does. Metres. A side-by-side 12 gauge coach gun with 18 inch
barrels, a little under a metre long, built bulkier than the real thing: the wrist is about as thick as the
pipe the fists were posed round (5.6 cm across).

The barrels and the fore-end under them are one part, which swings down on the hinge pin to open the
breech for loading.
"""

from mathutils import Vector

GRIP = Vector((0.0, 0.0, 0.0))
# The wrist of the stock runs from behind the fist up into the action; a fist round it has this as the
# line through it, toward the action.
GRIP_AXIS = Vector((0.0, 1.0, 0.25)).normalized()
WRIST = (0.024, 0.028)                                          # half width and half height at the fist
ACTION = ((-0.040, 0.035, -0.020), (0.040, 0.155, 0.054))       # box corners; the breech face is its front
BORE_Z = 0.032                                                  # both barrels' centre lines
BARREL_X = 0.0205                                               # each barrel's centre line, either side
BARREL = (0.155, 0.62, 0.0195)                                  # from y, to y, radius
HINGE = Vector((0.0, 0.155, -0.012))                            # the pin the barrels swing down on, along X
FORE_END = (0.165, 0.39, -0.002, 0.030, 0.025)                   # from y, to y, centre z, half width, half height
FORE_END_GRIP = Vector((0.0, 0.28, -0.002))                     # the left hand closes round the fore-end here
MUZZLES = (Vector((-BARREL_X, BARREL[1], BORE_Z)), Vector((BARREL_X, BARREL[1], BORE_Z)))
BREECH = Vector((0.0, BARREL[0], BORE_Z))                       # shells go in here, with the barrels open
BREAK_ANGLE = 55.0                                              # degrees the barrels drop to open: wide enough that
                                                                # the shells go in clear of the action
# A 12 gauge shell: a red hull with a brass head and its rim at the back.
SHELL_LENGTH = 0.068
SHELL_RADIUS = 0.0105
SHELL_HEAD = 0.014                                              # how long the brass head is
SHELL_RIM = 0.0118                                              # the rim's radius
BUTT = Vector((0.0, -0.36, -0.054))                             # the middle of the butt pad, against the shoulder
