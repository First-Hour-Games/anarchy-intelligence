@tool
extends SceneTree

## Standalone tool script to prune trees and foliage across starting_forest.tscn and residence_area.tscn.
## Can also be invoked in headless mode or from the Godot editor.

const TARGET_SCENES: Array[String] = [
	"res://scenes/chapters/main/starting_forest.tscn",
	"res://scenes/environment/residence_foliage.tscn"
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Running Standalone Tree & Foliage Pruner ===")
	for scene_path in TARGET_SCENES:
		print("\n--- Processing scene: %s ---" % scene_path)
		var packed := load(scene_path) as PackedScene
		if not packed:
			printerr("Failed to load scene: %s" % scene_path)
			continue

		var root_node := packed.instantiate()
		root.add_child(root_node)
		await process_frame

		# 1. Prune using ProceduralTreeGenerator if present
		var tree_gens := root_node.find_children("*", "ProceduralTreeGenerator", true, false)
		for gen in tree_gens:
			if gen.has_method(&"prune_all_trees_and_foliage"):
				print("Found ProceduralTreeGenerator '%s', running prune_all_trees_and_foliage()..." % gen.name)
				gen.call(&"prune_all_trees_and_foliage")

		# 2. Prune using TreeExclusionZone3D nodes
		var zones := root_node.find_children("*", "TreeExclusionZone3D", true, false)
		for zone in zones:
			if zone.has_method(&"prune_trees_and_foliage"):
				print("Found TreeExclusionZone3D '%s', running prune_trees_and_foliage()..." % zone.name)
				zone.call(&"prune_trees_and_foliage", root_node)

		# 3. Prune using ProceduralGrassGenerator if present
		var grass_gens := root_node.find_children("*", "ProceduralGrassGenerator", true, false)
		for grass in grass_gens:
			if grass.has_method(&"prune_instances"):
				print("Found ProceduralGrassGenerator '%s', running prune_instances()..." % grass.name)
				grass.call(&"prune_instances")

		root_node.queue_free()
		await process_frame

	print("\n=== Tree & Foliage Pruning Complete ===")
	quit()
