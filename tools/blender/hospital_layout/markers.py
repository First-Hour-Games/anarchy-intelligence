"""Godot markers for the hospital V2 ground floor (imported by layout.py)."""

# native AABB sizes (x, y, z) of pack models, used for footprints at a target height
NATIVE = {
    "bed_1": (0.536, 0.912, 1.408), "bed_2": (0.536, 0.488, 1.439), "bed_4": (0.536, 0.655, 1.584),
    "cupboard_bottom": (0.754, 0.689, 0.387), "cupboard_top": (0.754, 0.496, 0.302),
    "machine_1": (0.638, 0.703, 0.412), "machine_2": (0.512, 0.835, 0.504), "tray_1": (0.388, 0.568, 0.208),
    "overhead_light": (1.848, 0.784, 1.282), "chair": (0.2, 0.47, 0.2), "tableRound": (0.693, 0.367, 0.8),
    "pottedPlant": (0.212, 0.654, 0.241),
    "Med_1": (18.0, 4.411, 10.5), "Med_3": (6.547, 15.24, 3.47), "Med_9": (5.483, 9.208, 5.215),
    "Med_13": (4.134, 7.377, 3.58), "Med_14": (7.956, 10.608, 10.59), "Med_15": (6.49, 15.226, 8.156),
    "Med_16": (14.355, 25.318, 1.734), "Med_18": (3.763, 8.371, 3.763), "Med_19": (11.101, 0.345, 5.688),
    "Med_20": (10.674, 0.373, 4.488),
}
FIXED = {"ward_bed": (2.08, 1.08, 0.94)}

markers = []


def mk(name, type, x, y, z, rot, params, model=None, target=None, block=None):
    m = dict(name=name, type=type, x=round(x, 4), y=round(y, 4), z=round(z, 4), rotation_deg=rot, params=params)
    if model:
        if model in FIXED:
            w, h, d = FIXED[model]
        else:
            nx, ny, nz = NATIVE[model]
            s = target / ny
            w, h, d = nx * s, target, nz * s
        m["foot"] = (w, h, d)
        m["block"] = block if block is not None else (h > 0.25 and y < 0.5)
    markers.append(m)


# --- hiding spots (open side = local +Z after yaw; exactly 5 lockers, 1 closet, 2 beds)
for i, z in enumerate([-6.60, -7.25, -7.90]):
    mk(f"RecordsLocker_{i+1}", "hiding_locker", 12.31, 0.12, z, -90,
       "HidingSpot LOCKER (staff_locker.glb), back against the Records/Lounge wall, door opens west (-X); exit (11.51, %.2f). Keep the 'RecordsLocker' name prefix (hospital_hiding_map_smoke)." % z)
for i, z in enumerate([-7.60, -8.25]):
    mk(f"ChangingLocker_{i+1}", "hiding_locker", -3.80, 0.12, z, 90,
       "HidingSpot LOCKER (staff_locker.glb), back against the stair-core wall in Linen & Changing, door opens east (+X); exit (-3.00, %.2f). Hidden from the corridor, visible only from the linen doorway." % z)
mk("ProcedureCloset", "hiding_closet", 0.98, 0.12, -2.645, 0,
   "HidingSpot CLOSET (supply_closet.glb), back against the corridor wall inside Procedure Room 1 between the tower-hall door and the corridor door, doors open north (+Z); exit (0.98, -1.845); floor kept clear to z=-0.98.")
mk("WardBed_1", "hiding_bed", 1.00, 0.12, -8.20, 90,
   "HidingSpot UNDER_BED (ward_bed.glb): yaw 90 puts the headboard (local +X) against the back wall and the open long side facing east; exit (2.10, -8.20); hunter stands at (2.90, -8.20) in the 1.96 m gap to Bed 2.")
mk("WardBed_2", "hiding_bed", 3.90, 0.12, -8.20, 90,
   "HidingSpot UNDER_BED (ward_bed.glb): headboard to the back wall, open side east; exit (5.00, -8.20); hunter stands at (5.80, -8.20) in front of Bed 3's curtain.")

