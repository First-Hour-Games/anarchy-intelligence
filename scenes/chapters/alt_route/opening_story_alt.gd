extends "res://scenes/chapters/main/opening_story.gd"
## The alt route's copy of the opening chapter (map_alt.tscn): the same story, with the Ridgebacks on the roofs
## of the downtown street on the way to the hospital (rooftop_street.gd). While that street has Thomas, the
## Wrapper waits out of it, and dying there starts him again at the corner.
## Coming in from the alt route's residence area (residence_area_alt.gd), past the Ridgeback road, Thomas starts
## the chapter afresh at the head of Carrie's road, with the flashlight and the shotgun and shells he carried.
## The hospital here is the alt route's own (scenes/environment/alt_hospital.gd): its register and notice say
## the evacuation went out by air from the roof, so Thomas climbs it storey by storey, the Clawman waiting at the
## far end of each one, to the helicopter on the roof, and flies out.

## The corner where the street begins, by the crashed police car.
const STREET_CORNER := Vector3(103.0, 0.35, 225.0)
## Where Thomas comes in from the residence area, and which way he faces: down the west road to Carrie's.
const ARRIVAL := Vector3(97.0, 0.35, 125.0)
const ARRIVAL_FACING := Vector3(60.0, 0.35, 125.0)
const ARRIVAL_LINE := "Whatever those were, they didn't follow me. Carrie's house is at the end of this road."

var street_has_player := false

const HOSPITAL_PATH := "Buildings/NeighborhoodHospital"
const CLIMB_OBJECTIVE := "Climb to the roof. The last helicopter is waiting."
const ESCAPED_OBJECTIVE := "You got out. Chapter complete."
const REGISTER_TEXT := "TEMPORARY SHELTER — ARRIVALS\n\nCarrie — admitted to Ward 2. Personal belongings retained.\n\nLater entry: The road out is closed. Residents are being flown out from the roof helipad, the sickest first. The last group goes up tonight."
const EVACUATION_TEXT := "EVACUATION BY AIR\n\nThe roads are cut. The rescue helicopter is landing on the roof helipad and taking people out one load at a time.\n\nEveryone goes up by the stairs. The lifts are dead, and Stair A is chained shut on this floor.\n\nThe last flight will wait on the pad for as long as it can.\n\nDo not follow voices calling from empty rooms."
const FLIGHT_TEXT := "RADIO LOG — ROOF PAD\n\n19:40  Rescue One lifted with fourteen. Carrie M. on board.\n21:10  Last group not at the pad. The stairs are blocked on 2 and 3; sent them round to the other stair.\n22:30  Rescue One back on the pad. Pilot holding until the fuel runs low.\n\nWhoever reads this: get up here."
## What Thomas says as he first reaches each storey (4 is the roof).
const STOREY_LINES := {
	1: "The wards. Something's moving down there, at the far end of the corridor.",
	2: "Surgery. The stair up is barricaded... I'll have to go round to the other one.",
	3: "The top floor. The roof door is at the far end.",
	4: "There it is. The helicopter.",
}
## The landing each storey is first reached at, up the zig-zag (G up stair B, 2 up A, 3 up B, 4 up A).
const ARRIVAL_LANDINGS := {1: &"landing_B1", 2: &"landing_A2", 3: &"landing_B3", 4: &"roof_door"}

var hospital: Node3D
var helicopter: Node
var _escaping := false


func _ready() -> void:
	var carried := AltRouteCarry.take()
	if not carried.is_empty() and persist_progress and FileAccess.file_exists(progress_save_path):
		# Coming in from the residence area starts this chapter afresh.
		DirAccess.remove_absolute(progress_save_path)
	super._ready()
	if not carried.is_empty():
		_arrive(carried)
	_setup_hospital.call_deferred()


## In from the residence area: at the head of Carrie's road with what he carried, the flashlight found long ago.
func _arrive(carried: Dictionary) -> void:
	for id: String in ["arrival", "barrier", "station", "flashlight"]:
		spoken[id] = true
	subtitle_queue.clear()
	subtitle_time = 0.0
	stage = maxi(stage, 1)
	_flashlight_seen = true
	if not player.inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM):
		player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	var dropped := get_parent().get_node_or_null("AtmosphereProps/DroppedFlashlight")
	if dropped != null:
		dropped.queue_free()
	if bool(carried.get("shotgun", false)) and not player.inventory.has_item(&"shotgun"):
		player.inventory.add_item(&"shotgun")
		var shotgun := player.get_node_or_null("Head/Camera3D/ShotgunWeapon")
		if shotgun != null:
			# After the gun has looked at the inventory (deferred), which hands a found gun its own shells.
			shotgun.call_deferred("restore_shells", int(carried.get("loaded", 2)), int(carried.get("reserve", 0)))
	player.global_position = ARRIVAL
	player.velocity = Vector3.ZERO
	player.look_at(ARRIVAL_FACING, Vector3.UP)
	player.head.rotation.x = 0.0
	_set_checkpoint(ARRIVAL)
	narrate_once("alt_arrival", ARRIVAL_LINE)
	_refresh_objective()
	_sync_encounters()
	_save()


