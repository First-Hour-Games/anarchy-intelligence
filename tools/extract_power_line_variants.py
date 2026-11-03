"""Split the material-grouped source pack into nine grounded, Y-up pole GLBs.

Run from any directory with Python 3. Uses only the standard library.
"""
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "models/map/residence/power_line_low_poly.glb"
DESTINATION = SOURCE.parent / "power_lines"


def extract():
    with SOURCE.open("rb") as stream:
        assert stream.read(12)[:4] == b"glTF"
        length, _ = struct.unpack("<II", stream.read(8))
        source = json.loads(stream.read(length))
        length, _ = struct.unpack("<II", stream.read(8))
        binary = stream.read(length)

    def read_accessor(index):
        accessor = source["accessors"][index]
        view = source["bufferViews"][accessor["bufferView"]]
        width = 3 if accessor["type"] == "VEC3" else 1
        code = "f" if accessor["componentType"] == 5126 else "I"
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width * 4)
        return [struct.unpack_from("<" + code * width, binary, offset + i * stride)
                for i in range(accessor["count"])]

    surfaces = []
    intervals = []
    for mesh in source["meshes"]:
        for primitive in mesh["primitives"]:
            vertices = read_accessor(primitive["attributes"]["POSITION"])
            normals = read_accessor(primitive["attributes"]["NORMAL"])
            indices = [value[0] for value in read_accessor(primitive["indices"])]
            triangles = [indices[i:i + 3] for i in range(0, len(indices), 3)]
            surfaces.append((primitive["material"], vertices, normals, triangles))
            intervals.extend((min(vertices[i][2] for i in tri),
                              max(vertices[i][2] for i in tri)) for tri in triangles)

    # Components within one source unit belong to the same pole. The nearest
    # separate poles in this pack are more than eleven source units apart.
    bands = []
    for low, high in sorted(intervals):
        if bands and low <= bands[-1][1] + 1.0:
            bands[-1][1] = max(bands[-1][1], high)
        else:
            bands.append([low, high])
    assert len(bands) == 9, f"Source layout changed: expected 9 poles, got {bands}"
    DESTINATION.mkdir(exist_ok=True)

    for variant, (low, high) in enumerate(bands, 1):
        pole_vertices = [v for _, vertices, _, _ in surfaces for v in vertices
                         if low <= v[2] <= high]
        base_y = max(v[1] for v in pole_vertices)
        base = [v for v in pole_vertices if abs(v[1] - base_y) < 0.05]
        center_x = (min(v[0] for v in base) + max(v[0] for v in base)) / 2
        center_z = (min(v[2] for v in base) + max(v[2] for v in base)) / 2
        output = {"asset": {"version": "2.0"}, "materials": source["materials"],
                  "scenes": [{"nodes": [0]}], "scene": 0,
                  "nodes": [{"mesh": 0, "name": f"PowerLine{variant:02d}"}],
                  "meshes": [{"primitives": []}], "accessors": [], "bufferViews": []}
        data = bytearray()

        def append_accessor(values, kind, component):
            while len(data) % 4:
                data.append(0)
            offset = len(data)
            code = "f" if component == 5126 else "I"
            for value in values:
                data.extend(struct.pack("<" + code * len(value), *value))
            output["bufferViews"].append({"buffer": 0, "byteOffset": offset,
                                          "byteLength": len(data) - offset})
            accessor = {"bufferView": len(output["bufferViews"]) - 1,
                        "componentType": component, "count": len(values), "type": kind}
            if kind == "VEC3":
                accessor["min"] = [min(v[i] for v in values) for i in range(3)]
                accessor["max"] = [max(v[i] for v in values) for i in range(3)]
            output["accessors"].append(accessor)
            return len(output["accessors"]) - 1

        for material, vertices, normals, triangles in surfaces:
            selected = [tri for tri in triangles if low <= vertices[tri[0]][2] <= high]
            if not selected:
                continue
            used = sorted({i for tri in selected for i in tri})
            remap = {old: new for new, old in enumerate(used)}
            # Bake the pack's root rotation and remove its showroom offsets.
            positions = [(vertices[i][0] - center_x, base_y - vertices[i][1],
                          center_z - vertices[i][2]) for i in used]
            directions = [(normals[i][0], -normals[i][1], -normals[i][2]) for i in used]
            output["meshes"][0]["primitives"].append({
                "attributes": {"POSITION": append_accessor(positions, "VEC3", 5126),
                               "NORMAL": append_accessor(directions, "VEC3", 5126)},
                "indices": append_accessor([(remap[i],) for tri in selected for i in tri],
                                           "SCALAR", 5125), "material": material})
        output["buffers"] = [{"byteLength": len(data)}]
        description = json.dumps(output, separators=(",", ":")).encode()
        description += b" " * (-len(description) % 4)
        data.extend(b"\0" * (-len(data) % 4))
        path = DESTINATION / f"power_line_{variant:02d}.glb"
        path.write_bytes(struct.pack("<III", 0x46546C67, 2, 28 + len(description) + len(data))
                         + struct.pack("<II", len(description), 0x4E4F534A) + description
                         + struct.pack("<II", len(data), 0x004E4942) + data)
        print(f"{path.name}: {len(pole_vertices)} source vertices")


if __name__ == "__main__":
    extract()
