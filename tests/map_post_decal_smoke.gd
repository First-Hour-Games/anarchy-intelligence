extends SceneTree

# Retains the former decal test entry point; the board now uses mesh geometry
# because the project's Compatibility renderer cannot display Decal nodes.
var failures: int = 0
const MAP_PATH := "res://img/textures/mapPost.png"

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1

func run() -> void:
	for scene_path: String in ["res://scenes/chapters/main/starting_forest.tscn", "res://scenes/chapters/main/map.tscn"]:
		var packed := load(scene_path) as PackedScene
		check(packed != null, "Scene loads: " + scene_path)
		if packed == null:
			continue
		var scene := packed.instantiate()
		var board := scene.find_child("TownMapBoard", true, false) as Node3D
		check(board != null, "Map board exists: " + scene_path)
		if board != null:
			var image := board.get_node("MapImage") as MeshInstance3D
			var quad := image.mesh as QuadMesh
			var material := quad.material as StandardMaterial3D
			check(material.albedo_texture.resource_path == MAP_PATH, "Board shows the updated map in the welcome poster")
			var texture_ratio := material.albedo_texture.get_size().aspect()
			check(is_equal_approx(quad.size.aspect(), texture_ratio), "Map artwork keeps its aspect ratio on the board")
			check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Board remains readable in Compatibility rendering")
			var overlay := scene.get_node("WorldMap/Display") as WorldMapOverlay
			check(overlay.map_texture.resource_path == "res://img/items/cicely_town_map.png", "Collected map uses the labeled PDF artwork")
			check(overlay.map_texture != material.albedo_texture, "Wall map stays unlabeled while collected map has place names")
			check(ItemDatabase.get_item(&"map").image == overlay.map_texture, "Pickup and inventory use the final labeled map")
		scene.free()
	quit(0 if failures == 0 else 1)
