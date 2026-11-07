extends SceneTree

const CARS := ["honda_prelude", "panda", "lincoln_town_car", "mercedes_benz_s_class", "cadillac_hearse", "freelander"]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for index in CARS.size():
		var car = load("res://models/props/vehicles/%s.tscn" % CARS[index]).instantiate()
		root.add_child(car)
		car.position = Vector3(index * 20.0, 3.0, 0)
		var body: StaticBody3D = car.get_node("CarBody")
		var shape: CollisionShape3D = body.get_node("CollisionShape3D")
		assert(shape.shape is BoxShape3D and not shape.disabled)
		await physics_frame
		await physics_frame
		var center := shape.global_position
		var half_width: float = shape.shape.size.x * 0.5
		var query := PhysicsRayQueryParameters3D.create(center + Vector3(half_width + 1.0, 0, 0), center)
		var hit := root.world_3d.direct_space_state.intersect_ray(query)
		assert(not hit.is_empty() and hit.collider == body)
		var player := CharacterBody3D.new()
		var capsule := CollisionShape3D.new()
		capsule.shape = CapsuleShape3D.new()
		player.add_child(capsule)
		root.add_child(player)
		player.position = center + Vector3(half_width + 2.0, 0, 0)
		await physics_frame
		var collision := player.move_and_collide(Vector3(-4, 0, 0))
		assert(collision != null and collision.get_collider() == body)
		print("PASS: ", CARS[index], " blocks player movement and physics rays.")
		player.free()
		car.free()
	quit()
