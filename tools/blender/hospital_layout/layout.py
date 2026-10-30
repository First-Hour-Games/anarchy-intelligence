"""Hospital V2 ground floor layout data ("horror" designer). Game metres, hospital-local.

x east(+)/west(-), z = 0 at the facade and negative into the building, y up.
Walls: centreline endpoints; base at FLOOR; height to the slab.
Objects: x,z = footprint centre, y = base (bottom), size = [w_x, h_y, d_z] before yaw.
Yaw follows Godot: +90 turns local +Z to face +X.
"""

FLOOR = 0.12
SLAB = 3.39
CEIL = 2.90
WALL_H = round(SLAB - FLOOR, 2)  # 3.27
LT = 0.12   # perimeter lining
PT = 0.15   # partitions
DOOR_HEAD = 2.25

def win(center_along, width, head):
    return dict(kind="window", center_along=round(center_along, 3), width=round(width, 3), sill=0.54, head=head, door_state="none")

def door(center_along, width, state="open", head=DOOR_HEAD):
    return dict(kind="door", center_along=round(center_along, 3), width=round(width, 3), sill=FLOOR, head=head, door_state=state)

def pas(center_along, width, sill, head):
    return dict(kind="pass_through", center_along=round(center_along, 3), width=round(width, 3), sill=sill, head=head, door_state="none")

def front_along(x):
    return x + 20.16

walls = []

def wall(id, x1, z1, x2, z2, t=PT, openings=()):
    walls.append(dict(id=id, x1=x1, z1=z1, x2=x2, z2=z2, thickness=t, height=WALL_H, openings=list(openings)))

# ---------------- perimeter linings (room face exactly on the given inner faces)
wall("P_Front", -20.16, -0.24, 17.76, -0.24, LT, [
    win(front_along(-18.09), 2.48, 2.10),          # W1 [-19.33,-16.85]
    win(front_along(-14.43), 2.48, 2.10),          # W2 [-15.67,-13.19]
    win(front_along(-11.885), 0.25, 2.10),         # W3 remnant [-12.01,-11.76] (sidelight)
    door(front_along(-10.20), 3.12, "open", 2.70), # gameplay entrance [-11.76,-8.64]
    win(front_along(-7.11), 2.48, 2.10),           # W4 [-8.35,-5.87]
    door(front_along(-2.76), 2.40, "locked_blocked", 1.80),  # tower glass doors [-3.96,-1.56]
    win(front_along(1.605), 1.55, 1.98),
    win(front_along(4.08), 1.54, 1.98),
    win(front_along(6.555), 1.55, 1.98),
    win(front_along(9.045), 1.55, 1.98),
    win(front_along(11.52), 1.54, 1.98),
    win(front_along(13.995), 1.55, 1.98),
])
wall("P_Back", -20.16, -9.36, 17.76, -9.36, LT, [
    win(front_along(1.59), 1.54, 1.98),
    win(front_along(4.06), 1.54, 1.98),
    win(front_along(6.53), 1.54, 1.98),
    win(front_along(9.00), 1.54, 1.98),
    win(front_along(11.475), 1.55, 1.98),
    win(front_along(13.94), 1.54, 1.98),
    win(front_along(16.41), 1.54, 1.98),
])
wall("P_West", -20.16, -0.24, -20.16, -9.36, LT, [])
wall("P_East", 17.76, -0.24, 17.76, -9.36, LT, [
    win(-0.24 + 1.17, 1.22, 1.98),   # z [-0.56,-1.78]
    win(-0.24 + 3.84, 1.28, 1.98),   # z [-3.20,-4.48]  (corridor end window)
    win(-0.24 + 6.00, 1.28, 1.98),   # z [-5.36,-6.64]
    win(-0.24 + 8.16, 1.28, 1.98),   # z [-7.52,-8.80]
])

# ---------------- south line z=-5.25 (back rooms / corridor south wall), split per room
wall("S1_StoresFront", -20.10, -5.25, -14.60, -5.25, PT, [door(-17.0 + 20.10, 1.6, "open")])
wall("S2_IsolationFront", -14.60, -5.25, -11.40, -5.25, PT, [door(-13.9 + 14.60, 1.0, "locked_blocked")])
# Door at the east end, clear of the reception counter, so navigation reaches the office.
wall("S3_OfficeFront", -11.40, -5.25, -7.40, -5.25, PT, [door(-8.2 + 11.40, 1.5, "open")])
wall("S4_StairFront", -7.40, -5.25, -4.20, -5.25, PT, [door(-6.2 + 7.40, 1.0, "locked_blocked")])
wall("S5_LinenFront", -4.20, -5.25, 0.20, -5.25, PT, [door(-1.6 + 4.20, 1.6, "open")])
wall("S6_WardFront", 0.20, -5.25, 7.765, -5.25, PT, [door(1.5 - 0.20, 1.6, "open")])
wall("S7_RecordsFront", 7.765, -5.25, 12.71, -5.25, PT, [door(8.75 - 7.765, 1.6, "open")])
wall("S8_LoungeFront", 12.71, -5.25, 17.70, -5.25, PT, [door(14.3 - 12.71, 1.6, "open")])

