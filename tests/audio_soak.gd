extends SceneTree

# Runs ten virtual minutes of continuous, high-density audio through the real
# production mixer; fast-forwards the audio samples, not the musical scheduler.
# No real-time waiting, network access or user save data is required.
const DURATION_SECONDS := 600
const BLOCK_FRAMES := 1024
const MAX_VOICES := 16
var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("SOAK FAILED: " + description)

func dense_events() -> Array:
	var notes: Array = []
	var counts := [6, 7, 8, 9]
	for layer in 4:
		for i in counts[layer]:
			notes.append({"layer": layer, "step": (i * 3 + layer * 2) % 16,
				"order": i, "velocity": 0.87})
	return notes

func run() -> void:
	var events := dense_events()
	check(events.size() == 30, "Four layers contain the complete 30-shot arrangement")
	var engine := NBMusicEngine.new()
	engine.setup(3, 132, events, NBMusicEngine.MUSIC_VERSION, 4071)
	var total := DURATION_SECONDS * NBMusicEngine.RATE
	var start_usec := Time.get_ticks_usec()
	var first_memory := 0
	var last_memory := 0
	var max_voices := 0
	var peak := 0.0
	var checked_frames := 0
	while checked_frames < total:
		var sample_count := mini(BLOCK_FRAMES, total - checked_frames)
		var frames := engine.mix(sample_count)
		if checked_frames == 0:
			check(frames.size() == sample_count, "Mixer emits each requested audio block")
		for i in frames.size():
			var mono: Vector2 = frames[i]
			if not is_finite(mono.x) or not is_finite(mono.y) or absf(mono.x) >= 1.0 or absf(mono.y) >= 1.0:
				check(false, "PCM buffer contains NaN or hard clipping")
				break
			peak = maxf(peak, absf(mono.x))
		max_voices = maxi(max_voices, engine.active.size())
		checked_frames += frames.size()
		if checked_frames >= NBMusicEngine.RATE * 60 and first_memory == 0:
			first_memory = OS.get_static_memory_usage()
	last_memory = OS.get_static_memory_usage()
	var elapsed_sec := float(Time.get_ticks_usec() - start_usec) / 1000000.0
	var ratio := elapsed_sec / float(DURATION_SECONDS)
	check(engine.frame == total and checked_frames == total, "No cumulative audio sample drift over ten minutes")
	check(max_voices <= MAX_VOICES, "Active sound voices remain bounded")
	check(peak > 0.03 and peak < 1.0, "Ten-minute audio mix is audible and soft-limited")
	check(first_memory > 0 and last_memory - first_memory < 8 * 1024 * 1024,
		"Mixer does not retain unbounded memory during playback")
	# This is a generous desktop CI headroom check, not a claim about phone CPU.
	check(ratio < 0.35, "Mixer spends less than 35% of available real-time audio budget on CI")
	# A long-running session must be seekable without mixing millions of silent frames.
	var destination := 5 * 3600 * NBMusicEngine.RATE
	var seek := NBMusicEngine.new()
	seek.setup(3, 132, events, NBMusicEngine.MUSIC_VERSION, 4071)
	seek.seek_frame(destination)
	check(seek.frame == destination, "Five-hour transport seeks without an integer wrap")
	check(seek.mix(1024).size() == 1024, "Far-ahead transport produces audio")
	# Compare a restored transport against continuous playback sample for sample.
	var reference := NBMusicEngine.new()
	var restored := NBMusicEngine.new()
	reference.setup(3, 132, events, NBMusicEngine.MUSIC_VERSION, 4071)
	restored.setup(3, 132, events, NBMusicEngine.MUSIC_VERSION, 4071)
	var target := 23 * NBMusicEngine.RATE + 173
	var remaining := target
	while remaining > 0:
		remaining -= reference.mix(mini(4096, remaining)).size()
	restored.seek_frame(target)
	check(reference.mix(4096) == restored.mix(4096),
		"Restored PCM exactly matches uninterrupted playback at a non-grid position")
	print("AUDIO SOAK: %d assertions, %d failures, 600s simulated, %.2fs wall time, " %
		[assertions, failures, elapsed_sec],
		"real-time ratio=%.4f peak=%.3f max_voices=%d memory_delta=%d" %
		[ratio, peak, max_voices, last_memory - first_memory])
	quit(0 if failures == 0 else 1)
