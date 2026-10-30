extends SceneTree

# Carrie's house in its test scene: collision with footstep surfaces, the ground opened over
# the cellar, furniture boxes, hiding spots in the house's own furniture, the lights that still
# work, doors open only on the route the story uses, enemy route gates through the front door
# and up and down the main stair, and the story's named points. Walking the routes is
# carrie_house_routes_smoke.gd.

const FOOTSTEPS := preload("res://scenes/player/footstep_surfaces.gd")

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func wait_physics(frames: int) -> void:
	for frame in frames:
		await physics_frame


## What lies straight below a house-local point, cast from just above it.
func floor_below(house: Node3D, local: Vector3, exclude: Array[RID]) -> Dictionary:
	var from := house.to_global(local + Vector3.UP * 0.4)
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
	ray.exclude = exclude
	return house.get_world_3d().direct_space_state.intersect_ray(ray)


func surface_at(house: Node3D, local: Vector3, exclude: Array[RID]) -> String:
	var hit := floor_below(house, local, exclude)
	if hit.is_empty() or absf(house.to_local(hit.position).y - local.y) > 0.06:
		return "none"
	return str(FOOTSTEPS.classify(hit.collider))


## Whether the player fits where the spot lets them out, standing on a floor.
func exit_is_clear(house: Node3D, spot: HidingSpot, capsule: CapsuleShape3D, exclude: Array[RID]) -> bool:
	var exit := spot.exit_position()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, exit + Vector3.UP * (capsule.height * 0.5 + 0.03))
	query.exclude = exclude
	var overlaps := house.get_world_3d().direct_space_state.intersect_shape(query, 4)
	for overlap: Dictionary in overlaps:
		print("  ", spot.name, " lets the player out into ", overlap.collider.name)
	return overlaps.is_empty() and surface_at(house, house.to_local(exit), exclude) != "none"