func _sync_encounters() -> void:
	super._sync_encounters()
	if street_has_player:
		get_parent().get_node("Wrapper").set("enabled", false)
	# The new hospital's Clawman only hunts from the wards up, and never once Thomas is on his way out.
	var clawman := get_parent().get_node_or_null("Clawman")
	if clawman != null and hospital != null:
		clawman.set("enabled", stage >= 3 and discovered.has("storey_1") and not _escaping)


## The street has Thomas (or has let him go): the Wrapper stays out of it meanwhile, and a death there starts
## him again at the corner.
func set_street_hold(holding: bool) -> void:
	if holding == street_has_player:
		return
	street_has_player = holding
	if holding:
		_set_checkpoint(STREET_CORNER)
		_save()
	_sync_encounters()


## Debug menu: the street as Thomas reaches it with the notebook read, the flashlight and the shotgun, facing
## down it. Saving stops for that session.
func debug_start_street() -> void:
	persist_progress = false
	stage = maxi(stage, 2)
	_flashlight_seen = true
	discovered["carrie"] = true
	# The chapter's opening lines are long past by the time Thomas gets here.
	for id: String in ["arrival", "barrier", "station", "house", "west_road", "old_street", "hospital_route"]:
		spoken[id] = true
	subtitle_queue.clear()
	subtitle_time = 0.0
	for item: StringName in [PlayerInventory.FLASHLIGHT_ITEM, PlayerInventory.NOTEBOOK_ITEM, &"shotgun"]:
		if not player.inventory.has_item(item):
			player.inventory.add_item(item)
	_set_checkpoint(STREET_CORNER)
	_refresh_objective()
	_sync_encounters()


# ---- The new hospital ----------------------------------------------------------------------------------

func _setup_hospital() -> void:
	hospital = get_parent().get_node_or_null(HOSPITAL_PATH) as Node3D
	if hospital == null or not hospital.has_method("storey_at"):
		hospital = null
		return
	helicopter = hospital.get("helicopter") as Node
	if helicopter != null:
		helicopter.connect("boarded", _on_boarded)
		helicopter.connect("departed", _on_departed)
		helicopter.set("can_board", discovered.has("storey_4"))
	_place_clawman()
	_sync_encounters()
	_refresh_objective()


## The old hospital's documents are made by the main story; here they say where the evacuation really went,
## and the radio log on the top floor says who was on the first flight.
func _build_documents() -> void:
	super._build_documents()
	var building := get_parent().get_node(HOSPITAL_PATH) as Node3D
	if not building.has_method("storey_at"):
		return
	_reword(building, "RegisterDocument", "Emergency shelter registration", REGISTER_TEXT)
	_reword(building, "EvacuationDocument", "Evacuation notice", EVACUATION_TEXT)
	_document(building, building.call("document_point", &"flight"), &"flight", "Radio log, roof pad", FLIGHT_TEXT, Color(0.7, 0.72, 0.6))


func _reword(building: Node3D, node_name: String, title: String, words: String) -> void:
	var doc := building.get_node_or_null(node_name)
	if doc == null:
		return
	doc.set("title", title)
	doc.set("body", words)
	for label: Node in doc.find_children("*", "Label3D", false, false):
		(label as Label3D).text = title


func open_document(id: StringName, title: String, words: String) -> void:
	var fresh := not discovered.has(str(id))
	super.open_document(id, title, words)
	if not fresh or not document_open:
		return
	match id:
		&"evacuation":
			narrate_once("evac_air", "They flew everyone out from the roof. The stairs are the only way up.")
		&"flight":
			narrate_once("flight_read", "Carrie was on the first flight. She got out. Now I have to get up there before it leaves.")
	_refresh_objective()


func _refresh_objective() -> void:
	super._refresh_objective()
	if hospital == null:
		return
	if stage == 2 or stage == 3:
		target_position = hospital.call("point", &"entrance") * Vector3(1, 0, 1)
	if discovered.has("escaped"):
		objective.call("set_objective", stage, ESCAPED_OBJECTIVE)
		target_position = Vector3.ZERO
	elif stage >= 5 or discovered.has("storey_1"):
		objective.call("set_objective", stage, CLIMB_OBJECTIVE)
		target_position = hospital.call("point", &"helipad") * Vector3(1, 0, 1)


func _process(delta: float) -> void:
	super._process(delta)
	if document_open or not is_instance_valid(player) or hospital == null or _escaping:
		return
	var p := player.global_position
	var entrance: Vector3 = hospital.call("point", &"entrance")
	if stage < 3 and p.distance_to(entrance) < 9.0:
		stage = 3
		_set_checkpoint(entrance + Vector3.UP * 0.35)
		narrate_once("alt_hospital", "It's bigger than I remember. Four floors... and something on the roof.")
		_refresh_objective()
		_sync_encounters()
		_save()
	var storey: int = hospital.call("storey_at", p)
	if storey >= 1 and not discovered.has("storey_%d" % storey):
		_reach_storey(storey)


