extends SceneTree
## Decode CC0 source previews, choose the strongest short vocal section,
## normalize it and bake gentle edge fades. Originals remain untouched.
func _initialize() -> void:
	var rate := int(AudioServer.get_mix_rate())
	for entity: String in ["wrapper", "clawman", "ridgeback"]:
		var stream := load("res://sounds/entities/death_scares/" + entity + "_source.mp3") as AudioStream
		var playback := stream.instantiate_playback()
		playback.start()
		var frames := playback.mix_audio(1.0, int(stream.get_length() * rate))
		var window := mini(int(rate * 1.5), frames.size())
		var best_start := 0
		var best_energy := -1.0
		var energies := PackedFloat64Array()
		energies.resize(frames.size() + 1)
		for index in frames.size():
			energies[index + 1] = energies[index] + frames[index].length_squared()
		for start in range(0, frames.size() - window + 1, int(rate * 0.025)):
			var energy := energies[start + window] - energies[start]
			if energy > best_energy:
				best_energy = energy
				best_start = start
		var peak := 0.0
		for index in range(best_start, best_start + window):
			peak = maxf(peak, maxf(absf(frames[index].x), absf(frames[index].y)))
		if peak < 0.001:
			push_error("Silent death audio: " + entity)
			quit(1)
			return
		var bytes := PackedByteArray()
		bytes.resize(window * 4)
		for index in window:
			var edge := minf(1.0, minf(float(index) / (rate * 0.015), float(window - index) / (rate * 0.18)))
			var frame := frames[best_start + index] * (0.85 / peak) * edge
			bytes.encode_s16(index * 4, int(clampf(frame.x, -1, 1) * 32767))
			bytes.encode_s16(index * 4 + 2, int(clampf(frame.y, -1, 1) * 32767))
		var output := AudioStreamWAV.new()
		output.format = AudioStreamWAV.FORMAT_16_BITS
		output.stereo = true
		output.mix_rate = rate
		output.data = bytes
		output.save_to_wav("res://sounds/entities/death_scares/" + entity + "_kill.wav")
		print(entity, " source start=", float(best_start) / rate, " peak=", peak, " normalized to 0.85")
	quit()
