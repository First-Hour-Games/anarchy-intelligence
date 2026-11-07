extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.position = Vector3(100, 0, 100)
	var wrapper = load("res://scenes/monsters/the_wrapper.tscn").instantiate()
	root.add_child(wrapper)
	wrapper.set_physics_process(false)
	wrapper.enabled = true
	wrapper.hits_to_kill = 0
	wrapper.take_melee_hit(Vector3.ZERO, 1.5, 0.0)
	wrapper._physics_process(0.5)
	wrapper.take_melee_hit(Vector3.ZERO, 2.5, 0.0)
	assert(is_equal_approx(wrapper.melee_stagger_time, 1.0))
	assert(wrapper.hits_taken == 2)
	wrapper._physics_process(1.0)
	assert(is_zero_approx(wrapper.melee_stagger_time))
	assert(is_equal_approx(wrapper.melee_stun_immunity_time, 1.0))
	wrapper._physics_process(0.5)
	wrapper.take_melee_hit(Vector3.ZERO, 2.5, 0.0)
	assert(is_zero_approx(wrapper.melee_stagger_time))
	assert(wrapper.hits_taken == 3)
	wrapper._physics_process(0.5)
	wrapper.take_melee_hit(Vector3.ZERO, 2.5, 0.0)
	assert(is_equal_approx(wrapper.melee_stagger_time, 2.5))
	wrapper.reset_enemy()
	assert(is_zero_approx(wrapper.melee_stun_immunity_time))
	wrapper.free()
	player.queue_free()
	await process_frame
	print("PASS: Hits count during stun immunity, cannot extend a stun, and can stun again one second after recovery; reset clears immunity.")
	quit()
