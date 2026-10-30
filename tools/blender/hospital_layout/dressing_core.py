"""Hospital equipment for the core under the tower: Tower Hall, Linen & Changing and
Procedure Room 1 (format: tools/blender/hospital_dressing/README.md)."""

from placing import entry, wall

dressing = [
    # Tower Hall (old main entrance, barricaded).
    wall("aed_cabinet", "TowerAED", -4.125, "+x", -2.05),
    wall("fire_extinguisher_cabinet", "TowerExtinguisher", -0.30, "-z", -0.6),
    wall("fire_alarm_pull", "TowerAlarmPull", -0.30, "-z", -0.15),
    wall("wall_clock", "TowerClock", -5.175, "+z", -3.4),
    wall("poster", "TowerShelterPoster", -5.175, "+z", -3.75, title="EMERGENCY SHELTER", lines=("REGISTER AT", "ADMITTING"), band="SignGreen"),
    wall("waste_bin", "TowerBin", -5.175, "+z", -0.3, gap=0.03),
    entry("o2_cylinder_cart", "TowerOxygen", -1.45, -2.5, yaw=30.0),

    # Linen & Changing.
    entry("soiled_linen_hamper", "LinenHamper", -2.5, -8.95, bag="yellow"),
    wall("poster", "LinenStaffPoster", 0.125, "-x", -7.5, y=1.3, title="STAFF ONLY", lines=("CHANGING ROOM",)),
    wall("wall_clock", "LinenClock", -4.125, "+x", -6.5),

    # Procedure Room 1: exam-room wall kit on the corridor side, X-ray viewer by the trolley.
    # (No solid wall cabinet: that whole wall is within a metre of the nurse-station door.)
    wall("diagnostic_set", "ProcedureDiagnosticSet", -2.975, "+z", 3.97),
    wall("glove_box_holder", "ProcedureGloves", -2.975, "+z", 4.52),
    wall("sharps_container", "ProcedureSharps", -2.975, "+z", 4.95),
    wall("xray_viewbox", "ProcedureXray", 5.24, "-x", -0.82, y=1.45, films=2),
    wall("eye_chart", "ProcedureEyeChart", -0.30, "-z", 3.05),
    entry("wheeled_stool", "ProcedureStool", 3.2, -1.65),
    entry("step_stool", "ProcedureStepStool", 4.05, -1.55, yaw=180.0),
    entry("kick_bucket", "ProcedureKickBucket", 2.6, -1.6),
    entry("mobile_vitals", "ProcedureVitals", 4.92, -1.0, yaw=-90.0),
]
