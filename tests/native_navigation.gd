extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("NAVIGATION FAIL: " + message)
func run() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.store.save_enabled = false
	game.store.data = game.store._defaults()
	var navigation: Node = game.get_node("PlayerLifecycle")
	navigation.exit_requested.disconnect(quit)
	var closed := {"count": 0}
	navigation.exit_requested.connect(func(): closed["count"] += 1)
	check(not quit_on_go_back and not auto_accept_quit, "native exit is explicitly controlled")
	game.call("_start_song", false)
	game.call("_fire")
	var start: float = game.flight_start
	root.go_back_requested.emit()
	check(game.screen == "PAUSED" and game.paused_from == "FLIGHT", "native Back pauses an in-flight shot")
	check(game.audio.paused and not game.audio.worker_active(), "Back joins audio producer")
	root.go_back_requested.emit()
	check(game.screen == "PAUSED" and closed["count"] == 0, "second Back neither auto-plays nor discards progress")
	game.call("_tap", Vector2(220, 500))
	check(game.screen == "FLIGHT" and game.flight_start == start, "Continue resumes the same shot")
	root.close_requested.emit()
	check(closed["count"] == 1 and not game.audio.worker_active(), "window close shuts down the worker")
	check(game.store.data["active_song"]["screen"] == "RECORD", "window close retains a safe recovery checkpoint")
	game.call("_open_menu")
	game.screen = "IMPORT"
	game.import_field.visible = true
	root.go_back_requested.emit()
	check(game.screen == "LIBRARY" and not game.import_field.visible, "Back dismisses Import to its library")
	for screen in ["SETTINGS", "LIBRARY", "RESULTS"]:
		game.screen = screen
		root.go_back_requested.emit()
		check(game.screen == "MENU", "Back leaves " + screen + " for the studio")
	root.go_back_requested.emit()
	check(closed["count"] == 2, "Back at the studio allows a normal exit")
	game.free()
	await create_timer(0.3).timeout
	print("NATIVE NAVIGATION: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
