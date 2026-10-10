extends SceneTree

# End-to-end scene integration. Fires real 110ms shots by choosing a future
# physical impact time, rather than bypassing the game's collision system.
var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAILED  " + message)

func create_game(campaign_index: int = 0) -> Node:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	# Integration tests must never write to or change a player's real save.
	game.store.save_enabled = false
	game.store.data = game.store._defaults()
	game.store.data["campaign_index"] = campaign_index
	game.store.data["completed"] = campaign_index
	return game

func find_impact(game: Node, after_time: float, want_collision: bool = false,
	want_perfect: bool = false) -> float:
	for candidate_index in range(12000):
		var impact_time := after_time + float(candidate_index) * 0.0075
		var local_angle := NBGeometry.impact_local_angle(impact_time, game.motion)
		var result := NBGeometry.evaluate(local_angle, game.pins, game.active_lane)
		if bool(result["hit"]) == want_collision and (not want_perfect or bool(result["perfect"])):
			return impact_time
	return -1.0

func shoot(game: Node, time: float) -> void:
	game.call("_fire")
	game.flight_start = time
	game.stage_clock = time + NBGeometry.FLIGHT
	game.call("_land_shot")

func fill_record(game: Node, request_encore: bool = false, lose_encore: bool = false) -> int:
	var stage_id: int = game.stage_index
	var required: int = int(game.stage["quota"])
	var start_time := 0.0
	for index in required:
		var when := find_impact(game, start_time + 0.15)
		if when < 0.0:
			check(false, "reachable shot %d at stage %d" % [index, stage_id])
			return -1
		shoot(game, when)
		start_time = when
		check(game.placed == index + 1, "stage %d stores shot %d" % [stage_id, index + 1])
	check(game.screen == "STAGE_CLEAR", "stage %d clears at its exact quota" % stage_id)
	if not request_encore:
		return required
	game.call("_begin_encore")
	check(game.screen == "ENCORE", "encore optional state reached")
	for index in 2:
		var when := find_impact(game, start_time + 0.15, lose_encore and index == 0)
		if when < 0:
			check(false, "encore impact window found")
			return -1
		shoot(game, when)
		start_time = when
		if lose_encore:
			check(game.stage_index == stage_id + 1, "failed encore preserves completed record")
			return required
	check(game.stage_index == stage_id + 1, "successful encore advances stage")
	return required + 2

func run_campaign() -> void:
	var game := create_game()
	game.call("_start_song", false)
	check(game.screen == "RECORD" and game.stage_index == 0, "campaign starts at BEAT")
	check(game.music_version == 2, "new campaign records use version-two music")
	var safe := find_impact(game, 0.2, false, true)
	check(safe >= 0.0, "there is a safe PERFECT window")
	if safe < 0.0:
		game.free()
		return
	shoot(game, safe)
	check(game.stage_perfects == 1 and game.perfect_count == 0, "PERFECT is pending until record clear")
	var collision := find_impact(game, safe + 0.15, true)
	check(collision >= 0, "intentional collision available")
	if collision < 0.0:
		game.free()
		return
	shoot(game, collision)
	check(game.screen == "FAIL", "collision rejects shot")
	check(game.retries == 1 and game.miss_count == 1, "collision tracks retry and miss")
	game.call("_setup_stage")
	check(game.events.is_empty() and game.stage_perfects == 0 and game.perfect_count == 0,
		"retry discards failed stage note and accuracy")
	check(game.stage_points == 0 and game.total_score == 0, "failed record cannot farm score")
	var expected := 0
	for stage_id in 4:
		var landed := fill_record(game)
		if landed < 0:
			break
		expected += landed
		check(game.events.size() == expected, "all previous layers survive stage %d" % stage_id)
		game.call("_next_stage")
		if stage_id < 3:
			check(game.stage_index == stage_id + 1 and game.screen == "RECORD", "next record starts")
	if not game.last_song.is_empty():
		check(game.last_song["events"].size() == 30, "completed composition has thirty placed notes")
		check(game.store.data["completed"] == 1 and game.store.data["campaign_index"] == 1,
			"campaign progress advances exactly once")
		check(game.perfect_count <= 30 and game.perfect_count >= 0,
			"accuracy counts only the thirty recorded notes")
		var parsed: Dictionary = NBSongCodec.decode(game.last_song["code"])
		check(int(parsed.get("music_version", -1)) == 2 and parsed["events"] == game.events,
			"new share code reconstructs track including velocity")
		game.call("_save_track")
		check(game.store.data["favorites"].size() == 1, "completed track saved to local library")
		game.call("_play_saved", parsed)
		check(game.screen == "PREVIEW" and game.audio.mixer.music_version == 2,
			"saved v2 song replays with its own harmonic grammar")
		game.call("_open_menu")
		game.call("_start_song", true)
		check(game.is_daily and game.events.is_empty(), "daily challenge creates isolated session")
	game.call("_open_menu")
	game.free()

