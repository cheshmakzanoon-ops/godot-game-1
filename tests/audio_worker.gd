extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WORKER FAIL: " + message)

func run() -> void:
	var audio := NBAudioSystem.new()
	root.add_child(audio)
	var notes := [{"layer": 3, "step": 0, "order": 0, "velocity": 0.8}]
	audio.configure(0, 120, notes)
	check(audio.worker_active(), "PCM producer starts independently of graphical frames")
	OS.delay_msec(200) # Warm up the engine's audio thread.
	var before := audio.rendered_frames()
	var skips := audio.playback.get_skips()
	OS.delay_msec(450) # Deliberately blocks the main thread for >2 buffer lengths.
	check(audio.rendered_frames() > before + 6000, "PCM keeps flowing during a 450ms render stall")
	check(audio.playback.get_skips() - skips <= 1, "no sustained underruns during render stall")
	audio.pause_playback()
	before = audio.rendered_frames()
	OS.delay_msec(100)
	check(not audio.worker_active() and audio.rendered_frames() == before, "pause joins producer and freezes PCM")
	check(audio.resume_playback(), "manual resume reacquires focus")
	OS.delay_msec(100)
	check(audio.worker_active(), "producer resumes")
	for i in 12:
		audio.set_events(notes)
		audio.set_music_volume(0.4 + float(i % 3) * 0.1)
		audio.effect("click")
		audio.seek_seconds(float(i) + 0.137)
		audio.pause_playback()
		check(absf(audio.elapsed_seconds() - (float(i) + 0.137)) < 0.25, "seek remains bounded during thread churn")
		audio.resume_playback()
		audio.configure(i % 5, 120, notes)
	audio.stop()
	check(not audio.worker_active() and not audio.running, "stop joins producer before destroying playback")
	audio.configure(0, 120, notes)
	audio.free() # _exit_tree must join even without explicit stop.
	await create_timer(0.5).timeout # Let AudioServer release its last playback reference.
	check(true, "free joins an active worker without orphan thread")
	print("AUDIO WORKER: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
