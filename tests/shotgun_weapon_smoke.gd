extends SceneTree
## The alt route's double-barrelled shotgun: it comes up when found and puts the pipe away; each barrel
## fires once with a boom, hurting what is in front of the camera once with the summed pellets; reloading
## breaks it open, swings the barrels down, loads both from the spares and closes it, clicking, clattering
## and snapping in order, and it cannot fire while open; an empty gun only clicks. Its crosshair rings the
## pellets' spread, kicks open with a shot, marks hits and kills, and dims while the gun cannot fire.

const TARGET_SCRIPT := """
extends StaticBody3D
var hits: Array[float] = []
var dead := false
var die_on_hit := false
func take_damage(amount: float) -> void:
	hits.append(amount)
	dead = die_on_hit
"""

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	world.add_child(player)
	player.set_physics_process(false)
	player.unfreeze()
	await process_frame
	var shotgun: Node3D = player.get_node("Head/Camera3D/ShotgunWeapon")
	var pipe: Node3D = player.get_node("Head/Camera3D/PipeWeapon")
	var illustrated: AnimatedSprite2D = player.get_node("HandViewmodel").hands
	var arms: AnimationPlayer = shotgun.get_node("ModelPivot/Arms/AnimationPlayer")
	var hand: BoneAttachment3D = shotgun.get_node("ModelPivot/Arms/FPS_Arms/Skeleton3D/Hand_R")
	check(not shotgun.model_pivot.visible and not shotgun.equipped, "shotgun is not held before it is found")
	check(hand.has_node("ShotgunModel") and not hand.has_node("MetalPipe_Hand_R"), "the shotgun arms hold the gun, not the pipe")
	var gun: Node3D = hand.get_node("ShotgunModel")
	check(gun.transform.is_equal_approx(load("res://models/player/shotgun_clips.tres").get_meta(&"mount")), "the gun sits in the right hand where the clips put it")
	player.inventory.add_item(&"metal_pipe")
	await process_frame
	check(pipe.equipped, "the pipe comes up first")
	player.inventory.add_item(&"shotgun")
	await process_frame
	check(shotgun.equipped and not pipe.equipped, "finding the shotgun puts the pipe away")
	check(shotgun.loaded == 2 and shotgun.reserve == shotgun.starting_reserve, "the shotgun comes with both barrels loaded and a few spare shells")
	await create_timer(0.45).timeout
	check(shotgun.model_pivot.visible and not illustrated.visible, "the held shotgun replaces the illustrated hands")
	check(arms.current_animation == &"shotgun/shotgun_idle", "a held shotgun breathes in its idle clip")
	var crosshair: ShotgunCrosshair = shotgun.get_node("Hud/Crosshair")
	var view := crosshair.get_viewport_rect().size
	check((shotgun.get_node("Hud") as CanvasLayer).visible and crosshair.is_visible_in_tree()
		and (crosshair.size * 0.5).is_equal_approx(view * 0.5), "the held shotgun shows its crosshair in the middle of the view")
	var fov: float = (player.get_node("Head/Camera3D") as Camera3D).fov
	var expected := tan(deg_to_rad(shotgun.spread_degrees)) / tan(deg_to_rad(fov) * 0.5) * view.y * 0.5
	check(is_equal_approx(crosshair.spread_radius(), expected) and expected > 10.0,
		"the crosshair's ring is as wide as the pellets' spread (%.1f of %.0f)" % [crosshair.spread_radius(), view.y])
	check(crosshair.ready_to_fire and not crosshair.is_marking_hit(), "a loaded gun's crosshair is bright, with no hit marked")
	# A target three metres ahead of the camera.
	var target := StaticBody3D.new()
	var script := GDScript.new()
	script.source_code = TARGET_SCRIPT
	script.reload()
	target.set_script(script)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(2, 2, 0.4)
	target.add_child(shape)
	world.add_child(target)
	var camera: Camera3D = player.get_node("Head/Camera3D")
	target.global_position = camera.global_position - camera.global_basis.z * 3.0
	await physics_frame
	await physics_frame
	var pitch_before: float = player.head.rotation.x
	var barrels: Node3D = gun.find_child("Barrels", true, false)
	var closed := barrels.quaternion
	check(shotgun.try_fire(), "a loaded, held shotgun fires")
	check(shotgun.loaded == 1, "a shot spends one barrel")
	check(target.get("hits").size() == 1 and target.get("hits")[0] > 0.0, "the pellets that hit a target add up to one hit on it")
	check(target.get("hits")[0] <= shotgun.pellets * shotgun.pellet_damage, "a shot does no more than all its pellets together")
	check(player.head.rotation.x > pitch_before, "the shot kicks the view up")
	check(crosshair._kick > 0.9, "the shot kicks the crosshair's ring open")
	check(crosshair.is_marking_hit() and not crosshair.is_marking_kill(), "pellets landing on the target mark a hit, not a kill")
	check(arms.current_animation == &"shotgun/shotgun_fire", "firing plays the kick")
	var shot_audio: AudioStreamPlayer = shotgun.get_node("ShotAudio")
	check(shot_audio.playing and shot_audio.stream is AudioStreamRandomizer, "a shot booms with one of the blasts")
	check(not shotgun.try_fire(), "the second barrel waits a moment after the first")
	await create_timer(shotgun.barrel_interval + 0.05).timeout
	check(shotgun.try_fire() and shotgun.loaded == 0, "then the second barrel fires")
	await create_timer(shotgun.barrel_interval + 0.05).timeout
	check(not shotgun.try_fire(), "an empty shotgun does not fire")
	check(not crosshair.ready_to_fire and crosshair._opacity < 1.0 and crosshair._kick == 0.0,
		"an empty gun's crosshair dims, its ring settled back")
	var action_audio: AudioStreamPlayer = shotgun.get_node("ActionAudio")
	check(shotgun._dry_fire() and action_audio.playing and action_audio.stream == shotgun.DRY_FIRE_SOUND,
		"an empty shotgun only clicks")
	await create_timer(maxf(shotgun.DRY_FIRE_SECONDS, shotgun.DRY_FIRE_SOUND.get_length()) + 0.05).timeout
	check(shotgun.try_reload(), "spare shells can be loaded")
	check(shotgun.reloading and not shotgun.try_fire(), "it cannot fire while broken open")
	var opened := 0.0
	var carried: Node3D = shotgun.get_node("ModelPivot/Arms/FPS_Arms/Skeleton3D/Hand_L/HandShells")
	var chambered: Node3D = gun.find_child("ChamberShells", true, false)
	var seated := chambered.position
	var saw_carried := false
	var saw_empty := false
	var heard: Array[String] = []
	var reload_seconds: float = arms.get_animation(&"shotgun/shotgun_reload").length
	for i in ceili(reload_seconds / 0.05) + 4:
		await create_timer(0.05).timeout
		opened = maxf(opened, rad_to_deg(barrels.quaternion.angle_to(closed)))
		saw_carried = saw_carried or carried.visible
		saw_empty = saw_empty or not chambered.visible
		var sound := action_audio.stream.resource_path.get_file().get_basename() if action_audio.playing else ""
		if sound != "" and (heard.is_empty() or heard[-1] != sound):
			heard.append(sound)
	check(opened > 25.0, "reloading swings the barrels down on the hinge (%.0f degrees)" % opened)
	check(saw_empty and saw_carried, "the spent shells come out and the left hand brings two new ones")
	check(", ".join(heard) == "shotgun_break_open, shotgun_shells_out, shotgun_shells_in, shotgun_snap_shut",
		"reloading clicks open, the spent shells clatter out, the new ones click in and it snaps shut (heard %s)"
		% ", ".join(heard))
	check(not shotgun.reloading and shotgun.loaded == 2 and shotgun.reserve == shotgun.starting_reserve - 2,
		"reloading fills both barrels from the spares")
	check(not carried.visible and chambered.visible and chambered.position.is_equal_approx(seated),
		"after reloading the new shells sit in the chambers and the hand is empty")
	check(barrels.quaternion.angle_to(closed) < 0.01, "the barrels close again")
	check(crosshair.ready_to_fire, "a reloaded gun's crosshair brightens again")
	target.set("die_on_hit", true)
	check(shotgun.try_fire(), "a reloaded shotgun fires")
	check(crosshair.is_marking_kill(), "a shot that kills marks a kill")
	shotgun.loaded = 0
	shotgun.reserve = 0
	await create_timer(shotgun.barrel_interval + 0.05).timeout
	check(not shotgun.try_reload(), "with no spare shells there is nothing to load")
	player.inventory.select_slot(1)
	var slot := 0
	for i in PlayerInventory.SLOT_COUNT:
		if player.inventory.get_item(i) == &"shotgun":
			slot = i
	player.inventory.select_slot(slot)
	player.inventory.set_open(true, false)
	check(not shotgun.try_fire(), "the open inventory blocks the shotgun")
	player.inventory._use_selected()
	check(not shotgun.equipped and not player.inventory.is_open, "the inventory puts the shotgun away")
	await create_timer(0.4).timeout
	check(not shotgun.model_pivot.visible and illustrated.visible, "a holstered shotgun gives the illustrated hands back")
	check(not crosshair.is_visible_in_tree(), "the crosshair goes with the holstered shotgun")
	print("shotgun_weapon_smoke: %d failures" % failures)
	quit(1 if failures else 0)
