"""Share textures, trim buffers, and add collision boxes to the PSX industrial props.

The split exporter (export_psx_industrial_pack.py) leaves every prop GLB carrying
its own copy of the pack's texture atlases and the whole pack's vertex buffers.
This rewrites each GLB in place so that it:

* references the two shared atlas PNGs by URI instead of embedding them,
* keeps only the vertex/index data its own meshes use,
* gains a "<Name>Collision-convcolonly" box mesh, which Godot's importer turns
  into a StaticBody3D with a box-shaped collision hull (the box itself is not
  rendered). The box is the tight bounds of the prop's meshes in its root space.

Safe to run again: already-optimized files are left as they are.

Usage: python tools/optimize_psx_industrial_pack.py [pack_directory]
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

from export_neighborhood_lots import read_glb, write_glb


DEFAULT_PACK = Path(__file__).resolve().parents[1] / "models/psx_industrial_pack"
COMPONENT_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
TYPE_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
COLLISION_SUFFIX = "Collision-convcolonly"
MIN_THICKNESS = 0.02
# The showcase is the pack's whole display lineup; one box would wall off ~13 x 10 m.
NO_COLLISION = {"showcase.glb"}  # Keep flat props (sheets, planks) from producing a zero-width hull.


def multiply(left, right):
    return [sum(left[k * 4 + row] * right[col * 4 + k] for k in range(4))
            for col in range(4) for row in range(4)]


def transform_point(m, p):
    return [m[row] * p[0] + m[4 + row] * p[1] + m[8 + row] * p[2] + m[12 + row]
            for row in range(3)]


def accessor_bytes(document, binary, accessor):
    """Return an accessor's elements tightly packed."""
    assert "sparse" not in accessor
    element = COMPONENT_SIZE[accessor["componentType"]] * TYPE_COUNT[accessor["type"]]
    view = document["bufferViews"][accessor["bufferView"]]
    stride = view.get("byteStride", element)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    count = accessor["count"]
    if stride == element:
        data = bytes(binary[start:start + count * element])
    else:
        data = b"".join(binary[start + i * stride:start + i * stride + element]
                        for i in range(count))
    assert len(data) == count * element
    return data


def atlas_name(view_name):
    # "M_Industrial2_baseColor.png" -> "industrial2_basecolor.png"
    return re.sub(r"^m_", "", view_name.lower())


def node_matrix(node):
    assert not any(key in node for key in ("translation", "rotation", "scale"))
    return node.get("matrix", IDENTITY)


