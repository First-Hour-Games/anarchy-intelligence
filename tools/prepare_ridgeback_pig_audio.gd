extends SceneTree
## The voices of the alt route's car-ambush Ridgebacks (scenes/monsters/the_ridgeback/ridgeback_ambusher.tscn),
## made from the CC0 pig recordings in sounds/entities/ridgeback (see its CREDITS.md): the grunts from
## behind the cars, the shrieks on the roofs, the roar of a pounce, the squeals of one that is hit, the
## screams of one dying, and the scream the death scare plays when one kills. Also the sounds of the downtown
## Ridgebacks hitting the road off the roofs (scenes/monsters/the_ridgeback/ridgeback_faller.tscn), from the CC0
## splat, gore and bone recordings beside the pigs, and the alarm of a car one lands on, from the recording in
## sounds/props/car_alarm (its own CREDITS.md). Each sound mixes spans of the
## recordings played slower, so lower and bigger, like tape; a span whose rate changes as it plays slides
## in pitch, as the dying screams do. The mix loses its rumble below HIGH_PASS_HZ, is driven into a soft
## clip for grit, faded and peak-normalized, and saved beside the recordings as a mono WAV. The sources
## stay untouched.
##
## godot --headless --path . --script res://tools/prepare_ridgeback_pig_audio.gd

const FOLDER := "res://sounds/entities/ridgeback/"
## Each sound: how hard it is driven into the clip (1 leaves it clean), the peak it is normalized to, how
## long it fades out and how long it may run at most (seconds; 0 for as long as its layers), and its
## layers. A layer: the recording (FOLDER + it + "_source.mp3"), the span taken from it (seconds), the
## rate it plays at at the start of the span and at its end, its loudness, and when it comes in (seconds).
## A sound or recording named by a full res:// path lives there instead of in FOLDER.
const SOUNDS := {
	# Grunts from behind a car, and as it rears up to look over one.
	"ridgeback_grunt_1": [1.8, 0.8, 0.15, 0.0, [["pig_grunt_1", 0.04, 0.66, 0.72, 0.72, 1.0, 0.0]]],
	"ridgeback_grunt_2": [1.8, 0.8, 0.18, 0.0, [["pig_grunt_2", 0.06, 0.78, 0.7, 0.7, 1.0, 0.0]]],
	"ridgeback_grunt_3": [1.8, 0.8, 0.2, 0.0, [["pig_grunt_deep", 0.72, 1.42, 0.8, 0.8, 1.0, 0.0]]],
	# Shrieks on a roof.
	"ridgeback_shriek_1": [1.4, 0.9, 0.35, 0.0, [["pig_scream_5", 0.17, 1.72, 0.86, 0.86, 1.0, 0.0]]],
	"ridgeback_shriek_2": [1.6, 0.9, 0.4, 0.0, [["pig_scream_2", 0.36, 1.98, 0.84, 0.84, 1.0, 0.0]]],
	"ridgeback_shriek_3": [1.6, 0.9, 0.35, 0.0, [["pig_squeals", 0.48, 1.76, 0.78, 0.78, 1.0, 0.0]]],
	# The roar of a pounce, from the crouch before it through the leap: a scream played low over a deep grunt.
	"ridgeback_roar_1": [2.6, 0.92, 0.45, 0.0, [
		["pig_grunt_deep", 0.72, 1.3, 0.55, 0.55, 0.7, 0.0],
		["pig_scream_1", 0.46, 1.5, 0.6, 0.6, 1.0, 0.08]]],
	"ridgeback_roar_2": [2.6, 0.92, 0.45, 0.0, [
		["pig_grunt_2", 0.06, 0.6, 0.52, 0.52, 0.6, 0.0],
		["pig_scream_2", 0.36, 1.3, 0.56, 0.56, 1.0, 0.06]]],
	"ridgeback_roar_3": [2.4, 0.92, 0.4, 0.0, [
		["pig_grunt_1", 0.04, 0.6, 0.5, 0.5, 0.6, 0.0],
		["pig_scream_5", 0.17, 1.0, 0.6, 0.6, 1.0, 0.05]]],
	# Squeals of one hit and not killed.
	"ridgeback_pain_1": [1.5, 0.9, 0.2, 0.0, [["pig_scream_3", 0.18, 0.78, 0.9, 0.9, 1.0, 0.0]]],
	"ridgeback_pain_2": [1.5, 0.9, 0.25, 0.0, [["pig_grunt_squeal", 0.16, 0.94, 0.86, 0.86, 1.0, 0.0]]],
	# Dying: a scream that sinks as it gives out.
	"ridgeback_death_1": [1.5, 0.9, 1.2, 0.0, [["pig_scream_2", 0.36, 1.9, 0.92, 0.5, 1.0, 0.0]]],
	"ridgeback_death_2": [1.5, 0.9, 0.8, 0.0, [["pig_scream_4", 0.12, 0.98, 0.9, 0.45, 1.0, 0.0]]],
	# The death scare's scream when one kills the player (scenes/ui/death_scare.gd), as long as the others'.
	"ridgeback_road_kill": [2.2, 0.85, 0.3, 1.5, [
		["pig_grunt_deep", 0.72, 1.3, 0.6, 0.6, 0.6, 0.0],
		["pig_scream_5", 0.17, 1.1, 0.66, 0.66, 1.0, 0.0],
		["pig_scream_1", 1.6, 2.4, 0.62, 0.62, 0.55, 0.15]]],
	# A body off a roof hitting the road: a wet splat, played slower for the weight, or the gore impact
	# over a deep thud; the bones break under it. The squelch of a crawler taking a hit.
	"ridgeback_splat_1": [1.3, 0.95, 0.2, 0.0, [["body_splat", 0.0, 0.66, 0.8, 0.8, 1.0, 0.0]]],
	"ridgeback_splat_2": [1.4, 0.95, 0.3, 0.0, [["gore_impact", 0.0, 1.1, 0.82, 0.82, 1.0, 0.0]]],
	"ridgeback_splat_3": [1.6, 0.95, 0.3, 0.0, [
		["gore_impact", 0.0, 0.8, 0.55, 0.55, 0.8, 0.0],
		["body_splat", 0.0, 0.66, 0.9, 0.9, 1.0, 0.01]]],
	"ridgeback_bones_1": [1.2, 0.9, 0.12, 0.0, [["bone_break", 0.0, 0.48, 0.9, 0.9, 1.0, 0.0]]],
	"ridgeback_bones_2": [1.2, 0.9, 0.12, 0.0, [["bone_crackle", 0.0, 0.45, 0.85, 0.85, 1.0, 0.0]]],
	"ridgeback_squelch": [1.2, 0.85, 0.12, 0.0, [["squelch", 0.0, 0.45, 0.8, 0.8, 1.0, 0.0]]],
	# The alarm of a car one lands on: whole pulses of the recording, looped by its import settings.
	"res://sounds/props/car_alarm/car_alarm_loop": [1.0, 0.9, 0.005, 0.0, [
		["res://sounds/props/car_alarm/car_alarm_source.mp3", 0.98, 4.9, 1.0, 1.0, 1.0, 0.0]]],
}
const HIGH_PASS_HZ := 40.0
const FADE_IN := 0.006
## A rate that changes along a span is held for this many frames at a time.
const CHUNK := 64