# --- bottles (BottlePickup, base on the stated surface)
mk("Bottle_StoresShelf", "bottle", -18.20, 1.02, -9.05, 0, "BottlePickup on SupplyShelfUpright 3rd shelf, surface top y=1.02. First bottle, next to the stores log that explains throwing.")
mk("Bottle_OfficeDesk", "bottle", -9.00, 0.87, -8.70, 0, "BottlePickup on OfficeDesk, surface top y=0.87, beside the radio.")
mk("Bottle_LinenShelf", "bottle", -0.60, 1.02, -9.00, 0, "BottlePickup on LinenShelving 3rd shelf, surface top y=1.02; last pickup before the corridor.")
mk("Bottle_NurseCounter", "bottle", 7.60, 1.19, -2.60, 0, "BottlePickup on NurseCounter, surface top y=1.19; reachable through the corridor pass-through from about (7.6, -3.6).")
mk("Bottle_LoungeCounter", "bottle", 13.10, 1.02, -6.30, 0, "BottlePickup on LoungeKitchenette, surface top y=1.02; refill next to the climax room.")

# --- documents (StoryDocument book 0.32 x 0.045 x 0.24; marker = book centre = surface + 0.0225)
mk("Doc_Register", "document", -10.60, 1.2425, -3.62, 0, "document_id=register, 'Emergency shelter registration'; on the ReceptionDesk ledge, surface top y=1.22. Text unchanged.")
mk("Doc_Evacuation", "document", 9.20, 0.8925, -8.95, 0, "document_id=evacuation, 'Evacuation notice'; on RecordsDesk, surface top y=0.87, inside the desk-lamp pool. Text unchanged.")
mk("Doc_Supply", "document", -19.20, 1.4425, -9.05, 0, "document_id=supply, 'Medical stores log'; on SupplyShelfUpright 4th shelf, surface top y=1.42 with 0.40 m clear above. Text unchanged.")

# --- Clawman
mk("ClawmanSpawn", "clawman_spawn", 12.50, 0.12, -4.15, 90,
   "Clawman start in the corridor; yaw 90 turns Godot forward (-Z) to face west toward the tower hall. Stands 5.2 m in front of the moonlit end window and 2.3 m from the east red light, so it reads as a silhouette from the lobby. Territory (22 m) reaches x=-9.5; hearing (12 m) reaches x=0.5, the corridor mouth.")

