extends Node

# Native Back is a Window signal, not necessarily an Escape key event.
# Keep this adapter separate from the deterministic record simulation.
signal exit_requested
var game: Node

func _ready() -> void:
	game = get_parent()
	get_tree().quit_on_go_back = false
	get_tree().auto_accept_quit = false
	get_tree().root.go_back_requested.connect(handle_back)
	get_tree().root.close_requested.connect(_close_requested)
	exit_requested.connect(get_tree().quit)

func handle_back() -> void:
	if game == null or game.audio == null:
		return
	match game.screen:
		"MENU":
			_close_requested()
		"IMPORT":
			game.import_field.visible = false
			game.screen = "LIBRARY"
		"PAUSED":
			# Do not resume from a dismissal gesture: the visible Continue control
			# is the sole native-back-screen way to restart the moving record.
			pass
		"RECORD", "FLIGHT", "ENCORE", "FAIL", "STAGE_CLEAR", "DROP_SHOW", "DROP_PAUSE", "PREVIEW":
			game.call("_pause_game")
		_:
			game.call("_open_menu")
	game.queue_redraw()
	if OS.get_name() == "Android" and OS.has_feature("debug"):
		print("NEEDLEBEAT_QA_NATIVE_BACK screen=", game.screen)

func _close_requested() -> void:
	if game != null and game.audio != null:
		if game.screen not in ["PAUSED", "MENU", "RESULTS", "LIBRARY", "SETTINGS", "IMPORT"]:
			game.call("_pause_game")
		game.call("_checkpoint_session")
		game.audio.stop()
	exit_requested.emit()
