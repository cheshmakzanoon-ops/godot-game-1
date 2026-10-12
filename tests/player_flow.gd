extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PLAYER FAIL: " + message)

func run() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.store.save_enabled = false
	game.store.data = game.store._defaults()
	game.call("_open_menu")
	var song := {"genre": 0, "bpm": 120, "seed": 17, "score": 913,
		"events": [{"layer": 0, "step": 0, "order": 0, "velocity": 0.8}]}
	for i in 5:
		song["seed"] = i + 17
		song["code"] = NBSongCodec.encode(song)
		game.store.data["favorites"].append(song.duplicate(true))
	for i in 5:
		game.screen = "LIBRARY"
		game.call("_tap", Vector2(200, 300 + i * 96))
		check(game.screen == "PREVIEW" and game.seed == i + 17, "library lower row region maps to its actual row")
		game.call("_tap", Vector2(200, 790))
		check(game.screen == "RESULTS", "preview skip leads to save/share/replay controls")
		var before: int = game.store.data["completed"]
		game.call("_tap", Vector2(340, 200))
		check(game.screen == "PREVIEW" and game.total_score == 913 and game.store.data["completed"] == before, "replay does not award another completion or discard score")
	game.screen = "LIBRARY"
	game.call("_tap", Vector2(200, 318))
	check(game.screen == "LIBRARY", "gaps between favorite cards are not mistaken for another song")
	game.call("_start_song", false)
	game.call("_fire")
	game.call("_tap", Vector2(426, 55))
	check(game.screen == "PAUSED" and game.paused_from == "FLIGHT", "in-flight pause control works")
	game.call("_resume_game")
	game.screen = "RECORD"
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(240, 710)
	game.call("_unhandled_input", touch)
	check(game.screen == "RECORD", "a second finger cannot fire a second shot")
	game.screen = "SETTINGS"
	game.call("_tap", Vector2(64, 330))
	game.call("_tap", Vector2(416, 400))
	check(game.audio.mixer.music_volume == 0 and game.audio.effects_volume == 1, "music and hit effects have independent levels")
	game.call("_tap", Vector2(200, 605))
	check(game.store.data["settings"]["flashes"] == false, "reduced glow can be selected independently")
	check(NBStageDirector.daily_countdown(0) == "24:00:00", "UTC reset starts a full daily interval")
	check(NBStageDirector.daily_countdown(86399) == "00:00:01", "UTC reset countdown handles midnight")
	game.call("_start_song", false)
	game.call("_checkpoint_session")
	var checkpoint: Dictionary = game.store.data["active_song"].duplicate(true)
	check(game.call("_checkpoint_is_valid", checkpoint), "current checkpoint passes strict types")
	for key in checkpoint:
		var bad := checkpoint.duplicate(true)
		bad[key] = [] if typeof(checkpoint[key]) != TYPE_ARRAY else "invalid"
		check(not game.call("_checkpoint_is_valid", bad), "corrupted checkpoint field rejected: " + key)
	check(not NBAndroidShare.share_wav("user://exports/../needlebeat_private.wav"), "share path traversal rejected")
	game.call("_open_menu")
	game.free()
	await create_timer(0.5).timeout
	print("PLAYER FLOW: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
