extends SceneTree

# Run against the exported PCK with --main-pack, using this script's absolute path.
const SCENES := [
	"res://scenes/mainMenu/startup.tscn",
	"res://scenes/mainMenu/menu.tscn",
	"res://scenes/chapters/intro/intro.tscn",
	"res://scenes/chapters/tutorial/tutorial.tscn",
	"res://scenes/chapters/main/starting_forest.tscn",
	"res://scenes/chapters/main/map.tscn",
]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for path in SCENES:
		var result := change_scene_to_file(path)
		if result != OK:
			push_error("DEMO FAIL: %s (%s)" % [path, result])
			quit(1)
			return
		await create_timer(0.5).timeout
		print("DEMO PASS: ", path)
	print("DEMO SMOKE COMPLETE")
	quit()
