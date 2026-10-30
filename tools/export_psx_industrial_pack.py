"""Split the pack's authored prop groups into standalone, textured GLBs.

Usage: python tools/export_psx_industrial_pack.py path/to/psx_industrial_pack.glb
"""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re

from export_neighborhood_lots import export_lot, read_glb, write_glb
import optimize_psx_industrial_pack


DESTINATION = Path(__file__).resolve().parents[1] / "models/psx_industrial_pack"
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def multiply(left, right):
    """Multiply glTF column-major matrices without changing authored axes."""
    return [sum(left[k * 4 + row] * right[col * 4 + k] for k in range(4))
            for col in range(4) for row in range(4)]


def texture_references(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key.endswith("Texture") and isinstance(child, dict) and "index" in child:
                yield child
            else:
                yield from texture_references(child)
    elif isinstance(value, list):
        for child in value:
            yield from texture_references(child)


def add_textures(source, binary, result, packed):
    refs = list(texture_references(result["materials"]))
    texture_ids = sorted({ref["index"] for ref in refs})
    texture_map = {old: new for new, old in enumerate(texture_ids)}
    for ref in refs:
        ref["index"] = texture_map[ref["index"]]
    textures = [copy.deepcopy(source["textures"][i]) for i in texture_ids]
    assert all(not t.get("extensions") for t in textures), "Unsupported texture extension"
    image_ids = sorted({t["source"] for t in textures})
    sampler_ids = sorted({t["sampler"] for t in textures if "sampler" in t})
    image_map = {old: new for new, old in enumerate(image_ids)}
    sampler_map = {old: new for new, old in enumerate(sampler_ids)}
    for texture in textures:
        texture["source"] = image_map[texture["source"]]
        if "sampler" in texture:
            texture["sampler"] = sampler_map[texture["sampler"]]
    result["textures"] = textures
    result["samplers"] = [copy.deepcopy(source["samplers"][i]) for i in sampler_ids]
    result["images"] = []
    for index in image_ids:
        image = copy.deepcopy(source["images"][index])
        assert "bufferView" in image and "uri" not in image, "Expected embedded image"
        view = copy.deepcopy(source["bufferViews"][image["bufferView"]])
        assert view["buffer"] == 0
        start = view.get("byteOffset", 0)
        payload = binary[start:start + view["byteLength"]]
        assert len(payload) == view["byteLength"]
        packed.extend(b"\0" * (-len(packed) % 4))
        view.update(buffer=0, byteOffset=len(packed))
        image["bufferView"] = len(result["bufferViews"])
        packed.extend(payload)
        result["bufferViews"].append(view)
        result["images"].append(image)
    result["buffers"][0]["byteLength"] = len(packed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    source, binary = read_glb(args.source)
    assert not source.get("skins") and not source.get("animations")
    root_ids = [i for i, node in enumerate(source["nodes"]) if node.get("name") == "RootNode"]
    assert len(root_ids) == 1, "Expected the pack's authored RootNode"
    parents = {child: i for i, node in enumerate(source["nodes"])
               for child in node.get("children", [])}
    groups = source["nodes"][root_ids[0]]["children"]
    assert len(groups) == 37, "Expected 36 props and the Showcase assembly"
    DESTINATION.mkdir(parents=True, exist_ok=True)
    manifest = {"source_sha256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
                "assets": []}
    for index in groups:
        name = source["nodes"][index]["name"]
        filename = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", name).lower() + ".glb"
        result, packed = export_lot(source, binary, index)
        chain = [index]
        while chain[-1] in parents:
            chain.append(parents[chain[-1]])
        matrix = IDENTITY[:]
        for ancestor in reversed(chain):
            node = source["nodes"][ancestor]
            assert not any(key in node for key in ("translation", "rotation", "scale"))
            matrix = multiply(matrix, node.get("matrix", IDENTITY))
        # Remove the pack's lineup translation only. Preserve combined scale,
        # orientation, authored pivots, and every nested assembly transform.
        matrix[12:15] = [0, 0, 0]
        result["nodes"][0]["matrix"] = matrix
        add_textures(source, binary, result, packed)
        path = DESTINATION / filename
        write_glb(path, result, packed)
        reread, reread_binary = read_glb(path)
        assert reread == result and reread_binary[:len(packed)] == packed
        for view in result["bufferViews"]:
            assert view["byteOffset"] + view["byteLength"] <= len(packed)
        manifest["assets"].append({"name": name, "file": filename,
                                   "meshes": len(result["meshes"]),
                                   "source_node": index,
                                   "export_root_matrix": matrix})
        print(f"{filename}: {len(result['meshes'])} meshes, {len(result['images'])} embedded textures")
    (DESTINATION / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    assert hashlib.sha256(args.source.read_bytes()).hexdigest() == manifest["source_sha256"]
    print(f"Exported {len(groups)} standalone models to {DESTINATION}")
    # Share the two atlases, trim per-prop buffers, and add collision boxes.
    for path in sorted(DESTINATION.glob("*.glb")):
        optimize_psx_industrial_pack.optimize(path, DESTINATION)


if __name__ == "__main__":
    main()
