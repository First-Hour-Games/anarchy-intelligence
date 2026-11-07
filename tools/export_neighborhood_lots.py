"""Export the authored lots from hood.Final.glb as compact, standalone GLBs."""

import copy
import json
from pathlib import Path
import re
import struct


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scenes/chapters/main/hood.Final.glb"
DESTINATION = ROOT / "models/buildings/neighborhood_lots"


def read_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and length == len(data)
    offset = 12
    chunks = {}
    while offset < length:
        size, kind = struct.unpack_from("<II", data, offset)
        chunks[kind] = data[offset + 8:offset + 8 + size]
        offset += 8 + size
    return json.loads(chunks[0x4E4F534A]), chunks[0x004E4942]


def write_glb(path, document, binary):
    encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    binary = bytes(binary) + b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(encoded) + 8 + len(binary)
    path.write_bytes(
        struct.pack("<III", 0x46546C67, 2, total)
        + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
        + struct.pack("<II", len(binary), 0x004E4942) + binary
    )


def export_lot(source, binary, root_index):
    node_ids = []

    def visit(index):
        node_ids.append(index)
        for child in source["nodes"][index].get("children", []):
            visit(child)

    visit(root_index)
    mesh_ids = sorted({source["nodes"][i]["mesh"] for i in node_ids
                       if "mesh" in source["nodes"][i]})
    primitives = [p for i in mesh_ids for p in source["meshes"][i]["primitives"]]
    assert all(set(p) <= {"attributes", "indices", "material", "mode"}
               for p in primitives), "Unsupported primitive data"
    accessor_ids = sorted({a for p in primitives for a in p["attributes"].values()}
                          | {p["indices"] for p in primitives if "indices" in p})
    assert all("sparse" not in source["accessors"][i] for i in accessor_ids)
    view_ids = sorted({source["accessors"][i]["bufferView"] for i in accessor_ids})
    material_ids = sorted({p["material"] for p in primitives if "material" in p})
    maps = [{old: new for new, old in enumerate(ids)}
            for ids in [node_ids, mesh_ids, accessor_ids, view_ids, material_ids]]
    node_map, mesh_map, accessor_map, view_map, material_map = maps
    result = {
        "asset": copy.deepcopy(source["asset"]),
        "scene": 0,
        "scenes": [{"name": source["nodes"][root_index]["name"], "nodes": [0]}],
        "nodes": [], "meshes": [], "accessors": [], "bufferViews": [],
        "materials": [copy.deepcopy(source["materials"][i]) for i in material_ids],
    }
    for key in ["extensionsUsed", "extensionsRequired"]:
        if key in source:
            result[key] = copy.deepcopy(source[key])
    for index in node_ids:
        node = copy.deepcopy(source["nodes"][index])
        assert "skin" not in node
        if "children" in node:
            node["children"] = [node_map[i] for i in node["children"]]
        if "mesh" in node:
            node["mesh"] = mesh_map[node["mesh"]]
        if index == root_index:
            # Use the authored curb-center pivot; remove neighborhood placement.
            for key in ["translation", "rotation", "scale", "matrix"]:
                node.pop(key, None)
        result["nodes"].append(node)
    for index in mesh_ids:
        mesh = copy.deepcopy(source["meshes"][index])
        for primitive in mesh["primitives"]:
            primitive["attributes"] = {key: accessor_map[value]
                                       for key, value in primitive["attributes"].items()}
            if "indices" in primitive:
                primitive["indices"] = accessor_map[primitive["indices"]]
            if "material" in primitive:
                primitive["material"] = material_map[primitive["material"]]
        result["meshes"].append(mesh)
    for index in accessor_ids:
        accessor = copy.deepcopy(source["accessors"][index])
        accessor["bufferView"] = view_map[accessor["bufferView"]]
        result["accessors"].append(accessor)
    packed = bytearray()
    for index in view_ids:
        view = copy.deepcopy(source["bufferViews"][index])
        assert view["buffer"] == 0
        packed.extend(b"\0" * (-len(packed) % 4))
        start = view.get("byteOffset", 0)
        payload = binary[start:start + view["byteLength"]]
        assert len(payload) == view["byteLength"]
        view.update(buffer=0, byteOffset=len(packed))
        packed.extend(payload)
        result["bufferViews"].append(view)
    result["buffers"] = [{"byteLength": len(packed)}]
    return result, packed


def main():
    source, binary = read_glb(SOURCE)
    assert not any(source.get(key) for key in ["images", "textures", "skins", "animations"])
    lots = [i for i, node in enumerate(source["nodes"])
            if re.fullmatch(r"Lot\d+_.+_LOT", node.get("name", ""))]
    assert len(lots) == 12, "Expected 12 authored lots"
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for index in lots:
        name = source["nodes"][index]["name"]
        match = re.fullmatch(r"Lot(\d+)_(.+)_LOT", name)
        style = re.sub(r"(?<=[a-z])(?=[A-Z])", "_", match[2]).lower()
        path = DESTINATION / f"lot_{int(match[1]):02d}_{style}.glb"
        document, packed = export_lot(source, binary, index)
        write_glb(path, document, packed)
        # Re-read the actual file and verify every retained geometry buffer.
        exported, exported_binary = read_glb(path)
        assert exported == document
        assert exported_binary[:len(packed)] == packed
        print(f"{path.name}: {len(document['meshes'])} meshes, {path.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
