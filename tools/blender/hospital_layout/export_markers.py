"""Write models/buildings/hospital/hospital_markers.json from markers.py: the hiding spots,
bottles, documents, pack props, lights and Clawman post that
scenes/environment/story_building.gd spawns inside the exported hospital.

python tools/blender/hospital_layout/export_markers.py   (prepare_story_hospital.py runs it too)

Positions are hospital-local game metres; yaw is in degrees (Godot convention).
"""

import json
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
OUTPUT = PROJECT / "models" / "buildings" / "hospital" / "hospital_markers.json"
PACKS = {
    "clinic_hospital": "res://assets/local_licensed/clinic_hospital/",
    "clinic_medical": "res://assets/local_licensed/clinic_medical/",
    "furniture_kit": "res://assets/local_licensed/furniture_kit/Models/GLTF format/",
}
WARD_BED = "res://models/props/hospital/ward_bed.glb"
HIDING_KINDS = {"hiding_locker": "locker", "hiding_closet": "closet", "hiding_bed": "bed"}
DEFAULT_COLORS = {"light": (1.0, 0.85, 0.6), "light_flicker": (0.8, 0.88, 0.8),
                  "light_emergency": (1.0, 0.12, 0.08), "moonlight": (0.55, 0.65, 0.95)}
COMPASS = {"west": (-1.0, 0.0), "east": (1.0, 0.0), "north": (0.0, 1.0), "south": (0.0, -1.0)}


def number(params: str, key: str, default: float) -> float:
    found = re.search(key + r" (\d+(?:\.\d+)?)", params)
    return float(found.group(1)) if found else default


def color(m: dict) -> list:
    found = re.search(r"(?:color|warm|red) (\d(?:\.\d+)?),(\d(?:\.\d+)?),(\d(?:\.\d+)?)", m["params"])
    return [float(v) for v in found.groups()] if found else list(DEFAULT_COLORS[m["type"]])


def light_mode(m: dict) -> str:
    params = m["params"]
    if m["type"] == "light_flicker":
        if "strobe" in params:
            return "strobe"
        if "long dark gaps" in params:
            return "dying"
        if "noise" in params:
            return "noise"
        return "flicker"
    if m["type"] == "light_emergency" and "pulse" in params:
        return "pulse"
    return "steady"


def aim(params: str) -> list:
    """Spot direction from wording such as 'aimed north-west' or 'aimed west, 10 degrees down'."""
    phrase = params.split("aimed", 1)[1] if "aimed" in params else ""
    x = z = 0.0
    for word, (dx, dz) in COMPASS.items():
        if re.search(r"\b" + word, phrase.split(";")[0]):
            x += dx
            z += dz
    degrees = re.search(r"(\d+) degrees down", phrase)
    down = math.tan(math.radians(float(degrees.group(1)))) if degrees else (0.35 if "down" in phrase else 0.2)
    length = math.hypot(x, z) or 1.0
    return [round(x / length, 3), round(-down, 3), round(z / length, 3)]


def build() -> dict:
    sys.path.insert(0, str(HERE))
    import markers as M  # noqa: E402

    data = {"hiding_spots": [], "bottles": [], "documents": {}, "props": [], "lights": [], "clawman_spawn": None}
    for m in M.markers:
        position = [m["x"], m["y"], m["z"]]
        kind = m["type"]
        if kind in HIDING_KINDS:
            data["hiding_spots"].append({"name": m["name"], "kind": HIDING_KINDS[kind], "position": position, "yaw": m["rotation_deg"]})
        elif kind == "bottle":
            data["bottles"].append({"name": m["name"], "position": position})
        elif kind == "document":
            data["documents"][re.search(r"document_id=(\w+)", m["params"]).group(1)] = position
        elif kind == "clawman_spawn":
            data["clawman_spawn"] = {"position": position, "yaw": m["rotation_deg"]}
        elif kind == "pack_prop":
            found = re.search(r"(clinic_hospital|clinic_medical|furniture_kit) (\w+)", m["params"])
            if "ward_bed.glb" in m["params"]:
                model, target = WARD_BED, None
            else:
                model = PACKS[found.group(1)] + found.group(2) + ".glb"
                target = number(m["params"], "target_height", 0.0) or None
            data["props"].append({"name": m["name"], "model": model, "target_height": target, "position": position,
                                  "yaw": m["rotation_deg"], "block": bool(m.get("block")), "foot": list(m.get("foot", (0, 0, 0)))})
        elif kind in DEFAULT_COLORS:
            light = {"name": m["name"], "mode": light_mode(m), "spot": kind == "moonlight", "position": position,
                     "color": color(m), "energy": number(m["params"], "energy", 0.5),
                     "range": number(m["params"], "range", 5.0)}
            if kind == "moonlight":
                light["angle"] = number(m["params"], "angle", 40.0)
                light["direction"] = aim(m["params"])
                light["shadow"] = "shadows on" in m["params"]
            data["lights"].append(light)
    return data


def main() -> None:
    data = build()
    OUTPUT.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT}: {len(data['hiding_spots'])} hiding spots, {len(data['bottles'])} bottles, "
          f"{len(data['documents'])} documents, {len(data['props'])} props, {len(data['lights'])} lights")


if __name__ == "__main__":
    main()