def optimize(path, pack):
    document, binary = read_glb(path)
    root_index = document["scenes"][document.get("scene", 0)]["nodes"][0]
    root = document["nodes"][root_index]
    wants_collision = path.name not in NO_COLLISION
    has_collision = any(document["nodes"][c]["name"].endswith(COLLISION_SUFFIX)
                        for c in root.get("children", []))
    if (has_collision or not wants_collision) and all("uri" in image for image in document.get("images", [])):
        return None

    # 1. Point images at the shared atlas files.
    for image in document.get("images", []):
        if "uri" in image:
            continue
        view = document["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        payload = bytes(binary[start:start + view["byteLength"]])
        filename = atlas_name(view["name"])
        target = pack / filename
        if target.exists():
            assert target.read_bytes() == payload, f"{filename} differs from the copy in {path.name}"
        else:
            target.write_bytes(payload)
        image.clear()
        image["uri"] = filename

    # 2. Collision box from the actual vertices, in the root node's space.
    points = []

    def visit(index, matrix):
        node = document["nodes"][index]
        if node["name"].endswith(COLLISION_SUFFIX):
            return
        if "mesh" in node:
            for primitive in document["meshes"][node["mesh"]]["primitives"]:
                accessor = document["accessors"][primitive["attributes"]["POSITION"]]
                assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
                data = accessor_bytes(document, binary, accessor)
                points.extend(transform_point(matrix, p) for p in struct.iter_unpack("<3f", data))
        for child in node.get("children", []):
            visit(child, multiply(matrix, node_matrix(document["nodes"][child])))

    bounds = None
    if wants_collision and not has_collision:
        for child in root.get("children", []):
            visit(child, node_matrix(document["nodes"][child]))
        low = [min(p[i] for p in points) for i in range(3)]
        high = [max(p[i] for p in points) for i in range(3)]
        for i in range(3):
            if high[i] - low[i] < MIN_THICKNESS:
                middle = (high[i] + low[i]) / 2
                low[i], high[i] = middle - MIN_THICKNESS / 2, middle + MIN_THICKNESS / 2
        bounds = (low, high)

    # 3. Rebuild the binary buffer with only the accessors still in use.
    packed = bytearray()
    views = []

    def add_view(data, target, stride=None):
        packed.extend(b"\0" * (-len(packed) % 4))
        view = {"buffer": 0, "byteOffset": len(packed), "byteLength": len(data)}
        if target:
            view["target"] = target
        if stride:
            view["byteStride"] = stride
        packed.extend(data)
        views.append(view)
        return len(views) - 1

    index_accessors = {p["indices"] for m in document["meshes"] for p in m["primitives"] if "indices" in p}
    for i, accessor in enumerate(document["accessors"]):
        data = accessor_bytes(document, binary, accessor)
        element = COMPONENT_SIZE[accessor["componentType"]] * TYPE_COUNT[accessor["type"]]
        if i in index_accessors:
            accessor["bufferView"] = add_view(data, 34963)
        else:
            accessor["bufferView"] = add_view(data, 34962, element if element % 4 == 0 else None)
        accessor.pop("byteOffset", None)

    if bounds:
        low, high = bounds
        corners = [[(high if (c >> axis) & 1 else low)[axis] for axis in range(3)] for c in range(8)]
        # Two outward-facing triangles per box face (corner bit 0=x, 1=y, 2=z).
        faces = [(0, 2, 6, 4), (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6), (0, 1, 3, 2), (4, 6, 7, 5)]
        indices = [i for a, b, c, d in faces for i in (a, b, c, a, c, d)]
        position = len(document["accessors"])
        document["accessors"].append({
            "bufferView": add_view(b"".join(struct.pack("<3f", *c) for c in corners), 34962, 12),
            "componentType": 5126, "count": 8, "type": "VEC3",
            "min": [min(c[i] for c in corners) for i in range(3)],
            "max": [max(c[i] for c in corners) for i in range(3)]})
        document["accessors"].append({
            "bufferView": add_view(struct.pack(f"<{len(indices)}H", *indices), 34963),
            "componentType": 5123, "count": len(indices), "type": "SCALAR"})
        document["meshes"].append({"name": root["name"] + "Collision", "primitives": [
            {"attributes": {"POSITION": position}, "indices": position + 1, "mode": 4}]})
        document["nodes"].append({"name": root["name"] + COLLISION_SUFFIX,
                                  "mesh": len(document["meshes"]) - 1})
        root.setdefault("children", []).append(len(document["nodes"]) - 1)

    document["bufferViews"] = views
    document["buffers"] = [{"byteLength": len(packed)}]

    before = path.stat().st_size
    old_document, old_binary = read_glb(path)
    write_glb(path, document, packed)

    # Verify every original accessor still decodes to identical bytes.
    new_document, new_binary = read_glb(path)
    assert new_document == document
    for i, accessor in enumerate(old_document["accessors"]):
        assert accessor_bytes(old_document, old_binary, accessor) == \
            accessor_bytes(new_document, new_binary, new_document["accessors"][i])
    return before, path.stat().st_size, bounds


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path, nargs="?", default=DEFAULT_PACK)
    args = parser.parse_args()
    pack = args.pack.resolve()
    manifest_path = pack / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else None
    total_before = total_after = 0
    for path in sorted(pack.glob("*.glb")):
        result = optimize(path, pack)
        if result is None:
            print(f"{path.name}: already optimized")
            continue
        before, after, bounds = result
        total_before += before
        total_after += after
        size = [round(h - l, 3) for l, h in zip(*bounds)] if bounds else None
        print(f"{path.name}: {before // 1024} KB -> {after // 1024} KB, collision box {size}")
        if manifest and bounds:
            for asset in manifest["assets"]:
                if asset["file"] == path.name:
                    asset["collision_box"] = {"min": [round(v, 5) for v in bounds[0]],
                                              "max": [round(v, 5) for v in bounds[1]]}
    if manifest:
        manifest["shared_textures"] = sorted(p.name for p in pack.glob("*_basecolor.png"))
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    if total_before:
        print(f"GLBs: {total_before / 1048576:.1f} MB -> {total_after / 1048576:.2f} MB")


if __name__ == "__main__":
    main()