func run_encore() -> void:
	for lose in [false, true]:
		var game := create_game()
		game.call("_start_song", false)
		var landed := fill_record(game, true, lose)
		if landed > 0:
			var expected_score := 0
			# Beat score is the sum of landed note scores, stage completion and, if earned, encore.
			if lose:
				check(game.events.size() == 6, "failed encore rolls back its experimental notes")
				check(game.total_score > 600 and game.total_score < 2000,
					"failed encore keeps normal completed stage score")
			else:
				check(game.events.size() == 8, "successful encore adds exactly two notes")
				check(game.total_score >= 6 * 100 + 2 * 100 + 300 + 500,
					"successful encore earns a five-hundred point bonus")
			check(game.stage_index == 1 and game.screen == "RECORD", "encore progresses to ROOT")
			check(game.perfect_count <= landed, "encore cannot leak abandoned accuracy")
		game.call("_open_menu")
		game.free()

func run_specials() -> void:
	var game := create_game(34)
	game.selected_genre = 4
	game.call("_start_song", false)
	var expected_events := 0
	for stage_id in 4:
		check(game.stage["special"] in ["NORMAL", "PULSE", "REWIND", "TWIN"],
			"high-level special choice is supported")
		var shots := fill_record(game)
		if shots < 0:
			break
		expected_events += shots
		check(game.events.size() == expected_events, "high-level checkpoint across special stage")
		game.call("_next_stage")
	check(game.last_song.get("events", []).size() == 30, "high-level four-stage song clears")
	game.free()

func run_music() -> void:
	for genre in range(5):
		for bar in range(4):
			var chord := NBMusicEngine.chord_at(genre, bar, 987)
			var roots: Array = NBMusicEngine.notes_for_event(1, genre, bar, 0, 1, 987)
			var melody: Array = NBMusicEngine.notes_for_event(2, genre, bar, 0, 0, 987)
			var harmony: Array = NBMusicEngine.notes_for_event(3, genre, bar, 4, 2, 987)
			check(roots == [int(chord["root"])], "bass follows current chord")
			check(harmony[0] == int(chord["root"]) + 24,
				"harmony follows the same root")
			check(melody[0] in harmony, "strong melody note is a chord tone")
	var version_one := {"music_version": 1, "genre": 1, "bpm": 96, "seed": 77,
		"events": [{"layer": 1, "step": 1, "order": 0, "velocity": 0.72}]}
	var legacy_code: String = NBSongCodec.encode(version_one)
	var decoded := NBSongCodec.decode(legacy_code)
	check(legacy_code.begins_with("NBD1.") and decoded.get("music_version", 0) == 1,
		"legacy song code remains importable")
	var legacy_mixer := NBMusicEngine.new()
	legacy_mixer.setup(1, 96, decoded["events"], decoded["music_version"], decoded["seed"])
	var legacy_pcm := legacy_mixer.mix(2048)
	check(legacy_mixer.music_version == 1 and legacy_pcm.size() == 2048,
		"legacy sample recipe remains playable")
	# Golden PCM from the original NBD1 sound engine, before the v2 grammar update.
	var old_events := [{"layer": 0, "step": 0, "order": 0, "velocity": .9},
		{"layer": 1, "step": 5, "order": 1, "velocity": .72},
		{"layer": 2, "step": 7, "order": 3, "velocity": .89},
		{"layer": 3, "step": 12, "order": 4, "velocity": .75}]
	var golden_mixer := NBMusicEngine.new()
	golden_mixer.setup(2, 112, old_events, 1, 938)
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(golden_mixer.mix(8192).to_byte_array())
	check(h.finish().hex_encode() == "df5896b567e427e63b91de2b404e6b7a0f67ab356de8a1f12101a4ce50ac9773",
		"legacy NBD1 PCM stays byte-identical to original v1 engine")
	var events := [{"layer": 0, "step": 2, "order": 0, "velocity": .85},
		{"layer": 1, "step": 8, "order": 1, "velocity": .7},
		{"layer": 2, "step": 4, "order": 2, "velocity": .9},
		{"layer": 3, "step": 12, "order": 3, "velocity": .78}]
	var first := NBMusicEngine.new()
	var second := NBMusicEngine.new()
	first.setup(4, 104, events, 2, 12345)
	second.setup(4, 104, events, 2, 12345)
	var a := first.mix(8192)
	var b := second.mix(8192)
	check(a == b, "same composition and seed synthesize identical PCM")
	var peak := 0.0
	for frame in a:
		peak = maxf(peak, absf(frame.x))
	check(peak > 0.01 and peak < 1.0, "new genre harmony mix is non-silent and limited")
	check(NBMusicEngine.chord_at(0, 1, 0) != NBMusicEngine.chord_at(0, 1, 1),
		"different seeds select different curated progressions")

func run_export_audio() -> void:
	if OS.get_name() == "Android":
		return
	var game := create_game()
	game.call("_start_song", false)
	game.call("_complete_song")
	game.screen = "RESULTS"
	game.call("_export_wav")
	check(game.feedback == "WAV EXPORTED TO USER DATA", "desktop WAV export stays functional")
	check(FileAccess.file_exists(game.last_export_path), "exported WAV exists in user data")
	var file := FileAccess.open(game.last_export_path, FileAccess.READ)
	if file != null:
		check(file.get_buffer(4).get_string_from_ascii() == "RIFF", "share export has WAV RIFF signature")
		file.close()
	check(not NBAndroidShare.share_wav(game.last_export_path),
		"desktop does not attempt Android FileProvider sharing")
	game.free()

func run_checks() -> void:
	run_music()
	run_campaign()
	run_encore()
	run_specials()
	run_export_audio()
	call_deferred("finish")

func finish() -> void:
	print("FULL FLOW: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
