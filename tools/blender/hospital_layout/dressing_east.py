"""Hospital equipment for the east wing: Main Corridor, Nurse Station, Day Room, Treatment
Ward, Staff Records and Staff Lounge (format: tools/blender/hospital_dressing/README.md).
Corridor floor props stay under 0.45 m deep so 1.5 m stays clear between the handrails."""

from placing import entry, wall

dressing = [
    # Main Corridor: wall kit above the handrails (top 0.99), shallow carts by the doors.
    wall("fire_alarm_pull", "CorridorAlarmPull", -3.125, "-z", 4.3),
    wall("fire_extinguisher_cabinet", "CorridorExtinguisher", -5.175, "+z", 11.5, y=1.0),
    wall("aed_cabinet", "CorridorAED", -3.125, "-z", 12.0),
    wall("wall_clock", "CorridorClock", -3.125, "-z", 10.9),
    wall("poster", "CorridorRightsPoster", -3.125, "-z", 13.4, title="PATIENT RIGHTS", lines=("ASK US ABOUT", "YOUR CARE"), band="SignGreen"),
    wall("poster", "CorridorQuietPoster", -5.175, "+z", 16.4, title="QUIET PLEASE", lines=("PATIENTS", "RESTING")),
    wall("isolation_cart", "CorridorIsolationCart", -5.175, "+z", 2.9, gap=0.065),
    wall("o2_cylinder_cart", "CorridorOxygen", -5.175, "+z", 6.6, gap=0.07),
    wall("waste_bin", "CorridorBin", -5.175, "+z", 11.0, gap=0.07),

    # Nurse Station: workstation on the pass-through counter, carts on the floor.
    entry("crt_terminal", "NurseTerminal", 8.12, -2.67, y=1.19),
    entry("desk_phone", "NursePhone", 8.66, -2.6, y=1.19),
    entry("clipboard", "NurseClipboard", 9.08, -2.75, y=1.19),
    entry("med_cart", "NurseMedCart", 6.95, -0.65, yaw=180.0, locked=False),
    entry("chart_rack", "NurseChartRack", 9.0, -0.55, yaw=180.0),
    entry("waste_bin", "NurseBin", 9.7, -0.5, yaw=180.0),
    wall("wall_clock", "NurseClock", -2.975, "+z", 9.7),
    wall("binder_shelf", "NurseBinderShelf", 5.39, "+x", -0.82, y=1.6),
    wall("poster", "NurseMedPassPoster", -0.30, "-z", 5.55, title="MED PASS", lines=("08  12  18  22",)),

    # Day Room (nothing more on the floor along the corridor wall: the walkway behind the
    # armchairs is the only route from the nurse station's side door).
    wall("wall_clock", "DayRoomClock", -2.975, "+z", 12.6),
    wall("poster", "DayRoomActivitiesPoster", -2.975, "+z", 11.6, y=1.3, title="ACTIVITIES", lines=("BINGO THURS 2 PM", "CHAPEL SUN 10 AM"), band="SignGreen"),
    wall("poster", "DayRoomVisitingPoster", -2.975, "+z", 13.6, y=1.3, title="VISITING HOURS", lines=("2 PM - 8 PM",)),
    entry("o2_cylinder_cart", "DayRoomOxygen", 12.5, -1.75),
    entry("waste_bin", "DayRoomBin", 16.85, -2.78),

    # Treatment Ward: a services column on the window pier by each bed head, the hand-wash
    # station around the basin, Carrie's visitor chair at the foot of Bed 3. Nothing stands
    # between the beds: the Clawman pulls players out from beside each bed's open side.
    wall("headwall_column", "WardHeadwall_1", -9.30, "+z", 0.62, y=0.95, bed="1"),
    wall("headwall_column", "WardHeadwall_2", -9.30, "+z", 3.05, y=0.95, bed="2"),
    wall("headwall_column", "WardHeadwall_3", -9.30, "+z", 7.53, y=0.95, bed="3"),
    wall("overbed_table", "WardOverbedTable", -5.325, "-z", 6.0, gap=0.03),
    entry("visitor_chair", "WardVisitorChair_3", 6.45, -6.75, yaw=180.0),
    wall("mobile_vitals", "WardVitals", -5.325, "-z", 4.6, gap=0.03),
    wall("sanitizer_dispenser", "WardSoap", -5.325, "-z", 2.45, kind="soap"),
    wall("paper_towel_dispenser", "WardPaperTowels", -5.325, "-z", 3.4),
    wall("sharps_container", "WardSharps", -5.325, "-z", 3.95),
    wall("glove_box_holder", "WardGloves", -5.325, "-z", 4.55),
    wall("poster", "WardFallRiskPoster", -5.325, "-z", 5.4, title="FALL RISK", lines=("CALL, DON'T FALL",), band="SafetyYellow"),
    wall("wall_clock", "WardClock", -5.325, "-z", 6.2),
    wall("waste_bin", "WardBin", -5.325, "-z", 3.6, gap=0.03, kind="biohazard"),

    # Staff Records.
    wall("binder_shelf", "RecordsBinderShelf", 7.84, "+x", -7.75, y=1.75),
    entry("dot_matrix_printer", "RecordsPrinter", 8.16, -7.55, yaw=90.0, y=1.44),
    wall("wall_clock", "RecordsClock", -5.325, "-z", 10.2),
    wall("poster", "RecordsMusterPoster", -9.30, "+z", 10.2, title="EVACUATION", lines=("ALL STAFF MUSTER", "IN FRONT LOT"), band="MedicalRed"),
    wall("chart_rack", "RecordsChartRack", -9.30, "+z", 10.95, gap=0.05),
    entry("waste_bin", "RecordsBin", 10.0, -8.9),

    # Staff Lounge.
    wall("wall_clock", "LoungeClock", -5.325, "-z", 16.4),
    wall("paper_towel_dispenser", "LoungePaperTowels", 12.785, "+x", -7.55, y=1.08),
    entry("desk_phone", "LoungePhone", 13.09, -7.45, yaw=90.0, y=1.02),
    wall("poster", "LoungeNoticePoster", -5.325, "-z", 13.0, title="STAFF NOTICE", lines=("CLEAN UP", "AFTER YOURSELF")),
    wall("fire_extinguisher_cabinet", "LoungeExtinguisher", -5.325, "-z", 15.5),
    wall("waste_bin", "LoungeBin", 17.70, "-x", -9.0, gap=0.03),
]