# ---------------- corridor north wall z=-3.05 (east wing)
wall("N1_ProcedureFront", 0.20, -3.05, 5.315, -3.05, PT, [door(2.8 - 0.20, 1.6, "open")])
wall("N2_NurseFront", 5.315, -3.05, 10.285, -3.05, PT, [
    door(6.25 - 5.315, 1.5, "open"),
    pas(8.2 - 5.315, 1.8, 1.19, 2.25),
])
wall("N3_DayRoomFront", 10.285, -3.05, 17.70, -3.05, PT, [door(15.6 - 10.285, 1.6, "open")])

# ---------------- east-wing front dividers (front lining to corridor wall)
wall("D1_TowerProcedure", 0.20, -0.30, 0.20, -3.05, PT, [door(1.55 - 0.30, 1.5, "open")])
wall("D2_ProcedureNurse", 5.315, -0.30, 5.315, -3.05, PT, [door(2.15 - 0.30, 1.5, "open")])
wall("D3_NurseDayRoom", 10.285, -0.30, 10.285, -3.05, PT, [door(2.15 - 0.30, 1.5, "open")])

# ---------------- back-room dividers (south line to back lining)
wall("BD1_StoresIsolation", -14.60, -5.25, -14.60, -9.30, PT, [])
wall("BD2_IsolationOffice", -11.40, -5.25, -11.40, -9.30, PT, [])
wall("BD3_OfficeStair", -7.40, -5.25, -7.40, -9.30, PT, [])
wall("BD4_StairLinen", -4.20, -5.25, -4.20, -9.30, PT, [])
wall("BD5_LinenWard", 0.20, -5.25, 0.20, -9.30, PT, [door(6.30 - 5.25, 1.5, "open")])
wall("BD6_WardRecords", 7.765, -5.25, 7.765, -9.30, PT, [door(6.2 - 5.25, 1.6, "open")])
wall("BD7_RecordsLounge", 12.71, -5.25, 12.71, -9.30, PT, [])

# ---------------- west wing front dividers
wall("L1_ShelterLobby", -12.60, -0.30, -12.60, -5.25, PT, [door(2.0 - 0.30, 2.0, "open")])
wall("L2_LobbyTower", -4.20, -0.30, -4.20, -2.50, PT, [])

