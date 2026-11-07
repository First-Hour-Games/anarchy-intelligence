class_name RidgebackFallerVisual
extends Node3D
## The look of one of the downtown Ridgebacks (ridgeback_faller.gd): the whole body on the roof, in the fall
## and in the splat, then, if it lives, the legless crawler (THE_RIDGEBACK_crawler.glb) and the legs it
## leaves behind (THE_RIDGEBACK_legs.glb). The crawler's first frame and the legs are both the splat's last,
## so swapping to them changes nothing on screen until it crawls away. play() takes the gameplay clip names
## below; "attack" is what the death scare asks a killer for. Every mesh is drawn on Gore.GORE_FREE_LAYER,
## out of reach of the blood stains it lies in. Its eyes glow faintly, through the fog, so a line of them shows
## along the roofs at night and a crawler between the cars.
## It can be one of the ten walkers (walker), each a different mutation of the same body built by
## tools/blender/build_ridgeback_walkers.py: their meshes go on these models' skeletons, so every clip plays
## on them, and each has its own skin, eyes, size and voice.

## Gameplay clip: the clip on the whole body, the clip on the crawler.
const CLIPS := {
	"perch": [&"ledge", &"crawl"],
	"shriek": [&"ledge_shriek", &"crawl"],
	"leap": [&"leap_off", &"crawl"],
	"fall": [&"fall", &"crawl"],
	"splat": [&"splat", &"crawl_rise"],
	"rise": [&"splat", &"crawl_rise"],
	"crawl": [&"splat", &"crawl"],
	"attack": [&"attack", &"crawl_grab"],
	"hit": [&"hit", &"crawl_hit"],
	"dead": [&"splat", &"crawl_death"],
}
const LOOPS := [&"ledge", &"fall", &"crawl"]
## Metres per second the crawl covers at its own cadence (CRAWL_SPEED in tools/blender/ridgeback/clips.py).
const CRAWL_SPEED := 0.548
## Where its eyes are on the model at rest, in its skeleton's space, and how they glow.
const EYES: Array[Vector3] = [Vector3(0.044, 2.025, 0.13), Vector3(-0.044, 2.025, 0.13)]
const EYE_RADIUS := 0.024
const EYE_GLOW := Color(1.0, 0.84, 0.42)
const EYE_ENERGY := 3.5
## The walkers: name -> model, skin, scale, pitch and eyes ([{bone, position, glow}], in skeleton space).
const WALKERS := "res://models/enemies/the_ridgeback/walkers/walkers.json"

## Which walker it is (a name in WALKERS: spine, reacher, hanged, twin, hunch, gaper, crowned, quill, brute,
## patient); empty for the original Ridgeback. Set it before the node is ready.
@export var walker: StringName = &""

@onready var full: Node3D = $Full
@onready var crawler: Node3D = $Crawler
@onready var legs: Node3D = $Legs

var clip := "perch"
var is_crawler := false
## How much bigger than the original its walker is drawn, and the pitch of its voice.
var walker_scale := 1.0
var voice_pitch := 1.0
var _full_player: AnimationPlayer
var _crawler_player: AnimationPlayer
var _legs_rest: Transform3D
static var _walkers: Dictionary = {}


## Every walker's look, from the build's walkers.json.
static func walkers() -> Dictionary:
	if _walkers.is_empty():
		_walkers = (load(WALKERS) as JSON).data
	return _walkers


static func walker_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: String in walkers():
		names.append(StringName(key))
	return names


func _ready() -> void:
	_full_player = _player_in(full)
	_crawler_player = _player_in(crawler)
	for player in [_full_player, _crawler_player]:
		for animation_name: StringName in player.get_animation_list():
			player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR if animation_name in LOOPS \
				else Animation.LOOP_NONE
	var eyes: Array = [{"bone": "head", "position": EYES[0], "glow": EYE_GLOW},
		{"bone": "head", "position": EYES[1], "glow": EYE_GLOW}]
	if walker != &"":
		var look: Dictionary = walkers().get(String(walker), {})
		if look.is_empty():
			push_warning("No Ridgeback walker called %s" % walker)
		else:
			_wear(look)
			eyes = look.eyes
	for model in [full, crawler]:
		_add_eyes(model, eyes)
	for mesh: Node in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = Gore.GORE_FREE_LAYER
	_legs_rest = legs.transform
	set_whole()


