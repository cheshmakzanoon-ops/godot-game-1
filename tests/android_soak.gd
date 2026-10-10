extends Node

# Debug-only Android endurance probe: real audio generator, all four song layers,
# spinning disc, frame pacing, retained memory and output underrun metrics.
# It does not simulate hardware speaker latency or thermals on a physical phone.
const DURATION := 40.0
const WARMUP := 3.0
const MAX_P95_FRAME_MS := 250.0 # Headless software GPU safeguard, not the phone's 60fps target.
const MAX_MEMORY_GROWTH := 24 * 1024 * 1024
const MAX_UNDERRUNS := 100 # Count of underrun events, not skipped sample frames.

var game: Node
var running := false
var started_usec := 0
var last_frame_usec := 0
var next_report := 10.0
var frame_ms: Array[float] = []
var memory_start := 0
var audio_start := 0
var skipped_start := 0

func _ready() -> void:
	call_deferred("_begin")

func _dense_events() -> Array:
	var result: Array = []
	for layer in 4:
		for shot in [6, 7, 8, 9][layer]:
			result.append({"layer": layer, "step": (shot * 3 + layer * 2) % 16,
				"order": shot, "velocity": 0.87})
	return result

func _fail(reason: String) -> void:
	if not running:
		return
	running = false
	printerr("NEEDLEBEAT_QA_PERF_FAIL " + reason)
	game.audio.stop()

func _begin() -> void:
	game = get_parent()
	if OS.get_name() != "Android" or not OS.has_feature("debug"):
		return
	if game == null or game.audio == null:
		printerr("NEEDLEBEAT_QA_PERF_FAIL no-game")
		return
	game.call("_open_menu")
	game.store.save_enabled = false # A QA probe must not overwrite player data.
	game.call("_start_song", false)
	if game.screen != "RECORD" or not game.audio.running or game.audio.paused:
		printerr("NEEDLEBEAT_QA_PERF_FAIL audio-not-running")
		return
	var events := _dense_events()
	game.events = events
	game.audio.set_events(events)
	var time := Time.get_ticks_usec()
	started_usec = time
	last_frame_usec = time
	running = true
	print("NEEDLEBEAT_QA_PERF_BEGIN layers=4 notes=", events.size(), " duration=", int(DURATION))

func _process(_delta: float) -> void:
	if not running:
		return
	var now := Time.get_ticks_usec()
	var elapsed := float(now - started_usec) / 1000000.0
	if elapsed >= WARMUP:
		if memory_start == 0:
			memory_start = OS.get_static_memory_usage()
			audio_start = game.audio.mixer.frame
			skipped_start = game.audio.playback.get_skips()
		if last_frame_usec != 0:
			frame_ms.append(float(now - last_frame_usec) / 1000.0)
	last_frame_usec = now
	if elapsed >= next_report:
		print("NEEDLEBEAT_QA_PERF_TICK sec=", roundi(elapsed), " mixer_frame=", game.audio.mixer.frame)
		next_report += 10.0
	if elapsed >= DURATION + WARMUP:
		_finish()

func _finish() -> void:
	running = false
	frame_ms.sort()
	var p95 := 0.0
	if not frame_ms.is_empty():
		p95 = frame_ms[clampi(ceili(float(frame_ms.size()) * 0.95) - 1, 0, frame_ms.size() - 1)]
	var actual_audio_frames := maxi(0, game.audio.mixer.frame - audio_start)
	var expected_frames := DURATION * float(NBMusicEngine.RATE)
	var audio_ratio := float(actual_audio_frames) / expected_frames
	var skips := maxi(0, game.audio.playback.get_skips() - skipped_start)
	var memory_growth := OS.get_static_memory_usage() - memory_start
	print("NEEDLEBEAT_QA_PERF_METRICS p95_ms=%.2f frames=%d audio_ratio=%.4f skips=%d memory_delta=%d" %
		[p95, frame_ms.size(), audio_ratio, skips, memory_growth])
	if frame_ms.size() < 150:
		_fail_after("insufficient-render-frames")
	elif p95 > MAX_P95_FRAME_MS:
		_fail_after("slow-software-renderer")
	elif audio_ratio < 0.85 or audio_ratio > 1.15:
		_fail_after("audio-clock-drift")
	elif skips > MAX_UNDERRUNS:
		_fail_after("audio-buffer-underruns")
	elif memory_growth > MAX_MEMORY_GROWTH:
		_fail_after("memory-growth")
	else:
		print("NEEDLEBEAT_QA_PERF_PASS")
	game.audio.stop()

func _fail_after(reason: String) -> void:
	printerr("NEEDLEBEAT_QA_PERF_FAIL " + reason)