# ---------------- rooms
rooms = [
    dict(name="Shelter Hall (old Outpatients Waiting, Hall A)", purpose="Makeshift dormitory of the emergency shelter: rows of camp cots, belongings, privacy screens, water station; outside the Clawman's territory, the calm 'unease' beat", x_min=-20.10, x_max=-12.60, z_min=-5.25, z_max=-0.30, floor_finish="speckled beige vinyl tile, grubby, blankets and litter on the floor", wall_finish="cream painted block, 1.2 m pale-green dado, vinyl cove skirting; children's drawings taped up", mood="warm lantern pool in an otherwise dark room; boarded window, a blanket over the other; lived-in, abandoned mid-night"),
    dict(name="Lobby & Reception", purpose="Arrival space behind the broken sliding doors; registration counter facing the entrance (document 1), waiting seats, directory sign, wheelchair facing the door", x_min=-12.60, x_max=-4.20, z_min=-5.25, z_max=-0.30, floor_finish="terrazzo-look grey vinyl tile with a wet-look sheen, glass shards and a fallen door leaf at the entrance", wall_finish="cream paint over block, blue accent band at 2.1 m with a blue/white 'H' logo, notice boards", mood="a single flickering fluorescent over the counter, red EXIT glow at the door, everything else in shadow"),
    dict(name="Tower Hall (old main entrance)", purpose="Threshold hub under the tower: glass main doors barricaded from inside around a still-glowing vending machine, abandoned stretcher; first clear view down the corridor; branches to the corridor, Procedure Room 1 (north loop) and Linen & Changing (south loop)", x_min=-4.20, x_max=0.20, z_min=-5.25, z_max=-0.30, floor_finish="same lobby vinyl, scuffed drag marks toward the barricade", wall_finish="cream paint, blue accent band; plywood screwed over the door frame", mood="dark, cold blue vending-machine glow, red EXIT sign; the barricade reads as 'they were keeping something out'"),
    dict(name="Main Corridor", purpose="27 m spine from the tower hall to the moonlit east window; Clawman post; every east-wing room opens off it", x_min=0.20, x_max=17.70, z_min=-5.25, z_max=-3.05, floor_finish="pale green sheet vinyl with a darker centre stripe, scuffed", wall_finish="cream paint, timber-look bumper rails at 0.85-0.99 m both sides, projecting room signs", mood="red emergency lights at both ends, one strobing tube mid-way, a long silver shaft of moonlight from the end window"),
    dict(name="Procedure Room 1", purpose="Minor procedures: reclining exam chair under a dead surgical lamp, IV pole, trolley, scrub sink; supply-closet hiding spot; three doors (tower hall, corridor, nurse station) make it the north chase loop at the threshold", x_min=0.20, x_max=5.315, z_min=-3.05, z_max=-0.30, floor_finish="light grey seamless vinyl with coved edges", wall_finish="white wipe-clean panels, steel corner guards", mood="dark, dim skylight through half-closed blinds, the dead surgical lamp hanging like a face"),
    dict(name="Nurse Station (Ward B)", purpose="Staff hub with a pass-through counter onto the corridor, patient whiteboard naming Carrie in Bed 3, medication cabinet, monitor cart; front-route link", x_min=5.315, x_max=10.285, z_min=-3.05, z_max=-0.30, floor_finish="pale green sheet vinyl", wall_finish="cream paint, pin boards, whiteboard", mood="a dying fluorescent with long dark gaps; moonless front windows"),
    dict(name="Day Room", purpose="Patients' lounge: armchairs facing the windows, upright piano, static-filled TV, wheelchair facing the moonlit east window", x_min=10.285, x_max=17.70, z_min=-3.05, z_max=-0.30, floor_finish="worn wood-look vinyl plank", wall_finish="faded floral wallpaper above a cream dado", mood="brightest room in the building: silver moonlight from three windows, flickering TV snow"),
    dict(name="Medical Stores", purpose="Steel shelving of supplies; the medical stores log (document 3) teaches the Clawman rules; first bottle; safe tutorial space", x_min=-20.10, x_max=-14.60, z_min=-9.30, z_max=-5.25, floor_finish="grey sealed concrete-look vinyl", wall_finish="painted block, no windows", mood="pitch dark, flashlight only, shelves stripped bare"),
    dict(name="Isolation 104 (sealed)", purpose="Locked, barricaded room with 'DON'T ANSWER IT' on the door; interior not built (void); optional whisper audio source", x_min=-14.60, x_max=-11.40, z_min=-9.30, z_max=-5.25, floor_finish="not built (void)", wall_finish="not built (void)", mood="never seen; heard"),
    dict(name="Shelter Office (old Admissions)", purpose="The shelter's command post behind reception: desk with radio and log, filing cabinet, staff cot, town map with the evacuation route torn off; second bottle", x_min=-11.40, x_max=-7.40, z_min=-9.30, z_max=-5.25, floor_finish="blue-grey carpet tile, stained", wall_finish="cream paint, cork board", mood="dark, a radio hiss (audio) and papers everywhere"),
    dict(name="Stair 1 (sealed)", purpose="Tower stair to the closed upper floors; chained door, 'UPPER FLOORS CLOSED' sign; interior not built (void)", x_min=-7.40, x_max=-4.20, z_min=-9.30, z_max=-5.25, floor_finish="not built (void)", wall_finish="not built (void)", mood="chained shut"),
    dict(name="Linen & Changing", purpose="Staff changing room with two lockers (hiding), linen shelving, laundry cart, equipment stand; doors to the tower hall and the ward make it the south chase loop at the threshold; third bottle", x_min=-4.20, x_max=0.20, z_min=-9.30, z_max=-5.25, floor_finish="grey safety vinyl with a wet patch", wall_finish="white glazed tile to 1.5 m, paint above", mood="dark, a slow drip (audio), smell of bleach"),
    dict(name="Treatment Ward (Ward B)", purpose="Three-bed bay under the back windows where Carrie was admitted: two hideable ward beds, Carrie's curtained Bed 3 with her belongings, wall basin; doors to the corridor, Linen & Changing and Staff Records form the hidden back route", x_min=0.20, x_max=7.765, z_min=-9.30, z_max=-5.25, floor_finish="pale green sheet vinyl", wall_finish="cream paint, bed-head service rails, curtain tracks on the ceiling", mood="moonlight in pale bars across the beds; one drawn curtain backlit with a sitting shape behind it"),
    dict(name="Staff Records", purpose="Ward office and staff locker bank: records desk with the evacuation notice (document 2) under a still-burning desk lamp, filing cabinets, three lockers; two exits (corridor, ward)", x_min=7.765, x_max=12.71, z_min=-9.30, z_max=-5.25, floor_finish="blue-grey carpet tile, spilled files", wall_finish="cream paint, evacuation-plan diagram and staff rota on a pin board", mood="one warm desk lamp island, moonlight through two windows, everything else black"),
    dict(name="Staff Lounge", purpose="Dead-end kitchenette and break room: counter with a bottle, fridge left ajar and glowing, table and chairs, sofa; calendar circled 'EVAC'", x_min=12.71, x_max=17.70, z_min=-9.30, z_max=-5.25, floor_finish="worn wood-look vinyl plank", wall_finish="pale yellow paint, notice board", mood="moonlight from three windows, the fridge's cold glow, half-eaten meal"),
]

# ---------------- blender objects (lead-modelled)
objects = []

def obj(name, kind, x, y, z, rot, size, notes, block=True, segments=None):
    objects.append(dict(name=name, kind=kind, x=round(x, 3), y=round(y, 3), z=round(z, 3), rotation_deg=rot, size=[round(v, 3) for v in size], notes=notes, block=block, segments=segments))

