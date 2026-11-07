extends SceneTree
## Draws the alt route's hospital surfaces (scenes/environment/alt_hospital.gd): painted plaster, near white so
## each paint colour tints it, with mottling, grime and water damage; the drop ceiling's tiles on their grid; and
## the decals it projects: water stains, grime along the bottoms of the walls, handprints. Everything tiles that
## should; decals are white on transparent (the decal's colour tints them) except the water stain, which is
## coloured. Seeded, so a rerun draws the same images.
##
## godot --headless --path . --script res://tools/make_alt_hospital_textures.gd

const FOLDER := "res://img/textures/alt_hospital/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	_save(_plaster(), "plaster")
	_save(_ceiling_tiles(), "ceiling_tiles")
	_save(_water_stain(), "water_stain")
	_save(_grime(), "grime")
	_save(_handprint(), "handprint")
	quit()


func _save(image: Image, name: String) -> void:
	image.save_png(ProjectSettings.globalize_path(FOLDER + name + ".png"))
	print("TEXTURE ", name, " ", image.get_size())


func _noise(seed: int, frequency: float, octaves: int = 4) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return noise


## A seamless 0..1 field of a noise over size x size.
func _field(noise: FastNoiseLite, size: int) -> Image:
	return noise.get_seamless_image(size, size, false, false, 0.1, true)


## Painted plaster: mottled, a little grain, grimy patches and water marks with darker tide lines, a few cracks.
func _plaster() -> Image:
	var size := 512
	var mottle := _field(_noise(11, 0.008), size)
	var grain := _field(_noise(12, 0.12, 2), size)
	var damp := _field(_noise(13, 0.004, 3), size)
	var grime := _field(_noise(14, 0.02, 5), size)
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	for y in size:
		for x in size:
			var v := 0.9 + (mottle.get_pixel(x, y).r - 0.5) * 0.12 + (grain.get_pixel(x, y).r - 0.5) * 0.06
			var colour := Color(v, v, v * 0.98)
			var g := grime.get_pixel(x, y).r
			if g > 0.7:
				colour = colour.darkened((g - 0.7) * 0.45)
			# Water: a pale brown stain with a darker line at its edge.
			var d := damp.get_pixel(x, y).r
			if d > 0.8:
				colour = colour.lerp(Color(0.78, 0.68, 0.5), clampf((d - 0.8) * 3.0, 0.0, 0.35))
			if absf(d - 0.8) < 0.006:
				colour = colour.darkened(0.18)
			image.set_pixel(x, y, colour)
	# Hairline cracks.
	for k in 6:
		var at := Vector2(rng.randf_range(0, size), rng.randf_range(0, size))
		var heading := rng.randf_range(0.0, TAU)
		for step in rng.randi_range(40, 120):
			heading += rng.randf_range(-0.5, 0.5)
			at += Vector2(cos(heading), sin(heading)) * 1.5
			var px := posmod(int(at.x), size)
			var py := posmod(int(at.y), size)
			image.set_pixel(px, py, image.get_pixel(px, py).darkened(0.35))
	return image


## A drop ceiling's acoustic tiles, 0.6 x 1.2 m each, two to the 1.2 m image, on their steel grid; fissured, a
## few stained.
func _ceiling_tiles() -> Image:
	var size := 512
	var speckle := _field(_noise(21, 0.25, 2), size)
	var stain := _field(_noise(22, 0.006, 3), size)
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var bar := x % 256 < 5 or y < 5
			if bar:
				image.set_pixel(x, y, Color(0.62, 0.62, 0.6) if (x % 256 != 4 and y != 4) else Color(0.4, 0.4, 0.39))
				continue
			var v := 0.86 + (speckle.get_pixel(x, y).r - 0.5) * 0.1
			if speckle.get_pixel(x, y).r < 0.18:
				v -= 0.12
			var colour := Color(v, v * 0.99, v * 0.95)
			var s := stain.get_pixel(x, y).r
			if s > 0.8:
				colour = colour.lerp(Color(0.62, 0.5, 0.3), clampf((s - 0.8) * 3.5, 0.0, 0.5))
			if absf(s - 0.8) < 0.006:
				colour = colour.darkened(0.25)
			image.set_pixel(x, y, colour)
	return image


## A water stain: a pale brown blotch with rings where the water dried back, a darker tide line at its edge.
func _water_stain() -> Image:
	var size := 256
	var edge := _noise(31, 0.015, 3)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x, y) / size - Vector2(0.5, 0.5)
			var r := p.length() * 2.4 + edge.get_noise_2d(x, y) * 0.2
			if r > 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Faint inner rings, then the tide line, softened on its outside.
			var ring := pow(absf(sin(r * 9.0)), 12.0) * 0.12
			var tide := clampf(1.0 - absf(r - 0.93) / 0.07, 0.0, 1.0)
			var a := 0.18 + r * 0.12 + ring + tide * 0.4
			var colour := Color(0.66, 0.53, 0.32).lerp(Color(0.4, 0.28, 0.14), tide)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, a))
	return image


## Grime along the bottom of a wall: scuffs and kicks, heaviest at the bottom edge, fading up. White, for tint.
func _grime() -> Image:
	var w := 512
	var h := 192
	var noise := _noise(41, 0.03, 4)
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in h:
		for x in w:
			var up := float(y) / h    # 0 at the top of the image, 1 at the floor
			var a := clampf((up - 0.35) * 1.1 + noise.get_noise_2d(x, y) * 0.35, 0.0, 0.7) * clampf(minf(x, w - x) / 40.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	# Black scuff marks from trolleys and shoes.
	for k in 40:
		var x0 := rng.randi_range(20, w - 60)
		var y0 := rng.randi_range(int(h * 0.45), h - 10)
		var length := rng.randi_range(12, 50)
		for i in length:
			var px := x0 + i
			var py := y0 + int(sin(i * 0.2 + k) * 2.0)
			if px < w and py < h:
				image.set_pixel(px, py, Color(1, 1, 1, 0.6))
	return image


## A bloody handprint dragged down a wall: palm, fingers, and the smear below. White, for tint.
func _handprint() -> Image:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rough := _noise(51, 0.08, 2)
	var shapes: Array = [[Vector2(124, 128), Vector2(30, 34)]]
	# Fingers: (base, tip) capsules, a left hand's, the thumb off to the right.
	var fingers: Array = [[Vector2(102, 104), Vector2(92, 52)], [Vector2(117, 98), Vector2(113, 38)],
		[Vector2(132, 98), Vector2(136, 42)], [Vector2(146, 104), Vector2(156, 60)], [Vector2(150, 138), Vector2(186, 112)]]
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var inside := 0.0
			var palm: Array = shapes[0]
			var q := (p - (palm[0] as Vector2)) / (palm[1] as Vector2)
			if q.length() < 1.0:
				inside = 1.0
			for finger: Array in fingers:
				var a: Vector2 = finger[0]
				var b: Vector2 = finger[1]
				var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				if p.distance_to(a.lerp(b, t)) < 7.5 - t * 1.5:
					inside = 1.0
			# Below the palm, four streaks where the fingers dragged down as the hand slid.
			if y > 140:
				for k in 4:
					var lane := 100.0 + k * 15.0 + (y - 140) * 0.04
					if absf(x - lane) < 4.5 - (y - 140) * 0.03:
						inside = maxf(inside, 0.8 - (y - 140) / 140.0)
			if inside > 0.0:
				var a := inside * clampf(0.85 + rough.get_noise_2d(x, y) * 0.3, 0.3, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, a))
	return image
