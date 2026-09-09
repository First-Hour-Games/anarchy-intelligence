@tool
extends Node3D

## Adapts Kenney's rounded road end to the neighborhood's darker road palette.

@export var road_tint := Color(0.32, 0.30, 0.27, 1.0)


func _ready() -> void:
	get_node("RoadModel").visible = false
	if not visible:
		return
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_texture = load("res://assets/local_licensed/street_materials/textures/asphalt_02_diff_4k.jpg")
	asphalt.uv1_triplanar = true
	asphalt.uv1_scale = Vector3.ONE / 3.0
	asphalt.roughness = 0.95
	var approach := get_node_or_null("../../Roads/Crossroad") as CSGBox3D
	if approach != null:
		approach.material = asphalt
	var concrete := StandardMaterial3D.new()
	concrete.albedo_texture = load("res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3.ONE * 0.5
	var geometry := Node3D.new()
	geometry.name = "LowerTurnaround"
	add_child(geometry)
	geometry.position.y = -0.1
	# Same 10.44m bulb radius as the upper street; retain the 8m road mouth.
	var mouth_x := sqrt(93.0)
	geometry.position.x = 8.0 - mouth_x
	preload("res://scenes/environment/turnaround_geometry.gd").build(geometry, mouth_x, 4.0, asphalt, concrete)


func _apply_road_finish(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var source_material := mesh_instance.get_active_material(0) as StandardMaterial3D
		if source_material != null:
			var finished_material := source_material.duplicate() as StandardMaterial3D
			finished_material.albedo_color = road_tint
			finished_material.roughness = 0.95
			mesh_instance.material_override = finished_material
	for child: Node in node.get_children():
		_apply_road_finish(child)
