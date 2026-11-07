extends SceneTree
## Draws the blood the alt route's downtown Ridgebacks leave (scenes/atmosphere/gore/gore.gd): splats where
## a body hits the road, the pool that spreads under one lying still, the spatter of a shot, and the smear a
## crawler drags behind it. White on transparent, so the decals tint them; the alpha carries the shape.
## Seeded, so a rerun draws the same images.
##
## godot --headless --path . --script res://tools/make_gore_textures.gd

const FOLDER := "res://img/textures/gore/"
const SIZE := 256


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	for index in 3:
		_save(_splat(101 + index, 0.24 + 0.03 * index, 10 + 3 * index), "blood_splat_%d" % (index + 1))
	_save(_pool(201), "blood_pool")
	_save(_spatter(301), "blood_spatter")
	_save(_smear(401), "blood_smear")
	quit()


## A body's impact: a ragged blob, streaks flung out from it, and drops past their ends.
func _splat(seed: int, radius: float, streaks: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cover := PackedFloat32Array()
	cover.resize(SIZE * SIZE)
	var edge := _noise(seed, 3.0)
	_blob(cover, Vector2(0.5, 0.5), radius, edge, 0.35)
	for streak in streaks:
		var angle := rng.randf() * TAU
		var reach := rng.randf_range(radius * 1.2, 0.48)
		var width := rng.randf_range(0.012, 0.035)
		var direction := Vector2.from_angle(angle)
		var steps := 24
		for step in steps:
			var t := float(step) / steps
			var at := Vector2(0.5, 0.5) + direction * lerpf(radius * 0.6, reach, t)
			_disc(cover, at, width * (1.0 - 0.7 * t), 1.0)
		for drop in rng.randi_range(2, 5):
			var past := Vector2(0.5, 0.5) + direction.rotated(rng.randf_range(-0.12, 0.12)) * (reach + rng.randf_range(0.01, 0.08))
			_disc(cover, past, rng.randf_range(0.004, 0.016), 1.0)
	return _image(cover, seed)


## A pool under a body: one wide, smooth-edged blob.
func _pool(seed: int) -> Image:
	var cover := PackedFloat32Array()
	cover.resize(SIZE * SIZE)
	_blob(cover, Vector2(0.5, 0.5), 0.36, _noise(seed, 2.0), 0.22)
	return _image(cover, seed)


## A shot's spatter: a scatter of drops, thickest in the middle.
func _spatter(seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cover := PackedFloat32Array()
	cover.resize(SIZE * SIZE)
	for drop in 140:
		var at := Vector2(0.5, 0.5) + Vector2.from_angle(rng.randf() * TAU) * 0.45 * pow(rng.randf(), 1.6)
		_disc(cover, at, rng.randf_range(0.004, 0.022), 1.0)
	return _image(cover, seed)


## A drag mark, running along the image's height: streaks that thin out toward the top.
func _smear(seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cover := PackedFloat32Array()
	cover.resize(SIZE * SIZE)
	var noise := _noise(seed, 6.0)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var across := absf(u - 0.5) / (0.26 + 0.05 * noise.get_noise_2d(0.0, y * 2.0))
			# Claw and belly streaks running along the drag, wavering a little.
			var line := 0.5 + 0.5 * sin(u * 70.0 + 4.0 * noise.get_noise_2d(x * 0.5, y * 0.15))
			var streaks := 0.35 + 0.65 * smoothstep(0.35, 0.75, line)
			var fade := smoothstep(0.0, 0.35, v) * smoothstep(1.0, 0.8, v)
			cover[y * SIZE + x] = clampf((1.0 - across) * 4.0, 0.0, 1.0) * streaks * fade
	for drop in 30:
		_disc(cover, Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.1, 0.9)), rng.randf_range(0.004, 0.012), 1.0)
	return _image(cover, seed)


func _noise(seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency / SIZE
	noise.fractal_octaves = 3
	return noise


## Fills a blob whose edge wobbles by `rough` of its radius with the noise, round the angle.
func _blob(cover: PackedFloat32Array, centre: Vector2, radius: float, noise: FastNoiseLite, rough: float) -> void:
	for y in SIZE:
		for x in SIZE:
			var offset := Vector2(float(x) / SIZE, float(y) / SIZE) - centre
			var angle := offset.angle()
			var wobble := noise.get_noise_2d(cos(angle) * 60.0, sin(angle) * 60.0)
			var reach := radius * (1.0 + rough * wobble)
			var inside := clampf((reach - offset.length()) * SIZE / 2.5, 0.0, 1.0)
			cover[y * SIZE + x] = maxf(cover[y * SIZE + x], inside)


func _disc(cover: PackedFloat32Array, centre: Vector2, radius: float, value: float) -> void:
	var lo := Vector2i(int((centre.x - radius) * SIZE) - 1, int((centre.y - radius) * SIZE) - 1)
	var hi := Vector2i(int((centre.x + radius) * SIZE) + 2, int((centre.y + radius) * SIZE) + 2)
	for y in range(maxi(lo.y, 0), mini(hi.y, SIZE)):
		for x in range(maxi(lo.x, 0), mini(hi.x, SIZE)):
			var distance := Vector2(float(x) / SIZE, float(y) / SIZE).distance_to(centre)
			var inside := clampf((radius - distance) * SIZE / 1.2, 0.0, 1.0) * value
			cover[y * SIZE + x] = maxf(cover[y * SIZE + x], inside)


## White where covered, a little darker where the blood lies thick, alpha the cover, kept off the border.
func _image(cover: PackedFloat32Array, seed: int) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var grain := _noise(seed + 7, 40.0)
	for y in SIZE:
		for x in SIZE:
			var border := minf(minf(x, SIZE - 1 - x), minf(y, SIZE - 1 - y)) / 6.0
			var alpha := cover[y * SIZE + x] * clampf(border, 0.0, 1.0)
			var shade := 0.82 + 0.18 * grain.get_noise_2d(x, y)
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	return image


func _save(image: Image, file_name: String) -> void:
	var error := image.save_png(FOLDER + file_name + ".png")
	print("%s: %s" % [file_name, "saved" if error == OK else error_string(error)])