var _rate := 44100


func _initialize() -> void:
	_rate = int(AudioServer.get_mix_rate())
	for sound_name: String in SOUNDS:
		var sound: Array = SOUNDS[sound_name]
		var voices: Array[PackedFloat32Array] = []
		var length := 0
		for layer: Array in sound[4]:
			var voice := _render(layer)
			if voice.is_empty():
				quit(1)
				return
			voices.append(voice)
			length = maxi(length, int(float(layer[6]) * _rate) + voice.size())
		var limit := int(float(sound[3]) * _rate)
		if limit > 0:
			length = mini(length, limit)
		var mix := PackedFloat32Array()
		mix.resize(length)
		mix.fill(0.0)
		for index in voices.size():
			var layer: Array = sound[4][index]
			var first := int(float(layer[6]) * _rate)
			var voice := voices[index]
			for offset in mini(voice.size(), length - first):
				mix[first + offset] += voice[offset] * float(layer[5])
		_high_pass(mix)
		var drive := float(sound[0])
		var peak := _peak(mix)
		for index in length:
			var value := mix[index] / peak
			mix[index] = tanh(value * drive) / tanh(drive) if drive > 1.0 else value
		var fade_out := float(sound[2]) * _rate
		for index in length:
			var edge := minf(1.0, minf(float(index) / (FADE_IN * _rate), float(length - index) / fade_out))
			mix[index] *= smoothstep(0.0, 1.0, edge)
		peak = _peak(mix)
		var bytes := PackedByteArray()
		bytes.resize(length * 2)
		for index in length:
			bytes.encode_s16(index * 2, int(clampf(mix[index] * float(sound[1]) / peak, -1.0, 1.0) * 32767.0))
		var output := AudioStreamWAV.new()
		output.format = AudioStreamWAV.FORMAT_16_BITS
		output.stereo = false
		output.mix_rate = _rate
		output.data = bytes
		output.save_to_wav((sound_name if sound_name.begins_with("res://") else FOLDER + sound_name) + ".wav")
		print("%s: %.2f s from %d layer(s), driven %.1f" % [sound_name, float(length) / _rate, voices.size(), drive])
	quit()


## One layer's span of its recording, played at a rate running from the layer's start rate to its end
## rate; mono, at the mix rate, peak-normalized to 1. Empty if the span is silent.
func _render(layer: Array) -> PackedFloat32Array:
	var source := String(layer[0]) if String(layer[0]).begins_with("res://") else FOLDER + String(layer[0]) + "_source.mp3"
	var stream := load(source) as AudioStream
	var from := float(layer[1])
	var to := float(layer[2])
	var playback := stream.instantiate_playback()
	playback.start(from)
	var voice := PackedFloat32Array()
	var at := from
	while at < to:
		var rate := lerpf(float(layer[3]), float(layer[4]), (at - from) / (to - from))
		for frame: Vector2 in playback.mix_audio(rate, CHUNK):
			voice.append((frame.x + frame.y) * 0.5)
		at += CHUNK * rate / _rate
	var peak := _peak(voice)
	if peak < 0.001:
		push_error("Silent span: %s %.2f-%.2f s" % [source, from, to])
		return PackedFloat32Array()
	for index in voice.size():
		voice[index] /= peak
	return voice


## Takes out what lies below HIGH_PASS_HZ: the rumble of handling and wind, made lower still by the slower rates.
func _high_pass(samples: PackedFloat32Array) -> void:
	var keep := exp(-TAU * HIGH_PASS_HZ / _rate)
	var previous_in := 0.0
	var previous_out := 0.0
	for index in samples.size():
		var value := samples[index]
		previous_out = keep * (previous_out + value - previous_in)
		previous_in = value
		samples[index] = previous_out


func _peak(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	return maxf(peak, 0.000001)
