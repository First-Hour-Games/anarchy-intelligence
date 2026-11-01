@tool
extends Node3D
## Reuse the imported mesh and UVs, with a predictable origin and meter scale.

const SOURCE: PackedScene = preload("res://models/props/weapons/pipeWeapon.glb")
const MATERIAL: Material = preload("res://models/props/weapons/pipe_metal_material.tres")
@export var grip_origin: bool = false

func _ready() -> void:
	var source := SOURCE.instantiate()
	var geometry := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PipeMesh"
	mesh_instance.mesh = geometry.mesh
	mesh_instance.material_override = MATERIAL
	var bounds := geometry.get_aabb()
	var center := bounds.get_center()
	if grip_origin:
		center.y = bounds.position.y + bounds.size.y * 0.16
	mesh_instance.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.012), -center * 0.012)
	add_child(mesh_instance)
	source.free()
