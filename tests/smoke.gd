extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func verify(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAILED  " + description)
	else:
		print("PASS    " + description)

func run_checks() -> void:
	verify(is_equal_approx(NBGeometry.angular_distance(0, TAU - .03), .03), "wraparound collision distance")
	verify(NBGeometry.evaluate(0.0, [{"angle": 0.0, "lane": 0}], 0)["hit"], "direct collision")
	verify(not NBGeometry.evaluate(PI, [{"angle": 0.0, "lane": 0}], 0)["hit"], "far-safe landing")
	verify(not NBGeometry.evaluate(0.0, [{"angle": 0.0, "lane": 1}], 0)["hit"], "separate twin ring")
	var motion := NBDiscMotion.new()
	motion.configure(.25, 120, 1.0, "REWIND")
	verify(is_equal_approx(motion.phase_at(0.0), motion.phase_at(4.0)), "rewind analytic return")
	motion.configure(.25, 120, 1.0, "PULSE")
	verify(motion.phase_at(4.0) > motion.phase_at(2.0), "pulse continues forward")
	var stage_a := NBStageDirector.create_stage(4393, 3, 32, 120, false)
	var stage_b := NBStageDirector.create_stage(4393, 3, 32, 120, false)
	verify(JSON.stringify(stage_a) == JSON.stringify(stage_b), "deterministic stage seed")
	verify(NBStageDirector.daily_seed("2026-10-09") == NBStageDirector.daily_seed("2026-10-09"), "stable UTC daily challenge")
	var song := {"genre": 2, "bpm": 112, "seed": 909, "events": [
		{"layer": 0, "step": 0, "order": 0, "velocity": .9},
		{"layer": 1, "step": 5, "order": 1, "velocity": .7}]}
	var code := NBSongCodec.encode(song)
	var parsed := NBSongCodec.decode(code)
	verify(not parsed.is_empty() and parsed["events"].size() == 2, "song-code round trip")
	verify(NBSongCodec.decode(code + "A").is_empty(), "song-code checksum rejection")
	verify(code.begins_with("NBD2.") and int(parsed.get("music_version", 0)) == 2,
		"new songs use explicit NBD2 music version")
	var legacy_song := song.duplicate(true)
	legacy_song["music_version"] = 1
	verify(NBSongCodec.decode(NBSongCodec.encode(legacy_song)).get("music_version", -1) == 1,
		"original NBD1 codes remain importable")
	var mixer := NBMusicEngine.new()
	mixer.setup(2, 112, song["events"])
	var buffer := mixer.mix(4096)
	var peak := 0.0
	for sample in buffer:
		peak = maxf(peak, absf(sample.x))
	verify(peak > 0.01 and peak < 1.0, "original synthesized audio mixer emits bounded PCM")
	var system := NBAudioSystem.new()
	root.add_child(system)
	var path := "user://smoke_track.wav"
	verify(system.export_wav(song["events"], 2, 112, path), "complete four-bar WAV export")
	var wav := FileAccess.open(path, FileAccess.READ)
	verify(wav != null and wav.get_buffer(4).get_string_from_ascii() == "RIFF", "WAV RIFF header")
	var android_qa = load("res://tests/android_runtime.gd")
	verify(android_qa != null and android_qa.can_instantiate(), "debug-only Android runtime QA script parses")
	var scene: PackedScene = load("res://scenes/Main.tscn")
	verify(scene != null, "main scene loads")
	if scene != null:
		var game: Node = scene.instantiate()
		root.add_child(game)
		game.call("_start_song", false)
		verify(str(game.get("screen")) == "RECORD" and int(game.get("stage_index")) == 0, "playable game enters first record")
		game.call("_open_menu")
		game.queue_free()
	print("SMOKE TESTS: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
