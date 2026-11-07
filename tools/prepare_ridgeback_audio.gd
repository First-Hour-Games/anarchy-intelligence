extends SceneTree
## The Ridgeback's strike, played when a pounce in the alt route's car ambush lands on the player
## (scenes/monsters/the_ridgeback/ridgeback_ambusher.gd): a body slam, a rake of claws and a snarl, mixed
## into one mono WAV and peak-normalized. The slam (a falling sine with a click) and the claws (short bursts
## of band-passed noise) are synthesized here; the snarl is the loudest short stretch of one of the CC0 pig
## screams its other sounds come from (tools/prepare_ridgeback_pig_audio.gd), played low. Seeded, so it
## comes out the same every time. The source stays untouched.
##
## godot --headless --path . --script res://tools/prepare_ridgeback_audio.gd

const SOURCE := "res://sounds/entities/ridgeback/pig_scream_5_source.mp3"
const OUT := "res://sounds/entities/ridgeback/ridgeback_strike.wav"
const LENGTH := 0.8
const PEAK := 0.9
const FADE_OUT := 0.2
## The snarl: how long a stretch, how low it plays, when it comes in and how loud.
const SNARL_SECONDS := 0.42
const SNARL_RATE := 0.72
const SNARL_AT := 0.03
const SNARL_GAIN := 0.75
## The claws: when each scratch starts, how loud, and the band it rasps in.
const SCRATCHES := [[0.012, 0.5], [0.05, 0.42], [0.085, 0.34]]
const SCRATCH_BAND := Vector2(1800.0, 6000.0)
const SCRATCH_SECONDS := 0.06


func _initialize() -> void:
	var rate := int(AudioServer.get_mix_rate())
	var count := int(LENGTH * rate)
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_slam(mix, rate, rng)
	_claws(mix, rate, rng)
	if not _snarl(mix, rate):
		quit(1)
		return
	var peak := 0.0
	for value in mix:
		peak = maxf(peak, absf(value))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in count:
		var fade := minf(1.0, float(count - index) / (FADE_OUT * rate))
		bytes.encode_s16(index * 2, int(clampf(mix[index] * PEAK / peak * fade, -1.0, 1.0) * 32767.0))
	var output := AudioStreamWAV.new()
	output.format = AudioStreamWAV.FORMAT_16_BITS
	output.stereo = false
	output.mix_rate = rate
	output.data = bytes
	output.save_to_wav(OUT)
	print("ridgeback_strike: %.2f s, raw peak %.3f, normalized to %.2f" % [LENGTH, peak, PEAK])
	quit()


## A thud felt more than heard: a sine falling from 155 Hz to 45 Hz as it dies away, on a click of dull noise.
func _slam(mix: PackedFloat32Array, rate: int, rng: RandomNumberGenerator) -> void:
	var phase := 0.0
	var dull := 0.0
	var smoothing := 1.0 - exp(-TAU * 900.0 / rate)
	for index in mix.size():
		var t := float(index) / rate
		phase += TAU * (45.0 + 110.0 * exp(-t / 0.035)) / rate
		var body := sin(phase) * exp(-t / 0.11) * (1.0 - exp(-t / 0.002))
		dull += smoothing * (rng.randf_range(-1.0, 1.0) - dull)
		mix[index] += body + dull * 1.4 * exp(-t / 0.008)


## Claws dragged over cloth and skin: each scratch a burst of noise between SCRATCH_BAND's two
## frequencies, its loudness rasping at 70 Hz as it fades.
func _claws(mix: PackedFloat32Array, rate: int, rng: RandomNumberGenerator) -> void:
	var low := 1.0 - exp(-TAU * SCRATCH_BAND.y / rate)
	var high := 1.0 - exp(-TAU * SCRATCH_BAND.x / rate)
	for scratch: Array in SCRATCHES:
		var first := int(float(scratch[0]) * rate)
		var below_band := 0.0
		var band := 0.0
		for offset in int(SCRATCH_SECONDS * rate):
			if first + offset >= mix.size():
				break
			var t := float(offset) / rate
			var noise := rng.randf_range(-1.0, 1.0)
			band += low * (noise - band)
			below_band += high * (band - below_band)
			var envelope := (1.0 - exp(-t / 0.003)) * exp(-t / 0.018) * (0.6 + 0.4 * sin(TAU * 70.0 * t))
			mix[first + offset] += (band - below_band) * 3.0 * float(scratch[1]) * envelope


## The loudest SNARL_SECONDS of the scream, played at SNARL_RATE, with a quick fade in and a longer fade out.
func _snarl(mix: PackedFloat32Array, rate: int) -> bool:
	var stream := load(SOURCE) as AudioStream
	var playback := stream.instantiate_playback()
	playback.start()
	var frames := playback.mix_audio(SNARL_RATE, int(stream.get_length() / SNARL_RATE * rate))
	var window := mini(int(SNARL_SECONDS * rate), frames.size())
	var energies := PackedFloat64Array()
	energies.resize(frames.size() + 1)
	for index in frames.size():
		energies[index + 1] = energies[index] + frames[index].length_squared()
	var best_start := 0
	var best_energy := -1.0
	for start in range(0, frames.size() - window + 1, int(rate * 0.01)):
		var energy := energies[start + window] - energies[start]
		if energy > best_energy:
			best_energy = energy
			best_start = start
	var peak := 0.0
	for index in range(best_start, best_start + window):
		peak = maxf(peak, maxf(absf(frames[index].x), absf(frames[index].y)))
	if peak < 0.001:
		push_error("Silent scream: " + SOURCE)
		return false
	var first := int(SNARL_AT * rate)
	for offset in window:
		if first + offset >= mix.size():
			break
		var edge := minf(1.0, minf(float(offset) / (rate * 0.01), float(window - offset) / (rate * 0.15)))
		var frame := frames[best_start + offset]
		mix[first + offset] += (frame.x + frame.y) * 0.5 / peak * SNARL_GAIN * edge
	print("snarl from %.2f s of the scream at rate %.2f" % [float(best_start) / rate * SNARL_RATE, SNARL_RATE])
	return true
