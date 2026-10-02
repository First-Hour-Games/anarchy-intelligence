extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var map := load("res://scenes/chapters/main/map.tscn").instantiate() as Node3D
	root.add_child(map)
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	var enemy := map.get_node("RobotKid") as CharacterBody3D
	var player := map.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	enemy.target = player
	enemy.watch_requires_line_of_sight = false
	enemy.watch_turn_speed = 100.0
	var start_position := Vector2(enemy.global_position.x, enemy.global_position.z)
	for iteration in 30:
		enemy._physics_process(0.1)
	var end_position := Vector2(enemy.global_position.x, enemy.global_position.z)
	var target_direction := player.global_position - enemy.global_position
	target_direction.y = 0.0
	target_direction = target_direction.normalized()
	var forward := -enemy.global_basis.z.normalized()
	var followed_player := start_position.distance_to(end_position) > 0.2
	var facing_player := forward.dot(target_direction) > 0.95
	var passed: bool = enemy.watch_only and enemy.watching_player and followed_player and facing_player
	print("Map watcher movement: ", start_position.distance_to(end_position), "; facing player: ", facing_player)
	print("PASS map watcher" if passed else "FAIL map watcher")
	quit(0 if passed else 1)