# structure
obj("GroundFloor", "floor_slab", -1.20, 0.00, -4.80, 0, [37.80, 0.12, 9.00], "Interior floor slab, top y=0.12. Keep 'GroundFloor' in the name (footstep classifier -> tile). Vinyl finishes per room as material zones (see rooms).", block=False)
obj("CeilingGrid", "drop_ceiling", -1.20, 2.90, -4.80, 0, [37.80, 0.04, 9.00], "Suspended 600x1200 acoustic tile grid, underside y=2.90, walls run through it to the slab. Leave 4 tiles missing in the Tower Hall (x -3.0..-1.0, z -2.0..-3.2) and 3 in the ward (x 2.0..3.2, z -6.0..-6.6) showing black plenum; one tile hangs in the corridor (see CorridorSaggingTile).", block=False)
obj("CeilingLightFixtures", "light_fixture_set", -1.20, 2.86, -4.80, 0, [37.80, 0.04, 9.00], "Recessed 600x1200 fluorescent troffers, flush with the grid (emissive off unless a light marker sits at the fixture). One per ~10 m2: corridor at x=2.5, 6.0, 9.5, 13.0, 16.0 (z=-4.15); every room 2-4 on a 2.4 m grid. Purely visual, no collision needed.", block=False)
# entrance
obj("EntranceDoorFrame", "door_frame", -10.20, 0.12, -0.36, 0, [3.12, 2.58, 0.12], "Aluminium sliding-door frame fixed to the inner face of the entrance opening (z -0.30 to -0.42): jambs 0.08 wide at x [-11.76,-11.68] and [-8.72,-8.64], overhead track and operator box y 2.50-2.70, floor guide. Open centre 2.96 m.", block=False)
obj("EntranceLeafWest_Jammed", "door_leaf", -11.67, 0.12, -0.455, 0, [1.56, 2.45, 0.05], "West bi-parting sliding leaf jammed open, parked behind the frame in front of the W3 sidelight; frame dented, glass crazed. Clear entrance between x -10.89 and -8.64 (2.25 m).")
obj("EntranceLeafEast_Fallen", "door_leaf", -9.32, 0.12, -1.85, 0, [1.56, 0.05, 2.45], "East leaf torn off its track and lying flat on the floor, glass gone, aluminium frame bent. Walkable 5 cm step.", block=False)
obj("EntranceGlassShards", "debris", -9.75, 0.12, -1.325, 0, [2.10, 0.01, 1.75], "Scatter of tempered-glass cubes and a muddy entrance mat (single low mesh, no meaningful collision).", block=False)
obj("EntranceBannerShelter", "sign_hanging", -10.20, 2.30, -0.60, 0, [2.80, 0.55, 0.02], "Bedsheet banner hung from the ceiling grid on cord, hand-painted: 'EMERGENCY SHELTER - ALL ARRIVALS REGISTER AT DESK'. Reads from the doorway.")
# lobby
obj("ReceptionDesk", "counter", -10.20, 0.12, -3.775, 0, [3.00, 1.10, 0.75], "Registration/admissions counter facing the entrance (+Z). Transaction ledge top y=1.22 (front 0.3 m), staff work surface y=0.87 behind; modesty panel with blue 'REGISTRATION' lettering. Register book (document 1) on the ledge. Name kept for the floor-rest test.")
obj("ReceptionSignHanging", "sign_hanging", -10.20, 2.35, -3.75, 0, [2.00, 0.40, 0.02], "'ADMISSIONS - SHELTER REGISTRATION' hanging sign on chains.")
obj("LobbyNoticeBoard", "notice_board", -11.65, 1.10, -5.165, 0, [1.60, 0.90, 0.02], "Cork board on the wall behind the counter: shelter rules (lights out 22:00, register every arrival, stay in Hall A after dark), 'HAVE YOU SEEN' missing-person sheets.")
obj("LobbyEvacuationPlan", "sign_wall", -12.515, 1.30, -0.65, 0, [0.02, 0.45, 0.50], "Framed 'YOU ARE HERE' fire evacuation plan of this ground floor (doubles as a player map) on the east face of the shelter-hall wall.")
obj("WaitingSeatsNorth", "beam_seating", -7.10, 0.12, -0.72, 180, [2.20, 0.82, 0.62], "Four-seat steel beam seating under window W4, seats facing into the room (-Z). A coat left on one seat.")
obj("WaitingSeatsSouth", "beam_seating", -6.20, 0.12, -2.15, 0, [2.20, 0.82, 0.62], "Four-seat beam seating facing the north row (+Z); a child's shoe underneath.")
obj("LobbyWheelchair", "wheelchair", -12.03, 0.12, -3.65, 0, [0.65, 0.95, 1.05], "Empty wheelchair parked facing the doors (+Z) with a folded blanket on the seat, as if someone was waiting. Silhouetted against the doorway on entry.")
obj("LobbyWaterFountain", "water_fountain", -5.20, 0.55, -4.95, 0, [0.45, 0.45, 0.40], "Wall-hung stainless drinking fountain on the stair-core wall, dry.")
obj("LobbyDirectorySign", "sign_wall", -4.29, 1.40, -1.40, 0, [0.02, 0.80, 1.10], "Directory on the west face of the tower-hall wall: blue/white 'H' logo, '<- SHELTER HALL A - MEDICAL STORES' / 'TREATMENT WARD - STAFF RECORDS - DAY ROOM ->'. No Red Cross.")
# shelter hall
for i, x in enumerate([-19.45, -18.15, -16.85, -15.55]):
    obj(f"ShelterCot_F{i+1}", "cot", x, 0.12, -1.30, 0, [0.70, 0.45, 1.90], "Folding camp cot (aluminium frame, olive canvas), long axis N-S, head toward the windows; grey wool blanket and pillow, some unmade.")
