extends SceneTree
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1
func ragdoll_bones(wrapper: Node) -> int:
	var ragdoll := wrapper.get_node_or_null("Ragdoll")
	return ragdoll.find_children("*", "RigidBody3D", false, false).size() if ragdoll else 0
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor.add_child(floor_shape)
	world.add_child(floor)
	var scene := load("res://scenes/monsters/the_wrapper.tscn") as PackedScene
	var wrapper = scene.instantiate()
	# The forest's Wrapper is scaled 1.2; a scaled body is what broke the first ragdoll.
	wrapper.scale = Vector3.ONE * 1.2
	world.add_child(wrapper)
	wrapper.set("enabled", true)
	await physics_frame
	for i in 4:
		wrapper.take_melee_hit(Vector3(0, 0, 3), 0.1, 2.5)
	check(not wrapper.dead and ragdoll_bones(wrapper) == 0, "Four pipe hits only stagger the Wrapper")
	wrapper.take_melee_hit(Vector3(0, 0, 3), 0.1, 2.5)
	check(wrapper.dead, "The fifth pipe hit kills the Wrapper")
	check(ragdoll_bones(wrapper) >= 6, "Death builds a ragdoll (%d bones)" % ragdoll_bones(wrapper))
	var bone: RigidBody3D = wrapper.get_node("Ragdoll").find_children("*", "RigidBody3D", false, false)[0]
	var start: Vector3 = bone.global_position
	for i in 60:
		await physics_frame
	check(wrapper.get_node("CollisionShape3D").disabled, "The standing collider is off once dead")
	check(bone.global_position.distance_to(start) > 0.05, "The ragdoll moves under physics")
	check(bone.global_position.distance_to(start) < 4.0, "The ragdoll falls rather than flinging away")
	check(bone.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE), "Ragdoll bodies are unscaled under a scaled Wrapper")
	var corpse: Vector3 = wrapper.global_position
	wrapper.reset_enemy()
	wrapper.set_post(Transform3D(Basis.IDENTITY, Vector3(10, 0, 10)))
	check(wrapper.dead and wrapper.global_position == corpse, "Respawn and new posts leave the corpse alone")
	var hits: int = wrapper.hits_taken
	wrapper.set("enabled", true)
	wrapper.take_melee_hit(Vector3.ZERO, 0.1, 2.5)
	check(wrapper.hits_taken == hits and wrapper.melee_stagger_time == 0.0, "Hitting the corpse does nothing")
	var restored = scene.instantiate()
	restored.restore_dead(Vector3(4, 0, 4), 1.0)
	world.add_child(restored)
	await physics_frame
	check(restored.dead and restored.global_position.distance_to(Vector3(4, 0, 4)) < 0.01, "A saved corpse is restored where it fell")
	check(ragdoll_bones(restored) >= 6, "A restored corpse is a ragdoll")
	var hunt: AudioStreamPlayer = wrapper.get_node("HuntAudio")
	check(not hunt.playing, "Hunt music stays off for a dead Wrapper")
	world.queue_free()
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