# --- lights
mk("L_ReceptionFlicker", "light_flicker", -10.20, 2.86, -3.20, 0, "OmniLight in the troffer over the counter front; color 0.78,0.86,0.74; energy 1.0; range 7; irregular flicker about 65% on with 0.05-0.4 s dropouts; ballast buzz audio.")
mk("L_ShelterLantern", "light", -13.05, 1.00, -3.60, 0, "Battery camping lantern on ShelterWaterStation (mesh 0.15 x 0.25); warm 1.0,0.72,0.42; energy 0.6; range 6; steady. The only warm light in the building.")
mk("L_EntranceExit", "light_emergency", -10.20, 2.75, -0.42, 0, "Red EXIT lightbox (0.35 x 0.15 x 0.08) over the entrance, inside face; color 1.0,0.12,0.08; energy 0.5; range 4; steady.")
mk("L_VendingGlow", "light", -2.75, 1.30, -1.30, 0, "Vending machine front panel (emissive); color 0.55,0.75,1.0; energy 0.35; range 3.5; faint shimmer.")
mk("L_TowerHallExit", "light_emergency", -4.20, 2.60, -3.90, 0, "Hanging red EXIT sign over the passage back to the lobby, arrow west; energy 0.4; range 4.")
mk("L_CorridorRedWest", "light_emergency", 2.50, 2.86, -4.15, 0, "Ceiling emergency light; red 1.0,0.1,0.06; energy 0.6; range 5; slow 2 s pulse.")
mk("L_CorridorStrobe", "light_flicker", 6.00, 2.86, -4.15, 0, "Failing fluorescent tube; color 0.8,0.88,0.8; energy 1.4; range 7; dark most of the time, 2-4 fast strobe bursts every 3-6 s. This is the first-sighting reveal light.")
mk("L_CorridorRedEast", "light_emergency", 14.80, 2.86, -4.15, 0, "Ceiling emergency light just behind the Clawman's post; red; energy 0.6; range 5; steady, rims the Clawman red.")
mk("L_CorridorEndMoon", "moonlight", 17.55, 1.30, -3.84, 0, "Spot through the corridor end window aimed west (-X), 10 degrees down; color 0.55,0.65,0.95; energy 2.0; range 14; angle 50; shadows on so the blind slats stripe the floor.")
mk("L_NurseFlicker", "light_flicker", 7.80, 2.86, -1.60, 0, "Dying tube over the nurse station; energy 0.8; range 5; long dark gaps (1-3 s) with brief flashes.")
mk("L_DayRoomMoonEast", "moonlight", 17.55, 1.30, -1.17, 0, "Spot through the day room east window aimed west and down; color 0.55,0.65,0.95; energy 1.6; range 9; angle 45.")
mk("L_DayRoomTV", "light_flicker", 16.95, 0.95, -2.45, 0, "TV static glow in front of the screen; color 0.8,0.85,0.95; energy 0.3; range 3; rapid noise flicker; white-noise audio.")
mk("L_WardMoonB1", "moonlight", 1.59, 1.30, -9.20, 0, "Spot through back window B1 aimed north (+Z) and down across Bed 1; color 0.55,0.65,0.95; energy 1.2; range 6; angle 40.")
mk("L_WardMoonB3", "moonlight", 6.53, 1.30, -9.20, 0, "Spot through back window B3 aimed north-west at Bed 3's curtain so the propped pillows cast a sitting silhouette on it; energy 1.4; range 6; angle 40; shadows on.")
mk("L_WardExit", "light_emergency", 1.50, 2.60, -5.45, 0, "Red EXIT sign over the ward door, inside; energy 0.35; range 3.5.")
mk("L_RecordsDeskLamp", "light", 9.55, 1.25, -9.05, 0, "Green banker's desk lamp still on; warm 1.0,0.85,0.55; energy 0.5; range 3; steady; lights the evacuation notice.")
mk("L_RecordsMoonB5", "moonlight", 11.475, 1.30, -9.20, 0, "Spot through window B5 aimed north at the locker bank; energy 1.0; range 6; angle 40.")
mk("L_LoungeMoonEast", "moonlight", 17.55, 1.30, -6.00, 0, "Spot through the lounge east window aimed west; energy 1.4; range 8; angle 45.")
mk("L_LoungeFridgeGlow", "light", 13.40, 0.95, -8.40, 0, "Fridge bulb through the ajar door; color 0.9,0.95,1.0; energy 0.25; range 2.5.")
mk("L_StoresExit", "light_emergency", -17.00, 2.60, -5.45, 0, "Dim red EXIT sign inside the stores over its door; energy 0.25; range 3.")

