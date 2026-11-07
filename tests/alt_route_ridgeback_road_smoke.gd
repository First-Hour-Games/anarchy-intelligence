extends SceneTree
## The alt route's road past the yard gate: fenced in on both sides and blocked with rows of wrecked cars
## that each leave one way through; a pack of four Ridgebacks hides behind the cars, wakes when the player
## steps onto the road with one up on a roof in view, leaps over the cars (bounding off a roof when one is
## too close to clear), pounces for 15 damage one at a time, can be dodged and shot dead, stays dead in a
## save, and goes back to its places when the player comes back from a death. A box of shells waits in one
## of the dead ends. They have pigs' voices: grunting from hiding, shrieking on the roofs, roaring as they
## pounce, squealing when hit and screaming as they die, one cry at a time, each one a little differently.

const RESIDENCE := "res://scenes/chapters/alt_route/residence_area_alt.tscn"
const ROWS := [70.0, 78.0, 86.0, 94.0, 101.0, 110.0, 118.0]

var failures := 0
var cleared := false


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


## How many separate ways through a row there are, for something the player's size, across the road.
func openings(space: PhysicsDirectSpaceState3D, z: float, ignore: Array[RID]) -> int:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = ignore
	var count := 0
	var was_free := false
	var x := 122.0
	while x <= 135.0:
		query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.95, z))
		var free := space.intersect_shape(query, 1).is_empty()
		if free and not was_free:
			count += 1
		was_free = free
		x += 0.1
	return count