## The clip for a gameplay state on whichever body it has now; from_start plays it from its first frame.
func play(next_clip: String, from_start: bool = false) -> void:
	var entry: Array = CLIPS.get(next_clip, CLIPS["perch"])
	clip = next_clip
	var player := _crawler_player if is_crawler else _full_player
	var model_clip: StringName = entry[1] if is_crawler else entry[0]
	if not player.has_animation(model_clip):
		push_warning("Missing Ridgeback animation: %s" % model_clip)
		return
	if not from_start and player.current_animation == model_clip:
		return
	player.speed_scale = 1.0
	player.play(model_clip, 0.0 if next_clip in ["splat", "rise"] else 0.12)


## Starts the loop playing now at a point of its own, so a line of them on the roofs do not sway together.
func scatter_phase(rng: RandomNumberGenerator) -> void:
	var player := _crawler_player if is_crawler else _full_player
	if player.current_animation != &"":
		player.seek(rng.randf() * player.current_animation_length, true)


## Holds the clip playing now on its last frame: a body lying still.
func settle() -> void:
	var player := _crawler_player if is_crawler else _full_player
	if player.current_animation != &"":
		player.seek(player.current_animation_length, true)


## The crawl's cadence follows how fast it moves.
func set_crawl_speed(speed: float) -> void:
	if is_crawler and clip == "crawl":
		_crawler_player.speed_scale = clampf(speed / (CRAWL_SPEED * global_basis.get_scale().y), 0.4, 3.0)


## The whole body back, and the legs put away.
func set_whole() -> void:
	is_crawler = false
	full.show()
	crawler.hide()
	legs.top_level = false
	legs.transform = _legs_rest
	legs.hide()


## Into the crawler, leaving the legs lying where they are, the splat's corpse, now on their own.
func lose_legs() -> void:
	var lying := legs.global_transform
	legs.top_level = true
	legs.global_transform = lying
	legs.show()
	full.hide()
	crawler.show()
	is_crawler = true
	_crawler_player.play(&"crawl_rise", 0.0)
	_crawler_player.seek(0.0, true)
	clip = "rise"


## The walker's meshes on these models' skeletons (the same rig, so the same clips), and its size.
func _wear(look: Dictionary) -> void:
	var source := (load(str(look.model)) as PackedScene).instantiate()
	for pair: Array in [[full, "Walker"], [crawler, "WalkerCrawler"], [legs, "WalkerLegs"]]:
		var from := source.find_child(pair[1], true, false) as MeshInstance3D
		var into := (pair[0] as Node).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		into.mesh = from.mesh
		if from.skin != null:
			into.skin = from.skin
	source.free()
	walker_scale = float(look.get("scale", 1.0))
	voice_pitch = float(look.get("pitch", 1.0))
	scale *= walker_scale


## A glowing dot on its bone for each eye: [{bone, position (skeleton space, at rest), glow}].
func _add_eyes(model: Node3D, eyes: Array) -> void:
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var attachments := {}
	var dots := {}
	for eye: Dictionary in eyes:
		var bone := str(eye.bone)
		if not attachments.has(bone):
			var attachment := BoneAttachment3D.new()
			attachment.name = "Eyes" if bone == "head" else "Eyes_" + bone
			attachment.bone_name = bone
			skeleton.add_child(attachment)
			attachments[bone] = attachment
		var glow := _colour(eye.glow)
		if not dots.has(glow):
			dots[glow] = _eye_mesh(glow)
		var at := _vector(eye.position)
		var mesh := MeshInstance3D.new()
		mesh.mesh = dots[glow]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse() * at
		(attachments[bone] as Node).add_child(mesh)


func _eye_mesh(glow: Color) -> SphereMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = glow
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = EYE_ENERGY
	material.disable_fog = true
	var dot := SphereMesh.new()
	dot.radius = EYE_RADIUS
	dot.height = EYE_RADIUS * 2.0
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = material
	return dot


static func _colour(value: Variant) -> Color:
	if value is Color:
		return value
	var parts: Array = value
	return Color(float(parts[0]), float(parts[1]), float(parts[2]))


static func _vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var parts: Array = value
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _player_in(node: Node) -> AnimationPlayer:
	return node.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
