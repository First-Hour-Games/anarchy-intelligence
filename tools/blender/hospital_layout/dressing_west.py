"""Hospital equipment for the west wing: Shelter Hall, Lobby & Reception, Medical Stores and
the Shelter Office (format: tools/blender/hospital_dressing/README.md)."""

from placing import entry, wall

dressing = [
    # Shelter Hall (old outpatient waiting): clinic signage left behind, safety kit, a sick cot.
    wall("wall_clock", "ShelterClock", -20.10, "+x", -2.8),
    wall("poster", "ShelterVisitingPoster", -5.175, "+z", -19.05, title="VISITING HOURS", lines=("2 PM - 8 PM",), band="SignGreen"),
    wall("poster", "ShelterHygienePoster", -5.175, "+z", -15.0, title="WASH YOUR HANDS", lines=("STOP THE SPREAD",), curl=True),
    wall("fire_extinguisher_cabinet", "ShelterExtinguisher", -12.675, "-x", -4.85),
    wall("fire_alarm_pull", "ShelterAlarmPull", -12.675, "-x", -0.62),
    wall("waste_bin", "ShelterBin", -12.675, "-x", -0.55, gap=0.03),
    entry("o2_cylinder_cart", "ShelterOxygen", -17.5, -1.75),

    # Lobby & Reception (admitting): equipment on the staff desk behind the transaction ledge.
    entry("dot_matrix_printer", "ReceptionPrinter", -11.2, -3.92, yaw=180.0, y=0.87, on="ReceptionDesk"),
    entry("desk_phone", "ReceptionPhone", -10.4, -3.92, yaw=180.0, y=0.87, on="ReceptionDesk"),
    entry("clipboard", "ReceptionClipboard", -9.7, -3.95, yaw=170.0, y=0.87, on="ReceptionDesk"),
    wall("chart_rack", "AdmittingChartRack", -5.175, "+z", -12.0, gap=0.03),
    wall("crash_cart", "LobbyCrashCart", -5.175, "+z", -6.2, gap=0.03),   # abandoned in front of the chained stair door
    wall("wall_clock", "LobbyClock", -0.30, "-z", -5.45),
    wall("aed_cabinet", "LobbyAED", -0.30, "-z", -4.7),
    wall("fire_extinguisher_cabinet", "LobbyExtinguisher", -5.175, "+z", -7.05),
    wall("fire_alarm_pull", "LobbyAlarmPull", -5.175, "+z", -4.55),
    wall("poster", "LobbyNoSmokingPoster", -4.275, "-x", -2.25, title="NO SMOKING", lines=("OXYGEN IN USE",), band="MedicalRed"),

    # Medical Stores (central supply).
    wall("o2_cylinder_rack", "StoresOxygenRack", -9.30, "+z", -16.65, gap=0.03),
    wall("sterile_wall_cabinet", "StoresSterileCabinet", -14.675, "-x", -7.85),
    wall("fire_extinguisher_cabinet", "StoresExtinguisher", -5.325, "-z", -15.6),
    wall("poster", "StoresStaffOnlyPoster", -5.325, "-z", -18.6, y=1.4, title="CENTRAL SUPPLY", lines=("STAFF ONLY",)),
    wall("wall_clock", "StoresClock", -14.675, "-x", -5.75),
    entry("fluid_cartons", "StoresFluidCartons", -16.3, -8.1, yaw=15.0, y=0.12),

    # Shelter Office (old admitting office).
    wall("binder_shelf", "OfficeBinderShelf", -11.325, "+x", -7.0),
    wall("wall_clock", "OfficeClock", -9.30, "+z", -9.4),
    wall("poster", "OfficeMissingPoster", -5.325, "-z", -10.6, y=1.3, title="HAVE YOU SEEN", lines=("ASK AT THE", "SHELTER DESK"), band="SafetyYellow"),
    entry("desk_phone", "OfficePhone", -11.0, -8.95, y=1.44),
    entry("waste_bin", "OfficeBin", -8.35, -8.95),
]