func aim_at(player: FirstPersonPlayer, point: Vector3) -> void:
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var to := point - camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func run() -> void:
	root.get_node("PauseMenu").set_process_unhandled_input(false)
	root.get_node("DebugMenu").set_process_input(false)
	var section: Node3D = (load(RESIDENCE) as PackedScene).instantiate()
	root.add_child(section)
	current_scene = section
	var player := section.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.unfreeze()
	player.global_position = Vector3(131.5, 0.12, 57.0)
	for i in 8:
		await physics_frame
	var road := section.get_node("RidgebackRoad") as RidgebackRoad
	road.cleared.connect(func() -> void: cleared = true)
	var space := road.get_world_3d().direct_space_state
	var health := player.get_node("CombatHealth")
	var pack := road.ambushers
	var bodies: Array[RID] = [player.get_rid()]
	for ambusher in pack:
		bodies.append(ambusher.get_rid())

	# Closed in, and the cars leave one way through each row.
	var west := ray(space, Vector3(128.0, 1.2, 74.0), Vector3(115.0, 1.2, 74.0))
	var east := ray(space, Vector3(128.0, 1.2, 97.5), Vector3(141.0, 1.2, 97.5))
	check(not west.is_empty() and float(west.position.x) > 121.8 and not east.is_empty() and float(east.position.x) < 135.3,
		"fences close the road in on both sides")
	var rows_ok := true
	for z: float in ROWS:
		var count := openings(space, z, bodies)
		if count != 1:
			rows_ok = false
			print("  row at z %.0f has %d ways through" % [z, count])
	check(rows_ok, "each of the seven rows of cars leaves exactly one way through")
	check(not ray(space, Vector3(129.0, 1.0, 64.0), Vector3(129.0, 1.0, 124.0)).is_empty(), "no straight run down the road")

	# The pack, asleep behind the cars where the gate cannot see it.
	var roofs := road.spots.filter(func(spot: Dictionary) -> bool: return spot.perch).size()
	check(road.cars.size() >= 16 and road.spots.size() >= 60 and roofs >= 16, "the road finds the cars to hide behind and their roofs")
	check(pack.size() == 4 and pack.all(func(ambusher: RidgebackAmbusher) -> bool:
		return ambusher.state == RidgebackAmbusher.State.DORMANT and not road.spot_exposed(ambusher.spot)),
		"four Ridgebacks wait asleep behind the cars, out of sight of the gate")

	# A leap over a car clears its roof.
	var over_car := false
	for a in road.spots.size():
		var first: Dictionary = road.spots[a]
		if first.perch:
			continue
		for b in road.spots.size():
			var second: Dictionary = road.spots[b]
			if second.perch or second.car != first.car or (first.facing as Vector3).dot(second.facing) > -0.9:
				continue
			var height := road.arc_height(first.position, second.position)
			var top: float = road.cars[first.car].top
			if height >= 0.0 and ((first.position as Vector3).y + (second.position as Vector3).y) * 0.5 + height >= top + 0.4:
				over_car = true
				break
		if over_car:
			break
	check(over_car, "a leap from one side of a car to the other goes over its roof")

	# Crouched close behind the second row's Lincoln, a leap to behind the hearse in the row in front cannot
	# clear the Lincoln in one arc: it bounds off the Lincoln's roof and on, and comes down where it meant to.
	var behind_lincoln := road.nearest_spot(Vector3(123.8, 0.0, 79.9), false)
	var behind_hearse := road.nearest_spot(Vector3(126.4, 0.1, 72.0), false)
	var from := road.spot_position(behind_lincoln)
	var to := road.spot_position(behind_hearse)
	var vault := road.vault_point(from, to)
	check(road.arc_height(from, to) < 0.0 and vault != Vector3.INF and road.is_roof(vault)
		and road.car_at(vault) == road.car_at(Vector3(125.4, 0.0, 78.0)) and road.can_leap(from, to),
		"a leap too long to clear the car in front in one arc goes by way of its roof")
	var vaulter := pack[3]
	var vaulter_home := vaulter.global_position
	vaulter.global_position = from
	vaulter.spot = behind_lincoln
	vaulter.state = RidgebackAmbusher.State.HIDING
	vaulter.call("_leap", behind_hearse, RidgebackAmbusher.State.HIDING)
	var touched_roof := false
	for frame in 240:
		await physics_frame
		if road.is_roof(vaulter.global_position) and vaulter.global_position.y > float(road.cars[road.car_at(vault)].top) - 0.1:
			touched_roof = true
		if vaulter.state == RidgebackAmbusher.State.HIDING:
			break
	check(touched_roof and vaulter.state == RidgebackAmbusher.State.HIDING and vaulter.global_position.distance_to(to) < 0.05,
		"it bounds off that roof and comes down behind the hearse")
	vaulter.reset_enemy()
	check(vaulter.global_position.distance_to(vaulter_home) < 0.05, "and goes back to its place to wait")

	var pitches: Array[float] = []
	var own_voices := true
	for ambusher in pack:
		pitches.append(ambusher.roar.pitch_scale)
		own_voices = own_voices and ambusher.scare_kind == "ridgeback_road" and absf(ambusher.roar.pitch_scale - 1.0) <= 0.08 \
			and ambusher.grunt.pitch_scale == ambusher.roar.pitch_scale and ambusher.death_cry.pitch_scale == ambusher.roar.pitch_scale
	check(own_voices and pitches.min() < pitches.max(), "each one of the pack has a voice of its own, in all its cries (%s)"
		% ", ".join(pitches.map(func(pitch: float) -> String: return "%.3f" % pitch)))

	# Stepping onto the road wakes them; one shows itself on a roof, and Thomas speaks.
	player.global_position = Vector3(131.0, 0.12, 64.0)
	var revealed := false
	var revealed_at := 0.0
	var grunted := false
	for frame in int((road.reveal_delay + 4.0) * Engine.physics_ticks_per_second):
		await physics_frame
		revealed_at += 1.0 / Engine.physics_ticks_per_second
		grunted = grunted or pack.any(func(ambusher: RidgebackAmbusher) -> bool: return ambusher.grunt.playing)
		revealed = pack.any(func(ambusher: RidgebackAmbusher) -> bool:
			return ambusher.state == RidgebackAmbusher.State.PERCHED and road.seen_by_player(ambusher.global_position + Vector3.UP))
		if revealed:
			break
	check(road.active, "stepping onto the road wakes the pack")
	check(revealed and revealed_at > road.reveal_delay and grunted, "after a grunt from hiding, one leaps up onto a roof in plain view")
	check(pack.any(func(ambusher: RidgebackAmbusher) -> bool:
		return ambusher.state == RidgebackAmbusher.State.PERCHED and ambusher.shriek.playing), "and shrieks there")
	print("  revealed %.1f s after stepping onto the road" % revealed_at)
	var subtitles := section.get_node("RidgebackRoad/Subtitles") as RouteSubtitles
	check(subtitles.showing().begins_with("Thomas:"), "Thomas says what he sees")
	check(pack.any(func(ambusher: RidgebackAmbusher) -> bool: return ambusher.spot != ambusher.home_spot),
		"the pack moves among the cars")

	# One at a time from here: the others hold still.
	var hunter := pack[0]
	for ambusher in pack:
		ambusher.suspended = ambusher != hunter
	await physics_frame
	hunter.suspended = true
	await create_timer(1.5).timeout
	hunter.reset_enemy()
	hunter.global_position = Vector3(124.5, 0.12, 74.0)
	hunter.state = RidgebackAmbusher.State.HIDING
	player.global_position = Vector3(129.5, 0.12, 74.0)
	health.set("immunity", 0.0)
	var before := float(health.get("health"))
	road.attacker = null
	road.attack_cooldown = 0.0
	hunter.suspended = false
	check(road.claim_attack(hunter), "the road hands the attack to one Ridgeback")
	hunter.call("_start_windup")
	check(not road.claim_attack(pack[1]), "no second one attacks while it does")
	check(hunter.roar.playing, "it roars as it crouches to pounce")
	var struck := false
	var roared_into_leap := false
	var bite_ends_roar := false
	var recovering := 0.0
	for frame in int(3.0 * Engine.physics_ticks_per_second):
		await physics_frame
		roared_into_leap = roared_into_leap or (hunter.state == RidgebackAmbusher.State.POUNCING and hunter.roar.playing)
		if hunter.strike.playing and not struck:
			bite_ends_roar = not hunter.roar.playing
		struck = struck or hunter.strike.playing
		if hunter.state == RidgebackAmbusher.State.RECOVERING:
			recovering += 1.0 / Engine.physics_ticks_per_second
	check(roared_into_leap, "and roars on through the leap at the player")
	check(is_equal_approx(before - float(health.get("health")), 15.0) and struck and bite_ends_roar,
		"its pounce does 15 damage, the roar ending in the slam of its strike")
	check(recovering >= hunter.recover_seconds - 0.05, "and it stays crouched where it came down, open to a shot, before it leaps away")

	# Stepping out of the way once it has leapt dodges it.
	await create_timer(2.5).timeout
	hunter.suspended = true
	hunter.reset_enemy()
	hunter.global_position = Vector3(124.5, 0.12, 74.0)
	hunter.state = RidgebackAmbusher.State.HIDING
	player.global_position = Vector3(129.5, 0.12, 74.0)
	health.set("immunity", 0.0)
	before = float(health.get("health"))
	road.attacker = null
	road.attack_cooldown = 0.0
	hunter.suspended = false
	road.claim_attack(hunter)
	hunter.call("_start_windup")
	var launched := false
	for frame in 120:
		await physics_frame
		if hunter.state == RidgebackAmbusher.State.POUNCING:
			launched = true
			break
	player.global_position = Vector3(129.5, 0.12, 71.9)
	player.global_position.x = 132.5
	await create_timer(1.6).timeout
	check(launched and is_equal_approx(float(health.get("health")), before), "stepping aside as it leaps makes it miss")

	# A pounce that kills: the death scare holds everything still, and this one finishes its lunge onto the
	# player, down on the road, rather than hanging in the air. Trying again puts the pack back to sleep.
	hunter.suspended = true
	hunter.reset_enemy()
	hunter.global_position = Vector3(124.5, 0.12, 74.0)
	hunter.state = RidgebackAmbusher.State.HIDING
	player.global_position = Vector3(129.5, 0.12, 74.0)
	health.set("immunity", 0.0)
	health.set("health", 10.0)
	road.attacker = null
	road.attack_cooldown = 0.0
	hunter.suspended = false
	road.claim_attack(hunter)
	hunter.call("_start_windup")
	for frame in int(2.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if bool(health.get("is_dead")):
			break
	var killed := bool(health.get("is_dead"))
	var scare := health.get("death_scare") as CanvasLayer
	check(is_instance_valid(scare) and scare.get("entity_kind") == "ridgeback_road"
		and (scare.get("audio") as AudioStreamPlayer).stream.resource_path.ends_with("ridgeback/ridgeback_road_kill.wav"),
		"its death scare screams like a pig")
	await create_timer(0.6).timeout
	var lunge_end: Vector3 = hunter.get("_leap_to")
	check(killed and not hunter.can_process() and hunter.global_position.distance_to(lunge_end) < 0.05,
		"a killing pounce finishes its lunge onto the player, down on the road, as the death scare holds it")
	health.call("respawn")
	player.set_physics_process(false)
	await physics_frame
	check(not bool(health.get("is_dead")) and hunter.can_process() and hunter.state == RidgebackAmbusher.State.DORMANT
		and not road.active, "trying again puts the pack back to sleep at its places")
	check(not hunter.strike.playing and not hunter.roar.playing, "and nothing the death scare froze plays on")

	# One blast at close range kills it, and it stays down.
	hunter.suspended = true
	hunter.reset_enemy()
	hunter.global_position = Vector3(126.0, 0.12, 74.0)
	hunter.state = RidgebackAmbusher.State.HIDING
	player.global_position = Vector3(130.0, 0.12, 74.0)
	player.inventory.add_item(&"shotgun")
	var shotgun := player.get_node("Head/Camera3D/ShotgunWeapon")
	shotgun.call("restore_shells", 2, 4)
	hunter.take_damage(20.0)
	check(hunter.state == RidgebackAmbusher.State.HURT and hunter.pain.playing, "a hit makes it squeal")
	hunter.health = hunter.max_health
	await create_timer(0.7).timeout
	aim_at(player, hunter.global_position + Vector3(0.0, 0.45, -0.15))
	await physics_frame
	check(shotgun.call("try_fire"), "the shotgun fires at it")
	await physics_frame
	check(hunter.dead and hunter.state == RidgebackAmbusher.State.DEAD and hunter.body_shape.disabled,
		"one blast at close range kills it")
	check(hunter.death_cry.playing and not hunter.pain.playing, "it dies screaming, its squeal cut off")
	check(hunter.is_in_group(&"story_mob") and hunter.visual.animation_player.assigned_animation == &"fours_death",
		"it dies on all fours and is kept with the story's dead")

	# A save keeps the dead dead.
	var save_game := root.get_node("SaveGame")
	var saved: Dictionary = save_game.call("_capture_section", section)
	var dead_mobs: Dictionary = saved.get("dead_story_mobs", {})
	check(dead_mobs.has(str(section.get_path_to(hunter))) and dead_mobs.size() == 1, "a save keeps it dead, and only it")
	var other := pack[1]
	other.restore_dead(Vector3(127.0, 0.12, 74.5), 0.5)
	await physics_frame
	check(other.dead and other.state == RidgebackAmbusher.State.DEAD and other.body_shape.disabled
		and not other.visual.animation_player.is_playing(), "loading puts a dead one back down, still")

	# The box of shells in the dead end.
	var box := section.get_node("RidgebackRoad/ShellBox") as ShellBoxPickup
	player.global_position = Vector3(131.6, 0.12, 89.6)
	var spare := int(shotgun.get("reserve"))
	check(box.can_interact(player), "the box of shells can be reached from beside its car")
	box.interact(player)
	check(int(shotgun.get("reserve")) == spare + 6 and box.taken and not box.can_interact(player)
		and bool(box.get_save_state().taken), "taking the box adds six spare shells, once")

	# Back from a death: the living go back to their places, asleep, and wait for the player again.
	var living := pack[2]
	living.suspended = false
	living.reset_enemy()
	road.reset_enemy()
	check(living.state == RidgebackAmbusher.State.DORMANT and living.global_position.distance_to(road.spot_position(living.home_spot)) < 0.05
		and not road.active, "after a death the living go back to their places and sleep")

	# The last of them dead: the road is clear.
	for ambusher in pack:
		if not ambusher.dead:
			ambusher.take_damage(500.0)
	await physics_frame
	check(cleared and road.get("_spoken").has("cleared"), "with the pack dead the road is clear, and Thomas says so")
	print("alt_route_ridgeback_road_smoke: %d failures" % failures)
	quit(1 if failures else 0)
