extends SceneTree

class SilentZone extends MapBoundaryZone3D:
	func _play_dialogue(_player: Node3D = null, _text: String = "") -> void:
		pass

var failures := 0
var warnings := 0

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1

func _initialize() -> void:
	_run.call_deferred()

func make_zone(center: Vector3) -> SilentZone:
	var zone := SilentZone.new()
	zone.size = Vector3(10, 6, 10)
	zone.position = center
	zone.blink_and_return = false
	zone.cooldown = 0.0
	zone.boundary_warning_triggered.connect(func(_player: Node3D, _text: String) -> void: warnings += 1)
	root.add_child(zone)
	return zone

func _run() -> void:
	var a := make_zone(Vector3.ZERO)
	var b := make_zone(Vector3(8, 0, 0))
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	root.add_child(player)
	await physics_frame
	await process_frame
	a._on_body_entered(player)
	player.position = Vector3(7, 0, 0)
	a._on_body_exited(player)
	await process_frame
	check(warnings == 0, "Leaving A while inside B does not warn, even before B's entry signal")
	b._on_body_entered(player)
	player.position = Vector3(4, 0, 0)
	b._on_body_exited(player)
	await process_frame
	check(warnings == 0, "Crossing back into overlap does not warn")
	player.position = Vector3(20, 0, 0)
	a._on_body_exited(player)
	b._on_body_exited(player)
	await process_frame
	check(warnings == 1, "Exiting all zones emits one warning for simultaneous exits")
	b._teleport_player_inwards(player)
	check(b.is_point_inside(player.global_position), "Return places player inside the last exited zone")
	await physics_frame
	await process_frame
	b.is_enabled = false
	player.position = Vector3(7, 0, 0)
	a._on_body_exited(player)
	await process_frame
	check(warnings == 2, "Disabled allowed zone does not extend playable area")
	await physics_frame
	await process_frame
	b.is_enabled = true
	b.zone_behavior = MapBoundaryZone3D.ZoneBehavior.RESTRICTED_AREA
	a._on_body_exited(player)
	await process_frame
	check(warnings == 3, "Restricted zone does not extend playable area")
	b._on_body_entered(player)
	check(warnings == 4, "Restricted zone still warns on entry")
	b.zone_behavior = MapBoundaryZone3D.ZoneBehavior.ALLOWED_PLAY_AREA
	b.rotation.y = PI / 4.0
	b.scale = Vector3(2, 1, 1)
	player.global_position = b.to_global(Vector3(4, 0, 0))
	a._on_body_exited(player)
	await process_frame
	check(warnings == 4, "Rotated and scaled allowed zones join the union")
	a.free()
	b.free()
	player.free()
	await process_frame
	print("Boundary union tests: %d failures" % failures)
	quit(failures)
