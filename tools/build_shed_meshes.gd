extends SceneTree
## Builds the alt route's shed from the gas station's garage (models/buildings/gasStation/industrial_warehouse.glb,
## "Industrial Warehouse" by VertexForge, CC BY 4.0; read, never written): the garage's mesh without the panel
## of the side door in its east end, a collision for it, and that panel on its own as a door leaf. The wall
## already has the opening behind the panel, and the frame round it stays, so taking the panel out leaves a
## doorway. The collision stops the player from both sides of every face, inside the garage too.
##
## industrial_warehouse_shed.tscn holds the doorless mesh where the GLB holds the whole one, so the alt route
## instances it in the garage's place. It draws the mesh twice: the garage's faces point out, so "Building"
## draws their fronts, the outside, and casts the shadows; "Inside" draws their backs on INSIDE_LAYER, which
## a light outside can leave out. The gas station's pump sign lights the garage from forty metres off, too
## far for its shadows to stop at walls with no thickness, and would otherwise show through every seam.
## The leaf is written in metres in its own frame, as where the alt route places the garage puts it: its
## hinge edge on the Y axis at the origin, its width along +X toward the handle, its face toward -Z, out of
## the garage.
##
## godot --headless --path . --script res://tools/build_shed_meshes.gd

const SOURCE := "res://models/buildings/gasStation/industrial_warehouse.glb"
const MESH_NODE := "Cube_001_Industrial_0"
## Where the alt route places the garage, for the door leaf's world size and its hinge.
const ROUTE_SCENE := "res://scenes/chapters/alt_route/starting_forest_alt.tscn"
const ROUTE_NODE := "WarehouseBuilding"
const OUT := "res://models/buildings/gasStation/"
## The door's panel, in the garage's own frame (the GLB's root): flat in the plane z = PANEL_Z, between these
## corners on x and y. The faces of the frame round it step back out to the wall and are not taken.
const PANEL_Z := 2.7415
const PANEL_LOW := Vector2(0.58, -0.01)
const PANEL_HIGH := Vector2(1.04, 0.92)
const PANEL_TOLERANCE := 0.002
## The panel's edge on the garage's corner side, along x: the hinge.
const HINGE_X := 1.0222
## Render layer 12, for the shed's inside alone.
const INSIDE_LAYER := 1 << 11

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var source := (load(SOURCE) as PackedScene).instantiate() as Node3D
	root.add_child(source)
	var route := (load(ROUTE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(route)
	await process_frame
	var garage_world := (route.get_node(ROUTE_NODE) as Node3D).global_transform
	var mesh_node := source.find_child(MESH_NODE, true, false) as MeshInstance3D
	var to_garage := source.global_transform.affine_inverse() * mesh_node.global_transform
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var material := (mesh_node.get_active_material(0) as Material).duplicate() as Material
	material.resource_name = "IndustrialShed"
	ResourceSaver.save(material, OUT + "industrial_warehouse_shed_material.tres")
	material.take_over_path(OUT + "industrial_warehouse_shed_material.tres")

	var building := SurfaceTool.new()
	building.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_triangles: Array[int] = []
	var collision := PackedVector3Array()
	for t in range(0, indices.size(), 3):
		var in_panel := true
		for i in 3:
			var p := to_garage * vertices[indices[t + i]]
			in_panel = in_panel and absf(p.z - PANEL_Z) < PANEL_TOLERANCE and p.x > PANEL_LOW.x and p.x < PANEL_HIGH.x \
				and p.y > PANEL_LOW.y and p.y < PANEL_HIGH.y
		if in_panel:
			leaf_triangles.append(t)
			continue
		for i in 3:
			var index := indices[t + i]
			building.set_normal(normals[index])
			building.set_uv(uvs[index])
			building.add_vertex(vertices[index])
			collision.append(to_garage * vertices[index])
	if leaf_triangles.size() < 4:
		push_error("Found no door panel in the garage's east end")
		quit(1)
		return
	building.set_material(material)
	var building_mesh := building.commit()

	# The door leaf's frame in the world: the hinge edge at the panel's foot, +X across the panel.
	var hinge_world := garage_world * Vector3(HINGE_X, 0.0, PANEL_Z)
	hinge_world.y = garage_world.origin.y
	var across := (garage_world.basis * Vector3(-1.0, 0.0, 0.0)).normalized()
	var outward := (garage_world.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var leaf_frame := Transform3D(Basis(across, Vector3.UP, -outward), hinge_world)
	var to_leaf := leaf_frame.affine_inverse() * garage_world * to_garage
	var leaf := SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in leaf_triangles:
		for i in 3:
			var index := indices[t + i]
			leaf.set_normal((to_leaf.basis * normals[index]).normalized())
			leaf.set_uv(uvs[index])
			leaf.add_vertex(to_leaf * vertices[index])
	leaf.set_material(material)
	var leaf_mesh := leaf.commit()

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision)
	# The garage's faces point out, and now there is an inside to keep the player in.
	shape.backface_collision = true
	ResourceSaver.save(building_mesh, OUT + "industrial_warehouse_shed.res")
	building_mesh.take_over_path(OUT + "industrial_warehouse_shed.res")
	ResourceSaver.save(leaf_mesh, OUT + "industrial_warehouse_shed_door.res")
	ResourceSaver.save(shape, OUT + "industrial_warehouse_shed_collision.res")

	var shed := Node3D.new()
	shed.name = "IndustrialWarehouseShed"
	var outside_material := material.duplicate() as BaseMaterial3D
	outside_material.cull_mode = BaseMaterial3D.CULL_BACK
	var inside_material := material.duplicate() as BaseMaterial3D
	inside_material.cull_mode = BaseMaterial3D.CULL_FRONT
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Building"
	mesh_instance.mesh = building_mesh
	mesh_instance.material_override = outside_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	mesh_instance.transform = to_garage
	shed.add_child(mesh_instance)
	mesh_instance.owner = shed
	var inside_instance := MeshInstance3D.new()
	inside_instance.name = "Inside"
	inside_instance.mesh = building_mesh
	inside_instance.material_override = inside_material
	inside_instance.layers = INSIDE_LAYER
	inside_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inside_instance.transform = to_garage
	shed.add_child(inside_instance)
	inside_instance.owner = shed
	var packed := PackedScene.new()
	packed.pack(shed)
	ResourceSaver.save(packed, OUT + "industrial_warehouse_shed.tscn")
	shed.free()
	var leaf_box := leaf_mesh.get_aabb()
	print("shed: %d of %d triangles kept, door leaf %d triangles, %.2f m wide and %.2f m tall, hinge at %s facing %s" % [
		indices.size() / 3 - leaf_triangles.size(), indices.size() / 3, leaf_triangles.size(), leaf_box.size.x,
		leaf_box.end.y, hinge_world.snapped(Vector3.ONE * 0.001), outward.snapped(Vector3.ONE * 0.001)])
	route.free()
	source.free()
	quit()