# --- pack props
mk("P_ExamChair", "pack_prop", 3.75, 0.12, -0.95, 90, "clinic_hospital bed_1 (reclining exam chair); target_height 1.1; long axis along X after yaw (about 1.70 x 0.65); under window E2.", "bed_1", 1.1)
mk("P_SurgicalLamp", "pack_prop", 3.75, 2.10, -1.45, 0, "clinic_hospital overhead_light; target_height 0.8; base y=2.10 so the arm meets the ceiling at 2.90; dead, angled over the exam chair.", "overhead_light", 0.8, block=False)
mk("P_ProcedureTrolley", "pack_prop", 4.95, 0.12, -0.55, 0, "clinic_hospital tray_1 (3-tier instrument trolley); target_height 0.8.", "tray_1", 0.8)
mk("P_StoresBaseCabinet", "pack_prop", -14.928, 0.12, -6.60, -90, "clinic_hospital cupboard_bottom; target_height 0.9 (0.99 x 0.51); back against the stores east wall, doors facing -X; top y=1.02.", "cupboard_bottom", 0.9)
mk("P_StoresHutch", "pack_prop", -14.873, 1.02, -6.60, -90, "clinic_hospital cupboard_top; target_height 0.65; stands on the stores base cabinet (bottom y=1.02) against the wall.", "cupboard_top", 0.65, block=False)
mk("P_HubStretcher", "pack_prop", -2.86, 0.12, -1.92, 90, "clinic_hospital bed_4 (pedestal stretcher); target_height 0.9 (about 2.18 x 0.74 along X); abandoned in front of the barricade.", "bed_4", 0.9)
mk("P_NurseMonitorCart", "pack_prop", 5.95, 0.12, -0.68, 180, "clinic_hospital machine_1 (monitor cart); target_height 1.1 (about 1.0 x 0.65); screen faces into the station.", "machine_1", 1.1)
mk("P_StoredEquipmentStand", "pack_prop", -3.73, 0.12, -8.93, 0, "clinic_hospital machine_2 (equipment stand); target_height 1.2 (about 0.74 x 0.72); parked in the south-west corner of Linen & Changing, beside the lockers.", "machine_2", 1.2)
mk("P_WardBed3Decor", "pack_prop", 6.80, 0.12, -8.20, 90, "ward_bed.glb as plain decor (NOT a HidingSpot): Carrie's Bed 3, headboard to the back wall; native 2.08 x 1.08 x 0.94.", "ward_bed")
mk("P_ReceptionChair", "pack_prop", -10.60, 0.12, -4.65, 0, "furniture_kit chair; target_height 0.9; staff side of the counter.", "chair", 0.9)
mk("P_OfficeChair", "pack_prop", -9.40, 0.12, -8.10, 180, "furniture_kit chair; target_height 0.9; pushed back from the desk.", "chair", 0.9)
mk("P_NurseChair", "pack_prop", 8.20, 0.12, -2.10, 180, "furniture_kit chair; target_height 0.9; tucked at the nurse counter.", "chair", 0.9)
mk("P_RecordsChair", "pack_prop", 9.00, 0.12, -8.15, 180, "furniture_kit chair; target_height 0.9; at the records desk.", "chair", 0.9)
mk("P_LoungeChair_1", "pack_prop", 14.55, 0.12, -6.55, 180, "furniture_kit chair; target_height 0.9.", "chair", 0.9)
mk("P_LoungeChair_2", "pack_prop", 14.55, 0.12, -8.25, 0, "furniture_kit chair; target_height 0.9.", "chair", 0.9)
mk("P_ShelterChair", "pack_prop", -13.90, 0.12, -3.90, 90, "furniture_kit chair; target_height 0.9; beside the water station.", "chair", 0.9)
mk("P_LobbyDeadPlant", "pack_prop", -12.15, 0.12, -0.85, 0, "furniture_kit pottedPlant; target_height 1.0; dead plant in the corner by the doors.", "pottedPlant", 1.0)
mk("P_GauzeOnReception", "pack_prop", -9.60, 1.22, -3.62, 0, "clinic_medical Med_1 (gauze box); target_height 0.06; on the counter ledge.", "Med_1", 0.06, block=False)
mk("P_PapersOnReception", "pack_prop", -11.10, 1.22, -3.60, 0, "clinic_medical Med_19 (paper sheets); target_height 0.01; arrival forms.", "Med_19", 0.01, block=False)
mk("P_PillJarNurse", "pack_prop", 8.90, 1.19, -2.62, 0, "clinic_medical Med_9 (pill jar); target_height 0.10; on the nurse counter.", "Med_9", 0.10, block=False)
mk("P_BloodBagNurse", "pack_prop", 8.45, 1.19, -2.80, 0, "clinic_medical Med_16 (blood bag); target_height 0.20; on the nurse counter.", "Med_16", 0.20, block=False)
mk("P_StoresBox", "pack_prop", -16.00, 0.12, -8.85, 0, "clinic_medical Med_14 (cardboard box); target_height 0.35; on the stores floor.", "Med_14", 0.35)
mk("P_StoresCarton", "pack_prop", -17.60, 1.62, -7.10, 0, "clinic_medical Med_15 (carton); target_height 0.25; on the island shelving top cap y=1.62.", "Med_15", 0.25, block=False)
mk("P_StoresAntiseptic", "pack_prop", -15.125, 1.02, -6.30, 0, "clinic_medical Med_3 (antiseptic bottle); target_height 0.18; on the front strip of the stores base cabinet, y=1.02.", "Med_3", 0.18, block=False)
mk("P_WardPillBottle", "pack_prop", 3.10, 0.92, -8.95, 0, "clinic_medical Med_13 (orange pill bottle); target_height 0.09; on Bed 2's bedside locker.", "Med_13", 0.09, block=False)
mk("P_RecordsPapers", "pack_prop", 8.60, 0.87, -8.90, 0, "clinic_medical Med_20 (paper sheets); target_height 0.01; on the records desk.", "Med_20", 0.01, block=False)
mk("P_LinenWhiteJar", "pack_prop", -1.60, 1.42, -9.00, 0, "clinic_medical Med_18 (white jar); target_height 0.10; on the linen shelf y=1.42.", "Med_18", 0.10, block=False)
