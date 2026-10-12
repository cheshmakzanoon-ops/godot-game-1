extends SceneTree

# Regression for Android background/process-death recovery. Real file-backed
# save and the actual Game scene are exercised without touching player saves.
var errors := 0
var checks := 0
const SAVE := "user://needlebeat_checkpoint_qa.json"
const BACKUP := "user://needlebeat_checkpoint_qa_backup.json"

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		errors += 1
		printerr("CHECKPOINT FAIL: " + message)

func game() -> Node:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	instance.store.save_enabled = false
	instance.store.data = instance.store._defaults()
	return instance

func next_window(instance: Node, start: float = 0.15) -> float:
	for i in range(20000):
		var stamp: float = start + float(i) * 0.0075
		var angle := NBGeometry.impact_local_angle(stamp, instance.motion)
		if not bool(NBGeometry.evaluate(angle, instance.pins, instance.active_lane)["hit"]):
			return stamp
	return -1.0

func land(instance: Node, stamp: float) -> void:
	instance.call("_fire")
	instance.flight_start = stamp
	instance.stage_clock = stamp + NBGeometry.FLIGHT
	instance.call("_land_shot")

func run_checks() -> void:
	for filename in [SAVE, BACKUP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))

	var original := game()
	original.call("_start_song", false)
	var first: float = next_window(original)
	check(first > 0.0, "first landing window exists")
	if first < 0.0:
		quit(1)
		return
	land(original, first)
	var second: float = next_window(original, first + 0.3)
	land(original, second)
	check(original.screen == "RECORD" and original.placed == 2, "two note checkpoint created")
	check(original.store.data["active_song"]["pins"].size() == original.pins.size(),
		"checkpoint includes current geometry")
	original.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(original.screen == "PAUSED", "Android application pause suspends the record")
	var saved: Dictionary = original.store.data["active_song"].duplicate(true)
	check(saved["screen"] == "RECORD" and saved["placed"] == 2,
		"pause persists playable record state")
	check(saved["events"].size() == 2 and saved["stage_points"] == original.stage_points,
		"notes and pending stage score included")
	check(saved["stage_time"] > 0.0, "continuous disc phase stored")

	# Exercise durable on-disk round-trip and backup recovery after corruption.
	var disk_store := NBProgressStore.new()
	disk_store.file_path = SAVE
	disk_store.backup_path = BACKUP
	disk_store.data = disk_store._defaults()
	disk_store.data["active_song"] = saved
	disk_store.save()
	disk_store.save() # previous valid save becomes the last-known-good backup.
	var recovered_store := NBProgressStore.new()
	recovered_store.file_path = SAVE
	recovered_store.backup_path = BACKUP
	recovered_store.load_progress()
	check(int(recovered_store.data["active_song"].get("placed", -1)) == 2 and
		recovered_store.data["active_song"].get("events", []).size() == 2,
		"active song survives JSON reload")
	var corrupted := FileAccess.open(SAVE, FileAccess.WRITE)
	corrupted.store_string("{partial write")
	corrupted.close()
	recovered_store.load_progress()
	check(int(recovered_store.data["active_song"].get("placed", -1)) == 2 and
		recovered_store.data["active_song"].get("pins", []).size() == original.pins.size(),
		"corrupt primary falls back to backup")

	var restored := game()
	restored.store.data = recovered_store.data.duplicate(true)
	restored.call("_restore_active_song")
	check(restored.screen == "PAUSED" and restored.paused_from == "RECORD",
		"restart requires deliberate user resume")
	check(restored.audio.paused, "audio transport remains paused on restoration")
	check(restored.recovered_session, "pause overlay identifies recovered track")
	var positions_match: bool = restored.pins.size() == original.pins.size()
	for i in original.pins.size():
		positions_match = positions_match and is_equal_approx(float(restored.pins[i]["angle"]), float(original.pins[i]["angle"]))
	check(restored.events.size() == original.events.size() and positions_match,
		"the exact notes and hitboxes are reconstructed")
	check(restored.stage_points == original.stage_points and restored.total_score == original.total_score,
		"restoration cannot duplicate or discard points")
	check(absf(restored.motion.phase_at(restored.stage_clock) - original.motion.phase_at(original.stage_clock)) < 0.001,
		"deterministic disc phase survives restart")
	check(absf(restored.audio.elapsed_seconds() - saved["stage_time"]) < 0.24,
		"audio transport returns to the saved stage phase")
	restored.call("_resume_game")
	check(restored.screen == "RECORD" and not restored.audio.paused, "player can resume the unfinished record")
	check(not restored.recovered_session, "recovery notice clears after resuming")
	var third: float = next_window(restored, float(saved["stage_time"]) + 0.4)
	land(restored, third)
	check(restored.events.size() == 3, "new notes can be added after restarting")

	# If Android freezes/kills mid-flight, the unjudged pin is refunded.
	restored.call("_fire")
	var count_before: int = restored.events.size()
	restored.call("_pause_game")
	var flight: Dictionary = restored.store.data["active_song"].duplicate(true)
	check(flight["screen"] == "RECORD", "inflight shot normalized to safe retry")
	var after_flight := game()
	after_flight.store.data["active_song"] = flight
	after_flight.call("_restore_active_song")
	after_flight.call("_resume_game")
	check(after_flight.screen == "RECORD" and after_flight.events.size() == count_before,
		"restored flight does not duplicate or lose an embedded note")

	# A cleared record and its points remain intact across a kill.
	var stamp: float = float(after_flight.stage_clock) + 0.25
	while after_flight.placed < int(after_flight.stage["quota"]):
		stamp = next_window(after_flight, stamp)
		if stamp < 0.0:
			break
		land(after_flight, stamp)
		stamp += 0.2
	check(after_flight.screen == "STAGE_CLEAR", "record can still clear after restoration")
	var completed: Dictionary = after_flight.store.data["active_song"].duplicate(true)
	var after_clear := game()
	after_clear.store.data["active_song"] = completed
	after_clear.call("_restore_active_song")
	after_clear.call("_resume_game")
	check(after_clear.screen == "STAGE_CLEAR" and after_clear.stage_points == after_flight.stage_points,
		"a completed record is recovered without re-farming its score")
	after_clear.call("_next_stage")
	check(after_clear.stage_index == 1 and after_clear.total_score > 0,
		"committed first record advances to ROOT")
	check(after_clear.store.data["active_song"]["stage_index"] == 1,
		"new record receives its own independent checkpoint")

	# Reject malformed sessions, instead of crashing during _ready on a damaged save.
	var malformed := game()
	malformed.store.data["active_song"] = {"v": 1, "screen": "RECORD", "genre": 99}
	malformed.call("_restore_active_song")
	check(malformed.screen == "MENU" and malformed.store.data["active_song"].is_empty(),
		"invalid checkpoint is discarded safely")
	after_clear.call("_open_menu")
	check(after_clear.store.data["active_song"].is_empty(),
		"explicitly abandoning a song clears the checkpoint")

	# Bounded seek rebuilds the exact audible tail without rendering the entire
	# previously played composition, even for long pauses and repeated restarts.
	var tune: Array = [{"layer": 0, "step": 0, "order": 0, "velocity": 0.9},
		{"layer": 1, "step": 5, "order": 1, "velocity": 0.8},
		{"layer": 2, "step": 7, "order": 2, "velocity": 0.75},
		{"layer": 3, "step": 12, "order": 3, "velocity": 0.7}]
	var continuous := NBMusicEngine.new()
	continuous.setup(0, 120, tune, 2, 33)
	var sought := NBMusicEngine.new()
	sought.setup(0, 120, tune, 2, 33)
	continuous.mix(78000)
	var expected := continuous.mix(256)
	sought.seek_frame(78000)
	var actual := sought.mix(256)
	check(sought.frame == continuous.frame and expected == actual,
		"bounded audio restoration matches continuous sample-accurate output")

	# A completion must remove the active checkpoint in the same progress write.
	original.call("_resume_game")
	original.call("_complete_song")
	check(original.store.data["active_song"].is_empty(),
		"committing a finished song clears the active checkpoint")

	for node in [original, restored, after_flight, after_clear, malformed]:
		node.free()
	for filename in [SAVE, BACKUP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	print("CHECKPOINT FLOW: %d assertions, %d failures" % [checks, errors])
	await create_timer(0.5).timeout # Let native audio release retired playback references.
	quit(0 if errors == 0 else 1)
