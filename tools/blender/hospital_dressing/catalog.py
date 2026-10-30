"""Hospital equipment catalogue: merges PROPS (and extra materials) from every prop module in
this folder. Imported by build_hospital_interior.py inside Blender and by
hospital_layout/validate.py in plain Python, so prop modules must not import bpy at module level.
"""

import importlib.util
from pathlib import Path

FOLDER = Path(__file__).resolve().parent
# Tools in this folder that are not prop modules.
NOT_PROPS = {"catalog.py", "preview.py", "render_zone.py"}
MOUNTS = {"floor", "wall", "surface", "ceiling"}


def modules() -> list:
    found = []
    for path in sorted(FOLDER.glob("*.py")):
        if path.name in NOT_PROPS or path.name.startswith("_"):
            continue
        spec = importlib.util.spec_from_file_location("hospital_dressing_" + path.stem, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        found.append(module)
    return found


def check_spec(key: str, spec: dict, source: str) -> None:
    where = f"prop {key!r} in {source}"
    if not callable(spec.get("build")):
        raise ValueError(f"{where}: 'build' must be callable")
    size = spec.get("size")
    if not (isinstance(size, (tuple, list)) and len(size) == 3 and all(v > 0 for v in size)):
        raise ValueError(f"{where}: 'size' must be three positive numbers (w, h, d)")
    if spec.get("mount") not in MOUNTS:
        raise ValueError(f"{where}: 'mount' must be one of {sorted(MOUNTS)}")
    if spec["mount"] == "wall" and not isinstance(spec.get("y"), (int, float)):
        raise ValueError(f"{where}: wall props need a default base height 'y'")


def load(palette: dict | None = None, emission: dict | None = None, alpha: dict | None = None) -> dict:
    """All props by key. Pass the builder's material tables to merge each module's extras."""
    props: dict = {}
    for module in modules():
        source = Path(module.__file__).name
        for table, attribute in ((palette, "PALETTE"), (emission, "EMISSION"), (alpha, "ALPHA")):
            if table is None:
                continue
            for name, value in getattr(module, attribute, {}).items():
                if name in table and table[name] != value:
                    raise ValueError(f"{source} redefines material {name!r} in {attribute}")
                table[name] = value
        for key, spec in module.PROPS.items():
            if key in props:
                raise ValueError(f"prop {key!r} is defined in {props[key]['module']} and {source}")
            check_spec(key, spec, source)
            props[key] = dict(spec, module=source)
    return props


def describe(props: dict) -> str:
    """One line per prop: key, mount, size, default height, collision, options and description."""
    import inspect
    lines = []
    for key, spec in sorted(props.items(), key=lambda item: (item[1]["module"], item[0])):
        parameters = inspect.signature(spec["build"]).parameters.values()
        options = [f"{p.name}={p.default!r}" for p in parameters
                   if p.name not in ("B", "name", "x", "z", "yaw", "y") and p.default is not inspect.Parameter.empty]
        w, h, d = spec["size"]
        height = f" y={spec['y']}" if spec["mount"] == "wall" else ""
        lines.append(f"{key} [{spec['module'][:-3]}] {spec['mount']}{height} size=({w}, {h}, {d}) "
                     f"collide={spec.get('collide', True)} options: {', '.join(options) or '-'} | {spec.get('desc', '')}")
    return "\n".join(lines)


if __name__ == "__main__":
    print(describe(load()))
