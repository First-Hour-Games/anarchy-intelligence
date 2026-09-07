@tool
extends Node3D

var concrete: StandardMaterial3D
var crossings: Array[Vector3] = []

func _ready() -> void:
	call_deferred("build")

func build() -> void:
	concrete = StandardMaterial3D.new()
	concrete.albedo_texture = load("res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3.ONE * 0.5
	concrete.roughness = 0.95
	var index := 0
	for house: Node3D in get_node("../Buildings/ResidentialLots").get_children():
		if not (String(house.name).begins_with("Connector") or String(house.name).begins_with("CrossroadNorth") or String(house.name).begins_with("CrossroadSouth")):
			continue
		var lot := Node3D.new()
		lot.name = String(house.name) + "Connections"
		add_child(lot)
		lot.global_transform = house.global_transform
		var side := 1.0 if index % 2 == 0 else -1.0
		index += 1
		_box(lot, "SideParking", Vector3(side * 9.5, 0.06, 8.25), Vector3(3.4, 0.12, 12.5))
		_box(lot, "DriveCrossing", Vector3(side * 9.5, 0.06, 15.4), Vector3(3.4, 0.12, 1.8))
		_box(lot, "DriveApron", Vector3(side * 9.5, 0.06, 17.15), Vector3(3.4, 0.12, 1.7))
		_box(lot, "FrontDoorPath", Vector3(0, 0.06, 12.35), Vector3(1.4, 0.12, 4.3))
		_box(lot, "ParkingToDoor", Vector3(side * 4.25, 0.06, 11.3), Vector3(7.1, 0.12, 1.4))
		crossings.append(house.global_transform * Vector3(side * 9.5, 0, 18))
	var curb_names := ["ConnectorRoad_West_1", "ConnectorRoad_West_2", "ConnectorRoad_West_3", "ConnectorRoad_East_1", "ConnectorRoad_East_2", "Crossroad_North_1", "Crossroad_North_2", "Crossroad_South_1"]
	for name: String in curb_names:
		var curb := get_node("../Curbs/" + name) as CSGBox3D
		var vertical := name.begins_with("Connector")
		var fixed := curb.position.x if vertical else curb.position.z
		var center := curb.position.z if vertical else curb.position.x
		var length := curb.size.z if vertical else curb.size.x
		var start := center - length * 0.5
		var end := center + length * 0.5
		var openings: Array[float] = []
		for point: Vector3 in crossings:
			var along := point.z if vertical else point.x
			var across := point.x if vertical else point.z
			if absf(across - fixed) < 0.3 and along > start and along < end:
				openings.append(along)
		openings.sort()
		var inside := -2.5 if fixed < (100.0 if vertical else 225.0) else 2.5
		var cursor := start
		for opening: float in openings:
			_segment("Sidewalk", vertical, fixed + inside, cursor, opening - 1.7, 1.8, false)
			cursor = opening + 1.7
		_segment("Sidewalk", vertical, fixed + inside, cursor, end, 1.8, false)
		curb.visible = false
		curb.use_collision = false
		cursor = start
		for opening: float in openings:
			_segment("CutCurb", vertical, fixed, cursor, opening - 1.95, 0.2, true)
			cursor = opening + 1.95
		_segment("CutCurb", vertical, fixed, cursor, end, 0.2, true)

func _segment(label: String, vertical: bool, fixed: float, start: float, end: float, width: float, solid: bool) -> void:
	if end <= start:
		return
	var point := Vector3(fixed, 0.06, (start + end) * 0.5) if vertical else Vector3((start + end) * 0.5, 0.06, fixed)
	var size := Vector3(width, 0.12, end - start) if vertical else Vector3(end - start, 0.12, width)
	_box(self, label, point, size, solid)

func _box(parent: Node3D, label: String, point: Vector3, size: Vector3, solid: bool = false) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = concrete
	parent.add_child(visual)
	visual.position = point
	if solid:
		visual.create_trimesh_collision()
