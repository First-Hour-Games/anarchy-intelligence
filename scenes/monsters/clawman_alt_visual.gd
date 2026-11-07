extends "res://scenes/monsters/clawman_visual.gd"
## The alt route's Clawman: the creator's clips, plus what they never move. Its extra arms grope on their own,
## faster when it hunts; its head stays shut, so it looks like the Clawman you know, until it screams, when it
## splits open; and on the strike the tongue lashes out of the split. The bones are posed by
## clawman_alt_rig.gd, which this adds to the model's skeleton.

const RIG := preload("res://scenes/monsters/clawman_alt_rig.gd")
## The opening of the head (0 shut, 1 wide) for each clip; the strike opens it all the way.
const OPENING := {"idle": 0.0, "walk": 0.0, "run": 0.5, "windup": 1.0, "hit": 0.85, "attack": 1.0, "death": 0.4}
const AGITATION := {"idle": 0.15, "walk": 0.3, "run": 1.0, "windup": 0.8, "hit": 0.6, "attack": 1.0, "death": 0.0}
## Seconds into Attack_Slam the tongue starts out, is at full reach, and is back in.
const LASH_OUT := 0.32
const LASH_FULL := 0.62
const LASH_BACK := 1.35

var rig: RIG


func _ready() -> void:
	super._ready()
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	rig = RIG.new()
	rig.name = "ClawmanAltRig"
	skeletons[0].add_child(rig)


func _process(delta: float) -> void:
	if rig == null:
		return
	var target: float = OPENING.get(clip, 0.0)
	var lash_target := 0.0
	var aim_target := 0.0
	if clip == "run":
		# Chasing, its head hangs half split, gaping and closing as it breathes.
		target += 0.15 * sin(Time.get_ticks_msec() * 0.006)
	elif clip == "windup" or clip == "hit":
		lash_target = 0.12
		aim_target = 0.5
	elif clip == "attack":
		var at := _clip_time()
		lash_target = smoothstep(LASH_OUT, LASH_FULL, at) * (1.0 - smoothstep(LASH_FULL + 0.25, LASH_BACK, at))
		aim_target = 1.0
	# The tongue goes for the player's face.
	var body := get_parent()
	var player: Variant = body.get("player") if body != null else null
	if player is FirstPersonPlayer and is_instance_valid(player):
		rig.aim_target = (player as FirstPersonPlayer).camera.global_position
	else:
		rig.aim_target = global_position - global_basis.z * 3.0 + Vector3.UP * 1.5
	rig.aim = move_toward(rig.aim, aim_target, delta * 4.0)
	# It opens fast and shuts slowly; the tongue shoots out and is drawn back in.
	rig.opening = move_toward(rig.opening, target, delta * (5.5 if target > rig.opening else 1.6))
	rig.lash = move_toward(rig.lash, lash_target, delta * (8.0 if lash_target > rig.lash else 2.5))
	rig.agitation = move_toward(rig.agitation, AGITATION.get(clip, 0.2), delta * 1.5)


func _clip_time() -> float:
	if animation_player == null or animation_player.current_animation == &"":
		return 0.0
	return animation_player.current_animation_position
