extends SceneTree

# Pure Godot engine regression: Java audio-focus notifications are delivered
# through the same controller method as the Android JNI callback. No Android
# permissions, audio hardware or real phone call are required to run this.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func verify(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FOCUS FAIL: " + description)

func new_game() -> Node:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	instance.store.save_enabled = false
	instance.store.data = instance.store._defaults()
	instance.call("_open_menu")
	return instance

func run_checks() -> void:
	var controller := NBAndroidAudioFocus.new()
	root.add_child(controller)
	var counters := {"loss": 0}
	controller.focus_lost.connect(func(_reason: int) -> void: counters["loss"] = int(counters["loss"]) + 1)
	verify(controller.request_focus() and controller.requested and controller.acquired,
		"focus request starts active on desktop fallback")
	controller._apply_focus_change(NBAndroidAudioFocus.FOCUS_GAIN)
	verify(int(counters["loss"]) == 0 and controller.acquired, "GAIN never interrupts the game")
	for reason in [NBAndroidAudioFocus.FOCUS_LOSS, NBAndroidAudioFocus.FOCUS_LOSS_TRANSIENT,
		NBAndroidAudioFocus.FOCUS_LOSS_CAN_DUCK]:
		controller.abandon_focus()
		controller.request_focus()
		controller._apply_focus_change(reason)
		verify(not controller.acquired and int(counters["loss"]) > 0,
			"permanent, transient and ducking losses all suspend playback")
	controller.abandon_focus()
	var count: int = int(counters["loss"])
	controller._apply_focus_change(NBAndroidAudioFocus.FOCUS_LOSS_TRANSIENT)
	controller._apply_focus_change(NBAndroidAudioFocus.FOCUS_GAIN)
	verify(int(counters["loss"]) == count and not controller.requested,
		"stale callbacks after focus abandonment are ignored")

	var game := new_game()
	game.call("_start_song", false)
	verify(game.screen == "RECORD" and game.audio.running and game.audio.focus.requested,
		"starting a song requests Android audio focus")
	var record_index: int = game.stage_index
	var before_score: int = game.total_score
	var before_pins: int = game.pins.size()
	game.audio.focus._apply_focus_change(NBAndroidAudioFocus.FOCUS_LOSS_TRANSIENT)
	verify(game.screen == "PAUSED" and game.paused_from == "RECORD",
		"transient audio interruption pauses the visible game")
	verify(game.audio.paused and game.audio.player.stream_paused and not game.audio.focus.requested,
		"interrupted transport is suspended and voluntarily abandons its focus")
	verify(game.store.data["active_song"].get("screen", "") == "RECORD",
		"interrupted record retains a recovery checkpoint")
	var previous_frame: int = game.audio.rendered_frames()
	OS.delay_msec(20)
	game.audio._pump()
	verify(game.audio.rendered_frames() == previous_frame,
		"backgrounded audio mixer produces no additional PCM frames")
	game.audio.focus._apply_focus_change(NBAndroidAudioFocus.FOCUS_GAIN)
	verify(game.screen == "PAUSED", "late focus gain never auto-plays without player consent")
	game.call("_resume_game")
	verify(game.screen == "RECORD" and not game.audio.paused and game.audio.focus.requested,
		"explicit resume reacquires focus and continues the same record")
	verify(game.total_score == before_score and game.stage_index == record_index and
		game.pins.size() == before_pins, "audio interruption does not change scoring or geometry")

	# Regular Android window-focus events still pause, and duplicate notifications
	# must not race the new platform audio-focus listener.
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	verify(game.screen == "PAUSED" and not game.audio.focus.requested,
		"window focus-out and app background notifications are idempotent")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	verify(game.screen == "PAUSED" and game.audio.paused,
		"returning to foreground does not unexpectedly restart the track")
	game.call("_resume_game")
	verify(game.screen == "RECORD" and game.audio.focus.requested,
		"manual resume after background regains audio focus")

	game.call("_pause_game")
	verify(not game.audio.focus.requested and game.audio.paused,
		"player-initiated pause releases focus for other music applications")
	game.call("_open_menu")
	verify(not game.audio.running and not game.audio.focus.requested,
		"leaving song releases focus and shuts down audio transport")
	game.queue_free()
	controller.queue_free()
	print("AUDIO FOCUS FLOW: %d assertions, %d failures" % [checks, failures])
	await create_timer(0.5).timeout # Drain native audio references before process teardown.
	quit(0 if failures == 0 else 1)
