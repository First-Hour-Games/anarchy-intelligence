extends SceneTree
## Cut the shotgun's sounds from the CC0 source previews in sounds/weapons/shotgun (see its CREDITS.md):
## each is a span of one source, peak-normalized, with a short fade in and a fade out, saved beside them as
## a mono WAV. Prints where each one peaks, which shotgun_weapon.gd lines up with the moment it belongs to.
## Originals remain untouched.
##
## godot --headless --path . --script res://tools/prepare_shotgun_audio.gd

const FOLDER := "res://sounds/weapons/shotgun/"
## Each sound: its source, the span taken from it (seconds), the peak it is normalized to and how long its
## fade out lasts. The break-action recording runs: opened, closed, hammer cocked, dry-fired, opened,
## loaded, closed, opened again ejecting the shell.
const CUTS := {
	"shotgun_blast_1": ["blasts_source.mp3", 4.92, 6.5, 0.9, 0.8],
	"shotgun_blast_2": ["blasts_source.mp3", 9.29, 10.87, 0.9, 0.8],
	"shotgun_blast_3": ["blasts_source.mp3", 13.42, 15.0, 0.9, 0.8],
	"shotgun_break_open": ["break_action_source.mp3", 0.34, 0.62, 0.8, 0.1],
	"shotgun_shells_out": ["break_action_source.mp3", 14.17, 14.75, 0.8, 0.25],
	"shotgun_shells_in": ["break_action_source.mp3", 11.69, 12.1, 0.8, 0.12],
	"shotgun_snap_shut": ["break_action_source.mp3", 2.63, 3.0, 0.8, 0.12],
	"shotgun_dry_fire": ["break_action_source.mp3", 5.36, 5.75, 0.8, 0.12],
}
const FADE_IN := 0.003

func _initialize() -> void:
	var rate := int(AudioServer.get_mix_rate())
	var decoded := {}
	for sound_name: String in CUTS:
		var cut: Array = CUTS[sound_name]
		var source: String = cut[0]
		if not decoded.has(source):
			var stream := load(FOLDER + source) as AudioStream
			var playback := stream.instantiate_playback()
			playback.start()
			decoded[source] = playback.mix_audio(1.0, int(stream.get_length() * rate))
		var frames: PackedVector2Array = decoded[source]
		var first := int(float(cut[1]) * rate)
		var count := mini(int(float(cut[2]) * rate), frames.size()) - first
		var peak := 0.0
		var peak_at := 0
		for index in count:
			var level := absf((frames[first + index].x + frames[first + index].y) * 0.5)
			if level > peak:
				peak = level
				peak_at = index
		if peak < 0.001:
			push_error("Silent shotgun audio: " + sound_name)
			quit(1)
			return
		var fade_out := float(cut[4]) * rate
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for index in count:
			var edge := minf(1.0, minf(float(index) / (rate * FADE_IN), float(count - index) / fade_out))
			var sample := (frames[first + index].x + frames[first + index].y) * 0.5 * (float(cut[3]) / peak) * edge
			bytes.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767))
		var output := AudioStreamWAV.new()
		output.format = AudioStreamWAV.FORMAT_16_BITS
		output.stereo = false
		output.mix_rate = rate
		output.data = bytes
		output.save_to_wav(FOLDER + sound_name + ".wav")
		print("%s from %s %.2f-%.2f s: %.2f s long, peaks at %.3f s" % [sound_name, source, cut[1], cut[2],
			float(count) / rate, float(peak_at) / rate])
	quit()
