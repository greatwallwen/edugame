extends RefCounted


static func cue_profile(cue: String) -> Dictionary:
	var profiles := {
		"card": {"waveform": "triangle", "gain": 0.52, "notes": [{"frequency": 420.0, "duration": 0.07}]},
		"chain": {"waveform": "sine", "gain": 0.58, "notes": [{"frequency": 520.0, "duration": 0.05}, {"frequency": 690.0, "duration": 0.08}]},
		"repair": {"waveform": "triangle", "gain": 0.50, "notes": [{"frequency": 620.0, "duration": 0.05}, {"frequency": 790.0, "duration": 0.09}]},
		"weakness": {"waveform": "square", "gain": 0.34, "notes": [{"frequency": 760.0, "duration": 0.04}, {"frequency": 980.0, "duration": 0.08}]},
		"damage": {"waveform": "square", "gain": 0.42, "notes": [{"frequency": 190.0, "duration": 0.11}, {"frequency": 145.0, "duration": 0.12}]},
		"suppressed": {"waveform": "triangle", "gain": 0.55, "notes": [{"frequency": 430.0, "duration": 0.05}, {"frequency": 590.0, "duration": 0.05}, {"frequency": 740.0, "duration": 0.08}]},
		"fault": {"waveform": "noise", "gain": 0.28, "noiseSeed": 17, "notes": [{"frequency": 150.0, "duration": 0.11}, {"frequency": 105.0, "duration": 0.16}]},
		"boss_1": {"waveform": "triangle", "gain": 0.50, "notes": [{"frequency": 300.0, "duration": 0.08}, {"frequency": 250.0, "duration": 0.10}, {"frequency": 210.0, "duration": 0.14}]},
		"boss_2": {"waveform": "square", "gain": 0.36, "notes": [{"frequency": 240.0, "duration": 0.08}, {"frequency": 180.0, "duration": 0.08}, {"frequency": 240.0, "duration": 0.12}]},
		"boss_3": {"waveform": "noise", "gain": 0.31, "noiseSeed": 53, "notes": [{"frequency": 170.0, "duration": 0.10}, {"frequency": 130.0, "duration": 0.10}, {"frequency": 90.0, "duration": 0.18}]},
		"reward": {"waveform": "sine", "gain": 0.56, "notes": [{"frequency": 520.0, "duration": 0.05}, {"frequency": 660.0, "duration": 0.05}, {"frequency": 820.0, "duration": 0.10}]}
	}
	return (profiles.get(cue, {"waveform": "sine", "gain": 0.45, "notes": [{"frequency": 440.0, "duration": 0.08}]}) as Dictionary).duplicate(true)


static func target_key(kind: String, _event: Dictionary) -> String:
	return {
		"repair": "evidence",
		"weakness": "fault",
		"fault_suppressed": "fault",
		"stability": "device",
		"fault_triggered": "fault",
		"boss_phase": "fault"
	}.get(kind, "card" if kind == "card" else "fault")


static func banner_size(target_size: Vector2) -> Vector2:
	return Vector2(clampf(target_size.x - 12.0, 96.0, 300.0), 66.0)


static func tone_sequence(profile: Dictionary) -> AudioStreamWAV:
	var mix_rate := 22050
	var notes := profile.get("notes", []) as Array
	var waveform := str(profile.get("waveform", "sine"))
	var gain := clampf(float(profile.get("gain", 0.45)), 0.05, 1.0)
	var noise_seed := int(profile.get("noiseSeed", 1))
	var pause_duration := 0.018
	var total_duration := 0.0
	for raw_note in notes:
		total_duration += float((raw_note as Dictionary).get("duration", 0.08)) + pause_duration
	var sample_count := maxi(1, int(round(total_duration * mix_rate)))
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	var cursor := 0
	for raw_note in notes:
		var note := raw_note as Dictionary
		var frequency := float(note.get("frequency", 440.0))
		var duration := float(note.get("duration", 0.08))
		var note_samples := maxi(1, int(round(duration * mix_rate)))
		for note_index in range(note_samples):
			var progress := float(note_index) / float(note_samples)
			var envelope := minf(minf(progress / 0.08, (1.0 - progress) / 0.18), 1.0)
			var phase := TAU * frequency * float(note_index) / float(mix_rate)
			var sample := sin(phase)
			match waveform:
				"triangle":
					sample = asin(sin(phase)) * 2.0 / PI
				"square":
					sample = 0.72 if sin(phase) >= 0.0 else -0.72
				"noise":
					var noise_value := sin(float(note_index + noise_seed * 131) * 12.9898) * 43758.5453
					var deterministic_noise := fposmod(noise_value, 2.0) - 1.0
					sample = deterministic_noise * 0.58 + sin(phase) * 0.42
			var value := int(round(sample * 11200.0 * gain * maxf(envelope, 0.0)))
			if cursor + note_index < sample_count:
				samples.encode_s16((cursor + note_index) * 2, value)
		cursor += note_samples + int(round(pause_duration * mix_rate))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = samples
	return stream