for i, x in enumerate([-19.50, -18.60, -15.55]):
    obj(f"ShelterCot_B{i+1}", "cot", x, 0.12, -4.20, 0, [0.70, 0.45, 1.90], "Folding camp cot, back row against the stores wall; blanket thrown back.")
obj("PrivacyScreen", "privacy_screen", -14.70, 0.12, -1.40, 0, [0.35, 1.80, 1.80], "Three-panel folding hospital screen (steel frame, faded blue fabric) zig-zagged to screen the front cots from the lobby opening. Name kept for the floor-rest test.")
obj("ShelterWaterStation", "folding_table", -13.05, 0.12, -3.90, 0, [0.75, 0.74, 1.20], "Folding table: water jugs, paper cups, battery lantern (light marker), a box of donated toiletries. Top y=0.86.")
obj("IsolationDoorBarricade", "barricade", -13.90, 0.12, -4.90, 0, [1.10, 2.10, 0.55], "Isolation 104 door (closed leaf in the opening) with planks screwed across, a chair wedged under the handle, red spray paint 'DON'T ANSWER IT'. Scratches at knee height on the leaf.")
obj("BoardedWindowW1", "barricade", -18.09, 0.44, -0.33, 0, [2.68, 1.76, 0.04], "Plywood sheets nailed over window W1 from inside; thin gaps between boards.")
obj("BlanketOverW2", "curtain", -14.43, 0.54, -0.33, 0, [2.60, 1.60, 0.03], "Grey wool blanket tacked over window W2, one corner fallen.", block=False)
obj("ShelterBelongingsPile", "clutter", -19.75, 0.12, -2.80, 0, [0.60, 0.50, 0.70], "Suitcases, a duffel bag and a pillowcase of clothes stacked at the west wall.")
obj("ShelterKidBelongings", "clutter", -19.50, 0.57, -4.20, 0, [0.50, 0.25, 0.60], "On cot B1: a small backpack, a teddy bear, rain boots on the floor beside it.", block=False)
obj("ChildrenDrawings", "wall_decal", -12.685, 1.10, -3.90, 0, [0.01, 0.70, 1.20], "Crayon drawings taped to the wall over the water station: houses, 'WE ARE SAFE HERE', and one of a tall thin figure with long claws standing in a hallway.")
obj("ShelterIVStand", "iv_stand", -17.50, 0.12, -0.80, 0, [0.55, 1.95, 0.55], "IV pole squeezed between cots F2 and F3, bag half full and dark - someone was sick in the shelter.")
obj("ShelterBanner", "sign_hanging", -16.40, 2.30, -2.80, 0, [3.00, 0.55, 0.02], "Bedsheet banner: 'CICELY EMERGENCY SHELTER - HALL A'.")
# medical stores
obj("SupplyShelfUpright", "shelving_unit", -18.70, 0.12, -9.05, 0, [2.40, 2.00, 0.50], "Steel shelving unit against the back wall; 4 uprights, shelf tops at y 0.22, 0.62, 1.02, 1.42, 1.82. Stores log (document 3) on the 1.42 shelf, bottle on the 1.02 shelf. Name kept for the floor-rest test.")
obj("SupplyShelf_West", "shelving_unit", -19.85, 0.12, -6.60, 90, [2.40, 2.00, 0.50], "Second steel shelving unit along the west wall, open face +X; mostly empty, a few cartons.")
obj("SupplyShelf_Island", "shelving_unit", -17.60, 0.12, -7.10, 0, [2.00, 1.50, 0.90], "Back-to-back gondola shelving, shelf tops y 0.22, 0.62, 1.02, 1.42, top cap 1.62; picked clean.")
obj("MedicineFridge", "fridge", -15.05, 0.12, -8.85, 0, [0.70, 1.80, 0.70], "Glass-door vaccine fridge, dead, door ajar; 'KEEP COLD' tape.")
# shelter office
obj("OfficeDesk", "desk", -9.40, 0.12, -8.85, 0, [1.60, 0.75, 0.80], "Steel desk, top y=0.87: CB/ham radio with a coiled mic (audio: static), shelter logbook, mug, flashlight with dead batteries. Bottle on the desk.")
obj("OfficeFilingCabinet", "filing_cabinet", -11.00, 0.12, -8.95, 0, [0.47, 1.32, 0.62], "Four-drawer cabinet, top drawer open.")
obj("OfficeCot", "cot", -10.95, 0.12, -6.60, 0, [0.70, 0.45, 1.90], "Staff cot along the west wall, sleeping bag.")
obj("EvacuationMapBoard", "notice_board", -7.49, 1.10, -7.20, 0, [0.02, 1.00, 1.40], "Town map of Cicely on the east wall: route drawn in red marker from the hospital north out of town, the destination corner torn away (matches the evacuation notice).")
# tower hall
obj("MainDoorBarricade", "barricade", -2.75, 0.12, -0.90, 0, [2.70, 2.00, 1.20], "Pile against the glass main doors: gurney on its side, stacked plastic chairs, two mattresses, plywood screwed over the door frame, chain and padlock through the push bars.")
obj("VendingMachine", "vending_machine", -2.75, 0.12, -0.72, 180, [0.90, 1.85, 0.80], "Snack machine dragged across the hall and stood with its back against the glass doors as the core of the barricade; front faces the hall (-Z), panel still lit (light marker), one pane cracked. Sits inside MainDoorBarricade.")
obj("TowerHallTippedWheelchair", "wheelchair", -3.50, 0.12, -4.55, 0, [1.00, 0.65, 0.65], "Wheelchair lying on its side near the lobby passage.")
obj("CorridorMouthSign", "sign_hanging", 0.20, 2.35, -4.15, 0, [0.02, 0.40, 1.60], "Hanging sign at the corridor mouth facing west: 'TREATMENT WARD - STAFF RECORDS - DAY ROOM ->' with the blue 'H'.")
# linen & changing
obj("LinenShelving", "shelving_unit", -1.00, 0.12, -9.025, 0, [2.00, 2.00, 0.55], "Linen shelving, shelf tops y 0.22, 0.62, 1.02, 1.42, 1.82: folded sheets, towels, scrubs. Bottle on the 1.02 shelf.")
obj("LaundryCart", "cart", -0.20, 0.12, -8.30, 0, [0.60, 0.95, 0.90], "Canvas laundry hamper cart against the east wall, south of the door to the ward.")
obj("MopBucketWetFloor", "clutter", -3.80, 0.12, -5.65, 0, [0.50, 0.90, 0.50], "Mop bucket with wringer and a yellow 'WET FLOOR' sign in the north-west corner; wet patch decal and a slow drip from the ceiling (audio).")
# corridor
obj("CorridorBumperRailNorth", "bumper_rail", 8.975, 0.85, -3.155, 0, [17.35, 0.14, 0.06], "Timber-look bumper rail on the corridor side of the north wall, y 0.85-0.99, 0.06 proud. Build only these segments: x [0.30,1.95], [3.65,5.45], [9.15,14.75], [16.45,17.65] (no rail across door or pass-through openings).", segments=[(0.30, 1.95), (3.65, 5.45), (9.15, 14.75), (16.45, 17.65)])
obj("CorridorBumperRailSouth", "bumper_rail", 6.775, 0.85, -5.145, 0, [21.75, 0.14, 0.06], "Bumper rail on the north face of the south wall line, y 0.85-0.99, 0.06 proud. Build only these segments: x [-4.10,-2.45], [-0.75,0.65], [2.35,7.90], [9.60,13.45], [15.15,17.65] (gaps at doors; the first two run along the tower hall).", segments=[(-4.10, -2.45), (-0.75, 0.65), (2.35, 7.90), (9.60, 13.45), (15.15, 17.65)])
obj("SignBlade_Procedure", "sign_projecting", 2.80, 2.30, -3.40, 0, [0.03, 0.22, 0.55], "Double-sided blade sign 'PROCEDURE 1', fixed to the north wall above the door.")
obj("SignBlade_NurseStation", "sign_projecting", 6.25, 2.30, -3.40, 0, [0.03, 0.22, 0.55], "Blade sign 'NURSE STATION - WARD B'.")
obj("SignBlade_DayRoom", "sign_projecting", 15.60, 2.30, -3.40, 0, [0.03, 0.22, 0.55], "Blade sign 'DAY ROOM'.")
obj("SignBlade_TreatmentWard", "sign_projecting", 1.50, 2.30, -4.90, 0, [0.03, 0.22, 0.55], "Blade sign 'TREATMENT WARD B'.")
obj("SignBlade_StaffRecords", "sign_projecting", 8.75, 2.30, -4.90, 0, [0.03, 0.22, 0.55], "Blade sign 'STAFF RECORDS - STAFF ONLY'.")
obj("SignBlade_StaffLounge", "sign_projecting", 14.30, 2.30, -4.90, 0, [0.03, 0.22, 0.55], "Blade sign 'STAFF LOUNGE'.")
obj("CorridorSaggingTile", "ceiling_tile", 5.20, 2.55, -4.60, 0, [0.60, 0.35, 0.60], "One ceiling tile dropped at one end, hanging at an angle from the grid just past the strobing light; a cable dangles from the gap (bottom stays above y 2.5).")
obj("CorridorEndBlind", "blind", 17.62, 1.20, -3.84, 0, [0.04, 0.78, 1.28], "Broken venetian blind half-lowered over the corridor end window; slats cast bars in the moonlight shaft.", block=False)
# procedure room
obj("ProcedureIVStand", "iv_stand", 2.55, 0.12, -0.70, 0, [0.55, 1.95, 0.55], "Five-wheel IV pole with an empty bag and coiled line, beside the exam chair.")
obj("ProcedureSink", "sink_unit", 0.55, 0.12, -0.525, 180, [0.50, 1.88, 0.45], "Scrub sink base cabinet (top y=1.02) with a mirror above, on the narrow front pier west of window E1, faces -Z into the room.")
obj("ProcedureBlinds", "blind", 2.84, 1.20, -0.33, 0, [4.02, 0.78, 0.03], "Half-closed venetian blinds over windows E1-E2 (two blinds), letting through thin bars of skylight.", block=False)
# nurse station
obj("NurseCounter", "counter", 8.20, 0.12, -2.675, 0, [2.00, 1.07, 0.60], "Nurse station counter under the corridor pass-through, top y=1.19 (= pass-through sill). Phone off the hook, charts, pill jars; a bottle reachable from both sides.")
obj("PatientWhiteboard", "whiteboard", 10.20, 1.20, -0.85, 0, [0.02, 0.80, 1.00], "Ward whiteboard: 'WARD B - Bed 1 H. LARSEN / Bed 2 (wiped) / Bed 3 CARRIE M. - belongings retained / EVAC 18:00 LAST GROUP'.")
obj("NurseMedCabinet", "wall_cabinet", 7.80, 1.10, -0.40, 0, [0.80, 0.90, 0.20], "Locked steel medication cabinet on the pier between windows E3 and E4, door pried open, empty.")
# day room
obj("DayRoomArmchair_1", "armchair", 11.40, 0.12, -1.05, 0, [0.80, 0.95, 0.85], "Vinyl wing armchair facing window E5 (+Z).")
obj("DayRoomArmchair_2", "armchair", 12.50, 0.12, -1.05, 0, [0.80, 0.95, 0.85], "Armchair facing the window, a knitted blanket over the arm.")
obj("DayRoomArmchair_3", "armchair", 13.90, 0.12, -1.10, 180, [0.80, 0.95, 0.85], "Armchair turned to face into the room (-Z), toward the corridor door.")
obj("DayRoomTV", "tv_stand", 17.35, 0.12, -2.45, -90, [1.00, 1.25, 0.60], "CRT TV on a wheeled stand facing into the room (-X); emissive static (light_flicker marker).")
obj("DayRoomPiano", "piano", 15.75, 0.12, -0.62, 180, [1.50, 1.25, 0.60], "Upright piano against the solid front wall, keyboard facing -Z, lid open, sheet music.")
obj("DayRoomBookshelf", "bookcase", 10.53, 0.12, -0.80, 90, [1.00, 1.80, 0.32], "Bookcase of paperbacks and board games against the nurse-station wall, faces +X.")
obj("DayRoomWheelchair", "wheelchair", 17.00, 0.12, -1.25, 90, [0.65, 0.95, 1.05], "Wheelchair facing the moonlit east window (+X), a cardigan on the seat.")
# ward
obj("WardCubicleCurtain_Bed3", "curtain", 6.05, 0.30, -8.15, 0, [0.06, 2.10, 2.20], "Drawn cubicle curtain (pale blue, hem at y=0.30) on the west side of Bed 3, hung from a ceiling track at y 2.45. Backlit by window B3: the pillows on Bed 3 throw a sitting silhouette onto it.")
obj("WardCurtainTracks", "curtain_track", 3.90, 2.45, -8.10, 0, [7.20, 0.03, 2.30], "Thin ceiling-hung L-shaped curtain tracks around each bed (x 0.4-7.6, z -7.0 to -9.25), 3 cm aluminium; only Bed 1 and Bed 3 carry curtains.", block=False)
obj("WardBunchedCurtain_Bed1", "curtain", 0.40, 0.30, -8.90, 0, [0.20, 2.10, 0.30], "Curtain pulled back and bunched on the closed (west) side of Bed 1.")
obj("WardBedsideCabinet_Bed2", "bedside_cabinet", 3.10, 0.12, -8.95, 0, [0.45, 0.80, 0.45], "Bedside locker on Bed 2's closed (west) side, top y=0.92: water jug, orange pill bottle.")
obj("WardBedsideCabinet_Bed3", "bedside_cabinet", 7.48, 0.12, -8.95, 0, [0.38, 0.80, 0.45], "Narrow bedside locker east of Bed 3: Carrie's reading glasses, a paperback.")
obj("CarrieBelongings", "clutter", 6.80, 0.74, -8.40, 0, [0.55, 0.75, 0.70], "On Bed 3's mattress: pillows propped upright with Carrie's cardigan draped over them (the silhouette), her overnight bag with a luggage tag 'CARRIE M.', a hairbrush.", block=False)
obj("WardSink", "sink_unit", 2.80, 0.55, -5.50, 180, [0.55, 1.45, 0.35], "Wall-hung clinical hand-wash basin (bottom y=0.55) with mirror and soap dispenser on the ward side of the corridor wall, faces -Z; only 0.35 deep so the bed-foot aisle keeps 1.48 m.")
# records
obj("RecordsDesk", "desk", 9.00, 0.12, -8.925, 0, [1.50, 0.75, 0.75], "Ward office desk under window B4, top y=0.87: evacuation notice (document 2) by a still-burning green banker's lamp, paper piles, dried coffee mug. Name kept for the floor-rest test.")
obj("RecordsFilingCabinets", "filing_cabinet", 8.15, 0.12, -7.75, 90, [0.94, 1.32, 0.62], "Pair of four-drawer cabinets against the ward wall, faces +X; one drawer yanked out.")
obj("RecordsSpilledFiles", "debris", 9.50, 0.12, -7.00, 0, [1.20, 0.02, 0.80], "Patient files and loose forms spilled across the carpet.", block=False)
obj("RecordsNoticeBoard", "notice_board", 11.20, 1.10, -5.335, 0, [1.20, 0.90, 0.02], "Pin board: staff rota, 'GROUND FLOOR EVACUATION PLAN' diagram, a sticky note 'IT DOESN'T OPEN LOCKERS. IT WATCHES.'")
obj("RecordsCoatRack", "coat_rack", 12.35, 0.12, -5.70, 0, [0.45, 1.80, 0.45], "Coat stand with a nurse's raincoat and scarf left behind.")
# lounge
obj("LoungeKitchenette", "counter", 13.085, 0.12, -7.00, 90, [2.40, 0.90, 0.60], "Kitchenette base run along the west wall, faces +X, top y=1.02: sink, coffee maker, microwave, mugs; bottle on the counter.")
obj("LoungeUpperCabinets", "wall_cabinet", 12.96, 1.50, -7.00, 90, [2.40, 0.70, 0.35], "Wall cabinets above the kitchenette, base y=1.50, one door hanging.")
obj("LoungeFridge", "fridge", 13.135, 0.12, -8.70, 90, [0.70, 1.75, 0.70], "Domestic fridge, door ajar with the interior bulb still on (light marker).")
obj("LoungeTable", "table", 14.55, 0.12, -7.40, 0, [0.90, 0.75, 0.90], "Round break-room table, top y=0.87: half-eaten meal, playing cards.")
obj("LoungeSofa", "sofa", 16.20, 0.12, -7.20, -90, [2.00, 0.85, 0.85], "Vinyl two-seat sofa freestanding mid-room, facing west (-X); a nurse's cardigan.")
obj("LoungeNoticeBoard", "notice_board", 16.40, 1.10, -5.335, 0, [1.00, 0.80, 0.02], "Staff notice board: rota, calendar with the evacuation date circled 'EVAC'.")
# doors (static leaves) and special doors
obj("StairDoorChained", "door_leaf", -6.20, 0.12, -5.25, 0, [1.00, 2.10, 0.05], "Closed steel stair door in the S4 opening, chain wrapped through the push bar and frame, 'STAIR 1 - UPPER FLOORS CLOSED' sign.", block=False)
obj("SkirtingAndCornerGuards", "trim_set", -1.20, 0.12, -4.80, 0, [37.80, 0.10, 9.00], "Rule, not a box: 0.10 m vinyl cove skirting (0.015 proud) on every room-side wall face, stainless corner guards (0.05 x 1.2 m) on corridor and tower-hall corners. Visual trim only.", block=False)
obj("WindowSillBoards", "trim_set", -1.20, 0.54, -4.80, 0, [37.80, 0.03, 9.00], "Rule, not a box: in every lining window opening a 0.03 x 0.14 m painted sill board at y=0.54 and plain reveals linings back to the shell glass; nothing else enters an opening.", block=False)
obj("InteriorDoorLeaves", "door_frame_set", 3.00, 0.12, -4.15, 0, [0.90, 2.10, 0.05], "Rule, not a box: every 'open' doorway gets a painted steel frame with 0.05 architrave and a kick plate on the floor line, and NO leaf (the shelter lifted them off for stretcher traffic; empty hinge knuckles left on the frames). Leaves only where modelled explicitly: entrance (2), Stair 1 (closed, chained), Isolation 104 (closed, barricaded). Nothing may stand in a doorway the Clawman uses.", block=False)

from markers import *  # noqa: E402,F401,F403

# Ceiling openings (x_min, x_max, z_min, z_max): missing tiles in the tower hall and ward
# showing the black plenum, and the gap left by the corridor's sagging tile.
ceiling_holes = [(-3.0, -1.0, -3.2, -2.0), (2.0, 3.2, -6.6, -6.0), (4.9, 5.5, -4.9, -4.3)]
# Corridor fixtures; rooms get a 2.4 m grid of troffers from the builder.
corridor_fixtures_x = [2.5, 6.0, 9.5, 13.0, 16.0]
corridor_fixtures_z = -4.15