func _highest_storey() -> int:
	for storey: int in [4, 3, 2, 1]:
		if discovered.has("storey_%d" % storey):
			return storey
	return 0


## The Clawman waits at the far end of the highest storey Thomas has reached (from the wards up).
func _place_clawman() -> void:
	var clawman := get_parent().get_node_or_null("Clawman")
	if clawman == null or hospital == null:
		return
	clawman.call("set_post", hospital.call("clawman_post", clampi(_highest_storey(), 1, 3)))


func _reach_storey(storey: int) -> void:
	discovered["storey_%d" % storey] = true
	narrate_once("storey_%d" % storey, STOREY_LINES[storey])
	_set_checkpoint(hospital.call("point", ARRIVAL_LANDINGS[storey]) + Vector3.UP * 0.35)
	if storey <= 3:
		_place_clawman()
	if storey == 4:
		narrate_once("pilot_call", "Over here! Get in, we're going!", "Pilot", true)
		if helicopter != null:
			helicopter.set("can_board", true)
	_sync_encounters()
	_refresh_objective()
	_save()


## Thomas climbs in: the Clawman stops hunting and the helicopter lifts off. It comes out of the stair house
## as the rotors wind up, runs at the pad, screams and lashes at him as he rises out of reach.
func _on_boarded(rider: FirstPersonPlayer) -> void:
	if _escaping:
		return
	_escaping = true
	discovered["escaped"] = true
	stage = maxi(stage, 5)
	# The flight out passes over the downtown street: its Ridgebacks on the roofs are left behind as they are.
	var street := get_parent().get_node_or_null("RooftopStreet")
	if street != null:
		street.process_mode = Node.PROCESS_MODE_DISABLED
	_sync_encounters()
	narrate_once("pilot_go", "Hold on to something!", "Pilot", true)
	helicopter.call("fly_away", rider)
	_clawman_on_the_roof()
	_refresh_objective()
	_save()


func _clawman_on_the_roof() -> void:
	var clawman := get_parent().get_node_or_null("Clawman") as Node3D
	if clawman == null:
		return
	var door_local: Vector3 = hospital.call("local_point", &"roof_door")
	var inside: Vector3 = hospital.to_global(door_local + Vector3(-3.4, 0.0, 0.0))
	var pad: Vector3 = hospital.call("point", &"helipad")
	var flat := (pad - inside) * Vector3(1, 0, 1)
	clawman.call("place", Transform3D(Basis.looking_at(flat.normalized()), inside))
	var visual := clawman.get_node("Visual")
	visual.call("play", "run")
	var edge := inside.lerp(pad, 0.7)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(clawman, "global_position", edge, 2.6)
	tween.tween_callback(visual.call.bind("play", "windup"))
	tween.tween_interval(1.6)
	tween.tween_callback(visual.call.bind("play", "attack"))
	tween.tween_interval(2.2)
	tween.tween_callback(visual.call.bind("play", "windup"))


func _on_departed() -> void:
	narrate_once("escaped_line", "Carrie's out there somewhere. So am I, now.")
	var card := CanvasLayer.new()
	card.layer = 97
	card.name = "EscapeCard"
	add_child(card)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(black)
	var words := Label.new()
	words.text = "You got out.\n\nChapter complete.\n\n(Esc for the menu)"
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	words.modulate = Color(1, 1, 1, 0)
	words.add_theme_font_size_override("font_size", 28)
	card.add_child(words)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 2.5)
	tween.tween_property(words, "modulate:a", 1.0, 1.5)


## Debug menu: on the new hospital's roof by the stair house, every storey climbed and both clues read, with
## the flashlight and the shotgun; the helicopter is waiting. Saving stops for that session.
func debug_start_roof() -> void:
	persist_progress = false
	stage = 5
	_flashlight_seen = true
	for key: String in ["carrie", "register", "evacuation", "storey_1", "storey_2", "storey_3", "storey_4"]:
		discovered[key] = true
	for id: String in ["arrival", "barrier", "station", "house", "west_road", "old_street", "hospital_route",
			"alt_hospital", "storey_1", "storey_2", "storey_3"]:
		spoken[id] = true
	subtitle_queue.clear()
	subtitle_time = 0.0
	for item: StringName in [PlayerInventory.FLASHLIGHT_ITEM, PlayerInventory.NOTEBOOK_ITEM, &"shotgun"]:
		if not player.inventory.has_item(item):
			player.inventory.add_item(item)
	if hospital == null:
		_setup_hospital()
	if hospital != null:
		_set_checkpoint(hospital.call("point", &"roof_door") + Vector3.UP * 0.35)
		if helicopter != null:
			helicopter.set("can_board", true)
	narrate_once("pilot_call", "Over here! Get in, we're going!", "Pilot", true)
	_place_clawman()
	_refresh_objective()
	_sync_encounters()