## Whether an enemy at the watcher point has a clear line to the eye of a player hidden in the spot,
## looking past the spot's own furniture as the enemies do (HidingSpot.collision_rids()).
func sight_reaches_hidden_eye(house: Node3D, spot: HidingSpot, watcher: Vector3, exclude: Array[RID]) -> bool:
	var past_spot: Array[RID] = []
	past_spot.append_array(exclude)
	past_spot.append_array(spot.collision_rids())
	var ray := PhysicsRayQueryParameters3D.create(watcher, spot.eye_position())
	ray.exclude = past_spot
	return not spot.collision_rids().is_empty() and house.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func run() -> void:
	var scene := (load("res://scenes/chapters/playground/carrie_house_test.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await wait_physics(4)
	var house := scene.get_node("CarrieHouse") as Node3D
	var player := scene.get_node("Player") as CollisionObject3D
	var exclude: Array[RID] = [player.get_rid()]
	var floors: Dictionary = house.markers.floors

	check(house.has_node("Source/Floor_Wood/Floor_Wood_col") and house.has_node("Source/Floor_Tile/Floor_Tile_col"), "Floors get collision")
	check(surface_at(house, house.local_point(&"hall"), exclude) == "wood", "Hall floor is solid and sounds like wood")
	check(surface_at(house, Vector3(1.1, floors.GROUND, -8.0), exclude) == "tile", "Kitchen linoleum sounds like tile")
	check(surface_at(house, Vector3(1.5, floors.UPPER, -7.5), exclude) == "tile", "Bathroom hex tile sounds like tile")
	check(surface_at(house, house.local_point(&"porch"), exclude) == "wood", "Porch boards hold the player")
	check(surface_at(house, house.local_point(&"carrie_room"), exclude) == "wood", "Carrie's room floor is solid")

	# Without the opening, a drop from under the ground floor would stop on the map's ground.
	var under := floor_below(house, Vector3(2.0, -0.1, -3.0), exclude)
	check(not under.is_empty() and absf(house.to_local(under.position).y - float(floors.CELLAR)) < 0.06, "Ground is open over the cellar, down to its floor")
	check(surface_at(house, Vector3(2.0, floors.CELLAR, -3.0), exclude) == "concrete", "Cellar floor sounds like concrete")
	var yard := floor_below(house, Vector3(2.2, 0.0, 9.0), [])
	check(not yard.is_empty() and absf(yard.position.y) < 0.06, "Ground still stands in the yard")
	var ground_material := (scene.get_node("Ground") as MeshInstance3D).get_active_material(0) as ShaderMaterial
	var cutout: Vector4 = ground_material.get_shader_parameter("cutout_rect")
	var centre := house.to_global(Vector3(0.0, 0.0, -5.0))
	check(cutout.x < centre.x and centre.x < cutout.z and cutout.y < centre.z and centre.z < cutout.w, "Ground shader leaves the house's footprint undrawn")

	var furniture := house.get_node("FurnitureCollision")
	check(furniture.get_child_count() >= 35 and furniture.has_node("Dollhouse") and furniture.has_node("Stove"), "Furniture blocks with box collision")
	check(not furniture.has_node("LivingRug") and not furniture.has_node("Radio"), "Rugs and small things stay passable")
	check(house.has_node("Source/Dollhouse") and house.has_node("Source/TV") and house.has_node("Source/Radio"), "Furniture keeps its layout names")

	var hides: Array[HidingSpot] = []
	for child: Node in house.get_children():
		if child is HidingSpot:
			hides.append(child as HidingSpot)
	var furnished := hides.all(func(spot: HidingSpot) -> bool: return not spot.builtin_model and not spot.has_node("Model"))
	check(hides.size() == 4 and furnished, "Four hiding spots in the house's own bed, wardrobe and closets")
	var bed := house.get_node_or_null("CarrieBedHide") as HidingSpot
	var exit := house.to_local(bed.exit_position()) if bed != null else Vector3.ZERO
	check(bed != null and bed.kind == HidingSpot.Kind.UNDER_BED and surface_at(house, exit, exclude) == "wood", "Carrie's bed hides the player and lets them out onto the floor")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var clear_exits := 0
	for spot: HidingSpot in hides:
		if exit_is_clear(house, spot, capsule, exclude):
			clear_exits += 1
	check(clear_exits == 4, "Every hiding spot lets the player out on the floor, clear of walls and furniture")
	var watcher := house.to_global(Vector3(-3.0, float(floors.UPPER) + 1.3, -3.0))
	var in_sight := 0
	for spot_name: String in ["CarrieBedHide", "CarrieWardrobeHide"]:
		if sight_reaches_hidden_eye(house, house.get_node(spot_name) as HidingSpot, watcher, exclude):
			in_sight += 1
	check(in_sight == 2, "A player hidden in Carrie's bed or wardrobe can watch an enemy in her room")
	var lights := house.get_children().filter(func(child: Node) -> bool: return child is OmniLight3D)
	check(lights.size() == 3, "Only the porch, Carrie's room and the kitchen have power")

	var outside: Vector3 = house.point(&"yard_front") + house.global_basis.z * 3.0
	var hall: Vector3 = house.point(&"hall")
	check(house.contains_route_point(hall) and not house.contains_route_point(outside), "Enemy route area covers the house, not the yard")
	var up: Array[Dictionary] = house.route_transitions(outside, house.point(&"carrie_room"))
	check(up.size() == 6 and not up[0].direct and up[1].direct and not up[4].direct, "Enemies come in by the front door and climb the main stair")
	var down: Array[Dictionary] = house.route_transitions(house.point(&"carrie_room"), house.point(&"kitchen"))
	check(down.size() == 2 and down[0].point.distance_to(house.point(&"stairs_top")) < 0.01, "Enemies come back down the main stair")
	var out: Array[Dictionary] = house.route_transitions(house.point(&"carrie_room"), outside)
	check(out.size() == 6 and out[5].point.distance_to(house.point(&"yard_front")) < 0.01, "Enemies leave upstairs by the front door")

	# Only the route the story uses stands open: the other rooms' doors are shut and solid.
	var open_doorways := (house.markers.doorways as Array).filter(func(doorway: Dictionary) -> bool: return doorway.open)
	var links := house.get_children().filter(func(child: Node) -> bool: return child is NavigationLink3D)
	check(open_doorways.size() == 8 and links.size() == 8, "Navigation links cross the eight open doorways and nothing else")
	var narrow := open_doorways.filter(func(doorway: Dictionary) -> bool: return float(doorway.width) < 0.99)
	check(narrow.is_empty(), "Every open doorway is at least 1 m wide, so monsters fit through")
	var closed := (house.markers.doors as Array).filter(func(door: Dictionary) -> bool: return float(door.open_degrees) < 1.0).map(func(door: Dictionary) -> String: return str(door.name))
	check(closed.has("CellarDoor") and closed.has("ParentsDoor") and closed.has("BathDoor"), "The cellar, parents' room and bathroom are shut")

	var note: Vector3 = house.local_point(&"door_note")
	check(note.z > 0.0 and absf(note.y - (float(floors.GROUND) + 0.85)) < 0.05, "Door note hangs on the front wall at eye height")
	var notebook: Vector3 = house.local_point(&"notebook")
	var desk := house.get_node("Source/CarrieDesk") as Node3D
	check(absf(notebook.y - (float(floors.UPPER) + 0.7725)) < 0.01 and Vector2(notebook.x - desk.position.x, notebook.z - desk.position.z).length() < 0.2, "Notebook lies on the desk in Carrie's room")
	check(house.has_node("Entrance") and (house.get_node("Entrance") as Node3D).position.z > 3.6, "Entrance marker stands at the foot of the porch steps")

	# The Wrapper's post: room to stand in front of the armchair, facing the TV, its seat in the chair.
	var post: Vector3 = house.local_point(&"wrapper_post")
	var seat: Vector3 = house.local_point(&"wrapper_seat")
	var chair := house.get_node("Source/Armchair") as Node3D
	var monster := CapsuleShape3D.new()
	monster.radius = 0.4
	monster.height = 1.9
	var standing := PhysicsShapeQueryParameters3D.new()
	standing.shape = monster
	standing.transform = Transform3D(Basis.IDENTITY, house.to_global(post) + Vector3.UP * 1.0)
	standing.exclude = exclude
	check(house.get_world_3d().direct_space_state.intersect_shape(standing, 1).is_empty(), "The Wrapper has room to stand in front of the armchair")
	check(Vector2(seat.x - chair.position.x, seat.z - chair.position.z).length() < 0.3 and house.local_point(&"tv").z > post.z, "Its seat is in the armchair, facing the TV")

	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
